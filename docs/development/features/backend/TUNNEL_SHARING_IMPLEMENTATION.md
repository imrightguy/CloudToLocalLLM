# Tunnel Sharing and Access Control - Implementation Summary

## Task 18: Implement tunnel sharing and access control

**Requirement**: 4.8 - THE API SHALL support tunnel sharing and access control

**Status**: ✅ COMPLETE

## Implementation Overview

This implementation provides comprehensive tunnel sharing capabilities with granular permission management, temporary share tokens, and complete audit trails.

## Files Created

### 1. Database Migration

**File**: `services/api-backend/database/migrations/005_tunnel_sharing_and_access_control.sql`

Creates three new tables:

- `tunnel_shares`: Direct user-to-user sharing with permissions
- `tunnel_share_tokens`: Temporary tokens for link-based sharing
- `tunnel_access_logs`: Audit trail for all access operations

Includes proper indexes for performance optimization.

### 2. Service Layer

**File**: `services/api-backend/services/tunnel-sharing-service.js`

Implements `TunnelSharingService` class with methods:

- `shareTunnel()`: Share tunnel with another user
- `revokeTunnelAccess()`: Revoke access from a user
- `getTunnelShares()`: Get all shares for a tunnel
- `getSharedTunnels()`: Get tunnels shared with a user
- `createShareToken()`: Create temporary share token
- `revokeShareToken()`: Revoke a share token
- `getShareTokens()`: Get all tokens for a tunnel
- `verifyTunnelAccess()`: Verify user has required permission
- `getTunnelAccessLogs()`: Get audit trail
- `updateSharePermission()`: Update share permission level

### 3. API Routes

**File**: `services/api-backend/routes/tunnel-sharing.js`

Implements 9 endpoints:

- `POST /api/tunnels/:id/shares` - Share tunnel
- `GET /api/tunnels/:id/shares` - Get tunnel shares
- `DELETE /api/tunnels/:id/shares/:sharedWithUserId` - Revoke access
- `GET /api/tunnels/shared-with-me` - Get shared tunnels
- `POST /api/tunnels/:id/share-tokens` - Create token
- `GET /api/tunnels/:id/share-tokens` - Get tokens
- `DELETE /api/tunnels/:id/share-tokens/:tokenId` - Revoke token
- `GET /api/tunnels/:id/access-logs` - Get access logs
- `PUT /api/tunnels/:id/shares/:shareId/permission` - Update permission

### 4. Tests

**File**: `test/api-backend/tunnel-sharing.test.js`

Comprehensive test suite covering:

- Sharing tunnels with valid/invalid users
- Permission validation
- Token creation and revocation
- Access verification
- Access log tracking
- Permission updates
- Error cases

### 5. Documentation

**Files**:

- `services/api-backend/TUNNEL_SHARING_QUICK_REFERENCE.md` - Quick reference guide
- `services/api-backend/TUNNEL_SHARING_IMPLEMENTATION.md` - This file

## Key Features

### 1. Permission Levels

Three permission levels with hierarchical access:

- **read**: View tunnel details, status, metrics, configuration
- **write**: All read permissions + update config, start/stop tunnel
- **admin**: All write permissions + delete tunnel, manage shares

### 2. User-to-User Sharing

Direct sharing with specific users:

- Share tunnel with another user
- Set permission level
- Update permission level
- Revoke access
- View who has access

### 3. Temporary Share Tokens

Time-limited tokens for link-based sharing:

- Generate random 256-bit tokens
- Set expiration time (hours)
- Optional maximum uses limit
- Revoke tokens
- Track token usage

### 4. Access Control

Comprehensive access verification:

- Owner has admin access
- Shared users have specified permission
- Permission hierarchy enforcement
- Expiration checking
- Active status checking

### 5. Audit Trail

Complete access logging:

- Log all sharing operations
- Log permission changes
- Log token creation/revocation
- Include IP address and user agent
- Queryable access logs

## Database Schema

### tunnel_shares

