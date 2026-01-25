# Role-Based Access Control (RBAC) Middleware Guide

## Overview

The RBAC middleware provides comprehensive role-based access control for the API backend. It enables permission validation before operations and supports multiple roles with granular permissions.

**Validates: Requirements 2.3, 2.5**

- Support role-based access control (RBAC) for admin operations
- Validate user permissions before allowing operations

## Roles

The system defines the following roles:

### Admin Roles

- **super_admin**: Full system access with all permissions
- **support_admin**: Support team access (user management, sessions, audit logs)
- **finance_admin**: Finance team access (payments, refunds, subscriptions)

### User Roles

- **user**: Free tier user (basic tunnel operations)
- **premium_user**: Premium tier user (advanced features)
- **enterprise_user**: Enterprise tier user (all features)

## Permissions

The system defines granular permissions for different operations:

### User Management

- `view_users`: View user information
- `edit_users`: Edit user profiles
- `delete_users`: Delete user accounts
- `suspend_users`: Suspend user accounts
- `manage_user_tiers`: Manage user tier upgrades/downgrades

### Session Management

- `view_sessions`: View user sessions
- `terminate_sessions`: Terminate user sessions

### Tunnel Management

- `create_tunnels`: Create new tunnels
- `edit_tunnels`: Edit tunnel configuration
- `delete_tunnels`: Delete tunnels
- `view_tunnels`: View tunnel information
- `manage_tunnel_sharing`: Share tunnels with other users

### Proxy Management

- `manage_proxy`: Manage proxy instances
- `view_proxy_metrics`: View proxy metrics

### Payment and Billing

- `view_payments`: View payment information
- `process_refunds`: Process refunds
- `view_subscriptions`: View subscription information
- `edit_subscriptions`: Edit subscriptions

### Reporting and Analytics

- `view_reports`: View reports
- `export_reports`: Export reports
- `view_audit_logs`: View audit logs

### System Configuration

- `manage_system_config`: Manage system configuration
- `view_system_metrics`: View system metrics
- `manage_email_config`: Manage email configuration
- `view_email_config`: View email configuration

### Webhook Management

- `manage_webhooks`: Manage webhooks
- `view_webhooks`: View webhooks

## Usage

### 1. Middleware Setup

The RBAC middleware is automatically applied in the middleware pipeline:

```javascript
import { setupMiddlewarePipeline } from './middleware/pipeline.js';

const app = express();
setupMiddlewarePipeline(app);
```

### 2. Protecting Routes with Permissions

Use the `requirePermission` middleware to protect routes:

```javascript
import { requirePermission, PERMISSIONS } from './middleware/rbac.js';
import { authenticateJWT } from './middleware/auth.js';

// Single permission
router.get(
  '/users',
  authenticateJWT,
  requirePermission(PERMISSIONS.VIEW_USERS),
  (req, res) => {
    // Handle request
  }
);

// Multiple permissions (all required)
router.post(
  '/users/:id/suspend',
  authenticateJWT,
  requirePermission([PERMISSIONS.EDIT_USERS, PERMISSIONS.SUSPEND_USERS]),
  (req, res) => {
    // Handle request
  }
);

// Multiple permissions (any one required)
router.get(
  '/reports',
  authenticateJWT,
  requirePermission([PERMISSIONS.VIEW_REPORTS, PERMISSIONS.EXPORT_REPORTS], {
    requireAll: false,
  }),
  (req, res) => {
    // Handle request
  }
);
```

### 3. Protecting Routes with Roles

Use the `requireRole` middleware to protect routes by role:

