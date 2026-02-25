# Admin Reports API Documentation

## Overview

The Admin Reports API provides comprehensive financial and subscription reporting capabilities for administrators. All endpoints require admin authentication with appropriate permissions.

**Base Path:** `/api/admin/reports`

**Authentication:** JWT token with admin role required

**Permissions Required:**

- `view_reports` - View revenue and subscription reports
- `export_reports` - Export reports to CSV/PDF formats

---

## Endpoints

### 1. Revenue Report

Generate revenue report for a specified date range with optional tier breakdown.

**Endpoint:** `GET /api/admin/reports/revenue`

**Required Permission:** `view_reports`

**Query Parameters:**

| Parameter   | Type    | Required | Description                                         |
| ----------- | ------- | -------- | --------------------------------------------------- |
| `startDate` | string  | Yes      | Start date in ISO 8601 format (YYYY-MM-DD)          |
| `endDate`   | string  | Yes      | End date in ISO 8601 format (YYYY-MM-DD)            |
| `groupBy`   | boolean | No       | Group results by subscription tier (default: false) |

**Constraints:**

- Date range cannot exceed 1 year
- `startDate` must be before or equal to `endDate`
- Dates must be in ISO 8601 format

**Response:**

```json
{
  "period": {
    "startDate": "2025-01-01T00:00:00.000Z",
    "endDate": "2025-01-31T23:59:59.999Z"
  },
  "totalRevenue": 15420.5,
  "transactionCount": 342,
  "averageTransactionValue": 45.09,
  "revenueByTier": [
    {
      "tier": "premium",
      "transactionCount": 200,
      "totalRevenue": 10000.0,
      "averageTransactionValue": 50.0
    },
    {
      "tier": "enterprise",
      "transactionCount": 100,
      "totalRevenue": 5000.0,
      "averageTransactionValue": 50.0
    },
    {
      "tier": "free",
      "transactionCount": 42,
      "totalRevenue": 420.5,
      "averageTransactionValue": 10.01
    }
  ]
}
```

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/reports/revenue?startDate=2025-01-01&endDate=2025-01-31&groupBy=true" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Error Responses:**

- `400 Bad Request` - Missing or invalid parameters
- `401 Unauthorized` - Invalid or missing JWT token
- `403 Forbidden` - Insufficient permissions
- `500 Internal Server Error` - Server error

---

### 2. Subscription Metrics Report

Generate subscription metrics including MRR, churn rate, and retention metrics.

**Endpoint:** `GET /api/admin/reports/subscriptions`

**Required Permission:** `view_reports`

**Query Parameters:**

| Parameter   | Type    | Required | Description                                             |
| ----------- | ------- | -------- | ------------------------------------------------------- |
| `startDate` | string  | No       | Start date in ISO 8601 format (defaults to 30 days ago) |
| `endDate`   | string  | No       | End date in ISO 8601 format (defaults to now)           |
| `groupBy`   | boolean | No       | Group results by subscription tier (default: true)      |

**Response:**

```json
{
  "period": {
    "startDate": "2025-01-01T00:00:00.000Z",
    "endDate": "2025-01-31T23:59:59.999Z"
  },
  "monthlyRecurringRevenue": 25000.0,
  "churnRate": 5.2,
  "retentionRate": 94.8,
  "activeSubscriptions": 500,
  "canceledSubscriptions": 26,
  "newSubscriptions": 50,
  "metrics": {
    "subscriptionsAtPeriodStart": 476,
    "subscriptionsAtPeriodEnd": 500,
    "netChange": 24
  },
  "subscriptionsByTier": [
    {
      "tier": "premium",
      "totalCount": 300,
      "activeCount": 280,
      "canceledCount": 15,
      "newCount": 30
    },
    {
      "tier": "enterprise",
      "totalCount": 150,
      "activeCount": 145,
      "canceledCount": 8,
      "newCount": 15
    },
    {
      "tier": "free",
      "totalCount": 50,
      "activeCount": 75,
      "canceledCount": 3,
      "newCount": 5
    }
  ],
  "mrrByTier": [
    {
      "tier": "premium",
      "monthlyRecurringRevenue": 14000.0
    },
    {
      "tier": "enterprise",
      "monthlyRecurringRevenue": 10500.0
    },
    {
      "tier": "free",
      "monthlyRecurringRevenue": 500.0
    }
  ]
}
```

**Metrics Explained:**

