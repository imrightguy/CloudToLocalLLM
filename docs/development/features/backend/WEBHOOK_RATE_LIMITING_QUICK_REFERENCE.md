# Webhook Rate Limiting - Quick Reference

## Overview

Webhook rate limiting prevents abuse and ensures fair resource usage by controlling the frequency of webhook deliveries. The system supports three time windows: per-minute, per-hour, and per-day limits.

## Default Limits

- **Per Minute**: 60 deliveries
- **Per Hour**: 1,000 deliveries
- **Per Day**: 10,000 deliveries

## Configuration

### Get Rate Limit Configuration

```bash
GET /api/webhooks/:webhookId/rate-limit
Authorization: Bearer <token>
```

Response:

```json
{
  "webhook_id": "webhook-123",
  "user_id": "user-456",
  "rate_limit_config": {
    "id": "config-789",
    "rate_limit_per_minute": 60,
    "rate_limit_per_hour": 1000,
    "rate_limit_per_day": 10000,
    "is_enabled": true
  }
}
```

### Update Rate Limit Configuration

```bash
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

Response:

```json
{
  "webhook_id": "webhook-123",
  "user_id": "user-456",
  "rate_limit_config": {
    "id": "config-789",
    "rate_limit_per_minute": 30,
    "rate_limit_per_hour": 500,
    "rate_limit_per_day": 5000,
    "is_enabled": true
  },
  "message": "Rate limit configuration updated successfully"
}
```

### Get Rate Limit Statistics

```bash
GET /api/webhooks/:webhookId/rate-limit/stats
Authorization: Bearer <token>
```

Response:

```json
{
  "webhook_id": "webhook-123",
  "user_id": "user-456",
  "rate_limit_config": {
    "rate_limit_per_minute": 60,
    "rate_limit_per_hour": 1000,
    "rate_limit_per_day": 10000,
    "is_enabled": true
  },
  "statistics": {
    "total_deliveries": 450,
    "successful_deliveries": 440,
    "failed_deliveries": 10,
    "current_minute_usage": 5,
    "current_hour_usage": 45,
    "current_day_usage": 450,
    "minute_remaining": 55,
    "hour_remaining": 955,
    "day_remaining": 9550
  }
}
```

## Rate Limit Headers

All webhook delivery responses include rate limit headers:

```
X-RateLimit-Limit-Minute: 60
X-RateLimit-Remaining-Minute: 55
X-RateLimit-Limit-Hour: 1000
X-RateLimit-Remaining-Hour: 955
X-RateLimit-Limit-Day: 10000
X-RateLimit-Remaining-Day: 9550
```

## Rate Limit Exceeded Response

When a rate limit is exceeded, the API returns a 429 (Too Many Requests) response:

```json
{
  "error": {
    "code": "WEBHOOK_RATE_LIMIT_EXCEEDED",
    "message": "Webhook rate limit exceeded",
    "reason": "minute_limit_exceeded",
    "limits": {
      "per_minute": {
        "current": 60,
        "max": 60
      },
      "per_hour": {
        "current": 450,
        "max": 1000
      },
      "per_day": {
        "current": 4500,
        "max": 10000
      }
    }
  }
}
```

## Configuration Validation Rules

1. **Positive Integers**: All limits must be positive integers (> 0)
2. **Ordering**: `per_minute <= per_hour <= per_day`
3. **Enable/Disable**: Rate limiting can be disabled by setting `is_enabled: false`

## Implementation Details

### Service: WebhookRateLimiterService

Located in `services/webhook-rate-limiter.js`

Key methods:

- `getWebhookRateLimitConfig(webhookId, userId)` - Get configuration
- `setWebhookRateLimitConfig(webhookId, userId, config)` - Set configuration
- `checkRateLimit(webhookId, userId)` - Check if delivery is allowed
- `getRateLimitStats(webhookId, userId)` - Get statistics
- `validateRateLimitConfig(config)` - Validate configuration

### Middleware: webhookRateLimiterMiddleware

Located in `middleware/webhook-rate-limiter.js`

Automatically checks rate limits for webhook deliveries and returns 429 if exceeded.

### Database Tables

- `webhook_rate_limits` - Stores rate limit configurations
- `webhook_rate_limit_tracking` - Tracks delivery attempts for metrics

## Cache Management

The service uses an in-memory cache for performance:

- Cache entries are automatically cleaned up every 5 minutes
- Entries older than 1 hour are removed
- Cache is invalidated when configuration is updated

## Best Practices

1. **Set Appropriate Limits**: Configure limits based on your webhook volume
2. **Monitor Usage**: Regularly check statistics to understand usage patterns
3. **Adjust as Needed**: Update limits if you see consistent rate limit violations
4. **Disable Selectively**: Only disable rate limiting for trusted webhooks
5. **Handle 429 Responses**: Implement exponential backoff when receiving 429 responses

## Troubleshooting

### Webhook Deliveries Being Blocked

1. Check current usage: `GET /api/webhooks/:webhookId/rate-limit/stats`
2. Verify limits are appropriate for your use case
3. Update limits if needed: `PUT /api/webhooks/:webhookId/rate-limit`
4. Consider disabling rate limiting if not needed

### Configuration Not Taking Effect

1. Verify the configuration was saved successfully
2. Check that the webhook ID and user ID are correct
3. Clear any local caches if applicable
4. Restart the service if needed

## Performance Considerations

- Rate limit checks use in-memory caching for O(1) performance
- Database queries are only used for configuration management
- Cleanup runs every 5 minutes to prevent memory bloat
- Typical response time: < 1ms per check
