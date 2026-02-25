# Log Aggregation Quick Reference

## Quick Start

### 1. Enable Log Aggregation

```bash
# .env
LOKI_ENABLED=true
LOKI_URL=http://localhost:3100

ELK_ENABLED=true
ELK_HOSTS=localhost:9200
```

### 2. Add Middleware to Express

```javascript
import { createLogRoutingMiddleware, flushLogs, destroyLogRouting } from './middleware/log-routing.js';

app.use(createLogRoutingMiddleware());

process.on('SIGTERM', async () => {
  await flushLogs();
  destroyLogRouting();
  process.exit(0);
});
```

### 3. Use Structured Logging

```javascript
import logger from './logger.js';

logger.info('User login', {
  userId: user.id,
  correlationId: req.correlationId
});
```

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| LOKI_ENABLED | false | Enable Loki log aggregation |
| LOKI_URL | http://localhost:3100 | Loki server URL |
| LOKI_BATCH_SIZE | 100 | Logs per batch |
| LOKI_BATCH_TIMEOUT | 5000 | Batch timeout in ms |
| ELK_ENABLED | false | Enable ELK log aggregation |
| ELK_HOSTS | localhost:9200 | Elasticsearch hosts |
| ELK_INDEX | cloudtolocalllm-api | Index name |
| LOG_ERRORS_TO_SENTRY | true | Send errors to Sentry |
| LOG_ERRORS_TO_FILE | true | Write errors to file |
| LOG_WARNINGS_TO_FILE | true | Write warnings to file |
| LOG_INFO_TO_CONSOLE | true | Write info to console |

## Common Tasks

### Create Structured Log Entry

```javascript
import { createStructuredLogEntry } from './utils/log-aggregation.js';

const logEntry = createStructuredLogEntry({
  level: 'error',
  message: 'Database connection failed',
  correlationId: 'corr-123',
  userId: 'user-456',
  stack: error.stack,
  customField: 'customValue'
});
```

### Extract Request Context

```javascript
import { getCorrelationId, getUserIdFromRequest } from './utils/log-aggregation.js';

const correlationId = getCorrelationId(req);
const userId = getUserIdFromRequest(req);
```

### Route Logs Manually

```javascript
import { routeLog } from './middleware/log-routing.js';

const logEntry = createStructuredLogEntry({
  level: 'warn',
  message: 'High memory usage'
});

routeLog(logEntry, req);
```

### Flush Logs

```javascript
import { flushLogs } from './middleware/log-routing.js';

await flushLogs();
```

### Check Destination Status

```javascript
import { logRouter } from './middleware/log-routing.js';

if (logRouter.isDestinationEnabled('loki')) {
  console.log('Loki is enabled');
}
```

## Log Levels

| Level | Destinations | Use Case |
|-------|--------------|----------|
| error | Sentry, File, Loki, ELK | Errors and exceptions |
| warn | File, Loki, ELK | Warnings and issues |
| info | Console, Loki, ELK | General information |
| debug | Loki, ELK | Debug information |

## Loki Queries

```
# All logs
{service="cloudtolocalllm-api"}

# Error logs
{service="cloudtolocalllm-api", level="error"}

# Logs for specific user
{service="cloudtolocalllm-api", userId="user-123"}

# Logs with correlation ID
{service="cloudtolocalllm-api", correlationId="corr-123"}

# Logs in time range
{service="cloudtolocalllm-api"} | since 1h
```

## ELK Queries

```
# All logs
service: "cloudtolocalllm-api"

# Error logs
service: "cloudtolocalllm-api" AND level: "error"

# Logs for specific user
service: "cloudtolocalllm-api" AND userId: "user-123"

# Logs with correlation ID
service: "cloudtolocalllm-api" AND correlationId: "corr-123"

# Logs in time range
service: "cloudtolocalllm-api" AND @timestamp: [now-1h TO now]
```

## Testing

```bash
# Run unit tests
npm test -- ../test/api-backend/log-aggregation.test.js

# Run integration tests
npm test -- ../test/api-backend/log-routing-integration.test.js

# Run all log tests
npm test -- ../test/api-backend/log-aggregation.test.js ../test/api-backend/log-routing-integration.test.js
```

## Troubleshooting

### Logs not appearing

1. Check aggregation system is running
2. Check environment variables are set
3. Check logs are being flushed
4. Check network connectivity

### High memory usage

1. Reduce batch size
2. Reduce batch timeout
3. Check for transmission errors

### Slow performance

1. Increase batch size
2. Increase batch timeout
3. Check network latency

## Files

| File | Purpose |
|------|---------|
| `utils/log-aggregation.js` | Log formatting and batching |
| `middleware/log-routing.js` | Log routing middleware |
| `test/api-backend/log-aggregation.test.js` | Unit tests |
| `test/api-backend/log-routing-integration.test.js` | Integration tests |
| `LOG_AGGREGATION_IMPLEMENTATION.md` | Full documentation |

## Related Requirements

- **8.3**: Structured logging with JSON format
- **8.4**: Correlation IDs in all logs
- **8.9**: Log aggregation support (Loki, ELK)
