import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_destination_selector.dart';
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
    return signature == 'sig:${canonicalPayloadJson.length}:${canonicalPayloadJson.hashCode}';
  }
}

void main() {
  group('MainChatTimelineDestinationSelector', () {
    test('derives destinations only from trusted paired-device inventory', () {
      final trustStore = MainChatTimelineTrustStore(
        devices: <MainChatTimelineTrustedDevice>[
          MainChatTimelineTrustedDevice(
            deviceId: 'source-device',
            publicKey: 'source-public-key',
            approvedScopes: <String>{'main-chat-timeline-sync'},
          ),
          MainChatTimelineTrustedDevice(
            deviceId: 'allowed-peer',
            publicKey: 'allowed-public-key',
            approvedScopes: <String>{'main-chat-timeline-sync'},
          ),
          MainChatTimelineTrustedDevice(
            deviceId: 'unsupported-peer',
            publicKey: 'unsupported-public-key',
            approvedScopes: <String>{'voice'},
          ),
          MainChatTimelineTrustedDevice(
            deviceId: 'revoked-peer',
            publicKey: 'revoked-public-key',
            revoked: true,
            approvedScopes: <String>{'main-chat-timeline-sync'},
          ),
        ],
      );
      final selector = MainChatTimelineDestinationSelector(trustStore: trustStore);

      final destinations = selector.selectDestinations(sourceDeviceId: 'source-device');

      expect(destinations, hasLength(1));
      expect(destinations.single.deviceId, 'allowed-peer');
      expect(destinations.single.publicKey, 'allowed-public-key');
      expect(destinations.single.allowsScope('main-chat-timeline-sync'), isTrue);
      expect(destinations.single.allowsScope('voice'), isFalse);
    });

    test('sender contract rejects unpaired source devices before signing', () async {
      final trustStore = MainChatTimelineTrustStore();
      final selector = MainChatTimelineDestinationSelector(trustStore: trustStore);
      final contract = MainChatTimelineSyncSenderContract(
        trustStore: trustStore,
        destinationSelector: selector,
      );

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

      await expectLater(
        contract.buildEnvelope(
          sourceDeviceId: 'device-a',
          sourceSequence: 2,
          signer: FakeSyncSigner(),
          records: <MainChatTimelineRecord>[record],
        ),
        throwsA(
          isA<MainChatTimelineSyncException>().having(
            (exception) => exception.message,
            'message',
            contains('unpaired device cannot authorize sync writes'),
          ),
        ),
      );
    });

    test('sender contract builds paired-device envelopes that trust-store accepts',
        () async {
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
      final trustStore = MainChatTimelineTrustStore();
      trustStore.trustDevice(
        deviceId: 'device-a',
        publicKey: 'device-a-public-key',
        approvedScopes: <String>{'main-chat-timeline-sync'},
      );
      trustStore.trustDevice(
        deviceId: 'device-b',
        publicKey: 'device-b-public-key',
        approvedScopes: <String>{'main-chat-timeline-sync'},
      );
      final selector = MainChatTimelineDestinationSelector(trustStore: trustStore);
      final contract = MainChatTimelineSyncSenderContract(
        trustStore: trustStore,
        destinationSelector: selector,
      );
      final verifier = FakeSyncVerifier();

      final destinations = contract.selectDestinations(sourceDeviceId: 'device-a');
      expect(destinations.map((destination) => destination.deviceId), <String>['device-b']);

      final envelope = await contract.buildEnvelope(
        sourceDeviceId: 'device-a',
        sourceSequence: 2,
        signer: FakeSyncSigner(),
        records: <MainChatTimelineRecord>[record],
        createdAtUtc: DateTime.utc(2026, 5, 2, 12, 30),
      );

      expect(envelope.authorization.kind, MainChatTimelineSyncAuthorizationKind.pairedDevice);
      expect(envelope.authorization.deviceId, 'device-a');

      await trustStore.acceptEnvelope(envelope, verifier: verifier);
      expect(trustStore.lastAcceptedSequenceFor('device-a'), 2);
    });
  });
}
