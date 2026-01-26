# User Activity Tracking Implementation

## Overview

This document describes the implementation of user activity tracking for the CloudToLocalLLM API Backend. The system provides comprehensive logging of user operations, usage metrics tracking, and activity audit logs for analytics and compliance purposes.

**Validates: Requirements 3.4, 3.10**

- Tracks user activity and usage metrics
- Implements activity audit logs
- Provides user activity audit logs

## Components

### 1. Database Schema

#### user_activity_logs Table

Stores individual user activity events with full context.

```sql
CREATE TABLE user_activity_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  action TEXT NOT NULL,
  resource_type TEXT,
  resource_id TEXT,
  details JSONB DEFAULT '{}'::jsonb,
  ip_address INET,
  user_agent TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  severity TEXT DEFAULT 'info'
);
```

**Indexes:**

- `idx_user_activity_logs_user_id` - For querying by user
- `idx_user_activity_logs_action` - For filtering by action type
- `idx_user_activity_logs_created_at` - For time-based queries

#### user_usage_metrics Table

Aggregates usage metrics per user for analytics.

```sql
CREATE TABLE user_usage_metrics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL UNIQUE,
  total_requests INTEGER DEFAULT 0,
  total_api_calls INTEGER DEFAULT 0,
  total_tunnels_created INTEGER DEFAULT 0,
  total_tunnels_active INTEGER DEFAULT 0,
  total_data_transferred_bytes BIGINT DEFAULT 0,
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  metadata JSONB DEFAULT '{}'::jsonb
);
```

#### user_activity_summary Table

Stores aggregated activity summaries by period (daily, weekly, monthly).

```sql
CREATE TABLE user_activity_summary (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  period TEXT NOT NULL CHECK (period IN ('daily', 'weekly', 'monthly')),
  period_start TIMESTAMPTZ NOT NULL,
  period_end TIMESTAMPTZ NOT NULL,
  total_actions INTEGER DEFAULT 0,
  total_api_calls INTEGER DEFAULT 0,
  total_tunnels_created INTEGER DEFAULT 0,
  total_data_transferred_bytes BIGINT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, period, period_start)
);
```

### 2. Service Layer

#### UserActivityService (`services/user-activity-service.js`)

**Core Functions:**

1. **logUserActivity(options)**
   - Logs a user activity event
   - Parameters: userId, action, resourceType, resourceId, ipAddress, userAgent, details, severity
   - Returns: Activity log entry with ID and timestamp
   - Automatically updates usage metrics

2. **updateUserUsageMetrics(userId)**
   - Creates or updates user usage metrics
   - Increments total_requests counter
   - Updates last_activity timestamp
   - Returns: Updated metrics record

3. **getUserActivityLogs(userId, options)**
   - Retrieves user activity logs with filtering
   - Supports: limit, offset, action, resourceType, startDate, endDate
   - Returns: Array of activity log entries

4. **getUserActivityLogsCount(userId, options)**
   - Returns total count of user activity logs
   - Supports same filtering options as getUserActivityLogs

5. **getUserUsageMetrics(userId)**
   - Retrieves aggregated usage metrics for a user
   - Returns: Metrics record or null if not found

6. **getUserActivitySummary(userId, options)**
   - Retrieves activity summary for a period
   - Parameters: period ('daily', 'weekly', 'monthly'), startDate, endDate
   - Returns: Array of summary entries

7. **getAllUserActivityLogs(options)**
   - Admin function to retrieve all user activity logs
   - Supports: limit, offset, action, severity, startDate, endDate
   - Returns: Array of activity log entries

8. **getAllUserActivityLogsCount(options)**
   - Admin function to get total count of all activity logs
   - Supports same filtering options as getAllUserActivityLogs

**Activity Action Types:**

