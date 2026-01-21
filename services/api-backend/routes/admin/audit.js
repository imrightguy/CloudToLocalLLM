/**
 * Admin Audit Log API Routes
 *
 * Provides secure administrative endpoints for audit log management:
 * - List audit logs with pagination, search, and filtering
 * - View detailed audit log entries
 * - Export audit logs to CSV format
 *
 * Security Features:
 * - Admin authentication required
 * - Role-based permission checking (view_audit_logs, export_audit_logs)
 * - Comprehensive filtering capabilities
 * - Immutable audit log storage
 */

import express from 'express';
import { adminAuth } from '../../middleware/admin-auth.js';
import logger from '../../logger.js';
import { getPool, closePool } from '../../database/db-pool.js';
import {
  adminReadOnlyLimiter,
  adminExpensiveLimiter,
} from '../../middleware/admin-rate-limiter.js';

const router = express.Router();

/**
 * GET /api/admin/audit/logs
 * List audit logs with pagination and filtering
 *
 * Query Parameters:
 * - page: Page number (default: 1)
 * - limit: Items per page (default: 100, max: 200)
 * - adminUserId: Filter by admin user ID
 * - action: Filter by action type
 * - resourceType: Filter by resource type
 * - affectedUserId: Filter by affected user ID
 * - startDate: Filter by date range (start)
 * - endDate: Filter by date range (end)
 * - sortBy: Sort field (created_at, action, resource_type)
 * - sortOrder: Sort order (asc, desc)
 */
