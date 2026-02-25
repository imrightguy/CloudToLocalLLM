# Inline Code Documentation Guide

This guide provides standards and examples for adding inline documentation to the tunnel system codebase.

## TypeScript/Node.js Documentation (JSDoc)

### Class Documentation

```typescript
/**
 * Manages WebSocket connections for the tunnel system.
 * 
 * Handles connection lifecycle, heartbeat monitoring, and message routing.
 * Implements automatic reconnection with exponential backoff.
 * 
 * @example
 * const handler = new WebSocketHandler(connectionPool, authMiddleware);
 * await handler.handleUpgrade(req, socket, head);
 * 
 * @see {@link ConnectionPool} for connection management
 * @see {@link AuthMiddleware} for authentication
 */
export class WebSocketHandler {
  // ...
}
```

### Method Documentation

```typescript
/**
 * Handles WebSocket upgrade request from client.
 * 
 * Validates JWT token, creates WebSocket connection, and starts heartbeat.
 * Implements automatic reconnection on connection loss.
 * 
 * @param req - HTTP request object
 * @param socket - Network socket
 * @param head - First packet of upgraded stream
 * @returns Promise that resolves when connection is established
 * @throws {TunnelError} If authentication fails or connection setup fails
 * 
 * @example
 * try {
 *   await handler.handleUpgrade(req, socket, head);
 * } catch (error) {
 *   console.error('Upgrade failed:', error.message);
 * }
 * 
 * @remarks
 * - Validates JWT token on every upgrade
 * - Enforces per-user connection limits
 * - Starts heartbeat monitoring (30-second interval)
 * - Logs connection events for audit trail
 */
async handleUpgrade(
  req: Request,
  socket: Socket,
  head: Buffer
): Promise<void> {
  // Implementation
}
```

### Property Documentation

```typescript
/**
 * Maximum number of concurrent connections per user.
 * 
 * Prevents resource exhaustion from single user.
 * Configurable per user tier (free: 1, premium: 3, enterprise: 10).
 * 
 * @default 3
 * @see {@link UserTier} for tier definitions
 */
private maxConnectionsPerUser: number = 3;
```

### Complex Algorithm Documentation

#### Exponential Backoff with Jitter

```typescript
/**
 * Calculates exponential backoff delay with jitter.
 * 
 * Formula: delay = min(baseDelay * 2^(attempt-1) * (1 + jitter), maxDelay)
 * 
 * Where:
 * - baseDelay: Initial delay (2 seconds)
 * - attempt: Reconnection attempt number (1-based)
 * - jitter: Random variation (0-30%) to prevent thundering herd
 * - maxDelay: Maximum delay cap (60 seconds)
 * 
 * @param attempt - Reconnection attempt number (1-based)
 * @returns Delay in milliseconds
 * 
 * @example
 * // Attempt 1: ~2 seconds
 * calculateBackoff(1); // Returns ~2000ms
 * 
 * // Attempt 2: ~4 seconds
 * calculateBackoff(2); // Returns ~4000ms
 * 
 * // Attempt 3: ~8 seconds
 * calculateBackoff(3); // Returns ~8000ms
 * 
 * // Attempt 10: ~60 seconds (capped)
 * calculateBackoff(10); // Returns ~60000ms
 * 
 * @remarks
 * - Jitter prevents synchronized retries from multiple clients
 * - Exponential growth reduces server load during recovery
 * - Maximum delay prevents excessive wait times
 * - Used for reconnection and request retry logic
 */
private calculateBackoff(attempt: number): number {
  const baseDelay = 2000; // 2 seconds
  const maxDelay = 60000; // 60 seconds
  const jitterFactor = 0.3; // 30% jitter
  
  // Calculate exponential delay
  const exponentialDelay = baseDelay * Math.pow(2, attempt - 1);
  
  // Add jitter (random 0-30%)
  const jitter = Math.random() * jitterFactor;
  const delayWithJitter = exponentialDelay * (1 + jitter);
  
  // Cap at maximum delay
  return Math.min(delayWithJitter, maxDelay);
}
```

#### Circuit Breaker State Machine

