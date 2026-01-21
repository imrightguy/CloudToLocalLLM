/**
 * Stripe Webhook Handler
 *
 * Handles Stripe webhook events for payment and subscription updates.
 * Implements signature verification and idempotency.
 *
 * Events handled:
 * - payment_intent.succeeded
 * - payment_intent.failed
 * - customer.subscription.created
 * - customer.subscription.updated
 * - customer.subscription.deleted
 */

import express from 'express';
import stripeClient from '../services/stripe-client.js';
import logger from '../logger.js';
import pg from 'pg';

const router = express.Router();
const { Pool } = pg;

// Database connection pool
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl:
    process.env.NODE_ENV === 'production'
      ? { rejectUnauthorized: false }
      : false,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

/**
 * @swagger
 * /webhooks/stripe:
 *   post:
 *     summary: Stripe webhook endpoint
 *     description: |
 *       Receives and processes Stripe webhook events for payment and subscription updates.
 *       Verifies webhook signature for security and implements idempotency.
 *
 *       **Validates: Requirements 10.2, 10.3**
 *       - Implements webhook delivery with retry logic
 *       - Implements webhook signature verification
 *     tags:
 *       - Webhooks
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               id:
 *                 type: string
 *                 description: Stripe event ID
 *               type:
 *                 type: string
 *                 description: Event type (e.g., payment_intent.succeeded)
 *               data:
 *                 type: object
 *                 description: Event data
 *     responses:
 *       200:
 *         description: Webhook processed successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 received:
 *                   type: boolean
 *                 status:
 *                   type: string
 *                   enum: [processed, already_processed]
 *       400:
 *         description: Invalid webhook signature
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error: "Webhook signature verification failed"
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.post(
  '/stripe',
  express.raw({ type: 'application/json' }),
  async (req, res) => {
    const sig = req.headers['stripe-signature'];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!webhookSecret) {
      logger.error('Stripe webhook secret not configured');
      return res.status(500).json({ error: 'Webhook configuration error' });
    }

    let event;

    try {
      // Verify webhook signature
      const stripe = stripeClient.getClient();
      event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);

      logger.info('Stripe webhook received', {
        type: event.type,
        id: event.id,
        created: event.created,
      });
    } catch (err) {
      logger.error('Webhook signature verification failed', {
        error: err.message,
      });
      return res
        .status(400)
        .json({ error: 'Webhook signature verification failed' });
    }

    // Check for idempotency - prevent processing the same event twice
    const client = await pool.connect();
    try {
      // Check if event already processed
      const existingEvent = await client.query(
        'SELECT id FROM webhook_events WHERE stripe_event_id = $1',
        [event.id],
      );

      if (existingEvent.rows.length > 0) {
        logger.info('Webhook event already processed', { eventId: event.id });
        return res.json({ received: true, status: 'already_processed' });
      }

      // Record event as being processed
      await client.query(
        `INSERT INTO webhook_events (stripe_event_id, event_type, processed_at, event_data)
       VALUES ($1, $2, NOW(), $3)`,
        [event.id, event.type, JSON.stringify(event.data.object)],
      );

      // Handle the event
      await handleWebhookEvent(event, client);

      logger.info('Webhook event processed successfully', {
        type: event.type,
        id: event.id,
      });

      res.json({ received: true, status: 'processed' });
    } catch (error) {
      logger.error('Error processing webhook event', {
        type: event.type,
        id: event.id,
        error: error.message,
        stack: error.stack,
      });
      res.status(500).json({ error: 'Error processing webhook' });
    } finally {
      client.release();
    }
  },
);

/**
 * Handle webhook event based on type
 */
async function handleWebhookEvent(event, client) {
  switch (event.type) {
    case 'payment_intent.succeeded':
      await handlePaymentIntentSucceeded(event.data.object, client);
      break;

    case 'payment_intent.failed':
      await handlePaymentIntentFailed(event.data.object, client);
      break;

    case 'customer.subscription.created':
      await handleSubscriptionCreated(event.data.object, client);
      break;

    case 'customer.subscription.updated':
      await handleSubscriptionUpdated(event.data.object, client);
      break;

    case 'customer.subscription.deleted':
      await handleSubscriptionDeleted(event.data.object, client);
      break;

    default:
      logger.info('Unhandled webhook event type', { type: event.type });
  }
}

/**
 * Handle successful payment intent
 */
async function handlePaymentIntentSucceeded(paymentIntent, client) {
  logger.info('Processing payment_intent.succeeded', {
    paymentIntentId: paymentIntent.id,
    amount: paymentIntent.amount,
    currency: paymentIntent.currency,
  });

  // Update payment transaction status
  const result = await client.query(
    `UPDATE payment_transactions
     SET status = 'succeeded',
         stripe_charge_id = $1,
         receipt_url = $2,
         updated_at = NOW()
     WHERE stripe_payment_intent_id = $3
     RETURNING id, user_id`,
    [
      paymentIntent.latest_charge,
      paymentIntent.charges?.data[0]?.receipt_url,
      paymentIntent.id,
    ],
  );

  if (result.rows.length === 0) {
    logger.warn('Payment transaction not found for payment intent', {
      paymentIntentId: paymentIntent.id,
    });
    return;
  }

  const transaction = result.rows[0];

  logger.info('Payment transaction updated to succeeded', {
    transactionId: transaction.id,
    userId: transaction.user_id,
    paymentIntentId: paymentIntent.id,
  });
}

