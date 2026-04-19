import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import { addTierInfo } from '../middleware/tier-check.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { z } from 'zod';
import winston from 'winston';

const router = express.Router();

const createScalingPolicySchema = {
  params: z.object({
    proxyId: z.string().min(1),
  }),
  body: z.object({
    minReplicas: z.number().int().min(1).optional(),
    maxReplicas: z.number().int().min(1).optional(),
    targetCpuPercent: z.number().min(0).max(100).optional(),
    targetMemoryPercent: z.number().min(0).max(100).optional(),
    targetRequestRate: z.number().min(0).optional(),
    scaleUpThreshold: z.number().min(0).max(100).optional(),
    scaleDownThreshold: z.number().min(0).max(100).optional(),
    scaleUpCooldownSeconds: z.number().int().min(0).optional(),
    scaleDownCooldownSeconds: z.number().int().min(0).optional(),
    enabled: z.boolean().optional(),
  })
    .refine((data) => !data.maxReplicas || !data.minReplicas || data.maxReplicas >= data.minReplicas, {
      message: 'maxReplicas must be >= minReplicas',
      path: ['maxReplicas'],
    })
    .refine((data) => !data.scaleDownThreshold || !data.scaleUpThreshold || data.scaleDownThreshold < data.scaleUpThreshold, {
      message: 'scaleDownThreshold must be less than scaleUpThreshold',
      path: ['scaleDownThreshold'],
    }),
};

const recordLoadMetricsSchema = {
  params: z.object({
    proxyId: z.string().min(1),
  }),
  body: z.object({
    currentReplicas: z.number().int().min(1),
    cpuPercent: z.number().min(0).max(100),
    memoryPercent: z.number().min(0).max(100),
    requestRate: z.number().min(0),
    averageLatencyMs: z.number().min(0),
    errorRate: z.number().min(0).max(1),
    connectionCount: z.number().int().min(0),
  }),
};

const proxyIdParamSchema = {
  params: z.object({
    proxyId: z.string().min(1),
  }),
};

// Logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'proxy-scaling-routes' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

// Global proxy scaling service (will be injected)
let proxyScalingService = null;

/**
 * Initialize proxy scaling routes with service
 * @param {ProxyScalingService} scalingService - Proxy scaling service instance
 * @returns {Router} Express router
 */
export function createProxyScalingRoutes(scalingService) {
  proxyScalingService = scalingService;
  return router;
}

/**
 * POST /proxy/scaling/policies/:proxyId
 * Create or update scaling policy for a proxy
 * Validates: Requirements 5.5
 */
router.post(
  '/scaling/policies/:proxyId',
  authenticateJWT,
  addTierInfo,
  validateSchema(createScalingPolicySchema),
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const policy = req.body;

      if (!proxyScalingService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy scaling service not initialized',
          code: 'PROXY_SCALING_002',
        });
      }

      try {
        const createdPolicy = await proxyScalingService.createScalingPolicy(
          proxyId,
          userId,
          policy,
        );

        logger.info('Scaling policy created/updated', {
          proxyId,
          userId,
          policy: createdPolicy,
        });

        res.status(201).json({
          message: 'Scaling policy created/updated successfully',
          policy: createdPolicy,
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        if (error.message.includes('validation')) {
          return res.status(400).json({
            error: 'VALIDATION_ERROR',
            message: error.message,
            code: 'PROXY_SCALING_003',
          });
        }
        throw error;
      }
    } catch (error) {
      logger.error('Error creating scaling policy', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to create scaling policy',
        code: 'PROXY_SCALING_004',
      });
    }
  },
);

/**
 * GET /proxy/scaling/policies/:proxyId
 * Get scaling policy for a proxy
 * Validates: Requirements 5.5
 */
router.get(
  '/scaling/policies/:proxyId',
  authenticateJWT,
  addTierInfo,
  validateSchema(proxyIdParamSchema),
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      if (!proxyScalingService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy scaling service not initialized',
          code: 'PROXY_SCALING_002',
        });
      }

      const policy = await proxyScalingService.getScalingPolicy(proxyId);

      if (!policy) {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: 'Scaling policy not found',
          code: 'PROXY_SCALING_005',
        });
      }

      logger.info('Scaling policy retrieved', {
        proxyId,
        userId,
      });

      res.json({
        policy,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving scaling policy', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve scaling policy',
        code: 'PROXY_SCALING_004',
      });
    }
  },
);

/**
 * POST /proxy/scaling/metrics/:proxyId
 * Record load metrics for a proxy
 * Validates: Requirements 5.5
 */
router.post(
  '/scaling/metrics/:proxyId',
  authenticateJWT,
  addTierInfo,
  validateSchema(recordLoadMetricsSchema),
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const metrics = req.body;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_SCALING_001',
        });
      }

      if (!proxyScalingService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy scaling service not initialized',
          code: 'PROXY_SCALING_002',
        });
      }

      try {
        const recordedMetrics = await proxyScalingService.recordLoadMetrics(
          proxyId,
          userId,
          metrics,
        );

        logger.debug('Load metrics recorded', {
          proxyId,
          userId,
          loadScore: recordedMetrics.loadScore,
        });

        res.status(201).json({
          message: 'Load metrics recorded successfully',
          metrics: recordedMetrics,
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        if (
          error.message.includes('required') ||
          error.message.includes('must be')
        ) {
          return res.status(400).json({
            error: 'VALIDATION_ERROR',
            message: error.message,
            code: 'PROXY_SCALING_003',
          });
        }
        throw error;
      }
    } catch (error) {
      logger.error('Error recording load metrics', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to record load metrics',
        code: 'PROXY_SCALING_004',
      });
    }
  },
);

