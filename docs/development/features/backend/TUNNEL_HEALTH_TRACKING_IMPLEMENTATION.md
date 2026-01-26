# Tunnel Health and Status Tracking - Implementation Guide

## Overview

This document provides detailed implementation guidance for tunnel health checking, status tracking, and metrics collection.

**Validates: Requirements 4.2, 4.6**

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    API Routes                               │
│              (tunnel-health.js)                             │
├─────────────────────────────────────────────────────────────┤
│  GET /tunnels/:id/status                                    │
│  GET /tunnels/:id/health                                    │
│  POST /tunnels/:id/health-check                             │
│  GET /tunnels/:id/metrics                                   │
│  POST /tunnels/:id/metrics/record                           │
│  POST /tunnels/:id/metrics/flush                            │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│            TunnelHealthService                              │
├─────────────────────────────────────────────────────────────┤
│  Health Checking:                                           │
│  - startHealthChecks()                                      │
│  - stopHealthChecks()                                       │
│  - performHealthCheck()                                     │
│  - checkEndpointHealth()                                    │
│                                                             │
│  Metrics Management:                                        │
│  - recordRequestMetrics()                                   │
│  - getAggregatedMetrics()                                   │
│  - flushMetricsToDatabase()                                 │
│                                                             │
│  Status Tracking:                                           │
│  - getTunnelStatusSummary()                                 │
│  - getEndpointHealthStatus()                                │
│  - updateEndpointHealthStatus()                             │
└────────────────────┬────────────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼──────────┐    ┌────────▼──────────┐
│  In-Memory       │    │   PostgreSQL      │
│  Metrics Buffer  │    │   Database        │
│                  │    │                   │
│  Map<tunnelId,   │    │  tunnels table    │
│    metrics>      │    │  tunnel_endpoints │
│                  │    │  tunnel_activity  │
└──────────────────┘    └───────────────────┘
```

## Implementation Details

### 1. Health Checking System

#### Periodic Health Checks

Health checks run on configurable intervals (default: 30 seconds):

```javascript
// Start health checks
healthService.startHealthChecks(tunnelId, 30000);

// Internally:
// - Fetches all endpoints for tunnel
// - Performs HEAD request to each endpoint
// - Updates health_status in database
// - Logs results
```

#### Endpoint Health Check Logic

```javascript
async checkEndpointHealth(url) {
  try {
    // 5 second timeout
    const response = await fetch(url, {
      method: 'HEAD',
      signal: controller.signal,
    });
    
    // 2xx-3xx = healthy
    if (response.status >= 200 && response.status < 400) {
      return 'healthy';
    }
    return 'unhealthy';
  } catch (error) {
    // Timeout or network error = unhealthy
    return 'unhealthy';
  }
}
```

### 2. Metrics Collection System

#### In-Memory Metrics Buffer

Metrics are accumulated in memory for performance:

```javascript
metricsBuffer = Map<tunnelId, {
  requestCount: number,
  successCount: number,
  errorCount: number,
  totalLatency: number,
  minLatency: number,
  maxLatency: number,
  lastUpdated: Date
}>
```

#### Recording Metrics

```javascript
recordRequestMetrics(tunnelId, { latency, success, statusCode }) {
  // Get or create buffer for tunnel
  if (!buffer) {
    buffer = {
      requestCount: 0,
      successCount: 0,
      errorCount: 0,
      totalLatency: 0,
      minLatency: Infinity,
      maxLatency: 0,
    };
  }
  
  // Update counters
  buffer.requestCount++;
  if (success) buffer.successCount++;
  else buffer.errorCount++;
  
  // Update latency stats
  buffer.totalLatency += latency;
  buffer.minLatency = Math.min(buffer.minLatency, latency);
  buffer.maxLatency = Math.max(buffer.maxLatency, latency);
}
```

#### Aggregating Metrics

```javascript
getAggregatedMetrics(tunnelId) {
  const buffer = metricsBuffer.get(tunnelId);
  
  return {
    requestCount: buffer.requestCount,
    successCount: buffer.successCount,
    errorCount: buffer.errorCount,
    successRate: (buffer.successCount / buffer.requestCount) * 100,
    averageLatency: buffer.totalLatency / buffer.requestCount,
    minLatency: buffer.minLatency,
    maxLatency: buffer.maxLatency,
  };
}
```

#### Flushing to Database

```javascript
async flushMetricsToDatabase(tunnelId) {
  const metrics = this.getAggregatedMetrics(tunnelId);
  
  // Update tunnels table
  await pool.query(
    `UPDATE tunnels SET metrics = $1, updated_at = NOW() WHERE id = $2`,
    [JSON.stringify(metrics), tunnelId]
  );
  
  // Clear buffer
  metricsBuffer.delete(tunnelId);
}
```

### 3. Status Tracking System

#### Tunnel Status Values

```
created ──→ connecting ──→ connected
              ↓              ↓
            error        disconnected
