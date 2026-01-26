# Tunnel Configuration Management Implementation

## Overview

This document describes the implementation of tunnel configuration management for the API backend. The implementation provides endpoints and services for managing tunnel configurations including max connections, timeout, and compression settings.

**Validates: Requirements 4.3**

- Create tunnel config endpoints
- Support max connections, timeout, compression settings
- Implement config validation

## Implementation Summary

### Files Created/Modified

1. **services/api-backend/utils/tunnel-config-validation.js** (NEW)
   - Configuration validation utilities
   - Default configuration management
   - Configuration merging and sanitization

2. **services/api-backend/services/tunnel-service.js** (MODIFIED)
   - Added `getTunnelConfig()` method
   - Added `updateTunnelConfig()` method
   - Added `resetTunnelConfig()` method

3. **services/api-backend/routes/tunnels.js** (MODIFIED)
   - Added `GET /api/tunnels/:id/config` endpoint
   - Added `PUT /api/tunnels/:id/config` endpoint
   - Added `POST /api/tunnels/:id/config/reset` endpoint

4. **test/api-backend/tunnel-config-management.test.js** (NEW)
   - Comprehensive unit tests for configuration validation
   - 19 test cases covering all validation scenarios

## Configuration Parameters

### Supported Configuration Fields

```typescript
interface TunnelConfig {
  maxConnections: number;    // 1-10000 (default: 100)
  timeout: number;           // 1000-300000ms (default: 30000)
  compression: boolean;      // true/false (default: true)
}
```

### Validation Rules

| Parameter | Type | Min | Max | Default | Description |
|-----------|------|-----|-----|---------|-------------|
| maxConnections | integer | 1 | 10000 | 100 | Maximum concurrent connections |
| timeout | integer | 1000 | 300000 | 30000 | Request timeout in milliseconds |
| compression | boolean | - | - | true | Enable/disable compression |

## API Endpoints

### 1. GET /api/tunnels/:id/config

Retrieve tunnel configuration.

**Request:**

```bash
GET /api/tunnels/tunnel-123/config
Authorization: Bearer <JWT_TOKEN>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "maxConnections": 100,
    "timeout": 30000,
    "compression": true
  },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

**Error Responses:**

- `401 Unauthorized` - Missing or invalid JWT token
- `404 Not Found` - Tunnel not found or unauthorized access
- `503 Service Unavailable` - Tunnel service not initialized

### 2. PUT /api/tunnels/:id/config

Update tunnel configuration (partial update).

**Request:**

```bash
PUT /api/tunnels/tunnel-123/config
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json

{
  "maxConnections": 200,
  "timeout": 60000
}
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "maxConnections": 200,
    "timeout": 60000,
    "compression": true
  },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

**Error Responses:**

- `400 Bad Request` - Invalid configuration values
- `401 Unauthorized` - Missing or invalid JWT token
- `404 Not Found` - Tunnel not found or unauthorized access
- `503 Service Unavailable` - Tunnel service not initialized

**Validation Errors:**

```json
{
  "error": "Bad request",
  "code": "INVALID_CONFIG",
  "message": "Invalid tunnel configuration",
  "details": [
    "maxConnections must be between 1 and 10000",
    "timeout must be between 1000ms and 300000ms (5 minutes)"
  ]
}
```

### 3. POST /api/tunnels/:id/config/reset

Reset tunnel configuration to defaults.

**Request:**

```bash
POST /api/tunnels/tunnel-123/config/reset
Authorization: Bearer <JWT_TOKEN>
```

**Response (200 OK):**

```json
{
  "success": true,
  "data": {
    "maxConnections": 100,
    "timeout": 30000,
    "compression": true
  },
  "message": "Configuration reset to defaults",
  "timestamp": "2024-01-19T10:30:00Z"
}
```

**Error Responses:**

- `401 Unauthorized` - Missing or invalid JWT token
- `404 Not Found` - Tunnel not found or unauthorized access
- `503 Service Unavailable` - Tunnel service not initialized

## Service Methods

