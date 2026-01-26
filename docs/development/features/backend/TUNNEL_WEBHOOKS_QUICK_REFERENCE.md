# Tunnel Status Webhooks - Quick Reference

## Overview

Tunnel status webhooks enable real-time notifications when tunnel status changes. Webhooks are delivered with retry logic and signature verification for security.

**Validates: Requirements 4.10, 10.1, 10.2, 10.3, 10.4**

## Key Features

- **Webhook Registration**: Register webhooks for tunnel events
- **Event Filtering**: Subscribe to specific event types
- **Signature Verification**: HMAC-SHA256 signatures for security
- **Retry Logic**: Exponential backoff with up to 5 retries
- **Delivery Tracking**: Monitor webhook delivery status
- **Event Audit**: Complete event history logging

## API Endpoints

### Register Webhook

```bash
POST /api/tunnels/:tunnelId/webhooks
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json

{
  "url": "https://example.com/webhook",
  "events": ["tunnel.status_changed"]
}
```

**Response:**

```json
{
  "success": true,
  "data": {
    "id": "webhook-uuid",
    "user_id": "user-uuid",
    "tunnel_id": "tunnel-uuid",
    "url": "https://example.com/webhook",
    "events": ["tunnel.status_changed"],
    "secret": "webhook-secret-for-signature",
    "is_active": true,
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### List Webhooks

```bash
GET /api/tunnels/:tunnelId/webhooks?limit=50&offset=0
Authorization: Bearer <JWT_TOKEN>
```

### Get Webhook

```bash
GET /api/tunnels/:tunnelId/webhooks/:webhookId
Authorization: Bearer <JWT_TOKEN>
```

### Update Webhook

```bash
PUT /api/tunnels/:tunnelId/webhooks/:webhookId
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json

{
  "url": "https://example.com/webhook-updated",
  "events": ["tunnel.status_changed", "tunnel.created"],
  "is_active": true
}
```

### Delete Webhook

```bash
DELETE /api/tunnels/:tunnelId/webhooks/:webhookId
Authorization: Bearer <JWT_TOKEN>
```

### Get Delivery History

```bash
GET /api/tunnels/:tunnelId/webhooks/:webhookId/deliveries?limit=50&offset=0
Authorization: Bearer <JWT_TOKEN>
```

### Get Delivery Status

```bash
GET /api/tunnels/:tunnelId/webhooks/:webhookId/deliveries/:deliveryId
Authorization: Bearer <JWT_TOKEN>
```

## Webhook Events

### Supported Events

- `tunnel.status_changed` - Tunnel status changed
- `tunnel.created` - Tunnel created
- `tunnel.deleted` - Tunnel deleted
- `tunnel.metrics_updated` - Tunnel metrics updated

### Event Payload

```json
{
  "id": "delivery-uuid",
  "event": "tunnel.status_changed",
  "timestamp": "2024-01-01T00:00:00Z",
  "data": {
    "tunnelId": "tunnel-uuid",
    "oldStatus": "created",
    "newStatus": "connecting",
    "timestamp": "2024-01-01T00:00:00Z"
  }
}
```

## Signature Verification

All webhook deliveries include an `X-Webhook-Signature` header with HMAC-SHA256 signature.

### Verification Steps

1. Get the webhook secret from registration response
2. Extract `X-Webhook-Signature` header from request
3. Compute HMAC-SHA256 of request body using secret
4. Compare computed signature with header value

### Example (Node.js)

```javascript
const crypto = require('crypto');

function verifyWebhookSignature(payload, signature, secret) {
  const computed = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(payload))
    .digest('hex');
  
  return computed === signature;
}

// In webhook handler
const signature = req.headers['x-webhook-signature'];
const isValid = verifyWebhookSignature(req.body, signature, webhookSecret);

