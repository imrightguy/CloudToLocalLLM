# Admin Management API

## Overview

The Admin Management API provides secure endpoints for Super Admins to manage administrator accounts and roles. All endpoints require Super Admin authentication and log all actions to the audit trail.

**Base URL:** `/api/admin/admins`

**Authentication:** JWT Bearer token with Super Admin role required

**Rate Limiting:** 100 requests per minute per admin

---

## Quick Reference Table

| Action | Endpoint | Description |
| :--- | :--- | :--- |
| **List Admins** | `GET /api/admin/admins` | Returns all administrators with roles and activity summary. |
| **Assign Role** | `POST /api/admin/admins` | Assigns `support_admin` or `finance_admin` role to a user. |
| **Revoke Role** | `DELETE /api/admin/admins/:userId/roles/:role` | Revokes specified admin role from user. |

---

## Endpoints

### 1. List All Administrators

Get a list of all administrators with their roles and activity summary.

**Endpoint:** `GET /api/admin/admins`

**Response:**

```json
{
  "admins": [
    {
      "userId": "uuid",
      "email": "admin@example.com",
      "username": "admin_user",
      "userCreatedAt": "2025-01-01T00:00:00Z",
      "roles": [
        {
          "role": "super_admin",
          "grantedBy": "uuid",
          "grantedByEmail": "superadmin@example.com",
          "grantedAt": "2025-01-01T00:00:00Z",
          "revokedAt": null,
          "isActive": true
        }
      ],
      "activitySummary": {
        "totalActions": 150,
        "lastActionAt": "2025-11-15T10:30:00Z",
        "recentActions": 25
      }
    }
  ],
  "total": 5
}
```

**Status Codes:**

- `200 OK` - Success
- `401 Unauthorized` - Token missing or invalid
- `403 Forbidden` - Not a Super Admin

### 2. Assign Admin Role

Assign an admin role to a user by email.

**Endpoint:** `POST /api/admin/admins`

**Request Body:**

```json
{
  "email": "user@example.com",
  "role": "support_admin"
}
```

**Request Fields:**

- `email` (string, required) - Email address of the user to make admin
- `role` (string, required) - Role to assign: `support_admin` or `finance_admin`

**Status Codes:**

- `201 Created` - Admin role assigned successfully
- `400 Bad Request` - Missing required fields or invalid role
- `404 Not Found` - User with specified email not found
- `409 Conflict` - User already has the specified role

### 3. Revoke Admin Role

Revoke an admin role from a user.

**Endpoint:** `DELETE /api/admin/admins/:userId/roles/:role`

**URL Parameters:**

- `userId` (string, required) - ID of the user to revoke role from
- `role` (string, required) - Role to revoke: `super_admin`, `support_admin`, or `finance_admin`

**Status Codes:**

- `200 OK` - Admin role revoked successfully
- `403 Forbidden` - Attempting to revoke own Super Admin role
- `404 Not Found` - User/role not found

---

## Role Permissions

| Role | Can Assign? | Permissions |
| :--- | :--- | :--- |
| `super_admin` | ❌ No | Full access, manage administrators |
| `support_admin` | ✅ Yes | User management, view payments |
| `finance_admin` | ✅ Yes | Payments, refunds, financial reports |

---

## Audit Logging

All admin management operations are logged with the following metadata:

- Admin user ID and email
- Action performed (e.g., `admin_role_assigned`)
- Affected user ID and email
- Role assigned or revoked
- IP address and User agent

---

## Security & Implementation Notes

- 🔒 **Super Admin Only**: All endpoints require Super Admin role.
- 🚫 **No Super Admin Assignment**: Super Admin roles cannot be assigned through this API.
- 🛡️ **Self-Protection**: You cannot revoke your own Super Admin role.
- ✅ **Pre-requisite**: User must exist in the system before assigning a role.

## Examples

### Assign support admin role

```bash
curl -X POST https://api.zoidbot.online/api/admin/admins \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","role":"support_admin"}'
```

---

## Related Documentation

- [Audit Log API](./AUDIT_LOGS.md)
- [Backend Security Guide](../../operations/security/BACKEND_SECURITY.md)
