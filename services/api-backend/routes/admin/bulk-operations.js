/**
 * Admin Bulk Operations API Routes
 *
 * Provides endpoints for bulk user management operations:
 * - Create bulk operations
 * - Execute bulk operations
 * - Track operation progress
 * - View operation history
 *
 * Security Features:
 * - Admin authentication required
 * - Role-based permission checking
 * - Comprehensive audit logging
 * - Rate limiting for bulk operations
 */

import express from 'express';
import { adminAuth } from '../../middleware/admin-auth.js';
import { bulkOperationsService } from '../../services/bulk-operations-service.js';
import logger from '../../logger.js';
import {
  adminRateLimiter,
  adminReadOnlyLimiter,
} from '../../middleware/admin-rate-limiter.js';

const router = express.Router();

/**
 * POST /api/admin/bulk-operations/create
 * Create a new bulk operation
 *
 * Request Body:
 * - operationType: Type of operation (tier_update, suspend, reactivate, delete)
 * - userIds: Array of user IDs to operate on (max 1000)
 * - operationData: Operation-specific data
 *   - For tier_update: { tier: 'free|premium|enterprise' }
 *   - For suspend: { reason: 'string' }
 *   - For delete: { softDelete: boolean }
 */
router.post(
  '/create',
  adminRateLimiter,
  adminAuth(['edit_users']),
  async (req, res) => {
    try {
      const { operationType, userIds, operationData } = req.body;

      // Validate input
      if (!operationType || !userIds || !operationData) {
        return res.status(400).json({
          error: 'Missing required fields',
          code: 'MISSING_FIELDS',
          required: ['operationType', 'userIds', 'operationData'],
        });
      }

      // Create bulk operation
      const operation = await bulkOperationsService.createBulkOperation(
        operationType,
        userIds,
        operationData,
      );

      logger.info('✅ [BulkOps] Bulk operation created', {
        adminUserId: req.adminUser.id,
        operationId: operation.operationId,
        type: operationType,
        totalUsers: operation.totalUsers,
      });

      res.status(201).json({
        success: true,
        message: 'Bulk operation created successfully',
        data: operation,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [BulkOps] Failed to create bulk operation', {
        adminUserId: req.adminUser?.id,
        error: error.message,
      });

      res.status(400).json({
        error: error.message,
        code: 'BULK_OPERATION_CREATE_FAILED',
      });
    }
  },
);

/**
 * POST /api/admin/bulk-operations/:operationId/execute
 * Execute a bulk operation
 *
 * Executes the bulk operation asynchronously
 */
router.post(
  '/:operationId/execute',
  adminRateLimiter,
  adminAuth(['edit_users']),
  async (req, res) => {
    try {
      const { operationId } = req.params;

      // Execute operation asynchronously
      bulkOperationsService
        .executeBulkOperation(operationId, req.adminUser.id, req.adminRoles[0])
        .catch((error) => {
          logger.error('🔴 [BulkOps] Async bulk operation failed', {
            operationId,
            error: error.message,
          });
        });

      logger.info('✅ [BulkOps] Bulk operation execution started', {
        adminUserId: req.adminUser.id,
        operationId,
      });

      res.json({
        success: true,
        message: 'Bulk operation execution started',
        data: {
          operationId,
          status: 'in_progress',
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [BulkOps] Failed to execute bulk operation', {
        adminUserId: req.adminUser?.id,
        operationId: req.params.operationId,
        error: error.message,
      });

      res.status(400).json({
        error: error.message,
        code: 'BULK_OPERATION_EXECUTE_FAILED',
      });
    }
  },
);

/**
 * GET /api/admin/bulk-operations/:operationId/status
 * Get bulk operation status
 *
 * Returns:
 * - Operation status (pending, in_progress, completed, failed)
 * - Progress information
 * - Success/failure counts
 * - Error details
 */
router.get(
  '/:operationId/status',
  adminReadOnlyLimiter,
  adminAuth(['view_users']),
  async (req, res) => {
    try {
      const { operationId } = req.params;

      const status = bulkOperationsService.getOperationStatus(operationId);

      if (!status) {
        return res.status(404).json({
          error: 'Operation not found',
          code: 'OPERATION_NOT_FOUND',
        });
      }

      logger.info('✅ [BulkOps] Operation status retrieved', {
        adminUserId: req.adminUser.id,
        operationId,
        status: status.status,
      });

      res.json({
        success: true,
        data: status,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [BulkOps] Failed to get operation status', {
        adminUserId: req.adminUser?.id,
        operationId: req.params.operationId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to get operation status',
        code: 'STATUS_RETRIEVAL_FAILED',
      });
    }
  },
);

/**
 * GET /api/admin/bulk-operations/history
 * Get bulk operation history
 *
 * Query Parameters:
 * - limit: Number of operations to return (default: 50, max: 100)
 */
router.get(
  '/history',
  adminReadOnlyLimiter,
  adminAuth(['view_users']),
  async (req, res) => {
    try {
      const limit = Math.min(100, Math.max(1, parseInt(req.query.limit) || 50));

      const history = bulkOperationsService.getOperationHistory(limit);

      logger.info('✅ [BulkOps] Operation history retrieved', {
        adminUserId: req.adminUser.id,
        count: history.length,
      });

      res.json({
        success: true,
        data: {
          operations: history,
          count: history.length,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [BulkOps] Failed to get operation history', {
        adminUserId: req.adminUser?.id,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to get operation history',
        code: 'HISTORY_RETRIEVAL_FAILED',
      });
    }
  },
);

export default router;
