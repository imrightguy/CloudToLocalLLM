# Metrics Retention and Aggregation Implementation

## Overview

This document describes the implementation of metrics retention and aggregation for the streaming proxy server. The system stores raw metrics for 1 hour and aggregated metrics for 7 days, supporting multiple aggregation levels (raw, hourly, daily).

## Architecture

### Components

1. **MetricsAggregator** (`metrics-aggregator.ts`)
   - Manages time-series storage with sliding windows
   - Handles raw metrics recording and retention
   - Performs hourly and daily aggregation
   - Implements automatic cleanup

2. **ServerMetricsCollector** (enhanced)
   - Integrates MetricsAggregator
   - Records metric snapshots every minute
   - Provides historical metrics API

3. **Express Routes** (server.ts)
   - `/api/tunnel/metrics/history` - Historical metrics endpoint

## Data Retention

### Raw Metrics

- **Retention**: 1 hour (3,600,000 ms)
- **Recording**: Every minute via metric snapshots
- **Max Size**: 3,600 snapshots (1 per minute for 1 hour)
- **Use Case**: Real-time monitoring and detailed analysis

### Hourly Aggregates

- **Retention**: 7 days (604,800,000 ms)
- **Aggregation**: Hourly from raw metrics
- **Aggregation Interval**: Every hour
- **Use Case**: Daily trend analysis

### Daily Aggregates

- **Retention**: 7 days (604,800,000 ms)
- **Aggregation**: Daily from hourly aggregates
- **Aggregation Interval**: Every hour (calculates daily buckets)
- **Use Case**: Weekly trend analysis

## Aggregation Process

### Hourly Aggregation

Raw metrics are aggregated into hourly buckets:

```
Raw Metrics (1 minute intervals)
    ↓
Hourly Aggregates (60 samples per hour)
    ↓
Aggregated Values:
  - totalRequests: sum of all requests
  - totalSuccessful: sum of successful requests
  - totalErrors: sum of errors
  - averageLatency: average of latencies
  - p95Latency: 95th percentile of p95 values
  - p99Latency: 99th percentile of p99 values
  - totalBytesReceived: sum of bytes
  - totalBytesSent: sum of bytes
  - averageActiveConnections: average connections
  - peakActiveConnections: max connections
  - averageErrorRate: average error rate
  - averageActiveUsers: average active users
```

### Daily Aggregation

Hourly aggregates are aggregated into daily buckets:

```
Hourly Aggregates (24 samples per day)
    ↓
Daily Aggregates (7 samples for 7 days)
    ↓
Aggregated Values:
  - Same metrics as hourly, but for 24-hour window
```

## API Endpoints

### Historical Metrics Endpoint

**GET** `/api/tunnel/metrics/history`

Query Parameters:

- `window` (optional): Time window for data retrieval
  - `1h` (default): Last 1 hour
  - `24h`: Last 24 hours
  - `7d`: Last 7 days
  - Custom: Any millisecond value (e.g., `3600000`)

- `aggregation` (optional): Aggregation level
  - `raw` (default): Raw metrics (1-minute intervals)
  - `hourly`: Hourly aggregates
  - `daily`: Daily aggregates

Response:

```json
{
  "window": "1h",
  "windowMs": 3600000,
  "aggregation": "raw",
  "dataPoints": 60,
  "statistics": {
    "count": 60,
    "averageRequests": 100,
    "totalRequests": 6000,
    "averageLatency": 50,
    "averageErrorRate": 0.05
  },
  "metrics": [
    {
      "timestamp": "2024-01-15T10:00:00.000Z",
      "activeConnections": 10,
      "requestCount": 100,
      "successCount": 95,
      "errorCount": 5,
      "averageLatency": 50,
      "p95Latency": 100,
      "p99Latency": 150,
      "bytesReceived": 1000,
      "bytesSent": 2000,
      "requestsPerSecond": 10,
      "errorRate": 0.05,
      "activeUsers": 5,
      "memoryUsage": 100000000,
      "cpuUsage": 0.5
    },
    ...
  ],
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

### Example Requests

**Get raw metrics for last hour:**

```bash
curl http://localhost:3001/api/tunnel/metrics/history?window=1h&aggregation=raw
```

**Get hourly aggregates for last 24 hours:**

```bash
curl http://localhost:3001/api/tunnel/metrics/history?window=24h&aggregation=hourly
```

**Get daily aggregates for last 7 days:**

```bash
curl http://localhost:3001/api/tunnel/metrics/history?window=7d&aggregation=daily
```

## Cleanup Process

### Automatic Cleanup

Cleanup runs every hour and removes:

1. **Raw Metrics**: Older than 1 hour
2. **Hourly Aggregates**: Older than 7 days
3. **Daily Aggregates**: Older than 7 days

### Cleanup Implementation

```typescript
private cleanup(): void {
  const now = Date.now();
  
  // Clean raw metrics (1 hour retention)
  const rawCutoff = now - 3600000;
  this.rawMetrics = this.rawMetrics.filter(m => m.timestamp.getTime() > rawCutoff);
  
  // Clean hourly aggregates (7 days retention)
  const hourlyCutoff = now - 604800000;
  this.hourlyAggregates = this.hourlyAggregates.filter(
    a => a.windowStart.getTime() > hourlyCutoff
  );
  
  // Clean daily aggregates (7 days retention)
  const dailyCutoff = now - 604800000;
  this.dailyAggregates = this.dailyAggregates.filter(
    a => a.windowStart.getTime() > dailyCutoff
  );
}
```

## Memory Usage

### Estimated Memory Consumption

**Raw Metrics (1 hour):**

- 60 snapshots × ~500 bytes = ~30 KB

**Hourly Aggregates (7 days):**

- 168 aggregates × ~600 bytes = ~100 KB

**Daily Aggregates (7 days):**

- 7 aggregates × ~600 bytes = ~4 KB

**Total**: ~134 KB (minimal impact)

## Performance Characteristics

### Recording Performance

- **Metric Recording**: O(1) - constant time
- **Snapshot Recording**: O(1) - constant time
- **Cleanup**: O(n) - linear in number of metrics

### Query Performance

- **Raw Metrics Query**: O(n) - linear scan with time filter
- **Aggregated Query**: O(n) - linear scan with time filter
- **Statistics Calculation**: O(n) - single pass through data

### Aggregation Performance

- **Hourly Aggregation**: O(n) - processes all raw metrics
- **Daily Aggregation**: O(n) - processes all hourly aggregates
- **Runs**: Every hour (background task)

## Integration with Monitoring

### Prometheus Integration

Historical metrics can be used to:

1. Backfill Prometheus with historical data
2. Analyze trends over time
3. Detect anomalies in metrics

### Grafana Dashboards

Create Grafana dashboards using the historical metrics endpoint:

1. Query `/api/tunnel/metrics/history?window=24h&aggregation=hourly`
2. Plot trends over time
3. Compare daily patterns

## Configuration

### Environment Variables

```bash
# Metrics retention (milliseconds)
METRICS_RAW_RETENTION=3600000        # 1 hour
METRICS_HOURLY_RETENTION=604800000   # 7 days
METRICS_DAILY_RETENTION=604800000    # 7 days

# Aggregation intervals
METRICS_AGGREGATION_INTERVAL=3600000 # 1 hour
METRICS_SNAPSHOT_INTERVAL=60000      # 1 minute

# Cleanup interval
METRICS_CLEANUP_INTERVAL=3600000     # 1 hour
```

## Testing

### Unit Tests

Run tests for metrics aggregation:

```bash
npm test -- metrics-aggregator.test.ts
```

### Integration Tests

Test the historical metrics endpoint:

```bash
# Get raw metrics
curl http://localhost:3001/api/tunnel/metrics/history?window=1h&aggregation=raw

# Get hourly aggregates
curl http://localhost:3001/api/tunnel/metrics/history?window=24h&aggregation=hourly

# Get daily aggregates
curl http://localhost:3001/api/tunnel/metrics/history?window=7d&aggregation=daily
```

## Future Enhancements

1. **Persistent Storage**: Store aggregates in database for long-term retention
2. **Custom Retention**: Allow configurable retention windows per aggregation level
3. **Downsampling**: Implement downsampling for very old data
4. **Compression**: Compress old aggregates to reduce memory usage
5. **Export**: Export historical data to external systems (InfluxDB, Prometheus)

## Requirements Coverage

This implementation satisfies Requirement 3.10:

- ✅ Implement time-series storage in ServerMetricsCollector (in-memory with sliding window)
- ✅ Store raw metrics for 1 hour, aggregated metrics for 7 days
- ✅ Implement hourly aggregation (average latency, total requests, error rate)
- ✅ Implement daily aggregation (same metrics, daily rollup)
- ✅ Create cleanup task to remove old metrics (runs every hour)
- ✅ Create Express route `/api/tunnel/metrics/history` for historical data
- ✅ Support query parameters: window (1h, 24h, 7d), aggregation (raw, hourly, daily)
