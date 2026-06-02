import 'package:cloudtolocalllm/services/voice/dev_voice_input_adapter.dart';
import 'package:cloudtolocalllm/services/voice/voice_input_contract.dart';
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

  group('DevVoiceInputAdapter - partial transcripts', () {
    test('emits partial transcript events while running', () async {
      final adapter = DevVoiceInputAdapter();
      final events = <VoiceInputTranscriptEvent>[];
      final subscription = adapter.transcripts.listen(events.add);

      await adapter.start();
      adapter.submitPartialTranscript('partial   words');
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      expect(events.single.text, 'partial words');
      expect(events.single.isFinal, isFalse);
      expect(events.single.source, VoiceInputSource.dev);

      await subscription.cancel();
      await adapter.dispose();
    });

    test('ignores empty and whitespace-only transcripts', () async {
      final adapter = DevVoiceInputAdapter();
      final events = <VoiceInputTranscriptEvent>[];
      final subscription = adapter.transcripts.listen(events.add);

      await adapter.start();
      adapter.submitFinalTranscript('   ');
      adapter.submitPartialTranscript('');
      await Future<void>.delayed(Duration.zero);

      expect(events, isEmpty);

      await subscription.cancel();
      await adapter.dispose();
    });

    test('adapter is supported and not running initially', () {
      final adapter = DevVoiceInputAdapter();
      expect(adapter.isSupported, isTrue);
      expect(adapter.isRunning, isFalse);
      adapter.dispose();
    });
  });

  group('VoiceConversationService', () {
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

    test('starts in idle mode', () {
      expect(voiceConversationService.snapshot.mode,
          VoiceConversationMode.idle);
    });

    test('noteWakePhrase changes to engaged mode', () {
      voiceConversationService.noteWakePhrase('hello');
      expect(voiceConversationService.snapshot.mode,
          VoiceConversationMode.engaged);
      expect(voiceConversationService.snapshot.isEngaged, isTrue);
    });

    test('buildFastAcknowledgement returns response for heard query', () {
      final ack = voiceConversationService
          .buildFastAcknowledgement('Zoidbot can you hear me?');
      expect(ack, isNotNull);
    });

    test('shouldPreferConversationalPath returns true when engaged', () {
      voiceConversationService.noteWakePhrase('hello');
      expect(
          voiceConversationService.shouldPreferConversationalPath('test'),
          isTrue);
    });
  });
}
