# Proxy Diagnostics and Troubleshooting - Quick Reference

## Overview

The Proxy Diagnostics service provides comprehensive diagnostics, log collection, and troubleshooting information for streaming proxy instances.

**Validates: Requirements 5.7**

## Service: ProxyDiagnosticsService

Located in: `services/proxy-diagnostics-service.js`

### Key Methods

#### Registration

- `registerProxy(proxyId, proxyMetadata)` - Register a proxy for diagnostics
- `unregisterProxy(proxyId)` - Unregister a proxy

#### Log Collection

- `addDiagnosticLog(proxyId, logEntry)` - Add a diagnostic log entry
- `getDiagnosticLogs(proxyId, options)` - Retrieve diagnostic logs with filtering

#### Error Tracking

- `recordError(proxyId, error, context)` - Record an error
- `getErrorHistory(proxyId, options)` - Retrieve error history

#### Event Tracking

- `recordEvent(proxyId, eventType, eventData)` - Record an event
- `getEventHistory(proxyId, options)` - Retrieve event history

#### Diagnostics & Troubleshooting

- `getDiagnostics(proxyId)` - Get comprehensive diagnostics
- `getTroubleshootingInfo(proxyId)` - Get troubleshooting suggestions
- `exportDiagnostics(proxyId)` - Export complete diagnostics data
- `clearDiagnostics(proxyId)` - Clear diagnostics data

## API Endpoints

### GET /proxy/diagnostics/:proxyId

Get comprehensive diagnostics for a proxy.

**Response:**

```json
{
  "proxyId": "proxy-001",
  "diagnosticStatus": "healthy|degraded|unhealthy|critical",
  "registeredAt": "2024-01-01T00:00:00Z",
  "lastDiagnosticCheck": "2024-01-01T00:05:00Z",
  "metadata": {},
  "summary": {
    "totalLogs": 50,
    "totalErrors": 5,
    "totalEvents": 20
  },
  "recentLogs": [...],
  "recentErrors": [...],
  "recentEvents": [...],
  "timestamp": "2024-01-01T00:05:00Z"
}
```

### GET /proxy/diagnostics/:proxyId/logs

Get diagnostic logs for a proxy.

**Query Parameters:**

- `level` - Filter by log level (info, warn, error)
- `since` - Filter logs since timestamp
- `limit` - Maximum number of logs (default: 100)

**Response:**

```json
{
  "proxyId": "proxy-001",
  "logs": [
    {
      "timestamp": "2024-01-01T00:00:00Z",
      "level": "info",
      "message": "Proxy started",
      "context": {}
    }
  ],
  "count": 1,
  "timestamp": "2024-01-01T00:05:00Z"
}
```

### GET /proxy/diagnostics/:proxyId/errors

Get error history for a proxy.

**Query Parameters:**

- `since` - Filter errors since timestamp
- `limit` - Maximum number of errors (default: 50)

**Response:**

```json
{
  "proxyId": "proxy-001",
  "errors": [
    {
      "timestamp": "2024-01-01T00:00:00Z",
      "message": "Connection timeout",
      "stack": "...",
      "code": "ECONNREFUSED",
      "context": {}
    }
  ],
  "count": 1,
  "timestamp": "2024-01-01T00:05:00Z"
}
```

### GET /proxy/diagnostics/:proxyId/events

Get event history for a proxy.

**Query Parameters:**

- `type` - Filter by event type
- `since` - Filter events since timestamp
- `limit` - Maximum number of events (default: 100)

**Response:**

```json
{
  "proxyId": "proxy-001",
  "events": [
    {
      "timestamp": "2024-01-01T00:00:00Z",
      "type": "started",
      "data": {}
    }
  ],
  "count": 1,
  "timestamp": "2024-01-01T00:05:00Z"
}
```

### GET /proxy/diagnostics/:proxyId/troubleshooting

Get troubleshooting information for a proxy.

**Response:**

```json
{
  "proxyId": "proxy-001",
  "suggestions": [
    {
      "issue": "Timeout errors detected",
      "suggestion": "Check network connectivity and increase timeout settings if needed",
      "severity": "warning",
      "frequency": 5
    }
  ],
  "recentErrors": [...],
  "recentEvents": [...],
  "commonIssues": [
    {
      "type": "timeout",
      "description": "Frequent timeout errors",
      "count": 5
    }
  ],
  "recommendedActions": [
    {
      "action": "Increase timeout settings",
      "steps": [...]
    }
  ],
  "timestamp": "2024-01-01T00:05:00Z"
}
```

### GET /proxy/diagnostics/:proxyId/export

Export complete diagnostics data for a proxy.

**Response:**

```json
{
  "proxyId": "proxy-001",
  "exportedAt": "2024-01-01T00:05:00Z",
  "diagnostics": {...},
  "troubleshooting": {...},
  "allLogs": [...],
  "allErrors": [...],
  "allEvents": [...]
}
```

### POST /proxy/diagnostics/:proxyId/clear

Clear diagnostics data for a proxy (admin only).

**Response:**

```json
{
  "proxyId": "proxy-001",
  "message": "Diagnostics cleared successfully",
  "timestamp": "2024-01-01T00:05:00Z"
}
```

## Configuration

Environment variables:

- `PROXY_MAX_LOGS` - Maximum logs per proxy (default: 1000)
- `PROXY_MAX_ERRORS` - Maximum errors per proxy (default: 100)
- `PROXY_MAX_EVENTS` - Maximum events per proxy (default: 500)
- `PROXY_LOG_RETENTION` - Log retention time in ms (default: 3600000 = 1 hour)

## Diagnostic Status Levels

- **healthy** - No errors detected
- **degraded** - Some errors detected (1-5)
- **unhealthy** - Multiple errors detected (6-10)
- **critical** - Many errors detected (>10)

## Common Issues Identified

The service automatically identifies:

- **Connection errors** - Network connectivity issues
- **Timeout errors** - Request timeout issues
- **Resource errors** - Memory or resource constraint issues

## Troubleshooting Suggestions

The service generates suggestions based on error patterns:

- Timeout errors → Check network connectivity
- Connection errors → Verify endpoint reachability
- Memory errors → Increase resource allocation
- Authentication errors → Verify credentials

## Integration

### In server.js

```javascript
import { ProxyDiagnosticsService } from './services/proxy-diagnostics-service.js';
import { createProxyDiagnosticsRoutes } from './routes/proxy-diagnostics.js';

// Initialize service
const diagnosticsService = new ProxyDiagnosticsService();

// Create routes
const diagnosticsRouter = createProxyDiagnosticsRoutes(diagnosticsService);
app.use('/proxy', diagnosticsRouter);

// Register proxies
diagnosticsService.registerProxy('proxy-001', { userId: 'user-123' });

// Record events
diagnosticsService.recordEvent('proxy-001', 'started', {});
diagnosticsService.addDiagnosticLog('proxy-001', {
  level: 'info',
  message: 'Proxy started successfully'
});

// Record errors
try {
  // ... proxy operation
} catch (error) {
  diagnosticsService.recordError('proxy-001', error, { operation: 'health_check' });
}
```

## Testing

Run tests:

```bash
npm test -- test/api-backend/proxy-diagnostics.test.js
```

Test coverage includes:

- Diagnostics retrieval
- Log collection and filtering
- Error tracking
- Event tracking
- Troubleshooting suggestions
- Common issue identification
- Data export
- Admin-only operations

## Files

- Service: `services/proxy-diagnostics-service.js`
- Routes: `routes/proxy-diagnostics.js`
- Tests: `test/api-backend/proxy-diagnostics.test.js`
