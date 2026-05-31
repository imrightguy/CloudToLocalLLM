import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';

class MainChatTimelineVisibility {
  static List<MainChatTimelineEvent> filter(
    List<MainChatTimelineEvent> events, {
    required bool showVerbose,
  }) {
    if (showVerbose) {
      return events;
    }

    return events.where(_isCompactVisible).toList(growable: false);
  }

  static bool _isCompactVisible(MainChatTimelineEvent event) {
    if (_isChatEvent(event)) {
      return true;
    }
    if (event.isVerbose) {
      return false;
    }
    return !_isToolEvent(event);
  }

  static bool _isChatEvent(MainChatTimelineEvent event) {
    return switch (event.type) {
      MainChatTimelineEventType.chatUser ||
      MainChatTimelineEventType.chatAssistant ||
      MainChatTimelineEventType.chatSystem =>
        true,
      _ => false,
    };
  }

  static bool _isToolEvent(MainChatTimelineEvent event) {
    return switch (event.type) {
      MainChatTimelineEventType.toolStarted ||
      MainChatTimelineEventType.toolFinished =>
        true,
      _ => false,
    };
  }
}
