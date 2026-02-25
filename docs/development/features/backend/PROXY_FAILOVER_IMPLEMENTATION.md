# Proxy Failover and Redundancy - Implementation Summary

## Overview

This document summarizes the implementation of proxy failover and redundancy management for the CloudToLocalLLM API backend.

**Validates: Requirements 5.8**

## Files Created

### 1. Database Migration

**File**: `database/migrations/015_proxy_failover_and_redundancy.sql`

Creates four main tables:

- `proxy_failover_configurations` - Stores failover settings per proxy
- `proxy_instances` - Tracks individual proxy instances
- `proxy_failover_events` - Records failover operations
- `proxy_redundancy_status` - Current redundancy state
- `proxy_instance_metrics` - Performance metrics per instance

All tables include proper indexes for performance and foreign key constraints for data integrity.

### 2. Service Implementation

**File**: `services/proxy-failover-service.js`

Core service class with methods for:

- **Configuration Management**
  - `createFailoverConfiguration()` - Create/update failover config
  - `getFailoverConfiguration()` - Retrieve config

- **Instance Management**
  - `registerProxyInstance()` - Register new instance
  - `getProxyInstances()` - Get all instances for proxy
  - `updateInstanceHealth()` - Update health status
  - `recordInstanceMetrics()` - Record performance metrics

- **Failover Operations**
  - `evaluateFailover()` - Determine if failover needed
  - `executeFailover()` - Perform failover operation
  - `completeFailoverEvent()` - Mark failover as complete

- **Redundancy Management**
  - `getRedundancyStatus()` - Get current redundancy state
  - `updateRedundancyStatus()` - Update redundancy info
  - `getFailoverEvents()` - Retrieve failover history

### 3. API Routes

**File**: `routes/proxy-failover.js`

Implements 10 REST endpoints:

1. **POST /proxy/failover/config** - Create/update failover configuration
2. **GET /proxy/failover/config/:proxyId** - Get failover configuration
3. **POST /proxy/instances** - Register proxy instance
4. **GET /proxy/:proxyId/instances** - Get all instances
5. **PUT /proxy/instances/:instanceId/health** - Update instance health
6. **POST /proxy/failover/evaluate** - Evaluate failover need
7. **POST /proxy/failover/execute** - Execute failover (admin only)
8. **PUT /proxy/failover/events/:eventId/complete** - Complete failover event (admin only)
9. **GET /proxy/:proxyId/redundancy** - Get redundancy status
10. **PUT /proxy/:proxyId/redundancy** - Update redundancy status (admin only)
11. **GET /proxy/:proxyId/failover/events** - Get failover events

### 4. Test Suite

**File**: `test/api-backend/proxy-failover.test.js`

Comprehensive test coverage including:

- Configuration creation and validation
- Instance registration and management
- Health status updates
- Failover evaluation logic
- Failover execution
- Redundancy status management
- Error handling

## Architecture

### Failover Strategies

The service supports three failover strategies:

1. **Priority-Based** (Default)
   - Instances have priority values (lower = higher priority)
   - Failover switches to next highest priority healthy instance
   - Best for: Primary/backup scenarios

2. **Round-Robin**
   - Cycles through healthy instances in order
   - Best for: Load distribution across equal instances

3. **Least-Connections**
   - Routes to instance with fewest active connections
   - Best for: Connection-based load balancing

### Health Monitoring

Health status transitions:

```
unknown → healthy (health check passes)
healthy → unhealthy (consecutive failures exceed threshold)
unhealthy → healthy (consecutive successes exceed threshold)
```

Configurable thresholds:

- `unhealthyThreshold`: Consecutive failures before marking unhealthy (default: 3)
- `healthyThreshold`: Consecutive successes before marking healthy (default: 2)
- `healthCheckIntervalSeconds`: How often to check (default: 30)

### Redundancy Levels

- **single**: Single instance (no redundancy)
- **dual**: Two instances (primary + backup)
- **multi**: Three or more instances (full redundancy)

Degraded mode is triggered when:

- Healthy instances < total instances / 2
- Active instance is unhealthy
- No backup instances available

## Data Flow

### Failover Evaluation Flow

```
1. Get failover configuration
2. Check if auto-failover is enabled
3. Get all proxy instances
4. Identify active instance
5. Check if active instance is unhealthy
6. If unhealthy and failures exceed threshold:
   - Find healthy backup instance
   - Return failover recommendation
7. Otherwise, return no failover needed
```

### Failover Execution Flow

```
1. Validate source and target instances
2. Create failover event (status: in_progress)
3. Update active instance in memory
4. Trigger failover callback (if registered)
5. Return failover event
6. Complete failover event (status: completed/failed)
```

### Health Update Flow

```
1. Get current instance
2. Update health status
3. Adjust consecutive failures counter
4. Record metrics (if provided)
5. Cache health status
6. Return updated instance
```

## Integration Points

### With Other Services

