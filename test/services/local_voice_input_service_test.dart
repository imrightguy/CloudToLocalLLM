import 'package:cloudtolocalllm/services/voice/local_voice_input_service.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DevVoiceInputAdapter', () {
    test('emits final transcript events only while running', () async {
      final adapter = DevVoiceInputAdapter();
      final events = <VoiceInputTranscriptEvent>[];
      final subscription = adapter.transcripts.listen(events.add);

      adapter.submitFinalTranscript('ignored before start');
      await Future<void>.delayed(Duration.zero);
      expect(events, isEmpty);

      await adapter.start();
      adapter.submitFinalTranscript('  hello   voice  ');
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.text, 'hello voice');
      expect(events.single.isFinal, isTrue);
      expect(events.single.source, VoiceInputSource.dev);

      await adapter.stop();
      adapter.submitFinalTranscript('ignored after stop');
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));

      await subscription.cancel();
      await adapter.dispose();
    });
  });

  group('LocalVoiceInputService', () {
    late VoiceConversationService voiceConversationService;
    late DevVoiceInputAdapter devAdapter;

    setUp(() {
      voiceConversationService = VoiceConversationService(
        config: const VoiceConversationConfig(
          engagedHold: Duration(milliseconds: 200),
        ),
      );
      devAdapter = DevVoiceInputAdapter();
    });

    tearDown(() async {
      await devAdapter.dispose();
      voiceConversationService.dispose();
    });

    test('starts adapter and moves conversation into listening mode', () async {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        adapter: devAdapter,
        isWeb: false,
      );

      await service.start();

      expect(service.isRunning, isTrue);
      expect(devAdapter.isRunning, isTrue);
      expect(voiceConversationService.snapshot.mode,
          VoiceConversationMode.listening);

      await service.dispose();
    });

    test('routes final dev transcripts into a fast conversational turn',
        () async {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        adapter: devAdapter,
        isWeb: false,
      );

      await service.start();
      devAdapter.submitFinalTranscript('Zoidbot can you hear me properly?');
      await Future<void>.delayed(Duration.zero);

      final snapshot = voiceConversationService.snapshot;
      expect(snapshot.lastUserTranscript, 'Zoidbot can you hear me properly?');
      expect(snapshot.lastAssistantReply, 'Yeah, I hear you.');
      expect(snapshot.mode, VoiceConversationMode.speaking);
      expect(snapshot.isEngaged, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 900));

      final afterAckSnapshot = voiceConversationService.snapshot;
      expect(afterAckSnapshot.mode, VoiceConversationMode.engaged);
      expect(afterAckSnapshot.isEngaged, isTrue);

      await service.dispose();
    });

    test('uses a provided native adapter when no explicit adapter is given',
        () async {
      final nativeAdapter = DevVoiceInputAdapter();
      addTearDown(nativeAdapter.dispose);

      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        adapter: nativeAdapter,
        isWeb: false,
      );

      await service.start();
      nativeAdapter.submitFinalTranscript('Can you hear the native path?');
      await Future<void>.delayed(Duration.zero);

      expect(service.isRunning, isTrue);
      expect(nativeAdapter.isRunning, isTrue);
      expect(
        voiceConversationService.snapshot.lastUserTranscript,
        'Can you hear the native path?',
      );

      await service.dispose();
    });

    test('submitDevTranscript forwards through the dev adapter', () async {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        adapter: devAdapter,
        isWeb: false,
      );

      await service.start();
      service.submitDevTranscript('Can you hear the dev path?');
      await Future<void>.delayed(Duration.zero);

      expect(
        voiceConversationService.snapshot.lastUserTranscript,
        'Can you hear the dev path?',
      );

      await service.dispose();
    });

    test('ignores partial and empty transcript events for now', () async {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        adapter: devAdapter,
        isWeb: false,
      );

      await service.start();
      devAdapter.submitPartialTranscript('partial words');
      devAdapter.submitFinalTranscript('   ');
      await Future<void>.delayed(Duration.zero);

      final snapshot = voiceConversationService.snapshot;
      expect(snapshot.lastUserTranscript, isEmpty);
      expect(snapshot.mode, VoiceConversationMode.listening);

      await service.dispose();
    });

    test('stop returns the conversation state to idle', () async {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        adapter: devAdapter,
        isWeb: false,
      );

      await service.start();
      devAdapter.submitFinalTranscript('Zoidbot can you hear me?');
      await Future<void>.delayed(Duration.zero);

      expect(
        voiceConversationService.snapshot.mode,
        VoiceConversationMode.speaking,
      );
      expect(voiceConversationService.snapshot.isEngaged, isTrue);

      await service.stop();

      final snapshot = voiceConversationService.snapshot;
      expect(snapshot.mode, VoiceConversationMode.idle);
      expect(snapshot.isEngaged, isFalse);
      expect(snapshot.lastUserTranscript, 'Zoidbot can you hear me?');
    });

    test('web guard is a no-op and does not start adapter', () async {
      final service = LocalVoiceInputService(
        voiceConversationService: voiceConversationService,
        adapter: devAdapter,
        isWeb: true,
      );

      await service.start();
      devAdapter.submitFinalTranscript('should not be heard');
      await Future<void>.delayed(Duration.zero);

      expect(service.isSupported, isFalse);
      expect(service.isRunning, isFalse);
      expect(devAdapter.isRunning, isFalse);
      expect(voiceConversationService.snapshot.lastUserTranscript, isEmpty);

      await service.dispose();
    });
  });
}
