# Library Quick Reference Guide

Quick lookup guide for implementing features using ws, ssh2, and prom-client libraries.

## WebSocket (ws) - Quick Lookup

### Connection Heartbeat

```typescript
// Server-side heartbeat
function heartbeat() {
  this.isAlive = true;
}

wss.on('connection', (ws) => {
  ws.isAlive = true;
  ws.on('pong', heartbeat);
});

// Check connections every 30 seconds
const interval = setInterval(() => {
  wss.clients.forEach((ws) => {
    if (ws.isAlive === false) return ws.terminate();
    ws.isAlive = false;
    ws.ping();
  });
}, 30000);
```

### Frame Size Validation

```typescript
// Enforce 1MB max frame size
const ws = new WebSocket(url, {
  maxPayload: 1048576 // 1MB
});
```

### Compression Configuration

```typescript
// Enable permessage-deflate
const wss = new WebSocketServer({
  perMessageDeflate: {
    zlibDeflateOptions: {
      chunkSize: 1024,
      memLevel: 7,
      level: 3
    },
    clientNoContextTakeover: true,
    serverNoContextTakeover: true,
    serverMaxWindowBits: 10,
    concurrencyLimit: 10,
    threshold: 1024
  }
});
```

### Authentication During Upgrade

```typescript
server.on('upgrade', (request, socket, head) => {
  const token = new URL(request.url, 'ws://base').searchParams.get('token');
  
  if (!authenticate(token)) {
    socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
    socket.destroy();
    return;
  }
  
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});
```

### Graceful Close

```typescript
// Close with proper handshake
ws.close(1000, 'Normal closure');

// Server shutdown
wss.clients.forEach((client) => {
  client.close(1001, 'Server going away');
});
```

---

## SSH2 - Quick Lookup

### Security Configuration

```typescript
const conn = new Client();
conn.connect({
  host: 'example.com',
  username: 'user',
  password: 'pass',
  algorithms: {
    kex: ['curve25519-sha256', 'ecdh-sha2-nistp256'],
    cipher: ['aes256-gcm@openssh.com', 'aes256-ctr'],
    hmac: ['hmac-sha2-256', 'hmac-sha2-512'],
    serverHostKey: ['ssh-ed25519', 'ecdsa-sha2-nistp256']
  }
});
```

### Keep-Alive Implementation

```typescript
// Send keep-alive every 60 seconds
const keepAliveInterval = setInterval(() => {
  if (conn.exec('echo keep-alive', (err, stream) => {
    if (err) {
      clearInterval(keepAliveInterval);
      conn.end();
    }
    stream.on('close', () => {
      // Keep-alive successful
    });
  })) {
    // Command sent
  }
}, 60000);
```

### Channel Multiplexing

```typescript
// Track channels per connection
let channelCount = 0;
const maxChannels = 10;

function openChannel() {
  if (channelCount >= maxChannels) {
    throw new Error('Channel limit exceeded (10 channels per connection)');
  }
  channelCount++;
}

function closeChannel() {
  channelCount--;
}
```

### SSH Compression

```typescript
const conn = new Client();
conn.connect({
  host: 'example.com',
  username: 'user',
  compress: true,
  algorithms: {
    compress: ['zlib@openssh.com', 'zlib', 'none']
  }
});
```

### Port Forwarding (Local)

```typescript
// Forward local port to remote service
conn.forwardOut('127.0.0.1', 8000, '10.1.1.40', 22, (err, stream) => {
  if (err) throw err;
  
  // Use stream for tunneled connection
  const client2 = new Client();
  client2.connect({
    sock: stream,
    username: 'user2',
    password: 'pass2'
  });
});
```

### Port Forwarding (Remote)

```typescript
// Request server to listen and forward to client
conn.forwardIn('127.0.0.1', 8000, (err) => {
  if (err) throw err;
  console.log('Server listening on port 8000');
});

conn.on('tcp connection', (info, accept, reject) => {
  const stream = accept();
  // Handle incoming connection
  stream.end('HTTP/1.1 200 OK\r\n\r\n');
});
```

### Error Handling

```typescript
// Categorize SSH errors
function categorizeSSHError(error) {
  if (error.message.includes('auth')) return 'auth';
  if (error.message.includes('protocol')) return 'protocol';
  if (error.message.includes('ECONNREFUSED')) return 'network';
  if (error.message.includes('timeout')) return 'timeout';
  return 'unknown';
}

conn.on('error', (err) => {
  const category = categorizeSSHError(err);
  logger.error('SSH error', {
    category,
    message: err.message,
    connectionId: conn.id
  });
});
```

