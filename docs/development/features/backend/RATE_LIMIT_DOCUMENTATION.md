# Rate Limiting Documentation

## Overview

The CloudToLocalLLM API implements comprehensive rate limiting to protect the service from abuse and ensure fair resource allocation across all users. Rate limiting is applied at multiple levels: per-user, per-IP, and per-endpoint.

**Requirement: 12.7** - THE API SHALL implement API rate limit documentation

## Rate Limit Policies by User Tier

### Free Tier

- **Requests per minute**: 100
- **Requests per hour**: 5,000
- **Burst size**: 10 concurrent requests
- **Concurrent connections**: 5
- **Exemptions**: None

### Premium Tier

- **Requests per minute**: 500
- **Requests per hour**: 30,000
- **Burst size**: 50 concurrent requests
- **Concurrent connections**: 25
- **Exemptions**: Health check endpoints

### Enterprise Tier

- **Requests per minute**: 2,000
- **Requests per hour**: 120,000
- **Burst size**: 200 concurrent requests
- **Concurrent connections**: 100
- **Exemptions**: Health check endpoints, admin endpoints

## Rate Limit Types

### 1. Per-User Rate Limiting

Applied to authenticated requests based on user tier.

**Headers:**

- `X-RateLimit-Limit`: Maximum requests in current window
- `X-RateLimit-Remaining`: Remaining requests in current window
- `X-RateLimit-Reset`: Unix timestamp when limit resets

**Example Response Headers:**

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1699564800
```

### 2. Per-IP Rate Limiting

Applied to all requests (authenticated or not) to prevent DDoS attacks.

**Default limits:**

- 1,000 requests per minute per IP
- 50,000 requests per hour per IP

**Bypass:**

- Requests from authenticated users use per-user limits instead
- Whitelisted IPs (admin only)

### 3. Burst Rate Limiting

Prevents sudden spikes in traffic from a single user or IP.

**Mechanism:**

- Tracks concurrent requests
- Blocks requests exceeding burst size
- Queues requests when approaching limit

**Response:**

```json
{
  "error": {
    "code": "RATE_LIMIT_BURST",
    "message": "Too many concurrent requests",
    "statusCode": 429,
    "suggestion": "Wait for some requests to complete before retrying"
  }
}
```

### 4. Concurrent Connection Limiting

Limits the number of simultaneous connections per user.

**Enforcement:**

- Tracked per user ID
- Includes WebSocket connections
- Applies to all connection types

## Rate Limit Response Codes

### 429 Too Many Requests

Returned when rate limit is exceeded.

**Response Body:**

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Please try again later.",
    "category": "rate_limit",
    "statusCode": 429,
    "correlationId": "req-12345",
    "suggestion": "Wait 60 seconds before retrying"
  }
}
```

**Response Headers:**

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1699564860
Retry-After: 60
```

## Best Practices

### 1. Check Rate Limit Headers

Always check the `X-RateLimit-*` headers in responses to understand your current usage:

```javascript
const response = await fetch('https://api.cloudtolocalllm.online/v2/users/me');
const limit = response.headers.get('X-RateLimit-Limit');
const remaining = response.headers.get('X-RateLimit-Remaining');
const reset = response.headers.get('X-RateLimit-Reset');

console.log(`Requests remaining: ${remaining}/${limit}`);
console.log(`Resets at: ${new Date(reset * 1000).toISOString()}`);
```

### 2. Implement Exponential Backoff

When rate limited, use exponential backoff with jitter:

```javascript
async function makeRequestWithRetry(url, maxRetries = 3) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await fetch(url);
      
      if (response.status === 429) {
        const retryAfter = response.headers.get('Retry-After');
        const delay = parseInt(retryAfter) * 1000 + Math.random() * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      
      return response;
    } catch (error) {
      if (attempt === maxRetries - 1) throw error;
      const delay = Math.pow(2, attempt) * 1000 + Math.random() * 1000;
      await new Promise(resolve => setTimeout(resolve, delay));
    }
  }
}
```

### 3. Batch Requests

Combine multiple operations into single requests when possible:

```javascript
// ❌ Bad: 100 individual requests
for (let i = 0; i < 100; i++) {
  await fetch(`/v2/tunnels/${tunnelIds[i]}`);
}

