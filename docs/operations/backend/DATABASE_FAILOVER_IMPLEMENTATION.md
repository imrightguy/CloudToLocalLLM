# Database Failover and High Availability - Implementation Guide

## Overview

This guide provides detailed implementation instructions for the Database Failover and High Availability system. The system provides automatic failover from a primary PostgreSQL database to standby replicas with continuous health monitoring and automatic recovery.

## Architecture

### Components

1. **FailoverManager** - Core failover logic and state management
2. **Failover Routes** - REST API endpoints for status and control
3. **Health Monitoring** - Periodic health checks for all databases
4. **State Management** - Tracks failover state and transitions
5. **Metrics Collection** - Collects failover statistics

### Data Flow

```
Health Check Cycle (every 10s)
    ↓
Check Primary Health
    ↓
Check All Standbys Health
    ↓
Update Failover State
    ↓
If Primary Down & Standby Healthy
    ↓
Trigger Failover
    ↓
Update Current Primary Index
    ↓
Log Failover Event
```

## Implementation Details

### 1. FailoverManager Class

**Location:** `services/api-backend/database/failover-manager.js`

**Key Methods:**

- `initialize(primaryConfig, standbyConfigs)` - Initialize manager with database configs
- `getActivePool()` - Get current active database pool
- `query(queryText, params)` - Execute query with automatic failover
- `getClient()` - Get database client for transactions
- `checkPrimaryHealth()` - Check primary database health
- `checkStandbyHealth(index)` - Check specific standby health
- `performFailover(standbyIndex)` - Perform failover to standby
- `getFailoverStatus()` - Get current failover status
- `getMetrics()` - Get failover metrics
- `startHealthChecks()` - Start periodic health monitoring
- `stopHealthChecks()` - Stop health monitoring
- `close()` - Close all database connections

**State Management:**

```javascript
// Failover states
FailoverState = {
  HEALTHY: 'healthy',                    // Primary + standbys healthy
  DEGRADED: 'degraded',                  // Only primary or only standby healthy
  FAILOVER_IN_PROGRESS: 'failover_in_progress',
  FAILOVER_COMPLETE: 'failover_complete',
  RECOVERY_IN_PROGRESS: 'recovery_in_progress',
  UNKNOWN: 'unknown',                    // No healthy databases
};
```

**Health Status Tracking:**

```javascript
// Primary health status
primaryHealthStatus = {
  healthy: boolean,
  lastHealthCheck: ISO8601 timestamp,
  failureCount: number,
  responseTime: milliseconds,
  downSince: ISO8601 timestamp or null,
};

// Standby health status (per standby)
standbyHealthStatus = {
  healthy: boolean,
  lastHealthCheck: ISO8601 timestamp,
  failureCount: number,
  responseTime: milliseconds,
  promotionEligible: boolean,
};
```

### 2. Health Check Logic

**Primary Health Check:**

```javascript
async checkPrimaryHealth() {
  1. Connect to primary pool
  2. Execute "SELECT 1" query
  3. If successful:
     - Mark as healthy
     - Reset failure count
     - Clear downSince timestamp
     - If was unhealthy, increment recovery count
  4. If failed:
     - Increment failure count
     - If first failure, set downSince timestamp
     - If 3+ failures, mark as unhealthy
     - Trigger failover if needed
}
```

**Standby Health Check:**

```javascript
async checkStandbyHealth(index) {
  1. Connect to standby pool
  2. Execute "SELECT 1" query
  3. If successful:
     - Mark as healthy
     - Set promotionEligible = true
     - Reset failure count
  4. If failed:
     - Increment failure count
     - If 3+ failures, mark as unhealthy
     - Set promotionEligible = false
}
```

### 3. Failover Trigger Logic

**Automatic Failover:**

```javascript
async triggerFailoverIfNeeded() {
  1. Check if primary is healthy
     - If yes, return (no failover needed)
  2. Find healthy standby with promotionEligible = true
     - If none found, return (no standby available)
  3. Call performFailover(standbyIndex)
}
```

