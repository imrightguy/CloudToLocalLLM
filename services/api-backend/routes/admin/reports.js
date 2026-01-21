/**
 * Admin Reporting API Routes
 *
 * Provides secure administrative endpoints for financial and subscription reporting:
 * - Revenue reports with date range filtering
 * - Subscription metrics (MRR, churn, retention)
 * - Report export functionality (CSV, PDF)
 *
 * Security Features:
 * - Admin authentication required
 * - Role-based permission checking (view_reports, export_reports)
 * - Comprehensive audit logging
 * - Input validation and sanitization
 */

import express from 'express';
import { adminAuth } from '../../middleware/admin-auth.js';
import { logAdminAction } from '../../utils/audit-logger.js';
import logger from '../../logger.js';
import { getPool } from '../../database/db-pool.js';
import {
  adminReadOnlyLimiter,
  adminExpensiveLimiter,
} from '../../middleware/admin-rate-limiter.js';

const router = express.Router();

/**
 * GET /api/admin/reports/revenue
 * Generate revenue report for specified date range
 * Rate limit: Read-only (200 req/min) - report generation is cached
 *
 * Query Parameters:
 * - startDate: Start date for report (ISO 8601 format, required)
 * - endDate: End date for report (ISO 8601 format, required)
 * - groupBy: Group results by tier (optional, default: false)
 *
 * Response:
 * - totalRevenue: Total revenue in the date range
 * - transactionCount: Number of successful transactions
 * - averageTransactionValue: Average transaction amount
 * - revenueByTier: Revenue breakdown by subscription tier (if groupBy=true)
 * - period: Date range of the report
 */
router.get(
  '/revenue',
  adminReadOnlyLimiter,
  adminAuth(['view_reports']),
  async (req, res) => {
    try {
      const pool = getPool();

      // Validate required parameters
      const { startDate, endDate } = req.query;

      if (!startDate || !endDate) {
        return res.status(400).json({
          error: 'Missing required parameters',
          message: 'Both startDate and endDate are required',
          example:
            '/api/admin/reports/revenue?startDate=2025-01-01&endDate=2025-01-31',
        });
      }

      // Parse and validate dates
      const start = new Date(startDate);
      const end = new Date(endDate);

      if (isNaN(start.getTime()) || isNaN(end.getTime())) {
        return res.status(400).json({
          error: 'Invalid date format',
          message:
            'Dates must be in ISO 8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss.sssZ)',
        });
      }

      if (start > end) {
        return res.status(400).json({
          error: 'Invalid date range',
          message: 'startDate must be before or equal to endDate',
        });
      }

      // Check if date range exceeds 1 year
      const oneYearInMs = 365 * 24 * 60 * 60 * 1000;
      if (end - start > oneYearInMs) {
        return res.status(400).json({
          error: 'Date range too large',
          message: 'Date range cannot exceed 1 year',
        });
      }

      const groupBy = req.query.groupBy === 'true';

      logger.info('[AdminReports] Generating revenue report', {
        adminUserId: req.adminUser.id,
        startDate,
        endDate,
        groupBy,
      });

      // Query for overall revenue metrics
      const overallQuery = `
      SELECT 
        COUNT(*) as transaction_count,
        COALESCE(SUM(amount), 0) as total_revenue,
        COALESCE(AVG(amount), 0) as average_transaction_value
      FROM payment_transactions
      WHERE status = 'succeeded'
        AND created_at >= $1
        AND created_at <= $2
    `;

      const overallResult = await pool.query(overallQuery, [start, end]);
      const overallMetrics = overallResult.rows[0];

      // Build response
      const response = {
        period: {
          startDate: start.toISOString(),
          endDate: end.toISOString(),
        },
        totalRevenue: parseFloat(overallMetrics.total_revenue),
        transactionCount: parseInt(overallMetrics.transaction_count),
        averageTransactionValue: parseFloat(
          overallMetrics.average_transaction_value
        ),
      };

      // If groupBy is requested, add revenue breakdown by tier
      if (groupBy) {
        const tierQuery = `
        SELECT 
          COALESCE(s.tier, 'unknown') as tier,
          COUNT(pt.id) as transaction_count,
          COALESCE(SUM(pt.amount), 0) as total_revenue,
          COALESCE(AVG(pt.amount), 0) as average_transaction_value
        FROM payment_transactions pt
        LEFT JOIN subscriptions s ON pt.subscription_id = s.id
        WHERE pt.status = 'succeeded'
          AND pt.created_at >= $1
          AND pt.created_at <= $2
        GROUP BY s.tier
        ORDER BY total_revenue DESC
      `;

        const tierResult = await pool.query(tierQuery, [start, end]);

        response.revenueByTier = tierResult.rows.map((row) => ({
          tier: row.tier,
          transactionCount: parseInt(row.transaction_count),
          totalRevenue: parseFloat(row.total_revenue),
          averageTransactionValue: parseFloat(row.average_transaction_value),
        }));
      }

      // Log the report generation
      await logAdminAction(pool, {
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'report_generated',
        resourceType: 'report',
        resourceId: 'revenue',
        details: {
          startDate,
          endDate,
          groupBy,
          totalRevenue: response.totalRevenue,
          transactionCount: response.transactionCount,
        },
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });

      logger.info('[AdminReports] Revenue report generated successfully', {
        adminUserId: req.adminUser.id,
        totalRevenue: response.totalRevenue,
        transactionCount: response.transactionCount,
      });

      res.json(response);
    } catch (error) {
      logger.error('[AdminReports] Error generating revenue report', {
        error: error.message,
        stack: error.stack,
        adminUserId: req.adminUser?.id,
      });

      res.status(500).json({
        error: 'Failed to generate revenue report',
        message: error.message,
      });
    }
  }
);

