/**
 * Admin Dashboard Metrics API Routes
 *
 * Provides dashboard metrics and statistics for the Admin Center:
 * - Total registered users
 * - Active users (last 30 days)
 * - New user registrations (current month)
 * - Subscription tier distribution
 * - Monthly recurring revenue (MRR)
 * - Total revenue (current month)
 * - Recent payment transactions
 *
 * Security Features:
 * - Admin authentication required
 * - Comprehensive audit logging
 * - Input validation and sanitization
 */

import express from 'express';
import { adminAuth } from '../../middleware/admin-auth.js';
import logger from '../../logger.js';
import { getPool, closePool } from '../../database/db-pool.js';
import { adminReadOnlyLimiter } from '../../middleware/admin-rate-limiter.js';

const router = express.Router();

/**
 * GET /api/admin/dashboard/metrics
 * Get comprehensive dashboard metrics for Admin Center
 *
 * Returns:
 * - Total registered users
 * - Active users (last 30 days)
 * - New user registrations (current month)
 * - Subscription tier distribution
 * - Monthly recurring revenue (MRR)
 * - Total revenue (current month)
 * - Recent payment transactions (last 10)
 *
 * Requirements: 2, 11
 */
router.get('/metrics', adminReadOnlyLimiter, adminAuth(), async (req, res) => {
  try {
    const pool = getPool();

    logger.info('✅ [AdminDashboard] Dashboard metrics requested', {
      adminUserId: req.adminUser.id,
      adminRole: req.adminRoles[0],
    });

    // Calculate date ranges
    const now = new Date();
    const thirtyDaysAgo = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
    const currentMonthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const currentMonthEnd = new Date(
      now.getFullYear(),
      now.getMonth() + 1,
      0,
      23,
      59,
      59,
      999,
    );

    // 1. Get total registered users
    const totalUsersQuery = `
      SELECT COUNT(*) as total
      FROM users
      WHERE deleted_at IS NULL
    `;
    const totalUsersResult = await pool.query(totalUsersQuery);
    const totalUsers = parseInt(totalUsersResult.rows[0].total);

    // 2. Get active users (last 30 days)
    const activeUsersQuery = `
      SELECT COUNT(DISTINCT user_id) as active
      FROM user_sessions
      WHERE last_activity >= $1
    `;
    const activeUsersResult = await pool.query(activeUsersQuery, [
      thirtyDaysAgo,
    ]);
    const activeUsers = parseInt(activeUsersResult.rows[0].active);

    // 3. Get new user registrations (current month)
    const newUsersQuery = `
      SELECT COUNT(*) as new_users
      FROM users
      WHERE created_at >= $1 AND created_at <= $2
        AND deleted_at IS NULL
    `;
    const newUsersResult = await pool.query(newUsersQuery, [
      currentMonthStart,
      currentMonthEnd,
    ]);
    const newUsers = parseInt(newUsersResult.rows[0].new_users);

    // 4. Get subscription tier distribution
    const tierDistributionQuery = `
      SELECT 
        COALESCE(s.tier, 'free') as tier,
        COUNT(DISTINCT u.id) as count
      FROM users u
      LEFT JOIN subscriptions s ON u.id = s.user_id AND s.status = 'active'
      WHERE u.deleted_at IS NULL
      GROUP BY COALESCE(s.tier, 'free')
      ORDER BY tier
    `;
    const tierDistributionResult = await pool.query(tierDistributionQuery);

    const tierDistribution = {
      free: 0,
      premium: 0,
      enterprise: 0,
    };

    tierDistributionResult.rows.forEach((row) => {
      tierDistribution[row.tier] = parseInt(row.count);
    });

    // 5. Calculate monthly recurring revenue (MRR)
    const tierPricing = {
      free: 0,
      premium: 9.99,
      enterprise: 29.99,
    };

    const mrr =
      tierDistribution.premium * tierPricing.premium +
      tierDistribution.enterprise * tierPricing.enterprise;

    // 6. Get total revenue (current month)
    const revenueQuery = `
      SELECT 
        COALESCE(SUM(amount), 0) as total_revenue,
        COUNT(*) as transaction_count
      FROM payment_transactions
      WHERE status = 'succeeded'
        AND created_at >= $1
        AND created_at <= $2
    `;
    const revenueResult = await pool.query(revenueQuery, [
      currentMonthStart,
      currentMonthEnd,
    ]);
    const totalRevenue = parseFloat(revenueResult.rows[0].total_revenue);
    const transactionCount = parseInt(revenueResult.rows[0].transaction_count);

    // 7. Get recent payment transactions (last 10)
    const recentTransactionsQuery = `
      SELECT 
        pt.id,
        pt.user_id,
        u.email as user_email,
        pt.amount,
        pt.currency,
        pt.status,
        pt.payment_method_type,
        pt.payment_method_last4,
        pt.created_at,
        s.tier as subscription_tier
      FROM payment_transactions pt
      JOIN users u ON pt.user_id = u.id
      LEFT JOIN subscriptions s ON pt.subscription_id = s.id
      ORDER BY pt.created_at DESC
      LIMIT 10
    `;
    const recentTransactionsResult = await pool.query(recentTransactionsQuery);
    const recentTransactions = recentTransactionsResult.rows;

    // Compile metrics response
    const metrics = {
      users: {
        total: totalUsers,
        active: activeUsers,
        newThisMonth: newUsers,
        activePercentage:
          totalUsers > 0 ? ((activeUsers / totalUsers) * 100).toFixed(2) : 0,
      },
      subscriptions: {
        distribution: tierDistribution,
        totalSubscribed: tierDistribution.premium + tierDistribution.enterprise,
        conversionRate:
          totalUsers > 0
            ? (
                ((tierDistribution.premium + tierDistribution.enterprise) /
                  totalUsers) *
                100
              ).toFixed(2)
            : 0,
      },
      revenue: {
        mrr: mrr.toFixed(2),
        currentMonth: totalRevenue.toFixed(2),
        transactionCount,
        averageTransactionValue:
          transactionCount > 0
            ? (totalRevenue / transactionCount).toFixed(2)
            : 0,
      },
      recentTransactions: recentTransactions.map((tx) => ({
        id: tx.id,
        userId: tx.user_id,
        userEmail: tx.user_email,
        amount: parseFloat(tx.amount).toFixed(2),
        currency: tx.currency,
        status: tx.status,
        paymentMethod: tx.payment_method_type,
        last4: tx.payment_method_last4,
        subscriptionTier: tx.subscription_tier,
        createdAt: tx.created_at,
      })),
      period: {
        currentMonth: {
          start: currentMonthStart.toISOString(),
          end: currentMonthEnd.toISOString(),
        },
        last30Days: {
          start: thirtyDaysAgo.toISOString(),
          end: now.toISOString(),
        },
      },
    };

    logger.info(
      '✅ [AdminDashboard] Dashboard metrics retrieved successfully',
      {
        adminUserId: req.adminUser.id,
        totalUsers,
        activeUsers,
        mrr: mrr.toFixed(2),
        currentMonthRevenue: totalRevenue.toFixed(2),
      },
    );

    res.json({
      success: true,
      data: metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [AdminDashboard] Failed to retrieve dashboard metrics', {
      adminUserId: req.adminUser?.id,
      error: error.message,
      stack: error.stack,
    });

    res.status(500).json({
      error: 'Failed to retrieve dashboard metrics',
      code: 'DASHBOARD_METRICS_FAILED',
      details: error.message,
    });
  }
});

/**
 * Close database connection pool
 * Should be called on application shutdown
 */
export async function closeDashboardDbPool() {
  await closePool();
}

export default router;
