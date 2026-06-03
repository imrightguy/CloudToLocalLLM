import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

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
/// Captures PCM from `parec`, wraps chunks as WAV, POSTs to STT server,
/// and feeds transcripts into [VoiceConversationService].
class LocalVoiceInputService extends ChangeNotifier {
  LocalVoiceInputService({
    required VoiceConversationService voiceConversationService,
    this.sttUrl = 'http://127.0.0.1:8646/v1/audio/transcriptions',
    this.captureCommand = 'parec',
    this.sampleRate = 16000,
    this.flushInterval = const Duration(seconds: 3),
  })  : _voiceConversationService = voiceConversationService;

  final VoiceConversationService _voiceConversationService;
  final String sttUrl;
  final String captureCommand;
  final int sampleRate;
  final Duration flushInterval;

  Process? _captureProcess;
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

    final hasCapture = await _hasCommand(captureCommand);
    final hasStt = await _reachableStt();

    if (!hasCapture || !hasStt) {
      _lastError = [
        if (!hasCapture) 'missing capture command: $captureCommand',
        if (!hasStt) 'STT endpoint unreachable: $sttUrl',
      ].join('; ');
      _sttStatus = 'unavailable';
      return false;
    }

    try {
      _captureProcess = await Process.start(
        captureCommand,
        [
          '--rate=$sampleRate',
          '--format=s16le',
          '--channels=1',
          '--raw',
          '--device=@DEFAULT_SOURCE@',
        ],
      );

      _isCapturing = true;
      _lastError = null;
      _sttStatus = 'capturing';

      _captureProcess!.stdout.listen(
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
    _captureProcess?.kill();
    _captureProcess = null;
    _sttStatus = 'stopped';
  }

  @override
  void dispose() {
    _disposed = true;
    stopCapture();
    super.dispose();
  }

  /// PCM data arrives from parec as raw s16le bytes.
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
    // Pipeline died silently — clean up so the UI can retry
    _isCapturing = false;
    _flushTimer?.cancel();
    _flushTimer = null;
    _pcmBuffer.clear();
    _captureProcess = null;
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
      final wavBytes = _buildWav(Uint8List.fromList(pcmBytes));
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

  /// Build a WAV header around raw PCM s16le mono data.
  Uint8List _buildWav(Uint8List pcmBytes) {
    const channels = 1;
    const bitsPerSample = 16;
    const bytesPerSample = bitsPerSample ~/ 8;
    final byteRate = sampleRate * channels * bytesPerSample;
    final blockAlign = channels * bytesPerSample;
    final dataLength = pcmBytes.length;
    final totalLength = 44 + dataLength;
    final buffer = Uint8List(totalLength);
    final bytes = ByteData.sublistView(buffer);

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        buffer[offset + i] = value.codeUnitAt(i);
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);       // PCM
    bytes.setUint16(22, channels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, byteRate, Endian.little);
    bytes.setUint16(32, blockAlign, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);

    buffer.setRange(44, totalLength, pcmBytes);
    return buffer;
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

  Future<bool> _hasCommand(String command) async {
    try {
      final result = await Process.run('which', [command]);
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
