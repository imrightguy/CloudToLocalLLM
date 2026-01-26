# Webhook Payload Transformation - Quick Reference

## Overview

Webhook payload transformation allows users to transform webhook payloads before delivery using various transformation types: mapping, filtering, enrichment, and custom scripts.

**Validates: Requirements 10.6**

## Key Components

### 1. WebhookPayloadTransformer Service

**File:** `services/api-backend/services/webhook-payload-transformer.js`

Core service for managing webhook payload transformations.

### 2. Routes

**File:** `services/api-backend/routes/webhook-payload-transformations.js`

REST API endpoints for managing transformations.

### 3. Database

**File:** `services/api-backend/database/migrations/webhook-payload-transformations.sql`

Stores webhook payload transformation configurations.

## Transformation Types

### 1. Map Transformation

Maps source properties to target properties with optional transforms.

```json
{
  "type": "map",
  "mappings": {
    "eventType": { "source": "type" },
    "status": { "source": "data.status", "transform": { "type": "uppercase" } }
  }
}
```

**Available Transforms:**

- `uppercase` - Convert to uppercase
- `lowercase` - Convert to lowercase
- `trim` - Trim whitespace
- `json` - Parse JSON string
- `base64` - Encode to base64
- `custom` - Custom function

### 2. Filter Transformation

Filters payloads based on conditions.

```json
{
  "type": "filter",
  "filters": [
    { "path": "data.status", "operator": "equals", "value": "connected" },
    { "path": "data.userId", "operator": "startsWith", "value": "user" }
  ]
}
```

**Available Operators:**

- `equals` - Exact match
- `notEquals` - Not equal
- `contains` - String contains
- `startsWith` - String starts with
- `endsWith` - String ends with
- `in` - Value in array
- `regex` - Regular expression match
- `exists` - Property exists

### 3. Enrich Transformation

Adds new properties to payloads.

```json
{
  "type": "enrich",
  "enrichments": {
    "timestamp": { "type": "timestamp" },
    "requestId": { "type": "uuid" },
    "environment": { "type": "static", "value": "production" }
  }
}
```

**Available Enrichment Types:**

- `static` - Static value
- `timestamp` - Current ISO timestamp
- `uuid` - Generated UUID
- `custom` - Custom function

### 4. Custom Transformation

Apply custom JavaScript function to payload.

```json
{
  "type": "custom",
  "script": "payload => ({ ...payload, transformed: true })"
}
```

## API Endpoints

### Create/Update Transformation

```
POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations
```

### Get Transformation

```
GET /api/tunnels/:tunnelId/webhooks/:webhookId/transformations
```

### Update Transformation

```
PUT /api/tunnels/:tunnelId/webhooks/:webhookId/transformations
```

### Delete Transformation

```
DELETE /api/tunnels/:tunnelId/webhooks/:webhookId/transformations
```

### Validate Transformation

```
POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations/validate
```

### Test Transformation

```
POST /api/tunnels/:tunnelId/webhooks/:webhookId/transformations/test
```

## Usage Examples

### Map Transformation

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/transformations
{
  "type": "map",
  "mappings": {
    "eventType": { "source": "type" },
    "eventData": { "source": "data" }
  }
}
```

### Filter Transformation

```bash
POST /api/tunnels/{tunnelId}/webhooks/{webhookId}/transformations
{
  "type": "filter",
  "filters": [
    { "path": "data.status", "operator": "in", "value": ["connected", "connecting"] }
  ]
}
```

### Enrich Transformation

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

### Test Transformation

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

## Features

- **Configuration Validation**: Validates all transformation configurations
- **Payload Transformation**: Applies transformations to payloads
- **Nested Property Support**: Supports nested property paths (e.g., `data.tunnel.status`)
- **Multiple Filters**: Supports multiple filters with AND logic
- **Custom Scripts**: Supports custom JavaScript functions
- **Error Handling**: Graceful error handling for invalid transformations
- **Database Persistence**: Stores transformation configurations

## Security Considerations

1. **Authentication**: All endpoints require JWT authentication
2. **Authorization**: Users can only manage transformations for their own webhooks
3. **Input Validation**: All configurations are validated before storage
4. **Regex Safety**: Regex patterns are validated before compilation
5. **SQL Injection Prevention**: Parameterized queries used for database operations

## Performance Considerations

1. **Pattern Matching**: Efficient glob pattern matching
2. **Property Access**: Safe nested property access
3. **Database Indexes**: Indexes on webhook_id, user_id, and is_active
4. **Caching**: Transformation configurations can be cached

## Test Coverage

- 49 unit tests covering all transformation types
- Tests for configuration validation
- Tests for payload transformation
- Tests for edge cases and error handling
- All tests passing

## Compliance

- **Requirement 10.6**: Webhook payload transformation ✓
- **Requirement 10.1**: Webhook registration ✓ (existing)
- **Requirement 10.2**: Webhook delivery with retry logic ✓ (existing)
- **Requirement 10.3**: Webhook signature verification ✓ (existing)
- **Requirement 10.4**: Webhook delivery status tracking ✓ (existing)
- **Requirement 10.5**: Webhook event filtering ✓ (existing)
