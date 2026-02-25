# Stripe Webhook API Documentation

## Overview

The Stripe webhook endpoint receives and processes events from Stripe's payment gateway, ensuring database synchronization for payments and subscriptions.

## Endpoint

### Process Stripe Webhook

```
POST /api/webhooks/stripe
```

Receives and processes Stripe webhook events.

**Authentication:** Webhook signature verification (no JWT required)

**Headers:**

- `stripe-signature` (required) - Stripe webhook signature for verification
- `Content-Type: application/json`

**Request Body:**
Raw JSON webhook event from Stripe

**Example Request:**

```bash
curl -X POST https://api.cloudtolocalllm.online/api/webhooks/stripe \
  -H "stripe-signature: t=1234567890,v1=signature_here" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "evt_1234567890",
    "object": "event",
    "type": "payment_intent.succeeded",
    "data": {
      "object": {
        "id": "pi_1234567890",
        "amount": 2000,
        "currency": "usd",
        "status": "succeeded"
      }
    }
  }'
```

**Success Response (200 OK):**

```json
{
  "received": true,
  "status": "processed"
}
```

**Idempotent Response (200 OK):**

```json
{
  "received": true,
  "status": "already_processed"
}
```

**Error Responses:**

**400 Bad Request** - Invalid signature

```json
{
  "error": "Webhook signature verification failed"
}
```

**500 Internal Server Error** - Processing error

```json
{
  "error": "Error processing webhook"
}
```

**500 Internal Server Error** - Configuration error

```json
{
  "error": "Webhook configuration error"
}
```

## Supported Events

### Payment Events

#### payment_intent.succeeded

Triggered when a payment is successfully completed.

**Actions:**

- Updates payment transaction status to 'succeeded'
- Records Stripe charge ID
- Records receipt URL
- Logs successful payment

**Database Updates:**

- Table: `payment_transactions`
- Fields: `status`, `stripe_charge_id`, `receipt_url`, `updated_at`

**Example Event Data:**

```json
{
  "id": "pi_1234567890",
  "object": "payment_intent",
  "amount": 2000,
  "currency": "usd",
  "status": "succeeded",
  "latest_charge": "ch_1234567890",
  "charges": {
    "data": [
      {
        "receipt_url": "https://pay.stripe.com/receipts/..."
      }
    ]
  }
}
```

#### payment_intent.failed

Triggered when a payment fails.

**Actions:**

- Updates payment transaction status to 'failed'
- Records failure code
- Records failure message
- Logs payment failure

**Database Updates:**

- Table: `payment_transactions`
- Fields: `status`, `failure_code`, `failure_message`, `updated_at`

**Example Event Data:**

```json
{
  "id": "pi_1234567890",
  "object": "payment_intent",
  "amount": 2000,
  "currency": "usd",
  "status": "failed",
  "last_payment_error": {
    "code": "card_declined",
    "message": "Your card was declined."
  }
}
```

### Subscription Events

#### customer.subscription.created

Triggered when a new subscription is created.

**Actions:**

- Updates subscription with Stripe data
- Sets billing period dates
- Records trial period if applicable
- Logs subscription creation

**Database Updates:**

- Table: `subscriptions`
- Fields: `status`, `current_period_start`, `current_period_end`, `trial_start`, `trial_end`, `updated_at`

**Example Event Data:**

```json
{
  "id": "sub_1234567890",
  "object": "subscription",
  "customer": "cus_1234567890",
  "status": "active",
  "current_period_start": 1234567890,
  "current_period_end": 1237159890,
  "trial_start": null,
  "trial_end": null
}
```

#### customer.subscription.updated

Triggered when a subscription is modified.

**Actions:**

- Updates subscription status
- Updates billing periods
- Records cancellation information
- Updates trial period data
- Logs subscription changes

**Database Updates:**

- Table: `subscriptions`
- Fields: `status`, `current_period_start`, `current_period_end`, `cancel_at_period_end`, `canceled_at`, `trial_start`, `trial_end`, `updated_at`

