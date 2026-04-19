/**
 * Administrative API Routes for CloudToLocalLLM
 *
 * Provides secure administrative endpoints for:
 * - Data flush operations with multi-step confirmation
 * - System statistics and monitoring
 * - Audit trail access
 * - Emergency data clearing
 *
 * Security Features:
 * - Admin role/scope validation
 * - Multi-step confirmation process
 * - Comprehensive audit logging
 * - Rate limiting for sensitive operations
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT, requireAdmin } from '../middleware/auth.js';
import { adminDataFlushService } from '../admin-data-flush-service.js';
import { validateSchema } from '../middleware/schema-validation.js';
import logger from '../logger.js';

// Import admin rate limiters
import {
  adminRateLimiter,
  adminCriticalLimiter,
  adminReadOnlyLimiter,
} from '../middleware/admin-rate-limiter.js';

// Import admin sub-routes
import adminUsersRoutes from './admin/users.js';
import adminPaymentsRoutes from './admin/payments.js';
import adminSubscriptionsRoutes from './admin/subscriptions.js';
import adminReportsRoutes from './admin/reports.js';
import adminAuditRoutes from './admin/audit.js';
import adminAdminsRoutes from './admin/admins.js';
import adminDashboardRoutes from './admin/dashboard.js';
import adminEmailRoutes from './admin/email.js';
import adminDNSRoutes from './admin/dns.js';
import adminBulkOperationsRoutes from './admin/bulk-operations.js';

const router = express.Router();

const flushPrepareBodySchema = {
  body: z.object({
    targetUserId: z.string().optional(),
    scope: z.enum(['FULL_FLUSH', 'USER_SPECIFIC', 'CONTAINERS_ONLY', 'AUTH_ONLY']).optional(),
  }),
};

const flushExecuteBodySchema = {
  body: z.object({
    confirmationToken: z.string({ required_error: 'Confirmation token is required' }),
    targetUserId: z.string().optional(),
    options: z.record(z.any()).optional(),
  }),
};

/**
 * @swagger
 * /admin/system/stats:
 *   get:
 *     summary: Get system statistics
 *     description: |
 *       Retrieves system statistics for the admin dashboard.
 *       Includes user counts, tunnel metrics, and system health.
 *
 *       **Validates: Requirements 11.5, 11.8**
 *       - Provides admin dashboards and reporting
 *       - Provides system health and status endpoints
 *     tags:
 *       - Admin
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: System statistics retrieved successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     totalUsers:
 *                       type: integer
 *                     activeTunnels:
 *                       type: integer
 *                     totalRequests:
 *                       type: integer
 *                     systemHealth:
 *                       type: string
 *                       enum: [healthy, degraded, error]
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         $ref: '#/components/responses/ForbiddenError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get(
  '/system/stats',
  authenticateJWT,
  requireAdmin,
  adminReadOnlyLimiter,
  async (req, res) => {
    try {
      logger.info('� [AdminAPI] System statistics requested', {
        adminUserId: req.user.sub,
        userAgent: req.get('User-Agent'),
      });

      const stats = await adminDataFlushService.getSystemStatistics();

      res.json({
        success: true,
        data: stats,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('� [AdminAPI] Failed to get system statistics', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve system statistics',
        code: 'STATS_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * @swagger
 * /admin/flush/prepare:
 *   post:
 *     summary: Prepare data flush operation
 *     description: |
 *       Prepares a data flush operation and generates a confirmation token.
 *       This is the first step in a multi-step confirmation process.
 *
 *       **Validates: Requirements 11.3, 11.10**
 *       - Implements admin audit logging for all operations
 *       - Supports admin activity logging and audit trails
 *     tags:
 *       - Admin
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               targetUserId:
 *                 type: string
 *                 description: User ID to flush (optional, all users if omitted)
 *               scope:
 *                 type: string
 *                 enum: [FULL_FLUSH, PARTIAL_FLUSH]
 *                 description: Flush scope
 *     responses:
 *       200:
 *         description: Flush operation prepared
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 confirmationToken:
 *                   type: string
 *                 expiresIn:
 *                   type: integer
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         $ref: '#/components/responses/ForbiddenError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.post(
  '/flush/prepare',
  authenticateJWT,
  requireAdmin,
  adminRateLimiter,
  validateSchema(flushPrepareBodySchema),
  async (req, res) => {
    try {
      const { targetUserId, scope } = req.body;
      const adminUserId = req.user.sub;

      logger.info('🔵 [AdminAPI] Data flush preparation requested', {
        adminUserId,
        targetUserId: targetUserId || 'ALL_USERS',
        scope: scope || 'FULL_FLUSH',
        userAgent: req.get('User-Agent'),
      });

      const flushScope = scope || 'FULL_FLUSH';

      // Generate confirmation token
      const confirmationData = adminDataFlushService.generateConfirmationToken(
        adminUserId,
        targetUserId || 'ALL_USERS',
      );

      // Log the preparation (but not the token)
      logger.info('� [AdminAPI] Flush confirmation token generated', {
        adminUserId,
        targetUserId: targetUserId || 'ALL_USERS',
        scope: flushScope,
        expiresAt: confirmationData.expiresAt,
      });

      res.json({
        success: true,
        message:
          'Flush operation prepared. Use the confirmation token to execute.',
        confirmationToken: confirmationData.token,
        expiresAt: confirmationData.expiresAt,
        scope: flushScope,
        targetUserId: targetUserId || 'ALL_USERS',
        warning:
          'This operation will permanently delete user data. Ensure you have proper authorization.',
      });
    } catch (error) {
      logger.error('� [AdminAPI] Failed to prepare flush operation', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to prepare flush operation',
        code: 'FLUSH_PREPARATION_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/flush/execute
 * Execute data flush operation with confirmation token
 * Rate limit: Critical (5 req/hour)
 */
