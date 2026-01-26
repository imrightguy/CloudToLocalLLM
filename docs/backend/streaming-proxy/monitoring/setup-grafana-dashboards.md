# Grafana Dashboard Setup Implementation Guide

## Task 18: Set up Grafana monitoring dashboards using MCP tools

This document provides step-by-step instructions for implementing production monitoring dashboards for the SSH WebSocket tunnel system using Grafana MCP tools.

## Prerequisites

Before starting, ensure:

1. Grafana instance is running at `https://grafana.cloudtolocalllm.online`
2. Prometheus datasource is configured in Grafana
3. Loki datasource is configured in Grafana (for log analysis)
4. Grafana API key is available: [Configure in environment variables]
5. MCP Grafana server is configured in `.kiro/settings/mcp.json`
6. Streaming-proxy is running and exposing metrics at `/api/tunnel/metrics`

## Task 18.1: Create Tunnel Health Dashboard

### Objective

Create a real-time dashboard showing tunnel connection health, request success rates, latency, and error rates.

### Implementation Steps

#### Step 1: Verify Prometheus Datasource

```typescript
// Use mcp_grafana_list_datasources to verify Prometheus is available
const datasources = await mcp_grafana_list_datasources({ type: 'prometheus' });
const prometheusUid = datasources.find(ds => ds.type === 'prometheus')?.uid;

if (!prometheusUid) {
  throw new Error('Prometheus datasource not found. Please configure it in Grafana.');
}
```

#### Step 2: Create Dashboard Structure

```typescript
const dashboardConfig = {
  title: 'Tunnel Health',
  description: 'Real-time tunnel connection health and performance',
  tags: ['tunnel', 'monitoring', 'production'],
  timezone: 'browser',
  refresh: '30s',
  time: {
    from: 'now-6h',
    to: 'now'
  },
  panels: [
    // Panel 1: Active Connections (Gauge)
    {
      id: 1,
      title: 'Active Connections',
      type: 'gauge',
      gridPos: { h: 8, w: 6, x: 0, y: 0 },
      targets: [
        {
          expr: 'tunnel_active_connections',
          refId: 'A',
          legendFormat: 'Connections'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'short',
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'green', value: null },
              { color: 'yellow', value: 500 },
              { color: 'red', value: 1000 }
            ]
          }
        }
      }
    },
    
    // Panel 2: Request Success Rate (Percentage)
    {
      id: 2,
      title: 'Request Success Rate',
      type: 'gauge',
      gridPos: { h: 8, w: 6, x: 6, y: 0 },
      targets: [
        {
          expr: '(rate(tunnel_requests_total{status="success"}[5m]) / rate(tunnel_requests_total[5m])) * 100',
          refId: 'A',
          legendFormat: 'Success Rate'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'percent',
          min: 0,
          max: 100,
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'red', value: null },
              { color: 'yellow', value: 95 },
              { color: 'green', value: 99 }
            ]
          }
        }
      }
    },
    
    // Panel 3: Average Latency (Graph)
    {
      id: 3,
      title: 'Average Latency',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 0, y: 8 },
      targets: [
        {
          expr: 'avg(tunnel_request_latency_ms)',
          refId: 'A',
          legendFormat: 'Average Latency'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'ms',
          custom: {
            lineWidth: 2,
            fillOpacity: 10
          }
        }
      }
    },
    
    // Panel 4: Error Rate (Graph)
    {
      id: 4,
      title: 'Error Rate',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 12, y: 8 },
      targets: [
        {
          expr: 'rate(tunnel_errors_total[5m])',
          refId: 'A',
          legendFormat: '{{ error_type }}'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'short',
          custom: {
            lineWidth: 2,
            fillOpacity: 10
          }
        }
      }
    },
    
    // Panel 5: Connection Pool Status (Table)
    {
      id: 5,
      title: 'Connection Pool Status',
      type: 'table',
      gridPos: { h: 8, w: 24, x: 0, y: 16 },
      targets: [
        {
          expr: 'tunnel_connection_pool_active_connections',
          refId: 'A',
          format: 'table'
        }
      ],
      transformations: [
        {
          id: 'organize',
          options: {
            excludeByName: {},
            indexByName: {},
            renameByName: {
              'tunnel_connection_pool_active_connections': 'Active',
              'tunnel_connection_pool_idle_connections': 'Idle',
              'tunnel_connection_pool_total_connections': 'Total'
            }
          }
        }
      ]
    }
  ]
};
```

#### Step 3: Create Dashboard via MCP

```typescript
const dashboard = await mcp_grafana_create_dashboard({
  dashboard: dashboardConfig,
  overwrite: true
});

console.log(`Dashboard created: ${dashboard.url}`);
```

