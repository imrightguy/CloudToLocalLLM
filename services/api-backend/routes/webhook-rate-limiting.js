/**
 * Webhook Rate Limiting Routes
 *
 * Endpoints for managing webhook rate limiting configuration
 * - GET /api/webhooks/:webhookId/rate-limit - Get rate limit config
 * - PUT /api/webhooks/:webhookId/rate-limit - Update rate limit config
 * - GET /api/webhooks/:webhookId/rate-limit/stats - Get rate limit stats
 *
 * @fileoverview Webhook rate limiting routes
 * @version 1.0.0
 */

import express from 'express';
import logger from '../logger.js';
import { webhookRateLimiterService } from '../services/webhook-rate-limiter.js';
import { authenticateJWT } from '../middleware/auth.js';
import { webhookRateLimitConfigMiddleware } from '../middleware/webhook-rate-limiter.js';

const router = express.Router();

/**
 * GET /api/webhooks/:webhookId/rate-limit
 * Get rate limit configuration for a webhook
 */
router.get(
  '/:webhookId/rate-limit',
  authenticateJWT,
  async function (req, res) {
    try {
      const { webhookId } = req.params;
      const userId = req.user.id;

      logger.info('[WebhookRateLimiting] Getting rate limit config', {
        webhookId,
        userId,
      });

      const config = await webhookRateLimiterService.getWebhookRateLimitConfig(
        webhookId,
        userId,
      );

      res.json({
        webhook_id: webhookId,
        user_id: userId,
        rate_limit_config: config,
      });
    } catch (error) {
      logger.error('[WebhookRateLimiting] Failed to get rate limit config', {
        error: error.message,
      });

      res.status(500).json({
        error: {
          code: 'RATE_LIMIT_CONFIG_ERROR',
          message: 'Failed to get rate limit configuration',
        },
      });
    }
  },
);

/**
 * PUT /api/webhooks/:webhookId/rate-limit
 * Update rate limit configuration for a webhook
 */
router.put(
  '/:webhookId/rate-limit',
  authenticateJWT,
  webhookRateLimitConfigMiddleware,
  async function (req, res) {
    try {
      const { webhookId } = req.params;
      const userId = req.user.id;
      const config = req.validatedRateLimitConfig;

      if (!config) {
        return res.status(400).json({
          error: {
            code: 'MISSING_CONFIG',
            message: 'Rate limit configuration is required',
          },
        });
      }

      logger.info('[WebhookRateLimiting] Updating rate limit config', {
        webhookId,
        userId,
        config,
      });

      const updatedConfig =
        await webhookRateLimiterService.setWebhookRateLimitConfig(
          webhookId,
          userId,
          config,
        );

      res.json({
        webhook_id: webhookId,
        user_id: userId,
        rate_limit_config: updatedConfig,
        message: 'Rate limit configuration updated successfully',
      });
    } catch (error) {
      logger.error('[WebhookRateLimiting] Failed to update rate limit config', {
        error: error.message,
      });

      res.status(500).json({
        error: {
          code: 'RATE_LIMIT_CONFIG_ERROR',
          message: 'Failed to update rate limit configuration',
        },
      });
    }
  },
);

/**
 * GET /api/webhooks/:webhookId/rate-limit/stats
 * Get rate limit statistics for a webhook
 */
router.get(
  '/:webhookId/rate-limit/stats',
  authenticateJWT,
  async function (req, res) {
    try {
      const { webhookId } = req.params;
      const userId = req.user.id;

      logger.info('[WebhookRateLimiting] Getting rate limit stats', {
        webhookId,
        userId,
      });

      const stats = await webhookRateLimiterService.getRateLimitStats(
        webhookId,
        userId,
      );

      const config = await webhookRateLimiterService.getWebhookRateLimitConfig(
        webhookId,
        userId,
      );

      res.json({
        webhook_id: webhookId,
        user_id: userId,
        rate_limit_config: config,
        statistics: {
          total_deliveries: stats.total_deliveries,
          successful_deliveries: stats.successful_deliveries,
          failed_deliveries: stats.failed_deliveries,
          current_minute_usage: stats.minute_count,
          current_hour_usage: stats.hour_count,
          current_day_usage: stats.day_count,
          minute_remaining: Math.max(
            0,
            config.rate_limit_per_minute - stats.minute_count,
          ),
          hour_remaining: Math.max(
            0,
            config.rate_limit_per_hour - stats.hour_count,
          ),
          day_remaining: Math.max(
            0,
            config.rate_limit_per_day - stats.day_count,
          ),
        },
      });
    } catch (error) {
      logger.error('[WebhookRateLimiting] Failed to get rate limit stats', {
        error: error.message,
      });

      res.status(500).json({
        error: {
          code: 'RATE_LIMIT_STATS_ERROR',
          message: 'Failed to get rate limit statistics',
        },
      });
    }
  },
);

export default router;
