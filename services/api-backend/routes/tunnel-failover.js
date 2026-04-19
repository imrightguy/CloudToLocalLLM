/**
 * Tunnel Failover Management API Routes
 *
 * Provides endpoints for:
 * - Selecting endpoints with automatic failover
 * - Viewing failover status and endpoint health
 * - Manual failover to specific endpoints
 * - Resetting endpoint failure counts
 * - Managing endpoint recovery
 *
 * All endpoints require authentication via JWT token.
 *
 * Validates: Requirements 4.4
 * - Supports multiple tunnel endpoints for failover
 * - Implements endpoint health checking
 * - Adds automatic failover logic
 *
 * @fileoverview Tunnel failover management endpoints
 * @version 1.0.0
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { TunnelFailoverService } from '../services/tunnel-failover-service.js';
import logger from '../logger.js';

const router = express.Router();
let failoverService = null;

const tunnelIdSchema = z.object({
  tunnelId: z.string().uuid(),
});

const endpointIdBodySchema = z.object({
  endpointId: z.string().uuid(),
});

const recordFailureBodySchema = z.object({
  endpointId: z.string().uuid(),
  error: z.string().optional(),
});

/**
 * Initialize the tunnel failover service
 * Called once during server startup
 */
export async function initializeTunnelFailoverService() {
  try {
    failoverService = new TunnelFailoverService();
    await failoverService.initialize();
    logger.info('[TunnelFailoverRoutes] Tunnel failover service initialized');
  } catch (error) {
    logger.error(
      '[TunnelFailoverRoutes] Failed to initialize tunnel failover service',
      {
        error: error.message,
      },
    );
    throw error;
  }
}

