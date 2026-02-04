# API Versioning Strategy

## Overview

Zoidbot API implements URL-based versioning to support multiple API versions simultaneously while maintaining backward compatibility. This guide explains how versioning works and how to migrate between versions.

**Requirements: 12.4**

## Versioning Strategy

### URL-Based Versioning

The API uses URL path prefixes to specify the API version:

```
/v1/endpoint  - API version 1 (deprecated)
/v2/endpoint  - API version 2 (current)
/endpoint     - Defaults to v2 (current)
```

### Supported Versions

| Version | Status | Description | Sunset Date |
|---------|--------|-------------|------------|
| v1 | Deprecated | Legacy API version | 2025-01-01 |
| v2 | Current | Current stable version | N/A |

## Using API Versions

### Version 2 (Current)

Use v2 for all new integrations. This is the recommended version.

```bash
# Using explicit v2 prefix
curl https://api.zoidbot.online/v2/users/me \
  -H "Authorization: Bearer YOUR_TOKEN"

# Using default (also v2)
curl https://api.zoidbot.online/users/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Version 1 (Deprecated)

v1 is deprecated and will be removed on 2025-01-01. Migrate to v2 as soon as possible.

```bash
# Using v1 (deprecated)
curl https://api.zoidbot.online/v1/users/me \
  -H "Authorization: Bearer YOUR_TOKEN"
```

## Version Headers

All API responses include version information in headers:

```
API-Version: v2
API-Version-Status: current
```

### Deprecation Headers

Deprecated versions include additional headers:

```
Deprecation: true
Sunset: Wed, 01 Jan 2025 00:00:00 GMT
Warning: 299 - "API version v1 is deprecated. Migrate to v2 before 2025-01-01"
```

## Response Format Differences

### Version 1 (Deprecated)

```json
{
  "success": true,
  "data": {
    "userId": "123",
    "userEmail": "user@example.com",
    "userTier": "premium"
  }
}
```

### Version 2 (Current)

```json
{
  "user": {
    "id": "123",
    "email": "user@example.com",
    "tier": "premium",
    "profile": {
      "firstName": "John",
      "lastName": "Doe"
    }
  }
}
```

## Error Response Differences

### Version 1 (Deprecated)

```json
{
  "success": false,
  "error": "User not found",
  "errorCode": "USER_NOT_FOUND"
}
```

### Version 2 (Current)

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

## Migration Guide

### Step 1: Update Base URL

Change your API base URL from:

```
https://api.zoidbot.online/v1
```

To:

```
https://api.zoidbot.online/v2
```

Or simply use:

```
https://api.zoidbot.online
```

### Step 2: Update Response Parsing

Update your code to handle the new v2 response format:

**Before (v1):**

```javascript
const response = await fetch('/v1/users/me');
const data = await response.json();
const email = data.data.userEmail;
```

**After (v2):**

```javascript
const response = await fetch('/v2/users/me');
const data = await response.json();
const email = data.user.email;
```

### Step 3: Update Error Handling

Update error handling to use the new v2 error format:

**Before (v1):**

```javascript
if (!response.ok) {
  const error = await response.json();
  console.error(error.error);
}
```

**After (v2):**

```javascript
if (!response.ok) {
  const error = await response.json();
  console.error(error.error.message);
  console.error(error.error.suggestion);
}
```

### Step 4: Test Thoroughly

Test all API endpoints with v2 before deploying to production.

## Backward Compatibility

### Automatic Fallback

If you don't specify a version in the URL, the API automatically uses v2:

```bash
# These are equivalent
curl https://api.zoidbot.online/users/me
curl https://api.zoidbot.online/v2/users/me
```

### Version-Specific Behavior

Some endpoints may have different behavior in different versions:

- **v1**: Legacy response format, limited features
- **v2**: Current response format, all features

## API Version Information Endpoint

Get information about all supported API versions:

```bash
curl https://api.zoidbot.online/api/versions
```

Response:

```json
{
  "currentVersion": "v2",
  "defaultVersion": "v2",
  "supportedVersions": [
    {
      "version": "v1",
      "status": "deprecated",
      "description": "Legacy API version - use v2 for new integrations",
      "deprecatedAt": "2024-01-01",
      "sunsetAt": "2025-01-01"
    },
    {
      "version": "v2",
      "status": "current",
      "description": "Current stable API version"
    }
  ],
  "timestamp": "2024-11-20T10:00:00Z"
}
```

## Best Practices

1. **Always use v2 for new integrations** - v1 is deprecated and will be removed
2. **Check deprecation headers** - Monitor for deprecation warnings in responses
3. **Plan migration early** - Don't wait until the sunset date to migrate
4. **Test with v2** - Ensure your integration works with v2 before deploying
5. **Update documentation** - Keep your API documentation up to date with the version you're using

## Deprecation Timeline

- **2024-01-01**: v1 marked as deprecated
- **2025-01-01**: v1 will be removed (sunset date)

## Support

For questions about API versioning or migration help, contact:

- Email: support@zoidbot.online
- Documentation: https://docs.zoidbot.online
- GitHub Issues: https://github.com/ghcr.io/zoidbot-online/zoidbot/api/issues

## Implementation Details

### Versioning Middleware

The API uses middleware to:

1. Extract version from URL path
2. Validate version is supported
3. Add version info to request object
4. Add deprecation headers if needed
5. Route to version-specific handlers

### Version Routing

Routes are registered under version-specific paths:

- `/v1/endpoint` - v1 handler
- `/v2/endpoint` - v2 handler
- `/endpoint` - defaults to v2 handler

### Response Transformation

Response format is automatically transformed based on the requested version:

- v1 requests get v1 response format
- v2 requests get v2 response format

## Future Versions

When v3 is released:

1. v2 will remain current for 12 months
2. v2 will be marked as deprecated
3. v3 will become the default version
4. Migration guides will be provided

This ensures a smooth transition path for all API consumers.