/**
 * GET /proxy/scaling/metrics/:proxyId
 * Get current load metrics for a proxy
 * Validates: Requirements 5.5
 */
router.get(
  '/scaling/metrics/:proxyId',
  authenticateJWT,
  addTierInfo,
  validateSchema(proxyIdParamSchema),
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      if (!proxyScalingService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy scaling service not initialized',
          code: 'PROXY_SCALING_002',
        });
      }

      const metrics = await proxyScalingService.getCurrentLoadMetrics(proxyId);

      if (!metrics) {
        return res.status(404).json({
          error: 'NOT_FOUND',
          message: 'Load metrics not found',
          code: 'PROXY_SCALING_005',
        });
      }

      logger.info('Load metrics retrieved', {
        proxyId,
        userId,
      });

      res.json({
        metrics,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving load metrics', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve load metrics',
        code: 'PROXY_SCALING_004',
      });
    }
  },
);

/**
 * POST /proxy/scaling/evaluate/:proxyId
 * Evaluate if scaling is needed based on current metrics
 * Validates: Requirements 5.5
 */
router.post(
  '/scaling/evaluate/:proxyId',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;

      if (!proxyScalingService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy scaling service not initialized',
          code: 'PROXY_SCALING_002',
        });
      }

      const decision = await proxyScalingService.evaluateScaling(
        proxyId,
        userId,
      );

      logger.info('Scaling evaluation completed', {
        proxyId,
        userId,
        shouldScale: decision.shouldScale,
        scalingAction: decision.scalingAction,
      });

      res.json({
        decision,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error evaluating scaling', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to evaluate scaling',
        code: 'PROXY_SCALING_004',
      });
    }
  },
);

/**
 * POST /proxy/scaling/execute/:proxyId
 * Execute scaling operation
 * Validates: Requirements 5.5
 */
router.post(
  '/proxy/scaling/execute/:proxyId',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const { newReplicaCount, reason, triggeredBy } = req.body;

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_SCALING_001',
        });
      }

      if (!newReplicaCount) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'newReplicaCount is required',
          code: 'PROXY_SCALING_001',
        });
      }

      if (!proxyScalingService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy scaling service not initialized',
          code: 'PROXY_SCALING_002',
        });
      }

      try {
        const scalingEvent = await proxyScalingService.executeScaling(
          proxyId,
          userId,
          newReplicaCount,
          reason || 'Manual scaling',
          triggeredBy || 'manual',
        );

        logger.info('Scaling operation executed', {
          proxyId,
          userId,
          newReplicaCount,
          eventId: scalingEvent.id,
        });

        res.status(202).json({
          message: 'Scaling operation initiated',
          scalingEvent,
          timestamp: new Date().toISOString(),
        });
      } catch (error) {
        if (error.message.includes('must be')) {
          return res.status(400).json({
            error: 'VALIDATION_ERROR',
            message: error.message,
            code: 'PROXY_SCALING_003',
          });
        }
        throw error;
      }
    } catch (error) {
      logger.error('Error executing scaling', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to execute scaling',
        code: 'PROXY_SCALING_004',
      });
    }
  },
);

/**
 * GET /proxy/scaling/events/:proxyId
 * Get scaling events for a proxy
 * Validates: Requirements 5.5
 */
router.get(
  '/scaling/events/:proxyId',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const limit = parseInt(req.query.limit || '50', 10);

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_SCALING_001',
        });
      }

      if (!proxyScalingService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy scaling service not initialized',
          code: 'PROXY_SCALING_002',
        });
      }

      const events = await proxyScalingService.getScalingEvents(proxyId, limit);

      logger.info('Scaling events retrieved', {
        proxyId,
        userId,
        eventCount: events.length,
      });

      res.json({
        events,
        count: events.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving scaling events', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve scaling events',
        code: 'PROXY_SCALING_004',
      });
    }
  },
);

/**
 * GET /proxy/scaling/summary/:proxyId
 * Get scaling metrics summary for a proxy
 * Validates: Requirements 5.5
 */
router.get(
  '/scaling/summary/:proxyId',
  authenticateJWT,
  addTierInfo,
  async (req, res) => {
    try {
      const { proxyId } = req.params;
      const userId = req.user?.sub;
      const hoursBack = parseInt(req.query.hoursBack || '24', 10);

      if (!proxyId) {
        return res.status(400).json({
          error: 'INVALID_REQUEST',
          message: 'proxyId is required',
          code: 'PROXY_SCALING_001',
        });
      }

      if (!proxyScalingService) {
        return res.status(503).json({
          error: 'SERVICE_UNAVAILABLE',
          message: 'Proxy scaling service not initialized',
          code: 'PROXY_SCALING_002',
        });
      }

      const summary = await proxyScalingService.getScalingSummary(
        proxyId,
        hoursBack,
      );

      logger.info('Scaling summary retrieved', {
        proxyId,
        userId,
        hoursBack,
      });

      res.json({
        summary,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error retrieving scaling summary', {
        error: error.message,
        proxyId: req.params.proxyId,
      });

      res.status(500).json({
        error: 'INTERNAL_SERVER_ERROR',
        message: 'Failed to retrieve scaling summary',
        code: 'PROXY_SCALING_004',
      });
    }
  },
);

export default router;
