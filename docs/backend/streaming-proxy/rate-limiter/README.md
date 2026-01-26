# Rate Limiter Module

Comprehensive rate limiting implementation for the SSH WebSocket Tunnel system.

## Overview

This module provides production-ready rate limiting with:

- **Token Bucket Algorithm**: Smooth rate limiting with burst support
- **Per-User Limits**: Tier-based limits (Free, Premium, Enterprise)
- **Per-IP Limits**: DDoS protection and abuse prevention
- **Express Middleware**: Easy integration with existing routes
- **Automatic Blocking**: Auto-block abusive IPs
- **Monitoring**: Built-in statistics and violation tracking

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│              RateLimitMiddleware                        │
│  - Express integration                                  │
│  - Request interception                                 │
│  - Response headers                                     │
└────────────┬────────────────────────────┬───────────────┘
             │                            │
             ▼                            ▼
┌────────────────────────┐  ┌────────────────────────────┐
│  PerUserRateLimiter    │  │   PerIpRateLimiter         │
│  - Tier-based limits   │  │   - DDoS detection         │
│  - User tracking       │  │   - IP blocking            │
│  - Violation logging   │  │   - Suspicious IP tracking │
└────────────┬───────────┘  └────────────┬───────────────┘
             │                            │
             └────────────┬───────────────┘
                          ▼
              ┌───────────────────────┐
              │ TokenBucketRateLimiter│
              │ - Token bucket algo   │
              │ - Refill logic        │
              │ - Bucket management   │
              └───────────────────────┘
```

## Components

### 1. TokenBucketRateLimiter

Core rate limiting implementation using the token bucket algorithm.

**Features:**

- Smooth rate limiting with burst support
- Automatic token refill
- Per-user and per-IP buckets
- Violation tracking
- Configurable limits

**Usage:**

```typescript
import { TokenBucketRateLimiter } from './rate-limiter';

const limiter = new TokenBucketRateLimiter({
  requestsPerMinute: 100,
  maxConcurrentConnections: 3,
  maxQueueSize: 200,
});

// Check limit
const result = await limiter.checkLimit('user123', '192.168.1.1');
if (result.allowed) {
  // Process request
  limiter.recordRequest('user123', '192.168.1.1');
} else {
  // Return 429 with retry-after
  console.log(`Retry after ${result.retryAfter} seconds`);
}
```

### 2. PerUserRateLimiter

Manages rate limiting on a per-user basis with tier-based limits.

**Tier Limits:**

- **Free**: 60 requests/minute, 1 connection
- **Premium**: 300 requests/minute, 3 connections
- **Enterprise**: 1000 requests/minute, 10 connections

**Usage:**

```typescript
import { PerUserRateLimiter, DEFAULT_TIER_LIMITS } from './rate-limiter';
import { UserTier } from '../interfaces/auth-middleware';

const limiter = new PerUserRateLimiter();

// Set user tier
limiter.setUserTier('user123', UserTier.PREMIUM);

// Check limit
const result = await limiter.checkUserLimit('user123', '192.168.1.1');

// Get user info
const info = await limiter.getUserLimitInfo('user123', '192.168.1.1');
console.log(`Remaining: ${info.currentUsage.remaining}`);

// Get rate limit headers
const headers = limiter.getRateLimitHeaders(result, DEFAULT_TIER_LIMITS[UserTier.PREMIUM]);
```

### 3. PerIpRateLimiter

Implements DDoS protection by rate limiting requests per IP address.

**Features:**

- IP-based rate limiting
- Automatic suspicious IP detection
- Auto-blocking after threshold
- DDoS attack detection
- IP whitelist/blacklist

**Usage:**

```typescript
import { PerIpRateLimiter } from './rate-limiter';

const limiter = new PerIpRateLimiter();

// Check IP limit
const result = await limiter.checkIpLimit('192.168.1.1', 'user123');

// Block an IP
limiter.blockIp('192.168.1.100', 'Manual block - abuse detected');

// Check for DDoS
const ddos = limiter.detectDDoS();
if (ddos.isDDoS) {
  console.log(`DDoS detected: ${ddos.reason}`);
  await limiter.activateDDoSProtection();
}

