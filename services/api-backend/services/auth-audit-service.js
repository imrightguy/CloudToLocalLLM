/**
 * Authentication Audit Logging Service for CloudToLocalLLM API Backend
 *
 * Provides comprehensive logging of all authentication attempts, successes, and failures
 * with full context including IP address, user agent, and timestamp.
 *
 * Validates: Requirements 2.6, 11.10
 * - Logs all authentication attempts (success and failure)
 * - Creates audit log entries for auth events
 * - Includes IP address, user agent, and timestamp
 * - Supports admin activity logging and audit trails
 */

import logger from '../logger.js';
import { query } from '../database/db-pool.js';

/**
 * Authentication event types
 */
export const AUTH_EVENT_TYPES = {
  LOGIN: 'login',
  LOGOUT: 'logout',
  TOKEN_REFRESH: 'token_refresh',
  TOKEN_REVOKE: 'token_revoke',
  FAILED_LOGIN: 'failed_login',
  PASSWORD_CHANGE: 'password_change',
  SESSION_TIMEOUT: 'session_timeout',
};

/**
 * Severity levels for audit logs
 */
export const SEVERITY_LEVELS = {
  DEBUG: 'debug',
  INFO: 'info',
  WARN: 'warn',
  ERROR: 'error',
  CRITICAL: 'critical',
};

/**
 * Log authentication event to audit logs
 *
 * @param {Object} options - Logging options
 * @param {string} options.userId - User ID (optional for failed logins)
 * @param {string} options.eventType - Type of authentication event
 * @param {string} options.ipAddress - Client IP address
 * @param {string} options.userAgent - Client user agent string
 * @param {boolean} options.success - Whether the event was successful
 * @param {string} options.reason - Reason for failure (if applicable)
 * @param {Object} options.details - Additional event details
 * @param {string} options.severity - Severity level (default: 'info')
 * @returns {Promise<Object>} Audit log entry
 */
export async function logAuthEvent(options = {}) {
  const {
    userId = null,
    eventType,
    ipAddress,
    userAgent,
    success = true,
    reason = null,
    details = {},
    severity = success ? SEVERITY_LEVELS.INFO : SEVERITY_LEVELS.WARN,
  } = options;

  if (!eventType) {
    throw new Error('eventType is required');
  }

  if (!ipAddress) {
    throw new Error('ipAddress is required');
  }

  try {
    // Prepare audit log details
    const auditDetails = {
      success,
      reason,
      ...details,
    };

    // Insert into auth_audit_logs table
    const result = await query(
      `INSERT INTO auth_audit_logs (user_id, action, event_type, details, ip_address, user_agent, severity)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING id, created_at`,
      [
        userId,
        eventType,
        eventType,
        JSON.stringify(auditDetails),
        ipAddress,
        userAgent,
        severity,
      ],
    );

    const auditLog = result.rows[0];

    // Log to application logger
    const logLevel = success ? 'info' : 'warn';
    const logMessage = success
      ? `Authentication ${eventType} successful`
      : `Authentication ${eventType} failed`;

    logger.auth[logLevel](logMessage, {
      userId,
      eventType,
      ipAddress,
      userAgent,
      reason,
      auditLogId: auditLog.id,
      timestamp: auditLog.created_at,
    });

    return auditLog;
  } catch (error) {
    logger.error('[AuthAudit] Failed to log authentication event', {
      error: error.message,
      userId,
      eventType,
      ipAddress,
    });

    // Don't throw - audit logging failure shouldn't break authentication
    // But log it for monitoring
    return null;
  }
}

/**
 * Log successful login attempt
 *
 * @param {Object} options - Login options
 * @param {string} options.userId - User ID
 * @param {string} options.ipAddress - Client IP address
 * @param {string} options.userAgent - Client user agent
 * @param {Object} options.details - Additional details
 * @returns {Promise<Object>} Audit log entry
 */
export async function logLoginSuccess(options = {}) {
  const { userId, ipAddress, userAgent, details = {} } = options;

  return logAuthEvent({
    userId,
    eventType: AUTH_EVENT_TYPES.LOGIN,
    ipAddress,
    userAgent,
    success: true,
    details,
    severity: SEVERITY_LEVELS.INFO,
  });
}

/**
 * Log failed login attempt
 *
 * @param {Object} options - Login options
 * @param {string} options.userId - User ID (optional)
 * @param {string} options.email - User email (optional)
 * @param {string} options.ipAddress - Client IP address
 * @param {string} options.userAgent - Client user agent
 * @param {string} options.reason - Reason for failure
 * @param {Object} options.details - Additional details
 * @returns {Promise<Object>} Audit log entry
 */
