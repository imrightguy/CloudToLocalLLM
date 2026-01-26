# Adaptive Rate Limiting - Quick Reference

## Overview

Adaptive rate limiting automatically adjusts rate limits based on system load (CPU, memory, and request queue depth). This prevents the system from being overwhelmed during high-load periods while maintaining normal limits during low-load periods.

## Key Components

### 1. SystemLoadMonitor (`services/system-load-monitor.js`)

- Monitors CPU usage, memory usage, and request queue depth
- Calculates overall system load percentage (0-100)
- Determines load level: low, medium, high, critical
- Adjusts adaptive multiplier based on load

### 2. AdaptiveRateLimiter (`middleware/adaptive-rate-limiter.js`)

- Integrates SystemLoadMonitor with rate limiting
- Applies adaptive multiplier to rate limits
- Tracks per-user request counts
- Enforces adaptive limits

### 3. Routes (`routes/adaptive-rate-limiting.js`)

- `/adaptive-rate-limiting/metrics` - Get current system metrics
- `/adaptive-rate-limiting/status` - Get detailed system status
- `/adaptive-rate-limiting/user-stats` - Get user rate limit stats
- `/adaptive-rate-limiting/admin/system-status` - Admin system status
- `/adaptive-rate-limiting/admin/load-history` - Historical load data
- `/adaptive-rate-limiting/admin/adaptive-limits` - Current adaptive limits

## How It Works

### Load Calculation

```
Load = (CPU Usage × 0.4) + (Memory Usage × 0.4) + (Queued Requests × 0.2)
```

### Adaptive Multiplier

- **Load < 30%**: Multiplier = 1.0 (normal limits)
- **Load 30-60%**: Multiplier = 0.75 (75% of normal)
- **Load 60-80%**: Multiplier = 0.5 (50% of normal)
- **Load > 80%**: Multiplier = 0.25 (25% of normal)

### Example

If base limit is 1000 requests/minute:

- Normal load: 1000 requests/minute
- High load (70%): 500 requests/minute
- Critical load (85%): 250 requests/minute

## Configuration

```javascript
const limiter = new AdaptiveRateLimiter({
  // Base rate limits
  baseWindowMs: 15 * 60 * 1000,      // 15 minutes
  baseMaxRequests: 1000,              // requests per window
  baseBurstWindowMs: 60 * 1000,       // 1 minute
  baseBurstRequests: 100,             // requests per burst window

  // System load monitoring
  enableAdaptiveAdjustment: true,
  sampleIntervalMs: 5000,             // 5 seconds
  historySize: 60,                    // 5 minutes of history

  // Headers
  includeHeaders: true,
});
```

## Response Headers

When adaptive rate limiting is active, responses include:

- `X-RateLimit-Limit` - Current rate limit
- `X-RateLimit-Remaining` - Requests remaining
- `X-RateLimit-Reset` - When limit resets
- `X-RateLimit-Adaptive` - "true" if adaptive
- `X-RateLimit-Adaptive-Multiplier` - Current multiplier (e.g., "0.5")

## API Endpoints

### Get Current Metrics

```bash
GET /adaptive-rate-limiting/metrics
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "timestamp": "2024-01-19T10:30:00Z",
    "metrics": {
      "cpuUsage": "45.23",
      "memoryUsage": "62.15",
      "activeRequests": 12,
      "queuedRequests": 3,
      "loadPercentage": "56.79",
      "loadLevel": "medium",
      "adaptiveMultiplier": "0.75"
    }
  }
}
```

### Get System Status

```bash
GET /adaptive-rate-limiting/status
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "timestamp": "2024-01-19T10:30:00Z",
    "status": {
      "current": { ... },
      "average": { ... },
      "requests": { ... },
      "adaptive": { ... },
      "system": { ... }
    }
  }
}
```

### Get User Stats

