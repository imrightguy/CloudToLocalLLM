# Circuit Breaker Pattern Implementation

## Overview

This document describes the implementation of the Circuit Breaker pattern for the CloudToLocalLLM API backend. The circuit breaker prevents cascading failures by monitoring service calls and failing fast when a service is unavailable.

## Implementation Details

### Core Components

#### 1. CircuitBreaker Class (`services/circuit-breaker.js`)

The main circuit breaker implementation with three states:

- **CLOSED**: Normal operation, requests pass through
- **OPEN**: Service is failing, requests fail immediately
- **HALF_OPEN**: Testing if service has recovered, limited requests allowed

**Key Features:**

- Configurable failure and success thresholds
- Automatic state transitions based on request outcomes
- Metrics collection for monitoring
- State change callbacks for logging and alerting
- Manual control methods (open, close, reset)

**Configuration Options:**

```javascript
{
  name: 'ServiceName',           // Circuit breaker name
  failureThreshold: 5,           // Failures before opening
  successThreshold: 2,           // Successes before closing from HALF_OPEN
  timeout: 60000,                // Milliseconds before attempting reset
  onStateChange: (change) => {}  // Callback for state changes
}
```

#### 2. CircuitBreakerManager Class (`services/circuit-breaker.js`)

Manages multiple circuit breakers:

- Create or retrieve circuit breakers by name
- Get metrics for all circuit breakers
- Reset all circuit breakers
- Remove specific circuit breakers

#### 3. Circuit Breaker Middleware (`middleware/circuit-breaker-middleware.js`)

Express middleware for integrating circuit breakers:

**Functions:**

- `createCircuitBreakerMiddleware(serviceName, options)` - Creates middleware for a service
- `circuitBreakerErrorHandler(err, req, res, next)` - Handles circuit breaker errors
- `executeWithCircuitBreaker(serviceName, fn, options)` - Utility to execute functions through circuit breaker
- `getCircuitBreakerMetrics(req, res)` - Endpoint to get all metrics
- `resetAllCircuitBreakers(req, res)` - Endpoint to reset all breakers
- `getCircuitBreakerStatus(req, res)` - Endpoint to get specific breaker status
- `openCircuitBreaker(req, res)` - Endpoint to manually open a breaker
- `closeCircuitBreaker(req, res)` - Endpoint to manually close a breaker

### State Transitions

```
CLOSED
  ├─ On failure (count >= threshold) → OPEN
  └─ On success → CLOSED (reset counter)

OPEN
  ├─ On timeout → HALF_OPEN
  └─ On request → Reject immediately

HALF_OPEN
  ├─ On success (count >= threshold) → CLOSED
  ├─ On failure → OPEN
  └─ On request → Allow limited requests
```

### Metrics Collected

Each circuit breaker tracks:

- `totalRequests` - Total requests processed
- `successfulRequests` - Successful requests
- `failedRequests` - Failed requests
- `rejectedRequests` - Requests rejected due to open circuit
- `stateChanges` - History of state transitions
- `state` - Current state (CLOSED, OPEN, HALF_OPEN)
- `failureCount` - Current failure count
- `successCount` - Current success count

### Usage Examples

#### Basic Usage

```javascript
import { CircuitBreaker } from './services/circuit-breaker.js';

const breaker = new CircuitBreaker({
  name: 'external-api',
  failureThreshold: 5,
  successThreshold: 2,
  timeout: 60000,
});

try {
  const result = await breaker.execute(async () => {
    return await callExternalAPI();
  });
} catch (error) {
  if (error.code === 'CIRCUIT_BREAKER_OPEN') {
    console.log('Service is temporarily unavailable');
  }
}
```

#### With Middleware

```javascript
import express from 'express';
import {
  createCircuitBreakerMiddleware,
  executeWithCircuitBreaker,
  circuitBreakerErrorHandler,
} from './middleware/circuit-breaker-middleware.js';

const app = express();

// Apply middleware
app.get('/api/external', 
  createCircuitBreakerMiddleware('external-service'),
  async (req, res, next) => {
    try {
      const result = await executeWithCircuitBreaker('external-service', 
        async () => {
          return await callExternalService();
        }
      );
      res.json(result);
    } catch (error) {
      next(error);
    }
  }
);

// Error handler
app.use(circuitBreakerErrorHandler);
```

#### Manager Usage

