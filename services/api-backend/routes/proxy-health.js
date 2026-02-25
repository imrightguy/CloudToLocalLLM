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
  defaultMeta: { service: 'proxy-health-routes' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

// Global proxy health service (will be injected)
let proxyHealthService = null;

/**
 * Initialize proxy health routes with service
 * @param {ProxyHealthService} healthService - Proxy health service instance
 * @returns {Router} Express router
 */
export function createProxyHealthRoutes(healthService) {
  proxyHealthService = healthService;
  return router;
}

/**
 * GET /proxy/health/:proxyId
 * Get health status for a specific proxy
 * Validates: Requirements 5.3
 */
router.get('/health/:proxyId', authenticateJWT, addTierInfo, (req, res) => {
  try {
    const { proxyId } = req.params;
    const userId = req.user?.sub;

    if (!proxyId) {
      return res.status(400).json({
        error: 'INVALID_REQUEST',
        message: 'proxyId is required',
        code: 'PROXY_001',
      });
    }

    if (!proxyHealthService) {
      return res.status(503).json({
        error: 'SERVICE_UNAVAILABLE',
        message: 'Proxy health service not initialized',
        code: 'PROXY_002',
      });
    }

    const healthStatus = proxyHealthService.getProxyHealthStatus(proxyId);

    logger.info('Proxy health status retrieved', {
      proxyId,
      userId,
      status: healthStatus.status,
    });

    const statusCode = healthStatus.status === 'healthy' ? 200 : 503;
    res.status(statusCode).json({
      proxyId,
      status: healthStatus.status,
      lastCheck: healthStatus.lastCheck,
      consecutiveFailures: healthStatus.consecutiveFailures,
      recoveryAttempts: healthStatus.recoveryAttempts,
      metrics: healthStatus.metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Error retrieving proxy health status', {
      error: error.message,
      proxyId: req.params.proxyId,
    });

    res.status(500).json({
      error: 'INTERNAL_SERVER_ERROR',
      message: 'Failed to retrieve proxy health status',
      code: 'PROXY_003',
    });
  }
});

/**
 * GET /proxy/health
 * Get health status for all proxies
 * Validates: Requirements 5.3
 */
router.get('/health', authenticateJWT, addTierInfo, (req, res) => {
  try {
    const userId = req.user?.sub;

    if (!proxyHealthService) {
      return res.status(503).json({
        error: 'SERVICE_UNAVAILABLE',
        message: 'Proxy health service not initialized',
        code: 'PROXY_002',
      });
    }

    const allHealthStatus = proxyHealthService.getAllProxyHealthStatus();

    logger.info('All proxy health statuses retrieved', {
      userId,
      proxyCount: allHealthStatus.length,
    });

    // Determine overall status
    let overallStatus = 'healthy';
    if (allHealthStatus.some((s) => s.status === 'unhealthy')) {
      overallStatus = 'unhealthy';
    } else if (allHealthStatus.some((s) => s.status === 'degraded')) {
      overallStatus = 'degraded';
    }

    const statusCode = overallStatus === 'healthy' ? 200 : 503;
    res.status(statusCode).json({
      overallStatus,
      proxies: allHealthStatus,
      totalProxies: allHealthStatus.length,
      healthyProxies: allHealthStatus.filter((s) => s.status === 'healthy')
        .length,
      degradedProxies: allHealthStatus.filter((s) => s.status === 'degraded')
        .length,
      unhealthyProxies: allHealthStatus.filter((s) => s.status === 'unhealthy')
        .length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('Error retrieving all proxy health statuses', {
      error: error.message,
    });

    res.status(500).json({
      error: 'INTERNAL_SERVER_ERROR',
      message: 'Failed to retrieve proxy health statuses',
      code: 'PROXY_003',
    });
  }
});

/**
 * POST /proxy/health/:proxyId/recover
 * Trigger manual recovery for a proxy
 * Validates: Requirements 5.3
 */
router.post(
  '/health/:proxyId/recover',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_001',
        });
      }

      if (!proxyHealthService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy health service not initialized',
          code: 'PROXY_002',
        });
      }

      const healthStatus = proxyHealthService.getProxyHealthStatus(proxyId);

      if (healthStatus.status === 'unknown') {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: 'Proxy not found',
          code: 'PROXY_004',
        });
      }

      // Check if recovery is possible
      const canRecover = proxyHealthService.recordRecoveryAttempt(proxyId);

      if (!canRecover) {
        return res.status(429).json({
          error: 'TOO_MANY_RECOVERY_ATTEMPTS',
          message: 'Maximum recovery attempts exceeded',
          code: 'PROXY_005',
          recoveryAttempts: healthStatus.recoveryAttempts,
        });
      }

      logger.info('Manual recovery triggered for proxy', {
        proxyId,
        userId,
        recoveryAttempts: healthStatus.recoveryAttempts,
      });

      res.json({
        proxyId,
        message: 'Recovery initiated',
        recoveryAttempts: healthStatus.recoveryAttempts,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error triggering proxy recovery', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to trigger proxy recovery',
        code: 'PROXY_003',
      });
    }
  },
);

/**
 * GET /proxy/health/:proxyId/metrics
 * Get detailed metrics for a proxy
 * Validates: Requirements 5.3
 */
router.get(
  '/health/:proxyId/metrics',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_001',
        });
      }

      if (!proxyHealthService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy health service not initialized',
          code: 'PROXY_002',
        });
      }

      const metrics = proxyHealthService.getProxyMetrics(proxyId);

      if (!metrics) {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: 'Proxy metrics not found',
          code: 'PROXY_004',
        });
      }

      logger.info('Proxy metrics retrieved', {
        proxyId,
        userId,
      });

      res.json({
        proxyId,
        metrics: {
          requestCount: metrics.requestCount,
          successCount: metrics.successCount,
          errorCount: metrics.errorCount,
          successRate:
            metrics.requestCount > 0
              ? (metrics.successCount / metrics.requestCount) * 100
              : 0,
          errorRate:
            metrics.requestCount > 0
              ? (metrics.errorCount / metrics.requestCount) * 100
              : 0,
          averageLatency: metrics.averageLatency,
          lastUpdated: metrics.lastUpdated,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving proxy metrics', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve proxy metrics',
        code: 'PROXY_003',
      });
    }
  },
);

/**
 * POST /proxy/health/:proxyId/reset
 * Reset health status for a proxy (admin only)
 * Validates: Requirements 5.3
 */
router.post(
  '/health/:proxyId/reset',
  authenticateJWT,
  addTierInfo,
  (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      // Check admin permission
      const userRole =
        req.user?.['https://cloudtolocalllm.online/role'] || 'user';
      if (userRole !== 'admin') {
        return res.status(403).json({
          error: 'FORBIDDEN',
          message: 'Admin access required',
          code: 'PROXY_006',
        });
      }

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_001',
        });
      }

      if (!proxyHealthService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy health service not initialized',
          code: 'PROXY_002',
        });
      }

      proxyHealthService.resetRecoveryAttempts(proxyId);

      logger.info('Proxy health status reset', {
        proxyId,
        userId,
      });

      res.json({
        proxyId,
        message: 'Health status reset successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error resetting proxy health status', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to reset proxy health status',
        code: 'PROXY_003',
      });
    }
  },
);

export default router;
