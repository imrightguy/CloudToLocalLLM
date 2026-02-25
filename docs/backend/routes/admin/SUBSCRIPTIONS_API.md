# Subscription Management API Reference

## Overview

The Subscription Management API provides secure administrative endpoints for managing user subscriptions, including viewing, updating, and canceling subscriptions. All endpoints require admin authentication with specific permissions.

**Base URL:** `/api/admin/subscriptions`

**Authentication:** JWT Bearer token with admin role

**Permissions Required:**

- `view_subscriptions` - View subscription list and details
- `edit_subscriptions` - Update and cancel subscriptions

---

## Endpoints

### 1. List Subscriptions

**Endpoint:** `GET /api/admin/subscriptions`

**Permission:** `view_subscriptions`

**Description:** Retrieve a paginated list of subscriptions with filtering and sorting capabilities.

**Query Parameters:**

| Parameter       | Type    | Default    | Description                                                           |
| --------------- | ------- | ---------- | --------------------------------------------------------------------- |
| page            | integer | 1          | Page number (min: 1)                                                  |
| limit           | integer | 50         | Items per page (min: 1, max: 200)                                     |
| tier            | string  | -          | Filter by tier (free, premium, enterprise)                            |
| status          | string  | -          | Filter by status (active, canceled, past_due, trialing, incomplete)   |
| userId          | UUID    | -          | Filter by user ID                                                     |
| includeUpcoming | boolean | false      | Include upcoming renewals (next 7 days)                               |
| sortBy          | string  | created_at | Sort field (created_at, current_period_end, tier, status, updated_at) |
| sortOrder       | string  | desc       | Sort order (asc, desc)                                                |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/subscriptions?page=1&limit=50&tier=premium&includeUpcoming=true" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "subscriptions": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "userId": "660e8400-e29b-41d4-a716-446655440001",
        "stripeSubscriptionId": "sub_1234567890",
        "stripeCustomerId": "cus_1234567890",
        "tier": "premium",
        "status": "active",
        "currentPeriodStart": "2025-01-15T10:30:00Z",
        "currentPeriodEnd": "2025-02-15T10:30:00Z",
        "cancelAtPeriodEnd": false,
        "canceledAt": null,
        "trialStart": null,
        "trialEnd": null,
        "createdAt": "2025-01-15T10:30:00Z",
        "updatedAt": "2025-01-15T10:30:00Z",
        "metadata": {},
        "user": {
          "email": "user@example.com",
          "username": "johndoe",
          "status": "active"
        }
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "totalCount": 150,
      "totalPages": 3,
      "hasNextPage": true,
      "hasPreviousPage": false
    },
    "upcomingRenewals": [
      {
        "id": "770e8400-e29b-41d4-a716-446655440002",
        "userId": "880e8400-e29b-41d4-a716-446655440003",
        "tier": "enterprise",
        "currentPeriodEnd": "2025-01-22T10:30:00Z",
        "userEmail": "enterprise@example.com"
      }
    ]
  }
}
```

**Error Responses:**

- `400 Bad Request` - Invalid query parameters
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Insufficient permissions
- `500 Internal Server Error` - Server error

---

### 2. Get Subscription Details

**Endpoint:** `GET /api/admin/subscriptions/:subscriptionId`

**Permission:** `view_subscriptions`

**Description:** Retrieve detailed information about a specific subscription including user info, payment history, billing cycle, and payment statistics.

**Path Parameters:**

| Parameter      | Type | Description     |
| -------------- | ---- | --------------- |
| subscriptionId | UUID | Subscription ID |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/subscriptions/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "userId": "660e8400-e29b-41d4-a716-446655440001",
    "stripeSubscriptionId": "sub_1234567890",
    "stripeCustomerId": "cus_1234567890",
    "tier": "premium",
    "status": "active",
    "currentPeriodStart": "2025-01-15T10:30:00Z",
    "currentPeriodEnd": "2025-02-15T10:30:00Z",
    "cancelAtPeriodEnd": false,
    "canceledAt": null,
    "trialStart": null,
    "trialEnd": null,
    "createdAt": "2025-01-15T10:30:00Z",
    "updatedAt": "2025-01-15T10:30:00Z",
    "metadata": {},
    "user": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "user@example.com",
      "username": "johndoe",
      "status": "active",
      "createdAt": "2025-01-01T00:00:00Z",
      "lastLogin": "2025-01-20T14:22:00Z"
    },
    "billingCycle": {
      "currentPeriodStart": "2025-01-15T10:30:00Z",
      "currentPeriodEnd": "2025-02-15T10:30:00Z",
      "daysRemaining": 25,
      "daysInCycle": 31,
      "nextBillingDate": "2025-02-15T10:30:00Z",
      "willRenew": true
    },
    "paymentHistory": [
      {
        "id": "990e8400-e29b-41d4-a716-446655440004",
        "amount": 29.99,
        "currency": "USD",
        "status": "succeeded",
        "paymentMethodType": "card",
        "paymentMethodLast4": "4242",
        "receiptUrl": "https://stripe.com/receipts/...",
        "createdAt": "2025-01-15T10:30:00Z",
        "metadata": {}
      }
    ],
    "paymentStats": {
      "totalTransactions": 5,
      "successfulTransactions": 5,
      "failedTransactions": 0,
      "totalAmountPaid": 149.95,
      "currency": "USD"
    }
  }
}
```

