# Tunnel Status Webhooks - Implementation Guide

## Overview

This document describes the implementation of tunnel status webhooks for the CloudToLocalLLM API backend. Webhooks enable real-time notifications when tunnel status changes, supporting integration with external systems.

**Validates: Requirements 4.10, 10.1, 10.2, 10.3, 10.4**

## Architecture

### Components

1. **TunnelWebhookService** - Core webhook management service
2. **Webhook Routes** - REST API endpoints for webhook management
3. **Database Schema** - Tables for webhooks, deliveries, and events
4. **Retry Engine** - Exponential backoff retry logic
5. **Signature Verification** - HMAC-SHA256 signature generation and verification

### Data Flow

```
Tunnel Status Change
    ↓
triggerWebhookEvent()
    ↓
Find matching webhooks
    ↓
Log event to tunnel_webhook_events
    ↓
queueWebhookDelivery() for each webhook
    ↓
Create delivery record (status: pending)
    ↓
deliverWebhook() (async)
    ↓
Generate signature
    ↓
POST to webhook URL
    ↓
Success (2xx) → Mark as delivered
    ↓
Failure → scheduleRetry() with exponential backoff
    ↓
Max retries exceeded → Mark as failed
```

## Database Schema

### tunnel_webhooks Table

Stores webhook registrations for tunnel events.

```sql
CREATE TABLE tunnel_webhooks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  tunnel_id UUID REFERENCES tunnels(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  events TEXT[] NOT NULL DEFAULT ARRAY['tunnel.status_changed'],
  secret VARCHAR(255) NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Fields:**

- `id`: Unique webhook identifier
- `user_id`: User who registered the webhook
- `tunnel_id`: Tunnel ID (NULL for all user's tunnels)
- `url`: Webhook endpoint URL
- `events`: Array of subscribed event types
- `secret`: HMAC secret for signature verification
- `is_active`: Whether webhook is active
- `created_at`: Registration timestamp
- `updated_at`: Last update timestamp

### tunnel_webhook_deliveries Table

Tracks webhook delivery attempts and status.

```sql
CREATE TABLE tunnel_webhook_deliveries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id UUID NOT NULL REFERENCES tunnel_webhooks(id) ON DELETE CASCADE,
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  payload JSONB NOT NULL,
  status VARCHAR(50) NOT NULL DEFAULT 'pending',
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

**Fields:**

- `id`: Unique delivery identifier
- `webhook_id`: Reference to webhook
- `tunnel_id`: Tunnel that triggered event
- `user_id`: User who owns the webhook
- `event_type`: Type of event
- `payload`: Full webhook payload (JSON)
- `status`: Current delivery status (pending, retrying, delivered, failed)
- `http_status_code`: HTTP response code from webhook endpoint
- `error_message`: Error message if delivery failed
- `attempt_count`: Number of delivery attempts
- `max_attempts`: Maximum retry attempts
- `next_retry_at`: Scheduled time for next retry
- `delivered_at`: Timestamp when successfully delivered

### tunnel_webhook_events Table

Audit log of all webhook events.

```sql
CREATE TABLE tunnel_webhook_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id UUID NOT NULL REFERENCES tunnel_webhooks(id) ON DELETE CASCADE,
  tunnel_id UUID NOT NULL REFERENCES tunnels(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  event_type VARCHAR(50) NOT NULL,
  event_data JSONB NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
```

**Fields:**

- `id`: Unique event identifier
- `webhook_id`: Reference to webhook
- `tunnel_id`: Tunnel that triggered event
- `user_id`: User who owns the webhook
- `event_type`: Type of event
- `event_data`: Event data (JSON)
- `created_at`: Event timestamp

## Service Implementation

### TunnelWebhookService

Core service for webhook management.

#### Key Methods

**registerWebhook(userId, tunnelId, url, events)**

- Validates webhook URL and events
- Generates HMAC secret
- Creates webhook record
- Returns webhook with secret