// Get statistics
const stats = limiter.getStats();
console.log(`Blocked IPs: ${stats.blockedIps}`);
```

### 4. RateLimitMiddleware

Express middleware for easy integration with HTTP routes.

**Usage:**

```typescript
import express from 'express';
import { rateLimitMiddleware } from './rate-limiter';

const app = express();

// Apply to all routes
app.use(rateLimitMiddleware({
  enableUserLimits: true,
  enableIpLimits: true,
}));

// Apply to specific routes
app.post('/api/tunnel/forward', 
  rateLimitMiddleware(),
  async (req, res) => {
    // Handle request
  }
);

// Custom options
app.use('/api/admin', rateLimitMiddleware({
  enableUserLimits: true,
  enableIpLimits: false,
  skipSuccessfulRequests: false,
}));
```

## Configuration

### Environment Variables

```bash
# Rate Limiting
RATE_LIMIT_ENABLED=true
RATE_LIMIT_FREE_TIER=60
RATE_LIMIT_PREMIUM_TIER=300
RATE_LIMIT_ENTERPRISE_TIER=1000

# IP Rate Limiting
IP_RATE_LIMIT_ENABLED=true
IP_RATE_LIMIT_DEFAULT=200
IP_RATE_LIMIT_SUSPICIOUS=10

# DDoS Protection
DDOS_PROTECTION_ENABLED=true
DDOS_DETECTION_THRESHOLD=5000
DDOS_AUTO_BLOCK=true
```

### Programmatic Configuration

```typescript
import { 
  PerUserRateLimiter, 
  PerIpRateLimiter,
  DEFAULT_TIER_LIMITS 
} from './rate-limiter';
import { UserTier } from '../interfaces/auth-middleware';

// Customize tier limits
const customLimits = {
  ...DEFAULT_TIER_LIMITS,
  [UserTier.PREMIUM]: {
    requestsPerMinute: 500,
    maxConcurrentConnections: 5,
    maxQueueSize: 300,
  },
};

// Create limiter with custom limits
const userLimiter = new PerUserRateLimiter(customLimits[UserTier.FREE]);

// Set custom limit for specific user
userLimiter.setCustomUserLimit('vip-user', {
  requestsPerMinute: 2000,
  maxConcurrentConnections: 20,
  maxQueueSize: 1000,
});
```

## Monitoring

### Statistics

```typescript
import { RateLimitMiddleware } from './rate-limiter';

const middleware = new RateLimitMiddleware();

// Get statistics
const stats = middleware.getStats();

console.log('User Stats:', {
  totalUsers: stats.user.totalUsers,
  tierDistribution: stats.user.tierDistribution,
  recentViolations: stats.user.recentViolations,
});

console.log('IP Stats:', {
  totalIps: stats.ip.totalIps,
  blockedIps: stats.ip.blockedIps,
  suspiciousIps: stats.ip.suspiciousIps,
  ddosDetection: stats.ip.ddosDetection,
});
```

### Prometheus Metrics

```typescript
// Expose metrics endpoint
app.get('/metrics', (req, res) => {
  const stats = rateLimitMiddleware.getStats();
  
  const metrics = `
# HELP rate_limit_users_total Total number of users
# TYPE rate_limit_users_total gauge
rate_limit_users_total ${stats.user.totalUsers}

# HELP rate_limit_violations_total Total rate limit violations
# TYPE rate_limit_violations_total counter
rate_limit_violations_total ${stats.user.recentViolations}

# HELP rate_limit_blocked_ips Total blocked IP addresses
# TYPE rate_limit_blocked_ips gauge
rate_limit_blocked_ips ${stats.ip.blockedIps}

# HELP rate_limit_ddos_detected DDoS attack detected
# TYPE rate_limit_ddos_detected gauge
rate_limit_ddos_detected ${stats.ip.ddosDetection.isDDoS ? 1 : 0}
  `.trim();
  
  res.set('Content-Type', 'text/plain');
  res.send(metrics);
});
```

## Error Handling

### Rate Limit Exceeded Response

```json
{
  "error": "Too Many Requests",
  "message": "Rate limit exceeded. Please try again later.",
  "retryAfter": 30,
  "resetAt": "2024-01-15T10:30:00.000Z",
  "limitType": "user"
}
```

### Response Headers

```
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1705318200
Retry-After: 30
```

## Best Practices

### 1. Apply Rate Limiting Early

```typescript
// Apply rate limiting before authentication
app.use(rateLimitMiddleware());
app.use(authMiddleware());
```

### 2. Use Different Limits for Different Routes

```typescript
// Strict limits for expensive operations
app.post('/api/tunnel/forward', 
  rateLimitMiddleware({ 
    enableUserLimits: true,
    enableIpLimits: true 
  }),
  handler
);