### Metrics Used

- `tunnel_active_connections`: Current number of active tunnel connections
- `tunnel_requests_total`: Total number of requests processed
- `tunnel_errors_total`: Total number of errors
- `tunnel_request_latency_ms`: Request latency in milliseconds
- `tunnel_connection_pool_active_connections`: Active connections in pool
- `tunnel_connection_pool_idle_connections`: Idle connections in pool
- `tunnel_connection_pool_total_connections`: Total connections in pool

### Expected Output

- Dashboard URL: `https://grafana.cloudtolocalllm.online/d/tunnel-health`
- Refresh interval: 30 seconds
- Time range: Last 6 hours (configurable)

---

## Task 18.2: Create Performance Metrics Dashboard

### Objective

Create a dashboard focused on performance analysis including latency percentiles, throughput, and resource usage.

### Implementation Steps

#### Step 1: Create Dashboard with Variables

```typescript
const performanceDashboard = {
  title: 'Tunnel Performance',
  description: 'Performance metrics and resource usage analysis',
  tags: ['tunnel', 'performance', 'production'],
  refresh: '30s',
  templating: {
    list: [
      {
        name: 'userTier',
        type: 'query',
        datasource: 'Prometheus',
        query: 'label_values(tunnel_requests_total, user_tier)',
        multi: true,
        includeAll: true,
        current: { text: 'All', value: '$__all' }
      },
      {
        name: 'timeRange',
        type: 'interval',
        options: [
          { text: '1h', value: '1h' },
          { text: '6h', value: '6h' },
          { text: '24h', value: '24h' },
          { text: '7d', value: '7d' }
        ],
        current: { text: '6h', value: '6h' }
      }
    ]
  },
  panels: [
    // Panel 1: P95 Latency
    {
      id: 1,
      title: 'P95 Latency',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 0, y: 0 },
      targets: [
        {
          expr: 'histogram_quantile(0.95, tunnel_request_latency_ms)',
          refId: 'A',
          legendFormat: 'P95'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'ms',
          custom: { lineWidth: 2 }
        }
      }
    },
    
    // Panel 2: P99 Latency
    {
      id: 2,
      title: 'P99 Latency',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 12, y: 0 },
      targets: [
        {
          expr: 'histogram_quantile(0.99, tunnel_request_latency_ms)',
          refId: 'A',
          legendFormat: 'P99'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'ms',
          custom: { lineWidth: 2 }
        }
      }
    },
    
    // Panel 3: Throughput
    {
      id: 3,
      title: 'Throughput (Bytes/sec)',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 0, y: 8 },
      targets: [
        {
          expr: 'rate(tunnel_throughput_bytes_total[1m])',
          refId: 'A',
          legendFormat: 'Throughput'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'Bps',
          custom: { lineWidth: 2 }
        }
      }
    },
    
    // Panel 4: Request Rate
    {
      id: 4,
      title: 'Request Rate (req/sec)',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 12, y: 8 },
      targets: [
        {
          expr: 'rate(tunnel_requests_total[1m])',
          refId: 'A',
          legendFormat: 'Requests/sec'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'short',
          custom: { lineWidth: 2 }
        }
      }
    },
    
    // Panel 5: Memory Usage
    {
      id: 5,
      title: 'Memory Usage',
      type: 'gauge',
      gridPos: { h: 8, w: 12, x: 0, y: 16 },
      targets: [
        {
          expr: 'process_resident_memory_bytes / 1024 / 1024',
          refId: 'A',
          legendFormat: 'Memory'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'MB',
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'green', value: null },
              { color: 'yellow', value: 256 },
              { color: 'red', value: 512 }
            ]
          }
        }
      }
    },
    
    // Panel 6: CPU Usage
    {
      id: 6,
      title: 'CPU Usage',
      type: 'gauge',
      gridPos: { h: 8, w: 12, x: 12, y: 16 },
      targets: [
        {
          expr: 'rate(process_cpu_seconds_total[1m]) * 100',
          refId: 'A',
          legendFormat: 'CPU'
        }
      ],
      fieldConfig: {
        defaults: {
          unit: 'percent',
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'green', value: null },
              { color: 'yellow', value: 50 },
              { color: 'red', value: 80 }
            ]
          }
        }
      }
    }
  ]
};
```

#### Step 2: Create Dashboard

```typescript
const perfDashboard = await mcp_grafana_create_dashboard({
  dashboard: performanceDashboard,
  overwrite: true
});

console.log(`Performance dashboard created: ${perfDashboard.url}`);
```

### Metrics Used

