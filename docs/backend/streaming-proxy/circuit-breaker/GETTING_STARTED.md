# Getting Started with Circuit Breaker

Welcome! This guide will help you get started with the circuit breaker implementation in under 10 minutes.

## What is a Circuit Breaker?

A circuit breaker is a design pattern that prevents cascading failures in distributed systems. It works like an electrical circuit breaker:

- **CLOSED** (Normal): Requests flow through normally
- **OPEN** (Tripped): Requests are blocked after too many failures
- **HALF_OPEN** (Testing): Limited requests allowed to test recovery

## Why Use Circuit Breaker?

✅ **Prevent cascading failures** - Stop calling failing services  
✅ **Fast failure** - Fail quickly instead of waiting for timeouts  
✅ **Automatic recovery** - Test service health and recover automatically  
✅ **System stability** - Protect your system from overload  
✅ **Better user experience** - Provide fallback responses  

## Quick Start (5 Minutes)

### Step 1: Import

```typescript
import { CircuitBreakerImpl } from './circuit-breaker';
```

### Step 2: Create

```typescript
const breaker = new CircuitBreakerImpl({
  failureThreshold: 5,      // Open after 5 failures
  successThreshold: 2,      // Close after 2 successes
  timeout: 5000,            // 5 second timeout
  resetTimeout: 60000,      // Reset after 60 seconds
});
```

### Step 3: Use

```typescript
try {
  const result = await breaker.execute(async () => {
    return await myRiskyOperation();
  });
  console.log('Success!', result);
} catch (error) {
  console.error('Failed:', error.message);
}
```

That's it! You now have circuit breaker protection.

## Common Use Cases

### Use Case 1: Protect SSH Connections

```typescript
import { CircuitBreakerImpl, withCircuitBreaker } from './circuit-breaker';

const sshBreaker = new CircuitBreakerImpl({
  failureThreshold: 5,
  successThreshold: 2,
  timeout: 5000,
  resetTimeout: 60000,
});

async function connectToSSH(userId: string) {
  return await withCircuitBreaker(
    sshBreaker,
    async () => {
      return await sshPool.getConnection(userId);
    },
    async () => {
      // Fallback: return cached connection or error
      throw new Error('SSH service temporarily unavailable');
    }
  );
}
```

### Use Case 2: Protect API Calls

```typescript
const apiBreaker = new CircuitBreakerImpl({
  failureThreshold: 10,
  successThreshold: 3,
  timeout: 2000,
  resetTimeout: 30000,
});

async function callExternalAPI(data: any) {
  return await apiBreaker.execute(async () => {
    const response = await fetch('https://api.example.com', {
      method: 'POST',
      body: JSON.stringify(data),
    });
    return await response.json();
  });
}
```

### Use Case 3: Protect Database Operations

```typescript
const dbBreaker = new CircuitBreakerImpl({
  failureThreshold: 3,
  successThreshold: 5,
  timeout: 10000,
  resetTimeout: 120000,
});

async function queryDatabase(query: string) {
  return await dbBreaker.execute(async () => {
    return await db.query(query);
  });
}
```

## Add Automatic Recovery

Enable automatic recovery testing:

```typescript
import { createResetManager } from './circuit-breaker';

const resetManager = createResetManager(breaker, {
  resetTimeout: 60000,
  successThreshold: 2,
  enabled: true,
});

resetManager.start();

// Listen to recovery events
resetManager.on('recoveryTestingStarted', () => {
  console.log('Testing service recovery...');
});

resetManager.on('resetAttemptRecorded', (attempt) => {
  console.log('Reset attempt:', attempt.success ? 'SUCCESS' : 'FAILED');
});
```

## Add Monitoring

Track circuit breaker metrics:

```typescript
import { globalMetricsCollector } from './circuit-breaker';

// Register your circuit breaker
globalMetricsCollector.register('my-service', breaker);

// Get metrics
const metrics = globalMetricsCollector.getMetrics('my-service');
console.log('State:', metrics.state);
console.log('Total requests:', metrics.totalRequests);
console.log('Success rate:', 
  metrics.totalSuccesses / metrics.totalRequests
);

// Expose metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(globalMetricsCollector.exportPrometheusMetrics());
});
```

## Check Circuit Health

```typescript
import { isCircuitHealthy, getCircuitStatus } from './circuit-breaker';

// Simple health check
if (isCircuitHealthy(breaker)) {
  console.log('✅ Circuit is healthy');
} else {
  console.log('❌ Circuit is unhealthy');
}

// Detailed status
console.log(getCircuitStatus(breaker));
// Output: "Healthy - All requests allowed"
```

## Handle Circuit Open

When the circuit opens, you have several options:

### Option 1: Provide Fallback

```typescript
import { withCircuitBreaker } from './circuit-breaker';

const result = await withCircuitBreaker(
  breaker,
  () => primaryOperation(),
  () => fallbackOperation()  // Called when circuit is open
);
```

### Option 2: Queue for Later

