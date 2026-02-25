# Authentication and Authorization Middleware

This directory contains the server-side authentication and authorization middleware for the SSH WebSocket tunnel enhancement.

## Components

### 1. JWT Validation Middleware (`jwt-validation-middleware.ts`)

Validates JWT tokens from Auth0 with the following features:

- Integration with Auth0 JWKS endpoint
- Token signature verification using Web Crypto API
- Expiration checking with distinction between expired and invalid tokens
- 5-minute validation result caching
- Automatic JWKS key caching (1 hour)

**Usage:**

```typescript
import { JWTValidationMiddleware } from './middleware';

const jwtMiddleware = new JWTValidationMiddleware({
  domain: process.env.SUPABASE_AUTH_DOMAIN!,
  audience: process.env.SUPABASE_AUTH_AUDIENCE!,
  issuer: `https://${process.env.SUPABASE_AUTH_DOMAIN}/`,
});

// Validate a token
const result = await jwtMiddleware.validateToken(token);
if (result.valid) {
  console.log('User ID:', result.userId);
  console.log('Expires at:', result.expiresAt);
} else {
  console.error('Validation failed:', result.error);
}

// Get user context
const userContext = await jwtMiddleware.getUserContext(token);
console.log('User tier:', userContext.tier);
console.log('Rate limit:', userContext.rateLimit);
```

### 2. User Context Manager (`user-context-manager.ts`)

Manages user context extraction and attachment to requests:

- Extracts user ID and tier from JWT payload
- Loads user-specific rate limits based on tier
- Attaches user context to requests
- Implements tier-based permissions
- Provides middleware factories for permission and tier checks

**Usage:**

```typescript
import { UserContextManager, createUserContextMiddleware } from './middleware';

const contextManager = new UserContextManager();

// Create middleware
const userContextMiddleware = createUserContextMiddleware(
  jwtMiddleware,
  contextManager
);

// Use in Express app
app.use('/api/tunnel', userContextMiddleware);

// Access user context in route handlers
app.get('/api/tunnel/status', (req, res) => {
  const context = contextManager.getContextFromRequest(req);
  res.json({
    userId: context.userId,
    tier: context.tier,
    rateLimit: context.rateLimit,
  });
});

// Require specific permission
import { requirePermission } from './middleware';

app.post(
  '/api/tunnel/admin',
  userContextMiddleware,
  requirePermission(contextManager, 'admin:write'),
  (req, res) => {
    // Only users with 'admin:write' permission can access
  }
);

// Require minimum tier
import { requireTier, UserTier } from './middleware';

app.get(
  '/api/tunnel/advanced-metrics',
  userContextMiddleware,
  requireTier(contextManager, UserTier.PREMIUM),
  (req, res) => {
    // Only premium and enterprise users can access
  }
);
```

### 3. Authentication Audit Logger (`auth-audit-logger.ts`)

Comprehensive logging and monitoring of authentication events:

- Logs all authentication attempts and failures
- Detects brute force attack patterns
- Blocks suspicious IPs and users
- Generates security alerts
- Provides audit reports

**Usage:**

```typescript
import { AuthAuditLogger, createAuthAuditMiddleware } from './middleware';

const auditLogger = new AuthAuditLogger();

// Register security alert handler
auditLogger.onSecurityAlert((alert) => {
  console.error('SECURITY ALERT:', alert);
  // Send to monitoring system, email admins, etc.
});

// Log authentication attempts
auditLogger.logAuthAttempt(userId, ip, success, reason);

// Log specific events
auditLogger.logAuthSuccess(userId, ip, { method: 'jwt' });
auditLogger.logAuthFailure(userId, ip, 'Invalid token', { tokenType: 'Bearer' });

// Check if blocked
if (auditLogger.isIPBlocked(ip)) {
  return res.status(403).json({ error: 'IP blocked' });
}

// Get statistics
const stats = auditLogger.getAuthStats(60 * 60 * 1000); // Last hour
console.log('Success rate:', stats.successRate);
console.log('Blocked IPs:', stats.blockedIPs);

// Generate audit report
const report = auditLogger.generateAuditReport(
  new Date('2024-01-01'),
  new Date('2024-01-31')
);
console.log('Top failure reasons:', report.topFailureReasons);
console.log('Suspicious IPs:', report.suspiciousIPs);

