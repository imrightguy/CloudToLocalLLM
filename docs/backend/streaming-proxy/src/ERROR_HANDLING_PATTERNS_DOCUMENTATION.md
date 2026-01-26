# Error Handling Patterns Documentation

## Overview

This document consolidates error handling patterns from the SSH WebSocket Tunnel Enhancement project, providing comprehensive guidance on error categorization, recovery strategies, and best practices for handling errors across WebSocket, SSH, and metrics collection components.

---

## Error Categories

### 1. Network Errors

**Characteristics:**

- Connection-level failures
- Network infrastructure issues
- Temporary connectivity problems

**Examples:**

- `ECONNREFUSED` - Connection refused
- `ENOTFOUND` - DNS resolution failed
- `ETIMEDOUT` - Connection timeout
- `EHOSTUNREACH` - Host unreachable
- `ENETUNREACH` - Network unreachable

**Recovery Strategy:**

- Retry with exponential backoff
- Check network connectivity
- Verify server availability
- Fallback to alternative endpoints

**Code Example:**

```typescript
async function connectWithRetry(config, maxRetries = 3) {
  let lastError;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await connect(config);
    } catch (error) {
      lastError = error;
      
      if (isNetworkError(error)) {
        const delay = Math.pow(2, attempt) * 1000; // Exponential backoff
        console.log(`Network error, retrying in ${delay}ms...`);
        await sleep(delay);
      } else {
        throw error; // Non-network error, don't retry
      }
    }
  }
  
  throw lastError;
}

function isNetworkError(error) {
  return ['ECONNREFUSED', 'ENOTFOUND', 'ETIMEDOUT', 'EHOSTUNREACH'].includes(error.code);
}
```

### 2. Authentication Errors

**Characteristics:**

- Invalid credentials
- Expired tokens
- Insufficient permissions
- Authentication method not supported

**Examples:**

- `EACCES` - Permission denied
- `All_AUTH_METHODS_FAILED` - All authentication methods failed
- `INVALID_TOKEN` - JWT token invalid
- `TOKEN_EXPIRED` - JWT token expired

**Recovery Strategy:**

- Refresh credentials
- Re-authenticate with valid credentials
- Check token expiration
- Verify authentication method support

**Code Example:**

```typescript
async function handleAuthError(error, credentials) {
  if (error.code === 'TOKEN_EXPIRED') {
    console.log('Token expired, refreshing...');
    const newToken = await refreshToken(credentials);
    return { retry: true, newCredentials: { ...credentials, token: newToken } };
  }
  
  if (error.code === 'INVALID_TOKEN') {
    console.log('Invalid token, re-authenticating...');
    const newToken = await authenticate(credentials);
    return { retry: true, newCredentials: { ...credentials, token: newToken } };
  }
  
  if (error.code === 'EACCES') {
    console.error('Permission denied - check credentials');
    return { retry: false, error: 'Invalid credentials' };
  }
  
  return { retry: false, error: error.message };
}
```

### 3. Protocol Errors

**Characteristics:**

- Invalid message format
- Unsupported protocol version
- Handshake failures
- Invalid frame format

**Examples:**

- `INVALID_FRAME` - Invalid WebSocket frame
- `UNSUPPORTED_VERSION` - Unsupported SSH version
- `HANDSHAKE_FAILED` - Protocol handshake failed
- `INVALID_MESSAGE` - Invalid message format

**Recovery Strategy:**

- Log detailed error information
- Close connection gracefully
- Attempt reconnection with different parameters
- Check protocol version compatibility

**Code Example:**

```typescript
function handleProtocolError(error, connection) {
  logger.error('Protocol error', {
    errorCode: error.code,
    errorMessage: error.message,
    connectionId: connection.id,
    protocolVersion: connection.protocolVersion,
    timestamp: new Date().toISOString()
  });
  
  // Close connection gracefully
  connection.close(1002, 'Protocol error');
  
  // Attempt reconnection with different parameters
  return {
    retry: true,
    delay: 5000,
    newConfig: {
      ...connection.config,
      protocolVersion: 'auto' // Let server negotiate version
    }
  };
}
```

### 4. Server Errors

**Characteristics:**

- Server-side failures
- Resource exhaustion
- Internal server errors
- Service unavailable

**Examples:**

