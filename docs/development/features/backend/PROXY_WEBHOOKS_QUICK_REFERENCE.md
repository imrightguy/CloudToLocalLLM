# Proxy Webhooks Quick Reference

## API Endpoints

### Register Webhook

```bash
POST /api/proxy/:proxyId/webhooks
Content-Type: application/json

{
  "url": "https://example.com/webhook",
  "events": ["proxy.status_changed"]
}

Response: 201 Created
{
  "id": "webhook-uuid",
  "user_id": "user-uuid",
  "proxy_id": "proxy-uuid",
  "url": "https://example.com/webhook",
  "events": ["proxy.status_changed"],
  "secret": "webhook-secret",
  "is_active": true,
  "created_at": "2024-01-19T12:00:00Z",
  "updated_at": "2024-01-19T12:00:00Z"
}
```

### List Webhooks

```bash
GET /api/proxy/:proxyId/webhooks?limit=50&offset=0

Response: 200 OK
{
  "success": true,
  "data": [
    {
      "id": "webhook-uuid",
      "url": "https://example.com/webhook",
      "events": ["proxy.status_changed"],
      "is_active": true,
      "created_at": "2024-01-19T12:00:00Z"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0
  }
}
```

### Get Webhook Details

```bash
GET /api/proxy/:proxyId/webhooks/:webhookId

Response: 200 OK
{
  "success": true,
  "data": {
    "id": "webhook-uuid",
    "url": "https://example.com/webhook",
    "events": ["proxy.status_changed"],
    "is_active": true,
    "created_at": "2024-01-19T12:00:00Z"
  }
}
```

### Update Webhook

```bash
PUT /api/proxy/:proxyId/webhooks/:webhookId
Content-Type: application/json

{
  "url": "https://example.com/new-webhook",
  "events": ["proxy.status_changed", "proxy.created"],
  "is_active": true
}

Response: 200 OK
```

### Delete Webhook

```bash
DELETE /api/proxy/:proxyId/webhooks/:webhookId

Response: 200 OK
{
  "success": true,
  "message": "Webhook deleted successfully"
}
```

### Get Delivery History

```bash
GET /api/proxy/:proxyId/webhooks/:webhookId/deliveries?limit=50&offset=0

Response: 200 OK
{
  "success": true,
  "data": [
    {
      "id": "delivery-uuid",
      "webhook_id": "webhook-uuid",
      "event_type": "proxy.status_changed",
      "status": "delivered",
      "http_status_code": 200,
      "attempt_count": 1,
      "delivered_at": "2024-01-19T12:00:05Z",
      "created_at": "2024-01-19T12:00:00Z"
    }
  ],
  "pagination": {
    "limit": 50,
    "offset": 0
  }
}
```

### Get Delivery Status

```bash
GET /api/proxy/:proxyId/webhooks/:webhookId/deliveries/:deliveryId

Response: 200 OK
{
  "success": true,
  "data": {
    "id": "delivery-uuid",
    "status": "delivered",
    "http_status_code": 200,
    "attempt_count": 1,
    "delivered_at": "2024-01-19T12:00:05Z"
  }
}
```

## Webhook Payload

```json
{
  "id": "delivery-uuid",
  "event": "proxy.status_changed",
  "timestamp": "2024-01-19T12:00:00Z",
  "data": {
    "status": "connected",
    "timestamp": "2024-01-19T12:00:00Z"
  }
}
```

## Webhook Headers

```
Content-Type: application/json
X-Webhook-Signature: <HMAC-SHA256 signature>
X-Webhook-ID: <webhook-id>
X-Delivery-ID: <delivery-id>
```

## Signature Verification

```javascript
const crypto = require('crypto');

function verifySignature(payload, signature, secret) {
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(payload))
    .digest('hex');
  
  return signature === expectedSignature;
}
```

## Supported Events

- `proxy.status_changed` - Proxy status changed
- `proxy.created` - Proxy instance created
- `proxy.deleted` - Proxy instance deleted
- `proxy.metrics_updated` - Proxy metrics updated

## Delivery Status

- `pending` - Waiting to be delivered
- `delivered` - Successfully delivered
- `failed` - Failed after max retries
- `retrying` - Scheduled for retry

## Retry Schedule

| Attempt | Delay | Total Time |
|---------|-------|-----------|
| 1 | 1s | 1s |
| 2 | 5s | 6s |
| 3 | 30s | 36s |
| 4 | 5m | 5m 36s |
| 5 | 1h | 1h 5m 36s |

## Error Responses

### 400 Bad Request

```json
{
  "error": "Bad request",
  "code": "INVALID_REQUEST",
  "message": "Webhook URL is required"
}
```

### 401 Unauthorized

```json
{
  "error": "Authentication required",
  "code": "AUTH_REQUIRED",
  "message": "Please authenticate to register webhook"
}
```

### 404 Not Found

```json
{
  "error": "Not found",
  "code": "PROXY_NOT_FOUND",
  "message": "Proxy not found"
}
```

### 503 Service Unavailable

```json
{
  "error": "Service unavailable",
  "code": "SERVICE_UNAVAILABLE",
  "message": "Webhook service is not initialized"
}
```

## Service Integration

### Trigger Webhook Event

```javascript
const webhookService = new ProxyWebhookService();
await webhookService.initialize();

// Trigger event
await webhookService.triggerWebhookEvent(
  proxyId,
  userId,
  'proxy.status_changed',
  { status: 'connected', timestamp: new Date().toISOString() }
);
```

### Retry Failed Deliveries

```javascript
// Call periodically (e.g., every minute)
await webhookService.retryFailedDeliveries();
```

## Database Tables

### proxy_webhooks

- Webhook registrations
- Indexed by: user_id, proxy_id, is_active

### proxy_webhook_deliveries

- Delivery attempts and status
- Indexed by: webhook_id, status, next_retry_at

### proxy_webhook_events

- Event audit log
- Indexed by: webhook_id, event_type, created_at

## Requirements Validation

✅ **Requirement 5.10**: Proxy status webhooks for real-time updates
✅ **Requirement 10.1**: Webhook registration for events
✅ **Requirement 10.2**: Webhook delivery with retry logic
✅ **Requirement 10.3**: Webhook signature verification
✅ **Requirement 10.4**: Webhook delivery status tracking

## Property Validation

✅ **Property 13: Webhook delivery consistency**

- For any webhook, delivery should be attempted with retry logic
- For any webhook, signature should be verified on receipt
- For any webhook, delivery status should be tracked
