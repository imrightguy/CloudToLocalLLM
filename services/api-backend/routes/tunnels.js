/**
 * Tunnel Lifecycle Management API Routes
 *
 * Provides endpoints for:
 * - Tunnel creation, retrieval, updates, and deletion
 * - Tunnel status management (start/stop operations)
 * - Tunnel configuration management
 * - Tunnel endpoint management for failover
 * - Tunnel metrics and activity tracking
 *
 * All endpoints require authentication via JWT token.
 *
 * Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.6
 * - Provides endpoints for tunnel lifecycle management (create, start, stop, delete)
 * - Tracks tunnel status and health metrics
 * - Implements tunnel configuration management
 * - Supports multiple tunnel endpoints for failover
 * - Implements tunnel metrics collection and aggregation
 *
 * @fileoverview Tunnel lifecycle management endpoints
 * @version 1.0.0
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { TunnelService } from '../services/tunnel-service.js';
import logger from '../logger.js';

const router = express.Router();
let tunnelService = null;

// Zod schemas for validation
const tunnelEndpointSchema = z.object({
  url: z.string().url().optional(),
  priority: z.number().int().optional(),
  weight: z.number().int().optional(),
});

const createTunnelSchema = z.object({
  name: z.string().min(1).max(255),
  config: z
    .object({
      maxConnections: z.number().int().positive().optional(),
      timeout: z.number().int().positive().optional(),
      compression: z.boolean().optional(),
    })
    .optional(),
  endpoints: z.array(tunnelEndpointSchema).optional(),
});

const updateTunnelSchema = z
  .object({
    name: z.string().min(1).max(255).optional(),
    config: z
      .object({
        maxConnections: z.number().int().positive().optional(),
        timeout: z.number().int().positive().optional(),
        compression: z.boolean().optional(),
      })
      .optional(),
    endpoints: z.array(tunnelEndpointSchema).optional(),
  })
  .partial();

const tunnelIdSchema = z.object({
  id: z.string().uuid(),
});

/**
 * Initialize the tunnel service
 * Called once during server startup
 */
export async function initializeTunnelService() {
  try {
    tunnelService = new TunnelService();
    await tunnelService.initialize();
    logger.info('[TunnelRoutes] Tunnel service initialized');
  } catch (error) {
    logger.error('[TunnelRoutes] Failed to initialize tunnel service', {
      error: error.message,
    });
    throw error;
  }
}

