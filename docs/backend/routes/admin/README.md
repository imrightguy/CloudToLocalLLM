# Admin API Routes

This directory contains the administrative API routes for CloudToLocalLLM's Admin Center.

## Overview

The Admin Center provides secure, role-based administrative endpoints for managing users, subscriptions, payments, and system operations. All routes require admin authentication with specific permissions.

## Available Routes

### User Management (`users.js`)

**Status:** ✅ Implemented

Provides comprehensive user management capabilities including:

- **List Users** (`GET /`) - Paginated user listing with search and filtering
- **Get User Details** (`GET /:userId`) - Detailed user profile with subscription, payments, and sessions
- **Update Subscription** (`PATCH /:userId`) - Change user subscription tier with prorated charges
- **Suspend Account** (`POST /:userId/suspend`) - Suspend user account and invalidate sessions
- **Reactivate Account** (`POST /:userId/reactivate`) - Reactivate suspended user account

**Features:**

- Pagination support (50 users per page, max 100)
- Search by email, username, user ID, or Auth0 ID
- Filter by subscription tier, account status, and date range
- Sort by multiple fields (created_at, last_login, email, username)
- Automatic prorated charge calculation for upgrades
- Session invalidation on suspension
- Comprehensive audit logging for all actions
- Role-based permission checking

**Permissions Required:**

- `view_users` - View user list and details
- `edit_users` - Update user subscriptions
- `suspend_users` - Suspend and reactivate accounts

### Subscription Management (`subscriptions.js`)

**Status:** ✅ COMPLETED

Provides comprehensive subscription management capabilities including:

- **List Subscriptions** (`GET /subscriptions`) - Paginated subscription listing with filtering
- **Get Subscription Details** (`GET /subscriptions/:subscriptionId`) - Detailed subscription info with payment history
- **Update Subscription** (`PATCH /subscriptions/:subscriptionId`) - Upgrade/downgrade subscription tier
- **Cancel Subscription** (`POST /subscriptions/:subscriptionId/cancel`) - Cancel subscription (immediate or end-of-period)

**Features:**

- Pagination support (50 subscriptions per page, max 200)
- Filter by tier, status, and user ID
- Include upcoming renewals (next 7 days)
- Sort by multiple fields (created_at, current_period_end, tier, status)
- Automatic proration calculation for tier changes
- Immediate or end-of-period cancellation
- Refund eligibility calculation for immediate cancellations
- Billing cycle information and payment statistics
- Comprehensive audit logging for all actions
- Integration with Stripe for subscription management

**Permissions Required:**

- `view_subscriptions` - View subscription list and details
- `edit_subscriptions` - Update and cancel subscriptions

**Documentation:** See [SUBSCRIPTIONS_API.md](./SUBSCRIPTIONS_API.md) for detailed API reference

### Payment Management (`payments.js`)

**Status:** ✅ COMPLETED

Provides comprehensive payment and transaction management capabilities including:

- **List Transactions** (`GET /transactions`) - Paginated transaction listing with filtering
- **Get Transaction Details** (`GET /transactions/:transactionId`) - Detailed transaction info with refunds
- **Process Refund** (`POST /refunds`) - Process full or partial refunds through Stripe
- **Get Payment Methods** (`GET /methods/:userId`) - View user payment methods (masked)

**Features:**

- Pagination support (100 transactions per page, max 200)
- Filter by user ID, status, date range, and amount
- Sort by created_at, amount, or status
- Full and partial refund support
- Automatic transaction status updates
- Payment method data masking for PCI DSS compliance
- Comprehensive audit logging for all refund actions
- Integration with Stripe for refund processing
- Usage statistics for payment methods

**Permissions Required:**

- `view_payments` - View transactions and payment methods
- `process_refunds` - Process refunds

**Documentation:** See [PAYMENTS_API.md](./PAYMENTS_API.md) for detailed API reference

### Subscription Management (`subscriptions.js`)

**Status:** ✅ COMPLETED

Provides comprehensive subscription management capabilities including:

- **List Subscriptions** (`GET /subscriptions`) - Paginated subscription listing with filtering
- **Get Subscription Details** (`GET /subscriptions/:subscriptionId`) - Detailed subscription info with payment history
- **Update Subscription** (`PATCH /subscriptions/:subscriptionId`) - Upgrade/downgrade subscription tier
- **Cancel Subscription** (`POST /subscriptions/:subscriptionId/cancel`) - Cancel subscription (immediate or end-of-period)

**Features:**

- Pagination support (50 subscriptions per page, max 200)
- Filter by tier, status, and user ID
- Include upcoming renewals (next 7 days)
- Sort by multiple fields (created_at, current_period_end, tier, status)
- Automatic proration calculation for tier changes
- Immediate or end-of-period cancellation
- Refund eligibility calculation for immediate cancellations
- Billing cycle information and payment statistics
- Comprehensive audit logging for all actions
- Integration with Stripe for subscription management

**Permissions Required:**