**Example Event Data:**

```json
{
  "id": "sub_1234567890",
  "object": "subscription",
  "customer": "cus_1234567890",
  "status": "active",
  "current_period_start": 1234567890,
  "current_period_end": 1237159890,
  "cancel_at_period_end": true,
  "canceled_at": 1234567890
}
```

#### customer.subscription.deleted

Triggered when a subscription is canceled.

**Actions:**

- Updates subscription status to 'canceled'
- Records cancellation timestamp
- Logs subscription deletion

**Database Updates:**

- Table: `subscriptions`
- Fields: `status`, `canceled_at`, `updated_at`

**Example Event Data:**

```json
{
  "id": "sub_1234567890",
  "object": "subscription",
  "customer": "cus_1234567890",
  "status": "canceled"
}
```

## Security

### Signature Verification

All webhook requests are verified using Stripe's webhook signature:

1. Stripe signs each webhook with your webhook secret
2. Signature is sent in `stripe-signature` header
3. Server verifies signature using Stripe SDK
4. Invalid signatures are rejected with 400 error

**Signature Format:**

```
t=1234567890,v1=signature_here,v0=old_signature
```

**Verification Process:**

```javascript
const stripe = stripeClient.getClient();
const event = stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
```

### Configuration

**Webhook Secret:**

- Stored in `STRIPE_WEBHOOK_SECRET` environment variable
- Obtained from Stripe Dashboard > Developers > Webhooks
- Different secrets for test and production modes
- Must be kept secure and never committed to version control

## Idempotency

The webhook endpoint implements idempotency to prevent duplicate processing:

1. Each webhook event has a unique `id` (e.g., `evt_1234567890`)
2. Event ID is stored in `webhook_events` table on first processing
3. Subsequent requests with same event ID return success without processing
4. Safe for Stripe's automatic retry mechanism

**Idempotency Table:**

```sql
CREATE TABLE webhook_events (
  id UUID PRIMARY KEY,
  stripe_event_id TEXT UNIQUE NOT NULL,
  event_type TEXT NOT NULL,
  processed_at TIMESTAMPTZ NOT NULL,
  event_data JSONB,
  created_at TIMESTAMPTZ
);
```

**Idempotency Check:**

```sql
SELECT id FROM webhook_events WHERE stripe_event_id = $1
```

## Error Handling

### Signature Verification Failure

**Cause:** Invalid or missing webhook signature

**Response:** 400 Bad Request

**Action:** Check webhook secret configuration

**Stripe Behavior:** Will not retry (invalid request)

### Processing Error

**Cause:** Database error, missing records, or unexpected data

**Response:** 500 Internal Server Error

**Action:** Review logs and fix underlying issue

**Stripe Behavior:** Will retry with exponential backoff

### Configuration Error

**Cause:** Missing webhook secret or database connection

**Response:** 500 Internal Server Error

**Action:** Configure required environment variables

**Stripe Behavior:** Will retry with exponential backoff

## Stripe Retry Behavior

Stripe automatically retries failed webhooks:

- **Initial retry:** After 5 minutes
- **Subsequent retries:** Exponential backoff up to 3 days
- **Maximum attempts:** Multiple attempts over 3 days
- **Idempotency:** Safe to retry due to idempotency implementation

**Retry Schedule:**

- 5 minutes
- 30 minutes
- 2 hours
- 5 hours
- 10 hours
- 24 hours
- 48 hours
- 72 hours

## Testing

### Stripe CLI

```bash
# Forward webhooks to local server
stripe listen --forward-to localhost:8080/api/webhooks/stripe

# Trigger test events
stripe trigger payment_intent.succeeded
stripe trigger payment_intent.failed
stripe trigger customer.subscription.created
stripe trigger customer.subscription.updated
stripe trigger customer.subscription.deleted
```

### Stripe Dashboard

1. Navigate to: Developers > Webhooks > [Your Endpoint]
2. Click "Send test webhook"
3. Select event type
4. Click "Send test webhook"
5. View response and logs

