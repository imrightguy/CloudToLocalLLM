/**
 * Authentication Audit Logging Routes for CloudToLocalLLM API Backend
 *
 * Provides endpoints for retrieving authentication audit logs
 * with proper authorization and filtering.
 *
 * Validates: Requirements 2.6, 11.10
 * - Provides audit log retrieval endpoints
 * - Supports filtering and pagination
 * - Includes admin access for system-wide audit logs
 */

import express from 'express';
import { z } from 'zod';
import logger from '../logger.js';
import { authenticateJWT, requireAdmin } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import {
  getAuthAuditLogs,
  getAuthAuditLogsCount,
  getFailedLoginAttempts,
  getAuthAuditLogsForAdmin,
  getAuthAuditLogsCountForAdmin,
  AUTH_EVENT_TYPES,
} from '../services/auth-audit-service.js';

const router = express.Router();

const auditLogsQuerySchema = {
  query: z.object({
    limit: z.coerce.number().int().min(1).max(100).optional().default(50),
    offset: z.coerce.number().int().min(0).optional().default(0),
    eventType: z.string().optional(),
    startDate: z.string().datetime().optional(),
    endDate: z.string().datetime().optional(),
  }),
};

const auditLogsQueryNoEventSchema = {
  query: z.object({
    limit: z.coerce.number().int().min(1).max(100).optional().default(50),
    offset: z.coerce.number().int().min(0).optional().default(0),
    startDate: z.string().datetime().optional(),
    endDate: z.string().datetime().optional(),
  }),
};

const auditLogsQueryAdminSchema = {
  query: z.object({
    limit: z.coerce.number().int().min(1).max(500).optional().default(100),
    offset: z.coerce.number().int().min(0).optional().default(0),
    eventType: z.string().optional(),
    severity: z.string().optional(),
    startDate: z.string().datetime().optional(),
    endDate: z.string().datetime().optional(),
  }),
};

/**
 * GET /auth/audit-logs/me
 * Get authentication audit logs for current user
 *
 * Query parameters:
 * - limit: Maximum number of logs to return (default: 50, max: 100)
 * - offset: Offset for pagination (default: 0)
 * - eventType: Filter by event type (optional)
 * - startDate: Filter by start date in ISO format (optional)
 * - endDate: Filter by end date in ISO format (optional)
 *
 * Validates: Requirements 2.6, 11.10
 * - Logs all authentication attempts (success and failure)
 * - Provides audit log retrieval for users
 */