- `view_subscriptions` - View subscription list and details
- `edit_subscriptions` - Update and cancel subscriptions

**Documentation:** See [SUBSCRIPTIONS_API.md](./SUBSCRIPTIONS_API.md) for detailed API reference

## Authentication & Authorization

All admin routes use the `adminAuth` middleware which:

1. Validates JWT token from Authorization header
2. Verifies user has admin role in database
3. Checks user has required permissions for the operation
4. Attaches admin user info to request object

### Admin Roles

- **Super Admin**: All permissions (\*)
- **Support Admin**: view_users, edit_users, suspend_users, view_sessions, terminate_sessions, view_payments, view_audit_logs
- **Finance Admin**: view_users, view_payments, process_refunds, view_subscriptions, edit_subscriptions, view_reports, export_reports, view_audit_logs

## Database Schema

The admin routes interact with the following tables:

- `users` - User accounts with suspension fields
- `subscriptions` - User subscription information
- `payment_transactions` - Payment transaction records
- `payment_methods` - User payment method details
- `refunds` - Refund records
- `admin_roles` - Administrator role assignments
- `admin_audit_logs` - Comprehensive audit trail
- `user_sessions` - Active user sessions

## Audit Logging

All administrative actions are automatically logged to `admin_audit_logs` with:

- Admin user ID and role at time of action
- Action type and resource details
- Affected user ID
- IP address and user agent
- Timestamp and additional context (JSON)

## Error Handling

All routes follow a consistent error response format:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional error details"
}
```

Common error codes:

- `NO_TOKEN` - No JWT token provided
- `INVALID_TOKEN` - Invalid or expired JWT token
- `ADMIN_ACCESS_REQUIRED` - User does not have admin role
- `INSUFFICIENT_PERMISSIONS` - User lacks required permissions
- `INVALID_USER_ID` - Invalid user ID format
- `USER_NOT_FOUND` - User not found in database

## Database Connection

Each route file manages its own database connection pool with:

- Maximum 50 connections
- 10-minute idle timeout
- 30-second connection timeout
- Automatic error handling and reconnection

## Usage Examples

### List Users

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/users?page=1&limit=50&tier=premium" \
  -H "Authorization: Bearer <jwt_token>"
```

### Get User Details

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/users/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

### Update Subscription

```bash
curl -X PATCH "https://api.cloudtolocalllm.online/api/admin/users/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{"subscriptionTier": "premium", "reason": "Customer request"}'
```

### Suspend User

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/users/550e8400-e29b-41d4-a716-446655440000/suspend" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{"reason": "Terms of service violation"}'
```

### Reactivate User

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/users/550e8400-e29b-41d4-a716-446655440000/reactivate" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{"note": "Issue resolved"}'
```

### List Subscriptions

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/subscriptions?page=1&limit=50&tier=premium&includeUpcoming=true" \
  -H "Authorization: Bearer <jwt_token>"
```

### Get Subscription Details

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/subscriptions/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

### Update Subscription

```bash
curl -X PATCH "https://api.cloudtolocalllm.online/api/admin/subscriptions/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "tier": "enterprise",
    "priceId": "price_1234567890",
    "prorationBehavior": "create_prorations"
  }'
```

### Cancel Subscription

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/subscriptions/550e8400-e29b-41d4-a716-446655440000/cancel" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "immediate": false,
    "reason": "Customer requested cancellation"
  }'
```

### List Audit Logs

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs?page=1&limit=50&action=user_suspended" \
  -H "Authorization: Bearer <jwt_token>"
```

### Get Audit Log Details

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/logs/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

### Export Audit Logs

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/audit/export?startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer <jwt_token>" \
  -o audit-logs.csv
```

### List Administrators

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/admins" \
  -H "Authorization: Bearer <jwt_token>"
```

### Assign Admin Role

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/admins" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "support@example.com",
    "role": "support_admin"
  }'
```

### Revoke Admin Role

```bash
curl -X DELETE "https://api.cloudtolocalllm.online/api/admin/admins/550e8400-e29b-41d4-a716-446655440000/roles/support_admin" \
  -H "Authorization: Bearer <jwt_token>"
```

### Get Dashboard Metrics

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/dashboard/metrics" \
  -H "Authorization: Bearer <jwt_token>"
```

### Generate Revenue Report

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/reports/revenue?startDate=2025-01-01&endDate=2025-01-31&groupBy=true" \
  -H "Authorization: Bearer <jwt_token>"
```

## Testing

### Development Environment

1. Apply database migration:

   ```bash
   node services/api-backend/database/migrations/run-migration.js up 001
   ```

2. Apply seed data:

   ```bash
   node services/api-backend/database/seeds/run-seed.js apply 001
   ```

3. Test with curl or Postman using test admin credentials

### Test Data

The seed data creates:

- 5 test users with different subscription tiers
- 3 admin users (super admin, support admin, finance admin)
- Sample payment transactions and subscriptions
- Sample audit log entries

### Audit Log Management (`audit.js`)

**Status:** ✅ COMPLETED

