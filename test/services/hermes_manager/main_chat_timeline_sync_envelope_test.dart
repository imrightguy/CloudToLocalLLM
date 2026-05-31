import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_record.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_sync_envelope.dart';
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
  group('MainChatTimelineSyncEnvelope', () {
    test('serializes batches canonically and excludes local-only payload fields', () async {
      final record = MainChatTimelineRecord.fromTimelineEvent(
        MainChatTimelineEvent(
          id: 'chat:conversation-1:user-1',
          type: MainChatTimelineEventType.chatUser,
          title: 'User',
          body: 'Token token=abc123 and password=secret',
          timestamp: DateTime.utc(2026, 5, 2, 12),
          sourceId: 'user-1',
          artifactPath: '/tmp/work/job.final.md',
          metadata: const <String, Object?>{
            'status': 'sent',
            'model': 'gpt-5',
            'attempts': 2,
            'maxAttempts': 4,
            'token': 'abc123',
            'unknown': 'drop me',
          },
        ),
        sourceDeviceId: 'device-a',
        sourceSequence: 7,
        revision: 1,
        scope: MainChatTimelineScope.conversation,
        conversationId: 'conversation-1',
        sourceKind: MainChatTimelineSourceKind.chat,
      );

      final envelope = await MainChatTimelineSyncEnvelope.buildFromRecords(
        sourceDeviceId: 'device-a',
        sourceSequence: 11,
        authorization: MainChatTimelineSyncAuthorization.pairedDevice(
          deviceId: 'device-a',
        ),
        records: <MainChatTimelineRecord>[record],
        signer: FakeSyncSigner(),
        createdAtUtc: DateTime.utc(2026, 5, 2, 12, 30),
      );

      final canonical = envelope.canonicalPayloadJson();
      expect(canonical, contains('"authorization":{"deviceId":"device-a","kind":"pairedDevice"}'));
      expect(canonical, contains('"records":[{'));
      expect(canonical, contains('"artifactName":"job.final.md"'));
      expect(canonical, isNot(contains('localArtifactPath')));
      expect(canonical, isNot(contains('localOnlyMetadata')));
      expect(canonical, isNot(contains('promptFile')));
      expect(canonical.indexOf('"attempts"'), lessThan(canonical.indexOf('"maxAttempts"')));
      expect(canonical.indexOf('"maxAttempts"'), lessThan(canonical.indexOf('"model"')));
      expect(canonical.indexOf('"model"'), lessThan(canonical.indexOf('"status"')));

      final json = envelope.toJson();
      expect(json['signature'], isNotEmpty);
      expect(json['sourceDeviceId'], 'device-a');
      expect(json['sourceSequence'], 11);
      expect(json['authorization'], <String, Object?>{
        'kind': 'pairedDevice',
        'deviceId': 'device-a',
      });
    });

    test('round trips through json and keeps signature payload stable', () async {
      final record = MainChatTimelineRecord.fromTimelineEvent(
        MainChatTimelineEvent(
          id: 'local-think:device-a:task-1:completed',
          type: MainChatTimelineEventType.localThinkCompleted,
          title: 'Background work completed',
          body: 'Detailed result from the local run.',
          timestamp: DateTime.utc(2026, 5, 2, 12, 3),
          sourceId: 'task-1',
          metadata: const <String, Object?>{
            'attempts': 1,
            'maxAttempts': 1,
          },
        ),
        sourceDeviceId: 'device-a',
        sourceSequence: 8,
        revision: 1,
        scope: MainChatTimelineScope.global,
        sourceKind: MainChatTimelineSourceKind.localThink,
      );

      final envelope = await MainChatTimelineSyncEnvelope.buildFromRecords(
        sourceDeviceId: 'device-a',
        sourceSequence: 12,
        authorization: MainChatTimelineSyncAuthorization.pairedDevice(
          deviceId: 'device-a',
        ),
        records: <MainChatTimelineRecord>[record],
        signer: FakeSyncSigner(),
        createdAtUtc: DateTime.utc(2026, 5, 2, 12, 31),
      );

      final decoded = MainChatTimelineSyncEnvelope.fromJson(envelope.toJson());

      expect(decoded.sourceDeviceId, envelope.sourceDeviceId);
      expect(decoded.sourceSequence, envelope.sourceSequence);
      expect(decoded.authorization.kind, MainChatTimelineSyncAuthorizationKind.pairedDevice);
      expect(decoded.records.single.recordId, envelope.records.single.recordId);
      expect(decoded.canonicalPayloadJson(), envelope.canonicalPayloadJson());
      expect(decoded.canonicalJson(), envelope.canonicalJson());
    });

    test('rejects envelopes that omit transport authorization', () {
      expect(
        () => MainChatTimelineSyncEnvelope.fromJson(<String, Object?>{
          'envelopeVersion': MainChatTimelineSyncEnvelope.currentEnvelopeVersion,
          'sourceDeviceId': 'device-a',
          'sourceSequence': 1,
          'createdAtUtc': '2026-05-02T12:31:00.000Z',
          'records': const <Object?>[],
          'signature': 'sig',
        }),
        throwsA(isA<MainChatTimelineSyncException>().having(
          (exception) => exception.message,
          'message',
          contains('transport authorization is required'),
        )),
      );
    });

    test('rejects envelopes that declare user JWT transport authorization', () {
      expect(
        () => MainChatTimelineSyncEnvelope.fromJson(<String, Object?>{
          'envelopeVersion': MainChatTimelineSyncEnvelope.currentEnvelopeVersion,
          'sourceDeviceId': 'device-a',
          'sourceSequence': 1,
          'createdAtUtc': '2026-05-02T12:31:00.000Z',
          'authorization': <String, Object?>{'kind': 'userJwt'},
          'records': const <Object?>[],
          'signature': 'sig',
        }),
        throwsA(isA<MainChatTimelineSyncException>().having(
          (exception) => exception.message,
          'message',
          contains('ordinary user JWT cannot authorize sync'),
        )),
      );
    });

    test('rejects paired-device envelopes when sender auth is not paired-device', () async {
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
        MainChatTimelineSyncEnvelope.buildFromRecords(
          sourceDeviceId: 'device-a',
          sourceSequence: 2,
          authorization: MainChatTimelineSyncAuthorization.userJwt(),
          records: <MainChatTimelineRecord>[record],
          signer: FakeSyncSigner(),
          createdAtUtc: DateTime.utc(2026, 5, 2, 12, 30),
        ),
        throwsA(isA<MainChatTimelineSyncException>().having(
          (exception) => exception.message,
          'message',
          contains('paired device sync requires paired-device authorization'),
        )),
      );
    });

    test('rejects batches that claim another sourceDeviceId', () async {
      final record = MainChatTimelineRecord.fromTimelineEvent(
        MainChatTimelineEvent(
          id: 'chat:conversation-1:user-1',
          type: MainChatTimelineEventType.chatUser,
          title: 'User',
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
        MainChatTimelineSyncEnvelope.buildFromRecords(
          sourceDeviceId: 'device-b',
          sourceSequence: 1,
          authorization: MainChatTimelineSyncAuthorization.pairedDevice(
            deviceId: 'device-b',
          ),
          records: <MainChatTimelineRecord>[record],
          signer: FakeSyncSigner(),
          createdAtUtc: DateTime.utc(2026, 5, 2, 12),
        ),
        throwsA(isA<MainChatTimelineSyncException>()),
      );
    });
  });
}
