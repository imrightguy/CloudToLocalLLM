# Admin Center API Documentation - Complete Reference

## Overview

The Admin Center API provides secure administrative endpoints for managing CloudToLocalLLM users, subscriptions, payments, and system operations. All endpoints require admin authentication with role-based permissions.

**Version:** 1.0.0
**Last Updated:** November 2025

## Base URL

```
Production: https://api.cloudtolocalllm.online/api/admin
Staging: https://staging-api.cloudtolocalllm.online/api/admin
Development: http://localhost:3001/api/admin
```

## Authentication

All admin endpoints require a valid JWT token with admin privileges.

### Headers

```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

### Admin Roles and Permissions

The Admin Center implements role-based access control (RBAC) with three distinct roles:

#### Super Admin

**Full access to all admin operations**

Permissions:

- All user management operations (view, edit, suspend, delete)
- All payment operations (view, process refunds)
- All subscription operations (view, edit, cancel)
- All reporting operations (view, export)
- Admin management (create, edit, delete admins)
- Configuration management
- Audit log access (view, export)

#### Support Admin

**User support and account management**

Permissions:

- View users
- Edit users (subscription changes)
- Suspend/reactivate users
- View sessions
- Terminate sessions
- View payments (read-only)
- View audit logs (read-only)

#### Finance Admin

**Financial operations and reporting**

Permissions:

- View users (read-only)
- View payments
- Process refunds
- View subscriptions
- Edit subscriptions
- View reports
- Export reports
- View audit logs (read-only)

### Authentication Flow

1. User logs in to main application via Auth0
2. JWT token issued with user claims
3. Admin role verified from `admin_roles` table
4. Token passed to Admin Center via session inheritance
5. Each API request validates token and checks permissions

## Rate Limiting

Admin API endpoints implement rate limiting to prevent abuse and ensure system stability.

| Endpoint Type | Requests/Minute | Burst Allowance | Window |
|---------------|-----------------|-----------------|--------|
| Standard Operations | 100 | 20 | 60 seconds |
| Expensive Operations | 20 | 5 | 60 seconds |
| Report Generation | 10 | 2 | 60 seconds |
| Export Operations | 5 | 1 | 60 seconds |

### Rate Limit Headers

All responses include rate limit information:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705843260
X-RateLimit-Window: 60
```

---

## User Management Endpoints

### List Users

Retrieve a paginated list of users with search and filtering capabilities.

**Endpoint:** `GET /api/admin/users`
**Permissions Required:** `view_users`

**Query Parameters:**
| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| page | integer | 1 | Page number (min: 1) |
| limit | integer | 50 | Items per page (min: 1, max: 100) |
| search | string | - | Search by email, username, user ID, or Auth0 ID |
| tier | string | - | Filter by subscription tier (free, premium, enterprise) |
| status | string | - | Filter by account status (active, suspended, deleted) |
| startDate | string | - | Filter by registration date (ISO 8601 format) |
| endDate | string | - | Filter by registration date (ISO 8601 format) |
| sortBy | string | created_at | Sort field (created_at, last_login, email, username) |
| sortOrder | string | desc | Sort order (asc, desc) |

### Get User Details

Retrieve detailed information about a specific user.

**Endpoint:** `GET /api/admin/users/:userId`
**Permissions Required:** `view_users`

### Update User Subscription

Update a user's subscription tier with automatic prorated charge calculation.

**Endpoint:** `PATCH /api/admin/users/:userId`
**Permissions Required:** `edit_users`

### Suspend User Account

Suspend a user account and invalidate all active sessions.

**Endpoint:** `POST /api/admin/users/:userId/suspend`
**Permissions Required:** `suspend_users`

### Reactivate User Account

Reactivate a suspended user account.

**Endpoint:** `POST /api/admin/users/:userId/reactivate`
**Permissions Required:** `suspend_users`

---

## Subscription Management Endpoints

### List Subscriptions

Retrieve a paginated list of subscriptions with filtering capabilities.

**Endpoint:** `GET /api/admin/subscriptions`
**Permissions Required:** `view_subscriptions`

### Get Subscription Details

Retrieve detailed information about a specific subscription.

**Endpoint:** `GET /api/admin/subscriptions/:subscriptionId`
**Permissions Required:** `view_subscriptions`

### Update Subscription

Update a subscription tier (upgrade or downgrade).

**Endpoint:** `PATCH /api/admin/subscriptions/:subscriptionId`
**Permissions Required:** `edit_subscriptions`

### Cancel Subscription

Cancel a subscription immediately or at the end of the billing period.

**Endpoint:** `POST /api/admin/subscriptions/:subscriptionId/cancel`
**Permissions Required:** `edit_subscriptions`

---

## Payment Management Endpoints

### List Payment Transactions

Retrieve a paginated list of payment transactions with filtering and sorting.

**Endpoint:** `GET /api/admin/payments/transactions`
**Permissions Required:** `view_payments`

### Get Transaction Details

Retrieve detailed information about a specific payment transaction.

**Endpoint:** `GET /api/admin/payments/transactions/:transactionId`
**Permissions Required:** `view_payments`

### Process Refund

Process a full or partial refund for a payment transaction.

**Endpoint:** `POST /api/admin/payments/refunds`
**Permissions Required:** `process_refunds`

### Get User Payment Methods

Retrieve payment methods associated with a user account.

**Endpoint:** `GET /api/admin/payments/methods/:userId`
**Permissions Required:** `view_payments`

---

## Admin Management Endpoints

### List Administrators

Retrieve a list of all administrators with their roles and activity.

**Endpoint:** `GET /api/admin/admins`
**Permissions Required:** Super Admin only

### Assign Admin Role

Assign an admin role to a user.

**Endpoint:** `POST /api/admin/admins`
**Permissions Required:** Super Admin only

### Revoke Admin Role

Revoke an admin role from a user.

**Endpoint:** `DELETE /api/admin/admins/:userId/roles/:role`
**Permissions Required:** Super Admin only

---

## Dashboard Metrics Endpoint

### Get Dashboard Metrics

Retrieve key metrics and statistics for the Admin Center dashboard.

**Endpoint:** `GET /api/admin/dashboard/metrics`
**Permissions Required:** Admin authentication (any role)

---

## Financial Reporting Endpoints

### Generate Revenue Report

Generate revenue report for a specified date range with optional tier breakdown.

**Endpoint:** `GET /api/admin/reports/revenue`
**Permissions Required:** `view_reports`

---

## Audit Log Endpoints

### List Audit Logs

Retrieve a paginated list of admin audit logs with filtering.

**Endpoint:** `GET /api/admin/audit/logs`
**Permissions Required:** `view_audit_logs`

### Get Audit Log Details

Retrieve detailed information about a specific audit log entry.

**Endpoint:** `GET /api/admin/audit/logs/:logId`
**Permissions Required:** `view_audit_logs`

### Export Audit Logs

Export audit logs to CSV format for compliance and reporting.

**Endpoint:** `GET /api/admin/audit/export`
**Permissions Required:** `export_audit_logs`

---

## Webhook Endpoints

### Stripe Webhook Handler

Process Stripe webhook events for payment and subscription updates.

**Endpoint:** `POST /api/webhooks/stripe`

---

## Error Handling

All endpoints follow a consistent error response format:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional error details"
}
```
