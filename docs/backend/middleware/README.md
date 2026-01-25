# Middleware Directory

This directory contains all Express middleware for the CloudToLocalLLM API backend.

## Security Middleware (Task 29)

### Input Sanitization

**File**: `input-sanitizer.js`

Comprehensive input sanitization to prevent injection attacks and XSS.

**Key Functions**:

- `sanitizeString()` - Remove XSS, scripts, event handlers
- `sanitizeEmail()` - Validate and normalize emails
- `sanitizeNumber()` - Validate numbers with constraints
- `sanitizeUUID()` - Validate UUID format
- `sanitizeLikePattern()` - Escape SQL LIKE patterns
- `sanitizeAdminInput()` - Combined admin validation

**Usage**:

```javascript
import {
  sanitizeAll,
  sanitizeAdminInput,
} from './middleware/input-sanitizer.js';

app.use(sanitizeAll);
app.use('/api/admin', sanitizeAdminInput);
```

### CORS Configuration

**File**: `cors-config.js`

Secure CORS configuration with whitelist-based origin validation.

**Configurations**:

- `standardCors` - Public endpoints
- `adminCors` - Admin endpoints (stricter)
- `webhookCors` - Webhook endpoints

**Usage**:

```javascript
import { standardCors, adminCors } from './middleware/cors-config.js';

app.use(standardCors);
app.use('/api/admin', adminCors);
```

### HTTPS Enforcement

**File**: `https-enforcer.js`

HTTPS enforcement and security headers.

**Features**:

- HTTP to HTTPS redirect
- HSTS headers
- Secure cookie flags
- Security headers (X-Frame-Options, etc.)

**Usage**:

```javascript
import {
  httpsEnforcement,
  adminHttpsEnforcement,
} from './middleware/https-enforcer.js';

app.use(httpsEnforcement);
app.use('/api/admin', adminHttpsEnforcement);
```

## Authentication Middleware

### Admin Authentication

**File**: `admin-auth.js`

Admin authentication and role-based access control.

**Usage**:

```javascript
import { adminAuth } from './middleware/admin-auth.js';

app.use('/api/admin', adminAuth(['view_users']));
```

### JWT Validation

**File**: `jwt-validator.js`

JWT token validation for Auth0.

### Standard Authentication

**File**: `auth.js`

Standard authentication middleware.

## Rate Limiting

### Admin Rate Limiter

**File**: `admin-rate-limiter.js`

Rate limiting specifically for admin endpoints.

**Documentation**: `ADMIN_RATE_LIMITING_GUIDE.md`

### Standard Rate Limiter

**File**: `rate-limiter.js`

Rate limiting for public endpoints.

**Documentation**: `RATE_LIMITING_QUICK_REFERENCE.md`

## Other Middleware

### Connection Security

**File**: `connection-security.js`

Connection-level security checks.

### Security Audit Logger

**File**: `security-audit-logger.js`

Logs security-related events.

### Tier Check

**File**: `tier-check.js`

User tier validation and feature access control.

## Documentation

### Security Enhancements

- `SECURITY_ENHANCEMENTS_GUIDE.md` - Comprehensive guide
- `SECURITY_QUICK_REFERENCE.md` - Quick reference
- `INTEGRATION_EXAMPLE.md` - Integration examples

### Rate Limiting

- `ADMIN_RATE_LIMITING_GUIDE.md` - Admin rate limiting guide
- `RATE_LIMITING_QUICK_REFERENCE.md` - Rate limiting reference

## Middleware Order

The recommended order for applying middleware:

1. **Trust Proxy** - `app.set('trust proxy', 1)`
2. **HTTPS Enforcement** - `httpsEnforcement`
3. **Helmet** - Security headers
4. **CORS** - `standardCors`
5. **Rate Limiting** - Rate limiters
6. **Webhook Routes** - Before body parsing
7. **Body Parsing** - `express.json()`
8. **Input Sanitization** - `sanitizeAll`
9. **Authentication** - `adminAuth`, `authenticateJWT`
10. **Routes** - Application routes

## Quick Start

### Basic Setup

```javascript
import express from 'express';
import { standardCors } from './middleware/cors-config.js';
import { httpsEnforcement } from './middleware/https-enforcer.js';
import { sanitizeAll } from './middleware/input-sanitizer.js';

const app = express();

app.set('trust proxy', 1);
app.use(httpsEnforcement);
app.use(standardCors);
app.use(express.json());
app.use(sanitizeAll);

// Your routes here
```

### Admin Routes Setup

```javascript
import { adminCors } from './middleware/cors-config.js';
import { adminHttpsEnforcement } from './middleware/https-enforcer.js';
import { sanitizeAdminInput } from './middleware/input-sanitizer.js';
import { adminAuth } from './middleware/admin-auth.js';

app.use(
  '/api/admin',
  adminCors,
  adminHttpsEnforcement,
  sanitizeAdminInput,
  adminAuth(),
  adminRoutes
);
```

## Testing

### Unit Tests

Test individual middleware functions:

```javascript
import { sanitizeString } from './middleware/input-sanitizer.js';

test('sanitizes XSS', () => {
  const result = sanitizeString('<script>alert(1)</script>');
  expect(result).not.toContain('<script>');
});
```

### Integration Tests

Test middleware in request flow:

```javascript
import request from 'supertest';
import app from '../server.js';

test('CORS allows whitelisted origin', async () => {
  const response = await request(app)
    .get('/api/health')
    .set('Origin', 'https://app.cloudtolocalllm.online');

  expect(response.headers['access-control-allow-origin']).toBeDefined();
});
```

## Environment Variables

### CORS

- `ADDITIONAL_CORS_ORIGINS` - Comma-separated list of additional origins

### HTTPS

- `NODE_ENV` - Set to 'production' to enable HTTPS enforcement
- `FORCE_HTTPS` - Set to 'true' to force HTTPS in development

## Troubleshooting

### CORS Issues

- Check origin is in allowed list
- Add to `ADDITIONAL_CORS_ORIGINS`
- Verify credentials are sent

### HTTPS Issues

- Set `trust proxy` correctly
- Check `X-Forwarded-Proto` header
- Verify load balancer configuration

### Input Sanitization Issues

- Check validation constraints
- Verify data format
- Use correct sanitizer function

## Contributing

When adding new middleware:

1. Create file in this directory
2. Export middleware function
3. Add documentation
4. Add tests
5. Update this README
6. Update integration examples

## Support

For questions or issues:

1. Check relevant documentation files
2. Review test cases
3. Check logs for errors
4. Consult OWASP guidelines

## References

- [Express Middleware Guide](https://expressjs.com/en/guide/using-middleware.html)
- [OWASP Security Guidelines](https://owasp.org/)
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/)
