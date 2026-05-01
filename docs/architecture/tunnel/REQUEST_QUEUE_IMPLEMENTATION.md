# Request Queue Implementation

> **Status**: Legacy/fallback request queue notes for the older SSH WebSocket tunnel stack. Current connectivity work should prefer the Tailscale secure device mesh.

This document describes the implementation of the request queue with priority and persistence for the SSH WebSocket tunnel enhancement.

## Overview

The request queue system provides reliable request handling with the following features:

- **Priority-based queuing**: High, normal, and low priority requests
- **Persistence**: High-priority requests are persisted to disk
- **Backpressure management**: Automatic throttling signals when queue fills up
- **Timeout handling**: Automatic removal of timed-out requests
- **Graceful degradation**: Queue continues operating even if persistence fails

## Components

### 1. PersistentRequestQueue

**File**: `persistent_request_queue.dart`

The core queue implementation using a priority queue (SplayTreeSet) for automatic sorting.

**Key Features**:

- Configurable maximum size (default: 100 requests)
- Automatic priority-based ordering
- High-priority request persistence
- Backpressure signal emission at 80% capacity
- Timeout tracking per request
- Queue statistics and monitoring

**Usage**:

```dart
final queue = PersistentRequestQueue(maxSize: 100);

// Enqueue a request
await queue.enqueue(
  request,
  priority: RequestPriority.high,
);

// Dequeue highest priority request
final request = await queue.dequeue();

// Restore persisted requests on startup
final restored = await queue.restorePersistedRequests();

// Monitor backpressure
queue.backpressureStream.listen((signal) {
  if (signal.shouldThrottle) {
    // Slow down request rate
  }
});
```

**Requirements Addressed**:

- 5.1: Priority queue with configurable size
- 5.2: Priority-based request handling
- 5.3: Backpressure signaling at 80% capacity
- 5.4: Queue full handling
- 5.9: High-priority request persistence
- 5.10: Restore persisted requests on startup

### 2. RequestPersistenceManager

**File**: `request_persistence_manager.dart`

Dedicated manager for handling request persistence to SharedPreferences.

**Key Features**:

- Persist individual or multiple requests
- Remove persisted requests by ID
- Restore persisted requests with validation
- Handle corrupted persistence data gracefully
- Repair corrupted storage
- Configurable maximum persisted requests (default: 50)

**Usage**:

```dart
final persistenceManager = RequestPersistenceManager(
  persistenceKey: 'tunnel_queued_requests',
  maxPersistedRequests: 50,
);

// Persist a request
await persistenceManager.persistRequest(queuedRequest);

// Restore on startup
final restored = await persistenceManager.restorePersistedRequests();

// Check for corruption
if (await persistenceManager.isCorrupted()) {
  await persistenceManager.repairCorrupted();
}

// Get statistics
final stats = await persistenceManager.getStatistics();
```

**Requirements Addressed**:

- 5.9: Persist high-priority requests to disk
- 5.10: Restore persisted requests on startup
- Handle corrupted persistence data gracefully

### 3. BackpressureManager

**File**: `backpressure_manager.dart`

Monitors queue capacity and emits throttling signals with recommendations.

**Key Features**:

- Five backpressure levels: none, low, medium, high, critical
- Automatic recommendations: normal, slow down, throttle, pause, drop
- Configurable thresholds (60%, 80%, 90%, 95%)
- Signal cooldown to prevent spam (5 seconds)
- Recommended delays for each level

**Backpressure Levels**:

- **None** (< 60%): Normal operation
- **Low** (60-79%): Slow down by 25%
- **Medium** (80-89%): Throttle by 50%
- **High** (90-94%): Pause new requests
- **Critical** (≥ 95%): Drop low-priority requests

**Usage**:

```dart
final backpressureManager = BackpressureManager(
  queue: queue,
  mediumThreshold: 0.8,
);

// Monitor signals
backpressureManager.signalStream.listen((signal) {
  switch (signal.recommendation) {
    case BackpressureRecommendation.slowDown:
      // Reduce rate by 25%
      break;
    case BackpressureRecommendation.throttle:
      // Reduce rate by 50%
      break;
    case BackpressureRecommendation.pause:
      // Pause new requests
      break;
    case BackpressureRecommendation.drop:
      // Drop low-priority requests
      break;
  }
  
  // Use recommended delay
  if (signal.recommendedDelay != null) {
    await Future.delayed(signal.recommendedDelay!);
  }
});

// Check backpressure on each enqueue
backpressureManager.checkBackpressure();
```

