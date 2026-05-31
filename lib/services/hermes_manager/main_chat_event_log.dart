import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';

class MainChatEventLog {
  final Map<String, MainChatTimelineEvent> _eventsById =
      <String, MainChatTimelineEvent>{};

  void append(MainChatTimelineEvent event) {
    final existing = _eventsById[event.id];
    if (existing == null || _shouldReplace(existing, event)) {
      _eventsById[event.id] = event;
    }
  }

  void appendAll(Iterable<MainChatTimelineEvent> events) {
    for (final event in events) {
      append(event);
    }
  }

  List<MainChatTimelineEvent> list({bool newestFirst = false}) {
    final events = _eventsById.values.toList(growable: false);
    events.sort(_compareEvents);
    if (newestFirst) {
      return events.reversed.toList(growable: false);
    }
    return events;
  }

  MainChatTimelineEvent? getById(String id) => _eventsById[id];

  void clear() => _eventsById.clear();

  bool _shouldReplace(
    MainChatTimelineEvent existing,
    MainChatTimelineEvent incoming,
  ) {
    final existingTimestamp = existing.timestamp;
    final incomingTimestamp = incoming.timestamp;
    if (existingTimestamp == null) {
      return true;
    }
    if (incomingTimestamp == null) {
      return false;
    }
    return !incomingTimestamp.isBefore(existingTimestamp);
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
