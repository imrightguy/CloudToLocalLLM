# Authentication Audit Logging - Quick Reference

## Files Created/Modified

### New Files

- `services/auth-audit-service.js` - Core audit logging service
- `middleware/auth-audit-middleware.js` - Audit logging middleware
- `routes/auth-audit.js` - Audit log retrieval endpoints
- `test/api-backend/auth-audit.test.js` - Comprehensive tests

### Modified Files

- `middleware/auth.js` - Added audit logging for failed authentication
- `routes/auth.js` - Added audit logging to auth endpoints

## Key Functions

### Logging Events

```javascript
import { 
  logLoginSuccess, 
  logLoginFailure, 
  logLogout,
  logTokenRefresh,
  logTokenRevoke 
} from './services/auth-audit-service.js';

// Log successful login
await logLoginSuccess({
  userId: 'user-id',
  ipAddress: req.ip,
  userAgent: req.get('User-Agent')
});

// Log failed login
await logLoginFailure({
  email: 'user@example.com',
  ipAddress: req.ip,
  userAgent: req.get('User-Agent'),
  reason: 'Invalid credentials'
});
```

### Retrieving Logs

```javascript
import { 
  getAuthAuditLogs,
  getFailedLoginAttempts,
  getAuthAuditLogsForAdmin 
} from './services/auth-audit-service.js';

// Get user's logs
const logs = await getAuthAuditLogs(userId, {
  limit: 50,
  offset: 0,
  eventType: 'login'
});

// Get failed attempts
const failed = await getFailedLoginAttempts(userId);

// Get admin logs
const adminLogs = await getAuthAuditLogsForAdmin({
  limit: 100,
  eventType: 'failed_login'
});
```

## API Endpoints

### User Endpoints

- `GET /auth/audit-logs/me` - User's audit logs
- `GET /auth/audit-logs/failed-attempts` - User's failed login attempts

### Admin Endpoints

- `GET /admin/auth/audit-logs` - System-wide audit logs
- `GET /admin/auth/audit-logs/failed-attempts` - All failed login attempts
- `GET /admin/auth/audit-logs/summary` - Audit logs summary

## Event Types

- `login` - Successful login
- `logout` - Logout
- `token_refresh` - Token refresh
- `token_revoke` - Token revocation
- `failed_login` - Failed login attempt
- `password_change` - Password change
- `session_timeout` - Session timeout

## Database Table

```sql
CREATE TABLE auth_audit_logs (
  id UUID PRIMARY KEY,
  user_id TEXT,
  action TEXT,
  event_type TEXT,
  details JSONB,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ,
  severity TEXT
);
```

## Testing

```bash
npm test -- test/api-backend/auth-audit.test.js
```

## Integration Points

### In Authentication Middleware

- Failed JWT validation is logged
- Authentication errors include full context

### In Auth Routes

- Token refresh is logged
- Logout is logged
- Session revocation is logged

## Requirements Met

✅ **Requirement 2.6:** Log all authentication attempts and failures

- All login attempts (success and failure) are logged
- Full context included (IP, user agent, timestamp)

✅ **Requirement 11.10:** Support admin activity logging and audit trails

- Admin endpoints for viewing system-wide audit logs
- Audit log summary statistics
- Failed login attempt tracking

## Property-Based Tests

1. **JWT Validation Round Trip** - Audit log details preserved
2. **Permission Enforcement Consistency** - Correct event types logged
3. **Audit Log Immutability** - IP and user agent preserved exactly
