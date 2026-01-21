import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import { addTierInfo } from '../middleware/tier-check.js';
import winston from 'winston';

const router = express.Router();

// Logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'proxy-usage-routes' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

// Global proxy usage service (will be injected)
let proxyUsageService = null;

/**
 * Initialize proxy usage routes with service
 * @param {ProxyUsageService} usageService - Proxy usage service instance
 * @returns {Router} Express router
 */
export function createProxyUsageRoutes(usageService) {
  proxyUsageService = usageService;
  return router;
}

/**
 * POST /proxy/usage/:proxyId/record
 * Record a proxy usage event
 * Validates: Requirements 5.9
 */
router.post(
  '/usage/:proxyId/record',
  authenticateJWT,
  addTierInfo,
  async function (req, res) {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const { eventType, eventData } = req.body;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!eventType) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'eventType is required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!proxyUsageService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy usage service not initialized',
          code: 'PROXY_USAGE_002',
        });
      }

      await proxyUsageService.recordUsageEvent(
        proxyId,
        userId,
        eventType,
        eventData,
      );

      logger.info('Proxy usage event recorded', {
        proxyId,
        userId,
        eventType,
      });

      res.status(201).json({
        proxyId,
        eventType,
        message: 'Usage event recorded successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error recording proxy usage event', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to record proxy usage event',
        code: 'PROXY_USAGE_003',
      });
    }
  },
);

/**
 * GET /proxy/usage/:proxyId/metrics/:date
 * Get usage metrics for a proxy on a specific date
 * Validates: Requirements 5.9
 */
router.get(
  '/usage/:proxyId/metrics/:date',
  authenticateJWT,
  addTierInfo,
  async function (req, res) {
    try {
      const { proxyId, date } = req.params;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!date) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'date is required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!proxyUsageService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy usage service not initialized',
          code: 'PROXY_USAGE_002',
        });
      }

      const metrics = await proxyUsageService.getProxyUsageMetrics(
        proxyId,
        userId,
        date,
      );

      logger.info('Proxy usage metrics retrieved', {
        proxyId,
        userId,
        date,
      });

      res.json({
        proxyId,
        date,
        metrics,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy usage metrics', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy usage metrics',
        code: 'PROXY_USAGE_003',
      });
    }
  },
);

/**
 * GET /proxy/usage/:proxyId/metrics
 * Get usage metrics for a proxy over a date range
 * Query params: startDate, endDate (YYYY-MM-DD format)
 * Validates: Requirements 5.9
 */
router.get(
  '/usage/:proxyId/metrics',
  authenticateJWT,
  addTierInfo,
  async function (req, res) {
    try {
      const { proxyId } = req.params;
      const { startDate, endDate } = req.query;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!startDate || !endDate) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'startDate and endDate query parameters are required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!proxyUsageService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy usage service not initialized',
          code: 'PROXY_USAGE_002',
        });
      }

      const metrics = await proxyUsageService.getProxyUsageMetricsRange(
        proxyId,
        userId,
        startDate,
        endDate,
      );

      logger.info('Proxy usage metrics range retrieved', {
        proxyId,
        userId,
        startDate,
        endDate,
        count: metrics.length,
      });

      res.json({
        proxyId,
        startDate,
        endDate,
        metrics,
        count: metrics.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy usage metrics range', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy usage metrics range',
        code: 'PROXY_USAGE_003',
      });
    }
  },
);

/**
 * GET /proxy/usage/report
 * Get usage report for the authenticated user
 * Query params: startDate, endDate, groupBy (day|proxy)
 * Validates: Requirements 5.9
 */
