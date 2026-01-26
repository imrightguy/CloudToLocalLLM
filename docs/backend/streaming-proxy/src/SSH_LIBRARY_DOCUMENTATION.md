# SSH Library Documentation and Best Practices

## Library Resolution

**Library Name:** SSH2  
**Context7 Library ID:** `/mscdex/ssh2`  
**NPM Package:** `ssh2`  
**Trust Score:** 7.3/10  
**Code Snippets Available:** 36  
**Repository:** https://github.com/mscdex/ssh2

### Library Selection Rationale

The `ssh2` library was selected for the CloudToLocalLLM tunnel system because:

1. **Pure JavaScript Implementation**: Provides SSH2 client and server modules for Node.js without native dependencies
2. **Comprehensive Feature Set**: Supports SFTP, port forwarding, multiple authentication methods, and channel multiplexing
3. **Production-Ready**: Widely used in production systems with good community support
4. **Flexible Authentication**: Supports password, public key, keyboard-interactive, agent, and host-based authentication
5. **Stream-Based API**: Integrates well with Node.js streams for efficient data handling
6. **Security Features**: Built-in support for modern algorithms and secure key handling

---

## SSH Protocol Best Practices

### 1. Authentication Security

#### Use Timing-Safe Comparisons

Always use `timingSafeEqual` from the crypto module when comparing sensitive values like passwords and keys to prevent timing attacks:

```typescript
import { timingSafeEqual } from 'crypto';

function checkValue(input: Buffer, allowed: Buffer): boolean {
  const autoReject = (input.length !== allowed.length);
  if (autoReject) {
    // Prevent leaking length information by always making a comparison with the
    // same input when lengths don't match what we expect
    allowed = input;
  }
  const isMatch = timingSafeEqual(input, allowed);
  return (!autoReject && isMatch);
}
```

**Reference:** Requirement 4.2 (Multi-Tenant Security) - JWT token validation must be secure  
**Implementation Location:** `services/streaming-proxy/src/middleware/jwt-validation-middleware.ts`

#### Supported Authentication Methods

The ssh2 library supports multiple authentication methods. Choose based on your security requirements:

1. **Public Key Authentication** (Recommended for production)
   - Most secure for automated systems
   - No passwords transmitted over network
   - Supports ED25519, ECDSA, and RSA keys

2. **Password Authentication** (Use with caution)
   - Simpler for interactive use
   - Always use over encrypted SSH connection (TLS 1.3)
   - Implement rate limiting to prevent brute force

3. **Keyboard-Interactive** (For MFA)
   - Supports multi-factor authentication
   - Allows server-side prompt customization
   - Useful for challenge-response authentication

4. **Agent Authentication** (For key management)
   - Delegates key operations to SSH agent
   - Keys never exposed to application
   - Ideal for high-security environments

5. **Host-Based Authentication** (For trusted hosts)
   - Authenticates based on host identity
   - Requires host key configuration
   - Less common in cloud environments

**Reference:** Requirement 7.1 (SSH Protocol Enhancements) - Support modern SSH key exchange algorithms  
**Implementation Location:** `services/streaming-proxy/src/connection-pool/ssh-connection-impl.ts`

### 2. Key Management

#### Generate SSH Key Pairs Securely

Use the ssh2 utilities to generate keys with proper algorithms:

```typescript
import { utils } from 'ssh2';

// Generate ED25519 key (recommended - modern, secure, compact)
const keys = utils.generateKeyPairSync('ed25519');

// Generate ECDSA key with 256-bit curve
const ecdsaKeys = utils.generateKeyPairSync('ecdsa', { 
  bits: 256, 
  comment: 'tunnel-server-key' 
});

// Generate RSA key with encryption (for sensitive keys)
utils.generateKeyPair(
  'rsa',
  { 
    bits: 2048, 
    passphrase: 'secure-passphrase', 
    cipher: 'aes256-cbc' 
  },
  (err, keys) => {
    if (err) throw err;
    // Use keys.public and keys.private
  }
);
```

**Key Algorithm Recommendations:**

| Algorithm | Bits | Use Case | Security | Performance |
|-----------|------|----------|----------|-------------|
| ED25519 | N/A | **Recommended** | Excellent | Excellent |
| ECDSA | 256 | Good alternative | Excellent | Good |
| RSA | 2048+ | Legacy support | Good | Fair |