**Requirements Addressed**:

- 5.3: Backpressure signal emission
- 5.4: Queue fill percentage tracking
- Throttling recommendations

### 4. RequestTimeoutHandler

**File**: `request_timeout_handler.dart`

Monitors and handles request timeouts with automatic cleanup.

**Key Features**:

- Periodic timeout checking (default: every 5 seconds)
- Automatic removal of timed-out requests
- Timeout event stream
- Timeout history tracking (last 100 events)
- Generate timeout errors with context
- Statistics and monitoring

**Usage**:

```dart
final timeoutHandler = RequestTimeoutHandler(
  queue: queue,
  checkInterval: Duration(seconds: 5),
);

// Start monitoring
timeoutHandler.startMonitoring();

// Listen for timeout events
timeoutHandler.timeoutStream.listen((event) {
  final error = timeoutHandler.generateTimeoutError(event.request);
  // Handle timeout error
});

// Manual check
final timedOut = await timeoutHandler.checkTimeouts();

// Get statistics
final stats = timeoutHandler.getStatistics();
```

**Requirements Addressed**:

- 5.6: Request timeout tracking
- 8.4: Timeout handling
- Remove timed-out requests from queue
- Generate timeout errors
- Log timeout events

## Data Models

### QueuedRequest

Represents a request in the queue with priority and timeout information.

```dart
class QueuedRequest {
  final TunnelRequest request;
  final RequestPriority priority;
  final DateTime enqueuedAt;
  final DateTime? timeoutAt;
  
  bool get isTimedOut;
  int compareTo(QueuedRequest other); // For priority ordering
}
```

### BackpressureSignal

Basic backpressure signal emitted by PersistentRequestQueue.

```dart
class BackpressureSignal {
  final double queueFillPercentage;
  final bool shouldThrottle;
  final String? message;
}
```

### EnhancedBackpressureSignal

Enhanced signal with levels and recommendations from BackpressureManager.

```dart
class EnhancedBackpressureSignal {
  final double queueFillPercentage;
  final BackpressureLevel level;
  final BackpressureRecommendation recommendation;
  final String message;
  final DateTime timestamp;
  final int queueSize;
  final int maxQueueSize;
  
  bool get shouldThrottle;
  Duration? get recommendedDelay;
}
```

### TimeoutEvent

Represents a timeout event with context.

```dart
class TimeoutEvent {
  final TunnelRequest request;
  final DateTime timeoutAt;
  final DateTime detectedAt;
  final Duration queuedDuration;
}
```

## Integration Example

Here's how to integrate all components together:

```dart
class TunnelRequestManager {
  late final PersistentRequestQueue queue;
  late final BackpressureManager backpressureManager;
  late final RequestTimeoutHandler timeoutHandler;
  late final RequestPersistenceManager persistenceManager;
  
  Future<void> initialize() async {
    // Create queue
    queue = PersistentRequestQueue(maxSize: 100);
    
    // Create managers
    backpressureManager = BackpressureManager(queue: queue);
    timeoutHandler = RequestTimeoutHandler(queue: queue);
    persistenceManager = RequestPersistenceManager();
    
    // Restore persisted requests
    final restored = await queue.restorePersistedRequests();
    debugPrint('Restored $restored persisted requests');
    
    // Start timeout monitoring
    timeoutHandler.startMonitoring();
    
    // Listen for backpressure
    backpressureManager.signalStream.listen(_handleBackpressure);
    
    // Listen for timeouts
    timeoutHandler.timeoutStream.listen(_handleTimeout);
  }
  
  Future<void> enqueueRequest(
    TunnelRequest request, {
    RequestPriority priority = RequestPriority.normal,
  }) async {
    try {
      await queue.enqueue(request, priority: priority);
      backpressureManager.checkBackpressure();
    } on QueueFullException catch (e) {
      // Handle queue full
      throw TunnelError(
        category: TunnelErrorCategory.server,
        code: TunnelErrorCodes.queueFull,
        message: e.message,
      );
    }
  }
  
  Future<TunnelRequest?> dequeueRequest() async {
    return await queue.dequeue();
  }
  
  void _handleBackpressure(EnhancedBackpressureSignal signal) {
    if (signal.shouldThrottle) {
      // Notify UI or adjust request rate
      debugPrint('Backpressure: ${signal.message}');
    }
  }
  
  void _handleTimeout(TimeoutEvent event) {
    final error = timeoutHandler.generateTimeoutError(event.request);
    // Log or handle timeout error
    debugPrint('Request timeout: ${error.message}');
  }
  
  Future<void> dispose() async {
    timeoutHandler.stopMonitoring();
    await backpressureManager.dispose();
    await timeoutHandler.dispose();
    await queue.dispose();
  }
}
```