- `500` - Internal server error
- `503` - Service unavailable
- `CHANNEL_OPEN_FAILURE` - Channel creation failed
- `RESOURCE_EXHAUSTED` - Server resources exhausted

**Recovery Strategy:**

- Implement circuit breaker pattern
- Retry with backoff
- Check server health
- Fallback to alternative server

**Code Example:**

```typescript
class CircuitBreakerErrorHandler {
  constructor(threshold = 5, timeout = 60000) {
    this.failureCount = 0;
    this.threshold = threshold;
    this.timeout = timeout;
    this.state = 'CLOSED'; // CLOSED, OPEN, HALF_OPEN
    this.lastFailureTime = null;
  }
  
  handleError(error) {
    if (isServerError(error)) {
      this.failureCount++;
      this.lastFailureTime = Date.now();
      
      if (this.failureCount >= this.threshold) {
        this.state = 'OPEN';
        logger.warn('Circuit breaker opened due to server errors');
        return { retry: false, error: 'Service temporarily unavailable' };
      }
      
      return { retry: true, delay: Math.pow(2, this.failureCount) * 1000 };
    }
    
    return { retry: false, error: error.message };
  }
  
  recordSuccess() {
    this.failureCount = 0;
    this.state = 'CLOSED';
  }
  
  canAttempt() {
    if (this.state === 'CLOSED') return true;
    if (this.state === 'OPEN') {
      if (Date.now() - this.lastFailureTime > this.timeout) {
        this.state = 'HALF_OPEN';
        return true;
      }
      return false;
    }
    return true; // HALF_OPEN
  }
}

function isServerError(error) {
  return error.statusCode >= 500 || 
         ['CHANNEL_OPEN_FAILURE', 'RESOURCE_EXHAUSTED'].includes(error.code);
}
```

### 5. Configuration Errors

**Characteristics:**

- Invalid configuration parameters
- Missing required settings
- Incompatible settings
- Out-of-range values

**Examples:**

- `INVALID_CONFIG` - Configuration validation failed
- `MISSING_REQUIRED_FIELD` - Required field missing
- `INVALID_VALUE` - Configuration value out of range
- `INCOMPATIBLE_SETTINGS` - Settings conflict

**Recovery Strategy:**

- Validate configuration before use
- Use default values for optional settings
- Log configuration errors with details
- Fail fast with clear error messages

**Code Example:**

```typescript
function validateConfig(config) {
  const errors = [];
  
  // Required fields
  if (!config.host) errors.push('host is required');
  if (!config.port) errors.push('port is required');
  if (!config.username) errors.push('username is required');
  
  // Value ranges
  if (config.port < 1 || config.port > 65535) {
    errors.push('port must be between 1 and 65535');
  }
  
  if (config.timeout && config.timeout < 0) {
    errors.push('timeout must be non-negative');
  }
  
  // Incompatible settings
  if (config.compression && config.maxFrameSize < 1024) {
    errors.push('compression requires maxFrameSize >= 1024');
  }
  
  if (errors.length > 0) {
    throw new Error(`Configuration validation failed:\n${errors.join('\n')}`);
  }
  
  return config;
}
```

### 6. Resource Errors

**Characteristics:**

- Memory exhaustion
- File descriptor limits
- Queue overflow
- Connection limits exceeded

**Examples:**

- `ENOMEM` - Out of memory
- `EMFILE` - Too many open files
- `QUEUE_FULL` - Request queue full
- `MAX_CONNECTIONS_EXCEEDED` - Connection limit exceeded

**Recovery Strategy:**

- Implement backpressure
- Drop low-priority requests
- Increase resource limits
- Implement graceful degradation

**Code Example:**

```typescript
class BackpressureManager {
  constructor(maxQueueSize = 1000, maxMemory = 100 * 1024 * 1024) {
    this.queue = [];
    this.maxQueueSize = maxQueueSize;
    this.maxMemory = maxMemory;
  }
  
  canAcceptRequest(request) {
    // Check queue size
    if (this.queue.length >= this.maxQueueSize) {
      logger.warn('Queue full, rejecting low-priority requests');
      return request.priority === 'HIGH';
    }
    
    // Check memory usage
    const memUsage = process.memoryUsage().heapUsed;
    if (memUsage > this.maxMemory) {
      logger.warn('Memory limit reached, rejecting requests');
      return false;
    }
    
    return true;
  }
  
  addRequest(request) {
    if (!this.canAcceptRequest(request)) {
      throw new Error('QUEUE_FULL');
    }
    
    this.queue.push(request);
  }
}
```

