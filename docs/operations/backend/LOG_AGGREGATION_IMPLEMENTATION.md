# Log Aggregation Implementation

## Overview

This document describes the log aggregation support implementation for the CloudToLocalLLM API backend. The implementation provides comprehensive support for log aggregation systems like Loki and ELK (Elasticsearch, Logstash, Kibana).

**Requirement:** 8.9 - THE API SHALL implement log aggregation support (Loki, ELK)

## Architecture

### Components

1. **Log Aggregation Utilities** (`utils/log-aggregation.js`)
   - Configuration management for Loki and ELK
   - Log formatting for different aggregation systems
   - Log batching for efficient transmission
   - Log routing based on level and configuration

2. **Log Routing Middleware** (`middleware/log-routing.js`)
   - Express middleware for log routing
   - Integration with Winston logger
   - Batch processing and transmission
   - Graceful shutdown support

3. **Tests**
   - Unit tests: `test/api-backend/log-aggregation.test.js` (40 tests)
   - Integration tests: `test/api-backend/log-routing-integration.test.js` (24 tests)

## Configuration

### Environment Variables

```bash
# Loki Configuration
LOKI_ENABLED=true
LOKI_URL=http://localhost:3100
LOKI_BATCH_SIZE=100
LOKI_BATCH_TIMEOUT=5000

# ELK Configuration
ELK_ENABLED=true
ELK_HOSTS=localhost:9200
ELK_INDEX=cloudtolocalllm-api
ELK_INDEX_PATTERN=cloudtolocalllm-api-%DATE%
ELK_BATCH_SIZE=100
ELK_BATCH_TIMEOUT=5000

# Log Routing Configuration
LOG_ERRORS_TO_SENTRY=true
LOG_ERRORS_TO_FILE=true
LOG_WARNINGS_TO_FILE=true
LOG_INFO_TO_CONSOLE=true
```

## Usage

### Basic Setup

```javascript
import { createLogRoutingMiddleware, flushLogs, destroyLogRouting } from './middleware/log-routing.js';

// Add middleware to Express app
app.use(createLogRoutingMiddleware());

// On graceful shutdown
process.on('SIGTERM', async () => {
  await flushLogs();
  destroyLogRouting();
  process.exit(0);
});
```

### Log Formatting

#### Loki Format

Logs are formatted for Loki with stream labels and values:

```javascript
{
  timestamp: 1705318200000000000,  // Nanoseconds
  stream: {
    level: 'info',
    service: 'cloudtolocalllm-api',
    environment: 'production',
    correlationId: 'corr-123',
    userId: 'user-456'
  },
  values: [
    [
      1705318200000000000,
      '{"message":"Test log","level":"info",...}'
    ]
  ]
}
```

#### ELK Format

Logs are formatted for ELK with standard fields:

```javascript
{
  '@timestamp': '2024-01-15T10:30:00.000Z',
  level: 'info',
  message: 'Test log',
  service: 'cloudtolocalllm-api',
  environment: 'production',
  correlationId: 'corr-123',
  userId: 'user-456',
  metadata: {
    customField: 'value'
  }
}
```

### Log Routing

Logs are routed to appropriate destinations based on level:

- **Error logs**: Sentry, file, Loki, ELK
- **Warning logs**: File, Loki, ELK
- **Info logs**: Console, Loki, ELK
- **Debug logs**: Loki, ELK

### Request Context Enrichment

Logs are automatically enriched with request context:

```javascript
// Correlation ID from headers
req.headers['x-correlation-id']
req.headers['x-request-id']
req.id

// User ID from request
req.userId
req.user.id
```

## Features

### 1. Log Batching

Logs are batched for efficient transmission:

- Batch size: 100 logs (configurable)
- Batch timeout: 5 seconds (configurable)
- Automatic flush on size or timeout

```javascript
const batcher = new LogBatcher({
  batchSize: 100,
  batchTimeout: 5000,
  onFlush: (logs) => {
    // Send logs to aggregation system
  }
});

batcher.add(logEntry);
batcher.flush();
batcher.destroy();
```

### 2. Log Router

Routes logs to appropriate destinations:

```javascript
const router = new LogRouter({
  errorToSentry: true,
  errorToFile: true,
  warningToFile: true,
  infoToConsole: true
});

const destinations = router.getDestinations('error');
// Returns: ['sentry', 'file', 'loki', 'elk']
```

### 3. Structured Logging

Create structured log entries with all required fields:

```javascript
const logEntry = createStructuredLogEntry({
  level: 'error',
  message: 'Test error',
  correlationId: 'corr-123',
  userId: 'user-456',
  stack: 'Error stack trace',
  customField: 'customValue'
});
```

### 4. Request Context Extraction

Extract context from Express requests:

```javascript
const correlationId = getCorrelationId(req);
const userId = getUserIdFromRequest(req);
```

## Integration with Loki

### Setup

1. Deploy Loki:

```bash
docker run -d -p 3100:3100 grafana/loki:latest
```

1. Enable in environment:

```bash
LOKI_ENABLED=true
LOKI_URL=http://localhost:3100
```

1. Query logs in Grafana:

```
{service="cloudtolocalllm-api", level="error"}
```

## Integration with ELK

### Setup

1. Deploy ELK Stack:

```bash
docker-compose up -d elasticsearch logstash kibana
```

1. Enable in environment:

```bash
ELK_ENABLED=true
ELK_HOSTS=localhost:9200
```

1. Query logs in Kibana:

```
service: "cloudtolocalllm-api" AND level: "error"
```

## Testing

### Unit Tests (40 tests)

```bash
npm test -- ../test/api-backend/log-aggregation.test.js
```

Tests cover:

- Log aggregation configuration
- Loki log formatting
- ELK log formatting
- Log batching
- Log routing
- Structured log entry creation
- Request context extraction
- Log format consistency

### Integration Tests (24 tests)

```bash
npm test -- ../test/api-backend/log-routing-integration.test.js
```

Tests cover:

- Log routing middleware
- Log routing with request context
- Log router destination selection
- Log aggregation configuration
- Log flushing
- Log routing cleanup
- Log entry enrichment
- Error handling
- Performance

## Performance Considerations

### Batching

- Reduces network overhead by batching logs
- Configurable batch size and timeout
- Automatic flush on shutdown

### Async Processing

- Non-blocking log transmission
- Errors in log transmission don't affect application
- Graceful degradation if aggregation system is unavailable

### Memory Usage

- Logs are batched in memory
- Batch size limits memory usage
- Automatic cleanup after flush

## Error Handling

### Loki Errors

- Connection errors are logged but don't affect application
- Failed batches are retried on next batch
- Graceful degradation if Loki is unavailable

### ELK Errors

- Connection errors are logged but don't affect application
- Failed batches are retried on next batch
- Graceful degradation if ELK is unavailable

## Monitoring

### Metrics

- Log batches sent to Loki
- Log batches sent to ELK
- Failed log transmissions
- Log routing destinations

### Debugging

Enable debug logging:

```bash
LOG_LEVEL=debug
```

## Best Practices

1. **Always flush logs on shutdown**

   ```javascript
   process.on('SIGTERM', async () => {
     await flushLogs();
     destroyLogRouting();
   });
   ```

2. **Include correlation IDs in requests**

   ```javascript
   req.headers['x-correlation-id'] = generateCorrelationId();
   ```

3. **Use structured logging**

   ```javascript
   logger.info('User login', {
     userId: user.id,
     correlationId: req.correlationId,
     timestamp: new Date().toISOString()
   });
   ```

4. **Monitor log aggregation system health**

   ```javascript
   const router = new LogRouter();
   if (router.isDestinationEnabled('loki')) {
     // Loki is enabled
   }
   ```

## Troubleshooting

### Logs not appearing in Loki

1. Check Loki is running: `curl http://localhost:3100/loki/api/v1/status`
2. Check LOKI_ENABLED=true
3. Check LOKI_URL is correct
4. Check logs are being flushed

### Logs not appearing in ELK

1. Check Elasticsearch is running: `curl http://localhost:9200`
2. Check ELK_ENABLED=true
3. Check ELK_HOSTS is correct
4. Check logs are being flushed

### High memory usage

1. Reduce LOKI_BATCH_SIZE or ELK_BATCH_SIZE
2. Reduce LOKI_BATCH_TIMEOUT or ELK_BATCH_TIMEOUT
3. Check for log transmission errors

## Future Enhancements

1. **Log Sampling**: Sample logs based on level or rate
2. **Log Filtering**: Filter logs before transmission
3. **Log Transformation**: Transform logs before transmission
4. **Multiple Destinations**: Send logs to multiple aggregation systems
5. **Metrics**: Track log transmission metrics
6. **Alerting**: Alert on log aggregation failures

## References

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [ELK Stack Documentation](https://www.elastic.co/guide/index.html)
- [Winston Logger](https://github.com/winstonjs/winston)
- [Structured Logging Best Practices](https://www.kartar.net/2015/12/structured-logging/)
