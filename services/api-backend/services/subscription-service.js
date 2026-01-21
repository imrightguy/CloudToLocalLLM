/**
 * Subscription Management Service
 *
 * Handles subscription creation, updates, cancellation, and webhook processing
 * through Stripe. Manages subscription data in the database.
 */

import stripeClient from './stripe-client.js';
import logger from '../logger.js';
import { v4 as uuidv4 } from 'uuid';

class SubscriptionService {
  constructor(db) {
    this.db = db;
    this.stripe = null;
  }

  /**
   * Initialize the subscription service
   */
  initialize() {
    this.stripe = stripeClient.getClient();
  }

  /**
   * Create a new subscription for a user
   *
   * @param {Object} params - Subscription parameters
   * @param {string} params.userId - User ID
   * @param {string} params.tier - Subscription tier (free, premium, enterprise)
   * @param {string} params.paymentMethodId - Stripe payment method ID
   * @param {string} [params.priceId] - Stripe price ID for the tier
   * @param {Object} [params.metadata] - Optional metadata
   * @returns {Promise<Object>} Created subscription
   */
  async createSubscription({
    userId,
    tier,
    paymentMethodId,
    priceId,
    metadata = {},
  }) {
    if (!this.stripe) {
      this.initialize();
    }

    const subscriptionId = uuidv4();

    try {
      logger.info('Creating subscription', {
        userId,
        tier,
        subscriptionId,
      });

      // Get or create Stripe customer
      const customer = await this._getOrCreateCustomer(userId, paymentMethodId);

      // Create Stripe subscription
      const stripeSubscription = await this.stripe.subscriptions.create({
        customer: customer.id,
        items: [{ price: priceId }],
        default_payment_method: paymentMethodId,
        expand: ['latest_invoice.payment_intent'],
        metadata: {
          user_id: userId,
          subscription_id: subscriptionId,
          tier,
          ...metadata,
        },
      });

      // Store subscription in database
      const subscription = await this._storeSubscription({
        id: subscriptionId,
        userId,
        stripeSubscriptionId: stripeSubscription.id,
        stripeCustomerId: customer.id,
        tier,
        status: this._mapSubscriptionStatus(stripeSubscription.status),
        currentPeriodStart: new Date(
          stripeSubscription.current_period_start * 1000
        ),
        currentPeriodEnd: new Date(
          stripeSubscription.current_period_end * 1000
        ),
        cancelAtPeriodEnd: stripeSubscription.cancel_at_period_end,
        canceledAt: stripeSubscription.canceled_at
          ? new Date(stripeSubscription.canceled_at * 1000)
          : null,
        trialStart: stripeSubscription.trial_start
          ? new Date(stripeSubscription.trial_start * 1000)
          : null,
        trialEnd: stripeSubscription.trial_end
          ? new Date(stripeSubscription.trial_end * 1000)
          : null,
        metadata,
      });

      logger.info('Subscription created successfully', {
        subscriptionId,
        userId,
        tier,
        stripeSubscriptionId: stripeSubscription.id,
      });

      return {
        success: true,
        subscription,
        stripeSubscription: {
          id: stripeSubscription.id,
          status: stripeSubscription.status,
          current_period_end: stripeSubscription.current_period_end,
        },
      };
    } catch (error) {
      logger.error('Subscription creation failed', {
        subscriptionId,
        userId,
        tier,
        error: error.message,
      });

      const standardizedError = stripeClient.handleStripeError(error);

      return {
        success: false,
        error: standardizedError,
      };
    }
  }

  /**
   * Update an existing subscription
   *
   * @param {string} subscriptionId - Subscription ID
   * @param {Object} updates - Updates to apply
   * @param {string} [updates.tier] - New tier
   * @param {string} [updates.priceId] - New Stripe price ID
   * @param {boolean} [updates.cancelAtPeriodEnd] - Cancel at period end
   * @returns {Promise<Object>} Updated subscription
   */
  async updateSubscription(subscriptionId, updates) {
    if (!this.stripe) {
      this.initialize();
    }

    try {
      // Get existing subscription from database
      const existingSubscription = await this.getSubscription(subscriptionId);

      if (!existingSubscription) {
        throw new Error('Subscription not found');
      }

      logger.info('Updating subscription', {
        subscriptionId,
        updates,
      });

      // Prepare Stripe update parameters
      const stripeUpdates = {};

      if (updates.priceId) {
        // Get current subscription items
        const stripeSubscription = await this.stripe.subscriptions.retrieve(
          existingSubscription.stripe_subscription_id
        );

        stripeUpdates.items = [
          {
            id: stripeSubscription.items.data[0].id,
            price: updates.priceId,
          },
        ];
      }

      if (updates.cancelAtPeriodEnd !== undefined) {
        stripeUpdates.cancel_at_period_end = updates.cancelAtPeriodEnd;
      }

      // Update Stripe subscription
      const stripeSubscription = await this.stripe.subscriptions.update(
        existingSubscription.stripe_subscription_id,
        stripeUpdates
      );

      // Update database
      const updateQuery = `
        UPDATE subscriptions
        SET 
          tier = COALESCE($1, tier),
          status = $2,
          current_period_start = $3,
          current_period_end = $4,
          cancel_at_period_end = $5,
          canceled_at = $6,
          updated_at = NOW()
        WHERE id = $7
        RETURNING *
      `;

      const values = [
        updates.tier || null,
        this._mapSubscriptionStatus(stripeSubscription.status),
        new Date(stripeSubscription.current_period_start * 1000),
        new Date(stripeSubscription.current_period_end * 1000),
        stripeSubscription.cancel_at_period_end,
        stripeSubscription.canceled_at
          ? new Date(stripeSubscription.canceled_at * 1000)
          : null,
        subscriptionId,
      ];

      const result = await this.db.query(updateQuery, values);

      logger.info('Subscription updated successfully', {
        subscriptionId,
        updates,
      });

      return {
        success: true,
        subscription: result.rows[0],
      };
    } catch (error) {
      logger.error('Subscription update failed', {
        subscriptionId,
        error: error.message,
      });

      const standardizedError = stripeClient.handleStripeError(error);

      return {
        success: false,
        error: standardizedError,
      };
    }
  }