export default router;

/**
 * GET /api/admin/reports/subscriptions
 * Generate subscription metrics report
 *
 * Query Parameters:
 * - startDate: Start date for report (ISO 8601 format, optional, defaults to 30 days ago)
 * - endDate: End date for report (ISO 8601 format, optional, defaults to now)
 * - groupBy: Group results by tier (optional, default: true)
 *
 * Response:
 * - monthlyRecurringRevenue: Current MRR across all active subscriptions
 * - churnRate: Percentage of subscriptions canceled in the period
 * - retentionRate: Percentage of subscriptions retained
 * - activeSubscriptions: Count of currently active subscriptions
 * - canceledSubscriptions: Count of subscriptions canceled in period
 * - newSubscriptions: Count of new subscriptions in period
 * - subscriptionsByTier: Breakdown by subscription tier (if groupBy=true)
 * - period: Date range of the report
 */
router.get(
  '/subscriptions',
  adminReadOnlyLimiter,
  adminAuth(['view_reports']),
  async (req, res) => {
    try {
      const pool = getPool();

      // Parse and validate dates (default to last 30 days)
      const endDate = req.query.endDate
        ? new Date(req.query.endDate)
        : new Date();
      const startDate = req.query.startDate
        ? new Date(req.query.startDate)
        : new Date(endDate.getTime() - 30 * 24 * 60 * 60 * 1000);

      if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
        return res.status(400).json({
          error: 'Invalid date format',
          message:
            'Dates must be in ISO 8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss.sssZ)',
        });
      }

      if (startDate > endDate) {
        return res.status(400).json({
          error: 'Invalid date range',
          message: 'startDate must be before or equal to endDate',
        });
      }

      const groupBy = req.query.groupBy !== 'false'; // Default to true

      logger.info('[AdminReports] Generating subscription metrics report', {
        adminUserId: req.adminUser.id,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        groupBy,
      });

      // Query for active subscriptions count
      const activeQuery = `
      SELECT COUNT(*) as count
      FROM subscriptions
      WHERE status = 'active'
    `;
      const activeResult = await pool.query(activeQuery);
      const activeSubscriptions = parseInt(activeResult.rows[0].count);

      // Query for subscriptions at the start of the period
      const startPeriodQuery = `
      SELECT COUNT(*) as count
      FROM subscriptions
      WHERE created_at < $1
        AND (canceled_at IS NULL OR canceled_at >= $1)
    `;
      const startPeriodResult = await pool.query(startPeriodQuery, [startDate]);
      const subscriptionsAtStart = parseInt(startPeriodResult.rows[0].count);

      // Query for new subscriptions in the period
      const newQuery = `
      SELECT COUNT(*) as count
      FROM subscriptions
      WHERE created_at >= $1
        AND created_at <= $2
    `;
      const newResult = await pool.query(newQuery, [startDate, endDate]);
      const newSubscriptions = parseInt(newResult.rows[0].count);

      // Query for canceled subscriptions in the period
      const canceledQuery = `
      SELECT COUNT(*) as count
      FROM subscriptions
      WHERE canceled_at >= $1
        AND canceled_at <= $2
    `;
      const canceledResult = await pool.query(canceledQuery, [
        startDate,
        endDate,
      ]);
      const canceledSubscriptions = parseInt(canceledResult.rows[0].count);

      // Calculate churn rate and retention rate
      // Churn rate = (canceled subscriptions / subscriptions at start) * 100
      // Retention rate = 100 - churn rate
      const churnRate =
        subscriptionsAtStart > 0
          ? (canceledSubscriptions / subscriptionsAtStart) * 100
          : 0;
      const retentionRate = 100 - churnRate;

      // Calculate MRR (Monthly Recurring Revenue)
      // For simplicity, we'll estimate based on successful transactions in the last 30 days
      const mrrQuery = `
      SELECT 
        COALESCE(SUM(amount), 0) as total_revenue,
        COUNT(DISTINCT user_id) as paying_users
      FROM payment_transactions
      WHERE status = 'succeeded'
        AND created_at >= NOW() - INTERVAL '30 days'
    `;
      const mrrResult = await pool.query(mrrQuery);
      const mrrData = mrrResult.rows[0];
      const monthlyRecurringRevenue = parseFloat(mrrData.total_revenue);

      // Build response
      const response = {
        period: {
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString(),
        },
        monthlyRecurringRevenue,
        churnRate: parseFloat(churnRate.toFixed(2)),
        retentionRate: parseFloat(retentionRate.toFixed(2)),
        activeSubscriptions,
        canceledSubscriptions,
        newSubscriptions,
        metrics: {
          subscriptionsAtPeriodStart: subscriptionsAtStart,
          subscriptionsAtPeriodEnd:
            subscriptionsAtStart + newSubscriptions - canceledSubscriptions,
          netChange: newSubscriptions - canceledSubscriptions,
        },
      };

      // If groupBy is requested, add breakdown by tier
      if (groupBy) {
        const tierQuery = `
        SELECT 
          tier,
          COUNT(*) as total_count,
          SUM(CASE WHEN status = 'active' THEN 1 ELSE 0 END) as active_count,
          SUM(CASE WHEN canceled_at >= $1 AND canceled_at <= $2 THEN 1 ELSE 0 END) as canceled_count,
          SUM(CASE WHEN created_at >= $1 AND created_at <= $2 THEN 1 ELSE 0 END) as new_count
        FROM subscriptions
        GROUP BY tier
        ORDER BY tier
      `;

        const tierResult = await pool.query(tierQuery, [startDate, endDate]);

        response.subscriptionsByTier = tierResult.rows.map((row) => ({
          tier: row.tier,
          totalCount: parseInt(row.total_count),
          activeCount: parseInt(row.active_count),
          canceledCount: parseInt(row.canceled_count),
          newCount: parseInt(row.new_count),
        }));

        // Calculate MRR by tier
        const mrrByTierQuery = `
        SELECT 
          COALESCE(s.tier, 'unknown') as tier,
          COALESCE(SUM(pt.amount), 0) as revenue
        FROM payment_transactions pt
        LEFT JOIN subscriptions s ON pt.subscription_id = s.id
        WHERE pt.status = 'succeeded'
          AND pt.created_at >= NOW() - INTERVAL '30 days'
        GROUP BY s.tier
        ORDER BY revenue DESC
      `;

        const mrrByTierResult = await pool.query(mrrByTierQuery);

        response.mrrByTier = mrrByTierResult.rows.map((row) => ({
          tier: row.tier,
          monthlyRecurringRevenue: parseFloat(row.revenue),
        }));
      }

      // Log the report generation
      await logAdminAction(pool, {
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'report_generated',
        resourceType: 'report',
        resourceId: 'subscriptions',
        details: {
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString(),
          groupBy,
          activeSubscriptions,
          churnRate: response.churnRate,
          mrr: monthlyRecurringRevenue,
        },
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });

      logger.info(
        '[AdminReports] Subscription metrics report generated successfully',
        {
          adminUserId: req.adminUser.id,
          activeSubscriptions,
          churnRate: response.churnRate,
          mrr: monthlyRecurringRevenue,
        }
      );

      res.json(response);
    } catch (error) {
      logger.error(
        '[AdminReports] Error generating subscription metrics report',
        {
          error: error.message,
          stack: error.stack,
          adminUserId: req.adminUser?.id,
        }
      );

      res.status(500).json({
        error: 'Failed to generate subscription metrics report',
        message: error.message,
      });
    }
  }
);

