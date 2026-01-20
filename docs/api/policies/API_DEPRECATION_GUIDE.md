# API Deprecation and Migration Guide

## Overview

CloudToLocalLLM API implements a structured deprecation process to ensure smooth transitions between API versions. This guide explains how deprecation works, how to identify deprecated endpoints, and how to migrate to newer versions.

**Requirements: 12.5**

## Deprecation Policy

### Timeline

- **Deprecation**: Endpoint is marked as deprecated but continues to work
- **Sunset**: Endpoint is removed and no longer available (returns 410 Gone)
- **Minimum Notice**: 12 months between deprecation and sunset

### Current Status

| Version | Status | Deprecated | Sunset | Days Remaining |
|---------|--------|-----------|--------|-----------------|
| v1 | Deprecated | 2024-01-01 | 2025-01-01 | ~45 days |
| v2 | Current | N/A | N/A | N/A |

## Identifying Deprecated Endpoints

### Deprecation Headers

All responses from deprecated endpoints include these headers:

```
Deprecation: true
Sunset: Wed, 01 Jan 2025 00:00:00 GMT
Warning: 299 - "API endpoint /v1/users is deprecated and will be removed on 2025-01-01 (45 days). Use /v2/users instead."
Deprecation-Link: /v2/users
```

### Response Body

Deprecated endpoints include deprecation information in the response:

```json
{
  "user": {
    "id": "123",
    "email": "user@example.com"
  },
  "_deprecation": {
    "deprecated": true,
    "message": "API endpoint /v1/users is deprecated and will be removed on 2025-01-01 (45 days). Use /v2/users instead.",
    "replacedBy": "/v2/users",
    "sunsetAt": "2025-01-01",
    "migrationGuide": {
      "title": "Migrating from API v1 to v2",
      "steps": [...]
    }
  }
}
```

## Deprecation Information Endpoints

### Get Deprecation Status

```bash
curl https://api.cloudtolocalllm.online/api/deprecation/status
```

Response:
```json
{
  "timestamp": "2024-11-20T10:00:00Z",
  "deprecatedEndpoints": [
    {
      "path": "/v1/users",
      "status": "deprecated",
      "deprecatedAt": "2024-01-01",
      "sunsetAt": "2025-01-01",
      "replacedBy": "/v2/users",
      "reason": "API v1 is deprecated. Use v2 for new integrations.",
      "daysUntilSunset": 45
    }
  ],
  "sunsetEndpoints": [],
  "totalDeprecated": 4,
  "totalSunset": 0
}
```

### Get List of Deprecated Endpoints

```bash
curl https://api.cloudtolocalllm.online/api/deprecation/deprecated
```

Response:
```json
{
  "endpoints": [
    {
      "path": "/v1/users",
      "status": "deprecated",
      "deprecatedAt": "2024-01-01",
      "sunsetAt": "2025-01-01",
      "replacedBy": "/v2/users",
      "reason": "API v1 is deprecated. Use v2 for new integrations.",
      "daysUntilSunset": 45
    },
    {
      "path": "/v1/tunnels",
      "status": "deprecated",
      "deprecatedAt": "2024-01-01",
      "sunsetAt": "2025-01-01",
      "replacedBy": "/v2/tunnels",
      "reason": "API v1 is deprecated. Use v2 for new integrations.",
      "daysUntilSunset": 45
    }
  ],
  "count": 4
}
```

### Get Endpoint Deprecation Info

```bash
curl "https://api.cloudtolocalllm.online/api/deprecation/endpoint-info?path=/v1/users"
```

Response:
```json
{
  "path": "/v1/users",
  "status": "deprecated",
  "deprecatedAt": "2024-01-01",
  "sunsetAt": "2025-01-01",
  "replacedBy": "/v2/users",
  "reason": "API v1 is deprecated. Use v2 for new integrations.",
  "migrationGuide": {
    "title": "Migrating from API v1 to v2",
    "steps": [...]
  }
}
```

### Get Migration Guide

```bash
curl https://api.cloudtolocalllm.online/api/deprecation/migration-guide/MIGRATION_V1_TO_V2
```

Response:
```json
{
  "title": "Migrating from API v1 to v2",
  "description": "Complete guide for migrating from CloudToLocalLLM API v1 to v2",
  "steps": [
    {
      "step": 1,
      "title": "Update Base URL",
      "description": "Change your API base URL from /v1 to /v2",
      "before": "https://api.cloudtolocalllm.online/v1/users",
      "after": "https://api.cloudtolocalllm.online/v2/users"
    },
    {
      "step": 2,
      "title": "Update Response Parsing",
      "description": "Update your code to handle the new v2 response format",
      "before": "const email = data.data.userEmail;",
      "after": "const email = data.user.email;"
    },
    {
      "step": 3,
      "title": "Update Error Handling",
      "description": "Update error handling to use the new v2 error format",
      "before": "console.error(error.error);",
      "after": "console.error(error.error.message);"
    },
    {
      "step": 4,
      "title": "Test Thoroughly",
      "description": "Test all API endpoints with v2 before deploying to production",
      "resources": [
        "https://docs.cloudtolocalllm.online/api/v2",
        "https://api.cloudtolocalllm.online/api/docs"
      ]
    }
  ],
  "resources": {
    "documentation": "https://docs.cloudtolocalllm.online/api/migration",
    "apiDocs": "https://api.cloudtolocalllm.online/api/docs",
    "support": "support@cloudtolocalllm.online"
  },
  "timeline": {
    "deprecatedAt": "2024-01-01",
    "sunsetAt": "2025-01-01",
    "daysUntilSunset": 45
  }
}
```

