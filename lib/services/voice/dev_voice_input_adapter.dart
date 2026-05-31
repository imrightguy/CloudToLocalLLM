import 'dart:async';

import 'voice_input_types.dart';

/// Development adapter that allows tests and debug UI to inject transcripts.
class DevVoiceInputAdapter implements VoiceInputAdapter {
  final StreamController<VoiceInputTranscriptEvent> _transcriptsController =
      StreamController<VoiceInputTranscriptEvent>.broadcast();

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
    if (_disposed) {
      return;
    }
    _isRunning = true;
  }

  @override
  Future<void> stop() async {
    _isRunning = false;
  }

  void submitFinalTranscript(String text) {
    _submitTranscript(text, isFinal: true);
  }

  void submitPartialTranscript(String text) {
    _submitTranscript(text, isFinal: false);
  }

  Future<void> dispose() async {
    _disposed = true;
    _isRunning = false;
    await _transcriptsController.close();
  }

  void _submitTranscript(String text, {required bool isFinal}) {
    if (!_isRunning || _disposed) {
      return;
    }
    final cleaned = _clean(text);
    if (cleaned.isEmpty) {
      return;
    }
    _transcriptsController.add(
      VoiceInputTranscriptEvent(
        text: cleaned,
        isFinal: isFinal,
        source: VoiceInputSource.dev,
      ),
    );
  }

  String _clean(String text) {
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
