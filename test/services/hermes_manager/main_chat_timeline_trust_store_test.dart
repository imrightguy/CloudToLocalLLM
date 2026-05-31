import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_record.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_sync_envelope.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_trust_store.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSyncSigner implements MainChatTimelineSyncSigner {
  @override
  Future<String> sign(String canonicalPayloadJson) async {
    return 'sig:${canonicalPayloadJson.length}:${canonicalPayloadJson.hashCode}';
  }
}

class FakeSyncVerifier implements MainChatTimelineSyncVerifier {
  @override
  Future<bool> verify({
    required String canonicalPayloadJson,
    required String signature,
    required String publicKey,
  }) async {
    final expected = 'sig:${canonicalPayloadJson.length}:${canonicalPayloadJson.hashCode}:$publicKey';
    return signature == expected;
  }
}

void main() {
  group('MainChatTimelineTrustStore', () {
    test('accepts trusted envelopes and tracks replay state', () async {
      final record = MainChatTimelineRecord.fromTimelineEvent(
        MainChatTimelineEvent(
          id: 'chat:conversation-1:user-1',
          type: MainChatTimelineEventType.chatUser,
          title: 'User',
          body: 'Hello there',
          timestamp: DateTime.utc(2026, 5, 2, 12),
          sourceId: 'user-1',
        ),
        sourceDeviceId: 'device-a',
        sourceSequence: 1,
        revision: 1,
        scope: MainChatTimelineScope.conversation,
        conversationId: 'conversation-1',
        sourceKind: MainChatTimelineSourceKind.chat,
      );

      final unsignedEnvelope = await MainChatTimelineSyncEnvelope.buildFromRecords(
        sourceDeviceId: 'device-a',
        sourceSequence: 2,
        authorization: MainChatTimelineSyncAuthorization.pairedDevice(
          deviceId: 'device-a',
        ),
        records: <MainChatTimelineRecord>[record],
        signer: FakeSyncSigner(),
        createdAtUtc: DateTime.utc(2026, 5, 2, 12, 30),
      );
      final trustStore = MainChatTimelineTrustStore();
      trustStore.trustDevice(deviceId: 'device-a', publicKey: 'device-a-public-key');
      final verifier = FakeSyncVerifier();
      final signedEnvelope = unsignedEnvelope.copyWith(
        signature:
            'sig:${unsignedEnvelope.canonicalPayloadJson().length}:${unsignedEnvelope.canonicalPayloadJson().hashCode}:device-a-public-key',
      );

      await trustStore.acceptEnvelope(signedEnvelope, verifier: verifier);
      expect(trustStore.lastAcceptedSequenceFor('device-a'), 2);

      await expectLater(
        trustStore.acceptEnvelope(signedEnvelope, verifier: verifier),
        throwsA(isA<MainChatTimelineSyncException>().having(
          (exception) => exception.message,
          'message',
          contains('replayed source sequence'),
        )),
      );
    });

    test('rejects unknown, revoked, tampered and jwt-authorized envelopes', () async {
      final record = MainChatTimelineRecord.fromTimelineEvent(
        MainChatTimelineEvent(
          id: 'local-think:device-a:task-1:completed',
          type: MainChatTimelineEventType.localThinkCompleted,
          title: 'Background work completed',
          body: 'Detailed result from the local run.',
          timestamp: DateTime.utc(2026, 5, 2, 12, 3),
          sourceId: 'task-1',
        ),
        sourceDeviceId: 'device-a',
        sourceSequence: 1,
        revision: 1,
        scope: MainChatTimelineScope.global,
        sourceKind: MainChatTimelineSourceKind.localThink,
      );
      final verifier = FakeSyncVerifier();

      final unknownDeviceEnvelope = await MainChatTimelineSyncEnvelope.buildFromRecords(
        sourceDeviceId: 'device-a',
        sourceSequence: 3,
        authorization: MainChatTimelineSyncAuthorization.pairedDevice(
          deviceId: 'device-a',
        ),
        records: <MainChatTimelineRecord>[record],
        signer: FakeSyncSigner(),
        createdAtUtc: DateTime.utc(2026, 5, 2, 12, 30),
      );
      final unknownDeviceStore = MainChatTimelineTrustStore();
      await expectLater(
        unknownDeviceStore.validateEnvelope(unknownDeviceEnvelope, verifier: verifier),
        throwsA(isA<MainChatTimelineSyncException>().having(
          (exception) => exception.message,
          'message',
          contains('unknown device signature'),
        )),
      );

      final trustedStore = MainChatTimelineTrustStore();
      trustedStore.trustDevice(deviceId: 'device-a', publicKey: 'device-a-public-key');
      final signedEnvelope = unknownDeviceEnvelope.copyWith(
        signature:
            'sig:${unknownDeviceEnvelope.canonicalPayloadJson().length}:${unknownDeviceEnvelope.canonicalPayloadJson().hashCode}:device-a-public-key',
      );

      await trustedStore.acceptEnvelope(signedEnvelope, verifier: verifier);
      expect(trustedStore.lastAcceptedSequenceFor('device-a'), 3);

      final revokedStore = MainChatTimelineTrustStore(
        devices: <MainChatTimelineTrustedDevice>[
          MainChatTimelineTrustedDevice(
            deviceId: 'device-a',
            publicKey: 'device-a-public-key',
            revoked: true,
          ),
        ],
      );
      await expectLater(
        revokedStore.validateEnvelope(signedEnvelope, verifier: verifier),
        throwsA(isA<MainChatTimelineSyncException>().having(
          (exception) => exception.message,
          'message',
          contains('revoked device signature'),
        )),
      );

      final tamperedEnvelope = signedEnvelope.copyWith(
        records: <MainChatTimelineRecord>[
          record.copyWith(bodyRedacted: 'tampered body'),
        ],
      );
      final tamperedStore = MainChatTimelineTrustStore();
      tamperedStore.trustDevice(deviceId: 'device-a', publicKey: 'device-a-public-key');
      await expectLater(
        tamperedStore.validateEnvelope(tamperedEnvelope, verifier: verifier),
        throwsA(isA<MainChatTimelineSyncException>().having(
          (exception) => exception.message,
          'message',
          contains('tampered record payload'),
        )),
      );

      final jwtEnvelope = MainChatTimelineSyncEnvelope(
        envelopeVersion: MainChatTimelineSyncEnvelope.currentEnvelopeVersion,
        sourceDeviceId: 'device-a',
        sourceSequence: 4,
        createdAtUtc: DateTime.utc(2026, 5, 2, 12, 40),
        authorization: MainChatTimelineSyncAuthorization.userJwt(),
        records: <MainChatTimelineRecord>[record],
        signature: 'sig',
      );
      final jwtSignedEnvelope = jwtEnvelope.copyWith(
        signature:
            'sig:${jwtEnvelope.canonicalPayloadJson().length}:${jwtEnvelope.canonicalPayloadJson().hashCode}:device-a-public-key',
      );
      final jwtStore = MainChatTimelineTrustStore();
      jwtStore.trustDevice(deviceId: 'device-a', publicKey: 'device-a-public-key');
      await expectLater(
        jwtStore.validateEnvelope(jwtSignedEnvelope, verifier: verifier),
        throwsA(isA<MainChatTimelineSyncException>().having(
          (exception) => exception.message,
          'message',
          contains('ordinary user JWT cannot authorize sync'),
        )),
      );
    });
  });
}
