# Tunnel Failover and Multiple Endpoints Implementation

## Overview

This document describes the implementation of tunnel failover and multiple endpoint support for the CloudToLocalLLM API backend. The system provides automatic failover with priority-based and weighted load balancing across multiple tunnel endpoints.

**Validates: Requirements 4.4**

- Supports multiple tunnel endpoints for failover
- Implements endpoint health checking
- Adds automatic failover logic

## Architecture

### Components

1. **TunnelFailoverService** (`services/tunnel-failover-service.js`)
   - Core failover logic and endpoint selection
   - Health status tracking and failure management
   - Recovery check scheduling and management

2. **Tunnel Failover Routes** (`routes/tunnel-failover.js`)
   - API endpoints for failover management
   - Endpoint selection and status retrieval
   - Manual failover and failure recording

3. **Database Schema**
   - `tunnel_endpoints` table with priority, weight, and health status
   - Supports multiple endpoints per tunnel

## Key Features

### 1. Weighted Endpoint Selection

The system selects endpoints based on:

- **Health Status**: Only healthy endpoints are selected (fallback to highest priority if none healthy)
- **Priority**: Higher priority endpoints are preferred
- **Weight**: Within the same priority, weighted round-robin selection is used

```javascript
// Example: 3 endpoints with different priorities and weights
const endpoints = [
  { url: 'http://primary:8000', priority: 2, weight: 1 },      // Primary
  { url: 'http://secondary1:8001', priority: 1, weight: 2 },   // Secondary (preferred)
  { url: 'http://secondary2:8002', priority: 1, weight: 1 },   // Secondary (fallback)
];

// Selection order:
// 1. If primary is healthy, use it
// 2. If primary is unhealthy, use secondary1 (weight 2) or secondary2 (weight 1)
// 3. If all unhealthy, use highest priority (primary)
```

### 2. Automatic Failure Detection

The system tracks endpoint failures:

- Failure count increments on each failure
- After 3 consecutive failures (configurable threshold), endpoint is marked unhealthy
- Recovery checks start automatically for unhealthy endpoints
- Successful requests decrement failure count

```javascript
// Failure tracking
failoverService.recordEndpointFailure(endpointId, tunnelId, 'Connection timeout');
// After 3 failures: endpoint marked unhealthy, recovery checks start

// Success tracking
failoverService.recordEndpointSuccess(endpointId);
// Failure count decremented
```

### 3. Automatic Recovery

Unhealthy endpoints are periodically checked for recovery:

- Recovery checks run every 60 seconds (configurable)
- If endpoint becomes healthy, it's restored to service
- Failure count is reset
- Recovery checks stop

```javascript
// Recovery check process
1. Endpoint marked unhealthy after 3 failures
2. Recovery interval started (60 second checks)
3. Each check performs health check on endpoint
4. If healthy, endpoint restored and recovery stops
5. If still unhealthy, continues checking
```

### 4. Manual Failover

Administrators can manually trigger failover to specific endpoints:

```javascript
// Manual failover to specific endpoint
POST /api/tunnels/:tunnelId/failover/manual
{
  "endpointId": "endpoint-uuid"
}
```

### 5. Failover Status Monitoring

Real-time status of all endpoints:

```javascript
// Get failover status
GET /api/tunnels/:tunnelId/failover/status

Response:
{
  "tunnelId": "tunnel-uuid",
  "endpoints": [
    {
      "id": "endpoint-uuid",
      "url": "http://localhost:8000",
      "priority": 2,
      "weight": 1,
      "healthStatus": "healthy",
      "failureCount": 0,
      "lastFailure": null,
      "isUnhealthy": false,
      "isRecovering": false
    }
  ],
  "summary": {
    "total": 3,
    "healthy": 2,
    "unhealthy": 1,
    "recovering": 1
  }
}
```

## API Endpoints

### 1. Get Best Available Endpoint

```
GET /api/tunnels/:tunnelId/failover/endpoint
```

Returns the best available endpoint based on health, priority, and weight.

**Response:**

```json
{
  "endpoint": {
    "id": "endpoint-uuid",
    "url": "http://localhost:8000",
    "priority": 2,
    "weight": 1,
    "healthStatus": "healthy",
    "lastHealthCheck": "2024-01-19T10:30:00Z"
  }
}
```

### 2. Get Failover Status

```
GET /api/tunnels/:tunnelId/failover/status
```

Returns detailed status of all endpoints and failover state.

### 3. Manual Failover

```
POST /api/tunnels/:tunnelId/failover/manual
```

Manually trigger failover to a specific endpoint.

**Request:**

```json
{
  "endpointId": "endpoint-uuid"
}
```

### 4. Record Endpoint Failure

```
POST /api/tunnels/:tunnelId/failover/record-failure
```

Record a failure for an endpoint (internal use).

**Request:**

```json
{
  "endpointId": "endpoint-uuid",
  "error": "Connection timeout"
}
```

### 5. Record Endpoint Success

```
POST /api/tunnels/:tunnelId/failover/record-success
```

Record a successful request for an endpoint (internal use).

**Request:**

```json
{
  "endpointId": "endpoint-uuid"
}
```

### 6. Reset Endpoint Failures

