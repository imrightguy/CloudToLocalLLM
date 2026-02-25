# Database Failover and High Availability - Quick Reference

## Overview

The Database Failover Manager provides automatic failover and high availability for PostgreSQL databases with:

- Automatic detection of primary database failures
- Failover to healthy standby databases
- Continuous health monitoring
- Automatic recovery when primary comes back online
- Comprehensive metrics and status reporting

## Key Features

### 1. Automatic Failover Detection

- Monitors primary database health every 10 seconds (configurable)
- Marks primary as unhealthy after 3 consecutive failures
- Automatically promotes healthy standby when primary fails

### 2. Health Monitoring

- Periodic health checks for primary and all standbys
- Response time tracking
- Failure count tracking
- Promotion eligibility determination

### 3. State Management

- **HEALTHY**: Primary and at least one standby are healthy
- **DEGRADED**: Only primary or only standby is healthy
- **FAILOVER_IN_PROGRESS**: Failover operation in progress
- **FAILOVER_COMPLETE**: Failover completed successfully
- **RECOVERY_IN_PROGRESS**: Primary recovery in progress
- **UNKNOWN**: No healthy databases available

### 4. Metrics Collection

- Total failovers count
- Total recoveries count
- Health check failures count
- Last failover timestamp
- Current failover state

## Configuration

### Environment Variables

```bash
# Health check interval (milliseconds)
FAILOVER_HEALTH_CHECK_INTERVAL=10000

# Primary database configuration
DB_HOST=primary.example.com
DB_PORT=5432
DB_NAME=CloudToLocalLLM
DB_USER=postgres
DB_PASSWORD=password
DB_SSL=true

# Standby database configuration (via code)
# See initialization section below
```

## Usage

### Initialization

```javascript
import {
  initializeFailoverManager,
  getFailoverManager,
} from './database/failover-manager.js';

// Initialize with primary and standby configs
const primaryConfig = {
  host: 'primary.example.com',
  port: 5432,
  database: 'CloudToLocalLLM',
  user: 'postgres',
  password: 'password',
};

const standbyConfigs = [
  {
    host: 'standby1.example.com',
    port: 5432,
    database: 'CloudToLocalLLM',
    user: 'postgres',
    password: 'password',
  },
  {
    host: 'standby2.example.com',
    port: 5432,
    database: 'CloudToLocalLLM',
    user: 'postgres',
    password: 'password',
  },
];

const failoverManager = await initializeFailoverManager(
  primaryConfig,
  standbyConfigs,
);
```

### Query Execution

```javascript
import { getFailoverManager } from './database/failover-manager.js';

const failoverManager = getFailoverManager();

// Execute query with automatic failover
const result = await failoverManager.query(
  'SELECT * FROM users WHERE id = $1',
  [userId],
);

// Get a client for transactions
const client = await failoverManager.getClient();
try {
  await client.query('BEGIN');
  // ... transaction operations
  await client.query('COMMIT');
} finally {
  client.release();
}
```

### Status Monitoring

```javascript
// Get current failover status
const status = failoverManager.getFailoverStatus();
console.log(status);
// {
//   state: 'healthy',
//   primary: { host: '...', healthy: true, ... },
//   standbys: { standby_0: { ... }, standby_1: { ... } },
//   currentPrimaryIndex: 0,
//   lastFailoverTime: null,
//   failoverCount: 0
// }

// Get metrics
const metrics = failoverManager.getMetrics();
console.log(metrics);
// {
//   failovers: 0,
//   recoveries: 0,
//   healthCheckFailures: 0,
//   state: 'healthy',
//   ...
// }
```

### Manual Failover

```javascript
// Manually trigger failover to standby 0
await failoverManager.performFailover(0);
```

### Health Checks

```javascript
// Manually trigger health checks
await failoverManager.checkPrimaryHealth();
await failoverManager.checkStandbyHealth(0);
```

## API Endpoints

### GET /failover/status

Returns current failover status and health information.

**Response:**