**Reference:** Requirement 7.2 (SSH Protocol Enhancements) - Support modern SSH key exchange algorithms  
**Implementation Location:** `services/streaming-proxy/src/connection-pool/ssh-connection-impl.ts`

#### Host Key Verification

Always verify the server's host key on first connection and cache it:

```typescript
import { utils } from 'ssh2';

// Parse and verify host key
const hostKey = utils.parseKey(hostKeyData);

// Verify signature
const isValid = hostKey.verify(data, signature, hashAlgo);

if (!isValid) {
  throw new Error('Host key verification failed - possible MITM attack');
}

// Cache verified host key for future connections
cacheHostKey(hostname, hostKey);
```

**Reference:** Requirement 7.5 (SSH Protocol Enhancements) - Verify server host key on first connection and cache it  
**Implementation Location:** `lib/services/tunnel/ssh_host_key_manager.dart`

### 3. Connection Security

#### Use Modern Algorithms

The ssh2 library negotiates algorithms during handshake. Ensure your server configuration enforces modern algorithms:

```typescript
// Negotiated handshake details (example)
{
  kex: 'ecdh-sha2-nistp256',           // Key exchange
  srvHostKey: 'rsa-sha2-512',          // Host key algorithm
  cs: {                                 // Client-to-server
    cipher: 'aes128-gcm',              // Encryption
    mac: '',                            // MAC (integrated in GCM)
    compress: 'none',                   // Compression
    lang: ''
  },
  sc: {                                 // Server-to-client
    cipher: 'aes128-gcm',
    mac: '',
    compress: 'none',
    lang: ''
  }
}
```

**Recommended Algorithms:**

- **Key Exchange:** `ecdh-sha2-nistp256`, `curve25519-sha256`
- **Host Key:** `rsa-sha2-512`, `ecdsa-sha2-nistp256`, `ssh-ed25519`
- **Cipher:** `aes128-gcm`, `aes256-gcm`, `chacha20-poly1305`
- **MAC:** Integrated in GCM modes (no separate MAC needed)
- **Compression:** `none` (compression can leak information)

**Reference:** Requirement 7.1, 7.2 (SSH Protocol Enhancements) - Use SSH protocol version 2 only with modern algorithms  
**Implementation Location:** `services/streaming-proxy/src/connection-pool/ssh-connection-impl.ts`

#### Enable Compression Selectively

SSH compression can improve bandwidth but may leak information:

```typescript
// Enable compression only for high-latency, low-bandwidth connections
const compressionEnabled = networkCondition === 'low-bandwidth';

// Compression algorithms: 'none', 'zlib', 'zlib@openssh.com'
const algorithms = {
  compress: compressionEnabled ? 'zlib@openssh.com' : 'none'
};
```

**Reference:** Requirement 7.8 (SSH Protocol Enhancements) - Implement SSH compression for large data transfers  
**Implementation Location:** `services/streaming-proxy/src/websocket/compression-manager.ts`

### 4. Connection Management

#### Implement Keep-Alive Messages

Prevent connection timeouts and detect dead connections:

```typescript
// Send keep-alive every 60 seconds
const KEEP_ALIVE_INTERVAL = 60000; // milliseconds

setInterval(() => {
  if (connection.isConnected()) {
    // SSH keep-alive: send channel request with no response expected
    connection.exec('echo "keep-alive"', (err, stream) => {
      if (err) {
        console.error('Keep-alive failed:', err);
        // Trigger reconnection
      }
    });
  }
}, KEEP_ALIVE_INTERVAL);
```

**Reference:** Requirement 7.4 (SSH Protocol Enhancements) - Implement SSH keep-alive messages every 60 seconds  
**Implementation Location:** `services/streaming-proxy/src/connection-pool/ssh-connection-impl.ts`

#### Channel Multiplexing

Reuse SSH connections by multiplexing multiple channels:

```typescript
// Single SSH connection with multiple channels
const connection = new Client();

connection.on('ready', () => {
  // Channel 1: Execute command
  connection.exec('command1', (err, stream1) => {
    // Handle stream1
  });
  
  // Channel 2: Execute another command (same connection)
  connection.exec('command2', (err, stream2) => {
    // Handle stream2
  });
  
  // Channel 3: SFTP subsystem
  connection.sftp((err, sftp) => {
    // Handle SFTP operations
  });
});

connection.connect(config);
```