```typescript
/**
 * Circuit breaker state machine implementation.
 * 
 * States:
 * - CLOSED: Normal operation, requests forwarded
 * - OPEN: Failure threshold exceeded, requests blocked
 * - HALF_OPEN: Testing recovery, limited requests allowed
 * 
 * Transitions:
 * - CLOSED -> OPEN: When failureCount >= failureThreshold
 * - OPEN -> HALF_OPEN: After resetTimeout (60 seconds)
 * - HALF_OPEN -> CLOSED: When successCount >= successThreshold
 * - HALF_OPEN -> OPEN: When failureCount >= 1
 * 
 * @example
 * // Normal operation
 * breaker.state === CircuitState.CLOSED; // true
 * 
 * // After 5 failures
 * breaker.state === CircuitState.OPEN; // true
 * 
 * // After 60 seconds
 * breaker.state === CircuitState.HALF_OPEN; // true
 * 
 * // After 2 successes
 * breaker.state === CircuitState.CLOSED; // true
 * 
 * @remarks
 * - Prevents cascading failures
 * - Allows backend to recover
 * - Provides clear failure signals
 * - Metrics tracked for monitoring
 */
class CircuitBreaker {
  private state: CircuitState = CircuitState.CLOSED;
  private failureCount = 0;
  private successCount = 0;
  
  // Implementation
}
```

#### Token Bucket Rate Limiter

```typescript
/**
 * Token bucket rate limiting algorithm.
 * 
 * Concept:
 * - Bucket starts with N tokens (capacity)
 * - Each request consumes 1 token
 * - Tokens refill at rate R per second
 * - Request allowed if tokens available
 * 
 * Formula:
 * - tokens = min(capacity, tokens + (now - lastRefill) * rate)
 * - allowed = tokens >= 1
 * - tokens -= 1 (if allowed)
 * 
 * @example
 * // Limit: 100 requests per minute
 * const limiter = new RateLimiter(100, 60000);
 * 
 * // First 100 requests allowed
 * for (let i = 0; i < 100; i++) {
 *   limiter.checkLimit(); // Returns true
 * }
 * 
 * // 101st request blocked
 * limiter.checkLimit(); // Returns false
 * 
 * // After 1 minute, tokens refilled
 * await sleep(60000);
 * limiter.checkLimit(); // Returns true
 * 
 * @remarks
 * - Smooth rate limiting (no burst blocking)
 * - Efficient O(1) time complexity
 * - Supports burst traffic (up to capacity)
 * - Per-user and per-IP limits
 */
class RateLimiter {
  private tokens: number;
  private lastRefill: number = Date.now();
  
  constructor(
    private capacity: number,
    private refillInterval: number
  ) {
    this.tokens = capacity;
  }
  
  checkLimit(): boolean {
    // Implementation
  }
}
```

### Design Pattern Documentation

#### Connection Pool Pattern

```typescript
/**
 * Connection pool pattern for SSH connection management.
 * 
 * Purpose:
 * - Reuse SSH connections across multiple requests
 * - Reduce connection overhead and latency
 * - Enforce per-user connection limits
 * - Automatic cleanup of idle connections
 * 
 * Architecture:
 * ```
 * User 1 ──┐
 * User 2 ──┼──> Connection Pool ──> SSH Server
 * User 3 ──┘
 * ```
 * 
 * Features:
 * - Per-user connection management
 * - Max 3 connections per user
 * - Automatic cleanup after 5 minutes idle
 * - Health monitoring
 * - Graceful shutdown
 * 
 * @example
 * const pool = new ConnectionPool();
 * 
 * // Get connection for user
 * const conn = await pool.getConnection('user-123');
 * 
 * // Use connection
 * const response = await conn.forward(request);
 * 
 * // Release connection
 * pool.releaseConnection('user-123', conn);
 * 
 * // Cleanup
 * await pool.closeAllConnections();
 * 
 * @remarks
 * - Connections are reused for efficiency
 * - Each user has isolated connections
 * - Idle connections cleaned up automatically
 * - Graceful shutdown waits for in-flight requests
 */
class ConnectionPool {
  // Implementation
}
```

#### Request Queue Pattern

