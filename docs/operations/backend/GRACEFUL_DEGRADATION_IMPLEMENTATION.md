# Graceful Degradation Implementation

## Overview

This document describes the implementation of graceful degradation for the CloudToLocalLLM API backend. Graceful degradation allows the API to continue operating with reduced functionality when services are unavailable, preventing cascading failures and improving overall system resilience.

## Requirement

**Requirement 7.6:** THE API SHALL implement graceful degradation when services are unavailable

## Implementation Details

### Core Components

#### 1. GracefulDegradationService (`services/graceful-degradation.js`)

The main service for managing graceful degradation across all services.

**Key Features:**

- Service registration with fallback mechanisms
- Degradation state tracking (healthy, degraded, critical)
- Fallback function execution when primary services fail
- Reduced functionality mode support
- Critical endpoint protection
- Comprehensive metrics collection
- Automatic recovery detection

**Key Methods:**

```javascript
// Register a service for degradation management
registerService(serviceName, config)

// Mark a service as degraded
markDegraded(serviceName, reason, severity)

// Mark a service as recovered
markRecovered(serviceName)

// Get status for a specific service
getStatus(serviceName)

// Get all service statuses
getAllStatuses()

// Execute with fallback support
executeWithFallback(serviceName, primaryFn, context, args)

// Get reduced functionality response
getReducedFunctionalityResponse(serviceName, endpoint)

// Check if endpoint is critical
isCriticalEndpoint(serviceName, endpoint)

// Get metrics
getMetrics()

// Get comprehensive report
getReport()
```

#### 2. Graceful Degradation Middleware (`middleware/graceful-degradation-middleware.js`)

Express middleware for integrating graceful degradation into the API.

**Key Functions:**

- `createGracefulDegradationMiddleware(serviceName, options)` - Middleware for service degradation
- `degradationStatusMiddleware` - Adds degradation status to response headers
- `getDegradationStatus(req, res)` - Endpoint to get degradation status
- `getAllDegradationStatuses(req, res)` - Endpoint to get all statuses
- `markServiceDegraded(req, res)` - Endpoint to manually mark service as degraded
- `markServiceRecovered(req, res)` - Endpoint to manually mark service as recovered
- `getDegradationMetrics(req, res)` - Endpoint to get degradation metrics
- `resetAllDegradation(req, res)` - Endpoint to reset all degradation states
- `createReducedFunctionalityMiddleware(serviceName)` - Middleware for reduced functionality

### Service Registration Example

```javascript
import { gracefulDegradationService } from './services/graceful-degradation.js';

// Register a service with fallback
gracefulDegradationService.registerService('database', {
  fallback: async () => {
    // Return cached data or default response
    return { data: 'cached', source: 'fallback' };
  },
  criticalEndpoints: ['/api/auth', '/api/payment'],
  reducedFunctionality: {
    availableFeatures: ['read', 'cache'],
    unavailableFeatures: ['write', 'sync'],
    estimatedRecoveryTime: '5 minutes',
  },
});
```

### Middleware Integration Example

```javascript
import express from 'express';
import {
  createGracefulDegradationMiddleware,
  degradationStatusMiddleware,
} from './middleware/graceful-degradation-middleware.js';

const app = express();

// Add degradation status to all responses
app.use(degradationStatusMiddleware);

// Protect specific endpoints with degradation handling
app.get(
  '/api/data',
  createGracefulDegradationMiddleware('database'),
  (req, res) => {
    // Handle request
  }
);
```

### API Endpoints

When integrated into the API, the following endpoints are available:

#### Get Degradation Status

```
GET /api/degradation/status
GET /api/degradation/status/:serviceName
```

Response:

```json
{
  "service": "database",
  "isDegraded": true,
  "reason": "Connection timeout",
  "severity": "warning",
  "affectedEndpoints": [],
  "fallbackActive": true,
  "degradationStartTime": 1234567890,
  "status": "degraded"
}
```

#### Mark Service Degraded

```
POST /api/degradation/mark-degraded
```

Request:

```json
{
  "serviceName": "database",
  "reason": "Manual degradation",
  "severity": "warning"
}
```

#### Mark Service Recovered

```
POST /api/degradation/mark-recovered
```

Request:

```json
{
  "serviceName": "database"
}
```

#### Get Degradation Metrics

```
GET /api/degradation/metrics
```

Response:

```json
{
  "metrics": {
    "totalDegradations": 5,
    "activeDegradations": 1,
    "fallbacksUsed": 3,
    "recoveries": 4,
    "activeDegradedServices": 1
  },
  "timestamp": "2024-01-19T12:00:00Z"
}
```

#### Reset All Degradation

```
POST /api/degradation/reset
```

### Degradation States

The service tracks three severity levels:

1. **none** - Service is healthy
2. **warning** - Service is degraded but operational
3. **critical** - Service is severely degraded

### Critical Endpoints

Critical endpoints cannot be degraded and will return 503 Service Unavailable when their service is degraded:

```javascript
gracefulDegradationService.registerService('auth', {
  criticalEndpoints: ['/api/auth/login', '/api/auth/refresh'],
});
```

### Reduced Functionality Mode

Non-critical endpoints can operate in reduced functionality mode:

```javascript
gracefulDegradationService.registerService('database', {
  reducedFunctionality: {
    availableFeatures: ['read', 'cache'],
    unavailableFeatures: ['write', 'sync'],
    estimatedRecoveryTime: '5 minutes',
  },
});
```

### Fallback Mechanisms

Services can define fallback functions to execute when primary operations fail:

```javascript
gracefulDegradationService.registerService('external-api', {
  fallback: async (arg1, arg2) => {
    // Return cached or default response
    return { data: 'fallback', cached: true };
  },
});

// Execute with fallback
const result = await gracefulDegradationService.executeWithFallback(
  'external-api',
  primaryFunction,
  context,
  [arg1, arg2]
);
```

### Metrics and Monitoring

The service tracks comprehensive metrics:

- **totalDegradations** - Total number of degradation events
- **activeDegradations** - Currently degraded services
- **fallbacksUsed** - Number of times fallback was used
- **recoveries** - Number of successful recoveries
- **activeDegradedServices** - Count of currently degraded services

### Response Headers

When services are degraded, the API adds headers to responses:

```
X-Service-Status: degraded
X-Degraded-Services: 2
```

### Error Response Format

When a critical endpoint is accessed during degradation:

```json
{
  "error": {
    "code": "SERVICE_DEGRADED",
    "message": "Service is temporarily unavailable: Connection timeout",
    "category": "service_unavailable",
    "statusCode": 503,
    "correlationId": "req-12345",
    "suggestion": "Please try again in a few moments",
    "degradationInfo": {
      "service": "database",
      "severity": "warning",
      "degradationStartTime": 1234567890
    }
  }
}
```

## Testing

### Unit Tests (`test/api-backend/graceful-degradation.test.js`)

Comprehensive unit tests covering:

- Service registration
- Degradation state management
- Fallback mechanisms
- Critical endpoints
- Reduced functionality
- Status reporting
- Metrics tracking
- Reset functionality
- Error handling
- Multiple service scenarios

**Test Results:** 35 tests passed, 94.11% statement coverage

### Integration Tests (`test/api-backend/graceful-degradation-integration.test.js`)

Integration tests covering:

- Middleware integration
- Endpoint responses
- Status reporting
- Manual degradation/recovery
- Metrics endpoints
- Multiple service degradation scenarios
- Error response format

**Test Results:** 24 tests passed, 100% middleware coverage

## Usage Examples

### Example 1: Database Service with Fallback

```javascript
import { gracefulDegradationService } from './services/graceful-degradation.js';

// Register database service
gracefulDegradationService.registerService('database', {
  fallback: async (query) => {
    // Return cached results
    return cache.get(query) || { data: [], source: 'cache' };
  },
  criticalEndpoints: ['/api/auth', '/api/payment'],
  reducedFunctionality: {
    availableFeatures: ['read', 'cache'],
    unavailableFeatures: ['write', 'sync'],
  },
});

// Use in route
app.get('/api/users', async (req, res) => {
  try {
    const users = await gracefulDegradationService.executeWithFallback(
      'database',
      async () => {
        return await db.query('SELECT * FROM users');
      }
    );
    res.json(users);
  } catch (error) {
    res.status(503).json({ error: 'Service unavailable' });
  }
});
```

### Example 2: External API with Degradation

```javascript
// Register external API service
gracefulDegradationService.registerService('payment-api', {
  fallback: async (amount, userId) => {
    // Queue for retry
    await retryQueue.add({ amount, userId });
    return { status: 'queued', message: 'Payment queued for retry' };
  },
  criticalEndpoints: ['/api/payment/process'],
});

// Middleware protection
app.post(
  '/api/payment/process',
  createGracefulDegradationMiddleware('payment-api'),
  async (req, res) => {
    // Process payment
  }
);
```

### Example 3: Monitoring Degradation

```javascript
// Get comprehensive report
const report = gracefulDegradationService.getReport();

console.log(`Total services: ${report.totalServices}`);
console.log(`Degraded services: ${report.degradedServices}`);
console.log(`Overall status: ${report.summary.overallStatus}`);

// Get specific service status
const dbStatus = gracefulDegradationService.getStatus('database');
if (dbStatus.isDegraded) {
  console.log(`Database degraded: ${dbStatus.reason}`);
  console.log(`Severity: ${dbStatus.severity}`);
}
```

## Integration with Circuit Breaker

Graceful degradation works alongside the circuit breaker pattern:

1. **Circuit Breaker** - Prevents cascading failures by failing fast
2. **Graceful Degradation** - Continues operation with reduced functionality

When a circuit breaker opens, graceful degradation can provide fallback responses instead of complete failure.

## Best Practices

1. **Define Critical Endpoints** - Clearly identify endpoints that cannot be degraded
2. **Implement Fallbacks** - Provide meaningful fallback responses for non-critical operations
3. **Monitor Degradation** - Track degradation events and recovery times
4. **Test Degradation** - Regularly test degradation scenarios
5. **Document Reduced Functionality** - Clearly communicate what features are unavailable
6. **Set Realistic Recovery Times** - Provide accurate estimates for recovery
7. **Log Degradation Events** - Track all degradation and recovery events
8. **Alert on Critical Degradation** - Notify operators of critical service degradation

## Performance Considerations

- Minimal overhead when services are healthy
- Fallback execution is fast (cached or default responses)
- Metrics collection is efficient
- No blocking operations in degradation checks

## Future Enhancements

1. **Automatic Degradation Detection** - Detect degradation based on error rates
2. **Adaptive Fallbacks** - Adjust fallback behavior based on system load
3. **Degradation Policies** - Define degradation rules per service
4. **Distributed Degradation** - Share degradation state across instances
5. **Degradation Analytics** - Analyze degradation patterns and trends
6. **Predictive Degradation** - Predict and prevent degradation events

## References

- Requirement 7.6: Graceful Degradation
- Circuit Breaker Pattern Implementation
- Error Handling and Recovery Strategy
- Monitoring and Observability

## Conclusion

The graceful degradation implementation provides a robust mechanism for the API to continue operating when services are unavailable. By combining fallback mechanisms, reduced functionality modes, and comprehensive monitoring, the system can maintain service availability and user experience even during partial outages.
