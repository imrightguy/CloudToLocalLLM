# Backend Security Guide

## Overview

This guide documents the security enhancements and best practices for the CloudToLocalLLM API backend. It covers input sanitization, CORS configuration, and HTTPS enforcement.

---

## 🛡️ Security Components

### 1. Input Sanitization

**Middleware:** `input-sanitizer.js`

Comprehensive sanitization prevents injection attacks (SQLi, XSS) by validating types and escaping malicious characters.

| Function | Purpose | Example |
| :--- | :--- | :--- |
| `sanitizeString` | Remove XSS, scripts | `sanitizeString('<script>alert(1)</script>')` |
| `sanitizeEmail` | Validate/normalize email | `sanitizeEmail('User@Example.Com')` |
| `sanitizeUUID` | Validate UUID format | `sanitizeUUID('123e4567-...')` |
| `sanitizeLikePattern` | Escape SQL LIKE chars | `sanitizeLikePattern('user%')` |

**Usage:**

```javascript
import { sanitizeAll } from './middleware/input-sanitizer.js';
app.use(sanitizeAll); // Applied after body-parser
```

### 2. CORS Configuration

**Middleware:** `cors-config.js`

Strict whitelist-based CORS with no wildcards. Supports standard, admin, and webhook-specific profiles.

**Allowed Origins (Production):**

- `https://app.cloudtolocalllm.online`
- `https://admin.cloudtolocalllm.online`

### 3. HTTPS Enforcement

**Middleware:** `https-enforcer.js`

Automatic HTTP to HTTPS redirection in production, combined with HSTS and secure security headers.

**Security Headers Set:**

- `Strict-Transport-Security` (Force HTTPS)
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: DENY` (Anti-clickjacking)

---

## 🚀 Quick Start Integration

```javascript
const app = express();
app.set('trust proxy', 1); // Required for HTTPS detection

app.use(httpsEnforcement);
app.use(standardCors);
app.use(express.json());
app.use(sanitizeAll);

// Stricter rules for admin
app.use('/api/admin', adminCors, adminHttpsEnforcement, sanitizeAdminInput);
```

---

## 💡 Best Practices

1. **Always use parameterized queries**: Never concatenate user input into SQL strings.
2. **Cookie Security**: Cookies are automatically set to `HttpOnly`, `Secure` (in prod), and `SameSite: Strict`.
3. **Environment Variables**:
    - `NODE_ENV=production` (Enables strict enforcements)
    - `ADDITIONAL_CORS_ORIGINS` (Comma-separated list)

---

## Related Documentation

- [Admin Management API](../api/admin/ADMIN_MANAGEMENT.md)
- [Audit Log API](../api/admin/AUDIT_LOGS.md)
