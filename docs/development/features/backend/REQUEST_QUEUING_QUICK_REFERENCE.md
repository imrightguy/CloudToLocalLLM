# Request Queuing Quick Reference

## Overview

Request queuing automatically queues requests when the rate limit is approached (80% by default), preventing request rejection and improving user experience.

## Key Features

- **Automatic Queuing**: Requests queued when approaching rate limit
- **FIFO Processing**: Requests processed in order
- **Per-User & Per-IP**: Separate queues for each user and IP
- **Configurable**: Threshold, timeout, and queue size customizable
- **Statistics**: Comprehensive queue metrics and health status

## Configuration

In `middleware/pipeline.js`:

```javascript
const requestQueuingMiddleware = createRequestQueuingMiddleware({
  maxQueueSize: 1000,              // Max requests per queue
  queueTimeoutMs: 30000,           // 30 second timeout
  queueThresholdPercent: 80,       // Start queuing at 80% of limit
});
```

## API Endpoints

### Get Queue Status

```
GET /api/queue/status
GET /queue/status

Response:
{
  "status": "healthy|degraded",
  "queue": {
    "currentQueued": 5,
    "totalQueues": 3,
    "userQueues": 2,
    "ipQueues": 1,
    "maxQueueSize": 1000
  },
  "statistics": {
    "totalQueued": 150,
    "totalProcessed": 145,
    "totalExpired": 2,
    "totalRejected": 3
  },
  "health": {
    "averageQueueSize": 1.67,
    "status": "healthy"
  },
  "timestamp": "2024-11-19T10:30:00Z"
}
```

### Drain Queue (Authenticated)

```
POST /api/queue/drain
POST /queue/drain

Response:
{
  "success": true,
  "message": "Drained 5 requests from queue",
  "identifier": "user123",
  "queueType": "user",
  "processed": 5,
  "remainingInQueue": 0,
  "timestamp": "2024-11-19T10:30:00Z"
}
```

## Response Headers

When request is processed from queue:

- `X-Queue-Position`: Position in queue (e.g., "1")
- `X-Queue-Wait-Time`: Wait time in milliseconds (e.g., "250")

## Error Responses

### Queue Full (429)

```json
{
  "error": "Too many requests",
  "code": "QUEUE_FULL",
  "message": "Request queue is full. Please try again later.",
  "retryAfter": 60,
  "correlationId": "req-12345"
}
```

### Queue Timeout (504)

```json
{
  "error": "Request timeout",
  "code": "QUEUE_TIMEOUT",
  "message": "Your request was queued but timed out waiting for processing.",
  "correlationId": "req-12345"
}
```

### Queue Error (503)

```json
{
  "error": "Service unavailable",
  "code": "QUEUE_ERROR",
  "message": "Error processing queued request.",
  "correlationId": "req-12345"
}
```

## Usage Examples

### Check Queue Status

```bash
curl -X GET http://localhost:8080/api/queue/status
```

### Drain Queue (Authenticated)

```bash
curl -X POST http://localhost:8080/api/queue/drain \
  -H "Authorization: Bearer <token>"
```

## Queue Statistics

- **totalQueued**: Total requests ever queued
- **totalProcessed**: Total requests processed from queue
- **totalExpired**: Total requests that timed out
- **totalRejected**: Total requests rejected (queue full)
- **currentQueuedRequests**: Currently queued requests
- **userQueuesCount**: Number of active user queues
- **ipQueuesCount**: Number of active IP queues

## Health Status

- **healthy**: < 100 queued requests
- **degraded**: >= 100 queued requests

## Behavior

1. **Request arrives** → Rate limiter checks limit
2. **Approaching limit?** (80% by default)
   - YES → Queue request, wait for processing
   - NO → Continue normally
3. **Queue full?** (1000 requests by default)
   - YES → Return 429 error
   - NO → Add to queue
4. **Timeout?** (30 seconds by default)
   - YES → Return 504 error
   - NO → Process request
5. **Response sent** with queue info headers

## Monitoring

### Check Queue Health

```bash
curl http://localhost:8080/api/queue/status | jq '.health'
```

### Monitor Queue Size

```bash
curl http://localhost:8080/api/queue/status | jq '.queue.currentQueued'
```

### Track Statistics

```bash
curl http://localhost:8080/api/queue/status | jq '.statistics'
```

## Troubleshooting

### Queue Growing Too Large

- Check if rate limit is too restrictive
- Increase `maxQueueSize` if needed
- Monitor backend performance

### Requests Timing Out

- Increase `queueTimeoutMs` if needed
- Check backend performance
- Monitor queue processing rate

### High Rejection Rate

- Increase `maxQueueSize`
- Lower `queueThresholdPercent` to queue earlier
- Check rate limit configuration

## Integration

The request queuing middleware is integrated into the middleware pipeline at step 8:

1. Sentry Request Handler
2. Sentry Tracing Handler
3. CORS Middleware
4. Helmet Security Headers
5. Request Logging
6. Request Validation
7. Rate Limiting
8. **Request Queuing** ← Here
9. Body Parsing
10. Request Timeout
11. Authentication
12. Authorization
13. Queue Status
14. Compression
15. Error Handling

## Testing

Run tests:

```bash
npm test -- test/api-backend/request-queuing.test.js
```

Test coverage:

- 31 tests total
- 30 passing
- 4 property-based tests
- FIFO order validation
- Queue size limits
- Statistics accuracy
- Timeout handling
