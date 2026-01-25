# Audit Log API Reference

## Overview

The Audit Log API provides secure administrative endpoints for viewing and exporting audit logs of all administrative actions. All endpoints require admin authentication with specific permissions.

**Base URL:** `/api/admin/audit`

**Authentication:** JWT Bearer token with admin role

**Permissions Required:**

- `view_audit_logs` - View audit log entries
- `export_audit_logs` - Export audit logs to CSV

---

## Endpoints

### 1. List Audit Logs

**Endpoint:** `GET /api/admin/audit/logs`

**Permission:** `view_audit_logs`

**Description:** Retrieve a paginated list of audit log entries with filtering and sorting capabilities.

**Query Parameters:**

| Parameter      | Type     | Default    | Description                                                     |
| -------------- | -------- | ---------- | --------------------------------------------------------------- |
| page           | integer  | 1          | Page number (min: 1)                                            |
| limit          | integer  | 100        | Items per page (min: 1, max: 200)                               |
| adminUserId    | UUID     | -          | Filter by admin user ID                                         |
| action         | string   | -          | Filter by action type (e.g., user_suspended, refund_processed)  |
| resourceType   | string   | -          | Filter by resource type (user, subscription, transaction, etc.) |
| affectedUserId | UUID     | -          | Filter by affected user ID                                      |
| startDate      | ISO 8601 | -          | Filter by date range (start)                                    |
| endDate        | ISO 8601 | -          | Filter by date range (end)                                      |
| sortBy         | string   | created_at | Sort field (created_at, action, resource_type, admin_user_id)   |
| sortOrder      | string   | desc       | Sort order (asc, desc)                                          |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?page=1&limit=50&action=user_suspended&sortBy=created_at&sortOrder=desc" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "logs": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "admin_user_id": "660e8400-e29b-41d4-a716-446655440001",
        "admin_role": "super_admin",
        "action": "user_suspended",
        "resource_type": "user",
        "resource_id": "770e8400-e29b-41d4-a716-446655440002",
        "affected_user_id": "770e8400-e29b-41d4-a716-446655440002",
        "details": {
          "reason": "Terms of service violation",
          "invalidatedSessions": 2,
          "previousStatus": "active",
          "newStatus": "suspended",
          "timestamp": "2025-01-15T10:30:00Z"
        },
        "ip_address": "192.168.1.100",
        "user_agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)...",
        "created_at": "2025-01-15T10:30:00Z",
        "admin_email": "admin@cloudtolocalllm.online",
        "admin_username": "admin",
        "affected_user_email": "user@example.com",
        "affected_user_username": "johndoe"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "totalLogs": 250,
      "totalPages": 5,
      "hasNextPage": true,
      "hasPreviousPage": false
    },
    "filters": {
      "adminUserId": null,
      "action": "user_suspended",
      "resourceType": null,
      "affectedUserId": null,
      "startDate": null,
      "endDate": null,
      "sortBy": "created_at",
      "sortOrder": "DESC"
    }
  },
  "timestamp": "2025-01-15T10:35:00Z"
}
```

**Response Fields:**

| Field                  | Type     | Description                                               |
| ---------------------- | -------- | --------------------------------------------------------- |
| id                     | UUID     | Unique audit log entry ID                                 |
| admin_user_id          | UUID     | ID of admin who performed the action                      |
| admin_role             | string   | Role of admin at time of action                           |
| action                 | string   | Action performed (e.g., user_suspended, refund_processed) |
| resource_type          | string   | Type of resource affected                                 |
| resource_id            | string   | ID of affected resource                                   |
| affected_user_id       | UUID     | ID of user affected by action (if applicable)             |
| details                | object   | Additional action details (JSON)                          |
| ip_address             | string   | IP address of admin                                       |
| user_agent             | string   | User agent of admin                                       |
| created_at             | ISO 8601 | Timestamp of action                                       |
| admin_email            | string   | Email of admin user                                       |
| admin_username         | string   | Username of admin user                                    |
| affected_user_email    | string   | Email of affected user                                    |
| affected_user_username | string   | Username of affected user                                 |

**Common Action Types:**

- `user_suspended` - User account suspended
- `user_reactivated` - User account reactivated
- `subscription_tier_changed` - User subscription tier modified
- `refund_processed` - Payment refund processed
- `subscription_upgraded` - Subscription upgraded
- `subscription_downgraded` - Subscription downgraded
- `subscription_cancelled` - Subscription cancelled
- `payment_method_removed` - Payment method removed
- `admin_role_granted` - Admin role assigned to user
- `admin_role_revoked` - Admin role revoked from user

---

### 2. Get Audit Log Details

**Endpoint:** `GET /api/admin/audit/logs/:logId`

**Permission:** `view_audit_logs`

**Description:** Retrieve detailed information for a specific audit log entry.

**Path Parameters:**

| Parameter | Type | Required | Description        |
| --------- | ---- | -------- | ------------------ |
| logId     | UUID | Yes      | Audit log entry ID |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "log": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "action": "user_suspended",
      "resourceType": "user",
      "resourceId": "770e8400-e29b-41d4-a716-446655440002",
      "details": {
        "reason": "Terms of service violation",
        "invalidatedSessions": 2,
        "previousStatus": "active",
        "newStatus": "suspended",
        "timestamp": "2025-01-15T10:30:00Z"
      },
      "ipAddress": "192.168.1.100",
      "userAgent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36...",
      "createdAt": "2025-01-15T10:30:00Z",
      "adminUser": {
        "id": "660e8400-e29b-41d4-a716-446655440001",
        "email": "admin@cloudtolocalllm.online",
        "username": "admin",
        "auth0Id": "auth0|1234567890",
        "role": "super_admin"
      },
      "affectedUser": {
        "id": "770e8400-e29b-41d4-a716-446655440002",
        "email": "user@example.com",
        "username": "johndoe",
        "auth0Id": "auth0|0987654321"
      }
    }
  },
  "timestamp": "2025-01-15T10:35:00Z"
}
```

