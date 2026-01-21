/**
 * User Activity Tracking Service for CloudToLocalLLM API Backend
 *
 * Provides comprehensive logging of user operations, usage metrics tracking,
 * and activity audit logs for analytics and compliance purposes.
 *
 * Validates: Requirements 3.4, 3.10
 * - Tracks user activity and usage metrics
 * - Implements activity audit logs
 * - Provides user activity audit logs
 */

import logger from '../logger.js';
import { query } from '../database/db-pool.js';

/**
 * User activity action types
 */
export const ACTIVITY_ACTIONS = {
  // User profile actions
  PROFILE_VIEW: 'profile_view',
  PROFILE_UPDATE: 'profile_update',
  PROFILE_DELETE: 'profile_delete',
  AVATAR_UPLOAD: 'avatar_upload',
  PREFERENCES_UPDATE: 'preferences_update',

  // Tunnel actions
  TUNNEL_CREATE: 'tunnel_create',
  TUNNEL_START: 'tunnel_start',
  TUNNEL_STOP: 'tunnel_stop',
  TUNNEL_DELETE: 'tunnel_delete',
  TUNNEL_UPDATE: 'tunnel_update',
  TUNNEL_STATUS_CHECK: 'tunnel_status_check',

  // API actions
  API_KEY_CREATE: 'api_key_create',
  API_KEY_DELETE: 'api_key_delete',
  API_KEY_ROTATE: 'api_key_rotate',

  // Session actions
  SESSION_CREATE: 'session_create',
  SESSION_DESTROY: 'session_destroy',
  SESSION_REFRESH: 'session_refresh',

  // Admin actions
  ADMIN_USER_VIEW: 'admin_user_view',
  ADMIN_USER_UPDATE: 'admin_user_update',
  ADMIN_USER_DELETE: 'admin_user_delete',
  ADMIN_TIER_CHANGE: 'admin_tier_change',
};

/**
 * Severity levels for activity logs
 */
export const SEVERITY_LEVELS = {
  DEBUG: 'debug',
  INFO: 'info',
  WARN: 'warn',
  ERROR: 'error',
  CRITICAL: 'critical',
};

/**
 * Log user activity
 *
 * @param {Object} options - Activity logging options
 * @param {string} options.userId - User ID
 * @param {string} options.action - Activity action type
 * @param {string} options.resourceType - Type of resource affected (optional)
 * @param {string} options.resourceId - ID of resource affected (optional)
 * @param {string} options.ipAddress - Client IP address
 * @param {string} options.userAgent - Client user agent string
 * @param {Object} options.details - Additional activity details
 * @param {string} options.severity - Severity level (default: 'info')
 * @returns {Promise<Object>} Activity log entry
 */
export async function logUserActivity(options = {}) {
  const {
    userId,
    action,
    resourceType = null,
    resourceId = null,
    ipAddress,
    userAgent,
    details = {},
    severity = SEVERITY_LEVELS.INFO,
  } = options;

  if (!userId) {
    throw new Error('userId is required');
  }

  if (!action) {
    throw new Error('action is required');
  }

  if (!ipAddress) {
    throw new Error('ipAddress is required');
  }

  try {
    // Insert into user_activity_logs table
    const result = await query(
      `INSERT INTO user_activity_logs (user_id, action, resource_type, resource_id, details, ip_address, user_agent, severity)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, created_at`,
      [
        userId,
        action,
        resourceType,
        resourceId,
        JSON.stringify(details),
        ipAddress,
        userAgent,
        severity,
      ],
    );

    const activityLog = result.rows[0];

    // Log to application logger
    logger.debug('[UserActivity] Activity logged', {
      userId,
      action,
      resourceType,
      resourceId,
      activityLogId: activityLog.id,
      timestamp: activityLog.created_at,
    });

    // Update usage metrics asynchronously (don't wait for it)
    updateUserUsageMetrics(userId).catch((error) => {
      logger.error('[UserActivity] Failed to update usage metrics', {
        error: error.message,
        userId,
      });
    });

    return activityLog;
  } catch (error) {
    logger.error('[UserActivity] Failed to log user activity', {
      error: error.message,
      userId,
      action,
    });

    // Don't throw - activity logging failure shouldn't break the operation
    return null;
  }
}

/**
 * Update user usage metrics
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} Updated metrics
 */
export async function updateUserUsageMetrics(userId) {
  if (!userId) {
    throw new Error('userId is required');
  }

  try {
    // Check if metrics record exists
    const existingResult = await query(
      'SELECT id FROM user_usage_metrics WHERE user_id = $1',
      [userId],
    );

    if (existingResult.rows.length === 0) {
      // Create new metrics record
      const result = await query(
        `INSERT INTO user_usage_metrics (user_id, total_requests, total_api_calls, total_tunnels_created, total_tunnels_active, last_activity)
         VALUES ($1, 1, 0, 0, 0, NOW())
         RETURNING id, user_id, total_requests, last_activity`,
        [userId],
      );

      return result.rows[0];
    } else {
      // Update existing metrics record
      const result = await query(
        `UPDATE user_usage_metrics 
         SET total_requests = total_requests + 1, last_activity = NOW()
         WHERE user_id = $1
         RETURNING id, user_id, total_requests, last_activity`,
        [userId],
      );

      return result.rows[0];
    }
  } catch (error) {
    logger.error('[UserActivity] Failed to update usage metrics', {
      error: error.message,
      userId,
    });

    throw error;
  }
}

