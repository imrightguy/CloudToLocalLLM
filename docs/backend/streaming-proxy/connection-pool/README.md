# Connection Pool and SSH Management

This module implements server-side connection pooling and SSH connection management for the CloudToLocalLLM tunnel system.

## Overview

The connection pool manages SSH connections efficiently by:

- Reusing existing connections when possible
- Enforcing per-user connection limits
- Implementing health checks and keep-alive mechanisms
- Cleaning up stale connections automatically
- Providing graceful shutdown capabilities

## Components

### 1. ConnectionPoolImpl

Main connection pool implementation that manages SSH connections per user.

**Features:**

- Connection reuse and multiplexing
- Per-user connection limits (max 3 concurrent)
- Automatic stale connection cleanup
- User isolation (Requirement 4.1)

**Usage:**

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

// Get connection for user
const connection = await pool.getConnection('user123');

// Use connection
const response = await connection.forward({
  id: 'req1',
  method: 'POST',
  path: '/api/chat',
  headers: { 'content-type': 'application/json' },
  body: Buffer.from(JSON.stringify({ message: 'Hello' })),
});

// Release connection back to pool
pool.releaseConnection('user123', connection);

// Close all connections for user
await pool.closeConnection('user123');
```

### 2. SSHConnectionImpl

SSH connection wrapper with health checks and keep-alive.

**Features:**

- SSH keep-alive messages every 60 seconds (Requirement 7.4)
- Channel multiplexing support (Requirement 7.6)
- Channel limit enforcement (max 10 per connection) (Requirement 7.7)
- Connection health monitoring

**Usage:**

```typescript
import { SSHConnectionImpl } from './connection-pool/index.js';

const connection = new SSHConnectionImpl('user123', logger, {
  keepAliveInterval: 60000, // 60 seconds
  maxChannels: 10,
  connectionTimeout: 30000,
});

// Check health
if (connection.isHealthy()) {
  // Forward request
  const response = await connection.forward(request);
}

// Get statistics
const stats = connection.getStats();
console.log(`Connection uptime: ${stats.uptime}ms`);
console.log(`Active channels: ${stats.channelCount}`);

// Close connection
await connection.close();
```

### 3. ConnectionCleanupService

Periodic cleanup service for stale connections.

**Features:**

- Automatic cleanup of idle connections
- Configurable cleanup interval and idle timeout
- Manual cleanup trigger
- Cleanup statistics tracking

**Usage:**

```typescript
import { ConnectionCleanupService } from './connection-pool/index.js';

const cleanupService = new ConnectionCleanupService(pool, logger, {
  cleanupInterval: 30000, // 30 seconds
  maxIdleTime: 300000, // 5 minutes
  enabled: true,
});

// Start automatic cleanup
cleanupService.start();

// Manually trigger cleanup
const cleaned = await cleanupService.triggerCleanup();
console.log(`Cleaned ${cleaned} connections`);

// Get statistics
const stats = cleanupService.getStats();
console.log(`Total cleaned: ${stats.cleanupCount}`);

// Stop cleanup
cleanupService.stop();
```

### 4. GracefulShutdownManager

Handles graceful shutdown of connections and resources.

**Features:**

- Waits for in-flight requests (30 second timeout) (Requirement 8.4)
- Sends SSH disconnect messages (Requirement 8.2)
- Closes WebSocket with code 1000 (Requirement 8.3)
- Signal handler registration (SIGTERM, SIGINT)

**Usage:**

```typescript
import { GracefulShutdownManager } from './connection-pool/index.js';

const shutdownManager = new GracefulShutdownManager(pool, logger, {
  gracePeriod: 30000, // 30 seconds
  forceAfterGracePeriod: true,
  notifyClients: true,
});

// Shutdown is automatically triggered on SIGTERM/SIGINT
// Or manually trigger:
const result = await shutdownManager.shutdown();

if (result.success) {
  console.log(`Shutdown completed in ${result.duration}ms`);
  console.log(`Closed ${result.connectionsClosed} connections`);
} else {
  console.error('Shutdown completed with errors:', result.errors);
}

// Close individual WebSocket
await shutdownManager.closeWebSocket(ws, 'Server maintenance');

