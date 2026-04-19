/**
 * Tunnel Webhook Management API Routes
 *
 * Provides endpoints for:
 * - Webhook registration and management
 * - Webhook delivery status tracking
 * - Webhook event history
 * - Webhook testing and debugging
 *
 * All endpoints require authentication via JWT token.
 *
 * Validates: Requirements 4.10, 10.1, 10.2, 10.3, 10.4
 * - Provides tunnel status webhooks for real-time updates
 * - Supports webhook registration for events
 * - Implements webhook delivery with retry logic
 * - Supports webhook signature verification
 * - Tracks webhook delivery status and failures
 *
 * @fileoverview Tunnel webhook management endpoints
 * @version 1.0.0
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { TunnelWebhookService } from '../services/tunnel-webhook-service.js';
import logger from '../logger.js';

const router = express.Router();
let webhookService = null;

// Zod schemas
const registerWebhookSchema = z.object({
  url: z.string().url(),
  events: z.array(z.string()).min(1).optional(),
});

const webhookParamsSchema = z.object({
  tunnelId: z.string().uuid(),
  webhookId: z.string().uuid(),
});

const updateWebhookSchema = z.object({
  url: z.string().url().optional(),
  events: z.array(z.string()).min(1).optional(),
  is_active: z.boolean().optional(),
});

/**
 * Initialize the webhook service
 * Called once during server startup
 */
export async function initializeTunnelWebhookService() {
  try {
    webhookService = new TunnelWebhookService();
    await webhookService.initialize();
    logger.info('[TunnelWebhookRoutes] Tunnel webhook service initialized');
  } catch (error) {
    logger.error('[TunnelWebhookRoutes] Failed to initialize webhook service', {
      error: error.message,
    });
    throw error;
  }
}