```typescript
/**
 * Request queue pattern for handling network interruptions.
 * 
 * Purpose:
 * - Buffer requests during network issues
 * - Persist high-priority requests to disk
 * - Automatically flush after reconnection
 * - Implement backpressure when queue full
 * 
 * Priority Levels:
 * - HIGH: Interactive user requests (persisted)
 * - NORMAL: Batch operations (in-memory)
 * - LOW: Background tasks (in-memory)
 * 
 * Backpressure:
 * - Signal when queue reaches 80% capacity
 * - Application should throttle requests
 * - Prevents memory exhaustion
 * 
 * @example
 * const queue = new RequestQueue(100); // Max 100 requests
 * 
 * // Enqueue request
 * await queue.enqueue(request, RequestPriority.HIGH);
 * 
 * // Check backpressure
 * if (queue.fillPercentage > 0.8) {
 *   // Throttle requests
 * }
 * 
 * // Dequeue and process
 * const req = await queue.dequeue();
 * 
 * // After reconnection
 * await queue.restorePersistedRequests();
 * 
 * @remarks
 * - High-priority requests persisted to disk
 * - Automatic flush after reconnection
 * - Backpressure prevents overflow
 * - Configurable queue size
 */
class RequestQueue {
  // Implementation
}
```

#### Metrics Collector Pattern

```typescript
/**
 * Metrics collector pattern for performance monitoring.
 * 
 * Purpose:
 * - Collect performance metrics
 * - Aggregate metrics over time windows
 * - Export metrics in Prometheus format
 * - Track per-user and system-wide metrics
 * 
 * Metrics Collected:
 * - Request count and success rate
 * - Latency (average, p95, p99)
 * - Error counts by category
 * - Connection metrics
 * - Throughput
 * 
 * Export Formats:
 * - Prometheus text format (for scraping)
 * - JSON format (for APIs)
 * - Custom format (for dashboards)
 * 
 * @example
 * const collector = new MetricsCollector();
 * 
 * // Record request
 * collector.recordRequest({
 *   latency: 45,
 *   success: true,
 * });
 * 
 * // Get metrics
 * const metrics = collector.getMetrics();
 * console.log(metrics.averageLatency); // 45ms
 * 
 * // Export for Prometheus
 * const prometheus = collector.exportPrometheusFormat();
 * 
 * @remarks
 * - Metrics aggregated over time windows
 * - Percentile calculations (p95, p99)
 * - Per-user metrics tracking
 * - Efficient memory usage
 */
class MetricsCollector {
  // Implementation
}
```

## Dart/Flutter Documentation (Dartdoc)

### Class Documentation

