# Authentication Audit Logging Implementation

## Overview

This document describes the implementation of comprehensive authentication audit logging for the CloudToLocalLLM API Backend. The implementation provides complete logging of all authentication attempts, successes, and failures with full context including IP address, user agent, and timestamp.

**Validates: Requirements 2.6, 11.10**
- Logs all authentication attempts (success and failure)
- Creates audit log entries for auth events
- Includes IP address, user agent, and timestamp
- Supports admin activity logging and audit trails

## Components Implemented

### 1. Authentication Audit Service (`services/auth-audit-service.js`)

Core service for logging and retrieving authentication events.

**Key Functions:**

- `logAuthEvent(options)` - Log any authentication event with full context
- `logLoginSuccess(options)` - Log successful login
- `logLoginFailure(options)` - Log failed login attempt
- `logLogout(options)` - Log logout event
- `logTokenRefresh(options)` - Log token refresh
- `logTokenRevoke(options)` - Log token revocation
- `logSessionTimeout(options)` - Log session timeout
- `getAuthAuditLogs(userId, options)` - Retrieve user's audit logs
- `getAuthAuditLogsCount(userId, options)` - Count user's audit logs
- `getFailedLoginAttempts(userId, options)` - Get failed login attempts
- `getAuthAuditLogsForAdmin(options)` - Retrieve system-wide audit logs (admin only)
- `getAuthAuditLogsCountForAdmin(options)` - Count system-wide audit logs

**Event Types:**
- `LOGIN` - Successful login
- `LOGOUT` - Logout
- `TOKEN_REFRESH` - Token refresh
- `TOKEN_REVOKE` - Token revocation
- `FAILED_LOGIN` - Failed login attempt
- `PASSWORD_CHANGE` - Password change
- `SESSION_TIMEOUT` - Session timeout

**Severity Levels:**
- `DEBUG` - Debug information
- `INFO` - Informational
- `WARN` - Warning
- `ERROR` - Error
- `CRITICAL` - Critical

### 2. Authentication Audit Middleware (`middleware/auth-audit-middleware.js`)

Middleware for automatically logging authentication events.

**Key Middleware Functions:**

- `authSuccessAuditMiddleware()` - Log successful authentication
- `authFailureAuditMiddleware()` - Log failed authentication
- `logoutAuditMiddleware()` - Log logout events
- `tokenRefreshAuditMiddleware()` - Log token refresh
- `tokenRevokeAuditMiddleware()` - Log token revocation
- `sessionTimeoutAuditMiddleware()` - Log session timeout
- `comprehensiveAuthAuditMiddleware()` - Log all auth events

### 3. Authentication Audit Routes (`routes/auth-audit.js`)

API endpoints for retrieving audit logs.

**User Endpoints:**

- `GET /auth/audit-logs/me` - Get current user's audit logs
  - Query parameters: `limit`, `offset`, `eventType`, `startDate`, `endDate`
  - Returns paginated audit logs for authenticated user

- `GET /auth/audit-logs/failed-attempts` - Get current user's failed login attempts
  - Query parameters: `limit`, `offset`, `startDate`, `endDate`
  - Returns paginated failed login attempts

**Admin Endpoints:**

- `GET /admin/auth/audit-logs` - Get system-wide audit logs (admin only)
  - Query parameters: `limit`, `offset`, `eventType`, `severity`, `startDate`, `endDate`
  - Returns paginated system-wide audit logs

- `GET /admin/auth/audit-logs/failed-attempts` - Get all failed login attempts (admin only)
  - Query parameters: `limit`, `offset`, `startDate`, `endDate`
  - Returns paginated failed login attempts from all users

- `GET /admin/auth/audit-logs/summary` - Get audit logs summary (admin only)
  - Query parameters: `startDate`, `endDate`
  - Returns summary statistics for authentication events

### 4. Integration with Existing Authentication

The audit logging has been integrated into the existing authentication flow:

**In `middleware/auth.js`:**
- Added audit logging for failed JWT validation
- Logs authentication failures with error details

**In `routes/auth.js`:**
- Added audit logging to token refresh endpoint
- Added audit logging to logout endpoint
- Added audit logging to session revocation endpoint
- Logs both successful and failed operations

### 5. Database Schema

The implementation uses the existing `auth_audit_logs` table defined in `database/schema-auth.pg.sql`:

```sql
CREATE TABLE IF NOT EXISTS auth_audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  action TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('login', 'logout', 'token_refresh', 'token_revoke', 'failed_login', 'password_change', 'session_timeout')),
  details JSONB DEFAULT '{}'::jsonb,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  severity TEXT DEFAULT 'info' CHECK (severity IN ('debug', 'info', 'warn', 'error', 'critical'))
);
```