## Testing

### Unit Tests

Test each component independently:

```dart
// Test priority ordering
test('should dequeue high priority requests first', () async {
  final queue = PersistentRequestQueue(maxSize: 10);
  
  await queue.enqueue(request1, priority: RequestPriority.normal);
  await queue.enqueue(request2, priority: RequestPriority.high);
  await queue.enqueue(request3, priority: RequestPriority.low);
  
  final first = await queue.dequeue();
  expect(first?.id, request2.id); // High priority
});

// Test backpressure
test('should emit backpressure signal at 80%', () async {
  final queue = PersistentRequestQueue(maxSize: 10);
  final manager = BackpressureManager(queue: queue);
  
  final signals = <EnhancedBackpressureSignal>[];
  manager.signalStream.listen(signals.add);
  
  // Fill to 80%
  for (int i = 0; i < 8; i++) {
    await queue.enqueue(createTestRequest());
    manager.checkBackpressure();
  }
  
  expect(signals.isNotEmpty, isTrue);
  expect(signals.last.level, BackpressureLevel.medium);
});

// Test timeout handling
test('should remove timed out requests', () async {
  final queue = PersistentRequestQueue(maxSize: 10);
  final handler = RequestTimeoutHandler(queue: queue);
  
  final request = TunnelRequest(
    id: '1',
    userId: 'user1',
    payload: Uint8List(10),
    timeout: Duration(milliseconds: 100),
  );
  
  await queue.enqueue(request);
  await Future.delayed(Duration(milliseconds: 200));
  
  final timedOut = await handler.checkTimeouts();
  expect(timedOut.length, 1);
  expect(queue.size, 0);
});
```

## Performance Considerations

1. **Queue Size**: Default 100 requests. Adjust based on memory constraints and expected load.

2. **Persistence**: Only high-priority requests are persisted to minimize I/O overhead.

3. **Timeout Checking**: Default 5-second interval. Adjust based on timeout durations and responsiveness needs.

4. **Backpressure Cooldown**: 5-second cooldown prevents signal spam while maintaining responsiveness.

5. **Memory Usage**:
   - Queue: ~1KB per request × 100 = ~100KB
   - Timeout history: ~1KB per event × 100 = ~100KB
   - Total: ~200KB for queue system

## Error Handling

All components handle errors gracefully:

1. **Persistence Failures**: Logged but don't block queue operations
2. **Corrupted Data**: Skipped during restoration with logging
3. **Queue Full**: Throws QueueFullException for caller to handle
4. **Timeout Errors**: Generated with full context for debugging

## Monitoring and Observability

Each component provides statistics:

```dart
// Queue statistics
final queueStats = queue.getStatistics();
// {
//   'size': 45,
//   'maxSize': 100,
//   'fillPercentage': 0.45,
//   'isEmpty': false,
//   'isFull': false,
//   'priorityCounts': {'high': 10, 'normal': 30, 'low': 5},
//   'timeoutRemovals': 3
// }

// Backpressure statistics
final backpressureStats = backpressureManager.getStatistics();

// Timeout statistics
final timeoutStats = timeoutHandler.getStatistics();

// Persistence statistics
final persistenceStats = await persistenceManager.getStatistics();
```

## Future Enhancements

1. **Metrics Export**: Add Prometheus format export for monitoring
2. **Adaptive Thresholds**: Adjust backpressure thresholds based on system load
3. **Priority Adjustment**: Allow dynamic priority changes for queued requests
4. **Batch Operations**: Add batch enqueue/dequeue for efficiency
5. **Compression**: Compress persisted requests to save storage space

## References

- Requirements: 5.1, 5.2, 5.3, 5.4, 5.6, 5.9, 5.10, 8.4
- Design Document: Section on Request Queuing and Flow Control
- Related Components: TunnelService, ConnectionRecovery, MetricsCollector
