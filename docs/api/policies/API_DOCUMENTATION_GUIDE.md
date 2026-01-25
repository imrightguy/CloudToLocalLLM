# CloudToLocalLLM API Documentation Guide

## Overview

The CloudToLocalLLM API Backend provides comprehensive REST API endpoints for managing tunnels, users, authentication, and system operations. This guide explains how to access and use the API documentation.

## Accessing API Documentation

### Swagger UI

The interactive Swagger UI is available at:

- **Production**: https://api.cloudtolocalllm.online/api/docs
- **Development**: http://localhost:8080/api/docs

The Swagger UI provides:
- Interactive endpoint exploration
- Request/response examples
- Parameter documentation
- Error code reference
- Try-it-out functionality

### OpenAPI Specification

The raw OpenAPI 3.0 specification is available at:

- **Production**: https://api.cloudtolocalllm.online/api/docs/swagger.json
- **Development**: http://localhost:8080/api/docs/swagger.json

## API Endpoints

### Authentication Endpoints

All authentication endpoints are documented at `/api/docs` under the "Authentication" tag.

#### Token Management

- `POST /auth/token/refresh` - Refresh an expired JWT token
- `POST /auth/token/validate` - Validate a JWT token
- `POST /auth/token/check-expiry` - Check if token needs refresh
- `POST /auth/logout` - Logout and revoke token
- `POST /auth/session/revoke` - Revoke a specific session
- `GET /auth/me` - Get current user information

### User Endpoints

User management endpoints are documented under the "Users" tag.

#### User Profile

- `GET /users/tier` - Get current user's tier information
- `GET /users/:id` - Get user profile
- `PUT /users/:id` - Update user profile
- `DELETE /users/:id` - Delete user account

#### User Activity

- `GET /users/:id/activity` - Get user activity logs
- `GET /users/:id/usage` - Get user usage metrics

### Tunnel Endpoints

Tunnel management endpoints are documented under the "Tunnels" tag.

#### Tunnel Lifecycle

- `POST /tunnels` - Create a new tunnel
- `GET /tunnels` - List user's tunnels
- `GET /tunnels/:id` - Get tunnel details
- `PUT /tunnels/:id` - Update tunnel configuration
- `DELETE /tunnels/:id` - Delete tunnel
- `POST /tunnels/:id/start` - Start tunnel
- `POST /tunnels/:id/stop` - Stop tunnel

#### Tunnel Status and Metrics

- `GET /tunnels/:id/status` - Get tunnel status
- `GET /tunnels/:id/health` - Get tunnel health
- `GET /tunnels/:id/metrics` - Get tunnel metrics
- `GET /tunnels/:id/endpoints` - Get tunnel endpoints

### Webhook Endpoints

Webhook management endpoints are documented under the "Webhooks" tag.

#### Webhook Management

- `POST /webhooks` - Register a webhook
- `GET /webhooks` - List webhooks
- `GET /webhooks/:id` - Get webhook details
- `PUT /webhooks/:id` - Update webhook
- `DELETE /webhooks/:id` - Delete webhook

#### Webhook Events

- `GET /webhooks/:id/events` - Get webhook events
- `POST /webhooks/:id/test` - Send test webhook
- `POST /webhooks/:id/replay` - Replay webhook events

### Admin Endpoints

Administrative endpoints are documented under the "Admin" tag.

#### System Management

- `GET /admin/system/stats` - Get system statistics
- `GET /admin/system/health` - Get system health
- `POST /admin/system/config` - Update system configuration

#### User Management

- `GET /admin/users` - List all users
- `GET /admin/users/:id` - Get user details
- `PUT /admin/users/:id` - Update user
- `DELETE /admin/users/:id` - Delete user

#### Audit and Logging

- `GET /admin/audit` - Get audit logs
- `GET /admin/audit/:id` - Get audit log details

### Monitoring Endpoints

Monitoring endpoints are documented under the "Monitoring" tag.

#### Metrics

- `GET /metrics` - Prometheus metrics endpoint
- `GET /metrics/health` - Metrics collection health

#### Health Checks

- `GET /health` - API health check
- `GET /db/pool/health` - Database pool health
- `GET /db/pool/metrics` - Database pool metrics

## Authentication

### JWT Token Authentication

All protected endpoints require a valid JWT token in the Authorization header:

```
Authorization: Bearer <JWT_TOKEN>
```

### Token Refresh

Tokens expire after a set period. Refresh tokens using:

```bash
curl -X POST https://api.cloudtolocalllm.online/auth/token/refresh \
  -H "Content-Type: application/json" \
  -d '{"refreshToken": "your_refresh_token"}'
```

### API Key Authentication

Service-to-service communication uses API keys:

```
X-API-Key: <API_KEY>
```

## Request/Response Examples

### Example: Create a Tunnel

**Request:**

