# Webhook Event Filtering Implementation

## Overview

This document describes the implementation of webhook event filtering for the API backend, which allows users to filter webhook events based on event patterns and property values.

**Validates: Requirements 10.5**

- Implements webhook event filtering
- Supports filter configuration
- Validates filter rules

## Components Implemented

### 1. WebhookEventFilter Service

**File:** `services/api-backend/services/webhook-event-filter.js`

Core service for managing webhook event filters with the following capabilities:

#### Filter Configuration Validation

- Validates filter type (include/exclude)
- Validates event patterns (glob patterns like `tunnel.*`, `*`)
- Validates property filters with operators: equals, contains, startsWith, endsWith, in, regex
- Validates rate limit configuration

#### Event Matching

- Matches events against filter configurations
- Supports glob pattern matching for event types
- Supports property-based filtering with multiple operators
- Handles nested property paths (e.g., `data.tunnel.status`)
- Case-insensitive event type matching

#### Filter Persistence

- Create filter configurations for webhooks
- Retrieve filter configurations
- Update filter configurations
- Delete filter configurations

### 2. Webhook Event Filter Routes

**File:** `services/api-backend/routes/webhook-event-filters.js`

REST API endpoints for managing webhook event filters:

#### Endpoints

- `POST /api/tunnels/:tunnelId/webhooks/:webhookId/filters` - Create/update filter
- `GET /api/tunnels/:tunnelId/webhooks/:webhookId/filters` - Get filter
- `PUT /api/tunnels/:tunnelId/webhooks/:webhookId/filters` - Update filter
- `DELETE /api/tunnels/:tunnelId/webhooks/:webhookId/filters` - Delete filter
- `POST /api/tunnels/:tunnelId/webhooks/:webhookId/filters/validate` - Validate filter
- `POST /api/tunnels/:tunnelId/webhooks/:webhookId/filters/test` - Test filter against event

### 3. Database Schema

**File:** `services/api-backend/database/migrations/webhook-event-filters.sql`

Creates `webhook_event_filters` table with:

- `id` (UUID) - Primary key
- `webhook_id` (UUID) - Reference to webhook
- `user_id` (UUID) - Reference to user
- `filter_config` (JSONB) - Filter configuration
- `is_active` (Boolean) - Active status
- `created_at` (Timestamp) - Creation time
- `updated_at` (Timestamp) - Last update time

Indexes for efficient querying:

- `idx_webhook_event_filters_webhook_id`
- `idx_webhook_event_filters_user_id`
- `idx_webhook_event_filters_is_active`

### 4. Unit Tests

**File:** `test/api-backend/webhook-event-filters.test.js`

Comprehensive test suite with 37 tests covering:

#### Filter Configuration Validation (11 tests)

- Valid filter configurations
- Empty and null configurations
- Invalid filter types
- Invalid event patterns
- Invalid property filters
- Invalid rate limit configurations

#### Event Pattern Matching (8 tests)

- Exact pattern matching
- Wildcard pattern matching (`tunnel.*`)
- Global wildcard matching (`*`)
- Non-matching patterns
- Include/exclude filter types
- Multiple pattern matching

#### Property Filter Matching (11 tests)

- Equals operator
- Contains operator
- StartsWith operator
- EndsWith operator
- In operator
- Regex operator
- Multiple property filters

#### Combined Filter Matching (3 tests)

- Event pattern and property filters together
- Event pattern failures
- Property filter failures

#### Edge Cases (4 tests)

- Nested property paths
- Missing nested properties
- Numeric property values
- Boolean property values
- Case-insensitive event matching

## Filter Configuration Format

### Basic Structure

```json
{
  "type": "include",
  "eventPatterns": ["tunnel.status_changed", "tunnel.*"],
  "propertyFilters": {
    "data.status": { "operator": "in", "value": ["connected", "disconnected"] },
    "data.userId": { "operator": "startsWith", "value": "user" }
  },
  "rateLimit": {
    "maxEvents": 100,
    "windowSeconds": 60
  }
}
```

### Filter Type

- `include` - Only deliver events matching the patterns
- `exclude` - Deliver events NOT matching the patterns

### Event Patterns

Glob patterns for matching event types:

- `tunnel.status_changed` - Exact match
- `tunnel.*` - All tunnel events
- `*` - All events

### Property Filters

Operators for filtering event properties:

