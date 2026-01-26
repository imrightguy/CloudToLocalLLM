# Tunnel Health and Status Tracking - Quick Reference

## Overview

Implements comprehensive tunnel status tracking, health checking, and metrics collection for tunnel endpoints.

**Validates: Requirements 4.2, 4.6**

- Tracks tunnel status and health metrics
- Implements tunnel metrics collection and aggregation

## Key Components

### TunnelHealthService (`services/tunnel-health-service.js`)

Core service for health checking and metrics management.

**Key Methods:**

- `startHealthChecks(tunnelId, intervalMs)` - Start periodic health checks
- `stopHealthChecks(tunnelId)` - Stop health checks
- `performHealthCheck(tunnelId)` - Manually trigger health check
- `checkEndpointHealth(url)` - Check single endpoint health
- `recordRequestMetrics(tunnelId, metrics)` - Record request metrics
- `getAggregatedMetrics(tunnelId)` - Get aggregated metrics
- `flushMetricsToDatabase(tunnelId)` - Persist metrics to database
- `getTunnelStatusSummary(tunnelId, userId)` - Get complete status summary
- `getEndpointHealthStatus(tunnelId, userId)` - Get endpoint health details
- `updateEndpointHealthStatus(endpointId, healthStatus)` - Update health status

### API Routes (`routes/tunnel-health.js`)

REST endpoints for tunnel health and status operations.

**Endpoints:**

- `GET /api/tunnels/:id/status` - Get tunnel status summary
- `GET /api/tunnels/:id/health` - Get endpoint health status
- `POST /api/tunnels/:id/health-check` - Trigger manual health check
- `GET /api/tunnels/:id/metrics` - Get tunnel metrics
- `POST /api/tunnels/:id/metrics/record` - Record request metrics
- `POST /api/tunnels/:id/metrics/flush` - Flush metrics to database

## Database Schema

### tunnel_endpoints Table

```sql
CREATE TABLE tunnel_endpoints (
  id UUID PRIMARY KEY,
  tunnel_id UUID NOT NULL REFERENCES tunnels(id),
  url VARCHAR(255) NOT NULL,
  priority INTEGER DEFAULT 0,
  weight INTEGER DEFAULT 1,
  health_status VARCHAR(50) DEFAULT 'unknown',
  last_health_check TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### tunnels Table (metrics field)

```sql
metrics JSONB DEFAULT '{"requestCount": 0, "successCount": 0, "errorCount": 0, "averageLatency": 0}'
```

## Usage Examples

### Start Health Checks

```javascript
const healthService = new TunnelHealthService();
await healthService.initialize();

// Start health checks every 30 seconds
healthService.startHealthChecks(tunnelId, 30000);
```

### Record Metrics

```javascript
// Record successful request
healthService.recordRequestMetrics(tunnelId, {
  latency: 150,
  success: true,
  statusCode: 200,
});

// Record failed request
healthService.recordRequestMetrics(tunnelId, {
  latency: 5000,
  success: false,
  statusCode: 500,
});
```

### Get Metrics

```javascript
const metrics = healthService.getAggregatedMetrics(tunnelId);
console.log(metrics);
// {
//   requestCount: 10,
//   successCount: 8,
//   errorCount: 2,
//   successRate: 80,
//   averageLatency: 175,
//   minLatency: 100,
//   maxLatency: 250
// }
```

### Flush Metrics

```javascript
// Persist accumulated metrics to database
await healthService.flushMetricsToDatabase(tunnelId);
```

### Get Status Summary

```javascript
const summary = await healthService.getTunnelStatusSummary(tunnelId, userId);
console.log(summary);
// {
//   tunnelId: "...",
//   status: "connected",
//   metrics: { ... },
//   endpoints: {
//     total: 2,
//     healthy: 1,
//     unhealthy: 1,
//     details: [ ... ]
//   },
//   lastUpdated: "2024-01-19T..."
// }
```

## Health Status Values

- `healthy` - Endpoint is responding normally (2xx-3xx status)
- `unhealthy` - Endpoint is not responding or returning errors
- `unknown` - Health status not yet determined

## Tunnel Status Values

- `created` - Tunnel created but not started
- `connecting` - Tunnel is attempting to connect
- `connected` - Tunnel is actively connected
- `disconnected` - Tunnel is disconnected
- `error` - Tunnel encountered an error

## Metrics Fields

- `requestCount` - Total number of requests
- `successCount` - Number of successful requests
- `errorCount` - Number of failed requests
- `successRate` - Percentage of successful requests (0-100)
- `averageLatency` - Average request latency in milliseconds
- `minLatency` - Minimum request latency
- `maxLatency` - Maximum request latency

## Integration Points

### With TunnelService

The health service works alongside TunnelService for complete tunnel management:

```javascript
// Create tunnel
const tunnel = await tunnelService.createTunnel(userId, tunnelData, ip, agent);

// Start health checks
healthService.startHealthChecks(tunnel.id);

// Record metrics as requests are processed
healthService.recordRequestMetrics(tunnel.id, { latency, success, statusCode });

// Get status
const status = await healthService.getTunnelStatusSummary(tunnel.id, userId);
```

### With Middleware

Health checks and metrics can be integrated into request middleware:

```javascript
app.use(async (req, res, next) => {
  const startTime = Date.now();
  
  res.on('finish', () => {
    const latency = Date.now() - startTime;
    const success = res.statusCode < 400;
    
    healthService.recordRequestMetrics(tunnelId, {
      latency,
      success,
      statusCode: res.statusCode,
    });
  });
  
  next();
});
```

## Testing

Run tests with:

```bash
npm test -- test/api-backend/tunnel-health-tracking.test.js
```

Tests cover:

- Tunnel status tracking and transitions
- Endpoint health checking
- Metrics collection and aggregation
- Metrics persistence
- Success rate calculations
- Status summary generation
- Health check lifecycle

## Performance Considerations

- Health checks run asynchronously in intervals
- Metrics are buffered in memory and flushed periodically
- Database queries are indexed for performance
- Health check timeout is 5 seconds per endpoint
- Metrics aggregation is O(1) operation

## Error Handling

- Invalid health status values are rejected
- Tunnel ownership is verified before operations
- Health checks handle network timeouts gracefully
- Metrics recording is non-blocking
- Database errors are logged but don't block requests