```javascript
import {
  requireRole,
  requireAdmin,
  requireSuperAdmin,
  ROLES,
} from './middleware/rbac.js';

// Require specific role
router.get(
  '/admin/dashboard',
  authenticateJWT,
  requireRole(ROLES.SUPER_ADMIN),
  (req, res) => {
    // Handle request
  }
);

// Require any admin role
router.get('/admin/users', authenticateJWT, requireAdmin(), (req, res) => {
  // Handle request
});

// Require super admin
router.post(
  '/admin/system/config',
  authenticateJWT,
  requireSuperAdmin(),
  (req, res) => {
    // Handle request
  }
);

// Multiple roles (any one required)
router.get(
  '/admin/reports',
  authenticateJWT,
  requireRole([ROLES.SUPPORT_ADMIN, ROLES.FINANCE_ADMIN], {
    requireAll: false,
  }),
  (req, res) => {
    // Handle request
  }
);
```

### 4. Checking Permissions Programmatically

Use the `hasPermission` function to check permissions in your code:

```javascript
import { hasPermission, PERMISSIONS } from './middleware/rbac.js';

// Check if user has permission
if (hasPermission(req.userRoles, PERMISSIONS.VIEW_USERS)) {
  // User has permission
}

// Check multiple permissions
if (
  hasPermission(req.userRoles, [
    PERMISSIONS.EDIT_USERS,
    PERMISSIONS.SUSPEND_USERS,
  ])
) {
  // User has all permissions
}

// Check any permission
import { hasAnyPermission } from './middleware/rbac.js';

if (
  hasAnyPermission(req.userRoles, [
    PERMISSIONS.VIEW_REPORTS,
    PERMISSIONS.EXPORT_REPORTS,
  ])
) {
  // User has at least one permission
}
```

## How It Works

### 1. User Roles Assignment

When a request is authenticated, the `authorizeRBAC` middleware automatically assigns roles to the user based on:

1. **Admin metadata** from Auth0 (if present)
2. **Auth0 roles array** (if present)
3. **User tier** (free, premium, enterprise)

```javascript
// Example: User with Auth0 metadata
{
  user: {
    sub: 'auth0|123',
    'https://cloudtolocalllm.com/user_metadata': {
      role: 'super_admin'
    }
  }
}
// Result: req.userRoles = ['super_admin']

// Example: User with tier
{
  user: {
    sub: 'auth0|456',
    'https://cloudtolocalllm.com/tier': 'premium'
  }
}
// Result: req.userRoles = ['premium_user']
```

### 2. Permission Checking

When a route is protected with `requirePermission`:

1. Check if user is authenticated (401 if not)
2. Get user roles from `req.userRoles`
3. Get permissions for each role
4. Check if user has required permissions
5. Return 403 if insufficient permissions

### 3. Role Checking

When a route is protected with `requireRole`:

1. Check if user is authenticated (401 if not)
2. Get user roles from `req.userRoles`
3. Check if user has required role(s)
4. Return 403 if insufficient role

## Error Responses

### 401 Unauthorized

```json
{
  "error": "Authentication required",
  "code": "AUTH_REQUIRED"
}
```

### 403 Forbidden (Insufficient Permissions)

```json
{
  "error": "Insufficient permissions",
  "code": "INSUFFICIENT_PERMISSIONS",
  "required": ["view_users", "edit_users"]
}
```

### 403 Forbidden (Insufficient Role)

```json
{
  "error": "Insufficient role",
  "code": "INSUFFICIENT_ROLE",
  "required": ["super_admin"]
}
```

## Examples

### Example 1: Admin User Management Endpoint

```javascript
import express from 'express';
import { authenticateJWT } from './middleware/auth.js';
import { requirePermission, PERMISSIONS } from './middleware/rbac.js';

const router = express.Router();

// Get all users (requires view_users permission)
router.get(
  '/users',
  authenticateJWT,
  requirePermission(PERMISSIONS.VIEW_USERS),
  async (req, res) => {
    // Implementation
  }
);

// Update user (requires edit_users permission)
router.put(
  '/users/:id',
  authenticateJWT,
  requirePermission(PERMISSIONS.EDIT_USERS),
  async (req, res) => {
    // Implementation
  }
);

// Suspend user (requires both edit_users and suspend_users)
router.post(
  '/users/:id/suspend',
  authenticateJWT,
  requirePermission([PERMISSIONS.EDIT_USERS, PERMISSIONS.SUSPEND_USERS]),
  async (req, res) => {
    // Implementation
  }
);

export default router;
```

