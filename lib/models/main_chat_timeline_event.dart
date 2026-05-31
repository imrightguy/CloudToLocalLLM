enum MainChatTimelineEventType {
  chatUser,
  chatAssistant,
  chatSystem,
  localThinkQueued,
  localThinkRunning,
  localThinkCompleted,
  localThinkCancelled,
  localThinkFailed,
  localThinkSkipped,
  toolStarted,
  toolFinished,
  restartRecovered,
  artifactCreated,
}

class MainChatTimelineEvent {
  final String id;
  final MainChatTimelineEventType type;
  final DateTime? timestamp;
  final String title;
  final String? summary;
  final String? body;
  final String? sourceId;
  final String? artifactPath;
  final bool isVerbose;
  final bool isExpandable;
  final Map<String, Object?> metadata;

  const MainChatTimelineEvent({
    required this.id,
    required this.type,
    required this.title,
    this.timestamp,
    this.summary,
    this.body,
    this.sourceId,
    this.artifactPath,
    this.isVerbose = false,
    this.isExpandable = false,
    this.metadata = const <String, Object?>{},
  });
}
