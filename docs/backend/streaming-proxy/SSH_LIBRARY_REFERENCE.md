# SSH Library Reference Guide

## Quick Reference

**Library:** SSH2  
**Context7 ID:** `/mscdex/ssh2`  
**NPM Package:** `ssh2`  
**Documentation:** [SSH_LIBRARY_DOCUMENTATION.md](./src/SSH_LIBRARY_DOCUMENTATION.md)

---

## Key Implementation Files

### SSH Connection Management

- **File:** `src/connection-pool/ssh-connection-impl.ts`
- **Purpose:** Implements SSH connection wrapper with security best practices
- **Key Features:**
  - SSH protocol version 2 only (Requirement 7.1)
  - Modern algorithms: ED25519, ECDH, AES-256-GCM (Requirements 7.2, 7.3)
  - Keep-alive every 60 seconds (Requirement 7.4)
  - Channel multiplexing with limit of 10 (Requirements 7.6, 7.7)
  - SSH compression support (Requirement 7.8)
  - Comprehensive error logging (Requirement 7.10)

### SSH Error Handling

- **File:** `src/connection-pool/ssh-error-handler.ts`
- **Purpose:** Categorizes and handles SSH protocol errors
- **Key Features:**
  - Error categorization (Network, Auth, Config, Server, Unknown)
  - Timing-safe comparisons for authentication
  - Detailed error context logging
  - Automatic recovery strategies

### Connection Pool

- **File:** `src/connection-pool/connection-pool-impl.ts`
- **Purpose:** Manages SSH connections per user with pooling
- **Key Features:**
  - Per-user connection limits (max 3 concurrent)
  - Connection reuse for efficiency
  - Stale connection cleanup
  - Graceful shutdown support

---

## SSH Security Best Practices

### 1. Authentication

- Use **timing-safe comparisons** for password/key validation
- Support multiple auth methods: public key (recommended), password, keyboard-interactive
- Implement rate limiting to prevent brute force
- Log all authentication attempts

### 2. Key Management

- Generate keys with **ED25519** (recommended) or ECDSA-256
- Use **AES-256-GCM** for encryption
- Verify and cache host keys to prevent MITM attacks
- Never expose private keys to application

### 3. Connection Security

- Enforce SSH protocol version 2 only
- Use modern algorithms: ECDH, SHA-256+
- Disable compression by default (information leak risk)
- Implement keep-alive every 60 seconds
- Detect dead connections within 180 seconds

### 4. Channel Management

- Support multiplexing (multiple channels per connection)
- Limit channels to 10 per connection
- Implement graceful channel closure
- Track active channels and enforce limits

### 5. Error Handling

- Log all SSH errors with detailed context
- Categorize errors for appropriate recovery
- Provide user-friendly error messages
- Include actionable suggestions

---

## Code Examples

### Secure SSH Connection Initialization

```typescript
import { SSHConnectionImpl } from './ssh-connection-impl';
import { Logger } from '../utils/logger';

const logger = new Logger('ssh-tunnel');

// Create SSH connection with secure defaults
const connection = new SSHConnectionImpl(userId, logger, {
  keepAliveInterval: 60000,      // 60 seconds (Requirement 7.4)
  maxChannels: 10,               // Requirement 7.7
  connectionTimeout: 30000,      // 30 seconds
  algorithms: {
    // Modern key exchange (Requirement 7.2)
    kex: ['curve25519-sha256', 'ecdh-sha2-nistp256'],
    // AES-256-GCM encryption (Requirement 7.3)
    cipher: ['aes256-gcm@openssh.com', 'aes256-ctr'],
    // Secure MAC algorithms
    mac: ['hmac-sha2-256', 'hmac-sha2-512'],
  },
  compression: true,             // SSH compression (Requirement 7.8)
});

// Forward request through tunnel
const response = await connection.forward({
  id: 'req-123',
  path: '/api/ollama/generate',
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: Buffer.from(JSON.stringify({ model: 'llama2' })),
});

// Check connection health
if (connection.isHealthy()) {
  console.log('Connection is healthy');
}

// Get connection statistics
const stats = connection.getStats();
console.log(`Compression ratio: ${stats.compressionRatio}`);
console.log(`Active channels: ${stats.activeChannels}/${10}`);

// Graceful shutdown
await connection.close();
```

### Error Handling

```typescript
import { SSHErrorHandler } from './ssh-error-handler';

const errorHandler = new SSHErrorHandler(logger);

try {
  await connection.forward(request);
} catch (error) {
  // Handle SSH error with categorization
  const sshError = errorHandler.handleSSHError(
    error instanceof Error ? error : new Error(String(error)),
    connection.id,
    connection.userId
  );
  
  // Log error with context
  logger.error(`SSH Error: ${sshError.message}`, {
    category: sshError.type,
    connectionId: connection.id,
    userId: connection.userId,
    timestamp: new Date().toISOString(),
  });
  
  // Implement recovery strategy
  switch (sshError.type) {
    case 'NETWORK_ERROR':
      // Retry with exponential backoff
      await retryWithBackoff(() => connection.forward(request));
      break;
    case 'AUTH_ERROR':
      // Refresh credentials and retry
      await refreshCredentials();
      await connection.forward(request);
      break;
    case 'SERVER_ERROR':
      // Use circuit breaker pattern
      circuitBreaker.recordFailure();
      break;
  }
}
```

