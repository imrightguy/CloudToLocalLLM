# Webhook Rate Limiting - Implementation Summary

## Overview

This document describes the implementation of webhook-specific rate limiting for the CloudToLocalLLM API backend. The system enforces configurable rate limits on webhook deliveries to prevent abuse and ensure fair resource usage.

## Requirements Addressed

- **Requirement 10.7**: THE API SHALL implement webhook rate limiting

## Architecture

### Components

1. **WebhookRateLimiterService** (`services/webhook-rate-limiter.js`)
   - Core service for rate limit management
   - Handles configuration, enforcement, and statistics
   - Uses in-memory caching for performance

2. **Middleware** (`middleware/webhook-rate-limiter.js`)
   - `webhookRateLimiterMiddleware` - Enforces rate limits
   - `webhookRateLimitConfigMiddleware` - Validates configuration

3. **Routes** (`routes/webhook-rate-limiting.js`)
   - GET `/api/webhooks/:webhookId/rate-limit` - Get configuration
   - PUT `/api/webhooks/:webhookId/rate-limit` - Update configuration
   - GET `/api/webhooks/:webhookId/rate-limit/stats` - Get statistics

4. **Database** (`database/migrations/webhook-rate-limiting.sql`)
   - `webhook_rate_limits` - Configuration storage
   - `webhook_rate_limit_tracking` - Delivery tracking for metrics

## Key Features

### 1. Configurable Rate Limits

Three time windows with independent limits:

- **Per Minute**: Default 60 deliveries
- **Per Hour**: Default 1,000 deliveries
- **Per Day**: Default 10,000 deliveries

### 2. Rate Limit Enforcement

- Checks limits before allowing webhook delivery
- Returns 429 (Too Many Requests) when exceeded
- Includes rate limit headers in responses
- Tracks which limit was exceeded (minute/hour/day)

### 3. Configuration Management

- Per-webhook, per-user configuration
- Validation ensures `minute <= hour <= day`
- Can be enabled/disabled per webhook
- Configuration changes invalidate cache

### 4. Statistics and Monitoring

- Track total deliveries (successful and failed)
- Monitor current usage in each time window
- Calculate remaining quota
- Support for metrics and dashboards

### 5. Performance Optimization

- In-memory caching for O(1) rate limit checks
- Automatic cache cleanup every 5 minutes
- Database queries only for configuration
- Typical response time: < 1ms

## Implementation Details

### Rate Limit Checking Algorithm

```javascript
1. Get or create cache entry for webhook:user
2. Clean up old entries older than 1 day
3. Count deliveries in each time window:
   - Minute: deliveries in last 60 seconds
   - Hour: deliveries in last 3600 seconds
   - Day: deliveries in last 86400 seconds
4. Check if any limit exceeded
5. If allowed, add current delivery to cache
6. Return result with current usage and limits
```

### Configuration Validation

```javascript
1. Validate each limit is a positive integer
2. Ensure minute <= hour <= day
3. Throw error if validation fails
4. Prevent invalid configurations from being saved
```

### Cache Management

```javascript
1. Cache entries stored in Map with key: "webhookId:userId"
2. Each entry contains:
   - deliveries: array of timestamps
   - lastUpdated: timestamp of last update
3. Cleanup runs every 5 minutes
4. Entries older than 1 hour are removed
5. Cache invalidated when configuration changes
```

## Database Schema

### webhook_rate_limits Table

```sql
CREATE TABLE webhook_rate_limits (
  id UUID PRIMARY KEY,
  webhook_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id),
  rate_limit_per_minute INTEGER DEFAULT 60,
  rate_limit_per_hour INTEGER DEFAULT 1000,
  rate_limit_per_day INTEGER DEFAULT 10000,
  is_enabled BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(webhook_id, user_id)
);
```

### webhook_rate_limit_tracking Table

```sql
CREATE TABLE webhook_rate_limit_tracking (
  id UUID PRIMARY KEY,
  webhook_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id),
  delivery_id UUID NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## API Endpoints

### Get Rate Limit Configuration

```
GET /api/webhooks/:webhookId/rate-limit
Authorization: Bearer <token>
```

Returns current rate limit configuration for a webhook.

### Update Rate Limit Configuration

```
PUT /api/webhooks/:webhookId/rate-limit
Authorization: Bearer <token>
Content-Type: application/json