```json
{
  "success": true,
  "data": {
    "state": "healthy",
    "primary": {
      "host": "primary.example.com",
      "port": 5432,
      "database": "CloudToLocalLLM",
      "healthy": true,
      "lastHealthCheck": "2024-01-19T10:30:00Z",
      "failureCount": 0,
      "responseTime": 10,
      "downSince": null
    },
    "standbys": {
      "standby_0": {
        "host": "standby1.example.com",
        "port": 5432,
        "database": "CloudToLocalLLM",
        "healthy": true,
        "lastHealthCheck": "2024-01-19T10:30:00Z",
        "failureCount": 0,
        "responseTime": 12,
        "promotionEligible": true
      }
    },
    "currentPrimaryIndex": 0,
    "lastFailoverTime": null,
    "failoverCount": 0
  },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### GET /failover/metrics

Returns failover metrics and statistics.

**Response:**

```json
{
  "success": true,
  "data": {
    "failovers": 0,
    "recoveries": 0,
    "healthCheckFailures": 0,
    "totalDowntime": 0,
    "lastStateChange": "2024-01-19T10:30:00Z",
    "state": "healthy",
    "failoverStatus": { ... }
  },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### GET /failover/health

Returns detailed health information for all database instances.

**Response:**

```json
{
  "success": true,
  "data": {
    "primary": {
      "host": "primary.example.com",
      "port": 5432,
      "database": "CloudToLocalLLM",
      "healthy": true,
      "lastHealthCheck": "2024-01-19T10:30:00Z",
      "failureCount": 0,
      "responseTime": 10,
      "downSince": null,
      "status": "healthy"
    },
    "standbys": [
      {
        "name": "standby_0",
        "host": "standby1.example.com",
        "port": 5432,
        "database": "CloudToLocalLLM",
        "healthy": true,
        "lastHealthCheck": "2024-01-19T10:30:00Z",
        "failureCount": 0,
        "responseTime": 12,
        "promotionEligible": true,
        "status": "healthy"
      }
    ],
    "overall": "healthy",
    "timestamp": "2024-01-19T10:30:00Z"
  }
}
```

### POST /failover/trigger

Manually trigger failover to a specific standby (Admin only).

**Request:**

```json
{
  "standbyIndex": 0
}
```

**Response:**

```json
{
  "success": true,
  "message": "Failover triggered successfully",
  "data": { ... },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### POST /failover/check-health

Manually trigger health checks for all databases (Admin only).

**Response:**

```json
{
  "success": true,
  "message": "Health checks completed",
  "data": { ... },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### GET /failover/history

Returns failover history and events.

**Response:**

```json
{
  "success": true,
  "data": {
    "totalFailovers": 0,
    "totalRecoveries": 0,
    "totalHealthCheckFailures": 0,
    "lastFailoverTime": null,
    "lastStateChange": "2024-01-19T10:30:00Z",
    "currentState": "healthy",
    "failoverCount": 0
  },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

## Kubernetes Configuration

### StatefulSet with Failover

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-primary
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
      role: primary
  template:
    metadata:
      labels:
        app: postgres
        role: primary
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: CloudToLocalLLM
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 100Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres-standby
spec:
  serviceName: postgres-standby
  replicas: 2
  selector:
    matchLabels:
      app: postgres
      role: standby
  template:
    metadata:
      labels:
        app: postgres
        role: standby
    spec:
      containers:
      - name: postgres
        image: postgres:15
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_DB
          value: CloudToLocalLLM
        - name: PGUSER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 100Gi
```

## Monitoring and Alerting

### Prometheus Metrics

```
# Failover state (0=unknown, 1=healthy, 2=degraded, 3=failover_in_progress, 4=failover_complete, 5=recovery_in_progress)
failover_state{instance="api-backend"} 1

# Total failovers
failover_total{instance="api-backend"} 0

# Total recoveries
failover_recoveries_total{instance="api-backend"} 0

# Health check failures
failover_health_check_failures_total{instance="api-backend"} 0

# Primary database health (0=unhealthy, 1=healthy)
failover_primary_healthy{instance="api-backend"} 1

# Standby database health
failover_standby_healthy{instance="api-backend",standby="0"} 1
failover_standby_healthy{instance="api-backend",standby="1"} 1
```

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
      description: "Primary database has been unhealthy for 1 minute"

  - alert: AllDatabasesDown
    expr: failover_state == 0
    for: 1m
    annotations:
      summary: "All databases are down"
      description: "No healthy databases available"

  - alert: FailoverOccurred
    expr: increase(failover_total[5m]) > 0
    annotations:
      summary: "Database failover occurred"
      description: "Failover to standby database was triggered"
```

## Troubleshooting

### Primary Database Down

1. Check primary database connectivity
2. Verify primary database is running
3. Check network connectivity between API and primary
4. Review primary database logs

### Standby Not Promoted

1. Verify standby database is healthy
2. Check standby promotion eligibility
3. Verify standby has replication enabled
4. Check standby database logs

### Failover Not Triggering

1. Verify at least one standby is healthy
2. Check failover manager logs
3. Verify health check interval is appropriate
4. Check failure count threshold (default: 3)

### High Failover Count

1. Check network stability
2. Verify database performance
3. Review database logs for errors
4. Consider increasing health check interval

## Performance Considerations

- Health checks run every 10 seconds (configurable)
- Each health check takes ~10-20ms
- Failover operation takes ~100-500ms
- No impact on query performance during normal operation
- Minimal memory overhead (~1MB per failover manager)

## Security Considerations

- Database credentials stored in environment variables
- SSL/TLS support for database connections
- Health check queries are read-only
- Failover operations require admin authentication
- All operations are logged with timestamps and user IDs

## Limitations

- Requires manual promotion of standby to primary
- Does not support automatic data synchronization
- Requires external replication setup (e.g., PostgreSQL streaming replication)
- Does not support multi-region failover
- Requires manual DNS/connection string updates after failover

## Future Enhancements

- Automatic DNS updates on failover
- Multi-region failover support
- Automatic data synchronization
- Machine learning-based failure prediction
- Advanced metrics and analytics