1. **Health Check Service**
   - Calls `updateInstanceHealth()` with health check results
   - Provides metrics for failover decisions

2. **Metrics Service**
   - Calls `recordInstanceMetrics()` with performance data
   - Metrics used for load balancing decisions

3. **Webhook Service**
   - Notifies on failover events
   - Sends redundancy status changes

4. **Admin Service**
   - Provides admin endpoints for manual failover
   - Logs all failover operations

### Callbacks

Service supports three callback types:

- `setFailoverCallback()` - Called when failover is executed
- `setRecoveryCallback()` - Called when recovery is needed
- `setRedundancyStatusCallback()` - Called when redundancy status changes

## Configuration Example

```javascript
const config = {
  failoverStrategy: 'priority',
  healthCheckIntervalSeconds: 30,
  healthCheckTimeoutSeconds: 5,
  unhealthyThreshold: 3,
  healthyThreshold: 2,
  maxRecoveryAttempts: 3,
  recoveryBackoffSeconds: 5,
  enableAutoFailover: true,
  enableAutoRecovery: true,
  enableLoadBalancing: false,
  loadBalancingAlgorithm: 'round_robin'
};
```

## Error Handling

All methods include:

- Input validation
- Database error handling
- Logging of errors with context
- Meaningful error messages
- Proper HTTP status codes

Error codes range from `PROXY_FAILOVER_001` to `PROXY_FAILOVER_019`.

## Performance Considerations

1. **Database Indexes**
   - Indexes on proxy_id, user_id, status, health_status
   - Indexes on created_at for time-based queries
   - Composite indexes for common query patterns

2. **In-Memory Caching**
   - Health status cache for quick lookups
   - Active instance tracking
   - Failover state management

3. **Query Optimization**
   - Instances ordered by priority/weight in queries
   - Limit on returned events (default 50)
   - Efficient metric recording

## Security

1. **Authentication**
   - All endpoints require JWT authentication
   - User ID extracted from JWT token

2. **Authorization**
   - Failover execution requires admin role
   - Redundancy updates require admin role
   - Read operations available to all authenticated users

3. **Audit Logging**
   - All failover events recorded
   - Timestamps and user IDs tracked
   - Error messages logged for debugging

## Testing

### Test Coverage

- Configuration creation and validation
- Instance registration and retrieval
- Health status updates with failure counting
- Failover evaluation logic
- Failover execution and completion
- Redundancy status management
- Error handling and validation

### Running Tests

```bash
npm test -- proxy-failover.test.js
```

### Test Scenarios

1. **Happy Path**: Successful failover from unhealthy to healthy instance
2. **No Failover Needed**: Active instance is healthy
3. **No Backup Available**: No healthy backup instance exists
4. **Auto-Failover Disabled**: Configuration disables auto-failover
5. **Health Recovery**: Instance recovers from unhealthy state
6. **Degraded Mode**: Operating with reduced redundancy

## Deployment

### Prerequisites

1. Database migration must be run:

   ```bash
   npm run migrate -- 015_proxy_failover_and_redundancy.sql
   ```

2. Service must be initialized with database connection:

   ```javascript
   const failoverService = new ProxyFailoverService(db, logger);
   ```

3. Routes must be registered in main server:

   ```javascript
   import { createProxyFailoverRoutes } from './routes/proxy-failover.js';
   app.use(createProxyFailoverRoutes(db, logger));
   ```

### Environment Variables

Optional configuration via environment:

- `PROXY_HEALTH_CHECK_INTERVAL` - Health check interval in ms (default: 30000)
- `PROXY_MAX_RECOVERY_ATTEMPTS` - Max recovery attempts (default: 3)
- `PROXY_RECOVERY_BACKOFF` - Recovery backoff in ms (default: 5000)
- `PROXY_HEALTH_CHECK_TIMEOUT` - Health check timeout in ms (default: 5000)

## Future Enhancements

1. **Advanced Load Balancing**
   - Weighted round-robin
   - Least-latency routing
   - Connection-aware balancing

2. **Predictive Failover**
   - Machine learning for failure prediction
   - Proactive failover before actual failure

3. **Multi-Region Failover**
   - Cross-region instance failover
   - Geographic load balancing

4. **Enhanced Metrics**
   - Real-time metrics dashboard
   - Historical trend analysis
   - Anomaly detection

5. **Automated Recovery**
   - Automatic instance restart
   - Self-healing capabilities
   - Automatic scaling integration

## Troubleshooting

### Common Issues

1. **Failover Not Triggering**
   - Check if auto-failover is enabled in configuration
   - Verify health check is running
   - Check consecutive failure count

2. **No Backup Instance Available**
   - Register additional instances
   - Check instance health status
   - Verify instance is marked as active

3. **Degraded Mode**
   - Check healthy instance count
   - Review recent failover events
   - Check instance metrics

## References

- Requirements: 5.8 - Proxy failover and redundancy
- Related Services: Health Check, Metrics, Webhooks
- Database: PostgreSQL with UUID and JSONB support