- `equals` - Exact value match
- `contains` - String contains
- `startsWith` - String starts with
- `endsWith` - String ends with
- `in` - Value in array
- `regex` - Regular expression match

### Rate Limit

Optional rate limiting for webhook deliveries:

- `maxEvents` - Maximum events in window
- `windowSeconds` - Time window in seconds

## Usage Examples

### Create a Filter

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/filters
{
  "type": "include",
  "eventPatterns": ["tunnel.status_changed"],
  "propertyFilters": {
    "data.status": { "operator": "in", "value": ["connected", "disconnected"] }
  }
}
```

### Test a Filter

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/filters/test
{
  "event": {
    "type": "tunnel.status_changed",
    "data": { "status": "connected" }
  },
  "filter": {
    "type": "include",
    "eventPatterns": ["tunnel.*"]
  }
}
```

### Validate a Filter

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/filters/validate
{
  "type": "include",
  "eventPatterns": ["tunnel.status_changed"]
}
```

## Test Results

All 37 unit tests pass successfully:

```
PASS ../../test/api-backend/webhook-event-filters.test.js
  Webhook Event Filters
    Filter Configuration Validation
      ✓ should accept valid filter configuration
      ✓ should accept empty filter configuration
      ✓ should accept null filter configuration
      ✓ should reject invalid filter type
      ✓ should reject non-array event patterns
      ✓ should reject empty event patterns array
      ✓ should reject invalid event pattern format
      ✓ should reject non-object property filters
      ✓ should reject invalid property filter operator
      ✓ should reject invalid regex in property filter
      ✓ should reject invalid rate limit configuration
    Event Pattern Matching
      ✓ should match exact event pattern
      ✓ should match wildcard event pattern
      ✓ should match global wildcard pattern
      ✓ should not match non-matching pattern
      ✓ should exclude matching pattern with exclude type
      ✓ should include non-matching pattern with exclude type
      ✓ should match multiple patterns
    Property Filter Matching
      ✓ should match equals operator
      ✓ should not match equals operator with different value
      ✓ should match contains operator
      ✓ should match startsWith operator
      ✓ should match endsWith operator
      ✓ should match in operator
      ✓ should not match in operator with value not in list
      ✓ should match regex operator
      ✓ should not match regex operator with non-matching pattern
      ✓ should match multiple property filters
      ✓ should not match if any property filter fails
    Combined Filter Matching
      ✓ should match event pattern and property filters
      ✓ should not match if event pattern fails
      ✓ should not match if property filter fails
    Edge Cases
      ✓ should handle nested property paths
      ✓ should handle missing nested properties
      ✓ should handle numeric property values
      ✓ should handle boolean property values
      ✓ should be case-insensitive for event pattern matching

Tests: 37 passed, 37 total
```

## Integration Points

### With Tunnel Webhook Service

The webhook event filter integrates with the existing tunnel webhook service to:

1. Filter events before delivery
2. Validate filter configurations
3. Store filter configurations per webhook

### With API Routes

The filter routes are mounted at:

```
/api/tunnels/:tunnelId/webhooks/:webhookId/filters
```

## Security Considerations

1. **Authentication**: All filter endpoints require JWT authentication
2. **Authorization**: Users can only manage filters for their own webhooks
3. **Input Validation**: All filter configurations are validated before storage
4. **Regex Safety**: Regex patterns are validated before compilation
5. **SQL Injection Prevention**: Parameterized queries used for database operations

## Performance Considerations

1. **Pattern Matching**: Glob patterns are converted to regex for efficient matching
2. **Property Access**: Nested property access uses safe path traversal
3. **Database Indexes**: Indexes on webhook_id, user_id, and is_active for fast queries
4. **Caching**: Filter configurations can be cached in memory for frequently accessed webhooks

## Future Enhancements

1. **Filter Templates**: Pre-built filter templates for common use cases
2. **Filter Composition**: Combine multiple filters with AND/OR logic
3. **Filter Analytics**: Track which filters are most commonly used
4. **Performance Metrics**: Monitor filter matching performance
5. **Filter Versioning**: Track filter configuration changes over time

## Compliance

- **Requirement 10.5**: Webhook event filtering ✓
- **Requirement 10.1**: Webhook registration ✓ (existing)
- **Requirement 10.2**: Webhook delivery with retry logic ✓ (existing)
- **Requirement 10.3**: Webhook signature verification ✓ (existing)
- **Requirement 10.4**: Webhook delivery status tracking ✓ (existing)
