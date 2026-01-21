/**
 * Admin Subscription Management Routes
 *
 * Provides endpoints for administrators to manage user subscriptions,
 * including viewing, updating, and canceling subscriptions.
 *
 * All endpoints require admin authentication with appropriate permissions.
 */

import express from 'express';
import { adminAuth } from '../../middleware/admin-auth.js';
import { logAdminAction } from '../../utils/audit-logger.js';
import logger from '../../logger.js';
import {
  adminReadOnlyLimiter,
  adminRateLimiter,
} from '../../middleware/admin-rate-limiter.js';

const router = express.Router();

/**
 * GET /api/admin/subscriptions
 *
 * List all subscriptions with pagination and filtering
 *
 * Query Parameters:
 * - page: Page number (default: 1)
 * - limit: Items per page (default: 50, max: 200)
 * - tier: Filter by subscription tier (free, premium, enterprise)
 * - status: Filter by status (active, canceled, past_due, trialing, incomplete)
 * - userId: Filter by user ID
 * - includeUpcoming: Include upcoming renewals (default: false)
 * - sortBy: Sort field (created_at, current_period_end, tier, status)
 * - sortOrder: Sort order (asc, desc) (default: desc)
 *
 * Permissions: view_subscriptions
 */
router.get(
  '/subscriptions',
  adminReadOnlyLimiter,
  adminAuth(['view_subscriptions']),
  async (req, res) => {
    try {
      const {
        page = 1,
        limit = 50,
        tier,
        status,
        userId,
        includeUpcoming = 'false',
        sortBy = 'created_at',
        sortOrder = 'desc',
      } = req.query;

      // Validate and sanitize inputs
      const pageNum = Math.max(1, parseInt(page, 10));
      const limitNum = Math.min(200, Math.max(1, parseInt(limit, 10)));
      const offset = (pageNum - 1) * limitNum;

      // Validate sort parameters
      const validSortFields = [
        'created_at',
        'current_period_end',
        'tier',
        'status',
        'updated_at',
      ];
      const sortField = validSortFields.includes(sortBy)
        ? sortBy
        : 'created_at';
      const sortDirection = sortOrder.toLowerCase() === 'asc' ? 'ASC' : 'DESC';

      // Build WHERE clause
      const conditions = [];
      const values = [];
      let paramIndex = 1;

      if (tier) {
        conditions.push(`s.tier = $${paramIndex++}`);
        values.push(tier);
      }

      if (status) {
        conditions.push(`s.status = $${paramIndex++}`);
        values.push(status);
      }

      if (userId) {
        conditions.push(`s.user_id = $${paramIndex++}`);
        values.push(userId);
      }

      const whereClause =
        conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      // Get total count
      const countQuery = `
      SELECT COUNT(*) as total
      FROM subscriptions s
      ${whereClause}
    `;

      const countResult = await req.db.query(countQuery, values);
      const totalCount = parseInt(countResult.rows[0].total, 10);
      const totalPages = Math.ceil(totalCount / limitNum);

      // Get subscriptions with user information
      const query = `
      SELECT 
        s.id,
        s.user_id,
        s.stripe_subscription_id,
        s.stripe_customer_id,
        s.tier,
        s.status,
        s.current_period_start,
        s.current_period_end,
        s.cancel_at_period_end,
        s.canceled_at,
        s.trial_start,
        s.trial_end,
        s.created_at,
        s.updated_at,
        s.metadata,
        u.email as user_email,
        u.username as user_username,
        u.status as user_status
      FROM subscriptions s
      INNER JOIN users u ON s.user_id = u.id
      ${whereClause}
      ORDER BY s.${sortField} ${sortDirection}
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;

      values.push(limitNum, offset);

      const result = await req.db.query(query, values);

      // Calculate upcoming renewals if requested
      let upcomingRenewals = [];
      if (includeUpcoming === 'true') {
        const renewalQuery = `
        SELECT 
          s.id,
          s.user_id,
          s.tier,
          s.current_period_end,
          u.email as user_email
        FROM subscriptions s
        INNER JOIN users u ON s.user_id = u.id
        WHERE s.status = 'active'
          AND s.cancel_at_period_end = false
          AND s.current_period_end BETWEEN NOW() AND NOW() + INTERVAL '7 days'
        ORDER BY s.current_period_end ASC
        LIMIT 50
      `;

        const renewalResult = await req.db.query(renewalQuery);
        upcomingRenewals = renewalResult.rows;
      }

      // Format response
      const subscriptions = result.rows.map((row) => ({
        id: row.id,
        userId: row.user_id,
        stripeSubscriptionId: row.stripe_subscription_id,
        stripeCustomerId: row.stripe_customer_id,
        tier: row.tier,
        status: row.status,
        currentPeriodStart: row.current_period_start,
        currentPeriodEnd: row.current_period_end,
        cancelAtPeriodEnd: row.cancel_at_period_end,
        canceledAt: row.canceled_at,
        trialStart: row.trial_start,
        trialEnd: row.trial_end,
        createdAt: row.created_at,
        updatedAt: row.updated_at,
        metadata: row.metadata,
        user: {
          email: row.user_email,
          username: row.user_username,
          status: row.user_status,
        },
      }));

      res.json({
        success: true,
        data: {
          subscriptions,
          pagination: {
            page: pageNum,
            limit: limitNum,
            totalCount,
            totalPages,
            hasNextPage: pageNum < totalPages,
            hasPreviousPage: pageNum > 1,
          },
          upcomingRenewals:
            includeUpcoming === 'true' ? upcomingRenewals : undefined,
        },
      });
    } catch (error) {
      logger.error('Failed to list subscriptions', {
        error: error.message,
        stack: error.stack,
        adminUserId: req.adminUser?.id,
      });

      res.status(500).json({
        success: false,
        error: {
          code: 'SUBSCRIPTION_LIST_FAILED',
          message: 'Failed to retrieve subscriptions',
          details:
            process.env.NODE_ENV === 'development' ? error.message : undefined,
        },
      });
    }
  },
);

/**
 * GET /api/admin/subscriptions/:subscriptionId
 *
 * Get detailed information about a specific subscription
 *
 * Returns:
 * - Subscription details
 * - User information
 * - Payment history
 * - Billing cycle information
 *
 * Permissions: view_subscriptions
 */
router.get(
  '/subscriptions/:subscriptionId',
  adminReadOnlyLimiter,
  adminAuth(['view_subscriptions']),
  async (req, res) => {
    try {
      const { subscriptionId } = req.params;

      // Get subscription with user information
      const subscriptionQuery = `
      SELECT 
        s.id,
        s.user_id,
        s.stripe_subscription_id,
        s.stripe_customer_id,
        s.tier,
        s.status,
        s.current_period_start,
        s.current_period_end,
        s.cancel_at_period_end,
        s.canceled_at,
        s.trial_start,
        s.trial_end,
        s.created_at,
        s.updated_at,
        s.metadata,
        u.email as user_email,
        u.username as user_username,
        u.status as user_status,
        u.created_at as user_created_at,
        u.last_login as user_last_login
      FROM subscriptions s
      INNER JOIN users u ON s.user_id = u.id
      WHERE s.id = $1
    `;

      const subscriptionResult = await req.db.query(subscriptionQuery, [
        subscriptionId,
      ]);

      if (subscriptionResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'SUBSCRIPTION_NOT_FOUND',
            message: 'Subscription not found',
          },
        });
      }

      const subscription = subscriptionResult.rows[0];

      // Get payment history for this subscription
      const paymentHistoryQuery = `
      SELECT 
        id,
        amount,
        currency,
        status,
        payment_method_type,
        payment_method_last4,
        receipt_url,
        created_at,
        metadata
      FROM payment_transactions
      WHERE subscription_id = $1
      ORDER BY created_at DESC
      LIMIT 50
    `;

      const paymentHistoryResult = await req.db.query(paymentHistoryQuery, [
        subscriptionId,
      ]);

      // Calculate billing cycle information
      const currentPeriodStart = new Date(subscription.current_period_start);
      const currentPeriodEnd = new Date(subscription.current_period_end);
      const now = new Date();

      const billingCycleInfo = {
        currentPeriodStart: subscription.current_period_start,
        currentPeriodEnd: subscription.current_period_end,
        daysRemaining: Math.max(
          0,
          Math.ceil((currentPeriodEnd - now) / (1000 * 60 * 60 * 24)),
        ),
        daysInCycle: Math.ceil(
          (currentPeriodEnd - currentPeriodStart) / (1000 * 60 * 60 * 24),
        ),
        nextBillingDate: subscription.cancel_at_period_end
          ? null
          : subscription.current_period_end,
        willRenew:
          !subscription.cancel_at_period_end &&
          subscription.status === 'active',
      };

      // Calculate payment statistics
      const successfulPayments = paymentHistoryResult.rows.filter(
        (p) => p.status === 'succeeded',
      );
      const totalPaid = successfulPayments.reduce(
        (sum, p) => sum + parseFloat(p.amount),
        0,
      );

      const paymentStats = {
        totalTransactions: paymentHistoryResult.rows.length,
        successfulTransactions: successfulPayments.length,
        failedTransactions: paymentHistoryResult.rows.filter(
          (p) => p.status === 'failed',
        ).length,
        totalAmountPaid: totalPaid,
        currency: paymentHistoryResult.rows[0]?.currency || 'USD',
      };

      // Format response
      const response = {
        id: subscription.id,
        userId: subscription.user_id,
        stripeSubscriptionId: subscription.stripe_subscription_id,
        stripeCustomerId: subscription.stripe_customer_id,
        tier: subscription.tier,
        status: subscription.status,
        currentPeriodStart: subscription.current_period_start,
        currentPeriodEnd: subscription.current_period_end,
        cancelAtPeriodEnd: subscription.cancel_at_period_end,
        canceledAt: subscription.canceled_at,
        trialStart: subscription.trial_start,
        trialEnd: subscription.trial_end,
        createdAt: subscription.created_at,
        updatedAt: subscription.updated_at,
        metadata: subscription.metadata,
        user: {
          id: subscription.user_id,
          email: subscription.user_email,
          username: subscription.user_username,
          status: subscription.user_status,
          createdAt: subscription.user_created_at,
          lastLogin: subscription.user_last_login,
        },
        billingCycle: billingCycleInfo,
        paymentHistory: paymentHistoryResult.rows.map((row) => ({
          id: row.id,
          amount: parseFloat(row.amount),
          currency: row.currency,
          status: row.status,
          paymentMethodType: row.payment_method_type,
          paymentMethodLast4: row.payment_method_last4,
          receiptUrl: row.receipt_url,
          createdAt: row.created_at,
          metadata: row.metadata,
        })),
        paymentStats,
      };

      res.json({
        success: true,
        data: response,
      });
    } catch (error) {
      logger.error('Failed to get subscription details', {
        error: error.message,
        stack: error.stack,
        subscriptionId: req.params.subscriptionId,
        adminUserId: req.adminUser?.id,
      });

      res.status(500).json({
        success: false,
        error: {
          code: 'SUBSCRIPTION_DETAILS_FAILED',
          message: 'Failed to retrieve subscription details',
          details:
            process.env.NODE_ENV === 'development' ? error.message : undefined,
        },
      });
    }
  },
);

/**
 * PATCH /api/admin/subscriptions/:subscriptionId
 *
 * Update a subscription (upgrade/downgrade tier)
 *
 * Request Body:
 * - tier: New subscription tier (free, premium, enterprise)
 * - priceId: Stripe price ID for the new tier
 * - prorationBehavior: How to handle proration (create_prorations, none, always_invoice)
 *
 * Permissions: edit_subscriptions
 */
router.patch(
  '/subscriptions/:subscriptionId',
  adminRateLimiter,
  adminAuth(['edit_subscriptions']),
  async (req, res) => {
    try {
      const { subscriptionId } = req.params;
      const {
        tier,
        priceId,
        prorationBehavior = 'create_prorations',
      } = req.body;

      // Validate required fields
      if (!tier || !priceId) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_REQUEST',
            message: 'Missing required fields: tier and priceId',
          },
        });
      }

      // Validate tier
      const validTiers = ['free', 'premium', 'enterprise'];
      if (!validTiers.includes(tier)) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_TIER',
            message:
              'Invalid subscription tier. Must be one of: free, premium, enterprise',
          },
        });
      }

      // Get existing subscription
      const existingQuery = `
      SELECT 
        s.*,
        u.email as user_email
      FROM subscriptions s
      INNER JOIN users u ON s.user_id = u.id
      WHERE s.id = $1
    `;

      const existingResult = await req.db.query(existingQuery, [
        subscriptionId,
      ]);

      if (existingResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'SUBSCRIPTION_NOT_FOUND',
            message: 'Subscription not found',
          },
        });
      }

      const existingSubscription = existingResult.rows[0];
      const oldTier = existingSubscription.tier;

      // Check if subscription is active
      if (
        existingSubscription.status !== 'active' &&
        existingSubscription.status !== 'trialing'
      ) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'SUBSCRIPTION_NOT_ACTIVE',
            message: 'Can only update active or trialing subscriptions',
          },
        });
      }

      // Initialize subscription service
      const SubscriptionService = (
        await import('../../services/subscription-service.js')
      ).default;
      const subscriptionService = new SubscriptionService(req.db);
      subscriptionService.initialize();

      // Update subscription through service
      const updateResult = await subscriptionService.updateSubscription(
        subscriptionId,
        {
          tier,
          priceId,
          prorationBehavior,
        },
      );

      if (!updateResult.success) {
        return res.status(400).json({
          success: false,
          error: updateResult.error,
        });
      }

      // Calculate proration details if applicable
      let prorationDetails = null;
      if (prorationBehavior === 'create_prorations') {
        const stripe = subscriptionService.stripe;
        const upcomingInvoice = await stripe.invoices.retrieveUpcoming({
          customer: existingSubscription.stripe_customer_id,
          subscription: existingSubscription.stripe_subscription_id,
        });

        prorationDetails = {
          proratedAmount: upcomingInvoice.amount_due / 100, // Convert from cents
          currency: upcomingInvoice.currency,
          nextInvoiceDate: new Date(upcomingInvoice.period_end * 1000),
          lineItems: upcomingInvoice.lines.data.map((line) => ({
            description: line.description,
            amount: line.amount / 100,
            period: {
              start: new Date(line.period.start * 1000),
              end: new Date(line.period.end * 1000),
            },
          })),
        };
      }

      // Log action in audit log
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'subscription_updated',
        resourceType: 'subscription',
        resourceId: subscriptionId,
        affectedUserId: existingSubscription.user_id,
        details: {
          oldTier,
          newTier: tier,
          priceId,
          prorationBehavior,
          prorationAmount: prorationDetails?.proratedAmount,
        },
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });

      logger.info('Subscription updated successfully', {
        subscriptionId,
        oldTier,
        newTier: tier,
        adminUserId: req.adminUser.id,
        userId: existingSubscription.user_id,
      });

      res.json({
        success: true,
        data: {
          subscription: updateResult.subscription,
          prorationDetails,
          message: `Subscription upgraded from ${oldTier} to ${tier}`,
        },
      });
    } catch (error) {
      logger.error('Failed to update subscription', {
        error: error.message,
        stack: error.stack,
        subscriptionId: req.params.subscriptionId,
        adminUserId: req.adminUser?.id,
      });

      res.status(500).json({
        success: false,
        error: {
          code: 'SUBSCRIPTION_UPDATE_FAILED',
          message: 'Failed to update subscription',
          details:
            process.env.NODE_ENV === 'development' ? error.message : undefined,
        },
      });
    }
  },
);

/**
 * POST /api/admin/subscriptions/:subscriptionId/cancel
 *
 * Cancel a subscription
 *
 * Request Body:
 * - immediate: Cancel immediately (true) or at period end (false) (default: false)
 * - reason: Reason for cancellation (required)
 *
 * Permissions: edit_subscriptions
 */
router.post(
  '/subscriptions/:subscriptionId/cancel',
  adminRateLimiter,
  adminAuth(['edit_subscriptions']),
  async (req, res) => {
    try {
      const { subscriptionId } = req.params;
      const { immediate = false, reason } = req.body;

      // Validate required fields
      if (!reason || reason.trim().length === 0) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_REQUEST',
            message: 'Cancellation reason is required',
          },
        });
      }

      // Get existing subscription
      const existingQuery = `
      SELECT 
        s.*,
        u.email as user_email,
        u.username as user_username
      FROM subscriptions s
      INNER JOIN users u ON s.user_id = u.id
      WHERE s.id = $1
    `;

      const existingResult = await req.db.query(existingQuery, [
        subscriptionId,
      ]);

      if (existingResult.rows.length === 0) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'SUBSCRIPTION_NOT_FOUND',
            message: 'Subscription not found',
          },
        });
      }

      const existingSubscription = existingResult.rows[0];

      // Check if subscription is already canceled
      if (existingSubscription.status === 'canceled') {
        return res.status(400).json({
          success: false,
          error: {
            code: 'SUBSCRIPTION_ALREADY_CANCELED',
            message: 'Subscription is already canceled',
          },
        });
      }

      // Check if subscription is already set to cancel at period end
      if (existingSubscription.cancel_at_period_end && !immediate) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'SUBSCRIPTION_ALREADY_CANCELING',
            message: 'Subscription is already set to cancel at period end',
          },
        });
      }

      // Initialize subscription service
      const SubscriptionService = (
        await import('../../services/subscription-service.js')
      ).default;
      const subscriptionService = new SubscriptionService(req.db);
      subscriptionService.initialize();

      // Cancel subscription through service
      const cancelResult = await subscriptionService.cancelSubscription(
        subscriptionId,
        immediate,
      );

      if (!cancelResult.success) {
        return res.status(400).json({
          success: false,
          error: cancelResult.error,
        });
      }

      // Calculate refund information if immediate cancellation
      let refundInfo = null;
      if (immediate) {
        const currentPeriodStart = new Date(
          existingSubscription.current_period_start,
        );
        const currentPeriodEnd = new Date(
          existingSubscription.current_period_end,
        );
        const now = new Date();

        const totalDays = Math.ceil(
          (currentPeriodEnd - currentPeriodStart) / (1000 * 60 * 60 * 24),
        );
        const daysRemaining = Math.max(
          0,
          Math.ceil((currentPeriodEnd - now) / (1000 * 60 * 60 * 24)),
        );

        // Get last payment for this subscription
        const lastPaymentQuery = `
        SELECT amount, currency
        FROM payment_transactions
        WHERE subscription_id = $1
          AND status = 'succeeded'
        ORDER BY created_at DESC
        LIMIT 1
      `;

        const lastPaymentResult = await req.db.query(lastPaymentQuery, [
          subscriptionId,
        ]);

        if (lastPaymentResult.rows.length > 0) {
          const lastPayment = lastPaymentResult.rows[0];
          const proratedRefund =
            (parseFloat(lastPayment.amount) * daysRemaining) / totalDays;

          refundInfo = {
            eligibleForRefund: daysRemaining > 0,
            proratedAmount: Math.round(proratedRefund * 100) / 100,
            currency: lastPayment.currency,
            daysRemaining,
            totalDays,
            note: 'Refund must be processed separately through the refunds endpoint',
          };
        }
      }

      // Determine effective cancellation date
      const effectiveDate = immediate
        ? new Date()
        : new Date(existingSubscription.current_period_end);

      // Log action in audit log
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: immediate
          ? 'subscription_canceled_immediately'
          : 'subscription_canceled_at_period_end',
        resourceType: 'subscription',
        resourceId: subscriptionId,
        affectedUserId: existingSubscription.user_id,
        details: {
          tier: existingSubscription.tier,
          immediate,
          reason,
          effectiveDate,
          currentPeriodEnd: existingSubscription.current_period_end,
          refundInfo,
        },
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });

      logger.info('Subscription canceled successfully', {
        subscriptionId,
        immediate,
        reason,
        adminUserId: req.adminUser.id,
        userId: existingSubscription.user_id,
        userEmail: existingSubscription.user_email,
      });

      res.json({
        success: true,
        data: {
          subscription: cancelResult.subscription,
          cancellationType: immediate ? 'immediate' : 'end_of_period',
          effectiveDate,
          refundInfo,
          message: immediate
            ? 'Subscription canceled immediately. User access has been revoked.'
            : `Subscription will be canceled at the end of the current billing period (${effectiveDate.toISOString().split('T')[0]}). User will retain access until then.`,
        },
      });
    } catch (error) {
      logger.error('Failed to cancel subscription', {
        error: error.message,
        stack: error.stack,
        subscriptionId: req.params.subscriptionId,
        adminUserId: req.adminUser?.id,
      });

      res.status(500).json({
        success: false,
        error: {
          code: 'SUBSCRIPTION_CANCEL_FAILED',
          message: 'Failed to cancel subscription',
          details:
            process.env.NODE_ENV === 'development' ? error.message : undefined,
        },
      });
    }
  },
);

export default router;