```dart
/// Manages tunnel connections from the client side.
///
/// Handles connection lifecycle, reconnection logic, and request forwarding.
/// Implements exponential backoff for reconnection attempts.
/// Extends [ChangeNotifier] for reactive state management.
///
/// Example:
/// ```dart
/// final tunnelService = TunnelService();
/// await tunnelService.connect(
///   serverUrl: 'wss://proxy.example.com',
///   authToken: authToken,
/// );
/// ```
///
/// See also:
/// - [RequestQueue] for request buffering
/// - [MetricsCollector] for performance tracking
/// - [TunnelConfig] for configuration options
class TunnelService extends ChangeNotifier {
  // ...
}
```

### Method Documentation

```dart
/// Establishes a tunnel connection to the streaming proxy server.
///
/// Validates the JWT token, establishes WebSocket connection, and starts
/// heartbeat monitoring. Implements automatic reconnection with exponential
/// backoff if connection is lost.
///
/// Parameters:
/// - [serverUrl]: WebSocket URL of the streaming proxy
/// - [authToken]: JWT authentication token from Auth0
/// - [config]: Optional custom configuration; uses default if not provided
///
/// Returns: Future that completes when connection is established
///
/// Throws:
/// - [TunnelError] with category [TunnelErrorCategory.network] if connection fails
/// - [TunnelError] with category [TunnelErrorCategory.authentication] if token is invalid
/// - [TunnelError] with category [TunnelErrorCategory.configuration] if config is invalid
///
/// Example:
/// ```dart
/// try {
///   await tunnelService.connect(
///     serverUrl: 'wss://proxy.cloudtolocalllm.online',
///     authToken: authToken,
///     config: TunnelConfig.stableNetwork(),
///   );
///   print('Connected to tunnel');
/// } on TunnelError catch (e) {
///   print('Connection failed: ${e.userMessage}');
/// }
/// ```
///
/// See also:
/// - [disconnect] for closing the connection
/// - [reconnect] for manual reconnection
/// - [TunnelConfig] for configuration options
Future<void> connect({
  required String serverUrl,
  required String authToken,
  TunnelConfig? config,
}) async {
  // Implementation
}
```

### Property Documentation

```dart
/// Current connection state of the tunnel.
///
/// Possible values:
/// - [TunnelConnectionState.disconnected]: Not connected
/// - [TunnelConnectionState.connecting]: Connection in progress
/// - [TunnelConnectionState.connected]: Connected and ready
/// - [TunnelConnectionState.reconnecting]: Attempting to reconnect
/// - [TunnelConnectionState.error]: Connection error
///
/// This property is observable via [ChangeNotifier] listeners.
///
/// Example:
/// ```dart
/// tunnelService.addListener(() {
///   if (tunnelService.connectionState == TunnelConnectionState.connected) {
///     print('Tunnel is ready');
///   }
/// });
/// ```
TunnelConnectionState get connectionState => _connectionState;
```

### Complex Algorithm Documentation

#### Exponential Backoff with Jitter

```dart
/// Calculates exponential backoff delay with jitter.
///
/// Formula: delay = min(baseDelay * 2^(attempt-1) * (1 + jitter), maxDelay)
///
/// Where:
/// - baseDelay: Initial delay (2 seconds)
/// - attempt: Reconnection attempt number (1-based)
/// - jitter: Random variation (0-30%) to prevent thundering herd
/// - maxDelay: Maximum delay cap (60 seconds)
///
/// Parameters:
/// - [attempt]: Reconnection attempt number (1-based)
///
/// Returns: Delay as [Duration]
///
/// Examples:
/// ```dart
/// // Attempt 1: ~2 seconds
/// calculateBackoff(1); // Returns Duration(milliseconds: 2000)
///
/// // Attempt 2: ~4 seconds
/// calculateBackoff(2); // Returns Duration(milliseconds: 4000)
///
/// // Attempt 3: ~8 seconds
/// calculateBackoff(3); // Returns Duration(milliseconds: 8000)
///
/// // Attempt 10: ~60 seconds (capped)
/// calculateBackoff(10); // Returns Duration(milliseconds: 60000)
/// ```
///
/// Remarks:
/// - Jitter prevents synchronized retries from multiple clients
/// - Exponential growth reduces server load during recovery
/// - Maximum delay prevents excessive wait times
/// - Used for reconnection and request retry logic
Duration calculateBackoff(int attempt) {
  const baseDelay = Duration(seconds: 2);
  const maxDelay = Duration(seconds: 60);
  const jitterFactor = 0.3; // 30% jitter
  
  // Calculate exponential delay
  final exponentialMs = baseDelay.inMilliseconds * pow(2, attempt - 1);
  
  // Add jitter (random 0-30%)
  final jitter = Random().nextDouble() * jitterFactor;
  final delayWithJitterMs = exponentialMs * (1 + jitter);
  
  // Cap at maximum delay
  final finalMs = min(delayWithJitterMs.toInt(), maxDelay.inMilliseconds);
  return Duration(milliseconds: finalMs);
}
```

#### Circuit Breaker State Machine

```dart
/// Circuit breaker state machine implementation.
///
/// States:
/// - [CircuitState.closed]: Normal operation, requests forwarded
/// - [CircuitState.open]: Failure threshold exceeded, requests blocked
/// - [CircuitState.halfOpen]: Testing recovery, limited requests allowed
///
/// Transitions:
/// - CLOSED -> OPEN: When failureCount >= failureThreshold
/// - OPEN -> HALF_OPEN: After resetTimeout (60 seconds)
/// - HALF_OPEN -> CLOSED: When successCount >= successThreshold
/// - HALF_OPEN -> OPEN: When failureCount >= 1
///
/// Example:
/// ```dart
/// // Normal operation
/// breaker.state == CircuitState.closed; // true
///
/// // After 5 failures
/// breaker.state == CircuitState.open; // true
///
/// // After 60 seconds
/// breaker.state == CircuitState.halfOpen; // true
///
/// // After 2 successes
/// breaker.state == CircuitState.closed; // true
/// ```
///
/// Remarks:
/// - Prevents cascading failures
/// - Allows backend to recover
/// - Provides clear failure signals
/// - Metrics tracked for monitoring
class CircuitBreaker {
  // Implementation
}
```

#### Token Bucket Rate Limiter

```dart
/// Token bucket rate limiting algorithm.
///
/// Concept:
/// - Bucket starts with N tokens (capacity)
/// - Each request consumes 1 token
/// - Tokens refill at rate R per second
/// - Request allowed if tokens available
///
/// Formula:
/// - tokens = min(capacity, tokens + (now - lastRefill) * rate)
/// - allowed = tokens >= 1
/// - tokens -= 1 (if allowed)
///
/// Example:
/// ```dart
/// // Limit: 100 requests per minute
/// final limiter = RateLimiter(100, Duration(minutes: 1));
///
/// // First 100 requests allowed
/// for (int i = 0; i < 100; i++) {
///   limiter.checkLimit(); // Returns true
/// }
///
/// // 101st request blocked
/// limiter.checkLimit(); // Returns false
///
/// // After 1 minute, tokens refilled
/// await Future.delayed(Duration(minutes: 1));
/// limiter.checkLimit(); // Returns true
/// ```
///
/// Remarks:
/// - Smooth rate limiting (no burst blocking)
/// - Efficient O(1) time complexity
/// - Supports burst traffic (up to capacity)
/// - Per-user and per-IP limits
class RateLimiter {
  // Implementation
}
```

### Design Pattern Documentation

#### Connection Pool Pattern

```dart
/// Connection pool pattern for SSH connection management.
///
/// Purpose:
/// - Reuse SSH connections across multiple requests
/// - Reduce connection overhead and latency
/// - Enforce per-user connection limits
/// - Automatic cleanup of idle connections
///
/// Architecture:
/// ```
/// User 1 ──┐
/// User 2 ──┼──> Connection Pool ──> SSH Server
/// User 3 ──┘
/// ```
///
/// Features:
/// - Per-user connection management
/// - Max 3 connections per user
/// - Automatic cleanup after 5 minutes idle
/// - Health monitoring
/// - Graceful shutdown
///
/// Example:
/// ```dart
/// final pool = ConnectionPool();
///
/// // Get connection for user
/// final conn = await pool.getConnection('user-123');
///
/// // Use connection
/// final response = await conn.forward(request);
///
/// // Release connection
/// pool.releaseConnection('user-123', conn);
///
/// // Cleanup
/// await pool.closeAllConnections();
/// ```
///
/// Remarks:
/// - Connections are reused for efficiency
/// - Each user has isolated connections
/// - Idle connections cleaned up automatically
/// - Graceful shutdown waits for in-flight requests
class ConnectionPool {
  // Implementation
}
```

#### Request Queue Pattern

```dart
/// Request queue pattern for handling network interruptions.
///
/// Purpose:
/// - Buffer requests during network issues
/// - Persist high-priority requests to disk
/// - Automatically flush after reconnection
/// - Implement backpressure when queue full
///
/// Priority Levels:
/// - [RequestPriority.high]: Interactive user requests (persisted)
/// - [RequestPriority.normal]: Batch operations (in-memory)
/// - [RequestPriority.low]: Background tasks (in-memory)
///
/// Backpressure:
/// - Signal when queue reaches 80% capacity
/// - Application should throttle requests
/// - Prevents memory exhaustion
///
/// Example:
/// ```dart
/// final queue = RequestQueue(100); // Max 100 requests
///
/// // Enqueue request
/// await queue.enqueue(request, RequestPriority.high);
///
/// // Check backpressure
/// if (queue.fillPercentage > 0.8) {
///   // Throttle requests
/// }
///
/// // Dequeue and process
/// final req = await queue.dequeue();
///
/// // After reconnection
/// await queue.restorePersistedRequests();
/// ```
///
/// Remarks:
/// - High-priority requests persisted to disk
/// - Automatic flush after reconnection
/// - Backpressure prevents overflow
/// - Configurable queue size
class RequestQueue {
  // Implementation
}
```

#### Metrics Collector Pattern

```dart
/// Metrics collector pattern for performance monitoring.
///
/// Purpose:
/// - Collect performance metrics
/// - Aggregate metrics over time windows
/// - Export metrics in Prometheus format
/// - Track per-user and system-wide metrics
///
/// Metrics Collected:
/// - Request count and success rate
/// - Latency (average, p95, p99)
/// - Error counts by category
/// - Connection metrics
/// - Throughput
///
/// Export Formats:
/// - Prometheus text format (for scraping)
/// - JSON format (for APIs)
/// - Custom format (for dashboards)
///
/// Example:
/// ```dart
/// final collector = MetricsCollector();
///
/// // Record request
/// collector.recordRequest(
///   latency: Duration(milliseconds: 45),
///   success: true,
/// );
///
/// // Get metrics
/// final metrics = collector.getMetrics();
/// print(metrics.averageLatency); // 45ms
///
/// // Export for Prometheus
/// final prometheus = collector.exportPrometheusFormat();
/// ```
///
/// Remarks:
/// - Metrics aggregated over time windows
/// - Percentile calculations (p95, p99)
/// - Per-user metrics tracking
/// - Efficient memory usage
class MetricsCollector {
  // Implementation
}
```

## Error Handling Documentation

### TypeScript Error Documentation

```typescript
/**
 * Tunnel error with categorization and recovery suggestions.
 * 
 * Categories:
 * - network: DNS, connection refused, timeout
 * - authentication: Invalid token, expired token
 * - configuration: Invalid settings, missing config
 * - server: Server error, unavailable
 * - protocol: SSH error, WebSocket error
 * - unknown: Unexpected errors
 * 
 * @example
 * try {
 *   await tunnelService.connect(serverUrl, token);
 * } catch (error) {
 *   if (error instanceof TunnelError) {
 *     console.error(`Error: ${error.userMessage}`);
 *     console.error(`Suggestion: ${error.suggestion}`);
 *     console.error(`Code: ${error.code}`);
 *   }
 * }
 */
