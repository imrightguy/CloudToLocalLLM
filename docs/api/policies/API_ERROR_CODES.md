# CloudToLocalLLM API Error Codes and HTTP Status Codes

This document provides a comprehensive reference for all error codes and HTTP status codes used in the CloudToLocalLLM API Backend.

## HTTP Status Codes

### 2xx Success Codes

| Code | Name | Description |
|------|------|-------------|
| 200 | OK | Request succeeded |
| 201 | Created | Resource created successfully |
| 204 | No Content | Request succeeded with no content to return |

### 4xx Client Error Codes

| Code | Name | Description |
|------|------|-------------|
| 400 | Bad Request | Invalid request format or missing required parameters |
| 401 | Unauthorized | Authentication required or invalid credentials |
| 403 | Forbidden | Authenticated but insufficient permissions |
| 404 | Not Found | Requested resource not found |
| 429 | Too Many Requests | Rate limit exceeded |

### 5xx Server Error Codes

| Code | Name | Description |
|------|------|-------------|
| 500 | Internal Server Error | Unexpected server error |
| 503 | Service Unavailable | Service temporarily unavailable or dependencies down |

## Error Categories and Codes

### Authentication Errors (401)

| Code | Message | Description | Resolution |
|------|---------|-------------|-----------|
| MISSING_TOKEN | Token required | No authentication token provided | Provide valid JWT token in Authorization header |
| INVALID_TOKEN | Invalid token format | Token format is invalid | Ensure token is properly formatted |
| INVALID_TOKEN_FORMAT | Invalid token format | Token cannot be decoded | Provide valid JWT token |
| TOKEN_EXPIRED | Token expired | JWT token has expired | Refresh token using /auth/token/refresh |
| TOKEN_REFRESH_FAILED | Token refresh failed | Unable to refresh token | Check refresh token validity |
| TOKEN_REFRESH_ERROR | Token refresh failed | Error during token refresh | Retry or re-authenticate |
| INVALID_REFRESH_TOKEN | Invalid refresh token format | Refresh token format is invalid | Provide valid refresh token |
| MISSING_REFRESH_TOKEN | Refresh token required | No refresh token provided | Provide refresh token in request body or cookie |
| AUTH_REQUIRED | Authentication required | Endpoint requires authentication | Authenticate with valid JWT token |
| HTTPS_REQUIRED | HTTPS required | Authentication endpoints require HTTPS | Use HTTPS in production |

### Authorization Errors (403)

| Code | Message | Description | Resolution |
|------|---------|-------------|-----------|
| INSUFFICIENT_PERMISSIONS | Insufficient permissions | User lacks required permissions | Request admin to grant permissions |
| ADMIN_REQUIRED | Admin access required | Endpoint requires admin role | Use admin account |
| TIER_FEATURE_UNAVAILABLE | Feature not available for tier | Feature not available in user's tier | Upgrade to higher tier |
| RATE_LIMIT_EXEMPTION_DENIED | Rate limit exemption denied | User not eligible for exemption | Contact support |

### Validation Errors (400)

| Code | Message | Description | Resolution |
|------|---------|-------------|-----------|
| MISSING_PARAMETER | Missing required parameter | Required parameter not provided | Include all required parameters |
| INVALID_PARAMETER | Invalid parameter value | Parameter value is invalid | Provide valid parameter value |
| INVALID_EMAIL | Invalid email format | Email format is invalid | Provide valid email address |
| INVALID_URL | Invalid URL format | URL format is invalid | Provide valid URL |
| INVALID_JSON | Invalid JSON format | Request body is not valid JSON | Provide valid JSON |
| VALIDATION_ERROR | Validation failed | Input validation failed | Check error details for specific issues |
| MISSING_SESSION_ID | Session ID required | Session ID not provided | Provide valid session ID |
| INVALID_TUNNEL_CONFIG | Invalid tunnel configuration | Tunnel configuration is invalid | Check configuration parameters |

### Resource Not Found Errors (404)

| Code | Message | Description | Resolution |
|------|---------|-------------|-----------|
| NOT_FOUND | Resource not found | Requested resource does not exist | Verify resource ID |
| USER_NOT_FOUND | User not found | User does not exist | Check user ID |
| TUNNEL_NOT_FOUND | Tunnel not found | Tunnel does not exist | Check tunnel ID |
| SESSION_NOT_FOUND | Session not found | Session does not exist | Create new session |
| WEBHOOK_NOT_FOUND | Webhook not found | Webhook does not exist | Check webhook ID |

### Rate Limiting Errors (429)

| Code | Message | Description | Resolution |
|------|---------|-------------|-----------|
| RATE_LIMIT_EXCEEDED | Rate limit exceeded | Too many requests | Wait before retrying |
| RATE_LIMIT_EXCEEDED_USER | Rate limit exceeded for user | User rate limit exceeded | Wait or upgrade tier |
| RATE_LIMIT_EXCEEDED_IP | Rate limit exceeded for IP | IP rate limit exceeded | Wait before retrying |
| QUOTA_EXCEEDED | Quota exceeded | Resource quota exceeded | Upgrade tier or wait for reset |

