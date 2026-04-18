/**
 * User Deletion API Routes
 *
 * Provides endpoints for:
 * - User account deletion (hard and soft delete)
 * - User account restoration (for soft-deleted accounts)
 * - Deletion status checking
 * - Permanent deletion (after retention period)
 *
 * All endpoints require authentication via JWT token.
 *
 * Validates: Requirements 3.5
 * - Supports user account deletion with data cleanup
 * - Implements cascading data cleanup (sessions, tunnels, audit logs)
 * - Adds soft delete option for compliance
 *
 * @fileoverview User account deletion endpoints
 * @version 1.0.0
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { UserDeletionService } from '../services/user-deletion-service.js';
import logger from '../logger.js';

const userIdParamSchema = {
  params: z.object({
    id: z.string().min(1).max(200),
  }),
};

const deleteUserBodySchema = {
  params: z.object({
    id: z.string().min(1).max(200),
  }),
  body: z
    .object({
      softDelete: z.boolean().optional().default(true),
      reason: z
        .string()
        .min(1)
        .max(1000)
        .optional()
        .default('User requested deletion'),
    })
    .optional()
    .default({}),
  query: z
    .object({
      softDelete: z
        .string()
        .transform((v) => v !== 'false')
        .optional()
        .default('true'),
      reason: z.string().max(1000).optional(),
    })
    .optional()
    .default({}),
};

const router = express.Router();
let userDeletionService = null;

/**
 * Initialize the user deletion service
 * Called once during server startup
 */
export async function initializeUserDeletionService() {
  try {
    userDeletionService = new UserDeletionService();
    await userDeletionService.initialize();
    logger.info('[UserDeletionRoutes] User deletion service initialized');
  } catch (error) {
    logger.error(
      '[UserDeletionRoutes] Failed to initialize user deletion service',
      {
        error: error.message,
      },
    );
    throw error;
  }
}

/**
 * DELETE /api/users/:id
 *
 * Delete user account with cascading data cleanup
 *
 * Query Parameters:
 * - softDelete: boolean (default: true) - If true, soft delete; if false, hard delete
 * - reason: string (optional) - Reason for deletion (for audit purposes)
 *
 * Request body (optional):
 * {
 *   "softDelete": true,
 *   "reason": "User requested deletion"
 * }
 *
 * Returns:
 * - Deletion result with cleanup summary
 * - Number of records deleted/cleaned up
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 * Authorization: User can only delete their own account
 */
router.delete('/:id', authenticateJWT, validateSchema(deleteUserBodySchema), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to delete account',
      });
    }

    if (!userDeletionService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'User deletion service is not initialized',
      });
    }

    const { id } = req.params;
    const userId = req.user.sub;

    // Verify user is deleting their own account
    if (id !== userId) {
      logger.warn('[UserDeletion] Unauthorized deletion attempt', {
        requestingUser: userId,
        targetUser: id,
      });

      return res.status(403).json({
        error: 'Forbidden',
        code: 'FORBIDDEN',
        message: 'You can only delete your own account',
      });
    }

    const softDelete = req.body?.softDelete ?? req.query?.softDelete ?? true;
    const reason =
      req.body?.reason || req.query?.reason || 'User requested deletion';

    logger.info('[UserDeletion] Account deletion initiated', {
      userId,
      softDelete,
      reason,
    });

    const result = await userDeletionService.deleteUserAccount(userId, {
      softDelete,
      reason,
    });

    logger.info('[UserDeletion] Account deleted successfully', {
      userId,
      result,
    });

    res.json({
      success: true,
      data: result,
      message: softDelete
        ? 'Account marked for deletion. You can restore it within 30 days.'
        : 'Account permanently deleted with all associated data.',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserDeletion] Error deleting account', {
      userId: req.user?.sub,
      targetId: req.params.id,
      error: error.message,
    });

    if (error.message === 'User not found') {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND',
        message: 'User account not found',
      });
    }

    res.status(500).json({
      error: 'Failed to delete account',
      code: 'DELETION_FAILED',
      message: 'An error occurred while deleting your account',
    });
  }
});

/**
 * POST /api/users/:id/restore
 *
 * Restore a soft-deleted user account
 *
 * Returns:
 * - Restoration result
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 * Authorization: User can only restore their own account
 */