class TunnelError extends Error {
  constructor(
    public code: string,
    public message: string,
    public category: TunnelErrorCategory,
    public userMessage: string,
    public suggestion?: string
  ) {
    super(message);
  }
}
```

### Dart Error Documentation

```dart
/// Tunnel error with categorization and recovery suggestions.
///
/// Categories:
/// - [TunnelErrorCategory.network]: DNS, connection refused, timeout
/// - [TunnelErrorCategory.authentication]: Invalid token, expired token
/// - [TunnelErrorCategory.configuration]: Invalid settings, missing config
/// - [TunnelErrorCategory.server]: Server error, unavailable
/// - [TunnelErrorCategory.protocol]: SSH error, WebSocket error
/// - [TunnelErrorCategory.unknown]: Unexpected errors
///
/// Example:
/// ```dart
/// try {
///   await tunnelService.connect(serverUrl, token);
/// } catch (error) {
///   if (error is TunnelError) {
///     print('Error: ${error.userMessage}');
///     print('Suggestion: ${error.suggestion}');
///     print('Code: ${error.code}');
///   }
/// }
/// ```
class TunnelError implements Exception {
  final String code;
  final String message;
  final TunnelErrorCategory category;
  final String userMessage;
  final String? suggestion;
  
  TunnelError({
    required this.code,
    required this.message,
    required this.category,
    required this.userMessage,
    this.suggestion,
  });
}
```

## Configuration Documentation

### TypeScript Configuration

```typescript
/**
 * Tunnel system configuration.
 * 
 * WebSocket Configuration:
 * - port: Server port (default: 3001)
 * - path: WebSocket path (default: /ws)
 * - pingInterval: Heartbeat interval in ms (default: 30000)
 * - pongTimeout: Pong response timeout in ms (default: 5000)
 * - maxFrameSize: Maximum frame size in bytes (default: 1MB)
 * - compression: Enable permessage-deflate (default: true)
 * 
 * SSH Configuration:
 * - keepAliveInterval: SSH keep-alive interval in ms (default: 60000)
 * - maxChannelsPerConnection: Max channels per connection (default: 10)
 * - compression: Enable SSH compression (default: true)
 * - algorithms: SSH algorithms (kex, cipher, mac)
 * 
 * Rate Limiting:
 * - global: Global rate limits
 * - perUser: Per-user limits by tier
 * - perIp: Per-IP limits for DDoS protection
 * 
 * @example
 * const config: ServerConfig = {
 *   websocket: {
 *     port: 3001,
 *     path: '/ws',
 *     pingInterval: 30000,
 *     pongTimeout: 5000,
 *     maxFrameSize: 1048576,
 *     compression: true,
 *   },
 *   ssh: {
 *     keepAliveInterval: 60000,
 *     maxChannelsPerConnection: 10,
 *     compression: true,
 *     algorithms: {
 *       kex: ['curve25519-sha256'],
 *       cipher: ['aes256-gcm@openssh.com'],
 *       mac: ['hmac-sha2-256'],
 *     },
 *   },
 *   rateLimit: {
 *     global: { requestsPerMinute: 10000 },
 *     perUser: {
 *       free: { requestsPerMinute: 100 },
 *       premium: { requestsPerMinute: 1000 },
 *     },
 *   },
 * };
 */
