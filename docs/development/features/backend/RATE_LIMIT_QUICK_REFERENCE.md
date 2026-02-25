# Rate Limiting Quick Reference

## Rate Limit Policies by Tier

| Tier | Requests/Min | Requests/Hour | Burst Size | Concurrent |
|------|-------------|---------------|-----------|-----------|
| Free | 100 | 5,000 | 10 | 5 |
| Premium | 500 | 30,000 | 50 | 25 |
| Enterprise | 2,000 | 120,000 | 200 | 100 |

## Response Headers

```
X-RateLimit-Limit: 100          # Max requests in window
X-RateLimit-Remaining: 87       # Requests left
X-RateLimit-Reset: 1699564800   # Unix timestamp of reset
Retry-After: 60                 # Seconds to wait (if rate limited)
```

## Rate Limit Error (429)

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

## Check Your Limits

```bash
# Get your user tier
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/users/me

# Get rate limit metrics
curl -H "Authorization: Bearer $TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/summary
```

## Implement Retry Logic

```javascript
async function makeRequest(url, maxRetries = 3) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    const response = await fetch(url);
    
    if (response.status === 429) {
      const retryAfter = parseInt(response.headers.get('Retry-After'));
      await new Promise(r => setTimeout(r, retryAfter * 1000));
      continue;
    }
    
    return response;
  }
}
```

## Best Practices

1. **Check headers** - Always read `X-RateLimit-*` headers
2. **Batch requests** - Combine operations when possible
3. **Cache responses** - Reduce API calls with caching
4. **Implement backoff** - Use exponential backoff on 429 errors
5. **Monitor usage** - Check metrics regularly
6. **Upgrade tier** - If consistently hitting limits

## Exempt Endpoints

- `GET /health` - Health checks
- `POST /auth/login` - Authentication
- `POST /auth/refresh` - Token refresh
- `POST /error-recovery/manual-intervention` - Emergency recovery

## Admin Endpoints

```bash
# Top violators
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/top-violators?limit=10

# Top violating IPs
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/top-ips?limit=10

# Dashboard data
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  https://api.cloudtolocalllm.online/v2/rate-limit-metrics/dashboard-data
```

## Upgrade Your Tier

```bash
curl -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tier": "premium"}' \
  https://api.cloudtolocalllm.online/v2/users/me/tier/upgrade
```

## Rate Limit Types

1. **Per-User** - Based on user tier
2. **Per-IP** - 1,000 req/min, 50,000 req/hour
3. **Burst** - Concurrent request limits
4. **Concurrent** - Max simultaneous connections

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Rate limited on first request | Check tier, authenticate with API key |
| Burst requests queued | Reduce concurrent requests, upgrade tier |
| Unexpected reset time | Rate limits use sliding windows, check `X-RateLimit-Reset` |

---

**Requirement:** 12.7 - API rate limit documentation
