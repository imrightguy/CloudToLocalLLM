# Proxy Status Webhooks Implementation

## Overview

Task 29 implements proxy status webhooks for the API backend, enabling real-time notifications when proxy instances change status. This implementation follows the same pattern as tunnel webhooks and provides comprehensive webhook management, delivery, and retry logic.

**Validates: Requirements 5.10, 10.1, 10.2, 10.3, 10.4**
**Feature: api-backend-enhancement, Property 13: Webhook delivery consistency**

## Implementation Summary

### 1. Database Schema (Migration 017)

Created three new tables for proxy webhook management:

#### `proxy_webhooks` Table

- Stores webhook registrations for proxy events
- Fields:
  - `id` (UUID): Unique webhook identifier
  - `user_id` (UUID): Owner of the webhook
  - `proxy_id` (UUID, nullable): Specific proxy or null for all proxies
  - `url` (TEXT): Webhook endpoint URL
  - `events` (TEXT[]): Array of subscribed events
  - `secret` (VARCHAR): HMAC secret for signature verification
  - `is_active` (BOOLEAN): Enable/disable webhook
  - `created_at`, `updated_at` (TIMESTAMPTZ): Timestamps

#### `proxy_webhook_deliveries` Table

- Tracks webhook delivery attempts and status
- Fields:
  - `id` (UUID): Unique delivery identifier
  - `webhook_id` (UUID): Reference to webhook
  - `proxy_id` (UUID): Reference to proxy instance
  - `user_id` (UUID): Owner of the webhook
  - `event_type` (VARCHAR): Type of event
  - `payload` (JSONB): Webhook payload
  - `status` (VARCHAR): pending, delivered, failed, retrying
  - `http_status_code` (INTEGER): HTTP response code
  - `error_message` (TEXT): Error details
  - `attempt_count` (INTEGER): Number of delivery attempts
  - `max_attempts` (INTEGER): Maximum retry attempts (default: 5)
  - `next_retry_at` (TIMESTAMPTZ): Next retry time
  - `delivered_at` (TIMESTAMPTZ): Successful delivery time

#### `proxy_webhook_events` Table

- Audit log for webhook events
- Fields:
  - `id` (UUID): Unique event identifier
  - `webhook_id` (UUID): Reference to webhook
  - `proxy_id` (UUID): Reference to proxy instance
  - `user_id` (UUID): Owner of the webhook
  - `event_type` (VARCHAR): Type of event
  - `event_data` (JSONB): Event details
  - `created_at` (TIMESTAMPTZ): Event timestamp

### 2. Service Layer (`proxy-webhook-service.js`)

Implements `ProxyWebhookService` class with the following methods:

#### Webhook Management

- `registerWebhook(userId, proxyId, url, events)`: Register a new webhook
- `getWebhookById(webhookId, userId)`: Retrieve webhook details
- `listWebhooks(userId, proxyId, options)`: List webhooks with pagination
- `updateWebhook(webhookId, userId, updateData)`: Update webhook configuration
- `deleteWebhook(webhookId, userId)`: Delete a webhook

#### Event Handling

- `triggerWebhookEvent(proxyId, userId, eventType, eventData)`: Trigger webhook event
- `queueWebhookDelivery(webhookId, proxyId, userId, eventType, eventData)`: Queue delivery

#### Delivery Management

- `deliverWebhook(deliveryId)`: Attempt webhook delivery
- `scheduleRetry(deliveryId, attemptCount, httpStatusCode, errorMessage)`: Schedule retry
- `getDeliveryStatus(deliveryId)`: Get delivery status
- `getDeliveryHistory(webhookId, userId, options)`: Get delivery history
- `retryFailedDeliveries()`: Retry pending/retrying deliveries

### 3. API Routes (`proxy-webhooks.js`)

Implements REST endpoints for webhook management:

#### Webhook Registration

- `POST /api/proxy/:proxyId/webhooks` - Register webhook
- `GET /api/proxy/:proxyId/webhooks` - List webhooks
- `GET /api/proxy/:proxyId/webhooks/:webhookId` - Get webhook details
- `PUT /api/proxy/:proxyId/webhooks/:webhookId` - Update webhook
- `DELETE /api/proxy/:proxyId/webhooks/:webhookId` - Delete webhook

#### Delivery Tracking

- `GET /api/proxy/:proxyId/webhooks/:webhookId/deliveries` - Get delivery history
- `GET /api/proxy/:proxyId/webhooks/:webhookId/deliveries/:deliveryId` - Get delivery status

### 4. Supported Events

The following proxy events are supported:

- `proxy.status_changed` - Proxy status changed
- `proxy.created` - Proxy instance created
- `proxy.deleted` - Proxy instance deleted
- `proxy.metrics_updated` - Proxy metrics updated

