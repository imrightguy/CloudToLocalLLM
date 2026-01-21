/**
 * Tunnel Usage Routes
 *
 * Endpoints for tunnel usage tracking and billing:
 * - GET /tunnels/:tunnelId/usage/:date - Get usage metrics for a specific date
 * - GET /tunnels/:tunnelId/usage - Get usage metrics for a date range
 * - GET /users/usage/report - Get usage report for current user
 * - GET /users/usage/billing - Get billing summary for current user
 * - POST /tunnels/:tunnelId/usage/events - Record usage event
 *
 * Validates: Requirements 4.9
 * - Tracks tunnel usage metrics (connections, data transferred)
 * - Implements usage aggregation per user/tier
 * - Creates usage reporting endpoints
 *
 * @fileoverview Tunnel usage tracking routes
 * @version 1.0.0
 */

import express from 'express';
import logger from '../logger.js';

import { authenticateJWT } from '../middleware/auth.js';
import { validateInput } from '../utils/input-validation.js';

const router = express.Router();
let usageService;

/**
 * Initialize the tunnel usage routes with service
 */
export function initializeTunnelUsageRoutes(service) {
  usageService = service;
}

/**
 * GET /tunnels/:tunnelId/usage/:date
 * Get tunnel usage metrics for a specific date
 *
 * Query parameters:
 * - date: Date in YYYY-MM-DD format
 *
 * Response: 200 OK with usage metrics
 * Error: 400 Bad Request, 401 Unauthorized, 404 Not Found, 500 Internal Server Error
 */
router.get(
  '/tunnels/:tunnelId/usage/:date',
  authenticateJWT,
  async function (req, res) {
    try {
      const { tunnelId, date } = req.params;
      const userId = req.user.sub;

      // Validate inputs
      validateInput(tunnelId, 'tunnelId', 'uuid');
      validateInput(date, 'date', 'date');

      logger.info('[TunnelUsageRoutes] Getting tunnel usage metrics', {
        tunnelId,
        date,
        userId,
      });

      const metrics = await usageService.getTunnelUsageMetrics(
        tunnelId,
        userId,
        date,
      );

      res.json({
        success: true,
        data: metrics,
      });
    } catch (error) {
      logger.error('[TunnelUsageRoutes] Failed to get tunnel usage metrics', {
        tunnelId: req.params.tunnelId,
        date: req.params.date,
        error: error.message,
      });

      if (error.message === 'Tunnel not found') {
        return res.status(404).json({
          success: false,
          error: {
            code: 'TUNNEL_NOT_FOUND',
            message: 'Tunnel not found',
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
          message: 'Failed to get tunnel usage metrics',
        },
      });
    }
  },
);

/**
 * GET /tunnels/:tunnelId/usage
 * Get tunnel usage metrics for a date range
 *
 * Query parameters:
 * - startDate: Start date in YYYY-MM-DD format (required)
 * - endDate: End date in YYYY-MM-DD format (required)
 *
 * Response: 200 OK with usage metrics array
 * Error: 400 Bad Request, 401 Unauthorized, 404 Not Found, 500 Internal Server Error
 */
router.get(
  '/tunnels/:tunnelId/usage',
  authenticateJWT,
  async function (req, res) {
    try {
      const { tunnelId } = req.params;
      const { startDate, endDate } = req.query;
      const userId = req.user.sub;

      // Validate inputs
      validateInput(tunnelId, 'tunnelId', 'uuid');
      validateInput(startDate, 'startDate', 'date');
      validateInput(endDate, 'endDate', 'date');

      if (new Date(startDate) > new Date(endDate)) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_DATE_RANGE',
            message: 'startDate must be before or equal to endDate',
          },
        });
      }

      logger.info('[TunnelUsageRoutes] Getting tunnel usage metrics range', {
        tunnelId,
        startDate,
        endDate,
        userId,
      });

      const metrics = await usageService.getTunnelUsageMetricsRange(
        tunnelId,
        userId,
        startDate,
        endDate,
      );

      res.json({
        success: true,
        data: metrics,
      });
    } catch (error) {
      logger.error(
        '[TunnelUsageRoutes] Failed to get tunnel usage metrics range',
        {
          tunnelId: req.params.tunnelId,
          startDate: req.query.startDate,
          endDate: req.query.endDate,
          error: error.message,
        },
      );

      if (error.message === 'Tunnel not found') {
        return res.status(404).json({
          success: false,
          error: {
            code: 'TUNNEL_NOT_FOUND',
            message: 'Tunnel not found',
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
          message: 'Failed to get tunnel usage metrics range',
        },
      });
    }
  },
);

/**
 * GET /users/usage/report
 * Get usage report for current user
 *
 * Query parameters:
 * - startDate: Start date in YYYY-MM-DD format (required)
 * - endDate: End date in YYYY-MM-DD format (required)
 * - groupBy: Group by 'day' or 'tunnel' (default: 'day')
 *
 * Response: 200 OK with usage report
 * Error: 400 Bad Request, 401 Unauthorized, 500 Internal Server Error
 */