```javascript
import { circuitBreakerManager } from './services/circuit-breaker.js';

// Get or create a circuit breaker
const breaker = circuitBreakerManager.getOrCreate('my-service', {
  failureThreshold: 5,
});

// Get all metrics
const metrics = circuitBreakerManager.getAllMetrics();

// Reset all breakers
circuitBreakerManager.resetAll();
```

## Testing

### Unit Tests (`test/api-backend/circuit-breaker.test.js`)

Comprehensive unit tests covering:

- State transitions (CLOSED → OPEN → HALF_OPEN → CLOSED)
- Request handling in each state
- Metrics collection
- Manual control (open, close, reset)
- State change callbacks
- Function context and arguments
- Error handling

**Test Results:** 25 tests passed, 97.22% statement coverage

### Integration Tests (`test/api-backend/circuit-breaker-integration.test.js`)

Integration tests covering:

- Middleware integration
- Error handling in Express
- Metrics endpoint
- Reset endpoint
- Status endpoint
- Manual control endpoints
- Utility function usage

**Test Results:** 15 tests passed, 100% middleware coverage

## API Endpoints

When integrated into the API, the following endpoints are available:

### Get Metrics

```
GET /metrics
Response: { circuitBreakers: {...}, timestamp: "..." }
```

### Get Specific Status

```
GET /status/:serviceName
Response: { service: "...", metrics: {...}, timestamp: "..." }
```

### Reset All

```
POST /reset
Response: { message: "...", timestamp: "..." }
```

### Manually Open

```
POST /open/:serviceName
Response: { service: "...", state: "OPEN", message: "...", timestamp: "..." }
```

### Manually Close

```
POST /close/:serviceName
Response: { service: "...", state: "CLOSED", message: "...", timestamp: "..." }
```

## Error Responses

When a circuit breaker is open, requests receive:

```json
{
  "error": {
    "code": "SERVICE_UNAVAILABLE",
    "message": "Service is temporarily unavailable",
    "category": "service_unavailable",
    "statusCode": 503,
    "correlationId": "...",
    "suggestion": "Please try again in a few moments"
  }
}
```

## Configuration Recommendations

### For External APIs

```javascript
{
  failureThreshold: 5,      // Open after 5 failures
  successThreshold: 2,      // Close after 2 successes
  timeout: 60000            // Try recovery after 60 seconds
}
```

### For Internal Services

```javascript
{
  failureThreshold: 3,      // Open after 3 failures
  successThreshold: 1,      // Close after 1 success
  timeout: 30000            // Try recovery after 30 seconds
}
```

### For Critical Services

```javascript
{
  failureThreshold: 10,     // More tolerant
  successThreshold: 5,      // Require more successes
  timeout: 120000           // Longer recovery time
}
```

## Monitoring and Alerting

The circuit breaker provides state change callbacks for integration with monitoring systems:

```javascript
const breaker = new CircuitBreaker({
  name: 'my-service',
  onStateChange: (change) => {
    // Log to monitoring system
    logger.warn('Circuit breaker state change', {
      service: change.name,
      from: change.oldState,
      to: change.newState,
      timestamp: change.timestamp,
    });
    
    // Send alert if opening
    if (change.newState === 'OPEN') {
      alerting.sendAlert(`Service ${change.name} is unavailable`);
    }
  },
});
```

## Integration with Requirement 7.3

This implementation satisfies requirement 7.3:

- ✅ Creates circuit breaker for service failures
- ✅ Implements state management (CLOSED, OPEN, HALF_OPEN)
- ✅ Adds circuit breaker metrics
- ✅ Includes comprehensive unit tests for state transitions

## Future Enhancements

1. **Sliding Window Metrics** - Track metrics over time windows
2. **Bulkhead Pattern** - Isolate resources per service
3. **Fallback Strategies** - Define fallback behavior when circuit is open
4. **Adaptive Thresholds** - Adjust thresholds based on system load
5. **Distributed Circuit Breaker** - Share state across multiple instances
6. **Metrics Export** - Export to Prometheus/Grafana

## References

- [Circuit Breaker Pattern](https://martinfowler.com/bliki/CircuitBreaker.html)
- [Release It! Design and Deploy Production-Ready Software](https://pragprog.com/titles/mnee2/release-it-second-edition/)
- [Resilience4j Documentation](https://resilience4j.readme.io/docs/circuitbreaker)
