# Circuit Breaker Implementation

This module implements the Circuit Breaker pattern for fault tolerance in the SSH WebSocket tunnel system.

## Overview

The circuit breaker prevents cascading failures by monitoring operation failures and temporarily blocking requests when a failure threshold is exceeded. It has three states:

- **CLOSED**: Normal operation, all requests pass through
- **OPEN**: Failure threshold exceeded, requests are blocked
- **HALF_OPEN**: Testing recovery, limited requests allowed

## Components

### CircuitBreakerImpl

Core implementation of the circuit breaker pattern.

**Features:**

- State machine with three states (CLOSED, OPEN, HALF_OPEN)
- Configurable failure and success thresholds
- Automatic timeout for operations
- Event emission for monitoring
- Automatic reset after timeout

**Usage:**

```typescript
import { CircuitBreakerImpl } from './circuit-breaker';

const breaker = new CircuitBreakerImpl({
  failureThreshold: 5,      // Open after 5 failures
  successThreshold: 2,      // Close after 2 successes in half-open
  timeout: 5000,            // 5 second operation timeout
  resetTimeout: 60000,      // Try reset after 60 seconds
});

// Execute operation with protection
try {
  const result = await breaker.execute(async () => {
    return await someRiskyOperation();
  });
} catch (error) {
  console.error('Operation failed:', error);
}
```

### Circuit Breaker Wrapper

Utility functions for wrapping operations with circuit breaker protection.

**Features:**

- Simple wrapper function
- Function decorator
- Batch execution
- Retry with exponential backoff
- Health checking utilities

**Usage:**

```typescript
import { withCircuitBreaker, executeWithRetry } from './circuit-breaker';

// Simple wrapper
const result = await withCircuitBreaker(
  breaker,
  () => riskyOperation(),
  () => fallbackOperation() // Optional fallback
);

// With retry
const result = await executeWithRetry(
  breaker,
  () => riskyOperation(),
  3,      // Max 3 retries
  1000    // 1 second base delay
);

// Decorator
class MyService {
  @CircuitBreakerProtected(breaker)
  async myMethod() {
    // Method implementation
  }
}
```

### Automatic Reset Manager

Manages automatic reset and recovery testing for circuit breakers.

**Features:**

- Automatic transition to half-open state
- Recovery testing coordination
- Reset attempt tracking
- Statistics and history

**Usage:**

```typescript
import { createResetManager } from './circuit-breaker';

const resetManager = createResetManager(breaker, {
  resetTimeout: 60000,      // 60 seconds
  successThreshold: 2,      // 2 successes to close
  enabled: true,
});

resetManager.start();

// Listen to events
resetManager.on('resetScheduled', (event) => {
  console.log('Reset scheduled:', event);
});

resetManager.on('recoveryTestingStarted', (event) => {
  console.log('Testing recovery:', event);
});

// Get statistics
const stats = resetManager.getResetStatistics();
console.log('Success rate:', stats.successRate);
```

### Circuit Breaker Metrics

Tracks and exposes metrics for monitoring.

**Features:**

- Prometheus-compatible metrics
- JSON export
- State change history
- Request counting
- Summary statistics

**Usage:**

```typescript
import { globalMetricsCollector } from './circuit-breaker';

// Register circuit breaker
globalMetricsCollector.register('ssh-tunnel', breaker);

// Get metrics for specific breaker
const metrics = globalMetricsCollector.getMetrics('ssh-tunnel');
console.log('Current state:', metrics.state);
console.log('Total requests:', metrics.totalRequests);

// Export Prometheus metrics
const prometheusMetrics = globalMetricsCollector.exportPrometheusMetrics();

// Get summary
const summary = globalMetricsCollector.getSummary();
console.log('Open circuits:', summary.openCircuits);
console.log('Success rate:', summary.overallSuccessRate);
```

## Configuration

### CircuitBreakerConfig

```typescript
interface CircuitBreakerConfig {
  failureThreshold: number;   // Number of failures before opening
  successThreshold: number;   // Number of successes to close from half-open
  timeout: number;            // Operation timeout in milliseconds
  resetTimeout: number;       // Time before attempting reset in milliseconds
}
```

**Recommended Settings:**

**For SSH Tunnel Operations:**

```typescript
{
  failureThreshold: 5,
  successThreshold: 2,
  timeout: 5000,
  resetTimeout: 60000,
}
```

**For High-Frequency Operations:**

```typescript
{
  failureThreshold: 10,
  successThreshold: 3,
  timeout: 2000,
  resetTimeout: 30000,
}
```

**For Critical Operations:**

```typescript
{
  failureThreshold: 3,
  successThreshold: 5,
  timeout: 10000,
  resetTimeout: 120000,
}
```

## State Transitions

```
┌─────────┐
│ CLOSED  │ ◄──────────────────────┐
└────┬────┘                        │
     │                             │
     │ Failure threshold reached   │ Success threshold reached
     │                             │
     ▼                             │
┌─────────┐                   ┌────┴────────┐
│  OPEN   │ ─────────────────►│ HALF_OPEN   │
└─────────┘  Reset timeout    └─────────────┘
                                     │
                                     │ Any failure
                                     │
                                     ▼
                               ┌─────────┐
                               │  OPEN   │
                               └─────────┘
```

## Events

Circuit breakers emit the following events:

- `success`: Operation succeeded
- `failure`: Operation failed
- `stateChange`: State transition occurred
- `configured`: Configuration updated
- `reset`: Circuit breaker reset