- `histogram_quantile(0.95, tunnel_request_latency_ms)`: 95th percentile latency
- `histogram_quantile(0.99, tunnel_request_latency_ms)`: 99th percentile latency
- `tunnel_throughput_bytes_total`: Total bytes transferred
- `tunnel_requests_total`: Total requests
- `process_resident_memory_bytes`: Memory usage
- `process_cpu_seconds_total`: CPU usage

---

## Task 18.3: Create Error Tracking Dashboard

### Objective

Create a dashboard for error analysis and pattern detection using both Prometheus and Loki.

### Implementation Steps

#### Step 1: Create Error Dashboard

```typescript
const errorDashboard = {
  title: 'Tunnel Errors',
  description: 'Error tracking and pattern analysis',
  tags: ['tunnel', 'errors', 'production'],
  refresh: '30s',
  panels: [
    // Panel 1: Error Rate by Category (Pie Chart)
    {
      id: 1,
      title: 'Error Rate by Category',
      type: 'piechart',
      gridPos: { h: 8, w: 12, x: 0, y: 0 },
      targets: [
        {
          expr: 'sum by (error_category) (rate(tunnel_errors_total[5m]))',
          refId: 'A',
          legendFormat: '{{ error_category }}'
        }
      ]
    },
    
    // Panel 2: Error Count Over Time
    {
      id: 2,
      title: 'Error Count Over Time',
      type: 'timeseries',
      gridPos: { h: 8, w: 12, x: 12, y: 0 },
      targets: [
        {
          expr: 'rate(tunnel_errors_total[5m])',
          refId: 'A',
          legendFormat: '{{ error_category }}'
        }
      ],
      fieldConfig: {
        defaults: {
          custom: { lineWidth: 2 }
        }
      }
    },
    
    // Panel 3: Top Errors (Table)
    {
      id: 3,
      title: 'Top Errors',
      type: 'table',
      gridPos: { h: 8, w: 24, x: 0, y: 8 },
      targets: [
        {
          expr: 'topk(10, sum by (error_code, error_message) (rate(tunnel_errors_total[5m])))',
          refId: 'A',
          format: 'table'
        }
      ]
    },
    
    // Panel 4: Error Rate by User (Table)
    {
      id: 4,
      title: 'Error Rate by User',
      type: 'table',
      gridPos: { h: 8, w: 24, x: 0, y: 16 },
      targets: [
        {
          expr: 'sum by (user_id) (rate(tunnel_errors_total[5m]))',
          refId: 'A',
          format: 'table'
        }
      ]
    }
  ]
};
```

#### Step 2: Query Error Logs from Loki

```typescript
// Query error logs using mcp_grafana_query_loki_logs
const errorLogs = await mcp_grafana_query_loki_logs({
  datasourceUid: 'loki-uid',
  logql: '{service="streaming-proxy"} |= "error"',
  limit: 100,
  startRfc3339: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
  endRfc3339: new Date().toISOString()
});

console.log(`Found ${errorLogs.length} error logs`);
```

#### Step 3: Find Error Patterns

```typescript
// Use mcp_grafana_find_error_pattern_logs to identify patterns
const errorPatterns = await mcp_grafana_find_error_pattern_logs({
  name: 'Tunnel Error Pattern Analysis',
  labels: { service: 'streaming-proxy' },
  start: new Date(Date.now() - 30 * 60 * 1000),
  end: new Date()
});

console.log('Error patterns found:', errorPatterns);
```

---

## Task 18.4: Set up Critical Alerts

### Objective

Create alert rules for critical tunnel issues with appropriate notification channels.

### Implementation Steps

#### Step 1: List Available Contact Points

```typescript
const contactPoints = await mcp_grafana_list_contact_points();
console.log('Available notification channels:', contactPoints);
```

#### Step 2: Create High Error Rate Alert

```typescript
const highErrorRateAlert = await mcp_grafana_create_alert_rule({
  title: 'High Error Rate',
  ruleGroup: 'tunnel-alerts',
  folderUID: 'tunnel-monitoring',
  condition: 'A',
  data: [
    {
      refId: 'A',
      queryType: 'range',
      model: {
        expr: '(rate(tunnel_errors_total[5m]) / rate(tunnel_requests_total[5m])) > 0.05',
        interval: '1m'
      }
    }
  ],
  noDataState: 'NoData',
  execErrState: 'Alerting',
  for: '5m',
  orgID: 1,
  labels: {
    severity: 'warning',
    team: 'platform'
  },
  annotations: {
    summary: 'High error rate detected',
    description: 'Error rate exceeded 5% threshold'
  }
});

console.log('Alert created:', highErrorRateAlert);
```

#### Step 3: Create Connection Pool Exhaustion Alert

