# Proxy Failover and Redundancy - Quick Reference

## Overview

The Proxy Failover Service implements automatic failover and redundancy management for streaming proxy instances. It supports multiple failover strategies, health monitoring, and automatic recovery.

**Validates: Requirements 5.8**

## Key Features

- **Multiple Failover Strategies**: Priority-based, round-robin, least-connections
- **Health Monitoring**: Continuous health checks with configurable thresholds
- **Automatic Failover**: Automatic switching to backup instances on failure
- **Redundancy Management**: Track and manage multiple proxy instances
- **Load Balancing**: Optional load balancing across healthy instances
- **Recovery Management**: Automatic recovery of failed instances

## Database Tables

### proxy_failover_configurations

Stores failover configuration for each proxy:

- `failover_strategy`: Strategy for failover (priority, round_robin, least_connections)
- `health_check_interval_seconds`: How often to check health
- `unhealthy_threshold`: Consecutive failures before marking unhealthy
- `enable_auto_failover`: Enable automatic failover
- `enable_auto_recovery`: Enable automatic recovery

### proxy_instances

Tracks individual proxy instances:

- `instance_name`: Name of the instance
- `priority`: Priority for failover (lower = higher priority)
- `weight`: Weight for load balancing
- `health_status`: Current health (healthy, unhealthy, unknown)
- `consecutive_failures`: Number of consecutive health check failures

### proxy_failover_events

Records failover events:

- `event_type`: Type of event (failover, recovery)
- `source_instance_id`: Instance being failed over from
- `target_instance_id`: Instance being failed over to
- `status`: Event status (pending, in_progress, completed, failed)

### proxy_redundancy_status

Current redundancy status:

- `total_instances`: Total number of instances
- `healthy_instances`: Number of healthy instances
- `active_instance_id`: Currently active instance
- `redundancy_level`: Level of redundancy (single, dual, multi)
- `is_degraded`: Whether operating in degraded mode

## API Endpoints

### Configuration Management

**POST /proxy/failover/config**
Create or update failover configuration

```json
{
  "proxyId": "proxy-123",
  "config": {
    "failoverStrategy": "priority",
    "healthCheckIntervalSeconds": 30,
    "unhealthyThreshold": 3,
    "enableAutoFailover": true
  }
}
```

**GET /proxy/failover/config/:proxyId**
Get failover configuration

### Instance Management

**POST /proxy/instances**
Register a proxy instance

```json
{
  "proxyId": "proxy-123",
  "instanceData": {
    "instanceName": "proxy-instance-1",
    "priority": 100,
    "weight": 100
  }
}
```

**GET /proxy/:proxyId/instances**
Get all instances for a proxy

**PUT /proxy/instances/:instanceId/health**
Update instance health status

```json
{
  "healthStatus": "unhealthy",
  "metrics": {
    "cpuPercent": 85,
    "memoryPercent": 90
  }
}
```

### Failover Operations

**POST /proxy/failover/evaluate**
Evaluate if failover is needed

```json
{
  "proxyId": "proxy-123"
}
```

**POST /proxy/failover/execute** (Admin only)
Execute failover operation

```json
{
  "proxyId": "proxy-123",
  "sourceInstanceId": "instance-1",
  "targetInstanceId": "instance-2",
  "reason": "Instance unhealthy"
}
```

**PUT /proxy/failover/events/:eventId/complete** (Admin only)
Complete a failover event

```json
{
  "status": "completed",
  "durationMs": 1500
}
```

### Redundancy Status

**GET /proxy/:proxyId/redundancy**
Get redundancy status

**PUT /proxy/:proxyId/redundancy** (Admin only)
Update redundancy status

```json
{
  "totalInstances": 2,
  "healthyInstances": 2,
  "activeInstanceId": "instance-1",
  "redundancyLevel": "dual",
  "isDegraded": false
}
```

### Event History

**GET /proxy/:proxyId/failover/events**
Get failover events for a proxy

## Service Methods

### Configuration

- `createFailoverConfiguration(proxyId, userId, config)` - Create/update config
- `getFailoverConfiguration(proxyId)` - Get config

### Instance Management

