/**
 * Refund Processing Service
 *
 * Handles refund processing through Stripe, including creating refunds,
 * storing refund records in the database, and logging admin actions.
 */

import stripeClient from './stripe-client.js';
import logger from '../logger.js';
import { logAdminAction } from '../utils/audit-logger.js';
import { v4 as uuidv4 } from 'uuid';

class RefundService {
  constructor(db) {
    this.db = db;
    this.stripe = null;
  }

  /**
   * Initialize the refund service
   */
  initialize() {
    this.stripe = stripeClient.getClient();
  }

  /**
   * Process a refund for a transaction
   *
   * @param {Object} params - Refund parameters
   * @param {string} params.transactionId - Transaction ID to refund
   * @param {number} [params.amount] - Amount to refund (null for full refund)
   * @param {string} params.reason - Refund reason (customer_request, billing_error, service_issue, duplicate, fraudulent, other)
   * @param {string} [params.reasonDetails] - Additional details about the refund
   * @param {string} params.adminUserId - Admin user processing the refund
   * @param {string} params.adminRole - Admin role
   * @param {string} [params.ipAddress] - Admin IP address
   * @param {string} [params.userAgent] - Admin user agent
   * @returns {Promise<Object>} Refund result
   */
  async processRefund({
    transactionId,
    amount = null,
    reason,
    reasonDetails = null,
    adminUserId,
    adminRole,
    ipAddress = null,
    userAgent = null,
  }) {
    if (!this.stripe) {
      this.initialize();
    }

    const refundId = uuidv4();

    try {
      // Get transaction from database
      const transaction = await this._getTransaction(transactionId);

      if (!transaction) {
        throw new Error('Transaction not found');
      }

      if (transaction.status !== 'succeeded') {
        throw new Error('Can only refund succeeded transactions');
      }

      // Validate refund reason
      const validReasons = [
        'customer_request',
        'billing_error',
        'service_issue',
        'duplicate',
        'fraudulent',
        'other',
      ];
      if (!validReasons.includes(reason)) {
        throw new Error(
          `Invalid refund reason. Must be one of: ${validReasons.join(', ')}`
        );
      }

      logger.info('Processing refund', {
        refundId,
        transactionId,
        amount: amount || transaction.amount,
        reason,
        adminUserId,
      });

      // Determine refund amount
      const refundAmount = amount || transaction.amount;
      const refundAmountInCents = Math.round(refundAmount * 100);

      // Validate refund amount
      if (refundAmount > transaction.amount) {
        throw new Error('Refund amount cannot exceed transaction amount');
      }

      if (refundAmount <= 0) {
        throw new Error('Refund amount must be greater than zero');
      }

      // Create refund with Stripe
      const stripeRefund = await this.stripe.refunds.create({
        payment_intent: transaction.stripe_payment_intent_id,
        amount: refundAmountInCents,
        reason: this._mapRefundReasonToStripe(reason),
        metadata: {
          refund_id: refundId,
          transaction_id: transactionId,
          admin_user_id: adminUserId,
          reason: reason,
          reason_details: reasonDetails || '',
        },
      });

      // Store refund in database
      const refund = await this._storeRefund({
        id: refundId,
        transactionId,
        stripeRefundId: stripeRefund.id,
        amount: refundAmount,
        currency: transaction.currency,
        reason,
        reasonDetails,
        status: this._mapRefundStatus(stripeRefund.status),
        failureReason: stripeRefund.failure_reason || null,
        adminUserId,
      });

      // Update transaction status
      await this._updateTransactionStatus(
        transactionId,
        refundAmount,
        transaction.amount
      );

      // Log admin action in audit log
      await logAdminAction(this.db, {
        adminUserId,
        adminRole,
        action: 'refund_processed',
        resourceType: 'transaction',
        resourceId: transactionId,
        affectedUserId: transaction.user_id,
        details: {
          refund_id: refundId,
          amount: refundAmount,
          currency: transaction.currency,
          reason,
          reason_details: reasonDetails,
          stripe_refund_id: stripeRefund.id,
        },
        ipAddress,
        userAgent,
      });

      logger.info('Refund processed successfully', {
        refundId,
        transactionId,
        amount: refundAmount,
        stripeRefundId: stripeRefund.id,
      });

      return {
        success: true,
        refund,
        stripeRefund: {
          id: stripeRefund.id,
          status: stripeRefund.status,
          amount: stripeRefund.amount,
          currency: stripeRefund.currency,
        },
      };
    } catch (error) {
      logger.error('Refund processing failed', {
        refundId,
        transactionId,
        error: error.message,
      });

      // Store failed refund attempt
      if (error.type && error.type.startsWith('Stripe')) {
        await this._storeRefund({
          id: refundId,
          transactionId,
          stripeRefundId: null,
          amount: amount || 0,
          currency: 'USD',
          reason,
          reasonDetails,
          status: 'failed',
          failureReason: error.message,
          adminUserId,
        });
      }

      // Convert Stripe error to standardized format
      const standardizedError =
        error.type && error.type.startsWith('Stripe')
          ? stripeClient.handleStripeError(error)
          : {
              code: 'REFUND_ERROR',
              message: error.message,
              statusCode: 400,
            };

      return {
        success: false,
        error: standardizedError,
        refund: {
          id: refundId,
          status: 'failed',
        },
      };
    }
  }