**Failover Execution:**

```javascript
async performFailover(standbyIndex) {
  1. Set state to FAILOVER_IN_PROGRESS
  2. Verify standby is ready (execute SELECT 1)
  3. Update currentPrimaryIndex to standbyIndex
  4. Set lastFailoverTime to now
  5. Increment failoverCount
  6. Set state to FAILOVER_COMPLETE
  7. Update failover state
  8. Log failover event
}
```

### 4. API Routes

**Location:** `services/api-backend/routes/failover.js`

**Endpoints:**

1. `GET /failover/status` - Get current failover status
2. `GET /failover/metrics` - Get failover metrics
3. `GET /failover/health` - Get detailed health information
4. `POST /failover/trigger` - Manually trigger failover
5. `POST /failover/check-health` - Manually trigger health checks
6. `GET /failover/history` - Get failover history

### 5. Integration with Express App

**In server.js:**

```javascript
import failoverRoutes from './routes/failover.js';
import { initializeFailoverManager } from './database/failover-manager.js';

// Initialize failover manager on startup
const primaryConfig = {
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
};

const standbyConfigs = [
  // Parse from environment or config file
];

const failoverManager = await initializeFailoverManager(
  primaryConfig,
  standbyConfigs,
);

// Register routes
app.use('/failover', failoverRoutes);

// On shutdown
process.on('SIGTERM', async () => {
  await closeFailoverManager();
});
```

## Configuration

### Environment Variables

```bash
# Health check interval (milliseconds)
FAILOVER_HEALTH_CHECK_INTERVAL=10000

# Primary database
DB_HOST=primary.example.com
DB_PORT=5432
DB_NAME=CloudToLocalLLM
DB_USER=postgres
DB_PASSWORD=password
DB_SSL=true

# Standby databases (via code configuration)
```

### Standby Configuration

Standby databases should be configured in code or via configuration file:

```javascript
const standbyConfigs = [
  {
    host: 'standby1.example.com',
    port: 5432,
    database: 'CloudToLocalLLM',
    user: 'postgres',
    password: 'password',
    ssl: { rejectUnauthorized: false },
  },
  {
    host: 'standby2.example.com',
    port: 5432,
    database: 'CloudToLocalLLM',
    user: 'postgres',
    password: 'password',
    ssl: { rejectUnauthorized: false },
  },
];
```

## Testing

### Unit Tests

**Location:** `test/api-backend/failover-manager.test.js`

Tests cover:

- Initialization
- Health status management
- Failover state management
- Failover status reporting
- Metrics collection
- Failover triggering
- Recovery tracking
- Health check interval management

### Integration Tests

**Location:** `test/api-backend/failover-integration.test.js`

Tests cover:

- GET /failover/status endpoint
- GET /failover/metrics endpoint
- GET /failover/health endpoint
- POST /failover/trigger endpoint
- POST /failover/check-health endpoint
- GET /failover/history endpoint
- Error handling

### Running Tests

```bash
# Run unit tests
npm test -- test/api-backend/failover-manager.test.js

# Run integration tests
npm test -- test/api-backend/failover-integration.test.js

# Run all tests
npm test
```

## Deployment

### Prerequisites

1. PostgreSQL primary database running
2. PostgreSQL standby replicas configured with streaming replication
3. Network connectivity between API and all databases
4. Proper database credentials and permissions

### Deployment Steps

1. **Deploy Database Infrastructure**
   - Set up primary PostgreSQL instance
   - Set up standby replicas with streaming replication
   - Configure replication slots
   - Test replication connectivity

2. **Deploy API Backend**
   - Update server.js with failover manager initialization
   - Configure environment variables
   - Deploy to Kubernetes or other platform

3. **Verify Failover Setup**
   - Check GET /failover/status endpoint
   - Verify all databases are healthy
   - Test manual failover with POST /failover/trigger
   - Monitor logs for failover events

4. **Configure Monitoring**
   - Set up Prometheus metrics collection
   - Configure Grafana dashboards
   - Set up alerting rules
   - Test alert notifications

