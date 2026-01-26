# API Rate Limiting Guide

## Overview

CloudToLocalLLM utilizes a multi-tiered rate limiting strategy to protect the API from abuse, ensure fair resource allocation, and defend against brute-force attacks.

---

## 🛡️ Admin Rate Limit Profiles

Different administrative operations have distinct risk and resource profiles, necessitating specific limiters.

| Limiter Profile | Default Limit | Window | Ideal Use Case |
| :--- | :--- | :--- | :--- |
| **`adminReadOnly`** | 200 requests | 1 min | GET endpoints (dashboard, user lists). |
| **`adminRateLimiter`**| 100 requests | 1 min | Standard POST/PATCH operations. |
| **`adminBurst`** | 20 requests | 10 sec | Rapid-fire request protection. |
| **`adminExpensive`** | 10 requests | 1 min | Resource intensive (exports, complex reports). |
| **`adminCritical`** | 5 requests | 1 hour | Destructive actions (data flush, deletions). |

---

## 🛠️ Usage for Developers

### Basic Implementation

```javascript
import { adminRateLimiter, adminReadOnlyLimiter } from '../middleware/admin-rate-limiter.js';

// GET (Read-only)
router.get('/users', adminReadOnlyLimiter, handler);

// POST (Standard)
router.post('/users/:id', adminRateLimiter, handler);
```

### Combined Limiters

For highly sensitive endpoints, you can combine burst and standard limiters.

```javascript
import { combineRateLimiters, adminBurstLimiter, adminRateLimiter } from '../middleware/admin-rate-limiter.js';

router.post('/sensitive', combineRateLimiters(adminBurstLimiter, adminRateLimiter), handler);
```

---

## 📊 Headers and Responses

### Success Headers

- `RateLimit-Limit`: Maximum requests allowed.
- `RateLimit-Remaining`: Requests left in window.
- `RateLimit-Reset`: ISO timestamp when limit resets.

### Error Response (429)

When a limit is exceeded, the server returns a `429 Too Many Requests` status code.

```json
{
  "error": "Too many requests from this admin user",
  "code": "ADMIN_RATE_LIMIT_EXCEEDED",
  "retryAfter": 60,
  "timestamp": "2025-11-16T10:30:00.000Z"
}
```

---

## 🔒 Production Considerations

- **Redis Storage**: For multi-instance deployments, the rate limiter uses a Redis store to maintain global counts.
- **Health Check Exemption**: Internal health checks (/health) are automatically exempted from rate limiting.

---

## Related Documentation

- [Backend Security Guide](./BACKEND_SECURITY.md)
- [RBAC Guide](./RBAC_GUIDE.md)