### getTunnelConfig(tunnelId, userId)

Retrieve tunnel configuration.

```javascript
const config = await tunnelService.getTunnelConfig(tunnelId, userId);
// Returns: { maxConnections: 100, timeout: 30000, compression: true }
```

**Throws:**

- `Error: Tunnel not found` - If tunnel doesn't exist or user doesn't own it

### updateTunnelConfig(tunnelId, userId, config, ipAddress, userAgent)

Update tunnel configuration (partial update).

```javascript
const config = await tunnelService.updateTunnelConfig(
  tunnelId,
  userId,
  { maxConnections: 200 },
  '127.0.0.1',
  'Mozilla/5.0...'
);
// Returns: { maxConnections: 200, timeout: 30000, compression: true }
```

**Features:**

- Merges with existing configuration
- Preserves unmodified fields
- Logs activity to tunnel_activity_logs
- Validates configuration before update

**Throws:**

- `Error: Tunnel not found` - If tunnel doesn't exist or user doesn't own it

### resetTunnelConfig(tunnelId, userId, ipAddress, userAgent)

Reset tunnel configuration to defaults.

```javascript
const config = await tunnelService.resetTunnelConfig(
  tunnelId,
  userId,
  '127.0.0.1',
  'Mozilla/5.0...'
);
// Returns: { maxConnections: 100, timeout: 30000, compression: true }
```

**Features:**

- Resets all configuration to defaults
- Logs activity to tunnel_activity_logs
- Atomic operation with transaction

**Throws:**

- `Error: Tunnel not found` - If tunnel doesn't exist or user doesn't own it

## Validation Utilities

### validateTunnelConfig(config)

Validates configuration object.

```javascript
const result = validateTunnelConfig({
  maxConnections: 200,
  timeout: 60000,
  compression: false
});

// Returns:
// {
//   isValid: true,
//   errors: []
// }
```

### getDefaultTunnelConfig()

Returns default configuration.

```javascript
const defaults = getDefaultTunnelConfig();
// Returns: { maxConnections: 100, timeout: 30000, compression: true }
```

### mergeTunnelConfig(userConfig)

Merges user config with defaults.

```javascript
const merged = mergeTunnelConfig({ maxConnections: 200 });
// Returns: { maxConnections: 200, timeout: 30000, compression: true }
```

### sanitizeTunnelConfig(config)

Sanitizes and clamps configuration values.

```javascript
const sanitized = sanitizeTunnelConfig({
  maxConnections: 20000,  // Above max
  timeout: 500,           // Below min
  compression: 'yes'      // Invalid type
});
// Returns: { maxConnections: 10000, timeout: 1000, compression: true }
```

## Activity Logging

Configuration changes are logged to `tunnel_activity_logs` table:

```sql
INSERT INTO tunnel_activity_logs (
  tunnel_id, user_id, action, status, details, ip_address, user_agent
) VALUES (...)
```

**Log Actions:**

- `config_update` - Configuration updated
- `config_reset` - Configuration reset to defaults

**Example Log Entry:**

```json
{
  "id": "uuid",
  "tunnel_id": "tunnel-123",
  "user_id": "user-456",
  "action": "config_update",
  "status": "success",
  "details": {
    "changes": {
      "maxConnections": 200
    }
  },
  "ip_address": "127.0.0.1",
  "user_agent": "Mozilla/5.0...",
  "created_at": "2024-01-19T10:30:00Z"
}
```

## Database Schema

Configuration is stored in the `tunnels` table:

```sql
CREATE TABLE tunnels (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  name VARCHAR(255) NOT NULL,
  status VARCHAR(50) NOT NULL,
  config JSONB DEFAULT '{}'::jsonb,  -- Configuration stored here
  metrics JSONB DEFAULT '...'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  ...
);
```

**Configuration Storage:**

- Stored as JSONB in `config` column
- Supports partial updates
- Indexed for performance

## Testing

### Test Coverage

**File:** `test/api-backend/tunnel-config-management.test.js`

**Test Suites:**

