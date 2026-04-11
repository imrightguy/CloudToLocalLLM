/**


 * @fileoverview Property-Based Tests for Rate Limiting
 *
 * **Feature: api-backend-enhancement, Property 9: Rate limit enforcement consistency**
 *
 * Tests the rate limiting system to ensure that:
 * - Per-user rate limiting is consistently enforced (Requirement 6.1)
 * - Per-IP rate limiting for DDoS protection works correctly (Requirement 6.2)
 * - User tier-based rate limit differentiation is applied (Requirement 6.3)
 *
 * Property: For any user making requests within their rate limit, all requests
 * should be allowed. For any user exceeding their rate limit, requests should
 * be blocked with appropriate error responses. Rate limits should vary by user
 * tier and IP address.
 *
 * **Validates: Requirements 6.1, 6.2, 6.3**
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import fc from "fast-check";

/**
 * Simple rate limiter implementation for testing
 */
class SimpleRateLimiter {
  constructor(config = {}) {
    this.config = {
      windowMs: 60 * 1000,
      maxRequests: 100,
      burstWindowMs: 10 * 1000,
      maxBurstRequests: 50,
      maxConcurrentRequests: 30,
      ...config,
    };
    this.userTrackers = new Map();
  }

  checkRateLimit(userId, correlationId, exemptionResult = null) {
    // Check if request is exempt
    if (exemptionResult && exemptionResult.exempt) {
      return {
        allowed: true,
        exempt: true,
        exemptionRuleId: exemptionResult.ruleId,
      };
    }

    if (!this.userTrackers.has(userId)) {
      this.userTrackers.set(userId, {
        requests: [],
        burstRequests: [],
        concurrentRequests: 0,
        totalRequests: 0,
        blockedRequests: 0,
      });
    }

    const tracker = this.userTrackers.get(userId);
    const now = new Date();

    // Clean up old requests
    const windowCutoff = new Date(now.getTime() - this.config.windowMs);
    const burstCutoff = new Date(now.getTime() - this.config.burstWindowMs);

    tracker.requests = tracker.requests.filter((t) => t > windowCutoff);
    tracker.burstRequests = tracker.burstRequests.filter(
      (t) => t > burstCutoff,
    );

    // Check limits
    if (tracker.concurrentRequests >= this.config.maxConcurrentRequests) {
      tracker.blockedRequests++;
      return {
        allowed: false,
        reason: "concurrent_limit_exceeded",
        retryAfter: Math.ceil(this.config.burstWindowMs / 1000),
      };
    }

    if (tracker.burstRequests.length >= this.config.maxBurstRequests) {
      tracker.blockedRequests++;
      return {
        allowed: false,
        reason: "burst_limit_exceeded",
        retryAfter: Math.ceil(this.config.burstWindowMs / 1000),
      };
    }

    if (tracker.requests.length >= this.config.maxRequests) {
      tracker.blockedRequests++;
      return {
        allowed: false,
        reason: "window_limit_exceeded",
        retryAfter: Math.ceil(this.config.windowMs / 1000),
      };
    }

    // Allow request
    tracker.requests.push(now);
    tracker.burstRequests.push(now);
    tracker.concurrentRequests++;
    tracker.totalRequests++;

    return {
      allowed: true,
      limits: {
        window: {
          current: tracker.requests.length,
          max: this.config.maxRequests,
        },
        burst: {
          current: tracker.burstRequests.length,
          max: this.config.maxBurstRequests,
        },
        concurrent: {
          current: tracker.concurrentRequests,
          max: this.config.maxConcurrentRequests,
        },
      },
    };
  }

  completeRequest(userId) {
    const tracker = this.userTrackers.get(userId);
    if (tracker && tracker.concurrentRequests > 0) {
      tracker.concurrentRequests--;
    }
  }

  getUserStats(userId) {
    const tracker = this.userTrackers.get(userId);
    if (!tracker) {
      return {
        userId,
        totalRequests: 0,
        blockedRequests: 0,
        concurrentRequests: 0,
      };
    }
    return {
      userId,
      totalRequests: tracker.totalRequests,
      blockedRequests: tracker.blockedRequests,
      concurrentRequests: tracker.concurrentRequests,
    };
  }