```javascript
ACTIVITY_ACTIONS = {
  // User profile actions
  PROFILE_VIEW: 'profile_view',
  PROFILE_UPDATE: 'profile_update',
  PROFILE_DELETE: 'profile_delete',
  AVATAR_UPLOAD: 'avatar_upload',
  PREFERENCES_UPDATE: 'preferences_update',

  // Tunnel actions
  TUNNEL_CREATE: 'tunnel_create',
  TUNNEL_START: 'tunnel_start',
  TUNNEL_STOP: 'tunnel_stop',
  TUNNEL_DELETE: 'tunnel_delete',
  TUNNEL_UPDATE: 'tunnel_update',
  TUNNEL_STATUS_CHECK: 'tunnel_status_check',

  // API key actions
  API_KEY_CREATE: 'api_key_create',
  API_KEY_DELETE: 'api_key_delete',
  API_KEY_ROTATE: 'api_key_rotate',

  // Session actions
  SESSION_CREATE: 'session_create',
  SESSION_DESTROY: 'session_destroy',
  SESSION_REFRESH: 'session_refresh',

  // Admin actions
  ADMIN_USER_VIEW: 'admin_user_view',
  ADMIN_USER_UPDATE: 'admin_user_update',
  ADMIN_USER_DELETE: 'admin_user_delete',
  ADMIN_TIER_CHANGE: 'admin_tier_change',
}
```

**Severity Levels:**

```javascript
SEVERITY_LEVELS = {
  DEBUG: 'debug',
  INFO: 'info',
  WARN: 'warn',
  ERROR: 'error',
  CRITICAL: 'critical',
}
```

### 3. Middleware

#### Activity Logging Middleware (`middleware/activity-logging.js`)

Automatically logs user activities for all API requests.

**Features:**