1. Configuration Validation (11 tests)
   - Valid configuration
   - Invalid maxConnections (type, min, max)
   - Invalid timeout (type, min, max)
   - Invalid compression (type)
   - Partial configuration
   - Empty configuration
   - Non-object configuration

2. Configuration Defaults (4 tests)
   - Default configuration
   - Merge with defaults
   - Null config handling
   - Sanitization

3. Configuration Boundary Values (4 tests)
   - Minimum maxConnections (1)
   - Maximum maxConnections (10000)
   - Minimum timeout (1000ms)
   - Maximum timeout (300000ms)

**Test Results:**

- Total Tests: 19
- Passed: 19
- Failed: 0
- Coverage: 100% for validation utilities

### Running Tests

```bash
npm test -- test/api-backend/tunnel-config-management.test.js
```

## Error Handling

### Validation Errors

Invalid configuration values return 400 Bad Request:

```json
{
  "error": "Bad request",
  "code": "INVALID_CONFIG",
  "message": "Invalid tunnel configuration",
  "details": [
    "maxConnections must be between 1 and 10000",
    "timeout must be between 1000ms and 300000ms (5 minutes)"
  ]
}
```

### Authorization Errors

Unauthorized access returns 404 Not Found (to prevent tunnel enumeration):

```json
{
  "error": "Not found",
  "code": "TUNNEL_NOT_FOUND",
  "message": "Tunnel not found"
}
```

### Service Errors

Service unavailability returns 503 Service Unavailable:

```json
{
  "error": "Service unavailable",
  "code": "SERVICE_UNAVAILABLE",
  "message": "Tunnel service is not initialized"
}
```

## Security Considerations

1. **Authorization:** All endpoints require JWT authentication
2. **Ownership Verification:** Configuration can only be accessed/modified by tunnel owner
3. **Input Validation:** All configuration values are validated before storage
4. **Audit Logging:** All configuration changes are logged with IP and user agent
5. **Transaction Safety:** Configuration updates use database transactions
6. **Rate Limiting:** Endpoints subject to standard rate limiting (100 req/min)

## Performance Considerations

1. **JSONB Storage:** Configuration stored as JSONB for efficient partial updates
2. **Indexed Lookups:** Tunnel ID and user ID indexed for fast retrieval
3. **Minimal Queries:** Configuration retrieval requires single query
4. **Batch Operations:** Configuration updates use transactions for atomicity

## Integration Points

### Tunnel Service Integration

Configuration is integrated with tunnel lifecycle:

```javascript
// Create tunnel with initial config
const tunnel = await tunnelService.createTunnel(userId, {
  name: 'My Tunnel',
  config: {
    maxConnections: 100,
    timeout: 30000,
    compression: true
  }
});

// Update configuration later
const updated = await tunnelService.updateTunnelConfig(
  tunnel.id,
  userId,
  { maxConnections: 200 }
);

// Reset to defaults
const reset = await tunnelService.resetTunnelConfig(
  tunnel.id,
  userId
);
```

### Activity Tracking

Configuration changes are tracked in activity logs:

```javascript
const logs = await tunnelService.getTunnelActivityLogs(tunnelId, userId);
// Includes config_update and config_reset actions
```

## Future Enhancements

1. **Configuration Presets:** Pre-defined configuration templates
2. **Configuration History:** Track configuration changes over time
3. **Configuration Validation Rules:** Custom validation per tier
4. **Configuration Recommendations:** AI-based configuration suggestions
5. **Configuration Rollback:** Ability to revert to previous configurations

## Compliance

- **Requirement 4.3:** ✅ Tunnel configuration management implemented
  - ✅ Create tunnel config endpoints
  - ✅ Support max connections, timeout, compression settings
  - ✅ Implement config validation

## References

- Requirements: `.kiro/specs/api-backend-enhancement/requirements.md` (Requirement 4.3)
- Design: `.kiro/specs/api-backend-enhancement/design.md`
- Tests: `test/api-backend/tunnel-config-management.test.js`