```typescript
const poolExhaustionAlert = await mcp_grafana_create_alert_rule({
  title: 'Connection Pool Exhaustion',
  ruleGroup: 'tunnel-alerts',
  folderUID: 'tunnel-monitoring',
  condition: 'A',
  data: [
    {
      refId: 'A',
      queryType: 'range',
      model: {
        expr: '(tunnel_connection_pool_active_connections / tunnel_connection_pool_total_connections) > 0.9',
        interval: '1m'
      }
    }
  ],
  noDataState: 'NoData',
  execErrState: 'Alerting',
  for: '5m',
  orgID: 1,
  labels: {
    severity: 'warning'
  }
});
```

#### Step 4: Create Circuit Breaker Open Alert

```typescript
const circuitBreakerAlert = await mcp_grafana_create_alert_rule({
  title: 'Circuit Breaker Open',
  ruleGroup: 'tunnel-alerts',
  folderUID: 'tunnel-monitoring',
  condition: 'A',
  data: [
    {
      refId: 'A',
      queryType: 'instant',
      model: {
        expr: 'tunnel_circuit_breaker_state == 1'
      }
    }
  ],
  noDataState: 'NoData',
  execErrState: 'Alerting',
  for: '1m',
  orgID: 1,
  labels: {
    severity: 'critical'
  }
});
```

#### Step 5: Create Rate Limit Violations Alert

```typescript
const rateLimitAlert = await mcp_grafana_create_alert_rule({
  title: 'Rate Limit Violations Spike',
  ruleGroup: 'tunnel-alerts',
  folderUID: 'tunnel-monitoring',
  condition: 'A',
  data: [
    {
      refId: 'A',
      queryType: 'range',
      model: {
        expr: 'increase(tunnel_rate_limit_violations_total[5m]) > 100',
        interval: '1m'
      }
    }
  ],
  noDataState: 'NoData',
  execErrState: 'Alerting',
  for: '5m',
  orgID: 1,
  labels: {
    severity: 'warning'
  }
});
```

---

## Task 18.5: Generate Monitoring Documentation

### Objective

Create shareable dashboard links and comprehensive monitoring documentation.

### Implementation Steps

#### Step 1: Generate Dashboard Deeplinks

```typescript
// Generate link for Tunnel Health Dashboard
const healthDashboardLink = await mcp_grafana_generate_deeplink({
  resourceType: 'dashboard',
  dashboardUid: 'tunnel-health',
  timeRange: {
    from: 'now-6h',
    to: 'now'
  }
});

// Generate link for Performance Dashboard
const perfDashboardLink = await mcp_grafana_generate_deeplink({
  resourceType: 'dashboard',
  dashboardUid: 'tunnel-performance',
  timeRange: {
    from: 'now-24h',
    to: 'now'
  }
});

// Generate link for Error Dashboard
const errorDashboardLink = await mcp_grafana_generate_deeplink({
  resourceType: 'dashboard',
  dashboardUid: 'tunnel-errors',
  timeRange: {
    from: 'now-7d',
    to: 'now'
  }
});

console.log('Dashboard Links:');
console.log('- Health:', healthDashboardLink);
console.log('- Performance:', perfDashboardLink);
console.log('- Errors:', errorDashboardLink);
```

#### Step 2: Create Monitoring Guide

Create `docs/OPERATIONS/TUNNEL_MONITORING_GUIDE.md` with:

- Dashboard descriptions
- Metric meanings
- Alert thresholds
- Troubleshooting procedures

#### Step 3: Create Alert Runbooks

Create `docs/OPERATIONS/TUNNEL_ALERT_RUNBOOKS.md` with:

- Alert descriptions
- Investigation steps
- Resolution procedures
- Escalation paths

---

## Verification Checklist

- [ ] Prometheus datasource is available in Grafana
- [ ] Tunnel Health Dashboard created and accessible
- [ ] Performance Metrics Dashboard created and accessible
- [ ] Error Tracking Dashboard created and accessible
- [ ] High Error Rate alert configured
- [ ] Connection Pool Exhaustion alert configured
- [ ] Circuit Breaker Open alert configured
- [ ] Rate Limit Violations alert configured
- [ ] Dashboard deeplinks generated
- [ ] Monitoring documentation created
- [ ] Alert runbooks created
- [ ] Dashboards refresh correctly
- [ ] Metrics are being collected and displayed
- [ ] Alerts fire correctly when thresholds are exceeded

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

## References

- Grafana MCP Tools: `.kiro/steering/mcp-tools.md`
- Prometheus Metrics: `services/streaming-proxy/src/metrics/server-metrics-collector.ts`
- Alert Configuration: `config/prometheus/tunnel-alerts.yaml`
- Kubernetes Deployment: `k8s/streaming-proxy-deployment.yaml`