**Benefits:**

- Reduced connection overhead
- Better resource utilization
- Faster channel establishment
- Lower latency for multiple operations

**Limits:**

- Enforce maximum channels per connection (default: 10)
- Prevent resource exhaustion from single user

**Reference:** Requirement 7.6, 7.7 (SSH Protocol Enhancements) - Support SSH connection multiplexing with channel limits  
**Implementation Location:** `services/streaming-proxy/src/connection-pool/ssh-connection-impl.ts`

### 5. Error Handling

#### Comprehensive SSH Error Logging

Log all SSH protocol errors with detailed context:

```typescript
connection.on('error', (err) => {
  const errorContext = {
    timestamp: new Date().toISOString(),
    userId: connection.userId,
    connectionId: connection.id,
    errorCode: err.code,
    errorMessage: err.message,
    errorStack: err.stack,
    connectionState: connection.state,
    lastActivity: connection.lastActivityAt,
  };
  
  logger.error('SSH Connection Error', errorContext);
  
  // Categorize error for recovery
  const category = categorizeSSHError(err);
  errorRecoveryStrategy.attemptRecovery(category, connection);
});
```

**SSH Error Categories:**

| Error | Cause | Recovery |
|-------|-------|----------|
| `ECONNREFUSED` | Server not listening | Retry with backoff |
| `ENOTFOUND` | DNS resolution failed | Check hostname, retry |
| `ETIMEDOUT` | Connection timeout | Increase timeout, retry |
| `EACCES` | Authentication failed | Check credentials |
| `EHOSTUNREACH` | Network unreachable | Check network, retry |
| `All_AUTH_METHODS_FAILED` | All auth methods rejected | Check credentials |
| `CHANNEL_OPEN_FAILURE` | Channel creation failed | Check server resources |

**Reference:** Requirement 2.1, 2.2, 2.3 (Enhanced Error Handling) - Categorize errors and provide actionable suggestions  
**Implementation Location:** `services/streaming-proxy/src/connection-pool/ssh-error-handler.ts`

### 6. Port Forwarding

#### Local Port Forwarding (Client Perspective)

Forward local port to remote service through SSH tunnel:

```typescript
// Forward local port 8080 to remote service at 192.168.1.100:80
connection.forwardOut(
  '127.0.0.1',      // Local address
  8080,             // Local port
  '192.168.1.100',  // Remote address
  80,               // Remote port
  (err, stream) => {
    if (err) throw err;
    
    // Stream is now connected to remote service
    // Pipe data through the tunnel
    localSocket.pipe(stream).pipe(localSocket);
  }
);
```

#### Remote Port Forwarding (Server Perspective)

Allow remote connections to be forwarded to local client:

```typescript
// Listen on remote port 8080, forward to local client
connection.forwardIn(
  '0.0.0.0',  // Remote address (0.0.0.0 = all interfaces)
  8080,       // Remote port
  (err) => {
    if (err) throw err;
    console.log('Listening for connections on remote port 8080');
  }
);

// Handle incoming connections
connection.on('tcp connection', (info, accept, reject) => {
  console.log(`Incoming connection from ${info.srcAddr}:${info.srcPort}`);
  
  const stream = accept();
  // Forward to local service
  localSocket.pipe(stream).pipe(localSocket);
});
```

**Reference:** Requirement 6.5 (WebSocket Connection Management) - Implement connection pooling for multiple simultaneous tunnels  
**Implementation Location:** `services/streaming-proxy/src/connection-pool/connection-pool-impl.ts`

### 7. SFTP Operations

#### Secure File Transfer

Use SFTP for secure file operations:

```typescript
connection.sftp((err, sftp) => {
  if (err) throw err;
  
  // List directory
  sftp.readdir('/remote/path', (err, list) => {
    if (err) throw err;
    console.log(list);
  });
  
  // Create read stream
  const readStream = sftp.createReadStream('/remote/file.txt', {
    start: 0,
    end: 99  // Read bytes 0-99
  });
  
  // Create write stream
  const writeStream = sftp.createWriteStream('/remote/output.txt', {
    flags: 'w',
    mode: 0o644
  });
  
  readStream.pipe(writeStream);
});
```