router.get(
  '/usage/report',
  authenticateJWT,
  addTierInfo,
  async function (req, res) {
    try {
      const userId = req.user?.sub;
      const { startDate, endDate, groupBy = 'day' } = req.query;

      if (!startDate || !endDate) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'startDate and endDate query parameters are required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!proxyUsageService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy usage service not initialized',
          code: 'PROXY_USAGE_002',
        });
      }

      const report = await proxyUsageService.getUserUsageReport(userId, {
        startDate,
        endDate,
        groupBy,
      });

      logger.info('Proxy usage report retrieved', {
        userId,
        startDate,
        endDate,
        groupBy,
      });

      res.json({
        ...report,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy usage report', {
        error: error.message,
        userId: req.user?.sub,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy usage report',
        code: 'PROXY_USAGE_003',
      });
    }
  },
);

/**
 * GET /proxy/usage/aggregation
 * Get aggregated usage for the authenticated user
 * Query params: periodStart, periodEnd (YYYY-MM-DD format)
 * Validates: Requirements 5.9
 */
router.get(
  '/usage/aggregation',
  authenticateJWT,
  addTierInfo,
  async function (req, res) {
    try {
      const userId = req.user?.sub;
      const userTier = req.tier || 'free';
      const { periodStart, periodEnd } = req.query;

      if (!periodStart || !periodEnd) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'periodStart and periodEnd query parameters are required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!proxyUsageService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy usage service not initialized',
          code: 'PROXY_USAGE_002',
        });
      }

      const aggregation = await proxyUsageService.getUserUsageAggregation(
        userId,
        userTier,
        periodStart,
        periodEnd,
      );

      logger.info('Proxy usage aggregation retrieved', {
        userId,
        userTier,
        periodStart,
        periodEnd,
      });

      res.json({
        ...aggregation,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy usage aggregation', {
        error: error.message,
        userId: req.user?.sub,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy usage aggregation',
        code: 'PROXY_USAGE_003',
      });
    }
  },
);

/**
 * POST /proxy/usage/aggregate
 * Aggregate usage metrics for a user and period
 * Body: { periodStart, periodEnd }
 * Validates: Requirements 5.9
 */
router.post(
  '/usage/aggregate',
  authenticateJWT,
  addTierInfo,
  async function (req, res) {
    try {
      const userId = req.user?.sub;
      const userTier = req.tier || 'free';
      const { periodStart, periodEnd } = req.body;

      if (!periodStart || !periodEnd) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'periodStart and periodEnd are required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!proxyUsageService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy usage service not initialized',
          code: 'PROXY_USAGE_002',
        });
      }

      const aggregation = await proxyUsageService.aggregateUserUsage(
        userId,
        userTier,
        periodStart,
        periodEnd,
      );

      logger.info('Proxy usage aggregated', {
        userId,
        userTier,
        periodStart,
        periodEnd,
      });

      res.json({
        message: 'Usage aggregated successfully',
        aggregation,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error aggregating proxy usage', {
        error: error.message,
        userId: req.user?.sub,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to aggregate proxy usage',
        code: 'PROXY_USAGE_003',
      });
    }
  },
);

/**
 * GET /proxy/usage/billing
 * Get billing summary for the authenticated user
 * Query params: periodStart, periodEnd (YYYY-MM-DD format)
 * Validates: Requirements 5.9
 */
router.get(
  '/usage/billing',
  authenticateJWT,
  addTierInfo,
  async function (req, res) {
    try {
      const userId = req.user?.sub;
      const userTier = req.tier || 'free';
      const { periodStart, periodEnd } = req.query;

      if (!periodStart || !periodEnd) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'periodStart and periodEnd query parameters are required',
          code: 'PROXY_USAGE_001',
        });
      }

      if (!proxyUsageService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy usage service not initialized',
          code: 'PROXY_USAGE_002',
        });
      }

      const billingSummary = await proxyUsageService.getBillingSummary(
        userId,
        userTier,
        periodStart,
        periodEnd,
      );

      logger.info('Proxy billing summary retrieved', {
        userId,
        userTier,
        periodStart,
        periodEnd,
      });

      res.json({
        ...billingSummary,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy billing summary', {
        error: error.message,
        userId: req.user?.sub,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy billing summary',
        code: 'PROXY_USAGE_003',
      });
    }
  },
);

export default router;
