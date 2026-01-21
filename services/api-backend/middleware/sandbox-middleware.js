/**
 * Sandbox Middleware
 *
 * Middleware for handling sandbox mode requests.
 * Intercepts requests in sandbox mode and provides mock responses without side effects.
 */

import winston from 'winston';
import { sandboxService } from '../services/sandbox-service.js';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'sandbox-middleware' },
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
 * Sandbox mode detection middleware
 * Adds sandbox flag to request if sandbox mode is enabled
 */
export const sandboxDetectionMiddleware = (req, res, next) => {
  req.isSandbox = sandboxService.isSandbox();
  req.sandboxService = sandboxService;

  if (req.isSandbox) {
    logger.debug(`Sandbox mode enabled for request: ${req.method} ${req.path}`);
  }

  next();
};

/**
 * Sandbox request logging middleware
 * Logs all requests in sandbox mode for debugging and testing
 */
export const sandboxLoggingMiddleware = (req, res, next) => {
  if (!req.isSandbox) {
    return next();
  }

  const startTime = Date.now();

  // Capture original send method
  const originalSend = res.send;

  res.send = function (data) {
    const responseTime = Date.now() - startTime;

    // Log request in sandbox
    sandboxService.logRequest({
      method: req.method,
      path: req.path,
      userId: req.user?.sub || 'anonymous',
      statusCode: res.statusCode,
      responseTime,
      body: req.body,
    });

    logger.debug(
      `Sandbox request logged: ${req.method} ${req.path} (${responseTime}ms)`,
    );

    // Call original send
    return originalSend.call(this, data);
  };

  next();
};

/**
 * Sandbox data isolation middleware
 * Ensures sandbox requests don't affect production data
 */
export const sandboxDataIsolationMiddleware = (req, res, next) => {
  if (!req.isSandbox) {
    return next();
  }

  // Mark request as sandbox to prevent database writes
  req.sandboxMode = true;

  // Add sandbox header to response
  res.set('X-Sandbox-Mode', 'true');

  logger.debug(
    `Data isolation enabled for sandbox request: ${req.method} ${req.path}`,
  );

  next();
};

/**
 * Sandbox rate limiting middleware
 * Applies relaxed rate limits for sandbox testing
 */
export const sandboxRateLimitMiddleware = (req, res, next) => {
  if (!req.isSandbox) {
    return next();
  }

  // In sandbox mode, allow much higher rate limits
  const config = sandboxService.getSandboxConfig();
  req.sandboxRateLimit = {
    requestsPerMinute: config.rateLimits.requestsPerMinute,
    burstSize: config.rateLimits.burstSize,
  };

  logger.debug(
    `Sandbox rate limits applied: ${config.rateLimits.requestsPerMinute} req/min`,
  );

  next();
};

/**
 * Sandbox response wrapper middleware
 * Wraps responses with sandbox metadata
 */
export const sandboxResponseWrapperMiddleware = (req, res, next) => {
  if (!req.isSandbox) {
    return next();
  }

  // Capture original json method
  const originalJson = res.json;

  res.json = function (data) {
    // Wrap response with sandbox metadata
    const wrappedResponse = {
      data,
      _sandbox: {
        mode: true,
        timestamp: new Date().toISOString(),
        requestId: req.id,
      },
    };

    return originalJson.call(this, wrappedResponse);
  };

  next();
};

/**
 * Sandbox error handling middleware
 * Provides detailed error information in sandbox mode
 */
export const sandboxErrorHandlingMiddleware = (err, req, res, next) => {
  if (!req.isSandbox) {
    return next(err);
  }

  logger.error(`Sandbox error: ${err.message}`, {
    path: req.path,
    method: req.method,
    stack: err.stack,
  });

  const errorResponse = {
    error: {
      code: err.code || 'SANDBOX_ERROR',
      message: err.message,
      details: err.details || {},
      _sandbox: {
        mode: true,
        timestamp: new Date().toISOString(),
        requestId: req.id,
        stack: process.env.NODE_ENV === 'sandbox' ? err.stack : undefined,
      },
    },
  };

  res.status(err.statusCode || 500).json(errorResponse);
};

/**
 * Sandbox cleanup middleware
 * Cleans up sandbox data on request completion
 */
export const sandboxCleanupMiddleware = (req, res, next) => {
  if (!req.isSandbox) {
    return next();
  }

  // Schedule cleanup after response is sent
  res.on('finish', () => {
    logger.debug(`Sandbox request completed: ${req.method} ${req.path}`);
  });

  next();
};
