# Prometheus Metrics Quick Reference

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/metrics` | GET | Prometheus metrics in text format |
| `/api/metrics` | GET | Prometheus metrics (with /api prefix) |
| `/prometheus/health/metrics` | GET | Health check for metrics collection |

## Key Metrics

### HTTP Requests

- `http_request_duration_seconds` - Request latency (histogram)
- `http_requests_total` - Total requests (counter)
- `http_request_errors_total` - Total errors (counter)

### Services

- `tunnel_connections_active` - Active tunnels (gauge)
- `proxy_instances_active` - Active proxies (gauge)

### Database

- `db_connection_pool_size` - Pool size (gauge)
- `db_query_duration_seconds` - Query latency (histogram)
- `db_queries_total` - Total queries (counter)

### Authentication

- `auth_attempts_total` - Auth attempts (counter)
- `active_sessions` - Active sessions (gauge)

### Rate Limiting

- `rate_limit_violations_total` - Violations (counter)
- `rate_limited_users_active` - Limited users (gauge)

### System

- `api_uptime_seconds` - Uptime (gauge)
- `active_users` - Active users (gauge)
- `system_load` - System load (gauge)

## Usage

### Get Metrics

```bash
curl http://localhost:8080/metrics
```

### Check Health

```bash
curl http://localhost:8080/prometheus/health/metrics
```

### Prometheus Config

```yaml
scrape_configs:
  - job_name: 'api'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
```

## Recording Metrics

```javascript
import { metricsService } from './services/metrics-service.js';

// HTTP requests (automatic via middleware)
metricsService.recordHttpRequest({
  method: 'GET',
  route: '/api/users',
  status: 200,
  duration: 150,
});

// Database queries
metricsService.recordDatabaseQuery({
  queryType: 'select',
  duration: 50,
});

// Tunnel connections
metricsService.updateTunnelConnections(5);
metricsService.incrementTunnelConnectionsCreated();

// Proxy instances
metricsService.updateProxyInstances(3);
metricsService.incrementProxyInstancesCreated();

// Database pool
metricsService.updateDatabasePoolMetrics({
  poolType: 'main',
  size: 10,
  available: 8,
});

// Authentication
metricsService.recordAuthAttempt({
  authType: 'jwt',
  result: 'success',
});

// Rate limiting
metricsService.recordRateLimitViolation({
  violationType: 'per_user',
  userTier: 'free',
});

// System metrics
metricsService.updateApiUptime(3600);
metricsService.updateActiveUsers(42);
metricsService.updateSystemLoad({
  cpu: 45.5,
  memory: 62.3,
  disk: 78.1,
});
```

## Testing

```bash
npm test -- ../test/api-backend/prometheus-metrics.test.js
```

## Files

- `services/metrics-service.js` - Metrics collection service
- `middleware/metrics-collection.js` - Metrics collection middleware
- `routes/prometheus-metrics.js` - Prometheus metrics routes
- `test/api-backend/prometheus-metrics.test.js` - Test suite

## Integration

1. Metrics middleware automatically collects HTTP request metrics
2. Services can record custom metrics using metricsService
3. Prometheus scraper accesses `/metrics` endpoint
4. Grafana visualizes metrics from Prometheus

## Performance

- Minimal overhead: ~1-2ms per request
- On-demand metric generation
- In-memory storage
- Suitable for production use
