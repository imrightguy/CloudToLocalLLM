/**
 * @fileoverview Prometheus metrics endpoint routes
 * Provides /metrics endpoint for Prometheus scraping
 */

import express from 'express';
import { metricsService } from '../services/metrics-service.js';
import { TunnelLogger } from '../utils/logger.js';

const router = express.Router();
const logger = new TunnelLogger('prometheus-metrics-routes');

/**
 * @swagger
 * /metrics:
 *   get:
 *     summary: Prometheus metrics endpoint
 *     description: |
 *       Exposes application metrics in Prometheus text format.
 *       Includes request latency, throughput, error rates, and custom metrics.
 *
 *       **Feature: api-backend-enhancement, Property 11: Metrics consistency**
 *       **Validates: Requirements 8.1, 8.2**
 *       - Exposes Prometheus metrics endpoint at `/metrics`
 *       - Tracks request latency, throughput, and error rates
 *     tags:
 *       - Monitoring
 *     responses:
 *       200:
 *         description: Prometheus metrics in text format
 *         content:
 *           text/plain:
 *             schema:
 *               type: string
 *               description: Prometheus format metrics
 *             example: |
 *               # HELP http_request_duration_seconds HTTP request latency
 *               # TYPE http_request_duration_seconds histogram
 *               http_request_duration_seconds_bucket{le="0.1",method="GET",route="/health"} 100
 *               http_request_duration_seconds_bucket{le="0.5",method="GET",route="/health"} 150
 *               http_request_duration_seconds_bucket{le="1",method="GET",route="/health"} 200
 *               http_request_duration_seconds_sum{method="GET",route="/health"} 50.5
 *               http_request_duration_seconds_count{method="GET",route="/health"} 200
 *       500:
 *         description: Failed to generate metrics
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/metrics', async (req, res) => {
  try {
    const metrics = await metricsService.getMetrics();
    const contentType = metricsService.getContentType();

    res.set('Content-Type', contentType);
    res.set('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.set('Pragma', 'no-cache');
    res.set('Expires', '0');

    res.send(metrics);

    logger.debug('Prometheus metrics endpoint accessed', {
      metricsSize: metrics.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Failed to generate Prometheus metrics', {
      error: error.message,
      stack: error.stack,
    });

    res.status(500).json({
      error: 'Failed to generate metrics',
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * @swagger
 * /metrics/health:
 *   get:
 *     summary: Health check for metrics collection
 *     description: |
 *       Verifies that metrics collection is working properly.
 *       Returns 200 if metrics are being collected, 503 if not.
 *     tags:
 *       - Monitoring
 *     responses:
 *       200:
 *         description: Metrics collection is healthy
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 status:
 *                   type: string
 *                   enum: [healthy]
 *                 message:
 *                   type: string
 *                 metricsSize:
 *                   type: integer
 *                 timestamp:
 *                   type: string
 *                   format: date-time
 *       503:
 *         description: Metrics collection is not working
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.get('/health/metrics', async (req, res) => {
  try {
    // Try to get metrics to verify collection is working
    const metrics = await metricsService.getMetrics();

    if (!metrics || metrics.length === 0) {
      return res.status(503).json({
        status: 'unhealthy',
        message: 'Metrics collection is not working',
        timestamp: new Date().toISOString(),
      });
    }

    res.json({
      status: 'healthy',
      message: 'Metrics collection is working',
      metricsSize: metrics.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Metrics health check failed', {
      error: error.message,
    });

    res.status(503).json({
      status: 'unhealthy',
      message: 'Metrics health check failed',
      error: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

export default router;
