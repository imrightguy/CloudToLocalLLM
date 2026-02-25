# Authentication Middleware Quick Start Guide

## Installation

No additional dependencies required - uses Node.js built-in modules and Web Crypto API.

## Basic Setup (5 minutes)

### 1. Set Environment Variables

```bash
export SUPABASE_AUTH_DOMAIN=your-tenant.auth0.com
export SUPABASE_AUTH_AUDIENCE=https://api.CloudToLocalLLM.com
```

### 2. Initialize Middleware

```typescript
import {
  JWTValidationMiddleware,
  UserContextManager,
  AuthAuditLogger,
  createUserContextMiddleware,
} from './middleware';

// Initialize
const jwtMiddleware = new JWTValidationMiddleware({
  domain: process.env.SUPABASE_AUTH_DOMAIN!,
  audience: process.env.SUPABASE_AUTH_AUDIENCE!,
  issuer: `https://${process.env.SUPABASE_AUTH_DOMAIN}/`,
});

const contextManager = new UserContextManager();
const auditLogger = new AuthAuditLogger();
```

### 3. Apply to Express App

```typescript
import express from 'express';

const app = express();

// Apply user context middleware to protected routes
const userContextMiddleware = createUserContextMiddleware(
  jwtMiddleware,
  contextManager
);

app.use('/api/tunnel', userContextMiddleware);

// Your routes here
app.get('/api/tunnel/status', (req, res) => {
  const context = contextManager.getContextFromRequest(req);
  res.json({ userId: context!.userId, tier: context!.tier });
});
```

## Common Use Cases

### Validate a Token

```typescript
const result = await jwtMiddleware.validateToken(token);
if (result.valid) {
  console.log('Valid token for user:', result.userId);
} else {
  console.error('Invalid token:', result.error);
}
```

### Get User Context

```typescript
const context = await jwtMiddleware.getUserContext(token);
console.log('User:', context.userId);
console.log('Tier:', context.tier);
console.log('Rate limit:', context.rateLimit.requestsPerMinute);
```

### Check Permissions

```typescript
const context = contextManager.getContextFromRequest(req);
if (contextManager.hasPermission(context, 'admin:write')) {
  // User has permission
}
```

### Require Specific Tier

```typescript
import { requireTier, UserTier } from './middleware';

app.get(
  '/api/tunnel/premium-feature',
  userContextMiddleware,
  requireTier(contextManager, UserTier.PREMIUM),
  (req, res) => {
    // Only premium and enterprise users can access
  }
);
```

### Log Authentication Events

```typescript
// Log successful authentication
auditLogger.logAuthSuccess(userId, ip);

// Log failed authentication
auditLogger.logAuthFailure(userId, ip, 'Invalid password');

// Check if IP is blocked
if (auditLogger.isIPBlocked(ip)) {
  return res.status(403).json({ error: 'IP blocked' });
}
```

### Monitor Security Alerts

```typescript
auditLogger.onSecurityAlert((alert) => {
  console.error('SECURITY ALERT:', alert);
  // Send to monitoring system
  // Email admins
  // Trigger incident response
});
```

## Testing

### Test Token Validation

```bash
# Get a token from Auth0
TOKEN="eyJhbGc..."

# Test validation
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:3000/api/tunnel/status
```

### Test Brute Force Protection

```bash
# Make multiple failed attempts
for i in {1..6}; do
  curl -H "Authorization: Bearer invalid-token" \
    http://localhost:3000/api/tunnel/status
done

# IP should now be blocked
```

### Get Authentication Statistics

```typescript
const stats = auditLogger.getAuthStats(60 * 60 * 1000); // Last hour
console.log('Success rate:', stats.successRate);
console.log('Failed attempts:', stats.failedAttempts);
console.log('Blocked IPs:', stats.blockedIPs);
```

## Troubleshooting

### "Unable to retrieve public key"

- Check SUPABASE_AUTH_DOMAIN is correct
- Verify network connectivity to Auth0
- Check firewall rules

### "Invalid signature"

- Verify SUPABASE_AUTH_AUDIENCE matches your Auth0 API
- Check token is from correct Auth0 tenant
- Ensure token hasn't been tampered with

### "Token expired"

- Token has expired - client needs to refresh
- Check token expiration time (exp claim)
- Implement token refresh flow in client

### "IP blocked"

- Too many failed authentication attempts
- Unblock with: `auditLogger.unblockIP(ip)`
- Review audit logs for suspicious activity

## Production Checklist

- [ ] Set SUPABASE_AUTH_DOMAIN and SUPABASE_AUTH_AUDIENCE environment variables
- [ ] Configure Auth0 custom claims for tier and permissions
- [ ] Set up security alert monitoring
- [ ] Configure log aggregation
- [ ] Set up Prometheus metrics
- [ ] Test token validation
- [ ] Test brute force protection
- [ ] Review audit logs regularly
- [ ] Set up automated alerts
- [ ] Document incident response procedures

## Next Steps

1. Implement rate limiting (Task 8)
2. Integrate with WebSocket handler
3. Set up monitoring and alerting
4. Deploy to production
5. Configure Auth0 production tenant

## Support

For issues or questions:

- Review the full README.md
- Check IMPLEMENTATION_SUMMARY.md
- Review test files for examples
- Check Auth0 documentation
