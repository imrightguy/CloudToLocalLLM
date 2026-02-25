# Getting Started with WebSocket Connection Management

## Prerequisites

- Node.js 18+ installed
- TypeScript knowledge
- Understanding of WebSocket protocol
- JWT authentication setup (Auth0)

## Installation

The WebSocket module is part of the streaming-proxy service. No additional installation required.

```bash
cd services/streaming-proxy
npm install
```

## Quick Setup (5 minutes)

### Step 1: Configure Environment

Create `.env` file in `services/streaming-proxy/`:

```bash
# Auth0 Configuration
SUPABASE_AUTH_DOMAIN=your-domain.auth0.com
SUPABASE_AUTH_AUDIENCE=https://api.CloudToLocalLLM.com
SUPABASE_AUTH_ISSUER=https://your-domain.auth0.com/

# WebSocket Configuration
WEBSOCKET_PORT=3001
WEBSOCKET_PATH=/ws

# Heartbeat Configuration
PING_INTERVAL=30000
PONG_TIMEOUT=5000
MAX_MISSED_PONGS=3

# Compression Configuration
COMPRESSION_ENABLED=true
COMPRESSION_LEVEL=6
COMPRESSION_THRESHOLD=1024

# Frame Size Configuration
MAX_FRAME_SIZE=1048576
FRAME_WARN_THRESHOLD=524288
```

### Step 2: Create Server

Create `src/server.ts`:

```typescript
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import {
  WebSocketHandlerImpl,
  CompressionManager,
} from './websocket';
import { JWTValidationMiddleware } from './middleware';
import { TokenBucketRateLimiter } from './rate-limiter';

// Load configuration
const PORT = parseInt(process.env.WEBSOCKET_PORT || '3001');

// Create auth middleware
const authMiddleware = new JWTValidationMiddleware({
  domain: process.env.SUPABASE_AUTH_DOMAIN!,
  audience: process.env.SUPABASE_AUTH_AUDIENCE!,
  issuer: process.env.SUPABASE_AUTH_ISSUER!,
});

// Create rate limiter
const rateLimiter = new TokenBucketRateLimiter();

// Create compression manager
const compressionManager = CompressionManager.createDefault();

// Create WebSocket server with compression
const wss = new WebSocketServer({
  noServer: true,
  perMessageDeflate: compressionManager.getCompressionOptions(),
});

compressionManager.configureServer(wss);

// Create WebSocket handler
const wsHandler = new WebSocketHandlerImpl(wss, authMiddleware, rateLimiter);

// Create HTTP server
const server = createServer((req, res) => {
  res.writeHead(200);
  res.end('WebSocket server running');
});

// Handle WebSocket upgrade
server.on('upgrade', async (req, socket, head) => {
  await wsHandler.handleUpgrade(req, socket, head);
});

// Start server
server.listen(PORT, () => {
  console.log(`WebSocket server listening on port ${PORT}`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('Shutting down gracefully...');
  await wsHandler.closeAllConnections('Server shutdown');
  server.close();
  process.exit(0);
});
```

### Step 3: Run Server

```bash
npm run dev
```

### Step 4: Test Connection

Create `test-client.ts`:

```typescript
import WebSocket from 'ws';

const token = 'your-jwt-token';
const ws = new WebSocket(`ws://localhost:3001?token=${token}`);

ws.on('open', () => {
  console.log('Connected!');
  
  // Send test message
  ws.send(JSON.stringify({
    type: 'request',
    requestId: '123',
    payload: { action: 'test' },
    timestamp: Date.now(),
  }));
});

ws.on('message', (data) => {
  console.log('Received:', data.toString());
});

ws.on('close', (code, reason) => {
  console.log(`Closed: ${code} - ${reason}`);
});

ws.on('error', (error) => {
  console.error('Error:', error);
});
```

Run test:

```bash
npx ts-node test-client.ts
```

## Common Use Cases

### Use Case 1: Basic WebSocket Server

```typescript
import { WebSocketHandlerImpl } from './websocket';

const wsHandler = new WebSocketHandlerImpl(wss, authMiddleware, rateLimiter);

// That's it! Handler manages everything automatically
```

### Use Case 2: Custom Heartbeat Configuration

```typescript
import { HeartbeatManager } from './websocket';

const heartbeatManager = new HeartbeatManager({
  pingInterval: 15000,  // 15 seconds
  pongTimeout: 3000,    // 3 seconds
  maxMissedPongs: 5,    // 5 missed pongs
});

// Use in custom WebSocket handler
heartbeatManager.startHeartbeat(ws, (ws) => {
  console.log('Connection dead, closing...');
  ws.close(1001, 'Connection timeout');
});
```

### Use Case 3: High Compression for Large Messages

```typescript
import { CompressionManager } from './websocket';

const compressionManager = CompressionManager.createHighCompression();

const wss = new WebSocketServer({
  perMessageDeflate: compressionManager.getCompressionOptions(),
});
```

### Use Case 4: Strict Frame Size Limits

```typescript
import { FrameSizeValidator } from './websocket';

const validator = FrameSizeValidator.createStrict(); // 256KB max

ws.on('message', (data) => {
  if (!validator.validateAndHandle(ws, data.length, userId, connectionId)) {
    return; // Frame too large, connection closed
  }
  
  // Process message
});
```

### Use Case 5: Graceful Shutdown

```typescript
import { GracefulCloseManager, CloseCode } from './websocket';

const closeManager = new GracefulCloseManager();

