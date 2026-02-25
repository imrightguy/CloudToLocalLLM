# Read Replica Configuration Guide

## Overview

The Read Replica Manager provides automatic read/write routing and replica health management for scaling read operations across multiple PostgreSQL replicas.

## Features

- **Automatic Read/Write Routing**: Routes SELECT queries to replicas, INSERT/UPDATE/DELETE to primary
- **Health Checking**: Periodic health checks with automatic failover
- **Load Balancing**: Round-robin distribution across healthy replicas
- **Failover Support**: Automatic fallback to primary when replicas fail
- **Metrics Tracking**: Query counts, failovers, and health status

## Environment Configuration

Add these variables to `.env`:

```bash
# Read Replica Configuration
# Primary database (existing configuration)
DB_HOST=primary.example.com
DB_PORT=5432
DB_NAME=CloudToLocalLLM
DB_USER=db_user
DB_PASSWORD=db_password

# Replica Configuration (JSON format)
# Format: [{"host":"replica1.example.com","port":5432,"database":"CloudToLocalLLM","user":"db_user","password":"db_password"},...]
DB_REPLICAS='[{"host":"replica1.example.com","port":5432,"database":"CloudToLocalLLM","user":"db_user","password":"db_password"},{"host":"replica2.example.com","port":5432,"database":"CloudToLocalLLM","user":"db_user","password":"db_password"}]'

# Health Check Interval (milliseconds, default: 30000)
REPLICA_HEALTH_CHECK_INTERVAL=30000

# Connection Pool Settings (same as primary)
DB_POOL_MAX=50
DB_POOL_MIN=5
DB_POOL_CONNECT_TIMEOUT=30000
DB_POOL_IDLE=600000
```

## Usage

### Initialize Read Replica Manager

```javascript
import { initializeReadReplicaManager } from './database/read-replica-manager.js';

const primaryConfig = {
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT),
  database: process.env.DB_NAME,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
};

const replicaConfigs = process.env.DB_REPLICAS 
  ? JSON.parse(process.env.DB_REPLICAS)
  : [];

const replicaManager = await initializeReadReplicaManager(primaryConfig, replicaConfigs);
```

### Execute Queries with Automatic Routing

```javascript
import { getReadReplicaManager } from './database/read-replica-manager.js';

const manager = getReadReplicaManager();

// Read query - automatically routed to replica
const result = await manager.query('SELECT * FROM users WHERE id = $1', [userId]);

// Write query - automatically routed to primary
await manager.query('INSERT INTO users (name) VALUES ($1)', [userName]);
```

### Get Replica Status

```javascript
const manager = getReadReplicaManager();

// Get status of all replicas
const status = manager.getReplicaStatus();
console.log(status);
// Output:
// {
//   replica_0: {
//     host: 'replica1.example.com',
//     port: 5432,
//     database: 'CloudToLocalLLM',
//     healthy: true,
//     lastHealthCheck: '2024-01-01T00:00:00Z',
//     failureCount: 0,
//     responseTime: 45
//   },
//   replica_1: {
//     host: 'replica2.example.com',
//     port: 5432,
//     database: 'CloudToLocalLLM',
//     healthy: true,
//     lastHealthCheck: '2024-01-01T00:00:00Z',
//     failureCount: 0,
//     responseTime: 52
//   }
// }
```

### Get Metrics

```javascript
const manager = getReadReplicaManager();

// Get metrics
const metrics = manager.getMetrics();
console.log(metrics);
// Output:
// {
//   readQueries: 1250,
//   writeQueries: 450,
//   replicaFailovers: 2,
//   healthCheckFailures: 0,
//   replicaCount: 2,
//   replicaStatus: { ... }
// }
```

### Get Client for Transactions

