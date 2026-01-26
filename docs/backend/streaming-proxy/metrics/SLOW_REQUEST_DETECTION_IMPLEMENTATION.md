# Slow Request Detection Implementation

## Task 12.4: Implement slow request detection

### Status: COMPLETE ✓

This document describes the implementation of slow request detection for the streaming proxy server.

## Requirements Met

### 1. Enhance ServerMetricsCollector to track request duration ✓

**File**: `services/streaming-proxy/src/metrics/server-metrics-collector.ts`

The `ServerMetricsCollector` class has been enhanced with:

- `recordRequest()` method that accepts request duration (latency) as a parameter
- Integration with `SlowRequestDetector` to track slow requests
- Request history tracking with timestamps

```typescript
recordRequest(
  userId: string,
  latency: number,           // Request duration in milliseconds
  success: boolean,
  errorType?: string,
  bytesReceived?: number,
  bytesSent?: number,
  requestId?: string,
  endpoint?: string
): void
```

### 2. Log requests exceeding 5 seconds using ConsoleLogger ✓

**File**: `services/streaming-proxy/src/metrics/slow-request-detector.ts`

The `SlowRequestDetector` class logs slow requests using `ConsoleLogger`:

- Threshold: 5000ms (configurable)
- Log level: WARN
- Logged when `duration >= slowThresholdMs`

```typescript
this.logger.warn('Slow request detected', {
  userId,
  requestId,
  duration,
  endpoint,
  threshold: this.config.slowThresholdMs,
});
```

### 3. Include request details in logs: userId, requestId, duration, endpoint ✓

**File**: `services/streaming-proxy/src/metrics/slow-request-detector.ts`

All required fields are included in the log metadata:

- `userId`: User identifier
- `requestId`: Unique request identifier
- `duration`: Request duration in milliseconds
- `endpoint`: API endpoint (optional)
- `threshold`: Slow request threshold for context

Example log output:

```
[SlowRequestDetector] WARN: Slow request detected {
  userId: 'user123',
  requestId: 'request-abc',
  duration: 6000,
  endpoint: '/api/endpoint',
  threshold: 5000
}
```

### 4. Calculate slow request rate (slow requests / total requests) ✓

**File**: `services/streaming-proxy/src/metrics/slow-request-detector.ts`

Method: `getSlowRequestRate(): number`

- Calculates the ratio of slow requests to total requests
- Returns a decimal value (0.0 to 1.0)
- Filters to the configured time window (default: 5 minutes)

```typescript
getSlowRequestRate(): number {
  const now = Date.now();
  const cutoff = now - this.config.windowMs;
  const recentSlowRequests = this.slowRequests.filter(
    r => r.timestamp.getTime() > cutoff
  );
  return recentSlowRequests.length / Math.max(this.totalRequests, 1);
}
```

### 5. Alert (log warning) when slow request rate exceeds 10% over 5-minute window ✓

**File**: `services/streaming-proxy/src/metrics/slow-request-detector.ts`

Method: `checkAndAlert(): void`

- Checks if slow request rate exceeds threshold (default: 10%)
- Logs warning when threshold is exceeded
- Implements 1-minute cooldown between alerts to prevent alert spam
- Includes detailed statistics in alert

Alert log output:

```
[SlowRequestDetector] WARN: High slow request rate detected! {
  slowRequestRate: 0.15,
  threshold: 0.1,
  totalSlowRequests: 3,
  averageDuration: 6000,
  maxDuration: 7000,
  windowMinutes: 5
}
```

### 6. Add slow_requests_total metric to Prometheus endpoint ✓

**File**: `services/streaming-proxy/src/metrics/slow-request-detector.ts`

Method: `exportPrometheusMetrics(): string`

Exports the following Prometheus metrics:

