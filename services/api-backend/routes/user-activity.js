/**
 * User Activity Tracking API Routes
 *
 * Provides user-facing endpoints for:
 * - Retrieving user activity logs
 * - Viewing usage metrics
 * - Accessing activity summaries
 *
 * All endpoints require authentication via JWT token.
 *
 * Validates: Requirements 3.4, 3.10
 * - Tracks user activity and usage metrics
 * - Implements activity audit logs
 * - Provides user activity audit logs
 *
 * @fileoverview User activity tracking endpoints
 * @version 1.0.0
 */

import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import {
  getUserActivityLogs,
  getUserActivityLogsCount,
  getUserUsageMetrics,
  getUserActivitySummary,
} from '../services/user-activity-service.js';
import logger from '../logger.js';

const router = express.Router();

/**
 * GET /api/users/activity
 *
 * Get current user's activity logs
 *
 * Query Parameters:
 * - limit: Maximum number of logs to return (default: 50, max: 500)
 * - offset: Offset for pagination (default: 0)
 * - action: Filter by action type (optional)
 * - resourceType: Filter by resource type (optional)
 * - startDate: Filter by start date (optional, ISO 8601 format)
 * - endDate: Filter by end date (optional, ISO 8601 format)
 *
 * Returns:
 * - Array of activity log entries
 * - Total count of matching logs
 * - Pagination information
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/activity', authenticateJWT, async function (req, res) {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to access activity logs',
      });
    }

    const userId = req.user.sub;
    const limit = Math.min(parseInt(req.query.limit) || 50, 500);
    const offset = parseInt(req.query.offset) || 0;
    const action = req.query.action || null;
    const resourceType = req.query.resourceType || null;
    const startDate = req.query.startDate || null;
    const endDate = req.query.endDate || null;

    // Validate pagination parameters
    if (limit < 1 || limit > 500) {
      return res.status(400).json({
        error: 'Invalid limit',
        code: 'INVALID_LIMIT',
        message: 'Limit must be between 1 and 500',
      });
    }

    if (offset < 0) {
      return res.status(400).json({
        error: 'Invalid offset',
        code: 'INVALID_OFFSET',
        message: 'Offset must be non-negative',
      });
    }

    // Get activity logs
    const logs = await getUserActivityLogs(userId, {
      limit,
      offset,
      action,
      resourceType,
      startDate,
      endDate,
    });

    // Get total count
    const total = await getUserActivityLogsCount(userId, {
      action,
      resourceType,
      startDate,
      endDate,
    });

    logger.debug('[UserActivityRoutes] Activity logs retrieved', {
      userId,
      count: logs.length,
      total,
    });

    res.json({
      success: true,
      data: logs,
      pagination: {
        limit,
        offset,
        total,
        hasMore: offset + limit < total,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserActivityRoutes] Error retrieving activity logs', {
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to retrieve activity logs',
      code: 'ACTIVITY_LOGS_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/users/metrics
 *
 * Get current user's usage metrics
 *
 * Returns:
 * - Total requests
 * - Total API calls
 * - Total tunnels created
 * - Total tunnels active
 * - Total data transferred
 * - Last activity timestamp
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/metrics', authenticateJWT, async function (req, res) {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to access usage metrics',
      });
    }

    const userId = req.user.sub;

    // Get usage metrics
    const metrics = await getUserUsageMetrics(userId);

    if (!metrics) {
      return res.json({
        success: true,
        data: {
          userId,
          totalRequests: 0,
          totalApiCalls: 0,
          totalTunnelsCreated: 0,
          totalTunnelsActive: 0,
          totalDataTransferredBytes: 0,
          lastActivity: null,
          createdAt: null,
          updatedAt: null,
        },
        timestamp: new Date().toISOString(),
      });
    }

    logger.debug('[UserActivityRoutes] Usage metrics retrieved', {
      userId,
    });

    res.json({
      success: true,
      data: {
        userId: metrics.user_id,
        totalRequests: metrics.total_requests,
        totalApiCalls: metrics.total_api_calls,
        totalTunnelsCreated: metrics.total_tunnels_created,
        totalTunnelsActive: metrics.total_tunnels_active,
        totalDataTransferredBytes: metrics.total_data_transferred_bytes,
        lastActivity: metrics.last_activity,
        createdAt: metrics.created_at,
        updatedAt: metrics.updated_at,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserActivityRoutes] Error retrieving usage metrics', {
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to retrieve usage metrics',
      code: 'METRICS_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /api/users/activity/summary
 *
 * Get current user's activity summary for a period
 *
 * Query Parameters:
 * - period: Period type ('daily', 'weekly', 'monthly') (default: 'daily')
 * - startDate: Start date for summary (optional, ISO 8601 format)
 * - endDate: End date for summary (optional, ISO 8601 format)
 *
 * Returns:
 * - Array of activity summary entries
 * - Aggregated metrics for each period
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/activity/summary', authenticateJWT, async function (req, res) {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to access activity summary',
      });
    }

    const userId = req.user.sub;
    const period = req.query.period || 'daily';
    const startDate = req.query.startDate || null;
    const endDate = req.query.endDate || null;

    // Validate period parameter
    if (!['daily', 'weekly', 'monthly'].includes(period)) {
      return res.status(400).json({
        error: 'Invalid period',
        code: 'INVALID_PERIOD',
        message: 'Period must be one of: daily, weekly, monthly',
      });
    }

    // Get activity summary
    const summary = await getUserActivitySummary(userId, {
      period,
      startDate,
      endDate,
    });

    logger.debug('[UserActivityRoutes] Activity summary retrieved', {
      userId,
      period,
      count: summary.length,
    });

    res.json({
      success: true,
      data: summary,
      period,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserActivityRoutes] Error retrieving activity summary', {
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to retrieve activity summary',
      code: 'SUMMARY_ERROR',
      message: error.message,
    });
  }
});

export default router;
