# Proxy Scaling Quick Reference

## Overview

Proxy scaling automatically adjusts the number of proxy instances based on system load metrics (CPU, memory, request rate, error rate).

## Key Concepts

### Load Score

Composite metric (0-100) combining:

- CPU: 40%
- Memory: 30%
- Request Rate: 20%
- Error Rate: 10%

### Scaling Policy

Configuration that defines:

- Min/max replicas
- Scale up/down thresholds
- Cooldown periods
- Target metrics

### Scaling Events

Records of scaling operations with:

- Event type (scale_up, scale_down)
- Previous/new replica counts
- Trigger source (auto, manual, admin)
- Status and duration

## API Endpoints

### Create/Update Policy

```bash
POST /proxy/scaling/policies/:proxyId
Content-Type: application/json

{
  "minReplicas": 1,
  "maxReplicas": 10,
  "targetCpuPercent": 70,
  "targetMemoryPercent": 80,
  "scaleUpThreshold": 80,
  "scaleDownThreshold": 30,
  "scaleUpCooldownSeconds": 60,
  "scaleDownCooldownSeconds": 300
}
```

### Get Policy

```bash
GET /proxy/scaling/policies/:proxyId
```

### Record Metrics

```bash
POST /proxy/scaling/metrics/:proxyId
Content-Type: application/json

{
  "currentReplicas": 3,
  "cpuPercent": 75,
  "memoryPercent": 80,
  "requestRate": 1200,
  "averageLatencyMs": 50,
  "errorRate": 0.01,
  "connectionCount": 200
}
```

### Get Current Metrics

```bash
GET /proxy/scaling/metrics/:proxyId
```

### Evaluate Scaling

```bash
POST /proxy/scaling/evaluate/:proxyId
```

Response:

```json
{
  "shouldScale": true,
  "scalingAction": "scale_up",
  "reason": "Load score 85 exceeds threshold 80",
  "currentReplicas": 3,
  "loadScore": 85,
  "policy": {
    "minReplicas": 1,
    "maxReplicas": 10,
    "scaleUpThreshold": 80,
    "scaleDownThreshold": 30
  }
}
```

### Execute Scaling

```bash
POST /proxy/scaling/execute/:proxyId
Content-Type: application/json

{
  "newReplicaCount": 5,
  "reason": "High load detected",
  "triggeredBy": "auto"
}
```

### Get Scaling Events

```bash
GET /proxy/scaling/events/:proxyId?limit=50
```

### Get Scaling Summary

```bash
GET /proxy/scaling/summary/:proxyId?hoursBack=24
```

Response:

```json
{
  "summary": {
    "proxyId": "...",
    "timeRange": {
      "hoursBack": 24,
      "from": "2024-01-19T00:00:00Z",
      "to": "2024-01-20T00:00:00Z"
    },
    "scalingEvents": {
      "total": 5,
      "scaleUp": 3,
      "scaleDown": 2,
      "successful": 5,
      "failed": 0
    },
    "loadMetrics": {
      "recordCount": 1440,
      "averageLoadScore": "65.50",
      "maxLoadScore": "92.30",
      "minLoadScore": "15.20"
    }
  }
}
```

## Default Policy

```javascript
{
  minReplicas: 1,
  maxReplicas: 10,
  targetCpuPercent: 70.0,
  targetMemoryPercent: 80.0,
  targetRequestRate: 1000.0,
  scaleUpThreshold: 80.0,
  scaleDownThreshold: 30.0,
  scaleUpCooldownSeconds: 60,
  scaleDownCooldownSeconds: 300,
}
```

## Scaling Behavior

### Scale Up

- Triggered when: Load Score > 80%
- Condition: Current Replicas < Max Replicas
- Cooldown: 60 seconds
- Action: Increase replicas

### Scale Down

- Triggered when: Load Score < 30%
- Condition: Current Replicas > Min Replicas
- Cooldown: 300 seconds
- Action: Decrease replicas

### No Scaling

- Load Score between 30% and 80%
- Already at min/max replicas
- Cooldown period active
- Policy disabled

## Error Codes

