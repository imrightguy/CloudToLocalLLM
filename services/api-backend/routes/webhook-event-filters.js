/**
 * Webhook Event Filter API Routes
 *
 * Provides endpoints for:
 * - Creating and managing webhook event filters
 * - Validating filter configurations
 * - Testing filters against sample events
 *
 * All endpoints require authentication via JWT token.
 *
 * Validates: Requirements 10.5
 * - Implements webhook event filtering
 * - Supports filter configuration
 * - Validates filter rules
 *
 * @fileoverview Webhook event filter management endpoints
 * @version 1.0.0
 */

import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import { WebhookEventFilter } from '../services/webhook-event-filter.js';
import logger from '../logger.js';

const router = express.Router();
let filterService = null;

/**
 * Initialize the filter service
 * Called once during server startup
 */
export async function initializeWebhookEventFilterService() {
  try {
    filterService = new WebhookEventFilter();
    await filterService.initialize();
    logger.info(
      '[WebhookEventFilterRoutes] Webhook event filter service initialized',
    );
  } catch (error) {
    logger.error(
      '[WebhookEventFilterRoutes] Failed to initialize filter service',
      {
        error: error.message,
      },
    );
    throw error;
  }
}

/**
 * POST /api/tunnels/:tunnelId/webhooks/:webhookId/filters
 *
 * Create or update event filter for a webhook
 *
 * Request body:
 * {
 *   "type": "include",
 *   "eventPatterns": ["tunnel.status_changed", "tunnel.*"],
 *   "propertyFilters": {
 *     "data.status": { "operator": "in", "value": ["connected", "disconnected"] }
 *   },
 *   "rateLimit": { "maxEvents": 100, "windowSeconds": 60 }
 * }
 *
 * Returns:
 * - Filter ID
 * - Filter configuration
 * - Validation status
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post(
  '/:tunnelId/webhooks/:webhookId/filters',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to create filter',
        });
      }

      if (!filterService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Filter service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { webhookId } = req.params;
      const filterConfig = req.body;

      // Validate filter configuration
      const validation = filterService.validateFilterConfig(filterConfig);
      if (!validation.isValid) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_FILTER',
          message: 'Invalid filter configuration',
          details: validation.errors,
        });
      }

      const filter = await filterService.createFilter(
        webhookId,
        userId,
        filterConfig,
      );

      logger.info('[WebhookEventFilterRoutes] Filter created', {
        filterId: filter.id,
        webhookId,
        userId,
      });

      res.status(201).json({
        success: true,
        data: filter,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[WebhookEventFilterRoutes] Error creating filter', {
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

      if (error.message.includes('Invalid filter')) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_FILTER',
          message: error.message,
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to create filter',
      });
    }
  },
);

/**
 * GET /api/tunnels/:tunnelId/webhooks/:webhookId/filters
 *
 * Get event filter for a webhook
 *
 * Returns:
 * - Filter configuration
 * - Filter status
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get(
  '/:tunnelId/webhooks/:webhookId/filters',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to retrieve filter',
        });
      }

      if (!filterService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Filter service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { webhookId } = req.params;

      const filter = await filterService.getFilter(webhookId, userId);

      if (!filter) {
        return res.status(404).json({
          error: 'Not found',
          code: 'FILTER_NOT_FOUND',
          message: 'Filter not found',
        });
      }

      logger.debug('[WebhookEventFilterRoutes] Filter retrieved', {
        webhookId,
        userId,
      });

      res.json({
        success: true,
        data: filter,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[WebhookEventFilterRoutes] Error retrieving filter', {
        webhookId: req.params.webhookId,
        userId: req.user?.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to retrieve filter',
      });
    }
  },
);

/**
 * PUT /api/tunnels/:tunnelId/webhooks/:webhookId/filters
 *
 * Update event filter for a webhook
 *
 * Request body:
 * {
 *   "type": "include",
 *   "eventPatterns": ["tunnel.status_changed"],
 *   "propertyFilters": { ... }
 * }
 *
 * Returns:
 * - Updated filter configuration
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.put(
  '/:tunnelId/webhooks/:webhookId/filters',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to update filter',
        });
      }

      if (!filterService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Filter service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { webhookId } = req.params;
      const filterConfig = req.body;

      // Validate filter configuration
      const validation = filterService.validateFilterConfig(filterConfig);
      if (!validation.isValid) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_FILTER',
          message: 'Invalid filter configuration',
          details: validation.errors,
        });
      }

      const filter = await filterService.updateFilter(
        webhookId,
        userId,
        filterConfig,
      );

      logger.info('[WebhookEventFilterRoutes] Filter updated', {
        webhookId,
        userId,
      });

      res.json({
        success: true,
        data: filter,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[WebhookEventFilterRoutes] Error updating filter', {
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

      if (error.message.includes('Invalid filter')) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_FILTER',
          message: error.message,
        });
      }

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to update filter',
      });
    }
  },
);

/**
 * DELETE /api/tunnels/:tunnelId/webhooks/:webhookId/filters
 *
 * Delete event filter for a webhook
 *
 * Returns:
 * - Success message
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.delete(
  '/:tunnelId/webhooks/:webhookId/filters',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!req.user) {
        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to delete filter',
        });
      }

      if (!filterService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Filter service is not initialized',
        });
      }

      const userId = req.user.sub;
      const { webhookId } = req.params;

      await filterService.deleteFilter(webhookId, userId);

      logger.info('[WebhookEventFilterRoutes] Filter deleted', {
        webhookId,
        userId,
      });

      res.json({
        success: true,
        message: 'Filter deleted successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[WebhookEventFilterRoutes] Error deleting filter', {
        webhookId: req.params.webhookId,
        userId: req.user?.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to delete filter',
      });
    }
  },
);

/**
 * POST /api/tunnels/:tunnelId/webhooks/:webhookId/filters/validate
 *
 * Validate filter configuration
 *
 * Request body:
 * {
 *   "type": "include",
 *   "eventPatterns": ["tunnel.status_changed"],
 *   "propertyFilters": { ... }
 * }
 *
 * Returns:
 * - Validation result
 * - Error details if invalid
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post(
  '/:tunnelId/webhooks/:webhookId/filters/validate',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!filterService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Filter service is not initialized',
        });
      }

      const filterConfig = req.body;

      const validation = filterService.validateFilterConfig(filterConfig);

      res.json({
        success: true,
        data: {
          isValid: validation.isValid,
          errors: validation.errors,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[WebhookEventFilterRoutes] Error validating filter', {
        error: error.message,
      });

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to validate filter',
      });
    }
  },
);

/**
 * POST /api/tunnels/:tunnelId/webhooks/:webhookId/filters/test
 *
 * Test filter against sample event
 *
 * Request body:
 * {
 *   "event": { "type": "tunnel.status_changed", "data": { "status": "connected" } },
 *   "filter": { "type": "include", "eventPatterns": ["tunnel.*"] }
 * }
 *
 * Returns:
 * - Test result (matches or not)
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.post(
  '/:tunnelId/webhooks/:webhookId/filters/test',
  authenticateJWT,
  async (req, res) => {
    try {
      if (!filterService) {
        return res.status(503).json({
          error: 'Service unavailable',
          code: 'SERVICE_UNAVAILABLE',
          message: 'Filter service is not initialized',
        });
      }

      const { event, filter } = req.body;

      if (!event) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_REQUEST',
          message: 'Event is required',
        });
      }

      if (!filter) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_REQUEST',
          message: 'Filter is required',
        });
      }

      // Validate filter
      const validation = filterService.validateFilterConfig(filter);
      if (!validation.isValid) {
        return res.status(400).json({
          error: 'Bad request',
          code: 'INVALID_FILTER',
          message: 'Invalid filter configuration',
          details: validation.errors,
        });
      }

      const matches = filterService.matchesFilter(event, filter);

      logger.debug('[WebhookEventFilterRoutes] Filter test executed', {
        eventType: event.type,
        matches,
      });

      res.json({
        success: true,
        data: {
          matches,
          event,
          filter,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('[WebhookEventFilterRoutes] Error testing filter', {
        error: error.message,
      });

      res.status(500).json({
        error: 'Internal server error',
        code: 'INTERNAL_ERROR',
        message: 'Failed to test filter',
      });
    }
  },
);

export default router;