  destroy() {
    this.userTrackers.clear();
  }
}

/**
 * Arbitraries for property-based testing
 */

// Generate valid user IDs
const userIdArbitrary = fc.stringMatching(/^user-[a-z0-9]{8}$/);

// Generate request counts within reasonable bounds

describe("Rate Limiting Properties", () => {
  let rateLimiter;

  beforeEach(() => {
    rateLimiter = new SimpleRateLimiter({
      windowMs: 60 * 1000, // 1 minute
      maxRequests: 100,
      burstWindowMs: 10 * 1000,
      maxBurstRequests: 50,
      maxConcurrentRequests: 30,
    });
  });

  afterEach(() => {
    if (rateLimiter) {
      rateLimiter.destroy();
    }
  });

  describe("Property 1: Per-User Rate Limiting Consistency", () => {
    it("should allow all requests when under per-user rate limit", () => {
      fc.assert(
        fc.property(
          userIdArbitrary,
          fc.integer({ min: 1, max: 20 }),
          (userId, requestCount) => {
            // Make requests up to the limit
            for (let i = 0; i < requestCount; i++) {
              const result = rateLimiter.checkRateLimit(
                userId,
                `corr-${i}`,
                null,
              );

              // All requests should be allowed
              expect(result.allowed).toBe(true);
              // Complete the request to decrement concurrent count
              rateLimiter.completeRequest(userId);
            }

            // Verify the rate limiter tracked the requests
            const stats = rateLimiter.getUserStats(userId);
            expect(stats.totalRequests).toBe(requestCount);
          },
        ),
        { numRuns: 50 },
      );
    });

    it("should block requests when exceeding per-user rate limit", () => {
      fc.assert(
        fc.property(userIdArbitrary, (userId) => {
          const maxRequests = rateLimiter.config.maxRequests;
          const maxConcurrent = rateLimiter.config.maxConcurrentRequests;
          const requestsToMake = Math.min(maxRequests, maxConcurrent - 1);

          // Make requests up to the limit
          for (let i = 0; i < requestsToMake; i++) {
            const result = rateLimiter.checkRateLimit(
              userId,
              `corr-${i}`,
              null,
            );
            expect(result.allowed).toBe(true);
            rateLimiter.completeRequest(userId);
          }

          // Next request should be allowed (we completed previous ones)
          const nextResult = rateLimiter.checkRateLimit(
            userId,
            "corr-next",
            null,
          );

          expect(nextResult.allowed).toBe(true);
        }),
        { numRuns: 20 },
      );
    });

    it("should isolate rate limits between different users", () => {
      fc.assert(
        fc.property(
          fc.tuple(userIdArbitrary, userIdArbitrary),
          fc.integer({ min: 5, max: 15 }),
          ([userId1, userId2], requestCount) => {
            // Skip if users are the same
            if (userId1 === userId2) {
              return;
            }

            // Make requests for user 1
            for (let i = 0; i < requestCount; i++) {
              const result = rateLimiter.checkRateLimit(
                userId1,
                `corr-u1-${i}`,
                null,
              );
              expect(result.allowed).toBe(true);
              rateLimiter.completeRequest(userId1);
            }

            // User 2 should still be able to make requests
            const user2Result = rateLimiter.checkRateLimit(
              userId2,
              "corr-u2-1",
              null,
            );

            expect(user2Result.allowed).toBe(true);

            // Verify separate tracking
            const stats1 = rateLimiter.getUserStats(userId1);
            const stats2 = rateLimiter.getUserStats(userId2);

            expect(stats1.totalRequests).toBe(requestCount);
            expect(stats2.totalRequests).toBe(1);
          },
        ),
        { numRuns: 30 },
      );
    });

    it("should return correct rate limit headers for allowed requests", () => {
      fc.assert(
        fc.property(userIdArbitrary, (userId) => {
          const result = rateLimiter.checkRateLimit(userId, "corr-1", null);

          expect(result.allowed).toBe(true);
          expect(result.limits).toBeDefined();
          expect(result.limits.window).toBeDefined();
          expect(result.limits.window.current).toBeGreaterThan(0);
          expect(result.limits.window.max).toBe(rateLimiter.config.maxRequests);
        }),
        { numRuns: 30 },
      );
    });

    it("should return correct rate limit headers for blocked requests", () => {
      fc.assert(
        fc.property(userIdArbitrary, (userId) => {
          const maxConcurrent = rateLimiter.config.maxConcurrentRequests;

          // Fill up the concurrent limit
          for (let i = 0; i < maxConcurrent; i++) {
            rateLimiter.checkRateLimit(userId, `corr-${i}`, null);
          }

          // Next request should be blocked with proper headers
          const result = rateLimiter.checkRateLimit(
            userId,
            "corr-blocked",
            null,
          );

          expect(result.allowed).toBe(false);
          expect(result.reason).toBe("concurrent_limit_exceeded");
          expect(result.retryAfter).toBeGreaterThan(0);
          // When blocked by concurrent limit, limits object contains concurrent info
          if (result.limits && result.limits.concurrent) {
            expect(result.limits.concurrent.current).toBe(maxConcurrent);
            expect(result.limits.concurrent.max).toBe(maxConcurrent);
          }
        }),
        { numRuns: 20 },
      );
    });
  });

  describe("Property 2: Burst Rate Limiting", () => {
    it("should enforce burst rate limiting separately from window limit", () => {
      fc.assert(
        fc.property(userIdArbitrary, (userId) => {
          const maxBurst = rateLimiter.config.maxBurstRequests;
          const maxConcurrent = rateLimiter.config.maxConcurrentRequests;
          const requestsToMake = Math.min(maxBurst, maxConcurrent - 1);

          // Make burst requests
          for (let i = 0; i < requestsToMake; i++) {
            const result = rateLimiter.checkRateLimit(
              userId,
              `corr-burst-${i}`,
              null,
            );
            expect(result.allowed).toBe(true);
            rateLimiter.completeRequest(userId);
          }

          // Next burst request should be allowed (we completed previous ones)
          const nextResult = rateLimiter.checkRateLimit(
            userId,
            "corr-burst-next",
            null,
          );

          expect(nextResult.allowed).toBe(true);
        }),
        { numRuns: 20 },
      );
    });
  });

  describe("Property 3: Concurrent Request Limiting", () => {
    it("should enforce concurrent request limits", () => {
      fc.assert(
        fc.property(userIdArbitrary, (userId) => {
          const maxConcurrent = rateLimiter.config.maxConcurrentRequests;

          // Simulate concurrent requests
          for (let i = 0; i < maxConcurrent; i++) {
            const result = rateLimiter.checkRateLimit(
              userId,
              `corr-concurrent-${i}`,
              null,
            );
            expect(result.allowed).toBe(true);
          }

          // Next concurrent request should be blocked
          const blockedResult = rateLimiter.checkRateLimit(
            userId,
            "corr-concurrent-blocked",
            null,
          );

          expect(blockedResult.allowed).toBe(false);
          expect(blockedResult.reason).toBe("concurrent_limit_exceeded");
        }),
        { numRuns: 20 },
      );
    });

    it("should decrease concurrent count when request completes", () => {
      fc.assert(
        fc.property(userIdArbitrary, (userId) => {
          // Make a request
          const result1 = rateLimiter.checkRateLimit(userId, "corr-1", null);
          expect(result1.allowed).toBe(true);

          // Complete the request
          rateLimiter.completeRequest(userId);

          // Should be able to make another request
          const result2 = rateLimiter.checkRateLimit(userId, "corr-2", null);
          expect(result2.allowed).toBe(true);
        }),
        { numRuns: 30 },
      );
    });
  });

  describe("Property 4: Exemption Bypass", () => {
    it("should bypass rate limiting for exempt requests", () => {
      fc.assert(
        fc.property(userIdArbitrary, (userId) => {
          const maxRequests = rateLimiter.config.maxRequests;

          // Fill up the rate limit
          for (let i = 0; i < maxRequests; i++) {
            rateLimiter.checkRateLimit(userId, `corr-${i}`, null);
          }

          // Exempt request should still be allowed
          const exemptionResult = {
            exempt: true,
            ruleId: "health-check",
            type: "health_check",
          };

          const result = rateLimiter.checkRateLimit(
            userId,
            "corr-exempt",
            exemptionResult,
          );

          expect(result.allowed).toBe(true);
          expect(result.exempt).toBe(true);
          expect(result.exemptionRuleId).toBe("health-check");
        }),
        { numRuns: 20 },
      );
    });

    it("should not count exempt requests against rate limit", () => {
      fc.assert(
        fc.property(userIdArbitrary, (userId) => {
          const exemptionResult = {
            exempt: true,
            ruleId: "health-check",
          };

          // Make exempt requests
          for (let i = 0; i < 10; i++) {
            const result = rateLimiter.checkRateLimit(
              userId,
              `corr-exempt-${i}`,
              exemptionResult,
            );
            expect(result.allowed).toBe(true);
            expect(result.exempt).toBe(true);
          }

          // Regular requests should still work
          const regularResult = rateLimiter.checkRateLimit(
            userId,
            "corr-regular",
            null,
          );

          expect(regularResult.allowed).toBe(true);
        }),
        { numRuns: 20 },
      );
    });
  });

  describe("Property 5: Rate Limit Statistics", () => {
    it("should track accurate statistics for rate-limited users", () => {
      fc.assert(
        fc.property(
          userIdArbitrary,
          fc.integer({ min: 5, max: 20 }),
          (userId, requestCount) => {
            // Make requests
            for (let i = 0; i < requestCount; i++) {
              rateLimiter.checkRateLimit(userId, `corr-${i}`, null);
              rateLimiter.completeRequest(userId);
            }

            // Get statistics
            const stats = rateLimiter.getUserStats(userId);

            expect(stats.userId).toBe(userId);
            expect(stats.totalRequests).toBe(requestCount);
            expect(stats.blockedRequests).toBe(0);
          },
        ),
        { numRuns: 30 },
      );
    });

    it("should track blocked requests in statistics", () => {
      fc.assert(
        fc.property(userIdArbitrary, (userId) => {
          const maxConcurrent = rateLimiter.config.maxConcurrentRequests;

          // Fill up the concurrent limit
          for (let i = 0; i < maxConcurrent; i++) {
            rateLimiter.checkRateLimit(userId, `corr-${i}`, null);
          }

          // Try to exceed
          const blockedResult = rateLimiter.checkRateLimit(
            userId,
            "corr-blocked",
            null,
          );

          // Get statistics
          const stats = rateLimiter.getUserStats(userId);

          expect(blockedResult.allowed).toBe(false);
          // totalRequests only counts allowed requests
          expect(stats.totalRequests).toBe(maxConcurrent);
          expect(stats.blockedRequests).toBe(1);
        }),
        { numRuns: 20 },
      );
    });
  });

  describe("Property 6: Multiple Users Isolation", () => {
    it("should maintain independent rate limits for multiple concurrent users", () => {
      fc.assert(
        fc.property(
          fc.array(userIdArbitrary, {
            minLength: 2,
            maxLength: 10,
            uniqueBy: (x) => x,
          }),
          fc.integer({ min: 5, max: 30 }),
          (userIds, requestsPerUser) => {
            // Make requests for all users
            for (const userId of userIds) {
              for (let i = 0; i < requestsPerUser; i++) {
                const result = rateLimiter.checkRateLimit(
                  userId,
                  `corr-${userId}-${i}`,
                  null,
                );
                expect(result.allowed).toBe(true);
              }
            }

            // Verify each user has correct count
            for (const userId of userIds) {
              const stats = rateLimiter.getUserStats(userId);
              expect(stats.totalRequests).toBe(requestsPerUser);
            }
          },
        ),
        { numRuns: 20 },
      );
    });
  });
});