```typescript
try {
  await breaker.execute(() => operation());
} catch (error) {
  if (error.message.includes('Circuit breaker is OPEN')) {
    // Queue the operation for later
    await queue.enqueue(operation);
  }
}
```

### Option 3: Return Cached Data

```typescript
try {
  return await breaker.execute(() => fetchData());
} catch (error) {
  if (error.message.includes('Circuit breaker is OPEN')) {
    // Return cached data
    return cache.get('data');
  }
  throw error;
}
```

## Configuration Tips

### Start Conservative

```typescript
{
  failureThreshold: 5,      // Not too sensitive
  successThreshold: 2,      // Quick recovery
  timeout: 5000,            // Reasonable timeout
  resetTimeout: 60000,      // Give service time to recover
}
```

### Tune Based on Behavior

**If circuit opens too often:**

- Increase `failureThreshold`
- Increase `timeout`

**If circuit stays open too long:**

- Decrease `resetTimeout`
- Decrease `successThreshold`

**If recovery fails repeatedly:**

- Increase `resetTimeout`
- Increase `successThreshold`

## Listen to Events

Circuit breakers emit events you can listen to:

```typescript
breaker.on('stateChange', (event) => {
  console.log(`Circuit ${event.from} → ${event.to}`);
  
  if (event.to === 'open') {
    // Alert: Circuit opened!
    sendAlert('Circuit breaker opened');
  }
});

breaker.on('failure', (metrics) => {
  console.log(`Failure #${metrics.failureCount}`);
});

breaker.on('success', (metrics) => {
  console.log(`Success #${metrics.successCount}`);
});
```

## Complete Example

Here's a complete example putting it all together:

```typescript
import {
  CircuitBreakerImpl,
  createResetManager,
  globalMetricsCollector,
  withCircuitBreaker,
  isCircuitHealthy,
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

// 4. Listen to events
breaker.on('stateChange', (event) => {
  console.log(`Circuit state: ${event.from} → ${event.to}`);
});

// 5. Use in your application
async function processRequest(request: any) {
  return await withCircuitBreaker(
    breaker,
    async () => {
      // Primary operation
      return await externalService.process(request);
    },
    async () => {
      // Fallback operation
      return { 
        status: 'queued', 
        message: 'Service temporarily unavailable' 
      };
    }
  );
}

// 6. Health check endpoint
app.get('/health', (req, res) => {
  const healthy = isCircuitHealthy(breaker);
  const metrics = globalMetricsCollector.getMetrics('my-service');
  
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'healthy' : 'degraded',
    circuit: metrics,
  });
});

// 7. Metrics endpoint
app.get('/metrics', (req, res) => {
  res.set('Content-Type', 'text/plain');
  res.send(globalMetricsCollector.exportPrometheusMetrics());
});
```

## Testing Your Circuit Breaker

### Test Opening

```typescript
// Trigger failures
for (let i = 0; i < 5; i++) {
  try {
    await breaker.execute(() => Promise.reject(new Error('fail')));
  } catch {}
}

console.log(breaker.getState()); // Should be 'open'
```

### Test Recovery

```typescript
// Wait for reset
await new Promise(resolve => setTimeout(resolve, 61000));

console.log(breaker.getState()); // Should be 'half_open'

// Succeed twice
await breaker.execute(() => Promise.resolve('success'));
await breaker.execute(() => Promise.resolve('success'));

console.log(breaker.getState()); // Should be 'closed'
```

## Troubleshooting

### Problem: Circuit opens immediately

**Solution:** Increase `failureThreshold`

```typescript
{
  failureThreshold: 10,  // Was: 5
  // ... other config
}
```

### Problem: Circuit stays open forever

**Solution:** Check if reset manager is started

```typescript
resetManager.start();  // Don't forget this!
```

### Problem: Operations timeout

**Solution:** Increase `timeout` value

```typescript
{
  timeout: 10000,  // Was: 5000
  // ... other config
}
```

### Problem: Too many state changes

**Solution:** Increase both thresholds

```typescript
{
  failureThreshold: 10,  // Was: 5
  successThreshold: 5,   // Was: 2
  // ... other config
}
```

## Next Steps

1. ✅ Read [QUICK_START.md](./QUICK_START.md) for more patterns
2. ✅ Read [README.md](./README.md) for detailed documentation
3. ✅ Check [IMPLEMENTATION_SUMMARY.md](./IMPLEMENTATION_SUMMARY.md) for architecture
4. ✅ Integrate with your services
5. ✅ Set up monitoring and alerts
6. ✅ Write tests for your integration

## Need Help?

- Check the [README](./README.md) for detailed documentation
- Review [QUICK_START](./QUICK_START.md) for common patterns
- Look at integration examples in [IMPLEMENTATION_SUMMARY](./IMPLEMENTATION_SUMMARY.md)
- Check the design document for requirements

## Key Takeaways

✅ Circuit breakers prevent cascading failures  
✅ Three states: CLOSED, OPEN, HALF_OPEN  
✅ Automatic recovery with reset manager  
✅ Comprehensive metrics and monitoring  
✅ Easy to integrate and use  
✅ Production-ready and well-tested  

Happy coding! 🚀
