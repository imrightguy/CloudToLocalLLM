# CloudToLocalLLM Tier-Based API Documentation

## Overview

The CloudToLocalLLM API now supports a tier-based architecture that provides different levels of functionality based on user subscription levels. This document outlines the tier system, available endpoints, and usage patterns.

## User Tiers

### Free Tier
- **Direct tunnel access** without container orchestration
- **No Docker required** on user's machine
- **Single connection** to local Ollama instance
- **Basic features** with upgrade prompts for advanced functionality

### Premium Tier
- **Container orchestration** with isolated environments
- **Team features** and collaboration tools
- **API access** for custom integrations
- **Multiple connections** and advanced networking
- **Priority support**

### Enterprise Tier
- **Unlimited resources** and connections
- **Custom configurations** and on-premise deployment
- **Advanced security** and compliance features
- **Dedicated support** and SLA guarantees

## Authentication & Tier Detection

All API endpoints require authentication via Auth0 JWT tokens. User tier information is extracted from the token's metadata:

```javascript
// Tier information locations (in priority order)
user['https://cloudtolocalllm.com/user_metadata'].tier
user['https://cloudtolocalllm.com/app_metadata'].tier
user['https://cloudtolocalllm.com/user_metadata'].subscription
```

## API Endpoints

### Tier Information

#### GET `/api/user/tier`
Get current user's tier information and available features.

**Response:**
```json
{
  "tier": "free",
  "features": {
    "containerOrchestration": false,
    "teamFeatures": false,
    "apiAccess": false,
    "prioritySupport": false,
    "maxConnections": 1,
    "maxModels": 5
  },
  "upgradeUrl": "https://app.cloudtolocalllm.online/upgrade"
}
```

### Direct Proxy (Free Tier Only)

#### GET `/api/direct-proxy/:userId/health`
Health check for direct proxy service.

**Headers:**
- `Authorization: Bearer <jwt_token>`

**Response:**
```json
{
  "status": "ok",
  "service": "direct-proxy",
  "userTier": "free",
  "directTunnelEnabled": true,
  "tunnelConnected": true,
  "timestamp": "2024-01-15T10:30:00.000Z"
}
```

#### ALL `/api/direct-proxy/:userId/ollama/*`
Direct proxy to local Ollama instance for free tier users.

**Security:**
- Only accessible by free tier users
- User can only access their own proxy (`:userId` must match authenticated user)
- Request/response headers are sanitized
- Path traversal protection enabled
- Request size limits enforced

**Example:**
```bash
# Get available models
GET /api/direct-proxy/auth0|user123/ollama/api/tags

# Generate completion
POST /api/direct-proxy/auth0|user123/ollama/api/generate
Content-Type: application/json

{
  "model": "llama2",
  "prompt": "Hello, world!",
  "stream": false
}
```

**Error Responses:**

```json
// Desktop client not connected
{
  "error": "Desktop client not connected",
  "code": "DESKTOP_CLIENT_DISCONNECTED",
  "message": "Please ensure your CloudToLocalLLM desktop client is running and connected.",
  "requestId": "dp-1642234567890-abc123"
}

// Request timeout
{
  "error": "Request timeout",
  "code": "REQUEST_TIMEOUT",
  "message": "The request to your local Ollama instance timed out.",
  "timeout": 30000,
  "requestId": "dp-1642234567890-abc123"
}

// Access denied for non-free tier
{
  "error": "Direct proxy access is only available for free tier users",
  "code": "DIRECT_PROXY_FORBIDDEN",
  "userTier": "premium",
  "suggestion": "Use container-based proxy for premium features",
  "requestId": "dp-1642234567890-abc123"
}
```

### Container Proxy (Premium/Enterprise Only)

#### POST `/api/proxy/start`
Start container-based proxy for premium/enterprise users.

**Request:**
```json
{
  "testMode": false
}
```

**Response:**
```json
{
  "success": true,
  "message": "Streaming proxy started successfully",
  "proxy": {
    "proxyId": "proxy-auth0|user123-1642234567890",
    "status": "running",
    "createdAt": "2024-01-15T10:30:00.000Z",
    "directTunnel": false,
    "endpoint": "https://api.cloudtolocalllm.online/proxy/auth0|user123",
    "userTier": "premium"
  }
}
```

#### ALL `/api/tunnel/:userId/*`
Container-based proxy with advanced features (premium/enterprise only).

