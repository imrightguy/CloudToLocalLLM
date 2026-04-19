/**
 * Quota Management Routes
 *
 * Endpoints for quota management and reporting:
 * - GET /quotas - Get all quotas for current user
 * - GET /quotas/:resourceType - Get quota for specific resource
 * - GET /quotas/events - Get quota events for current user
 * - POST /quotas/:resourceType/reset - Reset quota (admin only)
 * - GET /quotas/summary - Get quota summary
 *
 * Validates: Requirements 6.6
 * - Implements quota management for resource usage
 * - Tracks quota usage per user
 * - Enforces quota limits
 * - Provides quota reporting
 *
 * @fileoverview Quota management routes
 * @version 1.0.0
 */

import express from 'express';
import { z } from 'zod';
import logger from '../logger.js';
import { authenticateJWT } from '../middleware/auth.js';
import { authorizeRBAC, requireAdmin } from '../middleware/rbac.js';
import { validateSchema } from '../middleware/schema-validation.js';

const router = express.Router();
let quotaService;

const resourceTypeSchema = {
  params: z.object({
    resourceType: z.string().min(1).max(100),
  }),
};

const quotaEventsSchema = {
  query: z.object({
    resourceType: z.string().optional(),
    eventType: z.string().optional(),
    limit: z.coerce.number().int().min(1).max(1000).default(100),
    offset: z.coerce.number().int().min(0).default(0),
  }),
};

const resetQuotaSchema = {
  params: z.object({
    resourceType: z.string().min(1).max(100),
  }),
  body: z.object({
    userId: z.string().uuid(),
  }),
};

/**
 * Initialize the quota routes with service
 */
export function initializeQuotaRoutes(service) {
  quotaService = service;
}

/**
 * GET /quotas
 * Get all quotas for current user
 *
 * Response: 200 OK with all quotas
 * Error: 401 Unauthorized, 500 Internal Server Error
 */
router.get('/quotas', authenticateJWT, async function (req, res) {
  try {
    const userId = req.user.sub;

    logger.info('[QuotaRoutes] Getting all quotas', {
      userId,
    });

    const quotas = await quotaService.getUserAllQuotas(userId);

    res.json({
      success: true,
      data: quotas,
    });
  } catch (error) {
    logger.error('[QuotaRoutes] Failed to get all quotas', {
      userId: req.user.sub,
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to get quotas',
      },
    });
  }
});

/**
 * GET /quotas/:resourceType
 * Get quota for specific resource type
 *
 * Path parameters:
 * - resourceType: Resource type (api_requests, data_transfer, etc.)
 *
 * Response: 200 OK with quota
 * Error: 400 Bad Request, 401 Unauthorized, 404 Not Found, 500 Internal Server Error
 */
router.get('/quotas/:resourceType', authenticateJWT, validateSchema(resourceTypeSchema), async function (req, res) {
  try {
    const { resourceType } = req.params;
    const userId = req.user.sub;

    logger.info('[QuotaRoutes] Getting quota for resource', {
      userId,
      resourceType,
    });

    const quota = await quotaService.getUserQuotaUsage(userId, resourceType);

    res.json({
      success: true,
      data: quota,
    });
  } catch (error) {
    logger.error('[QuotaRoutes] Failed to get quota', {
      userId: req.user.sub,
      resourceType: req.params.resourceType,
      error: error.message,
    });

    if (error.message.includes('not found')) {
      return res.status(404).json({
        success: false,
        error: {
          code: 'QUOTA_NOT_FOUND',
          message: 'Quota not found',
        },
      });
    }

    if (error.message.includes('Invalid')) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_INPUT',
          message: error.message,
        },
      });
    }

    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to get quota',
      },
    });
  }
});

/**
 * GET /quotas/events
 * Get quota events for current user
 *
 * Query parameters:
 * - resourceType: Filter by resource type (optional)
 * - eventType: Filter by event type (optional)
 * - limit: Limit results (default: 100)
 * - offset: Offset results (default: 0)
 *
 * Response: 200 OK with quota events
 * Error: 401 Unauthorized, 500 Internal Server Error
 */
router.get('/quotas/events', authenticateJWT, validateSchema(quotaEventsSchema), async function (req, res) {
  try {
    const userId = req.user.sub;
    const { resourceType, eventType, limit = 100, offset = 0 } = req.query;

    logger.info('[QuotaRoutes] Getting quota events', {
      userId,
      resourceType,
      eventType,
      limit,
      offset,
    });

    const events = await quotaService.getQuotaEvents(userId, {
      resourceType,
      eventType,
      limit: parseInt(limit, 10),
      offset: parseInt(offset, 10),
    });

    res.json({
      success: true,
      data: events,
    });
  } catch (error) {
    logger.error('[QuotaRoutes] Failed to get quota events', {
      userId: req.user.sub,
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to get quota events',
      },
    });
  }
});

/**
 * GET /quotas/summary
 * Get quota summary for current user
 *
 * Response: 200 OK with quota summary
 * Error: 401 Unauthorized, 500 Internal Server Error
 */
router.get('/quotas/summary', authenticateJWT, async function (req, res) {
  try {
    const userId = req.user.sub;

    logger.info('[QuotaRoutes] Getting quota summary', {
      userId,
    });

    const summary = await quotaService.getQuotaSummary(userId);

    res.json({
      success: true,
      data: summary,
    });
  } catch (error) {
    logger.error('[QuotaRoutes] Failed to get quota summary', {
      userId: req.user.sub,
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: {
        code: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to get quota summary',
      },
    });
  }
});

/**
 * POST /quotas/:resourceType/reset
 * Reset quota for a resource type (admin only)
 *
 * Path parameters:
 * - resourceType: Resource type to reset
 *
 * Response: 200 OK with reset quota
 * Error: 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 500 Internal Server Error
 */
router.post(
  '/quotas/:resourceType/reset',
  authenticateJWT,
  authorizeRBAC,
  requireAdmin(),
  validateSchema(resetQuotaSchema),
  async function (req, res) {
    try {
      const { resourceType } = req.params;
      const { userId } = req.body;

      logger.info('[QuotaRoutes] Resetting quota', {
        adminId: req.user.sub,
        userId,
        resourceType,
      });

      const quota = await quotaService.resetQuota(userId, resourceType);

      res.json({
        success: true,
        data: quota,
      });
    } catch (error) {
      logger.error('[QuotaRoutes] Failed to reset quota', {
        adminId: req.user.sub,
        userId: req.body.userId,
        resourceType: req.params.resourceType,
        error: error.message,
      });

      if (error.message.includes('not found')) {
        return res.status(404).json({
          success: false,
          error: {
            code: 'QUOTA_NOT_FOUND',
            message: 'Quota not found',
          },
        });
      }

      if (error.message.includes('Invalid')) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_INPUT',
            message: error.message,
          },
        });
      }

      res.status(500).json({
        success: false,
        error: {
          code: 'INTERNAL_SERVER_ERROR',
          message: 'Failed to reset quota',
        },
      });
    }
  },
);

export default router;
