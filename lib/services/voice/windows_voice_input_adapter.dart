import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

import 'voice_input_contract.dart';

/// Windows voice input adapter using WASAPI mic capture + local STT server.
class WindowsVoiceInputAdapter implements VoiceInputAdapter {
  WindowsVoiceInputAdapter({
    this.sttUrl = 'http://127.0.0.1:8646/v1/audio/transcriptions',
    this.sampleRate = 16000,
    this.flushInterval = const Duration(seconds: 3),
  });

  final String sttUrl;
  final int sampleRate;
  final Duration flushInterval;

  final StreamController<VoiceInputTranscriptEvent> _transcriptsController =
      StreamController<VoiceInputTranscriptEvent>.broadcast();

  AudioRecorder? _recorder;
  StreamSubscription<RecordState>? _stateSub;
  bool _isRunning = false;
  bool _disposed = false;

  @override
  Stream<VoiceInputTranscriptEvent> get transcripts =>
      _transcriptsController.stream;

  @override
  bool get isSupported => !_disposed;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<void> start() async {
    if (_disposed || _isRunning) return;

    final hasPermission = await AudioRecorder.hasPermission();
    if (!hasPermission) {
      throw StateError('Microphone permission denied');
    }

    _recorder = AudioRecorder();
    _isRunning = true;

    // Start recording to stream — record package supports WASAPI on Windows
    final stream = await _recorder!.startStream(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 16000,
      ),
    );

    final pcmBuffer = BytesBuilder(copy: false);

    _stateSub = stream.listen(
      (data) {
        if (_disposed) return;
        pcmBuffer.add(data);
      },
      onError: (e) {
        _transcriptsController.addError(e);
      },
      onDone: () {
        // Flush remaining
        if (pcmBuffer.isNotEmpty && !_disposed) {
          _transcribe(pcmBuffer.takeBytes());
        }
      },
    );

    // Periodic flush
    Timer.periodic(flushInterval, (_) {
      if (_disposed || pcmBuffer.isEmpty) return;
      _transcribe(pcmBuffer.takeBytes());
    });
  }

  Future<void> _transcribe(Uint8List wavBytes) async {
    try {
      final text = await _postStt(wavBytes);
      if (text.isEmpty) return;

      _transcriptsController.add(
        VoiceInputTranscriptEvent(
          text: text,
          isFinal: true,
          source: VoiceInputSource.native,
        ),
      );
    } catch (e) {
      // STT failure — don't crash, just skip this chunk
    }
  }

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
      request.headers.set(
        'Content-Type',
        'multipart/form-data; boundary=$boundary',
      );
      request.headers.set('Content-Length', body.length.toString());
      request.add(body);
      final response =
          await request.close().timeout(const Duration(seconds: 30));

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

  @override
  Future<void> stop() async {
    if (!_isRunning) return;
    _isRunning = false;
    await _stateSub?.cancel();
    _stateSub = null;
    await _recorder?.stop();
    _recorder = null;
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _transcriptsController.close();
  }
}