- `registerProxyInstance(proxyId, userId, instanceData)` - Register instance
- `getProxyInstances(proxyId)` - Get all instances
- `updateInstanceHealth(instanceId, healthStatus, metrics)` - Update health
- `recordInstanceMetrics(instanceId, proxyId, userId, metrics)` - Record metrics

### Failover Operations

- `evaluateFailover(proxyId, userId)` - Evaluate if failover needed
- `executeFailover(proxyId, userId, sourceId, targetId, reason)` - Execute failover
- `completeFailoverEvent(eventId, status, errorMessage, durationMs)` - Complete event

### Redundancy

- `getRedundancyStatus(proxyId)` - Get status
- `updateRedundancyStatus(proxyId, userId, statusData)` - Update status

### Events

- `getFailoverEvents(proxyId, limit)` - Get failover events

## Failover Strategies

### Priority-Based (Default)

Instances are ordered by priority. When active instance fails, switches to next highest priority healthy instance.

### Round-Robin

Cycles through healthy instances in order.

### Least-Connections

Routes to instance with fewest active connections.

## Health Check Configuration

```javascript
{
  healthCheckIntervalSeconds: 30,      // Check every 30 seconds
  healthCheckTimeoutSeconds: 5,        // Timeout after 5 seconds
  unhealthyThreshold: 3,               // Mark unhealthy after 3 failures
  healthyThreshold: 2,                 // Mark healthy after 2 successes
  maxRecoveryAttempts: 3,              // Try to recover 3 times
  recoveryBackoffSeconds: 5            // Wait 5 seconds between attempts
}
```

## Redundancy Levels

- **single**: Single instance (no redundancy)
- **dual**: Two instances (primary + backup)
- **multi**: Three or more instances (full redundancy)

## Error Codes

- `PROXY_FAILOVER_001-019`: Various failover operation errors

## Example Usage

```javascript
import { ProxyFailoverService } from './services/proxy-failover-service.js';

const service = new ProxyFailoverService(db, logger);

// Create failover configuration
const config = await service.createFailoverConfiguration(
  'proxy-123',
  'user-456',
  {
    failoverStrategy: 'priority',
    enableAutoFailover: true,
    unhealthyThreshold: 3
  }
);

// Register instances
const instance1 = await service.registerProxyInstance(
  'proxy-123',
  'user-456',
  {
    instanceName: 'proxy-instance-1',
    priority: 100,
    weight: 100
  }
);

const instance2 = await service.registerProxyInstance(
  'proxy-123',
  'user-456',
  {
    instanceName: 'proxy-instance-2',
    priority: 200,
    weight: 100
  }
);

// Update health status
await service.updateInstanceHealth(instance1.id, 'healthy', {
  cpuPercent: 45,
  memoryPercent: 60
});

// Evaluate failover
const evaluation = await service.evaluateFailover('proxy-123', 'user-456');

if (evaluation.shouldFailover) {
  // Execute failover
  const failoverEvent = await service.executeFailover(
    'proxy-123',
    'user-456',
    evaluation.sourceInstanceId,
    evaluation.targetInstanceId,
    evaluation.reason
  );

  // Complete failover
  await service.completeFailoverEvent(
    failoverEvent.id,
    'completed',
    null,
    1500
  );
}

// Update redundancy status
await service.updateRedundancyStatus('proxy-123', 'user-456', {
  totalInstances: 2,
  healthyInstances: 2,
  activeInstanceId: instance1.id,
  redundancyLevel: 'dual',
  isDegraded: false
});
```

## Integration Points

1. **Health Check Service**: Monitors instance health
2. **Metrics Service**: Collects performance metrics
3. **Webhook Service**: Notifies on failover events
4. **Admin Service**: Provides admin endpoints for manual failover

## Testing

Run tests with:

```bash
npm test -- proxy-failover.test.js
```

## Performance Considerations

- Health checks run at configurable intervals (default 30s)
- Failover events are recorded for audit trail
- Metrics are stored for historical analysis
- In-memory caching for frequently accessed data
- Database indexes on proxy_id, user_id, and status fields

## Security

- All endpoints require JWT authentication
- Failover execution requires admin role
- Audit logging for all failover events
- Health check data is not exposed to non-admin users
