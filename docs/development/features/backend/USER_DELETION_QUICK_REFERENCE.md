# User Deletion Feature - Quick Reference

## Overview

The User Deletion feature provides comprehensive account deletion with cascading data cleanup and soft delete support for compliance.

**Validates: Requirements 3.5**
- Supports user account deletion with data cleanup
- Implements cascading data cleanup (sessions, tunnels, audit logs)
- Adds soft delete option for compliance

## Files

- **Service**: `services/user-deletion-service.js`
- **Routes**: `routes/user-deletion.js`
- **Tests**: `test/api-backend/user-deletion.test.js`

## Key Features

### 1. Soft Delete (Default)
- Marks user as deleted in metadata
- Preserves data for compliance/recovery
- Can be restored within 30 days
- Default behavior for user-initiated deletions

### 2. Hard Delete
- Permanently removes all user data
- Cascading cleanup of related records
- Cannot be undone
- Requires explicit `softDelete: false` option

### 3. Cascading Cleanup
When hard deleting, the following data is removed in order:
1. User sessions
2. Tunnel connections
3. Audit logs
4. API usage records
5. Messages (from conversations)
6. Conversations
7. User preferences
8. User record

### 4. Restoration
- Soft-deleted users can be restored
- Removes deletion metadata
- Restores full account access

## API Endpoints

### DELETE /api/users/:id
Delete user account (soft or hard delete)

**Query Parameters:**
- `softDelete`: boolean (default: true)
- `reason`: string (optional)

**Request Body (optional):**
```json
{
  "softDelete": true,
  "reason": "User requested deletion"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "userId": "auth0|123456",
    "deletionType": "soft",
    "cleanupStats": {
      "sessionsDeleted": 2,
      "tunnelsDeleted": 3,
      "auditLogsDeleted": 5,
      "apiUsageDeleted": 1,
      "conversationsDeleted": 2,
      "messagesDeleted": 4,
      "preferencesDeleted": 1,
      "userDeleted": true
    }
  }
}
```

### POST /api/users/:id/restore
Restore a soft-deleted account

**Response:**
```json
{
  "success": true,
  "data": {
    "userId": "auth0|123456",
    "message": "User account restored successfully"
  }
}
```

### GET /api/users/:id/deletion-status
Check if user is deleted

**Response (if deleted):**
```json
{
  "success": true,
  "data": {
    "isDeleted": true,
    "userId": "auth0|123456",
    "deletedAt": "2024-01-15T10:30:00Z",
    "deletionReason": "User requested deletion",
    "restorationDeadline": "2024-02-14T10:30:00Z"
  }
}
```

### POST /api/users/:id/permanent-delete
Permanently delete a soft-deleted account (admin only)

**Response:**
```json
{
  "success": true,
  "data": {
    "userId": "auth0|123456",
    "deletionType": "permanent",
    "cleanupStats": { ... }
  }
}
```

## Service Methods

### deleteUserAccount(userId, options)
Delete user account with optional soft/hard delete

```javascript
// Soft delete (default)
await userDeletionService.deleteUserAccount('auth0|123456');

// Hard delete
await userDeletionService.deleteUserAccount('auth0|123456', {
  softDelete: false
});

// With reason
await userDeletionService.deleteUserAccount('auth0|123456', {
  softDelete: true,
  reason: 'Account no longer needed'
});
```

### restoreUserAccount(userId)
Restore a soft-deleted account

```javascript
await userDeletionService.restoreUserAccount('auth0|123456');
```

### isUserDeleted(userId)
Check if user is soft-deleted

```javascript
const isDeleted = await userDeletionService.isUserDeleted('auth0|123456');
```

### getDeletionInfo(userId)
Get deletion information for a soft-deleted user

```javascript
const info = await userDeletionService.getDeletionInfo('auth0|123456');
// Returns: { userId, deletedAt, deletionReason, isDeleted }
```

### permanentlyDeleteUser(userId)
Permanently delete a soft-deleted user (admin operation)

```javascript
await userDeletionService.permanentlyDeleteUser('auth0|123456');
```

## Database Schema

### Users Table Metadata
Soft-deleted users have metadata with:
- `deleted_at`: ISO timestamp of deletion
- `deletion_reason`: Reason for deletion
- `is_deleted`: 'true' if soft-deleted

## Testing

All functionality is covered by 27 comprehensive tests:

```bash
npm test -- test/api-backend/user-deletion.test.js
```

**Test Coverage:**
- Soft delete operations
- Hard delete with cascading cleanup
- Account restoration
- Deletion status checking
- Permanent deletion
- Error handling
- Default options
- Cleanup statistics tracking

## Security Considerations

1. **Authorization**: Users can only delete their own accounts
2. **Admin Operations**: Permanent deletion requires admin role
3. **Audit Logging**: All deletions are logged
4. **Data Retention**: Soft-deleted data is retained for 30 days
5. **Cascading Cleanup**: All related data is properly cleaned up

## Compliance

- **GDPR**: Supports right to be forgotten with hard delete
- **Data Retention**: Soft delete allows 30-day recovery period
- **Audit Trail**: Deletion reason and timestamp are recorded
- **Data Cleanup**: Comprehensive cascading cleanup of all related data

## Error Handling

- Invalid user ID: Returns 400 Bad Request
- User not found: Returns 404 Not Found
- Unauthorized deletion: Returns 403 Forbidden
- Service errors: Returns 500 Internal Server Error

## Integration

The user deletion service is initialized in the main server:

```javascript
import { initializeUserDeletionService } from './routes/user-deletion.js';

// During server startup
await initializeUserDeletionService();
```

Routes are registered:

```javascript
import userDeletionRoutes from './routes/user-deletion.js';

app.use('/api/users', userDeletionRoutes);
```

## Performance

- Soft delete: O(1) - Single metadata update
- Hard delete: O(n) - Where n is number of related records
- Restoration: O(1) - Single metadata update
- Status check: O(1) - Single metadata query

## Future Enhancements

1. Scheduled permanent deletion after retention period
2. Bulk deletion operations
3. Deletion analytics and reporting
4. Configurable retention periods
5. Deletion notifications to user email