```

#### Status Transitions

```javascript
// Valid transitions
created → connecting
connecting → connected
connecting → error
connected → disconnected
connected → error
disconnected → connecting
error → connecting
```

#### Status Summary

```javascript
async getTunnelStatusSummary(tunnelId, userId) {
  // Get tunnel
  const tunnel = await pool.query(
    `SELECT * FROM tunnels WHERE id = $1 AND user_id = $2`,
    [tunnelId, userId]
  );
  
  // Get endpoints
  const endpoints = await pool.query(
    `SELECT * FROM tunnel_endpoints WHERE tunnel_id = $1`,
    [tunnelId]
  );
  
  // Calculate health summary
  const healthyCount = endpoints.filter(e => e.health_status === 'healthy').length;
  
  return {
    tunnelId,
    status: tunnel.status,
    metrics: JSON.parse(tunnel.metrics),
    endpoints: {
      total: endpoints.length,
      healthy: healthyCount,
      unhealthy: endpoints.length - healthyCount,
      details: endpoints.map(e => ({
        id: e.id,
        url: e.url,
        healthStatus: e.health_status,
        lastHealthCheck: e.last_health_check,
        priority: e.priority,
        weight: e.weight,
      })),
    },
    lastUpdated: tunnel.updated_at,
  };
}
```

## API Endpoints

### GET /api/tunnels/:id/status

Get complete tunnel status summary.

**Response:**

```json
{
  "success": true,
  "data": {
    "tunnelId": "uuid",
    "status": "connected",
    "metrics": {
      "requestCount": 1000,
      "successCount": 950,
      "errorCount": 50,
      "successRate": 95,
      "averageLatency": 125,
      "minLatency": 50,
      "maxLatency": 500
    },
    "endpoints": {
      "total": 2,
      "healthy": 2,
      "unhealthy": 0,
      "details": [
        {
          "id": "uuid",
          "url": "http://localhost:8000",
          "healthStatus": "healthy",
          "lastHealthCheck": "2024-01-19T10:30:00Z",
          "priority": 1,
          "weight": 1
        }
      ]
    },
    "lastUpdated": "2024-01-19T10:30:00Z"
  }
}
```

### GET /api/tunnels/:id/health

Get endpoint health status.

**Response:**

```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "url": "http://localhost:8000",
      "healthStatus": "healthy",
      "lastHealthCheck": "2024-01-19T10:30:00Z",
      "priority": 1,
      "weight": 1
    }
  ]
}
```

### POST /api/tunnels/:id/health-check

Trigger manual health check.

**Response:**

```json
{
  "success": true,
  "data": {
    "tunnelId": "uuid",
    "endpoints": [
      {
        "endpointId": "uuid",
        "url": "http://localhost:8000",
        "healthStatus": "healthy",
        "lastHealthCheck": "2024-01-19T10:30:00Z"
      }
    ],
    "timestamp": "2024-01-19T10:30:00Z"
  }
}
```

### GET /api/tunnels/:id/metrics

Get tunnel metrics.

**Response:**

```json
{
  "success": true,
  "data": {
    "requestCount": 1000,
    "successCount": 950,
    "errorCount": 50,
    "successRate": 95,
    "averageLatency": 125,
    "minLatency": 50,
    "maxLatency": 500
  }
}
```

### POST /api/tunnels/:id/metrics/record

Record request metrics.

**Request:**

```json
{
  "latency": 150,
  "success": true,
  "statusCode": 200
}
```

**Response:**

```json
{
  "success": true,
  "message": "Metrics recorded successfully"
}
```

### POST /api/tunnels/:id/metrics/flush

Flush metrics to database.

**Response:**

```json
{
  "success": true,
  "message": "Metrics flushed successfully"
}
```

## Integration with Middleware

### Request Metrics Middleware

```javascript
app.use((req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const latency = Date.now() - startTime;
    const success = res.statusCode < 400;
    
    // Extract tunnel ID from request
    const tunnelId = req.params.tunnelId || req.body.tunnelId;
    
    if (tunnelId) {
      tunnelHealthService.recordRequestMetrics(tunnelId, {
        latency,
        success,
        statusCode: res.statusCode,
      });
    }
  });
  
  next();
});
```

### Periodic Metrics Flush

```javascript
// Flush metrics every 5 minutes
setInterval(async () => {
  for (const tunnelId of activeTunnels) {
    try {
      await tunnelHealthService.flushMetricsToDatabase(tunnelId);
    } catch (error) {
      logger.error('Failed to flush metrics', { tunnelId, error });
    }
  }
}, 5 * 60 * 1000);
```

## Testing Strategy

### Unit Tests

- Health check logic
- Metrics aggregation
- Status transitions
- Endpoint health determination

### Integration Tests

- End-to-end health checking
- Metrics persistence
- Status summary generation
- API endpoint functionality

### Property-Based Tests

**Property 6: Tunnel state transitions consistency**

- For any tunnel, state transitions should follow valid paths
- Invalid transitions should be rejected

**Property 7: Metrics aggregation consistency**

- For any set of recorded metrics, aggregation should be consistent
- Flushing and retrieving should produce same values

## Performance Optimization

### Metrics Buffering

- Accumulate metrics in memory
- Flush periodically (every 5 minutes)
- Reduces database writes by ~99%

### Health Check Optimization

- Configurable intervals (default: 30 seconds)
- Parallel endpoint checks
- 5-second timeout per endpoint
- Asynchronous, non-blocking

### Database Indexing

```sql
CREATE INDEX idx_tunnel_endpoints_tunnel_id ON tunnel_endpoints(tunnel_id);
CREATE INDEX idx_tunnel_endpoints_health_status ON tunnel_endpoints(health_status);
CREATE INDEX idx_tunnels_status ON tunnels(status);
```

## Error Handling

### Health Check Failures

- Network timeouts → unhealthy
- Connection refused → unhealthy
- Invalid response → unhealthy
- Errors logged but don't block

### Metrics Recording Failures

- Non-blocking operation
- Errors logged
- Metrics buffer continues accumulating

### Database Failures

- Flush failures logged
- Metrics retained in buffer
- Retry on next flush cycle

## Monitoring and Observability

### Metrics to Monitor

- Health check success rate
- Average endpoint response time
- Metrics flush frequency
- Buffer size

### Logging

- Health check results
- Metrics recording
- Status transitions
- Errors and failures

### Alerts

- Endpoint unhealthy for > 5 minutes
- Metrics flush failures
- High error rate (> 10%)
- Tunnel status errors