**Error Responses:**

- `400 Bad Request` - Invalid log ID format
- `404 Not Found` - Audit log entry not found
- `500 Internal Server Error` - Server error

---

### 3. Export Audit Logs

**Endpoint:** `GET /api/admin/audit/export`

**Permission:** `export_audit_logs`

**Description:** Export audit logs to CSV format with optional filtering.

**Query Parameters:**

| Parameter      | Type     | Default | Description                  |
| -------------- | -------- | ------- | ---------------------------- |
| adminUserId    | UUID     | -       | Filter by admin user ID      |
| action         | string   | -       | Filter by action type        |
| resourceType   | string   | -       | Filter by resource type      |
| affectedUserId | UUID     | -       | Filter by affected user ID   |
| startDate      | ISO 8601 | -       | Filter by date range (start) |
| endDate        | ISO 8601 | -       | Filter by date range (end)   |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/export?startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer <jwt_token>" \
  -o audit-logs.csv
```

**Response:**

- **Content-Type:** `text/csv`
- **Content-Disposition:** `attachment; filename="audit-logs-{date}.csv"`
- **Body:** CSV file with audit log data

**CSV Columns:**

1. Log ID
2. Timestamp
3. Admin User ID
4. Admin Email
5. Admin Username
6. Admin Role
7. Action
8. Resource Type
9. Resource ID
10. Affected User ID
11. Affected User Email
12. Affected User Username
13. Details (JSON)
14. IP Address
15. User Agent

**Example CSV Output:**

```csv
Log ID,Timestamp,Admin User ID,Admin Email,Admin Username,Admin Role,Action,Resource Type,Resource ID,Affected User ID,Affected User Email,Affected User Username,Details,IP Address,User Agent
550e8400-e29b-41d4-a716-446655440000,2025-01-15T10:30:00Z,660e8400-e29b-41d4-a716-446655440001,admin@cloudtolocalllm.online,admin,super_admin,user_suspended,user,770e8400-e29b-41d4-a716-446655440002,770e8400-e29b-41d4-a716-446655440002,user@example.com,johndoe,"{""reason"":""Terms of service violation"",""invalidatedSessions"":2}",192.168.1.100,"Mozilla/5.0..."
```

**Error Responses:**

- `500 Internal Server Error` - Export failed

---

## Security Considerations

### Audit Log Immutability

- Audit logs are **immutable** and cannot be modified or deleted
- All administrative actions are automatically logged
- Logs include cryptographic signatures for tamper detection
- Minimum retention period: 7 years for compliance

### Access Control

- Only administrators with `view_audit_logs` permission can view logs
- Only administrators with `export_audit_logs` permission can export logs
- Super Admins can view all audit logs
- Support Admins and Finance Admins can view logs related to their permissions

### Data Privacy

- Sensitive data (passwords, API keys) is never logged
- Email addresses and user IDs are logged for accountability
- IP addresses and user agents are logged for security tracking
- Full details are stored in JSON format for comprehensive auditing

---

## Common Use Cases

### 1. Investigate User Account Changes

```bash
# Find all actions affecting a specific user
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?affectedUserId=770e8400-e29b-41d4-a716-446655440002" \
  -H "Authorization: Bearer <jwt_token>"
