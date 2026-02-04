# API Key Authentication Implementation

## Overview

This document describes the API key authentication system for Zoidbot API Backend. API keys enable service-to-service communication with secure, scoped access control.

**Requirements: 2.8**

- Support API key authentication for service-to-service communication
- Implement API key rotation and revocation
- Add API key middleware for service endpoints

## Architecture

### Components

1. **API Key Service** (`services/api-key-service.js`)
   - Generate API keys with cryptographic security
   - Validate API keys against database
   - Manage key lifecycle (rotation, revocation)
   - Track audit logs for compliance

2. **API Key Middleware** (`middleware/api-key-auth.js`)
   - Authenticate requests using API keys
   - Support multiple header formats
   - Enforce rate limiting per key
   - Check scopes and permissions

3. **API Key Routes** (`routes/api-keys.js`)
   - REST endpoints for key management
   - CRUD operations for API keys
   - Audit log retrieval
   - Key rotation and revocation

4. **Database Schema** (`database/migrations/001_create_api_keys_table.sql`)
   - `api_keys` table for storing key metadata
   - `api_key_audit_logs` table for tracking usage

## API Key Format

API keys follow this format:

```
ctll_<64-character-hex-string>
```

Example:

```
ctll_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2
```

### Key Components

- **Prefix**: `ctll_` (identifies Zoidbot API keys)
- **Random Bytes**: 32 bytes (256 bits) of cryptographically secure random data
- **Encoding**: Hexadecimal (64 characters)

### Security

- Keys are hashed using SHA-256 before storage
- Only the key prefix (first 8 characters) is displayed in UI
- Full key is only returned once at creation time
- Keys are never logged or displayed after creation

## Database Schema

### api_keys Table

```sql
CREATE TABLE api_keys (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  name TEXT NOT NULL,
  key_hash TEXT UNIQUE NOT NULL,  -- SHA-256 hash
  key_prefix TEXT NOT NULL,       -- First 8 chars for display
  description TEXT,
  scopes TEXT[] DEFAULT ARRAY[]::TEXT[],
  rate_limit INTEGER DEFAULT 1000,
  is_active BOOLEAN DEFAULT true,
  last_used_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  rotation_required BOOLEAN DEFAULT false,
  rotated_from_id UUID REFERENCES api_keys(id)
);
```

### api_key_audit_logs Table

```sql
CREATE TABLE api_key_audit_logs (
  id UUID PRIMARY KEY,
  api_key_id UUID NOT NULL REFERENCES api_keys(id),
  user_id UUID NOT NULL REFERENCES users(id),
  action TEXT NOT NULL,  -- 'created', 'used', 'rotated', 'revoked', 'expired'
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## API Endpoints

### Generate API Key

**POST** `/api/api-keys`

Request:

```json
{
  "name": "Production API Key",
  "description": "For production service-to-service communication",
  "scopes": ["read", "write"],
  "rateLimit": 1000,
  "expiresIn": 2592000000
}
```

Response (201):

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "apiKey": "ctll_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2",
  "keyPrefix": "ctll_a1b2",
  "name": "Production API Key",
  "description": "For production service-to-service communication",
  "scopes": ["read", "write"],
  "rateLimit": 1000,
  "isActive": true,
  "createdAt": "2024-01-15T10:30:00Z",
  "expiresAt": "2024-02-14T10:30:00Z"
}
```

### List API Keys

**GET** `/api/api-keys`

