/**
 * Grafana Dashboard Setup using MCP Tools
 * 
 * This module demonstrates how to use Grafana MCP tools to create production
 * monitoring dashboards for the SSH WebSocket tunnel system.
 * 
 * Requirements:
 * - Grafana instance running at https://grafana.cloudtolocalllm.online
 * - Prometheus datasource configured in Grafana
 * - Grafana API key with admin permissions
 * - MCP Grafana server configured with GRAFANA_URL and GRAFANA_API_KEY
 * 
 * Usage:
 * 1. Ensure Prometheus datasource is available in Grafana
 * 2. Run this setup to create dashboards and alerts
 * 3. Access dashboards at https://grafana.cloudtolocalllm.online/d/{dashboardUid}
 */

/**
 * Task 18.1: Create Tunnel Health Dashboard
 * 
 * This dashboard provides real-time visibility into tunnel connection health,
 * request success rates, latency, and error rates.
 * 
 * Panels:
 * - Active connections (gauge)
 * - Request success rate (percentage)
 * - Average latency (graph)
 * - Error rate (graph)
 * - Connection pool status (table)
 * 
 * Metrics used:
 * - tunnel_active_connections: Current number of active tunnel connections
 * - tunnel_requests_total: Total number of requests processed
 * - tunnel_errors_total: Total number of errors
 * - tunnel_request_latency_ms: Request latency in milliseconds
 * 
 * Implementation steps:
 * 1. Use mcp_grafana_list_datasources to verify Prometheus datasource exists
 * 2. Use mcp_grafana_create_dashboard to create the dashboard
 * 3. Add panels with appropriate queries and visualizations
 * 4. Set refresh interval to 30 seconds
 * 5. Add tags: tunnel, monitoring, production
 */

export interface TunnelHealthDashboardConfig {
  datasourceUid: string;
  refreshInterval: string;
  tags: string[];
}

/**
 * Task 18.2: Create Performance Metrics Dashboard
 * 
 * This dashboard focuses on performance metrics including latency percentiles,
 * throughput, and resource usage.
 * 
 * Panels:
 * - P95 latency (graph)
 * - P99 latency (graph)
 * - Throughput (bytes/sec)
 * - Request rate (requests/sec)
 * - Memory usage (gauge)
 * - CPU usage (gauge)
 * 
 * Metrics used:
 * - tunnel_request_latency_ms{quantile="0.95"}: 95th percentile latency
 * - tunnel_request_latency_ms{quantile="0.99"}: 99th percentile latency
 * - tunnel_throughput_bytes_total: Total bytes transferred
 * - tunnel_requests_total: Total requests
 * - process_resident_memory_bytes: Memory usage
 * - process_cpu_seconds_total: CPU usage
 * 
 * Implementation steps:
 * 1. Create dashboard with time range selector (1h, 6h, 24h, 7d)
 * 2. Add dashboard variables for filtering by user tier
 * 3. Add panels with appropriate queries
 * 4. Configure graph visualizations with appropriate scales
 */

export interface PerformanceMetricsDashboardConfig {
  datasourceUid: string;
  timeRanges: string[];
  variables: Record<string, string>;
}

/**
 * Task 18.3: Create Error Tracking Dashboard
 * 
 * This dashboard provides visibility into errors, error patterns, and error rates.
 * 
 * Panels:
 * - Error rate by category (pie chart)
 * - Error count over time (graph)
 * - Top errors (table)
 * - Error rate by user (table)
 * 
 * Data sources:
 * - Prometheus for error metrics
 * - Loki for error logs
 * 
 * Implementation steps:
 * 1. Create dashboard with Prometheus and Loki datasources
 * 2. Add error rate pie chart using tunnel_errors_total metric
 * 3. Add error count graph using rate(tunnel_errors_total[5m])
 * 4. Use mcp_grafana_query_loki_logs to fetch error logs
 * 5. Use mcp_grafana_find_error_pattern_logs to identify error patterns
 * 6. Add drill-down capability to view detailed error logs
 */

export interface ErrorTrackingDashboardConfig {
  prometheusUid: string;
  lokiUid: string;
  errorThreshold: number;
}

