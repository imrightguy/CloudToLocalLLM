/// Metrics Exporter
/// Export tunnel metrics in various formats (Prometheus, JSON)
library;

import 'dart:convert';

import 'interfaces/tunnel_models.dart';
import 'interfaces/tunnel_health_metrics.dart';
import 'metrics_collector.dart';

/// Metrics export format
enum MetricsExportFormat {
  prometheus,
  json,
  csv,
}

/// Metrics exporter for various output formats
class MetricsExporter {
  final MetricsCollector _collector;

  MetricsExporter(this._collector);

  /// Export metrics in specified format
  String export({
    MetricsExportFormat format = MetricsExportFormat.json,
    Duration? window,
  }) {
    switch (format) {
      case MetricsExportFormat.prometheus:
        return exportPrometheus(window: window);
      case MetricsExportFormat.json:
        return exportJson(window: window);
      case MetricsExportFormat.csv:
        return exportCsv(window: window);
    }
  }

  /// Export in Prometheus text format
  String exportPrometheus({Duration? window}) {
    final metrics = _collector.getMetrics(window: window);
    final prometheusMetrics = metrics.toPrometheusFormat();

    final buffer = StringBuffer();

    // Add help and type information
    buffer.writeln(
        '# HELP tunnel_requests_total Total number of tunnel requests');
    buffer.writeln('# TYPE tunnel_requests_total counter');
    buffer.writeln(
        'tunnel_requests_total ${prometheusMetrics['tunnel_requests_total']}');
    buffer.writeln();

    buffer.writeln(
        '# HELP tunnel_requests_success_total Total number of successful requests');
    buffer.writeln('# TYPE tunnel_requests_success_total counter');
    buffer.writeln(
        'tunnel_requests_success_total ${prometheusMetrics['tunnel_requests_success_total']}');
    buffer.writeln();

    buffer.writeln(
        '# HELP tunnel_requests_failed_total Total number of failed requests');
    buffer.writeln('# TYPE tunnel_requests_failed_total counter');
    buffer.writeln(
        'tunnel_requests_failed_total ${prometheusMetrics['tunnel_requests_failed_total']}');
    buffer.writeln();

    buffer.writeln(
        '# HELP tunnel_request_success_rate Request success rate (0-1)');
    buffer.writeln('# TYPE tunnel_request_success_rate gauge');
    buffer.writeln(
        'tunnel_request_success_rate ${prometheusMetrics['tunnel_request_success_rate'].toStringAsFixed(4)}');
    buffer.writeln();

    buffer.writeln(
        '# HELP tunnel_request_latency_avg_ms Average request latency in milliseconds');
    buffer.writeln('# TYPE tunnel_request_latency_avg_ms gauge');
    buffer.writeln(
        'tunnel_request_latency_avg_ms ${prometheusMetrics['tunnel_request_latency_avg_ms']}');
    buffer.writeln();

    buffer.writeln(
        '# HELP tunnel_request_latency_p95_ms 95th percentile request latency in milliseconds');
    buffer.writeln('# TYPE tunnel_request_latency_p95_ms gauge');
    buffer.writeln(
        'tunnel_request_latency_p95_ms ${prometheusMetrics['tunnel_request_latency_p95_ms']}');
    buffer.writeln();

    buffer.writeln(
        '# HELP tunnel_request_latency_p99_ms 99th percentile request latency in milliseconds');
    buffer.writeln('# TYPE tunnel_request_latency_p99_ms gauge');
    buffer.writeln(
        'tunnel_request_latency_p99_ms ${prometheusMetrics['tunnel_request_latency_p99_ms']}');
    buffer.writeln();

    buffer.writeln(
        '# HELP tunnel_reconnection_count Total number of reconnections');
    buffer.writeln('# TYPE tunnel_reconnection_count counter');
    buffer.writeln(
        'tunnel_reconnection_count ${prometheusMetrics['tunnel_reconnection_count']}');
    buffer.writeln();

    buffer.writeln('# HELP tunnel_uptime_seconds Connection uptime in seconds');
    buffer.writeln('# TYPE tunnel_uptime_seconds gauge');
    buffer.writeln(
        'tunnel_uptime_seconds ${prometheusMetrics['tunnel_uptime_seconds']}');
    buffer.writeln();

    // Add error counts by type
    final errorCounts = metrics.errorCounts;
    if (errorCounts.isNotEmpty) {
      buffer.writeln('# HELP tunnel_errors_total Total errors by type');
      buffer.writeln('# TYPE tunnel_errors_total counter');
      for (final entry in errorCounts.entries) {
        buffer.writeln(
            'tunnel_errors_total{error_type="${entry.key}"} ${entry.value}');
      }
      buffer.writeln();
    }

    // Add connection quality
    buffer.writeln(
        '# HELP tunnel_connection_quality Connection quality indicator (0=poor, 1=fair, 2=good, 3=excellent)');
    buffer.writeln('# TYPE tunnel_connection_quality gauge');
    buffer.writeln(
        'tunnel_connection_quality ${_qualityToNumeric(_collector.currentQuality)}');
    buffer.writeln();

    return buffer.toString();
  }

