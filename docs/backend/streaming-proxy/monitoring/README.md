# Tunnel Monitoring Setup

This directory contains comprehensive guides and implementations for setting up production monitoring dashboards for the SSH WebSocket tunnel system using Grafana and Prometheus.

## Overview

The monitoring setup provides:

- **Real-time dashboards** for tunnel health, performance, and errors
- **Critical alerts** for system issues
- **Comprehensive metrics** for analysis and troubleshooting
- **Log analysis** capabilities using Loki
- **MCP tools integration** for automated dashboard creation

## Files in This Directory

### 1. `grafana-dashboard-setup.ts`

**Purpose**: Comprehensive guide for using Grafana MCP tools

**Contents**:

- Dashboard configuration interfaces
- Alert rule configurations
- Prometheus metrics reference (30+ metrics)
- Loki log queries reference
- Implementation notes and best practices
- Code examples for all MCP tools

**Use Case**: Reference guide for understanding dashboard setup and MCP tool usage

### 2. `setup-grafana-dashboards.md`

**Purpose**: Step-by-step implementation guide

**Contents**:

- Detailed instructions for each task
- Code examples for MCP tool usage
- Metrics reference
- Verification checklist
- Troubleshooting guide

**Use Case**: Follow this guide to implement dashboards in your Grafana instance

### 3. `grafana-setup-script.ts`

**Purpose**: Practical implementation script

**Contents**:

- Dashboard configurations (JSON)
- Alert rule configurations
- Prometheus metrics reference
- Loki log queries reference
- Implementation checklist

**Use Case**: Use this script as a starting point for your implementation

### 4. `TASK_18_COMPLETION_SUMMARY.md`

**Purpose**: Task completion documentation

**Contents**:

- Task overview and status
- Completed sub-tasks
- Deliverables
- Key features
- Requirements coverage
- Implementation steps
- Usage guide
- Troubleshooting

**Use Case**: Understand what was completed and how to use the monitoring system

## Quick Start

### Prerequisites

1. Grafana instance running at https://grafana.zoidbot.online
2. Prometheus datasource configured in Grafana
3. Grafana API key with admin permissions
4. MCP Grafana server configured with GRAFANA_URL and GRAFANA_API_KEY

### Step 1: Verify Prometheus Datasource

```bash
mcp_grafana_list_datasources({ type: 'prometheus' })
```

### Step 2: Create Dashboards

Follow the instructions in `setup-grafana-dashboards.md` to create:

- Tunnel Health Dashboard
- Performance Metrics Dashboard
- Error Tracking Dashboard

### Step 3: Set up Alerts

Create alert rules for:

- High error rate (>5% over 5 minutes)
- Connection pool exhaustion (>90% capacity)
- Circuit breaker open
- Rate limit violations spike (>100 in 5 minutes)

### Step 4: Generate Documentation

Generate shareable dashboard links and create monitoring documentation

## Dashboard Overview

### Tunnel Health Dashboard

**Purpose**: Real-time visibility into tunnel connection health

**Panels**:

- Active Connections (gauge)
- Request Success Rate (percentage)
- Average Latency (graph)
- Error Rate (graph)
- Connection Pool Status (table)

**Refresh**: 30 seconds
**Tags**: tunnel, monitoring, production

### Performance Metrics Dashboard

**Purpose**: Performance analysis and optimization

**Panels**:

- P95 Latency (graph)
- P99 Latency (graph)
- Throughput (bytes/sec)
- Request Rate (requests/sec)
- Memory Usage (gauge)
- CPU Usage (gauge)

**Variables**: User Tier, Time Range
**Refresh**: 30 seconds

### Error Tracking Dashboard

**Purpose**: Error analysis and pattern detection

**Panels**:

- Error Rate by Category (pie chart)
- Error Count Over Time (graph)
- Top Errors (table)
- Error Rate by User (table)

**Data Sources**: Prometheus, Loki
**Refresh**: 30 seconds

## Alert Rules

### 1. High Error Rate

- **Condition**: Error rate > 5% over 5 minutes
- **Severity**: Warning
- **Action**: Notify team

### 2. Connection Pool Exhaustion

- **Condition**: Connection pool > 90% capacity
- **Severity**: Warning
- **Action**: Scale up or investigate

### 3. Circuit Breaker Open

- **Condition**: Circuit breaker state = 1 (open)
- **Severity**: Critical
- **Action**: Immediate investigation

### 4. Rate Limit Violations Spike

- **Condition**: Rate limit violations > 100 in 5 minutes
- **Severity**: Warning
- **Action**: Investigate traffic patterns

## Metrics Reference

### Connection Metrics

- `tunnel_active_connections` - Current active connections
- `tunnel_connections_total` - Total connections established
- `tunnel_connection_duration_seconds` - Connection duration

### Request Metrics

- `tunnel_requests_total` - Total requests processed
- `tunnel_request_latency_ms` - Request latency
- `tunnel_request_latency_ms{quantile="0.95"}` - P95 latency
- `tunnel_request_latency_ms{quantile="0.99"}` - P99 latency