**Indexes:**
- `idx_auth_audit_logs_user_id` - For user-specific queries
- `idx_auth_audit_logs_event_type` - For event type filtering
- `idx_auth_audit_logs_created_at` - For time-based queries

## Usage Examples

### Logging Authentication Events

```javascript
import { logLoginSuccess, logLoginFailure } from './services/auth-audit-service.js';

// Log successful login
await logLoginSuccess({
  userId: 'user-123',
  ipAddress: '192.168.1.100',
  userAgent: 'Mozilla/5.0...',
  details: { provider: 'auth0' }
});

// Log failed login
await logLoginFailure({
  email: 'user@example.com',
  ipAddress: '192.168.1.100',
  userAgent: 'Mozilla/5.0...',
  reason: 'Invalid credentials'
});
```

### Retrieving Audit Logs

```javascript
import { getAuthAuditLogs, getFailedLoginAttempts } from './services/auth-audit-service.js';

// Get user's audit logs
const logs = await getAuthAuditLogs('user-123', {
  limit: 50,
  offset: 0,
  eventType: 'login'
});

// Get failed login attempts
const failedAttempts = await getFailedLoginAttempts('user-123', {
  limit: 50,
  offset: 0
});
```

### API Usage

```bash
# Get current user's audit logs
curl -H "Authorization: Bearer <token>" \
  https://api.cloudtolocalllm.online/auth/audit-logs/me

# Get failed login attempts
curl -H "Authorization: Bearer <token>" \
  https://api.cloudtolocalllm.online/auth/audit-logs/failed-attempts

# Get system-wide audit logs (admin only)
curl -H "Authorization: Bearer <admin-token>" \
  https://api.cloudtolocalllm.online/admin/auth/audit-logs

# Get audit logs summary (admin only)
curl -H "Authorization: Bearer <admin-token>" \
  https://api.cloudtolocalllm.online/admin/auth/audit-logs/summary
```

## Testing

Comprehensive tests are provided in `test/api-backend/auth-audit.test.js`:

**Test Coverage:**

1. **Service Tests:**
   - Logging authentication events
   - Logging login success/failure
   - Logging logout, token refresh, token revocation
   - Retrieving audit logs with filtering and pagination
   - Counting audit logs
   - Getting failed login attempts
   - Admin audit log retrieval

2. **Property-Based Tests:**
   - **Property 2: JWT validation round trip** - Audit log details are preserved on round trip
   - **Property 3: Permission enforcement consistency** - Correct event types are logged consistently
   - **Audit log immutability** - IP address and user agent are preserved exactly

**Running Tests:**

```bash
npm test -- test/api-backend/auth-audit.test.js
```

## Security Considerations

1. **Audit Log Immutability:** Audit logs are append-only and cannot be modified
2. **User Privacy:** Users can only view their own audit logs
3. **Admin Access:** Admins can view system-wide audit logs
4. **IP Address Logging:** All authentication events include the client IP address
5. **User Agent Logging:** All authentication events include the user agent string
6. **Timestamp Precision:** All events are timestamped with microsecond precision
7. **Sensitive Data:** Passwords and tokens are never logged

## Performance Considerations

1. **Indexes:** Proper indexes are created for efficient querying
2. **Pagination:** All endpoints support pagination to limit result sets
3. **Async Logging:** Audit logging is non-blocking and doesn't affect authentication performance
4. **Error Handling:** Audit logging failures don't break authentication

## Monitoring and Alerting

The audit logs can be monitored for:

1. **Failed Login Attempts:** Track brute force attacks
2. **Unusual Activity:** Monitor for suspicious patterns
3. **Token Refresh Frequency:** Detect potential token abuse
4. **Session Timeouts:** Track session management issues
5. **Admin Actions:** Monitor administrative access

## Future Enhancements

1. **Real-time Alerts:** Alert on suspicious authentication patterns
2. **Audit Log Retention:** Implement retention policies
3. **Audit Log Export:** Export audit logs for compliance
4. **Audit Log Analysis:** Analyze patterns and trends
5. **Integration with SIEM:** Send audit logs to security information and event management systems

## Compliance

This implementation helps meet compliance requirements for:

- **GDPR:** User activity tracking and audit trails
- **HIPAA:** Authentication and access logging
- **SOC 2:** Security event logging and monitoring
- **PCI DSS:** Authentication and access control logging
- **ISO 27001:** Information security event logging

## References

- Requirements 2.6: Log all authentication attempts and failures
- Requirements 11.10: Support admin activity logging and audit trails
- Database Schema: `database/schema-auth.pg.sql`
- Authentication Middleware: `middleware/auth.js`
- Authentication Routes: `routes/auth.js`
