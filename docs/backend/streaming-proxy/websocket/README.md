# WebSocket Connection Management

This module provides comprehensive WebSocket connection management for the streaming proxy server, including authentication, rate limiting, heartbeat monitoring, compression, frame size validation, and graceful closure.

## Components

### 1. WebSocketHandlerImpl

Main WebSocket handler that manages connection lifecycle and integrates all components.

**Features:**
- WebSocket upgrade handling with JWT authentication
- Connection lifecycle management (connect, disconnect, message routing)
- Integration with AuthMiddleware for authentication
- Integration with RateLimiter for rate limiting
- Connection tracking and metadata management
- Heartbeat monitoring
- Message routing and handling

**Usage:**
```typescript
import { WebSocketHandlerImpl } from './websocket';
import { WebSocketServer } from 'ws';

const wss = new WebSocketServer({ noServer: true });
const handler = new WebSocketHandlerImpl(wss, authMiddleware, rateLimiter);

// Handle upgrade requests
server.on('upgrade', (req, socket, head) => {
  handler.handleUpgrade(req, socket, head);
});

// Check connection health
const health = await handler.checkConnectionHealth();
console.log(`Active connections: ${health.activeConnections}`);
```

### 2. HeartbeatManager

Manages WebSocket heartbeat monitoring using ping/pong protocol.

**Features:**
- Automatic ping/pong heartbeat every 30 seconds
- Detects dead connections within 5 seconds of missed pong
- Tracks latency and connection health
- Configurable ping interval and pong timeout
- Automatic connection closure for unresponsive connections

**Usage:**
```typescript
import { HeartbeatManager } from './websocket';

const heartbeatManager = new HeartbeatManager({
  pingInterval: 30000, // 30 seconds
  pongTimeout: 5000, // 5 seconds
  maxMissedPongs: 3, // Close after 3 missed pongs
});

// Start monitoring
heartbeatManager.startHeartbeat(ws, (ws) => {
  console.log('Connection timeout - closing');
  ws.close(1001, 'Connection timeout');
});

// Check health
const isHealthy = heartbeatManager.isConnectionHealthy(ws);

// Get stats
const stats = heartbeatManager.getHeartbeatStats(ws);
console.log(`Latency: ${stats.latency}ms`);
```

### 3. CompressionManager

Manages WebSocket compression using permessage-deflate extension.

**Features:**
- Configurable compression level (0-9)
- Compression threshold (only compress messages above threshold)
- Compression statistics tracking
- Error handling and recovery
- Multiple compression profiles (default, high, fast, disabled)

**Usage:**
```typescript
import { CompressionManager } from './websocket';

// Create compression manager
const compressionManager = CompressionManager.createDefault();

// Configure WebSocket server
const wss = new WebSocketServer({
  perMessageDeflate: compressionManager.getCompressionOptions(),
});

compressionManager.configureServer(wss);

// Get statistics
const stats = compressionManager.getStats();
console.log(`Compression ratio: ${compressionManager.getCompressionRatioPercent()}%`);
console.log(`Average bytes saved: ${compressionManager.getAverageBytesSaved()}`);
```

**Compression Profiles:**
- **Default**: Balanced compression (level 6, 1KB threshold)
- **High**: Maximum compression (level 9, 512B threshold)
- **Fast**: Minimal compression (level 1, 2KB threshold)
- **Disabled**: No compression

### 4. FrameSizeValidator

Validates WebSocket frame sizes and enforces limits to prevent memory exhaustion.

**Features:**
- Configurable maximum frame size (default: 1MB)
- Warning threshold for large frames
- Violation tracking and logging
- Statistics collection
- Automatic connection closure for oversized frames

**Usage:**
```typescript
import { FrameSizeValidator } from './websocket';

const validator = FrameSizeValidator.createDefault();

// Validate frame size
const result = validator.validateFrameSize(frameSize, userId, connectionId);

if (!result.valid) {
  console.error(`Frame too large: ${result.frameSize} > ${result.maxSize}`);
  ws.close(1009, 'Message too large');
}

// Or validate and handle automatically
const isValid = validator.validateAndHandle(ws, frameSize, userId, connectionId);

// Get statistics
const stats = validator.getStats();
console.log(validator.getSummary());
```

**Validator Profiles:**
- **Default**: 1MB max, 512KB warning
- **Strict**: 256KB max, 128KB warning
- **Lenient**: 10MB max, 5MB warning

### 5. GracefulCloseManager

Manages graceful WebSocket connection closure with proper handshake.

**Features:**
- Proper close handshake with acknowledgment
- Appropriate close codes (RFC 6455)
- Configurable timeout for close acknowledgment
- Force close option for unresponsive connections
- Batch close operations
- Close metadata tracking

