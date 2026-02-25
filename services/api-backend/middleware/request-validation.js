/**
 * Request Validation Middleware for CloudToLocalLLM API Backend
 *
 * Implements request format validation and basic security checks
 * before processing by route handlers.
 *
 * @fileoverview Request validation middleware
 * @version 1.0.0
 */

import logger from '../logger.js';

/**
 * Create request validation middleware
 * @returns {Function} Express middleware function
 */
export function createRequestValidationMiddleware() {
  return (req, res, next) => {
    // Skip validation for GET and HEAD requests
    if (
      req.method === 'GET' ||
      req.method === 'HEAD' ||
      req.method === 'OPTIONS'
    ) {
      return next();
    }

    // Validate Content-Type for POST, PUT, PATCH requests
    const contentType = req.get('Content-Type');
    if (req.method !== 'DELETE' && !contentType) {
      logger.warn('Missing Content-Type header', {
        correlationId: req.correlationId,
        method: req.method,
        path: req.path,
        userId: req.user?.sub,
      });

      return res.status(400).json({
        error: 'Bad request',
        code: 'MISSING_CONTENT_TYPE',
        message: 'Content-Type header is required',
        correlationId: req.correlationId,
      });
    }

    // Validate JSON content type if body is present
    if (
      contentType &&
      !contentType.includes('application/json') &&
      !contentType.includes('application/x-www-form-urlencoded') &&
      !contentType.includes('multipart/form-data')
    ) {
      logger.warn('Invalid Content-Type', {
        correlationId: req.correlationId,
        method: req.method,
        path: req.path,
        contentType,
        userId: req.user?.sub,
      });

      return res.status(415).json({
        error: 'Unsupported media type',
        code: 'UNSUPPORTED_MEDIA_TYPE',
        message:
          'Content-Type must be application/json or application/x-www-form-urlencoded',
        correlationId: req.correlationId,
      });
    }

    // Validate request body size (should be handled by express.json limit, but double-check)
    const contentLength = req.get('Content-Length');
    if (contentLength && parseInt(contentLength) > 10 * 1024 * 1024) {
      logger.warn('Request body too large', {
        correlationId: req.correlationId,
        method: req.method,
        path: req.path,
        contentLength,
        userId: req.user?.sub,
      });

      return res.status(413).json({
        error: 'Payload too large',
        code: 'PAYLOAD_TOO_LARGE',
        message: 'Request body exceeds maximum size of 10MB',
        correlationId: req.correlationId,
      });
    }

    // Validate Authorization header format if present
    const authHeader = req.get('Authorization');
    if (authHeader && !authHeader.startsWith('Bearer ')) {
      logger.warn('Invalid Authorization header format', {
        correlationId: req.correlationId,
        method: req.method,
        path: req.path,
        userId: req.user?.sub,
      });

      return res.status(400).json({
        error: 'Bad request',
        code: 'INVALID_AUTH_HEADER',
        message: 'Authorization header must use Bearer scheme',
        correlationId: req.correlationId,
      });
    }

    next();
  };
}

/**
 * Default request validation middleware
 */
export const requestValidationMiddleware = createRequestValidationMiddleware();

export default requestValidationMiddleware;
