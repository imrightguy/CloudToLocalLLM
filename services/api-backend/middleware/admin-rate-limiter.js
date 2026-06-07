/**
 * @fileoverview Admin-specific rate limiting middleware
 * Implements per-admin rate limiting with configurable limits for different endpoint types
 *
 * Features:
 * - 100 requests per minute per admin (default)
 * - 20 request burst allowance
 * - Stricter limits for expensive operations (reports, exports)
 * - Looser limits for read-only operations
 * - Health check exemptions
 * - Rate limit headers in responses
 * - 429 status code on limit exceeded
 *
 * Requirements: 15 (Security and Data Protection)
 */

import rateLimit, { ipKeyGenerator } from 'express-rate-limit';
import logger from '../logger.js';

/**
 * Rate limit configurations for different endpoint types
 */
const RATE_LIMIT_CONFIGS = {
  // Default admin rate limit: 100 requests per minute
  default: {
    windowMs: 60 * 1000, // 1 minute
    max: 100, // 100 requests per minute
    message: {
      error: 'Too many requests from this admin user',
      code: 'ADMIN_RATE_LIMIT_EXCEEDED',
      retryAfter: 60,
    },
    standardHeaders: true, // Return rate limit info in `RateLimit-*` headers
    legacyHeaders: false, // Disable `X-RateLimit-*` headers
    skipSuccessfulRequests: false,
    skipFailedRequests: false,
  },

  // Burst protection: 20 requests in 10 seconds
  burst: {
    windowMs: 10 * 1000, // 10 seconds
    max: 20, // 20 requests per 10 seconds
    message: {
      error: 'Too many requests in a short time',
      code: 'ADMIN_BURST_LIMIT_EXCEEDED',
      retryAfter: 10,
    },
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: false,
    skipFailedRequests: false,
  },

  // Expensive operations (reports, exports): 10 requests per minute
  expensive: {
    windowMs: 60 * 1000, // 1 minute
    max: 10, // 10 requests per minute
    message: {
      error: 'Too many expensive operations',
      code: 'ADMIN_EXPENSIVE_OPERATION_LIMIT_EXCEEDED',
      retryAfter: 60,
    },
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: false,
    skipFailedRequests: false,
  },

  // Read-only operations: 200 requests per minute
  readOnly: {
    windowMs: 60 * 1000, // 1 minute
    max: 200, // 200 requests per minute
    message: {
      error: 'Too many read requests',
      code: 'ADMIN_READ_LIMIT_EXCEEDED',
      retryAfter: 60,
    },
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: false,
    skipFailedRequests: false,
  },

  // Critical operations (data flush, user deletion): 5 requests per hour
  critical: {
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 5, // 5 requests per hour
    message: {
      error: 'Too many critical operations',
      code: 'ADMIN_CRITICAL_OPERATION_LIMIT_EXCEEDED',
      retryAfter: 3600,
    },
    standardHeaders: true,
    legacyHeaders: false,
    skipSuccessfulRequests: false,
    skipFailedRequests: false,
  },
};

/**
 * Key generator function to identify admin users
 * Uses admin user ID from JWT token
 */
const adminKeyGenerator = (req) => {
  // Use admin user ID from authenticated request
  const adminUserId = req.adminUser?.id || req.user?.sub || ipKeyGenerator(req);
  return `admin:${adminUserId}`;
};

/**
 * Handler for rate limit exceeded
 * Logs the event and returns standardized error response
 */
const rateLimitHandler = (req, res, next, options) => {
  const adminUserId = req.adminUser?.id || req.user?.sub || 'unknown';
  const endpoint = req.originalUrl;
  const method = req.method;

  logger.warn('Admin rate limit exceeded', {
    adminUserId,
    endpoint,
    method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    limitType: options.limitType || 'default',
  });

  // Return 429 with rate limit info
  res.status(429).json({
    error: options.message.error,
    code: options.message.code,
    retryAfter: options.message.retryAfter,
    timestamp: new Date().toISOString(),
  });
};

/**
 * Skip function for health check endpoints
 * Health checks should not be rate limited
 */
const skipHealthChecks = (req) => {
  return req.path === '/health' || req.path.endsWith('/health');
};

/**
 * Create rate limiter middleware with specific configuration
 * @param {string} type - Rate limit type (default, burst, expensive, readOnly, critical)
 * @param {Object} customConfig - Optional custom configuration to override defaults
 * @returns {Function} Express middleware
 */
export function createAdminRateLimiter(type = 'default', customConfig = {}) {
  const config = RATE_LIMIT_CONFIGS[type] || RATE_LIMIT_CONFIGS.default;

  const rateLimiterConfig = {
    ...config,
    ...customConfig,
    keyGenerator: adminKeyGenerator,
    handler: (req, res, next, options) => {
      rateLimitHandler(req, res, next, { ...options, limitType: type });
    },
    skip: skipHealthChecks,
  };

  const limiter = rateLimit(rateLimiterConfig);

  // Wrap the limiter to add logging
  return (req, res, next) => {
    // Log rate limit check (debug level)
    const adminUserId = req.adminUser?.id || req.user?.sub || 'unknown';
    logger.debug('Admin rate limit check', {
      adminUserId,
      endpoint: req.originalUrl,
      method: req.method,
      limitType: type,
    });

    limiter(req, res, next);
  };
}

/**
 * Default admin rate limiter (100 req/min)
 * Use for general admin endpoints
 */
export const adminRateLimiter = createAdminRateLimiter('default');

/**
 * Burst protection rate limiter (20 req/10sec)
 * Use in combination with default limiter for additional protection
 */
export const adminBurstLimiter = createAdminRateLimiter('burst');

/**
 * Expensive operations rate limiter (10 req/min)
 * Use for reports, exports, and other resource-intensive operations
 */
export const adminExpensiveLimiter = createAdminRateLimiter('expensive');

/**
 * Read-only operations rate limiter (200 req/min)
 * Use for GET endpoints that only read data
 */
export const adminReadOnlyLimiter = createAdminRateLimiter('readOnly');

/**
 * Critical operations rate limiter (5 req/hour)
 * Use for dangerous operations like data deletion
 */
export const adminCriticalLimiter = createAdminRateLimiter('critical');

/**
 * Combined rate limiter that applies multiple limits
 * Useful for applying both default and burst protection
 * @param {Array<Function>} limiters - Array of rate limiter middleware
 * @returns {Function} Express middleware
 */
export function combineRateLimiters(...limiters) {
  return (req, res, next) => {
    let index = 0;

    const runNext = (err) => {
      if (err) {
        return next(err);
      }
      if (index >= limiters.length) {
        return next();
      }

      const limiter = limiters[index++];
      limiter(req, res, runNext);
    };

    runNext();
  };
}

/**
 * Get rate limit statistics for monitoring
 * Note: express-rate-limit stores data in memory by default
 * For production, consider using a Redis store for distributed rate limiting
 * @returns {Object} Rate limit statistics
 */
export function getRateLimitStats() {
  return {
    message: 'Rate limit statistics are stored in memory',
    recommendation: 'Use Redis store for production deployments',
    configs: Object.keys(RATE_LIMIT_CONFIGS).map((type) => ({
      type,
      windowMs: RATE_LIMIT_CONFIGS[type].windowMs,
      max: RATE_LIMIT_CONFIGS[type].max,
    })),
  };
}

export default {
  createAdminRateLimiter,
  adminRateLimiter,
  adminBurstLimiter,
  adminExpensiveLimiter,
  adminReadOnlyLimiter,
  adminCriticalLimiter,
  combineRateLimiters,
  getRateLimitStats,
};