// Relaxed limits for read operations
app.get('/api/tunnel/status',
  rateLimitMiddleware({
    enableUserLimits: false,
    enableIpLimits: true
  }),
  handler
);
```

### 3. Monitor and Alert

```typescript
// Check for DDoS attacks periodically
setInterval(async () => {
  const isDDoS = await middleware.checkDDoS();
  if (isDDoS) {
    // Send alert to monitoring system
    alerting.send('DDoS attack detected!');
  }
}, 60000);
```

### 4. Clean Up Periodically

```typescript
// Start cleanup task
const cleanupTask = middleware.startCleanupTask(3600000); // 1 hour

// Stop cleanup on shutdown
process.on('SIGTERM', () => {
  clearInterval(cleanupTask);
});
```

### 5. Handle Rate Limit Errors Gracefully

```typescript
app.use((err, req, res, next) => {
  if (err.statusCode === 429) {
    res.status(429).json({
      error: 'Rate limit exceeded',
      retryAfter: err.retryAfter,
      message: 'Please slow down your requests',
    });
  } else {
    next(err);
  }
});
```

## Testing

### Unit Tests

```typescript
import { TokenBucketRateLimiter } from './token-bucket-rate-limiter';

describe('TokenBucketRateLimiter', () => {
  it('should allow requests within limit', async () => {
    const limiter = new TokenBucketRateLimiter({
      requestsPerMinute: 60,
      maxConcurrentConnections: 3,
      maxQueueSize: 100,
    });

    const result = await limiter.checkLimit('user1', '127.0.0.1');
    expect(result.allowed).toBe(true);
  });

  it('should block requests exceeding limit', async () => {
    const limiter = new TokenBucketRateLimiter({
      requestsPerMinute: 2,
      maxConcurrentConnections: 1,
      maxQueueSize: 10,
    });

    // Consume all tokens
    await limiter.checkLimit('user1', '127.0.0.1');
    limiter.recordRequest('user1', '127.0.0.1');
    await limiter.checkLimit('user1', '127.0.0.1');
    limiter.recordRequest('user1', '127.0.0.1');

    // Should be blocked
    const result = await limiter.checkLimit('user1', '127.0.0.1');
    expect(result.allowed).toBe(false);
    expect(result.retryAfter).toBeGreaterThan(0);
  });
});
```

### Integration Tests

```typescript
import request from 'supertest';
import express from 'express';
import { rateLimitMiddleware } from './rate-limit-middleware';

describe('Rate Limit Middleware', () => {
  const app = express();
  app.use(rateLimitMiddleware());
  app.get('/test', (req, res) => res.json({ ok: true }));

  it('should return 429 after exceeding limit', async () => {
    // Make requests until limit is exceeded
    for (let i = 0; i < 100; i++) {
      await request(app).get('/test');
    }

    const response = await request(app).get('/test');
    expect(response.status).toBe(429);
    expect(response.body.error).toBe('Too Many Requests');
  });
});
```

## Troubleshooting

### High Memory Usage

If memory usage is high, increase cleanup frequency:

```typescript
middleware.startCleanupTask(600000); // 10 minutes
```

### False Positives

If legitimate users are being blocked:

1. Check tier limits
2. Review violation thresholds
3. Whitelist specific IPs
4. Increase limits for specific users

### DDoS False Alarms

Adjust DDoS detection thresholds:

```typescript
const limiter = new PerIpRateLimiter();

// Custom detection logic
const detection = limiter.detectDDoS(300000); // 5 minute window
```

## Requirements Mapping

- **Requirement 4.3**: Token bucket algorithm, per-user rate limiting
- **Requirement 4.8**: Tier-based limits, connection limits per user
- **Requirement 4.10**: Per-IP rate limiting, DDoS protection

## Related Documentation

- [Authentication Middleware](../middleware/README.md)
- [WebSocket Handler](../websocket/README.md)
- [Metrics Collection](../metrics/README.md)
