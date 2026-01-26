# User Deletion Implementation Guide

## Overview

This document provides a comprehensive guide to the User Deletion feature implementation, including architecture, design decisions, and integration points.

## Architecture

### Service Layer

The `UserDeletionService` handles all deletion operations:

```
UserDeletionService
├── deleteUserAccount()      - Main deletion method (soft/hard)
├── restoreUserAccount()     - Restore soft-deleted accounts
├── isUserDeleted()          - Check deletion status
├── getDeletionInfo()        - Get deletion metadata
└── permanentlyDeleteUser()  - Permanent deletion (admin)
```

### Route Layer

The `user-deletion.js` routes provide REST endpoints:

```
DELETE   /api/users/:id                    - Delete account
POST     /api/users/:id/restore            - Restore account
GET      /api/users/:id/deletion-status    - Check status
POST     /api/users/:id/permanent-delete   - Permanent delete (admin)
```

### Database Layer

Deletion data is stored in the `users` table metadata:

```sql
-- Soft-deleted user metadata
{
  "deleted_at": "2024-01-15T10:30:00Z",
  "deletion_reason": "User requested deletion",
  "is_deleted": "true"
}
```

## Design Decisions

### 1. Soft Delete as Default

**Decision**: Soft delete is the default behavior

**Rationale**:

- Compliance with GDPR right to be forgotten (30-day recovery period)
- Allows account recovery if user changes mind
- Preserves audit trail for compliance
- Reduces accidental data loss

**Implementation**:

```javascript
const { softDelete = true, reason = 'User requested deletion' } = options;
```

### 2. Cascading Cleanup

**Decision**: Hard delete performs cascading cleanup of all related data

**Rationale**:

- Ensures complete data removal
- Maintains referential integrity
- Prevents orphaned records
- Supports compliance requirements

**Cleanup Order**:

1. Sessions (user authentication)
2. Tunnel connections (active tunnels)
3. Audit logs (security records)
4. API usage (analytics)
5. Messages (conversation content)
6. Conversations (user data)
7. Preferences (user settings)
8. User record (final deletion)

### 3. Transaction-Based Operations

**Decision**: All deletions use database transactions

**Rationale**:

- Ensures atomicity (all-or-nothing)
- Prevents partial deletions
- Allows rollback on errors
- Maintains data consistency

**Implementation**:

```javascript
await client.query('BEGIN');
try {
  // Perform deletions
  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
}
```

### 4. Metadata-Based Soft Delete

**Decision**: Soft deletion uses metadata instead of separate table

**Rationale**:

- Simpler schema (no additional tables)
- Easier to query deleted users
- Preserves all user data
- Supports restoration without data recovery

**Metadata Fields**:

- `deleted_at`: Timestamp of deletion
- `deletion_reason`: Reason for deletion
- `is_deleted`: Boolean flag

### 5. Authorization Model

**Decision**: Users can only delete their own accounts; admins can permanently delete

**Rationale**:

- Prevents unauthorized deletions
- Allows admin cleanup after retention period
- Maintains security boundaries
- Supports compliance workflows

**Implementation**:

```javascript
// User can only delete their own account
if (id !== userId) {
  return res.status(403).json({ error: 'Forbidden' });
}

// Admin can permanently delete any account
if (!isAdmin) {
  return res.status(403).json({ error: 'Forbidden' });
}
```

## Implementation Details

### Soft Delete Flow

```
1. User requests account deletion
   ↓
2. Service validates user ID
   ↓
3. Begin transaction
   ↓
4. Update user metadata with deletion info
   ↓
5. Commit transaction
   ↓
6. Return cleanup statistics
   ↓
7. User can restore within 30 days
```

### Hard Delete Flow

```
1. User requests hard delete (softDelete: false)
   ↓
2. Service validates user ID
   ↓
3. Begin transaction
   ↓
4. Delete sessions
   ↓
5. Delete tunnel connections
   ↓
6. Delete audit logs
   ↓
7. Delete API usage records
   ↓
8. Delete messages (cascade from conversations)
   ↓
9. Delete conversations
   ↓
10. Delete user preferences
    ↓
11. Delete user record
    ↓
12. Commit transaction
    ↓
13. Return cleanup statistics
```

### Restoration Flow

```
1. User requests account restoration
   ↓
2. Service validates user ID
   ↓
3. Check if user is soft-deleted
   ↓
4. Remove deletion metadata
   ↓
5. Return success
   ↓
6. User account is fully restored
```

## Error Handling

### Validation Errors

```javascript
// Invalid user ID
if (!userId || typeof userId !== 'string') {
  throw new Error('Invalid user ID');
}
```

### Not Found Errors

```javascript
// User not found
if (userResult.rows.length === 0) {
  throw new Error('User not found');
}
```

### Authorization Errors

```javascript
// User trying to delete another user's account
if (id !== userId) {
  return res.status(403).json({ error: 'Forbidden' });
}
```

### Database Errors