**Error Responses:**

- `400 Bad Request` - Invalid subscription ID format
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Subscription not found
- `500 Internal Server Error` - Server error

---

### 3. Update Subscription

**Endpoint:** `PATCH /api/admin/subscriptions/:subscriptionId`

**Permission:** `edit_subscriptions`

**Description:** Update a subscription tier (upgrade or downgrade) with automatic proration calculation.

**Path Parameters:**

| Parameter      | Type | Description     |
| -------------- | ---- | --------------- |
| subscriptionId | UUID | Subscription ID |

**Request Body:**

```json
{
  "tier": "enterprise",
  "priceId": "price_1234567890",
  "prorationBehavior": "create_prorations"
}
```

**Body Parameters:**

| Parameter         | Type   | Required | Description                                                                               |
| ----------------- | ------ | -------- | ----------------------------------------------------------------------------------------- |
| tier              | string | Yes      | New subscription tier (free, premium, enterprise)                                         |
| priceId           | string | Yes      | Stripe price ID for the new tier                                                          |
| prorationBehavior | string | No       | Proration behavior (create_prorations, none, always_invoice) (default: create_prorations) |

**Proration Behaviors:**

- `create_prorations` - Create proration invoice items (default)
- `none` - No proration, charge full amount at next billing
- `always_invoice` - Always create an invoice immediately

**Example Request:**

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

**Example Response:**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "tier": "enterprise",
      "status": "active",
      "currentPeriodStart": "2025-01-15T10:30:00Z",
      "currentPeriodEnd": "2025-02-15T10:30:00Z",
      "updatedAt": "2025-01-20T15:00:00Z"
    },
    "prorationDetails": {
      "proratedAmount": 70.0,
      "currency": "usd",
      "nextInvoiceDate": "2025-02-15T10:30:00Z",
      "lineItems": [
        {
          "description": "Remaining time on Premium after 15 Jan 2025",
          "amount": -10.0,
          "period": {
            "start": "2025-01-20T15:00:00Z",
            "end": "2025-02-15T10:30:00Z"
          }
        },
        {
          "description": "Remaining time on Enterprise after 20 Jan 2025",
          "amount": 80.0,
          "period": {
            "start": "2025-01-20T15:00:00Z",
            "end": "2025-02-15T10:30:00Z"
          }
        }
      ]
    },
    "message": "Subscription upgraded from premium to enterprise"
  }
}
```

**Error Responses:**

- `400 Bad Request` - Invalid request (missing fields, invalid tier, subscription not active)
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Subscription not found
- `500 Internal Server Error` - Server error

**Error Codes:**

- `INVALID_REQUEST` - Missing required fields
- `INVALID_TIER` - Invalid subscription tier
- `SUBSCRIPTION_NOT_FOUND` - Subscription not found
- `SUBSCRIPTION_NOT_ACTIVE` - Can only update active or trialing subscriptions
- `SUBSCRIPTION_UPDATE_FAILED` - Update operation failed

---

### 4. Cancel Subscription

**Endpoint:** `POST /api/admin/subscriptions/:subscriptionId/cancel`

**Permission:** `edit_subscriptions`

**Description:** Cancel a subscription immediately or at the end of the billing period. Includes automatic refund eligibility calculation for immediate cancellations.

**Path Parameters:**

| Parameter      | Type | Description     |
| -------------- | ---- | --------------- |
| subscriptionId | UUID | Subscription ID |

**Request Body:**

```json
{
  "immediate": false,
  "reason": "Customer requested cancellation"
}
```

**Body Parameters:**

| Parameter | Type    | Required | Description                                                         |
| --------- | ------- | -------- | ------------------------------------------------------------------- |
| immediate | boolean | No       | Cancel immediately (true) or at period end (false) (default: false) |
| reason    | string  | Yes      | Reason for cancellation (required for audit trail)                  |

**Example Request (End of Period):**

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/subscriptions/550e8400-e29b-41d4-a716-446655440000/cancel" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "immediate": false,
    "reason": "Customer requested cancellation"
  }'
```