router.get('/users/usage/report', authenticateJWT, async function (req, res) {
  try {
    const userId = req.user.sub;
    const { startDate, endDate, groupBy = 'day' } = req.query;

    // Validate inputs
    validateInput(startDate, 'startDate', 'date');
    validateInput(endDate, 'endDate', 'date');

    if (!['day', 'tunnel'].includes(groupBy)) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_GROUP_BY',
          message: 'groupBy must be either "day" or "tunnel"',
        },
      });
    }

    if (new Date(startDate) > new Date(endDate)) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_DATE_RANGE',
          message: 'startDate must be before or equal to endDate',
        },
      });
    }

    logger.info('[TunnelUsageRoutes] Getting user usage report', {
      userId,
      startDate,
      endDate,
      groupBy,
    });

    const report = await usageService.getUserUsageReport(userId, {
      startDate,
      endDate,
      groupBy,
    });

    res.json({
      success: true,
      data: report,
    });
  } catch (error) {
    logger.error('[TunnelUsageRoutes] Failed to get user usage report', {
      userId: req.user.sub,
      startDate: req.query.startDate,
      endDate: req.query.endDate,
      error: error.message,
    });

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
        message: 'Failed to get user usage report',
      },
    });
  }
});

/**
 * GET /users/usage/billing
 * Get billing summary for current user
 *
 * Query parameters:
 * - periodStart: Period start date in YYYY-MM-DD format (required)
 * - periodEnd: Period end date in YYYY-MM-DD format (required)
 *
 * Response: 200 OK with billing summary
 * Error: 400 Bad Request, 401 Unauthorized, 500 Internal Server Error
 */
router.get('/users/usage/billing', authenticateJWT, async function (req, res) {
  try {
    const userId = req.user.sub;
    const { periodStart, periodEnd } = req.query;
    const userTier = req.user.tier || 'free';

    // Validate inputs
    validateInput(periodStart, 'periodStart', 'date');
    validateInput(periodEnd, 'periodEnd', 'date');

    if (new Date(periodStart) > new Date(periodEnd)) {
      return res.status(400).json({
        success: false,
        error: {
          code: 'INVALID_DATE_RANGE',
          message: 'periodStart must be before or equal to periodEnd',
        },
      });
    }

    logger.info('[TunnelUsageRoutes] Getting billing summary', {
      userId,
      userTier,
      periodStart,
      periodEnd,
    });

    const billing = await usageService.getBillingSummary(
      userId,
      userTier,
      periodStart,
      periodEnd,
    );

    res.json({
      success: true,
      data: billing,
    });
  } catch (error) {
    logger.error('[TunnelUsageRoutes] Failed to get billing summary', {
      userId: req.user.sub,
      periodStart: req.query.periodStart,
      periodEnd: req.query.periodEnd,
      error: error.message,
    });

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
        message: 'Failed to get billing summary',
      },
    });
  }
});

/**
 * POST /tunnels/:tunnelId/usage/events
 * Record a tunnel usage event
 *
 * Request body:
 * {
 *   "eventType": "connection_start|connection_end|data_transfer|error",
 *   "connectionId": "string",
 *   "dataBytes": number,
 *   "durationSeconds": number,
 *   "errorMessage": "string",
 *   "ipAddress": "string"
 * }
 *
 * Response: 201 Created with event data
 * Error: 400 Bad Request, 401 Unauthorized, 404 Not Found, 500 Internal Server Error
 */
router.post(
  '/tunnels/:tunnelId/usage/events',
  authenticateJWT,
  async function (req, res) {
    try {
      const { tunnelId } = req.params;
      const userId = req.user.sub;
      const {
        eventType,
        connectionId,
        dataBytes,
        durationSeconds,
        errorMessage,
        ipAddress,
      } = req.body;

      // Validate inputs
      validateInput(tunnelId, 'tunnelId', 'uuid');
      validateInput(eventType, 'eventType', 'string');

      if (
        ![
          'connection_start',
          'connection_end',
          'data_transfer',
          'error',
        ].includes(eventType)
      ) {
        return res.status(400).json({
          success: false,
          error: {
            code: 'INVALID_EVENT_TYPE',
            message:
              'eventType must be one of: connection_start, connection_end, data_transfer, error',
          },
        });
      }

      logger.info('[TunnelUsageRoutes] Recording usage event', {
        tunnelId,
        userId,
        eventType,
      });

      const event = await usageService.recordUsageEvent(
        tunnelId,
        userId,
        eventType,
        {
          connectionId,
          dataBytes: dataBytes || 0,
          durationSeconds,
          errorMessage,
          ipAddress,
        },
      );

      res.status(201).json({
        success: true,
        data: event,
      });
    } catch (error) {
      logger.error('[TunnelUsageRoutes] Failed to record usage event', {
        tunnelId: req.params.tunnelId,
        eventType: req.body.eventType,
        error: error.message,
      });

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
          message: 'Failed to record usage event',
        },
      });
    }
  },
);

export default router;
