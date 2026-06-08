/// Metrics Collector
///
/// Collects and aggregates tunnel performance metrics for monitoring and diagnostics.
///
/// ## Design Pattern: Metrics Aggregation
///
/// The metrics collector tracks tunnel performance across multiple dimensions:
///
/// ### Request Metrics
/// - Individual request latencies
/// - Success/failure rates
/// - Error categorization
///
/// ### Connection Metrics
/// - Connection state transitions
/// - Uptime calculation
/// - Reconnection attempts
///
/// ### Quality Calculation
///
/// Connection quality is calculated based on:
/// - **Latency**: Average request latency
/// - **Packet Loss**: Error rate
///
/// Quality levels:
/// - **Excellent**: < 50ms latency, < 1% error rate
/// - **Good**: < 100ms latency, < 3% error rate
/// - **Fair**: < 200ms latency, < 5% error rate
/// - **Poor**: > 200ms latency or > 5% error rate
///
/// ### Data Retention
///
/// - Request history: Last 10,000 data points
/// - Connection history: Last 1,000 state changes
/// - Reconnection history: Last 1,000 attempts
///
/// ### Usage Example
///
/// ```dart
/// final collector = MetricsCollector();
///
/// // Record request metrics
/// final stopwatch = Stopwatch()..start();
/// try {
///   final response = await tunnel.forwardRequest(request);
///   stopwatch.stop();
///   collector.recordRequest(
///     latency: stopwatch.elapsed,
///     success: true,
///   );
/// } catch (e) {
///   stopwatch.stop();
///   collector.recordRequest(
///     latency: stopwatch.elapsed,
///     success: false,
///     errorType: 'network',
///   );
/// }
///
/// // Get metrics
/// final metrics = collector.getMetrics();
/// print('Success rate: ${metrics.successRate}%');
/// print('Quality: ${metrics.quality}');
/// ```
///
/// Requirements: 3.1, 3.2, 3.3, 3.5, 3.6, 3.8, 3.9, 3.10
library;

import 'dart:collection';
import 'dart:math';

import 'interfaces/tunnel_models.dart';
import 'interfaces/tunnel_health_metrics.dart';

/// Individual metric data point
///
/// Records a single request measurement with timestamp and result.
class MetricDataPoint {
  /// When this measurement was taken
  final DateTime timestamp;

  /// Request latency
  final Duration latency;

  /// Whether request succeeded
  final bool success;

  /// Error type if failed (e.g., 'network', 'timeout')
  final String? errorType;

  /// Create a new MetricDataPoint
  MetricDataPoint({
    required this.timestamp,
    required this.latency,
    required this.success,
    this.errorType,
  });
}

/// Connection state change record
///
/// Tracks when and why the connection state changed.
class ConnectionStateChange {
  /// When state changed
  final DateTime timestamp;

  /// New connection state
  final TunnelConnectionState state;

  /// Reason for state change (e.g., 'network_failure', 'user_disconnect')
  final String? reason;

  /// Create a new ConnectionStateChange
  ConnectionStateChange({
    required this.timestamp,
    required this.state,
    this.reason,
  });
}

/// Reconnection attempt record
///
/// Tracks each reconnection attempt and its outcome.
class ReconnectionAttempt {
  /// When reconnection was attempted
  final DateTime timestamp;

  /// Attempt number (1-based)
  final int attemptNumber;

  /// Whether reconnection succeeded
  final bool success;

  /// Delay before this attempt (for exponential backoff tracking)
  final Duration? delay;

  /// Create a new ReconnectionAttempt
  ReconnectionAttempt({
    required this.timestamp,
    required this.attemptNumber,
    required this.success,
    this.delay,
  });
}

/// Metrics collector for tunnel performance tracking
///
/// Collects and aggregates metrics for monitoring connection quality,
/// performance, and reliability.
class MetricsCollector {
  /// Maximum number of data points to keep in history
  static const int maxHistorySize = 10000;

  /// Request metrics history (FIFO queue)
  final Queue<MetricDataPoint> _requestHistory = Queue<MetricDataPoint>();

  /// Connection state changes history (FIFO queue)
  final Queue<ConnectionStateChange> _connectionHistory =
      Queue<ConnectionStateChange>();

