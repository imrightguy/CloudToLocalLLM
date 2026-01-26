# Proxy Metrics Collection - Quick Reference

## Overview

Proxy metrics collection system for tracking and aggregating proxy performance data.

## Service: ProxyMetricsService

### Initialization

```javascript
import ProxyMetricsService from './services/proxy-metrics-service.js';

const metricsService = new ProxyMetricsService();
await metricsService.initialize();
```

### Recording Metrics

```javascript
// Record a metrics event
await metricsService.recordMetricsEvent(
  'proxy-123',           // proxyId
  'user-1',              // userId
  'request',             // eventType: 'request', 'error', 'connection', 'latency'
  {
    requestCount: 100,
    successCount: 95,
    errorCount: 5,
    totalLatencyMs: 5000,
    minLatencyMs: 10,
    maxLatencyMs: 500,
    dataTransferredBytes: 1000000,
    dataReceivedBytes: 500000,
    connectionCount: 50,
    concurrentConnections: 25
  }
);
```

### Retrieving Metrics

#### Daily Metrics for Specific Date

```javascript
const metrics = await metricsService.getProxyMetricsDaily(
  'proxy-123',
  'user-1',
  '2024-01-15'
);
```

#### Daily Metrics for Date Range

```javascript
const metrics = await metricsService.getProxyMetricsDailyRange(
  'proxy-123',
  'user-1',
  '2024-01-01',
  '2024-01-31'
);
```

#### Aggregated Metrics for Period

```javascript
const metrics = await metricsService.getProxyMetricsAggregation(
  'proxy-123',
  'user-1',
  '2024-01-01',
  '2024-01-31'
);
```

### Aggregating Metrics

```javascript
// Aggregate metrics from daily data
const aggregation = await metricsService.aggregateProxyMetrics(
  'proxy-123',
  'user-1',
  '2024-01-01',
  '2024-01-31'
);
```

## REST API Endpoints

### Record Metrics Event

```
POST /proxy/metrics/:proxyId/record
Authorization: Bearer <JWT_TOKEN>

Request Body:
{
  "eventType": "request",
  "metrics": {
    "requestCount": 100,
    "successCount": 95,
    "errorCount": 5,
    "totalLatencyMs": 5000,
    "minLatencyMs": 10,
    "maxLatencyMs": 500
  }
}

Response: 201 Created
{
  "proxyId": "proxy-123",
  "eventType": "request",
  "message": "Metrics event recorded successfully",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Get Daily Metrics

```
GET /proxy/metrics/:proxyId/daily/:date
Authorization: Bearer <JWT_TOKEN>