/**
 * Task 18.4: Set up Critical Alerts
 * 
 * This task creates alert rules for critical tunnel issues:
 * 
 * Alerts:
 * 1. High error rate (>5% over 5 minutes)
 *    - Severity: warning
 *    - Action: Notify team
 * 
 * 2. Connection pool exhaustion (>90% capacity)
 *    - Severity: warning
 *    - Action: Scale up or investigate
 * 
 * 3. Circuit breaker open state
 *    - Severity: critical
 *    - Action: Immediate investigation
 * 
 * 4. Rate limit violations spike
 *    - Severity: warning
 *    - Action: Investigate traffic patterns
 * 
 * Implementation steps:
 * 1. Use mcp_grafana_create_alert_rule for each alert
 * 2. Configure notification channels using mcp_grafana_list_contact_points
 * 3. Set appropriate thresholds and durations
 * 4. Test alerts with manual triggers
 */

export interface AlertConfig {
  name: string;
  severity: 'critical' | 'warning' | 'info';
  threshold: number;
  duration: string;
  notificationChannels: string[];
}

/**
 * Task 18.5: Generate Monitoring Documentation
 * 
 * This task creates shareable dashboard links and documentation.
 * 
 * Outputs:
 * 1. Dashboard URLs using mcp_grafana_generate_deeplink
 * 2. Monitoring guide with dashboard descriptions
 * 3. Runbook for common alerts
 * 4. Metric meanings and thresholds
 * 
 * Implementation steps:
 * 1. Use mcp_grafana_generate_deeplink to create shareable links
 * 2. Document each dashboard's purpose and panels
 * 3. Create runbook with investigation steps
 * 4. Document metric meanings and normal ranges
 */

export interface MonitoringDocumentation {
  dashboardLinks: Record<string, string>;
  runbooks: Record<string, string>;
  metricDefinitions: Record<string, string>;
}

/**
 * Example: How to use Grafana MCP tools to create dashboards
 * 
 * Step 1: List available datasources
 * ```typescript
 * const datasources = await mcp_grafana_list_datasources({ type: 'prometheus' });
 * const prometheusUid = datasources[0].uid;
 * ```
 * 
 * Step 2: Create a dashboard
 * ```typescript
 * const dashboard = await mcp_grafana_create_dashboard({
 *   dashboard: {
 *     title: 'Tunnel Health',
 *     panels: [
 *       {
 *         title: 'Active Connections',
 *         targets: [
 *           {
 *             expr: 'tunnel_active_connections',
 *             refId: 'A',
 *           }
 *         ],
 *         type: 'gauge',
 *       }
 *     ],
 *     tags: ['tunnel', 'monitoring', 'production'],
 *     refresh: '30s',
 *   }
 * });
 * ```
 * 
 * Step 3: Create an alert rule
 * ```typescript
 * const alert = await mcp_grafana_create_alert_rule({
 *   title: 'High Error Rate',
 *   ruleGroup: 'tunnel-alerts',
 *   folderUID: 'tunnel-monitoring',
 *   condition: 'A',
 *   data: [
 *     {
 *       refId: 'A',
 *       queryType: 'range',
 *       model: {
 *         expr: 'rate(tunnel_errors_total[5m]) / rate(tunnel_requests_total[5m]) > 0.05',
 *       }
 *     }
 *   ],
 *   noDataState: 'NoData',
 *   execErrState: 'Alerting',
 *   for: '5m',
 *   orgID: 1,
 * });
 * ```
 * 
 * Step 4: Query metrics
 * ```typescript
 * const metrics = await mcp_grafana_query_prometheus({
 *   datasourceUid: prometheusUid,
 *   expr: 'tunnel_active_connections',
 *   queryType: 'instant',
 *   startTime: 'now',
 * });
 * ```
 * 
 * Step 5: Query logs
 * ```typescript
 * const logs = await mcp_grafana_query_loki_logs({
 *   datasourceUid: lokiUid,
 *   logql: '{service="streaming-proxy"} |= "error"',
 *   limit: 100,
 * });
 * ```
 * 
 * Step 6: Find error patterns
 * ```typescript
 * const patterns = await mcp_grafana_find_error_pattern_logs({
 *   name: 'Tunnel Error Analysis',
 *   labels: { service: 'streaming-proxy' },
 *   start: new Date(Date.now() - 30 * 60 * 1000), // 30 minutes ago
 *   end: new Date(),
 * });
 * ```
 * 
 * Step 7: Generate deeplinks
 * ```typescript
 * const link = await mcp_grafana_generate_deeplink({
 *   resourceType: 'dashboard',
 *   dashboardUid: 'tunnel-health',
 *   timeRange: {
 *     from: 'now-6h',
 *     to: 'now',
 *   }
 * });
 * ```
 */