  /// Reconnection attempts history (FIFO queue)
  final Queue<ReconnectionAttempt> _reconnectionHistory =
      Queue<ReconnectionAttempt>();

  /// Error counts by type (e.g., 'network': 5, 'timeout': 2)
  final Map<String, int> _errorCounts = {};

  /// When the current connection started (for uptime calculation)
  DateTime? _connectionStartTime;

  /// Total number of reconnections since start
  int _totalReconnections = 0;

  /// Current calculated connection quality
  ConnectionQuality _currentQuality = ConnectionQuality.excellent;

  /// Record a request metric
  ///
  /// Adds a data point to the request history and updates error counts.
  /// Automatically maintains history size limit.
  ///
  /// @param latency - Request latency
  /// @param success - Whether request succeeded
  /// @param errorType - Error type if failed (e.g., 'network', 'timeout')
  void recordRequest({
    required Duration latency,
    required bool success,
    String? errorType,
  }) {
    final dataPoint = MetricDataPoint(
      timestamp: DateTime.now(),
      latency: latency,
      success: success,
      errorType: errorType,
    );

    _requestHistory.addLast(dataPoint);

    // Track error counts
    if (!success && errorType != null) {
      _errorCounts[errorType] = (_errorCounts[errorType] ?? 0) + 1;
    }

    // Maintain size limit (FIFO)
    if (_requestHistory.length > maxHistorySize) {
      _requestHistory.removeFirst();
    }

    // Update connection quality based on recent metrics
    _updateConnectionQuality();
  }

  /// Record a connection state change
  void recordConnection({
    required TunnelConnectionState state,
    String? reason,
  }) {
    final stateChange = ConnectionStateChange(
      timestamp: DateTime.now(),
      state: state,
      reason: reason,
    );

    _connectionHistory.addLast(stateChange);

    // Maintain size limit
    if (_connectionHistory.length > maxHistorySize) {
      _connectionHistory.removeFirst();
    }

    // Track connection start time
    if (state == TunnelConnectionState.connected &&
        _connectionStartTime == null) {
      _connectionStartTime = DateTime.now();
    } else if (state == TunnelConnectionState.disconnected) {
      _connectionStartTime = null;
    }
  }

  /// Record a reconnection attempt
  void recordReconnection({
    required int attemptNumber,
    required bool success,
    Duration? delay,
  }) {
    final attempt = ReconnectionAttempt(
      timestamp: DateTime.now(),
      attemptNumber: attemptNumber,
      success: success,
      delay: delay,
    );

    _reconnectionHistory.addLast(attempt);

    // Maintain size limit
    if (_reconnectionHistory.length > maxHistorySize) {
      _reconnectionHistory.removeFirst();
    }

    if (success) {
      _totalReconnections++;
    }
  }

  /// Get metrics for a specific time window
  TunnelMetrics getMetrics({Duration? window}) {
    final now = DateTime.now();
    final cutoffTime = window != null ? now.subtract(window) : null;

    // Filter data points by time window
    final relevantRequests = cutoffTime != null
        ? _requestHistory.where((dp) => dp.timestamp.isAfter(cutoffTime))
        : _requestHistory;

    if (relevantRequests.isEmpty) {
      return TunnelMetrics.empty();
    }

    // Calculate basic counts
    final totalRequests = relevantRequests.length;
    final successfulRequests =
        relevantRequests.where((dp) => dp.success).length;
    final failedRequests = totalRequests - successfulRequests;
    final successRate =
        totalRequests > 0 ? successfulRequests / totalRequests : 0.0;

    // Calculate latency metrics
    final latencies = relevantRequests.map((dp) => dp.latency).toList();
    final averageLatency = _calculateAverageLatency(latencies);
    final p95Latency = _calculatePercentile(latencies, 0.95);
    final p99Latency = _calculatePercentile(latencies, 0.99);

    // Calculate uptime
    final uptime = _connectionStartTime != null
        ? now.difference(_connectionStartTime!)
        : Duration.zero;

    // Get error counts for the window
    final windowErrorCounts = <String, int>{};
    if (cutoffTime != null) {
      for (final dp in relevantRequests) {
        if (!dp.success && dp.errorType != null) {
          windowErrorCounts[dp.errorType!] =
              (windowErrorCounts[dp.errorType!] ?? 0) + 1;
        }
      }
    } else {
      windowErrorCounts.addAll(_errorCounts);
    }

    return TunnelMetrics(
      totalRequests: totalRequests,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      successRate: successRate,
      averageLatency: averageLatency,
      p95Latency: p95Latency,
      p99Latency: p99Latency,
      reconnectionCount: _totalReconnections,
      totalUptime: uptime,
      errorCounts: windowErrorCounts,
    );
  }