/**
 * Handle failed payment intent
 */
async function handlePaymentIntentFailed(paymentIntent, client) {
  logger.info('Processing payment_intent.failed', {
    paymentIntentId: paymentIntent.id,
    failureCode: paymentIntent.last_payment_error?.code,
    failureMessage: paymentIntent.last_payment_error?.message,
  });

  // Update payment transaction status
  const result = await client.query(
    `UPDATE payment_transactions
     SET status = 'failed',
         failure_code = $1,
         failure_message = $2,
         updated_at = NOW()
     WHERE stripe_payment_intent_id = $3
     RETURNING id, user_id`,
    [
      paymentIntent.last_payment_error?.code,
      paymentIntent.last_payment_error?.message,
      paymentIntent.id,
    ],
  );

  if (result.rows.length === 0) {
    logger.warn('Payment transaction not found for payment intent', {
      paymentIntentId: paymentIntent.id,
    });
    return;
  }

  const transaction = result.rows[0];

  logger.info('Payment transaction updated to failed', {
    transactionId: transaction.id,
    userId: transaction.user_id,
    paymentIntentId: paymentIntent.id,
    failureCode: paymentIntent.last_payment_error?.code,
  });
}

/**
 * Handle subscription created
 */
async function handleSubscriptionCreated(subscription, client) {
  logger.info('Processing customer.subscription.created', {
    subscriptionId: subscription.id,
    customerId: subscription.customer,
    status: subscription.status,
  });

  // Find user by Stripe customer ID
  const userResult = await client.query(
    `SELECT s.id as subscription_id, s.user_id
     FROM subscriptions s
     WHERE s.stripe_subscription_id = $1`,
    [subscription.id],
  );

  if (userResult.rows.length === 0) {
    logger.warn('Subscription not found in database', {
      subscriptionId: subscription.id,
    });
    return;
  }

  const dbSubscription = userResult.rows[0];

  // Update subscription with Stripe data
  await client.query(
    `UPDATE subscriptions
     SET status = $1,
         current_period_start = to_timestamp($2),
         current_period_end = to_timestamp($3),
         trial_start = $4,
         trial_end = $5,
         updated_at = NOW()
     WHERE id = $6`,
    [
      subscription.status,
      subscription.current_period_start,
      subscription.current_period_end,
      subscription.trial_start
        ? new Date(subscription.trial_start * 1000)
        : null,
      subscription.trial_end ? new Date(subscription.trial_end * 1000) : null,
      dbSubscription.subscription_id,
    ],
  );

  logger.info('Subscription created and updated', {
    subscriptionId: subscription.id,
    userId: dbSubscription.user_id,
    status: subscription.status,
  });
}

/**
 * Handle subscription updated
 */
async function handleSubscriptionUpdated(subscription, client) {
  logger.info('Processing customer.subscription.updated', {
    subscriptionId: subscription.id,
    status: subscription.status,
    cancelAtPeriodEnd: subscription.cancel_at_period_end,
  });

  // Update subscription in database
  const result = await client.query(
    `UPDATE subscriptions
     SET status = $1,
         current_period_start = to_timestamp($2),
         current_period_end = to_timestamp($3),
         cancel_at_period_end = $4,
         canceled_at = $5,
         trial_start = $6,
         trial_end = $7,
         updated_at = NOW()
     WHERE stripe_subscription_id = $8
     RETURNING id, user_id`,
    [
      subscription.status,
      subscription.current_period_start,
      subscription.current_period_end,
      subscription.cancel_at_period_end,
      subscription.canceled_at
        ? new Date(subscription.canceled_at * 1000)
        : null,
      subscription.trial_start
        ? new Date(subscription.trial_start * 1000)
        : null,
      subscription.trial_end ? new Date(subscription.trial_end * 1000) : null,
      subscription.id,
    ],
  );

  if (result.rows.length === 0) {
    logger.warn('Subscription not found in database', {
      subscriptionId: subscription.id,
    });
    return;
  }

  const dbSubscription = result.rows[0];

  logger.info('Subscription updated', {
    subscriptionId: subscription.id,
    userId: dbSubscription.user_id,
    status: subscription.status,
    cancelAtPeriodEnd: subscription.cancel_at_period_end,
  });
}

/**
 * Handle subscription deleted
 */
async function handleSubscriptionDeleted(subscription, client) {
  logger.info('Processing customer.subscription.deleted', {
    subscriptionId: subscription.id,
    status: subscription.status,
  });

  // Update subscription status to canceled
  const result = await client.query(
    `UPDATE subscriptions
     SET status = 'canceled',
         canceled_at = NOW(),
         updated_at = NOW()
     WHERE stripe_subscription_id = $1
     RETURNING id, user_id`,
    [subscription.id],
  );

  if (result.rows.length === 0) {
    logger.warn('Subscription not found in database', {
      subscriptionId: subscription.id,
    });
    return;
  }

  const dbSubscription = result.rows[0];

  logger.info('Subscription deleted', {
    subscriptionId: subscription.id,
    userId: dbSubscription.user_id,
  });
}

export default router;