  /**
   * Cancel a subscription
   *
   * @param {string} subscriptionId - Subscription ID
   * @param {boolean} [immediate=false] - Cancel immediately or at period end
   * @returns {Promise<Object>} Cancellation result
   */
  async cancelSubscription(subscriptionId, immediate = false) {
    if (!this.stripe) {
      this.initialize();
    }

    try {
      const existingSubscription = await this.getSubscription(subscriptionId);

      if (!existingSubscription) {
        throw new Error('Subscription not found');
      }

      logger.info('Canceling subscription', {
        subscriptionId,
        immediate,
      });

      let stripeSubscription;

      if (immediate) {
        // Cancel immediately
        stripeSubscription = await this.stripe.subscriptions.cancel(
          existingSubscription.stripe_subscription_id
        );
      } else {
        // Cancel at period end
        stripeSubscription = await this.stripe.subscriptions.update(
          existingSubscription.stripe_subscription_id,
          { cancel_at_period_end: true }
        );
      }

      // Update database
      const updateQuery = `
        UPDATE subscriptions
        SET 
          status = $1,
          cancel_at_period_end = $2,
          canceled_at = $3,
          updated_at = NOW()
        WHERE id = $4
        RETURNING *
      `;

      const values = [
        this._mapSubscriptionStatus(stripeSubscription.status),
        stripeSubscription.cancel_at_period_end,
        stripeSubscription.canceled_at
          ? new Date(stripeSubscription.canceled_at * 1000)
          : new Date(),
        subscriptionId,
      ];

      const result = await this.db.query(updateQuery, values);

      logger.info('Subscription canceled successfully', {
        subscriptionId,
        immediate,
      });

      return {
        success: true,
        subscription: result.rows[0],
      };
    } catch (error) {
      logger.error('Subscription cancellation failed', {
        subscriptionId,
        error: error.message,
      });

      const standardizedError = stripeClient.handleStripeError(error);

      return {
        success: false,
        error: standardizedError,
      };
    }
  }

