import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_event_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MainChatEventLog', () {
    test('appends and lists mixed event types oldest-first by default', () {
      final log = MainChatEventLog();
      final userEvent = _event(
        id: 'chat:conversation-1:user-1',
        type: MainChatTimelineEventType.chatUser,
        timestamp: DateTime.utc(2026, 5, 2, 10),
      );
      final jobEvent = _event(
        id: 'local-think:job-1:completed',
        type: MainChatTimelineEventType.localThinkCompleted,
        timestamp: DateTime.utc(2026, 5, 2, 10, 1),
      );

      log.appendAll(<MainChatTimelineEvent>[jobEvent, userEvent]);

      expect(log.list(), <MainChatTimelineEvent>[userEvent, jobEvent]);
      expect(log.list(newestFirst: true), <MainChatTimelineEvent>[
        jobEvent,
        userEvent,
      ]);
      expect(log.getById('chat:conversation-1:user-1'), userEvent);
    });

    test('deduplicates by id and keeps older existing events', () {
      final log = MainChatEventLog();
      final original = _event(
        id: 'local-think:job-1:running',
        type: MainChatTimelineEventType.localThinkRunning,
        title: 'Running',
        timestamp: DateTime.utc(2026, 5, 2, 10, 2),
      );
      final older = _event(
        id: 'local-think:job-1:running',
        type: MainChatTimelineEventType.localThinkRunning,
        title: 'Older running',
        timestamp: DateTime.utc(2026, 5, 2, 10, 1),
      );

      log.append(original);
      log.append(older);

      expect(log.list(), <MainChatTimelineEvent>[original]);
      expect(log.getById(original.id)?.title, 'Running');
    });

    test('replaces same id with newer or equal timestamp', () {
      final log = MainChatEventLog();
      final original = _event(
        id: 'local-think:job-1:running',
        type: MainChatTimelineEventType.localThinkRunning,
        title: 'Running',
        timestamp: DateTime.utc(2026, 5, 2, 10, 1),
      );
      final newer = _event(
        id: 'local-think:job-1:running',
        type: MainChatTimelineEventType.localThinkRunning,
        title: 'Still running',
        timestamp: DateTime.utc(2026, 5, 2, 10, 2),
      );
      final equalTimestamp = _event(
        id: 'local-think:job-1:running',
        type: MainChatTimelineEventType.localThinkRunning,
        title: 'Running with details',
        timestamp: DateTime.utc(2026, 5, 2, 10, 2),
      );

      log.append(original);
      log.append(newer);
      log.append(equalTimestamp);

      expect(log.list(), <MainChatTimelineEvent>[equalTimestamp]);
      expect(log.getById(original.id)?.title, 'Running with details');
    });

    test('replaces null timestamp events and keeps stable id ordering', () {
      final log = MainChatEventLog();
      final noTimestamp = _event(
        id: 'b',
        type: MainChatTimelineEventType.localThinkQueued,
        title: 'Queued',
      );
      final noTimestampReplacement = _event(
        id: 'b',
        type: MainChatTimelineEventType.localThinkQueued,
        title: 'Queued replacement',
      );
      final sameTimeA = _event(
        id: 'a',
        type: MainChatTimelineEventType.chatSystem,
        timestamp: DateTime.utc(2026, 5, 2, 10),
      );
      final sameTimeC = _event(
        id: 'c',
        type: MainChatTimelineEventType.localThinkCompleted,
        timestamp: DateTime.utc(2026, 5, 2, 10),
      );

      log.appendAll(<MainChatTimelineEvent>[
        sameTimeC,
        noTimestamp,
        sameTimeA,
        noTimestampReplacement,
      ]);

      expect(
        log.list().map((event) => event.id),
        <String>['b', 'a', 'c'],
      );
      expect(log.getById('b')?.title, 'Queued replacement');

      log.clear();

      expect(log.list(), isEmpty);
      expect(log.getById('b'), isNull);
    });
  });
}

MainChatTimelineEvent _event({
  required String id,
  required MainChatTimelineEventType type,
  DateTime? timestamp,
  String title = 'Event',
}) {
  return MainChatTimelineEvent(
    id: id,
    type: type,
    title: title,
    timestamp: timestamp,
  );
}
