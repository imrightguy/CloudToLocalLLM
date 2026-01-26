# Webhook Event Filtering - Quick Reference

## Files Created

1. **Service**: `services/api-backend/services/webhook-event-filter.js`
   - Core filtering logic and validation

2. **Routes**: `services/api-backend/routes/webhook-event-filters.js`
   - REST API endpoints for filter management

3. **Database**: `services/api-backend/database/migrations/webhook-event-filters.sql`
   - Database schema for storing filters

4. **Tests**: `test/api-backend/webhook-event-filters.test.js`
   - 37 comprehensive unit tests (all passing)

## Key Classes and Methods

### WebhookEventFilter Service

```javascript
// Validate filter configuration
validateFilterConfig(filterConfig) -> { isValid, errors }

// Create filter for webhook
createFilter(webhookId, userId, filterConfig) -> Promise<filter>

// Get filter for webhook
getFilter(webhookId, userId) -> Promise<filter|null>

// Update filter configuration
updateFilter(webhookId, userId, filterConfig) -> Promise<filter>

// Delete filter for webhook
deleteFilter(webhookId, userId) -> Promise<void>

// Check if event matches filter
matchesFilter(event, filterConfig) -> boolean
```

## API Endpoints

### Create/Update Filter

```
POST /api/tunnels/:tunnelId/webhooks/:webhookId/filters
Content-Type: application/json

{
  "type": "include",
  "eventPatterns": ["tunnel.*"],
  "propertyFilters": { ... }
}
```

### Get Filter

```
GET /api/tunnels/:tunnelId/webhooks/:webhookId/filters
```

### Update Filter

```
PUT /api/tunnels/:tunnelId/webhooks/:webhookId/filters
Content-Type: application/json

{ ... filter config ... }
```

### Delete Filter

```
DELETE /api/tunnels/:tunnelId/webhooks/:webhookId/filters
```

### Validate Filter

```
POST /api/tunnels/:tunnelId/webhooks/:webhookId/filters/validate
Content-Type: application/json

{ ... filter config ... }
```

### Test Filter

```
POST /api/tunnels/:tunnelId/webhooks/:webhookId/filters/test
Content-Type: application/json

{
  "event": { "type": "tunnel.status_changed", "data": { ... } },
  "filter": { ... filter config ... }
}
```

## Filter Configuration Examples

### Include Only Connected Events

```json
{
  "type": "include",
  "eventPatterns": ["tunnel.status_changed"],
  "propertyFilters": {
    "data.status": { "operator": "equals", "value": "connected" }
  }
}
```

### Exclude Error Events

```json
{
  "type": "exclude",
  "eventPatterns": ["tunnel.*"],
  "propertyFilters": {
    "data.status": { "operator": "equals", "value": "error" }
  }
}
```

### Match Multiple Statuses

```json
{
  "type": "include",
  "eventPatterns": ["tunnel.*"],
  "propertyFilters": {
    "data.status": { "operator": "in", "value": ["connected", "disconnected"] }
  }
}
```

### Regex Pattern Matching

```json
{
  "type": "include",
  "eventPatterns": ["tunnel.*"],
  "propertyFilters": {
    "data.code": { "operator": "regex", "value": "^ERR_\\d+$" }
  }
}
```

## Event Pattern Syntax

- `tunnel.status_changed` - Exact match
- `tunnel.*` - All tunnel events
- `*.status_changed` - All status_changed events
- `*` - All events

## Property Filter Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `equals` | Exact match | `{ "operator": "equals", "value": "connected" }` |
| `contains` | String contains | `{ "operator": "contains", "value": "error" }` |
| `startsWith` | String starts with | `{ "operator": "startsWith", "value": "ERR_" }` |
| `endsWith` | String ends with | `{ "operator": "endsWith", "value": "_ERROR" }` |
| `in` | Value in array | `{ "operator": "in", "value": ["a", "b", "c"] }` |
| `regex` | Regular expression | `{ "operator": "regex", "value": "^[A-Z]+$" }` |

## Test Coverage

- **37 tests** covering all filter functionality
- **100% pass rate**
- Tests include:
  - Configuration validation
  - Event pattern matching
  - Property filter matching
  - Combined filtering
  - Edge cases

## Integration

### With Tunnel Webhooks

Filters are applied when delivering webhook events:

```javascript
// In webhook delivery logic
const filter = await filterService.getFilter(webhookId, userId);
if (filter && !filterService.matchesFilter(event, filter.filter_config)) {
  // Skip delivery
  return;
}
// Deliver webhook
```

### With API Routes

Mount filter routes in main server:

```javascript
import webhookFilterRoutes from './routes/webhook-event-filters.js';
import { initializeWebhookEventFilterService } from './routes/webhook-event-filters.js';

// Initialize service
await initializeWebhookEventFilterService();

// Mount routes
app.use('/api/tunnels', webhookFilterRoutes);
```

## Database Schema

```sql
CREATE TABLE webhook_event_filters (
  id UUID PRIMARY KEY,
  webhook_id UUID NOT NULL REFERENCES tunnel_webhooks(id),
  user_id UUID NOT NULL REFERENCES users(id),
  filter_config JSONB NOT NULL DEFAULT '{}',
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Error Handling

### Validation Errors

```json
{
  "error": "Bad request",
  "code": "INVALID_FILTER",
  "message": "Invalid filter configuration",
  "details": ["Filter type must be 'include' or 'exclude'"]
}
```

### Not Found Errors

```json
{
  "error": "Not found",
  "code": "WEBHOOK_NOT_FOUND",
  "message": "Webhook not found"
}
```

### Service Errors

```json
{
  "error": "Internal server error",
  "code": "INTERNAL_ERROR",
  "message": "Failed to create filter"
}
```

## Performance Notes

- Pattern matching uses compiled regex for efficiency
- Nested property access is safe and handles missing properties
- Database queries use indexes for fast lookups
- Filter configurations are small JSON objects (typically < 1KB)

## Security Notes

- All endpoints require JWT authentication
- Users can only manage filters for their own webhooks
- Regex patterns are validated before compilation
- SQL injection prevention via parameterized queries
- Input validation on all filter configurations