```javascript
const manager = getReadReplicaManager();

// Get read client (from replica)
const readClient = await manager.getClient('read');
try {
  const result = await readClient.query('SELECT * FROM users');
  // Use result
} finally {
  readClient.release();
}

// Get write client (from primary)
const writeClient = await manager.getClient('write');
try {
  await writeClient.query('BEGIN');
  await writeClient.query('INSERT INTO users (name) VALUES ($1)', [name]);
  await writeClient.query('COMMIT');
} catch (error) {
  await writeClient.query('ROLLBACK');
  throw error;
} finally {
  writeClient.release();
}
```

## Query Routing Rules

### Read Queries (Routed to Replicas)

- `SELECT ...`
- `WITH ... SELECT ...`
- `EXPLAIN ...`

### Write Queries (Routed to Primary)

- `INSERT ...`
- `UPDATE ...`
- `DELETE ...`
- `CREATE ...`
- `ALTER ...`
- `DROP ...`

## Health Checking

Health checks run periodically (default: every 30 seconds):

1. **Successful Check**: Replica marked as healthy, failure count reset
2. **Failed Check**: Failure count incremented
3. **Threshold Reached**: After 3 consecutive failures, replica marked as unhealthy
4. **Automatic Recovery**: Replica re-checked and can return to healthy status

## Failover Behavior

### Read Query Failover

1. Query routed to replica
2. If replica fails, query automatically retried on primary
3. Replica marked as unhealthy after 3 failures
4. Subsequent queries skip unhealthy replica

### Write Query Behavior

- Always routed to primary
- No failover to replicas (replicas are read-only)

## Kubernetes Deployment

### StatefulSet Configuration

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
  name: postgres-replica
spec:
  serviceName: postgres-replica
  replicas: 2
  selector:
    matchLabels:
      app: postgres
      role: replica
  template:
    metadata:
      labels:
        app: postgres
        role: replica
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
        - name: PGUSER
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: username
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

### API Backend Configuration

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: api-backend-config
data:
  DB_HOST: postgres-primary.default.svc.cluster.local
  DB_PORT: "5432"
  DB_NAME: CloudToLocalLLM
  DB_REPLICAS: '[{"host":"postgres-replica-0.postgres-replica.default.svc.cluster.local","port":5432,"database":"CloudToLocalLLM","user":"postgres","password":""},{"host":"postgres-replica-1.postgres-replica.default.svc.cluster.local","port":5432,"database":"CloudToLocalLLM","user":"postgres","password":""}]'
  REPLICA_HEALTH_CHECK_INTERVAL: "30000"
```

## Performance Considerations

### Benefits

- **Read Scaling**: Distribute read load across multiple replicas
- **Reduced Primary Load**: Primary handles only writes
- **High Availability**: Automatic failover if replica fails
- **Transparent**: Application code doesn't need to change

### Limitations

- **Replication Lag**: Replicas may be slightly behind primary
- **Consistency**: Read-after-write consistency not guaranteed
- **Setup Complexity**: Requires PostgreSQL replication setup

## Monitoring

### Metrics to Track

- `readQueries`: Total read queries routed to replicas
- `writeQueries`: Total write queries routed to primary
- `replicaFailovers`: Number of times read query failed on replica and retried on primary
- `healthCheckFailures`: Number of failed health checks

### Health Check Endpoint

```javascript
app.get('/health/replicas', (req, res) => {
  const manager = getReadReplicaManager();
  const status = manager.getReplicaStatus();
  const metrics = manager.getMetrics();
  
  res.json({
    status: 'ok',
    replicas: status,
    metrics: metrics
  });
});
```

## Troubleshooting

### All Replicas Unhealthy

- Check network connectivity to replicas
- Verify replica PostgreSQL services are running
- Check replica replication status
- Review health check logs

### High Failover Rate

- Check replica performance and load
- Verify replication lag
- Consider adding more replicas
- Review query patterns

### Uneven Load Distribution

- Verify all replicas are healthy
- Check round-robin counter
- Review replica response times
- Consider replica capacity

## Requirements Met

✅ **Requirement 9.5**: Read replica support for scaling read operations

- Create read replica configuration
- Implement read/write routing
- Add replica health checking
- Add unit tests for replica routing
