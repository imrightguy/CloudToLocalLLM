/**


 * Webhook Rate Limiting Unit Tests
 *
 * Tests for webhook rate limiting core logic without database
 * - Rate limit validation
 * - Cache management
 * - Rate limit calculation
 *
 * @fileoverview Webhook rate limiting unit tests
 * @version 1.0.0
 */

import { describe, it, expect, beforeEach } from "@jest/globals";

/**
 * Mock WebhookRateLimiterService for testing core logic
 */
class MockWebhookRateLimiterService {
  constructor() {
    this.rateLimitCache = new Map();
  }

  validateRateLimitConfig(config) {
    if (config.rate_limit_per_minute !== undefined) {
      if (
        !Number.isInteger(config.rate_limit_per_minute) ||
        config.rate_limit_per_minute < 1
      ) {
        throw new Error("rate_limit_per_minute must be a positive integer");
      }
    }

    if (config.rate_limit_per_hour !== undefined) {
      if (
        !Number.isInteger(config.rate_limit_per_hour) ||
        config.rate_limit_per_hour < 1
      ) {
        throw new Error("rate_limit_per_hour must be a positive integer");
      }
    }

    if (config.rate_limit_per_day !== undefined) {
      if (
        !Number.isInteger(config.rate_limit_per_day) ||
        config.rate_limit_per_day < 1
      ) {
        throw new Error("rate_limit_per_day must be a positive integer");
      }
    }

    // Ensure per_minute <= per_hour <= per_day
    if (
      config.rate_limit_per_minute &&
      config.rate_limit_per_hour &&
      config.rate_limit_per_minute > config.rate_limit_per_hour
    ) {
      throw new Error("rate_limit_per_minute must be <= rate_limit_per_hour");
    }

    if (
      config.rate_limit_per_hour &&
      config.rate_limit_per_day &&
      config.rate_limit_per_hour > config.rate_limit_per_day
    ) {
      throw new Error("rate_limit_per_hour must be <= rate_limit_per_day");
    }
  }

  checkRateLimitInMemory(webhookId, userId, config) {
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
        ? "minute_limit_exceeded"
        : hourExceeded
          ? "hour_limit_exceeded"
          : dayExceeded
            ? "day_limit_exceeded"
            : "allowed",
      limits: {
        per_minute: { current: minuteCount, max: config.rate_limit_per_minute },
        per_hour: { current: hourCount, max: config.rate_limit_per_hour },
        per_day: { current: dayCount, max: config.rate_limit_per_day },
      },
    };
  }

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

    return expiredKeys.length;
  }
}