// Send SSH disconnect
await shutdownManager.sendSSHDisconnect('user123', 'Server shutting down');
```

## Requirements Mapping

### Requirement 4.1: Multi-Tenant Isolation

- ✅ Connections stored per user in separate Map entries
- ✅ No cross-user data access possible
- ✅ User ID validated on every operation

### Requirement 4.6: Separate SSH Sessions

- ✅ Each user gets their own SSH connection instances
- ✅ Connections are never shared between users

### Requirement 4.8: Connection Limits

- ✅ Maximum 3 concurrent connections per user enforced
- ✅ Error thrown when limit exceeded

### Requirement 1.6: Stale Connection Cleanup

- ✅ Automatic cleanup within 60 seconds (configurable)
- ✅ Periodic cleanup task runs every 30 seconds

### Requirement 6.9: Connection Timeout

- ✅ 5-minute idle timeout (configurable)
- ✅ Connections closed after timeout

### Requirement 7.4: SSH Keep-Alive

- ✅ Keep-alive messages sent every 60 seconds
- ✅ Connection marked unhealthy if no response

### Requirement 7.6: SSH Multiplexing

- ✅ Multiple channels supported per connection
- ✅ Channel tracking and management

### Requirement 7.7: Channel Limits

- ✅ Maximum 10 channels per connection
- ✅ Error thrown when limit exceeded

### Requirement 8.2: SSH Disconnect

- ✅ Proper SSH disconnect message sent
- ✅ Graceful closure implemented

### Requirement 8.3: WebSocket Closure

- ✅ Close code 1000 (normal closure) used
- ✅ Proper close handshake

### Requirement 8.4: Wait for In-Flight Requests

- ✅ 30-second grace period implemented
- ✅ Waits for active channels to complete

## Configuration

### Environment Variables

```bash
# Connection Pool
MAX_CONNECTIONS_PER_USER=3
MAX_IDLE_TIME=300000  # 5 minutes
CLEANUP_INTERVAL=30000  # 30 seconds

# SSH Configuration
SSH_KEEPALIVE_INTERVAL=60000  # 60 seconds
SSH_MAX_CHANNELS=10
SSH_CONNECTION_TIMEOUT=30000  # 30 seconds

# Graceful Shutdown
SHUTDOWN_GRACE_PERIOD=30000  # 30 seconds
SHUTDOWN_FORCE_AFTER_GRACE=true
SHUTDOWN_NOTIFY_CLIENTS=true
```

### Default Configuration

```typescript
const defaultConfig = {
  connectionPool: {
    maxConnectionsPerUser: 3,
    maxIdleTime: 300000, // 5 minutes
    cleanupInterval: 30000, // 30 seconds
  },
  sshConnection: {
    keepAliveInterval: 60000, // 60 seconds
    maxChannels: 10,
    connectionTimeout: 30000, // 30 seconds
  },
  cleanup: {
    cleanupInterval: 30000, // 30 seconds
    maxIdleTime: 300000, // 5 minutes
    enabled: true,
  },
  shutdown: {
    gracePeriod: 30000, // 30 seconds
    forceAfterGracePeriod: true,
    notifyClients: true,
  },
};
```

## Integration Example

Complete example integrating all components:

```typescript
import {
  ConnectionPoolImpl,
  ConnectionCleanupService,
  GracefulShutdownManager,
} from './connection-pool/index.js';
import { ConsoleLogger } from './utils/logger.js';

// Initialize logger
const logger = new ConsoleLogger('TunnelServer');

// Create connection pool
const pool = new ConnectionPoolImpl(
  {
    maxConnectionsPerUser: 3,
    maxIdleTime: 300000,
    cleanupInterval: 30000,
  },
  logger
);

// Start cleanup service
const cleanupService = new ConnectionCleanupService(pool, logger);
cleanupService.start();

// Setup graceful shutdown
const shutdownManager = new GracefulShutdownManager(pool, logger);

// Use the pool
async function handleRequest(userId: string, request: any) {
  try {
    // Get connection from pool
    const connection = await pool.getConnection(userId);
    
    // Forward request
    const response = await connection.forward(request);
    
    // Release connection
    pool.releaseConnection(userId, connection);
    
    return response;
  } catch (error) {
    logger.error(`Error handling request for user ${userId}:`, error);
    throw error;
  }
}

// Cleanup on exit
process.on('beforeExit', async () => {
  cleanupService.stop();
  await pool.closeAllConnections();
});
```

## Monitoring

### Pool Statistics

```typescript
// Get pool statistics
const stats = pool.getPoolStats();
console.log(`Total connections: ${stats.totalConnections}`);
console.log(`Active users: ${stats.userCount}`);
console.log('Connections by user:', stats.connectionsByUser);

// Get connection statistics
const connection = await pool.getConnection('user123');
const connStats = connection.getStats();
console.log(`Connection ID: ${connStats.id}`);
console.log(`Uptime: ${connStats.uptime}ms`);
console.log(`Channels: ${connStats.channelCount}`);
console.log(`Healthy: ${connStats.isHealthy}`);
```

### Cleanup Statistics

```typescript
const cleanupStats = cleanupService.getStats();
console.log(`Cleanup running: ${cleanupStats.isRunning}`);
console.log(`Total cleaned: ${cleanupStats.cleanupCount}`);
console.log(`Last cleanup: ${cleanupStats.lastCleanupTime}`);
```

### Shutdown Statistics

```typescript
const shutdownStats = shutdownManager.getStats();
console.log(`Shutdown in progress: ${shutdownStats.isShuttingDown}`);
console.log(`Started at: ${shutdownStats.shutdownStartTime}`);
```

## Testing

### Unit Tests

```typescript
import { ConnectionPoolImpl } from './connection-pool-impl.js';
import { ConsoleLogger } from '../utils/logger.js';