/**
 * Get user activity logs
 *
 * @param {string} userId - User ID
 * @param {Object} options - Query options
 * @param {number} options.limit - Maximum number of logs to return (default: 50)
 * @param {number} options.offset - Offset for pagination (default: 0)
 * @param {string} options.action - Filter by action type (optional)
 * @param {string} options.resourceType - Filter by resource type (optional)
 * @param {string} options.startDate - Filter by start date (optional)
 * @param {string} options.endDate - Filter by end date (optional)
 * @returns {Promise<Array>} Activity log entries
 */
export async function getUserActivityLogs(userId, options = {}) {
  const {
    limit = 50,
    offset = 0,
    action = null,
    resourceType = null,
    startDate = null,
    endDate = null,
  } = options;

  if (!userId) {
    throw new Error('userId is required');
  }

  try {
    let sql = `SELECT id, user_id, action, resource_type, resource_id, details, ip_address, user_agent, severity, created_at
               FROM user_activity_logs
               WHERE user_id = $1`;
    const params = [userId];
    let paramIndex = 2;

    // Add action filter
    if (action) {
      sql += ` AND action = $${paramIndex}`;
      params.push(action);
      paramIndex++;
    }

    // Add resource type filter
    if (resourceType) {
      sql += ` AND resource_type = $${paramIndex}`;
      params.push(resourceType);
      paramIndex++;
    }

    // Add date range filters
    if (startDate) {
      sql += ` AND created_at >= $${paramIndex}`;
      params.push(startDate);
      paramIndex++;
    }

    if (endDate) {
      sql += ` AND created_at <= $${paramIndex}`;
      params.push(endDate);
      paramIndex++;
    }

    // Add ordering and pagination
    sql += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(limit, offset);

    const result = await query(sql, params);
    return result.rows;
  } catch (error) {
    logger.error('[UserActivity] Failed to get activity logs', {
      error: error.message,
      userId,
    });

    throw error;
  }
}

/**
 * Get user activity logs count
 *
 * @param {string} userId - User ID
 * @param {Object} options - Query options
 * @param {string} options.action - Filter by action type (optional)
 * @param {string} options.resourceType - Filter by resource type (optional)
 * @param {string} options.startDate - Filter by start date (optional)
 * @param {string} options.endDate - Filter by end date (optional)
 * @returns {Promise<number>} Total count of activity logs
 */
export async function getUserActivityLogsCount(userId, options = {}) {
  const {
    action = null,
    resourceType = null,
    startDate = null,
    endDate = null,
  } = options;

  if (!userId) {
    throw new Error('userId is required');
  }

  try {
    let sql =
      'SELECT COUNT(*) as count FROM user_activity_logs WHERE user_id = $1';
    const params = [userId];
    let paramIndex = 2;

    // Add action filter
    if (action) {
      sql += ` AND action = $${paramIndex}`;
      params.push(action);
      paramIndex++;
    }

    // Add resource type filter
    if (resourceType) {
      sql += ` AND resource_type = $${paramIndex}`;
      params.push(resourceType);
      paramIndex++;
    }

    // Add date range filters
    if (startDate) {
      sql += ` AND created_at >= $${paramIndex}`;
      params.push(startDate);
      paramIndex++;
    }

    if (endDate) {
      sql += ` AND created_at <= $${paramIndex}`;
      params.push(endDate);
      paramIndex++;
    }

    const result = await query(sql, params);
    return parseInt(result.rows[0].count, 10);
  } catch (error) {
    logger.error('[UserActivity] Failed to get activity logs count', {
      error: error.message,
      userId,
    });

    throw error;
  }
}

/**
 * Get user usage metrics
 *
 * @param {string} userId - User ID
 * @returns {Promise<Object>} User usage metrics
 */
export async function getUserUsageMetrics(userId) {
  if (!userId) {
    throw new Error('userId is required');
  }

  try {
    const result = await query(
      `SELECT id, user_id, total_requests, total_api_calls, total_tunnels_created, total_tunnels_active, 
              total_data_transferred_bytes, last_activity, created_at, updated_at, metadata
       FROM user_usage_metrics
       WHERE user_id = $1`,
      [userId],
    );

    if (result.rows.length === 0) {
      return null;
    }

    return result.rows[0];
  } catch (error) {
    logger.error('[UserActivity] Failed to get usage metrics', {
      error: error.message,
      userId,
    });

    throw error;
  }
}

/**
 * Get user activity summary for a period
 *
 * @param {string} userId - User ID
 * @param {Object} options - Query options
 * @param {string} options.period - Period type ('daily', 'weekly', 'monthly')
 * @param {string} options.startDate - Start date for summary
 * @param {string} options.endDate - End date for summary
 * @returns {Promise<Array>} Activity summary entries
 */
