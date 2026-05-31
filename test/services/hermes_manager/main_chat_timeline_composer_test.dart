import 'package:cloudtolocalllm/models/chat_model.dart';
import 'package:cloudtolocalllm/models/local_think_job.dart';
import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MainChatTimelineComposer', () {
    test('empty conversation with jobs still shows local-think events', () {
      final composer = MainChatTimelineComposer();
      final job = LocalThinkJob(
        taskId: 'job-1',
        name: 'background-summary',
        status: LocalThinkJobStatus.queued,
        attempts: 0,
        maxAttempts: 2,
        createdAt: DateTime.utc(2026, 5, 2, 12),
      );

      final events = composer.compose(
        conversation: null,
        localThinkJobs: <LocalThinkJob>[job],
      );

      expect(events, hasLength(1));
      expect(events.single.id, 'local-think:job-1:queued');
      expect(events.single.type, MainChatTimelineEventType.localThinkQueued);
    });

    test('merges conversation messages and jobs oldest-first by timestamp', () {
      final composer = MainChatTimelineComposer();
      final conversation = _conversation(
        messages: <Message>[
          _message(
            id: 'user-1',
            role: MessageRole.user,
            content: 'Start the analysis',
            timestamp: DateTime.utc(2026, 5, 2, 12),
          ),
          _message(
            id: 'assistant-1',
            role: MessageRole.assistant,
            content: 'Analysis complete.',
            timestamp: DateTime.utc(2026, 5, 2, 12, 3),
          ),
        ],
      );
      final job = LocalThinkJob(
        taskId: 'job-1',
        name: 'background-analysis',
        status: LocalThinkJobStatus.completed,
        attempts: 1,
        maxAttempts: 1,
        finishedAt: DateTime.utc(2026, 5, 2, 12, 2),
        finalPreview: 'Background analysis ready.',
      );

      final events = composer.compose(
        conversation: conversation,
        localThinkJobs: <LocalThinkJob>[job],
      );

      expect(
        events.map((event) => event.id),
        <String>[
          'chat:conversation-1:user-1',
          'local-think:job-1:completed',
          'chat:conversation-1:assistant-1',
        ],
      );
    });

    test('uses stable chat ids and role event types', () {
      final composer = MainChatTimelineComposer();
      final conversation = _conversation(
        messages: <Message>[
          _message(
            id: 'system-1',
            role: MessageRole.system,
            content: 'System notice',
            timestamp: DateTime.utc(2026, 5, 2, 12),
          ),
        ],
      );

      final events = composer.compose(
        conversation: conversation,
        localThinkJobs: const <LocalThinkJob>[],
      );

      expect(events.single.id, 'chat:conversation-1:system-1');
      expect(events.single.type, MainChatTimelineEventType.chatSystem);
      expect(events.single.body, 'System notice');
      expect(events.single.sourceId, 'system-1');
    });

    test('deduplicates events by stable id', () {
      final composer = MainChatTimelineComposer();
      const job = LocalThinkJob(
        taskId: 'job-1',
        name: 'deduped-job',
        status: LocalThinkJobStatus.running,
        attempts: 1,
        maxAttempts: 2,
      );

      final events = composer.compose(
        conversation: null,
        localThinkJobs: const <LocalThinkJob>[job, job],
      );

      expect(events, hasLength(1));
      expect(events.single.id, 'local-think:job-1:running');
    });
  });
}

Conversation _conversation({required List<Message> messages}) {
  return Conversation(
    id: 'conversation-1',
    title: 'Conversation',
    messages: messages,
    createdAt: DateTime.utc(2026, 5, 2, 11),
    updatedAt: DateTime.utc(2026, 5, 2, 13),
  );
}

Message _message({
  required String id,
  required MessageRole role,
  required String content,
  required DateTime timestamp,
}) {
  return Message(
    id: id,
    content: content,
    role: role,
    timestamp: timestamp,
  );
}