// Use as middleware to block suspicious traffic
app.use(createAuthAuditMiddleware(auditLogger));
```

## Complete Integration Example

Here's a complete example of integrating all middleware components:

```typescript
import express from 'express';
import {
  JWTValidationMiddleware,
  UserContextManager,
  AuthAuditLogger,
  createUserContextMiddleware,
  createAuthAuditMiddleware,
  requirePermission,
  requireTier,
  UserTier,
} from './middleware';

const app = express();

// Initialize middleware components
const jwtMiddleware = new JWTValidationMiddleware({
  domain: process.env.SUPABASE_AUTH_DOMAIN!,
  audience: process.env.SUPABASE_AUTH_AUDIENCE!,
  issuer: `https://${process.env.SUPABASE_AUTH_DOMAIN}/`,
});

const contextManager = new UserContextManager();
const auditLogger = new AuthAuditLogger();

// Register security alert handler
auditLogger.onSecurityAlert((alert) => {
  console.error('SECURITY ALERT:', {
    type: alert.type,
    severity: alert.severity,
    userId: alert.userId,
    ip: alert.ip,
    details: alert.details,
  });
  
  // In production, send to monitoring system
  // sendToMonitoring(alert);
  // sendEmailToAdmins(alert);
});

// Apply audit middleware globally
app.use(createAuthAuditMiddleware(auditLogger));

// Create user context middleware
const userContextMiddleware = createUserContextMiddleware(
  jwtMiddleware,
  contextManager
);

// Public endpoints (no auth required)
app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Protected endpoints (auth required)
app.use('/api/tunnel', userContextMiddleware);

// Basic tunnel endpoints
app.get('/api/tunnel/status', (req, res) => {
  const context = contextManager.getContextFromRequest(req);
  
  auditLogger.logAuthSuccess(context!.userId, req.ip);
  
  res.json({
    userId: context!.userId,
    tier: context!.tier,
    connected: true,
  });
});

// Premium feature (requires premium tier)
app.get(
  '/api/tunnel/advanced-metrics',
  requireTier(contextManager, UserTier.PREMIUM),
  (req, res) => {
    const context = contextManager.getContextFromRequest(req);
    // Return advanced metrics
    res.json({ metrics: 'advanced data' });
  }
);

// Admin endpoint (requires admin permission)
app.post(
  '/api/tunnel/admin/config',
  requirePermission(contextManager, 'admin:write'),
  (req, res) => {
    // Update configuration
    res.json({ success: true });
  }
);

// Audit endpoints (admin only)
app.get(
  '/api/tunnel/admin/audit/stats',
  requirePermission(contextManager, 'admin:read'),
  (req, res) => {
    const timeWindow = parseInt(req.query.window as string) || 60 * 60 * 1000;
    const stats = auditLogger.getAuthStats(timeWindow);
    res.json(stats);
  }
);

app.get(
  '/api/tunnel/admin/audit/report',
  requirePermission(contextManager, 'admin:read'),
  (req, res) => {
    const startDate = new Date(req.query.start as string);
    const endDate = new Date(req.query.end as string);
    const report = auditLogger.generateAuditReport(startDate, endDate);
    res.json(report);
  }
);