### Kubernetes Deployment

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-backend-config
data:
  FAILOVER_HEALTH_CHECK_INTERVAL: "10000"
  DB_HOST: "postgres-primary.default.svc.cluster.local"
  DB_PORT: "5432"
  DB_NAME: "CloudToLocalLLM"
  DB_USER: "postgres"
  DB_SSL: "true"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-backend
  template:
    metadata:
      labels:
        app: api-backend
    spec:
      containers:
      - name: api-backend
        image: ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/api:latest
        ports:
        - containerPort: 8080
        envFrom:
        - configMapRef:
            name: api-backend-config
        - secretRef:
            name: api-backend-secrets
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
```

## Monitoring and Alerting

### Prometheus Metrics

The failover manager exposes metrics via the `/metrics` endpoint:

```
failover_state{instance="api-backend"} 1
failover_total{instance="api-backend"} 0
failover_recoveries_total{instance="api-backend"} 0
failover_health_check_failures_total{instance="api-backend"} 0
failover_primary_healthy{instance="api-backend"} 1
failover_standby_healthy{instance="api-backend",standby="0"} 1
```

### Grafana Dashboards

Create dashboards to visualize:

- Failover state over time
- Primary database health
- Standby database health
- Failover count and frequency
- Recovery count and frequency
- Health check failure rate

### Alert Rules

```yaml
groups:
- name: database_failover
  rules:
  - alert: PrimaryDatabaseDown
    expr: failover_primary_healthy == 0
    for: 1m
    annotations:
      summary: "Primary database is down"

  - alert: AllDatabasesDown
    expr: failover_state == 0
    for: 1m
    annotations:
      summary: "All databases are down"

  - alert: FailoverOccurred
    expr: increase(failover_total[5m]) > 0
    annotations:
      summary: "Database failover occurred"
```

## Troubleshooting

### Primary Database Down

**Symptoms:**

- GET /failover/status shows primary.healthy = false
- Failover state is DEGRADED or UNKNOWN

**Resolution:**

1. Check primary database is running: `psql -h primary.example.com -U postgres -d CloudToLocalLLM -c "SELECT 1"`
2. Check network connectivity: `ping primary.example.com`
3. Check database logs for errors
4. Verify database credentials are correct
5. Check firewall rules allow connection

### Standby Not Promoted

**Symptoms:**

- Primary is down but failover doesn't occur
- GET /failover/status shows no healthy standbys

**Resolution:**

1. Check standby database is running
2. Verify standby has replication enabled
3. Check standby health: `psql -h standby.example.com -U postgres -d CloudToLocalLLM -c "SELECT 1"`
4. Check replication status on primary
5. Verify standby has caught up with primary

### High Failover Count

**Symptoms:**

- Frequent failovers occurring
- GET /failover/history shows high failoverCount

**Resolution:**

1. Check network stability between API and databases
2. Check database performance and load
3. Review database logs for errors
4. Consider increasing health check interval
5. Check for transient network issues

## Performance Considerations

- Health checks run every 10 seconds (configurable)
- Each health check takes ~10-20ms
- Failover operation takes ~100-500ms
- No impact on query performance during normal operation
- Memory overhead: ~1MB per failover manager instance

## Security Considerations

- Database credentials stored in environment variables or secrets
- SSL/TLS support for database connections
- Health check queries are read-only
- Failover operations require admin authentication
- All operations logged with timestamps and user IDs
- No sensitive data exposed in API responses

## Limitations

- Requires manual promotion of standby to primary
- Does not support automatic data synchronization
- Requires external replication setup (PostgreSQL streaming replication)
- Does not support multi-region failover
- Requires manual DNS/connection string updates after failover

## Future Enhancements

- Automatic DNS updates on failover
- Multi-region failover support
- Automatic data synchronization
- Machine learning-based failure prediction
- Advanced metrics and analytics
- Automatic connection string updates
- Support for other database systems (MySQL, Oracle, etc.)
