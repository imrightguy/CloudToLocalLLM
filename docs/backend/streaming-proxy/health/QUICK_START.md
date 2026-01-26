# Health Check and Diagnostics - Quick Start Guide

## Overview

The health check and diagnostics endpoints provide real-time monitoring and troubleshooting capabilities for the streaming proxy server.

## Endpoints

### Health Check Endpoint

```
GET /api/tunnel/health
```

**Purpose:** Quick health status check for monitoring and Kubernetes probes

**Response Codes:**

- `200` - Server is healthy
- `503` - Server is unhealthy or degraded

**Example:**

```bash
curl http://localhost:3001/api/tunnel/health
```

**Response:**

```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.000Z",
  "uptime": 3600000,
  "activeConnections": 5,
  "requestsPerSecond": 10.5,
  "successRate": 0.99,
  "components": [
    {
      "name": "WebSocket Service",
      "status": "healthy",
      "responseTime": 2
    },
    {
      "name": "Connection Pool",
      "status": "healthy",
      "responseTime": 1
    },
    {
      "name": "Circuit Breaker",
      "status": "healthy",
      "responseTime": 1
    },
    {
      "name": "Metrics Collector",
      "status": "healthy",
      "responseTime": 2
    },
    {
      "name": "Rate Limiter",
      "status": "healthy",
      "responseTime": 1
    }
  ]
}
```

### Diagnostics Endpoint

```
GET /api/tunnel/diagnostics
```

**Purpose:** Detailed system diagnostics for troubleshooting

**Response Code:**

- `200` - Diagnostics retrieved successfully
- `500` - Diagnostics failed

**Example:**

```bash
curl http://localhost:3001/api/tunnel/diagnostics
```

**Response includes:**

- Server information (version, Node.js, platform)
- Memory usage (heap, external, RSS)
- Connection statistics by user
- Metrics summary (requests, latency, errors)
- Circuit breaker states
- Rate limiter statistics
- Component health status

## Kubernetes Integration

### Liveness Probe

```yaml
livenessProbe:
  httpGet:
    path: /api/tunnel/health
    port: 3001
  initialDelaySeconds: 30
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

### Readiness Probe

```yaml
readinessProbe:
  httpGet:
    path: /api/tunnel/health
    port: 3001
  initialDelaySeconds: 10
  periodSeconds: 5
  timeoutSeconds: 3
  failureThreshold: 2
```

## Monitoring

### Prometheus Integration

The health check endpoint can be scraped by Prometheus:

```yaml
scrape_configs:
  - job_name: 'streaming-proxy'
    static_configs:
      - targets: ['localhost:3001']
    metrics_path: '/api/tunnel/metrics'
```

### Grafana Dashboard

Create a dashboard with:

- Health status gauge
- Component status table
- Active connections graph
- Request success rate
- Memory usage

## Troubleshooting

### Unhealthy Status

If the health check returns status `unhealthy` or `degraded`:

1. **Check component status** - Look at the `components` array
2. **Run diagnostics** - Get detailed information from `/api/tunnel/diagnostics`
3. **Check logs** - Review server logs for errors
4. **Verify resources** - Check memory and CPU usage
5. **Check dependencies** - Verify connection pool, circuit breaker, rate limiter

### Common Issues

#### WebSocket Service Unhealthy

- Check if metrics collector is working
- Verify no memory leaks
- Check active connection count

#### Connection Pool Degraded

- Too many connections (>100)
- Check for connection leaks
- Verify cleanup task is running

#### Circuit Breaker Open

- Backend service may be failing
- Check SSH connection health
- Verify network connectivity

#### Rate Limiter Issues

- High violation count
- Check for DDoS attacks
- Verify rate limit configuration

## Performance

- Health check: ~5-10ms
- Diagnostics: ~20-50ms
- Suitable for polling every 10-30 seconds
- No blocking operations

## Security

### Current Implementation

- Health check: Public (no authentication)
- Diagnostics: Requires admin authentication (JWT token with `view_system_metrics`, `admin`, or `*` permission)

### Recommended

- Health check should remain public for monitoring systems
- Diagnostics is secured with admin authentication
- Use authentication middleware
- Log access to diagnostics endpoint

## Examples

### Monitor Health Every 30 Seconds

```bash
while true; do
  curl -s http://localhost:3001/api/tunnel/health | jq '.status'
  sleep 30
done
```

### Get Detailed Diagnostics

```bash
curl -s http://localhost:3001/api/tunnel/diagnostics | jq '.'
```

### Check Specific Component

```bash
curl -s http://localhost:3001/api/tunnel/diagnostics | jq '.components[] | select(.name=="Circuit Breaker")'
```

### Monitor Memory Usage

```bash
curl -s http://localhost:3001/api/tunnel/diagnostics | jq '.memoryUsage'
```

### Check Connection Statistics

```bash
curl -s http://localhost:3001/api/tunnel/diagnostics | jq '.connectionStats'
```

## Integration with Monitoring Systems

### Datadog

```python
from datadog import initialize, api

options = {
    'api_key': 'YOUR_API_KEY',
    'app_key': 'YOUR_APP_KEY'
}

initialize(**options)

# Send health status as metric
api.Metric.send(
    metric='streaming_proxy.health',
    points=1,  # 1 for healthy, 0 for unhealthy
    tags=['service:streaming-proxy']
)
```

### New Relic

```bash
curl -X POST https://api.newrelic.com/v2/custom_metrics.json \
  -H "X-Api-Key: YOUR_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "metric": "Custom/StreamingProxy/Health",
    "value": 1
  }'
```

## Next Steps

1. Deploy health check endpoints to production
2. Configure Kubernetes probes
3. Set up monitoring and alerting
4. Add admin authentication to diagnostics
5. Create Grafana dashboards
6. Document runbooks for common issues