  /**
   * Get refund by ID
   *
   * @param {string} refundId - Refund ID
   * @returns {Promise<Object>} Refund details
   */
  async getRefund(refundId) {
    const result = await this.db.query('SELECT * FROM refunds WHERE id = $1', [
      refundId,
    ]);

    if (result.rows.length === 0) {
      throw new Error('Refund not found');
    }

    return result.rows[0];
  }

  /**
   * Get refunds for a transaction
   *
   * @param {string} transactionId - Transaction ID
   * @returns {Promise<Array>} List of refunds
   */
  async getTransactionRefunds(transactionId) {
    const result = await this.db.query(
      'SELECT * FROM refunds WHERE transaction_id = $1 ORDER BY created_at DESC',
      [transactionId]
    );

    return result.rows;
  }

  /**
   * Get transaction from database
   * @private
   */
  async _getTransaction(transactionId) {
    const result = await this.db.query(
      'SELECT * FROM payment_transactions WHERE id = $1',
      [transactionId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    return result.rows[0];
  }

  /**
   * Store refund in database
   * @private
   */
  async _storeRefund(data) {
    const query = `
      INSERT INTO refunds (
        id, transaction_id, stripe_refund_id, amount, currency,
        reason, reason_details, status, failure_reason, admin_user_id,
        created_at, updated_at
      ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, NOW(), NOW()
      )
      RETURNING *
    `;

    const values = [
      data.id,
      data.transactionId,
      data.stripeRefundId,
      data.amount,
      data.currency,
      data.reason,
      data.reasonDetails,
      data.status,
      data.failureReason,
      data.adminUserId,
    ];

    const result = await this.db.query(query, values);
    return result.rows[0];
  }

  /**
   * Update transaction status after refund
   * @private
   */
  async _updateTransactionStatus(
    transactionId,
    refundAmount,
    transactionAmount
  ) {
    // Determine new status
    let newStatus;
    if (refundAmount >= transactionAmount) {
      newStatus = 'refunded';
    } else {
      newStatus = 'partially_refunded';
    }

    await this.db.query(
      'UPDATE payment_transactions SET status = $1, updated_at = NOW() WHERE id = $2',
      [newStatus, transactionId]
    );
  }

  /**
   * Map our refund reason to Stripe's reason
   * @private
   */
  _mapRefundReasonToStripe(reason) {
    const reasonMap = {
      customer_request: 'requested_by_customer',
      billing_error: 'duplicate',
      service_issue: 'requested_by_customer',
      duplicate: 'duplicate',
      fraudulent: 'fraudulent',
      other: 'requested_by_customer',
    };

    return reasonMap[reason] || 'requested_by_customer';
  }

  /**
   * Map Stripe refund status to our status
   * @private
   */
  _mapRefundStatus(stripeStatus) {
    const statusMap = {
      succeeded: 'succeeded',
      pending: 'pending',
      failed: 'failed',
      canceled: 'canceled',
    };

    return statusMap[stripeStatus] || 'pending';
  }
}

export default RefundService;