```bash
curl -X POST https://api.cloudtolocalllm.online/tunnels \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "My Tunnel",
    "config": {
      "maxConnections": 100,
      "timeout": 30000,
      "compression": true
    },
    "endpoints": [
      {
        "url": "http://localhost:8000",
        "priority": 1,
        "weight": 1
      }
    ]
  }'
```

**Response:**

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "userId": "auth0|123456",
  "name": "My Tunnel",
  "status": "created",
  "endpoints": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440001",
      "url": "http://localhost:8000",
      "priority": 1,
      "weight": 1,
      "healthStatus": "unknown"
    }
  ],
  "config": {
    "maxConnections": 100,
    "timeout": 30000,
    "compression": true
  },
  "metrics": {
    "requestCount": 0,
    "successCount": 0,
    "errorCount": 0,
    "averageLatency": 0
  },
  "createdAt": "2024-01-15T10:30:00Z",
  "updatedAt": "2024-01-15T10:30:00Z"
}
```

### Example: Get User Tier Information

**Request:**

```bash
curl -X GET https://api.cloudtolocalllm.online/users/tier \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

**Response:**

```json
{
  "currentTier": "premium",
  "features": [
    {
      "name": "containerOrchestration",
      "enabled": true,
      "description": "Container orchestration and management"
    },
    {
      "name": "teamFeatures",
      "enabled": true,
      "description": "Team collaboration features"
    },
    {
      "name": "apiAccess",
      "enabled": true,
      "description": "API access for integrations"
    }
  ],
  "limits": {
    "maxConnections": 1000,
    "maxModels": 10
  }
}
```

## Error Handling

All errors follow a standard format with error codes and HTTP status codes.

### Error Response Format

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "category": "error_category",
    "statusCode": 400,
    "correlationId": "req-12345-abcde",
    "suggestion": "Suggested action to resolve the error"
  }
}
```

### Common Error Codes

- `INVALID_TOKEN` (401) - Invalid or expired JWT token
- `MISSING_PARAMETER` (400) - Required parameter missing
- `RATE_LIMIT_EXCEEDED` (429) - Rate limit exceeded
- `NOT_FOUND` (404) - Resource not found
- `INTERNAL_ERROR` (500) - Server error

See [API_ERROR_CODES.md](./API_ERROR_CODES.md) for complete error code reference.

## Rate Limiting

The API implements rate limiting to prevent abuse:

- **Default**: 100 requests per minute per user
- **Premium**: 500 requests per minute per user
- **Enterprise**: 2000 requests per minute per user

Rate limit information is included in response headers:

```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1640000000
```

## Pagination

List endpoints support pagination with query parameters:

```
GET /admin/users?page=1&limit=20&sort=createdAt&order=desc
```

### Pagination Parameters

- `page` - Page number (default: 1)
- `limit` - Items per page (default: 20, max: 100)
- `sort` - Sort field (default: createdAt)
- `order` - Sort order: asc or desc (default: desc)

## Filtering

List endpoints support filtering with query parameters:

```
GET /tunnels?status=connected&userId=auth0|123456
```

## Sorting

List endpoints support sorting:

```
GET /tunnels?sort=createdAt&order=desc
```

## Webhooks

### Webhook Events

Webhooks are sent for important events:

- `tunnel.created` - Tunnel created
- `tunnel.started` - Tunnel started
- `tunnel.stopped` - Tunnel stopped
- `tunnel.deleted` - Tunnel deleted
- `user.created` - User created
- `user.updated` - User updated
- `user.deleted` - User deleted

### Webhook Payload

```json
{
  "id": "evt_123456",
  "type": "tunnel.created",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "tunnel": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "My Tunnel",
      "status": "created"
    }
  }
}
```

### Webhook Signature Verification

Webhooks include a signature header for verification:

```
X-Webhook-Signature: sha256=abcdef123456...
```

## SDKs and Client Libraries

Official SDKs are available for:

- **JavaScript/TypeScript**: `@cloudtolocalllm/api-client`
- **Python**: `cloudtolocalllm-api`
- **Go**: `github.com/cloudtolocalllm/api-go`

## API Versioning

The API uses URL-based versioning:

- Current version: `/api/v2/`
- Legacy version: `/api/v1/` (deprecated)

## Best Practices

1. **Always use HTTPS** in production
2. **Store tokens securely** (never in localStorage)
3. **Implement exponential backoff** for retries
4. **Monitor rate limits** and adjust request rate
5. **Use correlation IDs** for debugging
6. **Validate webhook signatures** before processing
7. **Implement proper error handling** for all requests
8. **Keep tokens fresh** by refreshing before expiry

## Support

For API support:

- **Documentation**: https://docs.cloudtolocalllm.online
- **Issues**: https://github.com/ghcr.io/cloudtolocalllm-online/cloudtolocalllm/api/issues
- **Email**: support@cloudtolocalllm.online
- **Discord**: https://discord.gg/cloudtolocalllm

## Changelog

See [CHANGELOG.md](../../../docs/CHANGELOG.md) for API changes and updates.

## License

The CloudToLocalLLM API is licensed under the MIT License.
