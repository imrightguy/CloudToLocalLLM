# Circuit Breaker Quick Start Guide

Get started with circuit breaker pattern in 5 minutes.

## Installation

The circuit breaker is already included in the streaming-proxy service. No additional installation needed.

## Basic Usage

### 1. Create a Circuit Breaker

```typescript
import { CircuitBreakerImpl } from './circuit-breaker';

const breaker = new CircuitBreakerImpl({
  failureThreshold: 5,      // Open after 5 failures
  successThreshold: 2,      // Close after 2 successes
  timeout: 5000,            // 5 second timeout
  resetTimeout: 60000,      // Reset after 60 seconds
});
```

### 2. Wrap Your Operations

```typescript
// Execute with circuit breaker
try {
  const result = await breaker.execute(async () => {
    return await myRiskyOperation();
  });
  console.log('Success:', result);
} catch (error) {
  console.error('Failed:', error.message);
}
```

### 3. Add Automatic Reset

```typescript
import { createResetManager } from './circuit-breaker';

const resetManager = createResetManager(breaker, {
  resetTimeout: 60000,
  successThreshold: 2,
  enabled: true,
});

resetManager.start();
```

### 4. Monitor with Metrics

```typescript
import { globalMetricsCollector } from './circuit-breaker';

// Register for metrics
globalMetricsCollector.register('my-service', breaker);

// Get metrics
const metrics = globalMetricsCollector.getMetrics('my-service');
console.log('State:', metrics.state);
console.log('Requests:', metrics.totalRequests);
console.log('Failures:', metrics.totalFailures);
```

## Common Patterns

### Pattern 1: With Fallback

```typescript
import { withCircuitBreaker } from './circuit-breaker';

const result = await withCircuitBreaker(
  breaker,
  () => primaryOperation(),
  () => fallbackOperation()  // Called when circuit is open
);
```

### Pattern 2: With Retry

```typescript
import { executeWithRetry } from './circuit-breaker';

const result = await executeWithRetry(
  breaker,
  () => myOperation(),
  3,      // Max 3 retries
  1000    // 1 second base delay
);
```

### Pattern 3: Batch Operations

```typescript
import { executeBatch } from './circuit-breaker';

const operations = [
  () => operation1(),
  () => operation2(),
  () => operation3(),
];

const results = await executeBatch(breaker, operations);
```

### Pattern 4: Method Decorator

```typescript
import { CircuitBreakerProtected } from './circuit-breaker';

class MyService {
  @CircuitBreakerProtected(breaker)
  async myMethod() {
    // Method automatically protected
    return await riskyOperation();
  }
}
```

## Monitoring

### Check Circuit Health

```typescript
import { isCircuitHealthy, getCircuitStatus } from './circuit-breaker';

if (isCircuitHealthy(breaker)) {
  console.log('Circuit is healthy');
} else {
  console.log('Circuit is unhealthy');
}

console.log(getCircuitStatus(breaker));
// Output: "Healthy - All requests allowed"
```

### Listen to Events

```typescript
breaker.on('stateChange', (event) => {
  console.log(`State changed from ${event.from} to ${event.to}`);
});

breaker.on('failure', (metrics) => {
  console.log(`Failure count: ${metrics.failureCount}`);
});

breaker.on('success', (metrics) => {
  console.log(`Success count: ${metrics.successCount}`);
});
```

### Expose Metrics Endpoint

```typescript
import express from 'express';

const app = express();

app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(globalMetricsCollector.exportPrometheusMetrics());
});

app.get('/circuit-breakers', (req, res) => {
  res.json(globalMetricsCollector.exportJsonMetrics());
});
```

## Configuration Presets

### For SSH Tunnel Operations

```typescript
const sshTunnelBreaker = new CircuitBreakerImpl({
  failureThreshold: 5,
  successThreshold: 2,
  timeout: 5000,
  resetTimeout: 60000,
});
```

### For High-Frequency API Calls

```typescript
const apiBreaker = new CircuitBreakerImpl({
  failureThreshold: 10,
  successThreshold: 3,
  timeout: 2000,
  resetTimeout: 30000,
});
```

### For Database Operations

```typescript
const dbBreaker = new CircuitBreakerImpl({
  failureThreshold: 3,
  successThreshold: 5,
  timeout: 10000,
  resetTimeout: 120000,
});
```

## Testing Your Circuit Breaker

### Test Opening

```typescript
// Trigger failures to open circuit
for (let i = 0; i < 5; i++) {
  try {
    await breaker.execute(() => Promise.reject(new Error('fail')));
  } catch {}
}

console.log(breaker.getState()); // Should be 'open'
```

### Test Reset

```typescript
// Open circuit
breaker.open();

// Wait for reset
await new Promise(resolve => setTimeout(resolve, 61000));

console.log(breaker.getState()); // Should be 'half_open'
```

### Test Recovery

```typescript
// In half-open state, succeed twice
await breaker.execute(() => Promise.resolve('success'));
await breaker.execute(() => Promise.resolve('success'));

console.log(breaker.getState()); // Should be 'closed'
```

## Complete Example

```typescript
import {
  CircuitBreakerImpl,
  createResetManager,
  globalMetricsCollector,
  withCircuitBreaker,
} from './circuit-breaker';

// 1. Create circuit breaker
const breaker = new CircuitBreakerImpl({
  failureThreshold: 5,
  successThreshold: 2,
  timeout: 5000,
  resetTimeout: 60000,
});

// 2. Add automatic reset
const resetManager = createResetManager(breaker, {
  resetTimeout: 60000,
  successThreshold: 2,
  enabled: true,
});
resetManager.start();

// 3. Register for metrics
globalMetricsCollector.register('my-service', breaker);

// 4. Use in your application
async function processRequest(request: any) {
  return await withCircuitBreaker(
    breaker,
    async () => {
      // Primary operation
      return await externalService.process(request);
    },
    async () => {
      // Fallback operation
      return { status: 'queued', message: 'Service temporarily unavailable' };
    }
  );
}

// 5. Monitor
setInterval(() => {
  const metrics = globalMetricsCollector.getMetrics('my-service');
  console.log('Circuit state:', metrics?.state);
  console.log('Success rate:', 
    metrics ? metrics.totalSuccesses / metrics.totalRequests : 0
  );
}, 10000);
```

## Next Steps

- Read the [full README](./README.md) for detailed documentation
- Check [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md) for architecture details
- Review requirements in the [design document](../../.kiro/specs/ssh-websocket-tunnel-enhancement/design.md)
- Integrate with other tunnel components (connection pool, rate limiter)

## Troubleshooting

**Circuit opens too quickly?**

- Increase `failureThreshold`

**Circuit stays open too long?**

- Decrease `resetTimeout`

**Operations timing out?**

- Increase `timeout` value

**Too many state changes?**

- Increase both `failureThreshold` and `successThreshold`

## Support

For issues or questions:

1. Check the [README](./README.md)
2. Review the [design document](../../.kiro/specs/ssh-websocket-tunnel-enhancement/design.md)
3. Check existing implementations in connection-pool and rate-limiter modules
