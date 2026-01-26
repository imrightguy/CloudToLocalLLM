# User Activity Tracking - Quick Reference

## Files Created

1. **Database Migration**
   - `database/migrations/003-user-activity-tracking.sql` - Creates tables and indexes

2. **Service**
   - `services/user-activity-service.js` - Core activity tracking logic

3. **Middleware**
   - `middleware/activity-logging.js` - Automatic activity logging

4. **Routes**
   - `routes/user-activity.js` - User-facing activity endpoints

5. **Tests**
   - `test/api-backend/user-activity-unit.test.js` - Unit tests (passing)
   - `test/api-backend/user-activity.test.js` - Integration tests (requires DB)

6. **Documentation**
   - `USER_ACTIVITY_TRACKING_IMPLEMENTATION.md` - Full implementation guide
   - `USER_ACTIVITY_TRACKING_QUICK_REFERENCE.md` - This file

## Key Functions

### Service Functions

```javascript
// Log activity
logUserActivity({
  userId, action, resourceType, resourceId,
  ipAddress, userAgent, details, severity
})

// Update metrics
updateUserUsageMetrics(userId)

// Get activity logs
getUserActivityLogs(userId, { limit, offset, action, resourceType, startDate, endDate })

// Get usage metrics
getUserUsageMetrics(userId)

// Get activity summary
getUserActivitySummary(userId, { period, startDate, endDate })

// Admin functions
getAllUserActivityLogs(options)
getAllUserActivityLogsCount(options)
```

### API Endpoints

```
GET  /api/users/activity          - Get user's activity logs
GET  /api/users/metrics           - Get user's usage metrics
GET  /api/users/activity/summary  - Get user's activity summary
```

## Activity Actions

```javascript
// Profile
PROFILE_VIEW, PROFILE_UPDATE, PROFILE_DELETE, AVATAR_UPLOAD, PREFERENCES_UPDATE

// Tunnel
TUNNEL_CREATE, TUNNEL_START, TUNNEL_STOP, TUNNEL_DELETE, TUNNEL_UPDATE, TUNNEL_STATUS_CHECK

// API Keys
API_KEY_CREATE, API_KEY_DELETE, API_KEY_ROTATE

// Sessions
SESSION_CREATE, SESSION_DESTROY, SESSION_REFRESH

// Admin
ADMIN_USER_VIEW, ADMIN_USER_UPDATE, ADMIN_USER_DELETE, ADMIN_TIER_CHANGE
```

## Integration Steps

1. **Apply Database Migration**

   ```bash
   npm run migrate
   ```

2. **Add Middleware to Server**

   ```javascript
   import { activityLoggingMiddleware } from './middleware/activity-logging.js';
   app.use(authenticateJWT);
   app.use(activityLoggingMiddleware);
   ```

3. **Add Routes to Server**

   ```javascript
   import userActivityRoutes from './routes/user-activity.js';
   app.use('/api/users', userActivityRoutes);
   ```

4. **Use in Route Handlers** (Optional)

   ```javascript
   await res.logActivity({
     action: ACTIVITY_ACTIONS.PROFILE_UPDATE,
     details: { fields: ['email', 'name'] }
   });
   ```

## Database Tables

### user_activity_logs

- Stores individual activity events
- Indexed by: user_id, action, created_at

### user_usage_metrics

- Aggregates usage per user
- Unique constraint on user_id

### user_activity_summary

- Stores period-based summaries
- Unique constraint on (user_id, period, period_start)

## Testing

```bash
# Run unit tests (no DB required)
npm test -- test/api-backend/user-activity-unit.test.js

# Run integration tests (requires DB)
npm test -- test/api-backend/user-activity.test.js
```

## Requirements Validation

✅ **Requirement 3.4**: Track user activity and usage metrics

- Implemented via `logUserActivity()` and `updateUserUsageMetrics()`
- Automatic middleware logging for all requests
- Usage metrics aggregation

✅ **Requirement 3.10**: Provide user activity audit logs

- Implemented via `getUserActivityLogs()` and `getAllUserActivityLogs()`
- API endpoints for retrieving activity logs
- Admin access to system-wide logs

## Performance Notes

- Activity logging is asynchronous (non-blocking)
- Database indexes optimize query performance
- Metrics updates are incremental
- Pagination support for large datasets
- Graceful error handling (logging failures don't break requests)

## Security Notes

- All user endpoints require JWT authentication
- Admin endpoints require admin role
- IP addresses and user agents captured for audit
- Users can only view their own activity
- Admins can view all activity