**Example Response (End of Period):**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "active",
      "cancelAtPeriodEnd": true,
      "canceledAt": "2025-01-20T15:00:00Z",
      "currentPeriodEnd": "2025-02-15T10:30:00Z"
    },
    "cancellationType": "end_of_period",
    "effectiveDate": "2025-02-15T10:30:00Z",
    "refundInfo": null,
    "message": "Subscription will be canceled at the end of the current billing period (2025-02-15). User will retain access until then."
  }
}
```

**Example Request (Immediate):**

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/subscriptions/550e8400-e29b-41d4-a716-446655440000/cancel" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "immediate": true,
    "reason": "Terms of service violation"
  }'
```

**Example Response (Immediate with Refund Info):**

```json
{
  "success": true,
  "data": {
    "subscription": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "status": "canceled",
      "cancelAtPeriodEnd": false,
      "canceledAt": "2025-01-20T15:00:00Z"
    },
    "cancellationType": "immediate",
    "effectiveDate": "2025-01-20T15:00:00Z",
    "refundInfo": {
      "eligibleForRefund": true,
      "proratedAmount": 19.35,
      "currency": "USD",
      "daysRemaining": 25,
      "totalDays": 31,
      "note": "Refund must be processed separately through the refunds endpoint"
    },
    "message": "Subscription canceled immediately. User access has been revoked."
  }
}
```

**Refund Information:**

When `immediate: true` is specified, the response includes `refundInfo` with:

- `eligibleForRefund` - Whether the user is eligible for a prorated refund
- `proratedAmount` - Calculated prorated refund amount based on days remaining
- `currency` - Currency of the refund
- `daysRemaining` - Days remaining in the billing cycle
- `totalDays` - Total days in the billing cycle
- `note` - Instructions for processing the refund

**Important:** The refund is NOT automatically processed. Admins must manually process the refund using the `/api/admin/payments/refunds` endpoint if desired.

**Error Responses:**

- `400 Bad Request` - Invalid request (missing reason, subscription already canceled, etc.)
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Subscription not found
- `500 Internal Server Error` - Server error

**Error Codes:**

- `INVALID_REQUEST` - Missing cancellation reason
- `SUBSCRIPTION_NOT_FOUND` - Subscription not found
- `SUBSCRIPTION_ALREADY_CANCELED` - Subscription is already canceled
- `SUBSCRIPTION_ALREADY_CANCELING` - Subscription is already set to cancel at period end
- `SUBSCRIPTION_CANCEL_FAILED` - Cancellation operation failed

---

## Common Error Response Format

All endpoints follow a consistent error response format:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": "Additional error details (development only)"
  }
}
```

## Rate Limiting

Admin API endpoints are rate-limited to prevent abuse:

- **100 requests per minute** per admin user
- **Burst allowance**: 20 requests
- **Response headers** include rate limit information

## Audit Logging

All subscription management actions are automatically logged to the `admin_audit_logs` table with:

- Admin user ID and role
- Action type and resource details
- Affected user ID
- Old and new values (for updates)
- Proration details (for tier changes)
- Cancellation reason and type
- IP address and user agent
- Timestamp and additional context

## Best Practices

1. **Always include reason fields** when canceling subscriptions
2. **Check subscription status** before performing operations
3. **Use end-of-period cancellation** by default to maintain user goodwill
4. **Calculate proration** before tier changes to inform users of charges
5. **Process refunds separately** for immediate cancellations
6. **Handle errors gracefully** with proper error messages
7. **Log all administrative actions** for compliance
8. **Use pagination** for large result sets
9. **Validate input** before making API calls
10. **Store JWT tokens securely** and refresh before expiration

## Integration with Stripe

All subscription operations are synchronized with Stripe:

- **Tier changes** update Stripe subscription items with proration
- **Cancellations** are reflected in Stripe immediately
- **Billing cycles** are managed by Stripe
- **Invoices** are generated automatically by Stripe
- **Webhooks** keep database in sync with Stripe events

## Support

For API support or questions:

- Documentation: `/docs/API/`
- Issues: GitHub Issues
- Email: support@cloudtolocalllm.online
