# Admin Dashboard API Documentation

## Overview

The Dashboard API provides comprehensive metrics and statistics for the Admin Center dashboard. It aggregates data from users, subscriptions, and payment transactions to provide real-time insights into system health and business performance.

## Base URL

```
/api/admin/dashboard
```

## Authentication

All endpoints require:

- Valid JWT token in Authorization header
- Admin role (any admin role has access)

## Endpoints

### GET /metrics

Get comprehensive dashboard metrics for the Admin Center.

**Authentication Required:** Yes (any admin role)

**Query Parameters:** None

**Response:**

```json
{
  "success": true,
  "data": {
    "users": {
      "total": 1250,
      "active": 450,
      "newThisMonth": 85,
      "activePercentage": "36.00"
    },
    "subscriptions": {
      "distribution": {
        "free": 1000,
        "premium": 200,
        "enterprise": 50
      },
      "totalSubscribed": 250,
      "conversionRate": "20.00"
    },
    "revenue": {
      "mrr": "3497.50",
      "currentMonth": "3850.75",
      "transactionCount": 125,
      "averageTransactionValue": "30.81"
    },
    "recentTransactions": [
      {
        "id": "uuid",
        "userId": "uuid",
        "userEmail": "user@example.com",
        "amount": "29.99",
        "currency": "USD",
        "status": "succeeded",
        "paymentMethod": "card",
        "last4": "4242",
        "subscriptionTier": "enterprise",
        "createdAt": "2025-11-16T10:30:00Z"
      }
    ],
    "period": {
      "currentMonth": {
        "start": "2025-11-01T00:00:00Z",
        "end": "2025-11-30T23:59:59Z"
      },
      "last30Days": {
        "start": "2025-10-17T10:30:00Z",
        "end": "2025-11-16T10:30:00Z"
      }
    }
  },
  "timestamp": "2025-11-16T10:30:00Z"
}
```

**Response Fields:**

- `users.total`: Total number of registered users (excluding deleted)
- `users.active`: Number of users with activity in last 30 days
- `users.newThisMonth`: New user registrations in current month
- `users.activePercentage`: Percentage of total users that are active

- `subscriptions.distribution`: Count of users by subscription tier
- `subscriptions.totalSubscribed`: Total paid subscribers (premium + enterprise)
- `subscriptions.conversionRate`: Percentage of users with paid subscriptions

- `revenue.mrr`: Monthly Recurring Revenue (based on active subscriptions)
- `revenue.currentMonth`: Total revenue for current month
- `revenue.transactionCount`: Number of successful transactions this month
- `revenue.averageTransactionValue`: Average transaction amount

- `recentTransactions`: Array of last 10 payment transactions
- `period`: Date ranges used for calculations

**Error Responses:**

```json
{
  "error": "Failed to retrieve dashboard metrics",
  "code": "DASHBOARD_METRICS_FAILED",
  "details": "Database connection error"
}
```

**Status Codes:**

- `200 OK`: Metrics retrieved successfully
- `401 Unauthorized`: Invalid or missing authentication token
- `403 Forbidden`: User does not have admin privileges
- `500 Internal Server Error`: Server error occurred

## Metrics Calculations

### Active Users

Users with at least one session activity in the last 30 days.

### New Users This Month

Users registered between the 1st and last day of the current month.

### Subscription Tier Distribution

Count of users by their active subscription tier. Users without active subscriptions are counted as "free".

### Monthly Recurring Revenue (MRR)

Calculated as:

```
MRR = (Premium Users × $9.99) + (Enterprise Users × $29.99)
```

### Current Month Revenue

Sum of all successful payment transactions in the current calendar month.

### Conversion Rate

Percentage of total users with paid subscriptions:

```
Conversion Rate = (Paid Subscribers / Total Users) × 100
```

## Usage Examples

### cURL

```bash
curl -X GET https://api.cloudtolocalllm.online/api/admin/dashboard/metrics \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### JavaScript (Fetch)

```javascript
const response = await fetch('/api/admin/dashboard/metrics', {
  method: 'GET',
  headers: {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  },
});

const data = await response.json();
console.log('Dashboard Metrics:', data.data);
```

### Dart (dio)

```dart
final response = await dio.get(
  '/api/admin/dashboard/metrics',
  options: Options(
    headers: {
      'Authorization': 'Bearer $token',
    },
  ),
);

final metrics = response.data['data'];
print('Total Users: ${metrics['users']['total']}');
print('MRR: \$${metrics['revenue']['mrr']}');
```

## Performance Considerations

- Metrics are calculated in real-time from the database
- Response time typically < 500ms for databases with < 100K users
- Consider implementing caching for high-traffic scenarios
- Recommended refresh interval: 60 seconds

## Security Notes

- All endpoints require admin authentication
- No sensitive payment information (full card numbers, CVV) is exposed
- Only last 4 digits of payment methods are included
- All admin actions are logged in audit logs

## Related Endpoints

- `GET /api/admin/users` - Detailed user management
- `GET /api/admin/payments/transactions` - Payment transaction details
- `GET /api/admin/subscriptions` - Subscription management
- `GET /api/admin/reports/revenue` - Detailed revenue reports

## Changelog

### Version 1.0.0 (2025-11-16)

- Initial implementation
- Dashboard metrics endpoint
- Real-time calculations
- Recent transactions list