router.get(
  '/logs',
  adminReadOnlyLimiter,
  adminAuth(['view_audit_logs']),
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
      const adminUserId = req.query.adminUserId?.trim();
      const action = req.query.action?.trim();
      const resourceType = req.query.resourceType?.trim();
      const affectedUserId = req.query.affectedUserId?.trim();
      const startDate = req.query.startDate;
      const endDate = req.query.endDate;
      const sortBy = req.query.sortBy || 'created_at';
      const sortOrder =
        req.query.sortOrder?.toLowerCase() === 'asc' ? 'ASC' : 'DESC';

      // Validate sort field
      const validSortFields = [
        'created_at',
        'action',
        'resource_type',
        'admin_user_id',
      ];
      const sortField = validSortFields.includes(sortBy)
        ? sortBy
        : 'created_at';

      // Build query conditions
      const conditions = [];
      const params = [];
      let paramIndex = 1;

      // Admin user filter
      if (adminUserId) {
        conditions.push(`aal.admin_user_id = $${paramIndex}`);
        params.push(adminUserId);
        paramIndex++;
      }

      // Action filter
      if (action) {
        conditions.push(`aal.action = $${paramIndex}`);
        params.push(action);
        paramIndex++;
      }

      // Resource type filter
      if (resourceType) {
        conditions.push(`aal.resource_type = $${paramIndex}`);
        params.push(resourceType);
        paramIndex++;
      }

      // Affected user filter
      if (affectedUserId) {
        conditions.push(`aal.affected_user_id = $${paramIndex}`);
        params.push(affectedUserId);
        paramIndex++;
      }

      // Date range filter
      if (startDate) {
        conditions.push(`aal.created_at >= $${paramIndex}`);
        params.push(startDate);
        paramIndex++;
      }

      if (endDate) {
        conditions.push(`aal.created_at <= $${paramIndex}`);
        params.push(endDate);
        paramIndex++;
      }

      const whereClause =
        conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      // Get total count
      const countQuery = `
      SELECT COUNT(*) as total
      FROM admin_audit_logs aal
      ${whereClause}
    `;

      const countResult = await pool.query(countQuery, params);
      const totalLogs = parseInt(countResult.rows[0].total);
      const totalPages = Math.ceil(totalLogs / limit);

      // Get audit logs with pagination and admin/user details
      const logsQuery = `
      SELECT 
        aal.id,
        aal.admin_user_id,
        aal.admin_role,
        aal.action,
        aal.resource_type,
        aal.resource_id,
        aal.affected_user_id,
        aal.details,
        aal.ip_address,
        aal.user_agent,
        aal.created_at,
        admin_user.email as admin_email,
        admin_user.username as admin_username,
        affected_user.email as affected_user_email,
        affected_user.username as affected_user_username
      FROM admin_audit_logs aal
      LEFT JOIN users admin_user ON aal.admin_user_id = admin_user.id
      LEFT JOIN users affected_user ON aal.affected_user_id = affected_user.id
      ${whereClause}
      ORDER BY aal.${sortField} ${sortOrder}
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;

      params.push(limit, offset);

      const logsResult = await pool.query(logsQuery, params);

      logger.info('✅ [AdminAudit] Audit logs retrieved', {
        adminUserId: req.adminUser.id,
        page,
        limit,
        totalLogs,
        filters: {
          adminUserId,
          action,
          resourceType,
          affectedUserId,
          startDate,
          endDate,
        },
      });

      res.json({
        success: true,
        data: {
          logs: logsResult.rows,
          pagination: {
            page,
            limit,
            totalLogs,
            totalPages,
            hasNextPage: page < totalPages,
            hasPreviousPage: page > 1,
          },
          filters: {
            adminUserId,
            action,
            resourceType,
            affectedUserId,
            startDate,
            endDate,
            sortBy: sortField,
            sortOrder,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminAudit] Failed to retrieve audit logs', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve audit logs',
        code: 'AUDIT_LOGS_FAILED',
        details: error.message,
      });
    }
  },
);

export default router;

/**
 * GET /api/admin/audit/logs/:logId
 * Get detailed audit log entry by ID
 *
 * Returns:
 * - Full audit log entry details
 * - Admin user information (email, username, role)
 * - Affected user information (if applicable)
 * - Complete action details (JSON formatted)
 * - IP address and user agent
 */
router.get(
  '/logs/:logId',
  adminReadOnlyLimiter,
  adminAuth(['view_audit_logs']),
  async (req, res) => {
    try {
      const pool = getPool();
      const { logId } = req.params;

      // Validate logId format (UUID)
      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      if (!uuidRegex.test(logId)) {
        return res.status(400).json({
          error: 'Invalid log ID format',
          code: 'INVALID_LOG_ID',
        });
      }

      // Get audit log entry with admin and affected user details
      const logQuery = `
      SELECT 
        aal.id,
        aal.admin_user_id,
        aal.admin_role,
        aal.action,
        aal.resource_type,
        aal.resource_id,
        aal.affected_user_id,
        aal.details,
        aal.ip_address,
        aal.user_agent,
        aal.created_at,
        admin_user.email as admin_email,
        admin_user.username as admin_username,
        admin_user.jwt_id as admin_jwt_id,
        affected_user.email as affected_user_email,
        affected_user.username as affected_user_username,
        affected_user.jwt_id as affected_user_jwt_id
      FROM admin_audit_logs aal
      LEFT JOIN users admin_user ON aal.admin_user_id = admin_user.id
      LEFT JOIN users affected_user ON aal.affected_user_id = affected_user.id
      WHERE aal.id = $1
    `;

      const logResult = await pool.query(logQuery, [logId]);

      if (logResult.rows.length === 0) {
        return res.status(404).json({
          error: 'Audit log entry not found',
          code: 'LOG_NOT_FOUND',
        });
      }

      const log = logResult.rows[0];

      // Parse details JSON if it's a string
      if (typeof log.details === 'string') {
        try {
          log.details = JSON.parse(log.details);
        } catch {
          // Keep as string if parsing fails
        }
      }

      logger.info('✅ [AdminAudit] Audit log details retrieved', {
        adminUserId: req.adminUser.id,
        logId,
        action: log.action,
        resourceType: log.resource_type,
      });

      res.json({
        success: true,
        data: {
          log: {
            id: log.id,
            action: log.action,
            resourceType: log.resource_type,
            resourceId: log.resource_id,
            details: log.details,
            ipAddress: log.ip_address,
            userAgent: log.user_agent,
            createdAt: log.created_at,
            adminUser: {
              id: log.admin_user_id,
              email: log.admin_email,
              username: log.admin_username,
              jwtId: log.admin_jwt_id,
              role: log.admin_role,
            },
            affectedUser: log.affected_user_id
              ? {
                  id: log.affected_user_id,
                  email: log.affected_user_email,
                  username: log.affected_user_username,
                  jwtId: log.affected_user_jwt_id,
                }
              : null,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminAudit] Failed to retrieve audit log details', {
        adminUserId: req.adminUser?.id,
        logId: req.params.logId,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve audit log details',
        code: 'LOG_DETAILS_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/audit/export
 * Export audit logs to CSV format
 *
 * Query Parameters:
 * - adminUserId: Filter by admin user ID
 * - action: Filter by action type
 * - resourceType: Filter by resource type
 * - affectedUserId: Filter by affected user ID
 * - startDate: Filter by date range (start)
 * - endDate: Filter by date range (end)
 *
 * Returns:
 * - CSV file stream with audit log data
 * - Filename: audit-logs-{timestamp}.csv
 */
router.get(
  '/export',
  adminExpensiveLimiter,
  adminAuth(['export_audit_logs']),
  async (req, res) => {
    try {
      const pool = getPool();

      // Parse query parameters for filtering
      const adminUserId = req.query.adminUserId?.trim();
      const action = req.query.action?.trim();
      const resourceType = req.query.resourceType?.trim();
      const affectedUserId = req.query.affectedUserId?.trim();
      const startDate = req.query.startDate;
      const endDate = req.query.endDate;

      // Build query conditions
      const conditions = [];
      const params = [];
      let paramIndex = 1;

      if (adminUserId) {
        conditions.push(`aal.admin_user_id = $${paramIndex}`);
        params.push(adminUserId);
        paramIndex++;
      }

      if (action) {
        conditions.push(`aal.action = $${paramIndex}`);
        params.push(action);
        paramIndex++;
      }

      if (resourceType) {
        conditions.push(`aal.resource_type = $${paramIndex}`);
        params.push(resourceType);
        paramIndex++;
      }

      if (affectedUserId) {
        conditions.push(`aal.affected_user_id = $${paramIndex}`);
        params.push(affectedUserId);
        paramIndex++;
      }

      if (startDate) {
        conditions.push(`aal.created_at >= $${paramIndex}`);
        params.push(startDate);
        paramIndex++;
      }

      if (endDate) {
        conditions.push(`aal.created_at <= $${paramIndex}`);
        params.push(endDate);
        paramIndex++;
      }

      const whereClause =
        conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

      // Get audit logs for export
      const exportQuery = `
      SELECT 
        aal.id,
        aal.created_at,
        aal.admin_user_id,
        admin_user.email as admin_email,
        admin_user.username as admin_username,
        aal.admin_role,
        aal.action,
        aal.resource_type,
        aal.resource_id,
        aal.affected_user_id,
        affected_user.email as affected_user_email,
        affected_user.username as affected_user_username,
        aal.details,
        aal.ip_address,
        aal.user_agent
      FROM admin_audit_logs aal
      LEFT JOIN users admin_user ON aal.admin_user_id = admin_user.id
      LEFT JOIN users affected_user ON aal.affected_user_id = affected_user.id
      ${whereClause}
      ORDER BY aal.created_at DESC
    `;

      const logsResult = await pool.query(exportQuery, params);

      // Generate CSV content
      const csvHeaders = [
        'Log ID',
        'Timestamp',
        'Admin User ID',
        'Admin Email',
        'Admin Username',
        'Admin Role',
        'Action',
        'Resource Type',
        'Resource ID',
        'Affected User ID',
        'Affected User Email',
        'Affected User Username',
        'Details',
        'IP Address',
        'User Agent',
      ];

      // Helper function to escape CSV values
      const escapeCsvValue = (value) => {
        if (value === null || value === undefined) {
          return '';
        }
        const stringValue = String(value);
        // Escape double quotes and wrap in quotes if contains comma, newline, or quote
        if (
          stringValue.includes(',') ||
          stringValue.includes('\n') ||
          stringValue.includes('"')
        ) {
          return `"${stringValue.replace(/"/g, '""')}"`;
        }
        return stringValue;
      };

      // Build CSV rows
      const csvRows = [csvHeaders.join(',')];

      for (const log of logsResult.rows) {
        // Convert details object to JSON string for CSV
        const detailsStr =
          typeof log.details === 'object'
            ? JSON.stringify(log.details)
            : String(log.details || '');

        const row = [
          escapeCsvValue(log.id),
          escapeCsvValue(log.created_at),
          escapeCsvValue(log.admin_user_id),
          escapeCsvValue(log.admin_email),
          escapeCsvValue(log.admin_username),
          escapeCsvValue(log.admin_role),
          escapeCsvValue(log.action),
          escapeCsvValue(log.resource_type),
          escapeCsvValue(log.resource_id),
          escapeCsvValue(log.affected_user_id),
          escapeCsvValue(log.affected_user_email),
          escapeCsvValue(log.affected_user_username),
          escapeCsvValue(detailsStr),
          escapeCsvValue(log.ip_address),
          escapeCsvValue(log.user_agent),
        ];

        csvRows.push(row.join(','));
      }

      const csvContent = csvRows.join('\n');

      // Generate filename with timestamp
      const timestamp = new Date()
        .toISOString()
        .replace(/[:.]/g, '-')
        .split('T')[0];
      const filename = `audit-logs-${timestamp}.csv`;

      // Set response headers for file download
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="${filename}"`,
      );
      res.setHeader('Content-Length', Buffer.byteLength(csvContent));

      logger.info('✅ [AdminAudit] Audit logs exported', {
        adminUserId: req.adminUser.id,
        totalLogs: logsResult.rows.length,
        filename,
        filters: {
          adminUserId,
          action,
          resourceType,
          affectedUserId,
          startDate,
          endDate,
        },
      });

      // Send CSV content
      res.send(csvContent);
    } catch (error) {
      logger.error('🔴 [AdminAudit] Failed to export audit logs', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to export audit logs',
        code: 'AUDIT_EXPORT_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * Close database connection pool
 * Should be called on application shutdown
 */
export async function closeAuditDbPool() {
  await closePool();
}
