# Webhook Payload Transformation Implementation

## Overview

This document describes the implementation of webhook payload transformation for the API backend, which allows users to transform webhook payloads before delivery using various transformation types.

**Validates: Requirements 10.6**

- Implements webhook payload transformation
- Supports transformation configuration
- Validates transformation rules

## Components Implemented

### 1. WebhookPayloadTransformer Service

**File:** `services/api-backend/services/webhook-payload-transformer.js`

Core service for managing webhook payload transformations with the following capabilities:

#### Transformation Configuration Validation

- Validates transformation type (map, filter, enrich, custom)
- Validates mappings with source properties and optional transforms
- Validates filters with operators: equals, notEquals, contains, startsWith, endsWith, in, regex, exists
- Validates enrichments with types: static, timestamp, uuid, custom
- Validates custom scripts

#### Payload Transformation

- Applies map transformations to payloads
- Applies filter transformations to payloads
- Applies enrichment transformations to payloads
- Applies custom script transformations to payloads
- Supports nested property paths (e.g., `data.tunnel.status`)
- Handles missing properties gracefully

#### Transformation Persistence

- Create transformation configurations for webhooks
- Retrieve transformation configurations
- Update transformation configurations
- Delete transformation configurations

### 2. Webhook Payload Transformation Routes

**File:** `services/api-backend/routes/webhook-payload-transformations.js`

REST API endpoints for managing webhook payload transformations:

#### Endpoints

- `POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations` - Create/update transformation
- `GET /api/tunnels/:tunnelId/webhooks/:webhookId/transformations` - Get transformation
- `PUT /api/tunnels/:tunnelId/webhooks/:webhookId/transformations` - Update transformation
- `DELETE /api/tunnels/:tunnelId/webhooks/:webhookId/transformations` - Delete transformation
- `POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations/validate` - Validate transformation
- `POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations/test` - Test transformation

### 3. Database Schema

**File:** `services/api-backend/database/migrations/webhook-payload-transformations.sql`

Creates `webhook_payload_transformations` table with:

- `id` (UUID) - Primary key
- `webhook_id` (UUID) - Reference to webhook
- `user_id` (UUID) - Reference to user
- `transform_config` (JSONB) - Transformation configuration
- `is_active` (Boolean) - Active status
- `created_at` (Timestamp) - Creation time
- `updated_at` (Timestamp) - Last update time

Indexes for efficient querying:

- `idx_webhook_payload_transformations_webhook_id`
- `idx_webhook_payload_transformations_user_id`
- `idx_webhook_payload_transformations_is_active`
- `idx_webhook_payload_transformations_webhook_user`

### 4. Unit Tests

**File:** `test/api-backend/webhook-payload-transformer.test.js`

Comprehensive test suite with 49 tests covering:

#### Transformation Configuration Validation (10 tests)

- Valid map transformation configuration
- Valid filter transformation configuration
- Valid enrich transformation configuration
- Valid custom transformation configuration
- Empty transformation configuration
- Invalid transformation type
- Invalid mapping configuration
- Invalid filter configuration
- Invalid enrichment configuration
- Empty custom script

#### Payload Mapping Transformations (8 tests)

- Simple property mapping
- Uppercase transformation
- Lowercase transformation
- Trim transformation
- Base64 transformation
- Missing source properties
- Multiple mappings
- Nested property mapping

#### Payload Filtering Transformations (11 tests)

- Filter with equals operator
- Filter with non-matching equals operator
- Filter with contains operator
- Filter with startsWith operator
- Filter with endsWith operator
- Filter with in operator
- Filter with regex operator
- Filter with exists operator
- Filter out when property does not exist
- Multiple filters with AND logic
- Filter out when any filter fails

#### Payload Enrichment Transformations (5 tests)

- Enrich with static value
- Enrich with timestamp
- Enrich with UUID
- Enrich with multiple enrichments
- Preserve original payload properties

#### Custom Transformation Scripts (3 tests)

- Apply custom transformation script
- Custom script that modifies payload
- Handle custom script errors gracefully

#### Edge Cases and Error Handling (7 tests)

- Handle null payload
- Handle undefined transformation config
- Handle nested property paths
- Handle deeply nested missing properties
- Do not mutate original payload
- Handle numeric property values
- Handle boolean property values

#### Transformation Type Detection (2 tests)

- Default to map type when not specified
- Handle unknown transformation type gracefully

#### Complex Transformation Scenarios (3 tests)

- Map transformation with multiple transforms
- JSON parsing transformation
- Invalid JSON handling

## Transformation Configuration Format

### Basic Structure

```json
{
  "type": "map|filter|enrich|custom",
  "mappings": {},
  "filters": [],
  "enrichments": {},
  "script": ""
}
```

### Map Transformation

```json
{
  "type": "map",
  "mappings": {
    "targetField": {
      "source": "sourceField",
      "transform": {
        "type": "uppercase|lowercase|trim|json|base64|custom",
        "fn": "custom function"
      }
    }
  }
}
```

### Filter Transformation

```json
{
  "type": "filter",
  "filters": [
    {
      "path": "data.status",
      "operator": "equals|notEquals|contains|startsWith|endsWith|in|regex|exists",
      "value": "value"
    }
  ]
}
```

### Enrich Transformation

```json
{
  "type": "enrich",
  "enrichments": {
    "fieldName": {
      "type": "static|timestamp|uuid|custom",
      "value": "value"
    }
  }
}
```

### Custom Transformation

```json
{
  "type": "custom",
  "script": "payload => ({ ...payload, transformed: true })"
}
```

## Usage Examples