**triggerWebhookEvent(tunnelId, userId, eventType, eventData)**

- Finds all matching webhooks
- Logs event to audit table
- Queues deliveries asynchronously

**queueWebhookDelivery(webhookId, tunnelId, userId, eventType, eventData)**

- Creates delivery record with status 'pending'
- Schedules immediate delivery attempt

**deliverWebhook(deliveryId)**

- Retrieves delivery and webhook details
- Generates HMAC-SHA256 signature
- POSTs to webhook URL with signature header
- Handles success/failure responses
- Schedules retry on failure

**scheduleRetry(deliveryId, attemptCount, httpStatusCode, errorMessage)**

- Updates delivery status to 'retrying'
- Calculates next retry time using exponential backoff
- Stores error details

**retryFailedDeliveries()**

- Finds pending/retrying deliveries past retry time
- Attempts delivery for each
- Called periodically (e.g., every 30 seconds)

#### Retry Logic

Exponential backoff delays:

- Attempt 1: Immediate
- Attempt 2: 1 second
- Attempt 3: 5 seconds
- Attempt 4: 30 seconds
- Attempt 5: 5 minutes
- Attempt 6: 1 hour

After 5 failed attempts, delivery is marked as failed.

## API Endpoints

### POST /api/tunnels/:tunnelId/webhooks

Register a webhook for tunnel events.

**Request:**

```json
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
    "secret": "webhook-secret",
    "is_active": true,
    "created_at": "2024-01-01T00:00:00Z"
  }
}
```

### GET /api/tunnels/:tunnelId/webhooks

List webhooks for a tunnel.

**Query Parameters:**

- `limit`: Number of results (default: 50, max: 1000)
- `offset`: Result offset (default: 0)

### GET /api/tunnels/:tunnelId/webhooks/:webhookId

Get webhook details.

### PUT /api/tunnels/:tunnelId/webhooks/:webhookId

Update webhook.

**Request:**

```json
{
  "url": "https://example.com/webhook-updated",
  "events": ["tunnel.status_changed", "tunnel.created"],
  "is_active": true
}
```

### DELETE /api/tunnels/:tunnelId/webhooks/:webhookId

Delete webhook.

### GET /api/tunnels/:tunnelId/webhooks/:webhookId/deliveries

Get delivery history.

**Query Parameters:**

- `limit`: Number of results (default: 50)
- `offset`: Result offset (default: 0)

### GET /api/tunnels/:tunnelId/webhooks/:webhookId/deliveries/:deliveryId

Get delivery status.

## Webhook Payload

### Event Payload Structure

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

### Request Headers

```
POST /webhook HTTP/1.1
Content-Type: application/json
X-Webhook-Signature: sha256=<hmac-sha256-signature>
X-Webhook-ID: <webhook-id>
X-Delivery-ID: <delivery-id>

<payload>
```

## Signature Verification

### Generation

```javascript
const crypto = require('crypto');

const signature = crypto
  .createHmac('sha256', webhookSecret)
  .update(JSON.stringify(payload))
  .digest('hex');
```

### Verification

```javascript
function verifySignature(payload, signature, secret) {
  const computed = crypto
    .createHmac('sha256', secret)
    .update(JSON.stringify(payload))
    .digest('hex');
  
  return computed === signature;
}
```

## Integration Points

### Triggering Webhook Events

When tunnel status changes, trigger webhook event:

```javascript
// In tunnel-service.js
async updateTunnelStatus(tunnelId, userId, status, ipAddress, userAgent) {
  // ... update tunnel status ...
  
  // Trigger webhook event
  if (webhookService) {
    await webhookService.triggerWebhookEvent(
      tunnelId,
      userId,
      'tunnel.status_changed',
      {
        tunnelId,
        oldStatus: oldTunnel.status,
        newStatus: status,
        timestamp: new Date().toISOString()
      }
    );
  }
}
```

