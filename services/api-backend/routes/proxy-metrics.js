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
  defaultMeta: { service: 'proxy-metrics-routes' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

// Global proxy metrics service (will be injected)
let proxyMetricsService = null;

/**
 * Initialize proxy metrics routes with service
 * @param {ProxyMetricsService} metricsService - Proxy metrics service instance
 * @returns {Router} Express router
 */
export function createProxyMetricsRoutes(metricsService) {
  proxyMetricsService = metricsService;
  return router;
}

/**
 * POST /proxy/metrics/:proxyId/record
 * Record a proxy metrics event
 * Validates: Requirements 5.6
 */
router.post(
  '/metrics/:proxyId/record',
  authenticateJWT,
  addTierInfo,
  async function (req, res) {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const { eventType, metrics } = req.body;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_METRICS_001',
        });
      }

      if (!eventType) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'eventType is required',
          code: 'PROXY_METRICS_001',
        });
      }

      if (!proxyMetricsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy metrics service not initialized',
          code: 'PROXY_METRICS_002',
        });
      }

      await proxyMetricsService.recordMetricsEvent(
        proxyId,
        userId,
        eventType,
        metrics,
      );

      logger.info('Proxy metrics event recorded', {
        proxyId,
        userId,
        eventType,
      });

      res.status(201).json({
        proxyId,
        eventType,
        message: 'Metrics event recorded successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error recording proxy metrics event', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to record proxy metrics event',
        code: 'PROXY_METRICS_003',
      });
    }
  },
);

/**
 * GET /proxy/metrics/:proxyId/daily/:date
 * Get daily metrics for a proxy
 * Validates: Requirements 5.6
 */
router.get(
  '/metrics/:proxyId/daily/:date',
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
          code: 'PROXY_METRICS_001',
        });
      }

      if (!date) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'date is required',
          code: 'PROXY_METRICS_001',
        });
      }

      if (!proxyMetricsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy metrics service not initialized',
          code: 'PROXY_METRICS_002',
        });
      }

      const metrics = await proxyMetricsService.getProxyMetricsDaily(
        proxyId,
        userId,
        date,
      );

      logger.info('Proxy daily metrics retrieved', {
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
      logger.error('Error retrieving proxy daily metrics', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy daily metrics',
        code: 'PROXY_METRICS_003',
      });
    }
  },
);

/**
 * GET /proxy/metrics/:proxyId/daily
 * Get daily metrics for a proxy over a date range
 * Query params: startDate, endDate (YYYY-MM-DD format)
 * Validates: Requirements 5.6
 */
router.get(
  '/metrics/:proxyId/daily',
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
          code: 'PROXY_METRICS_001',
        });
      }

      if (!startDate || !endDate) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'startDate and endDate query parameters are required',
          code: 'PROXY_METRICS_001',
        });
      }

      if (!proxyMetricsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy metrics service not initialized',
          code: 'PROXY_METRICS_002',
        });
      }

      const metrics = await proxyMetricsService.getProxyMetricsDailyRange(
        proxyId,
        userId,
        startDate,
        endDate,
      );

      logger.info('Proxy daily metrics range retrieved', {
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
      logger.error('Error retrieving proxy daily metrics range', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy daily metrics range',
        code: 'PROXY_METRICS_003',
      });
    }
  },
);

/**
 * GET /proxy/metrics/:proxyId/aggregation
 * Get aggregated metrics for a proxy over a period
 * Query params: periodStart, periodEnd (YYYY-MM-DD format)
 * Validates: Requirements 5.6
 */
router.get(
  '/metrics/:proxyId/aggregation',
  authenticateJWT,
  addTierInfo,
  async function (req, res) {
    try {
      const { proxyId } = req.params;
      const { periodStart, periodEnd } = req.query;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_METRICS_001',
        });
      }

      if (!periodStart || !periodEnd) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'periodStart and periodEnd query parameters are required',
          code: 'PROXY_METRICS_001',
        });
      }

      if (!proxyMetricsService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy metrics service not initialized',
          code: 'PROXY_METRICS_002',
        });
      }

      const metrics = await proxyMetricsService.getProxyMetricsAggregation(
        proxyId,
        userId,
        periodStart,
        periodEnd,
      );

      logger.info('Proxy aggregated metrics retrieved', {
        proxyId,
        userId,
        periodStart,
        periodEnd,
      });

      res.json({
        proxyId,
        periodStart,
        periodEnd,
        metrics,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy aggregated metrics', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy aggregated metrics',
        code: 'PROXY_METRICS_003',
      });
    }
  },
);

export default router;
