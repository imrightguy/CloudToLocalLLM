/**
 * @fileoverview Express routes for SSH tunnel system health and status checks.
 */

import express from 'express';
import winston from 'winston';
import {
  TunnelLogger,
  ERROR_CODES,
  ErrorResponseBuilder,
} from '../utils/logger.js';
import { AuthService } from '../auth/auth-service.js';
import { addTierInfo, requireFeature } from '../middleware/tier-check.js';

/**
 * Creates tunnel-related routes, primarily for health and status checks.
 * @param {Object} config - Configuration object.
 * @param {Object} config - Configuration object.
 * @param {Object} tunnelProxy - The tunnel proxy instance (SSHProxy when implemented).
 * @param {winston.Logger} [logger] - Logger instance.
 * @param {AuthService} [authService] - Pre-initialized authentication service.
 * @returns {express.Router} The configured Express router.
 */
export function createTunnelRoutes(
  config,
  tunnelProxy,
  logger = winston.createLogger(),
  authService = null,
) {
  const router = express.Router();

  const tunnelLogger =
    logger instanceof TunnelLogger ? logger : new TunnelLogger('tunnel-routes');

  // Use provided auth service or create a new one (fallback)
  if (!authService) {
    authService = new AuthService({
      AUTH0_ISSUER_URL: process.env.AUTH0_ISSUER_URL,
    });
  }

  async function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res
        .status(401)
        .json(
          ErrorResponseBuilder.authenticationError(
            'Bearer token is required.',
            ERROR_CODES.AUTH_TOKEN_MISSING,
          ),
        );
    }

    try {
      const payload = await authService.validateToken(token);
      req.userId = payload.sub;
      req.user = payload; // Also set req.user for addTierInfo middleware
      next();
    } catch (error) {
      tunnelLogger.logSecurity('auth_token_invalid', null, {
        error: error.message,
      });
      res
        .status(403)
        .json(
          ErrorResponseBuilder.authenticationError(
            'Invalid or expired token.',
            ERROR_CODES.AUTH_TOKEN_INVALID,
          ),
        );
    }
  }

  router.use(authenticateToken);
  router.use(addTierInfo);

  // Register SSH client connection
  // Called by desktop client after establishing SSH tunnel
  router.post('/register', requireFeature('tunneling'), async (req, res) => {
    try {
      const userId = req.userId;
      const { tunnelId, localPort, serverPort } = req.body;

      if (!tunnelId || !localPort) {
        return res.status(400).json({
          error: 'Bad Request',
          message: 'tunnelId and localPort are required',
        });
      }

      if (!tunnelProxy) {
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'SSH tunnel server not initialized',
        });
      }

      // Register the client connection
      const assignedPort = tunnelProxy.registerClient(
        userId,
        tunnelId,
        localPort,
        serverPort,
      );

      res.json({
        success: true,
        userId,
        tunnelId,
        localPort,
        serverPort: assignedPort,
        message: 'SSH client registered successfully',
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to register client',
        { error: error.message },
      );
      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to register client.',
            ERROR_CODES.INTERNAL_SERVER_ERROR,
          ),
        );
    }
  });

  // Unregister SSH client connection
  router.post('/unregister', requireFeature('tunneling'), (req, res) => {
    try {
      const userId = req.userId;

      if (!tunnelProxy) {
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'SSH tunnel server not initialized',
        });
      }

      tunnelProxy.unregisterClient(userId);

      res.json({
        success: true,
        userId,
        message: 'SSH client unregistered successfully',
      });
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to unregister client',
        { error: error.message },
      );
      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to unregister client.',
            ERROR_CODES.INTERNAL_SERVER_ERROR,
          ),
        );
    }
  });

  // Health check for a specific user's tunnel connection
  router.get('/health/:userId', requireFeature('tunneling'), (req, res) => {
    const { userId } = req.params;
    if (userId !== req.userId) {
      return res.status(403).json({
        error: 'Forbidden',
        message: 'You can only check your own tunnel status.',
      });
    }

    if (!tunnelProxy) {
      return res.json({
        userId,
        connected: false,
        message: 'SSH tunnel server not initialized',
        timestamp: new Date().toISOString(),
      });
    }

    const status = tunnelProxy.getUserConnectionStatus(userId);
    res.json({ userId, ...status, timestamp: new Date().toISOString() });
  });

  // General system-wide tunnel health
  router.get('/health', (req, res) => {
    try {
      if (!tunnelProxy) {
        return res.status(503).json({
          status: 'degraded',
          message: 'SSH tunnel server not initialized',
          timestamp: new Date().toISOString(),
        });
      }

      const healthStatus = tunnelProxy.getHealthStatus();
      const statusCode = healthStatus.status === 'healthy' ? 200 : 503;
      res.status(statusCode).json(healthStatus);
    } catch (error) {
      tunnelLogger.logTunnelError(
        ERROR_CODES.INTERNAL_SERVER_ERROR,
        'Failed to get tunnel health status',
        { error: error.message },
      );
      res
        .status(500)
        .json(
          ErrorResponseBuilder.internalServerError(
            'Failed to retrieve health status.',
            ERROR_CODES.INTERNAL_SERVER_ERROR,
          ),
        );
    }
  });

  // Get performance and connection metrics
  router.get('/metrics', requireFeature('tunneling'), (req, res) => {
    if (!tunnelProxy) {
      return res.json({
        system: { message: 'SSH tunnel server not initialized' },
        timestamp: new Date().toISOString(),
      });
    }

    const stats = tunnelProxy.getStats();
    res.json({
      system: stats,
      timestamp: new Date().toISOString(),
    });
  });

  return router;
}
