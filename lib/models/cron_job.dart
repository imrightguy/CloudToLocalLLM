/// Model for a scheduled cron job.
library;

import 'package:flutter/material.dart';

/// Cron job status
enum CronJobStatus {
  active,
  inactive,
  failed,
  running,
}

/// Model representing a scheduled cron job.
class CronJob {
  /// Unique identifier for the cron job
  final String id;

  /// Human-readable name
  final String name;

  /// Cron schedule expression (e.g., "0 2 * * *" for daily at 2 AM)
  final String schedule;

  /// Human-readable schedule description
  final String scheduleDescription;

  /// Command/script to execute
  final String command;

  /// Current status of the job
  final CronJobStatus status;

  /// Next scheduled run time
  final DateTime? nextRun;

  /// Last execution time
  final DateTime? lastRun;

  /// Last execution status
  final bool lastRunSuccess;

  /// Last execution output (truncated)
  final String? lastRunOutput;

  const CronJob({
    required this.id,
    required this.name,
    required this.schedule,
    required this.scheduleDescription,
    required this.command,
    required this.status,
    this.nextRun,
    this.lastRun,
    this.lastRunSuccess = true,
    this.lastRunOutput,
  });

  /// Get status icon
  IconData get statusIcon {
    switch (status) {
      case CronJobStatus.active:
        return Icons.schedule;
      case CronJobStatus.inactive:
        return Icons.pause_circle_outline;
      case CronJobStatus.failed:
        return Icons.error_outline;
      case CronJobStatus.running:
        return Icons.sync;
    }
  }

  /// Get status color
  Color getStatusColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (status) {
      case CronJobStatus.active:
        return theme.colorScheme.primary;
      case CronJobStatus.inactive:
        return theme.colorScheme.onSurface.withValues(alpha: 0.4);
      case CronJobStatus.failed:
        return theme.colorScheme.error;
      case CronJobStatus.running:
        return theme.colorScheme.tertiary;
    }
  }

  /// Get formatted status text
  String get statusText {
    switch (status) {
      case CronJobStatus.active:
        return 'Active';
      case CronJobStatus.inactive:
        return 'Inactive';
      case CronJobStatus.failed:
        return 'Failed';
      case CronJobStatus.running:
        return 'Running';
    }
  }

  /// Get last run status text
  String? get lastRunStatusText {
    if (lastRun == null) return null;
    return lastRunSuccess ? 'Success' : 'Failed';
  }
}