router.post('/:id/restore', authenticateJWT, validateSchema(userIdParamSchema), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to restore account',
      });
    }

    if (!userDeletionService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'User deletion service is not initialized',
      });
    }

    const { id } = req.params;
    const userId = req.user.sub;

    // Verify user is restoring their own account
    if (id !== userId) {
      logger.warn('[UserDeletion] Unauthorized restoration attempt', {
        requestingUser: userId,
        targetUser: id,
      });

      return res.status(403).json({
        error: 'Forbidden',
        code: 'FORBIDDEN',
        message: 'You can only restore your own account',
      });
    }

    logger.info('[UserDeletion] Account restoration initiated', {
      userId,
    });

    const result = await userDeletionService.restoreUserAccount(userId);

    logger.info('[UserDeletion] Account restored successfully', {
      userId,
    });

    res.json({
      success: true,
      data: result,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserDeletion] Error restoring account', {
      userId: req.user?.sub,
      targetId: req.params.id,
      error: error.message,
    });

    if (error.message === 'User not found or not soft-deleted') {
      return res.status(404).json({
        error: 'User not found or not deleted',
        code: 'USER_NOT_FOUND',
        message: 'User account not found or is not soft-deleted',
      });
    }

    res.status(500).json({
      error: 'Failed to restore account',
      code: 'RESTORATION_FAILED',
      message: 'An error occurred while restoring your account',
    });
  }
});

/**
 * GET /api/users/:id/deletion-status
 *
 * Check if a user account is deleted
 *
 * Returns:
 * - Deletion status
 * - Deletion timestamp (if deleted)
 * - Deletion reason (if deleted)
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 * Authorization: User can only check their own status
 */
router.get('/:id/deletion-status', authenticateJWT, validateSchema(userIdParamSchema), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to check deletion status',
      });
    }

    if (!userDeletionService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'User deletion service is not initialized',
      });
    }

    const { id } = req.params;
    const userId = req.user.sub;

    // Verify user is checking their own status
    if (id !== userId) {
      logger.warn('[UserDeletion] Unauthorized status check attempt', {
        requestingUser: userId,
        targetUser: id,
      });

      return res.status(403).json({
        error: 'Forbidden',
        code: 'FORBIDDEN',
        message: 'You can only check your own deletion status',
      });
    }

    logger.debug('[UserDeletion] Deletion status check', {
      userId,
    });

    const isDeleted = await userDeletionService.isUserDeleted(userId);

    if (isDeleted) {
      const deletionInfo = await userDeletionService.getDeletionInfo(userId);

      return res.json({
        success: true,
        data: {
          isDeleted: true,
          ...deletionInfo,
          restorationDeadline: new Date(
            new Date(deletionInfo.deletedAt).getTime() +
              30 * 24 * 60 * 60 * 1000,
          ).toISOString(),
        },
        timestamp: new Date().toISOString(),
      });
    }

    res.json({
      success: true,
      data: {
        isDeleted: false,
        userId,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserDeletion] Error checking deletion status', {
      userId: req.user?.sub,
      targetId: req.params.id,
      error: error.message,
    });

    if (error.message === 'User not found') {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND',
        message: 'User account not found',
      });
    }

    res.status(500).json({
      error: 'Failed to check deletion status',
      code: 'STATUS_CHECK_FAILED',
      message: 'An error occurred while checking deletion status',
    });
  }
});

/**
 * POST /api/users/:id/permanent-delete
 *
 * Permanently delete a soft-deleted user account (admin only)
 * This endpoint is typically called after a retention period
 *
 * Returns:
 * - Permanent deletion result with cleanup summary
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 * Authorization: Admin only
 */
router.post('/:id/permanent-delete', authenticateJWT, validateSchema(userIdParamSchema), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to permanently delete account',
      });
    }

    if (!userDeletionService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'User deletion service is not initialized',
      });
    }

    // Check if user is admin (this would be checked via RBAC middleware in production)
    const isAdmin =
      req.user.role === 'admin' ||
      req.user.permissions?.includes('admin:delete');

    if (!isAdmin) {
      logger.warn('[UserDeletion] Unauthorized permanent deletion attempt', {
        requestingUser: req.user.sub,
        targetUser: req.params.id,
      });

      return res.status(403).json({
        error: 'Forbidden',
        code: 'FORBIDDEN',
        message: 'Only administrators can permanently delete accounts',
      });
    }

    const { id } = req.params;

    logger.info('[UserDeletion] Permanent deletion initiated', {
      adminUser: req.user.sub,
      targetUser: id,
    });

    const result = await userDeletionService.permanentlyDeleteUser(id);

    logger.info('[UserDeletion] Account permanently deleted', {
      adminUser: req.user.sub,
      targetUser: id,
      result,
    });

    res.json({
      success: true,
      data: result,
      message: 'Account permanently deleted with all associated data.',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[UserDeletion] Error permanently deleting account', {
      adminUser: req.user?.sub,
      targetId: req.params.id,
      error: error.message,
    });

    if (error.message === 'User not found') {
      return res.status(404).json({
        error: 'User not found',
        code: 'USER_NOT_FOUND',
        message: 'User account not found',
      });
    }

    res.status(500).json({
      error: 'Failed to permanently delete account',
      code: 'PERMANENT_DELETION_FAILED',
      message: 'An error occurred while permanently deleting the account',
    });
  }
});

export default router;
