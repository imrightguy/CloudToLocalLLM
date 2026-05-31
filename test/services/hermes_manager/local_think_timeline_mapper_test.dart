import 'package:cloudtolocalllm/models/local_think_job.dart';
import 'package:cloudtolocalllm/models/main_chat_timeline_event.dart';
import 'package:cloudtolocalllm/services/hermes_manager/local_think_timeline_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalThinkTimelineMapper', () {
    test('maps completed jobs to compact timeline events', () {
      final job = LocalThinkJob(
        taskId: 'job-1',
        name: 'summarize-project',
        status: LocalThinkJobStatus.completed,
        attempts: 1,
        maxAttempts: 2,
        dedupKey: 'summarize-project',
        createdAt: DateTime.utc(2026, 5, 2, 10),
        startedAt: DateTime.utc(2026, 5, 2, 10, 1),
        finishedAt: DateTime.utc(2026, 5, 2, 10, 2),
        parentTaskId: 'parent-1',
        contextFrom: 'parent-1',
        finalPreview: 'Project summary ready.',
        finalFile: '/tmp/job-1/final.md',
        logFile: '/tmp/job-1/run.log',
        outputFile: '/tmp/job-1/output.json',
      );

      final event = LocalThinkTimelineMapper.mapJob(job);

      expect(event.id, 'local-think:job-1:completed');
      expect(event.type, MainChatTimelineEventType.localThinkCompleted);
      expect(event.title, 'Background work completed');
      expect(event.summary, 'Project summary ready.');
      expect(event.timestamp, DateTime.utc(2026, 5, 2, 10, 2));
      expect(event.sourceId, 'job-1');
      expect(event.artifactPath, '/tmp/job-1/final.md');
      expect(event.metadata['attempts'], 1);
      expect(event.metadata['maxAttempts'], 2);
      expect(event.metadata['dedupKey'], 'summarize-project');
      expect(event.metadata['notify'], isNull);
      expect(event.metadata['wakeGate'], isNull);
      expect(event.metadata['parentTaskId'], 'parent-1');
      expect(event.metadata['contextFrom'], 'parent-1');
      expect(event.metadata['finalFile'], '/tmp/job-1/final.md');
      expect(event.metadata['logFile'], '/tmp/job-1/run.log');
      expect(event.metadata['outputFile'], '/tmp/job-1/output.json');
    });

    test('maps running jobs using started timestamp and status title', () {
      final job = LocalThinkJob(
        taskId: 'job-2',
        name: 'inspect-logs',
        status: LocalThinkJobStatus.running,
        attempts: 1,
        maxAttempts: 3,
        notify: 'telegram',
        wakeGate: 'open',
        createdAt: DateTime.utc(2026, 5, 2, 10),
        startedAt: DateTime.utc(2026, 5, 2, 10, 5),
      );

      final event = LocalThinkTimelineMapper.mapJob(job);

      expect(event.id, 'local-think:job-2:running');
      expect(event.type, MainChatTimelineEventType.localThinkRunning);
      expect(event.title, 'Running background work');
      expect(event.timestamp, DateTime.utc(2026, 5, 2, 10, 5));
      expect(event.summary, 'inspect-logs');
      expect(event.metadata['notify'], 'telegram');
      expect(event.metadata['wakeGate'], 'open');
    });

    test('renders silent previews as quiet skipped summaries', () {
      final job = LocalThinkJob(
        taskId: 'job-3',
        name: 'wake-gate',
        status: LocalThinkJobStatus.completed,
        attempts: 1,
        maxAttempts: 1,
        createdAt: DateTime.utc(2026, 5, 2, 10),
        finalPreview: '[SILENT] no work needed',
        isSilent: true,
      );

      final event = LocalThinkTimelineMapper.mapJob(job);

      expect(event.type, MainChatTimelineEventType.localThinkCompleted);
      expect(event.summary, localThinkSilentPreviewSummary);
      expect(event.metadata['isSilent'], isTrue);
    });

    test('treats normalized silent summary text as quiet activity metadata', () {
      const job = LocalThinkJob(
        taskId: 'job-3b',
        name: 'wake-gate-normalized',
        status: LocalThinkJobStatus.completed,
        attempts: 1,
        maxAttempts: 1,
        finalPreview: localThinkSilentPreviewSummary,
      );

      final event = LocalThinkTimelineMapper.mapJob(job);

      expect(event.type, MainChatTimelineEventType.localThinkCompleted);
      expect(event.summary, localThinkSilentPreviewSummary);
      expect(event.metadata['isSilent'], isTrue);
    });

    test('maps cancelled jobs to dedicated cancelled activity events', () {
      const job = LocalThinkJob(
        taskId: 'job-4',
        name: 'cancelled-job',
        status: LocalThinkJobStatus.cancelled,
        attempts: 1,
        maxAttempts: 1,
      );

      final event = LocalThinkTimelineMapper.mapJob(job);

      expect(event.id, 'local-think:job-4:cancelled');
      expect(event.type, MainChatTimelineEventType.localThinkCancelled);
      expect(event.title, 'Background work cancelled');
    });

    test('falls back to updatedAt when explicit timestamps are missing', () {
      const job = LocalThinkJob(
        taskId: 'job-updated-only',
        name: 'repaired-terminal-row',
        status: LocalThinkJobStatus.completed,
        attempts: 1,
        maxAttempts: 1,
        updatedAt: 1777716600.5,
      );

      final event = LocalThinkTimelineMapper.mapJob(job);

      expect(
        event.timestamp,
        DateTime.fromMillisecondsSinceEpoch(
          1777716600500,
          isUtc: true,
        ),
      );
    });

    test('falls back to log then output files for artifact path', () {
      final logOnlyJob = LocalThinkJob(
        taskId: 'job-5',
        name: 'log-only',
        status: LocalThinkJobStatus.completed,
        attempts: 1,
        maxAttempts: 1,
        logFile: '/tmp/job-5/run.log',
        outputFile: '/tmp/job-5/output.json',
      );
      final outputOnlyJob = LocalThinkJob(
        taskId: 'job-6',
        name: 'output-only',
        status: LocalThinkJobStatus.completed,
        attempts: 1,
        maxAttempts: 1,
        outputFile: '/tmp/job-6/output.json',
      );

      final logOnlyEvent = LocalThinkTimelineMapper.mapJob(logOnlyJob);
      final outputOnlyEvent = LocalThinkTimelineMapper.mapJob(outputOnlyJob);

      expect(logOnlyEvent.artifactPath, '/tmp/job-5/run.log');
      expect(outputOnlyEvent.artifactPath, '/tmp/job-6/output.json');
    });
  });
}
