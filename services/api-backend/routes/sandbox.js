/**
 * Sandbox Routes
 *
 * Provides endpoints for managing sandbox environment and testing.
 * Allows developers to:
 * - Get sandbox configuration
 * - Retrieve test credentials
 * - Create mock data
 * - View request logs
 * - Clear sandbox data
 */

import express from 'express';
import { z } from 'zod';
import winston from 'winston';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { sandboxService } from '../services/sandbox-service.js';

const router = express.Router();
router.use(authenticateJWT);

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'sandbox-routes' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

// Zod schemas for validation
const createMockUserSchema = z.object({
  email: z.string().email().optional(),
  firstName: z.string().optional(),
  lastName: z.string().optional(),
  tier: z.string().optional(),
});

const createMockTunnelSchema = z.object({
  userId: z.string().optional(),
  name: z.string().optional(),
});

const createMockWebhookSchema = z.object({
  userId: z.string().optional(),
  url: z.string().url().optional(),
  events: z.array(z.string()).optional(),
});

const updateTunnelStatusSchema = z.object({
  status: z.string().min(1),
});

const recordTunnelMetricsSchema = z.object({
  requestCount: z.number().int().nonnegative().optional(),
  successCount: z.number().int().nonnegative().optional(),
  errorCount: z.number().int().nonnegative().optional(),
  latency: z.number().nonnegative().optional(),
});

const tunnelIdSchema = z.object({
  tunnelId: z.string().min(1),
});

/**
 * GET /sandbox/config
 * Get sandbox environment configuration
 */
router.get('/config', (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  const config = sandboxService.getSandboxConfig();
  logger.info('Sandbox configuration retrieved');

  res.json({
    success: true,
    config,
  });
});

/**
 * GET /sandbox/credentials
 * Get test credentials for sandbox environment
 */
router.get('/credentials', (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  const credentials = sandboxService.getTestCredentials();
  logger.info('Test credentials retrieved');

  res.json({
    success: true,
    credentials,
  });
});

/**
 * POST /sandbox/users
 * Create mock user for testing
 */
router.post('/users', validateSchema({ body: createMockUserSchema }), (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  try {
    const { email, firstName, lastName, tier } = req.body;

    const mockUser = sandboxService.createMockUser({
      email,
      firstName,
      lastName,
      tier,
    });

    logger.info(`Mock user created: ${mockUser.id}`);

    res.status(201).json({
      success: true,
      user: mockUser,
    });
  } catch (error) {
    logger.error(`Error creating mock user: ${error.message}`);
    res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: error.message,
      },
    });
  }
});

/**
 * POST /sandbox/tunnels
 * Create mock tunnel for testing
 */
router.post('/tunnels', validateSchema({ body: createMockTunnelSchema }), (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  try {
    const { userId, name } = req.body;

    const mockTunnel = sandboxService.createMockTunnel({
      userId,
      name,
    });

    logger.info(`Mock tunnel created: ${mockTunnel.id}`);

    res.status(201).json({
      success: true,
      tunnel: mockTunnel,
    });
  } catch (error) {
    logger.error(`Error creating mock tunnel: ${error.message}`);
    res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: error.message,
      },
    });
  }
});

/**
 * POST /sandbox/webhooks
 * Create mock webhook for testing
 */
router.post('/webhooks', validateSchema({ body: createMockWebhookSchema }), (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  try {
    const { userId, url, events } = req.body;

    const mockWebhook = sandboxService.createMockWebhook({
      userId,
      url,
      events,
    });

    logger.info(`Mock webhook created: ${mockWebhook.id}`);

    res.status(201).json({
      success: true,
      webhook: mockWebhook,
    });
  } catch (error) {
    logger.error(`Error creating mock webhook: ${error.message}`);
    res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: error.message,
      },
    });
  }
});

/**
 * GET /sandbox/requests
 * Get request log from sandbox
 */
