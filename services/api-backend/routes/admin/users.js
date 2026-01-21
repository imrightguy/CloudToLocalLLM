/**
 * Admin User Management API Routes
 *
 * Provides secure administrative endpoints for user management:
 * - List users with pagination, search, and filtering
 * - View detailed user profiles
 * - Update user subscriptions
 * - Suspend and reactivate user accounts
 *
 * Security Features:
 * - Admin authentication required
 * - Role-based permission checking
 * - Comprehensive audit logging
 * - Input validation and sanitization
 */

import express from 'express';
import { adminAuth } from '../../middleware/admin-auth.js';
import { logAdminAction } from '../../utils/audit-logger.js';
import logger from '../../logger.js';
import { getPool, closePool } from '../../database/db-pool.js';
import {
  adminReadOnlyLimiter,
  adminRateLimiter,
} from '../../middleware/admin-rate-limiter.js';

const router = express.Router();

/**
 * GET /api/admin/users
 * List all users with pagination, search, and filtering
 *
 * Query Parameters:
 * - page: Page number (default: 1)
 * - limit: Items per page (default: 50, max: 100)
 * - search: Search by email, username, or user ID
 * - tier: Filter by subscription tier (free, premium, enterprise)
 * - status: Filter by account status (active, suspended, deleted)
 * - startDate: Filter by registration date (start)
 * - endDate: Filter by registration date (end)
 * - sortBy: Sort field (created_at, last_login, email)
 * - sortOrder: Sort order (asc, desc)
 */