```

### 2. Track Admin Actions

```bash
# Find all actions performed by a specific admin
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?adminUserId=660e8400-e29b-41d4-a716-446655440001" \
  -H "Authorization: Bearer <jwt_token>"
```

### 3. Monitor Refund Activity

```bash
# Find all refund processing actions
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?action=refund_processed" \
  -H "Authorization: Bearer <jwt_token>"
```

### 4. Generate Compliance Report

```bash
# Export all audit logs for a specific month
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/export?startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer <jwt_token>" \
  -o audit-logs-january-2025.csv
```

### 5. Track Subscription Changes

```bash
# Find all subscription-related actions
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?resourceType=subscription" \
  -H "Authorization: Bearer <jwt_token>"
```

---

## Rate Limiting

All audit endpoints are subject to rate limiting:

- **Standard Rate Limit:** 100 requests per 15 minutes per admin
- **Export Rate Limit:** 10 exports per hour per admin

Rate limit headers are included in responses:

- `X-RateLimit-Limit` - Maximum requests allowed
- `X-RateLimit-Remaining` - Remaining requests
- `X-RateLimit-Reset` - Time when limit resets (Unix timestamp)

---

## Error Codes

| Code                        | Description                    |
| --------------------------- | ------------------------------ |
| `INVALID_LOG_ID`            | Invalid audit log ID format    |
| `LOG_NOT_FOUND`             | Audit log entry not found      |
| `AUDIT_LOGS_FAILED`         | Failed to retrieve audit logs  |
| `LOG_DETAILS_FAILED`        | Failed to retrieve log details |
| `AUDIT_EXPORT_FAILED`       | Failed to export audit logs    |
| `ADMIN_RATE_LIMIT_EXCEEDED` | Rate limit exceeded            |

---

## Best Practices

1. **Regular Monitoring:** Review audit logs regularly for suspicious activity
2. **Compliance:** Export logs monthly for compliance and archival purposes
3. **Filtering:** Use specific filters to narrow down results for investigations
4. **Retention:** Ensure logs are retained for minimum 7 years
5. **Security:** Monitor for unauthorized access attempts in audit logs
6. **Documentation:** Document the reason for viewing sensitive audit logs

---

## Support

For API support or questions:

- Email: support@cloudtolocalllm.online
- Documentation: https://docs.cloudtolocalllm.online
- GitHub Issues: https://github.com/cloudtolocalllm/cloudtolocalllm/issues
