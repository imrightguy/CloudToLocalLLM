/**
 * Tunnel Health and Status API Routes
 *
 * Provides endpoints for:
 * - Tunnel status tracking and monitoring
 * - Endpoint health checking
 * - Metrics collection and retrieval
 * - Health status updates
 *
 * All endpoints require authentication via JWT token.
 *
 * Validates: Requirements 4.2, 4.6
 * - Tracks tunnel status and health metrics
 * - Implements tunnel metrics collection and aggregation
 *
 * @fileoverview Tunnel health and status endpoints
 * @version 1.0.0
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { TunnelHealthService } from '../services/tunnel-health-service.js';
import logger from '../logger.js';

const router = express.Router();
let tunnelHealthService = null;

const tunnelIdSchema = z.object({
  id: z.string().uuid(),
});

/**
 * Initialize the tunnel health service
 * Called once during server startup
 */
export async function initializeTunnelHealthService() {
  try {
    tunnelHealthService = new TunnelHealthService();
    await tunnelHealthService.initialize();
    logger.info('[TunnelHealthRoutes] Tunnel health service initialized');
  } catch (error) {
    logger.error(
      '[TunnelHealthRoutes] Failed to initialize tunnel health service',
      {
        error: error.message,
      },
    );
    throw error;
  }
}

/**
 * GET /api/tunnels/:id/status
 *
 * Get tunnel status and health summary
 *
 * Returns:
 * - Tunnel status (created, connecting, connected, disconnected, error)
 * - Endpoint health statuses
 * - Aggregated metrics
 * - Last update timestamp
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:id/status', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to retrieve tunnel status',
      });
    }

    if (!tunnelHealthService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel health service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const statusSummary = await tunnelHealthService.getTunnelStatusSummary(
      tunnelId,
      userId,
    );

    logger.debug('[TunnelHealthRoutes] Tunnel status retrieved', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: statusSummary,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelHealthRoutes] Error retrieving tunnel status', {
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
      message: 'Failed to retrieve tunnel status',
    });
  }
});

/**
 * GET /api/tunnels/:id/health
 *
 * Get endpoint health status for a tunnel
 *
 * Returns:
 * - Array of endpoints with health status
 * - Last health check timestamp for each endpoint
 * - Priority and weight information
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:id/health', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to retrieve health status',
      });
    }

    if (!tunnelHealthService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel health service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    const healthStatus = await tunnelHealthService.getEndpointHealthStatus(
      tunnelId,
      userId,
    );

    logger.debug('[TunnelHealthRoutes] Endpoint health status retrieved', {
      tunnelId,
      userId,
      endpointCount: healthStatus.length,
    });

    res.json({
      success: true,
      data: healthStatus,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelHealthRoutes] Error retrieving health status', {
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
      message: 'Failed to retrieve health status',
    });
  }
});

/**
 * POST /api/tunnels/:id/health-check
 *
 * Manually trigger a health check for tunnel endpoints
 *
 * Returns:
 * - Health check results for each endpoint
 * - Updated health statuses
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post('/:id/health-check', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to trigger health check',
      });
    }

    if (!tunnelHealthService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel health service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    // Verify tunnel ownership
    const { getPool } = await import('../database/db-pool.js');
    const pool = getPool();
    const tunnelResult = await pool.query(
      'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
      [tunnelId, userId],
    );

    if (tunnelResult.rows.length === 0) {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    // Perform health check
    const healthCheckResults =
      await tunnelHealthService.performHealthCheck(tunnelId);

    logger.info('[TunnelHealthRoutes] Health check triggered', {
      tunnelId,
      userId,
      endpointCount: healthCheckResults.endpoints.length,
    });

    res.json({
      success: true,
      data: healthCheckResults,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelHealthRoutes] Error triggering health check', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to trigger health check',
    });
  }
});

/**
 * GET /api/tunnels/:id/metrics
 *
 * Get tunnel metrics (request count, success rate, latency)
 *
 * Returns:
 * - Request count
 * - Success count and success rate
 * - Error count
 * - Average, min, and max latency
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

    if (!tunnelHealthService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel health service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    // Verify tunnel ownership
    const { getPool } = await import('../database/db-pool.js');
    const pool = getPool();
    const tunnelResult = await pool.query(
      'SELECT metrics FROM tunnels WHERE id = $1 AND user_id = $2',
      [tunnelId, userId],
    );

    if (tunnelResult.rows.length === 0) {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    const metrics = JSON.parse(tunnelResult.rows[0].metrics);

    logger.debug('[TunnelHealthRoutes] Tunnel metrics retrieved', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      data: metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelHealthRoutes] Error retrieving metrics', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to retrieve metrics',
    });
  }
});

/**
 * POST /api/tunnels/:id/metrics/record
 *
 * Record request metrics for a tunnel
 *
 * Request body:
 * {
 *   "latency": 150,
 *   "success": true,
 *   "statusCode": 200
 * }
 *
 * Returns:
 * - Success message
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post('/:id/metrics/record', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to record metrics',
      });
    }

    if (!tunnelHealthService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel health service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;
    const { latency, success, statusCode } = req.body;

    // Validate required fields
    if (typeof latency !== 'number' || latency < 0) {
      return res.status(400).json({
        error: 'Bad request',
        code: 'INVALID_REQUEST',
        message: 'Latency must be a non-negative number',
      });
    }

    if (typeof success !== 'boolean') {
      return res.status(400).json({
        error: 'Bad request',
        code: 'INVALID_REQUEST',
        message: 'Success must be a boolean',
      });
    }

    // Verify tunnel ownership
    const { getPool } = await import('../database/db-pool.js');
    const pool = getPool();
    const tunnelResult = await pool.query(
      'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
      [tunnelId, userId],
    );

    if (tunnelResult.rows.length === 0) {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    // Record metrics
    tunnelHealthService.recordRequestMetrics(tunnelId, {
      latency,
      success,
      statusCode,
    });

    logger.debug('[TunnelHealthRoutes] Request metrics recorded', {
      tunnelId,
      userId,
      latency,
      success,
    });

    res.json({
      success: true,
      message: 'Metrics recorded successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelHealthRoutes] Error recording metrics', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to record metrics',
    });
  }
});

/**
 * POST /api/tunnels/:id/metrics/flush
 *
 * Flush accumulated metrics to database
 *
 * Returns:
 * - Success message
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post('/:id/metrics/flush', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to flush metrics',
      });
    }

    if (!tunnelHealthService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel health service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { id: tunnelId } = req.params;

    // Verify tunnel ownership
    const { getPool } = await import('../database/db-pool.js');
    const pool = getPool();
    const tunnelResult = await pool.query(
      'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
      [tunnelId, userId],
    );

    if (tunnelResult.rows.length === 0) {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    // Flush metrics
    await tunnelHealthService.flushMetricsToDatabase(tunnelId);

    logger.info('[TunnelHealthRoutes] Metrics flushed to database', {
      tunnelId,
      userId,
    });

    res.json({
      success: true,
      message: 'Metrics flushed successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelHealthRoutes] Error flushing metrics', {
      tunnelId: req.params.id,
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to flush metrics',
    });
  }
});

export default router;