/**
 * Prometheus Metrics Reference
 * 
 * Connection Metrics:
 * - tunnel_active_connections: Current number of active connections
 * - tunnel_connections_total: Total connections established
 * - tunnel_connection_duration_seconds: Connection duration
 * 
 * Request Metrics:
 * - tunnel_requests_total: Total requests processed
 * - tunnel_request_latency_ms: Request latency in milliseconds
 * - tunnel_request_latency_ms{quantile="0.95"}: 95th percentile latency
 * - tunnel_request_latency_ms{quantile="0.99"}: 99th percentile latency
 * 
 * Error Metrics:
 * - tunnel_errors_total: Total errors
 * - tunnel_errors_total{category="network"}: Network errors
 * - tunnel_errors_total{category="auth"}: Authentication errors
 * - tunnel_errors_total{category="server"}: Server errors
 * 
 * Performance Metrics:
 * - tunnel_throughput_bytes_total: Total bytes transferred
 * - tunnel_request_rate: Requests per second
 * - tunnel_error_rate: Error rate (errors/total requests)
 * 
 * Resource Metrics:
 * - process_resident_memory_bytes: Memory usage
 * - process_cpu_seconds_total: CPU usage
 * - process_open_fds: Open file descriptors
 * 
 * Circuit Breaker Metrics:
 * - tunnel_circuit_breaker_state: Circuit breaker state (0=closed, 1=open, 0.5=half-open)
 * - tunnel_circuit_breaker_failures_total: Total failures
 * - tunnel_circuit_breaker_successes_total: Total successes
 * 
 * Rate Limiter Metrics:
 * - tunnel_rate_limit_violations_total: Total rate limit violations
 * - tunnel_rate_limit_violations_total{user_id="..."}: Violations per user
 * 
 * Queue Metrics:
 * - tunnel_queue_size: Current queue size
 * - tunnel_queue_fill_percentage: Queue fill percentage
 * - tunnel_queue_dropped_total: Total dropped requests
 */

/**
 * Loki Log Queries Reference
 * 
 * Error logs:
 * {service="streaming-proxy"} |= "error"
 * 
 * Authentication errors:
 * {service="streaming-proxy"} |= "auth" |= "error"
 * 
 * Connection logs:
 * {service="streaming-proxy"} |= "connection"
 * 
 * Slow requests:
 * {service="streaming-proxy"} |= "slow" |= "request"
 * 
 * Circuit breaker events:
 * {service="streaming-proxy"} |= "circuit" |= "breaker"
 * 
 * Rate limit violations:
 * {service="streaming-proxy"} |= "rate" |= "limit"
 * 
 * With correlation ID:
 * {service="streaming-proxy"} | json | correlationId="..."
 */