---

## Implementation Guidelines for CloudToLocalLLM

### SSH Connection Manager

The SSH connection manager in `services/streaming-proxy/src/connection-pool/ssh-connection-impl.ts` should:

1. **Initialize Connections Securely**

   ```typescript
   // Use ED25519 keys for modern security
   // Verify host keys on first connection
   // Cache verified keys for future connections
   // Enforce TLS 1.3 for WebSocket transport
   ```

2. **Manage Connection Lifecycle**

   ```typescript
   // Implement keep-alive every 60 seconds
   // Detect dead connections within 45 seconds
   // Implement graceful closure with proper SSH disconnect
   // Log all connection events with correlation IDs
   ```

3. **Handle Errors Gracefully**

   ```typescript
   // Categorize SSH errors
   // Implement automatic recovery strategies
   // Log detailed error context
   // Provide user-friendly error messages
   ```

4. **Enforce Security Policies**

   ```typescript
   // Limit channels per connection (max 10)
   // Enforce rate limiting per user
   // Validate all input data
   // Use timing-safe comparisons for sensitive data
   ```

### Code Comments Template

Add these comments to SSH-related code:

```typescript
/**
 * SSH Connection Manager
 * 
 * Manages SSH connections for tunnel forwarding with security best practices:
 * - Uses ED25519 keys for modern cryptography (Requirement 7.2)
 * - Implements host key verification and caching (Requirement 7.5)
 * - Sends keep-alive messages every 60 seconds (Requirement 7.4)
 * - Supports channel multiplexing with limits (Requirement 7.6, 7.7)
 * - Implements comprehensive error logging (Requirement 2.1, 2.3)
 * 
 * Reference: ssh2 library documentation
 * Library ID: /mscdex/ssh2
 * Trust Score: 7.3/10
 * 
 * Security Considerations:
 * - All authentication uses timing-safe comparisons
 * - Host keys are verified and cached to prevent MITM attacks
 * - SSH compression is disabled by default (information leak risk)
 * - Modern algorithms enforced: ECDH, AES-GCM, SHA-256+
 */
```

---

## References

### SSH2 Library Documentation

- **Repository:** https://github.com/mscdex/ssh2
- **NPM Package:** https://www.npmjs.com/package/ssh2
- **Documentation:** https://github.com/mscdex/ssh2/blob/master/README.md

### SSH Protocol Standards

- **RFC 4251:** The Secure Shell (SSH) Protocol Architecture
- **RFC 4252:** The Secure Shell (SSH) Authentication Protocol
- **RFC 4253:** The Secure Shell (SSH) Transport Layer Protocol
- **RFC 4254:** The Secure Shell (SSH) Connection Protocol

### Security Best Practices

- **OWASP:** SSH Security Best Practices
- **NIST:** Guidelines for SSH Key Management
- **CIS:** SSH Security Benchmark

---

## Related Requirements

This documentation addresses the following requirements:

- **Requirement 7.1:** Use SSH protocol version 2 only (no SSHv1)
- **Requirement 7.2:** Support modern SSH key exchange algorithms (curve25519-sha256)
- **Requirement 7.3:** Use AES-256-GCM for SSH encryption
- **Requirement 7.4:** Implement SSH keep-alive messages every 60 seconds
- **Requirement 7.5:** Verify server host key on first connection and cache it
- **Requirement 7.6:** Support SSH connection multiplexing (multiple channels over one connection)
- **Requirement 7.7:** Limit SSH channel count per connection to 10
- **Requirement 7.8:** Implement SSH compression for large data transfers
- **Requirement 7.10:** Log SSH protocol errors with detailed context
- **Requirement 2.1:** Categorize errors into Network, Authentication, Configuration, Server, Unknown
- **Requirement 2.2:** Provide user-friendly error messages for each error category
- **Requirement 2.3:** Include actionable suggestions for common errors
- **Requirement 4.2:** Validate JWT tokens on every request (timing-safe comparison)

---

## Document Metadata

- **Created:** 2024
- **Last Updated:** 2024
- **Status:** Complete
- **Task:** 19.2 - Resolve and document SSH library
- **Library ID:** `/mscdex/ssh2`
- **Trust Score:** 7.3/10
- **Code Snippets:** 36 available
