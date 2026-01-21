/**
 * Webhook Rate Limiting Middleware
 *
 * Enforces rate limiting for webhook deliveries
 * Checks rate limits before allowing webhook delivery
 * Returns 429 (Too Many Requests) when limits are exceeded
 *
 * @fileoverview Webhook rate limiting middleware
 * @version 1.0.0
 */

import logger from '../logger.js';
import { webhookRateLimiterService } from '../services/webhook-rate-limiter.js';

/**
 * Webhook rate limiting middleware
 * Checks if webhook delivery is allowed based on configured rate limits
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 * @returns {void}
 */
export async function webhookRateLimiterMiddleware(req, res, next) {
  try {
    // Extract webhook ID and user ID from request
    const webhookId = req.params.webhookId || req.body?.webhook_id;
    const userId = req.user?.id || req.body?.user_id;

    // Skip rate limiting if webhook ID or user ID is missing
    if (!webhookId || !userId) {
      return next();
    }

    // Check rate limit
    const rateLimitResult = await webhookRateLimiterService.checkRateLimit(
      webhookId,
      userId,
    );

    // Attach rate limit info to request
    req.rateLimit = rateLimitResult;

    // Add rate limit headers to response
    res.set('X-RateLimit-Limit-Minute', rateLimitResult.limits.per_minute.max);
    res.set(
      'X-RateLimit-Remaining-Minute',
      Math.max(
        0,
        rateLimitResult.limits.per_minute.max -
          rateLimitResult.limits.per_minute.current,
      ),
    );
    res.set('X-RateLimit-Limit-Hour', rateLimitResult.limits.per_hour.max);
    res.set(
      'X-RateLimit-Remaining-Hour',
      Math.max(
        0,
        rateLimitResult.limits.per_hour.max -
          rateLimitResult.limits.per_hour.current,
      ),
    );
    res.set('X-RateLimit-Limit-Day', rateLimitResult.limits.per_day.max);
    res.set(
      'X-RateLimit-Remaining-Day',
      Math.max(
        0,
        rateLimitResult.limits.per_day.max -
          rateLimitResult.limits.per_day.current,
      ),
    );

    // If rate limit exceeded, return 429
    if (!rateLimitResult.allowed) {
      logger.warn('[WebhookRateLimiter] Rate limit exceeded', {
        webhookId,
        userId,
        reason: rateLimitResult.reason,
        limits: rateLimitResult.limits,
      });

      return res.status(429).json({
        error: {
          code: 'WEBHOOK_RATE_LIMIT_EXCEEDED',
          message: 'Webhook rate limit exceeded',
          reason: rateLimitResult.reason,
          limits: rateLimitResult.limits,
        },
      });
    }

    next();
  } catch (error) {
    logger.error('[WebhookRateLimiter] Error in rate limiting middleware', {
      error: error.message,
      stack: error.stack,
    });

    // Don't block request on error - log and continue
    next();
  }
}

/**
 * Webhook rate limiting configuration middleware
 * Allows setting rate limit configuration for a webhook
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 * @returns {void}
 */
export async function webhookRateLimitConfigMiddleware(req, res, next) {
  try {
    // Extract configuration from request body
    const config = req.body?.rate_limit_config;

    if (!config) {
      return next();
    }

    // Validate configuration
    webhookRateLimiterService.validateRateLimitConfig(config);

    // Attach validated config to request
    req.validatedRateLimitConfig = config;

    next();
  } catch (error) {
    logger.error('[WebhookRateLimiter] Invalid rate limit configuration', {
      error: error.message,
    });

    return res.status(400).json({
      error: {
        code: 'INVALID_RATE_LIMIT_CONFIG',
        message: 'Invalid rate limit configuration',
        details: error.message,
      },
    });
  }
}