---

## Error Handling Patterns

### 1. Try-Catch with Recovery

```typescript
async function executeWithRecovery(operation, maxRetries = 3) {
  let lastError;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      
      const recovery = getRecoveryStrategy(error);
      if (!recovery.retry) throw error;
      
      logger.warn(`Attempt ${attempt + 1} failed, retrying...`, {
        error: error.message,
        delay: recovery.delay
      });
      
      await sleep(recovery.delay);
    }
  }
  
  throw lastError;
}
```

### 2. Error Categorization

```typescript
function categorizeError(error) {
  if (isNetworkError(error)) return 'NETWORK';
  if (isAuthError(error)) return 'AUTH';
  if (isProtocolError(error)) return 'PROTOCOL';
  if (isServerError(error)) return 'SERVER';
  if (isConfigError(error)) return 'CONFIG';
  if (isResourceError(error)) return 'RESOURCE';
  return 'UNKNOWN';
}

function getRecoveryStrategy(error) {
  const category = categorizeError(error);
  
  switch (category) {
    case 'NETWORK':
      return { retry: true, delay: 1000, maxRetries: 5 };
    case 'AUTH':
      return { retry: true, delay: 0, maxRetries: 1, action: 'refresh-credentials' };
    case 'PROTOCOL':
      return { retry: true, delay: 5000, maxRetries: 1 };
    case 'SERVER':
      return { retry: true, delay: 10000, maxRetries: 3 };
    case 'CONFIG':
      return { retry: false, error: 'Configuration error' };
    case 'RESOURCE':
      return { retry: true, delay: 30000, maxRetries: 1, action: 'backpressure' };
    default:
      return { retry: false, error: 'Unknown error' };
  }
}
```

### 3. Error Logging with Context

```typescript
function logError(error, context) {
  const errorLog = {
    timestamp: new Date().toISOString(),
    errorCode: error.code,
    errorMessage: error.message,
    errorStack: error.stack,
    category: categorizeError(error),
    context: {
      userId: context.userId,
      connectionId: context.connectionId,
      requestId: context.requestId,
      operation: context.operation
    },
    metrics: {
      duration: context.duration,
      retryCount: context.retryCount,
      memoryUsage: process.memoryUsage().heapUsed
    }
  };
  
  logger.error('Operation failed', errorLog);
  
  // Send to monitoring system
  errorMetrics.recordError(errorLog.category);
}
```

### 4. Graceful Degradation

```typescript
async function executeWithFallback(primaryOperation, fallbackOperation) {
  try {
    return await primaryOperation();
  } catch (error) {
    logger.warn('Primary operation failed, attempting fallback', {
      error: error.message
    });
    
    try {
      return await fallbackOperation();
    } catch (fallbackError) {
      logger.error('Both primary and fallback operations failed', {
        primaryError: error.message,
        fallbackError: fallbackError.message
      });
      throw fallbackError;
    }
  }
}
```

---

## WebSocket Error Handling

### Connection Errors

- **Cause:** Network issues, server unavailable
- **Recovery:** Automatic reconnection with exponential backoff
- **Logging:** Log connection attempts and failures

### Protocol Errors

- **Cause:** Invalid frames, handshake failures
- **Recovery:** Close connection, attempt reconnection
- **Logging:** Log protocol violations with frame details

### Authentication Errors

- **Cause:** Invalid tokens, expired credentials
- **Recovery:** Refresh credentials, re-authenticate
- **Logging:** Log authentication attempts and failures

---

## SSH Error Handling

### Authentication Errors

- **Cause:** Invalid credentials, unsupported auth method
- **Recovery:** Try alternative auth methods, refresh credentials
- **Logging:** Log auth attempts (without passwords)

### Protocol Errors

- **Cause:** Unsupported algorithms, handshake failures
- **Recovery:** Negotiate compatible algorithms, reconnect
- **Logging:** Log protocol negotiation details

### Channel Errors

- **Cause:** Channel limit exceeded, stream errors
- **Recovery:** Close unused channels, retry with backoff
- **Logging:** Log channel operations and limits

### Keep-Alive Failures

- **Cause:** Connection stalled, server unresponsive
- **Recovery:** Close connection, attempt reconnection
- **Logging:** Log keep-alive failures and response times