export async function getUserActivitySummary(userId, options = {}) {
  const { period = 'daily', startDate = null, endDate = null } = options;

  if (!userId) {
    throw new Error('userId is required');
  }

  if (!['daily', 'weekly', 'monthly'].includes(period)) {
    throw new Error('period must be one of: daily, weekly, monthly');
  }

  try {
    let sql = `SELECT id, user_id, period, period_start, period_end, total_actions, total_api_calls, 
                      total_tunnels_created, total_data_transferred_bytes, created_at, updated_at
               FROM user_activity_summary
               WHERE user_id = $1 AND period = $2`;
    const params = [userId, period];
    let paramIndex = 3;

    // Add date range filters
    if (startDate) {
      sql += ` AND period_start >= $${paramIndex}`;
      params.push(startDate);
      paramIndex++;
    }

    if (endDate) {
      sql += ` AND period_end <= $${paramIndex}`;
      params.push(endDate);
      paramIndex++;
    }

    // Add ordering
    sql += ' ORDER BY period_start DESC';

    const result = await query(sql, params);
    return result.rows;
  } catch (error) {
    logger.error('[UserActivity] Failed to get activity summary', {
      error: error.message,
      userId,
      period,
    });

    throw error;
  }
}

/**
 * Get all user activity logs for admin review
 *
 * @param {Object} options - Query options
 * @param {number} options.limit - Maximum number of logs to return (default: 100)
 * @param {number} options.offset - Offset for pagination (default: 0)
 * @param {string} options.action - Filter by action type (optional)
 * @param {string} options.severity - Filter by severity (optional)
 * @param {string} options.startDate - Filter by start date (optional)
 * @param {string} options.endDate - Filter by end date (optional)
 * @returns {Promise<Array>} Activity log entries
 */
export async function getAllUserActivityLogs(options = {}) {
  const {
    limit = 100,
    offset = 0,
    action = null,
    severity = null,
    startDate = null,
    endDate = null,
  } = options;

  try {
    let sql = `SELECT id, user_id, action, resource_type, resource_id, details, ip_address, user_agent, severity, created_at
               FROM user_activity_logs
               WHERE 1=1`;
    const params = [];
    let paramIndex = 1;

    // Add action filter
    if (action) {
      sql += ` AND action = $${paramIndex}`;
      params.push(action);
      paramIndex++;
    }

    // Add severity filter
    if (severity) {
      sql += ` AND severity = $${paramIndex}`;
      params.push(severity);
      paramIndex++;
    }

    // Add date range filters
    if (startDate) {
      sql += ` AND created_at >= $${paramIndex}`;
      params.push(startDate);
      paramIndex++;
    }

    if (endDate) {
      sql += ` AND created_at <= $${paramIndex}`;
      params.push(endDate);
      paramIndex++;
    }

    // Add ordering and pagination
    sql += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(limit, offset);

    const result = await query(sql, params);
    return result.rows;
  } catch (error) {
    logger.error('[UserActivity] Failed to get admin activity logs', {
      error: error.message,
    });

    throw error;
  }
}

/**
 * Get all user activity logs count for admin review
 *
 * @param {Object} options - Query options
 * @param {string} options.action - Filter by action type (optional)
 * @param {string} options.severity - Filter by severity (optional)
 * @param {string} options.startDate - Filter by start date (optional)
 * @param {string} options.endDate - Filter by end date (optional)
 * @returns {Promise<number>} Total count of activity logs
 */
export async function getAllUserActivityLogsCount(options = {}) {
  const {
    action = null,
    severity = null,
    startDate = null,
    endDate = null,
  } = options;

  try {
    let sql = 'SELECT COUNT(*) as count FROM user_activity_logs WHERE 1=1';
    const params = [];
    let paramIndex = 1;

    // Add action filter
    if (action) {
      sql += ` AND action = $${paramIndex}`;
      params.push(action);
      paramIndex++;
    }

    // Add severity filter
    if (severity) {
      sql += ` AND severity = $${paramIndex}`;
      params.push(severity);
      paramIndex++;
    }

    // Add date range filters
    if (startDate) {
      sql += ` AND created_at >= $${paramIndex}`;
      params.push(startDate);
      paramIndex++;
    }

    if (endDate) {
      sql += ` AND created_at <= $${paramIndex}`;
      params.push(endDate);
      paramIndex++;
    }

    const result = await query(sql, params);
    return parseInt(result.rows[0].count, 10);
  } catch (error) {
    logger.error('[UserActivity] Failed to get admin activity logs count', {
      error: error.message,
    });

    throw error;
  }
}

export default {
  logUserActivity,
  updateUserUsageMetrics,
  getUserActivityLogs,
  getUserActivityLogsCount,
  getUserUsageMetrics,
  getUserActivitySummary,
  getAllUserActivityLogs,
  getAllUserActivityLogsCount,
  ACTIVITY_ACTIONS,
  SEVERITY_LEVELS,
};
