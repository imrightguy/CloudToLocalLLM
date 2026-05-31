import 'dart:async';

/// The source of a voice input transcript.
enum VoiceInputSource {
  dev,
  native,
}

/// A single voice input transcript event emitted by an adapter.
class VoiceInputTranscriptEvent {
  VoiceInputTranscriptEvent({
    required this.text,
    required this.isFinal,
    required this.source,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String text;
  final bool isFinal;
  final VoiceInputSource source;
  final DateTime timestamp;
}

/// Platform adapter contract for voice input capture/transcription.
abstract class VoiceInputAdapter {
  Stream<VoiceInputTranscriptEvent> get transcripts;
  bool get isSupported;
  bool get isRunning;

  Future<void> start();
  Future<void> stop();
}

String cleanVoiceTranscript(String text) {
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}
