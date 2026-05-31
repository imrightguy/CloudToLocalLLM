import 'dart:io';

import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_record.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MainChatTimelineRepository', () {
    late Directory tempDir;
    late LocalBrain database;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('main-chat-timeline-repo-test-');
      database = LocalBrain.withExecutor(
        NativeDatabase(File('${tempDir.path}/brain.sqlite')),
      );
    });

    tearDown(() async {
      await database.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('persists scoped records across repository instances', () async {
      final firstRepository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      final chatEvent = MainChatTimelineEvent(
        id: 'chat:conversation-1:user-1',
        type: MainChatTimelineEventType.chatUser,
        title: 'User',
        body: 'Hello there',
        timestamp: DateTime.utc(2026, 5, 2, 12),
        sourceId: 'user-1',
      );
      final globalEvent = MainChatTimelineEvent(
        id: 'local-think:device-a:task-1:completed',
        type: MainChatTimelineEventType.localThinkCompleted,
        title: 'Background work completed',
        summary: 'A safe preview',
        timestamp: DateTime.utc(2026, 5, 2, 12, 1),
        sourceId: 'task-1',
        metadata: const <String, Object?>{
          'attempts': 1,
          'maxAttempts': 2,
        },
      );

      await firstRepository.appendTimelineEvents(
        <MainChatTimelineEvent>[chatEvent, globalEvent],
        conversationId: 'conversation-1',
      );

      final secondRepository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      final conversationEvents = await secondRepository.loadTimelineEvents(
        conversationId: 'conversation-1',
      );
      final otherConversationEvents = await secondRepository.loadTimelineEvents(
        conversationId: 'conversation-2',
      );

      expect(
        conversationEvents.map((event) => event.id),
        <String>[
          'chat:conversation-1:user-1',
          'local-think:device-a:task-1:completed',
        ],
      );
      expect(
        otherConversationEvents.map((event) => event.id),
        <String>['local-think:device-a:task-1:completed'],
      );
    });

    test('rehydrates persisted records after database restart', () async {
      final repository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      final event = MainChatTimelineEvent(
        id: 'chat:conversation-1:user-1',
        type: MainChatTimelineEventType.chatUser,
        title: 'User',
        body: 'Hello there',
        timestamp: DateTime.utc(2026, 5, 2, 12),
        sourceId: 'user-1',
      );

      await repository.appendTimelineEvents(
        <MainChatTimelineEvent>[event],
        conversationId: 'conversation-1',
      );

      await database.close();
      database = LocalBrain.withExecutor(
        NativeDatabase(File('${tempDir.path}/brain.sqlite')),
      );

      final reopenedRepository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      final hydratedEvents = await reopenedRepository.loadTimelineEvents(
        conversationId: 'conversation-1',
      );

      expect(hydratedEvents, hasLength(1));
      expect(hydratedEvents.single.id, 'chat:conversation-1:user-1');
      expect(hydratedEvents.single.body, 'Hello there');
    });

    test('null conversation loads only global and device records', () async {
      final repository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      final conversationEvent = MainChatTimelineEvent(
        id: 'chat:conversation-1:user-1',
        type: MainChatTimelineEventType.chatUser,
        title: 'User',
        body: 'Hello there',
        timestamp: DateTime.utc(2026, 5, 2, 12),
        sourceId: 'user-1',
      );
      final globalEvent = MainChatTimelineEvent(
        id: 'local-think:device-a:task-1:completed',
        type: MainChatTimelineEventType.localThinkCompleted,
        title: 'Background work completed',
        summary: 'A safe preview',
        timestamp: DateTime.utc(2026, 5, 2, 12, 1),
        sourceId: 'task-1',
      );
      final deviceEvent = MainChatTimelineEvent(
        id: 'runtime:device-a:runtime-1:recovered:2026-05-02T12:02:00.000Z',
        type: MainChatTimelineEventType.restartRecovered,
        title: 'Runtime recovered',
        summary: 'Recovered after restart',
        timestamp: DateTime.utc(2026, 5, 2, 12, 2),
        sourceId: 'runtime-1',
      );

      await repository.appendTimelineEvents(
        <MainChatTimelineEvent>[
          conversationEvent,
          globalEvent,
          deviceEvent,
        ],
        conversationId: 'conversation-1',
      );

      final noConversationRecords = await repository.loadRecords();
      final noConversationEvents = await repository.loadTimelineEvents();

      expect(
        noConversationRecords.map((record) => record.scope),
        <MainChatTimelineScope>[
          MainChatTimelineScope.global,
          MainChatTimelineScope.device,
        ],
      );
      expect(
        noConversationEvents.map((event) => event.id),
        <String>[
          'local-think:device-a:task-1:completed',
          'runtime:device-a:runtime-1:recovered:2026-05-02T12:02:00.000Z',
        ],
      );
    });

    test('deduplicates records on repeated append', () async {
      final repository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      final event = MainChatTimelineEvent(
        id: 'chat:conversation-1:user-1',
        type: MainChatTimelineEventType.chatUser,
        title: 'User',
        body: 'Hello again',
        timestamp: DateTime.utc(2026, 5, 2, 12),
        sourceId: 'user-1',
      );

      await repository.appendTimelineEvents(
        <MainChatTimelineEvent>[event],
        conversationId: 'conversation-1',
      );
      await repository.appendTimelineEvents(
        <MainChatTimelineEvent>[event],
        conversationId: 'conversation-1',
      );

      final records = await repository.loadRecords(conversationId: 'conversation-1');
      expect(records, hasLength(1));
      expect(records.single.recordId, 'device-a:chat:conversation-1:user-1:1');
    });

    test('hydrates safe global events without mixing conversation-scoped chat',
        () async {
      final repository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      await repository.appendTimelineEvents(
        <MainChatTimelineEvent>[
          MainChatTimelineEvent(
            id: 'chat:conversation-1:user-1',
            type: MainChatTimelineEventType.chatUser,
            title: 'User',
            body: 'Hello from conversation 1',
            timestamp: DateTime.utc(2026, 5, 2, 12),
            sourceId: 'user-1',
          ),
        ],
        conversationId: 'conversation-1',
      );
      await repository.appendTimelineEvents(
        <MainChatTimelineEvent>[
          MainChatTimelineEvent(
            id: 'chat:conversation-2:user-2',
            type: MainChatTimelineEventType.chatAssistant,
            title: 'Assistant',
            body: 'Hello from conversation 2',
            timestamp: DateTime.utc(2026, 5, 2, 12, 1),
            sourceId: 'user-2',
          ),
        ],
        conversationId: 'conversation-2',
      );
      await repository.appendTimelineEvents(
        <MainChatTimelineEvent>[
          MainChatTimelineEvent(
            id: 'local-think:device-a:task-1:completed',
            type: MainChatTimelineEventType.localThinkCompleted,
            title: 'Background work completed',
            summary: 'A safe preview',
            timestamp: DateTime.utc(2026, 5, 2, 12, 2),
            sourceId: 'task-1',
            metadata: const <String, Object?>{
              'attempts': 1,
              'maxAttempts': 2,
            },
          ),
        ],
      );

      await database.close();
      database = LocalBrain.withExecutor(
        NativeDatabase(File('${tempDir.path}/brain.sqlite')),
      );

      final reopenedRepository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      final cockpitEvents = await reopenedRepository.loadTimelineEvents();
      final conversationOneEvents = await reopenedRepository.loadTimelineEvents(
        conversationId: 'conversation-1',
      );
      final conversationTwoEvents = await reopenedRepository.loadTimelineEvents(
        conversationId: 'conversation-2',
      );

      expect(cockpitEvents, hasLength(1));
      expect(cockpitEvents.single.id, 'local-think:device-a:task-1:completed');
      expect(cockpitEvents.single.summary, 'A safe preview');
      expect(cockpitEvents.single.metadata, <String, Object?>{
        'attempts': 1,
        'maxAttempts': 2,
      });

      expect(
        conversationOneEvents.map((event) => event.id),
        <String>[
          'chat:conversation-1:user-1',
          'local-think:device-a:task-1:completed',
        ],
      );
      expect(
        conversationTwoEvents.map((event) => event.id),
        <String>[
          'chat:conversation-2:user-2',
          'local-think:device-a:task-1:completed',
        ],
      );
    });

    test('keeps silent events quiet after hydration', () async {
      final repository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      await repository.appendTimelineEvents(
        <MainChatTimelineEvent>[
          MainChatTimelineEvent(
            id: 'local-think:device-a:task-quiet:completed',
            type: MainChatTimelineEventType.localThinkCompleted,
            title: 'Background work completed',
            summary: 'Silent wake-gate skip.',
            timestamp: DateTime.utc(2026, 5, 2, 12, 3),
            sourceId: 'task-quiet',
            metadata: const <String, Object?>{
              'attempts': 1,
              'maxAttempts': 1,
              'isSilent': true,
            },
          ),
        ],
        conversationId: 'conversation-quiet',
      );

      await database.close();
      database = LocalBrain.withExecutor(
        NativeDatabase(File('${tempDir.path}/brain.sqlite')),
      );

      final reopenedRepository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      final hydratedEvents = await reopenedRepository.loadTimelineEvents(
        conversationId: 'conversation-quiet',
      );

      expect(hydratedEvents, hasLength(1));
      expect(hydratedEvents.single.summary, 'Silent wake-gate skip.');
      expect(hydratedEvents.single.isVerbose, isFalse);
      expect(hydratedEvents.single.metadata, <String, Object?>{
        'attempts': 1,
        'maxAttempts': 1,
        'isSilent': true,
      });
    });

    test('drops raw metadata but keeps safe allowlisted fields after hydration',
        () async {
      final repository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      await repository.appendTimelineEvents(
        <MainChatTimelineEvent>[
          MainChatTimelineEvent(
            id: 'local-think:device-a:task-redacted:completed',
            type: MainChatTimelineEventType.localThinkCompleted,
            title: 'Background work completed',
            body:
                'Detailed result with token=abc123 and password=secret still redacted.',
            summary: 'Safe preview.',
            timestamp: DateTime.utc(2026, 5, 2, 12, 4),
            sourceId: 'task-redacted',
            metadata: const <String, Object?>{
              'attempts': 2,
              'maxAttempts': 4,
              'status': 'sent',
              'token': 'abc123',
              'password': 'secret',
              'rawLog': 'secret-bearing raw log',
              'promptFile': '/tmp/work/prompt.md',
              'outputFile': '/tmp/work/output.md',
              'logFile': '/tmp/work/run.log',
              'metaFile': '/tmp/work/meta.json',
              'runnerFile': '/tmp/work/runner.sh',
            },
          ),
        ],
        conversationId: 'conversation-redacted',
      );

      await database.close();
      database = LocalBrain.withExecutor(
        NativeDatabase(File('${tempDir.path}/brain.sqlite')),
      );

      final reopenedRepository = MainChatTimelineRepository(
        database: database,
        sourceDeviceId: 'device-a',
      );
      final hydratedEvents = await reopenedRepository.loadTimelineEvents(
        conversationId: 'conversation-redacted',
      );

      expect(hydratedEvents, hasLength(1));
      expect(hydratedEvents.single.body, contains('[REDACTED]'));
      expect(hydratedEvents.single.body, isNot(contains('abc123')));
      expect(hydratedEvents.single.body, isNot(contains('secret')));
      expect(hydratedEvents.single.metadata, <String, Object?>{
        'attempts': 2,
        'maxAttempts': 4,
        'status': 'sent',
      });
      expect(hydratedEvents.single.metadata.containsKey('token'), isFalse);
      expect(hydratedEvents.single.metadata.containsKey('password'), isFalse);
      expect(hydratedEvents.single.metadata.containsKey('rawLog'), isFalse);
      expect(hydratedEvents.single.metadata.containsKey('promptFile'), isFalse);
      expect(hydratedEvents.single.metadata.containsKey('outputFile'), isFalse);
      expect(hydratedEvents.single.metadata.containsKey('logFile'), isFalse);
      expect(hydratedEvents.single.metadata.containsKey('metaFile'), isFalse);
      expect(hydratedEvents.single.metadata.containsKey('runnerFile'), isFalse);
    });
  });
}
