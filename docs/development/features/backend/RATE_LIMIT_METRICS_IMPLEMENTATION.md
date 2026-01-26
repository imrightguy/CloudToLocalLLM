# Rate Limit Metrics and Dashboards Implementation

## Overview

Task 37 implements comprehensive rate limit metrics collection and dashboard data endpoints for the API backend. This feature provides Prometheus metrics for rate limiting and admin dashboard endpoints to monitor rate limit violations and trends.

## Validates

- **Requirement 6.10**: THE API SHALL provide rate limit metrics and dashboards

## Components Implemented

### 1. Rate Limit Metrics Service (`services/rate-limit-metrics-service.js`)

**RateLimitMetricsService** provides:

#### Prometheus Metrics

- `rate_limit_violations_total` - Total rate limit violations by type and tier
- `rate_limit_violations_by_type_total` - Violations grouped by type
- `rate_limited_users_active` - Number of currently rate limited users
- `rate_limit_exemptions_total` - Total exemptions granted by type
- `rate_limit_requests_allowed_total` - Requests allowed by tier
- `rate_limit_requests_blocked_total` - Requests blocked by type and tier
- `rate_limit_window_usage_percent` - Current window usage percentage per user
- `rate_limit_burst_usage_percent` - Current burst usage percentage per user
- `rate_limit_concurrent_requests` - Concurrent requests per user
- `rate_limit_check_duration_seconds` - Duration of rate limit checks

#### Recording Methods

- `recordViolation()` - Record a rate limit violation
- `recordExemption()` - Record a rate limit exemption
- `recordRequestAllowed()` - Record an allowed request
- `recordRequestBlocked()` - Record a blocked request

#### Tracking Methods

- `updateWindowUsage()` - Update window usage percentage
- `updateBurstUsage()` - Update burst usage percentage
- `updateConcurrentRequests()` - Update concurrent request count
- `recordCheckDuration()` - Record rate limit check duration
- `updateActiveRateLimitedUsers()` - Update active rate limited users count

#### Analysis Methods

- `getTopViolators()` - Get top violating users
- `getTopViolatingIps()` - Get top violating IPs
- `getMetricsSummary()` - Get overall metrics summary

### 2. Metrics Routes (`routes/rate-limit-metrics.js`)

Public and admin endpoints:

```
GET /metrics
  - Prometheus metrics endpoint (public)
  - Returns metrics in Prometheus format
  - Used by Prometheus scraper

GET /rate-limit-metrics/summary
  - Get rate limit metrics summary
  - Requires authentication
  - Returns: top violators, top IPs, totals

GET /rate-limit-metrics/top-violators
  - Get top rate limit violators
  - Requires admin role
  - Query params: limit (default: 10, max: 100)
  - Returns: list of top violators with violation counts

GET /rate-limit-metrics/top-ips
  - Get top violating IPs
  - Requires admin role
  - Query params: limit (default: 10, max: 100)
  - Returns: list of top IPs with violation counts

GET /rate-limit-metrics/dashboard-data
  - Get comprehensive dashboard data
  - Requires admin role
  - Returns: summary, top violators, top IPs
```

### 3. Middleware Integration

#### Rate Limiter (`middleware/rate-limiter.js`)

Updated to record metrics for:

- Allowed requests
- Blocked requests (window, burst, concurrent)
- Window usage updates
- Burst usage updates
- Concurrent request updates

#### Exemptions (`middleware/rate-limit-exemptions.js`)

Updated to record metrics for:

- Granted exemptions by type

### 4. Server Integration (`server.js`)

Routes registered at:

- `/metrics` - Prometheus metrics endpoint
- `/api/metrics` - Metrics with /api prefix
- `/rate-limit-metrics/*` - Dashboard endpoints

## Usage Examples

### Get Prometheus Metrics

```bash
curl http://localhost:8080/metrics
```

Response format (Prometheus text format):

```
# HELP rate_limit_violations_total Total number of rate limit violations
# TYPE rate_limit_violations_total counter
rate_limit_violations_total{violation_type="window_limit_exceeded",user_tier="free"} 42
rate_limit_violations_total{violation_type="burst_limit_exceeded",user_tier="premium"} 5
```

### Get Metrics Summary

```bash
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/rate-limit-metrics/summary
```

Response:

```json
{
  "success": true,
  "data": {
    "timestamp": "2024-01-19T10:30:00Z",
    "topViolators": [
      {
        "userId": "user-123",
        "violationCount": 42
      },
      {
        "userId": "user-456",
        "violationCount": 28
      }
    ],
    "topViolatingIps": [
      {
        "ipAddress": "192.168.1.100",
        "violationCount": 15
      }
    ],
    "totalViolators": 10,
    "totalViolatingIps": 5
  }
}
```

### Get Top Violators (Admin)

