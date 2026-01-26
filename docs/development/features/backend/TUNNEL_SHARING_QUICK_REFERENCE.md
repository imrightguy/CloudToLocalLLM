# Tunnel Sharing and Access Control - Quick Reference

## Overview

Tunnel sharing allows users to grant other users access to their tunnels with granular permission control. This implementation provides:

- **User-to-user sharing** with permission levels (read, write, admin)
- **Temporary share tokens** for time-limited access
- **Access logs** for audit trails
- **Permission management** with ability to update or revoke access

## Database Schema

### tunnel_shares

Manages direct user-to-user tunnel sharing:

- `id`: Share ID (UUID)
- `tunnel_id`: Tunnel being shared
- `owner_id`: User who owns the tunnel
- `shared_with_user_id`: User receiving access
- `permission`: Access level (read, write, admin)
- `is_active`: Whether share is active
- `expires_at`: Optional expiration time

### tunnel_share_tokens

Manages temporary share tokens for link-based sharing:

- `id`: Token ID (UUID)
- `tunnel_id`: Tunnel being shared
- `owner_id`: User who created the token
- `token`: Random token string (32 bytes hex)
- `permission`: Access level
- `expires_at`: Token expiration time
- `max_uses`: Optional maximum uses
- `use_count`: Current use count

### tunnel_access_logs

Audit trail for all tunnel access operations:

- `id`: Log ID (UUID)
- `tunnel_id`: Tunnel being accessed
- `user_id`: User performing action
- `action`: Action type (share, revoke, create_token, etc.)
- `permission`: Permission level (if applicable)
- `ip_address`: Client IP
- `user_agent`: Client user agent

## API Endpoints

### Share Tunnel with User

```
POST /api/tunnels/:id/shares
Authorization: Bearer <token>

Request:
{
  "sharedWithUserId": "user-uuid",
  "permission": "read" | "write" | "admin"
}

Response:
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

Response:
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

### Revoke Tunnel Access

```
DELETE /api/tunnels/:id/shares/:sharedWithUserId
Authorization: Bearer <token>

Response:
{
  "success": true,
  "message": "Tunnel access revoked successfully"
}
```

### Get Shared Tunnels

```
GET /api/tunnels/shared-with-me?limit=50&offset=0
Authorization: Bearer <token>

Response:
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
  "permission": "read" | "write" | "admin",
  "expiresInHours": 24,
  "maxUses": 10 (optional)
}

Response:
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

Response:
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

### Revoke Share Token

```
DELETE /api/tunnels/:id/share-tokens/:tokenId
Authorization: Bearer <token>

Response:
{
  "success": true,
  "message": "Share token revoked successfully"
}
```

### Get Access Logs

```
GET /api/tunnels/:id/access-logs?limit=50&offset=0
Authorization: Bearer <token>

Response:
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

### Update Share Permission

```
PUT /api/tunnels/:id/shares/:shareId/permission
Authorization: Bearer <token>

Request:
{
  "permission": "write"
}

Response:
{
  "success": true,
  "data": {
    "id": "share-uuid",
    "permission": "write",
    "updatedAt": "2024-01-01T00:00:00Z"
  }
}
```

## Permission Levels

### read

- View tunnel details
- View tunnel status and metrics
- View tunnel configuration
- Cannot modify tunnel

### write

- All read permissions
- Update tunnel configuration
- Start/stop tunnel
- Cannot delete tunnel
- Cannot manage shares

### admin

- All write permissions
- Delete tunnel
- Manage shares (share/revoke)
- Create share tokens
- View access logs

## Service Methods

### TunnelSharingService

```javascript
// Share tunnel with user
shareTunnel(tunnelId, ownerId, sharedWithUserId, permission, ipAddress, userAgent)

// Get tunnel shares
getTunnelShares(tunnelId, ownerId)

// Revoke tunnel access
revokeTunnelAccess(tunnelId, ownerId, sharedWithUserId, ipAddress, userAgent)

// Create share token
createShareToken(tunnelId, ownerId, permission, expiresInHours, maxUses, ipAddress, userAgent)

// Get share tokens
getShareTokens(tunnelId, ownerId)

// Revoke share token
revokeShareToken(tokenId, ownerId, ipAddress, userAgent)

// Get tunnels shared with user
getSharedTunnels(userId, options)

// Verify tunnel access
verifyTunnelAccess(tunnelId, userId, requiredPermission)

// Get access logs
getTunnelAccessLogs(tunnelId, ownerId, options)

// Update share permission
updateSharePermission(shareId, ownerId, newPermission, ipAddress, userAgent)
```

## Usage Examples

### Share a tunnel

```javascript
const share = await tunnelSharingService.shareTunnel(
  'tunnel-123',
  'owner-456',
  'user-789',
  'read',
  '192.168.1.1',
  'Mozilla/5.0'
);
```

### Create a temporary share link

```javascript
const token = await tunnelSharingService.createShareToken(
  'tunnel-123',
  'owner-456',
  'read',
  24,  // expires in 24 hours
  10,  // max 10 uses
  '192.168.1.1',
  'Mozilla/5.0'
);

// Share link: https://app.example.com/share/token?token=<token.token>
```

### Verify access before operation

```javascript
const access = await tunnelSharingService.verifyTunnelAccess(
  'tunnel-123',
  'user-456',
  'write'  // required permission
);

if (!access.hasAccess) {
  throw new Error('Insufficient permissions');
}
```

## Security Considerations

1. **Permission Hierarchy**: admin > write > read
2. **Token Security**: Tokens are 32-byte random hex strings (256 bits)
3. **Expiration**: Share tokens have mandatory expiration times
4. **Audit Trail**: All access operations are logged
5. **Ownership Verification**: Only tunnel owner can manage shares
6. **Active Status**: Revoked shares are marked inactive, not deleted

## Testing

Run tests with:

```bash
npm test -- tunnel-sharing.test.js
```

Tests cover:

- Sharing tunnels with valid/invalid users
- Permission validation
- Token creation and revocation
- Access verification
- Access log tracking
- Permission updates
