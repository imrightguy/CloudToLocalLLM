import 'package:cloudtolocalllm/models/local_think_job.dart';
import 'package:flutter/foundation.dart';

import 'local_think_artifact_preview_service.dart';
import 'local_think_ledger_process_stub.dart'
    if (dart.library.io) 'local_think_ledger_process_io.dart';

typedef LocalThinkLedgerReader = Future<String> Function();
typedef LocalThinkLedgerDetailReader = Future<String> Function(
  String taskIdPrefix,
);

class LocalThinkJobService {
  final LocalThinkLedgerReader _ledgerReader;
  final LocalThinkLedgerDetailReader _detailReader;
  final LocalThinkArtifactPreviewService _artifactPreviewService;
  final bool _isWeb;
  final bool _enrichDetails;
  final bool _enrichFinalPreview;
  final int _enrichLimit;

  LocalThinkJobService({
    LocalThinkLedgerReader? ledgerReader,
    LocalThinkLedgerDetailReader? detailReader,
    LocalThinkArtifactPreviewService? artifactPreviewService,
    bool isWeb = kIsWeb,
    bool enrichDetails = false,
    bool enrichFinalPreview = true,
    int enrichLimit = 5,
  })  : _ledgerReader = ledgerReader ?? readLocalThinkLedgerFromProcess,
        _detailReader = detailReader ?? readLocalThinkLedgerDetailFromProcess,
        _artifactPreviewService =
            artifactPreviewService ?? LocalThinkArtifactPreviewService(),
        _isWeb = isWeb,
        _enrichDetails = enrichDetails,
        _enrichFinalPreview = enrichFinalPreview,
        _enrichLimit = enrichLimit;

  bool get isSupported => !_isWeb;

  Future<List<LocalThinkJob>> listJobs() async {
    if (!isSupported) {
      return const <LocalThinkJob>[];
    }

    final ledgerJson = await _ledgerReader();
    final jobs = LocalThinkJob.listFromJsonString(ledgerJson);
    if (!_enrichDetails || _enrichLimit <= 0) {
      return jobs;
    }

    return _enrichJobs(jobs);
  }

  Future<List<LocalThinkJob>> _enrichJobs(List<LocalThinkJob> jobs) async {
    final targetJobs = jobs.where(_isTerminalJob).toList(growable: false)
      ..sort(_compareMostRecentFirst);
    final enrichedJobsById = <String, LocalThinkJob>{};

    for (final job in targetJobs.take(_enrichLimit)) {
      try {
        final detailJson = await _detailReader(job.taskId);
        final detailMap = LocalThinkJob.detailMapFromJsonString(detailJson);
        final detailJob = job.mergeWithJson(
          <String, Object?>{
            ...detailMap,
            'task_id': job.taskId,
          },
        );
        enrichedJobsById[job.taskId] =
            await _enrichFinalPreviewForJob(detailJob);
      } catch (_) {
        continue;
      }
    }

    return <LocalThinkJob>[
      for (final job in jobs) enrichedJobsById[job.taskId] ?? job,
    ];
  }

  Future<LocalThinkJob> _enrichFinalPreviewForJob(LocalThinkJob job) async {
    if (!_enrichFinalPreview || !_isTerminalJob(job)) {
      return job;
    }
    if (job.finalFile == null || job.finalFile!.trim().isEmpty) {
      return job;
    }
    if (job.finalPreview != null && job.finalPreview!.trim().isNotEmpty) {
      return job;
    }

    final preview = await _artifactPreviewService.previewFinalFile(
      job.finalFile,
    );
    if (preview == null || preview.trim().isEmpty) {
      return job;
    }
    return job.copyWith(finalPreview: preview);
  }

  bool _isTerminalJob(LocalThinkJob job) {
    return switch (job.status) {
      LocalThinkJobStatus.completed ||
      LocalThinkJobStatus.failed ||
      LocalThinkJobStatus.cancelled ||
      LocalThinkJobStatus.skipped =>
        true,
      LocalThinkJobStatus.queued ||
      LocalThinkJobStatus.running ||
      LocalThinkJobStatus.unknown =>
        false,
    };
  }

  int _compareMostRecentFirst(LocalThinkJob left, LocalThinkJob right) {
    final leftTimestamp = _jobTimestamp(left);
    final rightTimestamp = _jobTimestamp(right);
    if (leftTimestamp == null && rightTimestamp == null) {
      return left.taskId.compareTo(right.taskId);
    }
    if (leftTimestamp == null) {
      return 1;
    }
    if (rightTimestamp == null) {
      return -1;
    }
    final timestampComparison = rightTimestamp.compareTo(leftTimestamp);
    if (timestampComparison != 0) {
      return timestampComparison;
    }
    return left.taskId.compareTo(right.taskId);
  }

  DateTime? _jobTimestamp(LocalThinkJob job) {
    return job.finishedAt ??
        job.startedAt ??
        job.createdAt ??
        _updatedAtTimestamp(job.updatedAt);
  }

  DateTime? _updatedAtTimestamp(double? updatedAt) {
    if (updatedAt == null || !updatedAt.isFinite) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      (updatedAt * Duration.millisecondsPerSecond).round(),
      isUtc: true,
    );
  }
}
