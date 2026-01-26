# Connection Pool Quick Start Guide

Get started with the Connection Pool and SSH Management module in 5 minutes.

## Installation

No additional dependencies required. The module uses Node.js built-in modules.

## Basic Usage

### 1. Create Connection Pool

```typescript
import { ConnectionPoolImpl } from './connection-pool/index.js';
import { ConsoleLogger } from './utils/logger.js';

const logger = new ConsoleLogger('ConnectionPool');
const pool = new ConnectionPoolImpl(
  {
    maxConnectionsPerUser: 3,
    maxIdleTime: 300000, // 5 minutes
    cleanupInterval: 30000, // 30 seconds
  },
  logger
);
```

### 2. Get and Use Connection

```typescript
// Get connection for user
const connection = await pool.getConnection('user123');

// Forward request through SSH tunnel
const response = await connection.forward({
  id: 'req1',
  method: 'POST',
  path: '/api/chat',
  headers: { 'content-type': 'application/json' },
  body: Buffer.from(JSON.stringify({ message: 'Hello' })),
});

// Release connection back to pool
pool.releaseConnection('user123', connection);
```

### 3. Enable Automatic Cleanup

```typescript
import { ConnectionCleanupService } from './connection-pool/index.js';

const cleanupService = new ConnectionCleanupService(pool, logger);
cleanupService.start();
```

### 4. Setup Graceful Shutdown

```typescript
import { GracefulShutdownManager } from './connection-pool/index.js';

const shutdownManager = new GracefulShutdownManager(pool, logger);
// Automatically handles SIGTERM and SIGINT
```

## Complete Example

```typescript
import {
  ConnectionPoolImpl,
  ConnectionCleanupService,
  GracefulShutdownManager,
} from './connection-pool/index.js';
import { ConsoleLogger } from './utils/logger.js';

// Setup
const logger = new ConsoleLogger('TunnelServer');
const pool = new ConnectionPoolImpl(
  { maxConnectionsPerUser: 3, maxIdleTime: 300000, cleanupInterval: 30000 },
  logger
);
const cleanupService = new ConnectionCleanupService(pool, logger);
const shutdownManager = new GracefulShutdownManager(pool, logger);

// Start services
cleanupService.start();

// Handle requests
async function handleRequest(userId: string, request: any) {
  const connection = await pool.getConnection(userId);
  try {
    const response = await connection.forward(request);
    return response;
  } finally {
    pool.releaseConnection(userId, connection);
  }
}

// Use it
const response = await handleRequest('user123', {
  id: 'req1',
  method: 'GET',
  path: '/api/status',
  headers: {},
});

console.log('Response:', response);
```

## Common Patterns

### Pattern 1: Request Handler Middleware

```typescript
async function connectionPoolMiddleware(req, res, next) {
  const userId = req.user.id;
  const connection = await pool.getConnection(userId);
  
  req.sshConnection = connection;
  
  res.on('finish', () => {
    pool.releaseConnection(userId, connection);
  });
  
  next();
}
```

### Pattern 2: Connection Health Check

```typescript
async function ensureHealthyConnection(userId: string) {
  const connection = await pool.getConnection(userId);
  
  if (!connection.isHealthy()) {
    await pool.closeConnection(userId);
    return await pool.getConnection(userId);
  }
  
  return connection;
}
```

### Pattern 3: Batch Request Processing

```typescript
async function processBatch(userId: string, requests: any[]) {
  const connection = await pool.getConnection(userId);
  
  try {
    const responses = await Promise.all(
      requests.map(req => connection.forward(req))
    );
    return responses;
  } finally {
    pool.releaseConnection(userId, connection);
  }
}
```

## Configuration Tips

### Development

```typescript
const devConfig = {
  maxConnectionsPerUser: 1,
  maxIdleTime: 60000, // 1 minute
  cleanupInterval: 10000, // 10 seconds
};
```

### Production

```typescript
const prodConfig = {
  maxConnectionsPerUser: 3,
  maxIdleTime: 300000, // 5 minutes
  cleanupInterval: 30000, // 30 seconds
};
```

### High Traffic

```typescript
const highTrafficConfig = {
  maxConnectionsPerUser: 5,
  maxIdleTime: 600000, // 10 minutes
  cleanupInterval: 60000, // 1 minute
};
```

## Monitoring

### Check Pool Status

```typescript
const stats = pool.getPoolStats();
console.log(`Active connections: ${stats.totalConnections}`);
console.log(`Active users: ${stats.userCount}`);
```

### Check Cleanup Status

```typescript
const cleanupStats = cleanupService.getStats();
console.log(`Cleaned connections: ${cleanupStats.cleanupCount}`);
```

### Check Connection Health

```typescript
const connection = await pool.getConnection('user123');
const connStats = connection.getStats();
console.log(`Healthy: ${connStats.isHealthy}`);
console.log(`Channels: ${connStats.channelCount}`);
```

## Troubleshooting

### Problem: Connection limit exceeded

```typescript
// Solution: Close unused connections
await pool.closeConnection('user123');

// Or increase limit
const pool = new ConnectionPoolImpl({
  maxConnectionsPerUser: 5, // Increased from 3
  ...
});
```

### Problem: Stale connections not cleaned

```typescript
// Solution: Manually trigger cleanup
await cleanupService.triggerCleanup();

// Or adjust cleanup interval
cleanupService.updateConfig({
  cleanupInterval: 10000, // More frequent
});
```

### Problem: Shutdown takes too long

```typescript
// Solution: Reduce grace period
const shutdownManager = new GracefulShutdownManager(pool, logger, {
  gracePeriod: 10000, // Reduced from 30 seconds
  forceAfterGracePeriod: true,
});
```

## Next Steps

1. Read the [full README](./README.md) for detailed documentation
2. Review the [implementation summary](./IMPLEMENTATION_SUMMARY.md)
3. Check the [requirements mapping](./README.md#requirements-mapping)
4. Explore the [integration examples](./README.md#integration-example)

## Support

For issues or questions:

1. Check the [troubleshooting section](./README.md#troubleshooting)
2. Review the [requirements document](../../../.kiro/specs/ssh-websocket-tunnel-enhancement/requirements.md)
3. Check the [design document](../../../.kiro/specs/ssh-websocket-tunnel-enhancement/design.md)
