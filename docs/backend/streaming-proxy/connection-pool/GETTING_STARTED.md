# Getting Started with Connection Pool

A step-by-step guide to integrate the connection pool into your streaming proxy server.

## Prerequisites

- Node.js 18.0.0 or higher
- TypeScript 5.0 or higher
- Basic understanding of SSH and WebSocket protocols

## Installation

No additional dependencies required. The connection pool uses Node.js built-in modules.

## Step 1: Import the Module

```typescript
import {
  ConnectionPoolImpl,
  ConnectionCleanupService,
  GracefulShutdownManager,
} from './connection-pool/index.js';
import { ConsoleLogger } from './utils/logger.js';
```

## Step 2: Initialize the Logger

```typescript
const logger = new ConsoleLogger('TunnelServer');
```

## Step 3: Create the Connection Pool

```typescript
const pool = new ConnectionPoolImpl(
  {
    maxConnectionsPerUser: 3,        // Max connections per user
    maxIdleTime: 300000,             // 5 minutes idle timeout
    cleanupInterval: 30000,          // Cleanup every 30 seconds
  },
  logger
);
```

## Step 4: Start the Cleanup Service

```typescript
const cleanupService = new ConnectionCleanupService(pool, logger, {
  cleanupInterval: 30000,  // Run cleanup every 30 seconds
  maxIdleTime: 300000,     // Close connections idle for 5 minutes
  enabled: true,           // Enable automatic cleanup
});

cleanupService.start();
```

## Step 5: Setup Graceful Shutdown

```typescript
const shutdownManager = new GracefulShutdownManager(pool, logger, {
  gracePeriod: 30000,              // Wait 30 seconds for in-flight requests
  forceAfterGracePeriod: true,     // Force shutdown after grace period
  notifyClients: true,             // Notify clients before shutdown
});

// Shutdown is automatically triggered on SIGTERM/SIGINT
```

## Step 6: Use the Connection Pool

### Basic Usage

```typescript
async function handleRequest(userId: string, request: any) {
  // Get connection from pool
  const connection = await pool.getConnection(userId);
  
  try {
    // Forward request through SSH tunnel
    const response = await connection.forward({
      id: request.id,
      method: request.method,
      path: request.path,
      headers: request.headers,
      body: request.body,
    });
    
    return response;
  } finally {
    // Always release connection back to pool
    pool.releaseConnection(userId, connection);
  }
}
```

### With Error Handling

```typescript
async function handleRequestWithErrorHandling(userId: string, request: any) {
  let connection;
  
  try {
    connection = await pool.getConnection(userId);
    
    // Check connection health
    if (!connection.isHealthy()) {
      logger.warn(`Unhealthy connection for user ${userId}, closing...`);
      await pool.closeConnection(userId);
      connection = await pool.getConnection(userId);
    }
    
    const response = await connection.forward(request);
    return response;
    
  } catch (error) {
    logger.error(`Error handling request for user ${userId}:`, error);
    
    // Close connection on error
    if (connection) {
      await pool.closeConnection(userId);
    }
    
    throw error;
    
  } finally {
    if (connection) {
      pool.releaseConnection(userId, connection);
    }
  }
}
```

## Step 7: Monitor the Pool

### Get Pool Statistics

```typescript
// Get overall pool statistics
const stats = pool.getPoolStats();
console.log(`Total connections: ${stats.totalConnections}`);
console.log(`Active users: ${stats.userCount}`);
console.log('Connections by user:', stats.connectionsByUser);
```

### Get Connection Statistics

```typescript
const connection = await pool.getConnection('user123');
const connStats = connection.getStats();

console.log(`Connection ID: ${connStats.id}`);
console.log(`User ID: ${connStats.userId}`);
console.log(`Created at: ${connStats.createdAt}`);
console.log(`Last used: ${connStats.lastUsedAt}`);
console.log(`Channel count: ${connStats.channelCount}`);
console.log(`Is healthy: ${connStats.isHealthy}`);
console.log(`Uptime: ${connStats.uptime}ms`);
```

### Get Cleanup Statistics

```typescript
const cleanupStats = cleanupService.getStats();
console.log(`Cleanup running: ${cleanupStats.isRunning}`);
console.log(`Total cleaned: ${cleanupStats.cleanupCount}`);
console.log(`Last cleanup: ${cleanupStats.lastCleanupTime}`);
```

## Step 8: Integrate with Express/HTTP Server

```typescript
import express from 'express';

const app = express();

// Middleware to attach connection to request
app.use(async (req, res, next) => {
  const userId = req.user?.id; // From auth middleware
  
  if (!userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  
  try {
    req.sshConnection = await pool.getConnection(userId);
    
    // Release connection when response finishes
    res.on('finish', () => {
      pool.releaseConnection(userId, req.sshConnection);
    });
    
    next();
  } catch (error) {
    logger.error(`Error getting connection for user ${userId}:`, error);
    res.status(500).json({ error: 'Connection pool error' });
  }
});

// Route handler
app.post('/api/forward', async (req, res) => {
  try {
    const response = await req.sshConnection.forward({
      id: req.body.id,
      method: req.body.method,
      path: req.body.path,
      headers: req.body.headers,
      body: Buffer.from(JSON.stringify(req.body.data)),
    });
    
    res.status(response.statusCode).json(response.body);
  } catch (error) {
    logger.error('Error forwarding request:', error);
    res.status(500).json({ error: 'Forward error' });
  }
});

app.listen(3000, () => {
  logger.info('Server started on port 3000');
});
```

