/**
 * @fileoverview Rate limit metrics routes
 * Provides endpoints for rate limit metrics and dashboards
 */

import express from 'express';
import { register } from 'prom-client';
import { TunnelLogger } from '../utils/logger.js';
import { rateLimitMetricsService } from '../services/rate-limit-metrics-service.js';
import { authenticateJWT } from '../middleware/auth.js';
import { requireAdmin } from '../middleware/rbac.js';

const router = express.Router();
const logger = new TunnelLogger('rate-limit-metrics-routes');

/**
 * @swagger
 * /metrics:
 *   get:
 *     summary: Prometheus metrics endpoint
 *     description: |
 *       Public endpoint for Prometheus scraping. Returns metrics in Prometheus text format.
 *
 *       **Rate Limit:** Exempt (health check endpoint)
 *
 *       **Metrics Exposed:**
 *       - `rate_limit_violations_total` - Total rate limit violations
 *       - `rate_limit_requests_allowed_total` - Requests allowed by rate limiter
 *       - `rate_limit_requests_blocked_total` - Requests blocked by rate limiter
 *       - `rate_limited_users_active` - Currently rate limited users
 *       - `rate_limit_window_usage_percent` - Rate limit window usage
 *       - `rate_limit_burst_usage_percent` - Burst limit usage
 *       - `rate_limit_concurrent_requests` - Concurrent requests per user
 *     tags:
 *       - Monitoring
 *       - Rate Limiting
 *     produces:
 *       - text/plain
 *     responses:
 *       200:
 *         description: Prometheus metrics in text format
 *         content:
 *           text/plain:
 *             schema:
 *               type: string
 *               example: |
 *                 # HELP rate_limit_violations_total Total number of rate limit violations
 *                 # TYPE rate_limit_violations_total counter
 *                 rate_limit_violations_total{violation_type="per_user",user_tier="free"} 42
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    logger.error('Failed to generate metrics', {
      error: error.message,
    });
    res.status(500).json({
      error: 'Failed to generate metrics',
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /rate-limit-metrics/summary:
 *   get:
 *     summary: Get rate limit metrics summary
 *     description: |
 *       Returns a summary of rate limit metrics for the authenticated user.
 *
 *       **Rate Limit:** 100 requests/minute (free), 500 requests/minute (premium)
 *
 *       **Includes:**
 *       - Top violators (users hitting rate limits)
 *       - Top violating IPs
 *       - Total count of violators
 *       - Timestamp of metrics
 *     tags:
 *       - Rate Limiting
 *       - Metrics
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Rate limit metrics summary
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     timestamp:
 *                       type: string
 *                       format: date-time
 *                     topViolators:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           userId:
 *                             type: string
 *                           violationCount:
 *                             type: integer
 *                     topViolatingIps:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           ipAddress:
 *                             type: string
 *                           violationCount:
 *                             type: integer
 *                     totalViolators:
 *                       type: integer
 *                     totalViolatingIps:
 *                       type: integer
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get('/rate-limit-metrics/summary', authenticateJWT, async (req, res) => {
  try {
    const summary = rateLimitMetricsService.getMetricsSummary();

    res.json({
      success: true,
      data: summary,
    });
  } catch (error) {
    logger.error('Failed to get metrics summary', {
      error: error.message,
      userId: req.userId,
    });
    res.status(500).json({
      error: 'Failed to get metrics summary',
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /rate-limit-metrics/top-violators:
 *   get:
 *     summary: Get top rate limit violators
 *     description: |
 *       Returns the top users who have violated rate limits.
 *
 *       **Admin Only:** Requires admin role
 *
 *       **Rate Limit:** Exempt (admin endpoint)
 *
 *       **Query Parameters:**
 *       - `limit` (optional): Number of top violators to return (default: 10, max: 100)
 *     tags:
 *       - Rate Limiting
 *       - Admin
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: limit
 *         in: query
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 10
 *         description: Number of top violators to return
 *     responses:
 *       200:
 *         description: Top rate limit violators
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     timestamp:
 *                       type: string
 *                       format: date-time
 *                     limit:
 *                       type: integer
 *                     count:
 *                       type: integer
 *                     topViolators:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           userId:
 *                             type: string
 *                             format: uuid
 *                           violationCount:
 *                             type: integer
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         $ref: '#/components/responses/ForbiddenError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get(
  '/rate-limit-metrics/top-violators',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const limit = Math.min(parseInt(req.query.limit) || 10, 100);
      const topViolators = rateLimitMetricsService.getTopViolators(limit);

      res.json({
        success: true,
        data: {
          timestamp: new Date().toISOString(),
          limit,
          count: topViolators.length,
          topViolators,
        },
      });
    } catch (error) {
      logger.error('Failed to get top violators', {
        error: error.message,
        userId: req.userId,
      });
      res.status(500).json({
        error: 'Failed to get top violators',
        message: error.message,
      });
    }
  },
);

/**
 * @swagger
 * /rate-limit-metrics/top-ips:
 *   get:
 *     summary: Get top violating IP addresses
 *     description: |
 *       Returns the top IP addresses that have violated rate limits.
 *
 *       **Admin Only:** Requires admin role
 *
 *       **Rate Limit:** Exempt (admin endpoint)
 *
 *       **Use Cases:**
 *       - Identify DDoS attacks
 *       - Monitor suspicious traffic patterns
 *       - Configure IP-based blocking
 *
 *       **Query Parameters:**
 *       - `limit` (optional): Number of top IPs to return (default: 10, max: 100)
 *     tags:
 *       - Rate Limiting
 *       - Admin
 *       - Security
 *     security:
 *       - bearerAuth: []
 *     parameters:
 *       - name: limit
 *         in: query
 *         schema:
 *           type: integer
 *           minimum: 1
 *           maximum: 100
 *           default: 10
 *         description: Number of top IPs to return
 *     responses:
 *       200:
 *         description: Top violating IP addresses
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     timestamp:
 *                       type: string
 *                       format: date-time
 *                     limit:
 *                       type: integer
 *                     count:
 *                       type: integer
 *                     topIps:
 *                       type: array
 *                       items:
 *                         type: object
 *                         properties:
 *                           ipAddress:
 *                             type: string
 *                           violationCount:
 *                             type: integer
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         $ref: '#/components/responses/ForbiddenError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get(
  '/rate-limit-metrics/top-ips',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const limit = Math.min(parseInt(req.query.limit) || 10, 100);
      const topIps = rateLimitMetricsService.getTopViolatingIps(limit);

      res.json({
        success: true,
        data: {
          timestamp: new Date().toISOString(),
          limit,
          count: topIps.length,
          topIps,
        },
      });
    } catch (error) {
      logger.error('Failed to get top violating IPs', {
        error: error.message,
        userId: req.userId,
      });
      res.status(500).json({
        error: 'Failed to get top violating IPs',
        message: error.message,
      });
    }
  },
);

/**
 * @swagger
 * /rate-limit-metrics/dashboard-data:
 *   get:
 *     summary: Get comprehensive rate limit dashboard data
 *     description: |
 *       Returns comprehensive rate limit metrics for admin dashboards.
 *
 *       **Admin Only:** Requires admin role
 *
 *       **Rate Limit:** Exempt (admin endpoint)
 *
 *       **Includes:**
 *       - Summary statistics (total violators, total violating IPs)
 *       - Top 10 violating users
 *       - Top 10 violating IP addresses
 *       - Timestamp of data collection
 *
 *       **Use Cases:**
 *       - Admin dashboard display
 *       - Rate limit monitoring
 *       - Security analysis
 *     tags:
 *       - Rate Limiting
 *       - Admin
 *       - Monitoring
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Comprehensive rate limit dashboard data
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 data:
 *                   type: object
 *                   properties:
 *                     timestamp:
 *                       type: string
 *                       format: date-time
 *                     summary:
 *                       type: object
 *                       properties:
 *                         totalViolators:
 *                           type: integer
 *                           description: Total number of users who have violated rate limits
 *                         totalViolatingIps:
 *                           type: integer
 *                           description: Total number of IPs that have violated rate limits
 *                     topViolators:
 *                       type: array
 *                       maxItems: 10
 *                       items:
 *                         type: object
 *                         properties:
 *                           userId:
 *                             type: string
 *                             format: uuid
 *                           violationCount:
 *                             type: integer
 *                     topIps:
 *                       type: array
 *                       maxItems: 10
 *                       items:
 *                         type: object
 *                         properties:
 *                           ipAddress:
 *                             type: string
 *                           violationCount:
 *                             type: integer
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         $ref: '#/components/responses/ForbiddenError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get(
  '/rate-limit-metrics/dashboard-data',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const summary = rateLimitMetricsService.getMetricsSummary();
      const topViolators = rateLimitMetricsService.getTopViolators(10);
      const topIps = rateLimitMetricsService.getTopViolatingIps(10);

      res.json({
        success: true,
        data: {
          timestamp: new Date().toISOString(),
          summary: {
            totalViolators: summary.totalViolators,
            totalViolatingIps: summary.totalViolatingIps,
          },
          topViolators,
          topIps,
        },
      });
    } catch (error) {
      logger.error('Failed to get dashboard data', {
        error: error.message,
        userId: req.userId,
      });
      res.status(500).json({
        error: 'Failed to get dashboard data',
        message: error.message,
      });
    }
  },
);

export default router;