### Server Errors (500)

| Code | Message | Description | Resolution |
|------|---------|-------------|-----------|
| INTERNAL_ERROR | Internal server error | Unexpected server error | Retry or contact support |
| DATABASE_ERROR | Database error | Database operation failed | Retry or contact support |
| SERVICE_ERROR | Service error | External service error | Retry or contact support |
| CONFIGURATION_ERROR | Configuration error | Server configuration error | Contact support |

### Service Unavailable Errors (503)

| Code | Message | Description | Resolution |
|------|---------|-------------|-----------|
| SERVICE_UNAVAILABLE | Service unavailable | Service temporarily unavailable | Retry after delay |
| DATABASE_UNAVAILABLE | Database unavailable | Database is unavailable | Wait for database recovery |
| CACHE_UNAVAILABLE | Cache unavailable | Cache service is unavailable | Retry or use fallback |
| EXTERNAL_SERVICE_UNAVAILABLE | External service unavailable | External service is down | Wait for service recovery |

## Error Response Format

All error responses follow this standard format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "category": "error_category",
    "statusCode": 400,
    "correlationId": "req-12345-abcde",
    "suggestion": "Suggested action to resolve the error",
    "details": {
      "field": "Additional error details"
    }
  }
}
```

### Error Response Fields

| Field | Type | Description |
|-------|------|-------------|
| code | string | Machine-readable error code |
| message | string | Human-readable error message |
| category | string | Error category (validation, authentication, authorization, not_found, rate_limit, server, service_unavailable) |
| statusCode | integer | HTTP status code |
| correlationId | string | Request correlation ID for tracing |
| suggestion | string | Suggested action to resolve the error |
| details | object | Additional error details (optional) |

## Error Categories

### Validation Errors

- Invalid input format
- Missing required parameters
- Invalid parameter values
- Constraint violations

### Authentication Errors

- Missing or invalid tokens
- Expired tokens
- Invalid credentials
- Token refresh failures

### Authorization Errors

- Insufficient permissions
- Role-based access denied
- Tier-based feature restrictions
- Admin-only operations

### Not Found Errors

- Resource does not exist
- User not found
- Tunnel not found
- Session not found

### Rate Limit Errors

- User rate limit exceeded
- IP rate limit exceeded
- Quota exceeded
- Request queued

### Server Errors

- Unexpected exceptions
- Database errors
- External service errors
- Configuration errors

### Service Unavailable Errors

- Service temporarily down
- Database unavailable
- Cache unavailable
- External dependencies down

## Rate Limit Headers

All responses include rate limit information in headers:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000
```

### Rate Limit Header Fields

| Header | Description |
|--------|-------------|
| X-RateLimit-Limit | Maximum requests per window |
| X-RateLimit-Remaining | Remaining requests in current window |
| X-RateLimit-Reset | Unix timestamp when limit resets |

## Retry Strategy

### Retryable Errors

The following errors should be retried with exponential backoff:

- 429 (Rate Limit Exceeded)
- 503 (Service Unavailable)
- 500 (Internal Server Error) - with caution
- 504 (Gateway Timeout)

### Non-Retryable Errors

The following errors should NOT be retried:

- 400 (Bad Request)
- 401 (Unauthorized)
- 403 (Forbidden)
- 404 (Not Found)

## Example Error Responses

### Authentication Error

```json
{
  "error": {
    "code": "INVALID_TOKEN",
    "message": "Invalid token format",
    "category": "authentication",
    "statusCode": 401,
    "correlationId": "req-12345-abcde",
    "suggestion": "Ensure token is properly formatted and not expired"
  }
}
```

### Validation Error

```json
{
  "error": {
    "code": "MISSING_PARAMETER",
    "message": "Missing required parameter",
    "category": "validation",
    "statusCode": 400,
    "correlationId": "req-12345-abcde",
    "suggestion": "Include all required parameters in request",
    "details": {
      "missingFields": ["name", "email"]
    }
  }
}
```

### Rate Limit Error

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded",
    "category": "rate_limit",
    "statusCode": 429,
    "correlationId": "req-12345-abcde",
    "suggestion": "Wait before retrying",
    "details": {
      "retryAfter": 60
    }
  }
}
```

### Server Error

```json
{
  "error": {
    "code": "INTERNAL_ERROR",
    "message": "Internal server error",
    "category": "server",
    "statusCode": 500,
    "correlationId": "req-12345-abcde",
    "suggestion": "Retry or contact support if problem persists"
  }
}
```

## Best Practices

1. **Always include correlation IDs** in error logs for tracing
2. **Use appropriate HTTP status codes** for error categorization
3. **Provide actionable suggestions** in error messages
4. **Include relevant details** for debugging
5. **Implement exponential backoff** for retryable errors
6. **Log all errors** with full context
7. **Monitor error rates** for anomalies
8. **Document custom error codes** in API documentation

## Support

For questions about error codes or to report issues, contact support at support@cloudtolocalllm.online.
