# Error Recovery Endpoints - Quick Reference

## Overview

Error recovery endpoints provide manual intervention capabilities for service recovery procedures.

## Files Created

- `services/error-recovery-service.js` - Core error recovery service
- `routes/error-recovery.js` - Express routes for error recovery endpoints
- `test/api-backend/error-recovery.test.js` - Unit tests (27 tests, all passing)
- `test/api-backend/error-recovery-integration.test.js` - Integration tests

## API Endpoints

### Get All Recovery Statuses

```
GET /error-recovery/status
Authorization: Bearer <admin-token>
```

Returns array of recovery statuses for all services.

### Get Specific Service Status

```
GET /error-recovery/status/:serviceName
Authorization: Bearer <admin-token>
```

Returns recovery status for a specific service.

### Trigger Recovery

```
POST /error-recovery/recover/:serviceName
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "reason": "Manual intervention"
}
```

Executes recovery procedure for a service.

### Get Recovery History

```
GET /error-recovery/history?serviceName=service-1&status=success&limit=10
Authorization: Bearer <admin-token>
```

Returns recovery history with optional filtering.

### Get Recovery Metrics

```
GET /error-recovery/metrics
Authorization: Bearer <admin-token>
```

Returns recovery metrics and statistics.

### Get Recovery Report

```
GET /error-recovery/report
Authorization: Bearer <admin-token>
```

Returns comprehensive recovery report.

### Clear History

```
DELETE /error-recovery/history
Authorization: Bearer <admin-token>
```

Clears all recovery history.

### Reset Metrics

```
POST /error-recovery/reset-metrics
Authorization: Bearer <admin-token>
```

Resets all recovery metrics.

## Service Registration

Register a recovery procedure for a service:

```javascript
import { errorRecoveryService } from './services/error-recovery-service.js';

errorRecoveryService.registerRecoveryProcedure('my-service', {
  procedure: async () => {
    // Recovery logic here
    return { status: 'recovered' };
  },
  description: 'My service recovery procedure',
  prerequisites: ['check-network'],
  timeoutMs: 30000,
});
```

## Response Examples

### Recovery Status Response

```json
{
  "service": "database-service",
  "isRecovering": false,
  "lastRecoveryAttempt": "2025-11-19T10:30:00Z",
  "lastRecoveryResult": {
    "status": "success",
    "duration": 1234,
    "timestamp": "2025-11-19T10:30:00Z"
  },
  "recoveryCount": 5,
  "successCount": 4,
  "failureCount": 1,
  "successRate": "80.00%",
  "description": "Database reconnection and validation",
  "prerequisites": ["check-network"],
  "timestamp": "2025-11-19T10:35:00Z"
}
```

### Recovery Execution Response

```json
{
  "recoveryId": "recovery-database-service-1700387400000",
  "service": "database-service",
  "status": "success",
  "duration": 1234,
  "result": {
    "status": "recovered"
  },
  "timestamp": "2025-11-19T10:30:00Z"
}
```

### Recovery Metrics Response

```json
{
  "totalRecoveryAttempts": 10,
  "successfulRecoveries": 8,
  "failedRecoveries": 2,
  "averageRecoveryTime": 1500,
  "timestamp": "2025-11-19T10:35:00Z"
}
```

## Error Responses

### Recovery Already in Progress

```json
{
  "status": "error",
  "message": "Recovery already in progress for this service",
  "error": "Recovery already in progress for service: database-service",
  "timestamp": "2025-11-19T10:35:00Z"
}
```

### No Recovery Procedure Registered

```json
{
  "status": "error",
  "message": "No recovery procedure registered for this service",
  "error": "No recovery procedure registered for service: unknown-service",
  "timestamp": "2025-11-19T10:35:00Z"
}
```

### Unauthorized

```json
{
  "status": "error",
  "message": "Unauthorized",
  "error": "Invalid token"
}
```

### Forbidden

```json
{
  "status": "error",
  "message": "Forbidden",
  "error": "Admin role required"
}
```

## Testing

### Run Unit Tests

```bash
npm test -- test/api-backend/error-recovery.test.js
```

### Run Integration Tests

```bash
npm test -- test/api-backend/error-recovery-integration.test.js
```

## Key Features

✅ Manual recovery procedure execution
✅ Recovery status tracking
✅ Recovery history with filtering
✅ Recovery metrics and statistics
✅ Concurrent recovery prevention
✅ Timeout protection (30 seconds default)
✅ Admin-only access
✅ Comprehensive error handling
✅ Full audit logging

## Integration

Add to `server.js`:

```javascript
import errorRecoveryRoutes from './routes/error-recovery.js';

app.use('/api/error-recovery', errorRecoveryRoutes);
app.use('/error-recovery', errorRecoveryRoutes);
```

## Requirement Coverage

**Requirement 7.7:** THE API SHALL provide error recovery endpoints for manual intervention

✅ Provides error recovery endpoints
✅ Implements recovery procedures
✅ Adds recovery status reporting
✅ Includes unit tests
✅ Includes integration tests
