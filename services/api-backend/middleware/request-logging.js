/**
 * Request Logging Middleware for CloudToLocalLLM API Backend
 *
 * Implements structured request/response logging with correlation IDs
 * for request tracing across distributed systems.
 *
 * @fileoverview Request logging middleware with correlation IDs
 * @version 1.0.0
 */

import { v4 as uuidv4 } from 'uuid';
import logger from '../logger.js';

/**
 * Create request logging middleware with correlation ID tracking
 * @returns {Function} Express middleware function
 */
export function createRequestLoggingMiddleware() {
  return (req, res, next) => {
    // Generate or extract correlation ID
    const correlationId = req.headers['x-correlation-id'] || `req-${uuidv4()}`;
    req.correlationId = correlationId;

    // Add correlation ID to response headers
    res.setHeader('X-Correlation-ID', correlationId);

    // Record request start time
    const startTime = Date.now();

    // Log incoming request
    logger.info('Incoming request', {
      correlationId,
      method: req.method,
      path: req.path,
      query: req.query,
      userId: req.user?.sub,
      ip: req.ip,
      userAgent: req.get('User-Agent'),
    });

    // Intercept response to log completion
    const originalSend = res.send;
    res.send = function (data) {
      const duration = Date.now() - startTime;

      // Log response
      logger.info('Request completed', {
        correlationId,
        method: req.method,
        path: req.path,
        statusCode: res.statusCode,
        duration,
        userId: req.user?.sub,
        ip: req.ip,
      });

      // Add timing header
      res.setHeader('X-Response-Time', `${duration}ms`);

      // Call original send
      return originalSend.call(this, data);
    };

    next();
  };
}

/**
 * Default request logging middleware
 */
export const requestLoggingMiddleware = createRequestLoggingMiddleware();

export default requestLoggingMiddleware;