/**
 * Helper function to convert data to CSV format
 */
function convertToCSV(data, headers) {
  if (!data || data.length === 0) {
    return headers.join(',') + '\n';
  }

  const csvRows = [];

  // Add headers
  csvRows.push(headers.join(','));

  // Add data rows
  for (const row of data) {
    const values = headers.map((header) => {
      const value = row[header];
      // Escape quotes and wrap in quotes if contains comma or quote
      if (value === null || value === undefined) {
        return '';
      }
      const stringValue = String(value);
      if (
        stringValue.includes(',') ||
        stringValue.includes('"') ||
        stringValue.includes('\n')
      ) {
        return `"${stringValue.replace(/"/g, '""')}"`;
      }
      return stringValue;
    });
    csvRows.push(values.join(','));
  }

  return csvRows.join('\n');
}

/**
 * Helper function to generate revenue report data for export
 */
async function generateRevenueReportData(pool, startDate, endDate) {
  const query = `
    SELECT 
      pt.id,
      pt.created_at,
      u.email as user_email,
      u.username,
      pt.amount,
      pt.currency,
      pt.status,
      COALESCE(s.tier, 'N/A') as subscription_tier,
      pt.payment_method_type,
      pt.payment_method_last4
    FROM payment_transactions pt
    JOIN users u ON pt.user_id = u.id
    LEFT JOIN subscriptions s ON pt.subscription_id = s.id
    WHERE pt.status = 'succeeded'
      AND pt.created_at >= $1
      AND pt.created_at <= $2
    ORDER BY pt.created_at DESC
  `;

  const result = await pool.query(query, [startDate, endDate]);
  return result.rows;
}

