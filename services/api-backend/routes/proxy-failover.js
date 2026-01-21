import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import { authorizeRBAC } from '../middleware/rbac.js';
import { ProxyFailoverService } from '../services/proxy-failover-service.js';

/**
 * Proxy Failover Routes
 * Implements endpoints for managing proxy failover and redundancy
 * Validates: Requirements 5.8
 */

export function createProxyFailoverRoutes(db, logger) {
  const router = express.Router();
  const failoverService = new ProxyFailoverService(db, logger);

  /**
   * POST /proxy/failover/config
   * Create or update failover configuration for a proxy
   */
  router.post('/proxy/failover/config', authenticateJWT, async (req, res) => {
    try {
      const { proxyId, config } = req.body;
      const userId = req.user.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: {
            code: 'PROXY_FAILOVER_001',
            message: 'proxyId is required',
            statusCode: 400,
          },
        });
      }

      const result = await failoverService.createFailoverConfiguration(
        proxyId,
        userId,
        config,
      );

      res.status(201).json({
        data: result,
        message: 'Failover configuration created/updated successfully',
      });
    } catch (error) {
      logger.error('Error creating failover configuration', {
        error: error.message,
        userId: req.user?.sub,
      });

      res.status(500).json({
        error: {
          code: 'PROXY_FAILOVER_002',
          message: 'Failed to create failover configuration',
          statusCode: 500,
        },
      });
    }
  });

  /**
   * GET /proxy/failover/config/:proxyId
   * Get failover configuration for a proxy
   */
  router.get(
    '/proxy/failover/config/:proxyId',
    authenticateJWT,
    async (req, res) => {
      try {
        const { proxyId } = req.params;

        const result = await failoverService.getFailoverConfiguration(proxyId);

        if (!result) {
          return res.status(404).json({
            error: {
              code: 'PROXY_FAILOVER_003',
              message: 'Failover configuration not found',
              statusCode: 404,
            },
          });
        }

        res.status(200).json({
          data: result,
        });
      } catch (error) {
        logger.error('Error retrieving failover configuration', {
          error: error.message,
          proxyId: req.params.proxyId,
        });

        res.status(500).json({
          error: {
            code: 'PROXY_FAILOVER_004',
            message: 'Failed to retrieve failover configuration',
            statusCode: 500,
          },
        });
      }
    },
  );

  /**
   * POST /proxy/instances
   * Register a proxy instance
   */
  router.post('/proxy/instances', authenticateJWT, async (req, res) => {
    try {
      const { proxyId, instanceData } = req.body;
      const userId = req.user.sub;

      if (!proxyId || !instanceData) {
        return res.status(400).json({
          error: {
            code: 'PROXY_FAILOVER_005',
            message: 'proxyId and instanceData are required',
            statusCode: 400,
          },
        });
      }

      const result = await failoverService.registerProxyInstance(
        proxyId,
        userId,
        instanceData,
      );

      res.status(201).json({
        data: result,
        message: 'Proxy instance registered successfully',
      });
    } catch (error) {
      logger.error('Error registering proxy instance', {
        error: error.message,
        userId: req.user?.sub,
      });

      res.status(500).json({
        error: {
          code: 'PROXY_FAILOVER_006',
          message: 'Failed to register proxy instance',
          statusCode: 500,
        },
      });
    }
  });

  /**
   * GET /proxy/:proxyId/instances
   * Get all instances for a proxy
   */
  router.get('/proxy/:proxyId/instances', authenticateJWT, async (req, res) => {
    try {
      const { proxyId } = req.params;

      const result = await failoverService.getProxyInstances(proxyId);

      res.status(200).json({
        data: result,
        count: result.length,
      });
    } catch (error) {
      logger.error('Error retrieving proxy instances', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: {
          code: 'PROXY_FAILOVER_007',
          message: 'Failed to retrieve proxy instances',
          statusCode: 500,
        },
      });
    }
  });

  /**
   * PUT /proxy/instances/:instanceId/health
   * Update instance health status
   */
  router.put(
    '/proxy/instances/:instanceId/health',
    authenticateJWT,
    async (req, res) => {
      try {
        const { instanceId } = req.params;
        const { healthStatus, metrics } = req.body;

        if (!healthStatus) {
          return res.status(400).json({
            error: {
              code: 'PROXY_FAILOVER_008',
              message: 'healthStatus is required',
              statusCode: 400,
            },
          });
        }

        const result = await failoverService.updateInstanceHealth(
          instanceId,
          healthStatus,
          metrics,
        );

        res.status(200).json({
          data: result,
          message: 'Instance health updated successfully',
        });
      } catch (error) {
        logger.error('Error updating instance health', {
          error: error.message,
          instanceId: req.params.instanceId,
        });

        res.status(500).json({
          error: {
            code: 'PROXY_FAILOVER_009',
            message: 'Failed to update instance health',
            statusCode: 500,
          },
        });
      }
    },
  );

  /**
   * POST /proxy/failover/evaluate
   * Evaluate if failover is needed
   */
  router.post('/proxy/failover/evaluate', authenticateJWT, async (req, res) => {
    try {
      const { proxyId } = req.body;
      const userId = req.user.sub;

      if (!proxyId) {
        return res.status(400).json({
          error: {
            code: 'PROXY_FAILOVER_010',
            message: 'proxyId is required',
            statusCode: 400,
          },
        });
      }

      const result = await failoverService.evaluateFailover(proxyId, userId);

      res.status(200).json({
        data: result,
      });
    } catch (error) {
      logger.error('Error evaluating failover', {
        error: error.message,
        userId: req.user?.sub,
      });

      res.status(500).json({
        error: {
          code: 'PROXY_FAILOVER_011',
          message: 'Failed to evaluate failover',
          statusCode: 500,
        },
      });
    }
  });

  /**
   * POST /proxy/failover/execute
   * Execute failover operation
   */
  router.post(
    '/proxy/failover/execute',
    authenticateJWT,
    authorizeRBAC('admin'),
    async (req, res) => {
      try {
        const { proxyId, sourceInstanceId, targetInstanceId, reason } =
          req.body;
        const userId = req.user.sub;

        if (!proxyId || !sourceInstanceId || !targetInstanceId) {
          return res.status(400).json({
            error: {
              code: 'PROXY_FAILOVER_012',
              message:
                'proxyId, sourceInstanceId, and targetInstanceId are required',
              statusCode: 400,
            },
          });
        }

        const result = await failoverService.executeFailover(
          proxyId,
          userId,
          sourceInstanceId,
          targetInstanceId,
          reason || 'Manual failover',
        );

        res.status(200).json({
          data: result,
          message: 'Failover executed successfully',
        });
      } catch (error) {
        logger.error('Error executing failover', {
          error: error.message,
          userId: req.user?.sub,
        });

        res.status(500).json({
          error: {
            code: 'PROXY_FAILOVER_013',
            message: 'Failed to execute failover',
            statusCode: 500,
          },
        });
      }
    },
  );

  /**
   * PUT /proxy/failover/events/:eventId/complete
   * Complete a failover event
   */
  router.put(
    '/proxy/failover/events/:eventId/complete',
    authenticateJWT,
    authorizeRBAC('admin'),
    async (req, res) => {
      try {
        const { eventId } = req.params;
        const { status, errorMessage, durationMs } = req.body;

        if (!status) {
          return res.status(400).json({
            error: {
              code: 'PROXY_FAILOVER_014',
              message: 'status is required',
              statusCode: 400,
            },
          });
        }

        const result = await failoverService.completeFailoverEvent(
          eventId,
          status,
          errorMessage,
          durationMs,
        );

        res.status(200).json({
          data: result,
          message: 'Failover event completed successfully',
        });
      } catch (error) {
        logger.error('Error completing failover event', {
          error: error.message,
          eventId: req.params.eventId,
        });

        res.status(500).json({
          error: {
            code: 'PROXY_FAILOVER_015',
            message: 'Failed to complete failover event',
            statusCode: 500,
          },
        });
      }
    },
  );

  /**
   * GET /proxy/:proxyId/redundancy
   * Get redundancy status for a proxy
   */
  router.get(
    '/proxy/:proxyId/redundancy',
    authenticateJWT,
    async (req, res) => {
      try {
        const { proxyId } = req.params;

        const result = await failoverService.getRedundancyStatus(proxyId);

        if (!result) {
          return res.status(404).json({
            error: {
              code: 'PROXY_FAILOVER_016',
              message: 'Redundancy status not found',
              statusCode: 404,
            },
          });
        }

        res.status(200).json({
          data: result,
        });
      } catch (error) {
        logger.error('Error retrieving redundancy status', {
          error: error.message,
          proxyId: req.params.proxyId,
        });

        res.status(500).json({
          error: {
            code: 'PROXY_FAILOVER_017',
            message: 'Failed to retrieve redundancy status',
            statusCode: 500,
          },
        });
      }
    },
  );

  /**
   * PUT /proxy/:proxyId/redundancy
   * Update redundancy status for a proxy
   */
  router.put(
    '/proxy/:proxyId/redundancy',
    authenticateJWT,
    authorizeRBAC('admin'),
    async (req, res) => {
      try {
        const { proxyId } = req.params;
        const userId = req.user.sub;
        const statusData = req.body;

        const result = await failoverService.updateRedundancyStatus(
          proxyId,
          userId,
          statusData,
        );

        res.status(200).json({
          data: result,
          message: 'Redundancy status updated successfully',
        });
      } catch (error) {
        logger.error('Error updating redundancy status', {
          error: error.message,
          proxyId: req.params.proxyId,
        });

        res.status(500).json({
          error: {
            code: 'PROXY_FAILOVER_018',
            message: 'Failed to update redundancy status',
            statusCode: 500,
          },
        });
      }
    },
  );

  /**
   * GET /proxy/:proxyId/failover/events
   * Get failover events for a proxy
   */
  router.get(
    '/proxy/:proxyId/failover/events',
    authenticateJWT,
    async (req, res) => {
      try {
        const { proxyId } = req.params;
        const limit = parseInt(req.query.limit || '50', 10);

        const result = await failoverService.getFailoverEvents(proxyId, limit);

        res.status(200).json({
          data: result,
          count: result.length,
        });
      } catch (error) {
        logger.error('Error retrieving failover events', {
          error: error.message,
          proxyId: req.params.proxyId,
        });

        res.status(500).json({
          error: {
            code: 'PROXY_FAILOVER_019',
            message: 'Failed to retrieve failover events',
            statusCode: 500,
          },
        });
      }
    },
  );

  return router;
}

export default createProxyFailoverRoutes;