---

## Prometheus Client (prom-client) - Quick Lookup

### Counter Metric

```typescript
const requestCounter = new Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'status']
});

// Increment
requestCounter.inc({ method: 'GET', status: '200' });
requestCounter.inc({ method: 'POST', status: '201' }, 5); // Increment by 5
```

### Gauge Metric

```typescript
const activeConnections = new Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
  labelNames: ['service']
});

// Set, increment, decrement
activeConnections.set({ service: 'api' }, 42);
activeConnections.inc({ service: 'api' });
activeConnections.dec({ service: 'api' }, 3);
```

### Histogram Metric

```typescript
const requestDuration = new Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration',
  labelNames: ['method', 'endpoint'],
  buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1, 2, 5]
});

// Observe value
requestDuration.observe({ method: 'GET', endpoint: '/api/users' }, 0.123);

// Use timer
const end = requestDuration.startTimer({ method: 'GET', endpoint: '/api/users' });
// ... perform operation ...
end(); // Records duration automatically
```

### Summary Metric

```typescript
const latency = new Summary({
  name: 'request_latency_seconds',
  help: 'Request latency percentiles',
  labelNames: ['service'],
  percentiles: [0.5, 0.9, 0.95, 0.99]
});

// Observe value
latency.observe({ service: 'api' }, 0.15);

// Use timer
const end = latency.startTimer({ service: 'api' });
// ... perform operation ...
end();
```

### Bucket Generation

```typescript
// Linear buckets: [0, 100, 200, 300, 400, 500]
buckets: linearBuckets(0, 100, 6)

// Exponential buckets: [1, 2, 4, 8, 16, 32]
buckets: exponentialBuckets(1, 2, 6)
```

### Metrics Endpoint

```typescript
const express = require('express');
const app = express();

app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    res.status(500).end(err.message);
  }
});
```

### Default Metrics

```typescript
const { collectDefaultMetrics, register } = require('prom-client');

// Enable with custom configuration
collectDefaultMetrics({
  prefix: 'myapp_',
  gcDurationBuckets: [0.001, 0.01, 0.1, 1, 2, 5],
  labels: {
    app: 'streaming-proxy',
    environment: 'production'
  }
});
```

### Custom Registry

```typescript
const customRegistry = new Registry();

const counter = new Counter({
  name: 'custom_metric',
  help: 'Custom metric',
  registers: [customRegistry]
});

// Get metrics from custom registry
const metrics = await customRegistry.metrics();
```

### Metric Initialization

```typescript
// Initialize all expected label combinations to zero
const histogram = new Histogram({
  name: 'request_duration',
  help: 'Request duration',
  labelNames: ['method', 'endpoint']
});

histogram.zero({ method: 'GET', endpoint: '/api/users' });
histogram.zero({ method: 'POST', endpoint: '/api/users' });
```

---

## Common Patterns

### WebSocket + Metrics

```typescript
const requestCounter = new Counter({
  name: 'ws_messages_total',
  help: 'Total WebSocket messages',
  labelNames: ['type']
});

wss.on('connection', (ws) => {
  ws.on('message', (data) => {
    requestCounter.inc({ type: 'received' });
    // Process message
  });
});
```

### SSH + Metrics

```typescript
const sshErrors = new Counter({
  name: 'ssh_errors_total',
  help: 'Total SSH errors',
  labelNames: ['type']
});

conn.on('error', (err) => {
  const type = categorizeSSHError(err);
  sshErrors.inc({ type });
});
```

### Connection Pool + Metrics

```typescript
const poolSize = new Gauge({
  name: 'connection_pool_size',
  help: 'Connection pool size',
  labelNames: ['status']
});

// Update metrics
poolSize.set({ status: 'active' }, activeCount);
poolSize.set({ status: 'idle' }, idleCount);
```

---

## Troubleshooting

### WebSocket Connection Issues

- Check heartbeat interval (30s recommended)
- Verify frame size limits (1MB default)
- Check authentication token validation
- Verify close codes (1000=normal, 1001=going away)

### SSH Connection Issues

- Verify security algorithms are supported
- Check keep-alive interval (60s recommended)
- Verify channel limits (10 per connection)
- Check error categorization for proper recovery

### Metrics Issues

- Verify label cardinality (avoid high-cardinality labels)
- Check bucket configuration for histograms
- Verify metric initialization with zero()
- Check registry configuration

---

**Last Updated:** November 15, 2025  
**Purpose:** Development reference for ws, ssh2, and prom-client libraries