- Automatic action detection based on route and HTTP method
- Resource type and ID extraction from request path
- IP address and user agent capture
- Asynchronous logging (doesn't block request)
- Graceful error handling

**Route Action Mapping:**

```javascript
ROUTE_ACTION_MAP = {
  'GET /api/users/profile': ACTIVITY_ACTIONS.PROFILE_VIEW,
  'PUT /api/users/profile': ACTIVITY_ACTIONS.PROFILE_UPDATE,
  'DELETE /api/users/profile': ACTIVITY_ACTIONS.PROFILE_DELETE,
  'PUT /api/users/avatar': ACTIVITY_ACTIONS.AVATAR_UPLOAD,
  'PUT /api/users/preferences': ACTIVITY_ACTIONS.PREFERENCES_UPDATE,
  'POST /api/tunnels': ACTIVITY_ACTIONS.TUNNEL_CREATE,
  'GET /api/tunnels/:id': ACTIVITY_ACTIONS.TUNNEL_STATUS_CHECK,
  'PUT /api/tunnels/:id': ACTIVITY_ACTIONS.TUNNEL_UPDATE,
  'DELETE /api/tunnels/:id': ACTIVITY_ACTIONS.TUNNEL_DELETE,
  'POST /api/tunnels/:id/start': ACTIVITY_ACTIONS.TUNNEL_START,
  'POST /api/tunnels/:id/stop': ACTIVITY_ACTIONS.TUNNEL_STOP,
  // ... more mappings
}
```

### 4. API Routes

#### User Activity Routes (`routes/user-activity.js`)

**Endpoints:**

1. **GET /api/users/activity**
   - Get current user's activity logs
   - Query Parameters: limit, offset, action, resourceType, startDate, endDate
   - Returns: Array of activity logs with pagination info
   - Authentication: Required (JWT)

2. **GET /api/users/metrics**
   - Get current user's usage metrics
   - Returns: User usage metrics (requests, API calls, tunnels, data transferred)
   - Authentication: Required (JWT)

3. **GET /api/users/activity/summary**
   - Get current user's activity summary for a period
   - Query Parameters: period ('daily', 'weekly', 'monthly'), startDate, endDate
   - Returns: Array of activity summary entries
   - Authentication: Required (JWT)

## Usage Examples

### Logging User Activity

```javascript
import { logUserActivity, ACTIVITY_ACTIONS } from './services/user-activity-service.js';

// Log a profile update
await logUserActivity({
  userId: 'user-123',
  action: ACTIVITY_ACTIONS.PROFILE_UPDATE,
  resourceType: 'user',
  resourceId: 'user-123',
  ipAddress: '192.168.1.1',
  userAgent: 'Mozilla/5.0',
  details: {
    field: 'email',
    oldValue: 'old@example.com',
    newValue: 'new@example.com'
  },
  severity: 'info'
});
```

### Retrieving Activity Logs

```javascript
import { getUserActivityLogs } from './services/user-activity-service.js';

// Get user's activity logs
const logs = await getUserActivityLogs('user-123', {
  limit: 50,
  offset: 0,
  action: 'profile_update',
  startDate: '2024-01-01T00:00:00Z',
  endDate: '2024-01-31T23:59:59Z'
});
```

### Getting Usage Metrics

```javascript
import { getUserUsageMetrics } from './services/user-activity-service.js';

// Get user's usage metrics
const metrics = await getUserUsageMetrics('user-123');
console.log(`Total requests: ${metrics.total_requests}`);
console.log(`Total API calls: ${metrics.total_api_calls}`);
console.log(`Tunnels created: ${metrics.total_tunnels_created}`);
```

### Using the Middleware

```javascript
import express from 'express';
import { activityLoggingMiddleware } from './middleware/activity-logging.js';

const app = express();

// Add activity logging middleware after authentication
app.use(authenticateJWT);
app.use(activityLoggingMiddleware);

// Now all requests will be automatically logged
```

## Integration Points

### 1. Server Initialization

Add the activity logging middleware to the Express app:

```javascript
import { activityLoggingMiddleware } from './middleware/activity-logging.js';
import userActivityRoutes from './routes/user-activity.js';

// Add middleware
app.use(authenticateJWT);
app.use(activityLoggingMiddleware);

// Add routes
app.use('/api/users', userActivityRoutes);
```

### 2. Route Handlers

Route handlers can manually log activities if needed:

```javascript
router.put('/profile', authenticateJWT, async (req, res) => {
  try {
    // Update profile
    const updatedProfile = await updateProfile(req.user.sub, req.body);

    // Log activity (middleware will also log this)
    await res.logActivity({
      action: ACTIVITY_ACTIONS.PROFILE_UPDATE,
      details: { fields: Object.keys(req.body) }
    });

    res.json({ success: true, data: updatedProfile });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

## Performance Considerations

1. **Asynchronous Logging**: Activity logging is performed asynchronously to avoid blocking requests
2. **Database Indexes**: Proper indexes on user_id, action, and created_at for efficient queries
3. **Metrics Aggregation**: Usage metrics are updated incrementally to avoid expensive calculations
4. **Pagination**: All list endpoints support pagination to handle large datasets

## Security Considerations

1. **Authentication**: All user-facing endpoints require JWT authentication
2. **Authorization**: Admin endpoints require admin role verification
3. **Data Sanitization**: IP addresses and user agents are stored as-is for audit purposes
4. **Access Control**: Users can only view their own activity logs; admins can view all

## Testing

Unit tests are provided in `test/api-backend/user-activity-unit.test.js` covering:

- Activity action constants
- Severity level constants
- Service function signatures

Integration tests require a running PostgreSQL database and are located in `test/api-backend/user-activity.test.js`.

## Migration

Database migration file: `database/migrations/003-user-activity-tracking.sql`

To apply the migration:

```bash
npm run migrate
```

## Future Enhancements

1. **Real-time Analytics**: WebSocket support for real-time activity streaming
2. **Activity Aggregation**: Automated daily/weekly/monthly summary generation
3. **Export Functionality**: CSV/JSON export of activity logs
4. **Advanced Filtering**: More sophisticated query capabilities
5. **Activity Alerts**: Notifications for unusual activity patterns
6. **Retention Policies**: Automatic cleanup of old activity logs
