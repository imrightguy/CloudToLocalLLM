# Context7 MCP Best Practices Reference

This document consolidates best practices from Context7 MCP tools for key dependencies used in the SSH WebSocket Tunnel Enhancement project.

## WebSocket Library (ws) - Best Practices

**Library ID:** `/websockets/ws`  
**Trust Score:** 6.7  
**Code Snippets:** 65

### Key Best Practices

#### 1. Connection Management

- Always implement heartbeat/ping-pong mechanism to detect dead connections
- Use `readyState` constants (CONNECTING=0, OPEN=1, CLOSING=2, CLOSED=3) to check connection status
- Implement exponential backoff for reconnection attempts
- Reset reconnection delay on successful connection

#### 2. Heartbeat Implementation

```
- Send ping frames every 30 seconds
- Track pong responses with timeout
- Terminate connections that don't respond to pings within timeout
- Use isAlive flag to track connection health
```

#### 3. Frame Handling

- Set maximum frame size limits (1MB recommended)
- Validate frame sizes before processing
- Handle compression with permessage-deflate extension
- Configure compression parameters (level 6 for balance)

#### 4. Connection Lifecycle

- Implement proper close handshake with close codes
- Use close code 1000 for normal closure
- Use close code 1001 for "Going Away" (server shutdown)
- Wait for close acknowledgment before cleanup

#### 5. Error Handling

- Distinguish between connection errors and protocol errors
- Log all errors with context (connection ID, user ID, timestamp)
- Implement graceful degradation on errors
- Provide user-friendly error messages

#### 6. Authentication

- Validate tokens during HTTP upgrade handshake
- Reject connections without valid authentication
- Use timing-safe comparison for token validation
- Cache validation results (5 minutes recommended)

#### 7. Multiple WebSocket Servers

- Route connections based on URL path
- Use noServer mode for custom routing
- Implement separate handlers for different protocols
- Aggregate metrics across servers

---

## SSH2 Library - Best Practices

**Library ID:** `/mscdex/ssh2`  
**Trust Score:** 7.3  
**Code Snippets:** 36

### Key Best Practices

#### 1. SSH Security Configuration

```
- Enforce SSH protocol version 2 only (no SSHv1)
- Use strong key exchange algorithms:
  * curve25519-sha256
  * ecdh-sha2-nistp256
  * ecdh-sha2-nistp384
- Use strong encryption algorithms:
  * aes256-gcm@openssh.com
  * aes256-ctr
  * aes192-ctr
  * aes128-ctr
- Use strong MAC algorithms:
  * hmac-sha2-256
  * hmac-sha2-512
```

#### 2. Connection Management

- Implement SSH keep-alive every 60 seconds
- Track keep-alive responses with timestamps
- Detect dead connections after 3 failed keep-alives (180 seconds)
- Close unresponsive connections automatically

#### 3. Channel Multiplexing

- Enforce channel limits per connection (10 channels recommended)
- Track active channel count
- Increment/decrement on channel open/close
- Throw error when limit exceeded

#### 4. SSH Compression

- Enable compression for bandwidth optimization
- Set compression level to 6 (balanced)
- Monitor compression ratio (bytes sent vs compressed)
- Log compression effectiveness

#### 5. Authentication Methods

- Support multiple auth methods: password, public key, agent
- Use timing-safe comparison for credentials
- Implement keyboard-interactive for MFA
- Cache authentication results appropriately

#### 6. Port Forwarding

- Implement local port forwarding (forwardOut)
- Implement remote port forwarding (forwardIn)
- Validate forwarding requests
- Clean up forwarding on connection close

#### 7. Error Handling

- Categorize SSH errors: auth, protocol, network, timeout, channel
- Log all errors with connection context
- Provide troubleshooting hints for common errors
- Track error frequency for monitoring

#### 8. Connection Hopping/Tunneling

- Support tunneling through intermediate SSH servers
- Use forwardOut to create tunnels
- Implement proper stream piping
- Handle tunnel failures gracefully

---

## Prometheus Client (prom-client) - Best Practices

**Library ID:** `/siimon/prom-client`  
**Trust Score:** Not specified  
**Code Snippets:** 38

### Key Best Practices

#### 1. Metric Types

**Counter** - Only increases, never decreases

- Use for: request counts, error counts, total operations
- Reset on process restart only
- Increment by 1 or specific value

**Gauge** - Can increase or decrease

- Use for: active connections, queue size, memory usage
- Set to specific value or use inc/dec
- Implement collect() for point-in-time observations

**Histogram** - Tracks distribution of values

- Use for: request latency, response size, processing time
- Define buckets based on expected value ranges
- Use startTimer() for automatic duration measurement
- Provides count, sum, and bucket metrics

**Summary** - Calculates percentiles

- Use for: latency percentiles (P50, P95, P99)
- Configure percentiles: [0.5, 0.9, 0.95, 0.99]
- Supports sliding window with maxAgeSeconds
- More memory efficient than histograms for percentiles

#### 2. Bucket Configuration

**Linear Buckets** - Equal spacing

```
linearBuckets(start, width, count)
Example: linearBuckets(0, 100, 11) = [0, 100, 200, ..., 1000]
Use for: response sizes, queue depths
```

