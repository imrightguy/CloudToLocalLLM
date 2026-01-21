/**
 * @fileoverview Adaptive Rate Limiting Routes
 * Provides endpoints for monitoring and managing adaptive rate limiting
 */

import express from 'express';
import { TunnelLogger } from '../utils/logger.js';
import { authenticateJWT } from '../middleware/auth.js';
import { authorizeRBAC } from '../middleware/rbac.js';

const router = express.Router();
const logger = new TunnelLogger('adaptive-rate-limiting-routes');

/**
 * GET /adaptive-rate-limiting/metrics
 * Get current system load metrics and adaptive rate limiting status
 * Requires authentication
 */
router.get('/metrics', authenticateJWT, (req, res) => {
  try {
    const rateLimiter = req.adaptiveRateLimiter;

    if (!rateLimiter) {
      return res.status(503).json({
        error: 'Adaptive rate limiter not available',
      });
    }

    const metrics = rateLimiter.getSystemMetrics();

    res.json({
      success: true,
      data: {
        timestamp: new Date().toISOString(),
        metrics,
      },
    });
  } catch (error) {
    logger.error('Failed to get adaptive rate limiting metrics', {
      error: error.message,
      userId: req.userId,
      correlationId: req.correlationId,
    });

    res.status(500).json({
      error: 'Failed to get metrics',
      message: error.message,
    });
  }
});

/**
 * GET /adaptive-rate-limiting/status
 * Get detailed system status and adaptive rate limiting information
 * Requires authentication
 */
router.get('/status', authenticateJWT, (req, res) => {
  try {
    const rateLimiter = req.adaptiveRateLimiter;

    if (!rateLimiter) {
      return res.status(503).json({
        error: 'Adaptive rate limiter not available',
      });
    }

    const status = rateLimiter.getSystemStatus();

    res.json({
      success: true,
      data: {
        timestamp: new Date().toISOString(),
        status,
      },
    });
  } catch (error) {
    logger.error('Failed to get adaptive rate limiting status', {
      error: error.message,
      userId: req.userId,
      correlationId: req.correlationId,
    });

    res.status(500).json({
      error: 'Failed to get status',
      message: error.message,
    });
  }
});

/**
 * GET /adaptive-rate-limiting/user-stats
 * Get rate limiting statistics for the current user
 * Requires authentication
 */
router.get('/user-stats', authenticateJWT, (req, res) => {
  try {
    const rateLimiter = req.adaptiveRateLimiter;
    const userId = req.userId;

    if (!rateLimiter) {
      return res.status(503).json({
        error: 'Adaptive rate limiter not available',
      });
    }

    const stats = rateLimiter.getUserStats(userId);

    res.json({
      success: true,
      data: {
        timestamp: new Date().toISOString(),
        userId,
        stats,
      },
    });
  } catch (error) {
    logger.error('Failed to get user rate limiting stats', {
      error: error.message,
      userId: req.userId,
      correlationId: req.correlationId,
    });

    res.status(500).json({
      error: 'Failed to get user stats',
      message: error.message,
    });
  }
});

/**
 * GET /adaptive-rate-limiting/admin/system-status
 * Get detailed system status for administrators
 * Requires admin role
 */
router.get(
  '/admin/system-status',
  authenticateJWT,
  authorizeRBAC,
  (req, res) => {
    try {
      // Check if user has admin role
      if (!req.userRoles || !req.userRoles.includes('admin')) {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Admin role required',
        });
      }

      const rateLimiter = req.adaptiveRateLimiter;

      if (!rateLimiter) {
        return res.status(503).json({
          error: 'Adaptive rate limiter not available',
        });
      }

      const status = rateLimiter.getSystemStatus();

      res.json({
        success: true,
        data: {
          timestamp: new Date().toISOString(),
          status,
        },
      });
    } catch (error) {
      logger.error('Failed to get admin system status', {
        error: error.message,
        userId: req.userId,
        correlationId: req.correlationId,
      });

      res.status(500).json({
        error: 'Failed to get system status',
        message: error.message,
      });
    }
  },
);

/**
 * GET /adaptive-rate-limiting/admin/load-history
 * Get historical system load data for administrators
 * Requires admin role
 */
router.get(
  '/admin/load-history',
  authenticateJWT,
  authorizeRBAC,
  (req, res) => {
    try {
      // Check if user has admin role
      if (!req.userRoles || !req.userRoles.includes('admin')) {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Admin role required',
        });
      }

      const rateLimiter = req.adaptiveRateLimiter;

      if (!rateLimiter) {
        return res.status(503).json({
          error: 'Adaptive rate limiter not available',
        });
      }

      const monitor = rateLimiter.systemLoadMonitor;
      const history = monitor.metricsHistory.map((snapshot) => ({
        timestamp: snapshot.timestamp.toISOString(),
        cpuUsage: snapshot.cpuUsage.toFixed(2),
        memoryUsage: snapshot.memoryUsage.toFixed(2),
        activeRequests: snapshot.activeRequests,
        queuedRequests: snapshot.queuedRequests,
        loadPercentage: snapshot.getLoadPercentage().toFixed(2),
        loadLevel: snapshot.getLoadLevel(),
      }));

      res.json({
        success: true,
        data: {
          timestamp: new Date().toISOString(),
          historySize: history.length,
          history,
        },
      });
    } catch (error) {
      logger.error('Failed to get load history', {
        error: error.message,
        userId: req.userId,
        correlationId: req.correlationId,
      });

      res.status(500).json({
        error: 'Failed to get load history',
        message: error.message,
      });
    }
  },
);

/**
 * GET /adaptive-rate-limiting/admin/adaptive-limits
 * Get current adaptive rate limit multipliers for administrators
 * Requires admin role
 */
router.get(
  '/admin/adaptive-limits',
  authenticateJWT,
  authorizeRBAC,
  (req, res) => {
    try {
      // Check if user has admin role
      if (!req.userRoles || !req.userRoles.includes('admin')) {
        return res.status(403).json({
          error: 'Forbidden',
          message: 'Admin role required',
        });
      }

      const rateLimiter = req.adaptiveRateLimiter;

      if (!rateLimiter) {
        return res.status(503).json({
          error: 'Adaptive rate limiter not available',
        });
      }

      const adaptiveLimits = rateLimiter.getAdaptiveLimits();
      const metrics = rateLimiter.getSystemMetrics();

      res.json({
        success: true,
        data: {
          timestamp: new Date().toISOString(),
          adaptiveLimits: {
            baseMaxRequests: rateLimiter.config.baseMaxRequests,
            adaptiveMaxRequests: adaptiveLimits.maxRequests,
            baseBurstRequests: rateLimiter.config.baseBurstRequests,
            adaptiveBurstRequests: adaptiveLimits.burstRequests,
            multiplier: adaptiveLimits.multiplier.toFixed(2),
          },
          systemMetrics: metrics,
        },
      });
    } catch (error) {
      logger.error('Failed to get adaptive limits', {
        error: error.message,
        userId: req.userId,
        correlationId: req.correlationId,
      });

      res.status(500).json({
        error: 'Failed to get adaptive limits',
        message: error.message,
      });
    }
  },
);

export default router;