// ✅ Good: Single batch request
const response = await fetch('/v2/tunnels/batch', {
  method: 'POST',
  body: JSON.stringify({ ids: tunnelIds })
});
```

### 4. Cache Responses

Use caching to reduce API calls:

```javascript
const cache = new Map();
const CACHE_TTL = 60000; // 1 minute

async function getCachedUser(userId) {
  const cached = cache.get(userId);
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return cached.data;
  }
  
  const response = await fetch(`/v2/users/${userId}`);
  const data = await response.json();
  cache.set(userId, { data, timestamp: Date.now() });
  return data;
}
```

### 5. Monitor Your Usage

Regularly check your rate limit status:

```javascript
async function checkRateLimitStatus() {
  const response = await fetch('/v2/rate-limit-metrics/summary', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  const status = await response.json();
  
  if (status.data.remaining < 10) {
    console.warn('Approaching rate limit!');
  }
}
```

## Rate Limit Exemptions

### Critical Operations

The following operations are exempt from rate limiting:

- Health checks (`GET /health`)
- Authentication endpoints (`POST /auth/login`, `POST /auth/refresh`)
- Emergency recovery endpoints (`POST /error-recovery/manual-intervention`)

### Admin Operations

Admin users have exemptions for:

- Admin dashboard endpoints
- User management endpoints
- System configuration endpoints

### Service-to-Service Communication

API key authenticated requests have higher limits:

- 10,000 requests per minute
- 500,000 requests per hour

## Upgrading Your Tier

If you're consistently hitting rate limits, consider upgrading:

### Free → Premium

- 5x increase in requests per minute (100 → 500)
- 6x increase in requests per hour (5,000 → 30,000)
- 5x increase in burst size (10 → 50)
- 5x increase in concurrent connections (5 → 25)

### Premium → Enterprise

- 4x increase in requests per minute (500 → 2,000)
- 4x increase in requests per hour (30,000 → 120,000)
- 4x increase in burst size (50 → 200)
- 4x increase in concurrent connections (25 → 100)

**Upgrade endpoint:**

```
POST /v2/users/me/tier/upgrade
Content-Type: application/json

{
  "tier": "premium"
}
```

## Rate Limit Metrics

### Monitoring Your Usage

Get your current rate limit metrics:

```bash
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/summary
```

**Response:**

```json
{
  "success": true,
  "data": {
    "timestamp": "2024-11-10T12:00:00Z",
    "topViolators": [],
    "topViolatingIps": [],
    "totalViolators": 0,
    "totalViolatingIps": 0
  }
}
```

### Admin Metrics

Admins can view top violators:

```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/top-violators?limit=10
```

## Common Issues and Solutions

### Issue: "Rate limit exceeded" on first request

**Cause:** Your tier has very low limits or you're using a shared IP.

**Solution:**

1. Check your user tier: `GET /v2/users/me`
2. Consider upgrading to a higher tier
3. If using shared IP, authenticate with your API key

### Issue: Burst requests are being queued

**Cause:** You're sending too many concurrent requests.

**Solution:**

1. Reduce concurrent request count
2. Implement request queuing on your client
3. Upgrade to a higher tier for more burst capacity

### Issue: Rate limit resets at unexpected times

**Cause:** Rate limits use sliding windows, not fixed times.

**Solution:**

- Rate limits reset based on when your first request in the window was made
- Check `X-RateLimit-Reset` header for exact reset time
- Plan requests accordingly

## API Endpoints for Rate Limiting

### Get Rate Limit Summary

```
GET /v2/rate-limit-metrics/summary
Authorization: Bearer {token}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "timestamp": "2024-11-10T12:00:00Z",
    "topViolators": [],
    "topViolatingIps": [],
    "totalViolators": 0,
    "totalViolatingIps": 0
  }
}
```

### Get Top Violators (Admin Only)

```
GET /v2/rate-limit-metrics/top-violators?limit=10
Authorization: Bearer {admin_token}
```

### Get Top Violating IPs (Admin Only)

```
GET /v2/rate-limit-metrics/top-ips?limit=10
Authorization: Bearer {admin_token}
```

### Get Dashboard Data (Admin Only)

```
GET /v2/rate-limit-metrics/dashboard-data
Authorization: Bearer {admin_token}
```

## Rate Limiting in Different Scenarios

### Web Application

For web applications, implement client-side rate limit handling:

```javascript
class APIClient {
  constructor(token) {
    this.token = token;
    this.requestQueue = [];
    this.isRateLimited = false;
  }