Response: 200 OK
{
  "proxyId": "proxy-123",
  "date": "2024-01-15",
  "metrics": {
    "requestCount": 1000,
    "successCount": 950,
    "errorCount": 50,
    "averageLatencyMs": 50,
    "minLatencyMs": 10,
    "maxLatencyMs": 500,
    "p95LatencyMs": 150,
    "p99LatencyMs": 300,
    "dataTransferredBytes": 1000000,
    "dataReceivedBytes": 500000,
    "peakConcurrentConnections": 100,
    "averageConcurrentConnections": 50,
    "uptimePercentage": 99.5
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Get Daily Metrics Range

```
GET /proxy/metrics/:proxyId/daily?startDate=2024-01-01&endDate=2024-01-31
Authorization: Bearer <JWT_TOKEN>

Response: 200 OK
{
  "proxyId": "proxy-123",
  "startDate": "2024-01-01",
  "endDate": "2024-01-31",
  "metrics": [
    { /* daily metrics for 2024-01-01 */ },
    { /* daily metrics for 2024-01-02 */ },
    ...
  ],
  "count": 31,
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Get Aggregated Metrics

```
GET /proxy/metrics/:proxyId/aggregation?periodStart=2024-01-01&periodEnd=2024-01-31
Authorization: Bearer <JWT_TOKEN>

Response: 200 OK
{
  "proxyId": "proxy-123",
  "periodStart": "2024-01-01",
  "periodEnd": "2024-01-31",
  "metrics": {
    "totalRequestCount": 30000,
    "totalSuccessCount": 28500,
    "totalErrorCount": 1500,
    "averageLatencyMs": 50,
    "minLatencyMs": 10,
    "maxLatencyMs": 500,
    "p95LatencyMs": 150,
    "p99LatencyMs": 300,
    "totalDataTransferredBytes": 30000000,
    "totalDataReceivedBytes": 15000000,
    "peakConcurrentConnections": 110,
    "averageConcurrentConnections": 55,
    "averageUptimePercentage": 99.6
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Database Tables

### proxy_metrics_events

Raw metric events from proxy instances

- `id` - UUID primary key
- `proxy_id` - Proxy identifier
- `user_id` - User identifier (FK to users)
- `event_type` - Type of event (request, error, connection, latency)
- `request_count` - Number of requests
- `success_count` - Number of successful requests
- `error_count` - Number of failed requests
- `total_latency_ms` - Total latency in milliseconds
- `min_latency_ms` - Minimum latency
- `max_latency_ms` - Maximum latency
- `data_transferred_bytes` - Bytes sent
- `data_received_bytes` - Bytes received
- `connection_count` - Number of connections
- `concurrent_connections` - Concurrent connection count
- `error_message` - Error message if applicable
- `created_at` - Event timestamp

### proxy_metrics_daily

Aggregated daily metrics

- `id` - UUID primary key
- `proxy_id` - Proxy identifier
- `user_id` - User identifier (FK to users)
- `date` - Date (YYYY-MM-DD)
- `request_count` - Total requests for day
- `success_count` - Successful requests
- `error_count` - Failed requests
- `average_latency_ms` - Average latency
- `min_latency_ms` - Minimum latency
- `max_latency_ms` - Maximum latency
- `p95_latency_ms` - 95th percentile latency
- `p99_latency_ms` - 99th percentile latency
- `data_transferred_bytes` - Total bytes sent
- `data_received_bytes` - Total bytes received
- `peak_concurrent_connections` - Peak concurrent connections
- `average_concurrent_connections` - Average concurrent connections
- `uptime_percentage` - Uptime percentage for day
- `created_at` - Record creation time
- `updated_at` - Last update time

### proxy_metrics_aggregation

Period-based aggregated metrics

- Similar structure to daily metrics
- `period_start` - Period start date
- `period_end` - Period end date
- Aggregates data across multiple days

### proxy_metrics_summary

Current summary metrics for quick access

- `proxy_id` - Proxy identifier (unique)
- `user_id` - User identifier (FK to users)
- `request_count_1h` - Requests in last hour
- `request_count_24h` - Requests in last 24 hours
- `success_rate_1h` - Success rate in last hour
- `success_rate_24h` - Success rate in last 24 hours
- `average_latency_ms_1h` - Average latency in last hour
- `average_latency_ms_24h` - Average latency in last 24 hours
- `error_count_1h` - Errors in last hour
- `error_count_24h` - Errors in last 24 hours
- `data_transferred_1h_bytes` - Data transferred in last hour
- `data_transferred_24h_bytes` - Data transferred in last 24 hours
- `concurrent_connections` - Current concurrent connections
- `last_updated` - Last update timestamp

## Error Handling

### Common Errors

- `PROXY_METRICS_001` - Invalid request (missing required fields)
- `PROXY_METRICS_002` - Service unavailable (service not initialized)
- `PROXY_METRICS_003` - Internal server error

### Error Response Format

```json
{
  "error": "ERROR_CODE",
  "message": "Error description",
  "code": "PROXY_METRICS_XXX"
}
```

## Integration Notes

### With Proxy Health Service

Metrics can be collected automatically when health checks are performed:

```javascript
proxyHealthService.updateProxyMetrics(proxyId, {
  requestCount: 100,
  successCount: 95,
  errorCount: 5,
  averageLatency: 50
});
```

### With Monitoring/Dashboards

Metrics can be queried for visualization:

```javascript
const dailyMetrics = await metricsService.getProxyMetricsDailyRange(
  proxyId,
  userId,
  startDate,
  endDate
);
```

### With Billing System

Aggregated metrics can be used for usage-based billing:

```javascript
const aggregation = await metricsService.getProxyMetricsAggregation(
  proxyId,
  userId,
  billingPeriodStart,
  billingPeriodEnd
);
```

## Performance Considerations

- Indexes on `proxy_id`, `user_id`, `date`, and `period_start/period_end` for fast queries
- Daily aggregation reduces storage for historical data
- Summary table for quick access to current metrics
- Transaction support for data consistency during aggregation

## Testing

Run tests:

```bash
npm test -- test/api-backend/proxy-metrics.test.js
```

Test coverage: 78.68% statements, 71.42% branches, 87.5% functions
