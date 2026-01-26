# Audit Log API

## Overview

The Audit Log API provides secure administrative endpoints for viewing and exporting audit logs of all administrative actions. All endpoints require admin authentication with specific permissions.

**Base URL:** `/api/admin/audit`

**Authentication:** JWT Bearer token with admin role

---

## Quick Reference Table

| Action | Endpoint | Permissions | Description |
| :--- | :--- | :--- | :--- |
| **List Logs** | `GET /api/admin/audit/logs` | `view_audit_logs` | Retrieve a paginated list of audit logs. |
| **Get Details** | `GET /api/admin/audit/logs/:logId` | `view_audit_logs` | Retrieve detailed info for a specific entry. |
| **Export CSV** | `GET /api/admin/audit/export` | `export_audit_logs` | Export audit logs to CSV format. |

---

## Endpoints

### 1. List Audit Logs

**Endpoint:** `GET /api/admin/audit/logs`

**Query Parameters:**

- `page` (integer, default: 1): Page number.
- `limit` (integer, default: 100, max: 200): Items per page.
- `action` (string): Filter by action (e.g., `user_suspended`, `refund_processed`).
- `resourceType` (string): Filter by resource (e.g., `user`, `subscription`).
- `startDate` / `endDate` (ISO 8601): Filter by date range.

**Example Response:**

```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "id": "uuid",
        "action": "user_suspended",
        "resource_type": "user",
        "affected_user_id": "uuid",
        "details": {
          "reason": "Terms of service violation",
          "previousStatus": "active",
          "newStatus": "suspended"
        },
        "created_at": "2025-01-15T10:30:00Z"
      }
    ],
    "pagination": { "page": 1, "totalLogs": 250, "totalPages": 5 }
  }
}
```

### 2. Export Audit Logs

**Endpoint:** `GET /api/admin/audit/export`

**Description:** Export audit logs to CSV format with optional filtering.

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/export?startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer <jwt_token>" \
  -o audit-logs.csv
```

---

## Action and Resource Types

### Action Types

- `user_suspended` / `user_reactivated`
- `subscription_tier_changed`
- `refund_processed`
- `admin_role_granted` / `admin_role_revoked`

### Resource Types

- `user`
- `subscription`
- `transaction`
- `admin_role`

---

## Security & Compliance

- **Immutability**: Audit logs are immutable and include cryptographic signatures for tamper detection.
- **Retention**: Minimum retention period of 7 years for compliance.
- **Privacy**: Sensitive data (passwords, API keys) is never logged.

---

## Rate Limits

- **Standard**: 100 requests per 15 minutes per admin.
- **Export**: 10 exports per hour per admin.

---

## Related Documentation

- [Admin Management API](./ADMIN_MANAGEMENT.md)
- [Admin Authentication Middleware](../../middleware/admin-auth.js)