- `tunnel_slow_requests_total`: Total number of slow requests (counter)
- `tunnel_slow_request_rate`: Rate of slow requests (gauge)
- `tunnel_slow_request_duration_avg_ms`: Average duration of slow requests (gauge)
- `tunnel_slow_request_duration_max_ms`: Maximum duration of slow requests (gauge)
- `tunnel_slow_requests_by_user_total`: Slow requests by user (counter with labels)

Example Prometheus output:

```
# HELP tunnel_slow_requests_total Total number of slow requests
# TYPE tunnel_slow_requests_total counter
tunnel_slow_requests_total 3

# HELP tunnel_slow_request_rate Rate of slow requests
# TYPE tunnel_slow_request_rate gauge
tunnel_slow_request_rate 0.1500

# HELP tunnel_slow_request_duration_avg_ms Average duration of slow requests
# TYPE tunnel_slow_request_duration_avg_ms gauge
tunnel_slow_request_duration_avg_ms 6000.00

# HELP tunnel_slow_request_duration_max_ms Maximum duration of slow requests
# TYPE tunnel_slow_request_duration_max_ms gauge
tunnel_slow_request_duration_max_ms 7000.00

# HELP tunnel_slow_requests_by_user_total Slow requests by user
# TYPE tunnel_slow_requests_by_user_total counter
tunnel_slow_requests_by_user_total{user_id="user1"} 2
tunnel_slow_requests_by_user_total{user_id="user2"} 1
```

## Implementation Details

### SlowRequestDetector Class

**Location**: `services/streaming-proxy/src/metrics/slow-request-detector.ts`

#### Configuration

```typescript
interface SlowRequestDetectorConfig {
  slowThresholdMs: number;      // Default: 5000ms
  alertThresholdRate: number;   // Default: 0.1 (10%)
  windowMs: number;             // Default: 300000ms (5 minutes)
  maxHistorySize: number;       // Default: 1000 records
}
```

#### Key Methods

1. **trackRequest(userId, requestId, duration, endpoint?)**
   - Records a request and checks if it's slow
   - Logs slow requests with all required fields
   - Triggers alert check

2. **getSlowRequestRate()**
   - Returns the rate of slow requests in the current window
   - Used for alert threshold checking

3. **getSlowRequestCount()**
   - Returns the count of slow requests in the current window

4. **getSlowRequestsByUser(userId)**
   - Returns slow requests for a specific user

5. **getStatistics()**
   - Returns comprehensive statistics including:
     - Total slow requests
     - Slow request rate
     - Average duration
     - Maximum duration
     - Slowest request details
     - Slow requests by user

6. **exportPrometheusMetrics()**
   - Exports metrics in Prometheus text format
   - Included in the `/api/tunnel/metrics` endpoint

7. **cleanup()**
   - Removes records outside the retention window

8. **reset()**
   - Clears all statistics

### ServerMetricsCollector Integration

**Location**: `services/streaming-proxy/src/metrics/server-metrics-collector.ts`

The `ServerMetricsCollector` integrates `SlowRequestDetector`:

```typescript
export class ServerMetricsCollector implements MetricsCollector {
  private slowRequestDetector: SlowRequestDetector;

  constructor(...) {
    this.slowRequestDetector = new SlowRequestDetector();
  }

  recordRequest(
    userId: string,
    latency: number,
    success: boolean,
    errorType?: string,
    bytesReceived?: number,
    bytesSent?: number,
    requestId?: string,
    endpoint?: string
  ): void {
    // ... existing code ...
    
    // Track slow requests
    if (requestId) {
      this.slowRequestDetector.trackRequest(userId, requestId, latency, endpoint);
    }
  }

  exportPrometheusFormat(): string {
    // ... existing metrics ...
    
    // Add slow request metrics
    lines.push('');
    lines.push(this.slowRequestDetector.exportPrometheusMetrics());
    
    return lines.join('\n');
  }
}
```

### Prometheus Endpoint Integration

**Location**: `services/streaming-proxy/src/server.ts`

The `/api/tunnel/metrics` endpoint automatically includes slow request metrics:

```typescript
app.get('/api/tunnel/metrics', (req: Request, res: Response) => {
  try {
    const prometheusMetrics = metricsCollector.exportPrometheusFormat();
    res.setHeader('Content-Type', 'text/plain; version=0.0.4');
    res.status(200).send(prometheusMetrics);
  } catch (error) {
    logger.error('Error exporting Prometheus metrics:', error);
    res.status(500).json({ error: 'Failed to export metrics' });
  }
});
```

## Usage Example

### Recording a Request

```typescript
// When a request completes
const startTime = Date.now();
// ... process request ...
const duration = Date.now() - startTime;

metricsCollector.recordRequest(
  'user123',           // userId
  duration,            // latency in milliseconds
  true,                // success
  undefined,           // errorType
  1024,                // bytesReceived
  2048,                // bytesSent
  'req-abc-123',       // requestId
  '/api/endpoint'      // endpoint
);
```

### Accessing Metrics

```typescript
// Get slow request statistics
const stats = metricsCollector.getServerMetrics();
console.log(`Slow requests: ${stats.slowRequestCount}`);
console.log(`Slow request rate: ${(stats.slowRequestRate * 100).toFixed(1)}%`);

// Get Prometheus metrics
const prometheusMetrics = metricsCollector.exportPrometheusFormat();
// Use with Prometheus scraper
```

### Monitoring

The slow request metrics are available at:

- **Prometheus endpoint**: `GET /api/tunnel/metrics`
- **JSON endpoint**: `GET /api/tunnel/metrics/json`

Example Prometheus query:

```promql
# Get slow request rate
tunnel_slow_request_rate

# Get slow requests by user
tunnel_slow_requests_by_user_total

# Alert on high slow request rate
ALERT HighSlowRequestRate
  IF tunnel_slow_request_rate > 0.1
  FOR 5m
```

## Testing

### Unit Tests

**File**: `services/streaming-proxy/src/metrics/slow-request-detector.test.ts`

Comprehensive test suite covering:

- Slow request detection and logging
- Rate calculation
- Statistics generation
- Prometheus metrics export
- Alert mechanism
- Cleanup and reset functionality

### Verification Script

**File**: `services/streaming-proxy/src/metrics/verify-slow-request-detection.ts`

Verification script that confirms:

- All required methods are implemented
- Integration with ServerMetricsCollector
- Logging includes all required fields
- Prometheus metrics are exported correctly
- Alert mechanism is functional

## Configuration

### Environment Variables

The slow request detector can be configured via environment variables (future enhancement):

```bash
# Slow request threshold in milliseconds (default: 5000)
SLOW_REQUEST_THRESHOLD_MS=5000

# Alert threshold rate (default: 0.1 = 10%)
SLOW_REQUEST_ALERT_THRESHOLD=0.1

# Time window for rate calculation in milliseconds (default: 300000 = 5 minutes)
SLOW_REQUEST_WINDOW_MS=300000

# Maximum history size (default: 1000)
SLOW_REQUEST_MAX_HISTORY=1000
```

## Performance Considerations

1. **Memory Usage**: Slow request records are stored in memory with a configurable limit (default: 1000)
2. **CPU Usage**: Minimal overhead - only processes slow requests
3. **Cleanup**: Automatic cleanup runs every hour to remove old records
4. **Alert Cooldown**: 1-minute cooldown between alerts to prevent spam

## Future Enhancements

1. Persist slow request data to database for long-term analysis
2. Integration with alerting systems (PagerDuty, Slack, etc.)
3. Configurable alert thresholds per user or endpoint
4. Slow request analysis dashboard
5. Automatic performance tuning recommendations

## References

- **Requirement**: 3.8 - Track and log slow requests (>5 seconds)
- **Related Requirements**: 3.1, 3.2, 3.4, 3.6, 3.7, 3.10, 11.1, 11.6
- **Prometheus Format**: https://prometheus.io/docs/instrumenting/exposition_formats/