Response (200):

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Production API Key",
    "keyPrefix": "ctll_a1b2",
    "description": "For production service-to-service communication",
    "scopes": ["read", "write"],
    "rateLimit": 1000,
    "isActive": true,
    "createdAt": "2024-01-15T10:30:00Z",
    "updatedAt": "2024-01-15T10:30:00Z",
    "expiresAt": "2024-02-14T10:30:00Z",
    "lastUsedAt": "2024-01-15T11:45:00Z"
  }
]
```

### Get API Key Details

**GET** `/api/api-keys/:keyId`

Response (200): Same as list item above

### Update API Key

**PATCH** `/api/api-keys/:keyId`

Request:

```json
{
  "name": "Updated Key Name",
  "description": "Updated description",
  "scopes": ["read"],
  "rateLimit": 500
}
```

Response (200): Updated API key object

### Rotate API Key

**POST** `/api/api-keys/:keyId/rotate`

Response (200):

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440001",
  "apiKey": "ctll_b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2g3",
  "keyPrefix": "ctll_b2c3",
  "name": "Production API Key",
  "description": "For production service-to-service communication",
  "scopes": ["read", "write"],
  "rateLimit": 1000,
  "isActive": true,
  "createdAt": "2024-01-15T11:00:00Z",
  "expiresAt": "2024-02-14T10:30:00Z"
}
```

### Revoke API Key

**POST** `/api/api-keys/:keyId/revoke`

Response (200):

```json
{
  "message": "API key revoked successfully"
}
```

### Get Audit Logs

**GET** `/api/api-keys/:keyId/audit-logs`

Response (200):

```json
[
  {
    "id": "550e8400-e29b-41d4-a716-446655440002",
    "action": "created",
    "details": {
      "name": "Production API Key",
      "scopes": ["read", "write"],
      "rateLimit": 1000
    },
    "createdAt": "2024-01-15T10:30:00Z"
  },
  {
    "id": "550e8400-e29b-41d4-a716-446655440003",
    "action": "used",
    "details": {
      "timestamp": "2024-01-15T11:45:00Z"
    },
    "createdAt": "2024-01-15T11:45:00Z"
  }
]
```

## Authentication with API Keys

### Using API Keys in Requests

API keys can be provided in two ways:

#### 1. Authorization Header (Recommended)

```bash
curl -H "Authorization: Bearer ctll_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2" \
  https://api.zoidbot.online/api/tunnels
```

#### 2. X-API-Key Header

```bash
curl -H "X-API-Key: ctll_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6a7b8c9d0e1f2" \
  https://api.zoidbot.online/api/tunnels
```

### Middleware Usage

```javascript
import { authenticateApiKey, requireApiKeyScope, rateLimitByApiKey } from './middleware/api-key-auth.js';

// Require API key authentication
app.post('/api/protected', authenticateApiKey, (req, res) => {
  // req.apiKey contains key metadata
  // req.userId contains the user ID
  res.json({ message: 'Success' });
});

// Require specific scopes
app.post('/api/admin', 
  authenticateApiKey,
  requireApiKeyScope(['admin']),
  (req, res) => {
    res.json({ message: 'Admin operation' });
  }
);

// Apply rate limiting
app.use(rateLimitByApiKey());
```

## Scopes

Scopes define what operations an API key can perform. Common scopes:

- `read` - Read-only access to resources
- `write` - Create and update resources
- `delete` - Delete resources
- `admin` - Administrative operations
- `tunnels:read` - Read tunnel information
- `tunnels:write` - Create and manage tunnels
- `webhooks:read` - Read webhook configurations
- `webhooks:write` - Create and manage webhooks

## Rate Limiting

Each API key has a configurable rate limit (default: 1000 requests/minute).

Rate limit headers are included in responses:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1705329600
```

When rate limit is exceeded:

```
HTTP/1.1 429 Too Many Requests

