import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cloudtolocalllm/services/voice/hermes_voice_bridge_service.dart';
import 'package:cloudtolocalllm/services/voice/voice_conversation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HermesVoiceBridgeService', () {
    late Directory tempDir;
    late VoiceConversationService voiceService;
    late HermesVoiceBridgeService bridgeService;

    setUp(() async {
      tempDir =
          await Directory.systemTemp.createTemp('ctllm_voice_bridge_test_');
      voiceService = VoiceConversationService();
      bridgeService = HermesVoiceBridgeService(
        voiceConversationService: voiceService,
        pollInterval: const Duration(milliseconds: 40),
        habitMonitorPath: tempDir.path,
      );
    });

    tearDown(() async {
      bridgeService.dispose();
      voiceService.dispose();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('reports waiting state when Hermes files are missing', () async {
      bridgeService.start();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final snapshot = voiceService.snapshot;
      expect(snapshot.liveBridgeConnected, isFalse);
      expect(snapshot.liveBridgeStatus,
          contains('waiting for Hermes voice reactor status'));
      expect(snapshot.mode, VoiceConversationMode.idle);
    });

    test('maps live Hermes observer files into conversational state', () async {
      await _writeJson(
        File('${tempDir.path}/voice_reactor_status.json'),
        {
          'running': true,
          'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch / 1000,
          'last_transcript_preview': 'Are you hearing me now?',
          'last_candidate_response': 'Yeah, I hear you.',
          'last_spoken': 'Yeah, I hear you.',
        },
      );
      await _writeJson(
        File('${tempDir.path}/conversation_state.json'),
        {
          'engaged_until': DateTime.now()
                  .toUtc()
                  .add(const Duration(seconds: 15))
                  .millisecondsSinceEpoch /
              1000,
          'last_user_transcript': 'Are you hearing me now?',
          'last_reply': 'Yeah, I hear you.',
        },
      );
      await _writeJson(
        File('${tempDir.path}/status.json'),
        {
          'last_observation': {
            'audio': {
              'metrics': {'speech_like': true}
            }
          }
        },
      );

      bridgeService.start();
      await Future<void>.delayed(const Duration(milliseconds: 120));

      final snapshot = voiceService.snapshot;
      expect(snapshot.liveBridgeConnected, isTrue);
      expect(snapshot.liveBridgeStatus, 'live Hermes bridge');
      expect(snapshot.lastUserTranscript, 'Are you hearing me now?');
      expect(snapshot.lastAssistantReply, 'Yeah, I hear you.');
      expect(snapshot.mode,
          anyOf(VoiceConversationMode.speaking, VoiceConversationMode.engaged));
      expect(snapshot.isEngaged, isTrue);
    });
  });
}

Future<void> _writeJson(File file, Map<String, dynamic> jsonMap) async {
  await file.writeAsString(jsonEncode(jsonMap));
}
