import 'package:cloudtolocalllm/models/local_think_job.dart';
import 'package:cloudtolocalllm/services/hermes_manager/local_think_timeline_mapper.dart';
import 'package:cloudtolocalllm/widgets/hermes/main_chat_timeline_item.dart';
import 'package:flutter/material.dart';

class LocalThinkTrainCard extends StatelessWidget {
  const LocalThinkTrainCard({
    required this.jobs,
    this.showVerboseDetails = false,
    super.key,
  });

  final List<LocalThinkJob> jobs;
  final bool showVerboseDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sortedJobs = [...jobs]..sort(_compareMostRecentFirst);
    final visibleJobs = sortedJobs.take(3).toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Local-think train',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _CountChip(
                  label: jobs.length == 1 ? '1 job' : '${jobs.length} jobs',
                  color: scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Latest durable background work from the Hermes ledger, shown with compact-by-default summaries.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (visibleJobs.isEmpty)
              Text(
                'No local-think jobs yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              Column(
                children: [
                  for (final job in visibleJobs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: MainChatTimelineItem(
                        event: LocalThinkTimelineMapper.mapJob(job),
                        showVerboseDetails: showVerboseDetails,
                      ),
                    ),
                ],
              ),
            if (sortedJobs.length > visibleJobs.length) ...[
              const SizedBox(height: 4),
              Text(
                '+${sortedJobs.length - visibleJobs.length} more jobs in the ledger',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
