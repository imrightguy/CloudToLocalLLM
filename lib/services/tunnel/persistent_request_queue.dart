/// Persistent Request Queue
///
/// Priority-based queue with persistence for high-priority requests.
///
/// ## Design Pattern: Request Queue with Backpressure
///
/// The request queue handles network interruptions gracefully by queuing
/// requests when the connection is unavailable and flushing them when
/// the connection is restored.
///
/// ### Priority Levels
///
/// - **HIGH**: Interactive user requests (e.g., chat messages)
/// - **NORMAL**: Regular batch operations (default)
/// - **LOW**: Background tasks (e.g., analytics)
///
/// Requests are processed in priority order, with FIFO ordering within
/// each priority level.
///
/// ### Persistence
///
/// High-priority requests are persisted to disk using SharedPreferences.
/// This ensures they survive app restarts.
///
/// ### Backpressure
///
/// When queue reaches 80% capacity, backpressure signals are emitted
/// to throttle new requests and prevent memory exhaustion.
///
/// ### Usage Example
///
/// ```dart
/// final queue = PersistentRequestQueue(
///   maxSize: 100,
///   prefs: sharedPreferences,
/// );
///
/// // Enqueue a request
/// await queue.enqueue(request, priority: RequestPriority.high);
///
/// // Listen for backpressure
/// queue.backpressureStream.listen((signal) {
///   if (signal.shouldThrottle) {
///     // Reduce request rate
///   }
/// });
///
/// // Dequeue and process
/// while (!queue.isEmpty) {
///   final request = await queue.dequeue();
///   await processRequest(request);
/// }
///
/// // Persist on shutdown
/// await queue.persistHighPriorityRequests();
/// ```
///
/// Requirements: 5.1, 5.2, 5.3, 5.4, 5.9, 5.10
library;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'interfaces/tunnel_models.dart';

/// Exception thrown when queue is full
///
/// Indicates that the queue has reached maximum capacity and cannot
/// accept new requests without dropping existing ones.
class QueueFullException implements Exception {
  /// Error message
  final String message;

  /// Create a new QueueFullException
  QueueFullException(this.message);

  @override
  String toString() => 'QueueFullException: $message';
}

/// Backpressure signal for flow control
///
/// Emitted when queue fill percentage reaches threshold (80%).
/// Signals to the application that it should throttle request rate.
class BackpressureSignal {
  /// Queue fill percentage (0.0 to 1.0)
  final double queueFillPercentage;

  /// Whether application should throttle requests
  final bool shouldThrottle;

  /// Optional message describing the backpressure condition
  final String? message;

  /// Create a new BackpressureSignal
  BackpressureSignal({
    required this.queueFillPercentage,
    required this.shouldThrottle,
    this.message,
  });

  @override
  String toString() {
    return 'BackpressureSignal(fill: ${(queueFillPercentage * 100).toStringAsFixed(1)}%, '
        'throttle: $shouldThrottle, message: $message)';
  }
}

/// Queued request with priority and metadata
///
/// Wraps a TunnelRequest with priority level and timing information.
/// Implements Comparable for priority queue ordering.
class QueuedRequest implements Comparable<QueuedRequest> {
  /// The actual request to be sent
  final TunnelRequest request;

  /// Priority level for this request
  final RequestPriority priority;

  /// When this request was added to the queue
  final DateTime enqueuedAt;

  /// When this request should timeout (optional)
  final DateTime? timeoutAt;

