# Tunnel Failover Quick Reference

## Overview

Automatic failover system for tunnel endpoints with priority-based and weighted load balancing.

**Validates: Requirements 4.4**

## Key Concepts

### Endpoint Selection Priority

1. **Health Status**: Healthy endpoints only (fallback to highest priority if none healthy)
2. **Priority**: Higher priority first (0 = lowest, higher = better)
3. **Weight**: Weighted round-robin within same priority (1 = normal, 2 = twice as likely)

### Failure Tracking

- **Threshold**: 3 consecutive failures before marking unhealthy
- **Recovery**: Automatic checks every 60 seconds
- **Success**: Decrements failure count

## API Quick Reference

### Get Best Endpoint

```bash
GET /api/tunnels/{tunnelId}/failover/endpoint
```

Returns the best available endpoint for routing requests.

### Get Failover Status

```bash
GET /api/tunnels/{tunnelId}/failover/status
```

Returns detailed status of all endpoints and failover state.

### Manual Failover

```bash
POST /api/tunnels/{tunnelId}/failover/manual
Body: { "endpointId": "uuid" }
```

Manually trigger failover to specific endpoint.

### Record Failure

```bash
POST /api/tunnels/{tunnelId}/failover/record-failure
Body: { "endpointId": "uuid", "error": "message" }
```

Record endpoint failure (internal use).

### Record Success

```bash
POST /api/tunnels/{tunnelId}/failover/record-success
Body: { "endpointId": "uuid" }
```

Record successful request (internal use).

### Reset Failures

```bash
POST /api/tunnels/{tunnelId}/failover/reset-failures
Body: { "endpointId": "uuid" }
```

Reset failure count for endpoint.

## Configuration

```javascript
// In TunnelFailoverService
failoverService.failoverThreshold = 3;           // Failures before unhealthy
failoverService.recoveryCheckInterval = 60000;   // Recovery check interval (ms)
```

## Example: Creating Tunnel with Multiple Endpoints

```javascript
const tunnelData = {
  name: 'My Tunnel',
  endpoints: [
    { url: 'http://primary:8000', priority: 2, weight: 1 },
    { url: 'http://secondary1:8001', priority: 1, weight: 2 },
    { url: 'http://secondary2:8002', priority: 1, weight: 1 }
  ]
};

const tunnel = await tunnelService.createTunnel(userId, tunnelData, ip, agent);
```

## Example: Using Failover in Request Handler

```javascript
// 1. Get best endpoint
const endpoint = await failoverService.selectEndpoint(tunnelId);

// 2. Make request
try {
  const response = await fetch(endpoint.url, options);
  
  // 3. Record success
  await failoverService.recordEndpointSuccess(endpoint.id);
  
} catch (error) {
  // 4. Record failure
  await failoverService.recordEndpointFailure(
    endpoint.id,
    tunnelId,
    error.message
  );
}
```

## Endpoint Status Values

- **healthy**: Endpoint is responding normally
- **unhealthy**: Endpoint has exceeded failure threshold
- **unknown**: Endpoint health not yet determined

## Failure Count Behavior

| Failures | Status | Action |
|----------|--------|--------|
| 0-2 | healthy | Normal operation |
| 3+ | unhealthy | Marked unhealthy, recovery checks start |
| Success | -1 | Failure count decremented |

## Recovery Process

1. Endpoint marked unhealthy after 3 failures
2. Recovery interval started (checks every 60 seconds)
3. Health check performed on endpoint
4. If healthy: endpoint restored, recovery stops
5. If unhealthy: continues checking

## Weighted Selection Example

With 3 endpoints at same priority:

- Weight 1: ~25% selection rate
- Weight 2: ~50% selection rate
- Weight 1: ~25% selection rate

Total weight = 4, so each unit = 25%

## Troubleshooting

| Issue | Solution |
|-------|----------|
| All endpoints unhealthy | Check endpoint URLs and connectivity |
| Endpoint not recovering | Wait 60 seconds, check endpoint health |
| High failure rate | Check endpoint load, increase threshold |
| Wrong endpoint selected | Verify priority and weight settings |

## Files

- **Service**: `services/tunnel-failover-service.js`
- **Routes**: `routes/tunnel-failover.js`
- **Tests**: `test/api-backend/tunnel-failover.test.js`
- **Docs**: `TUNNEL_FAILOVER_IMPLEMENTATION.md`

## Test Results

✓ 13 tests passing

- Failure tracking
- Weighted selection
- Recovery checks
- Failure count reset
- Cleanup operations

## Related

- Tunnel Service: `services/tunnel-service.js`
- Tunnel Health Service: `services/tunnel-health-service.js`
- Tunnel Routes: `routes/tunnels.js`