/**
 * POST /api/tunnels/:tunnelId/webhooks
 *
 * Register a webhook for tunnel events
 *
 * Request body:
 * {
 *   "url": "https://example.com/webhook",
 *   "events": ["tunnel.status_changed"]
 * }
 *
 * Returns:
 * - Webhook ID
 * - Webhook URL and events
 * - Secret for signature verification
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post('/:tunnelId/webhooks',
  validateSchema({ params: z.object({ tunnelId: z.string().uuid() }), body: registerWebhookSchema }),
  authenticateJWT,
  async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to register webhook',
      });
    }

    if (!webhookService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Webhook service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { tunnelId } = req.params;
    const { url, events } = req.body;

    const webhook = await webhookService.registerWebhook(
      userId,
      tunnelId,
      url,
      events,
    );

    logger.info('[TunnelWebhookRoutes] Webhook registered', {
      webhookId: webhook.id,
      userId,
      tunnelId,
    });

    res.status(201).json({
      success: true,
      data: webhook,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelWebhookRoutes] Error registering webhook', {
      userId: req.user?.sub,
      tunnelId: req.params.tunnelId,
      error: error.message,
    });

    if (error.message === 'Tunnel not found') {
      return res.status(404).json({
        error: 'Not found',
        code: 'TUNNEL_NOT_FOUND',
        message: 'Tunnel not found',
      });
    }

    if (error.message.includes('Invalid')) {
      return res.status(400).json({
        error: 'Bad request',
        code: 'INVALID_REQUEST',
        message: error.message,
      });
    }

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to register webhook',
    });
  }
});

/**
 * GET /api/tunnels/:tunnelId/webhooks
 *
 * List webhooks for a tunnel
 *
 * Query parameters:
 * - limit: Number of results (default: 50, max: 1000)
 * - offset: Result offset (default: 0)
 *
 * Returns:
 * - Array of webhooks
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/:tunnelId/webhooks', authenticateJWT, async (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to list webhooks',
      });
    }

    if (!webhookService) {
      return res.status(503).json({
        error: 'Service unavailable',
        code: 'SERVICE_UNAVAILABLE',
        message: 'Webhook service is not initialized',
      });
    }

    const userId = req.user.sub;
    const { tunnelId } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 50, 1000);
    const offset = Math.max(parseInt(req.query.offset) || 0, 0);

    const webhooks = await webhookService.listWebhooks(userId, tunnelId, {
      limit,
      offset,
    });

    logger.debug('[TunnelWebhookRoutes] Webhooks listed', {
      userId,
      tunnelId,
      count: webhooks.length,
    });

    res.json({
      success: true,
      data: webhooks,
      pagination: {
        limit,
        offset,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[TunnelWebhookRoutes] Error listing webhooks', {
      userId: req.user?.sub,
      tunnelId: req.params.tunnelId,
      error: error.message,
    });

    res.status(500).json({
      error: 'Internal server error',
      code: 'INTERNAL_ERROR',
      message: 'Failed to list webhooks',
    });
  }
});

/**
 * GET /api/tunnels/:tunnelId/webhooks/:webhookId
 *
 * Get a specific webhook
 *
 * Returns:
 * - Webhook details
 * - Events and URL
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get(
  '/:tunnelId/webhooks/:webhookId',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to retrieve webhook',
        });
      }

      if (!webhookService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Webhook service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { webhookId } = req.params;

      const webhook = await webhookService.getWebhookById(webhookId, userId);

      logger.debug('[TunnelWebhookRoutes] Webhook retrieved', {
        webhookId,
        userId,
      });

      res.json({
        success: true,
        data: webhook,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[TunnelWebhookRoutes] Error retrieving webhook', {
        webhookId: req.params.webhookId,
        userId: req.user?.sub,
        error: error.message,
      });

      if (error.message === 'Webhook not found') {
        return res.status(404).json({
          error: 'Not found',
          code: 'WEBHOOK_NOT_FOUND',
          message: 'Webhook not found',
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve webhook',
      });
    }
  },
);

/**
 * PUT /api/tunnels/:tunnelId/webhooks/:webhookId
 *
 * Update a webhook
 *
 * Request body:
 * {
 *   "url": "https://example.com/webhook",
 *   "events": ["tunnel.status_changed"],
 *   "is_active": true
 * }
 *
 * Returns:
 * - Updated webhook details
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.put(
  '/:tunnelId/webhooks/:webhookId',
  validateSchema({ params: webhookParamsSchema, body: updateWebhookSchema }),
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to update webhook',
        });
      }

      if (!webhookService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Webhook service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { webhookId } = req.params;
      const updateData = req.body;

      const webhook = await webhookService.updateWebhook(
        webhookId,
        userId,
        updateData,
      );

      logger.info('[TunnelWebhookRoutes] Webhook updated', {
        webhookId,
        userId,
      });

      res.json({
        success: true,
        data: webhook,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[TunnelWebhookRoutes] Error updating webhook', {
        webhookId: req.params.webhookId,
        userId: req.user?.sub,
        error: error.message,
      });

      if (error.message === 'Webhook not found') {
        return res.status(404).json({
          error: 'Not found',
          code: 'WEBHOOK_NOT_FOUND',
          message: 'Webhook not found',
        });
      }

      if (error.message.includes('Invalid')) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_REQUEST',
          message: error.message,
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to update webhook',
      });
    }
  },
);

/**
 * DELETE /api/tunnels/:tunnelId/webhooks/:webhookId
 *
 * Delete a webhook
 *
 * Returns:
 * - Success message
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.delete(
  '/:tunnelId/webhooks/:webhookId',
  validateSchema({ params: webhookParamsSchema }),
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to delete webhook',
        });
      }

      if (!webhookService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Webhook service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { webhookId } = req.params;

      await webhookService.deleteWebhook(webhookId, userId);

      logger.info('[TunnelWebhookRoutes] Webhook deleted', {
        webhookId,
        userId,
      });

      res.json({
        success: true,
        message: 'Webhook deleted successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[TunnelWebhookRoutes] Error deleting webhook', {
        webhookId: req.params.webhookId,
        userId: req.user?.sub,
        error: error.message,
      });

      if (error.message === 'Webhook not found') {
        return res.status(404).json({
          error: 'Not found',
          code: 'WEBHOOK_NOT_FOUND',
          message: 'Webhook not found',
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to delete webhook',
      });
    }
  },
);

/**
 * GET /api/tunnels/:tunnelId/webhooks/:webhookId/deliveries
 *
 * Get webhook delivery history
 *
 * Query parameters:
 * - limit: Number of results (default: 50)
 * - offset: Result offset (default: 0)
 *
 * Returns:
 * - Array of delivery records
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get(
  '/:tunnelId/webhooks/:webhookId/deliveries',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to retrieve delivery history',
        });
      }

      if (!webhookService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Webhook service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { webhookId } = req.params;
      const limit = Math.min(parseInt(req.query.limit) || 50, 1000);
      const offset = Math.max(parseInt(req.query.offset) || 0, 0);

      const deliveries = await webhookService.getDeliveryHistory(
        webhookId,
        userId,
        { limit, offset },
      );

      logger.debug('[TunnelWebhookRoutes] Delivery history retrieved', {
        webhookId,
        userId,
        count: deliveries.length,
      });

      res.json({
        success: true,
        data: deliveries,
        pagination: {
          limit,
          offset,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[TunnelWebhookRoutes] Error retrieving delivery history', {
        webhookId: req.params.webhookId,
        userId: req.user?.sub,
        error: error.message,
      });

      if (error.message === 'Webhook not found') {
        return res.status(404).json({
          error: 'Not found',
          code: 'WEBHOOK_NOT_FOUND',
          message: 'Webhook not found',
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve delivery history',
      });
    }
  },
);

/**
 * GET /api/tunnels/:tunnelId/webhooks/:webhookId/deliveries/:deliveryId
 *
 * Get delivery status
 *
 * Returns:
 * - Delivery status and details
 * - HTTP status code and error message if failed
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get(
  '/:tunnelId/webhooks/:webhookId/deliveries/:deliveryId',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to retrieve delivery status',
        });
      }

      if (!webhookService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Webhook service is not initialized',
        });
      }

      const { deliveryId } = req.params;

      const delivery = await webhookService.getDeliveryStatus(deliveryId);

      logger.debug('[TunnelWebhookRoutes] Delivery status retrieved', {
        deliveryId,
      });

      res.json({
        success: true,
        data: delivery,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[TunnelWebhookRoutes] Error retrieving delivery status', {
        deliveryId: req.params.deliveryId,
        userId: req.user?.sub,
        error: error.message,
      });

      if (error.message === 'Delivery not found') {
        return res.status(404).json({
          error: 'Not found',
          code: 'DELIVERY_NOT_FOUND',
          message: 'Delivery not found',
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve delivery status',
      });
    }
  },
);

export default router;
