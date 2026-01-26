# Webhook Testing and Debugging - Quick Reference

## Overview

Webhook testing and debugging tools for testing webhook functionality, generating test payloads, and debugging webhook issues.

## Quick Start

### 1. Generate Test Payload

```bash
curl -X POST http://localhost:8080/api/webhooks/test/payload \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "tunnel.status_changed",
    "customData": { "customField": "value" }
  }'
```

### 2. Send Test Webhook

```bash
curl -X POST http://localhost:8080/api/webhooks/test/send \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "webhookUrl": "https://example.com/webhook",
    "eventType": "tunnel.status_changed",
    "secret": "webhook-secret"
  }'
```

### 3. Get Test Event History

```bash
curl -X GET "http://localhost:8080/api/webhooks/test/events?limit=10" \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

### 4. Get Specific Test Event

```bash
curl -X GET http://localhost:8080/api/webhooks/test/events/<TEST_ID> \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

### 5. Get Webhook Debug Info

```bash
curl -X GET http://localhost:8080/api/webhooks/<WEBHOOK_ID>/debug \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

### 6. Validate Payload

```bash
curl -X POST http://localhost:8080/api/webhooks/test/validate \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "payload": {
      "id": "uuid",
      "type": "tunnel.status_changed",
      "timestamp": "2024-01-01T00:00:00Z",
      "data": { "test": "data" }
    }
  }'
```

### 7. Get Supported Event Types

```bash
curl -X GET http://localhost:8080/api/webhooks/test/supported-types \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

### 8. Clear Test Event Cache

```bash
curl -X DELETE http://localhost:8080/api/webhooks/test/events \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

## Supported Event Types

- `tunnel.status_changed` - Tunnel status changes
- `tunnel.created` - Tunnel creation
- `tunnel.deleted` - Tunnel deletion
- `tunnel.metrics` - Tunnel metrics
- `proxy.status_changed` - Proxy status changes
- `proxy.metrics` - Proxy metrics
- `user.activity` - User activity

## Service Methods

### WebhookTestingService

```javascript
import { webhookTestingService } from './services/webhook-testing-service.js';

// Generate test payload
const payload = webhookTestingService.generateTestPayload('tunnel.status_changed');

// Get supported types
const types = webhookTestingService.getSupportedEventTypes();

// Simulate delivery
const result = await webhookTestingService.simulateWebhookDelivery(
  'https://example.com/webhook',
  payload,
  'secret'
);

// Generate signature
const sig = webhookTestingService.generateWebhookSignature(payload, 'secret', Date.now());

// Validate signature
const isValid = webhookTestingService.validateWebhookSignature(sig, payload, 'secret', Date.now());

// Cache test event
webhookTestingService.cacheTestEvent('test-id', result);

// Get test event
const event = webhookTestingService.getTestEvent('test-id');

// Get all test events
const events = webhookTestingService.getAllTestEvents(100);

// Clear cache
webhookTestingService.clearTestEventCache();

// Get webhook debug info
const debugInfo = await webhookTestingService.getWebhookDebugInfo('webhook-id', 'user-id');

// Get delivery details
const details = await webhookTestingService.getDeliveryDetails('delivery-id', 'user-id');

