/**
 * Payment Processing Service
 *
 * Handles payment processing through Stripe, including creating payment intents,
 * storing transactions in the database, and handling payment success/failure.
 */

import stripeClient from './stripe-client.js';
import logger from '../logger.js';
import { v4 as uuidv4 } from 'uuid';

class PaymentService {
  constructor(db) {
    this.db = db;
    this.stripe = null;
  }

  /**
   * Initialize the payment service
   */
  initialize() {
    this.stripe = stripeClient.getClient();
  }

  /**
   * Process a payment through Stripe
   *
   * @param {Object} params - Payment parameters
   * @param {string} params.userId - User ID making the payment
   * @param {number} params.amount - Amount in dollars
   * @param {string} params.currency - Currency code (USD, EUR, GBP)
   * @param {string} params.paymentMethodId - Stripe payment method ID
   * @param {string} [params.subscriptionId] - Optional subscription ID
   * @param {Object} [params.metadata] - Optional metadata
   * @returns {Promise<Object>} Payment result with transaction details
   */
  async processPayment({
    userId,
    amount,
    currency = 'USD',
    paymentMethodId,
    subscriptionId = null,
    metadata = {},
  }) {
    if (!this.stripe) {
      this.initialize();
    }

    const transactionId = uuidv4();

    try {
      logger.info('Processing payment', {
        userId,
        amount,
        currency,
        transactionId,
      });

      // Convert amount to cents for Stripe
      const amountInCents = Math.round(amount * 100);

      // Create PaymentIntent with Stripe
      const paymentIntent = await this.stripe.paymentIntents.create({
        amount: amountInCents,
        currency: currency.toLowerCase(),
        payment_method: paymentMethodId,
        confirm: true,
        automatic_payment_methods: {
          enabled: true,
          allow_redirects: 'never',
        },
        metadata: {
          user_id: userId,
          transaction_id: transactionId,
          ...metadata,
        },
      });

      // Extract payment method details
      const paymentMethod =
        await this.stripe.paymentMethods.retrieve(paymentMethodId);
      const paymentMethodType = paymentMethod.type;
      const paymentMethodLast4 = paymentMethod.card?.last4 || null;

      // Determine transaction status
      const status = this._mapPaymentIntentStatus(paymentIntent.status);

      // Store transaction in database
      const transaction = await this._storeTransaction({
        id: transactionId,
        userId,
        subscriptionId,
        stripePaymentIntentId: paymentIntent.id,
        stripeChargeId: paymentIntent.latest_charge,
        amount,
        currency,
        status,
        paymentMethodType,
        paymentMethodLast4,
        failureCode: paymentIntent.last_payment_error?.code || null,
        failureMessage: paymentIntent.last_payment_error?.message || null,
        receiptUrl: paymentIntent.charges?.data[0]?.receipt_url || null,
        metadata,
      });

      logger.info('Payment processed successfully', {
        transactionId,
        userId,
        amount,
        status,
        paymentIntentId: paymentIntent.id,
      });

      return {
        success: status === 'succeeded',
        transaction,
        paymentIntent: {
          id: paymentIntent.id,
          status: paymentIntent.status,
          amount: paymentIntent.amount,
          currency: paymentIntent.currency,
        },
      };
    } catch (error) {
      logger.error('Payment processing failed', {
        transactionId,
        userId,
        amount,
        error: error.message,
      });

      // Store failed transaction
      await this._storeTransaction({
        id: transactionId,
        userId,
        subscriptionId,
        stripePaymentIntentId: error.payment_intent?.id || null,
        stripeChargeId: null,
        amount,
        currency,
        status: 'failed',
        paymentMethodType: null,
        paymentMethodLast4: null,
        failureCode: error.code || 'unknown',
        failureMessage: error.message,
        receiptUrl: null,
        metadata,
      });

      // Convert Stripe error to standardized format
      const standardizedError = stripeClient.handleStripeError(error);

      return {
        success: false,
        error: standardizedError,
        transaction: {
          id: transactionId,
          status: 'failed',
        },
      };
    }
  }

  /**
   * Get transaction details by ID
   *
   * @param {string} transactionId - Transaction ID
   * @returns {Promise<Object>} Transaction details
   */
  async getTransaction(transactionId) {
    const result = await this.db.query(
      'SELECT * FROM payment_transactions WHERE id = $1',
      [transactionId]
    );

    if (result.rows.length === 0) {
      throw new Error('Transaction not found');
    }

    return result.rows[0];
  }

  /**
   * Get transactions for a user
   *
   * @param {string} userId - User ID
   * @param {Object} options - Query options
   * @param {number} [options.limit=50] - Maximum number of transactions
   * @param {number} [options.offset=0] - Offset for pagination
   * @param {string} [options.status] - Filter by status
   * @returns {Promise<Array>} List of transactions
   */
  async getUserTransactions(
    userId,
    { limit = 50, offset = 0, status = null } = {}
  ) {
    let query = 'SELECT * FROM payment_transactions WHERE user_id = $1';
    const params = [userId];

    if (status) {
      query += ' AND status = $2';
      params.push(status);
    }

    query +=
      ' ORDER BY created_at DESC LIMIT $' +
      (params.length + 1) +
      ' OFFSET $' +
      (params.length + 2);
    params.push(limit, offset);

    const result = await this.db.query(query, params);
    return result.rows;
  }

  /**
   * Store transaction in database
   * @private
   */
  async _storeTransaction(data) {
    const query = `
      INSERT INTO payment_transactions (
        id, user_id, subscription_id, stripe_payment_intent_id, stripe_charge_id,
        amount, currency, status, payment_method_type, payment_method_last4,
        failure_code, failure_message, receipt_url, metadata, created_at, updated_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, NOW(), NOW()
      )
      RETURNING *
    `;

    const values = [
      data.id,
      data.userId,
      data.subscriptionId,
      data.stripePaymentIntentId,
      data.stripeChargeId,
      data.amount,
      data.currency,
      data.status,
      data.paymentMethodType,
      data.paymentMethodLast4,
      data.failureCode,
      data.failureMessage,
      data.receiptUrl,
      JSON.stringify(data.metadata || {}),
    ];

    const result = await this.db.query(query, values);
    return result.rows[0];
  }

  /**
   * Map Stripe PaymentIntent status to our transaction status
   * @private
   */
  _mapPaymentIntentStatus(stripeStatus) {
    const statusMap = {
      succeeded: 'succeeded',
      processing: 'pending',
      requires_payment_method: 'failed',
      requires_confirmation: 'pending',
      requires_action: 'pending',
      canceled: 'failed',
      requires_capture: 'pending',
    };

    return statusMap[stripeStatus] || 'pending';
  }
}

export default PaymentService;
