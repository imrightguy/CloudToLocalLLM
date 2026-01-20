# API Versioning Quick Reference

## Quick Start

### Using v2 (Current)
```bash
curl https://api.cloudtolocalllm.online/v2/users/me
curl https://api.cloudtolocalllm.online/users/me  # defaults to v2
```

### Using v1 (Deprecated)
```bash
curl https://api.cloudtolocalllm.online/v1/users/me
```

## Version Information

| Version | Status | Sunset | Use For |
|---------|--------|--------|---------|
| v1 | Deprecated | 2025-01-01 | Legacy integrations only |
| v2 | Current | N/A | All new integrations |

## Response Format

### v1 Response
```json
{
  "success": true,
  "data": { "userId": "123", "userEmail": "user@example.com" }
}
```

### v2 Response
```json
{
  "user": { "id": "123", "email": "user@example.com" }
}
```

## Error Format

### v1 Error
```json
{
  "success": false,
  "error": "User not found",
  "errorCode": "USER_NOT_FOUND"
}
```

### v2 Error
```json
{
  "error": {
    "code": "USER_NOT_FOUND",
    "message": "User not found",
    "statusCode": 404,
    "suggestion": "Check the user ID and try again"
  }
}
```

## Headers

All responses include:
```
API-Version: v2
API-Version-Status: current
```

Deprecated versions also include:
```
Deprecation: true
Sunset: Wed, 01 Jan 2025 00:00:00 GMT
Warning: 299 - "API version v1 is deprecated..."
```

## Migration Checklist

- [ ] Update base URL to v2
- [ ] Update response parsing for v2 format
- [ ] Update error handling for v2 format
- [ ] Test all endpoints with v2
- [ ] Deploy to production
- [ ] Monitor for deprecation warnings

## Endpoints

### Get Version Info
```bash
GET /api/versions
```

Returns information about all supported API versions.

### Health Check
```bash
GET /v2/health
GET /v1/health
GET /health  # defaults to v2
```

## Implementation

### Middleware
```javascript
import { apiVersioningMiddleware } from './middleware/api-versioning.js';
app.use(apiVersioningMiddleware());
```

### Version Routing
```javascript
import { versionRouter } from './middleware/api-versioning.js';

app.get('/users/:id', versionRouter({
  v1: handleUserV1,
  v2: handleUserV2,
}));
```

### Mounted Routes
```javascript
import { mountVersionedRoutes } from './middleware/api-versioning.js';

mountVersionedRoutes(app, '/users', {
  v1: userRouterV1,
  v2: userRouterV2,
});
```

## Common Issues

### "Unsupported API version"
- Check URL path: `/v1/` or `/v2/`
- Supported versions: v1, v2
- Default: v2

### "Endpoint not available in this version"
- Some endpoints may only be available in v2
- Check documentation for version availability
- Migrate to v2 if needed

### Deprecation warnings
- v1 is deprecated, migrate to v2
- Sunset date: 2025-01-01
- Use v2 for all new integrations

## Support

- Documentation: https://docs.cloudtolocalllm.online
- Migration Guide: See API_VERSIONING_GUIDE.md
- Issues: https://github.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/api/issues
