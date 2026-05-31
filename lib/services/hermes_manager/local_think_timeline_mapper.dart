import 'package:cloudtolocalllm/models/local_think_job.dart';
import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';

class LocalThinkTimelineMapper {
  const LocalThinkTimelineMapper._();

  static MainChatTimelineEvent mapJob(LocalThinkJob job) {
    return MainChatTimelineEvent(
      id: 'local-think:${job.taskId}:${job.status.name}',
      type: _eventTypeForStatus(job.status),
      title: _titleForStatus(job.status),
      summary: _summaryForJob(job),
      timestamp: _timestampForJob(job),
      sourceId: job.taskId,
      artifactPath: _artifactPathForJob(job),
      metadata: _metadataForJob(job),
    );
  }

  static MainChatTimelineEventType _eventTypeForStatus(
    LocalThinkJobStatus status,
  ) {
    return switch (status) {
      LocalThinkJobStatus.queued => MainChatTimelineEventType.localThinkQueued,
      LocalThinkJobStatus.running =>
        MainChatTimelineEventType.localThinkRunning,
      LocalThinkJobStatus.completed =>
        MainChatTimelineEventType.localThinkCompleted,
      LocalThinkJobStatus.failed => MainChatTimelineEventType.localThinkFailed,
      LocalThinkJobStatus.cancelled =>
        MainChatTimelineEventType.localThinkCancelled,
      LocalThinkJobStatus.skipped =>
        MainChatTimelineEventType.localThinkSkipped,
      LocalThinkJobStatus.unknown =>
        MainChatTimelineEventType.localThinkSkipped,
    };
  }

  static String _titleForStatus(LocalThinkJobStatus status) {
    return switch (status) {
      LocalThinkJobStatus.queued => 'Queued background work',
      LocalThinkJobStatus.running => 'Running background work',
      LocalThinkJobStatus.completed => 'Background work completed',
      LocalThinkJobStatus.failed => 'Background work failed',
      LocalThinkJobStatus.cancelled => 'Background work cancelled',
      LocalThinkJobStatus.skipped => 'Background work skipped',
      LocalThinkJobStatus.unknown => 'Background work skipped',
    };
  }

  static String _summaryForJob(LocalThinkJob job) {
    if (_isSilentJob(job)) {
      return localThinkSilentPreviewSummary;
    }
    final finalPreview = job.finalPreview?.trim();
    if (finalPreview != null && finalPreview.isNotEmpty) {
      return finalPreview;
    }
    return job.name;
  }

  static Map<String, Object?> _metadataForJob(LocalThinkJob job) {
    return <String, Object?>{
      'attempts': job.attempts,
      'maxAttempts': job.maxAttempts,
      if (job.dedupKey != null) 'dedupKey': job.dedupKey,
      if (job.notify != null) 'notify': job.notify,
      if (job.wakeGate != null) 'wakeGate': job.wakeGate,
      if (job.parentTaskId != null) 'parentTaskId': job.parentTaskId,
      if (job.contextFrom != null) 'contextFrom': job.contextFrom,
      if (job.exitCode != null) 'exitCode': job.exitCode,
      if (job.finalFile != null) 'finalFile': job.finalFile,
      if (job.logFile != null) 'logFile': job.logFile,
      if (job.outputFile != null) 'outputFile': job.outputFile,
      if (job.metaFile != null) 'metaFile': job.metaFile,
      if (_isSilentJob(job)) 'isSilent': true,
    };
  }

  static String? _artifactPathForJob(LocalThinkJob job) {
    return job.finalFile ?? job.logFile ?? job.outputFile;
  }

  static DateTime? _timestampForJob(LocalThinkJob job) {
    return job.finishedAt ??
        job.startedAt ??
        job.createdAt ??
        _updatedAtTimestamp(job.updatedAt);
  }

  static DateTime? _updatedAtTimestamp(double? updatedAt) {
    if (updatedAt == null || !updatedAt.isFinite) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      (updatedAt * Duration.millisecondsPerSecond).round(),
      isUtc: true,
    );
  }

  static bool _looksSilent(String? value) {
    if (value == null) {
      return false;
    }
    final trimmed = value.trim();
    return trimmed == localThinkSilentPreviewSummary ||
        trimmed.startsWith('[SILENT]');
  }

  static bool _isSilentJob(LocalThinkJob job) {
    return job.isSilent || _looksSilent(job.finalPreview);
  }
}