/**
 * GET /api/tunnels/:tunnelId/failover/endpoint
 *
 * Get the best available endpoint for a tunnel
 *
 * Uses weighted selection based on:
 * - Health status (healthy endpoints only)
 * - Priority (higher priority first)
 * - Weight (weighted round-robin)
 *
 * Returns:
 * - Selected endpoint with URL, priority, weight
 * - Health status and last health check time
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get(
  '/:tunnelId/failover/endpoint',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to access tunnel endpoints',
        });
      }

      if (!failoverService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Tunnel failover service is not initialized',
        });
      }

      const { tunnelId } = req.params;

      const endpoint = await failoverService.selectEndpoint(tunnelId);

      if (!endpoint) {
        return res.status(404).json({
          error: 'No endpoints available',
          code: 'NO_ENDPOINTS',
          message: 'No endpoints found for this tunnel',
        });
      }

      res.json({
        endpoint: {
          id: endpoint.id,
          url: endpoint.url,
          priority: endpoint.priority,
          weight: endpoint.weight,
          healthStatus: endpoint.health_status,
          lastHealthCheck: endpoint.last_health_check,
        },
      });
    } catch (error) {
      logger.error('[TunnelFailoverRoutes] Failed to get endpoint', {
        tunnelId: req.params.tunnelId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to get endpoint',
        code: 'ENDPOINT_SELECTION_FAILED',
        message: error.message,
      });
    }
  },
);

/**
 * GET /api/tunnels/:tunnelId/failover/status
 *
 * Get failover status for a tunnel
 *
 * Returns:
 * - All endpoints with health status
 * - Failure counts and recovery status
 * - Summary of healthy/unhealthy/recovering endpoints
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:tunnelId/failover/status', authenticateJWT, validateSchema({ params: tunnelIdSchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to view failover status',
      });
    }

    if (!failoverService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel failover service is not initialized',
      });
    }

    const { tunnelId } = req.params;
    const userId = req.user.sub;

    const status = await failoverService.getFailoverStatus(tunnelId, userId);

    res.json(status);
  } catch (error) {
    logger.error('[TunnelFailoverRoutes] Failed to get failover status', {
      tunnelId: req.params.tunnelId,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Tunnel not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'The specified tunnel does not exist',
      });
    }

    res.status(500).json({
      error: 'Failed to get failover status',
      code: 'FAILOVER_STATUS_FAILED',
      message: error.message,
    });
  }
});

/**
 * POST /api/tunnels/:tunnelId/failover/manual
 *
 * Manually trigger failover to a specific endpoint
 *
 * Request body:
 * {
 *   "endpointId": "endpoint-uuid"
 * }
 *
 * Returns:
 * - Selected endpoint details
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post('/:tunnelId/failover/manual', authenticateJWT, validateSchema({ params: tunnelIdSchema, body: endpointIdBodySchema }), async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to perform manual failover',
      });
    }

    if (!failoverService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Tunnel failover service is not initialized',
      });
    }

    const { tunnelId } = req.params;
    const { endpointId } = req.body;
    const userId = req.user.sub;

    const endpoint = await failoverService.manualFailover(
      tunnelId,
      endpointId,
      userId,
    );

    res.json({
      message: 'Manual failover triggered',
      endpoint: {
        id: endpoint.id,
        url: endpoint.url,
        priority: endpoint.priority,
        weight: endpoint.weight,
        healthStatus: endpoint.health_status,
      },
    });
  } catch (error) {
    logger.error('[TunnelFailoverRoutes] Failed to perform manual failover', {
      tunnelId: req.params.tunnelId,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Tunnel not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'The specified tunnel does not exist',
      });
    }

    if (error.message === 'Endpoint not found for this tunnel') {
      return res.status(404).json({
        error: 'Endpoint not found',
        code: 'ENDPOINT_NOT_FOUND',
        message: 'The specified endpoint does not exist for this tunnel',
      });
    }

    res.status(500).json({
      error: 'Failed to perform manual failover',
      code: 'MANUAL_FAILOVER_FAILED',
      message: error.message,
    });
  }
});

/**
 * POST /api/tunnels/:tunnelId/failover/record-failure
 *
 * Record an endpoint failure (internal use)
 *
 * Request body:
 * {
 *   "endpointId": "endpoint-uuid",
 *   "error": "Connection timeout"
 * }
 *
 * Returns:
 * - Updated endpoint state with failure count
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post(
  '/:tunnelId/failover/record-failure',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema, body: recordFailureBodySchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to record endpoint failure',
        });
      }

      if (!failoverService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Tunnel failover service is not initialized',
        });
      }

      const { tunnelId } = req.params;
      const { endpointId, error } = req.body;

      const state = await failoverService.recordEndpointFailure(
        endpointId,
        tunnelId,
        error || 'Unknown error',
      );

      res.json({
        message: 'Endpoint failure recorded',
        state: {
          endpointId,
          failureCount: state.failureCount,
          lastFailure: state.lastFailure,
          isUnhealthy: state.isUnhealthy,
        },
      });
    } catch (error) {
      logger.error('[TunnelFailoverRoutes] Failed to record endpoint failure', {
        tunnelId: req.params.tunnelId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to record endpoint failure',
        code: 'RECORD_FAILURE_FAILED',
        message: error.message,
      });
    }
  },
);

/**
 * POST /api/tunnels/:tunnelId/failover/record-success
 *
 * Record an endpoint success (internal use)
 *
 * Request body:
 * {
 *   "endpointId": "endpoint-uuid"
 * }
 *
 * Returns:
 * - Success message
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post(
  '/:tunnelId/failover/record-success',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema, body: endpointIdBodySchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to record endpoint success',
        });
      }

      if (!failoverService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Tunnel failover service is not initialized',
        });
      }

      const { endpointId } = req.body;

      await failoverService.recordEndpointSuccess(endpointId);

      res.json({
        message: 'Endpoint success recorded',
        endpointId,
      });
    } catch (error) {
      logger.error('[TunnelFailoverRoutes] Failed to record endpoint success', {
        tunnelId: req.params.tunnelId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to record endpoint success',
        code: 'RECORD_SUCCESS_FAILED',
        message: error.message,
      });
    }
  },
);

/**
 * POST /api/tunnels/:tunnelId/failover/reset-failures
 *
 * Reset failure count for an endpoint
 *
 * Request body:
 * {
 *   "endpointId": "endpoint-uuid"
 * }
 *
 * Returns:
 * - Success message
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post(
  '/:tunnelId/failover/reset-failures',
  authenticateJWT,
  validateSchema({ params: tunnelIdSchema, body: endpointIdBodySchema }),
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to reset endpoint failures',
        });
      }

      if (!failoverService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Tunnel failover service is not initialized',
        });
      }

      const { endpointId } = req.body;

      await failoverService.resetEndpointFailureCount(endpointId);

      res.json({
        message: 'Endpoint failure count reset',
        endpointId,
      });
    } catch (error) {
      logger.error('[TunnelFailoverRoutes] Failed to reset endpoint failures', {
        tunnelId: req.params.tunnelId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to reset endpoint failures',
        code: 'RESET_FAILURES_FAILED',
        message: error.message,
      });
    }
  },
);

export default router;