/**
 * Helper function to generate subscription report data for export
 */
async function generateSubscriptionReportData(pool, startDate, endDate) {
  const query = `
    SELECT 
      s.id,
      s.created_at,
      u.email as user_email,
      u.username,
      s.tier,
      s.status,
      s.current_period_start,
      s.current_period_end,
      s.canceled_at,
      s.cancel_at_period_end
    FROM subscriptions s
    JOIN users u ON s.user_id = u.id
    WHERE s.created_at >= $1
      AND s.created_at <= $2
    ORDER BY s.created_at DESC
  `;

  const result = await pool.query(query, [startDate, endDate]);
  return result.rows;
}

/**
 * Helper function to generate transaction report data for export
 */
async function generateTransactionReportData(pool, startDate, endDate) {
  const query = `
    SELECT 
      pt.id,
      pt.created_at,
      u.email as user_email,
      u.username,
      pt.amount,
      pt.currency,
      pt.status,
      pt.payment_method_type,
      pt.payment_method_last4,
      pt.stripe_payment_intent_id,
      COALESCE(s.tier, 'N/A') as subscription_tier
    FROM payment_transactions pt
    JOIN users u ON pt.user_id = u.id
    LEFT JOIN subscriptions s ON pt.subscription_id = s.id
    WHERE pt.created_at >= $1
      AND pt.created_at <= $2
    ORDER BY pt.created_at DESC
  `;

  const result = await pool.query(query, [startDate, endDate]);
  return result.rows;
}

/**
 * GET /api/admin/reports/export
 * Export report data in CSV or PDF format
 *
 * Query Parameters:
 * - type: Report type (revenue, subscriptions, transactions) - required
 * - format: Export format (csv, pdf) - required
 * - startDate: Start date for report (ISO 8601 format, required)
 * - endDate: End date for report (ISO 8601 format, required)
 *
 * Response:
 * - Streams file download with appropriate content type
 * - CSV: text/csv
 * - PDF: application/pdf (placeholder - returns CSV for now)
 */