### Manual Testing

```bash
# Get webhook secret from Stripe dashboard
export STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx

# Send test webhook (requires valid signature)
# Use Stripe CLI or dashboard for testing
```

## Monitoring

### Webhook Delivery

**Stripe Dashboard:**

- Developers > Webhooks > [Your Endpoint]
- View delivery attempts
- See response codes
- Retry failed webhooks

**Application Logs:**

```bash
# View webhook activity
grep "Stripe webhook" /var/log/app.log

# Check for errors
grep "ERROR.*webhook" /var/log/app.log

# View specific event
grep "evt_1234567890" /var/log/app.log
```

### Database Verification

```sql
-- Check processed webhooks
SELECT * FROM webhook_events
ORDER BY processed_at DESC
LIMIT 10;

-- Check payment updates
SELECT id, status, stripe_payment_intent_id, updated_at
FROM payment_transactions
WHERE updated_at > NOW() - INTERVAL '1 hour'
ORDER BY updated_at DESC;

-- Check subscription updates
SELECT id, status, stripe_subscription_id, updated_at
FROM subscriptions
WHERE updated_at > NOW() - INTERVAL '1 hour'
ORDER BY updated_at DESC;
```

## Troubleshooting

### Webhook Not Received

**Possible Causes:**

- Webhook endpoint not configured in Stripe
- Incorrect webhook URL
- Firewall blocking Stripe IPs
- Server not accessible from internet

**Solutions:**

1. Verify webhook endpoint in Stripe dashboard
2. Check webhook URL is correct
3. Verify server is accessible: `curl https://api.cloudtolocalllm.online/api/webhooks/stripe`
4. Check firewall rules allow Stripe IPs

### Signature Verification Fails

**Possible Causes:**

- Incorrect webhook secret
- Body parsing middleware interfering
- Webhook secret mismatch (test vs production)

**Solutions:**

1. Verify `STRIPE_WEBHOOK_SECRET` matches Stripe dashboard
2. Ensure webhook route mounted before body parsing
3. Check using correct secret for environment (test/production)

### Events Not Processing

**Possible Causes:**

- Database connection error
- Missing payment transaction or subscription
- Processing logic error

**Solutions:**

1. Check database connection
2. Verify payment/subscription exists before webhook
3. Review application logs for errors
4. Check event data format

### Duplicate Processing

**Possible Causes:**

- Idempotency table not created
- Database transaction issues
- Unique constraint not enforced

**Solutions:**

1. Run database migration: `002_webhook_events_table.sql`
2. Verify unique constraint on `stripe_event_id`
3. Check database transaction handling

## Best Practices

### Development

1. Use Stripe test mode and test webhook secret
2. Test with Stripe CLI for local development
3. Verify idempotency by sending same event twice
4. Test all supported event types
5. Test error scenarios (invalid signature, missing records)

### Production

1. Use production webhook secret
2. Monitor webhook delivery in Stripe dashboard
3. Set up alerts for failed webhooks
4. Review logs regularly
5. Keep webhook secret secure
6. Rotate webhook secret periodically

### Security

1. Never commit webhook secret to version control
2. Store secret in environment variables
3. Verify signature on every request
4. Use HTTPS for webhook endpoint
5. Implement rate limiting if needed
6. Log all webhook activity

## Related Documentation

- [Stripe Webhook Documentation](https://stripe.com/docs/webhooks)
- [Webhook Implementation Summary](./WEBHOOK_IMPLEMENTATION_SUMMARY.md)
- [Webhook Quick Reference](./WEBHOOK_QUICK_REFERENCE.md)
- [Admin API Documentation](../../docs/API/ADMIN_API.md)
- [Payment Service](../services/README.md)
- [Subscription Service](../services/README.md)

## Support

For webhook issues:

1. Check Stripe dashboard delivery logs
2. Review application logs
3. Verify database state
4. Test with Stripe CLI
5. Contact development team with:
   - Event ID
   - Timestamp
   - Error logs
   - Webhook delivery attempt details from Stripe