export const GRAFANA_DASHBOARD_SETUP_GUIDE = `
# Grafana Dashboard Setup Guide

## Overview
This guide explains how to set up production monitoring dashboards for the SSH WebSocket tunnel system using Grafana MCP tools.

## Prerequisites
1. Grafana instance running at https://grafana.cloudtolocalllm.online
2. Prometheus datasource configured in Grafana
3. Loki datasource configured in Grafana (optional, for log analysis)
4. Grafana API key with admin permissions
5. MCP Grafana server configured with GRAFANA_URL and GRAFANA_API_KEY

## Dashboard Setup

### 1. Tunnel Health Dashboard (Task 18.1)
**Purpose**: Real-time visibility into tunnel connection health

**Panels**:
- Active Connections (gauge): Shows current number of active connections
- Request Success Rate (percentage): Shows percentage of successful requests
- Average Latency (graph): Shows request latency over time
- Error Rate (graph): Shows error rate over time
- Connection Pool Status (table): Shows connection pool statistics

**Metrics**:
- tunnel_active_connections
- tunnel_requests_total
- tunnel_errors_total
- tunnel_request_latency_ms

**Refresh**: 30 seconds
**Tags**: tunnel, monitoring, production

### 2. Performance Metrics Dashboard (Task 18.2)
**Purpose**: Performance analysis and optimization

**Panels**:
- P95 Latency (graph): 95th percentile latency
- P99 Latency (graph): 99th percentile latency
- Throughput (graph): Bytes per second
- Request Rate (graph): Requests per second
- Memory Usage (gauge): Process memory usage
- CPU Usage (gauge): Process CPU usage

**Variables**:
- User Tier: Filter by free, premium, enterprise
- Time Range: 1h, 6h, 24h, 7d

### 3. Error Tracking Dashboard (Task 18.3)
**Purpose**: Error analysis and pattern detection

**Panels**:
- Error Rate by Category (pie chart): Distribution of error types
- Error Count Over Time (graph): Error trend
- Top Errors (table): Most common errors
- Error Rate by User (table): Errors per user

**Data Sources**:
- Prometheus for metrics
- Loki for detailed logs

### 4. Critical Alerts (Task 18.4)
**Alerts**:
1. High Error Rate (>5% over 5 minutes) - Warning
2. Connection Pool Exhaustion (>90% capacity) - Warning
3. Circuit Breaker Open - Critical
4. Rate Limit Violations Spike - Warning

**Notification Channels**:
- Email
- Slack (optional)
- PagerDuty (optional)

### 5. Monitoring Documentation (Task 18.5)
**Outputs**:
- Dashboard URLs with deeplinks
- Monitoring guide
- Alert runbooks
- Metric definitions

## Implementation Steps

### Step 1: Verify Datasources
\`\`\`bash
# List available Prometheus datasources
mcp_grafana_list_datasources({ type: 'prometheus' })
\`\`\`

### Step 2: Create Dashboards
\`\`\`bash
# Create Tunnel Health Dashboard
mcp_grafana_create_dashboard({
  dashboard: {
    title: 'Tunnel Health',
    tags: ['tunnel', 'monitoring', 'production'],
    refresh: '30s',
    panels: [...]
  }
})
\`\`\`

### Step 3: Create Alerts
\`\`\`bash
# Create High Error Rate Alert
mcp_grafana_create_alert_rule({
  title: 'High Error Rate',
  ruleGroup: 'tunnel-alerts',
  condition: 'A',
  data: [...],
  for: '5m'
})
\`\`\`

### Step 4: Query Metrics
\`\`\`bash
# Query active connections
mcp_grafana_query_prometheus({
  datasourceUid: 'prometheus-uid',
  expr: 'tunnel_active_connections',
  queryType: 'instant'
})
\`\`\`

### Step 5: Query Logs
\`\`\`bash
# Query error logs
mcp_grafana_query_loki_logs({
  datasourceUid: 'loki-uid',
  logql: '{service="streaming-proxy"} |= "error"',
  limit: 100
})
\`\`\`

### Step 6: Generate Deeplinks
\`\`\`bash
# Generate shareable dashboard link
mcp_grafana_generate_deeplink({
  resourceType: 'dashboard',
  dashboardUid: 'tunnel-health',
  timeRange: { from: 'now-6h', to: 'now' }
})
\`\`\`

## Monitoring Best Practices

1. **Set Appropriate Thresholds**
   - Error rate: >5% is concerning
   - Latency: P95 > 200ms is concerning
   - Connection pool: >90% is concerning

2. **Use Correlation IDs**
   - All logs include X-Correlation-ID header
   - Use for tracing requests through system

3. **Regular Review**
   - Review dashboards daily
   - Adjust thresholds based on baseline
   - Update runbooks as needed

4. **Alert Fatigue Prevention**
   - Set appropriate alert durations (5-10 minutes)
   - Use severity levels appropriately
   - Avoid alerting on transient issues

## Troubleshooting

### Datasource Not Found
- Verify Prometheus is running
- Check Grafana datasource configuration
- Verify API key has appropriate permissions

### Metrics Not Appearing
- Verify streaming-proxy is running
- Check /api/tunnel/metrics endpoint
- Verify Prometheus is scraping metrics

### Alerts Not Firing
- Check alert rule configuration
- Verify notification channels are configured
- Test with manual alert trigger

## References

- Grafana Documentation: https://grafana.com/docs/
- Prometheus Documentation: https://prometheus.io/docs/
- Loki Documentation: https://grafana.com/docs/loki/
- MCP Grafana Tools: See mcp-tools.md
`;