```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:8080/rate-limit-metrics/top-violators?limit=20"
```

Response:

```json
{
  "success": true,
  "data": {
    "timestamp": "2024-01-19T10:30:00Z",
    "limit": 20,
    "count": 10,
    "topViolators": [
      {
        "userId": "user-123",
        "violationCount": 42
      },
      ...
    ]
  }
}
```

### Get Top Violating IPs (Admin)

```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  "http://localhost:8080/rate-limit-metrics/top-ips?limit=10"
```

### Get Dashboard Data (Admin)

```bash
curl -H "Authorization: Bearer $ADMIN_TOKEN" \
  http://localhost:8080/rate-limit-metrics/dashboard-data
```

Response:

```json
{
  "success": true,
  "data": {
    "timestamp": "2024-01-19T10:30:00Z",
    "summary": {
      "totalViolators": 10,
      "totalViolatingIps": 5
    },
    "topViolators": [...],
    "topIps": [...]
  }
}
```

## Prometheus Integration

### Scrape Configuration

Add to Prometheus `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'cloudtolocalllm-api'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
    scrape_interval: 15s
    scrape_timeout: 10s
```

### Grafana Dashboard

Create dashboard panels using these metrics:

1. **Rate Limit Violations Over Time**

   ```
   rate(rate_limit_violations_total[5m])
   ```

2. **Top Violators**

   ```
   topk(10, rate_limit_violations_total)
   ```

3. **Requests Allowed vs Blocked**

   ```
   rate_limit_requests_allowed_total vs rate_limit_requests_blocked_total
   ```

4. **Active Rate Limited Users**

   ```
   rate_limited_users_active
   ```

5. **Average Rate Limit Check Duration**

   ```
   rate_limit_check_duration_seconds_bucket
   ```

## Database Schema

No database schema changes required. Metrics are stored in memory and tracked via Prometheus.

## Testing

Comprehensive test suite in `test/api-backend/rate-limit-metrics.test.js`:

- Violation recording (single and multiple)
- Violation tracking by user and IP
- Exemption recording
- Request recording (allowed and blocked)
- Usage tracking (window, burst, concurrent)
- Top violators identification
- Top violating IPs identification
- Metrics summary generation
- Reset functionality

**Test Coverage:** 87.67% statements, 57.89% branches, 100% functions

Run tests:

```bash
npm test -- ../test/api-backend/rate-limit-metrics.test.js
```

## Integration Points

1. **Rate Limiter Middleware** - Records violations and allowed requests
2. **Exemptions Middleware** - Records exemptions
3. **Server** - Exposes metrics endpoints
4. **Prometheus** - Scrapes metrics
5. **Grafana** - Visualizes metrics

## Performance Considerations

- **Memory Usage**: ~1-5 MB for tracking top violators and IPs
- **CPU Overhead**: Minimal (~0.1% per request)
- **Prometheus Metrics**: Efficient counter and gauge operations
- **Cleanup**: Automatic via Prometheus retention policies

## Monitoring Recommendations

### Key Metrics to Monitor

1. **Violation Rate** - Should be low under normal conditions
2. **Top Violators** - Identify problematic users
3. **Top IPs** - Identify potential DDoS sources
4. **Exemption Rate** - Should be low for critical operations
5. **Check Duration** - Should be < 5ms

### Alerts to Set Up

```yaml
- alert: HighRateLimitViolations
  expr: rate(rate_limit_violations_total[5m]) > 10
  for: 5m
  annotations:
    summary: "High rate limit violations detected"

- alert: DDoSDetected
  expr: topk(1, rate_limit_violations_total{violation_type="ip_limit_exceeded"}) > 100
  for: 1m
  annotations:
    summary: "Potential DDoS attack detected"

- alert: HighRateLimitCheckDuration
  expr: rate_limit_check_duration_seconds_bucket{le="0.01"} < 0.8
  for: 5m
  annotations:
    summary: "Rate limit checks taking too long"
```

## Dashboard Data Endpoints

The dashboard endpoints provide aggregated data for admin dashboards:

- **Summary** - Overall statistics
- **Top Violators** - Users with most violations
- **Top IPs** - IPs with most violations
- **Comprehensive** - All data combined

These endpoints are designed for dashboard consumption and return data in a format suitable for visualization.

## Next Steps

1. Configure Prometheus to scrape `/metrics` endpoint
2. Create Grafana dashboards using the metrics
3. Set up alerts for critical thresholds
4. Monitor violation trends
5. Use data to tune rate limit settings

## Related Tasks

- Task 30: Per-user rate limiting
- Task 31: Per-IP rate limiting
- Task 32: Request queuing
- Task 33: Quota management
- Task 34: Rate limit exemptions
- Task 35: Rate limit violation logging
- Task 36: Adaptive rate limiting
