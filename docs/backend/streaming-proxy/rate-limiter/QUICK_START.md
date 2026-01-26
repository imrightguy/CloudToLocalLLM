# Rate Limiter Quick Start Guide

Get started with rate limiting in 5 minutes.

## Installation

The rate limiter is part of the streaming-proxy service. No additional installation required.

## Basic Usage

### 1. Add Middleware to Express App

```typescript
import express from 'express';
import { rateLimitMiddleware } from './rate-limiter';

const app = express();

// Apply rate limiting to all routes
app.use(rateLimitMiddleware());

// Your routes
app.post('/api/tunnel/forward', async (req, res) => {
  res.json({ success: true });
});

app.listen(3000);
```

### 2. Configure User Tiers

```typescript
import { RateLimitMiddleware } from './rate-limiter';
import { UserTier } from '../interfaces/auth-middleware';

const middleware = new RateLimitMiddleware();

// Set user tier after authentication
app.use((req, res, next) => {
  if (req.user) {
    middleware.setUserTier(req.user.id, req.user.tier);
  }
  next();
});

app.use(middleware.middleware());
```

### 3. Handle Rate Limit Errors

```typescript
app.use((err, req, res, next) => {
  if (res.statusCode === 429) {
    res.json({
      error: 'Rate limit exceeded',
      message: 'Please slow down your requests',
      retryAfter: res.getHeader('Retry-After'),
    });
  } else {
    next(err);
  }
});
```

## Common Scenarios

### Scenario 1: Different Limits for Different Routes

```typescript
import { rateLimitMiddleware } from './rate-limiter';

// Strict limits for expensive operations
app.post('/api/tunnel/forward',
  rateLimitMiddleware({
    enableUserLimits: true,
    enableIpLimits: true,
  }),
  forwardHandler
);

// Relaxed limits for status checks
app.get('/api/tunnel/status',
  rateLimitMiddleware({
    enableUserLimits: false,
    enableIpLimits: true,
  }),
  statusHandler
);
```

### Scenario 2: Block Abusive IPs

```typescript
import { RateLimitMiddleware } from './rate-limiter';

const middleware = new RateLimitMiddleware();

// Block an IP manually
middleware.blockIp('192.168.1.100', 'Abuse detected');

// Check blocked IPs
const blockedIps = middleware.getBlockedIps();
console.log('Blocked IPs:', blockedIps);

// Unblock an IP
middleware.unblockIp('192.168.1.100');
```

### Scenario 3: Monitor Rate Limiting

```typescript
import { RateLimitMiddleware } from './rate-limiter';

const middleware = new RateLimitMiddleware();

// Get statistics
app.get('/admin/rate-limit-stats', (req, res) => {
  const stats = middleware.getStats();
  res.json(stats);
});

// Check for DDoS
setInterval(async () => {
  const isDDoS = await middleware.checkDDoS();
  if (isDDoS) {
    console.log('DDoS attack detected!');
  }
}, 60000);
```

### Scenario 4: Custom User Limits

```typescript
import { PerUserRateLimiter } from './rate-limiter';

const limiter = new PerUserRateLimiter();

// Set custom limit for VIP user
limiter.setCustomUserLimit('vip-user-123', {
  requestsPerMinute: 2000,
  maxConcurrentConnections: 20,
  maxQueueSize: 1000,
});
```

## Testing Your Setup

### Test Rate Limiting

```bash
# Make multiple requests quickly
for i in {1..100}; do
  curl http://localhost:3000/api/test
done

# You should see 429 responses after the limit
```

### Test with Different Users

```bash
# Free tier user (60 req/min)
curl -H "Authorization: Bearer <free-user-token>" \
  http://localhost:3000/api/test

# Premium tier user (300 req/min)
curl -H "Authorization: Bearer <premium-user-token>" \
  http://localhost:3000/api/test
```

## Configuration

### Default Tier Limits

```typescript
FREE: {
  requestsPerMinute: 60,
  maxConcurrentConnections: 1,
  maxQueueSize: 50,
}

PREMIUM: {
  requestsPerMinute: 300,
  maxConcurrentConnections: 3,
  maxQueueSize: 200,
}

ENTERPRISE: {
  requestsPerMinute: 1000,
  maxConcurrentConnections: 10,
  maxQueueSize: 500,
}
```

### Environment Variables

```bash
# .env
RATE_LIMIT_ENABLED=true
RATE_LIMIT_FREE_TIER=60
RATE_LIMIT_PREMIUM_TIER=300
RATE_LIMIT_ENTERPRISE_TIER=1000
IP_RATE_LIMIT_ENABLED=true
IP_RATE_LIMIT_DEFAULT=200
DDOS_PROTECTION_ENABLED=true
```

## Monitoring

### Expose Metrics Endpoint

```typescript
app.get('/metrics', (req, res) => {
  const stats = middleware.getStats();
  
  res.json({
    users: {
      total: stats.user.totalUsers,
      violations: stats.user.recentViolations,
    },
    ips: {
      total: stats.ip.totalIps,
      blocked: stats.ip.blockedIps,
      suspicious: stats.ip.suspiciousIps,
    },
    ddos: stats.ip.ddosDetection,
  });
});
```

### View Statistics

```bash
curl http://localhost:3000/metrics
```

## Troubleshooting

### Issue: Users Getting Blocked Incorrectly

**Solution**: Check tier limits and increase if needed

```typescript
middleware.setUserTier(userId, UserTier.PREMIUM);
```

### Issue: High Memory Usage

**Solution**: Enable periodic cleanup

```typescript
middleware.startCleanupTask(600000); // 10 minutes
```

### Issue: DDoS False Alarms

**Solution**: Adjust detection thresholds in `per-ip-rate-limiter.ts`

## Next Steps

- Read the [full documentation](./README.md)
- Review [authentication middleware](../middleware/README.md)
- Check [requirements](../../../../.kiro/specs/ssh-websocket-tunnel-enhancement/requirements.md)
- See [design document](../../../../.kiro/specs/ssh-websocket-tunnel-enhancement/design.md)

## Support

For issues or questions:

1. Check the [README](./README.md)
2. Review the [requirements](../../../../.kiro/specs/ssh-websocket-tunnel-enhancement/requirements.md)
3. Check existing tests for examples
