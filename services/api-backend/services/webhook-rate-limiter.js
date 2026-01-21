/**
 * Webhook Rate Limiter Service
 *
 * Manages webhook-specific rate limiting including:
 * - Per-webhook rate limiting
 * - Per-user webhook rate limiting
 * - Rate limit configuration and enforcement
 * - Rate limit metrics and tracking
 * - Validates rate limit rules
 *
 * @fileoverview Webhook rate limiting service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

/**
 * Webhook Rate Limiter Service
 * Manages rate limiting for webhook deliveries
 */
export class WebhookRateLimiterService {
  constructor() {
    this.pool = null;
    this.rateLimitCache = new Map(); // In-memory cache for rate limit tracking
    this.cleanupInterval = null;
  }

  /**
   * Initialize the rate limiter service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info(
        '[WebhookRateLimiter] Webhook rate limiter service initialized',
      );

      // Start cleanup interval for cache
      this.startCleanupInterval();
    } catch (error) {
      logger.error(
        '[WebhookRateLimiter] Failed to initialize rate limiter service',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Start cleanup interval for rate limit cache
   */
  startCleanupInterval() {
    // Clean up cache every 5 minutes
    this.cleanupInterval = setInterval(
      () => {
        this.cleanupCache();
      },
      5 * 60 * 1000,
    );
  }

