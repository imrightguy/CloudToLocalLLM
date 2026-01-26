# Role-Based Access Control (RBAC)

## Overview

The API backend implements a comprehensive RBAC system that correlates user roles with granular permissions. Access is validated via JWT Bearer tokens, with roles assigned based on Auth0 metadata or user tier.

---

## 👥 Roles and Tiers

### Administrative Roles

- **`super_admin`**: Full system access; manage administrators.
- **`support_admin`**: User management, sessions, and audit log access.
- **`finance_admin`**: Payments, refunds, subscriptions, and financial reports.

### User Tiers

- **`user` (Free)**: Basic tunnel operations.
- **`premium_user`**: Advanced features, proxy management, and metrics.
- **`enterprise_user`**: All features including export reports and webhook management.

---

## 🔐 Permissions Reference

| Category | Key Permissions |
| :--- | :--- |
| **User Management** | `view_users`, `edit_users`, `suspend_users` |
| **Tunnels** | `create_tunnels`, `view_tunnels`, `manage_tunnel_sharing` |
| **Payments** | `view_payments`, `process_refunds` |
| **System** | `manage_system_config`, `view_audit_logs`, `manage_webhooks` |

---

## 🛠️ Usage for Developers

### Protecting Routes

#### By Permission

```javascript
import { requirePermission, PERMISSIONS } from './middleware/rbac.js';

router.get('/users', authenticateJWT, requirePermission(PERMISSIONS.VIEW_USERS), handler);
```

#### By Role

```javascript
import { requireAdmin, requireSuperAdmin } from './middleware/rbac.js';

router.get('/admin/dashboard', authenticateJWT, requireAdmin(), handler);
router.post('/admin/config', authenticateJWT, requireSuperAdmin(), handler);
```

### Checking Permissions Programmatically

```javascript
import { hasPermission } from './middleware/rbac.js';

if (hasPermission(req.userRoles, PERMISSIONS.EDIT_USERS)) {
  // Logic for users with edit permission
}
```

---

## ⚠️ Error Responses

- **401 Unauthorized**: Authentication required (`AUTH_REQUIRED`).
- **403 Forbidden**: Insufficient permissions (`INSUFFICIENT_PERMISSIONS`) or role (`INSUFFICIENT_ROLE`).

---

## Related Documentation

- [Backend Security Guide](./BACKEND_SECURITY.md)
- [Admin Management API](../../api/admin/ADMIN_MANAGEMENT.md)