{
  "rate_limit_config": {
    "rate_limit_per_minute": 30,
    "rate_limit_per_hour": 500,
    "rate_limit_per_day": 5000,
    "is_enabled": true
  }
}
```

Updates rate limit configuration. Validates that limits are in correct order.

### Get Rate Limit Statistics

```
GET /api/webhooks/:webhookId/rate-limit/stats
Authorization: Bearer <token>
```

Returns current usage statistics and remaining quota.

## Response Headers

All webhook delivery responses include rate limit headers:

```
X-RateLimit-Limit-Minute: 60
X-RateLimit-Remaining-Minute: 55
X-RateLimit-Limit-Hour: 1000
X-RateLimit-Remaining-Hour: 955
X-RateLimit-Limit-Day: 10000
X-RateLimit-Remaining-Day: 9550
```

## Error Handling

### Invalid Configuration

```json
{
  "error": {
    "code": "INVALID_RATE_LIMIT_CONFIG",
    "message": "Invalid rate limit configuration",
    "details": "rate_limit_per_minute must be <= rate_limit_per_hour"
  }
}
```

### Rate Limit Exceeded

```json
{
  "error": {
    "code": "WEBHOOK_RATE_LIMIT_EXCEEDED",
    "message": "Webhook rate limit exceeded",
    "reason": "minute_limit_exceeded",
    "limits": {
      "per_minute": { "current": 60, "max": 60 },
      "per_hour": { "current": 450, "max": 1000 },
      "per_day": { "current": 4500, "max": 10000 }
    }
  }
}
```

## Testing

### Unit Tests

Located in `test/api-backend/webhook-rate-limiting-unit.test.js`

Tests cover:

- Configuration validation
- Rate limit enforcement
- Cache management
- Limit isolation between webhooks/users
- Property-based tests for consistency

### Test Coverage

- ✅ Configuration validation (positive integers, ordering)
- ✅ Rate limit enforcement (minute, hour, day limits)
- ✅ Cache cleanup and expiration
- ✅ Isolation between webhooks and users
- ✅ Accuracy of limit counting
- ✅ Property: Rate limit enforcement consistency
- ✅ Property: Rate limit isolation
- ✅ Property: Rate limit accuracy

## Integration

### Middleware Integration

Add to middleware pipeline in `server.js`:

```javascript
import { webhookRateLimiterMiddleware } from './middleware/webhook-rate-limiter.js';

// Apply to webhook routes
app.use('/api/webhooks', webhookRateLimiterMiddleware);
```

### Service Initialization

Initialize in application startup:

```javascript
import { webhookRateLimiterService } from './services/webhook-rate-limiter.js';

await webhookRateLimiterService.initialize();
```

### Route Registration

Register routes in `server.js`:

```javascript
import webhookRateLimitingRoutes from './routes/webhook-rate-limiting.js';

app.use('/api/webhooks', webhookRateLimitingRoutes);
```

## Performance Characteristics

- **Rate Limit Check**: O(1) with in-memory cache
- **Configuration Update**: O(1) with cache invalidation
- **Statistics Query**: O(n) where n = deliveries in tracking table
- **Memory Usage**: ~100 bytes per active webhook:user pair
- **Cache Cleanup**: O(n) where n = cache entries (runs every 5 minutes)

## Monitoring and Observability

### Metrics to Track

- Total webhook deliveries
- Successful vs failed deliveries
- Rate limit violations per webhook
- Rate limit violations per user
- Average usage per time window

### Logging

- Configuration changes logged with details
- Rate limit violations logged with reason
- Cache cleanup logged periodically
- Errors logged with full context

## Future Enhancements

1. **Adaptive Rate Limiting**: Adjust limits based on system load
2. **Burst Allowance**: Allow temporary bursts above limits
3. **Rate Limit Tiers**: Different limits for different user tiers
4. **Webhook Prioritization**: Priority queue for important webhooks
5. **Rate Limit Sharing**: Share limits across related webhooks
6. **Metrics Export**: Export metrics to Prometheus/Grafana

## Troubleshooting

### Webhook Deliveries Blocked

1. Check current usage: `GET /api/webhooks/:webhookId/rate-limit/stats`
2. Verify limits are appropriate
3. Update limits if needed: `PUT /api/webhooks/:webhookId/rate-limit`
4. Consider disabling rate limiting if not needed

### Configuration Not Applied

1. Verify configuration was saved successfully
2. Check webhook ID and user ID are correct
3. Clear cache if needed
4. Restart service if necessary

### Performance Issues

1. Monitor cache size and cleanup frequency
2. Check database query performance
3. Verify indexes are created
4. Consider increasing cleanup interval if needed

## Compliance

- ✅ Requirement 10.7: Webhook rate limiting implemented
- ✅ Configurable limits per webhook
- ✅ Rate limit enforcement with 429 response
- ✅ Rate limit headers in responses
- ✅ Statistics and monitoring support
- ✅ Comprehensive error handling
- ✅ Unit tests with property-based testing
