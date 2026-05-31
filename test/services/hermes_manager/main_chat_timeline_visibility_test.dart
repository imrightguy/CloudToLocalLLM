import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/services/hermes_manager/main_chat_timeline_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MainChatTimelineVisibility', () {
    test('compact mode hides verbose and tool timeline rows', () {
      final compactEvent = _event(
        id: 'local-think:job-1:completed',
        type: MainChatTimelineEventType.localThinkCompleted,
      );
      final verboseEvent = _event(
        id: 'local-think:job-1:details',
        type: MainChatTimelineEventType.artifactCreated,
        isVerbose: true,
      );
      final toolEvent = _event(
        id: 'tool:job-1:started',
        type: MainChatTimelineEventType.toolStarted,
      );
      final chatEvent = _event(
        id: 'chat:user-1',
        type: MainChatTimelineEventType.chatUser,
        isVerbose: true,
      );

      final visible = MainChatTimelineVisibility.filter(
        <MainChatTimelineEvent>[
          compactEvent,
          verboseEvent,
          toolEvent,
          chatEvent,
        ],
        showVerbose: false,
      );

      expect(visible, <MainChatTimelineEvent>[compactEvent, chatEvent]);
    });

    test('verbose mode keeps compact, verbose, and tool timeline rows', () {
      final compactEvent = _event(
        id: 'local-think:job-1:completed',
        type: MainChatTimelineEventType.localThinkCompleted,
      );
      final verboseEvent = _event(
        id: 'local-think:job-1:details',
        type: MainChatTimelineEventType.artifactCreated,
        isVerbose: true,
      );
      final toolEvent = _event(
        id: 'tool:job-1:finished',
        type: MainChatTimelineEventType.toolFinished,
      );

      final visible = MainChatTimelineVisibility.filter(
        <MainChatTimelineEvent>[compactEvent, verboseEvent, toolEvent],
        showVerbose: true,
      );

      expect(
        visible,
        <MainChatTimelineEvent>[compactEvent, verboseEvent, toolEvent],
      );
    });
  });
}

MainChatTimelineEvent _event({
  required String id,
  required MainChatTimelineEventType type,
  bool isVerbose = false,
}) {
  return MainChatTimelineEvent(
    id: id,
    type: type,
    title: id,
    isVerbose: isVerbose,
  );
}
