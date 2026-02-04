# API Deprecation Quick Reference

## Overview

Zoidbot API implements structured deprecation with migration guides. This quick reference shows how to use deprecation features.

**Requirements: 12.5**

## Key Endpoints

### Check Deprecation Status

```bash
# Get overall deprecation status
curl https://api.zoidbot.online/api/deprecation/status

# Get list of deprecated endpoints
curl https://api.zoidbot.online/api/deprecation/deprecated

# Get list of sunset endpoints
curl https://api.zoidbot.online/api/deprecation/sunset

# Get info for specific endpoint
curl "https://api.zoidbot.online/api/deprecation/endpoint-info?path=/v1/users"

# Get migration guide
curl https://api.zoidbot.online/api/deprecation/migration-guide/MIGRATION_V1_TO_V2
```

## Deprecation Headers

All responses from deprecated endpoints include:

```
Deprecation: true
Sunset: Wed, 01 Jan 2025 00:00:00 GMT
Warning: 299 - "API endpoint /v1/users is deprecated..."
Deprecation-Link: /v2/users
```

## Response Format

Deprecated endpoints include deprecation info in response:

```json
{
  "user": { ... },
  "_deprecation": {
    "deprecated": true,
    "message": "API endpoint /v1/users is deprecated...",
    "replacedBy": "/v2/users",
    "sunsetAt": "2025-01-01",
    "migrationGuide": { ... }
  }
}
```

## Migration Steps

### 1. Update Base URL

```javascript
// Before
const api = 'https://api.zoidbot.online/v1';

// After
const api = 'https://api.zoidbot.online/v2';
```

### 2. Update Response Parsing

```javascript
// Before
const email = data.data.userEmail;

// After
const email = data.user.email;
```

### 3. Update Error Handling

```javascript
// Before
console.error(error.error);

// After
console.error(error.error.message);
console.error(error.error.suggestion);
```

### 4. Test with v2

```bash
curl -H "Authorization: Bearer TOKEN" \
  https://api.zoidbot.online/v2/users/me
```

## Implementation

### Using Deprecation Service

```javascript
import {
  isDeprecated,
  getDeprecationInfo,
  getMigrationGuide,
  getDeprecationHeaders,
} from './services/deprecation-service.js';

// Check if endpoint is deprecated
if (isDeprecated('/v1/users')) {
  console.log('Endpoint is deprecated');
}

// Get deprecation info
const info = getDeprecationInfo('/v1/users');
console.log(info.replacedBy); // /v2/users

// Get migration guide
const guide = getMigrationGuide('/v1/users');
console.log(guide.title); // Migrating from API v1 to v2

// Get deprecation headers
const headers = getDeprecationHeaders('/v1/users');
// { Deprecation: 'true', Sunset: '...', Warning: '...' }
```

### Using Deprecation Middleware

```javascript
import { deprecationMiddleware } from './middleware/deprecation-middleware.js';

app.use(deprecationMiddleware());
```

### Using Deprecation Routes

```javascript
import deprecationRoutes from './routes/deprecation.js';

app.use('/api/deprecation', deprecationRoutes);
```

## Current Deprecations

| Endpoint | Status | Sunset | Replaced By |
|----------|--------|--------|-------------|
| /v1/users | Deprecated | 2025-01-01 | /v2/users |
| /v1/tunnels | Deprecated | 2025-01-01 | /v2/tunnels |
| /v1/auth | Deprecated | 2025-01-01 | /v2/auth |
| /v1/admin | Deprecated | 2025-01-01 | /v2/admin |

## Monitoring

### Check Deprecation Status

```bash
curl https://api.zoidbot.online/api/deprecation/status | jq '.totalDeprecated'
```

### Get Days Until Sunset

```bash
curl https://api.zoidbot.online/api/deprecation/deprecated | \
  jq '.endpoints[0].daysUntilSunset'
```

### Monitor Deprecated Endpoint Usage

```bash
# Check logs for deprecation warnings
grep "DEPRECATION" /var/log/api-backend.log
```

## Best Practices

1. **Check deprecation status regularly**

   ```bash
   curl https://api.zoidbot.online/api/deprecation/status
   ```

2. **Monitor deprecation headers**

   ```bash
   curl -i https://api.zoidbot.online/v1/users | grep Deprecation
   ```

3. **Use migration guides**

   ```bash
   curl https://api.zoidbot.online/api/deprecation/migration-guide/MIGRATION_V1_TO_V2
   ```

4. **Test with v2 before sunset**

   ```bash
   curl https://api.zoidbot.online/v2/users/me
   ```

5. **Set calendar reminders**
   - Deprecation date: 2024-01-01
   - Sunset date: 2025-01-01

## Troubleshooting

### Endpoint Returns 410 Gone

The endpoint has been sunset and is no longer available. Use the replacement endpoint:

```bash
# Old (sunset)
curl https://api.zoidbot.online/v1/users

# New (use this)
curl https://api.zoidbot.online/v2/users
```

### Missing Deprecation Headers

The endpoint is not deprecated. Check the endpoint path:

```bash
# Check if endpoint is deprecated
curl "https://api.zoidbot.online/api/deprecation/endpoint-info?path=/v1/users"
```

### Migration Guide Not Found

The migration guide ID may be incorrect. Get the correct ID:

```bash
# Get endpoint info with guide ID
curl "https://api.zoidbot.online/api/deprecation/endpoint-info?path=/v1/users" | \
  jq '.migrationGuide'
```

## Support

- **Documentation**: https://docs.zoidbot.online/api/deprecation
- **API Docs**: https://api.zoidbot.online/api/docs
- **Support**: support@zoidbot.online
- **Issues**: https://github.com/ghcr.io/zoidbot-online/zoidbot/api/issues

</content>
