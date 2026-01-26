# Rate Limiting by User Tier

## Overview

CloudToLocalLLM implements tier-based rate limiting to ensure fair resource allocation and protect the service from abuse. Each tier has different rate limits tailored to different use cases.

**Requirement:** 12.7 - THE API SHALL implement API rate limit documentation

## Free Tier

### Limits

- **Requests per minute:** 100
- **Requests per hour:** 5,000
- **Burst size:** 10 concurrent requests
- **Concurrent connections:** 5
- **Exemptions:** None

### Best For

- Personal projects
- Learning and experimentation
- Low-traffic applications
- Testing and development

### Example Usage Pattern

```javascript
// Free tier: 100 requests/minute = ~1.67 requests/second
// Plan requests accordingly

async function freeUserWorkflow() {
  // ✅ Good: Spread requests over time
  for (let i = 0; i < 100; i++) {
    await makeRequest();
    await delay(600); // 600ms between requests = ~1.67 req/sec
  }
  
  // ❌ Bad: Burst all requests at once
  // const promises = [];
  // for (let i = 0; i < 100; i++) {
  //   promises.push(makeRequest());
  // }
  // await Promise.all(promises); // Will hit rate limit!
}
```

### Upgrade Triggers

Consider upgrading to Premium if you:

- Consistently hit rate limits
- Need more concurrent connections
- Have production applications
- Need higher throughput

### Upgrade Path

```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tier": "premium"}' \
  https://api.cloudtolocalllm.online/v2/users/me/tier/upgrade
```

## Premium Tier

### Limits

- **Requests per minute:** 500
- **Requests per hour:** 30,000
- **Burst size:** 50 concurrent requests
- **Concurrent connections:** 25
- **Exemptions:** Health check endpoints

### Best For

- Production web applications
- Mobile applications
- Small to medium businesses
- Regular API consumers

### Comparison to Free

| Metric | Free | Premium | Increase |
|--------|------|---------|----------|
| Requests/minute | 100 | 500 | 5x |
| Requests/hour | 5,000 | 30,000 | 6x |
| Burst size | 10 | 50 | 5x |
| Concurrent connections | 5 | 25 | 5x |

### Example Usage Pattern

```javascript
// Premium tier: 500 requests/minute = ~8.33 requests/second
// Can handle more concurrent requests

async function premiumUserWorkflow() {
  // ✅ Good: Can handle more concurrency
  const batchSize = 25; // Premium burst size
  
  for (let i = 0; i < 500; i += batchSize) {
    const batch = [];
    for (let j = 0; j < batchSize && i + j < 500; j++) {
      batch.push(makeRequest());
    }
    await Promise.all(batch);
    await delay(100); // Small delay between batches
  }
}

// ✅ Good: Can maintain higher throughput
async function premiumHighThroughput() {
  const concurrentRequests = 20; // Within burst limit
  const queue = [];
  
  for (let i = 0; i < 30000; i++) {
    queue.push(makeRequest());
    
    if (queue.length >= concurrentRequests) {
      await Promise.race(queue);
      queue.splice(queue.findIndex(p => p.settled), 1);
    }
  }
  
  await Promise.all(queue);
}
```

### Health Check Exemption

Premium users get exemption for health check endpoints:

```bash
# These don't count against rate limit for Premium users
curl https://api.cloudtolocalllm.online/health
curl https://api.cloudtolocalllm.online/v2/health
```

### Upgrade Triggers

Consider upgrading to Enterprise if you:

- Consistently hit Premium limits
- Need guaranteed high throughput
- Have mission-critical applications
- Need dedicated support

## Enterprise Tier

### Limits

- **Requests per minute:** 2,000
- **Requests per hour:** 120,000
- **Burst size:** 200 concurrent requests
- **Concurrent connections:** 100
- **Exemptions:** Health check endpoints, admin endpoints

### Best For

- Large-scale applications
- High-traffic services
- Enterprise deployments
- Mission-critical systems

### Comparison to Premium

| Metric | Premium | Enterprise | Increase |
|--------|---------|-----------|----------|
| Requests/minute | 500 | 2,000 | 4x |
| Requests/hour | 30,000 | 120,000 | 4x |
| Burst size | 50 | 200 | 4x |
| Concurrent connections | 25 | 100 | 4x |

### Example Usage Pattern

```javascript
// Enterprise tier: 2,000 requests/minute = ~33.33 requests/second
// Can handle very high concurrency

async function enterpriseHighThroughput() {
  const concurrentRequests = 100; // Enterprise burst size
  const queue = [];
  
  for (let i = 0; i < 120000; i++) {
    queue.push(makeRequest());
    
    if (queue.length >= concurrentRequests) {
      await Promise.race(queue);
      queue.splice(queue.findIndex(p => p.settled), 1);
    }
  }
  
  await Promise.all(queue);
}

// ✅ Good: Can handle sustained high load
async function enterpriseSustainedLoad() {
  const requestsPerSecond = 30; // Sustainable rate
  const interval = 1000 / requestsPerSecond;
  
  for (let i = 0; i < 120000; i++) {
    makeRequest().catch(console.error);
    await delay(interval);
  }
}
```