export async function logLoginFailure(options = {}) {
  const {
    userId = null,
    email = null,
    ipAddress,
    userAgent,
    reason,
    details = {},
  } = options;

  return logAuthEvent({
    userId,
    eventType: AUTH_EVENT_TYPES.FAILED_LOGIN,
    ipAddress,
    userAgent,
    success: false,
    reason,
    details: {
      email,
      ...details,
    },
    severity: SEVERITY_LEVELS.WARN,
  });
}

/**
 * Log logout event
 *
 * @param {Object} options - Logout options
 * @param {string} options.userId - User ID
 * @param {string} options.ipAddress - Client IP address
 * @param {string} options.userAgent - Client user agent
 * @param {Object} options.details - Additional details
 * @returns {Promise<Object>} Audit log entry
 */
export async function logLogout(options = {}) {
  const { userId, ipAddress, userAgent, details = {} } = options;

  return logAuthEvent({
    userId,
    eventType: AUTH_EVENT_TYPES.LOGOUT,
    ipAddress,
    userAgent,
    success: true,
    details,
    severity: SEVERITY_LEVELS.INFO,
  });
}

/**
 * Log token refresh event
 *
 * @param {Object} options - Token refresh options
 * @param {string} options.userId - User ID
 * @param {string} options.ipAddress - Client IP address
 * @param {string} options.userAgent - Client user agent
 * @param {Object} options.details - Additional details
 * @returns {Promise<Object>} Audit log entry
 */
export async function logTokenRefresh(options = {}) {
  const { userId, ipAddress, userAgent, details = {} } = options;

  return logAuthEvent({
    userId,
    eventType: AUTH_EVENT_TYPES.TOKEN_REFRESH,
    ipAddress,
    userAgent,
    success: true,
    details,
    severity: SEVERITY_LEVELS.DEBUG,
  });
}

/**
 * Log token revocation event
 *
 * @param {Object} options - Token revocation options
 * @param {string} options.userId - User ID
 * @param {string} options.ipAddress - Client IP address
 * @param {string} options.userAgent - Client user agent
 * @param {Object} options.details - Additional details
 * @returns {Promise<Object>} Audit log entry
 */
export async function logTokenRevoke(options = {}) {
  const { userId, ipAddress, userAgent, details = {} } = options;

  return logAuthEvent({
    userId,
    eventType: AUTH_EVENT_TYPES.TOKEN_REVOKE,
    ipAddress,
    userAgent,
    success: true,
    details,
    severity: SEVERITY_LEVELS.INFO,
  });
}

/**
 * Log session timeout event
 *
 * @param {Object} options - Session timeout options
 * @param {string} options.userId - User ID
 * @param {string} options.ipAddress - Client IP address
 * @param {string} options.userAgent - Client user agent
 * @param {Object} options.details - Additional details
 * @returns {Promise<Object>} Audit log entry
 */
export async function logSessionTimeout(options = {}) {
  const { userId, ipAddress, userAgent, details = {} } = options;

  return logAuthEvent({
    userId,
    eventType: AUTH_EVENT_TYPES.SESSION_TIMEOUT,
    ipAddress,
    userAgent,
    success: false,
    reason: 'Session expired',
    details,
    severity: SEVERITY_LEVELS.INFO,
  });
}

/**
 * Get authentication audit logs for a user
 *
 * @param {string} userId - User ID
 * @param {Object} options - Query options
 * @param {number} options.limit - Maximum number of logs to return (default: 50)
 * @param {number} options.offset - Offset for pagination (default: 0)
 * @param {string} options.eventType - Filter by event type (optional)
 * @param {string} options.startDate - Filter by start date (optional)
 * @param {string} options.endDate - Filter by end date (optional)
 * @returns {Promise<Array>} Audit log entries
 */