  /**
   * Get subscription by ID
   *
   * @param {string} subscriptionId - Subscription ID
   * @returns {Promise<Object>} Subscription details
   */
  async getSubscription(subscriptionId) {
    const result = await this.db.query(
      'SELECT * FROM subscriptions WHERE id = $1',
      [subscriptionId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return result.rows[0];
  }

  /**
   * Get subscriptions for a user
   *
   * @param {string} userId - User ID
   * @returns {Promise<Array>} List of subscriptions
   */
  async getUserSubscriptions(userId) {
    const result = await this.db.query(
      'SELECT * FROM subscriptions WHERE user_id = $1 ORDER BY created_at DESC',
      [userId]
    );

    return result.rows;
  }

  /**
   * Handle Stripe webhook events
   *
   * @param {Object} event - Stripe webhook event
   * @returns {Promise<void>}
   */
  async handleWebhook(event) {
    logger.info('Processing Stripe webhook', {
      type: event.type,
      id: event.id,
    });

    try {
      switch (event.type) {
        case 'customer.subscription.created':
          await this._handleSubscriptionCreated(event.data.object);
          break;

        case 'customer.subscription.updated':
          await this._handleSubscriptionUpdated(event.data.object);
          break;

        case 'customer.subscription.deleted':
          await this._handleSubscriptionDeleted(event.data.object);
          break;

        case 'invoice.payment_succeeded':
          await this._handleInvoicePaymentSucceeded(event.data.object);
          break;

        case 'invoice.payment_failed':
          await this._handleInvoicePaymentFailed(event.data.object);
          break;

        default:
          logger.info('Unhandled webhook event type', { type: event.type });
      }
    } catch (error) {
      logger.error('Webhook processing failed', {
        eventType: event.type,
        eventId: event.id,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get or create Stripe customer for user
   * @private
   */
  async _getOrCreateCustomer(userId, paymentMethodId) {
    // Check if user already has a customer ID
    const userResult = await this.db.query(
      'SELECT email FROM users WHERE id = $1',
      [userId]
    );

    if (userResult.rows.length === 0) {
      throw new Error('User not found');
    }

    const userEmail = userResult.rows[0].email;

    // Check if customer already exists in subscriptions table
    const existingSubscription = await this.db.query(
      'SELECT stripe_customer_id FROM subscriptions WHERE user_id = $1 AND stripe_customer_id IS NOT NULL LIMIT 1',
      [userId]
    );

    if (existingSubscription.rows.length > 0) {
      const customerId = existingSubscription.rows[0].stripe_customer_id;

      // Attach payment method to existing customer
      await this.stripe.paymentMethods.attach(paymentMethodId, {
        customer: customerId,
      });

      return { id: customerId };
    }

    // Create new customer
    const customer = await this.stripe.customers.create({
      email: userEmail,
      payment_method: paymentMethodId,
      invoice_settings: {
        default_payment_method: paymentMethodId,
      },
      metadata: {
        user_id: userId,
      },
    });

    return customer;
  }

  /**
   * Store subscription in database
   * @private
   */
  async _storeSubscription(data) {
    const query = `
      INSERT INTO subscriptions (
        id, user_id, stripe_subscription_id, stripe_customer_id, tier, status,
        current_period_start, current_period_end, cancel_at_period_end, canceled_at,
        trial_start, trial_end, metadata, created_at, updated_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW(), NOW()
      )
      RETURNING *
    `;

    const values = [
      data.id,
      data.userId,
      data.stripeSubscriptionId,
      data.stripeCustomerId,
      data.tier,
      data.status,
      data.currentPeriodStart,
      data.currentPeriodEnd,
      data.cancelAtPeriodEnd,
      data.canceledAt,
      data.trialStart,
      data.trialEnd,
      JSON.stringify(data.metadata || {}),
    ];

    const result = await this.db.query(query, values);
    return result.rows[0];
  }

  /**
   * Map Stripe subscription status to our status
   * @private
   */
  _mapSubscriptionStatus(stripeStatus) {
    const statusMap = {
      active: 'active',
      canceled: 'canceled',
      incomplete: 'incomplete',
      incomplete_expired: 'canceled',
      past_due: 'past_due',
      trialing: 'trialing',
      unpaid: 'past_due',
    };

    return statusMap[stripeStatus] || 'incomplete';
  }

  /**
   * Handle subscription created webhook
   * @private
   */
  async _handleSubscriptionCreated(subscription) {
    logger.info('Handling subscription.created webhook', {
      subscriptionId: subscription.id,
    });
    // Webhook handling logic will be implemented when needed
  }

  /**
   * Handle subscription updated webhook
   * @private
   */
  async _handleSubscriptionUpdated(subscription) {
    logger.info('Handling subscription.updated webhook', {
      subscriptionId: subscription.id,
    });

    // Find subscription in database by Stripe subscription ID
    const result = await this.db.query(
      'SELECT id FROM subscriptions WHERE stripe_subscription_id = $1',
      [subscription.id]
    );

    if (result.rows.length > 0) {
      const subscriptionId = result.rows[0].id;

      // Update subscription status
      await this.db.query(
        `UPDATE subscriptions 
         SET status = $1, 
             current_period_start = $2,
             current_period_end = $3,
             cancel_at_period_end = $4,
             canceled_at = $5,
             updated_at = NOW()
         WHERE id = $6`,
        [
          this._mapSubscriptionStatus(subscription.status),
          new Date(subscription.current_period_start * 1000),
          new Date(subscription.current_period_end * 1000),
          subscription.cancel_at_period_end,
          subscription.canceled_at
            ? new Date(subscription.canceled_at * 1000)
            : null,
          subscriptionId,
        ]
      );
    }
  }

  /**
   * Handle subscription deleted webhook
   * @private
   */
  async _handleSubscriptionDeleted(subscription) {
    logger.info('Handling subscription.deleted webhook', {
      subscriptionId: subscription.id,
    });

    // Update subscription status to canceled
    await this.db.query(
      `UPDATE subscriptions 
       SET status = 'canceled', 
           canceled_at = NOW(),
           updated_at = NOW()
       WHERE stripe_subscription_id = $1`,
      [subscription.id]
    );
  }

  /**
   * Handle invoice payment succeeded webhook
   * @private
   */
  async _handleInvoicePaymentSucceeded(invoice) {
    logger.info('Handling invoice.payment_succeeded webhook', {
      invoiceId: invoice.id,
    });
    // Additional invoice handling logic can be added here
  }

  /**
   * Handle invoice payment failed webhook
   * @private
   */
  async _handleInvoicePaymentFailed(invoice) {
    logger.info('Handling invoice.payment_failed webhook', {
      invoiceId: invoice.id,
    });
    // Additional invoice handling logic can be added here
  }
}

export default SubscriptionService;