- **MRR (Monthly Recurring Revenue):** Total revenue from successful transactions in the last 30 days
- **Churn Rate:** Percentage of subscriptions canceled during the period
- **Retention Rate:** Percentage of subscriptions retained (100 - churn rate)
- **Net Change:** New subscriptions minus canceled subscriptions

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/reports/subscriptions?startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Error Responses:**

- `400 Bad Request` - Invalid date format or date range
- `401 Unauthorized` - Invalid or missing JWT token
- `403 Forbidden` - Insufficient permissions
- `500 Internal Server Error` - Server error

---

### 3. Export Report

Export report data in CSV or PDF format for offline analysis.

**Endpoint:** `GET /api/admin/reports/export`

**Required Permission:** `export_reports`

**Query Parameters:**

| Parameter   | Type   | Required | Description                                                |
| ----------- | ------ | -------- | ---------------------------------------------------------- |
| `type`      | string | Yes      | Report type: `revenue`, `subscriptions`, or `transactions` |
| `format`    | string | Yes      | Export format: `csv` or `pdf`                              |
| `startDate` | string | Yes      | Start date in ISO 8601 format (YYYY-MM-DD)                 |
| `endDate`   | string | Yes      | End date in ISO 8601 format (YYYY-MM-DD)                   |

**Valid Report Types:**

1. **revenue** - Revenue report with transaction details
2. **subscriptions** - Subscription report with user and tier information
3. **transactions** - Detailed transaction report with payment methods

**Response:**

- **Content-Type:** `text/csv` for CSV format
- **Content-Type:** `application/pdf` for PDF format (currently returns CSV with note)
- **Content-Disposition:** `attachment; filename="report_name.csv"`

**CSV Format Examples:**

**Revenue Report:**

```csv
id,created_at,user_email,username,amount,currency,status,subscription_tier,payment_method_type,payment_method_last4
uuid-1,2025-01-15T10:30:00Z,user@example.com,john_doe,50.00,USD,succeeded,premium,card,4242
uuid-2,2025-01-16T14:20:00Z,user2@example.com,jane_smith,100.00,USD,succeeded,enterprise,card,1234
```

**Subscriptions Report:**

```csv
id,created_at,user_email,username,tier,status,current_period_start,current_period_end,canceled_at,cancel_at_period_end
uuid-1,2025-01-01T00:00:00Z,user@example.com,john_doe,premium,active,2025-01-01T00:00:00Z,2025-02-01T00:00:00Z,,false
uuid-2,2025-01-05T00:00:00Z,user2@example.com,jane_smith,enterprise,active,2025-01-05T00:00:00Z,2025-02-05T00:00:00Z,,false
```

**Transactions Report:**

```csv
id,created_at,user_email,username,amount,currency,status,payment_method_type,payment_method_last4,stripe_payment_intent_id,subscription_tier
uuid-1,2025-01-15T10:30:00Z,user@example.com,john_doe,50.00,USD,succeeded,card,4242,pi_xxx,premium
uuid-2,2025-01-16T14:20:00Z,user2@example.com,jane_smith,100.00,USD,succeeded,card,1234,pi_yyy,enterprise
```

**Example Request:**

```bash
curl -X GET "https://api.cloudtolocalllm.online/api/admin/reports/export?type=revenue&format=csv&startDate=2025-01-01&endDate=2025-01-31" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -o revenue_report.csv
```

**Audit Logging:**

All export operations are logged in the admin audit log with:

- Admin user ID
- Report type and format
- Date range
- Number of records exported
- IP address and user agent

**Error Responses:**

- `400 Bad Request` - Missing or invalid parameters
- `401 Unauthorized` - Invalid or missing JWT token
- `403 Forbidden` - Insufficient permissions (requires `export_reports`)
- `500 Internal Server Error` - Server error

---

## Security Features

### Authentication & Authorization

- All endpoints require valid JWT token with admin role
- Role-based permission checking (view_reports, export_reports)
- Admin actions are logged in audit trail

### Rate Limiting

- Standard admin rate limiting applies (100 requests per minute)
- Export operations may have additional rate limits

### Data Protection

- User emails and sensitive data are included in exports
- Exports should be handled securely and not shared publicly
- Audit logs track all export operations

### Input Validation

- Date formats validated (ISO 8601)
- Date ranges validated (max 1 year)
- Report types and formats validated against whitelist
- SQL injection prevention via parameterized queries