export async function getAuthAuditLogs(userId, options = {}) {
  const {
    limit = 50,
    offset = 0,
    eventType = null,
    startDate = null,
    endDate = null,
  } = options;

  try {
    let sql = `SELECT id, user_id, action, event_type, details, ip_address, user_agent, severity, created_at
               FROM auth_audit_logs
               WHERE user_id = $1`;
    const params = [userId];
    let paramIndex = 2;

    // Add event type filter
    if (eventType) {
      sql += ` AND event_type = $${paramIndex}`;
      params.push(eventType);
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
    logger.error('[AuthAudit] Failed to get audit logs', {
      error: error.message,
      userId,
    });
    throw error;
  }
}

/**
 * Get authentication audit logs count for a user
 *
 * @param {string} userId - User ID
 * @param {Object} options - Query options
 * @param {string} options.eventType - Filter by event type (optional)
 * @param {string} options.startDate - Filter by start date (optional)
 * @param {string} options.endDate - Filter by end date (optional)
 * @returns {Promise<number>} Total count of audit logs
 */
export async function getAuthAuditLogsCount(userId, options = {}) {
  const { eventType = null, startDate = null, endDate = null } = options;

  try {
    let sql =
      'SELECT COUNT(*) as count FROM auth_audit_logs WHERE user_id = $1';
    const params = [userId];
    let paramIndex = 2;

    // Add event type filter
    if (eventType) {
      sql += ` AND event_type = $${paramIndex}`;
      params.push(eventType);
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
    logger.error('[AuthAudit] Failed to get audit logs count', {
      error: error.message,
      userId,
    });
    throw error;
  }
}

/**
 * Get failed login attempts for a user
 *
 * @param {string} userId - User ID (optional)
 * @param {Object} options - Query options
 * @param {number} options.limit - Maximum number of logs to return (default: 50)
 * @param {number} options.offset - Offset for pagination (default: 0)
 * @param {string} options.startDate - Filter by start date (optional)
 * @param {string} options.endDate - Filter by end date (optional)
 * @returns {Promise<Array>} Failed login attempts
 */
export async function getFailedLoginAttempts(userId = null, options = {}) {
  const { limit = 50, offset = 0, startDate = null, endDate = null } = options;

  try {
    let sql = `SELECT id, user_id, action, event_type, details, ip_address, user_agent, severity, created_at
               FROM auth_audit_logs
               WHERE event_type = $1`;
    const params = [AUTH_EVENT_TYPES.FAILED_LOGIN];
    let paramIndex = 2;

    // Add user ID filter if provided
    if (userId) {
      sql += ` AND user_id = $${paramIndex}`;
      params.push(userId);
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
    logger.error('[AuthAudit] Failed to get failed login attempts', {
      error: error.message,
      userId,
    });
    throw error;
  }
}

/**
 * Get authentication audit logs for admin review
 *
 * @param {Object} options - Query options
 * @param {number} options.limit - Maximum number of logs to return (default: 100)
 * @param {number} options.offset - Offset for pagination (default: 0)
 * @param {string} options.eventType - Filter by event type (optional)
 * @param {string} options.severity - Filter by severity (optional)
 * @param {string} options.startDate - Filter by start date (optional)
 * @param {string} options.endDate - Filter by end date (optional)
 * @returns {Promise<Array>} Audit log entries
 */
export async function getAuthAuditLogsForAdmin(options = {}) {
  const {
    limit = 100,
    offset = 0,
    eventType = null,
    severity = null,
    startDate = null,
    endDate = null,
  } = options;

  try {
    let sql = `SELECT id, user_id, action, event_type, details, ip_address, user_agent, severity, created_at
               FROM auth_audit_logs
               WHERE 1=1`;
    const params = [];
    let paramIndex = 1;

    // Add event type filter
    if (eventType) {
      sql += ` AND event_type = $${paramIndex}`;
      params.push(eventType);
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
    logger.error('[AuthAudit] Failed to get admin audit logs', {
      error: error.message,
    });
    throw error;
  }
}

/**
 * Get authentication audit logs count for admin review
 *
 * @param {Object} options - Query options
 * @param {string} options.eventType - Filter by event type (optional)
 * @param {string} options.severity - Filter by severity (optional)
 * @param {string} options.startDate - Filter by start date (optional)
 * @param {string} options.endDate - Filter by end date (optional)
 * @returns {Promise<number>} Total count of audit logs
 */
export async function getAuthAuditLogsCountForAdmin(options = {}) {
  const {
    eventType = null,
    severity = null,
    startDate = null,
    endDate = null,
  } = options;

  try {
    let sql = 'SELECT COUNT(*) as count FROM auth_audit_logs WHERE 1=1';
    const params = [];
    let paramIndex = 1;

    // Add event type filter
    if (eventType) {
      sql += ` AND event_type = $${paramIndex}`;
      params.push(eventType);
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
    logger.error('[AuthAudit] Failed to get admin audit logs count', {
      error: error.message,
    });
    throw error;
  }
}

export default {
  logAuthEvent,
  logLoginSuccess,
  logLoginFailure,
  logLogout,
  logTokenRefresh,
  logTokenRevoke,
  logSessionTimeout,
  getAuthAuditLogs,
  getAuthAuditLogsCount,
  getFailedLoginAttempts,
  getAuthAuditLogsForAdmin,
  getAuthAuditLogsCountForAdmin,
  AUTH_EVENT_TYPES,
  SEVERITY_LEVELS,
};