router.post(
  '/flush/execute',
  authenticateJWT,
  requireAdmin,
  adminCriticalLimiter,
  validateSchema(flushExecuteBodySchema),
  async (req, res) => {
    try {
      const { confirmationToken, targetUserId, options = {} } = req.body;
      const adminUserId = req.user.sub;

      logger.warn('🔴 [AdminAPI] CRITICAL: Data flush execution requested', {
        adminUserId,
        targetUserId: targetUserId || 'ALL_USERS',
        options,
        userAgent: req.get('User-Agent'),
        ipAddress: req.ip,
      });

      // Execute the flush operation
      const result = await adminDataFlushService.executeDataFlush(
        adminUserId,
        confirmationToken,
        targetUserId,
        options,
      );

      // Log successful completion
      logger.warn('� [AdminAPI] CRITICAL: Data flush executed successfully', {
        adminUserId,
        operationId: result.operationId,
        targetUserId: targetUserId || 'ALL_USERS',
        duration: result.duration,
        results: result.results,
      });

      res.json({
        success: true,
        message: 'Data flush operation completed successfully',
        operationId: result.operationId,
        results: result.results,
        duration: result.duration,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('� [AdminAPI] CRITICAL: Data flush execution failed', {
        adminUserId: req.user.sub,
        targetUserId: req.body.targetUserId || 'ALL_USERS',
        error: error.message,
      });

      res.status(500).json({
        error: 'Data flush operation failed',
        code: 'FLUSH_EXECUTION_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/flush/status/:operationId
 * Get status of a flush operation
 * Rate limit: Read-only (200 req/min)
 */
router.get(
  '/flush/status/:operationId',
  authenticateJWT,
  requireAdmin,
  adminReadOnlyLimiter,
  async (req, res) => {
    try {
      const { operationId } = req.params;
      const adminUserId = req.user.sub;

      const status = adminDataFlushService.getFlushOperationStatus(operationId);

      if (!status) {
        return res.status(404).json({
          error: 'Flush operation not found',
          code: 'OPERATION_NOT_FOUND',
        });
      }

      logger.info('� [AdminAPI] Flush operation status requested', {
        adminUserId,
        operationId,
        status: status.status,
      });

      res.json({
        success: true,
        data: status,
      });
    } catch (error) {
      logger.error('� [AdminAPI] Failed to get flush operation status', {
        adminUserId: req.user.sub,
        operationId: req.params.operationId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to get operation status',
        code: 'STATUS_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/flush/history
 * Get flush operation history for audit purposes
 * Rate limit: Read-only (200 req/min)
 */
router.get(
  '/flush/history',
  authenticateJWT,
  requireAdmin,
  adminReadOnlyLimiter,
  async (req, res) => {
    try {
      const { limit = 50 } = req.query;
      const adminUserId = req.user.sub;

      logger.info('� [AdminAPI] Flush history requested', {
        adminUserId,
        limit: parseInt(limit),
      });

      const history = adminDataFlushService.getFlushHistory(parseInt(limit));

      res.json({
        success: true,
        data: history,
        count: history.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('� [AdminAPI] Failed to get flush history', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve flush history',
        code: 'HISTORY_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/containers/cleanup
 * Emergency cleanup of orphaned containers and networks
 * Rate limit: Default (100 req/min)
 */
router.post(
  '/containers/cleanup',
  authenticateJWT,
  requireAdmin,
  adminRateLimiter,
  async (req, res) => {
    try {
      const adminUserId = req.user.sub;

      logger.warn('� [AdminAPI] Emergency container cleanup requested', {
        adminUserId,
        userAgent: req.get('User-Agent'),
      });

      // Execute container cleanup only
      const result =
        await adminDataFlushService.clearUserContainersAndNetworks();

      logger.info('� [AdminAPI] Emergency container cleanup completed', {
        adminUserId,
        results: result,
      });

      res.json({
        success: true,
        message: 'Container cleanup completed',
        results: result,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('� [AdminAPI] Emergency container cleanup failed', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Container cleanup failed',
        code: 'CLEANUP_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/health
 * Admin health check endpoint
 */
router.get('/health', authenticateJWT, requireAdmin, (req, res) => {
  logger.info('� [AdminAPI] Admin health check', {
    adminUserId: req.user.sub,
  });

  res.json({
    status: 'healthy',
    service: 'CloudToLocalLLM-admin',
    timestamp: new Date().toISOString(),
    adminUserId: req.user.sub,
  });
});

// Mount admin sub-routes
router.use('/users', adminUsersRoutes);
router.use('/payments', adminPaymentsRoutes);
router.use('/subscriptions', adminSubscriptionsRoutes);
router.use('/reports', adminReportsRoutes);
router.use('/audit', adminAuditRoutes);
router.use('/admins', adminAdminsRoutes);
router.use('/dashboard', adminDashboardRoutes);
router.use('/email', adminEmailRoutes);
router.use('/dns', adminDNSRoutes);
router.use('/bulk-operations', adminBulkOperationsRoutes);

export default router;