Provides comprehensive audit trail functionality for all administrative actions including:

- **List Audit Logs** (`GET /audit/logs`) - Paginated audit log listing with filtering
- **Get Audit Log Details** (`GET /audit/logs/:logId`) - Detailed audit log entry with full context
- **Export Audit Logs** (`GET /audit/export`) - Export audit logs to CSV format

**Features:**

- Pagination support (100 logs per page, max 200)
- Filter by admin user, action type, resource type, affected user, and date range
- Sort by created_at, action, resource_type, admin_user_id
- Immutable audit log storage (cannot be modified or deleted)
- CSV export with all filtering options
- Automatic filename generation with timestamp
- IP address and user agent tracking
- Comprehensive admin and affected user details
- JSON details field for additional context

**Permissions Required:**

- `view_audit_logs` - View audit log entries
- `export_audit_logs` - Export audit logs to CSV

**Documentation:** See [AUDIT_API.md](./AUDIT_API.md) for detailed API reference

### Admin Management (`admins.js`)

**Status:** ✅ COMPLETED

Provides Super Admin-only endpoints for managing administrator accounts and roles including:

- **List Administrators** (`GET /admins`) - List all administrators with roles and activity summary
- **Assign Admin Role** (`POST /admins`) - Assign admin role to a user by email
- **Revoke Admin Role** (`DELETE /admins/:userId/roles/:role`) - Revoke admin role from a user

**Features:**

- Super Admin authentication required for all endpoints
- Role assignment history tracking
- Admin activity summary (total actions, last action, recent actions)
- Support for `support_admin` and `finance_admin` roles
- Self-protection: Cannot revoke own Super Admin role
- Duplicate role prevention
- Comprehensive audit logging for all role changes
- User search by email for role assignment

**Permissions Required:**

- Super Admin role required (no granular permissions)

**Valid Roles:**

- `support_admin` - User management and support functions
- `finance_admin` - Financial operations and reporting
- `super_admin` - Full system access (cannot be assigned via API)

**Documentation:** See [ADMINS_API.md](./ADMINS_API.md) for detailed API reference

### Dashboard Metrics (`dashboard.js`)

**Status:** ✅ COMPLETED

Provides comprehensive dashboard metrics for the Admin Center including:

- **Get Dashboard Metrics** (`GET /dashboard/metrics`) - Comprehensive metrics for admin dashboard

**Features:**

- Total registered users count
- Active users (last 30 days)
- New user registrations (current month)
- Subscription tier distribution
- Monthly Recurring Revenue (MRR) calculation
- Total revenue (current month)
- Recent payment transactions (last 10)
- Real-time calculations from database
- Optimized SQL queries with aggregations
- Response time < 500ms for typical datasets

**Permissions Required:**

- Any admin role (no specific permissions required)

**Metrics Provided:**

- User statistics (total, active, new, active percentage)
- Subscription distribution and conversion rate
- Revenue metrics (MRR, current month, average transaction value)
- Recent transactions with user and subscription details
- Date ranges for all calculations

**Documentation:** See [DASHBOARD_API.md](./DASHBOARD_API.md) for detailed API reference

### Financial Reporting (`reports.js`)

**Status:** 🚧 IN PROGRESS

Provides financial and subscription reporting capabilities including:

- **Revenue Report** (`GET /reports/revenue`) - Generate revenue reports with date range filtering

**Features:**

- Date range filtering (up to 1 year)
- Optional tier-based grouping
- Total revenue calculation
- Transaction count and averages
- Revenue breakdown by subscription tier
- Comprehensive audit logging
- Input validation and sanitization

**Permissions Required:**

- `view_reports` - View revenue reports
- `export_reports` - Export reports (planned)

**Planned Features:**

- Subscription metrics report (MRR, churn, retention)
- Report export functionality (CSV, PDF)
- Additional report types

**Documentation:** See [REPORTS_API.md](./REPORTS_API.md) for detailed API reference

## Future Enhancements

Planned routes (see `.kiro/specs/admin-center/tasks.md`):

- Financial reporting endpoints - 🚧 IN PROGRESS
  - Revenue reports - ✅ COMPLETED
  - Subscription metrics (MRR, churn, retention) - 📋 PLANNED
  - Report export (CSV, PDF) - 📋 PLANNED
- Admin management endpoints (role assignment, revocation) - ✅ COMPLETED
- Dashboard metrics endpoint - ✅ COMPLETED
- Email provider configuration (self-hosted only) - 📋 PLANNED

## Documentation

- [Admin API Reference](../../../docs/API/ADMIN_API.md)
- [Admin Center Requirements](../../../.kiro/specs/admin-center/requirements.md)
- [Admin Center Design](../../../.kiro/specs/admin-center/design.md)
- [Admin Center Tasks](../../../.kiro/specs/admin-center/tasks.md)
- [Database Setup Guide](../../database/QUICKSTART.md)

## Support

For issues or questions:

- GitHub Issues: https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues
- Documentation: `/docs/`
- Email: support@cloudtolocalllm.online
