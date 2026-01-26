# Monitoring Setup Quick Reference

## File Guide

| File | Purpose | Use When |
|------|---------|----------|
| `README.md` | Central hub for monitoring docs | You need an overview or quick reference |
| `grafana-dashboard-setup.ts` | Comprehensive MCP tools guide | You need detailed implementation guidance |
| `setup-grafana-dashboards.md` | Step-by-step implementation | You're implementing dashboards |
| `grafana-setup-script.ts` | Practical implementation script | You need a working example |
| `TASK_18_COMPLETION_SUMMARY.md` | Task completion details | You need to understand what was completed |
| `DOCUMENTATION_UPDATE_SUMMARY.md` | Documentation changes | You need to understand doc updates |

## Quick Start (5 minutes)

### 1. Verify Prerequisites

```bash
# Check Prometheus datasource exists
mcp_grafana_list_datasources({ type: 'prometheus' })
```

### 2. Create Dashboards

```bash
# Create Tunnel Health Dashboard
mcp_grafana_create_dashboard({
  dashboard: {
    title: 'Tunnel Health',
    tags: ['tunnel', 'monitoring', 'production'],
    refresh: '30s',
    panels: [...]
  }
})
```

### 3. Create Alerts

```bash
# Create High Error Rate Alert
mcp_grafana_create_alert_rule({
  title: 'High Error Rate',
  ruleGroup: 'tunnel-alerts',
  condition: 'A',
  data: [...],
  for: '5m'
})
```

## Dashboard Summary

### Tunnel Health Dashboard

- **Panels**: 5 (Active Connections, Success Rate, Latency, Error Rate, Pool Status)
- **Refresh**: 30 seconds
- **Purpose**: Real-time tunnel health monitoring

### Performance Metrics Dashboard

- **Panels**: 6 (P95/P99 Latency, Throughput, Request Rate, Memory, CPU)
- **Variables**: User Tier, Time Range
- **Purpose**: Performance analysis

### Error Tracking Dashboard

- **Panels**: 4 (Error Rate by Category, Error Count, Top Errors, Error Rate by User)
- **Data Sources**: Prometheus, Loki
- **Purpose**: Error analysis and pattern detection

## Alert Summary

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| High Error Rate | >5% over 5m | Warning | Notify team |
| Connection Pool Exhaustion | >90% capacity | Warning | Scale/investigate |
| Circuit Breaker Open | State = 1 | Critical | Immediate investigation |
| Rate Limit Violations | >100 in 5m | Warning | Investigate traffic |

## Key Metrics

### Connection Metrics

- `tunnel_active_connections` - Current connections
- `tunnel_connections_total` - Total established
- `tunnel_connection_duration_seconds` - Duration

### Request Metrics

- `tunnel_requests_total` - Total requests
- `tunnel_request_latency_ms` - Latency
- `tunnel_request_latency_ms{quantile="0.95"}` - P95
- `tunnel_request_latency_ms{quantile="0.99"}` - P99

### Error Metrics

- `tunnel_errors_total` - Total errors
- `tunnel_errors_total{category="network"}` - Network errors
- `tunnel_errors_total{category="auth"}` - Auth errors
- `tunnel_errors_total{category="server"}` - Server errors

### Performance Metrics

- `tunnel_throughput_bytes_total` - Bytes transferred
- `tunnel_request_rate` - Requests/second
- `tunnel_error_rate` - Error rate

### Resource Metrics

- `process_resident_memory_bytes` - Memory usage
- `process_cpu_seconds_total` - CPU usage
- `process_open_fds` - Open file descriptors

### Circuit Breaker Metrics

- `tunnel_circuit_breaker_state` - State (0=closed, 1=open, 0.5=half-open)
- `tunnel_circuit_breaker_failures_total` - Total failures
- `tunnel_circuit_breaker_successes_total` - Total successes

### Rate Limiter Metrics

- `tunnel_rate_limit_violations_total` - Total violations

### Queue Metrics

- `tunnel_queue_size` - Current size
- `tunnel_queue_fill_percentage` - Fill percentage
- `tunnel_queue_dropped_total` - Dropped requests

## MCP Tools Quick Reference

