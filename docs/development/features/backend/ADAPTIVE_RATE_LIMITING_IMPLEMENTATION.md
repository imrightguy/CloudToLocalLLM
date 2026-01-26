# Adaptive Rate Limiting - Implementation Guide

## Overview

This guide explains how adaptive rate limiting has been implemented in the API backend. The system monitors system load and automatically adjusts rate limits to protect the system during high-load periods.

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    Express Application                       │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Adaptive Rate Limiting Middleware                   │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  • Checks rate limits per user                       │  │
│  │  • Applies adaptive multiplier                       │  │
│  │  • Records active/completed requests                 │  │
│  │  • Sets rate limit headers                           │  │
│  └──────────────────────────────────────────────────────┘  │
│                              │                                │
│                              ▼                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  System Load Monitor                                 │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  • Collects CPU metrics                              │  │
│  │  • Collects memory metrics                           │  │
│  │  • Tracks request queue depth                        │  │
│  │  • Calculates overall load percentage                │  │
│  │  • Adjusts adaptive multiplier                       │  │
│  │  • Maintains metrics history                         │  │
│  └──────────────────────────────────────────────────────┘  │
│                              │                                │
│                              ▼                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Monitoring Routes                                   │  │
│  ├──────────────────────────────────────────────────────┤  │
│  │  • GET /metrics - Current metrics                    │  │
│  │  • GET /status - System status                       │  │
│  │  • GET /user-stats - User statistics                 │  │
│  │  • GET /admin/system-status - Admin view             │  │
│  │  • GET /admin/load-history - Historical data         │  │
│  │  • GET /admin/adaptive-limits - Current limits       │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Implementation Details

### 1. System Load Monitoring

**File**: `services/system-load-monitor.js`

The SystemLoadMonitor class:

- Samples system metrics every 5 seconds (configurable)
- Tracks CPU usage using `process.cpuUsage()`
- Tracks memory usage using `process.memoryUsage()`
- Maintains a history of metrics (default: 60 samples = 5 minutes)
- Calculates overall load percentage using weighted formula
- Adjusts adaptive multiplier based on load level

**Load Calculation**:

```javascript
Load = (CPU × 0.4) + (Memory × 0.4) + (Queued Requests × 0.2)
```

**Multiplier Adjustment**:

- Load < 30%: multiplier = 1.0
- Load 30-60%: multiplier = 0.75
- Load 60-80%: multiplier = 0.5
- Load > 80%: multiplier = 0.25

### 2. Adaptive Rate Limiting

**File**: `middleware/adaptive-rate-limiter.js`

The AdaptiveRateLimiter class:

- Integrates SystemLoadMonitor with rate limiting logic
- Tracks per-user request counts
- Applies adaptive multiplier to base limits
- Enforces burst and window rate limits
- Provides detailed rate limit information

**Rate Limit Enforcement**:

1. Check if request count exceeds adaptive burst limit
2. Check if request count exceeds adaptive window limit
3. If allowed, increment request counter
4. Set rate limit headers in response

**Adaptive Limits**:

```javascript
adaptiveMaxRequests = baseMaxRequests × multiplier
adaptiveBurstRequests = baseBurstRequests × multiplier
```

### 3. Monitoring Routes

**File**: `routes/adaptive-rate-limiting.js`

Provides endpoints for monitoring and managing adaptive rate limiting:

**Public Endpoints** (authenticated users):

- `GET /metrics` - Current system metrics
- `GET /status` - Detailed system status
- `GET /user-stats` - User's rate limit statistics

**Admin Endpoints** (admin role required):

- `GET /admin/system-status` - Full system status
- `GET /admin/load-history` - Historical load data
- `GET /admin/adaptive-limits` - Current adaptive limits

## Integration Points

### 1. Middleware Pipeline

Add to `middleware/pipeline.js`:

```javascript
import { createAdaptiveRateLimitMiddleware } from './adaptive-rate-limiter.js';

// In setupMiddlewarePipeline function:
const adaptiveRateLimitMiddleware = createAdaptiveRateLimitMiddleware({
  baseMaxRequests: 1000,
  baseBurstRequests: 100,
  enableAdaptiveAdjustment: true,
});

app.use(adaptiveRateLimitMiddleware);
```

### 2. Route Registration

Add to `server.js`:

```javascript
import adaptiveRateLimitingRoutes from './routes/adaptive-rate-limiting.js';

// Register routes
app.use('/api/adaptive-rate-limiting', adaptiveRateLimitingRoutes);
```

### 3. Request Context

The middleware stores the rate limiter in the request:

```javascript
req.adaptiveRateLimiter // Access in routes
```

## Data Flow

### Request Processing

```
1. Request arrives
   ↓
2. Middleware extracts user ID
   ↓
3. Get adaptive limits from SystemLoadMonitor
   ↓
4. Check if user has exceeded limits
   ├─ If exceeded: Return 429 with retry info
   └─ If allowed: Continue to next middleware
   ↓
5. Record active request in SystemLoadMonitor
   ↓
6. Process request
   ↓
7. On response completion: Record completed request
```