router.get('/requests', (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  try {
    const { userId, method, path, limit } = req.query;

    const log = sandboxService.getRequestLog({
      userId,
      method,
      path,
      limit: limit ? parseInt(limit) : 100,
    });

    logger.info(`Request log retrieved: ${log.length} entries`);

    res.json({
      success: true,
      requests: log,
      count: log.length,
    });
  } catch (error) {
    logger.error(`Error retrieving request log: ${error.message}`);
    res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: error.message,
      },
    });
  }
});

/**
 * GET /sandbox/stats
 * Get sandbox statistics
 */
router.get('/stats', (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  const stats = sandboxService.getSandboxStats();
  logger.info('Sandbox statistics retrieved');

  res.json({
    success: true,
    stats,
  });
});

/**
 * DELETE /sandbox/clear
 * Clear all sandbox data
 */
router.delete('/clear', (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  try {
    sandboxService.clearSandboxData();
    logger.info('Sandbox data cleared');

    res.json({
      success: true,
      message: 'Sandbox data cleared successfully',
    });
  } catch (error) {
    logger.error(`Error clearing sandbox data: ${error.message}`);
    res.status(500).json({
      error: {
        code: 'INTERNAL_ERROR',
        message: error.message,
      },
    });
  }
});

/**
 * GET /sandbox/users/:userId
 * Get mock user by ID
 */
router.get('/users/:userId', (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  try {
    const { userId } = req.params;
    const user = sandboxService.getMockUser(userId);

    if (!user) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: `Mock user not found: ${userId}`,
        },
      });
    }

    res.json({
      success: true,
      user,
    });
  } catch (error) {
    logger.error(`Error retrieving mock user: ${error.message}`);
    res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: error.message,
      },
    });
  }
});

/**
 * GET /sandbox/tunnels/:tunnelId
 * Get mock tunnel by ID
 */
router.get('/tunnels/:tunnelId', (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  try {
    const { tunnelId } = req.params;
    const tunnel = sandboxService.getMockTunnel(tunnelId);

    if (!tunnel) {
      return res.status(404).json({
        error: {
          code: 'NOT_FOUND',
          message: `Mock tunnel not found: ${tunnelId}`,
        },
      });
    }

    res.json({
      success: true,
      tunnel,
    });
  } catch (error) {
    logger.error(`Error retrieving mock tunnel: ${error.message}`);
    res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: error.message,
      },
    });
  }
});

/**
 * PATCH /sandbox/tunnels/:tunnelId/status
 * Update mock tunnel status
 */
router.patch('/tunnels/:tunnelId/status', validateSchema({ params: tunnelIdSchema, body: updateTunnelStatusSchema }), (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  try {
    const { tunnelId } = req.params;
    const { status } = req.body;

    sandboxService.updateMockTunnelStatus(tunnelId, status);
    const tunnel = sandboxService.getMockTunnel(tunnelId);

    logger.info(`Mock tunnel status updated: ${tunnelId} -> ${status}`);

    res.json({
      success: true,
      tunnel,
    });
  } catch (error) {
    logger.error(`Error updating mock tunnel status: ${error.message}`);
    res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: error.message,
      },
    });
  }
});

/**
 * POST /sandbox/tunnels/:tunnelId/metrics
 * Record mock tunnel metrics
 */
router.post('/tunnels/:tunnelId/metrics', validateSchema({ params: tunnelIdSchema, body: recordTunnelMetricsSchema }), (req, res) => {
  if (!req.isSandbox) {
    return res.status(403).json({
      error: {
        code: 'SANDBOX_DISABLED',
        message: 'Sandbox mode is not enabled',
      },
    });
  }

  try {
    const { tunnelId } = req.params;
    const { requestCount, successCount, errorCount, latency } = req.body;

    sandboxService.recordMockTunnelMetrics(tunnelId, {
      requestCount,
      successCount,
      errorCount,
      latency,
    });

    const tunnel = sandboxService.getMockTunnel(tunnelId);

    logger.info(`Mock tunnel metrics recorded: ${tunnelId}`);

    res.json({
      success: true,
      tunnel,
    });
  } catch (error) {
    logger.error(`Error recording mock tunnel metrics: ${error.message}`);
    res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: error.message,
      },
    });
  }
});

export default router;