```sql
CREATE TABLE tunnel_shares (
  id UUID PRIMARY KEY,
  tunnel_id UUID NOT NULL REFERENCES tunnels(id),
  owner_id UUID NOT NULL REFERENCES users(id),
  shared_with_user_id UUID NOT NULL REFERENCES users(id),
  permission VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  is_active BOOLEAN DEFAULT true,
  UNIQUE (tunnel_id, owner_id, shared_with_user_id)
);
```

### tunnel_share_tokens

```sql
CREATE TABLE tunnel_share_tokens (
  id UUID PRIMARY KEY,
  tunnel_id UUID NOT NULL REFERENCES tunnels(id),
  owner_id UUID NOT NULL REFERENCES users(id),
  token VARCHAR(255) NOT NULL UNIQUE,
  permission VARCHAR(50) NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  is_active BOOLEAN DEFAULT true,
  max_uses INTEGER,
  use_count INTEGER DEFAULT 0
);
```

### tunnel_access_logs

```sql
CREATE TABLE tunnel_access_logs (
  id UUID PRIMARY KEY,
  tunnel_id UUID NOT NULL REFERENCES tunnels(id),
  user_id UUID NOT NULL REFERENCES users(id),
  action VARCHAR(50) NOT NULL,
  permission VARCHAR(50),
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## API Endpoints

### Share Tunnel

```
POST /api/tunnels/:id/shares
Authorization: Bearer <token>

Request:
{
  "sharedWithUserId": "user-uuid",
  "permission": "read|write|admin"
}

Response: 201 Created
{
  "success": true,
  "data": {
    "id": "share-uuid",
    "tunnelId": "tunnel-uuid",
    "ownerId": "owner-uuid",
    "sharedWithUserId": "user-uuid",
    "permission": "read",
    "createdAt": "2024-01-01T00:00:00Z"
  }
}
```

### Get Tunnel Shares

```
GET /api/tunnels/:id/shares
Authorization: Bearer <token>