describe('ConnectionPoolImpl', () => {
  let pool: ConnectionPoolImpl;
  let logger: ConsoleLogger;

  beforeEach(() => {
    logger = new ConsoleLogger('Test');
    pool = new ConnectionPoolImpl(
      {
        maxConnectionsPerUser: 3,
        maxIdleTime: 60000,
        cleanupInterval: 10000,
      },
      logger
    );
  });

  afterEach(async () => {
    await pool.closeAllConnections();
    pool.stopCleanupTask();
  });

  test('should create new connection for user', async () => {
    const connection = await pool.getConnection('user1');
    expect(connection).toBeDefined();
    expect(connection.userId).toBe('user1');
  });

  test('should reuse existing connection', async () => {
    const conn1 = await pool.getConnection('user1');
    pool.releaseConnection('user1', conn1);
    
    const conn2 = await pool.getConnection('user1');
    expect(conn2.id).toBe(conn1.id);
  });

  test('should enforce connection limit', async () => {
    await pool.getConnection('user1');
    await pool.getConnection('user1');
    await pool.getConnection('user1');
    
    await expect(pool.getConnection('user1')).rejects.toThrow('Connection limit exceeded');
  });

  test('should clean up stale connections', async () => {
    const connection = await pool.getConnection('user1');
    connection.lastUsedAt = new Date(Date.now() - 120000); // 2 minutes ago
    
    const cleaned = await pool.cleanupStaleConnections(60000);
    expect(cleaned).toBe(1);
  });
});
```

## Troubleshooting

### Connection Limit Exceeded

**Error:** `Connection limit exceeded. Maximum 3 concurrent connections allowed.`

**Solution:**

- Check if connections are being properly released
- Verify that old connections are being cleaned up
- Consider increasing `maxConnectionsPerUser` if needed

### Stale Connections Not Cleaned

**Issue:** Connections remain in pool after idle timeout

**Solution:**

- Verify cleanup service is running: `cleanupService.getStats().isRunning`
- Check cleanup interval configuration
- Manually trigger cleanup: `cleanupService.triggerCleanup()`

### Keep-Alive Failures

**Issue:** Connections marked as unhealthy

**Solution:**

- Check network connectivity
- Verify SSH server is responding to keep-alive
- Review keep-alive interval configuration
- Check connection logs for errors

### Graceful Shutdown Timeout

**Issue:** Shutdown takes longer than grace period

**Solution:**

- Increase `gracePeriod` configuration
- Check for stuck in-flight requests
- Review connection closure logs
- Consider enabling `forceAfterGracePeriod`

## Performance Considerations

### Connection Reuse

- Reusing connections reduces overhead of SSH handshake
- Pool maintains connections for quick access
- Health checks ensure only valid connections are reused

### Memory Usage

- Each connection consumes memory for SSH state
- Cleanup service prevents memory leaks
- Connection limits prevent resource exhaustion

### CPU Usage

- Keep-alive messages use minimal CPU
- Cleanup runs periodically, not continuously
- Channel multiplexing reduces connection overhead

## Security Considerations

### User Isolation

- Connections are strictly isolated per user
- No cross-user access possible
- User ID validated on every operation

### Connection Limits

- Prevents resource exhaustion attacks
- Limits per-user resource consumption
- Protects against connection storms

### Graceful Shutdown

- Prevents data loss during shutdown
- Ensures proper cleanup of resources
- Notifies clients before disconnection

## Future Enhancements

1. **Connection Pooling Strategies**
   - Implement different pooling strategies (LIFO, FIFO, LRU)
   - Add connection warming
   - Implement connection pre-allocation

2. **Advanced Health Checks**
   - Ping-based health checks
   - Latency-based health scoring
   - Automatic connection replacement

3. **Metrics and Monitoring**
   - Prometheus metrics export
   - Connection pool dashboard
   - Performance analytics

4. **Load Balancing**
   - Distribute connections across multiple SSH servers
   - Implement failover mechanisms
   - Add connection affinity

## References

- [SSH Protocol RFC 4254](https://tools.ietf.org/html/rfc4254)
- [WebSocket Protocol RFC 6455](https://tools.ietf.org/html/rfc6455)
- [Connection Pooling Best Practices](https://en.wikipedia.org/wiki/Connection_pool)