### 5. Webhook Delivery

#### Payload Structure

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

#### Headers

- `Content-Type: application/json`
- `X-Webhook-Signature: <HMAC-SHA256 signature>`
- `X-Webhook-ID: <webhook-id>`
- `X-Delivery-ID: <delivery-id>`

#### Signature Verification

Webhooks are signed using HMAC-SHA256 with the webhook secret:

```javascript
signature = HMAC-SHA256(secret, payload)
```

### 6. Retry Logic

Implements exponential backoff with the following delays:

- Attempt 1: 1 second
- Attempt 2: 5 seconds
- Attempt 3: 30 seconds
- Attempt 4: 5 minutes (300 seconds)
- Attempt 5: 1 hour (3600 seconds)

Maximum 5 retry attempts before marking as failed.

### 7. Validation

#### URL Validation

- Must be valid HTTPS or HTTP URL
- Must not be empty
- Validated using Node.js URL constructor

#### Event Validation

- Must be one of supported event types
- At least one event must be specified
- Events array must not be empty

#### Proxy Validation

- If proxyId specified, must exist and belong to user
- If proxyId is null, webhook applies to all user's proxies

## Testing

Created comprehensive test suite (`proxy-webhooks.test.js`) with 22 tests covering:

### Signature Verification (4 tests)

- Valid HMAC signature generation
- Invalid signature rejection
- Different signatures for different payloads
- Consistent signatures for same payload

### Retry Logic (3 tests)

- Exponential backoff calculation
- Max retry attempts
- Next retry time calculation

### Event Validation (4 tests)

- Supported event type validation
- Invalid event type rejection
- Non-empty event array validation
- Empty event array rejection

### URL Validation (5 tests)

- HTTPS URL validation
- HTTP URL validation
- Invalid URL rejection
- Empty URL rejection
- URLs with paths and query parameters

### Payload Structure (3 tests)

- Valid payload structure creation
- JSON serialization
- Required headers in delivery

### Delivery Status (3 tests)

- Delivery status transitions
- HTTP status code validation
- Attempt count tracking

**All 22 tests pass successfully.**

## Integration Points

### With Proxy Services

The webhook service integrates with proxy management services:

- Proxy health service triggers `proxy.status_changed` events
- Proxy metrics service triggers `proxy.metrics_updated` events
- Proxy lifecycle endpoints trigger `proxy.created` and `proxy.deleted` events

### With Database

- Uses PostgreSQL connection pool for all database operations
- Supports transactions for data consistency
- Implements cascading deletes for cleanup

### With Authentication

- All endpoints require JWT authentication
- User ownership verified for all operations
- RBAC middleware ensures proper authorization

## Security Features

1. **Webhook Secrets**: Each webhook has a unique HMAC secret
2. **Signature Verification**: All deliveries are signed with HMAC-SHA256
3. **User Isolation**: Users can only manage their own webhooks
4. **URL Validation**: Webhook URLs are validated before storage
5. **Event Filtering**: Users can subscribe to specific events
6. **Delivery Tracking**: All delivery attempts are logged

## Performance Considerations

1. **Asynchronous Delivery**: Webhook deliveries are queued and processed asynchronously
2. **Connection Pooling**: Database operations use connection pooling
3. **Pagination**: List endpoints support pagination for large result sets
4. **Indexing**: Database indexes on frequently queried columns
5. **Retry Scheduling**: Failed deliveries are retried with exponential backoff

## Error Handling

- Invalid URLs: 400 Bad Request
- Non-existent webhooks: 404 Not Found
- Non-existent proxies: 404 Not Found
- Authentication failures: 401 Unauthorized
- Service unavailable: 503 Service Unavailable
- Server errors: 500 Internal Server Error

## Future Enhancements

1. **Webhook Filtering**: Support for filtering events by proxy attributes
2. **Payload Transformation**: Support for custom payload transformations
3. **Rate Limiting**: Per-webhook rate limiting
4. **Webhook Testing**: Test endpoint for webhook debugging
5. **Event Replay**: Ability to replay failed events
6. **Webhook Analytics**: Dashboard for webhook delivery metrics

## Files Created

1. `services/api-backend/database/migrations/017_proxy_webhooks.sql` - Database schema
2. `services/api-backend/services/proxy-webhook-service.js` - Service implementation
3. `services/api-backend/routes/proxy-webhooks.js` - API routes
4. `test/api-backend/proxy-webhooks.test.js` - Test suite

## Compliance

✅ Validates Requirements 5.10, 10.1, 10.2, 10.3, 10.4
✅ Implements Property 13: Webhook delivery consistency
✅ All 22 tests passing
✅ Follows existing webhook patterns (tunnel webhooks)
✅ Comprehensive error handling
✅ Security best practices implemented
