# Rate Limit Exemptions - Quick Reference

## Quick Start

### 1. Initialize Exemption Manager

```javascript
import { RateLimitExemptionManager, createRateLimitExemptionMiddleware } from './middleware/rate-limit-exemptions.js';

const exemptionManager = new RateLimitExemptionManager({
  enabled: true,
  logExemptions: true,
});

const exemptionMiddleware = createRateLimitExemptionMiddleware(exemptionManager);
```

### 2. Add to Middleware Pipeline

```javascript
// IMPORTANT: Add BEFORE rate limiter middleware
app.use(exemptionMiddleware);
app.use(rateLimitMiddleware);
```

### 3. Add Custom Exemption Rules

```javascript
exemptionManager.addRule(
  'my-critical-op',
  'critical_operation',
  (req) => req.path === '/api/critical' && req.method === 'POST',
  {
    description: 'Critical operation endpoint',
    enabled: true,
    maxExemptionsPerUser: 50,
  }
);
```

## Common Operations

### Check if Request is Exempt

```javascript
const result = exemptionManager.checkExemption(req);
if (result.exempt) {
  console.log(`Exempt via rule: ${result.ruleId}`);
}
```

### Enable/Disable Rules

```javascript
exemptionManager.enableRule('health-check');
exemptionManager.disableRule('admin-operations');
```

### Remove Rule

```javascript
exemptionManager.removeRule('my-custom-rule');
```

### Get Statistics

```javascript
const stats = exemptionManager.getStatistics();
console.log(`Total rules: ${stats.totalRules}`);
console.log(`Enabled: ${stats.enabledRules}`);
```

### Reset Exemptions

```javascript
// Reset for specific user
exemptionManager.resetUserExemptions('user-123');

// Reset all
exemptionManager.resetAllExemptions();
```

## Default Exemption Rules

| Rule ID | Type | Paths | Enabled |
|---------|------|-------|---------|
| `health-check` | `health_check` | `/health`, `/api/health`, `/db/health` | ✅ |
| `authentication` | `authentication` | `/auth/login`, `/auth/refresh`, `/auth/logout` | ✅ |
| `admin-operations` | `admin_operation` | `/admin/*`, `/api/admin/*` (admin only) | ✅ |

## Admin API Endpoints

### List Exemption Rules

```bash
GET /api/admin/rate-limit-exemptions
```

Response:

```json
{
  "success": true,
  "data": {
    "rules": [
      {
        "id": "health-check",
        "type": "health_check",
        "description": "Health check endpoints",
        "enabled": true
      }
    ],
    "statistics": {
      "totalRules": 3,
      "enabledRules": 3,
      "disabledRules": 0
    }
  }
}
```

### Add Exemption Rule

```bash
POST /api/admin/rate-limit-exemptions
Content-Type: application/json

{
  "id": "custom-rule",
  "type": "critical_operation",
  "description": "Custom critical operation",
  "enabled": true,
  "pathPatterns": ["/api/critical"],
  "maxExemptionsPerUser": 100
}
```

### Enable Rule

```bash
PATCH /api/admin/rate-limit-exemptions/custom-rule/enable
```

### Disable Rule

```bash
PATCH /api/admin/rate-limit-exemptions/custom-rule/disable
```

### Delete Rule

```bash
DELETE /api/admin/rate-limit-exemptions/custom-rule
```

### Reset User Exemptions

```bash
POST /api/admin/rate-limit-exemptions/reset/user/user-123
```

### Reset All Exemptions

```bash
POST /api/admin/rate-limit-exemptions/reset/all
```

## Response Headers

When a request is exempt, the response includes:

```
X-RateLimit-Exempt: true
X-RateLimit-Exempt-Rule: health-check
```

## Exemption Types

```javascript
CRITICAL_OPERATION  // Critical system operations
ADMIN_OPERATION     // Admin-only operations
HEALTH_CHECK        // Health check endpoints
AUTHENTICATION      // Authentication endpoints
EMERGENCY           // Emergency operations
```

## Configuration Options

```javascript
{
  enabled: true,                    // Enable/disable exemptions globally
  logExemptions: true,              // Log exemption checks
  logExemptionValidation: true,     // Log validation failures
  exemptionTypes: {                 // Available exemption types
    CRITICAL_OPERATION: 'critical_operation',
    ADMIN_OPERATION: 'admin_operation',
    HEALTH_CHECK: 'health_check',
    AUTHENTICATION: 'authentication',
    EMERGENCY: 'emergency',
  }
}
```

## Troubleshooting

### Requests Not Being Exempted

1. Check if exemption manager is initialized
2. Verify middleware is added BEFORE rate limiter
3. Check if rule is enabled: `exemptionManager.enableRule('rule-id')`
4. Verify matcher function logic

### Exemption Quota Exceeded

```javascript
// Check exemption count
const rule = exemptionManager.rules.get('rule-id');
const count = rule.getExemptionCount('user-123');

// Reset if needed
exemptionManager.resetUserExemptions('user-123');
```

### Logging Issues

Enable debug logging:

```javascript
const exemptionManager = new RateLimitExemptionManager({
  logExemptions: true,
  logExemptionValidation: true,
});
```

## Performance Tips

1. **Minimize Rules**: Keep number of rules < 20
2. **Simple Matchers**: Use simple path matching instead of complex logic
3. **Disable Logging**: Set `logExemptions: false` in production if needed
4. **Batch Operations**: Use `resetAllExemptions()` instead of individual resets

## Security Best Practices

1. ✅ Always validate user roles for admin exemptions
2. ✅ Use exemption quotas to prevent abuse
3. ✅ Log all exemption checks for audit trails
4. ✅ Regularly review exemption statistics
5. ✅ Disable exemptions for non-critical operations
6. ✅ Monitor exemption usage patterns

## Testing

```bash
# Run exemption tests
npm test -- test/api-backend/rate-limit-exemptions.test.js

# Run with coverage
npm test -- test/api-backend/rate-limit-exemptions.test.js --coverage
```

## Files

- `middleware/rate-limit-exemptions.js` - Exemption manager
- `middleware/rate-limiter.js` - Rate limiter with exemption support
- `routes/rate-limit-exemptions.js` - Admin management routes
- `test/api-backend/rate-limit-exemptions.test.js` - Tests
