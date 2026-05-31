import 'package:cloudtolocalllm/models/chat_model.dart';
import 'package:cloudtolocalllm/models/local_think_job.dart';
import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';

import 'local_think_timeline_mapper.dart';

class MainChatTimelineComposer {
  List<MainChatTimelineEvent> compose({
    required Conversation? conversation,
    required List<LocalThinkJob> localThinkJobs,
  }) {
    final eventsById = <String, MainChatTimelineEvent>{};

    for (final message in conversation?.messages ?? const <Message>[]) {
      eventsById.putIfAbsent(
        'chat:${conversation?.id}:${message.id}',
        () => _eventFromMessage(conversation?.id, message),
      );
    }

    for (final job in localThinkJobs) {
      final event = LocalThinkTimelineMapper.mapJob(job);
      eventsById.putIfAbsent(event.id, () => event);
    }

    final events = eventsById.values.toList(growable: false);
    events.sort(_compareEvents);
    return events;
  }

  MainChatTimelineEvent _eventFromMessage(String? conversationId, Message message) {
    return MainChatTimelineEvent(
      id: 'chat:${conversationId ?? 'unknown'}:${message.id}',
      type: _typeForRole(message.role),
      title: _titleForRole(message.role),
      body: message.content,
      timestamp: message.timestamp,
      sourceId: message.id,
      metadata: <String, Object?>{
        'status': message.status.name,
        if (message.model != null) 'model': message.model,
      },
    );
  }

  MainChatTimelineEventType _typeForRole(MessageRole role) {
    return switch (role) {
      MessageRole.user => MainChatTimelineEventType.chatUser,
      MessageRole.assistant => MainChatTimelineEventType.chatAssistant,
      MessageRole.system => MainChatTimelineEventType.chatSystem,
    };
  }

  String _titleForRole(MessageRole role) {
    return switch (role) {
      MessageRole.user => 'User',
      MessageRole.assistant => 'Assistant',
      MessageRole.system => 'System',
    };
  }

  int _compareEvents(
    MainChatTimelineEvent left,
    MainChatTimelineEvent right,
  ) {
    final leftTimestamp =
        left.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTimestamp =
        right.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
    final timestampComparison = leftTimestamp.compareTo(rightTimestamp);
    if (timestampComparison != 0) {
      return timestampComparison;
    }
    return left.id.compareTo(right.id);
  }
}