### Periodic Retry Processing

Add to server startup to process retries:

```javascript
// In server.js
import { TunnelWebhookService } from './services/tunnel-webhook-service.js';

const webhookService = new TunnelWebhookService();
await webhookService.initialize();

// Retry failed deliveries every 30 seconds
setInterval(() => {
  webhookService.retryFailedDeliveries().catch(error => {
    logger.error('Failed to retry webhook deliveries', { error: error.message });
  });
}, 30000);
```

## Testing

### Unit Tests

```bash
npm test -- tunnel-webhooks.test.js
```

### Manual Testing

1. Register webhook:

```bash
curl -X POST http://localhost:8080/api/tunnels/tunnel-id/webhooks \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://webhook.site/unique-id",
    "events": ["tunnel.status_changed"]
  }'
```

1. Trigger tunnel status change to test webhook delivery

2. Check delivery status:

```bash
curl http://localhost:8080/api/tunnels/tunnel-id/webhooks/webhook-id/deliveries \
  -H "Authorization: Bearer <token>"
```

## Monitoring

### Key Metrics

- Webhook registration count
- Delivery success rate
- Average delivery time
- Failed delivery count
- Retry count

### Queries

```sql
-- Delivery success rate
SELECT 
  COUNT(*) as total,
  SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) as delivered,
  ROUND(100.0 * SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) / COUNT(*), 2) as success_rate
FROM tunnel_webhook_deliveries;

-- Failed deliveries
SELECT * FROM tunnel_webhook_deliveries WHERE status = 'failed' ORDER BY created_at DESC;

-- Pending retries
SELECT * FROM tunnel_webhook_deliveries WHERE status IN ('pending', 'retrying') AND next_retry_at <= NOW();

-- Webhook usage by user
SELECT user_id, COUNT(*) as webhook_count FROM tunnel_webhooks GROUP BY user_id;
```

## Performance Considerations

1. **Async Delivery**: Webhook deliveries are queued asynchronously to avoid blocking requests
2. **Connection Timeout**: 10-second timeout for webhook endpoint connections
3. **Batch Retries**: Retry processing handles up to 100 deliveries per cycle
4. **Index Optimization**: Indexes on frequently queried columns for fast lookups
5. **Event Audit**: Events are logged for audit but can be archived after retention period

## Security Considerations

1. **Signature Verification**: All webhooks include HMAC-SHA256 signature
2. **Secret Management**: Secrets are generated securely and stored in database
3. **URL Validation**: Webhook URLs are validated before registration
4. **Authorization**: Webhooks can only be accessed by their owner
5. **Rate Limiting**: Webhook endpoints are subject to rate limiting
6. **HTTPS Enforcement**: Webhook URLs should use HTTPS in production

## Error Handling

### Common Errors

- **Invalid URL**: Webhook URL must be valid HTTP/HTTPS URL
- **Invalid Events**: Event type must be in supported list
- **Tunnel Not Found**: Tunnel must exist and belong to user
- **Webhook Not Found**: Webhook must exist and belong to user
- **Network Error**: Webhook endpoint unreachable (retried)
- **HTTP Error**: Webhook endpoint returns non-2xx status (retried)

### Error Recovery

- Failed deliveries are automatically retried with exponential backoff
- After max retries, delivery is marked as failed
- Users can check delivery history to diagnose issues
- Webhook can be updated or deleted if endpoint is no longer valid

## Future Enhancements

1. **Webhook Filtering**: Filter events by tunnel properties
2. **Payload Transformation**: Transform payload before delivery
3. **Webhook Testing**: Test endpoint with sample payload
4. **Event Replay**: Replay failed events
5. **Webhook Analytics**: Dashboard for webhook metrics
6. **Custom Headers**: Allow custom headers in webhook requests
7. **Webhook Signing**: Support multiple signature algorithms
