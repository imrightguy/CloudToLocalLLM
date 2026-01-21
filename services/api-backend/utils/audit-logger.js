/**
 * Audit Logging Utility for Admin Actions
 *
 * Provides comprehensive audit logging for all administrative actions
 * with tamper-proof storage in the admin_audit_logs table.
 */

import logger from '../logger.js';
import { getPool, closePool } from '../database/db-pool.js';

/**
 * Log an admin action to the audit log
 *
 * @param {Object} params - Audit log parameters
 * @param {string} params.adminUserId - ID of the admin user performing the action
 * @param {string} params.adminRole - Role of the admin at time of action
 * @param {string} params.action - Action being performed (e.g., 'user_suspended', 'refund_processed')
 * @param {string} params.resourceType - Type of resource affected (e.g., 'user', 'subscription', 'transaction')
 * @param {string} params.resourceId - ID of the affected resource
 * @param {string} [params.affectedUserId] - ID of the user affected by the action (optional)
 * @param {Object} [params.details] - Additional action details (optional)
 * @param {string} [params.ipAddress] - IP address of the admin (optional)
 * @param {string} [params.userAgent] - User agent of the admin (optional)
 * @returns {Promise<Object>} The created audit log entry
 */
export async function logAdminAction({
  adminUserId,
  adminRole,
  action,
  resourceType,
  resourceId,
  affectedUserId = null,
  details = {},
  ipAddress = null,
  userAgent = null,
}) {
  try {
    // Validate required parameters
    if (!adminUserId || !adminRole || !action || !resourceType || !resourceId) {
      throw new Error('Missing required audit log parameters');
    }

    // Initialize database pool if needed
    const pool = getPool();

    // Insert audit log entry
    const result = await pool.query(
      `INSERT INTO admin_audit_logs (
        admin_user_id,
        admin_role,
        action,
        resource_type,
        resource_id,
        affected_user_id,
        details,
        ip_address,
        user_agent,
        created_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())
      RETURNING *`,
      [
        adminUserId,
        adminRole,
        action,
        resourceType,
        resourceId,
        affectedUserId,
        JSON.stringify(details),
        ipAddress,
        userAgent,
      ],
    );

    const auditLog = result.rows[0];

    logger.info('📝 [AuditLogger] Admin action logged', {
      auditLogId: auditLog.id,
      adminUserId,
      adminRole,
      action,
      resourceType,
      resourceId,
      affectedUserId,
    });

    return auditLog;
  } catch (error) {
    logger.error('🔴 [AuditLogger] Failed to log admin action', {
      error: error.message,
      stack: error.stack,
      adminUserId,
      action,
      resourceType,
      resourceId,
    });
    // Don't throw - audit logging failure shouldn't break the main operation
    // But we should alert on this
    return null;
  }
}

/**
 * Express middleware to automatically log admin actions
 * Extracts admin info from request and logs after successful response
 *
 * @param {string} action - Action being performed
 * @param {string} resourceType - Type of resource affected
 * @param {Function} [getResourceId] - Function to extract resource ID from request (optional)
 * @param {Function} [getAffectedUserId] - Function to extract affected user ID from request (optional)
 * @param {Function} [getDetails] - Function to extract additional details from request (optional)
 * @returns {Function} Express middleware function
 */
export function auditMiddleware({
  action,
  resourceType,
  getResourceId = (req) =>
    req.params.id || req.params.userId || req.params.resourceId,
  getAffectedUserId = (req) => req.params.userId || null,
  getDetails = (_req) => ({}),
}) {
  return async (req, res, next) => {
    // Store original send function
    const originalSend = res.send;

    // Override send function to log after successful response
    res.send = function (data) {
      // Only log on successful responses (2xx status codes)
      if (res.statusCode >= 200 && res.statusCode < 300) {
        // Log asynchronously without blocking response
        setImmediate(async () => {
          try {
            const resourceId = getResourceId(req);
            const affectedUserId = getAffectedUserId(req);
            const details = getDetails(req);

            if (req.adminUser && resourceId) {
              await logAdminAction({
                adminUserId: req.adminUser.id,
                adminRole: req.adminRoles?.[0] || 'unknown',
                action,
                resourceType,
                resourceId,
                affectedUserId,
                details,
                ipAddress: req.ip,
                userAgent: req.get('User-Agent'),
              });
            }
          } catch (error) {
            logger.error('🔴 [AuditLogger] Middleware logging failed', {
              error: error.message,
            });
          }
        });
      }

      // Call original send
      return originalSend.call(this, data);
    };

    next();
  };
}