/**
 * @swagger
 * /tunnels:
 *   post:
 *     summary: Create a new tunnel
 *     description: |
 *       Creates a new tunnel with specified configuration and endpoints.
 *       Tunnels are used to establish secure connections to local services.
 *
 *       **Validates: Requirements 4.1, 4.3**
 *       - Provides endpoints for tunnel lifecycle management (create, start, stop, delete)
 *       - Implements tunnel configuration management
 *     tags:
 *       - Tunnels
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required:
 *               - name
 *             properties:
 *               name:
 *                 type: string
 *                 description: Tunnel name
 *               config:
 *                 type: object
 *                 properties:
 *                   maxConnections:
 *                     type: integer
 *                     default: 100
 *                   timeout:
 *                     type: integer
 *                     default: 30000
 *                   compression:
 *                     type: boolean
 *                     default: true
 *               endpoints:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     url:
 *                       type: string
 *                       format: uri
 *                     priority:
 *                       type: integer
 *                     weight:
 *                       type: integer
 *           example:
 *             name: "My Tunnel"
 *             config:
 *               maxConnections: 100
 *               timeout: 30000
 *               compression: true
 *             endpoints:
 *               - url: "http://localhost:8000"
 *                 priority: 1
 *                 weight: 1
 *     responses:
 *       201:
 *         description: Tunnel created successfully
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Tunnel'
 *       400:
 *         description: Invalid tunnel configuration
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.post(
  '/',
  authenticateJWT,
  validateSchema({ body: createTunnelSchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to create a tunnel',
        });
      }

      if (!tunnelService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Tunnel service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { name, config, endpoints } = req.body;

    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('user-agent');

    const tunnel = await tunnelService.createTunnel(
      userId,
      { name, config, endpoints },
      ipAddress,
      userAgent,
    );

    logger.info('[TunnelRoutes] Tunnel created', {
      tunnelId: tunnel.id,
      userId,
      name,
    });

    res.status(201).json({
      success: true,
      data: tunnel,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error creating tunnel', {
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message.includes('already exists')) {
      return res.status(409).json({
        error: 'Conflict',
        code: 'TUNNEL_EXISTS',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to create tunnel',
    });
  }
});

/**
 * GET /api/tunnels
 *
 * List all tunnels for the authenticated user
 *
 * Query parameters:
 * - limit: Number of results (default: 50, max: 1000)
 * - offset: Result offset (default: 0)
 *
 * Returns:
 * - Array of tunnels
 * - Total count
 * - Pagination info
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/', authenticateJWT, async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to list tunnels',
      });
    }

    if (!tunnelService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const limit = Math.min(parseInt(req.query.limit) || 50, 1000);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);

    const result = await tunnelService.listTunnels(userId, { limit, offset });

    logger.debug('[TunnelRoutes] Tunnels listed', {
      userId,
      count: result.tunnels.length,
      total: result.total,
    });

    res.json({
      success: true,
      data: result.tunnels,
      pagination: {
        limit,
        offset,
        total: result.total,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error listing tunnels', {
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to list tunnels',
    });
  }
});

/**
 * GET /api/tunnels/:id
 *
 * Get a specific tunnel by ID
 *
 * Returns:
 * - Tunnel details
 * - Configuration
 * - Endpoints
 * - Metrics
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:id', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to retrieve tunnel',
      });
    }

    if (!tunnelService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const tunnel = await tunnelService.getTunnelById(tunnelId, userId);

    logger.debug('[TunnelRoutes] Tunnel retrieved', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: tunnel,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error retrieving tunnel', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to retrieve tunnel',
    });
  }
});

/**
 * PUT /api/tunnels/:id
 *
 * Update a tunnel
 *
 * Request body:
 * {
 *   "name": "Updated Tunnel Name",
 *   "config": { ... },
 *   "endpoints": [ ... ]
 * }
 *
 * Returns:
 * - Updated tunnel details
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.put(
  '/:id',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema, body: updateTunnelSchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to update tunnel',
        });
      }

      if (!tunnelService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Tunnel service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { id: tunnelId } = req.params;
      const updateData = req.body;

    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('user-agent');

    const tunnel = await tunnelService.updateTunnel(
      tunnelId,
      userId,
      updateData,
      ipAddress,
      userAgent,
    );

    logger.info('[TunnelRoutes] Tunnel updated', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: tunnel,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error updating tunnel', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    if (error.message.includes('already exists')) {
      return res.status(409).json({
        error: 'Conflict',
        code: 'TUNNEL_EXISTS',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to update tunnel',
    });
  }
});

/**
 * DELETE /api/tunnels/:id
 *
 * Delete a tunnel
 *
 * Returns:
 * - Success message
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.delete(
  '/:id',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to delete tunnel',
        });
      }

      if (!tunnelService) {
        return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('user-agent');

    await tunnelService.deleteTunnel(tunnelId, userId, ipAddress, userAgent);

    logger.info('[TunnelRoutes] Tunnel deleted', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      message: 'Tunnel deleted successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error deleting tunnel', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to delete tunnel',
    });
  }
});

/**
 * POST /api/tunnels/:id/start
 *
 * Start a tunnel (change status to connecting/connected)
 *
 * Returns:
 * - Updated tunnel with new status
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post(
  '/:id/start',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to start tunnel',
        });
      }

      if (!tunnelService) {
        return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('user-agent');

    const tunnel = await tunnelService.updateTunnelStatus(
      tunnelId,
      userId,
      'connecting',
      ipAddress,
      userAgent,
    );

    logger.info('[TunnelRoutes] Tunnel started', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: tunnel,
      message: 'Tunnel start initiated',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error starting tunnel', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to start tunnel',
    });
  }
});

/**
 * POST /api/tunnels/:id/stop
 *
 * Stop a tunnel (change status to disconnected)
 *
 * Returns:
 * - Updated tunnel with new status
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post(
  '/:id/stop',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to stop tunnel',
        });
      }

      if (!tunnelService) {
        return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('user-agent');

    const tunnel = await tunnelService.updateTunnelStatus(
      tunnelId,
      userId,
      'disconnected',
      ipAddress,
      userAgent,
    );

    logger.info('[TunnelRoutes] Tunnel stopped', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: tunnel,
      message: 'Tunnel stopped successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error stopping tunnel', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to stop tunnel',
    });
  }
});

/**
 * GET /api/tunnels/:id/metrics
 *
 * Get tunnel metrics
 *
 * Returns:
 * - Request count
 * - Success/error counts
 * - Average latency
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:id/metrics', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to retrieve metrics',
      });
    }

    if (!tunnelService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const metrics = await tunnelService.getTunnelMetrics(tunnelId, userId);

    logger.debug('[TunnelRoutes] Tunnel metrics retrieved', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error retrieving metrics', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to retrieve metrics',
    });
  }
});

/**
 * GET /api/tunnels/:id/activity
 *
 * Get tunnel activity logs
 *
 * Query parameters:
 * - limit: Number of results (default: 50)
 * - offset: Result offset (default: 0)
 *
 * Returns:
 * - Array of activity log entries
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:id/activity', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to retrieve activity logs',
      });
    }

    if (!tunnelService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 50, 1000);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);

    const logs = await tunnelService.getTunnelActivityLogs(tunnelId, userId, {
      limit,
      offset,
    });

    logger.debug('[TunnelRoutes] Tunnel activity logs retrieved', {
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
    logger.error('[TunnelRoutes] Error retrieving activity logs', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to retrieve activity logs',
    });
  }
});

/**
 * GET /api/tunnels/:id/config
 *
 * Get tunnel configuration
 *
 * Returns:
 * - maxConnections: Maximum concurrent connections
 * - timeout: Request timeout in milliseconds
 * - compression: Enable/disable compression
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:id/config', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to retrieve configuration',
      });
    }

    if (!tunnelService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const config = await tunnelService.getTunnelConfig(tunnelId, userId);

    logger.debug('[TunnelRoutes] Tunnel config retrieved', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: config,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error retrieving config', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to retrieve configuration',
    });
  }
});

/**
 * PUT /api/tunnels/:id/config
 *
 * Update tunnel configuration
 *
 * Request body:
 * {
 *   "maxConnections": 100,
 *   "timeout": 30000,
 *   "compression": true
 * }
 *
 * Returns:
 * - Updated configuration
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.put(
  '/:id/config',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to update configuration',
        });
      }

      if (!tunnelService) {
        return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;
    const configUpdate = req.body;

    // Validate configuration
    const { validateTunnelConfig } =
      await import('../utils/tunnel-config-validation.js');
    const validation = validateTunnelConfig(configUpdate);

    if (!validation.isValid) {
      return res.status(400).json({
        error: 'Bad request',
        code: 'INVALID_CONFIG',
        message: 'Invalid tunnel configuration',
        details: validation.errors,
      });
    }

    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('user-agent');

    const config = await tunnelService.updateTunnelConfig(
      tunnelId,
      userId,
      configUpdate,
      ipAddress,
      userAgent,
    );

    logger.info('[TunnelRoutes] Tunnel config updated', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: config,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error updating config', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to update configuration',
    });
  }
});

/**
 * POST /api/tunnels/:id/config/reset
 *
 * Reset tunnel configuration to defaults
 *
 * Returns:
 * - Default configuration
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post(
  '/:id/config/reset',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to reset configuration',
        });
      }

      if (!tunnelService) {
        return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const ipAddress = req.ip || req.connection.remoteAddress;
    const userAgent = req.get('user-agent');

    const config = await tunnelService.resetTunnelConfig(
      tunnelId,
      userId,
      ipAddress,
      userAgent,
    );

    logger.info('[TunnelRoutes] Tunnel config reset', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: config,
      message: 'Configuration reset to defaults',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelRoutes] Error resetting config', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to reset configuration',
    });
  }
});

export default router;