```bash
GET /adaptive-rate-limiting/user-stats
Authorization: Bearer <token>

Response:
{
  "success": true,
  "data": {
    "timestamp": "2024-01-19T10:30:00Z",
    "userId": "user123",
    "stats": {
      "windowRequests": 45,
      "burstRequests": 12,
      "concurrentRequests": 2,
      "totalRequests": 150,
      "blockedRequests": 0
    }
  }
}
```

### Admin: Get System Status

```bash
GET /adaptive-rate-limiting/admin/system-status
Authorization: Bearer <admin-token>

Response: Detailed system status with all metrics
```

### Admin: Get Load History

```bash
GET /adaptive-rate-limiting/admin/load-history
Authorization: Bearer <admin-token>

Response: Historical load data for the past 5 minutes
```

### Admin: Get Adaptive Limits

```bash
GET /adaptive-rate-limiting/admin/adaptive-limits
Authorization: Bearer <admin-token>

Response:
{
  "success": true,
  "data": {
    "timestamp": "2024-01-19T10:30:00Z",
    "adaptiveLimits": {
      "baseMaxRequests": 1000,
      "adaptiveMaxRequests": 500,
      "baseBurstRequests": 100,
      "adaptiveBurstRequests": 50,
      "multiplier": "0.50"
    },
    "systemMetrics": { ... }
  }
}
```

## Monitoring

### Key Metrics to Monitor

1. **Adaptive Multiplier** - Should be 1.0 under normal load
2. **System Load** - Should stay below 60%
3. **Active Requests** - Should not exceed concurrent limit
4. **Queued Requests** - Should be minimal
5. **CPU Usage** - Should stay below 70%
6. **Memory Usage** - Should stay below 75%

### Alerts to Set Up

- Alert when load > 80% (critical)
- Alert when multiplier < 0.5 (high load)
- Alert when queued requests > 100
- Alert when CPU > 90%
- Alert when memory > 90%

## Testing

Run tests:

```bash
npm test -- adaptive-rate-limiting.test.js
```

Test scenarios covered:

- System metrics collection
- Load calculation
- Adaptive multiplier adjustment
- Rate limit enforcement
- Multiple user handling
- Load recovery
- Critical load scenarios

## Integration

### In Middleware Pipeline

```javascript
import { createAdaptiveRateLimitMiddleware } from './middleware/adaptive-rate-limiter.js';

app.use(createAdaptiveRateLimitMiddleware({
  baseMaxRequests: 1000,
  baseBurstRequests: 100,
  enableAdaptiveAdjustment: true,
}));
```

### In Routes

```javascript
import adaptiveRateLimitingRoutes from './routes/adaptive-rate-limiting.js';

app.use('/api/adaptive-rate-limiting', adaptiveRateLimitingRoutes);
```

## Performance Impact

- **CPU Overhead**: ~1-2% (minimal)
- **Memory Overhead**: ~5-10 MB (for history and tracking)
- **Sampling Interval**: 5 seconds (configurable)
- **Cleanup Interval**: 5 minutes

## Troubleshooting

### Multiplier Not Changing

- Check if `enableAdaptiveAdjustment` is true
- Verify system load is actually high
- Check cooldown period (10 seconds between adjustments)

### Limits Too Restrictive

- Increase `baseMaxRequests` or `baseBurstRequests`
- Adjust load thresholds in SystemLoadMonitor
- Check if system is actually under load

### Limits Too Permissive

- Decrease `baseMaxRequests` or `baseBurstRequests`
- Lower load thresholds
- Increase sampling frequency

## Best Practices

1. **Monitor Regularly** - Check metrics endpoint frequently
2. **Set Alerts** - Alert on critical load conditions
3. **Tune Thresholds** - Adjust based on your system capacity
4. **Test Under Load** - Verify behavior with load testing
5. **Document Changes** - Track any configuration changes
6. **Review History** - Use load history to identify patterns

## Related Tasks

- Task 30: Per-user rate limiting
- Task 31: Per-IP rate limiting
- Task 32: Request queuing
- Task 33: Quota management
- Task 34: Rate limit exemptions
- Task 35: Rate limit violation logging
- Task 37: Rate limit metrics and dashboards
