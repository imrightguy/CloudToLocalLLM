import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MainChatTimelineEvent', () {
    test('can construct user and assistant chat events', () {
      final userEvent = MainChatTimelineEvent(
        id: 'chat:user-1',
        type: MainChatTimelineEventType.chatUser,
        title: 'User',
        body: 'Can you summarize this?',
        timestamp: DateTime.utc(2026, 5, 2, 12),
        sourceId: 'user-1',
      );
      final assistantEvent = MainChatTimelineEvent(
        id: 'chat:assistant-1',
        type: MainChatTimelineEventType.chatAssistant,
        title: 'Assistant',
        body: 'Summary ready.',
        timestamp: DateTime.utc(2026, 5, 2, 12, 1),
        sourceId: 'assistant-1',
      );

      expect(userEvent.type, MainChatTimelineEventType.chatUser);
      expect(userEvent.body, 'Can you summarize this?');
      expect(assistantEvent.type, MainChatTimelineEventType.chatAssistant);
      expect(assistantEvent.title, 'Assistant');
    });

    test('can construct local-think activity events', () {
      final event = MainChatTimelineEvent(
        id: 'local-think:job-1:completed',
        type: MainChatTimelineEventType.localThinkCompleted,
        title: 'Background work completed',
        summary: 'Checked project state.',
        sourceId: 'job-1',
        metadata: const <String, Object?>{
          'attempts': 1,
          'maxAttempts': 2,
        },
      );

      expect(event.type, MainChatTimelineEventType.localThinkCompleted);
      expect(event.summary, 'Checked project state.');
      expect(event.sourceId, 'job-1');
      expect(event.metadata['attempts'], 1);
    });

    test('defaults metadata to an empty map', () {
      const event = MainChatTimelineEvent(
        id: 'local-think:job-1:queued',
        type: MainChatTimelineEventType.localThinkQueued,
        title: 'Queued background work',
      );

      expect(event.metadata, isEmpty);
      expect(event.isVerbose, isFalse);
      expect(event.isExpandable, isFalse);
    });
  });
}