  /// Export in JSON format
  String exportJson({Duration? window, bool pretty = true}) {
    final metrics = _collector.getMetrics(window: window);
    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'window': window?.inSeconds,
      'metrics': metrics.toJson(),
      'quality': {
        'current': _collector.currentQuality.name,
        'numeric': _qualityToNumeric(_collector.currentQuality),
      },
      'percentiles': {
        'p95_latency_ms': metrics.p95Latency.inMilliseconds,
        'p99_latency_ms': metrics.p99Latency.inMilliseconds,
      },
      'errors': {
        'by_type': metrics.errorCounts,
        'total': metrics.failedRequests,
      },
    };

    if (pretty) {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(data);
    } else {
      return jsonEncode(data);
    }
  }

  /// Export in CSV format
  String exportCsv({Duration? window}) {
    final metrics = _collector.getMetrics(window: window);

    final buffer = StringBuffer();

    // Header
    buffer.writeln('metric,value,unit');

    // Basic metrics
    buffer.writeln('total_requests,${metrics.totalRequests},count');
    buffer.writeln('successful_requests,${metrics.successfulRequests},count');
    buffer.writeln('failed_requests,${metrics.failedRequests},count');
    buffer.writeln(
        'success_rate,${metrics.successRate.toStringAsFixed(4)},ratio');

    // Latency metrics
    buffer
        .writeln('average_latency,${metrics.averageLatency.inMilliseconds},ms');
    buffer.writeln('p95_latency,${metrics.p95Latency.inMilliseconds},ms');
    buffer.writeln('p99_latency,${metrics.p99Latency.inMilliseconds},ms');

    // Connection metrics
    buffer.writeln('reconnection_count,${metrics.reconnectionCount},count');
    buffer.writeln('uptime,${metrics.totalUptime.inSeconds},seconds');

    // Quality
    buffer.writeln('connection_quality,${_collector.currentQuality.name},enum');
    buffer.writeln(
        'connection_quality_numeric,${_qualityToNumeric(_collector.currentQuality)},score');

    return buffer.toString();
  }

  /// Export percentile metrics
  Map<String, dynamic> exportPercentiles({Duration? window}) {
    final metrics = _collector.getMetrics(window: window);

    return {
      'p50': metrics.averageLatency.inMilliseconds, // Approximation
      'p95': metrics.p95Latency.inMilliseconds,
      'p99': metrics.p99Latency.inMilliseconds,
      'unit': 'milliseconds',
    };
  }

  /// Export error aggregation
  Map<String, dynamic> exportErrorAggregation({Duration? window}) {
    final metrics = _collector.getMetrics(window: window);

    final totalErrors = metrics.failedRequests;
    final errorsByType = metrics.errorCounts;

    // Calculate error percentages
    final errorPercentages = <String, double>{};
    if (totalErrors > 0) {
      for (final entry in errorsByType.entries) {
        errorPercentages[entry.key] = (entry.value / totalErrors) * 100;
      }
    }

    return {
      'total_errors': totalErrors,
      'error_rate': metrics.totalRequests > 0
          ? metrics.failedRequests / metrics.totalRequests
          : 0.0,
      'errors_by_type': errorsByType,
      'error_percentages': errorPercentages,
      'most_common_error': _getMostCommonError(errorsByType),
    };
  }

  /// Export summary statistics
  Map<String, dynamic> exportSummary({Duration? window}) {
    final metrics = _collector.getMetrics(window: window);

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'window_seconds': window?.inSeconds,
      'summary': {
        'total_requests': metrics.totalRequests,
        'success_rate': '${(metrics.successRate * 100).toStringAsFixed(2)}%',
        'average_latency_ms': metrics.averageLatency.inMilliseconds,
        'p95_latency_ms': metrics.p95Latency.inMilliseconds,
        'connection_quality': _collector.currentQuality.name,
        'uptime_hours': metrics.totalUptime.inHours.toStringAsFixed(2),
        'reconnections': metrics.reconnectionCount,
      },
      'health_status': _getHealthStatus(metrics),
    };
  }

  /// Convert quality enum to numeric value
  int _qualityToNumeric(ConnectionQuality quality) {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 3;
      case ConnectionQuality.good:
        return 2;
      case ConnectionQuality.fair:
        return 1;
      case ConnectionQuality.poor:
        return 0;
    }
  }

  /// Get most common error type
  String? _getMostCommonError(Map<String, int> errorCounts) {
    if (errorCounts.isEmpty) return null;

    var maxCount = 0;
    String? mostCommon;

    for (final entry in errorCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        mostCommon = entry.key;
      }
    }

    return mostCommon;
  }

  /// Get overall health status
  String _getHealthStatus(TunnelMetrics metrics) {
    if (metrics.successRate >= 0.99 &&
        _collector.currentQuality == ConnectionQuality.excellent) {
      return 'healthy';
    } else if (metrics.successRate >= 0.95 &&
        (_collector.currentQuality == ConnectionQuality.excellent ||
            _collector.currentQuality == ConnectionQuality.good)) {
      return 'degraded';
    } else {
      return 'unhealthy';
    }
  }
}

/// Metrics export helper functions
class MetricsExportHelper {
  /// Format duration for display
  static String formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Format latency for display
  static String formatLatency(Duration latency) {
    if (latency.inMilliseconds < 1000) {
      return '${latency.inMilliseconds}ms';
    } else {
      return '${(latency.inMilliseconds / 1000).toStringAsFixed(2)}s';
    }
  }

  /// Format success rate as percentage
  static String formatSuccessRate(double rate) {
    return '${(rate * 100).toStringAsFixed(2)}%';
  }

  /// Format bytes for display
  static String formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)}KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
    }
  }
}