```bash
# List datasources
mcp_grafana_list_datasources({ type: 'prometheus' })

# Create dashboard
mcp_grafana_create_dashboard({ dashboard: {...} })

# Create alert
mcp_grafana_create_alert_rule({ title: '...', ... })

# List contact points
mcp_grafana_list_contact_points()

# Query metrics
mcp_grafana_query_prometheus({ datasourceUid: '...', expr: '...' })

# Query logs
mcp_grafana_query_loki_logs({ datasourceUid: '...', logql: '...' })

# Find error patterns
mcp_grafana_find_error_pattern_logs({ name: '...', labels: {...} })

# Generate deeplink
mcp_grafana_generate_deeplink({ resourceType: 'dashboard', dashboardUid: '...' })
```

## Common Queries

### Prometheus

```
# Active connections
tunnel_active_connections

# Success rate
(rate(tunnel_requests_total{status="success"}[5m]) / rate(tunnel_requests_total[5m])) * 100

# Average latency
avg(tunnel_request_latency_ms)

# P95 latency
histogram_quantile(0.95, tunnel_request_latency_ms)

# Error rate
rate(tunnel_errors_total[5m])

# Throughput
rate(tunnel_throughput_bytes_total[1m])
```

### Loki

```
# Error logs
{service="streaming-proxy"} |= "error"

# Auth errors
{service="streaming-proxy"} |= "auth" |= "error"

# Connection logs
{service="streaming-proxy"} |= "connection"

# Slow requests
{service="streaming-proxy"} |= "slow" |= "request"

# Circuit breaker events
{service="streaming-proxy"} |= "circuit" |= "breaker"

# Rate limit violations
{service="streaming-proxy"} |= "rate" |= "limit"
```

## Thresholds

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Active Connections | 0-500 | 500-1000 | >1000 |
| Success Rate | >99% | 95-99% | <95% |
| P95 Latency | <100ms | 100-200ms | >200ms |
| P99 Latency | <200ms | 200-500ms | >500ms |
| Error Rate | <1% | 1-5% | >5% |
| Memory Usage | <256MB | 256-512MB | >512MB |
| CPU Usage | <50% | 50-80% | >80% |
| Connection Pool | <80% | 80-90% | >90% |

## Troubleshooting Quick Tips

### Datasource Not Found

1. Verify Prometheus is running
2. Check Grafana datasource configuration
3. Verify API key permissions

### Metrics Not Appearing

1. Verify streaming-proxy is running
2. Check `/api/tunnel/metrics` endpoint
3. Verify Prometheus is scraping

### Alerts Not Firing

1. Check alert rule configuration
2. Verify notification channels
3. Test with manual trigger

### Dashboard Slow

1. Reduce time range
2. Simplify queries
3. Check Prometheus performance

## Implementation Checklist

- [ ] Verify Prometheus datasource
- [ ] Create Tunnel Health Dashboard
- [ ] Create Performance Dashboard
- [ ] Create Error Dashboard
- [ ] Create High Error Rate alert
- [ ] Create Connection Pool alert
- [ ] Create Circuit Breaker alert
- [ ] Create Rate Limit alert
- [ ] Configure notifications
- [ ] Generate dashboard links
- [ ] Test dashboards
- [ ] Test alerts
- [ ] Document URLs

## Related Documentation

- **Overview**: `README.md`
- **Detailed Guide**: `grafana-dashboard-setup.ts`
- **Step-by-Step**: `setup-grafana-dashboards.md`
- **Implementation**: `grafana-setup-script.ts`
- **Task Details**: `TASK_18_COMPLETION_SUMMARY.md`
- **Doc Updates**: `DOCUMENTATION_UPDATE_SUMMARY.md`

## External References

- Grafana Docs: https://grafana.com/docs/
- Prometheus Docs: https://prometheus.io/docs/
- Loki Docs: https://grafana.com/docs/loki/
- MCP Tools: `.kiro/steering/mcp-tools.md`

## Key Contacts

- **Grafana URL**: https://grafana.cloudtolocalllm.online
- **API Key**: [Configure in environment variables]
- **Metrics Endpoint**: `/api/tunnel/metrics`
- **Health Endpoint**: `/api/tunnel/health`

## Task 18 Status

✅ **COMPLETED**

- ✅ 18.1: Tunnel Health Dashboard
- ✅ 18.2: Performance Metrics Dashboard
- ✅ 18.3: Error Tracking Dashboard
- ✅ 18.4: Critical Alerts
- ✅ 18.5: Monitoring Documentation

See `TASK_18_COMPLETION_SUMMARY.md` for details.