// Error handling
app.use((err: any, req: any, res: any, next: any) => {
  console.error('Error:', err);
  
  // Log authentication errors
  if (err.name === 'UnauthorizedError') {
    const userId = req.userContext?.userId || 'unknown';
    auditLogger.logAuthFailure(userId, req.ip, err.message);
  }
  
  res.status(err.status || 500).json({
    error: err.message || 'Internal server error',
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
```

## Configuration

### Environment Variables

```bash
# Auth0 Configuration
SUPABASE_AUTH_DOMAIN=your-tenant.auth0.com
SUPABASE_AUTH_AUDIENCE=https://api.CloudToLocalLLM.com
SUPABASE_AUTH_ISSUER=https://your-tenant.auth0.com/

# Server Configuration
PORT=3000
LOG_LEVEL=info
```

### Auth0 Setup

1. Create an API in Auth0 dashboard
2. Configure the audience (e.g., `https://api.CloudToLocalLLM.com`)
3. Add custom claims to tokens:
   - `https://CloudToLocalLLM.com/tier` - User tier (free/premium/enterprise)
   - `https://CloudToLocalLLM.com/permissions` - Array of permissions

Example Auth0 Rule:

```javascript
function addCustomClaims(user, context, callback) {
  const namespace = 'https://CloudToLocalLLM.com/';
  
  context.accessToken[namespace + 'tier'] = user.app_metadata?.tier || 'free';
  context.accessToken[namespace + 'permissions'] = user.app_metadata?.permissions || [];
  
  callback(null, user, context);
}
```

## Rate Limits by Tier

| Tier       | Requests/Min | Max Connections | Max Queue Size |
|------------|--------------|-----------------|----------------|
| Free       | 100          | 3               | 100            |
| Premium    | 300          | 5               | 200            |
| Enterprise | 1000         | 10              | 500            |

## Security Features

### Brute Force Protection

- Tracks failed authentication attempts per IP and user
- Blocks IP after 5 failed attempts within 5 minutes
- Blocks user after 10 failed attempts from different IPs within 5 minutes
- Generates security alerts for suspicious activity

### Token Validation

- Verifies JWT signature using Auth0 public keys
- Checks token expiration
- Validates issuer and audience
- Caches validation results for 5 minutes
- Distinguishes between expired and invalid tokens

### Audit Logging

- Logs all authentication attempts (success and failure)
- Structured JSON logging for easy parsing
- Tracks user agents and IP addresses
- Generates audit reports with statistics
- Identifies suspicious patterns

## Testing

```typescript
// Test JWT validation
const token = 'eyJhbGc...'; // Valid JWT token
const result = await jwtMiddleware.validateToken(token);
console.assert(result.valid === true);

// Test expired token detection
const expiredToken = 'eyJhbGc...'; // Expired JWT token
const expiredResult = await jwtMiddleware.validateToken(expiredToken);
console.assert(expiredResult.valid === false);
console.assert(expiredResult.error === 'Token expired');

// Test brute force detection
for (let i = 0; i < 6; i++) {
  auditLogger.logAuthAttempt('user123', '192.168.1.1', false, 'Invalid password');
}
console.assert(auditLogger.isIPBlocked('192.168.1.1') === true);

// Test tier-based access
const freeUserContext = { tier: UserTier.FREE, /* ... */ };
const premiumUserContext = { tier: UserTier.PREMIUM, /* ... */ };
// Free user should not access premium features
// Premium user should access premium features
```

## Monitoring

### Metrics to Track

- Authentication success rate
- Failed authentication attempts per minute
- Blocked IPs and users
- Token validation cache hit rate
- Average token validation time
- Security alerts generated

### Alerts to Configure

- High authentication failure rate (> 10% over 5 minutes)
- Brute force attack detected
- Unusual number of blocked IPs (> 10 in 1 hour)
- Token validation errors (> 5% over 5 minutes)

## Troubleshooting

### Common Issues

1. **"Unable to retrieve public key"**
   - Check Auth0 domain configuration
   - Verify network connectivity to Auth0
   - Check JWKS endpoint is accessible

2. **"Invalid signature"**
   - Token may be from wrong Auth0 tenant
   - Token may be tampered with
   - Check audience and issuer configuration

3. **"Token expired"**
   - Client needs to refresh token
   - Check token expiration time (exp claim)
   - Implement token refresh flow

4. **"IP blocked"**
   - Too many failed authentication attempts
   - Use `auditLogger.unblockIP(ip)` to unblock
   - Review audit logs for suspicious activity

## Best Practices

1. **Always validate tokens on every request** - Don't rely on connection-time validation only
2. **Use HTTPS** - Never send tokens over unencrypted connections
3. **Implement token refresh** - Handle expired tokens gracefully
4. **Monitor security alerts** - Set up real-time monitoring for brute force attacks
5. **Regular audit reviews** - Review audit logs weekly for suspicious patterns
6. **Rate limit by tier** - Enforce different limits based on user tier
7. **Cache validation results** - Reduce Auth0 API calls with caching
8. **Log everything** - Comprehensive logging helps with debugging and security
