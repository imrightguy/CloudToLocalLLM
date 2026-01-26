# Proxy Usage Tracking - Quick Reference

## Overview

Proxy usage tracking implementation for billing and analytics. Tracks proxy usage metrics including connections, data transfer, and errors.

**Validates: Requirements 5.9**

## Files Created

### Service

- `services/proxy-usage-service.js` - Core service for usage tracking

### Routes

- `routes/proxy-usage.js` - API endpoints for usage tracking

### Database

- `database/migrations/016_proxy_usage_tracking.sql` - Database schema

### Tests

- `test/api-backend/proxy-usage.test.js` - Comprehensive test suite

## API Endpoints

### Record Usage Event

```
POST /proxy/usage/:proxyId/record
Authorization: Bearer <JWT>
Content-Type: application/json

Body:
{
  "eventType": "connection_start|connection_end|data_transfer|error",
  "eventData": {
    "connectionId": "conn-123",
    "dataBytes": 1024,
    "durationSeconds": 60,
    "errorMessage": "Connection timeout",
    "ipAddress": "192.168.1.1"
  }
}

Response:
{
  "proxyId": "proxy-123",
  "eventType": "connection_start",
  "message": "Usage event recorded successfully",
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### Get Usage Metrics for Specific Date

```
GET /proxy/usage/:proxyId/metrics/:date
Authorization: Bearer <JWT>