/**
 * Helper function to create audit log details for user management actions
 * @param {Object} req - Express request object
 * @param {Object} changes - Changes being made
 * @returns {Object} Audit log details
 */
export function createUserManagementDetails(req, changes = {}) {
  return {
    changes,
    requestBody: req.body,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Helper function to create audit log details for payment actions
 * @param {Object} req - Express request object
 * @param {Object} paymentInfo - Payment information
 * @returns {Object} Audit log details
 */
export function createPaymentDetails(req, paymentInfo = {}) {
  return {
    amount: paymentInfo.amount,
    currency: paymentInfo.currency,
    reason: paymentInfo.reason,
    transactionId: paymentInfo.transactionId,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Helper function to create audit log details for subscription actions
 * @param {Object} req - Express request object
 * @param {Object} subscriptionInfo - Subscription information
 * @returns {Object} Audit log details
 */
export function createSubscriptionDetails(req, subscriptionInfo = {}) {
  return {
    previousTier: subscriptionInfo.previousTier,
    newTier: subscriptionInfo.newTier,
    proratedCharge: subscriptionInfo.proratedCharge,
    effectiveDate: subscriptionInfo.effectiveDate,
    timestamp: new Date().toISOString(),
  };
}

/**
 * Query audit logs with filtering
 * @param {Object} filters - Filter parameters
 * @param {string} [filters.adminUserId] - Filter by admin user ID
 * @param {string} [filters.action] - Filter by action type
 * @param {string} [filters.resourceType] - Filter by resource type
 * @param {string} [filters.affectedUserId] - Filter by affected user ID
 * @param {Date} [filters.startDate] - Filter by start date
 * @param {Date} [filters.endDate] - Filter by end date
 * @param {number} [filters.limit] - Limit number of results (default: 100)
 * @param {number} [filters.offset] - Offset for pagination (default: 0)
 * @returns {Promise<Array>} Array of audit log entries
 */
export async function queryAuditLogs(filters = {}) {
  try {
    const pool = getPool();

    // Build query dynamically based on filters
    const conditions = [];
    const params = [];
    let paramIndex = 1;

    if (filters.adminUserId) {
      conditions.push(`admin_user_id = $${paramIndex++}`);
      params.push(filters.adminUserId);
    }

    if (filters.action) {
      conditions.push(`action = $${paramIndex++}`);
      params.push(filters.action);
    }

    if (filters.resourceType) {
      conditions.push(`resource_type = $${paramIndex++}`);
      params.push(filters.resourceType);
    }

    if (filters.affectedUserId) {
      conditions.push(`affected_user_id = $${paramIndex++}`);
      params.push(filters.affectedUserId);
    }

    if (filters.startDate) {
      conditions.push(`created_at >= $${paramIndex++}`);
      params.push(filters.startDate);
    }

    if (filters.endDate) {
      conditions.push(`created_at <= $${paramIndex++}`);
      params.push(filters.endDate);
    }

    const whereClause =
      conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';
    const limit = filters.limit || 100;
    const offset = filters.offset || 0;

    const query = `
      SELECT * FROM admin_audit_logs
      ${whereClause}
      ORDER BY created_at DESC
      LIMIT $${paramIndex++} OFFSET $${paramIndex++}
    `;

    params.push(limit, offset);

    const result = await pool.query(query, params);

    return result.rows;
  } catch (error) {
    logger.error('🔴 [AuditLogger] Failed to query audit logs', {
      error: error.message,
      filters,
    });
    throw error;
  }
}

/**
 * Get audit log entry by ID
 * @param {string} logId - Audit log ID
 * @returns {Promise<Object>} Audit log entry
 */
export async function getAuditLogById(logId) {
  try {
    const pool = getPool();

    const result = await pool.query(
      'SELECT * FROM admin_audit_logs WHERE id = $1',
      [logId],
    );

    if (result.rows.length === 0) {
      return null;
    }

    return result.rows[0];
  } catch (error) {
    logger.error('🔴 [AuditLogger] Failed to get audit log', {
      error: error.message,
      logId,
    });
    throw error;
  }
}

/**
 * Close database connection pool
 * Should be called on application shutdown
 */
export async function closeAuditDbPool() {
  await closePool();
}