if (!isValid) {
  return res.status(401).json({ error: 'Invalid signature' });
}
```

## Retry Logic

Webhooks use exponential backoff for retries:

- Attempt 1: Immediate
- Attempt 2: 1 second delay
- Attempt 3: 5 seconds delay
- Attempt 4: 30 seconds delay
- Attempt 5: 5 minutes delay
- Attempt 6: 1 hour delay

Maximum 5 retries. After max retries, delivery is marked as failed.

## Delivery Status

- `pending` - Waiting to be delivered
- `retrying` - Failed, scheduled for retry
- `delivered` - Successfully delivered (HTTP 2xx)
- `failed` - Failed after max retries

## Database Schema

### tunnel_webhooks

```sql
CREATE TABLE tunnel_webhooks (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  tunnel_id UUID REFERENCES tunnels(id),
  url TEXT NOT NULL,
  events TEXT[] NOT NULL,
  secret VARCHAR(255) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### tunnel_webhook_deliveries

```sql
CREATE TABLE tunnel_webhook_deliveries (
  id UUID PRIMARY KEY,
  webhook_id UUID NOT NULL REFERENCES tunnel_webhooks(id),
  tunnel_id UUID NOT NULL REFERENCES tunnels(id),
  user_id UUID NOT NULL REFERENCES users(id),
  event_type VARCHAR(50) NOT NULL,
  payload JSONB NOT NULL,
  status VARCHAR(50) NOT NULL,
  http_status_code INTEGER,
  error_message TEXT,
  attempt_count INTEGER DEFAULT 0,
  max_attempts INTEGER DEFAULT 5,
  next_retry_at TIMESTAMPTZ,
  delivered_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### tunnel_webhook_events

```sql
CREATE TABLE tunnel_webhook_events (
  id UUID PRIMARY KEY,
  webhook_id UUID NOT NULL REFERENCES tunnel_webhooks(id),
  tunnel_id UUID NOT NULL REFERENCES tunnels(id),
  user_id UUID NOT NULL REFERENCES users(id),
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## Service Integration

### TunnelWebhookService

```javascript
import { TunnelWebhookService } from './services/tunnel-webhook-service.js';

const webhookService = new TunnelWebhookService();
await webhookService.initialize();

// Register webhook
const webhook = await webhookService.registerWebhook(
  userId,
  tunnelId,
  'https://example.com/webhook',
  ['tunnel.status_changed']
);

// Trigger event
await webhookService.triggerWebhookEvent(
  tunnelId,
  userId,
  'tunnel.status_changed',
  { oldStatus: 'created', newStatus: 'connecting' }
);

// Retry failed deliveries (call periodically)
await webhookService.retryFailedDeliveries();
```

## Implementation Notes

1. **Webhook Registration**: Users can register webhooks for specific tunnels or all tunnels (tunnelId = null)
2. **Event Filtering**: Webhooks only receive events they're subscribed to
3. **Signature Verification**: Always verify signatures in webhook handlers
4. **Retry Scheduling**: Failed deliveries are automatically retried with exponential backoff
5. **Audit Logging**: All events are logged for audit purposes
6. **Performance**: Deliveries are queued asynchronously to avoid blocking requests

## Testing

Run webhook tests:

```bash
npm test -- tunnel-webhooks.test.js
```

## Monitoring

Monitor webhook delivery:

```sql
-- Check pending deliveries
SELECT * FROM tunnel_webhook_deliveries WHERE status = 'pending';

-- Check failed deliveries
SELECT * FROM tunnel_webhook_deliveries WHERE status = 'failed';

-- Check delivery success rate
SELECT 
  COUNT(*) as total,
  SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) as delivered,
  SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed
FROM tunnel_webhook_deliveries;
```

## Troubleshooting

### Webhooks not being delivered

1. Check webhook is active: `is_active = true`
2. Check webhook URL is valid and accessible
3. Check delivery status: `SELECT * FROM tunnel_webhook_deliveries WHERE webhook_id = ?`
4. Check error message in delivery record
5. Verify signature verification in webhook handler

### High retry count

1. Check webhook endpoint is responding with 2xx status
2. Check webhook endpoint is not timing out (10 second timeout)
3. Check network connectivity to webhook URL
4. Review error messages in delivery records

### Missing events

1. Check webhook is subscribed to event type
2. Check webhook is active
3. Check tunnel ID matches (if tunnel-specific webhook)
4. Check event was triggered: `SELECT * FROM tunnel_webhook_events WHERE webhook_id = ?`