Response:
{
  "proxyId": "proxy-123",
  "date": "2024-01-19",
  "metrics": {
    "connectionCount": 100,
    "dataTransferredBytes": 5242880,
    "dataReceivedBytes": 2621440,
    "peakConcurrentConnections": 10,
    "averageConnectionDurationSeconds": 30,
    "errorCount": 2,
    "successCount": 98
  },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### Get Usage Metrics for Date Range

```
GET /proxy/usage/:proxyId/metrics?startDate=2024-01-01&endDate=2024-01-31
Authorization: Bearer <JWT>

Response:
{
  "proxyId": "proxy-123",
  "startDate": "2024-01-01",
  "endDate": "2024-01-31",
  "metrics": [
    {
      "proxyId": "proxy-123",
      "date": "2024-01-01",
      "connectionCount": 100,
      ...
    },
    ...
  ],
  "count": 31,
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### Get Usage Report

```
GET /proxy/usage/report?startDate=2024-01-01&endDate=2024-01-31&groupBy=day|proxy
Authorization: Bearer <JWT>

Response:
{
  "userId": "user-123",
  "startDate": "2024-01-01",
  "endDate": "2024-01-31",
  "groupBy": "day",
  "data": [
    {
      "date": "2024-01-01",
      "totalConnections": 100,
      "totalDataTransferredBytes": 5242880,
      "totalDataReceivedBytes": 2621440,
      "peakConcurrentConnections": 10,
      "averageConnectionDurationSeconds": 30,
      "totalErrorCount": 2,
      "totalSuccessCount": 98
    },
    ...
  ],
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### Get Usage Aggregation

```
GET /proxy/usage/aggregation?periodStart=2024-01-01&periodEnd=2024-01-31
Authorization: Bearer <JWT>

Response:
{
  "userId": "user-123",
  "userTier": "premium",
  "periodStart": "2024-01-01",
  "periodEnd": "2024-01-31",
  "totalConnections": 3100,
  "totalDataTransferredBytes": 157286400,
  "totalDataReceivedBytes": 78643200,
  "proxyCount": 2,
  "peakConcurrentConnections": 15,
  "averageConnectionDurationSeconds": 28,
  "totalErrorCount": 45,
  "totalSuccessCount": 3055,
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### Aggregate Usage Metrics

```
POST /proxy/usage/aggregate
Authorization: Bearer <JWT>
Content-Type: application/json

Body:
{
  "periodStart": "2024-01-01",
  "periodEnd": "2024-01-31"
}

Response:
{
  "message": "Usage aggregated successfully",
  "aggregation": {
    "user_id": "user-123",
    "user_tier": "premium",
    "period_start": "2024-01-01",
    "period_end": "2024-01-31",
    "total_connections": 3100,
    ...
  },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

### Get Billing Summary

```
GET /proxy/usage/billing?periodStart=2024-01-01&periodEnd=2024-01-31
Authorization: Bearer <JWT>

Response:
{
  "userId": "user-123",
  "userTier": "premium",
  "periodStart": "2024-01-01",
  "periodEnd": "2024-01-31",
  "usage": {
    "userId": "user-123",
    "userTier": "premium",
    "periodStart": "2024-01-01",
    "periodEnd": "2024-01-31",
    "totalConnections": 3100,
    "totalDataTransferredBytes": 157286400,
    "totalDataReceivedBytes": 78643200,
    "proxyCount": 2,
    "peakConcurrentConnections": 15,
    "averageConnectionDurationSeconds": 28,
    "totalErrorCount": 45,
    "totalSuccessCount": 3055
  },
  "billing": {
    "amount": 11.52,
    "currency": "USD",
    "breakdown": {
      "baseCharge": 10,
      "dataTransferCharge": 1.52,
      "connectionCharge": 0
    }
  },
  "timestamp": "2024-01-19T10:30:00Z"
}
```

## Database Schema

### proxy_usage_events

Raw usage events collected from proxy instances.

```sql
CREATE TABLE proxy_usage_events (
  id UUID PRIMARY KEY,
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  event_type VARCHAR(50) NOT NULL,
  connection_id VARCHAR(255),
  data_bytes BIGINT DEFAULT 0,
  duration_seconds INTEGER,
  error_message TEXT,
  ip_address VARCHAR(45),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id)
);
```

### proxy_usage_metrics

Aggregated daily usage metrics for proxy instances.

```sql
CREATE TABLE proxy_usage_metrics (
  id UUID PRIMARY KEY,
  proxy_id VARCHAR(255) NOT NULL,
  user_id UUID NOT NULL,
  date DATE NOT NULL,
  connection_count INTEGER DEFAULT 0,
  data_transferred_bytes BIGINT DEFAULT 0,
  data_received_bytes BIGINT DEFAULT 0,
  peak_concurrent_connections INTEGER DEFAULT 0,
  average_connection_duration_seconds FLOAT DEFAULT 0,
  error_count INTEGER DEFAULT 0,
  success_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(proxy_id, date)
);
```

### proxy_usage_aggregation

Period-based aggregated usage metrics for billing.

```sql
CREATE TABLE proxy_usage_aggregation (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL,
  user_tier VARCHAR(50) NOT NULL,
  period_start DATE NOT NULL,
  period_end DATE NOT NULL,
  total_connections INTEGER DEFAULT 0,
  total_data_transferred_bytes BIGINT DEFAULT 0,
  total_data_received_bytes BIGINT DEFAULT 0,
  proxy_count INTEGER DEFAULT 0,
  peak_concurrent_connections INTEGER DEFAULT 0,
  average_connection_duration_seconds FLOAT DEFAULT 0,
  total_error_count INTEGER DEFAULT 0,
  total_success_count INTEGER DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, period_start, period_end)
);
```

### proxy_usage_summary

Current summary usage metrics for quick access.

```sql
CREATE TABLE proxy_usage_summary (
  id UUID PRIMARY KEY,
  proxy_id VARCHAR(255) NOT NULL UNIQUE,
  user_id UUID NOT NULL,
  connection_count_1h INTEGER DEFAULT 0,
  connection_count_24h INTEGER DEFAULT 0,
  success_rate_1h FLOAT DEFAULT 100,
  success_rate_24h FLOAT DEFAULT 100,
  data_transferred_1h_bytes BIGINT DEFAULT 0,
  data_transferred_24h_bytes BIGINT DEFAULT 0,
  error_count_1h INTEGER DEFAULT 0,
  error_count_24h INTEGER DEFAULT 0,
  concurrent_connections INTEGER DEFAULT 0,
  last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Service Methods

### recordUsageEvent(proxyId, userId, eventType, eventData)

Record a usage event for a proxy.

**Parameters:**

- `proxyId` (string) - Proxy ID
- `userId` (string) - User ID
- `eventType` (string) - Event type: connection_start, connection_end, data_transfer, error
- `eventData` (object) - Event data with optional fields

**Returns:** Promise<Object> - Created event

### getProxyUsageMetrics(proxyId, userId, date)

Get usage metrics for a proxy on a specific date.

**Parameters:**

- `proxyId` (string) - Proxy ID
- `userId` (string) - User ID
- `date` (string) - Date in YYYY-MM-DD format

**Returns:** Promise<Object> - Usage metrics

### getProxyUsageMetricsRange(proxyId, userId, startDate, endDate)

Get usage metrics for a proxy over a date range.

**Parameters:**

- `proxyId` (string) - Proxy ID
- `userId` (string) - User ID
- `startDate` (string) - Start date in YYYY-MM-DD format
- `endDate` (string) - End date in YYYY-MM-DD format

**Returns:** Promise<Array> - Usage metrics for each day

### getUserUsageAggregation(userId, userTier, periodStart, periodEnd)

Get aggregated usage for a user.

**Parameters:**

- `userId` (string) - User ID
- `userTier` (string) - User tier (free, premium, enterprise)
- `periodStart` (string) - Period start date in YYYY-MM-DD format
- `periodEnd` (string) - Period end date in YYYY-MM-DD format

**Returns:** Promise<Object> - Aggregated usage

### aggregateUserUsage(userId, userTier, periodStart, periodEnd)

Aggregate usage metrics for a user and period.

**Parameters:**

- `userId` (string) - User ID
- `userTier` (string) - User tier
- `periodStart` (string) - Period start date in YYYY-MM-DD format
- `periodEnd` (string) - Period end date in YYYY-MM-DD format

**Returns:** Promise<Object> - Aggregated usage

### getUserUsageReport(userId, options)

Get usage report for a user.

**Parameters:**

- `userId` (string) - User ID
- `options` (object) - Report options
  - `startDate` (string) - Start date in YYYY-MM-DD format
  - `endDate` (string) - End date in YYYY-MM-DD format
  - `groupBy` (string) - Group by 'day' or 'proxy'

**Returns:** Promise<Object> - Usage report

### getBillingSummary(userId, userTier, periodStart, periodEnd)

Get billing summary for a user.

**Parameters:**

- `userId` (string) - User ID
- `userTier` (string) - User tier
- `periodStart` (string) - Period start date in YYYY-MM-DD format
- `periodEnd` (string) - Period end date in YYYY-MM-DD format

**Returns:** Promise<Object> - Billing summary

## Billing Calculation

### Free Tier

- Base charge: $0
- Data transfer charge: $0
- Total: $0

### Premium Tier

- Base charge: $10/month
- Data transfer charge: $0.01 per GB
- Total: $10 + (total_data_gb * $0.01)

### Enterprise Tier

- Custom pricing (contact sales)

## Integration

To integrate proxy usage tracking into the API backend:

1. Import the service:

```javascript
import ProxyUsageService from './services/proxy-usage-service.js';
```

1. Initialize the service:

```javascript
const proxyUsageService = new ProxyUsageService();
await proxyUsageService.initialize();
```

1. Register routes:

```javascript
import { createProxyUsageRoutes } from './routes/proxy-usage.js';
app.use('/proxy', createProxyUsageRoutes(proxyUsageService));
```

1. Record usage events:

```javascript
await proxyUsageService.recordUsageEvent(
  proxyId,
  userId,
  'connection_start',
  { connectionId: 'conn-123', ipAddress: '192.168.1.1' }
);
```

## Error Codes

- `PROXY_USAGE_001` - Invalid request (missing required parameters)
- `PROXY_USAGE_002` - Service unavailable (service not initialized)
- `PROXY_USAGE_003` - Internal server error

## Testing

Run tests with:

```bash
npm test -- test/api-backend/proxy-usage.test.js
```

## Notes

- All timestamps are in UTC
- Data transfer is measured in bytes
- Dates are in YYYY-MM-DD format
- User authorization is enforced on all endpoints
- Proxy ownership is verified before returning metrics
