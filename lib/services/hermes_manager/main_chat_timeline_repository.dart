import 'package:cloudtolocalllm/database/drift_local_brain.dart';
import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';

import 'main_chat_timeline_record.dart';

class MainChatTimelineRepository {
  final LocalBrain _database;
  final String sourceDeviceId;

  MainChatTimelineRepository({
    LocalBrain? database,
    this.sourceDeviceId = 'local-device',
  }) : _database = database ?? LocalBrain();

  Future<List<MainChatTimelineRecord>> loadRecords({String? conversationId}) {
    return _database.loadMainChatTimelineRecords(conversationId: conversationId);
  }

  Future<List<MainChatTimelineEvent>> loadTimelineEvents({
    String? conversationId,
  }) async {
    final records = await loadRecords(conversationId: conversationId);
    final materialized = records.toList(growable: false)
      ..sort(_compareRecords);
    return materialized
        .map((record) => record.toTimelineEvent())
        .toList(growable: false);
  }

  Future<void> appendTimelineEvents(
    Iterable<MainChatTimelineEvent> events, {
    String? conversationId,
  }) {
    return _database.appendMainChatTimelineEvents(
      events,
      sourceDeviceId: sourceDeviceId,
      conversationId: conversationId,
    );
  }

  Future<void> clear() {
    return _database.clearMainChatTimelineRecords();
  }

  int _compareRecords(
    MainChatTimelineRecord left,
    MainChatTimelineRecord right,
  ) {
    final leftTimestamp = left.timestampUtc;
    final rightTimestamp = right.timestampUtc;
    final timestampComparison = leftTimestamp.compareTo(rightTimestamp);
    if (timestampComparison != 0) {
      return timestampComparison;
    }
    final sequenceComparison = left.sourceSequence.compareTo(right.sourceSequence);
    if (sequenceComparison != 0) {
      return sequenceComparison;
    }
    return left.recordId.compareTo(right.recordId);
  }
}