```
POST /api/tunnels/:tunnelId/failover/reset-failures
```

Reset failure count for an endpoint.

**Request:**

```json
{
  "endpointId": "endpoint-uuid"
}
```

## Configuration

### Failure Threshold

Default: 3 consecutive failures before marking unhealthy

```javascript
failoverService.failoverThreshold = 3;
```

### Recovery Check Interval

Default: 60 seconds between recovery checks

```javascript
failoverService.recoveryCheckInterval = 60000; // milliseconds
```

### Health Check Timeout

Default: 5 seconds for endpoint health checks

```javascript
// In checkEndpointHealth method
const timeoutId = setTimeout(() => controller.abort(), 5000);
```

## Database Schema

### tunnel_endpoints Table

```sql
CREATE TABLE tunnel_endpoints (
  id UUID PRIMARY KEY,
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  url VARCHAR(255) NOT NULL,
  priority INTEGER DEFAULT 0,
  weight INTEGER DEFAULT 1,
  health_status VARCHAR(50) DEFAULT 'unknown' CHECK (health_status IN ('healthy', 'unhealthy', 'unknown')),
  last_health_check TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Usage Examples

### Creating a Tunnel with Multiple Endpoints

```javascript
const tunnelData = {
  name: 'My Tunnel',
  config: {
    maxConnections: 100,
    timeout: 30000,
    compression: true
  },
  endpoints: [
    {
      url: 'http://primary.example.com:8000',
      priority: 2,
      weight: 1
    },
    {
      url: 'http://secondary1.example.com:8001',
      priority: 1,
      weight: 2
    },
    {
      url: 'http://secondary2.example.com:8002',
      priority: 1,
      weight: 1
    }
  ]
};

const tunnel = await tunnelService.createTunnel(userId, tunnelData, ipAddress, userAgent);
```

### Selecting an Endpoint for a Request

```javascript
// Get the best available endpoint
const endpoint = await failoverService.selectEndpoint(tunnelId);

if (!endpoint) {
  throw new Error('No endpoints available');
}

// Use endpoint.url for the request
const response = await fetch(endpoint.url, {
  method: 'POST',
  body: JSON.stringify(data)
});

// Record success or failure
if (response.ok) {
  await failoverService.recordEndpointSuccess(endpoint.id);
} else {
  await failoverService.recordEndpointFailure(
    endpoint.id,
    tunnelId,
    `HTTP ${response.status}`
  );
}
```

### Monitoring Failover Status

```javascript
// Get current failover status
const status = await failoverService.getFailoverStatus(tunnelId, userId);

console.log(`Total endpoints: ${status.summary.total}`);
console.log(`Healthy: ${status.summary.healthy}`);
console.log(`Unhealthy: ${status.summary.unhealthy}`);
console.log(`Recovering: ${status.summary.recovering}`);

// Check individual endpoint status
for (const endpoint of status.endpoints) {
  console.log(`${endpoint.url}: ${endpoint.healthStatus} (failures: ${endpoint.failureCount})`);
}
```

## Testing

### Unit Tests

Run the tunnel failover tests:

```bash
npm test -- test/api-backend/tunnel-failover.test.js
```

### Test Coverage

The test suite covers:

- Failure tracking and threshold detection
- Weighted endpoint selection
- Recovery check management
- Failure count reset
- Cleanup operations

All 13 tests pass successfully.

## Performance Considerations

1. **Weighted Selection**: O(n) where n is number of endpoints in priority group
2. **Failure Tracking**: O(1) using Map for state storage
3. **Recovery Checks**: Configurable interval (default 60 seconds)
4. **Health Checks**: 5-second timeout per endpoint

## Security Considerations

1. **Authorization**: All endpoints require JWT authentication
2. **Input Validation**: Endpoint IDs and tunnel IDs are validated
3. **Rate Limiting**: Standard rate limits apply (100 req/min)
4. **Audit Logging**: Failover events are logged for audit trails

## Future Enhancements

1. **Weighted Health Checks**: Different health check strategies per endpoint
2. **Circuit Breaker Pattern**: More sophisticated failure detection
3. **Metrics Export**: Prometheus metrics for failover events
4. **Webhook Notifications**: Notify on failover events
5. **Adaptive Thresholds**: Dynamic failure thresholds based on load

## Troubleshooting

### All Endpoints Unhealthy

If all endpoints are marked unhealthy:

1. Check endpoint URLs are correct
2. Verify endpoints are accessible
3. Check network connectivity
4. Review failure logs for specific errors
5. Use manual failover to force specific endpoint

### Endpoint Not Recovering

If an unhealthy endpoint doesn't recover:

1. Verify endpoint is actually healthy
2. Check recovery check interval (default 60 seconds)
3. Review health check timeout (default 5 seconds)
4. Check endpoint logs for issues
5. Manually reset failure count if needed

### High Failure Rate

If experiencing high failure rates:

1. Check endpoint performance and load
2. Review network connectivity
3. Increase failure threshold if transient issues
4. Consider adding more endpoints
5. Review timeout settings

## References

- Requirements: 4.4 - Support multiple tunnel endpoints for failover
- Design Document: API Backend Enhancement
- Related Services: TunnelService, TunnelHealthService
