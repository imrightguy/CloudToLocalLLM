import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceConversationService', () {
    late VoiceConversationService service;

    setUp(() {
      service = VoiceConversationService(
        config: const VoiceConversationConfig(
          engagedHold: Duration(milliseconds: 120),
        ),
      );
    });

    tearDown(() {
      service.dispose();
    });

    test('starts idle with default bridge state', () {
      final snapshot = service.snapshot;
      expect(snapshot.mode, VoiceConversationMode.idle);
      expect(snapshot.isEngaged, isFalse);
      expect(snapshot.liveBridgeConnected, isFalse);
      expect(snapshot.liveBridgeStatus, 'local demo only');
    });

    test('wake phrase engages conversation and stores transcript', () {
      service.noteWakePhrase('Zoidbot, are you there?');

      final snapshot = service.snapshot;
      expect(snapshot.mode, VoiceConversationMode.engaged);
      expect(snapshot.isEngaged, isTrue);
      expect(snapshot.lastUserTranscript, 'Zoidbot, are you there?');
      expect(snapshot.engagedUntil, isNotNull);
    });

    test('buildFastAcknowledgement returns natural acknowledgements', () {
      expect(
        service.buildFastAcknowledgement('are you hearing me right now'),
        'Yeah, I hear you.',
      );
      expect(
        service.buildFastAcknowledgement('Zoidbot hello bot'),
        'Yeah? I’m here.',
      );
      expect(
        service.buildFastAcknowledgement('what are you doing'),
        'Yeah, go on.',
      );
    });

    test('noteAssistantReply moves service into speaking mode', () {
      service.noteAssistantReply('Yeah, I’m here.');

      final snapshot = service.snapshot;
      expect(snapshot.mode, VoiceConversationMode.speaking);
      expect(snapshot.lastAssistantReply, 'Yeah, I’m here.');
      expect(snapshot.isEngaged, isTrue);
    });

    test('applyExternalSnapshot replaces local state from live bridge', () {
      final until = DateTime.now().add(const Duration(seconds: 15));

      service.applyExternalSnapshot(
        mode: VoiceConversationMode.listening,
        liveBridgeConnected: true,
        liveBridgeStatus: 'live Hermes bridge',
        engagedUntil: until,
        lastUserTranscript: 'Can you hear me now?',
        lastAssistantReply: 'Yeah, better now.',
      );

      final snapshot = service.snapshot;
      expect(snapshot.mode, VoiceConversationMode.listening);
      expect(snapshot.liveBridgeConnected, isTrue);
      expect(snapshot.liveBridgeStatus, 'live Hermes bridge');
      expect(snapshot.lastUserTranscript, 'Can you hear me now?');
      expect(snapshot.lastAssistantReply, 'Yeah, better now.');
      expect(snapshot.engagedUntil, isNotNull);
    });

    test('engagement hold expires back to idle', () async {
      service.noteWakePhrase('Hey Hermes');
      expect(service.snapshot.isEngaged, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 180));

      final snapshot = service.snapshot;
      expect(snapshot.isEngaged, isFalse);
      expect(snapshot.mode, VoiceConversationMode.idle);
    });
  });
}