**Usage:**
```typescript
import { GracefulCloseManager, CloseCode } from './websocket';

const closeManager = new GracefulCloseManager();

// Close with normal closure code
await closeManager.closeNormal(ws, 'User disconnected');

// Close due to server shutdown
await closeManager.closeGoingAway(ws, 'Server maintenance');

// Close due to error
await closeManager.closeInternalError(ws, 'Database connection failed');

// Close all connections
await closeManager.closeAll(connections, {
  code: CloseCode.SERVICE_RESTART,
  reason: 'Server restart',
  timeout: 5000,
});

// Check if closing
if (closeManager.isClosing(ws)) {
  console.log('Connection is closing...');
}
```

**Close Codes:**
- `1000`: Normal closure
- `1001`: Going away (server shutdown)
- `1002`: Protocol error
- `1008`: Policy violation
- `1009`: Message too big
- `1011`: Internal error
- `1012`: Service restart

## Integration Example

Complete example integrating all components:

```typescript
import { WebSocketServer } from 'ws';
import {
  WebSocketHandlerImpl,
  HeartbeatManager,
  CompressionManager,
  FrameSizeValidator,
  GracefulCloseManager,
} from './websocket';
import { JWTValidationMiddleware } from './middleware';
import { TokenBucketRateLimiter } from './rate-limiter';

// Create components
const authMiddleware = new JWTValidationMiddleware(auth0Config);
const rateLimiter = new TokenBucketRateLimiter();
const compressionManager = CompressionManager.createDefault();

// Create WebSocket server with compression
const wss = new WebSocketServer({
  noServer: true,
  perMessageDeflate: compressionManager.getCompressionOptions(),
});

compressionManager.configureServer(wss);

// Create WebSocket handler
const wsHandler = new WebSocketHandlerImpl(wss, authMiddleware, rateLimiter);

// Handle HTTP upgrade requests
server.on('upgrade', async (req, socket, head) => {
  await wsHandler.handleUpgrade(req, socket, head);
});

// Graceful shutdown
const closeManager = new GracefulCloseManager();

process.on('SIGTERM', async () => {
  console.log('Shutting down gracefully...');
  
  const connections = wsHandler.getConnectionsByUserId('*'); // Get all
  await closeManager.closeAll(connections, {
    code: CloseCode.SERVICE_RESTART,
    reason: 'Server restart',
  });
  
  process.exit(0);
});
```

## Configuration

### Environment Variables

```bash
# WebSocket Configuration
WEBSOCKET_PORT=3001
WEBSOCKET_PATH=/ws

# Heartbeat Configuration
PING_INTERVAL=30000  # 30 seconds
PONG_TIMEOUT=5000    # 5 seconds
MAX_MISSED_PONGS=3

# Compression Configuration
COMPRESSION_ENABLED=true
COMPRESSION_LEVEL=6
COMPRESSION_THRESHOLD=1024  # 1KB

# Frame Size Configuration
MAX_FRAME_SIZE=1048576  # 1MB
FRAME_WARN_THRESHOLD=524288  # 512KB

# Close Configuration
CLOSE_TIMEOUT=5000  # 5 seconds
```

## Monitoring

### Health Check

```typescript
const health = await wsHandler.checkConnectionHealth();

console.log({
  activeConnections: health.activeConnections,
  healthyConnections: health.healthyConnections,
  unhealthyConnections: health.unhealthyConnections,
  averageLatency: health.averageLatency,
});
```

### Metrics

```typescript
// Heartbeat metrics
const heartbeatStats = heartbeatManager.getAllHeartbeatStats();

// Compression metrics
const compressionStats = compressionManager.getStats();
console.log(compressionManager.getSummary());

// Frame size metrics
const frameSizeStats = validator.getStats();
console.log(validator.getSummary());

// Close metrics
const closingCount = closeManager.getClosingCount();
```

## Error Handling

All components include comprehensive error handling and logging:

- **Connection errors**: Logged with connection metadata
- **Heartbeat timeouts**: Logged with latency and missed pong count
- **Compression errors**: Logged with error details and statistics
- **Frame size violations**: Logged with frame size and user info
- **Close errors**: Logged with close code and reason

## Testing

See `websocket-handler.test.ts` for comprehensive test examples.

## Requirements Satisfied

This implementation satisfies the following requirements:

- **6.1**: WebSocket ping/pong heartbeat every 30 seconds
- **6.2**: Detect connection loss within 45 seconds
- **6.3**: Respond to ping frames within 5 seconds
- **6.4**: WebSocket compression (permessage-deflate)
- **6.6**: Limit WebSocket frame size to 1MB
- **6.7**: Graceful WebSocket close with proper close codes
- **6.8**: Handle WebSocket upgrade requests
- **6.9**: WebSocket connection timeout (5 minutes idle)
- **6.10**: Log all WebSocket lifecycle events
- **4.2**: JWT token validation on connection
- **4.3**: Rate limiting per user

## Next Steps

1. Integrate with ConnectionPool for SSH forwarding
2. Add OpenTelemetry tracing
3. Implement metrics collection endpoint
4. Add load testing
5. Deploy to Kubernetes