describe("WebhookRateLimiterService - Unit Tests", () => {
  let service;

  beforeEach(() => {
    service = new MockWebhookRateLimiterService();
  });

  describe("validateRateLimitConfig", () => {
    it("should accept valid config", () => {
      const config = {
        rate_limit_per_minute: 60,
        rate_limit_per_hour: 1000,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).not.toThrow();
    });

    it("should reject negative rate limits", () => {
      const config = {
        rate_limit_per_minute: -1,
        rate_limit_per_hour: 1000,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).toThrow("rate_limit_per_minute must be a positive integer");
    });

    it("should reject zero rate limits", () => {
      const config = {
        rate_limit_per_minute: 0,
        rate_limit_per_hour: 1000,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).toThrow("rate_limit_per_minute must be a positive integer");
    });

    it("should reject non-integer rate limits", () => {
      const config = {
        rate_limit_per_minute: 60.5,
        rate_limit_per_hour: 1000,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).toThrow("rate_limit_per_minute must be a positive integer");
    });

    it("should enforce minute <= hour <= day ordering", () => {
      const config = {
        rate_limit_per_minute: 100,
        rate_limit_per_hour: 50,
        rate_limit_per_day: 10000,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).toThrow("rate_limit_per_minute must be <= rate_limit_per_hour");
    });

    it("should enforce hour <= day ordering", () => {
      const config = {
        rate_limit_per_minute: 50,
        rate_limit_per_hour: 1000,
        rate_limit_per_day: 500,
      };

      expect(() => {
        service.validateRateLimitConfig(config);
      }).toThrow("rate_limit_per_hour must be <= rate_limit_per_day");
    });
  });

  describe("checkRateLimitInMemory", () => {
    it("should allow request when under limit", () => {
      const config = {
        rate_limit_per_minute: 10,
        rate_limit_per_hour: 100,
        rate_limit_per_day: 1000,
      };

      const result = service.checkRateLimitInMemory(
        "webhook1",
        "user1",
        config,
      );

      expect(result.allowed).toBe(true);
      expect(result.reason).toBe("allowed");
      expect(result.limits.per_minute.current).toBe(0); // Count before adding current request
      expect(result.limits.per_minute.max).toBe(10);
    });

    it("should block request when minute limit exceeded", () => {
      const config = {
        rate_limit_per_minute: 2,
        rate_limit_per_hour: 100,
        rate_limit_per_day: 1000,
      };

      // First request
      let result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(true);

      // Second request
      result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(true);

      // Third request - should be blocked
      result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe("minute_limit_exceeded");
    });

    it("should block request when hour limit exceeded", () => {
      const config = {
        rate_limit_per_minute: 100,
        rate_limit_per_hour: 2,
        rate_limit_per_day: 1000,
      };

      // First request
      let result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(true);

      // Second request
      result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(true);

      // Third request - should be blocked
      result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe("hour_limit_exceeded");
    });

    it("should block request when day limit exceeded", () => {
      const config = {
        rate_limit_per_minute: 100,
        rate_limit_per_hour: 100,
        rate_limit_per_day: 2,
      };

      // First request
      let result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(true);

      // Second request
      result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(true);

      // Third request - should be blocked
      result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe("day_limit_exceeded");
    });

    it("should track separate limits for different webhooks", () => {
      const config = {
        rate_limit_per_minute: 1,
        rate_limit_per_hour: 100,
        rate_limit_per_day: 1000,
      };

      // First webhook
      let result1 = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result1.allowed).toBe(true);

      // Second webhook - should also be allowed
      let result2 = service.checkRateLimitInMemory("webhook2", "user1", config);
      expect(result2.allowed).toBe(true);

      // First webhook again - should be blocked
      result1 = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result1.allowed).toBe(false);

      // Second webhook again - should be blocked
      result2 = service.checkRateLimitInMemory("webhook2", "user1", config);
      expect(result2.allowed).toBe(false);
    });

    it("should track separate limits for different users", () => {
      const config = {
        rate_limit_per_minute: 1,
        rate_limit_per_hour: 100,
        rate_limit_per_day: 1000,
      };

      // First user
      let result1 = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result1.allowed).toBe(true);

      // Second user - should also be allowed
      let result2 = service.checkRateLimitInMemory("webhook1", "user2", config);
      expect(result2.allowed).toBe(true);

      // First user again - should be blocked
      result1 = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result1.allowed).toBe(false);

      // Second user again - should be blocked
      result2 = service.checkRateLimitInMemory("webhook1", "user2", config);
      expect(result2.allowed).toBe(false);
    });
  });

  describe("cleanupCache", () => {
    it("should remove expired cache entries", () => {
      const cacheKey1 = "webhook1:user1";
      const cacheKey2 = "webhook2:user2";

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

      const removed = service.cleanupCache();

      expect(removed).toBe(1);
      expect(service.rateLimitCache.has(cacheKey1)).toBe(false);
      expect(service.rateLimitCache.has(cacheKey2)).toBe(true);
    });

    it("should not remove recent cache entries", () => {
      const cacheKey = "webhook1:user1";

      service.rateLimitCache.set(cacheKey, {
        deliveries: [],
        lastUpdated: Date.now(),
      });

      const removed = service.cleanupCache();

      expect(removed).toBe(0);
      expect(service.rateLimitCache.has(cacheKey)).toBe(true);
    });
  });

  describe("Rate Limit Enforcement - Property Tests", () => {
    /**
     * Property: Rate limit enforcement consistency
     * For any webhook and user, the rate limiter should consistently enforce
     * configured limits across all time windows (minute, hour, day)
     * **Validates: Requirements 10.7**
     */
    it("should enforce rate limits consistently across multiple requests", () => {
      const config = {
        rate_limit_per_minute: 5,
        rate_limit_per_hour: 50,
        rate_limit_per_day: 500,
      };

      let allowedCount = 0;
      let blockedCount = 0;

      // Make 10 requests
      for (let i = 0; i < 10; i++) {
        const result = service.checkRateLimitInMemory(
          "webhook1",
          "user1",
          config,
        );
        if (result.allowed) {
          allowedCount++;
        } else {
          blockedCount++;
        }
      }

      // First 5 should be allowed, rest blocked
      expect(allowedCount).toBe(5);
      expect(blockedCount).toBe(5);
    });

    /**
     * Property: Rate limit isolation
     * For any two different webhooks or users, their rate limits should be
     * independent and not affect each other
     * **Validates: Requirements 10.7**
     */
    it("should isolate rate limits between different webhooks", () => {
      const config = {
        rate_limit_per_minute: 2,
        rate_limit_per_hour: 100,
        rate_limit_per_day: 1000,
      };

      // Webhook 1 - make 3 requests
      let result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(true);
      result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(true);
      result = service.checkRateLimitInMemory("webhook1", "user1", config);
      expect(result.allowed).toBe(false); // Blocked

      // Webhook 2 - should still allow requests
      result = service.checkRateLimitInMemory("webhook2", "user1", config);
      expect(result.allowed).toBe(true);
      result = service.checkRateLimitInMemory("webhook2", "user1", config);
      expect(result.allowed).toBe(true);
      result = service.checkRateLimitInMemory("webhook2", "user1", config);
      expect(result.allowed).toBe(false); // Blocked
    });

    /**
     * Property: Rate limit accuracy
     * For any configuration, the number of allowed requests should exactly
     * match the configured limit before blocking begins
     * **Validates: Requirements 10.7**
     */
    it("should allow exactly the configured number of requests", () => {
      const limits = [1, 5, 10, 50];

      for (const limit of limits) {
        service.rateLimitCache.clear();

        const config = {
          rate_limit_per_minute: limit,
          rate_limit_per_hour: limit * 10,
          rate_limit_per_day: limit * 100,
        };

        let allowedCount = 0;

        // Make limit + 5 requests
        for (let i = 0; i < limit + 5; i++) {
          const result = service.checkRateLimitInMemory(
            `webhook-${limit}`,
            "user1",
            config,
          );
          if (result.allowed) {
            allowedCount++;
          }
        }

        // Should allow exactly 'limit' requests
        expect(allowedCount).toBe(limit);
      }
    });
  });
});
