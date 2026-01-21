/**
 * Admin Payment Management API Routes
 *
 * Provides secure administrative endpoints for payment management:
 * - List payment transactions with pagination and filtering
 * - View detailed transaction information
 * - Process refunds
 * - View user payment methods
 *
 * Security Features:
 * - Admin authentication required
 * - Role-based permission checking
 * - Comprehensive audit logging
 * - Input validation and sanitization
 */

import express from 'express';
import { adminAuth } from '../../middleware/admin-auth.js';
import logger from '../../logger.js';
import { getPool, closePool } from '../../database/db-pool.js';
import RefundService from '../../services/refund-service.js';
import {
  adminReadOnlyLimiter,
  adminRateLimiter,
} from '../../middleware/admin-rate-limiter.js';

const router = express.Router();

/**
 * GET /api/admin/payments/transactions
 * List all payment transactions with pagination and filtering
 *
 * Query Parameters:
 * - page: Page number (default: 1)
 * - limit: Items per page (default: 100, max: 200)
 * - userId: Filter by user ID
 * - status: Filter by transaction status (pending, succeeded, failed, refunded, partially_refunded, disputed)
 * - startDate: Filter by date range (start)
 * - endDate: Filter by date range (end)
 * - minAmount: Filter by minimum amount
 * - maxAmount: Filter by maximum amount
 * - sortBy: Sort field (created_at, amount, status)
 * - sortOrder: Sort order (asc, desc)
 */