## Migration Guide: v1 to v2

### Step 1: Update Base URL

Change your API base URL from v1 to v2:

**Before (v1):**
```javascript
const baseURL = 'https://api.cloudtolocalllm.online/v1';
```

**After (v2):**
```javascript
const baseURL = 'https://api.cloudtolocalllm.online/v2';
```

### Step 2: Update Response Parsing

Update your code to handle the new v2 response format:

**Before (v1):**
```javascript
const response = await fetch('/v1/users/me');
const data = await response.json();
const email = data.data.userEmail;
const tier = data.data.userTier;
```

**After (v2):**
```javascript
const response = await fetch('/v2/users/me');
const data = await response.json();
const email = data.user.email;
const tier = data.user.tier;
```

### Step 3: Update Error Handling

Update error handling to use the new v2 error format:

**Before (v1):**
```javascript
if (!response.ok) {
  const error = await response.json();
  console.error(error.error);
  console.error(error.errorCode);
}
```

**After (v2):**
```javascript
if (!response.ok) {
  const error = await response.json();
  console.error(error.error.message);
  console.error(error.error.code);
  console.error(error.error.suggestion);
}
```

### Step 4: Update Tunnel Endpoints

**Before (v1):**
```javascript
const tunnels = await fetch('/v1/tunnels');
const data = await tunnels.json();
const tunnelId = data.data[0].tunnelId;
```

**After (v2):**
```javascript
const tunnels = await fetch('/v2/tunnels');
const data = await tunnels.json();
const tunnelId = data.tunnels[0].id;
```

### Step 5: Test Thoroughly

Test all API endpoints with v2 before deploying to production:

```bash
# Test user endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.cloudtolocalllm.online/v2/users/me

# Test tunnels endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.cloudtolocalllm.online/v2/tunnels

# Test admin endpoint
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.cloudtolocalllm.online/v2/admin/users
```

## Sunset Endpoints

When an endpoint reaches its sunset date, it returns a 410 Gone response:

```json
{
  "error": {
    "code": "ENDPOINT_SUNSET",
    "message": "This API endpoint has been removed as of 2025-01-01",
    "statusCode": 410,
    "replacedBy": "/v2/users",
    "suggestion": "Please use /v2/users instead"
  }
}
```

## Best Practices

1. **Monitor Deprecation Headers**: Check for deprecation headers in API responses
2. **Plan Migration Early**: Don't wait until the sunset date to migrate
3. **Use Deprecation Endpoints**: Check `/api/deprecation/status` regularly
4. **Test with v2**: Ensure your integration works with v2 before deploying
5. **Update Documentation**: Keep your API documentation up to date
6. **Set Reminders**: Set calendar reminders for sunset dates
7. **Gradual Migration**: Migrate endpoints gradually, not all at once

## Deprecation Timeline

### Current Deprecations

- **v1 API**: Deprecated 2024-01-01, Sunset 2025-01-01 (45 days remaining)

### Future Deprecations

When v3 is released:
1. v2 will remain current for 12 months
2. v2 will be marked as deprecated
3. v3 will become the default version
4. Migration guides will be provided

## Support

For questions about API deprecation or migration help:

- **Email**: support@cloudtolocalllm.online
- **Documentation**: https://docs.cloudtolocalllm.online
- **API Docs**: https://api.cloudtolocalllm.online/api/docs
- **GitHub Issues**: https://github.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/api/issues

## Implementation Details

### Deprecation Service

The deprecation service manages:
- Deprecated endpoint registry
- Migration guides
- Deprecation status tracking
- Sunset enforcement

### Deprecation Middleware

The deprecation middleware:
- Adds deprecation headers to responses
- Logs deprecation warnings
- Includes deprecation info in response body
- Enforces sunset endpoints

### Deprecation Routes

Deprecation routes provide:
- `/api/deprecation/status` - Overall deprecation status
- `/api/deprecation/deprecated` - List of deprecated endpoints
- `/api/deprecation/sunset` - List of sunset endpoints
- `/api/deprecation/endpoint-info` - Info for specific endpoint
- `/api/deprecation/migration-guide/{id}` - Migration guides

## Monitoring Deprecation

### Logging

All deprecation warnings are logged with:
- Endpoint path
- Request method
- User ID
- Timestamp

### Metrics

Track deprecation usage:
- Number of requests to deprecated endpoints
- Percentage of traffic using deprecated endpoints
- Time until sunset for each endpoint

### Alerts

Set up alerts for:
- Endpoints approaching sunset date
- High traffic to deprecated endpoints
- Sunset endpoint access attempts

</content>
