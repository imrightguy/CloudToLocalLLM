# Subscription Management API - Quick Reference

## Endpoints Overview

| Method | Endpoint                              | Permission         | Description                       |
| ------ | ------------------------------------- | ------------------ | --------------------------------- |
| GET    | `/api/admin/subscriptions`            | view_subscriptions | List subscriptions with filtering |
| GET    | `/api/admin/subscriptions/:id`        | view_subscriptions | Get subscription details          |
| PATCH  | `/api/admin/subscriptions/:id`        | edit_subscriptions | Update subscription tier          |
| POST   | `/api/admin/subscriptions/:id/cancel` | edit_subscriptions | Cancel subscription               |

## Quick Examples

### List Subscriptions

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/subscriptions?tier=premium&includeUpcoming=true" \
  -H "Authorization: Bearer <token>"
```

### Get Subscription Details

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/subscriptions/{id}" \
  -H "Authorization: Bearer <token>"
```

### Update Subscription Tier

```bash
curl -X PATCH "https://api.cloudtolocalllm.online/api/admin/subscriptions/{id}" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"tier": "enterprise", "priceId": "price_xxx"}'
```

### Cancel Subscription (End of Period)

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/subscriptions/{id}/cancel" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"immediate": false, "reason": "Customer request"}'
```

### Cancel Subscription (Immediate)

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/subscriptions/{id}/cancel" \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"immediate": true, "reason": "Terms violation"}'
```

## Query Parameters

### List Subscriptions

- `page` - Page number (default: 1)
- `limit` - Items per page (default: 50, max: 200)
- `tier` - Filter by tier (free, premium, enterprise)
- `status` - Filter by status (active, canceled, past_due, trialing, incomplete)
- `userId` - Filter by user ID
- `includeUpcoming` - Include upcoming renewals (default: false)
- `sortBy` - Sort field (created_at, current_period_end, tier, status, updated_at)
- `sortOrder` - Sort order (asc, desc)

## Request Bodies

### Update Subscription

```json
{
  "tier": "enterprise",
  "priceId": "price_1234567890",
  "prorationBehavior": "create_prorations"
}
```

**Proration Behaviors:**

- `create_prorations` - Create proration invoice items (default)
- `none` - No proration, charge full amount at next billing
- `always_invoice` - Always create an invoice immediately

### Cancel Subscription

```json
{
  "immediate": false,
  "reason": "Customer requested cancellation"
}
```

## Response Formats

### List Response

```json
{
  "success": true,
  "data": {
    "subscriptions": [...],
    "pagination": {
      "page": 1,
      "limit": 50,
      "totalCount": 150,
      "totalPages": 3,
      "hasNextPage": true,
      "hasPreviousPage": false
    },
    "upcomingRenewals": [...]
  }
}
```

### Details Response

```json
{
  "success": true,
  "data": {
    "id": "...",
    "tier": "premium",
    "status": "active",
    "user": {...},
    "billingCycle": {...},
    "paymentHistory": [...],
    "paymentStats": {...}
  }
}
```

### Update Response

```json
{
  "success": true,
  "data": {
    "subscription": {...},
    "prorationDetails": {
      "proratedAmount": 70.00,
      "currency": "usd",
      "nextInvoiceDate": "...",
      "lineItems": [...]
    },
    "message": "Subscription upgraded from premium to enterprise"
  }
}
```

### Cancel Response

```json
{
  "success": true,
  "data": {
    "subscription": {...},
    "cancellationType": "end_of_period",
    "effectiveDate": "...",
    "refundInfo": {...},
    "message": "..."
  }
}
```

## Error Codes

| Code                           | Status | Description                      |
| ------------------------------ | ------ | -------------------------------- |
| SUBSCRIPTION_LIST_FAILED       | 500    | Failed to retrieve subscriptions |
| SUBSCRIPTION_NOT_FOUND         | 404    | Subscription not found           |
| SUBSCRIPTION_DETAILS_FAILED    | 500    | Failed to retrieve details       |
| INVALID_REQUEST                | 400    | Missing required fields          |
| INVALID_TIER                   | 400    | Invalid subscription tier        |
| SUBSCRIPTION_NOT_ACTIVE        | 400    | Subscription not active/trialing |
| SUBSCRIPTION_UPDATE_FAILED     | 500    | Update operation failed          |
| SUBSCRIPTION_ALREADY_CANCELED  | 400    | Already canceled                 |
| SUBSCRIPTION_ALREADY_CANCELING | 400    | Already set to cancel            |
| SUBSCRIPTION_CANCEL_FAILED     | 500    | Cancellation failed              |

## Permissions

- **view_subscriptions** - View subscription list and details
- **edit_subscriptions** - Update and cancel subscriptions

## Roles with Permissions

- **Super Admin** - All permissions
- **Finance Admin** - view_subscriptions, edit_subscriptions
- **Support Admin** - view_subscriptions only

## Important Notes

1. **Refunds are NOT automatic** - When canceling immediately, use the refunds endpoint separately
2. **Proration is automatic** - Tier changes calculate prorated charges via Stripe
3. **End-of-period is default** - Users retain access until billing period ends
4. **Audit logging is automatic** - All actions are logged with admin details
5. **Stripe sync is automatic** - All changes are reflected in Stripe immediately

## See Also

- [Full API Documentation](./SUBSCRIPTIONS_API.md)
- [Implementation Summary](./IMPLEMENTATION_SUMMARY.md)
- [Admin API Overview](../../../docs/API/ADMIN_API.md)