  async request(endpoint, options = {}) {
    if (this.isRateLimited) {
      return new Promise((resolve) => {
        this.requestQueue.push(() => this.request(endpoint, options).then(resolve));
      });
    }

    const response = await fetch(endpoint, {
      ...options,
      headers: {
        'Authorization': `Bearer ${this.token}`,
        ...options.headers
      }
    });

    if (response.status === 429) {
      this.isRateLimited = true;
      const retryAfter = parseInt(response.headers.get('Retry-After')) * 1000;
      
      setTimeout(() => {
        this.isRateLimited = false;
        this.requestQueue.forEach(fn => fn());
        this.requestQueue = [];
      }, retryAfter);

      return this.request(endpoint, options);
    }

    return response;
  }
}
```

### Mobile Application

For mobile apps, use aggressive caching and batch requests:

```javascript
// Batch tunnel status checks
async function checkMultipleTunnelStatus(tunnelIds) {
  const response = await fetch('/v2/tunnels/batch-status', {
    method: 'POST',
    body: JSON.stringify({ ids: tunnelIds })
  });
  return response.json();
}

// Cache user profile for 5 minutes
const userProfileCache = {
  data: null,
  timestamp: null,
  TTL: 5 * 60 * 1000
};

async function getUserProfile() {
  if (userProfileCache.data && 
      Date.now() - userProfileCache.timestamp < userProfileCache.TTL) {
    return userProfileCache.data;
  }
  
  const response = await fetch('/v2/users/me');
  const data = await response.json();
  userProfileCache.data = data;
  userProfileCache.timestamp = Date.now();
  return data;
}
```

### Server-to-Server Communication

For service-to-service communication, use API keys with higher limits:

```javascript
async function makeServiceRequest(endpoint, options = {}) {
  const response = await fetch(endpoint, {
    ...options,
    headers: {
      'X-API-Key': process.env.API_KEY,
      ...options.headers
    }
  });

  if (response.status === 429) {
    // Service-to-service should rarely hit limits
    // Log and alert if this happens
    console.error('Service rate limited:', endpoint);
  }

  return response;
}
```

## Rate Limiting Headers Reference

| Header | Description | Example |
|--------|-------------|---------|
| `X-RateLimit-Limit` | Max requests in current window | `100` |
| `X-RateLimit-Remaining` | Requests remaining in window | `87` |
| `X-RateLimit-Reset` | Unix timestamp of window reset | `1699564800` |
| `Retry-After` | Seconds to wait before retrying | `60` |

## Troubleshooting

### Check Your Current Limits

```bash
# Get your user info including tier
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/users/me

# Check rate limit metrics
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/summary
```

### Monitor Rate Limit Violations

```bash
# Admin: Get top violators
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/top-violators

# Admin: Get top violating IPs
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/top-ips
```

## Support

For rate limiting issues or questions:

1. Check this documentation
2. Review your rate limit metrics
3. Consider upgrading your tier
4. Contact support with your correlation ID from error responses

---

**Last Updated:** November 2024
**API Version:** 2.0
**Requirement:** 12.7 - API rate limit documentation
