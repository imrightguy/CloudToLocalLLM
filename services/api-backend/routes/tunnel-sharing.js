/**
 * Tunnel Sharing and Access Control API Routes
 *
 * Provides endpoints for:
 * - Sharing tunnels with other users
 * - Managing tunnel access permissions
 * - Creating and revoking share tokens
 * - Viewing tunnel shares and access logs
 *
 * All endpoints require authentication via JWT token.
 *
 * Validates: Requirements 4.8
 * - Supports tunnel sharing and access control
 * - Implements permission management for tunnel access
 *
 * @fileoverview Tunnel sharing and access control endpoints
 * @version 1.0.0
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { TunnelSharingService } from '../services/tunnel-sharing-service.js';
import logger from '../logger.js';

const router = express.Router();
let tunnelSharingService = null;

const tunnelIdSchema = z.object({
  id: z.string().uuid(),
});

/**
 * Initialize the tunnel sharing service
 * Called once during server startup
 */
export async function initializeTunnelSharingService() {
  try {
    tunnelSharingService = new TunnelSharingService();
    await tunnelSharingService.initialize();
    logger.info('[TunnelSharingRoutes] Tunnel sharing service initialized');
  } catch (error) {
    logger.error(
      '[TunnelSharingRoutes] Failed to initialize tunnel sharing service',
      {
        error: error.message,
      },
    );
    throw error;
  }
}

