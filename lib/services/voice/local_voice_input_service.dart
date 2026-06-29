import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:record/record.dart';

import 'voice_conversation_service.dart';

/// UI-facing state for the local voice input path.
class LocalVoiceInputSnapshot {
  const LocalVoiceInputSnapshot({
    required this.isCapturing,
    required this.lastFullTranscript,
    required this.lastError,
    required this.sttStatus,
  });

  final bool isCapturing;
  final String lastFullTranscript;
  final String? lastError;
  final String sttStatus;
}

/// Local mic capture service with real STT via local faster-whisper server.
///
/// Uses the `record` package (WASAPI on Windows, PulseAudio on Linux)
/// to capture mic audio, wraps chunks as WAV, POSTs to STT server,
/// and feeds transcripts into [VoiceConversationService].
class LocalVoiceInputService extends ChangeNotifier {
  LocalVoiceInputService({
    required VoiceConversationService voiceConversationService,
    this.sttUrl = 'http://127.0.0.1:8646/v1/audio/transcriptions',
    this.sampleRate = 16000,
    this.flushInterval = const Duration(seconds: 3),
  })  : _voiceConversationService = voiceConversationService;

  final VoiceConversationService _voiceConversationService;
  final String sttUrl;
  final int sampleRate;
  final Duration flushInterval;

  AudioRecorder? _recorder;
  StreamSubscription<Uint8List>? _stateSub;
  bool _isCapturing = false;
  bool _disposed = false;

  final BytesBuilder _pcmBuffer = BytesBuilder(copy: false);
  Timer? _flushTimer;
  Future<void> _pendingStt = Future<void>.value();
  String _lastFullTranscript = '';
  String? _lastError;
  String _sttStatus = 'unconfigured';

  bool get isCapturing => _isCapturing;
  String get sttStatus => _sttStatus;

  LocalVoiceInputSnapshot get snapshot => LocalVoiceInputSnapshot(
        isCapturing: _isCapturing,
        lastFullTranscript: _lastFullTranscript,
        lastError: _lastError,
        sttStatus: _sttStatus,
      );

  Future<bool> startCapture() async {
    if (_isCapturing || _disposed || kIsWeb) return false;

    final hasStt = await _reachableStt();
    if (!hasStt) {
      _lastError = 'STT endpoint unreachable: $sttUrl';
      _sttStatus = 'unavailable';
      return false;
    }

    final recorder = AudioRecorder();
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      _lastError = 'Microphone permission denied';
      _sttStatus = 'error';
      return false;
    }

    try {
      _recorder = recorder;
      final stream = await _recorder!.startStream(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          numChannels: 1,
          sampleRate: 16000,
        ),
      );

      _isCapturing = true;
      _lastError = null;
      _sttStatus = 'capturing';

      _stateSub = stream.listen(
        _onPcm,
        onError: _onPcmError,
        onDone: _onPcmDone,
        cancelOnError: false,
      );

      // Periodic flush even if PCM stream is continuous
      _flushTimer = Timer.periodic(flushInterval, (_) {
        unawaited(_flushAndTranscribe());
      });

      return true;
    } catch (e) {
      _lastError = 'Capture start failed: $e';
      _isCapturing = false;
      _sttStatus = 'error';
      return false;
    }
  }

  Future<void> stopCapture() async {
    if (!_isCapturing) return;
    _isCapturing = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flushAndTranscribe();
    await _stateSub?.cancel();
    _stateSub = null;
    await _recorder?.stop();
    _recorder = null;
    _sttStatus = 'stopped';
  }

  @override
  void dispose() {
    _disposed = true;
    stopCapture();
    super.dispose();
  }

  /// PCM data arrives from record as WAV bytes.
  void _onPcm(List<int> data) {
    if (_disposed || data.isEmpty) return;
    _pcmBuffer.add(data);
  }

  Future<void> _onPcmDone() async {
    _sttStatus = 'idle';
    await _flushAndTranscribe();
  }

  void _onPcmError(Object e) {
    _lastError = 'Capture stream error: $e';
    _sttStatus = 'error';
    _isCapturing = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _pcmBuffer.clear();
    _recorder = null;
    notifyListeners();
  }

  /// Take the accumulated PCM, wrap as WAV, POST to STT, feed transcript.
  Future<void> _flushAndTranscribe() async {
    if (_disposed) return;
    if (_pcmBuffer.isEmpty) return;

    final pcmBytes = _pcmBuffer.takeBytes();
    if (pcmBytes.isEmpty) return;

    _pendingStt = _pendingStt.then((_) => _transcribePcm(pcmBytes));
    await _pendingStt;
  }

  Future<void> _transcribePcm(List<int> pcmBytes) async {
    try {
      _voiceConversationService.noteTranscriptInProgress('Processing...');
      final wavBytes = Uint8List.fromList(pcmBytes);
      final text = await _postStt(wavBytes);

      _voiceConversationService.noteTranscriptInProgress('');

      if (text.isEmpty) return;

      _lastFullTranscript = text;

      if (_voiceConversationService.shouldPreferConversationalPath(text)) {
        _voiceConversationService.noteWakePhrase(text);
      }
    } catch (e) {
      _lastError = 'STT error: $e';
    }
  }

  /// POST a WAV file to the STT endpoint and return the transcription text.
  Future<String> _postStt(Uint8List wavBytes) async {
    final boundary = '----VoiceBoundary${DateTime.now().microsecondsSinceEpoch}';

    final body = utf8.encode(
          '--$boundary\r\n'
          'Content-Disposition: form-data; name="file"; filename="voice.wav"\r\n'
          'Content-Type: audio/wav\r\n\r\n',
        ) +
        wavBytes +
        utf8.encode('\r\n--$boundary--\r\n');

    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse(sttUrl));
      request.headers.set('Content-Type', 'multipart/form-data; boundary=$boundary');
      request.headers.set('Content-Length', body.length.toString());
      request.add(body);
      final response = await request.close().timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        final errBody = await response.transform(utf8.decoder).join();
        throw Exception('STT returned ${response.statusCode}: $errBody');
      }

      final respBody = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(respBody) as Map<String, dynamic>;
      return (decoded['text'] as String?)?.trim() ?? '';
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _reachableStt() async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    try {
      final request = await client.getUrl(Uri.parse(sttUrl.replaceAll('/v1/audio/transcriptions', '/health')));
      final response = await request.close();
      return response.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
