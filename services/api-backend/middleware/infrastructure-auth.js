/**
 * Infrastructure Authentication Middleware
 *
 * Validates API key authentication for infrastructure management endpoints.
 * These endpoints are used for deployment automation and system management.
 *
 * Authentication: X-Infrastructure-Key header
 * Environment: INFRASTRUCTURE_API_KEY
 *
 * @fileoverview Infrastructure API authentication middleware
 * @version 1.0.0
 */

import logger from '../logger.js';

/**
 * Middleware to authenticate infrastructure management requests
 *
 * Validates the X-Infrastructure-Key header against the
 * INFRASTRUCTURE_API_KEY environment variable.
 *
 * @param {import('express').Request} req - Express request object
 * @param {import('express').Response} res - Express response object
 * @param {import('express').NextFunction} next - Express next function
 * @returns {void}
 */
export function authenticateInfrastructure(req, res, next) {
  const apiKey = req.headers['x-infrastructure-key'];
  const expectedKey = process.env.INFRASTRUCTURE_API_KEY;

  // Check if infrastructure API key is configured
  if (!expectedKey) {
    logger.error(
      '[InfraAuth] INFRASTRUCTURE_API_KEY not configured in environment',
    );
    return res.status(503).json({
      error: 'Service unavailable',
      code: 'INFRA_NOT_CONFIGURED',
      message: 'Infrastructure API is not configured',
    });
  }

  // Validate API key presence
  if (!apiKey) {
    logger.warn('[InfraAuth] Missing X-Infrastructure-Key header', {
      ip: req.ip,
      path: req.path,
    });
    return res.status(401).json({
      error: 'Unauthorized',
      code: 'MISSING_API_KEY',
      message: 'X-Infrastructure-Key header is required',
    });
  }

  // Validate API key value
  if (apiKey !== expectedKey) {
    logger.warn('[InfraAuth] Invalid infrastructure API key', {
      ip: req.ip,
      path: req.path,
    });
    return res.status(401).json({
      error: 'Unauthorized',
      code: 'INVALID_API_KEY',
      message: 'Invalid infrastructure API key',
    });
  }

  // Log successful authentication
  logger.debug('[InfraAuth] Infrastructure request authenticated', {
    ip: req.ip,
    path: req.path,
    method: req.method,
  });

  next();
}

/**
 * Middleware to optionally authenticate infrastructure requests
 *
 * If the X-Infrastructure-Key header is present, validates it.
 * If not present, continues without authentication (for internal calls).
 *
 * @param {import('express').Request} req - Express request object
 * @param {import('express').Response} res - Express response object
 * @param {import('express').NextFunction} next - Express next function
 * @returns {void}
 */
export function optionalInfrastructureAuth(req, res, next) {
  const apiKey = req.headers['x-infrastructure-key'];

  // If no API key provided, skip authentication
  if (!apiKey) {
    req.infraAuthenticated = false;
    return next();
  }

  // If API key provided, validate it
  const expectedKey = process.env.INFRASTRUCTURE_API_KEY;

  if (apiKey === expectedKey) {
    req.infraAuthenticated = true;
    logger.debug('[InfraAuth] Optional infrastructure auth successful', {
      ip: req.ip,
      path: req.path,
    });
    return next();
  }

  // Invalid key
  logger.warn('[InfraAuth] Invalid infrastructure API key (optional auth)', {
    ip: req.ip,
    path: req.path,
  });

  return res.status(401).json({
    error: 'Unauthorized',
    code: 'INVALID_API_KEY',
    message: 'Invalid infrastructure API key',
  });
}

export default { authenticateInfrastructure, optionalInfrastructureAuth };
