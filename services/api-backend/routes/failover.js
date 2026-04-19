/**
 * Database Failover Routes
 *
 * Provides endpoints for:
 * - Failover status monitoring
 * - Manual failover triggering
 * - Failover metrics and history
 * - Health status reporting
 *
 * Requirements: 9.9 (Database failover and high availability)
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { getFailoverManager } from '../database/failover-manager.js';
import { validateSchema } from '../middleware/schema-validation.js';
import logger from '../logger.js';

const router = express.Router();
router.use(authenticateJWT);

const triggerFailoverBodySchema = z.object({
  standbyIndex: z.coerce.number().int().min(0),
});

/**
 * GET /failover/status
 * Get current failover status and health information
 */
router.get('/status', async (req, res) => {
  try {
    const failoverManager = getFailoverManager();
    const status = failoverManager.getFailoverStatus();

    res.json({
      success: true,
      data: status,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Failover Routes] Error getting failover status', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to get failover status',
      message: error.message,
    });
  }
});

/**
 * GET /failover/metrics
 * Get failover metrics and statistics
 */
router.get('/metrics', async (req, res) => {
  try {
    const failoverManager = getFailoverManager();
    const metrics = failoverManager.getMetrics();

    res.json({
      success: true,
      data: metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Failover Routes] Error getting failover metrics', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to get failover metrics',
      message: error.message,
    });
  }
});

/**
 * GET /failover/health
 * Get detailed health information for all database instances
 */
router.get('/health', async (req, res) => {
  try {
    const failoverManager = getFailoverManager();
    const status = failoverManager.getFailoverStatus();

    const health = {
      primary: {
        ...status.primary,
        status: status.primary.healthy ? 'healthy' : 'unhealthy',
      },
      standbys: Object.entries(status.standbys).map(([key, value]) => ({
        name: key,
        ...value,
        status: value.healthy ? 'healthy' : 'unhealthy',
      })),
      overall: status.state,
      timestamp: new Date().toISOString(),
    };

    res.json({
      success: true,
      data: health,
    });
  } catch (error) {
    logger.error('🔴 [Failover Routes] Error getting health information', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to get health information',
      message: error.message,
    });
  }
});

/**
 * POST /failover/trigger
 * Manually trigger failover to a specific standby
 * Admin only
 */
router.post('/trigger', validateSchema({ body: triggerFailoverBodySchema }), async (req, res) => {
  try {
    const { standbyIndex } = req.body;

    const failoverManager = getFailoverManager();
    const status = failoverManager.getFailoverStatus();

    if (standbyIndex >= Object.keys(status.standbys).length) {
      return res.status(400).json({
        success: false,
        error: `Invalid standbyIndex: must be less than ${Object.keys(status.standbys).length}`,
      });
    }

    logger.warn('⚠️ [Failover Routes] Manual failover triggered', {
      standbyIndex,
      userId: req.user?.id,
    });

    await failoverManager.performFailover(standbyIndex);

    const updatedStatus = failoverManager.getFailoverStatus();

    res.json({
      success: true,
      message: 'Failover triggered successfully',
      data: updatedStatus,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Failover Routes] Error triggering failover', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to trigger failover',
      message: error.message,
    });
  }
});

/**
 * POST /failover/check-health
 * Manually trigger health checks for all databases
 * Admin only
 */
router.post('/check-health', async (req, res) => {
  try {
    const failoverManager = getFailoverManager();

    logger.info('🔵 [Failover Routes] Manual health check triggered', {
      userId: req.user?.id,
    });

    // Check primary
    await failoverManager.checkPrimaryHealth();

    // Check all standbys
    for (let i = 0; i < failoverManager.standbyPools.length; i++) {
      await failoverManager.checkStandbyHealth(i);
    }

    const status = failoverManager.getFailoverStatus();

    res.json({
      success: true,
      message: 'Health checks completed',
      data: status,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Failover Routes] Error during manual health check', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to perform health checks',
      message: error.message,
    });
  }
});

/**
 * GET /failover/history
 * Get failover history and events
 */
router.get('/history', async (req, res) => {
  try {
    const failoverManager = getFailoverManager();
    const metrics = failoverManager.getMetrics();

    const history = {
      totalFailovers: metrics.failovers,
      totalRecoveries: metrics.recoveries,
      totalHealthCheckFailures: metrics.healthCheckFailures,
      lastFailoverTime: failoverManager.lastFailoverTime,
      lastStateChange: metrics.lastStateChange,
      currentState: metrics.state,
      failoverCount: failoverManager.failoverCount,
    };

    res.json({
      success: true,
      data: history,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Failover Routes] Error getting failover history', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to get failover history',
      message: error.message,
    });
  }
});

export default router;
