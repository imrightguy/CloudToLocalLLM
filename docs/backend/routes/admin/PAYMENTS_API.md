# Payment Management API Reference

## Overview

The Payment Management API provides secure administrative endpoints for managing payment transactions, processing refunds, and viewing payment methods. All endpoints require admin authentication with specific permissions.

**Base URL:** `/api/admin/payments`

**Authentication:** JWT Bearer token with admin role

**Permissions Required:**

- `view_payments` - View transactions and payment methods
- `process_refunds` - Process refunds

---

## Endpoints

### 1. List Payment Transactions

**Endpoint:** `GET /api/admin/payments/transactions`

**Permission:** `view_payments`

**Description:** Retrieve a paginated list of payment transactions with filtering and sorting capabilities.

**Query Parameters:**

| Parameter | Type     | Default    | Description                                                                           |
| --------- | -------- | ---------- | ------------------------------------------------------------------------------------- |
| page      | integer  | 1          | Page number (min: 1)                                                                  |
| limit     | integer  | 100        | Items per page (min: 1, max: 200)                                                     |
| userId    | UUID     | -          | Filter by user ID                                                                     |
| status    | string   | -          | Filter by status (pending, succeeded, failed, refunded, partially_refunded, disputed) |
| startDate | ISO 8601 | -          | Filter by date range (start)                                                          |
| endDate   | ISO 8601 | -          | Filter by date range (end)                                                            |
| minAmount | decimal  | -          | Filter by minimum amount                                                              |
| maxAmount | decimal  | -          | Filter by maximum amount                                                              |
| sortBy    | string   | created_at | Sort field (created_at, amount, status)                                               |
| sortOrder | string   | desc       | Sort order (asc, desc)                                                                |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/payments/transactions?page=1&limit=50&status=succeeded&sortBy=amount&sortOrder=desc" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "transactions": [
      {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "user_id": "660e8400-e29b-41d4-a716-446655440001",
        "subscription_id": "770e8400-e29b-41d4-a716-446655440002",
        "stripe_payment_intent_id": "pi_1234567890",
        "stripe_charge_id": "ch_1234567890",
        "amount": 29.99,
        "currency": "USD",
        "status": "succeeded",
        "payment_method_type": "card",
        "payment_method_last4": "4242",
        "failure_code": null,
        "failure_message": null,
        "receipt_url": "https://stripe.com/receipts/...",
        "created_at": "2025-01-15T10:30:00Z",
        "updated_at": "2025-01-15T10:30:00Z",
        "user_email": "user@example.com",
        "user_username": "johndoe",
        "refund_count": 0,
        "total_refunded": null
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 50,
      "totalTransactions": 150,
      "totalPages": 3,
      "hasNextPage": true,
      "hasPreviousPage": false
    },
    "filters": {
      "userId": null,
      "status": "succeeded",
      "startDate": null,
      "endDate": null,
      "minAmount": null,
      "maxAmount": null,
      "sortBy": "amount",
      "sortOrder": "DESC"
    },
    "statistics": {
      "totalCount": 150,
      "totalRevenue": 4498.5,
      "successfulCount": 145,
      "failedCount": 3,
      "refundedCount": 2
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request` - Invalid query parameters
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Insufficient permissions
- `500 Internal Server Error` - Server error

---

### 2. Get Transaction Details

**Endpoint:** `GET /api/admin/payments/transactions/:transactionId`

**Permission:** `view_payments`

**Description:** Retrieve detailed information about a specific transaction including user info, payment method, refunds, and subscription.

**Path Parameters:**

| Parameter     | Type | Description    |
| ------------- | ---- | -------------- |
| transactionId | UUID | Transaction ID |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/payments/transactions/550e8400-e29b-41d4-a716-446655440000" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "transaction": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "user_id": "660e8400-e29b-41d4-a716-446655440001",
      "subscription_id": "770e8400-e29b-41d4-a716-446655440002",
      "stripe_payment_intent_id": "pi_1234567890",
      "stripe_charge_id": "ch_1234567890",
      "amount": 29.99,
      "currency": "USD",
      "status": "succeeded",
      "payment_method_type": "card",
      "payment_method_last4": "4242",
      "failure_code": null,
      "failure_message": null,
      "receipt_url": "https://stripe.com/receipts/...",
      "created_at": "2025-01-15T10:30:00Z",
      "updated_at": "2025-01-15T10:30:00Z",
      "metadata": {}
    },
    "user": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "user@example.com",
      "username": "johndoe",
      "auth0_id": "auth0|123456789",
      "created_at": "2025-01-01T00:00:00Z",
      "is_suspended": false
    },
    "paymentMethod": {
      "id": "880e8400-e29b-41d4-a716-446655440003",
      "stripe_payment_method_id": "pm_1234567890",
      "type": "card",
      "card_brand": "visa",
      "card_last4": "4242",
      "card_exp_month": 12,
      "card_exp_year": 2025,
      "billing_email": "us***@example.com",
      "billing_name": "John Doe",
      "is_default": true,
      "status": "active"
    },
    "refunds": [],
    "subscription": {
      "id": "770e8400-e29b-41d4-a716-446655440002",
      "stripe_subscription_id": "sub_1234567890",
      "stripe_customer_id": "cus_1234567890",
      "tier": "premium",
      "status": "active",
      "current_period_start": "2025-01-15T10:30:00Z",
      "current_period_end": "2025-02-15T10:30:00Z",
      "cancel_at_period_end": false,
      "canceled_at": null,
      "created_at": "2025-01-15T10:30:00Z"
    },
    "summary": {
      "originalAmount": 29.99,
      "totalRefunded": 0,
      "netAmount": 29.99,
      "refundCount": 0,
      "isFullyRefunded": false
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request` - Invalid transaction ID format
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Transaction not found
- `500 Internal Server Error` - Server error

---

### 3. Process Refund

**Endpoint:** `POST /api/admin/payments/refunds`

**Permission:** `process_refunds`

**Description:** Process a full or partial refund for a transaction through Stripe.

**Request Body:**

```json
{
  "transactionId": "550e8400-e29b-41d4-a716-446655440000",
  "amount": 29.99,
  "reason": "customer_request",
  "reasonDetails": "Customer requested refund due to service not meeting expectations"
}
```

**Body Parameters:**

| Parameter     | Type    | Required | Description                             |
| ------------- | ------- | -------- | --------------------------------------- |
| transactionId | UUID    | Yes      | Transaction ID to refund                |
| amount        | decimal | No       | Amount to refund (null for full refund) |
| reason        | string  | Yes      | Refund reason (see valid reasons below) |
| reasonDetails | string  | No       | Additional details about the refund     |

**Valid Refund Reasons:**

- `customer_request` - Customer requested refund
- `billing_error` - Billing error occurred
- `service_issue` - Service quality issue
- `duplicate` - Duplicate charge
- `fraudulent` - Fraudulent transaction
- `other` - Other reason

**Example Request:**

```bash
curl -X POST "https://api.cloudtolocalllm.online/api/admin/payments/refunds" \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "transactionId": "550e8400-e29b-41d4-a716-446655440000",
    "amount": 29.99,
    "reason": "customer_request",
    "reasonDetails": "Customer requested refund"
  }'
```

**Example Response:**

```json
{
  "success": true,
  "message": "Refund processed successfully",
  "data": {
    "refund": {
      "id": "990e8400-e29b-41d4-a716-446655440004",
      "transaction_id": "550e8400-e29b-41d4-a716-446655440000",
      "stripe_refund_id": "re_1234567890",
      "amount": 29.99,
      "currency": "USD",
      "reason": "customer_request",
      "reason_details": "Customer requested refund",
      "status": "succeeded",
      "failure_reason": null,
      "admin_user_id": "aa0e8400-e29b-41d4-a716-446655440005",
      "created_at": "2025-01-20T15:00:00Z",
      "updated_at": "2025-01-20T15:00:00Z"
    },
    "transaction": {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "originalAmount": 29.99,
      "totalRefunded": 29.99,
      "remainingAmount": 0
    },
    "stripeRefund": {
      "id": "re_1234567890",
      "status": "succeeded",
      "amount": 2999,
      "currency": "usd"
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Error Responses:**

- `400 Bad Request` - Invalid request (missing fields, invalid amount, etc.)
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - Transaction not found
- `500 Internal Server Error` - Server error

**Error Codes:**

- `TRANSACTION_ID_REQUIRED` - Transaction ID is required
- `REASON_REQUIRED` - Refund reason is required
- `INVALID_TRANSACTION_ID` - Invalid transaction ID format
- `INVALID_REASON` - Invalid refund reason
- `INVALID_AMOUNT` - Refund amount must be a positive number
- `TRANSACTION_NOT_FOUND` - Transaction not found
- `INVALID_TRANSACTION_STATUS` - Cannot refund transaction with current status
- `AMOUNT_EXCEEDS_REMAINING` - Refund amount exceeds remaining refundable amount
- `REFUND_PROCESSING_FAILED` - Refund processing failed

---

### 4. Get User Payment Methods

**Endpoint:** `GET /api/admin/payments/methods/:userId`

**Permission:** `view_payments`

**Description:** Retrieve all payment methods for a user with masked sensitive data (PCI DSS compliant).

**Path Parameters:**

| Parameter | Type | Description |
| --------- | ---- | ----------- |
| userId    | UUID | User ID     |

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/payments/methods/660e8400-e29b-41d4-a716-446655440001" \
  -H "Authorization: Bearer <jwt_token>"
```

**Example Response:**

```json
{
  "success": true,
  "data": {
    "user": {
      "id": "660e8400-e29b-41d4-a716-446655440001",
      "email": "user@example.com",
      "username": "johndoe"
    },
    "paymentMethods": [
      {
        "id": "880e8400-e29b-41d4-a716-446655440003",
        "stripe_payment_method_id": "pm_1234567890",
        "type": "card",
        "card_brand": "visa",
        "card_last4": "4242",
        "card_exp_month": 12,
        "card_exp_year": 2025,
        "billing_email": "us***@example.com",
        "billing_name": "John Doe",
        "is_default": true,
        "status": "active",
        "created_at": "2025-01-15T10:30:00Z",
        "updated_at": "2025-01-15T10:30:00Z",
        "is_expired": false,
        "usage": {
          "transactionCount": 5,
          "totalSpent": 149.95,
          "lastUsed": "2025-01-20T10:00:00Z"
        }
      }
    ],
    "summary": {
      "totalMethods": 1,
      "activeMethods": 1,
      "expiredMethods": 0,
      "defaultMethod": {
        "id": "880e8400-e29b-41d4-a716-446655440003",
        "card_brand": "visa",
        "card_last4": "4242"
      }
    }
  },
  "timestamp": "2025-01-20T15:00:00Z"
}
```

**Security Notes:**

- Billing email is masked (only first 2 characters and domain shown)
- Only last 4 digits of card number are returned
- No CVV or full card numbers are ever returned
- Complies with PCI DSS requirements

**Error Responses:**

- `400 Bad Request` - Invalid user ID format
- `401 Unauthorized` - Missing or invalid JWT token
- `403 Forbidden` - Insufficient permissions
- `404 Not Found` - User not found
- `500 Internal Server Error` - Server error

---

## Common Error Response Format

All endpoints follow a consistent error response format:

```json
{
  "error": "Error message",
  "code": "ERROR_CODE",
  "details": "Additional error details"
}
```

## Rate Limiting

Admin API endpoints are rate-limited to prevent abuse:

- **100 requests per minute** per admin user
- **Burst allowance**: 20 requests
- **Response headers** include rate limit information

## Audit Logging

All payment management actions are automatically logged to the `admin_audit_logs` table with:

- Admin user ID and role
- Action type and resource details
- Affected user ID
- IP address and user agent
- Timestamp and additional context

## Best Practices

1. **Always include reason fields** when processing refunds
2. **Check transaction status** before attempting refunds
3. **Handle errors gracefully** with proper error messages
4. **Log all administrative actions** for compliance
5. **Use pagination** for large result sets
6. **Validate input** before making API calls
7. **Store JWT tokens securely** and refresh before expiration
8. **Never log or store** full card numbers or CVV codes

## Support

For API support or questions:

- Documentation: `/docs/API/`
- Issues: GitHub Issues
- Email: support@cloudtolocalllm.online