  /// Get current connection quality
  ConnectionQuality get currentQuality => _currentQuality;

  /// Export metrics in Prometheus format
  Map<String, dynamic> exportPrometheusFormat() {
    final metrics = getMetrics();
    return metrics.toPrometheusFormat();
  }

  /// Export metrics in JSON format
  Map<String, dynamic> exportJson() {
    final metrics = getMetrics();
    return {
      ...metrics.toJson(),
      'currentQuality': _currentQuality.name,
      'connectionStartTime': _connectionStartTime?.toIso8601String(),
      'historySize': _requestHistory.length,
    };
  }

  /// Calculate average latency from a list of durations
  Duration _calculateAverageLatency(List<Duration> latencies) {
    if (latencies.isEmpty) return Duration.zero;

    final totalMs = latencies.fold<int>(
      0,
      (sum, duration) => sum + duration.inMilliseconds,
    );

    return Duration(milliseconds: totalMs ~/ latencies.length);
  }

  /// Calculate percentile latency
  Duration _calculatePercentile(List<Duration> latencies, double percentile) {
    if (latencies.isEmpty) return Duration.zero;

    final sorted = List<Duration>.from(latencies)
      ..sort((a, b) => a.inMilliseconds.compareTo(b.inMilliseconds));

    final index = ((sorted.length - 1) * percentile).round();
    return sorted[index];
  }

  /// Update connection quality based on recent metrics
  void _updateConnectionQuality() {
    // Use last 100 requests or all if less
    final recentCount = min(100, _requestHistory.length);
    if (recentCount == 0) {
      _currentQuality = ConnectionQuality.excellent;
      return;
    }

    final recentRequests = _requestHistory.toList().sublist(
          max(0, _requestHistory.length - recentCount),
        );

    // Calculate average latency
    final latencies = recentRequests.map((dp) => dp.latency).toList();
    final avgLatency = _calculateAverageLatency(latencies);

    // Calculate packet loss (failed requests)
    final failedCount = recentRequests.where((dp) => !dp.success).length;
    final packetLoss = failedCount / recentCount;

    // Calculate quality
    _currentQuality = TunnelHealthMetrics.calculateQuality(
      latency: avgLatency.inMilliseconds.toDouble(),
      packetLoss: packetLoss,
    );
  }

  /// Get packet loss percentage
  double getPacketLoss({Duration? window}) {
    final now = DateTime.now();
    final cutoffTime = window != null ? now.subtract(window) : null;

    final relevantRequests = cutoffTime != null
        ? _requestHistory.where((dp) => dp.timestamp.isAfter(cutoffTime))
        : _requestHistory;

    if (relevantRequests.isEmpty) return 0.0;

    final failedCount = relevantRequests.where((dp) => !dp.success).length;
    return failedCount / relevantRequests.length;
  }

  /// Get average latency for recent requests
  double getAverageLatency({Duration? window}) {
    final metrics = getMetrics(window: window);
    return metrics.averageLatency.inMilliseconds.toDouble();
  }

  /// Clear all metrics
  void clear() {
    _requestHistory.clear();
    _connectionHistory.clear();
    _reconnectionHistory.clear();
    _errorCounts.clear();
    _connectionStartTime = null;
    _totalReconnections = 0;
    _currentQuality = ConnectionQuality.excellent;
  }

  /// Get total request count
  int get totalRequests => _requestHistory.length;

  /// Get successful request count
  int get successfulRequests =>
      _requestHistory.where((dp) => dp.success).length;

  /// Get failed request count
  int get failedRequests => _requestHistory.where((dp) => !dp.success).length;

  /// Get reconnection count
  int get reconnectionCount => _totalReconnections;

  /// Get uptime
  Duration get uptime {
    if (_connectionStartTime == null) return Duration.zero;
    return DateTime.now().difference(_connectionStartTime!);
  }

  /// Get error counts
  Map<String, int> get errorCounts => Map.unmodifiable(_errorCounts);
}