// Validate payload
const validation = webhookTestingService.validatePayloadStructure(payload);
```

## Response Examples

### Test Payload Response

```json
{
  "payload": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "type": "tunnel.status_changed",
    "timestamp": "2024-01-01T12:00:00.000Z",
    "version": "1.0",
    "data": {
      "tunnelId": "550e8400-e29b-41d4-a716-446655440001",
      "userId": "550e8400-e29b-41d4-a716-446655440002",
      "previousStatus": "connected",
      "newStatus": "disconnected",
      "reason": "user_initiated",
      "timestamp": "2024-01-01T12:00:00.000Z"
    }
  }
}
```

### Test Webhook Response

```json
{
  "testId": "550e8400-e29b-41d4-a716-446655440000",
  "success": true,
  "statusCode": 200,
  "statusText": "OK",
  "responseTime": 150,
  "headers": {
    "content-type": "application/json"
  },
  "payload": { ... },
  "responseBody": { "success": true }
}
```

### Debug Info Response

```json
{
  "webhook": {
    "id": "webhook-123",
    "url": "https://example.com/webhook",
    "events": ["tunnel.status_changed"],
    "active": true,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  },
  "recentDeliveries": [
    {
      "id": "delivery-123",
      "status": "delivered",
      "attempt_count": 1,
      "last_error": null,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ],
  "statistics": {
    "totalDeliveries": 100,
    "successful": 95,
    "failed": 5,
    "pending": 0,
    "averageDeliveryTime": 150,
    "successRate": "95.00"
  }
}
```

### Validation Response

```json
{
  "isValid": true,
  "errors": []
}
```

## Error Responses

### Missing Required Field

```json
{
  "error": "eventType is required"
}
```

### Unsupported Event Type

```json
{
  "error": "Unsupported event type. Supported types: tunnel.status_changed, tunnel.created, ...",
  "supportedTypes": ["tunnel.status_changed", "tunnel.created", ...]
}
```

### Invalid Webhook URL

```json
{
  "testId": "550e8400-e29b-41d4-a716-446655440000",
  "success": false,
  "error": "Invalid webhook URL protocol",
  "responseTime": 10
}
```

### Webhook Not Found

```json
{
  "error": "Webhook not found"
}
```

## Testing Workflow

1. **Get Supported Types**

   ```bash
   GET /api/webhooks/test/supported-types
   ```

2. **Generate Test Payload**

   ```bash
   POST /api/webhooks/test/payload
   ```

3. **Validate Payload**

   ```bash
   POST /api/webhooks/test/validate
   ```

4. **Send Test Webhook**

   ```bash
   POST /api/webhooks/test/send
   ```

5. **Check Test Event**

   ```bash
   GET /api/webhooks/test/events/<TEST_ID>
   ```

6. **Get Webhook Debug Info**

   ```bash
   GET /api/webhooks/<WEBHOOK_ID>/debug
   ```

## Common Use Cases

### Test Webhook Endpoint

```bash
# 1. Generate payload
curl -X POST http://localhost:8080/api/webhooks/test/payload \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{"eventType": "tunnel.status_changed"}'

# 2. Send to endpoint
curl -X POST http://localhost:8080/api/webhooks/test/send \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{
    "webhookUrl": "https://myapp.com/webhook",
    "eventType": "tunnel.status_changed"
  }'

# 3. Check result
curl -X GET http://localhost:8080/api/webhooks/test/events \
  -H "Authorization: Bearer <TOKEN>"
```

### Debug Webhook Issues

```bash
# Get webhook debug info
curl -X GET http://localhost:8080/api/webhooks/webhook-123/debug \
  -H "Authorization: Bearer <TOKEN>"

# Get specific delivery details
curl -X GET http://localhost:8080/api/webhooks/deliveries/delivery-123/details \
  -H "Authorization: Bearer <TOKEN>"
```

### Validate Webhook Payload

```bash
curl -X POST http://localhost:8080/api/webhooks/test/validate \
  -H "Authorization: Bearer <TOKEN>" \
  -d '{
    "payload": {
      "id": "test-id",
      "type": "tunnel.status_changed",
      "timestamp": "2024-01-01T00:00:00Z",
      "data": {}
    }
  }'
```

## Authentication

All endpoints require JWT authentication via the `Authorization` header:

```
Authorization: Bearer <JWT_TOKEN>
```

## Rate Limiting

Standard API rate limits apply to webhook testing endpoints.

## Troubleshooting

### Webhook Delivery Fails

1. Check webhook URL is accessible
2. Verify webhook secret is correct
3. Check webhook payload structure
4. Review webhook debug info for error details

### Invalid Payload

1. Ensure all required fields are present
2. Verify timestamp is ISO 8601 format
3. Check payload structure with validation endpoint

### Signature Validation Fails

1. Verify webhook secret is correct
2. Check timestamp is recent
3. Ensure payload hasn't been modified

## Performance Tips

- Cache test events for debugging (max 1000)
- Use limit parameter to reduce response size
- Clear cache periodically to free memory
- Batch test payloads when possible

## Related Documentation

- [Webhook Testing Implementation](./WEBHOOK_TESTING_IMPLEMENTATION.md)
- [Webhook Implementation Summary](./routes/WEBHOOK_IMPLEMENTATION_SUMMARY.md)
- [Webhook API Reference](./routes/WEBHOOK_API.md)
