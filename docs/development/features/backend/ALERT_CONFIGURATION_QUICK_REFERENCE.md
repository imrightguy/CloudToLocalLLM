# Alert Configuration Quick Reference

## Alert Configuration Service

### Import

```javascript
import { alertConfigService } from './services/alert-configuration-service.js';
```

### Get Thresholds

```javascript
const thresholds = alertConfigService.getThresholds();
// Returns: { responseTime: { warning: 500, critical: 1000 }, ... }
```

### Update Thresholds

```javascript
alertConfigService.updateThresholds({
  responseTime: { warning: 300, critical: 800 },
  errorRate: { warning: 3, critical: 8 }
});
```

### Get Enabled Channels

```javascript
const channels = alertConfigService.getEnabledChannels();
// Returns: { email: true, slack: false, pagerduty: false }
```

### Update Channels

```javascript
alertConfigService.updateEnabledChannels({
  email: true,
  slack: true,
  pagerduty: false
});
```

### Check Threshold

```javascript
const result = alertConfigService.checkThreshold('responseTime', 1200);
// Returns: { shouldAlert: true, severity: 'critical' }
```

### Get Alert History

```javascript
const history = alertConfigService.getAlertHistory({
  limit: 50,
  metric: 'responseTime',
  severity: 'critical'
});
```

### Get Active Alerts

```javascript
const activeAlerts = alertConfigService.getActiveAlerts();
```

### Reset to Defaults

```javascript
alertConfigService.resetToDefaults();
```

---

## Alert Triggering Service

### Import

```javascript
import { alertTriggeringService } from './services/alert-triggering-service.js';
```

### Start Service

```javascript
alertTriggeringService.start();
```

### Stop Service

```javascript
alertTriggeringService.stop();
```

### Record Metric

```javascript
alertTriggeringService.recordMetric('responseTime', 450);
alertTriggeringService.recordMetric('errorRate', 3.5, { endpoint: '/api/users' });
```

### Get Metric Statistics

```javascript
const stats = alertTriggeringService.getMetricStats('responseTime');
// Returns: { count: 10, average: 500, max: 1200, min: 300, latest: 450, timestamp: 1234567890 }
```

### Get All Metrics Statistics

```javascript
const allStats = alertTriggeringService.getAllMetricStats();
// Returns: { responseTime: {...}, errorRate: {...}, ... }
```

### Manual Alert Trigger

```javascript
await alertTriggeringService.manualTrigger('responseTime', 1500, 'critical');
```

### Get Service Status

```javascript
const status = alertTriggeringService.getStatus();
// Returns: { isRunning: true, evaluationInterval: 10000, metricsTracked: 3, metrics: [...] }
```

---

## REST API Endpoints

### Get Configuration

```bash
GET /api/alert-config
Authorization: Bearer <admin-token>
```

### Get Thresholds

```bash
GET /api/alert-config/thresholds
Authorization: Bearer <admin-token>
```

### Update Thresholds

```bash
PUT /api/alert-config/thresholds
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "thresholds": {
    "responseTime": { "warning": 300, "critical": 800 },
    "errorRate": { "warning": 3, "critical": 8 }
  }
}
```

### Get Channels

```bash
GET /api/alert-config/channels
Authorization: Bearer <admin-token>
```

### Update Channels

```bash
PUT /api/alert-config/channels
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "channels": {
    "email": true,
    "slack": true,
    "pagerduty": false
  }
}
```

### Get Alert History

```bash
GET /api/alert-config/history?limit=100&metric=responseTime&severity=critical
Authorization: Bearer <admin-token>
```

### Get Active Alerts

```bash
GET /api/alert-config/active
Authorization: Bearer <admin-token>
```

### Test Alert

```bash
POST /api/alert-config/test
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "metric": "responseTime",
  "value": 1500,
  "severity": "critical"
}
```

### Reset to Defaults

```bash
POST /api/alert-config/reset
Authorization: Bearer <admin-token>
```

### Get Metrics Statistics

```bash
GET /api/alert-config/metrics
Authorization: Bearer <admin-token>
```

---

## Default Alert Thresholds

| Metric | Warning | Critical |
|--------|---------|----------|
| Response Time (ms) | 500 | 1000 |
| Error Rate (%) | 5 | 10 |
| CPU Usage (%) | 70 | 90 |
| Memory Usage (%) | 75 | 90 |
| Pool Usage (%) | 80 | 95 |
| Queue Depth | 100 | 500 |
| Active Connections | 1000 | 5000 |
| Tunnel Failures (5m) | 5 | 20 |

---

## Alert Channels

### Email

- Requires: SMTP configuration
- Environment: `ALERT_EMAIL_ENABLED=true`
- Configuration: SMTP host, port, user, password

### Slack

- Requires: Webhook URL
- Environment: `ALERT_SLACK_ENABLED=true`
- Configuration: `ALERT_SLACK_WEBHOOK_URL`

### PagerDuty

- Requires: Integration key
- Environment: `ALERT_PAGERDUTY_ENABLED=true`
- Configuration: `ALERT_PAGERDUTY_INTEGRATION_KEY`

---

## Alert Cooldown

- Default: 5 minutes
- Purpose: Prevent alert storms
- Behavior: Same alert won't trigger again within cooldown period

---

## Metric Buffer

- Max size: 100 values per metric
- Oldest values removed when buffer is full
- Used for statistics calculation

---

## Alert History

- Max records: 1000
- Oldest records removed when limit exceeded
- Filterable by metric and severity

---

## Integration Example

```javascript
// Start alert service
alertTriggeringService.start();

// In request handler
const startTime = Date.now();
// ... handle request ...
const duration = Date.now() - startTime;

// Record metric
alertTriggeringService.recordMetric('responseTime', duration);

// Metrics are automatically evaluated every 10 seconds
// Alerts are triggered if thresholds are exceeded
```

---

## Testing

### Run Configuration Tests

```bash
npm test -- test/api-backend/alert-configuration.test.js
```

### Run Triggering Tests

```bash
npm test -- test/api-backend/alert-triggering.test.js
```

### Run Property Tests

```bash
npm test -- test/api-backend/metrics-consistency-properties.test.js
```

### Run All Alert Tests

```bash
npm test -- test/api-backend/alert-*.test.js
```