/**
 * POST /api/tunnels/:id/shares
 *
 * Share a tunnel with another user
 *
 * Request body:
 * {
 *   "sharedWithUserId": "user-uuid",
 *   "permission": "read" | "write" | "admin"
 * }
 *
 * Returns:
 * - Share ID
 * - Permission level
 * - Timestamps
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post('/:id/shares', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to share a tunnel',
      });
    }

    if (!tunnelSharingService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel sharing service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;
    const { sharedWithUserId, permission = 'read' } = req.body;

    // Validate required fields
    if (!sharedWithUserId) {
      return res.status(400).json({
        error: 'Bad request',
        code: 'INVALID_REQUEST',
        message: 'sharedWithUserId is required',
      });
    }

    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('user-agent');

    const share = await tunnelSharingService.shareTunnel(
      tunnelId,
      userId,
      sharedWithUserId,
      permission,
      ipAddress,
      userAgent,
    );

    logger.info('[TunnelSharingRoutes] Tunnel shared', {
      tunnelId,
      userId,
      sharedWithUserId,
      permission,
    });

    res.status(201).json({
      success: true,
      data: share,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelSharingRoutes] Error sharing tunnel', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (
      error.message.includes('not found') ||
      error.message.includes('permission')
    ) {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: error.message,
      });
    }

    if (error.message.includes('Invalid permission')) {
      return res.status(400).json({
        error: 'Bad request',
        code: 'INVALID_PERMISSION',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to share tunnel',
    });
  }
});

/**
 * GET /api/tunnels/:id/shares
 *
 * Get all shares for a tunnel (who has access)
 *
 * Returns:
 * - Array of shares with user info and permissions
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:id/shares', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to view tunnel shares',
      });
    }

    if (!tunnelSharingService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel sharing service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const shares = await tunnelSharingService.getTunnelShares(tunnelId, userId);

    logger.debug('[TunnelSharingRoutes] Tunnel shares retrieved', {
      tunnelId,
      userId,
      count: shares.length,
    });

    res.json({
      success: true,
      data: shares,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelSharingRoutes] Error retrieving tunnel shares', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (
      error.message.includes('not found') ||
      error.message.includes('permission')
    ) {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to retrieve tunnel shares',
    });
  }
});

/**
 * DELETE /api/tunnels/:id/shares/:sharedWithUserId
 *
 * Revoke tunnel access from a user
 *
 * Returns:
 * - Success message
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.delete(
  '/:id/shares/:sharedWithUserId',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to revoke tunnel access',
        });
      }

      if (!tunnelSharingService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Tunnel sharing service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { id: tunnelId, sharedWithUserId } = req.params;

      const ipAddress = req.ip || req.connection.remoteAddress;
      const userAgent = req.get('user-agent');

      await tunnelSharingService.revokeTunnelAccess(
        tunnelId,
        userId,
        sharedWithUserId,
        ipAddress,
        userAgent,
      );

      logger.info('[TunnelSharingRoutes] Tunnel access revoked', {
        tunnelId,
        userId,
        sharedWithUserId,
      });

      res.json({
        success: true,
        message: 'Tunnel access revoked successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[TunnelSharingRoutes] Error revoking tunnel access', {
        tunnelId: req.params.id,
        userId: req.user?.sub,
        error: error.message,
      });

      if (
        error.message.includes('not found') ||
        error.message.includes('permission')
      ) {
        return res.status(404).json({
          error: 'Not found',
          code: 'TUNNEL_NOT_FOUND',
          message: error.message,
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to revoke tunnel access',
      });
    }
  },
);

/**
 * GET /api/tunnels/shared-with-me
 *
 * Get tunnels shared with the authenticated user
 *
 * Query parameters:
 * - limit: Number of results (default: 50, max: 1000)
 * - offset: Result offset (default: 0)
 *
 * Returns:
 * - Array of shared tunnels with owner info
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/shared-with-me', authenticateJWT, async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to view shared tunnels',
      });
    }

    if (!tunnelSharingService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel sharing service is not initialized',
      });
    }

    const userId = req.user.sub;
    const limit = Math.min(parseInt(req.query.limit) || 50, 1000);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);

    const tunnels = await tunnelSharingService.getSharedTunnels(userId, {
      limit,
      offset,
    });

    logger.debug('[TunnelSharingRoutes] Shared tunnels retrieved', {
      userId,
      count: tunnels.length,
    });

    res.json({
      success: true,
      data: tunnels,
      pagination: {
        limit,
        offset,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelSharingRoutes] Error retrieving shared tunnels', {
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to retrieve shared tunnels',
    });
  }
});

/**
 * POST /api/tunnels/:id/share-tokens
 *
 * Create a temporary share token
 *
 * Request body:
 * {
 *   "permission": "read" | "write" | "admin",
 *   "expiresInHours": 24,
 *   "maxUses": 10 (optional)
 * }
 *
 * Returns:
 * - Token ID
 * - Token string
 * - Expiration time
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post('/:id/share-tokens', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to create share token',
      });
    }

    if (!tunnelSharingService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel sharing service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;
    const {
      permission = 'read',
      expiresInHours = 24,
      maxUses = null,
    } = req.body;

    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('user-agent');

    const token = await tunnelSharingService.createShareToken(
      tunnelId,
      userId,
      permission,
      expiresInHours,
      maxUses,
      ipAddress,
      userAgent,
    );

    logger.info('[TunnelSharingRoutes] Share token created', {
      tunnelId,
      userId,
      permission,
    });

    res.status(201).json({
      success: true,
      data: token,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelSharingRoutes] Error creating share token', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (
      error.message.includes('not found') ||
      error.message.includes('permission')
    ) {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: error.message,
      });
    }

    if (error.message.includes('Invalid permission')) {
      return res.status(400).json({
        error: 'Bad request',
        code: 'INVALID_PERMISSION',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to create share token',
    });
  }
});

/**
 * GET /api/tunnels/:id/share-tokens
 *
 * Get all share tokens for a tunnel
 *
 * Returns:
 * - Array of share tokens (without token strings)
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:id/share-tokens', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to view share tokens',
      });
    }

    if (!tunnelSharingService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel sharing service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const tokens = await tunnelSharingService.getShareTokens(tunnelId, userId);

    logger.debug('[TunnelSharingRoutes] Share tokens retrieved', {
      tunnelId,
      userId,
      count: tokens.length,
    });

    res.json({
      success: true,
      data: tokens,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelSharingRoutes] Error retrieving share tokens', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (
      error.message.includes('not found') ||
      error.message.includes('permission')
    ) {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to retrieve share tokens',
    });
  }
});

/**
 * DELETE /api/tunnels/:id/share-tokens/:tokenId
 *
 * Revoke a share token
 *
 * Returns:
 * - Success message
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.delete(
  '/:id/share-tokens/:tokenId',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to revoke share token',
        });
      }

      if (!tunnelSharingService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Tunnel sharing service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { tokenId } = req.params;

      const ipAddress = req.ip || req.connection.remoteAddress;
      const userAgent = req.get('user-agent');

      await tunnelSharingService.revokeShareToken(
        tokenId,
        userId,
        ipAddress,
        userAgent,
      );

      logger.info('[TunnelSharingRoutes] Share token revoked', {
        tokenId,
        userId,
      });

      res.json({
        success: true,
        message: 'Share token revoked successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[TunnelSharingRoutes] Error revoking share token', {
        tokenId: req.params.tokenId,
        userId: req.user?.sub,
        error: error.message,
      });

      if (
        error.message.includes('not found') ||
        error.message.includes('permission')
      ) {
        return res.status(404).json({
          error: 'Not found',
          code: 'TOKEN_NOT_FOUND',
          message: error.message,
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to revoke share token',
      });
    }
  },
);

/**
 * GET /api/tunnels/:id/access-logs
 *
 * Get tunnel access logs (audit trail)
 *
 * Query parameters:
 * - limit: Number of results (default: 50)
 * - offset: Result offset (default: 0)
 *
 * Returns:
 * - Array of access log entries
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:id/access-logs', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to view access logs',
      });
    }

    if (!tunnelSharingService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel sharing service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 50, 1000);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);

    const logs = await tunnelSharingService.getTunnelAccessLogs(
      tunnelId,
      userId,
      {
        limit,
        offset,
      },
    );

    logger.debug('[TunnelSharingRoutes] Access logs retrieved', {
      tunnelId,
      userId,
      count: logs.length,
    });

    res.json({
      success: true,
      data: logs,
      pagination: {
        limit,
        offset,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelSharingRoutes] Error retrieving access logs', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (
      error.message.includes('not found') ||
      error.message.includes('permission')
    ) {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to retrieve access logs',
    });
  }
});

/**
 * PUT /api/tunnels/:id/shares/:shareId/permission
 *
 * Update share permission
 *
 * Request body:
 * {
 *   "permission": "read" | "write" | "admin"
 * }
 *
 * Returns:
 * - Updated share with new permission
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.put(
  '/:id/shares/:shareId/permission',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to update share permission',
        });
      }

      if (!tunnelSharingService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Tunnel sharing service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { shareId } = req.params;
      const { permission } = req.body;

      if (!permission) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_REQUEST',
          message: 'permission is required',
        });
      }

      const ipAddress = req.ip || req.connection.remoteAddress;
      const userAgent = req.get('user-agent');

      const updatedShare = await tunnelSharingService.updateSharePermission(
        shareId,
        userId,
        permission,
        ipAddress,
        userAgent,
      );

      logger.info('[TunnelSharingRoutes] Share permission updated', {
        shareId,
        userId,
        permission,
      });

      res.json({
        success: true,
        data: updatedShare,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[TunnelSharingRoutes] Error updating share permission', {
        shareId: req.params.shareId,
        userId: req.user?.sub,
        error: error.message,
      });

      if (
        error.message.includes('not found') ||
        error.message.includes('permission')
      ) {
        return res.status(404).json({
          error: 'Not found',
          code: 'SHARE_NOT_FOUND',
          message: error.message,
        });
      }

      if (error.message.includes('Invalid permission')) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_PERMISSION',
          message: error.message,
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to update share permission',
      });
    }
  },
);

export default router;