---

## Best Practices

### Date Ranges

1. **Keep ranges reasonable:** Large date ranges may take longer to process
2. **Use specific dates:** Avoid open-ended queries
3. **Consider timezone:** All dates are stored and returned in UTC

### Performance

1. **Use groupBy sparingly:** Grouping adds additional queries
2. **Export in batches:** For large datasets, export in smaller date ranges
3. **Cache results:** Consider caching frequently accessed reports

### Reporting Workflow

1. **Generate report first:** Use revenue or subscriptions endpoint to preview data
2. **Verify metrics:** Check that the data looks correct
3. **Export if needed:** Use export endpoint for offline analysis
4. **Review audit logs:** Verify all operations are logged

---

## Error Handling

### Common Errors

**Missing Parameters:**

```json
{
  "error": "Missing required parameters",
  "message": "Both startDate and endDate are required",
  "example": "/api/admin/reports/revenue?startDate=2025-01-01&endDate=2025-01-31"
}
```

**Invalid Date Format:**

```json
{
  "error": "Invalid date format",
  "message": "Dates must be in ISO 8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss.sssZ)"
}
```

**Date Range Too Large:**

```json
{
  "error": "Date range too large",
  "message": "Date range cannot exceed 1 year"
}
```

**Invalid Report Type:**

```json
{
  "error": "Invalid report type",
  "message": "Report type must be one of: revenue, subscriptions, transactions"
}
```

**Insufficient Permissions:**

```json
{
  "error": "Insufficient permissions",
  "required": ["export_reports"]
}
```

---

## Integration Examples

### JavaScript/TypeScript

```typescript
// Revenue report
async function getRevenueReport(startDate: string, endDate: string) {
  const response = await fetch(
    `https://api.cloudtolocalllm.online/api/admin/reports/revenue?startDate=${startDate}&endDate=${endDate}&groupBy=true`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to fetch revenue report: ${response.statusText}`);
  }

  return await response.json();
}

// Export report
async function exportReport(
  type: string,
  format: string,
  startDate: string,
  endDate: string
) {
  const response = await fetch(
    `https://api.cloudtolocalllm.online/api/admin/reports/export?type=${type}&format=${format}&startDate=${startDate}&endDate=${endDate}`,
    {
      headers: {
        Authorization: `Bearer ${token}`,
      },
    }
  );

  if (!response.ok) {
    throw new Error(`Failed to export report: ${response.statusText}`);
  }

  const blob = await response.blob();
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${type}_report_${startDate}_${endDate}.${format}`;
  a.click();
}
```

### Python

```python
import requests
from datetime import datetime, timedelta

def get_subscription_metrics(token, days=30):
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)

    response = requests.get(
        'https://api.cloudtolocalllm.online/api/admin/reports/subscriptions',
        params={
            'startDate': start_date.isoformat(),
            'endDate': end_date.isoformat(),
            'groupBy': 'true'
        },
        headers={'Authorization': f'Bearer {token}'}
    )

    response.raise_for_status()
    return response.json()

def export_revenue_report(token, start_date, end_date):
    response = requests.get(
        'https://api.cloudtolocalllm.online/api/admin/reports/export',
        params={
            'type': 'revenue',
            'format': 'csv',
            'startDate': start_date,
            'endDate': end_date
        },
        headers={'Authorization': f'Bearer {token}'}
    )

    response.raise_for_status()

    filename = f'revenue_report_{start_date}_{end_date}.csv'
    with open(filename, 'wb') as f:
        f.write(response.content)

    return filename
```

---

## Changelog

### Version 1.0.0 (2025-11-16)

- Initial release of Admin Reports API
- Revenue report endpoint with tier breakdown
- Subscription metrics endpoint with MRR and churn calculations
- Export functionality for CSV format
- PDF export placeholder (returns CSV with note)
- Comprehensive audit logging
- Role-based permission checking

---

## Support

For issues or questions about the Admin Reports API:

1. Check the error response for specific error codes
2. Review audit logs for operation history
3. Verify admin permissions are correctly configured
4. Contact system administrator for access issues

---

## Related Documentation

- [Admin Users API](./README.md)
- [Admin Payments API](./PAYMENTS_API.md)
- [Admin Subscriptions API](./SUBSCRIPTIONS_API.md)
- [Admin Authentication](../../middleware/admin-auth.js)
- [Audit Logging](../../utils/audit-logger.js)