router.get('/audit-logs/me', authenticateJWT, validateSchema(auditLogsQuerySchema), async (req, res) => {
  try {
    const userId = req.user?.sub || req.userId;

    if (!userId) {
      return res.status(401).json({
        error: 'User not authenticated',
        code: 'AUTH_REQUIRED',
      });
    }

    const { limit, offset, eventType, startDate, endDate } = req.query;

    logger.info('[AuthAudit] Retrieving audit logs for user', {
      userId,
      limit,
      offset,
      eventType,
    });

    // Get audit logs
    const logs = await getAuthAuditLogs(userId, {
      limit,
      offset,
      eventType,
      startDate,
      endDate,
    });

    // Get total count
    const total = await getAuthAuditLogsCount(userId, {
      eventType,
      startDate,
      endDate,
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
    });
  } catch (error) {
    logger.error('[AuthAudit] Failed to retrieve audit logs', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Failed to retrieve audit logs',
      code: 'AUDIT_LOG_RETRIEVAL_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /auth/audit-logs/failed-attempts
 * Get failed login attempts for current user
 *
 * Query parameters:
 * - limit: Maximum number of logs to return (default: 50, max: 100)
 * - offset: Offset for pagination (default: 0)
 * - startDate: Filter by start date in ISO format (optional)
 * - endDate: Filter by end date in ISO format (optional)
 *
 * Validates: Requirements 2.6
 * - Logs all authentication attempts (success and failure)
 * - Provides failed login attempt retrieval
 */
router.get('/audit-logs/failed-attempts', authenticateJWT, validateSchema(auditLogsQueryNoEventSchema), async (req, res) => {
  try {
    const userId = req.user?.sub || req.userId;

    if (!userId) {
      return res.status(401).json({
        error: 'User not authenticated',
        code: 'AUTH_REQUIRED',
      });
    }

    const { limit, offset, startDate, endDate } = req.query;

    logger.info('[AuthAudit] Retrieving failed login attempts for user', {
      userId,
      limit,
      offset,
    });

    // Get failed login attempts
    const logs = await getFailedLoginAttempts(userId, {
      limit,
      offset,
      startDate,
      endDate,
    });

    // Get total count
    const total = await getAuthAuditLogsCount(userId, {
      eventType: AUTH_EVENT_TYPES.FAILED_LOGIN,
      startDate,
      endDate,
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
    });
  } catch (error) {
    logger.error('[AuthAudit] Failed to retrieve failed login attempts', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Failed to retrieve failed login attempts',
      code: 'FAILED_ATTEMPTS_RETRIEVAL_ERROR',
      message: error.message,
    });
  }
});

/**
 * GET /admin/auth/audit-logs
 * Get authentication audit logs for all users (admin only)
 *
 * Query parameters:
 * - limit: Maximum number of logs to return (default: 100, max: 500)
 * - offset: Offset for pagination (default: 0)
 * - eventType: Filter by event type (optional)
 * - severity: Filter by severity (optional)
 * - startDate: Filter by start date in ISO format (optional)
 * - endDate: Filter by end date in ISO format (optional)
 *
 * Validates: Requirements 11.10
 * - Supports admin activity logging and audit trails
 * - Provides system-wide audit log retrieval
 */
router.get(
  '/admin/auth/audit-logs',
  authenticateJWT,
  requireAdmin,
  validateSchema(auditLogsQueryAdminSchema),
  async (req, res) => {
    try {
      const { limit, offset, eventType, severity, startDate, endDate } = req.query;

      logger.info('[AuthAudit] Admin retrieving system-wide audit logs', {
        adminUserId: req.user?.sub,
        limit,
        offset,
        eventType,
        severity,
      });

      // Get audit logs
      const logs = await getAuthAuditLogsForAdmin({
        limit,
        offset,
        eventType,
        severity,
        startDate,
        endDate,
      });

      // Get total count
      const total = await getAuthAuditLogsCountForAdmin({
        eventType,
        severity,
        startDate,
        endDate,
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
      });
    } catch (error) {
      logger.error('[AuthAudit] Failed to retrieve admin audit logs', {
        error: error.message,
        adminUserId: req.user?.sub,
      });

      res.status(500).json({
        error: 'Failed to retrieve audit logs',
        code: 'ADMIN_AUDIT_LOG_RETRIEVAL_ERROR',
        message: error.message,
      });
    }
  },
);

/**
 * GET /admin/auth/audit-logs/failed-attempts
 * Get all failed login attempts (admin only)
 *
 * Query parameters:
 * - limit: Maximum number of logs to return (default: 100, max: 500)
 * - offset: Offset for pagination (default: 0)
 * - startDate: Filter by start date in ISO format (optional)
 * - endDate: Filter by end date in ISO format (optional)
 *
 * Validates: Requirements 11.10
 * - Supports admin activity logging and audit trails
 * - Provides system-wide failed login attempt retrieval
 */
router.get(
  '/admin/auth/audit-logs/failed-attempts',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      // Parse query parameters
      let limit = parseInt(req.query.limit) || 100;
      let offset = parseInt(req.query.offset) || 0;
      const startDate = req.query.startDate || null;
      const endDate = req.query.endDate || null;

      // Validate and constrain limit
      if (limit < 1) {
        limit = 1;
      }
      if (limit > 500) {
        limit = 500;
      }

      // Validate and constrain offset
      if (offset < 0) {
        offset = 0;
      }

      logger.info('[AuthAudit] Admin retrieving all failed login attempts', {
        adminUserId: req.user?.sub,
        limit,
        offset,
      });

      // Get failed login attempts
      const logs = await getFailedLoginAttempts(null, {
        limit,
        offset,
        startDate,
        endDate,
      });

      // Get total count
      const total = await getAuthAuditLogsCountForAdmin({
        eventType: AUTH_EVENT_TYPES.FAILED_LOGIN,
        startDate,
        endDate,
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
      });
    } catch (error) {
      logger.error(
        '[AuthAudit] Failed to retrieve admin failed login attempts',
        {
          error: error.message,
          adminUserId: req.user?.sub,
        },
      );

      res.status(500).json({
        error: 'Failed to retrieve failed login attempts',
        code: 'ADMIN_FAILED_ATTEMPTS_RETRIEVAL_ERROR',
        message: error.message,
      });
    }
  },
);

/**
 * GET /admin/auth/audit-logs/summary
 * Get authentication audit logs summary (admin only)
 *
 * Query parameters:
 * - startDate: Filter by start date in ISO format (optional)
 * - endDate: Filter by end date in ISO format (optional)
 *
 * Validates: Requirements 11.10
 * - Supports admin activity logging and audit trails
 * - Provides audit log summary statistics
 */
router.get(
  '/admin/auth/audit-logs/summary',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const startDate = req.query.startDate || null;
      const endDate = req.query.endDate || null;

      logger.info('[AuthAudit] Admin retrieving audit logs summary', {
        adminUserId: req.user?.sub,
        startDate,
        endDate,
      });

      // Get counts for each event type
      const loginCount = await getAuthAuditLogsCountForAdmin({
        eventType: AUTH_EVENT_TYPES.LOGIN,
        startDate,
        endDate,
      });

      const logoutCount = await getAuthAuditLogsCountForAdmin({
        eventType: AUTH_EVENT_TYPES.LOGOUT,
        startDate,
        endDate,
      });

      const failedLoginCount = await getAuthAuditLogsCountForAdmin({
        eventType: AUTH_EVENT_TYPES.FAILED_LOGIN,
        startDate,
        endDate,
      });

      const tokenRefreshCount = await getAuthAuditLogsCountForAdmin({
        eventType: AUTH_EVENT_TYPES.TOKEN_REFRESH,
        startDate,
        endDate,
      });

      const sessionTimeoutCount = await getAuthAuditLogsCountForAdmin({
        eventType: AUTH_EVENT_TYPES.SESSION_TIMEOUT,
        startDate,
        endDate,
      });

      res.json({
        success: true,
        summary: {
          logins: loginCount,
          logouts: logoutCount,
          failedLogins: failedLoginCount,
          tokenRefreshes: tokenRefreshCount,
          sessionTimeouts: sessionTimeoutCount,
          total:
            loginCount +
            logoutCount +
            failedLoginCount +
            tokenRefreshCount +
            sessionTimeoutCount,
        },
        dateRange: {
          startDate,
          endDate,
        },
      });
    } catch (error) {
      logger.error('[AuthAudit] Failed to retrieve audit logs summary', {
        error: error.message,
        adminUserId: req.user?.sub,
      });

      res.status(500).json({
        error: 'Failed to retrieve audit logs summary',
        code: 'AUDIT_LOG_SUMMARY_ERROR',
        message: error.message,
      });
    }
  },
);

export default router;