### Metrics Collection

```
Every 5 seconds:
1. Collect CPU usage
2. Collect memory usage
3. Get active/queued request counts
4. Calculate overall load percentage
5. Determine load level
6. Update metrics history
7. Check if adjustment needed
8. Update adaptive multiplier if needed
```

## Configuration

### Default Configuration

```javascript
{
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
}
```

### Customization

```javascript
const limiter = new AdaptiveRateLimiter({
  baseMaxRequests: 2000,              // Increase base limit
  baseBurstRequests: 200,
  sampleIntervalMs: 10000,            // Sample every 10 seconds
  historySize: 30,                    // Keep 5 minutes of history
  enableAdaptiveAdjustment: false,    // Disable adaptive adjustment
});
```

## Testing

### Unit Tests

File: `test/api-backend/adaptive-rate-limiting.test.js`

Test coverage:

- SystemLoadMonitor initialization
- Metrics collection
- Load calculation
- Adaptive multiplier adjustment
- Rate limit enforcement
- Multiple user handling
- Load recovery scenarios
- Critical load scenarios

### Running Tests

```bash
npm test -- adaptive-rate-limiting.test.js
```

### Test Scenarios

1. **Normal Load**: Verify standard rate limits apply
2. **High Load**: Verify limits are reduced
3. **Critical Load**: Verify limits are significantly reduced
4. **Recovery**: Verify limits return to normal
5. **Multiple Users**: Verify independent tracking
6. **Burst Limit**: Verify burst protection
7. **Window Limit**: Verify window protection

## Monitoring and Observability

### Metrics Exposed

**Current Metrics**:

- CPU usage (%)
- Memory usage (%)
- Active requests
- Queued requests
- Load percentage (0-100)
- Load level (low/medium/high/critical)
- Adaptive multiplier

**Historical Metrics**:

- Metrics history (configurable size)
- Average metrics over history
- Trend analysis

### Logging

The system logs:

- Initialization with configuration
- Metrics collection (debug level)
- Adaptive multiplier adjustments (info level)
- Rate limit violations (security level)
- Errors (error level)

### Response Headers

Responses include adaptive rate limiting information:

```
X-RateLimit-Limit: 500
X-RateLimit-Remaining: 450
X-RateLimit-Reset: 2024-01-19T10:45:00Z
X-RateLimit-Adaptive: true
X-RateLimit-Adaptive-Multiplier: 0.50
```

## Performance Considerations

### CPU Overhead

- Metrics collection: ~1-2% CPU
- Rate limit checking: <1% CPU
- Total overhead: ~1-2% CPU

### Memory Overhead

- Per-user tracker: ~1 KB
- Metrics history: ~5-10 MB (for 60 samples)
- Total overhead: ~5-10 MB

### Sampling Interval

- Default: 5 seconds
- Adjustable: 1-60 seconds
- Trade-off: Accuracy vs. CPU usage

## Troubleshooting

### Issue: Multiplier Not Changing

**Cause**: Cooldown period between adjustments

**Solution**:

- Wait 10 seconds between adjustments
- Check if system load is actually high
- Verify `enableAdaptiveAdjustment` is true

### Issue: Limits Too Restrictive

**Cause**: Base limits too low or thresholds too aggressive

**Solution**:

- Increase `baseMaxRequests`
- Adjust load thresholds
- Increase sampling interval

### Issue: Limits Too Permissive

**Cause**: Base limits too high or thresholds too lenient

**Solution**:

- Decrease `baseMaxRequests`
- Lower load thresholds
- Decrease sampling interval

## Best Practices

1. **Monitor Regularly**
   - Check metrics endpoint frequently
   - Set up dashboards for visualization

2. **Set Alerts**
   - Alert on critical load (>80%)
   - Alert on high multiplier reduction (<0.5)
   - Alert on queue buildup

3. **Tune Thresholds**
   - Start with defaults
   - Adjust based on your system capacity
   - Test under realistic load

4. **Test Under Load**
   - Use load testing tools
   - Verify behavior at different load levels
   - Validate recovery from high load

5. **Document Changes**
   - Track configuration changes
   - Document reasons for adjustments
   - Keep audit trail

## Future Enhancements

1. **Per-Tier Adaptive Limits**
   - Different multipliers for different user tiers
   - Premium users get higher limits

2. **Predictive Adjustment**
   - Use historical data to predict load
   - Proactive limit adjustment

3. **Custom Load Metrics**
   - Add database query time
   - Add external service latency
   - Add custom application metrics

4. **Machine Learning**
   - Learn optimal multipliers
   - Predict load patterns
   - Automatic threshold tuning

## Related Documentation

- [Rate Limiting Overview](./RATE_LIMIT_VIOLATIONS_IMPLEMENTATION.md)
- [Request Queuing](./REQUEST_QUEUING_IMPLEMENTATION.md)
- [Quota Management](./QUOTA_MANAGEMENT_IMPLEMENTATION.md)
- [Rate Limit Exemptions](./RATE_LIMIT_EXEMPTIONS_IMPLEMENTATION.md)