### Keep-Alive Implementation

```typescript
// Keep-alive is automatically managed by SSHConnectionImpl
// Sends keep-alive every 60 seconds (Requirement 7.4)
// Detects dead connections after 180 seconds (3 missed keep-alives)

// Monitor connection health
setInterval(() => {
  if (!connection.isHealthy()) {
    logger.warn(`Connection ${connection.id} is unhealthy`);
    // Trigger reconnection
    connectionPool.removeConnection(connection.id);
  }
}, 30000); // Check every 30 seconds
```

### Channel Multiplexing

```typescript
// Multiple channels over single SSH connection (Requirement 7.6)
// Limit: 10 channels per connection (Requirement 7.7)

// Channel 1: Forward request 1
const response1 = await connection.forward(request1);

// Channel 2: Forward request 2 (same connection)
const response2 = await connection.forward(request2);

// Channel 3: Forward request 3 (same connection)
const response3 = await connection.forward(request3);

// All three requests use the same SSH connection
// Reduces overhead and improves performance
```

---

## Requirements Mapping

| Requirement | Implementation | File |
|-------------|-----------------|------|
| 7.1: SSH v2 only | Algorithm enforcement | ssh-connection-impl.ts |
| 7.2: Modern algorithms | ED25519, ECDH, SHA-256+ | ssh-connection-impl.ts |
| 7.3: AES-256-GCM | Cipher configuration | ssh-connection-impl.ts |
| 7.4: Keep-alive 60s | startKeepAlive() method | ssh-connection-impl.ts |
| 7.5: Host key verification | (Future implementation) | ssh-connection-impl.ts |
| 7.6: Channel multiplexing | activeChannels tracking | ssh-connection-impl.ts |
| 7.7: Channel limit 10 | maxChannels config | ssh-connection-impl.ts |
| 7.8: SSH compression | compression config option | ssh-connection-impl.ts |
| 7.10: Error logging | SSHErrorHandler class | ssh-error-handler.ts |
| 2.1: Error categorization | handleSSHError() method | ssh-error-handler.ts |
| 2.2: User-friendly messages | Error message generation | ssh-error-handler.ts |
| 2.3: Actionable suggestions | Error recovery strategies | ssh-error-handler.ts |
| 4.2: Timing-safe comparison | timingSafeEqual usage | ssh-error-handler.ts |

---

## Testing SSH Implementation

### Unit Tests

```bash
npm test -- ssh-connection-impl.test.ts
npm test -- ssh-error-handler.test.ts
```

### Integration Tests

```bash
npm run test:integration -- ssh-tunnel.test.ts
```

### Manual Testing

```bash
# Test SSH connection with local server
npm run dev

# Check connection health
curl http://localhost:3001/api/tunnel/health

# View metrics
curl http://localhost:3001/api/tunnel/metrics

# Run diagnostics
curl http://localhost:3001/api/tunnel/diagnostics
```

---

## Troubleshooting

### Connection Refused

- **Cause:** SSH server not listening
- **Solution:** Check server is running, verify host/port
- **Reference:** SSH_LIBRARY_DOCUMENTATION.md - Error Handling section

### Authentication Failed

- **Cause:** Invalid credentials or key
- **Solution:** Verify username, password, or private key
- **Reference:** SSH_LIBRARY_DOCUMENTATION.md - Authentication Security section

### Timeout

- **Cause:** Network latency or server overload
- **Solution:** Increase timeout, check network conditions
- **Reference:** SSH_LIBRARY_DOCUMENTATION.md - Connection Management section

### Channel Limit Exceeded

- **Cause:** Too many concurrent channels
- **Solution:** Reduce concurrent requests, increase channel limit (max 10)
- **Reference:** SSH_LIBRARY_DOCUMENTATION.md - Channel Multiplexing section

---

## Related Documentation

- [SSH_LIBRARY_DOCUMENTATION.md](./src/SSH_LIBRARY_DOCUMENTATION.md) - Comprehensive SSH best practices
- [ssh-connection-impl.ts](./src/connection-pool/ssh-connection-impl.ts) - SSH connection implementation
- [ssh-error-handler.ts](./src/connection-pool/ssh-error-handler.ts) - SSH error handling
- [connection-pool-impl.ts](./src/connection-pool/connection-pool-impl.ts) - Connection pool management
- [Requirements Document](../../.kiro/specs/ssh-websocket-tunnel-enhancement/requirements.md) - Full requirements

---

## Document Metadata

- **Created:** 2024
- **Last Updated:** 2024
- **Task:** 19.2 - Resolve and document SSH library
- **Library:** SSH2 (`/mscdex/ssh2`)
- **Status:** Complete