process.on('SIGTERM', async () => {
  const connections = []; // Get all connections
  
  await closeManager.closeAll(connections, {
    code: CloseCode.SERVICE_RESTART,
    reason: 'Server maintenance',
    timeout: 10000, // 10 seconds
  });
  
  process.exit(0);
});
```

## Monitoring and Debugging

### Check Connection Health

```typescript
const health = await wsHandler.checkConnectionHealth();

console.log({
  active: health.activeConnections,
  healthy: health.healthyConnections,
  unhealthy: health.unhealthyConnections,
  avgLatency: health.averageLatency,
});
```

### Monitor Compression

```typescript
const stats = compressionManager.getStats();

console.log({
  ratio: compressionManager.getCompressionRatioPercent(),
  avgSaved: compressionManager.getAverageBytesSaved(),
  compressed: stats.messagesCompressed,
  uncompressed: stats.messagesUncompressed,
});
```

### Monitor Frame Sizes

```typescript
const stats = validator.getStats();

console.log({
  totalFrames: stats.totalFrames,
  violations: stats.violations,
  warnings: stats.warnings,
  largestFrame: stats.largestFrame,
  avgFrameSize: stats.averageFrameSize,
});
```

### View Logs

All components use structured JSON logging:

```bash
# View all logs
npm run dev | jq

# Filter connection events
npm run dev | jq 'select(.type | startswith("connection"))'

# Filter heartbeat events
npm run dev | jq 'select(.type | startswith("heartbeat"))'

# Filter errors
npm run dev | jq 'select(.type | endswith("error"))'
```

## Troubleshooting

### Problem: Connection Refused

**Symptoms**: Client cannot connect to server

**Solutions**:

1. Check server is running: `curl http://localhost:3001`
2. Check port is not in use: `netstat -an | grep 3001`
3. Check firewall settings

### Problem: Authentication Failed

**Symptoms**: `401 Unauthorized` error

**Solutions**:

1. Verify JWT token is valid: Use jwt.io to decode
2. Check token expiration
3. Verify Auth0 configuration (domain, audience, issuer)
4. Check token is passed correctly (query string or header)

### Problem: Rate Limit Exceeded

**Symptoms**: `429 Too Many Requests` error

**Solutions**:

1. Reduce request rate
2. Check user tier limits
3. Implement exponential backoff
4. Upgrade user tier if needed

### Problem: Connection Timeout

**Symptoms**: Connection closes with code 1001

**Solutions**:

1. Check network connectivity
2. Ensure client responds to pings
3. Increase ping interval if needed
4. Check for network proxies blocking WebSocket

### Problem: Message Too Large

**Symptoms**: Connection closes with code 1009

**Solutions**:

1. Reduce message size
2. Split message into multiple smaller messages
3. Increase frame size limit (if appropriate)
4. Enable compression

## Best Practices

### 1. Always Use Authentication

```typescript
// ✅ Good: Token in query string
const ws = new WebSocket(`ws://localhost:3001?token=${token}`);

// ✅ Good: Token in header (if supported)
const ws = new WebSocket('ws://localhost:3001', {
  headers: { Authorization: `Bearer ${token}` }
});

// ❌ Bad: No authentication
const ws = new WebSocket('ws://localhost:3001');
```

### 2. Handle Reconnection

```typescript
// ✅ Good: Exponential backoff reconnection
let reconnectAttempts = 0;

function connect() {
  const ws = new WebSocket(`ws://localhost:3001?token=${token}`);
  
  ws.onclose = (event) => {
    if (event.code === 1000) return; // Normal closure
    
    const delay = Math.min(1000 * Math.pow(2, reconnectAttempts), 30000);
    reconnectAttempts++;
    setTimeout(connect, delay);
  };
  
  ws.onopen = () => {
    reconnectAttempts = 0;
  };
}
```

### 3. Implement Request Timeout

```typescript
// ✅ Good: Timeout for requests
function sendRequest(ws, request, timeout = 30000) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error('Request timeout'));
    }, timeout);
    
    ws.send(JSON.stringify(request));
    
    ws.once('message', (data) => {
      clearTimeout(timer);
      resolve(JSON.parse(data.toString()));
    });
  });
}
```

### 4. Use Structured Messages

```typescript
// ✅ Good: Structured message format
interface Message {
  type: 'request' | 'response' | 'error';
  requestId: string;
  payload: any;
  timestamp: number;
}

ws.send(JSON.stringify({
  type: 'request',
  requestId: crypto.randomUUID(),
  payload: { action: 'getData' },
  timestamp: Date.now(),
}));
```

### 5. Handle Errors Gracefully

```typescript
// ✅ Good: Comprehensive error handling
ws.onerror = (error) => {
  console.error('WebSocket error:', error);
  // Log to monitoring service
  // Show user-friendly message
  // Attempt reconnection
};

ws.onclose = (event) => {
  if (event.code !== 1000) {
    console.error(`Abnormal closure: ${event.code} - ${event.reason}`);
    // Handle reconnection
  }
};
```

## Next Steps

1. Read the [README.md](./README.md) for detailed documentation
2. Review [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md) for architecture details
3. Check [QUICK_START.md](./QUICK_START.md) for quick reference
4. Integrate with ConnectionPool for SSH forwarding
5. Add metrics collection (Task 12)
6. Implement structured logging (Task 13)
7. Add health check endpoints (Task 14)

## Support

For issues or questions:

1. Check the documentation in this directory
2. Review the implementation code
3. Check the requirements document
4. Contact the development team

## License

Part of CloudToLocalLLM project. See main LICENSE file.
