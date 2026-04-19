/**
 * Error Recovery Routes
 *
 * Provides endpoints for manual error recovery intervention.
 * Allows admins to trigger recovery procedures and monitor recovery status.
 *
 * Requirement 7.7: THE API SHALL provide error recovery endpoints for manual intervention
 */

import express from 'express';
import { z } from 'zod';
import winston from 'winston';
import { errorRecoveryService } from '../services/error-recovery-service.js';
import { authenticateJWT } from '../middleware/auth.js';
import { requireAdmin as createRequireAdminMiddleware } from '../middleware/rbac.js';
import { validateSchema } from '../middleware/schema-validation.js';

const router = express.Router();

const serviceNameParamSchema = z.object({
  serviceName: z.string().min(1),
});

const recoverServiceSchema = {
  params: serviceNameParamSchema,
  body: z.object({
    reason: z.string().optional(),
  }),
};

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'error-recovery-routes' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

/**
 * GET /error-recovery/status
 * Get recovery status for all services
 * Requires: Admin role
 */
router.get(
  '/status',
  authenticateJWT,
  createRequireAdminMiddleware(),
  (req, res) => {
    try {
      const statuses = errorRecoveryService.getAllRecoveryStatuses();

      res.json({
        status: 'success',
        data: statuses,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error fetching recovery statuses:', error);
      res.status(500).json({
        status: 'error',
        message: 'Failed to fetch recovery statuses',
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  },
);

/**
 * GET /error-recovery/status/:serviceName
 * Get recovery status for a specific service
 * Requires: Admin role
 */
router.get(
  '/status/:serviceName',
  validateSchema({ params: serviceNameParamSchema }),
  authenticateJWT,
  createRequireAdminMiddleware(),
  (req, res) => {
    try {
      const { serviceName } = req.params;

      const status = errorRecoveryService.getRecoveryStatus(serviceName);

      res.json({
        status: 'success',
        data: status,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error fetching recovery status:', error);
      res.status(500).json({
        status: 'error',
        message: 'Failed to fetch recovery status',
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  },
);

/**
 * POST /error-recovery/recover/:serviceName
 * Trigger recovery procedure for a service
 * Requires: Admin role
 * Body: { reason?: string }
 */
router.post(
  '/recover/:serviceName',
  validateSchema(recoverServiceSchema),
  authenticateJWT,
  createRequireAdminMiddleware(),
  async (req, res) => {
    try {
      const { serviceName } = req.params;
      const { reason } = req.body || {};
      const userId = req.auth?.payload?.sub;

      logger.info(`Recovery initiated for service: ${serviceName}`, {
        userId,
        reason,
      });

      const result = await errorRecoveryService.executeRecovery(serviceName, {
        initiatedBy: userId,
        reason: reason || 'Manual intervention',
      });

      res.json({
        status: 'success',
        data: result,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error executing recovery:', error);

      // Check if error is due to recovery already in progress
      if (error.message.includes('already in progress')) {
        return res.status(409).json({
          status: 'error',
          message: 'Recovery already in progress for this service',
          error: error.message,
          timestamp: new Date().toISOString(),
        });
      }

      // Check if error is due to no recovery procedure registered
      if (error.message.includes('No recovery procedure')) {
        return res.status(404).json({
          status: 'error',
          message: 'No recovery procedure registered for this service',
          error: error.message,
          timestamp: new Date().toISOString(),
        });
      }

      res.status(500).json({
        status: 'error',
        message: 'Failed to execute recovery procedure',
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  },
);

/**
 * GET /error-recovery/history
 * Get recovery history
 * Requires: Admin role
 * Query: { serviceName?: string, status?: string, limit?: number }
 */
router.get(
  '/history',
  authenticateJWT,
  createRequireAdminMiddleware(),
  (req, res) => {
    try {
      const { serviceName, status, limit } = req.query;

      const options = {};
      if (serviceName) {
        options.serviceName = serviceName;
      }
      if (status) {
        options.status = status;
      }
      if (limit) {
        options.limit = parseInt(limit, 10);
      }

      const history = errorRecoveryService.getRecoveryHistory(options);

      res.json({
        status: 'success',
        data: history,
        count: history.length,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error fetching recovery history:', error);
      res.status(500).json({
        status: 'error',
        message: 'Failed to fetch recovery history',
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  },
);

/**
 * GET /error-recovery/metrics
 * Get recovery metrics
 * Requires: Admin role
 */
router.get(
  '/metrics',
  authenticateJWT,
  createRequireAdminMiddleware(),
  (req, res) => {
    try {
      const metrics = errorRecoveryService.getMetrics();

      res.json({
        status: 'success',
        data: metrics,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error fetching recovery metrics:', error);
      res.status(500).json({
        status: 'error',
        message: 'Failed to fetch recovery metrics',
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  },
);

/**
 * GET /error-recovery/report
 * Get comprehensive recovery report
 * Requires: Admin role
 */
router.get(
  '/report',
  authenticateJWT,
  createRequireAdminMiddleware(),
  (req, res) => {
    try {
      const report = errorRecoveryService.getReport();

      res.json({
        status: 'success',
        data: report,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error generating recovery report:', error);
      res.status(500).json({
        status: 'error',
        message: 'Failed to generate recovery report',
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  },
);

/**
 * DELETE /error-recovery/history
 * Clear recovery history
 * Requires: Admin role
 */
router.delete(
  '/history',
  authenticateJWT,
  createRequireAdminMiddleware(),
  (req, res) => {
    try {
      errorRecoveryService.clearHistory();

      res.json({
        status: 'success',
        message: 'Recovery history cleared',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error clearing recovery history:', error);
      res.status(500).json({
        status: 'error',
        message: 'Failed to clear recovery history',
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  },
);

/**
 * POST /error-recovery/reset-metrics
 * Reset recovery metrics
 * Requires: Admin role
 */
router.post(
  '/reset-metrics',
  authenticateJWT,
  createRequireAdminMiddleware(),
  (req, res) => {
    try {
      errorRecoveryService.resetMetrics();

      res.json({
        status: 'success',
        message: 'Recovery metrics reset',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error resetting recovery metrics:', error);
      res.status(500).json({
        status: 'error',
        message: 'Failed to reset recovery metrics',
        error: error.message,
        timestamp: new Date().toISOString(),
      });
    }
  },
);

export default router;