### Admin Endpoint Exemption

Enterprise users get exemption for admin endpoints:

```bash
# These don't count against rate limit for Enterprise users
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/admin/users

curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/admin/subscriptions
```

## Service-to-Service Communication

### API Key Authentication

Service-to-service communication using API keys has higher limits:

- **Requests per minute:** 10,000
- **Requests per hour:** 500,000
- **Burst size:** 500 concurrent requests
- **Concurrent connections:** 200

### Usage

```bash
curl -H "X-API-Key: $API_KEY" \
  https://api.cloudtolocalllm.online/v2/tunnels
```

### When to Use

- Backend service integration
- Scheduled jobs
- Batch processing
- System-to-system communication

## Rate Limit Monitoring by Tier

### Free Tier Monitoring

```bash
# Check your current usage
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/summary
```

### Premium Tier Monitoring

```bash
# Same endpoint, but with higher limits
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/summary
```

### Enterprise Tier Monitoring

```bash
# Same endpoint, plus access to admin metrics
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/summary

# Admin: View top violators
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/top-violators

# Admin: View top violating IPs
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/top-ips

# Admin: View dashboard data
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/dashboard-data
```

## Tier Comparison Table

| Feature | Free | Premium | Enterprise | API Key |
|---------|------|---------|-----------|---------|
| Requests/minute | 100 | 500 | 2,000 | 10,000 |
| Requests/hour | 5,000 | 30,000 | 120,000 | 500,000 |
| Burst size | 10 | 50 | 200 | 500 |
| Concurrent connections | 5 | 25 | 100 | 200 |
| Health check exempt | ❌ | ✅ | ✅ | ✅ |
| Admin endpoint exempt | ❌ | ❌ | ✅ | ✅ |
| Metrics access | ✅ | ✅ | ✅ | ✅ |
| Admin metrics | ❌ | ❌ | ✅ | ✅ |

## Choosing the Right Tier

### Free Tier

**Choose if:**

- You're learning or experimenting
- Your application has low traffic
- You're building a personal project
- You want to test the API

**Example:** Personal dashboard with <100 requests/day

### Premium Tier

**Choose if:**

- You have a production application
- You need reliable service
- Your traffic is moderate
- You want better performance

**Example:** SaaS application with 1,000-10,000 requests/day

### Enterprise Tier

**Choose if:**

- You have high-traffic applications
- You need guaranteed performance
- You require admin features
- You need dedicated support

**Example:** Large platform with 100,000+ requests/day

## Handling Rate Limits by Tier

### Free Tier Strategy

```javascript
// Conservative approach for free tier
async function freeUserStrategy() {
  const maxConcurrent = 5; // Free tier limit
  const queue = [];
  
  for (let i = 0; i < totalRequests; i++) {
    queue.push(makeRequest());
    
    if (queue.length >= maxConcurrent) {
      await Promise.race(queue);
      queue.splice(queue.findIndex(p => p.settled), 1);
    }
  }
  
  await Promise.all(queue);
}
```

### Premium Tier Strategy

```javascript
// Balanced approach for premium tier
async function premiumUserStrategy() {
  const maxConcurrent = 25; // Premium tier limit
  const batchSize = 50; // Premium burst size
  
  for (let i = 0; i < totalRequests; i += batchSize) {
    const batch = [];
    for (let j = 0; j < batchSize && i + j < totalRequests; j++) {
      batch.push(makeRequest());
    }
    await Promise.all(batch);
  }
}
```

### Enterprise Tier Strategy

```javascript
// Aggressive approach for enterprise tier
async function enterpriseUserStrategy() {
  const maxConcurrent = 100; // Enterprise tier limit
  const batchSize = 200; // Enterprise burst size
  
  for (let i = 0; i < totalRequests; i += batchSize) {
    const batch = [];
    for (let j = 0; j < batchSize && i + j < totalRequests; j++) {
      batch.push(makeRequest());
    }
    await Promise.all(batch);
  }
}
```

## Upgrading Your Tier

### Upgrade Process

1. Check your current tier:

   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     https://api.cloudtolocalllm.online/v2/users/me
   ```

2. Upgrade to desired tier:

   ```bash
   curl -X POST \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{"tier": "premium"}' \
     https://api.cloudtolocalllm.online/v2/users/me/tier/upgrade
   ```

3. Verify upgrade:

   ```bash
   curl -H "Authorization: Bearer $TOKEN" \
     https://api.cloudtolocalllm.online/v2/users/me
   ```

### Effective Immediately

Tier upgrades take effect immediately. Your new rate limits apply to the next request.

## Support

For tier-related questions or issues:

1. Check this guide
2. Review your rate limit metrics
3. Contact support with your user ID

---

**Last Updated:** November 2024
**API Version:** 2.0
**Requirement:** 12.7 - Rate limit documentation by tier