## Step 9: Handle Cleanup on Exit

```typescript
// Cleanup on process exit
process.on('beforeExit', async () => {
  logger.info('Process exiting, cleaning up...');
  
  // Stop cleanup service
  cleanupService.stop();
  
  // Close all connections
  await pool.closeAllConnections();
  
  logger.info('Cleanup complete');
});
```

## Complete Example

Here's a complete working example:

```typescript
import express from 'express';
import {
  ConnectionPoolImpl,
  ConnectionCleanupService,
  GracefulShutdownManager,
} from './connection-pool/index.js';
import { ConsoleLogger } from './utils/logger.js';

// Initialize
const logger = new ConsoleLogger('TunnelServer');
const pool = new ConnectionPoolImpl(
  { maxConnectionsPerUser: 3, maxIdleTime: 300000, cleanupInterval: 30000 },
  logger
);
const cleanupService = new ConnectionCleanupService(pool, logger);
const shutdownManager = new GracefulShutdownManager(pool, logger);

// Start services
cleanupService.start();

// Create Express app
const app = express();
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  const stats = pool.getPoolStats();
  res.json({
    status: 'healthy',
    connections: stats.totalConnections,
    users: stats.userCount,
  });
});

// Forward endpoint
app.post('/api/forward', async (req, res) => {
  const userId = req.headers['x-user-id'] as string;
  
  if (!userId) {
    return res.status(401).json({ error: 'Missing user ID' });
  }
  
  let connection;
  try {
    connection = await pool.getConnection(userId);
    
    const response = await connection.forward({
      id: req.body.id,
      method: req.body.method,
      path: req.body.path,
      headers: req.body.headers,
      body: Buffer.from(JSON.stringify(req.body.data)),
    });
    
    res.status(response.statusCode).json(response.body);
    
  } catch (error) {
    logger.error(`Error forwarding request for user ${userId}:`, error);
    res.status(500).json({ error: error.message });
    
  } finally {
    if (connection) {
      pool.releaseConnection(userId, connection);
    }
  }
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`Server started on port ${PORT}`);
});

// Cleanup on exit
process.on('beforeExit', async () => {
  cleanupService.stop();
  await pool.closeAllConnections();
});
```

## Configuration Options

### Connection Pool Configuration

```typescript
interface ConnectionPoolConfig {
  maxConnectionsPerUser: number;  // Default: 3
  maxIdleTime: number;            // Default: 300000 (5 minutes)
  cleanupInterval: number;        // Default: 30000 (30 seconds)
}
```

### SSH Connection Configuration

```typescript
interface SSHConnectionConfig {
  keepAliveInterval: number;  // Default: 60000 (60 seconds)
  maxChannels: number;        // Default: 10
  connectionTimeout: number;  // Default: 30000 (30 seconds)
}
```

### Cleanup Service Configuration

```typescript
interface CleanupServiceConfig {
  cleanupInterval: number;  // Default: 30000 (30 seconds)
  maxIdleTime: number;      // Default: 300000 (5 minutes)
  enabled: boolean;         // Default: true
}
```

### Graceful Shutdown Configuration

```typescript
interface ShutdownConfig {
  gracePeriod: number;              // Default: 30000 (30 seconds)
  forceAfterGracePeriod: boolean;   // Default: true
  notifyClients: boolean;           // Default: true
}
```

## Environment Variables

```bash
# Connection Pool
MAX_CONNECTIONS_PER_USER=3
MAX_IDLE_TIME=300000
CLEANUP_INTERVAL=30000

# SSH Configuration
SSH_KEEPALIVE_INTERVAL=60000
SSH_MAX_CHANNELS=10
SSH_CONNECTION_TIMEOUT=30000

# Graceful Shutdown
SHUTDOWN_GRACE_PERIOD=30000
SHUTDOWN_FORCE_AFTER_GRACE=true
SHUTDOWN_NOTIFY_CLIENTS=true
```

## Troubleshooting

### Problem: Connection limit exceeded

```typescript
// Solution 1: Close unused connections
await pool.closeConnection('user123');

// Solution 2: Increase limit
const pool = new ConnectionPoolImpl({
  maxConnectionsPerUser: 5, // Increased from 3
  ...
});
```

### Problem: Connections not being cleaned up

```typescript
// Solution 1: Manually trigger cleanup
await cleanupService.triggerCleanup();

// Solution 2: Adjust cleanup interval
cleanupService.updateConfig({
  cleanupInterval: 10000, // More frequent
});
```

### Problem: Unhealthy connections

```typescript
// Solution: Check and replace unhealthy connections
const connection = await pool.getConnection('user123');
if (!connection.isHealthy()) {
  await pool.closeConnection('user123');
  connection = await pool.getConnection('user123');
}
```

## Next Steps

1. Read the [full documentation](./README.md)
2. Review the [quick start guide](./QUICK_START.md)
3. Check the [implementation summary](./IMPLEMENTATION_SUMMARY.md)
4. Explore the [completion report](./TASK_9_COMPLETION.md)

## Support

For issues or questions:

- Check the [troubleshooting section](./README.md#troubleshooting)
- Review the [requirements document](../../../.kiro/specs/ssh-websocket-tunnel-enhancement/requirements.md)
- Check the [design document](../../../.kiro/specs/ssh-websocket-tunnel-enhancement/design.md)
