import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MainChatTimelineRecord', () {
    test('serializes safe fields and keeps local-only fields out of sync json', () {
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
            'password': 'secret',
            'promptFile': '/tmp/work/prompt.md',
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

      expect(record.recordId, 'device-a:chat:conversation-1:user-1:1');
      expect(record.eventId, 'chat:conversation-1:user-1');
      expect(record.summary, isNull);
      expect(
        record.bodyRedacted,
        'Token token=[REDACTED] and password=[REDACTED]',
      );
      expect(record.artifactName, 'job.final.md');
      expect(record.localArtifactPath, '/tmp/work/job.final.md');
      expect(record.safeMetadata, <String, Object?>{
        'status': 'sent',
        'model': 'gpt-5',
        'attempts': 2,
        'maxAttempts': 4,
      });

      final syncJson = record.toSyncJson();
      expect(syncJson['artifactName'], 'job.final.md');
      expect(syncJson['bodyRedacted'], 'Token token=[REDACTED] and password=[REDACTED]');
      expect(syncJson.containsKey('localArtifactPath'), isFalse);
      expect(syncJson.containsKey('promptFile'), isFalse);
      expect(syncJson.containsKey('token'), isFalse);
    });

    test('round trips into the UI model without promoting body-only details', () {
      final original = MainChatTimelineRecord.fromTimelineEvent(
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

      final roundTrip = original.toTimelineEvent();

      expect(roundTrip.id, original.eventId);
      expect(roundTrip.title, 'Background work completed');
      expect(roundTrip.summary, isNull);
      expect(roundTrip.body, 'Detailed result from the local run.');
      expect(roundTrip.isVerbose, isTrue);
      expect(roundTrip.sourceId, 'task-1');
    });

    test('round trips through local json', () {
      final original = MainChatTimelineRecord.fromTimelineEvent(
        MainChatTimelineEvent(
          id: 'artifact:source-1:job.final.md',
          type: MainChatTimelineEventType.artifactCreated,
          title: 'Artifact created',
          summary: 'Preview ready.',
          body: 'Preview ready.',
          timestamp: DateTime.utc(2026, 5, 2, 12, 5),
          sourceId: 'source-1',
          artifactPath: '/tmp/work/job.final.md',
          metadata: const <String, Object?>{
            'status': 'ready',
            'contextFrom': 'conversation-1',
          },
        ),
        sourceDeviceId: 'device-a',
        sourceSequence: 9,
        revision: 1,
        scope: MainChatTimelineScope.conversation,
        conversationId: 'conversation-1',
        sourceKind: MainChatTimelineSourceKind.artifact,
      );

      final decoded = MainChatTimelineRecord.fromJson(original.toLocalJson());

      expect(decoded.recordId, original.recordId);
      expect(decoded.eventId, original.eventId);
      expect(decoded.scope, MainChatTimelineScope.conversation);
      expect(decoded.conversationId, 'conversation-1');
      expect(decoded.artifactName, 'job.final.md');
      expect(decoded.localArtifactPath, '/tmp/work/job.final.md');
      expect(decoded.safeMetadata, original.safeMetadata);
      expect(decoded.localOnlyMetadata, original.localOnlyMetadata);
    });
  });

}
