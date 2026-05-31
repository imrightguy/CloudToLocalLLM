import 'package:cloudtolocalllm/models/local_think_job.dart';
import 'package:cloudtolocalllm/services/hermes_manager/local_think_artifact_preview_service.dart';
import 'package:cloudtolocalllm/services/hermes_manager/local_think_job_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalThinkJob', () {
    test('parses hermes-local-think-ledger list JSON rows', () {
      const ledgerJson = '''
[
  {
    "task_id": "20260502_030547_cloudtolocalllm-thought-train-code-slice",
    "status": "queued",
    "exit_code": null,
    "attempts": 0,
    "max_attempts": 2,
    "dedup_key": "cloudtolocalllm-thought-train-code-slice",
    "name": "cloudtolocalllm-thought-train-code-slice",
    "created_at": "2026-05-02T07:05:47.745631+00:00",
    "finished_at": null,
    "parent_task_id": null
  },
  {
    "task_id": "20260502_022456_chain-child",
    "status": "completed",
    "exit_code": 0,
    "attempts": 1,
    "max_attempts": 1,
    "dedup_key": null,
    "name": "chain-child",
    "created_at": "2026-05-02T06:24:56.572522+00:00",
    "finished_at": "2026-05-02T06:25:03.276612+00:00",
    "parent_task_id": "20260502_022444_chain-base",
    "context_from": "20260502_022444_chain-base",
    "final_preview": "[SILENT] Finished smoke test"
  }
]
''';

      final jobs = LocalThinkJob.listFromJsonString(ledgerJson);

      expect(jobs, hasLength(2));
      expect(
        jobs.first.taskId,
        '20260502_030547_cloudtolocalllm-thought-train-code-slice',
      );
      expect(jobs.first.status, LocalThinkJobStatus.queued);
      expect(jobs.first.attempts, 0);
      expect(jobs.first.maxAttempts, 2);
      expect(
        jobs.first.dedupKey,
        'cloudtolocalllm-thought-train-code-slice',
      );
      expect(jobs.first.createdAt, isNotNull);
      expect(jobs.first.finishedAt, isNull);

      expect(jobs.last.status, LocalThinkJobStatus.completed);
      expect(jobs.last.exitCode, 0);
      expect(jobs.last.parentTaskId, '20260502_022444_chain-base');
      expect(jobs.last.contextFrom, '20260502_022444_chain-base');
      expect(jobs.last.isSilent, isTrue);
    });

    test('parses object wrapper with jobs list', () {
      const ledgerJson = '''
{
  "jobs": [
    {
      "task_id": "job-1",
      "status": "failed",
      "attempts": "2",
      "max_attempts": "3",
      "name": "failed-job"
    }
  ]
}
''';

      final jobs = LocalThinkJob.listFromJsonString(ledgerJson);

      expect(jobs.single.taskId, 'job-1');
      expect(jobs.single.name, 'failed-job');
      expect(jobs.single.status, LocalThinkJobStatus.failed);
      expect(jobs.single.attempts, 2);
      expect(jobs.single.maxAttempts, 3);
    });

    test('normalizes status casing and whitespace from ledger rows', () {
      const ledgerJson = '''
[
  {
    "task_id": "job-uppercase-completed",
    "status": " Completed ",
    "attempts": 1,
    "max_attempts": 1,
    "name": "upper-completed"
  },
  {
    "task_id": "job-us-canceled",
    "status": "CANCELED",
    "attempts": 1,
    "max_attempts": 1,
    "name": "us-canceled"
  }
]
''';

      final jobs = LocalThinkJob.listFromJsonString(ledgerJson);

      expect(jobs.first.status, LocalThinkJobStatus.completed);
      expect(jobs.last.status, LocalThinkJobStatus.cancelled);
    });

    test('throws for rows missing task id', () {
      expect(
        () => LocalThinkJob.listFromJsonString('[{"status":"queued"}]'),
        throwsFormatException,
      );
    });

    test('parses artifact path fields from snake and camel case JSON', () {
      const ledgerJson = '''
[
  {
    "task_id": "job-snake",
    "unit": "local-think@job-snake.service",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "dedup_key": "job-snake-key",
    "notify": "telegram",
    "wake_gate": "open",
    "name": "snake-artifacts",
    "updated_at": 1777716000.25,
    "final_file": "/tmp/job-snake/final.md",
    "log_file": "/tmp/job-snake/run.log",
    "output_file": "/tmp/job-snake/output.json",
    "meta_file": "/tmp/job-snake/meta.json",
    "runner_file": "/tmp/job-snake/runner.sh",
    "meta_json": "{\\"source\\":\\"ledger\\"}"
  },
  {
    "taskId": "job-camel",
    "status": "completed",
    "attempts": 1,
    "maxAttempts": 1,
    "name": "camel-artifacts",
    "updatedAt": "1777716001.5",
    "wakeGate": "busy",
    "finalFile": "/tmp/job-camel/final.md",
    "logFile": "/tmp/job-camel/run.log",
    "outputFile": "/tmp/job-camel/output.json",
    "metaFile": "/tmp/job-camel/meta.json",
    "runnerFile": "/tmp/job-camel/runner.sh",
    "metaJson": "{\\"source\\":\\"detail\\"}"
  }
]
''';

      final jobs = LocalThinkJob.listFromJsonString(ledgerJson);

      expect(jobs.first.unit, 'local-think@job-snake.service');
      expect(jobs.first.dedupKey, 'job-snake-key');
      expect(jobs.first.notify, 'telegram');
      expect(jobs.first.wakeGate, 'open');
      expect(jobs.first.updatedAt, 1777716000.25);
      expect(jobs.first.finalFile, '/tmp/job-snake/final.md');
      expect(jobs.first.logFile, '/tmp/job-snake/run.log');
      expect(jobs.first.outputFile, '/tmp/job-snake/output.json');
      expect(jobs.first.metaFile, '/tmp/job-snake/meta.json');
      expect(jobs.first.runnerFile, '/tmp/job-snake/runner.sh');
      expect(jobs.first.metaJson, '{"source":"ledger"}');
      expect(jobs.last.updatedAt, 1777716001.5);
      expect(jobs.last.wakeGate, 'busy');
      expect(jobs.last.finalFile, '/tmp/job-camel/final.md');
      expect(jobs.last.logFile, '/tmp/job-camel/run.log');
      expect(jobs.last.outputFile, '/tmp/job-camel/output.json');
      expect(jobs.last.metaFile, '/tmp/job-camel/meta.json');
      expect(jobs.last.runnerFile, '/tmp/job-camel/runner.sh');
      expect(jobs.last.metaJson, '{"source":"detail"}');
    });

    test('parses explicit silent flags from numeric and padded string values', () {
      const ledgerJson = '''
[
  {
    "task_id": "job-num-silent",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "numeric-silent",
    "is_silent": 1,
    "final_preview": "Visible summary should still stay quiet"
  },
  {
    "task_id": "job-string-not-silent",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "string-not-silent",
    "isSilent": "  no  ",
    "final_preview": "Visible summary"
  }
]
''';

      final jobs = LocalThinkJob.listFromJsonString(ledgerJson);

      expect(jobs.first.isSilent, isTrue);
      expect(jobs.last.isSilent, isFalse);
    });

    test('treats normalized silent summary text as quiet work', () {
      const ledgerJson = '''
[
  {
    "task_id": "job-normalized-silent",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "normalized-silent",
    "final_preview": "Silent wake-gate skip."
  }
]
''';

      final jobs = LocalThinkJob.listFromJsonString(ledgerJson);

      expect(jobs.single.isSilent, isTrue);
    });

    test('mergeWithJson preserves stable ledger task identity', () {
      const job = LocalThinkJob(
        taskId: 'ledger-task-id',
        name: 'ledger-name',
        status: LocalThinkJobStatus.completed,
        attempts: 1,
        maxAttempts: 1,
      );

      final merged = job.mergeWithJson(const <String, Object?>{
        'task_id': 'detail-task-id',
        'name': 'detail-name',
        'final_file': '/tmp/ledger-task-id/final.md',
      });

      expect(merged.taskId, 'ledger-task-id');
      expect(merged.name, 'detail-name');
      expect(merged.finalFile, '/tmp/ledger-task-id/final.md');
    });

    test('mergeWithJson keeps quiet-job state from explicit detail flags', () {
      const job = LocalThinkJob(
        taskId: 'ledger-task-id',
        name: 'ledger-name',
        status: LocalThinkJobStatus.completed,
        attempts: 1,
        maxAttempts: 1,
        isSilent: false,
      );

      final merged = job.mergeWithJson(const <String, Object?>{
        'isSilent': '  yes  ',
        'final_preview': 'Visible summary that should still stay quiet',
      });

      expect(merged.finalPreview, 'Visible summary that should still stay quiet');
      expect(merged.isSilent, isTrue);
    });
  });

  group('LocalThinkJobService', () {
    test('parses jobs from injected ledger output', () async {
      var detailReadCount = 0;
      final service = LocalThinkJobService(
        ledgerReader: () async => '''
[
  {
    "task_id": "job-1",
    "status": "running",
    "attempts": 1,
    "max_attempts": 2,
    "name": "active-job"
  }
]
''',
        detailReader: (_) async {
          detailReadCount += 1;
          return '{}';
        },
      );

      final jobs = await service.listJobs();

      expect(jobs, hasLength(1));
      expect(jobs.single.name, 'active-job');
      expect(jobs.single.status, LocalThinkJobStatus.running);
      expect(detailReadCount, 0);
    });

    test('returns empty list on web guard without reading ledger', () async {
      var readCount = 0;
      var detailReadCount = 0;
      final service = LocalThinkJobService(
        isWeb: true,
        enrichDetails: true,
        ledgerReader: () async {
          readCount += 1;
          return '[]';
        },
        detailReader: (_) async {
          detailReadCount += 1;
          return '{}';
        },
      );

      final jobs = await service.listJobs();

      expect(jobs, isEmpty);
      expect(readCount, 0);
      expect(detailReadCount, 0);
    });

    test('enriches recent terminal jobs up to the configured limit', () async {
      final detailReads = <String>[];
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 2,
        ledgerReader: () async => '''
[
  {
    "task_id": "old-completed",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "old-completed",
    "finished_at": "2026-05-02T10:00:00Z"
  },
  {
    "task_id": "new-completed",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "new-completed",
    "finished_at": "2026-05-02T10:03:00Z"
  },
  {
    "task_id": "running-job",
    "status": "running",
    "attempts": 1,
    "max_attempts": 2,
    "name": "running-job",
    "started_at": "2026-05-02T10:04:00Z"
  },
  {
    "task_id": "failed-job",
    "status": "failed",
    "attempts": 2,
    "max_attempts": 2,
    "name": "failed-job",
    "finished_at": "2026-05-02T10:02:00Z"
  }
]
''',
        detailReader: (taskIdPrefix) async {
          detailReads.add(taskIdPrefix);
          return '''
{
  "task_id": "$taskIdPrefix",
  "status": "completed",
  "attempts": 1,
  "max_attempts": 1,
  "name": "$taskIdPrefix",
  "started_at": "2026-05-02T10:01:00Z",
  "context_from": "parent-$taskIdPrefix",
  "updated_at": 1777716000.25,
  "notify": "telegram",
  "wake_gate": "open",
  "final_preview": "Preview for $taskIdPrefix",
  "final_file": "/tmp/$taskIdPrefix/final.md",
  "log_file": "/tmp/$taskIdPrefix/run.log",
  "output_file": "/tmp/$taskIdPrefix/output.json",
  "meta_file": "/tmp/$taskIdPrefix/meta.json",
  "runner_file": "/tmp/$taskIdPrefix/runner.sh",
  "meta_json": "{\\"task\\":\\"$taskIdPrefix\\"}"
}
''';
        },
      );

      final jobs = await service.listJobs();
      final byId = <String, LocalThinkJob>{
        for (final job in jobs) job.taskId: job,
      };

      expect(detailReads, <String>['new-completed', 'failed-job']);
      expect(byId['new-completed']?.finalFile, '/tmp/new-completed/final.md');
      expect(byId['new-completed']?.logFile, '/tmp/new-completed/run.log');
      expect(
        byId['new-completed']?.outputFile,
        '/tmp/new-completed/output.json',
      );
      expect(byId['new-completed']?.metaFile, '/tmp/new-completed/meta.json');
      expect(byId['new-completed']?.runnerFile, '/tmp/new-completed/runner.sh');
      expect(byId['new-completed']?.metaJson, '{"task":"new-completed"}');
      expect(byId['new-completed']?.notify, 'telegram');
      expect(byId['new-completed']?.wakeGate, 'open');
      expect(byId['new-completed']?.updatedAt, 1777716000.25);
      expect(byId['new-completed']?.contextFrom, 'parent-new-completed');
      expect(byId['new-completed']?.startedAt, DateTime.utc(2026, 5, 2, 10, 1));
      expect(byId['new-completed']?.finalPreview, 'Preview for new-completed');
      expect(byId['old-completed']?.finalFile, isNull);
      expect(byId['running-job']?.finalFile, isNull);
    });

    test('uses updated_at fallback when choosing recent terminal jobs', () async {
      final detailReads = <String>[];
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 1,
        ledgerReader: () async => '''
[
  {
    "task_id": "older-finished",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "older-finished",
    "finished_at": "2026-05-02T10:00:00Z"
  },
  {
    "task_id": "updated-only-recent",
    "status": "failed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "updated-only-recent",
    "updated_at": 1777716600.5
  }
]
''',
        detailReader: (taskIdPrefix) async {
          detailReads.add(taskIdPrefix);
          return '''
{
  "task_id": "$taskIdPrefix",
  "status": "failed",
  "attempts": 1,
  "max_attempts": 1,
  "name": "$taskIdPrefix",
  "final_preview": "Preview for $taskIdPrefix"
}
''';
        },
      );

      final jobs = await service.listJobs();
      final byId = <String, LocalThinkJob>{
        for (final job in jobs) job.taskId: job,
      };

      expect(detailReads, <String>['updated-only-recent']);
      expect(
        byId['updated-only-recent']?.finalPreview,
        'Preview for updated-only-recent',
      );
      expect(byId['older-finished']?.finalPreview, isNull);
    });

    test('keeps list row data when one detail lookup fails', () async {
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 5,
        ledgerReader: () async => '''
[
  {
    "task_id": "completed-job",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "completed-job",
    "finished_at": "2026-05-02T10:00:00Z"
  },
  {
    "task_id": "failed-detail",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "failed-detail",
    "finished_at": "2026-05-02T10:01:00Z"
  }
]
''',
        detailReader: (taskIdPrefix) async {
          if (taskIdPrefix == 'failed-detail') {
            throw StateError('detail unavailable');
          }
          return '''
{
  "task_id": "$taskIdPrefix",
  "status": "completed",
  "attempts": 1,
  "max_attempts": 1,
  "name": "$taskIdPrefix",
  "final_file": "/tmp/$taskIdPrefix/final.md"
}
''';
        },
      );

      final jobs = await service.listJobs();
      final byId = <String, LocalThinkJob>{
        for (final job in jobs) job.taskId: job,
      };

      expect(jobs, hasLength(2));
      expect(byId['completed-job']?.finalFile, '/tmp/completed-job/final.md');
      expect(byId['failed-detail']?.name, 'failed-detail');
      expect(byId['failed-detail']?.finalFile, isNull);
    });

    test('detail enrichment supports wrapped job detail payloads', () async {
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 1,
        ledgerReader: () async => '''
[
  {
    "task_id": "wrapped-job",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "wrapped-job",
    "finished_at": "2026-05-02T10:00:00Z"
  }
]
''',
        detailReader: (_) async => '''
{
  "job": {
    "task_id": "different-detail-job",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "detail-name",
    "final_preview": "Detail preview",
    "final_file": "/tmp/wrapped-job/final.md"
  }
}
''',
      );

      final jobs = await service.listJobs();

      expect(jobs.single.taskId, 'wrapped-job');
      expect(jobs.single.name, 'detail-name');
      expect(jobs.single.finalPreview, 'Detail preview');
      expect(jobs.single.finalFile, '/tmp/wrapped-job/final.md');
    });

    test('detail enrichment supports wrapped task detail payloads', () async {
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 1,
        ledgerReader: () async => '''
[
  {
    "task_id": "wrapped-task",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "wrapped-task",
    "finished_at": "2026-05-02T10:00:00Z"
  }
]
''',
        detailReader: (_) async => '''
{
  "task": {
    "task_id": "different-task-id",
    "status": "failed",
    "attempts": 2,
    "max_attempts": 2,
    "name": "task-wrapper-name",
    "context_from": "parent-task",
    "meta_file": "/tmp/wrapped-task/meta.json"
  }
}
''',
      );

      final jobs = await service.listJobs();

      expect(jobs.single.taskId, 'wrapped-task');
      expect(jobs.single.status, LocalThinkJobStatus.failed);
      expect(jobs.single.name, 'task-wrapper-name');
      expect(jobs.single.contextFrom, 'parent-task');
      expect(jobs.single.metaFile, '/tmp/wrapped-task/meta.json');
    });

    test('detail enrichment keeps quiet-job state from explicit detail flags',
        () async {
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 1,
        ledgerReader: () async => '''
[
  {
    "task_id": "quiet-detail-job",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "quiet-detail-job",
    "finished_at": "2026-05-02T10:00:00Z"
  }
]
''',
        detailReader: (_) async => '''
{
  "task_id": "quiet-detail-job",
  "status": "completed",
  "attempts": 1,
  "max_attempts": 1,
  "name": "quiet-detail-job",
  "is_silent": 1,
  "final_preview": "Visible summary that should still stay quiet"
}
''',
      );

      final jobs = await service.listJobs();

      expect(
        jobs.single.finalPreview,
        'Visible summary that should still stay quiet',
      );
      expect(jobs.single.isSilent, isTrue);
    });

    test('populates missing finalPreview from safe final file preview',
        () async {
      final previewReads = <String>[];
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 1,
        artifactPreviewService: LocalThinkArtifactPreviewService(
          allowedPathPrefixes: const <String>['/tmp/local-think/'],
          textReader: (path) async {
            previewReads.add(path);
            return 'Safe final summary.';
          },
        ),
        ledgerReader: () async => '''
[
  {
    "task_id": "completed-job",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "completed-job",
    "finished_at": "2026-05-02T10:00:00Z"
  }
]
''',
        detailReader: (_) async => '''
{
  "task_id": "completed-job",
  "status": "completed",
  "attempts": 1,
  "max_attempts": 1,
  "name": "completed-job",
  "final_file": "/tmp/local-think/completed-job/completed-job.final.md"
}
''',
      );

      final jobs = await service.listJobs();

      expect(jobs.single.finalFile, endsWith('completed-job.final.md'));
      expect(jobs.single.finalPreview, 'Safe final summary.');
      expect(previewReads, <String>[
        '/tmp/local-think/completed-job/completed-job.final.md',
      ]);
    });

    test('does not overwrite an existing finalPreview', () async {
      var previewReadCount = 0;
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 1,
        artifactPreviewService: LocalThinkArtifactPreviewService(
          allowedPathPrefixes: const <String>['/tmp/local-think/'],
          textReader: (_) async {
            previewReadCount += 1;
            return 'Preview from file.';
          },
        ),
        ledgerReader: () async => '''
[
  {
    "task_id": "completed-job",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "completed-job",
    "finished_at": "2026-05-02T10:00:00Z"
  }
]
''',
        detailReader: (_) async => '''
{
  "task_id": "completed-job",
  "status": "completed",
  "attempts": 1,
  "max_attempts": 1,
  "name": "completed-job",
  "final_preview": "Existing preview.",
  "final_file": "/tmp/local-think/completed-job/completed-job.final.md"
}
''',
      );

      final jobs = await service.listJobs();

      expect(jobs.single.finalPreview, 'Existing preview.');
      expect(previewReadCount, 0);
    });

    test('preview failure keeps job data and artifact path', () async {
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 1,
        artifactPreviewService: LocalThinkArtifactPreviewService(
          allowedPathPrefixes: const <String>['/tmp/local-think/'],
          textReader: (_) async => throw StateError('preview unavailable'),
        ),
        ledgerReader: () async => '''
[
  {
    "task_id": "completed-job",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "completed-job",
    "finished_at": "2026-05-02T10:00:00Z"
  }
]
''',
        detailReader: (_) async => '''
{
  "task_id": "completed-job",
  "status": "completed",
  "attempts": 1,
  "max_attempts": 1,
  "name": "completed-job",
  "final_file": "/tmp/local-think/completed-job/completed-job.final.md"
}
''',
      );

      final jobs = await service.listJobs();

      expect(jobs.single.finalFile, endsWith('completed-job.final.md'));
      expect(jobs.single.finalPreview, isNull);
    });

    test('silent final file previews keep quiet job state after normalization',
        () async {
      final service = LocalThinkJobService(
        enrichDetails: true,
        enrichLimit: 1,
        artifactPreviewService: LocalThinkArtifactPreviewService(
          allowedPathPrefixes: const <String>['/tmp/local-think/'],
          textReader: (_) async => '[SILENT] skipped by wake gate',
        ),
        ledgerReader: () async => '''
[
  {
    "task_id": "completed-job",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "completed-job",
    "finished_at": "2026-05-02T10:00:00Z"
  }
]
''',
        detailReader: (_) async => '''
{
  "task_id": "completed-job",
  "status": "completed",
  "attempts": 1,
  "max_attempts": 1,
  "name": "completed-job",
  "final_file": "/tmp/local-think/completed-job/completed-job.final.md"
}
''',
      );

      final jobs = await service.listJobs();

      expect(jobs.single.finalPreview, localThinkSilentPreviewSummary);
      expect(jobs.single.isSilent, isTrue);
    });

    test('preview reader is not called when detail enrichment is disabled',
        () async {
      var previewReadCount = 0;
      final service = LocalThinkJobService(
        enrichDetails: false,
        artifactPreviewService: LocalThinkArtifactPreviewService(
          allowedPathPrefixes: const <String>['/tmp/local-think/'],
          textReader: (_) async {
            previewReadCount += 1;
            return 'Preview from file.';
          },
        ),
        ledgerReader: () async => '''
[
  {
    "task_id": "completed-job",
    "status": "completed",
    "attempts": 1,
    "max_attempts": 1,
    "name": "completed-job",
    "finished_at": "2026-05-02T10:00:00Z",
    "final_file": "/tmp/local-think/completed-job/completed-job.final.md"
  }
]
''',
      );

      final jobs = await service.listJobs();

      expect(jobs.single.finalPreview, isNull);
      expect(previewReadCount, 0);
    });

    test('preview reader is not called on web guard', () async {
      var previewReadCount = 0;
      final service = LocalThinkJobService(
        isWeb: true,
        enrichDetails: true,
        artifactPreviewService: LocalThinkArtifactPreviewService(
          allowedPathPrefixes: const <String>['/tmp/local-think/'],
          textReader: (_) async {
            previewReadCount += 1;
            return 'Preview from file.';
          },
        ),
        ledgerReader: () async => '[]',
        detailReader: (_) async => '{}',
      );

      final jobs = await service.listJobs();

      expect(jobs, isEmpty);
      expect(previewReadCount, 0);
    });
  });
}