**Exponential Buckets** - Exponential growth

```
exponentialBuckets(start, factor, count)
Example: exponentialBuckets(1, 2, 9) = [1, 2, 4, 8, 16, 32, 64, 128, 256]
Use for: latencies spanning multiple orders of magnitude
```

#### 3. Labels and Cardinality

- Use labels for dimensions: method, status, endpoint, user_tier
- Avoid high-cardinality labels (user IDs, request IDs)
- Initialize all expected label combinations with zero()
- Use labelNames as const in TypeScript for type safety

#### 4. Registry Management

- Use default registry for most metrics
- Create custom registries for isolated metric collections
- Merge registries when needed
- Set default labels for all metrics in registry

#### 5. Metric Exposure

- Expose metrics at `/metrics` endpoint
- Use correct Content-Type: `text/plain; version=0.0.4`
- Support OpenMetrics format for advanced features
- Include exemplars for trace correlation

#### 6. Default Metrics

- Enable collectDefaultMetrics() for Node.js runtime metrics
- Configure prefix for metric names
- Add custom labels (app, environment, instance)
- Monitor: GC duration, event loop lag, memory usage

#### 7. Cluster Aggregation

- Use AggregatorRegistry for multi-process aggregation
- Workers collect metrics normally
- Master aggregates worker metrics
- Configure aggregation method: sum, first, min, max, average

#### 8. Performance Considerations

- Minimize metric cardinality
- Use appropriate bucket counts (10-20 typical)
- Implement metric retention policies
- Clean up old metrics periodically

#### 9. Pushgateway Integration

- Push metrics for batch jobs
- Use pushAdd() to add metrics
- Use push() to replace all metrics
- Use delete() to remove metrics
- Configure timeout and connection pooling

---

## Implementation References

### WebSocket Handler Implementation

Reference: `services/streaming-proxy/src/websocket/websocket-handler-impl.ts`

- Implements heartbeat manager for ping/pong
- Handles frame size validation
- Manages compression
- Implements graceful close

### SSH Connection Implementation

Reference: `services/streaming-proxy/src/connection-pool/ssh-connection-impl.ts`

- Configures SSH security algorithms
- Implements keep-alive mechanism
- Manages channel multiplexing
- Handles SSH errors with categorization

### Metrics Collection Implementation

Reference: `services/streaming-proxy/src/metrics/server-metrics-collector.ts`

- Collects tunnel metrics (requests, latency, errors)
- Tracks per-user metrics
- Implements Prometheus endpoint
- Manages metric retention

---

## Error Handling Patterns

### WebSocket Errors

- Connection errors: Network issues, timeout
- Protocol errors: Invalid frames, handshake failures
- Authentication errors: Invalid tokens, expired credentials
- Recovery: Automatic reconnection with backoff

### SSH Errors

- Authentication errors: Invalid credentials, key issues
- Protocol errors: Unsupported algorithms, handshake failures
- Network errors: Connection refused, timeout
- Channel errors: Channel limit exceeded, stream errors
- Recovery: Retry with exponential backoff, fallback to alternative auth

### Metrics Errors

- Collection errors: Metric not found, invalid labels
- Export errors: Serialization failures, format issues
- Recovery: Log error, continue with partial metrics

---

## Monitoring and Observability

### Key Metrics to Track

1. **Connection Metrics**
   - Active connections (gauge)
   - Connection attempts (counter)
   - Connection duration (histogram)

2. **Request Metrics**
   - Total requests (counter)
   - Request latency (histogram/summary)
   - Request size (histogram)
   - Success rate (gauge)

3. **Error Metrics**
   - Error count by type (counter)
   - Error rate (gauge)
   - Error recovery time (histogram)

4. **Resource Metrics**
   - Memory usage (gauge)
   - CPU usage (gauge)
   - Queue size (gauge)
   - Channel count (gauge)

### Alerting Thresholds

- High error rate: > 5% over 5 minutes
- High latency: P95 > 200ms
- Connection storm: > 1000 new connections per minute
- Circuit breaker open: Any open state
- Queue nearly full: > 90% capacity

---

## Development Workflow

### When Implementing WebSocket Features

1. Reference ws library documentation for connection patterns
2. Implement heartbeat mechanism for connection health
3. Add frame size validation
4. Implement proper error handling and logging
5. Test with multiple concurrent connections

### When Implementing SSH Features

1. Configure security algorithms per best practices
2. Implement keep-alive mechanism
3. Add channel multiplexing with limits
4. Implement comprehensive error handling
5. Test with various SSH server configurations

### When Implementing Metrics

1. Define metrics based on monitoring needs
2. Choose appropriate metric types (counter/gauge/histogram/summary)
3. Configure buckets for histograms
4. Initialize all label combinations
5. Expose metrics at /metrics endpoint
6. Test metric collection and export

---

## References

- WebSocket Library: https://github.com/websockets/ws
- SSH2 Library: https://github.com/mscdex/ssh2
- Prometheus Client: https://github.com/siimon/prom-client
- Prometheus Best Practices: https://prometheus.io/docs/practices/
- OpenTelemetry: https://opentelemetry.io/docs/

---

**Last Updated:** November 15, 2025  
**Context7 MCP Integration:** Task 19 - Documentation and Best Practices