router.get(
  '/',
  adminReadOnlyLimiter,
  adminAuth(['view_users']),
  async (req, res) => {
    try {
      const pool = getPool();

      // Parse and validate query parameters
      const page = Math.max(1, parseInt(req.query.page) || 1);
      const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 50));
      const offset = (page - 1) * limit;
      const search = req.query.search?.trim() || '';
      const tier = req.query.tier?.toLowerCase();
      const status = req.query.status?.toLowerCase();
      const startDate = req.query.startDate;
      const endDate = req.query.endDate;
      const sortBy = req.query.sortBy || 'created_at';
      const sortOrder =
        req.query.sortOrder?.toLowerCase() === 'asc' ? 'ASC' : 'DESC';

      // Validate sort field
      const validSortFields = ['created_at', 'last_login', 'email', 'username'];
      const sortField = validSortFields.includes(sortBy)
        ? sortBy
        : 'created_at';

      // Build query conditions
      const conditions = [];
      const params = [];
      let paramIndex = 1;

      // Search condition (email, username, or user ID)
      if (search) {
        conditions.push(`(
        u.email ILIKE $${paramIndex} OR 
        u.username ILIKE $${paramIndex} OR 
        u.id::text ILIKE $${paramIndex} OR
        u.jwt_id ILIKE $${paramIndex}
      )`);
        params.push(`%${search}%`);
        paramIndex++;
      }

      // Tier filter
      if (tier && ['free', 'premium', 'enterprise'].includes(tier)) {
        conditions.push(`s.tier = $${paramIndex}`);
        params.push(tier);
        paramIndex++;
      }

      // Status filter
      if (status) {
        if (status === 'active') {
          conditions.push('u.is_suspended = false AND u.deleted_at IS NULL');
        } else if (status === 'suspended') {
          conditions.push('u.is_suspended = true');
        } else if (status === 'deleted') {
          conditions.push('u.deleted_at IS NOT NULL');
        }
      }

      // Date range filter
      if (startDate) {
        conditions.push(`u.created_at >= $${paramIndex}`);
        params.push(startDate);
        paramIndex++;
      }

      if (endDate) {
        conditions.push(`u.created_at <= $${paramIndex}`);
        params.push(endDate);
        paramIndex++;
      }

      const whereClause =
        conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      // Get total count
      const countQuery = `
      SELECT COUNT(DISTINCT u.id) as total
      FROM users u
      LEFT JOIN subscriptions s ON u.id = s.user_id AND s.status = 'active'
      ${whereClause}
    `;

      const countResult = await pool.query(countQuery, params);
      const totalUsers = parseInt(countResult.rows[0].total);
      const totalPages = Math.ceil(totalUsers / limit);

      // Get users with pagination
      const usersQuery = `
      SELECT 
        u.id,
        u.email,
        u.username,
        u.jwt_id,
        u.created_at,
        u.last_login,
        u.is_suspended,
        u.suspended_at,
        u.suspension_reason,
        u.deleted_at,
        s.tier as subscription_tier,
        s.status as subscription_status,
        s.current_period_end as subscription_end_date,
        (SELECT COUNT(*) FROM user_sessions WHERE user_id = u.id AND expires_at > NOW()) as active_sessions
      FROM users u
      LEFT JOIN subscriptions s ON u.id = s.user_id AND s.status = 'active'
      ${whereClause}
      ORDER BY u.${sortField} ${sortOrder}
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;

      params.push(limit, offset);

      const usersResult = await pool.query(usersQuery, params);

      logger.info('✅ [AdminUsers] Users list retrieved', {
        adminUserId: req.adminUser.id,
        page,
        limit,
        totalUsers,
        search,
        tier,
        status,
      });

      res.json({
        success: true,
        data: {
          users: usersResult.rows,
          pagination: {
            page,
            limit,
            totalUsers,
            totalPages,
            hasNextPage: page < totalPages,
            hasPreviousPage: page > 1,
          },
          filters: {
            search,
            tier,
            status,
            startDate,
            endDate,
            sortBy: sortField,
            sortOrder,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminUsers] Failed to retrieve users list', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve users list',
        code: 'USERS_LIST_FAILED',
        details: error.message,
      });
    }
  },
);

export default router;

/**
 * GET /api/admin/users/:userId
 * Get detailed user profile information
 *
 * Returns:
 * - User profile details
 * - Subscription information
 * - Payment history
 * - Session information
 * - Activity timeline
 */
router.get(
  '/:userId',
  adminReadOnlyLimiter,
  adminAuth(['view_users']),
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

      // Get user profile
      const userQuery = `
      SELECT 
        u.id,
        u.email,
        u.username,
        u.jwt_id,
        u.created_at,
        u.last_login,
        u.is_suspended,
        u.suspended_at,
        u.suspension_reason,
        u.deleted_at,
        u.metadata
      FROM users u
      WHERE u.id = $1
    `;

      const userResult = await pool.query(userQuery, [userId]);

      if (userResult.rows.length === 0) {
        return res.status(404).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND',
        });
      }

      const user = userResult.rows[0];

      // Get subscription information
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
        trial_start,
        trial_end,
        created_at,
        updated_at,
        metadata
      FROM subscriptions
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT 1
    `;

      const subscriptionResult = await pool.query(subscriptionQuery, [userId]);
      const subscription = subscriptionResult.rows[0] || null;

      // Get payment history
      const paymentHistoryQuery = `
      SELECT 
        id,
        subscription_id,
        stripe_payment_intent_id,
        stripe_charge_id,
        amount,
        currency,
        status,
        payment_method_type,
        payment_method_last4,
        failure_code,
        failure_message,
        receipt_url,
        created_at,
        metadata
      FROM payment_transactions
      WHERE user_id = $1
      ORDER BY created_at DESC
      LIMIT 20
    `;

      const paymentHistoryResult = await pool.query(paymentHistoryQuery, [
        userId,
      ]);
      const paymentHistory = paymentHistoryResult.rows;

      // Get active sessions
      const sessionsQuery = `
      SELECT 
        id,
        session_token,
        created_at,
        expires_at,
        last_activity,
        ip_address,
        user_agent
      FROM user_sessions
      WHERE user_id = $1 AND expires_at > NOW()
      ORDER BY last_activity DESC
    `;

      const sessionsResult = await pool.query(sessionsQuery, [userId]);
      const activeSessions = sessionsResult.rows;

      // Get admin audit logs for this user (recent actions)
      const auditLogsQuery = `
      SELECT 
        id,
        admin_user_id,
        admin_role,
        action,
        resource_type,
        resource_id,
        details,
        ip_address,
        created_at
      FROM admin_audit_logs
      WHERE affected_user_id = $1
      ORDER BY created_at DESC
      LIMIT 10
    `;

      const auditLogsResult = await pool.query(auditLogsQuery, [userId]);
      const activityTimeline = auditLogsResult.rows;

      // Get payment methods
      const paymentMethodsQuery = `
      SELECT 
        id,
        stripe_payment_method_id,
        type,
        card_brand,
        card_last4,
        card_exp_month,
        card_exp_year,
        is_default,
        status,
        created_at
      FROM payment_methods
      WHERE user_id = $1
      ORDER BY is_default DESC, created_at DESC
    `;

      const paymentMethodsResult = await pool.query(paymentMethodsQuery, [
        userId,
      ]);
      const paymentMethods = paymentMethodsResult.rows;

      logger.info('✅ [AdminUsers] User details retrieved', {
        adminUserId: req.adminUser.id,
        targetUserId: userId,
        userEmail: user.email,
      });

      res.json({
        success: true,
        data: {
          user,
          subscription,
          paymentHistory,
          paymentMethods,
          activeSessions,
          activityTimeline,
          statistics: {
            totalPayments: paymentHistory.length,
            totalSpent: paymentHistory
              .filter((p) => p.status === 'succeeded')
              .reduce((sum, p) => sum + parseFloat(p.amount), 0),
            activeSessions: activeSessions.length,
            accountAge: Math.floor(
              (Date.now() - new Date(user.created_at).getTime()) /
                (1000 * 60 * 60 * 24),
            ),
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminUsers] Failed to retrieve user details', {
        adminUserId: req.adminUser?.id,
        targetUserId: req.params.userId,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve user details',
        code: 'USER_DETAILS_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * PATCH /api/admin/users/:userId
 * Update user information (primarily subscription tier changes)
 *
 * Request Body:
 * - subscriptionTier: New subscription tier (free, premium, enterprise)
 * - reason: Reason for the change (optional)
 *
 * Features:
 * - Calculates prorated charges for upgrades
 * - Updates subscription in database
 * - Logs action in audit log
 */
router.patch(
  '/:userId',
  adminRateLimiter,
  adminAuth(['edit_users']),
  async (req, res) => {
    try {
      const pool = getPool();
      const { userId } = req.params;
      const { subscriptionTier, reason } = req.body;

      // Validate userId format
      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(userId)) {
        return res.status(400).json({
          error: 'Invalid user ID format',
          code: 'INVALID_USER_ID',
        });
      }

      // Validate subscription tier
      const validTiers = ['free', 'premium', 'enterprise'];
      if (
        subscriptionTier &&
        !validTiers.includes(subscriptionTier.toLowerCase())
      ) {
        return res.status(400).json({
          error: 'Invalid subscription tier',
          code: 'INVALID_TIER',
          validTiers,
        });
      }

      // Get current user and subscription
      const userQuery = `
      SELECT u.id, u.email, s.id as subscription_id, s.tier as current_tier, s.status as subscription_status
      FROM users u
      LEFT JOIN subscriptions s ON u.id = s.user_id AND s.status = 'active'
      WHERE u.id = $1
    `;

      const userResult = await pool.query(userQuery, [userId]);

      if (userResult.rows.length === 0) {
        return res.status(404).json({
          error: 'User not found',
          code: 'USER_NOT_FOUND',
        });
      }

      const user = userResult.rows[0];
      const previousTier = user.current_tier || 'free';
      const newTier = subscriptionTier.toLowerCase();

      // Check if tier is actually changing
      if (previousTier === newTier) {
        return res.status(400).json({
          error: 'User already has this subscription tier',
          code: 'TIER_UNCHANGED',
        });
      }

      // Calculate prorated charge for upgrades
      let proratedCharge = 0;
      const tierPricing = {
        free: 0,
        premium: 9.99,
        enterprise: 29.99,
      };

      if (tierPricing[newTier] > tierPricing[previousTier]) {
        // Upgrade - calculate prorated charge
        const priceDifference =
          tierPricing[newTier] - tierPricing[previousTier];

        // If user has active subscription, calculate days remaining
        if (user.subscription_id) {
          const subscriptionDetailsQuery = `
          SELECT current_period_start, current_period_end
          FROM subscriptions
          WHERE id = $1
        `;
          const subDetails = await pool.query(subscriptionDetailsQuery, [
            user.subscription_id,
          ]);

          if (subDetails.rows.length > 0) {
            const periodStart = new Date(
              subDetails.rows[0].current_period_start,
            );
            const periodEnd = new Date(subDetails.rows[0].current_period_end);
            const now = new Date();

            const totalDays = Math.ceil(
              (periodEnd - periodStart) / (1000 * 60 * 60 * 24),
            );
            const remainingDays = Math.ceil(
              (periodEnd - now) / (1000 * 60 * 60 * 24),
            );

            if (remainingDays > 0) {
              proratedCharge = (priceDifference * remainingDays) / totalDays;
            }
          }
        } else {
          // No existing subscription, charge full amount
          proratedCharge = tierPricing[newTier];
        }
      }

      // Begin transaction
      await pool.query('BEGIN');

      try {
        let subscriptionId;

        if (user.subscription_id) {
          // Update existing subscription
          const updateQuery = `
          UPDATE subscriptions
          SET tier = $1, updated_at = NOW()
          WHERE id = $2
          RETURNING id
        `;
          const updateResult = await pool.query(updateQuery, [
            newTier,
            user.subscription_id,
          ]);
          subscriptionId = updateResult.rows[0].id;
        } else {
          // Create new subscription
          const insertQuery = `
          INSERT INTO subscriptions (user_id, tier, status, created_at, updated_at)
          VALUES ($1, $2, 'active', NOW(), NOW())
          RETURNING id
        `;
          const insertResult = await pool.query(insertQuery, [userId, newTier]);
          subscriptionId = insertResult.rows[0].id;
        }

        // Log the action in audit log
        await logAdminAction({
          adminUserId: req.adminUser.id,
          adminRole: req.adminRoles[0],
          action: 'subscription_tier_changed',
          resourceType: 'subscription',
          resourceId: subscriptionId,
          affectedUserId: userId,
          details: {
            previousTier,
            newTier,
            proratedCharge: proratedCharge.toFixed(2),
            reason: reason || 'No reason provided',
            timestamp: new Date().toISOString(),
          },
          ipAddress: req.ip,
          userAgent: req.get('User-Agent'),
        });

        // Commit transaction
        await pool.query('COMMIT');

        logger.info('✅ [AdminUsers] User subscription tier updated', {
          adminUserId: req.adminUser.id,
          targetUserId: userId,
          previousTier,
          newTier,
          proratedCharge: proratedCharge.toFixed(2),
        });

        res.json({
          success: true,
          message: 'User subscription tier updated successfully',
          data: {
            userId,
            previousTier,
            newTier,
            proratedCharge: proratedCharge.toFixed(2),
            subscriptionId,
          },
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        // Rollback transaction on error
        await pool.query('ROLLBACK');
        throw error;
      }
    } catch (error) {
      logger.error('🔴 [AdminUsers] Failed to update user subscription', {
        adminUserId: req.adminUser?.id,
        targetUserId: req.params.userId,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to update user subscription',
        code: 'USER_UPDATE_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/users/:userId/suspend
 * Suspend a user account
 *
 * Request Body:
 * - reason: Reason for suspension (required)
 *
 * Features:
 * - Suspends user account
 * - Invalidates all active sessions
 * - Logs action in audit log
 */
router.post(
  '/:userId/suspend',
  adminRateLimiter,
  adminAuth(['suspend_users']),
  async (req, res) => {
    try {
      const pool = getPool();
      const { userId } = req.params;
      const { reason } = req.body;

      // Validate userId format
      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(userId)) {
        return res.status(400).json({
          error: 'Invalid user ID format',
          code: 'INVALID_USER_ID',
        });
      }

      // Validate reason
      if (!reason || reason.trim().length === 0) {
        return res.status(400).json({
          error: 'Suspension reason is required',
          code: 'REASON_REQUIRED',
        });
      }

      // Get user
      const userQuery = `
      SELECT id, email, is_suspended
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

      // Check if user is already suspended
      if (user.is_suspended) {
        return res.status(400).json({
          error: 'User is already suspended',
          code: 'ALREADY_SUSPENDED',
        });
      }

      // Begin transaction
      await pool.query('BEGIN');

      try {
        // Suspend user
        const suspendQuery = `
        UPDATE users
        SET is_suspended = true,
            suspended_at = NOW(),
            suspension_reason = $1
        WHERE id = $2
      `;

        await pool.query(suspendQuery, [reason.trim(), userId]);

        // Invalidate all active sessions
        const invalidateSessionsQuery = `
        UPDATE user_sessions
        SET expires_at = NOW()
        WHERE user_id = $1 AND expires_at > NOW()
      `;

        const sessionsResult = await pool.query(invalidateSessionsQuery, [
          userId,
        ]);
        const invalidatedSessions = sessionsResult.rowCount;

        // Log the action in audit log
        await logAdminAction({
          adminUserId: req.adminUser.id,
          adminRole: req.adminRoles[0],
          action: 'user_suspended',
          resourceType: 'user',
          resourceId: userId,
          affectedUserId: userId,
          details: {
            reason: reason.trim(),
            invalidatedSessions,
            previousStatus: 'active',
            newStatus: 'suspended',
            timestamp: new Date().toISOString(),
          },
          ipAddress: req.ip,
          userAgent: req.get('User-Agent'),
        });

        // Commit transaction
        await pool.query('COMMIT');

        logger.warn('⚠️ [AdminUsers] User account suspended', {
          adminUserId: req.adminUser.id,
          targetUserId: userId,
          userEmail: user.email,
          reason: reason.trim(),
          invalidatedSessions,
        });

        res.json({
          success: true,
          message: 'User account suspended successfully',
          data: {
            userId,
            email: user.email,
            suspendedAt: new Date().toISOString(),
            reason: reason.trim(),
            invalidatedSessions,
          },
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        // Rollback transaction on error
        await pool.query('ROLLBACK');
        throw error;
      }
    } catch (error) {
      logger.error('🔴 [AdminUsers] Failed to suspend user account', {
        adminUserId: req.adminUser?.id,
        targetUserId: req.params.userId,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to suspend user account',
        code: 'USER_SUSPEND_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/users/:userId/reactivate
 * Reactivate a suspended user account
 *
 * Request Body:
 * - note: Optional note about reactivation
 *
 * Features:
 * - Reactivates suspended user account
 * - Clears suspension reason
 * - Logs action in audit log
 */
router.post(
  '/:userId/reactivate',
  adminRateLimiter,
  adminAuth(['suspend_users']),
  async (req, res) => {
    try {
      const pool = getPool();
      const { userId } = req.params;
      const { note } = req.body;

      // Validate userId format
      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(userId)) {
        return res.status(400).json({
          error: 'Invalid user ID format',
          code: 'INVALID_USER_ID',
        });
      }

      // Get user
      const userQuery = `
      SELECT id, email, is_suspended, suspension_reason
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

      // Check if user is actually suspended
      if (!user.is_suspended) {
        return res.status(400).json({
          error: 'User is not suspended',
          code: 'NOT_SUSPENDED',
        });
      }

      // Begin transaction
      await pool.query('BEGIN');

      try {
        // Reactivate user
        const reactivateQuery = `
        UPDATE users
        SET is_suspended = false,
            suspended_at = NULL,
            suspension_reason = NULL
        WHERE id = $1
      `;

        await pool.query(reactivateQuery, [userId]);

        // Log the action in audit log
        await logAdminAction({
          adminUserId: req.adminUser.id,
          adminRole: req.adminRoles[0],
          action: 'user_reactivated',
          resourceType: 'user',
          resourceId: userId,
          affectedUserId: userId,
          details: {
            previousStatus: 'suspended',
            newStatus: 'active',
            previousSuspensionReason: user.suspension_reason,
            note: note || 'No note provided',
            timestamp: new Date().toISOString(),
          },
          ipAddress: req.ip,
          userAgent: req.get('User-Agent'),
        });

        // Commit transaction
        await pool.query('COMMIT');

        logger.info('✅ [AdminUsers] User account reactivated', {
          adminUserId: req.adminUser.id,
          targetUserId: userId,
          userEmail: user.email,
          previousSuspensionReason: user.suspension_reason,
        });

        res.json({
          success: true,
          message: 'User account reactivated successfully',
          data: {
            userId,
            email: user.email,
            reactivatedAt: new Date().toISOString(),
            previousSuspensionReason: user.suspension_reason,
          },
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        // Rollback transaction on error
        await pool.query('ROLLBACK');
        throw error;
      }
    } catch (error) {
      logger.error('🔴 [AdminUsers] Failed to reactivate user account', {
        adminUserId: req.adminUser?.id,
        targetUserId: req.params.userId,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to reactivate user account',
        code: 'USER_REACTIVATE_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * Close database connection pool
 * Should be called on application shutdown
 */
export async function closeUserDbPool() {
  await closePool();
}