  /**
   * Stop cleanup interval
   */
  stopCleanupInterval() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
  }

  /**
   * Clean up expired entries from rate limit cache
   */
  cleanupCache() {
    const now = Date.now();
    const expiredKeys = [];

    for (const [key, data] of this.rateLimitCache.entries()) {
      // Remove entries older than 1 hour
      if (now - data.lastUpdated > 60 * 60 * 1000) {
        expiredKeys.push(key);
      }
    }

    for (const key of expiredKeys) {
      this.rateLimitCache.delete(key);
    }

    if (expiredKeys.length > 0) {
      logger.debug('[WebhookRateLimiter] Cleaned up cache entries', {
        count: expiredKeys.length,
      });
    }
  }

  /**
   * Get or create rate limit configuration for a webhook
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Rate limit configuration
   */
  async getWebhookRateLimitConfig(webhookId, userId) {
    try {
      const client = await this.pool.connect();
      try {
        const result = await client.query(
          `SELECT 
             id, user_id, rate_limit_per_minute, rate_limit_per_hour, 
             rate_limit_per_day, is_enabled, created_at, updated_at
           FROM webhook_rate_limits
           WHERE webhook_id = $1 AND user_id = $2`,
          [webhookId, userId],
        );

        if (result.rows.length > 0) {
          return result.rows[0];
        }

        // Return default configuration if not found
        return {
          webhook_id: webhookId,
          user_id: userId,
          rate_limit_per_minute: 60, // Default: 60 deliveries per minute
          rate_limit_per_hour: 1000, // Default: 1000 deliveries per hour
          rate_limit_per_day: 10000, // Default: 10000 deliveries per day
          is_enabled: true,
        };
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('[WebhookRateLimiter] Failed to get rate limit config', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Set rate limit configuration for a webhook
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @param {Object} config - Rate limit configuration
   * @returns {Promise<Object>} Updated configuration
   */
  async setWebhookRateLimitConfig(webhookId, userId, config) {
    try {
      // Validate configuration
      this.validateRateLimitConfig(config);

      const client = await this.pool.connect();
      try {
        await client.query('BEGIN');

        // Check if config exists
        const existing = await client.query(
          'SELECT id FROM webhook_rate_limits WHERE webhook_id = $1 AND user_id = $2',
          [webhookId, userId],
        );

        let result;
        if (existing.rows.length > 0) {
          // Update existing config
          result = await client.query(
            `UPDATE webhook_rate_limits
             SET rate_limit_per_minute = $1,
                 rate_limit_per_hour = $2,
                 rate_limit_per_day = $3,
                 is_enabled = $4,
                 updated_at = NOW()
             WHERE webhook_id = $5 AND user_id = $6
             RETURNING *`,
            [
              config.rate_limit_per_minute,
              config.rate_limit_per_hour,
              config.rate_limit_per_day,
              config.is_enabled !== false,
              webhookId,
              userId,
            ],
          );
        } else {
          // Create new config
          result = await client.query(
            `INSERT INTO webhook_rate_limits 
             (webhook_id, user_id, rate_limit_per_minute, rate_limit_per_hour, rate_limit_per_day, is_enabled)
             VALUES ($1, $2, $3, $4, $5, $6)
             RETURNING *`,
            [
              webhookId,
              userId,
              config.rate_limit_per_minute,
              config.rate_limit_per_hour,
              config.rate_limit_per_day,
              config.is_enabled !== false,
            ],
          );
        }

        await client.query('COMMIT');

        // Invalidate cache
        this.rateLimitCache.delete(`${webhookId}:${userId}`);

        logger.info('[WebhookRateLimiter] Rate limit config updated', {
          webhookId,
          userId,
          config: result.rows[0],
        });

        return result.rows[0];
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('[WebhookRateLimiter] Failed to set rate limit config', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Check if webhook delivery is allowed based on rate limits
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Rate limit check result
   */
  async checkRateLimit(webhookId, userId) {
    try {
      const config = await this.getWebhookRateLimitConfig(webhookId, userId);

      if (!config.is_enabled) {
        return {
          allowed: true,
          reason: 'rate_limiting_disabled',
          limits: {
            per_minute: { current: 0, max: config.rate_limit_per_minute },
            per_hour: { current: 0, max: config.rate_limit_per_hour },
            per_day: { current: 0, max: config.rate_limit_per_day },
          },
        };
      }

      const cacheKey = `${webhookId}:${userId}`;
      const now = Date.now();
      const oneMinuteAgo = now - 60 * 1000;
      const oneHourAgo = now - 60 * 60 * 1000;
      const oneDayAgo = now - 24 * 60 * 60 * 1000;

      // Get or initialize cache entry
      let cacheEntry = this.rateLimitCache.get(cacheKey);
      if (!cacheEntry) {
        cacheEntry = {
          deliveries: [],
          lastUpdated: now,
        };
        this.rateLimitCache.set(cacheKey, cacheEntry);
      }

      // Clean up old entries from cache
      cacheEntry.deliveries = cacheEntry.deliveries.filter(
        (timestamp) => timestamp > oneDayAgo,
      );

      // Count deliveries in each window
      const minuteCount = cacheEntry.deliveries.filter(
        (timestamp) => timestamp > oneMinuteAgo,
      ).length;
      const hourCount = cacheEntry.deliveries.filter(
        (timestamp) => timestamp > oneHourAgo,
      ).length;
      const dayCount = cacheEntry.deliveries.length;

      // Check limits
      const minuteExceeded = minuteCount >= config.rate_limit_per_minute;
      const hourExceeded = hourCount >= config.rate_limit_per_hour;
      const dayExceeded = dayCount >= config.rate_limit_per_day;

      const allowed = !minuteExceeded && !hourExceeded && !dayExceeded;

      if (allowed) {
        // Add current delivery to cache
        cacheEntry.deliveries.push(now);
        cacheEntry.lastUpdated = now;
      }

      return {
        allowed,
        reason: minuteExceeded
          ? 'minute_limit_exceeded'
          : hourExceeded
            ? 'hour_limit_exceeded'
            : dayExceeded
              ? 'day_limit_exceeded'
              : 'allowed',
        limits: {
          per_minute: {
            current: minuteCount,
            max: config.rate_limit_per_minute,
          },
          per_hour: { current: hourCount, max: config.rate_limit_per_hour },
          per_day: { current: dayCount, max: config.rate_limit_per_day },
        },
      };
    } catch (error) {
      logger.error('[WebhookRateLimiter] Failed to check rate limit', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Record a webhook delivery for rate limit tracking
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @param {Object} deliveryData - Delivery data
   * @returns {Promise<void>}
   */
  async recordDelivery(webhookId, userId, deliveryData) {
    try {
      const client = await this.pool.connect();
      try {
        await client.query(
          `INSERT INTO webhook_rate_limit_tracking 
           (webhook_id, user_id, delivery_id, status, created_at)
           VALUES ($1, $2, $3, $4, NOW())`,
          [webhookId, userId, deliveryData.delivery_id, deliveryData.status],
        );
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('[WebhookRateLimiter] Failed to record delivery', {
        webhookId,
        userId,
        error: error.message,
      });
      // Don't throw - this is non-critical
    }
  }

  /**
   * Get rate limit statistics for a webhook
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Rate limit statistics
   */
  async getRateLimitStats(webhookId, userId) {
    try {
      const client = await this.pool.connect();
      try {
        const result = await client.query(
          `SELECT 
             COUNT(*) as total_deliveries,
             COUNT(CASE WHEN status = 'delivered' THEN 1 END) as successful_deliveries,
             COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_deliveries,
             COUNT(CASE WHEN created_at > NOW() - INTERVAL '1 minute' THEN 1 END) as minute_count,
             COUNT(CASE WHEN created_at > NOW() - INTERVAL '1 hour' THEN 1 END) as hour_count,
             COUNT(CASE WHEN created_at > NOW() - INTERVAL '1 day' THEN 1 END) as day_count
           FROM webhook_rate_limit_tracking
           WHERE webhook_id = $1 AND user_id = $2`,
          [webhookId, userId],
        );

        return (
          result.rows[0] || {
            total_deliveries: 0,
            successful_deliveries: 0,
            failed_deliveries: 0,
            minute_count: 0,
            hour_count: 0,
            day_count: 0,
          }
        );
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('[WebhookRateLimiter] Failed to get rate limit stats', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Validate rate limit configuration
   * @param {Object} config - Configuration to validate
   * @throws {Error} If configuration is invalid
   */
  validateRateLimitConfig(config) {
    if (config.rate_limit_per_minute !== undefined) {
      if (
        !Number.isInteger(config.rate_limit_per_minute) ||
        config.rate_limit_per_minute < 1
      ) {
        throw new Error('rate_limit_per_minute must be a positive integer');
      }
    }

    if (config.rate_limit_per_hour !== undefined) {
      if (
        !Number.isInteger(config.rate_limit_per_hour) ||
        config.rate_limit_per_hour < 1
      ) {
        throw new Error('rate_limit_per_hour must be a positive integer');
      }
    }

    if (config.rate_limit_per_day !== undefined) {
      if (
        !Number.isInteger(config.rate_limit_per_day) ||
        config.rate_limit_per_day < 1
      ) {
        throw new Error('rate_limit_per_day must be a positive integer');
      }
    }

    // Ensure per_minute <= per_hour <= per_day
    if (
      config.rate_limit_per_minute &&
      config.rate_limit_per_hour &&
      config.rate_limit_per_minute > config.rate_limit_per_hour
    ) {
      throw new Error('rate_limit_per_minute must be <= rate_limit_per_hour');
    }

    if (
      config.rate_limit_per_hour &&
      config.rate_limit_per_day &&
      config.rate_limit_per_hour > config.rate_limit_per_day
    ) {
      throw new Error('rate_limit_per_hour must be <= rate_limit_per_day');
    }
  }

  /**
   * Destroy the service and clean up resources
   */
  destroy() {
    this.stopCleanupInterval();
    this.rateLimitCache.clear();
  }
}

// Export singleton instance
export const webhookRateLimiterService = new WebhookRateLimiterService();
