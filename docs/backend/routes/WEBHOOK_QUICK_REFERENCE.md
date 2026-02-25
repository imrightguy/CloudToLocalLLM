# Stripe Webhook Quick Reference

## Endpoint

```
POST /api/webhooks/stripe
```

**Authentication:** Webhook signature verification (no JWT)

## Supported Events

| Event Type                      | Description                    | Database Update                                      |
| ------------------------------- | ------------------------------ | ---------------------------------------------------- |
| `payment_intent.succeeded`      | Payment completed successfully | Updates `payment_transactions` status to 'succeeded' |
| `payment_intent.failed`         | Payment failed                 | Updates `payment_transactions` status to 'failed'    |
| `customer.subscription.created` | New subscription created       | Updates `subscriptions` with Stripe data             |
| `customer.subscription.updated` | Subscription modified          | Updates `subscriptions` status and billing periods   |
| `customer.subscription.deleted` | Subscription canceled          | Updates `subscriptions` status to 'canceled'         |

## Configuration

### Environment Variables

```bash
# Required
STRIPE_WEBHOOK_SECRET=whsec_xxxxxxxxxxxxx
DATABASE_URL=postgresql://user:pass@host:5432/db

# Optional
NODE_ENV=production
LOG_LEVEL=info
```

### Stripe Dashboard Setup

1. Go to: Developers > Webhooks > Add endpoint
2. URL: `https://api.cloudtolocalllm.online/api/webhooks/stripe`
3. Events: Select all 5 events listed above
4. Copy signing secret to `STRIPE_WEBHOOK_SECRET`

## Testing

### Local Testing with Stripe CLI

```bash
# Install Stripe CLI
# https://stripe.com/docs/stripe-cli

# Login
stripe login

# Forward webhooks to local server
stripe listen --forward-to localhost:8080/api/webhooks/stripe

# Trigger test events
stripe trigger payment_intent.succeeded
stripe trigger payment_intent.failed
stripe trigger customer.subscription.created
```

### Verify Processing

```sql
-- Check processed webhooks
SELECT * FROM webhook_events ORDER BY processed_at DESC LIMIT 10;

-- Check payment updates
SELECT id, status, stripe_payment_intent_id, updated_at
FROM payment_transactions
WHERE updated_at > NOW() - INTERVAL '1 hour';

-- Check subscription updates
SELECT id, status, stripe_subscription_id, updated_at
FROM subscriptions
WHERE updated_at > NOW() - INTERVAL '1 hour';
```

## Idempotency

Webhooks are idempotent - sending the same event multiple times will only process it once.

**Implementation:**

- Event ID stored in `webhook_events` table
- Duplicate events return success without processing
- Safe to retry failed webhooks

## Error Responses

| Status Code | Meaning      | Action                                   |
| ----------- | ------------ | ---------------------------------------- |
| 200         | Success      | Event processed                          |
| 400         | Bad Request  | Invalid signature - check webhook secret |
| 500         | Server Error | Processing failed - Stripe will retry    |

## Monitoring

### Key Logs

```bash
# View webhook activity
grep "Stripe webhook" /var/log/app.log

# Check for errors
grep "ERROR.*webhook" /var/log/app.log

# View specific event
grep "eventId: evt_xxx" /var/log/app.log
```

### Metrics to Monitor

- Webhook success rate (target: >99%)
- Processing time (target: <2s)
- Duplicate event rate (should be low)
- Signature verification failures (should be 0)

## Troubleshooting

### Signature Verification Fails

```bash
# Check webhook secret
echo $STRIPE_WEBHOOK_SECRET

# Verify in Stripe dashboard
# Developers > Webhooks > [endpoint] > Signing secret

# Ensure raw body parsing
# Webhook route must be mounted BEFORE express.json()
```

### Events Not Processing

```sql
-- Check if event was received
SELECT * FROM webhook_events WHERE stripe_event_id = 'evt_xxx';

-- Check payment transaction exists
SELECT * FROM payment_transactions WHERE stripe_payment_intent_id = 'pi_xxx';

-- Check subscription exists
SELECT * FROM subscriptions WHERE stripe_subscription_id = 'sub_xxx';
```

### Database Out of Sync

```bash
# Check Stripe dashboard for webhook delivery status
# Developers > Webhooks > [endpoint] > Attempts

# Manually trigger webhook from Stripe dashboard
# Developers > Webhooks > [endpoint] > Send test webhook

# Or use Stripe CLI
stripe events resend evt_xxx
```

## Security

### Webhook Secret

- **Never** commit to version control
- Store in environment variables
- Rotate periodically (update in Stripe dashboard and env vars)
- Use different secrets for test and production

### Signature Verification

All webhooks are verified using Stripe's signature:

```javascript
stripe.webhooks.constructEvent(rawBody, signature, webhookSecret);
```

**Failed verification = rejected request**

## Deployment

### Pre-Deployment

```bash
# Run database migration
node database/migrations/run-migration.js 002_webhook_events_table.sql

# Verify migration
psql $DATABASE_URL -c "\dt webhook_events"
```

### Post-Deployment

1. Configure webhook in Stripe dashboard
2. Send test webhook
3. Verify in logs: `grep "Stripe webhook" /var/log/app.log`
4. Check database: `SELECT * FROM webhook_events LIMIT 1;`

## Support

**Webhook not working?**

1. Check Stripe dashboard delivery logs
2. Verify webhook secret matches
3. Check application logs
4. Verify database connection
5. Test with Stripe CLI

**Need help?**

- Review: [WEBHOOK_IMPLEMENTATION_SUMMARY.md](./WEBHOOK_IMPLEMENTATION_SUMMARY.md)
- Check: [Stripe Webhook Docs](https://stripe.com/docs/webhooks)
- Contact: Development team with event ID and logs