Reset manager emits:

- `started`: Monitoring started
- `stopped`: Monitoring stopped
- `resetScheduled`: Reset scheduled
- `resetAttempted`: Reset attempt made
- `recoveryTestingStarted`: Recovery testing started
- `resetAttemptRecorded`: Reset attempt recorded
- `configUpdated`: Configuration updated

## Metrics

### Prometheus Metrics

- `circuit_breaker_state`: Current state (0=closed, 1=half_open, 2=open)
- `circuit_breaker_failures_total`: Total failures
- `circuit_breaker_successes_total`: Total successes
- `circuit_breaker_requests_total`: Total requests
- `circuit_breaker_state_changes_total`: Total state changes
- `circuit_breaker_last_state_change_seconds`: Seconds since last state change

### JSON Metrics

```json
{
  "timestamp": "2024-01-01T00:00:00.000Z",
  "uptime": 3600000,
  "circuitBreakers": [
    {
      "name": "ssh-tunnel",
      "state": "closed",
      "failureCount": 0,
      "successCount": 0,
      "lastStateChange": "2024-01-01T00:00:00.000Z",
      "stateChangeHistory": [],
      "uptime": 3600000,
      "totalRequests": 1000,
      "totalFailures": 5,
      "totalSuccesses": 995
    }
  ]
}
```

## Integration Example

Complete example integrating all components:

```typescript
import {
  CircuitBreakerImpl,
  createResetManager,
  globalMetricsCollector,
  withCircuitBreaker,
} from './circuit-breaker';

// Create circuit breaker
const sshTunnelBreaker = new CircuitBreakerImpl({
  failureThreshold: 5,
  successThreshold: 2,
  timeout: 5000,
  resetTimeout: 60000,
});

// Create reset manager
const resetManager = createResetManager(sshTunnelBreaker, {
  resetTimeout: 60000,
  successThreshold: 2,
  enabled: true,
});

// Register for metrics
globalMetricsCollector.register('ssh-tunnel', sshTunnelBreaker);

// Start monitoring
resetManager.start();

// Use in application
async function forwardRequest(request: any) {
  return await withCircuitBreaker(
    sshTunnelBreaker,
    async () => {
      // Forward request through SSH tunnel
      return await sshConnection.forward(request);
    },
    async () => {
      // Fallback: queue request for later
      await requestQueue.enqueue(request);
      throw new Error('Service temporarily unavailable');
    }
  );
}

// Expose metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(globalMetricsCollector.exportPrometheusMetrics());
});

// Health check
app.get('/health', (req, res) => {
  const summary = globalMetricsCollector.getSummary();
  const healthy = summary.openCircuits === 0;
  
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'healthy' : 'degraded',
    circuitBreakers: summary,
  });
});
```

## Testing

### Unit Tests

```typescript
describe('CircuitBreaker', () => {
  it('should open after failure threshold', async () => {
    const breaker = new CircuitBreakerImpl({
      failureThreshold: 3,
      successThreshold: 2,
      timeout: 1000,
      resetTimeout: 5000,
    });

    // Trigger failures
    for (let i = 0; i < 3; i++) {
      try {
        await breaker.execute(() => Promise.reject(new Error('fail')));
      } catch {}
    }

    expect(breaker.getState()).toBe(CircuitState.OPEN);
  });

  it('should transition to half-open after reset timeout', async () => {
    const breaker = new CircuitBreakerImpl({
      failureThreshold: 1,
      successThreshold: 2,
      timeout: 1000,
      resetTimeout: 100,
    });

    // Open circuit
    try {
      await breaker.execute(() => Promise.reject(new Error('fail')));
    } catch {}

    // Wait for reset
    await new Promise(resolve => setTimeout(resolve, 150));

    expect(breaker.getState()).toBe(CircuitState.HALF_OPEN);
  });
});
```

## Requirements Satisfied

- **Requirement 5.7**: Circuit breaker stops forwarding after 5 consecutive failures
- **Requirement 5.8**: Circuit breaker automatically resets after 60 seconds

## Related Components

- **Connection Pool**: Uses circuit breaker for SSH connection operations
- **Rate Limiter**: Works alongside circuit breaker for request protection
- **Metrics Collector**: Integrates with circuit breaker metrics
- **WebSocket Handler**: Uses circuit breaker for message forwarding

## Performance Considerations

- Circuit breaker adds minimal overhead (~1ms per operation)
- State transitions are synchronous and fast
- Metrics collection is asynchronous
- Event emission is non-blocking
- Memory usage is bounded (max 100 state changes stored)

## Troubleshooting

### Circuit Stays Open

**Symptoms:** Circuit breaker remains in OPEN state indefinitely

**Causes:**

- Reset timeout too long
- Underlying service still failing
- Reset manager not started

**Solutions:**

- Reduce reset timeout
- Fix underlying service
- Ensure reset manager is started

### Too Many State Changes

**Symptoms:** Circuit breaker rapidly transitions between states

**Causes:**

- Failure threshold too low
- Success threshold too low
- Intermittent failures

**Solutions:**

- Increase failure threshold
- Increase success threshold
- Add retry logic before circuit breaker

### Operations Timing Out

**Symptoms:** Operations fail with timeout errors

**Causes:**

- Timeout value too low
- Slow operations

**Solutions:**

- Increase timeout value
- Optimize operations
- Use separate circuit breakers for different operation types