router.get(
  '/export',
  adminExpensiveLimiter,
  adminAuth(['export_reports']),
  async (req, res) => {
    try {
      const pool = getPool();

      // Validate required parameters
      const { type, format, startDate, endDate } = req.query;

      if (!type || !format || !startDate || !endDate) {
        return res.status(400).json({
          error: 'Missing required parameters',
          message: 'type, format, startDate, and endDate are required',
          example:
            '/api/admin/reports/export?type=revenue&format=csv&startDate=2025-01-01&endDate=2025-01-31',
        });
      }

      // Validate report type
      const validTypes = ['revenue', 'subscriptions', 'transactions'];
      if (!validTypes.includes(type)) {
        return res.status(400).json({
          error: 'Invalid report type',
          message: `Report type must be one of: ${validTypes.join(', ')}`,
        });
      }

      // Validate format
      const validFormats = ['csv', 'pdf'];
      if (!validFormats.includes(format)) {
        return res.status(400).json({
          error: 'Invalid format',
          message: `Format must be one of: ${validFormats.join(', ')}`,
        });
      }

      // Parse and validate dates
      const start = new Date(startDate);
      const end = new Date(endDate);

      if (isNaN(start.getTime()) || isNaN(end.getTime())) {
        return res.status(400).json({
          error: 'Invalid date format',
          message:
            'Dates must be in ISO 8601 format (YYYY-MM-DD or YYYY-MM-DDTHH:mm:ss.sssZ)',
        });
      }

      if (start > end) {
        return res.status(400).json({
          error: 'Invalid date range',
          message: 'startDate must be before or equal to endDate',
        });
      }

      logger.info('[AdminReports] Exporting report', {
        adminUserId: req.adminUser.id,
        type,
        format,
        startDate,
        endDate,
      });

      // Generate report data based on type
      let reportData;
      let headers;
      let filename;

      switch (type) {
        case 'revenue':
          reportData = await generateRevenueReportData(pool, start, end);
          headers = [
            'id',
            'created_at',
            'user_email',
            'username',
            'amount',
            'currency',
            'status',
            'subscription_tier',
            'payment_method_type',
            'payment_method_last4',
          ];
          filename = `revenue_report_${startDate}_${endDate}`;
          break;

        case 'subscriptions':
          reportData = await generateSubscriptionReportData(pool, start, end);
          headers = [
            'id',
            'created_at',
            'user_email',
            'username',
            'tier',
            'status',
            'current_period_start',
            'current_period_end',
            'canceled_at',
            'cancel_at_period_end',
          ];
          filename = `subscription_report_${startDate}_${endDate}`;
          break;

        case 'transactions':
          reportData = await generateTransactionReportData(pool, start, end);
          headers = [
            'id',
            'created_at',
            'user_email',
            'username',
            'amount',
            'currency',
            'status',
            'payment_method_type',
            'payment_method_last4',
            'stripe_payment_intent_id',
            'subscription_tier',
          ];
          filename = `transaction_report_${startDate}_${endDate}`;
          break;
      }

      // Export based on format
      if (format === 'csv') {
        const csv = convertToCSV(reportData, headers);

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader(
          'Content-Disposition',
          `attachment; filename="${filename}.csv"`
        );
        res.send(csv);
      } else if (format === 'pdf') {
        // PDF export is a placeholder for now
        // In a production environment, you would use a library like pdfkit or puppeteer
        // For now, we'll return CSV with a note
        const csv = convertToCSV(reportData, headers);

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader(
          'Content-Disposition',
          `attachment; filename="${filename}.csv"`
        );
        res.setHeader(
          'X-PDF-Note',
          'PDF export not yet implemented, returning CSV format'
        );
        res.send(csv);
      }

      // Log the export action
      await logAdminAction(pool, {
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'report_exported',
        resourceType: 'report',
        resourceId: type,
        details: {
          type,
          format,
          startDate,
          endDate,
          recordCount: reportData.length,
        },
        ipAddress: req.ip,
        userAgent: req.get('user-agent'),
      });

      logger.info('[AdminReports] Report exported successfully', {
        adminUserId: req.adminUser.id,
        type,
        format,
        recordCount: reportData.length,
      });
    } catch (error) {
      logger.error('[AdminReports] Error exporting report', {
        error: error.message,
        stack: error.stack,
        adminUserId: req.adminUser?.id,
      });

      res.status(500).json({
        error: 'Failed to export report',
        message: error.message,
      });
    }
  }
);
