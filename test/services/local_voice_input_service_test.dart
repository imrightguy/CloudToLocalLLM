import 'package:cloudtolocalllm/services/voice/local_voice_input_service.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalVoiceInputService', () {
    late VoiceConversationService voiceConversationService;

    setUp(() {
      voiceConversationService = VoiceConversationService(
        config: const VoiceConversationConfig(
          engagedHold: Duration(milliseconds: 200),
        ),
      );
    });

    tearDown(() {
      voiceConversationService.dispose();
    });

    test('starts in a stopped state with correct defaults', () {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
      );

      expect(service.isCapturing, isFalse);
      expect(service.sttStatus, 'unconfigured');

      final snap = service.snapshot;
      expect(snap.isCapturing, isFalse);
      expect(snap.lastFullTranscript, isEmpty);
      expect(snap.lastError, isNull);
      expect(snap.sttStatus, 'unconfigured');

      service.dispose();
    });

    test('startCapture returns false when capture command is not available', () async {
      // Use a command that won't exist to guarantee failure
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        captureCommand: '__nonexistent_cmd_12345__',
      );
      addTearDown(service.dispose);

      final started = await service.startCapture();
      expect(started, isFalse);
      expect(service.isCapturing, isFalse);
      expect(service.sttStatus, 'unavailable');

      final snap = service.snapshot;
      expect(snap.isCapturing, isFalse);
      expect(snap.lastError, contains('missing capture command'));
      expect(snap.sttStatus, 'unavailable');
    });

    test('stopCapture is a no-op when not capturing', () async {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
      );
      addTearDown(service.dispose);

      // Should not throw
      await service.stopCapture();
      expect(service.isCapturing, isFalse);
    });

    test('dispose prevents further capture', () async {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
      );

      await service.dispose();
      // After dispose, startCapture should return false
      final started = await service.startCapture();
      expect(started, isFalse);
    });

    test('accepts custom configuration', () {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        sttUrl: 'http://custom:9999/v1/audio/transcriptions',
        captureCommand: 'arecord',
        sampleRate: 44100,
      );

      expect(service.sttStatus, 'unconfigured');
      expect(service.isCapturing, isFalse);

      final snap = service.snapshot;
      expect(snap.sttStatus, 'unconfigured');

      service.dispose();
    });

    test('snapshot values reflect internal state changes', () async {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        captureCommand: '__nonexistent_cmd_12345__',
      );
      addTearDown(service.dispose);

      // Before start
      var snap = service.snapshot;
      expect(snap.isCapturing, isFalse);
      expect(snap.sttStatus, 'unconfigured');

      // After failed start — sttStatus and lastError should update
      await service.startCapture();
      snap = service.snapshot;
      expect(snap.isCapturing, isFalse);
      expect(snap.sttStatus, 'unavailable');
      expect(snap.lastError, isNotNull);

      // After stopCapture — sttStatus becomes 'stopped'
      await service.stopCapture();
      snap = service.snapshot;
      expect(snap.isCapturing, isFalse);
      // stopCapture sets sttStatus to 'stopped' only if was capturing;
      // since startCapture never succeeded, this is a no-op
    });
  });
}
