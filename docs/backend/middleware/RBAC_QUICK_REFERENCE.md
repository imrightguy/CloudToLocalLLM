# RBAC Quick Reference

## Import

```javascript
import {
  ROLES,
  PERMISSIONS,
  ROLE_PERMISSIONS,
  hasPermission,
  hasAnyPermission,
  requirePermission,
  authorizeRBAC,
  requireRole,
  requireAdmin,
  requireSuperAdmin,
} from './middleware/rbac.js';
```

## Roles

```javascript
ROLES.SUPER_ADMIN; // 'super_admin'
ROLES.SUPPORT_ADMIN; // 'support_admin'
ROLES.FINANCE_ADMIN; // 'finance_admin'
ROLES.USER; // 'user'
ROLES.PREMIUM_USER; // 'premium_user'
ROLES.ENTERPRISE_USER; // 'enterprise_user'
```

## Common Permissions

```javascript
PERMISSIONS.VIEW_USERS;
PERMISSIONS.EDIT_USERS;
PERMISSIONS.DELETE_USERS;
PERMISSIONS.SUSPEND_USERS;
PERMISSIONS.CREATE_TUNNELS;
PERMISSIONS.EDIT_TUNNELS;
PERMISSIONS.DELETE_TUNNELS;
PERMISSIONS.VIEW_TUNNELS;
PERMISSIONS.MANAGE_TUNNEL_SHARING;
PERMISSIONS.VIEW_PAYMENTS;
PERMISSIONS.PROCESS_REFUNDS;
PERMISSIONS.VIEW_REPORTS;
PERMISSIONS.EXPORT_REPORTS;
PERMISSIONS.MANAGE_SYSTEM_CONFIG;
PERMISSIONS.VIEW_SYSTEM_METRICS;
```

## Protect Routes

### By Permission (Single)

```javascript
router.get(
  '/users',
  authenticateJWT,
  requirePermission(PERMISSIONS.VIEW_USERS),
  handler
);
```

### By Permission (Multiple - All Required)

```javascript
router.post(
  '/users/:id/suspend',
  authenticateJWT,
  requirePermission([PERMISSIONS.EDIT_USERS, PERMISSIONS.SUSPEND_USERS]),
  handler
);
```

### By Permission (Multiple - Any One)

```javascript
router.get(
  '/reports',
  authenticateJWT,
  requirePermission([PERMISSIONS.VIEW_REPORTS, PERMISSIONS.EXPORT_REPORTS], {
    requireAll: false,
  }),
  handler
);
```

### By Role (Single)

```javascript
router.get(
  '/admin/dashboard',
  authenticateJWT,
  requireRole(ROLES.SUPER_ADMIN),
  handler
);
```

### By Role (Multiple - Any One)

```javascript
router.get(
  '/admin/users',
  authenticateJWT,
  requireRole([ROLES.SUPER_ADMIN, ROLES.SUPPORT_ADMIN], { requireAll: false }),
  handler
);
```

### By Admin Role (Any Admin)

```javascript
router.get('/admin/dashboard', authenticateJWT, requireAdmin(), handler);
```

### By Super Admin Role

```javascript
router.post(
  '/admin/system/config',
  authenticateJWT,
  requireSuperAdmin(),
  handler
);
```

## Check Permissions Programmatically

### Check All Permissions

```javascript
if (hasPermission(req.userRoles, PERMISSIONS.VIEW_USERS)) {
  // User has permission
}

if (
  hasPermission(req.userRoles, [PERMISSIONS.VIEW_USERS, PERMISSIONS.EDIT_USERS])
) {
  // User has all permissions
}
```

### Check Any Permission

```javascript
if (
  hasAnyPermission(req.userRoles, [
    PERMISSIONS.VIEW_USERS,
    PERMISSIONS.EDIT_USERS,
  ])
) {
  // User has at least one permission
}
```

## User Roles in Request

After authentication and RBAC middleware:

```javascript
req.user; // Authenticated user from Auth0
req.userRoles; // Array of roles assigned to user
// Example: ['super_admin'] or ['premium_user']
```

## Error Responses

### 401 Unauthorized

```json
{
  "error": "Authentication required",
  "code": "AUTH_REQUIRED"
}
```

### 403 Forbidden (Permission)

```json
{
  "error": "Insufficient permissions",
  "code": "INSUFFICIENT_PERMISSIONS",
  "required": ["view_users"]
}
```

### 403 Forbidden (Role)

```json
{
  "error": "Insufficient role",
  "code": "INSUFFICIENT_ROLE",
  "required": ["super_admin"]
}
```

## Role Permissions

### Super Admin

- All permissions (wildcard '\*')

### Support Admin

- view_users, edit_users, suspend_users
- view_sessions, terminate_sessions
- view_payments, view_audit_logs
- view_email_config, manage_email_config
- view_system_metrics, view_webhooks

### Finance Admin

- view_users, view_payments, process_refunds
- view_subscriptions, edit_subscriptions
- view_reports, export_reports, view_audit_logs

### User (Free Tier)

- create_tunnels, edit_tunnels, delete_tunnels
- view_tunnels, manage_tunnel_sharing
- view_payments, view_subscriptions

### Premium User

- All User permissions +
- manage_proxy, view_proxy_metrics
- view_reports

### Enterprise User

- All Premium permissions +
- export_reports, manage_webhooks, view_webhooks

## Common Patterns

### Admin-Only Endpoint

```javascript
router.get('/admin/users', authenticateJWT, requireAdmin(), handler);
```

### Super Admin-Only Endpoint

```javascript
router.post(
  '/admin/system/config',
  authenticateJWT,
  requireSuperAdmin(),
  handler
);
```

### User Tunnel Operations

```javascript
router.post(
  '/tunnels',
  authenticateJWT,
  requirePermission(PERMISSIONS.CREATE_TUNNELS),
  handler
);
```

### Finance Operations

```javascript
router.post(
  '/payments/refund',
  authenticateJWT,
  requirePermission(PERMISSIONS.PROCESS_REFUNDS),
  handler
);
```

### Multi-Role Access

```javascript
router.get(
  '/reports',
  authenticateJWT,
  requireRole([ROLES.SUPPORT_ADMIN, ROLES.FINANCE_ADMIN], {
    requireAll: false,
  }),
  handler
);
```

## Testing

Run RBAC tests:

```bash
npm test -- rbac.test.js
```

## Documentation

Full documentation: `services/api-backend/middleware/RBAC_GUIDE.md`