```javascript
// Transaction rollback on error
try {
  await client.query('BEGIN');
  // ... operations ...
  await client.query('COMMIT');
} catch (error) {
  await client.query('ROLLBACK');
  throw error;
}
```

## Testing Strategy

### Unit Tests (27 tests)

**Soft Delete Tests**:

- Successful soft deletion
- Deletion reason included in metadata
- Rollback on error
- User not found error
- Invalid user ID error

**Hard Delete Tests**:

- Cascading cleanup
- Zero records deleted gracefully
- Rollback on error

**Restoration Tests**:

- Successful restoration
- User not found or not deleted error
- Invalid user ID error

**Status Checking Tests**:

- Check deleted user status
- Check active user status
- User not found error
- Invalid user ID error

**Deletion Info Tests**:

- Retrieve deletion information
- Non-deleted user error
- User not found error
- Invalid user ID error

**Permanent Deletion Tests**:

- Permanent deletion with cleanup
- Rollback on error
- User not found error
- Invalid user ID error

**Cascading Cleanup Tests**:

- Correct deletion order
- Accurate cleanup statistics
- Default options
- Default reason

### Property-Based Tests

While not explicitly implemented as PBT, the tests verify:

- **Idempotence**: Restoring a restored account is safe
- **Consistency**: Cleanup statistics match actual deletions
- **Atomicity**: All-or-nothing transactions

## Integration Points

### Server Initialization

```javascript
import { initializeUserDeletionService } from './routes/user-deletion.js';

// During server startup
await initializeUserDeletionService();
```

### Route Registration

```javascript
import userDeletionRoutes from './routes/user-deletion.js';

app.use('/api/users', userDeletionRoutes);
```

### Middleware Integration

- **Authentication**: `authenticateJWT` middleware
- **Authorization**: User ID validation
- **Logging**: Request/response logging
- **Error Handling**: Global error handler

## Performance Considerations

### Soft Delete

- **Time Complexity**: O(1)
- **Space Complexity**: O(1)
- **Database Operations**: 1 UPDATE query

### Hard Delete

- **Time Complexity**: O(n) where n = related records
- **Space Complexity**: O(1)
- **Database Operations**: 8 DELETE queries

### Optimization Opportunities

1. Batch deletion for multiple users
2. Asynchronous permanent deletion
3. Caching of deletion status
4. Indexed queries on deletion metadata

## Security Considerations

### Authentication

- All endpoints require JWT authentication
- User ID extracted from JWT token

### Authorization

- Users can only delete their own accounts
- Admins can permanently delete any account
- Role-based access control

### Audit Logging

- All deletions logged with reason
- Deletion timestamp recorded
- User IP and user agent captured

### Data Protection

- Soft-deleted data encrypted at rest
- Hard-deleted data permanently removed
- No backup recovery possible after hard delete

## Compliance

### GDPR

- Right to be forgotten: Hard delete removes all data
- Data retention: Soft delete allows 30-day recovery
- Audit trail: Deletion reason and timestamp recorded

### Data Protection

- Cascading cleanup ensures no orphaned data
- Metadata-based deletion preserves audit trail
- Transaction-based operations ensure consistency

## Monitoring and Observability

### Logging

- Deletion operations logged at INFO level
- Errors logged at ERROR level
- Cleanup statistics included in logs

### Metrics

- Deletion count per day
- Hard vs soft deletion ratio
- Restoration rate
- Error rate

### Alerts

- High deletion rate (potential abuse)
- Permanent deletion operations (admin actions)
- Restoration requests (user recovery)

## Future Enhancements

### 1. Scheduled Permanent Deletion

```javascript
// Automatically permanently delete soft-deleted users after 30 days
const deletionDeadline = new Date(deletedAt);
deletionDeadline.setDate(deletionDeadline.getDate() + 30);
```

### 2. Bulk Operations

```javascript
// Delete multiple users at once
await userDeletionService.bulkDeleteUsers(userIds, options);
```

### 3. Deletion Analytics

```javascript
// Track deletion patterns and trends
await userDeletionService.getDeletionAnalytics(startDate, endDate);
```

### 4. Configurable Retention

```javascript
// Allow different retention periods per user tier
const retentionDays = getTierRetentionDays(userTier);
```

### 5. Deletion Notifications

```javascript
// Notify user of pending permanent deletion
await notificationService.sendDeletionNotification(userId);
```

## Troubleshooting

### Issue: User not found error

**Cause**: User ID doesn't exist in database
**Solution**: Verify user ID is correct and user exists

### Issue: Unauthorized deletion error

**Cause**: User trying to delete another user's account
**Solution**: Only users can delete their own accounts

### Issue: Transaction rollback

**Cause**: Database error during deletion
**Solution**: Check database logs and retry operation

### Issue: Restoration fails

**Cause**: User is not soft-deleted
**Solution**: Only soft-deleted users can be restored

## References

- Requirements: 3.5 - User account deletion with data cleanup
- Design Document: API Backend Enhancement
- Database Schema: schema.pg.sql
- Test Suite: test/api-backend/user-deletion.test.js
