# Graceful Degradation Quick Reference

## Quick Start

### 1. Register a Service

```javascript
import { gracefulDegradationService } from './services/graceful-degradation.js';

gracefulDegradationService.registerService('my-service', {
  fallback: async () => ({ data: 'fallback' }),
  criticalEndpoints: ['/api/critical'],
  reducedFunctionality: {
    availableFeatures: ['read'],
    unavailableFeatures: ['write'],
  },
});
```

### 2. Use Middleware

```javascript
import { createGracefulDegradationMiddleware } from './middleware/graceful-degradation-middleware.js';

app.get(
  '/api/data',
  createGracefulDegradationMiddleware('my-service'),
  handler
);
```

### 3. Execute with Fallback

```javascript
const result = await gracefulDegradationService.executeWithFallback(
  'my-service',
  async () => primaryFunction(),
  context,
  args
);
```

## Common Operations

### Mark Service as Degraded

```javascript
gracefulDegradationService.markDegraded('my-service', 'Connection failed', 'warning');
```

### Mark Service as Recovered

```javascript
gracefulDegradationService.markRecovered('my-service');
```

### Get Service Status

```javascript
const status = gracefulDegradationService.getStatus('my-service');
console.log(status.isDegraded); // true/false
```

### Get All Statuses

```javascript
const statuses = gracefulDegradationService.getAllStatuses();
```

### Get Metrics

```javascript
const metrics = gracefulDegradationService.getMetrics();
console.log(metrics.activeDegradations);
```

### Get Full Report

```javascript
const report = gracefulDegradationService.getReport();
console.log(report.summary.overallStatus); // 'healthy' or 'degraded'
```

### Reset All

```javascript
gracefulDegradationService.resetAll();
```

## API Endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/degradation/status` | Get all service statuses |
| GET | `/api/degradation/status/:serviceName` | Get specific service status |
| POST | `/api/degradation/mark-degraded` | Manually mark service as degraded |
| POST | `/api/degradation/mark-recovered` | Manually mark service as recovered |
| GET | `/api/degradation/metrics` | Get degradation metrics |
| POST | `/api/degradation/reset` | Reset all degradation states |

## Configuration Options

```javascript
{
  // Function to call when primary fails
  fallback: async (...args) => {},
  
  // Endpoints that cannot be degraded
  criticalEndpoints: ['/api/auth', '/api/payment'],
  
  // Reduced functionality configuration
  reducedFunctionality: {
    availableFeatures: ['read', 'cache'],
    unavailableFeatures: ['write', 'sync'],
    estimatedRecoveryTime: '5 minutes',
  },
  
  // Retry configuration
  retryConfig: {
    maxRetries: 3,
    backoffMs: 1000,
  },
}
```

## Severity Levels

- **none** - Service is healthy
- **warning** - Service is degraded but operational
- **critical** - Service is severely degraded

## Response Headers

When services are degraded:

```
X-Service-Status: degraded
X-Degraded-Services: 2
```

## Error Response

```json
{
  "error": {
    "code": "SERVICE_DEGRADED",
    "message": "Service is temporarily unavailable: Connection timeout",
    "statusCode": 503,
    "degradationInfo": {
      "service": "database",
      "severity": "warning"
    }
  }
}
```

## Testing

### Unit Tests

```bash
npm test -- test/api-backend/graceful-degradation.test.js
```

### Integration Tests

```bash
npm test -- test/api-backend/graceful-degradation-integration.test.js
```

## Metrics

- `totalDegradations` - Total degradation events
- `activeDegradations` - Currently degraded services
- `fallbacksUsed` - Fallback executions
- `recoveries` - Successful recoveries
- `activeDegradedServices` - Count of degraded services

## Best Practices

1. ✅ Define critical endpoints clearly
2. ✅ Implement meaningful fallbacks
3. ✅ Monitor degradation events
4. ✅ Test degradation scenarios
5. ✅ Log all degradation events
6. ✅ Alert on critical degradation
7. ✅ Document reduced functionality
8. ✅ Set realistic recovery times

## Common Patterns

### Pattern 1: Cache Fallback

```javascript
fallback: async (query) => cache.get(query) || { data: [] }
```

### Pattern 2: Queue Fallback

```javascript
fallback: async (data) => {
  await queue.add(data);
  return { status: 'queued' };
}
```

### Pattern 3: Default Response

```javascript
fallback: async () => ({ data: [], source: 'default' })
```

### Pattern 4: Partial Data

```javascript
fallback: async () => ({
  data: partialData,
  warning: 'Partial data from cache'
})
```

## Troubleshooting

### Service not degrading?

- Check if service is registered
- Verify middleware is applied
- Check error handling in primary function

### Fallback not executing?

- Verify fallback function is defined
- Check if primary function is throwing error
- Review error logs

### Metrics not updating?

- Verify service is registered
- Check if operations are being executed
- Review metrics endpoint response

## Integration Points

- **Circuit Breaker** - Works with circuit breaker for cascading failure prevention
- **Error Handling** - Integrates with error categorization
- **Monitoring** - Exports metrics for Prometheus
- **Logging** - Logs all degradation events
- **Alerting** - Can trigger alerts on critical degradation

## Performance

- Minimal overhead when healthy
- Fast fallback execution
- Efficient metrics collection
- No blocking operations

## Files

- `services/graceful-degradation.js` - Core service
- `middleware/graceful-degradation-middleware.js` - Express middleware
- `test/api-backend/graceful-degradation.test.js` - Unit tests
- `test/api-backend/graceful-degradation-integration.test.js` - Integration tests