### Example 2: Finance Admin Endpoint

```javascript
import express from 'express';
import { authenticateJWT } from './middleware/auth.js';
import { requireRole, ROLES } from './middleware/rbac.js';

const router = express.Router();

// Finance dashboard (requires finance_admin role)
router.get(
  '/dashboard',
  authenticateJWT,
  requireRole(ROLES.FINANCE_ADMIN),
  async (req, res) => {
    // Implementation
  }
);

export default router;
```

### Example 3: Tunnel Operations

```javascript
import express from 'express';
import { authenticateJWT } from './middleware/auth.js';
import { requirePermission, PERMISSIONS } from './middleware/rbac.js';

const router = express.Router();

// Create tunnel (requires create_tunnels permission)
router.post(
  '/tunnels',
  authenticateJWT,
  requirePermission(PERMISSIONS.CREATE_TUNNELS),
  async (req, res) => {
    // Implementation
  }
);

// View tunnel (requires view_tunnels permission)
router.get(
  '/tunnels/:id',
  authenticateJWT,
  requirePermission(PERMISSIONS.VIEW_TUNNELS),
  async (req, res) => {
    // Implementation
  }
);

// Share tunnel (requires manage_tunnel_sharing permission)
router.post(
  '/tunnels/:id/share',
  authenticateJWT,
  requirePermission(PERMISSIONS.MANAGE_TUNNEL_SHARING),
  async (req, res) => {
    // Implementation
  }
);

export default router;
```

## Testing

The RBAC middleware includes comprehensive unit tests. Run tests with:

```bash
npm test -- rbac.test.js
```

Tests cover:

- Permission checking (single and multiple)
- Role checking (single and multiple)
- Middleware behavior
- Error responses
- Role-to-permission mappings

## Best Practices

1. **Always authenticate before checking permissions**

   ```javascript
   router.get(
     '/protected',
     authenticateJWT, // Always first
     requirePermission(PERMISSIONS.VIEW_DATA),
     handler
   );
   ```

2. **Use specific permissions, not just roles**

   ```javascript
   // Good: Specific permission
   requirePermission(PERMISSIONS.VIEW_USERS);

   // Less ideal: Just checking role
   requireRole(ROLES.SUPPORT_ADMIN);
   ```

3. **Log permission denials for security**
   - The middleware automatically logs permission denials
   - Review logs regularly for suspicious activity

4. **Keep role definitions in sync**
   - Update `ROLE_PERMISSIONS` when adding new permissions
   - Document permission changes

5. **Test permission checks**
   - Write tests for protected endpoints
   - Verify both allowed and denied access

## Troubleshooting

### User roles not assigned

- Check if user is authenticated
- Verify Auth0 metadata is present
- Check user tier is set correctly

### Permission denied unexpectedly

- Check user roles: `console.log(req.userRoles)`
- Verify permission is in role definition
- Check middleware order (auth before RBAC)

### Super admin can't access endpoint

- Verify super admin role is assigned
- Check if endpoint requires specific permission
- Super admin has all permissions (wildcard '\*')

## Integration with Existing Code

The RBAC middleware integrates seamlessly with existing authentication:

1. **Automatic role assignment** via `authorizeRBAC` middleware
2. **No changes needed** to existing authentication code
3. **Backward compatible** with existing admin-auth middleware
4. **Flexible** - can use permissions, roles, or both

## Future Enhancements

Potential improvements:

- Dynamic permission loading from database
- Permission caching for performance
- Audit logging for permission changes
- Permission delegation
- Time-based permissions
- Resource-level permissions
