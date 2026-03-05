/// Model for a log entry.
library;

import 'package:flutter/material.dart';

/// Log severity levels
enum LogSeverity {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Model representing a single log entry.
class LogEntry {
  /// Unique identifier for the log entry
  final String id;

  /// Timestamp when the log was created
  final DateTime timestamp;

  /// Severity level of the log
  final LogSeverity severity;

  /// Source component/service that generated the log
  final String source;

  /// Log message
  final String message;

  /// Optional error details (for error/critical logs)
  final String? errorDetails;

  /// Optional stack trace
  final String? stackTrace;

  const LogEntry({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.source,
    required this.message,
    this.errorDetails,
    this.stackTrace,
  });

  /// Get severity icon
  IconData get severityIcon {
    switch (severity) {
      case LogSeverity.debug:
        return Icons.bug_report_outlined;
      case LogSeverity.info:
        return Icons.info_outline;
      case LogSeverity.warning:
        return Icons.warning_outlined;
      case LogSeverity.error:
        return Icons.error_outline;
      case LogSeverity.critical:
        return Icons.dangerous;
    }
  }

  /// Get severity color
  Color getSeverityColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (severity) {
      case LogSeverity.debug:
        return theme.colorScheme.onSurface.withValues(alpha: 0.5);
      case LogSeverity.info:
        return theme.colorScheme.primary;
      case LogSeverity.warning:
        return Colors.orange;
      case LogSeverity.error:
        return theme.colorScheme.error;
      case LogSeverity.critical:
        return Colors.red.shade700;
    }
  }

  /// Get severity label
  String get severityLabel {
    switch (severity) {
      case LogSeverity.debug:
        return 'DEBUG';
      case LogSeverity.info:
        return 'INFO';
      case LogSeverity.warning:
        return 'WARNING';
      case LogSeverity.error:
        return 'ERROR';
      case LogSeverity.critical:
        return 'CRITICAL';
    }
  }

  /// Format timestamp for display
  String formatTimestamp() {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Format date for display
  String formatDate() {
    return '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-'
        '${timestamp.day.toString().padLeft(2, '0')}';
  }

  /// Check if log has error details
  bool get hasErrorDetails => errorDetails != null || stackTrace != null;
}