| Code | Status | Meaning |
|------|--------|---------|
| PROXY_SCALING_001 | 400 | Invalid request (missing required field) |
| PROXY_SCALING_002 | 503 | Service unavailable |
| PROXY_SCALING_003 | 400 | Validation error |
| PROXY_SCALING_004 | 500 | Internal server error |
| PROXY_SCALING_005 | 404 | Not found |

## Usage Example

```javascript
// 1. Create scaling policy
POST /proxy/scaling/policies/proxy-123
{
  "minReplicas": 2,
  "maxReplicas": 20,
  "scaleUpThreshold": 75,
  "scaleDownThreshold": 25
}

// 2. Record metrics periodically
POST /proxy/scaling/metrics/proxy-123
{
  "currentReplicas": 3,
  "cpuPercent": 65,
  "memoryPercent": 70,
  "requestRate": 800,
  "averageLatencyMs": 45,
  "errorRate": 0.005,
  "connectionCount": 150
}

// 3. Evaluate if scaling needed
POST /proxy/scaling/evaluate/proxy-123
// Returns: shouldScale: false (load score 60 is within thresholds)

// 4. When load increases
POST /proxy/scaling/metrics/proxy-123
{
  "currentReplicas": 3,
  "cpuPercent": 85,
  "memoryPercent": 88,
  "requestRate": 1500,
  "averageLatencyMs": 100,
  "errorRate": 0.02,
  "connectionCount": 400
}

// 5. Evaluate again
POST /proxy/scaling/evaluate/proxy-123
// Returns: shouldScale: true, scalingAction: "scale_up"

// 6. Execute scaling
POST /proxy/scaling/execute/proxy-123
{
  "newReplicaCount": 5,
  "reason": "High load detected",
  "triggeredBy": "auto"
}

// 7. Check history
GET /proxy/scaling/events/proxy-123
GET /proxy/scaling/summary/proxy-123?hoursBack=24
```

## Configuration

### Environment Variables

```bash
# Scaling service configuration
PROXY_SCALING_ENABLED=true
PROXY_SCALING_INTERVAL_MS=30000  # Evaluation interval
PROXY_SCALING_MAX_REPLICAS=20
PROXY_SCALING_MIN_REPLICAS=1
```

### Policy Customization

Policies can be customized per proxy:

```javascript
{
  // Conservative scaling (fewer changes)
  minReplicas: 2,
  maxReplicas: 10,
  scaleUpThreshold: 85,
  scaleDownThreshold: 20,
  scaleUpCooldownSeconds: 300,
  scaleDownCooldownSeconds: 600
}

// Aggressive scaling (more responsive)
{
  minReplicas: 1,
  maxReplicas: 50,
  scaleUpThreshold: 70,
  scaleDownThreshold: 40,
  scaleUpCooldownSeconds: 30,
  scaleDownCooldownSeconds: 120
}
```

## Monitoring

### Key Metrics to Monitor

1. **Load Score**: Current composite load (0-100)
2. **Scaling Events**: Frequency and success rate
3. **Replica Count**: Current vs target
4. **Cooldown Status**: Active cooldown periods
5. **Policy Effectiveness**: Load trends after scaling

### Prometheus Metrics

```
proxy_scaling_load_score{proxy_id="..."} 65.5
proxy_scaling_replicas{proxy_id="..."} 3
proxy_scaling_events_total{proxy_id="...", type="scale_up"} 5
proxy_scaling_events_failed{proxy_id="..."} 0
```

## Troubleshooting

### Scaling Not Happening

1. Check if policy is enabled
2. Verify load score calculation
3. Check cooldown periods
4. Verify min/max replica limits

### Excessive Scaling

1. Increase cooldown periods
2. Adjust thresholds (wider gap)
3. Review load metrics for spikes
4. Consider conservative policy

### Metrics Not Recording

1. Verify metrics endpoint is called
2. Check required fields are present
3. Verify authentication
4. Check database connectivity

## Best Practices

1. **Set Realistic Thresholds**: Based on actual workload patterns
2. **Monitor Cooldown Periods**: Prevent oscillation
3. **Review Policies Regularly**: Adjust based on trends
4. **Test Scaling**: Verify scaling works before production
5. **Set Alerts**: Monitor scaling failures
6. **Document Policies**: Record why policies are configured
7. **Gradual Changes**: Don't change policies drastically
8. **Capacity Planning**: Ensure max replicas are sufficient