interface ServerConfig {
  // ...
}
```

### Dart Configuration

```dart
/// Tunnel system configuration.
///
/// Predefined Profiles:
/// - [TunnelConfig.stableNetwork]: For stable, high-speed networks
/// - [TunnelConfig.unstableNetwork]: For unstable, low-speed networks
/// - [TunnelConfig.lowBandwidth]: For low-bandwidth connections
///
/// Custom Configuration:
/// - maxReconnectAttempts: Max reconnection attempts (default: 5)
/// - reconnectBaseDelay: Base delay for exponential backoff (default: 2s)
/// - requestTimeout: Request timeout (default: 30s)
/// - maxQueueSize: Max queued requests (default: 100)
/// - enableCompression: Enable WebSocket compression (default: true)
/// - enableAutoReconnect: Enable automatic reconnection (default: true)
/// - logLevel: Logging level (default: info)
///
/// Example:
/// ```dart
/// final config = TunnelConfig(
///   maxReconnectAttempts: 8,
///   reconnectBaseDelay: Duration(seconds: 3),
///   requestTimeout: Duration(seconds: 45),
///   maxQueueSize: 150,
///   enableCompression: true,
///   enableAutoReconnect: true,
///   logLevel: LogLevel.debug,
/// );
/// ```
class TunnelConfig {
  // ...
}
```

## Best Practices

1. **Be Descriptive**: Explain what, why, and how
2. **Include Examples**: Show common usage patterns
3. **Document Edge Cases**: Explain special behaviors
4. **Link Related Code**: Use @see/@link for cross-references
5. **Explain Algorithms**: Document complex logic with formulas
6. **Document Patterns**: Explain design patterns used
7. **Include Remarks**: Add important notes and caveats
8. **Keep Updated**: Update docs when code changes
9. **Use Consistent Format**: Follow JSDoc/Dartdoc standards
10. **Test Examples**: Ensure code examples are correct

## Tools

- **TypeScript**: JSDoc with TypeScript support
- **Dart**: Dartdoc with markdown support
- **Generation**: `npm run docs` (TypeScript), `dart doc` (Dart)
- **Validation**: `npm run lint` (TypeScript), `dart analyze` (Dart)

## Resources

- [JSDoc Documentation](https://jsdoc.app/)
- [Dartdoc Documentation](https://dart.dev/guides/doc/dartdoc)
- [TypeScript JSDoc Reference](https://www.typescriptlang.org/docs/handbook/jsdoc-supported-types.html)
- [Dart Documentation Comments](https://dart.dev/guides/language/effective-dart/documentation)