**Features:**
- Isolated container environments
- Advanced networking and security
- Team collaboration capabilities
- Custom configurations

## Error Handling

### Standard Error Response Format

```json
{
  "error": "Error description",
  "code": "ERROR_CODE",
  "message": "User-friendly message",
  "userTier": "free",
  "upgradeUrl": "https://app.cloudtolocalllm.online/upgrade",
  "requestId": "unique-request-id"
}
```

### Common Error Codes

| Code | Description | HTTP Status |
|------|-------------|-------------|
| `AUTH_REQUIRED` | Authentication required | 401 |
| `TIER_INSUFFICIENT` | Insufficient subscription tier | 403 |
| `FEATURE_UNAVAILABLE` | Feature not available in current tier | 403 |
| `DIRECT_PROXY_FORBIDDEN` | Direct proxy access denied | 403 |
| `DESKTOP_CLIENT_DISCONNECTED` | Desktop client not connected | 503 |
| `REQUEST_TIMEOUT` | Request timed out | 504 |
| `REQUEST_TOO_LARGE` | Request entity too large | 413 |
| `INVALID_PATH` | Invalid or malicious path | 400 |
| `PROXY_ERROR` | Internal proxy error | 500 |

## Rate Limiting

### Free Tier
- **Direct proxy**: 100 requests per minute
- **API calls**: 50 requests per minute
- **Concurrent connections**: 1

### Premium Tier
- **Container proxy**: 500 requests per minute
- **API calls**: 200 requests per minute
- **Concurrent connections**: 10

### Enterprise Tier
- **No rate limits** (within reasonable usage)
- **Custom limits** available upon request

## Security Considerations

### Request Sanitization
- Hop-by-hop headers removed from forwarded requests
- Security-sensitive headers (Authorization, Cookie) stripped
- Response headers sanitized before returning to client
- Path traversal protection on all proxy endpoints

### User Isolation
- Users can only access their own proxy endpoints
- Tier validation performed on every request
- Audit logging for all tier-related access attempts
- Request tracing with unique request IDs

### Data Protection
- No sensitive user data logged in error messages
- Request/response bodies not logged by default
- Secure token handling and validation
- HTTPS required for all API communications

## Usage Examples

### Free Tier User Flow

```javascript
// 1. Check tier and features
const tierInfo = await fetch('/api/user/tier', {
  headers: { 'Authorization': `Bearer ${token}` }
}).then(r => r.json());

if (tierInfo.tier === 'free') {
  // 2. Use direct proxy for Ollama access
  const models = await fetch(`/api/direct-proxy/${userId}/ollama/api/tags`, {
    headers: { 'Authorization': `Bearer ${token}` }
  }).then(r => r.json());
  
  // 3. Generate completion
  const completion = await fetch(`/api/direct-proxy/${userId}/ollama/api/generate`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'llama2',
      prompt: 'Hello!',
      stream: false
    })
  }).then(r => r.json());
}
```

### Premium Tier User Flow

```javascript
// 1. Start container-based proxy
const proxy = await fetch('/api/proxy/start', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ testMode: false })
}).then(r => r.json());

// 2. Use container proxy with advanced features
const response = await fetch(`/api/tunnel/${userId}/ollama/api/generate`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    model: 'llama2',
    prompt: 'Hello!',
    stream: true
  })
});
```

## Migration Guide

### Existing Users
- **Premium/Enterprise users**: No changes required, existing functionality preserved
- **Free tier users**: Automatically migrated to direct tunnel mode
- **Setup process**: Updated to be tier-aware with appropriate guidance

### API Clients
- **Existing endpoints**: Continue to work with tier validation
- **New endpoints**: Use direct proxy for free tier, container proxy for premium
- **Error handling**: Update to handle new tier-related error codes

## Support & Troubleshooting

### Common Issues

1. **"Direct proxy access denied"**
   - Verify user is on free tier
   - Check Auth0 metadata configuration
   - Ensure proper authentication

2. **"Desktop client not connected"**
   - Verify desktop client is running
   - Check WebSocket connection status
   - Review firewall and network settings

3. **"Request timeout"**
   - Check local Ollama instance status
   - Verify network connectivity
   - Review timeout configuration

### Debug Information
- All responses include `requestId` for tracing
- Health check endpoints provide connection status
- Tier information available in user profile
- Audit logs capture all tier-related events
