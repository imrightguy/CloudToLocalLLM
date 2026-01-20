/* global jest */

/**


 * Webhook Rate Limiting Tests
 *
 * Tests for webhook rate limiting functionality including:
 * - Rate limit configuration management
 * - Rate limit enforcement
 * - Rate limit statistics
 * - Cache cleanup
 *
 * @fileoverview Webhook rate limiting unit tests
 * @version 1.0.0
 */

import { jest, describe, it, expect, beforeAll, afterAll, beforeEach } from "@jest/globals";
import { WebhookRateLimiterService } from '../../services/api-backend/services/webhook-rate-limiter.js';
import { getPool } from '../../services/api-backend/database/db-pool.js';

describe('WebhookRateLimiterService', () => {
  let service;
  let pool;
  let testWebhookId;
  let testUserId;

  beforeAll(async () => {
    // Initialize service
    service = new WebhookRateLimiterService();
    pool = getPool();

    // Create test data
    testWebhookId = 'test-webhook-' + Date.now();
    testUserId = 'test-user-' + Date.now();

    // Initialize service
    await service.initialize();
  });

  afterAll(async () => {
    // Clean up
    service.destroy();
  });

  beforeEach(async () => {
    // Clear cache before each test
    service.rateLimitCache.clear();
  });

  describe('getWebhookRateLimitConfig', () => {
    it('should return default config when no config exists', async () => {
      const config = await service.getWebhookRateLimitConfig(
        testWebhookId,
        testUserId,
      );

      expect(config).toBeDefined();
      expect(config.rate_limit_per_minute).toBe(60);
      expect(config.rate_limit_per_hour).toBe(1000);
      expect(config.rate_limit_per_day).toBe(10000);
      expect(config.is_enabled).toBe(true);
    });
  });

  describe('setWebhookRateLimitConfig', () => {
    it('should create new rate limit config', async () => {
      const config = {
        rate_limit_per_minute: 30,
        rate_limit_per_hour: 500,
        rate_limit_per_day: 5000,
        is_enabled: true,
      };

      const result = await service.setWebhookRateLimitConfig(
        testWebhookId,
        testUserId,
        config,
      );

      expect(result).toBeDefined();
      expect(result.rate_limit_per_minute).toBe(30);
      expect(result.rate_limit_per_hour).toBe(500);
      expect(result.rate_limit_per_day).toBe(5000);
    });

    it('should update existing rate limit config', async () => {
      const config1 = {
        rate_limit_per_minute: 30,
        rate_limit_per_hour: 500,
        rate_limit_per_day: 5000,
        is_enabled: true,
      };

      await service.setWebhookRateLimitConfig(
        testWebhookId,
        testUserId,
        config1,
      );

      const config2 = {
        rate_limit_per_minute: 50,
        rate_limit_per_hour: 800,
        rate_limit_per_day: 8000,
        is_enabled: true,
      };

      const result = await service.setWebhookRateLimitConfig(
        testWebhookId,
        testUserId,
        config2,
      );

      expect(result.rate_limit_per_minute).toBe(50);
      expect(result.rate_limit_per_hour).toBe(800);
      expect(result.rate_limit_per_day).toBe(8000);
    });

    it('should invalidate cache after update', async () => {
      const cacheKey = `${testWebhookId}:${testUserId}`;

      // Add to cache
      service.rateLimitCache.set(cacheKey, { deliveries: [Date.now()] });

      const config = {
        rate_limit_per_minute: 40,
        rate_limit_per_hour: 600,
        rate_limit_per_day: 6000,
        is_enabled: true,
      };

      await service.setWebhookRateLimitConfig(
        testWebhookId,
        testUserId,
        config,
      );

      // Cache should be cleared
      expect(service.rateLimitCache.has(cacheKey)).toBe(false);
    });
  });

  describe('checkRateLimit', () => {
    it('should allow request when under limit', async () => {
      const config = {
        rate_limit_per_minute: 10,
        rate_limit_per_hour: 100,
        rate_limit_per_day: 1000,
        is_enabled: true,
      };

      await service.setWebhookRateLimitConfig(
        testWebhookId,
        testUserId,
        config,
      );

      const result = await service.checkRateLimit(testWebhookId, testUserId);

      expect(result.allowed).toBe(true);
      expect(result.reason).toBe('allowed');
      expect(result.limits.per_minute.current).toBe(1);
      expect(result.limits.per_minute.max).toBe(10);
    });

    it('should block request when minute limit exceeded', async () => {
      const config = {
        rate_limit_per_minute: 2,
        rate_limit_per_hour: 100,
        rate_limit_per_day: 1000,
        is_enabled: true,
      };

      const webhookId = 'test-webhook-minute-' + Date.now();
      const userId = 'test-user-minute-' + Date.now();

      await service.setWebhookRateLimitConfig(webhookId, userId, config);

      // First request
      let result = await service.checkRateLimit(webhookId, userId);
      expect(result.allowed).toBe(true);

      // Second request
      result = await service.checkRateLimit(webhookId, userId);
      expect(result.allowed).toBe(true);

      // Third request - should be blocked
      result = await service.checkRateLimit(webhookId, userId);
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe('minute_limit_exceeded');
    });

    it('should block request when hour limit exceeded', async () => {
      const config = {
        rate_limit_per_minute: 2,
        rate_limit_per_hour: 2,
        rate_limit_per_day: 1000,
        is_enabled: true,
      };

      const webhookId = 'test-webhook-hour-' + Date.now();
      const userId = 'test-user-hour-' + Date.now();

      await service.setWebhookRateLimitConfig(webhookId, userId, config);

      // First request
      let result = await service.checkRateLimit(webhookId, userId);
      expect(result.allowed).toBe(true);

      // Second request
      result = await service.checkRateLimit(webhookId, userId);
      expect(result.allowed).toBe(true);

      // Third request - should be blocked
      result = await service.checkRateLimit(webhookId, userId);
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe('hour_limit_exceeded');
    });

    it('should allow request when rate limiting disabled', async () => {
      const config = {
        rate_limit_per_minute: 1,
        rate_limit_per_hour: 1,
        rate_limit_per_day: 1,
        is_enabled: false,
      };

      const webhookId = 'test-webhook-disabled-' + Date.now();
      const userId = 'test-user-disabled-' + Date.now();

      await service.setWebhookRateLimitConfig(webhookId, userId, config);

      // Multiple requests should all be allowed
      for (let i = 0; i < 5; i++) {
        const result = await service.checkRateLimit(webhookId, userId);
        expect(result.allowed).toBe(true);
        expect(result.reason).toBe('rate_limiting_disabled');
      }
    });
  });

  describe('validateRateLimitConfig', () => {
    it('should accept valid config', () => {
      const config = {
        rate_limit_per_minute: 60,
        rate_limit_per_hour: 1000,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).not.toThrow();
    });

    it('should reject negative rate limits', () => {
      const config = {
        rate_limit_per_minute: -1,
        rate_limit_per_hour: 1000,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).toThrow();
    });

    it('should reject zero rate limits', () => {
      const config = {
        rate_limit_per_minute: 0,
        rate_limit_per_hour: 1000,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).toThrow();
    });

    it('should reject non-integer rate limits', () => {
      const config = {
        rate_limit_per_minute: 60.5,
        rate_limit_per_hour: 1000,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).toThrow();
    });

    it('should enforce minute <= hour <= day ordering', () => {
      const config = {
        rate_limit_per_minute: 100,
        rate_limit_per_hour: 50,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).toThrow();
    });
  });

  describe('getRateLimitStats', () => {
    it('should return stats for webhook', async () => {
      const webhookId = 'test-webhook-stats-' + Date.now();
      const userId = 'test-user-stats-' + Date.now();

      const stats = await service.getRateLimitStats(webhookId, userId);

      expect(stats).toBeDefined();
      expect(stats.total_deliveries).toBe(0);
      expect(stats.successful_deliveries).toBe(0);
      expect(stats.failed_deliveries).toBe(0);
    });
  });

  describe('cleanupCache', () => {
    it('should remove expired cache entries', () => {
      const cacheKey1 = 'webhook1:user1';
      const cacheKey2 = 'webhook2:user2';

      // Add old entry (older than 1 hour)
      service.rateLimitCache.set(cacheKey1, {
        deliveries: [],
        lastUpdated: Date.now() - 61 * 60 * 1000,
      });

      // Add recent entry
      service.rateLimitCache.set(cacheKey2, {
        deliveries: [],
        lastUpdated: Date.now(),
      });

      service.cleanupCache();

      expect(service.rateLimitCache.has(cacheKey1)).toBe(false);
      expect(service.rateLimitCache.has(cacheKey2)).toBe(true);
    });
  });

  describe('recordDelivery', () => {
    it('should record delivery without throwing', async () => {
      const webhookId = 'test-webhook-record-' + Date.now();
      const userId = 'test-user-record-' + Date.now();
      const deliveryData = {
        delivery_id: 'delivery-' + Date.now(),
        status: 'delivered',
      };

      // Should not throw
      await service.recordDelivery(webhookId, userId, deliveryData);
    });
  });
});