---

## Metrics Collection Error Handling

### Collection Errors

- **Cause:** Metric not found, invalid labels
- **Recovery:** Log error, continue with partial metrics
- **Logging:** Log collection failures with metric details

### Export Errors

- **Cause:** Serialization failures, format issues
- **Recovery:** Retry export, drop oldest metrics if needed
- **Logging:** Log export failures with error details

### Storage Errors

- **Cause:** Memory exhaustion, disk full
- **Recovery:** Implement retention policies, drop old data
- **Logging:** Log storage issues with resource usage

---

## Best Practices

### 1. Error Context

- Always include relevant context (user ID, connection ID, request ID)
- Log timestamps in ISO 8601 format
- Include stack traces for debugging

### 2. Error Recovery

- Implement exponential backoff for retries
- Set maximum retry limits
- Use circuit breaker pattern for cascading failures

### 3. Error Monitoring

- Track error rates and categories
- Alert on error spikes
- Monitor recovery success rates

### 4. Error Messages

- Use clear, actionable error messages
- Avoid exposing sensitive information
- Provide suggestions for resolution

### 5. Error Propagation

- Preserve error context through call chain
- Add context at each level
- Don't swallow errors silently

---

## Code Comments Template

Add these comments to error handling code:

```typescript
/**
 * Error Handling and Recovery
 * 
 * Implements comprehensive error handling with categorization and recovery:
 * - Categorizes errors into Network, Auth, Protocol, Server, Config, Resource
 * - Implements exponential backoff for retries
 * - Uses circuit breaker pattern for cascading failures
 * - Logs errors with full context for debugging
 * - Implements graceful degradation and fallback strategies
 * 
 * Error Categories:
 * - NETWORK: Connection failures, timeouts, DNS issues
 * - AUTH: Invalid credentials, expired tokens, permission denied
 * - PROTOCOL: Invalid frames, handshake failures, unsupported versions
 * - SERVER: 5xx errors, resource exhaustion, service unavailable
 * - CONFIG: Invalid configuration, missing fields, incompatible settings
 * - RESOURCE: Memory exhaustion, file descriptor limits, queue overflow
 * 
 * Recovery Strategies:
 * - NETWORK: Retry with exponential backoff (1s, 2s, 4s, 8s, 16s)
 * - AUTH: Refresh credentials, re-authenticate
 * - PROTOCOL: Close connection, reconnect with different parameters
 * - SERVER: Circuit breaker pattern, fallback to alternative server
 * - CONFIG: Fail fast with clear error message
 * - RESOURCE: Implement backpressure, drop low-priority requests
 * 
 * Requirements:
 * - 2.1: Error categorization
 * - 2.2: User-friendly error messages
 * - 2.3: Actionable error suggestions
 * - 2.4: Error recovery strategies
 * - 2.5: Error logging with context
 * - 2.6: Error monitoring and metrics
 * - 2.7: Error diagnostics
 * - 2.8: Error documentation
 * - 2.9: Error testing
 */
```

---

## References

### Error Handling Standards

- **RFC 3986:** URI Generic Syntax (error codes)
- **HTTP Status Codes:** https://httpwg.org/specs/rfc7231.html#status.codes
- **SSH Error Codes:** https://tools.ietf.org/html/rfc4253#section-11.1

### Related Documentation

- [SSH_LIBRARY_DOCUMENTATION.md](./SSH_LIBRARY_DOCUMENTATION.md) - SSH error handling
- [CONTEXT7_BEST_PRACTICES.md](./CONTEXT7_BEST_PRACTICES.md) - WebSocket error handling
- [error_categorization.dart](../../lib/services/tunnel/error_categorization.dart) - Client-side error categorization
- [error_recovery_strategy.dart](../../lib/services/tunnel/error_recovery_strategy.dart) - Client-side recovery strategies
- [ssh-error-handler.ts](./connection-pool/ssh-error-handler.ts) - Server-side SSH error handling

---

## Document Metadata

- **Created:** 2024
- **Last Updated:** 2024
- **Task:** 19.4 - Document error handling patterns
- **Status:** Complete
- **Error Categories:** 6 (Network, Auth, Protocol, Server, Config, Resource)
- **Recovery Strategies:** 6 (Retry, Refresh, Reconnect, Circuit Breaker, Backpressure, Fallback)
- **Requirements Addressed:** 2.1-2.9