{
  "error": "API key rate limit exceeded",
  "code": "API_KEY_RATE_LIMIT_EXCEEDED",
  "retryAfter": 45
}
```

## Key Rotation

Key rotation is the process of replacing an old API key with a new one while maintaining the same metadata and scopes.

### Rotation Process

1. Old key is marked as inactive
2. New key is generated with same metadata
3. New key is linked to old key via `rotated_from_id`
4. Audit log entries are created for both keys
5. Services should update to use new key

### Best Practices

- Rotate keys regularly (e.g., every 90 days)
- Rotate immediately if key is compromised
- Update services to use new key before old key expires
- Monitor audit logs for unauthorized access

## Expiration

API keys can be configured to expire after a specified time period.

- Expired keys are automatically marked as inactive
- Validation checks expiration date
- Audit log entry is created when key expires
- Services should rotate keys before expiration

## Audit Logging

All API key operations are logged for compliance and security:

- **created**: Key was generated
- **used**: Key was used to authenticate a request
- **rotated**: Key was rotated (old key revoked, new key created)
- **revoked**: Key was manually revoked
- **expired**: Key automatically expired

Audit logs include:

- Action performed
- Timestamp
- User ID
- API key ID
- Additional details (scopes, rate limit, etc.)

## Security Best Practices

1. **Never commit API keys to version control**
   - Use environment variables or secure vaults
   - Add `.env` files to `.gitignore`

2. **Rotate keys regularly**
   - Implement automated rotation policies
   - Rotate immediately if compromised

3. **Use minimal scopes**
   - Grant only necessary permissions
   - Use separate keys for different services

4. **Monitor usage**
   - Review audit logs regularly
   - Set up alerts for unusual activity
   - Track last_used_at timestamps

5. **Secure storage**
   - Store keys in secure vaults (e.g., HashiCorp Vault)
   - Use encrypted environment variables
   - Never log full API keys

6. **Rate limiting**
   - Set appropriate rate limits per key
   - Monitor for rate limit violations
   - Adjust limits based on usage patterns

## Error Handling

### Missing API Key

```json
{
  "error": "API key required",
  "code": "MISSING_API_KEY",
  "message": "Provide API key via Authorization header or X-API-Key header"
}
```

### Invalid API Key

```json
{
  "error": "Invalid or expired API key",
  "code": "INVALID_API_KEY"
}
```

### Insufficient Scopes

```json
{
  "error": "Insufficient API key scopes",
  "code": "INSUFFICIENT_SCOPES",
  "requiredScopes": ["admin"]
}
```

### Rate Limit Exceeded

```json
{
  "error": "API key rate limit exceeded",
  "code": "API_KEY_RATE_LIMIT_EXCEEDED",
  "retryAfter": 45
}
```

## Testing

Run the API key tests:

```bash
npm test -- test/api-backend/api-keys.test.js
```

Tests cover:

- API key generation and validation
- Key rotation and revocation
- Scope enforcement
- Rate limiting
- Audit logging
- Error handling
- Middleware functionality

## Migration Guide

### For Existing Services

1. Generate API keys for each service
2. Update service configuration with API keys
3. Update request headers to include API key
4. Test authentication with new keys
5. Monitor audit logs for successful authentication
6. Remove old authentication methods

### Example Migration

Before:

```javascript
const response = await fetch('https://api.zoidbot.online/api/tunnels', {
  headers: {
    'Authorization': `Bearer ${jwtToken}`
  }
});
```

After:

```javascript
const response = await fetch('https://api.zoidbot.online/api/tunnels', {
  headers: {
    'X-API-Key': apiKey
  }
});
```

## Troubleshooting

### Key Not Working

1. Verify key format starts with `ctll_`
2. Check if key is active (not revoked or expired)
3. Verify scopes include required permissions
4. Check rate limit hasn't been exceeded
5. Review audit logs for error details

### Rate Limit Issues

1. Check current rate limit: `GET /api/api-keys/:keyId`
2. Increase rate limit: `PATCH /api/api-keys/:keyId` with higher `rateLimit`
3. Monitor usage patterns
4. Consider using separate keys for different services

### Audit Log Issues

1. Verify user has permission to view logs
2. Check key ID is correct
3. Ensure key exists and belongs to user
4. Review database for audit log entries

## Future Enhancements

- IP whitelisting per API key
- Custom rate limit schedules
- Webhook notifications for key events
- API key templates for common use cases
- Integration with external secret management systems
- Automatic key rotation policies