router.get(
  '/transactions',
  adminReadOnlyLimiter,
  adminAuth(['view_payments']),
  async (req, res) => {
    try {
      const pool = getPool();

      // Parse and validate query parameters
      const page = Math.max(1, parseInt(req.query.page) || 1);
      const limit = Math.min(
        200,
        Math.max(1, parseInt(req.query.limit) || 100),
      );
      const offset = (page - 1) * limit;
      const userId = req.query.userId?.trim();
      const status = req.query.status?.toLowerCase();
      const startDate = req.query.startDate;
      const endDate = req.query.endDate;
      const minAmount = req.query.minAmount
        ? parseFloat(req.query.minAmount)
        : null;
      const maxAmount = req.query.maxAmount
        ? parseFloat(req.query.maxAmount)
        : null;
      const sortBy = req.query.sortBy || 'created_at';
      const sortOrder =
        req.query.sortOrder?.toLowerCase() === 'asc' ? 'ASC' : 'DESC';

      // Validate sort field
      const validSortFields = ['created_at', 'amount', 'status'];
      const sortField = validSortFields.includes(sortBy)
        ? sortBy
        : 'created_at';

      // Validate status
      const validStatuses = [
        'pending',
        'succeeded',
        'failed',
        'refunded',
        'partially_refunded',
        'disputed',
      ];
      if (status && !validStatuses.includes(status)) {
        return res.status(400).json({
          error: 'Invalid status',
          code: 'INVALID_STATUS',
          validStatuses,
        });
      }

      // Build query conditions
      const conditions = [];
      const params = [];
      let paramIndex = 1;

      // User ID filter
      if (userId) {
        // Validate UUID format
        const uuidRegex =
          /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        if (!uuidRegex.test(userId)) {
          return res.status(400).json({
            error: 'Invalid user ID format',
            code: 'INVALID_USER_ID',
          });
        }
        conditions.push(`pt.user_id = $${paramIndex}`);
        params.push(userId);
        paramIndex++;
      }

      // Status filter
      if (status) {
        conditions.push(`pt.status = $${paramIndex}`);
        params.push(status);
        paramIndex++;
      }

      // Date range filter
      if (startDate) {
        conditions.push(`pt.created_at >= $${paramIndex}`);
        params.push(startDate);
        paramIndex++;
      }

      if (endDate) {
        conditions.push(`pt.created_at <= $${paramIndex}`);
        params.push(endDate);
        paramIndex++;
      }

      // Amount range filter
      if (minAmount !== null) {
        conditions.push(`pt.amount >= $${paramIndex}`);
        params.push(minAmount);
        paramIndex++;
      }

      if (maxAmount !== null) {
        conditions.push(`pt.amount <= $${paramIndex}`);
        params.push(maxAmount);
        paramIndex++;
      }

      const whereClause =
        conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      // Get total count
      const countQuery = `
      SELECT COUNT(*) as total
      FROM payment_transactions pt
      ${whereClause}
    `;

      const countResult = await pool.query(countQuery, params);
      const totalTransactions = parseInt(countResult.rows[0].total);
      const totalPages = Math.ceil(totalTransactions / limit);

      // Get transactions with pagination
      const transactionsQuery = `
      SELECT 
        pt.id,
        pt.user_id,
        pt.subscription_id,
        pt.stripe_payment_intent_id,
        pt.stripe_charge_id,
        pt.amount,
        pt.currency,
        pt.status,
        pt.payment_method_type,
        pt.payment_method_last4,
        pt.failure_code,
        pt.failure_message,
        pt.receipt_url,
        pt.created_at,
        pt.updated_at,
        u.email as user_email,
        u.username as user_username,
        (SELECT COUNT(*) FROM refunds WHERE transaction_id = pt.id) as refund_count,
        (SELECT SUM(amount) FROM refunds WHERE transaction_id = pt.id AND status = 'succeeded') as total_refunded
      FROM payment_transactions pt
      LEFT JOIN users u ON pt.user_id = u.id
      ${whereClause}
      ORDER BY pt.${sortField} ${sortOrder}
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;

      params.push(limit, offset);

      const transactionsResult = await pool.query(transactionsQuery, params);

      // Calculate summary statistics
      const statsQuery = `
      SELECT 
        COUNT(*) as total_count,
        SUM(CASE WHEN status = 'succeeded' THEN amount ELSE 0 END) as total_revenue,
        SUM(CASE WHEN status = 'succeeded' THEN 1 ELSE 0 END) as successful_count,
        SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count,
        SUM(CASE WHEN status IN ('refunded', 'partially_refunded') THEN 1 ELSE 0 END) as refunded_count
      FROM payment_transactions pt
      ${whereClause}
    `;

      const statsResult = await pool.query(
        statsQuery,
        params.slice(0, paramIndex - 2),
      );
      const statistics = statsResult.rows[0];

      logger.info('✅ [AdminPayments] Transactions list retrieved', {
        adminUserId: req.adminUser.id,
        page,
        limit,
        totalTransactions,
        filters: { userId, status, startDate, endDate, minAmount, maxAmount },
      });

      res.json({
        success: true,
        data: {
          transactions: transactionsResult.rows,
          pagination: {
            page,
            limit,
            totalTransactions,
            totalPages,
            hasNextPage: page < totalPages,
            hasPreviousPage: page > 1,
          },
          filters: {
            userId,
            status,
            startDate,
            endDate,
            minAmount,
            maxAmount,
            sortBy: sortField,
            sortOrder,
          },
          statistics: {
            totalCount: parseInt(statistics.total_count),
            totalRevenue: parseFloat(statistics.total_revenue || 0),
            successfulCount: parseInt(statistics.successful_count),
            failedCount: parseInt(statistics.failed_count),
            refundedCount: parseInt(statistics.refunded_count),
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminPayments] Failed to retrieve transactions list', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve transactions list',
        code: 'TRANSACTIONS_LIST_FAILED',
        details: error.message,
      });
    }
  },
);

export default router;

/**
 * Close database connection pool
 * Should be called on application shutdown
 */
export async function closePaymentDbPool() {
  await closePool();
}

/**
 * GET /api/admin/payments/transactions/:transactionId
 * Get detailed transaction information
 *
 * Returns:
 * - Transaction details
 * - User information
 * - Payment method details
 * - Refund information (if applicable)
 * - Related subscription information
 */
router.get(
  '/transactions/:transactionId',
  adminReadOnlyLimiter,
  adminAuth(['view_payments']),
  async (req, res) => {
    try {
      const pool = getPool();
      const { transactionId } = req.params;

      // Validate transactionId format (UUID)
      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(transactionId)) {
        return res.status(400).json({
          error: 'Invalid transaction ID format',
          code: 'INVALID_TRANSACTION_ID',
        });
      }

      // Get transaction details
      const transactionQuery = `
      SELECT 
        pt.id,
        pt.user_id,
        pt.subscription_id,
        pt.stripe_payment_intent_id,
        pt.stripe_charge_id,
        pt.amount,
        pt.currency,
        pt.status,
        pt.payment_method_type,
        pt.payment_method_last4,
        pt.failure_code,
        pt.failure_message,
        pt.receipt_url,
        pt.created_at,
        pt.updated_at,
        pt.metadata
      FROM payment_transactions pt
      WHERE pt.id = $1
    `;

      const transactionResult = await pool.query(transactionQuery, [
        transactionId,
      ]);

      if (transactionResult.rows.length === 0) {
        return res.status(404).json({
          error: 'Transaction not found',
          code: 'TRANSACTION_NOT_FOUND',
        });
      }

      const transaction = transactionResult.rows[0];

      // Get user information
      const userQuery = `
      SELECT 
        id,
        email,
        username,
        jwt_id,
        created_at,
        is_suspended
      FROM users
      WHERE id = $1
    `;

      const userResult = await pool.query(userQuery, [transaction.user_id]);
      const user = userResult.rows[0] || null;

      // Get payment method details (if available)
      let paymentMethod = null;
      if (transaction.payment_method_last4) {
        const paymentMethodQuery = `
        SELECT 
          id,
          stripe_payment_method_id,
          type,
          card_brand,
          card_last4,
          card_exp_month,
          card_exp_year,
          billing_email,
          billing_name,
          is_default,
          status
        FROM payment_methods
        WHERE user_id = $1 AND card_last4 = $2
        ORDER BY created_at DESC
        LIMIT 1
      `;

        const paymentMethodResult = await pool.query(paymentMethodQuery, [
          transaction.user_id,
          transaction.payment_method_last4,
        ]);

        paymentMethod = paymentMethodResult.rows[0] || null;
      }

      // Get refund information
      const refundsQuery = `
      SELECT 
        id,
        stripe_refund_id,
        amount,
        currency,
        reason,
        reason_details,
        status,
        failure_reason,
        admin_user_id,
        created_at,
        updated_at
      FROM refunds
      WHERE transaction_id = $1
      ORDER BY created_at DESC
    `;

      const refundsResult = await pool.query(refundsQuery, [transactionId]);
      const refunds = refundsResult.rows;

      // Get admin user info for refunds
      if (refunds.length > 0) {
        const adminUserIds = [
          ...new Set(refunds.map((r) => r.admin_user_id).filter(Boolean)),
        ];
        if (adminUserIds.length > 0) {
          const adminUsersQuery = `
          SELECT id, email, username
          FROM users
          WHERE id = ANY($1)
        `;
          const adminUsersResult = await pool.query(adminUsersQuery, [
            adminUserIds,
          ]);
          const adminUsersMap = new Map(
            adminUsersResult.rows.map((u) => [u.id, u]),
          );

          // Add admin user info to refunds
          refunds.forEach((refund) => {
            if (refund.admin_user_id) {
              refund.admin_user =
                adminUsersMap.get(refund.admin_user_id) || null;
            }
          });
        }
      }

      // Get subscription information (if applicable)
      let subscription = null;
      if (transaction.subscription_id) {
        const subscriptionQuery = `
        SELECT 
          id,
          stripe_subscription_id,
          stripe_customer_id,
          tier,
          status,
          current_period_start,
          current_period_end,
          cancel_at_period_end,
          canceled_at,
          created_at
        FROM subscriptions
        WHERE id = $1
      `;

        const subscriptionResult = await pool.query(subscriptionQuery, [
          transaction.subscription_id,
        ]);
        subscription = subscriptionResult.rows[0] || null;
      }

      // Calculate refund totals
      const totalRefunded = refunds
        .filter((r) => r.status === 'succeeded')
        .reduce((sum, r) => sum + parseFloat(r.amount), 0);

      const netAmount = parseFloat(transaction.amount) - totalRefunded;

      logger.info('✅ [AdminPayments] Transaction details retrieved', {
        adminUserId: req.adminUser.id,
        transactionId,
        userId: transaction.user_id,
      });

      res.json({
        success: true,
        data: {
          transaction,
          user,
          paymentMethod,
          refunds,
          subscription,
          summary: {
            originalAmount: parseFloat(transaction.amount),
            totalRefunded,
            netAmount,
            refundCount: refunds.length,
            isFullyRefunded: totalRefunded >= parseFloat(transaction.amount),
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error(
        '🔴 [AdminPayments] Failed to retrieve transaction details',
        {
          adminUserId: req.adminUser?.id,
          transactionId: req.params.transactionId,
          error: error.message,
          stack: error.stack,
        },
      );

      res.status(500).json({
        error: 'Failed to retrieve transaction details',
        code: 'TRANSACTION_DETAILS_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/payments/refunds
 * Process a refund for a transaction
 *
 * Request Body:
 * - transactionId: Transaction ID to refund (required)
 * - amount: Amount to refund (optional, defaults to full refund)
 * - reason: Refund reason (required) - customer_request, billing_error, service_issue, duplicate, fraudulent, other
 * - reasonDetails: Additional details about the refund (optional)
 *
 * Features:
 * - Validates refund amount
 * - Processes refund through Stripe
 * - Stores refund in database
 * - Logs action in audit log
 */
router.post(
  '/refunds',
  adminRateLimiter,
  adminAuth(['process_refunds']),
  async (req, res) => {
    try {
      const pool = getPool();
      const { transactionId, amount, reason, reasonDetails } = req.body;

      // Validate required fields
      if (!transactionId) {
        return res.status(400).json({
          error: 'Transaction ID is required',
          code: 'TRANSACTION_ID_REQUIRED',
        });
      }

      if (!reason) {
        return res.status(400).json({
          error: 'Refund reason is required',
          code: 'REASON_REQUIRED',
        });
      }

      // Validate transactionId format (UUID)
      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(transactionId)) {
        return res.status(400).json({
          error: 'Invalid transaction ID format',
          code: 'INVALID_TRANSACTION_ID',
        });
      }

      // Validate reason
      const validReasons = [
        'customer_request',
        'billing_error',
        'service_issue',
        'duplicate',
        'fraudulent',
        'other',
      ];
      if (!validReasons.includes(reason)) {
        return res.status(400).json({
          error: 'Invalid refund reason',
          code: 'INVALID_REASON',
          validReasons,
        });
      }

      // Validate amount if provided
      if (amount !== undefined && amount !== null) {
        const parsedAmount = parseFloat(amount);
        if (isNaN(parsedAmount) || parsedAmount <= 0) {
          return res.status(400).json({
            error: 'Refund amount must be a positive number',
            code: 'INVALID_AMOUNT',
          });
        }
      }

      // Get transaction to verify it exists and can be refunded
      const transactionQuery = `
      SELECT 
        pt.id,
        pt.user_id,
        pt.amount,
        pt.currency,
        pt.status,
        pt.stripe_payment_intent_id,
        u.email as user_email
      FROM payment_transactions pt
      LEFT JOIN users u ON pt.user_id = u.id
      WHERE pt.id = $1
    `;

      const transactionResult = await pool.query(transactionQuery, [
        transactionId,
      ]);

      if (transactionResult.rows.length === 0) {
        return res.status(404).json({
          error: 'Transaction not found',
          code: 'TRANSACTION_NOT_FOUND',
        });
      }

      const transaction = transactionResult.rows[0];

      // Check if transaction can be refunded
      if (
        transaction.status !== 'succeeded' &&
        transaction.status !== 'partially_refunded'
      ) {
        return res.status(400).json({
          error: `Cannot refund transaction with status: ${transaction.status}`,
          code: 'INVALID_TRANSACTION_STATUS',
          currentStatus: transaction.status,
        });
      }

      // Calculate already refunded amount
      const refundedQuery = `
      SELECT COALESCE(SUM(amount), 0) as total_refunded
      FROM refunds
      WHERE transaction_id = $1 AND status = 'succeeded'
    `;

      const refundedResult = await pool.query(refundedQuery, [transactionId]);
      const totalRefunded = parseFloat(refundedResult.rows[0].total_refunded);
      const remainingAmount = parseFloat(transaction.amount) - totalRefunded;

      // Validate refund amount doesn't exceed remaining amount
      const refundAmount = amount ? parseFloat(amount) : remainingAmount;

      if (refundAmount > remainingAmount) {
        return res.status(400).json({
          error: 'Refund amount exceeds remaining refundable amount',
          code: 'AMOUNT_EXCEEDS_REMAINING',
          transactionAmount: parseFloat(transaction.amount),
          totalRefunded,
          remainingAmount,
          requestedAmount: refundAmount,
        });
      }

      // Initialize refund service
      const refundService = new RefundService(pool);
      refundService.initialize();

      // Process refund
      const refundResult = await refundService.processRefund({
        transactionId,
        amount: refundAmount,
        reason,
        reasonDetails: reasonDetails || null,
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      if (!refundResult.success) {
        return res.status(400).json({
          error: 'Refund processing failed',
          code: refundResult.error.code,
          details: refundResult.error.message,
        });
      }

      logger.info('✅ [AdminPayments] Refund processed successfully', {
        adminUserId: req.adminUser.id,
        transactionId,
        refundId: refundResult.refund.id,
        amount: refundAmount,
        reason,
      });

      res.json({
        success: true,
        message: 'Refund processed successfully',
        data: {
          refund: refundResult.refund,
          transaction: {
            id: transactionId,
            originalAmount: parseFloat(transaction.amount),
            totalRefunded: totalRefunded + refundAmount,
            remainingAmount: remainingAmount - refundAmount,
          },
          stripeRefund: refundResult.stripeRefund,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminPayments] Failed to process refund', {
        adminUserId: req.adminUser?.id,
        transactionId: req.body?.transactionId,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to process refund',
        code: 'REFUND_PROCESSING_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/payments/methods/:userId
 * Get user payment methods
 *
 * Returns:
 * - List of payment methods for the user
 * - Sensitive data is masked (only last 4 digits shown)
 * - Payment method status
 *
 * Security:
 * - Never returns full card numbers or CVV
 * - Complies with PCI DSS requirements
 */
router.get(
  '/methods/:userId',
  adminReadOnlyLimiter,
  adminAuth(['view_payments']),
  async (req, res) => {
    try {
      const pool = getPool();
      const { userId } = req.params;

      // Validate userId format (UUID)
      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(userId)) {
        return res.status(400).json({
          error: 'Invalid user ID format',
          code: 'INVALID_USER_ID',
        });
      }

      // Verify user exists
      const userQuery = `
      SELECT id, email, username
      FROM users
      WHERE id = $1
    `;

      const userResult = await pool.query(userQuery, [userId]);

      if (userResult.rows.length === 0) {
        return res.status(404).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND',
        });
      }

      const user = userResult.rows[0];

      // Get payment methods (with sensitive data masked)
      const paymentMethodsQuery = `
      SELECT 
        id,
        stripe_payment_method_id,
        type,
        card_brand,
        card_last4,
        card_exp_month,
        card_exp_year,
        billing_email,
        billing_name,
        is_default,
        status,
        created_at,
        updated_at
      FROM payment_methods
      WHERE user_id = $1
      ORDER BY is_default DESC, created_at DESC
    `;

      const paymentMethodsResult = await pool.query(paymentMethodsQuery, [
        userId,
      ]);
      const paymentMethods = paymentMethodsResult.rows;

      // Mask billing email (show only first 2 chars and domain)
      paymentMethods.forEach((method) => {
        if (method.billing_email) {
          const [localPart, domain] = method.billing_email.split('@');
          if (localPart && domain) {
            const maskedLocal = localPart.substring(0, 2) + '***';
            method.billing_email = `${maskedLocal}@${domain}`;
          }
        }

        // Add expiration status
        if (method.card_exp_month && method.card_exp_year) {
          const now = new Date();
          const expDate = new Date(
            method.card_exp_year,
            method.card_exp_month - 1,
          );
          method.is_expired = expDate < now;
        }
      });

      // Get usage statistics for each payment method
      for (const method of paymentMethods) {
        const usageQuery = `
        SELECT 
          COUNT(*) as transaction_count,
          SUM(CASE WHEN status = 'succeeded' THEN amount ELSE 0 END) as total_spent,
          MAX(created_at) as last_used
        FROM payment_transactions
        WHERE user_id = $1 AND payment_method_last4 = $2
      `;

        const usageResult = await pool.query(usageQuery, [
          userId,
          method.card_last4,
        ]);
        const usage = usageResult.rows[0];

        method.usage = {
          transactionCount: parseInt(usage.transaction_count),
          totalSpent: parseFloat(usage.total_spent || 0),
          lastUsed: usage.last_used,
        };
      }

      logger.info('✅ [AdminPayments] Payment methods retrieved', {
        adminUserId: req.adminUser.id,
        targetUserId: userId,
        methodCount: paymentMethods.length,
      });

      res.json({
        success: true,
        data: {
          user: {
            id: user.id,
            email: user.email,
            username: user.username,
          },
          paymentMethods,
          summary: {
            totalMethods: paymentMethods.length,
            activeMethods: paymentMethods.filter((m) => m.status === 'active')
              .length,
            expiredMethods: paymentMethods.filter((m) => m.is_expired).length,
            defaultMethod: paymentMethods.find((m) => m.is_default) || null,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminPayments] Failed to retrieve payment methods', {
        adminUserId: req.adminUser?.id,
        targetUserId: req.params.userId,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve payment methods',
        code: 'PAYMENT_METHODS_FAILED',
        details: error.message,
      });
    }
  },
);