### Error Metrics

- `tunnel_errors_total` - Total errors
- `tunnel_errors_total{category="network"}` - Network errors
- `tunnel_errors_total{category="auth"}` - Auth errors
- `tunnel_errors_total{category="server"}` - Server errors

### Performance Metrics

- `tunnel_throughput_bytes_total` - Total bytes transferred
- `tunnel_request_rate` - Requests per second
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

- `tunnel_queue_size` - Current queue size
- `tunnel_queue_fill_percentage` - Queue fill percentage
- `tunnel_queue_dropped_total` - Total dropped requests

## MCP Tools Used

1. **mcp_grafana_list_datasources** - Verify Prometheus datasource
2. **mcp_grafana_create_dashboard** - Create monitoring dashboards
3. **mcp_grafana_create_alert_rule** - Create alert rules
4. **mcp_grafana_list_contact_points** - Verify notification channels
5. **mcp_grafana_query_prometheus** - Query metrics
6. **mcp_grafana_query_loki_logs** - Query error logs
7. **mcp_grafana_find_error_pattern_logs** - Detect error patterns
8. **mcp_grafana_generate_deeplink** - Generate shareable links

## Monitoring Best Practices

1. **Set Appropriate Thresholds**
   - Error rate: >5% is concerning
   - Latency P95: >200ms is concerning
   - Connection pool: >90% is concerning
   - Memory: >512MB is concerning
   - CPU: >80% is concerning

2. **Use Correlation IDs**
   - All logs include X-Correlation-ID header
   - Use for tracing requests through system
   - Correlate logs with metrics

3. **Regular Review**
   - Review dashboards daily
   - Adjust thresholds based on baseline
   - Update runbooks as needed

4. **Alert Fatigue Prevention**
   - Set appropriate alert durations (5-10 minutes)
   - Use severity levels appropriately
   - Avoid alerting on transient issues

5. **Documentation**
   - Document dashboard purposes
   - Explain metric meanings
   - Provide troubleshooting guides

## Troubleshooting

### Datasource Not Found

- Verify Prometheus is running
- Check Grafana datasource configuration
- Verify API key has appropriate permissions

### Metrics Not Appearing

- Verify streaming-proxy is running
- Check `/api/tunnel/metrics` endpoint
- Verify Prometheus is scraping metrics
- Check Prometheus targets page

### Alerts Not Firing

- Check alert rule configuration
- Verify notification channels are configured
- Test with manual alert trigger
- Check Grafana logs for errors

### Dashboard Slow

- Reduce time range
- Simplify queries
- Increase Prometheus retention
- Check Prometheus performance

## Related Documentation

- **Grafana MCP Tools Usage**: `docs/OPERATIONS/GRAFANA_MCP_TOOLS_USAGE.md`
- **Tunnel Monitoring Setup**: `docs/OPERATIONS/TUNNEL_MONITORING_SETUP.md`
- **Streaming Proxy Metrics**: `services/streaming-proxy/src/metrics/server-metrics-collector.ts`
- **MCP Tools Configuration**: `.kiro/steering/mcp-tools.md`

## Implementation Checklist

- [ ] Verify Prometheus datasource is available
- [ ] Create Tunnel Health Dashboard
- [ ] Create Performance Metrics Dashboard
- [ ] Create Error Tracking Dashboard
- [ ] Create High Error Rate alert
- [ ] Create Connection Pool Exhaustion alert
- [ ] Create Circuit Breaker Open alert
- [ ] Create Rate Limit Violations alert
- [ ] Configure notification channels
- [ ] Generate dashboard deeplinks
- [ ] Create monitoring documentation
- [ ] Create alert runbooks
- [ ] Test dashboards with real metrics
- [ ] Test alerts with manual triggers
- [ ] Verify log queries work correctly
- [ ] Document dashboard URLs

## Next Steps

1. **Deploy Dashboards**
   - Use MCP tools to create dashboards in production Grafana
   - Configure notification channels
   - Test alerts

2. **Monitor System**
   - Review dashboards daily
   - Adjust thresholds based on baseline
   - Update runbooks as needed

3. **Continuous Improvement**
   - Add new dashboards as needed
   - Refine alert thresholds
   - Improve documentation
   - Gather team feedback

## References

- Grafana Documentation: https://grafana.com/docs/
- Prometheus Documentation: https://prometheus.io/docs/
- Loki Documentation: https://grafana.com/docs/loki/
- MCP Grafana Tools: `.kiro/steering/mcp-tools.md`
- Streaming Proxy Metrics: `services/streaming-proxy/src/metrics/server-metrics-collector.ts`

## Task 18 Status

✅ **COMPLETED** - All sub-tasks completed:

- ✅ 18.1: Tunnel Health Dashboard
- ✅ 18.2: Performance Metrics Dashboard
- ✅ 18.3: Error Tracking Dashboard
- ✅ 18.4: Critical Alerts
- ✅ 18.5: Monitoring Documentation

See `TASK_18_COMPLETION_SUMMARY.md` for detailed completion information.