  /// Create a new QueuedRequest
  QueuedRequest({
    required this.request,
    required this.priority,
    DateTime? enqueuedAt,
    this.timeoutAt,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();

  /// Check if request has timed out
  ///
  /// Returns true if timeoutAt is set and current time is after it.
  bool get isTimedOut {
    if (timeoutAt == null) return false;
    return DateTime.now().isAfter(timeoutAt!);
  }

  /// Compare for priority queue ordering
  ///
  /// Implements priority ordering:
  /// 1. Higher priority first (HIGH < NORMAL < LOW)
  /// 2. Earlier timestamp first (FIFO within same priority)
  ///
  /// @param other - Request to compare with
  /// @return Negative if this < other, 0 if equal, positive if this > other
  @override
  int compareTo(QueuedRequest other) {
    // Higher priority first (high=0, normal=1, low=2, so reverse comparison)
    final priorityCompare = priority.index.compareTo(other.priority.index);
    if (priorityCompare != 0) return priorityCompare;

    // Earlier timestamp first (FIFO within same priority)
    return enqueuedAt.compareTo(other.enqueuedAt);
  }

  /// Convert to JSON for persistence
  ///
  /// Serializes the request for storage in SharedPreferences.
  Map<String, dynamic> toJson() {
    return {
      'request': request.toJson(),
      'priority': priority.name,
      'enqueuedAt': enqueuedAt.toIso8601String(),
      'timeoutAt': timeoutAt?.toIso8601String(),
    };
  }

  /// Create from JSON
  factory QueuedRequest.fromJson(Map<String, dynamic> json) {
    final priorityStr = json['priority'] as String;
    final priority = RequestPriority.values.firstWhere(
      (e) => e.name == priorityStr,
      orElse: () => RequestPriority.normal,
    );

    return QueuedRequest(
      request: TunnelRequest.fromJson(json['request'] as Map<String, dynamic>),
      priority: priority,
      enqueuedAt: DateTime.parse(json['enqueuedAt'] as String),
      timeoutAt: json['timeoutAt'] != null
          ? DateTime.parse(json['timeoutAt'] as String)
          : null,
    );
  }
}

/// Persistent request queue with priority support
class PersistentRequestQueue {
  final int maxSize;
  final String _persistenceKey = 'tunnel_queued_requests';
  final double _backpressureThreshold = 0.8; // 80%

  // Priority queue using SplayTreeSet for automatic sorting
  final SplayTreeSet<QueuedRequest> _queue = SplayTreeSet<QueuedRequest>();

  // Stream controller for backpressure signals
  final StreamController<BackpressureSignal> _backpressureController =
      StreamController<BackpressureSignal>.broadcast();

  // Track timeout removals
  int _timeoutRemovals = 0;

  PersistentRequestQueue({
    this.maxSize = 100,
  });

  /// Get current queue size
  int get size => _queue.length;

  /// Check if queue is full
  bool get isFull => _queue.length >= maxSize;

  /// Check if queue is empty
  bool get isEmpty => _queue.isEmpty;

  /// Get queue fill percentage (0.0 to 1.0)
  double get fillPercentage => _queue.length / maxSize;

  /// Stream of backpressure signals
  Stream<BackpressureSignal> get backpressureStream =>
      _backpressureController.stream;

  /// Get count of timed out requests removed
  int get timeoutRemovals => _timeoutRemovals;

  /// Enqueue a request with priority
  Future<void> enqueue(
    TunnelRequest request, {
    RequestPriority priority = RequestPriority.normal,
  }) async {
    // Check if queue is full
    if (isFull) {
      throw QueueFullException(
        'Request queue is full (max: $maxSize). Request ${request.id} dropped.',
      );
    }

    // Calculate timeout
    final timeoutAt = DateTime.now().add(request.timeout);

    // Create queued request
    final queuedRequest = QueuedRequest(
      request: request,
      priority: priority,
      timeoutAt: timeoutAt,
    );

    // Add to queue
    _queue.add(queuedRequest);

    // Persist high-priority requests
    if (priority == RequestPriority.high) {
      await _persistRequest(queuedRequest);
    }

    // Check for backpressure
    _checkBackpressure();
  }

  /// Dequeue the highest priority request
  Future<TunnelRequest?> dequeue() async {
    if (_queue.isEmpty) return null;

    // Remove timed out requests first
    await _removeTimedOutRequests();

    if (_queue.isEmpty) return null;

    // Get first (highest priority) request
    final queuedRequest = _queue.first;
    _queue.remove(queuedRequest);

    // Remove from persistence if it was persisted
    await _removePersisted(queuedRequest.request.id);

    return queuedRequest.request;
  }

  /// Peek at the next request without removing it
  TunnelRequest? peek() {
    if (_queue.isEmpty) return null;
    return _queue.first.request;
  }

  /// Clear all requests from queue
  Future<void> clear() async {
    _queue.clear();
    await _clearPersistence();
  }

  /// Remove timed out requests from queue
  Future<int> _removeTimedOutRequests() async {
    final timedOut = _queue.where((q) => q.isTimedOut).toList();

    for (final request in timedOut) {
      _queue.remove(request);
      await _removePersisted(request.request.id);
      _timeoutRemovals++;
    }

    return timedOut.length;
  }

  /// Get all timed out requests and remove them
  Future<List<TunnelRequest>> removeTimedOutRequests() async {
    final timedOut = _queue.where((q) => q.isTimedOut).toList();
    final requests = <TunnelRequest>[];

    for (final queuedRequest in timedOut) {
      _queue.remove(queuedRequest);
      await _removePersisted(queuedRequest.request.id);
      requests.add(queuedRequest.request);
      _timeoutRemovals++;
    }

    return requests;
  }

  /// Persist a request to disk
  Future<void> _persistRequest(QueuedRequest queuedRequest) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_persistenceKey) ?? [];

      // Add new request
      existing.add(jsonEncode(queuedRequest.toJson()));

      // Save back to preferences
      await prefs.setStringList(_persistenceKey, existing);
    } catch (e) {
      // Log error but don't throw - persistence is best-effort
      debugPrint('Failed to persist request ${queuedRequest.request.id}: $e');
    }
  }

  /// Remove a persisted request by ID
  Future<void> _removePersisted(String requestId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_persistenceKey) ?? [];

      // Filter out the request with matching ID
      final filtered = existing.where((jsonStr) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final request = json['request'] as Map<String, dynamic>;
          return request['id'] != requestId;
        } catch (e) {
          // Keep malformed entries for now
          return true;
        }
      }).toList();

      await prefs.setStringList(_persistenceKey, filtered);
    } catch (e) {
      debugPrint('Failed to remove persisted request $requestId: $e');
    }
  }

  /// Clear all persisted requests
  Future<void> _clearPersistence() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_persistenceKey);
    } catch (e) {
      debugPrint('Failed to clear persisted requests: $e');
    }
  }

  /// Restore persisted requests from disk
  Future<int> restorePersistedRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getStringList(_persistenceKey) ?? [];
      int restored = 0;

      for (final jsonStr in persisted) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final queuedRequest = QueuedRequest.fromJson(json);

          // Only restore if not timed out and queue has space
          if (!queuedRequest.isTimedOut && !isFull) {
            _queue.add(queuedRequest);
            restored++;
          }
        } catch (e) {
          // Skip corrupted entries
          debugPrint('Skipping corrupted persisted request: $e');
        }
      }

      // Persist remaining (overflow + malformed-skipped) entries for later restoration
      final remaining = <String>[];
      for (final jsonStr in persisted) {
        try {
          final json = jsonDecode(jsonStr) as Map<String, dynamic>;
          final queuedRequest = QueuedRequest.fromJson(json);
          // If this request was not restored (overflow or timed out), keep in persistence
          if (!_queue.any((q) => q.request.id == queuedRequest.request.id)) {
            remaining.add(jsonStr);
          }
        } catch (_) {
          // Skip corrupted entries — don't persist malformed data
        }
      }

      if (remaining.isEmpty) {
        await _clearPersistence();
      } else {
        await prefs.setStringList(_persistenceKey, remaining);
      }

      return restored;
    } catch (e) {
      debugPrint('Failed to restore persisted requests: $e');
      return 0;
    }
  }

  /// Check for backpressure and emit signal if needed
  void _checkBackpressure() {
    final fill = fillPercentage;

    if (fill >= _backpressureThreshold) {
      final signal = BackpressureSignal(
        queueFillPercentage: fill,
        shouldThrottle: true,
        message: 'Queue is ${(fill * 100).toInt()}% full. '
            'Consider slowing down request rate.',
      );
      _backpressureController.add(signal);
    }
  }

  /// Get queue statistics
  Map<String, dynamic> getStatistics() {
    final priorityCounts = <String, int>{
      'high': 0,
      'normal': 0,
      'low': 0,
    };

    for (final queuedRequest in _queue) {
      priorityCounts[queuedRequest.priority.name] =
          (priorityCounts[queuedRequest.priority.name] ?? 0) + 1;
    }

    return {
      'size': size,
      'maxSize': maxSize,
      'fillPercentage': fillPercentage,
      'isEmpty': isEmpty,
      'isFull': isFull,
      'priorityCounts': priorityCounts,
      'timeoutRemovals': _timeoutRemovals,
    };
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _backpressureController.close();
  }
}