Response: 200 OK
{
  "success": true,
  "data": [
    {
      "id": "share-uuid",
      "tunnel_id": "tunnel-uuid",
      "shared_with_user_id": "user-uuid",
      "shared_with_email": "user@example.com",
      "permission": "read",
      "is_active": true,
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### Revoke Access

```
DELETE /api/tunnels/:id/shares/:sharedWithUserId
Authorization: Bearer <token>

Response: 200 OK
{
  "success": true,
  "message": "Tunnel access revoked successfully"
}
```

### Get Shared Tunnels

```
GET /api/tunnels/shared-with-me?limit=50&offset=0
Authorization: Bearer <token>

Response: 200 OK
{
  "success": true,
  "data": [
    {
      "id": "tunnel-uuid",
      "name": "Tunnel Name",
      "status": "connected",
      "permission": "read",
      "owner_id": "owner-uuid",
      "owner_email": "owner@example.com"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0
  }
}
```

### Create Share Token

```
POST /api/tunnels/:id/share-tokens
Authorization: Bearer <token>

Request:
{
  "permission": "read|write|admin",
  "expiresInHours": 24,
  "maxUses": 10 (optional)
}

Response: 201 Created
{
  "success": true,
  "data": {
    "id": "token-uuid",
    "token": "hex-string-64-chars",
    "tunnelId": "tunnel-uuid",
    "permission": "read",
    "expiresAt": "2024-01-02T00:00:00Z",
    "maxUses": 10
  }
}
```

### Get Share Tokens

```
GET /api/tunnels/:id/share-tokens
Authorization: Bearer <token>

Response: 200 OK
{
  "success": true,
  "data": [
    {
      "id": "token-uuid",
      "tunnel_id": "tunnel-uuid",
      "permission": "read",
      "created_at": "2024-01-01T00:00:00Z",
      "expires_at": "2024-01-02T00:00:00Z",
      "is_active": true,
      "max_uses": 10,
      "use_count": 0
    }
  ]
}
```

### Revoke Token

```
DELETE /api/tunnels/:id/share-tokens/:tokenId
Authorization: Bearer <token>

Response: 200 OK
{
  "success": true,
  "message": "Share token revoked successfully"
}
```

### Get Access Logs

```
GET /api/tunnels/:id/access-logs?limit=50&offset=0
Authorization: Bearer <token>

Response: 200 OK
{
  "success": true,
  "data": [
    {
      "id": "log-uuid",
      "tunnel_id": "tunnel-uuid",
      "user_id": "user-uuid",
      "action": "share",
      "permission": "read",
      "ip_address": "192.168.1.1",
      "user_agent": "Mozilla/5.0...",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0
  }
}
```

### Update Permission

```
PUT /api/tunnels/:id/shares/:shareId/permission
Authorization: Bearer <token>

Request:
{
  "permission": "write"
}

Response: 200 OK
{
  "success": true,
  "data": {
    "id": "share-uuid",
    "permission": "write",
    "updatedAt": "2024-01-01T00:00:00Z"
  }
}
```

## Error Handling

All endpoints return appropriate HTTP status codes:

- `201 Created`: Successful creation
- `200 OK`: Successful operation
- `400 Bad Request`: Invalid input
- `401 Unauthorized`: Missing authentication
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `409 Conflict`: Resource already exists
- `500 Internal Server Error`: Server error

Error responses include:

```json
{
  "error": "Error type",
  "code": "ERROR_CODE",
  "message": "Human-readable message"
}
```

## Security Features

1. **Permission Hierarchy**: Enforced permission levels (read < write < admin)
2. **Token Security**: 256-bit random tokens using crypto.randomBytes()
3. **Expiration**: All tokens have mandatory expiration times
4. **Audit Trail**: Complete logging of all access operations
5. **Ownership Verification**: Only tunnel owner can manage shares
6. **Soft Delete**: Revoked shares marked inactive, not deleted
7. **Input Validation**: All inputs validated before processing
8. **SQL Injection Prevention**: Parameterized queries throughout

## Testing

Run tests:

```bash
npm test -- tunnel-sharing.test.js
```

Test coverage includes:

- ✅ Sharing tunnels with valid users
- ✅ Rejecting invalid users
- ✅ Preventing self-sharing
- ✅ Permission validation
- ✅ Token creation and revocation
- ✅ Access verification
- ✅ Permission hierarchy
- ✅ Access log tracking
- ✅ Permission updates
- ✅ Error cases

## Integration Points

### With Tunnel Service

- Verify tunnel ownership before sharing
- Cascade delete shares when tunnel is deleted
- Include sharing info in tunnel responses

### With Auth Service

- Verify user authentication on all endpoints
- Extract user ID from JWT token
- Log user actions with IP and user agent

### With Activity Logging

- Log all sharing operations
- Track permission changes
- Maintain audit trail

## Performance Considerations

1. **Indexes**: Created on frequently queried columns
   - `tunnel_shares(tunnel_id, owner_id, shared_with_user_id)`
   - `tunnel_share_tokens(tunnel_id, token)`
   - `tunnel_access_logs(tunnel_id, created_at)`

2. **Query Optimization**:
   - Efficient permission checking
   - Pagination support for large result sets
   - Proper use of database constraints

3. **Caching Opportunities**:
   - Cache user's shared tunnels
   - Cache tunnel shares list
   - Invalidate on updates

## Future Enhancements

1. **Group Sharing**: Share with groups of users
2. **Role-Based Sharing**: Predefined role templates
3. **Conditional Sharing**: Share based on conditions
4. **Sharing Analytics**: Track sharing patterns
5. **Notification System**: Notify users of shares
6. **Expiring Shares**: Auto-expire shares after time
7. **Share Requests**: Users request access
8. **Delegation**: Share permission to manage shares

## Compliance

✅ Requirement 4.8: THE API SHALL support tunnel sharing and access control

- Provides endpoints for tunnel sharing
- Implements access control with permissions
- Adds permission management for tunnel access

## Validation

All acceptance criteria met:

- ✅ Create tunnel sharing endpoints
- ✅ Implement access control for shared tunnels
- ✅ Add permission management for tunnel access
