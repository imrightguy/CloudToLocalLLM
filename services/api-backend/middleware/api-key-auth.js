/**
 * API Key Authentication Middleware
 *
 * Validates API keys for service-to-service communication
 * and attaches key metadata to request.
 *
 * Requirements: 2.8
 * - Support API key authentication for service-to-service communication
 */

import logger from '../logger.js';
import { validateApiKey } from '../services/api-key-service.js';

/**
 * API Key Authentication Middleware
 * Validates API key from Authorization header or X-API-Key header
 *
 * Supports two formats:
 * 1. Authorization: Bearer <api-key>
 * 2. X-API-Key: <api-key>
 */
export async function authenticateApiKey(req, res, next) {
  try {
    let apiKey = null;

    // Try to get API key from Authorization header
    const authHeader = req.headers['authorization'];
    if (authHeader && authHeader.startsWith('Bearer ')) {
      apiKey = authHeader.substring(7);
    }

    // Fall back to X-API-Key header
    if (!apiKey) {
      apiKey = req.headers['x-api-key'];
    }

    if (!apiKey) {
      logger.warn('[APIKeyAuth] Missing API key', {
        ip: req.ip,
        path: req.path,
      });

      return res.status(401).json({
        error: 'API key required',
        code: 'MISSING_API_KEY',
        message: 'Provide API key via Authorization header or X-API-Key header',
      });
    }

    // Validate API key
    const keyMetadata = await validateApiKey(apiKey);

    if (!keyMetadata) {
      logger.warn('[APIKeyAuth] Invalid or expired API key', {
        // keyPrefix removed for security
        ip: req.ip,
        path: req.path,
      });

      return res.status(401).json({
        error: 'Invalid or expired API key',
        code: 'INVALID_API_KEY',
      });
    }

    // Attach key metadata to request
    req.apiKey = keyMetadata;
    req.userId = keyMetadata.userId;
    req.isServiceAuth = true;

    logger.debug('[APIKeyAuth] API key authenticated', {
      keyId: keyMetadata.id,
      userId: keyMetadata.userId,
      scopes: keyMetadata.scopes,
    });

    next();
  } catch (error) {
    logger.error('[APIKeyAuth] API key authentication failed', {
      error: error.message,
      ip: req.ip,
    });

    res.status(500).json({
      error: 'API key authentication failed',
      code: 'API_KEY_AUTH_ERROR',
    });
  }
}

/**
 * Optional API Key Authentication Middleware
 * Attempts to authenticate with API key but doesn't require it
 */
export async function optionalApiKeyAuth(req, res, next) {
  try {
    let apiKey = null;

    // Try to get API key from Authorization header
    const authHeader = req.headers['authorization'];
    if (authHeader && authHeader.startsWith('Bearer ')) {
      apiKey = authHeader.substring(7);
    }

    // Fall back to X-API-Key header
    if (!apiKey) {
      apiKey = req.headers['x-api-key'];
    }

    if (apiKey) {
      // Validate API key
      const keyMetadata = await validateApiKey(apiKey);

      if (keyMetadata) {
        // Attach key metadata to request
        req.apiKey = keyMetadata;
        req.userId = keyMetadata.userId;
        req.isServiceAuth = true;

        logger.debug('[APIKeyAuth] Optional API key authenticated', {
          keyId: keyMetadata.id,
          userId: keyMetadata.userId,
        });
      }
    }

    next();
  } catch (error) {
    logger.error('[APIKeyAuth] Optional API key authentication failed', {
      error: error.message,
    });
    // Continue without authentication on error
    next();
  }
}

/**
 * Check if request has required scope
 * @param {string|string[]} requiredScopes - Required scope(s)
 * @returns {Function} Express middleware
 */
export function requireApiKeyScope(requiredScopes) {
  const scopes = Array.isArray(requiredScopes)
    ? requiredScopes
    : [requiredScopes];

  return (req, res, next) => {
    if (!req.apiKey) {
      return res.status(401).json({
        error: 'API key authentication required',
        code: 'API_KEY_REQUIRED',
      });
    }

    const keyScopes = req.apiKey.scopes || [];
    const hasRequiredScope = scopes.some((scope) => keyScopes.includes(scope));

    if (!hasRequiredScope) {
      logger.warn('[APIKeyAuth] Insufficient API key scopes', {
        keyId: req.apiKey.id,
        requiredScopes: scopes,
        // keyScopes, // Redacted
      });

      return res.status(403).json({
        error: 'Insufficient API key scopes',
        code: 'INSUFFICIENT_SCOPES',
        requiredScopes: scopes,
      });
    }

    next();
  };
}

/**
 * Rate limit by API key
 * @param {Object} options - Rate limiting options
 * @returns {Function} Express middleware
 */
export function apiKeyAuth(_options = {}) {
  const keyRequests = new Map();

  return (req, res, next) => {
    if (!req.apiKey) {
      return next();
    }

    const keyId = req.apiKey.id;
    const rateLimit = req.apiKey.rateLimit || 1000;
    const windowMs = 60 * 1000; // 1 minute
    const now = Date.now();

    // Clean up old entries
    for (const [key, data] of keyRequests.entries()) {
      if (now - data.windowStart > windowMs) {
        keyRequests.delete(key);
      }
    }

    // Get or create key request data
    let keyData = keyRequests.get(keyId);
    if (!keyData || now - keyData.windowStart > windowMs) {
      keyData = { count: 0, windowStart: now };
      keyRequests.set(keyId, keyData);
    }

    keyData.count++;

    // Add rate limit headers
    res.set('X-RateLimit-Limit', rateLimit.toString());
    res.set(
      'X-RateLimit-Remaining',
      Math.max(0, rateLimit - keyData.count).toString(),
    );
    res.set('X-RateLimit-Reset', (keyData.windowStart + windowMs).toString());

    if (keyData.count > rateLimit) {
      logger.warn('[APIKeyAuth] API key rate limit exceeded', {
        keyId,
        limit: rateLimit,
        // requests: keyData.count, // Potentially sensitive volume data
      });

      return res.status(429).json({
        error: 'API key rate limit exceeded',
        code: 'API_KEY_RATE_LIMIT_EXCEEDED',
        retryAfter: Math.ceil((keyData.windowStart + windowMs - now) / 1000),
      });
    }

    next();
  };
}