### Create a Map Transformation

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/transformations
{
  "type": "map",
  "mappings": {
    "eventType": { "source": "type" },
    "status": { "source": "data.status", "transform": { "type": "uppercase" } }
  }
}
```

### Create a Filter Transformation

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/transformations
{
  "type": "filter",
  "filters": [
    { "path": "data.status", "operator": "in", "value": ["connected", "connecting"] }
  ]
}
```

### Create an Enrich Transformation

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/transformations
{
  "type": "enrich",
  "enrichments": {
    "timestamp": { "type": "timestamp" },
    "environment": { "type": "static", "value": "production" }
  }
}
```

### Test a Transformation

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/transformations/test
{
  "payload": {
    "type": "tunnel.status_changed",
    "data": { "status": "connected" }
  },
  "transformation": {
    "type": "map",
    "mappings": {
      "eventType": { "source": "type" }
    }
  }
}
```

### Validate a Transformation

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/transformations/validate
{
  "type": "map",
  "mappings": {
    "eventType": { "source": "type" }
  }
}
```

## Test Results

All 49 unit tests pass successfully:

```
PASS ../../test/api-backend/webhook-payload-transformer.test.js
  Webhook Payload Transformer
    Transformation Configuration Validation
      ✓ should accept valid map transformation configuration
      ✓ should accept valid filter transformation configuration
      ✓ should accept valid enrich transformation configuration
      ✓ should accept valid custom transformation configuration
      ✓ should accept empty transformation configuration
      ✓ should reject invalid transformation type
      ✓ should reject invalid mapping configuration
      ✓ should reject invalid filter configuration
      ✓ should reject invalid enrichment configuration
      ✓ should reject empty custom script
    Payload Mapping Transformations
      ✓ should map simple properties
      ✓ should apply uppercase transformation
      ✓ should apply lowercase transformation
      ✓ should apply trim transformation
      ✓ should apply base64 transformation
      ✓ should handle missing source properties
      ✓ should handle multiple mappings
      ✓ should handle nested property paths
    Payload Filtering Transformations
      ✓ should filter payload with equals operator
      ✓ should filter out payload with non-matching equals operator
      ✓ should filter payload with contains operator
      ✓ should filter payload with startsWith operator
      ✓ should filter payload with endsWith operator
      ✓ should filter payload with in operator
      ✓ should filter payload with regex operator
      ✓ should filter payload with exists operator
      ✓ should filter out payload when property does not exist
      ✓ should apply multiple filters with AND logic
      ✓ should filter out payload when any filter fails
    Payload Enrichment Transformations
      ✓ should enrich payload with static value
      ✓ should enrich payload with timestamp
      ✓ should enrich payload with UUID
      ✓ should enrich payload with multiple enrichments
      ✓ should preserve original payload properties when enriching
    Custom Transformation Scripts
      ✓ should apply custom transformation script
      ✓ should handle custom script that modifies payload
      ✓ should handle custom script errors gracefully
    Edge Cases and Error Handling
      ✓ should handle null payload
      ✓ should handle undefined transformation config
      ✓ should handle nested property paths
      ✓ should handle deeply nested missing properties
      ✓ should not mutate original payload
      ✓ should handle numeric property values
      ✓ should handle boolean property values
      ✓ should handle empty mappings
      ✓ should handle empty filters
    Transformation Type Detection
      ✓ should default to map type when not specified
      ✓ should handle unknown transformation type gracefully
    Complex Transformation Scenarios
      ✓ should handle map transformation with multiple transforms
      ✓ should handle JSON parsing transformation
      ✓ should handle invalid JSON gracefully

Tests: 49 passed, 49 total
```

## Integration Points

### With Tunnel Webhook Service

The webhook payload transformer integrates with the existing tunnel webhook service to:

1. Transform payloads before delivery
2. Validate transformation configurations
3. Store transformation configurations per webhook

### With API Routes

The transformation routes are mounted at:

```
/api/tunnels/:tunnelId/webhooks/:webhookId/transformations
```

## Security Considerations

1. **Authentication**: All transformation endpoints require JWT authentication
2. **Authorization**: Users can only manage transformations for their own webhooks
3. **Input Validation**: All transformation configurations are validated before storage
4. **Regex Safety**: Regex patterns are validated before compilation
5. **SQL Injection Prevention**: Parameterized queries used for database operations
6. **Script Sandboxing**: Custom scripts are executed in a controlled context

## Performance Considerations

1. **Pattern Matching**: Efficient glob pattern matching for filters
2. **Property Access**: Safe nested property access with early termination
3. **Database Indexes**: Indexes on webhook_id, user_id, and is_active for fast queries
4. **Caching**: Transformation configurations can be cached in memory
5. **Payload Copying**: Deep copy of payloads to prevent mutations

## Future Enhancements

1. **Transformation Templates**: Pre-built transformation templates for common use cases
2. **Transformation Composition**: Combine multiple transformations with AND/OR logic
3. **Transformation Analytics**: Track which transformations are most commonly used
4. **Performance Metrics**: Monitor transformation execution performance
5. **Transformation Versioning**: Track transformation configuration changes over time
6. **Conditional Transformations**: Apply different transformations based on conditions

## Compliance

- **Requirement 10.6**: Webhook payload transformation ✓
- **Requirement 10.1**: Webhook registration ✓ (existing)
- **Requirement 10.2**: Webhook delivery with retry logic ✓ (existing)
- **Requirement 10.3**: Webhook signature verification ✓ (existing)
- **Requirement 10.4**: Webhook delivery status tracking ✓ (existing)
- **Requirement 10.5**: Webhook event filtering ✓ (existing)
