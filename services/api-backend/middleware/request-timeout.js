/**
 * Request Timeout Middleware for CloudToLocalLLM API Backend
 *
 * Implements configurable request timeout handling with graceful error responses.
 * Prevents long-running requests from consuming resources indefinitely.
 *
 * @fileoverview Request timeout middleware
 * @version 1.0.0
 */

import logger from '../logger.js';

/**
 * Create request timeout middleware
 * @param {number} timeoutMs - Timeout in milliseconds (default: 30000ms = 30 seconds)
 * @returns {Function} Express middleware function
 */
export function createRequestTimeoutMiddleware(timeoutMs = 30000) {
  return (req, res, next) => {
    // Skip timeout for WebSocket upgrades
    if (req.upgrade) {
      return next();
    }

    // Set timeout on the response socket
    const timeout = setTimeout(() => {
      if (!res.headersSent) {
        logger.warn('Request timeout', {
          correlationId: req.correlationId,
          method: req.method,
          path: req.path,
          userId: req.user?.sub,
          timeoutMs,
        });

        res.status(408).json({
          error: 'Request timeout',
          code: 'REQUEST_TIMEOUT',
          message: `Request exceeded ${timeoutMs}ms timeout`,
          correlationId: req.correlationId,
        });
      }
    }, timeoutMs);

    // Clear timeout when response is sent
    res.on('finish', () => {
      clearTimeout(timeout);
    });

    res.on('close', () => {
      clearTimeout(timeout);
    });

    next();
  };
}

/**
 * Default request timeout middleware (30 seconds)
 */
export const requestTimeoutMiddleware = createRequestTimeoutMiddleware(30000);

export default requestTimeoutMiddleware;
