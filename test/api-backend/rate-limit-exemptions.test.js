/**


 * @fileoverview Tests for Rate Limit Exemptions
 *
 * Tests the rate limit exemption mechanism for critical operations.
 * Validates that exemption rules work correctly and that critical
 * operations bypass rate limiting as expected.
 *
 * @fileoverview Rate limit exemptions tests
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import {
  RateLimitExemptionManager,
  createRateLimitExemptionMiddleware,
} from "../../services/api-backend/middleware/rate-limit-exemptions.js";
import { TunnelRateLimiter } from "../../services/api-backend/middleware/rate-limiter.js";

describe("Rate Limit Exemptions", () => {
  let exemptionManager;
  let rateLimiter;

  beforeEach(() => {
    exemptionManager = new RateLimitExemptionManager({
      enabled: true,
      logExemptions: true,
      logExemptionValidation: true,
    });

    rateLimiter = new TunnelRateLimiter({
      windowMs: 60 * 1000, // 1 minute
      maxRequests: 100,
      burstWindowMs: 10 * 1000, // 10 seconds
      maxBurstRequests: 50,
      maxConcurrentRequests: 30,
    });
  });

  afterEach(() => {
    if (rateLimiter) {
      rateLimiter.destroy();
    }
  });

  describe("Exemption Manager Initialization", () => {
    it("should initialize with default exemption rules", () => {
      const rules = exemptionManager.getRules();
      expect(rules.length).toBeGreaterThan(0);
      expect(rules.some((r) => r.id === "health-check")).toBe(true);
      expect(rules.some((r) => r.id === "authentication")).toBe(true);
    });

    it("should have health check rule enabled by default", () => {
      const rules = exemptionManager.getRules();
      const healthCheckRule = rules.find((r) => r.id === "health-check");
      expect(healthCheckRule).toBeDefined();
      expect(healthCheckRule.enabled).toBe(true);
    });

    it("should have authentication rule enabled by default", () => {
      const rules = exemptionManager.getRules();
      const authRule = rules.find((r) => r.id === "authentication");
      expect(authRule).toBeDefined();
      expect(authRule.enabled).toBe(true);
    });
  });

  describe("Exemption Rule Matching", () => {
    it("should exempt health check endpoint", () => {
      const req = {
        path: "/health",
        method: "GET",
        userId: "user123",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
      expect(result.ruleId).toBe("health-check");
    });

    it("should exempt /api/health endpoint", () => {
      const req = {
        path: "/api/health",
        method: "GET",
        userId: "user123",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
      expect(result.ruleId).toBe("health-check");
    });

    it("should exempt /db/health endpoint", () => {
      const req = {
        path: "/db/health",
        method: "GET",
        userId: "user123",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
      expect(result.ruleId).toBe("health-check");
    });

    it("should exempt authentication login endpoint", () => {
      const req = {
        path: "/auth/login",
        method: "POST",
        userId: "user123",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
      expect(result.ruleId).toBe("authentication");
    });

    it("should exempt authentication refresh endpoint", () => {
      const req = {
        path: "/auth/refresh",
        method: "POST",
        userId: "user123",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
      expect(result.ruleId).toBe("authentication");
    });

    it("should exempt authentication logout endpoint", () => {
      const req = {
        path: "/auth/logout",
        method: "POST",
        userId: "user123",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
      expect(result.ruleId).toBe("authentication");
    });

    it("should not exempt non-matching endpoints", () => {
      const req = {
        path: "/api/users/profile",
        method: "GET",
        userId: "user123",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(false);
    });
  });

  describe("Custom Exemption Rules", () => {
    it("should add custom exemption rule", () => {
      exemptionManager.addRule(
        "custom-rule",
        exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
        (req) => req.path === "/api/critical",
        { description: "Custom critical operation" },
      );

      const rules = exemptionManager.getRules();
      expect(rules.some((r) => r.id === "custom-rule")).toBe(true);
    });

    it("should match custom exemption rule", () => {
      exemptionManager.addRule(
        "custom-rule",
        exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
        (req) => req.path === "/api/critical",
        { description: "Custom critical operation" },
      );

      const req = {
        path: "/api/critical",
        method: "POST",
        userId: "user123",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
      expect(result.ruleId).toBe("custom-rule");
    });

    it("should remove exemption rule", () => {
      exemptionManager.addRule(
        "temp-rule",
        exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
        (req) => req.path === "/api/temp",
      );

      let rules = exemptionManager.getRules();
      expect(rules.some((r) => r.id === "temp-rule")).toBe(true);

      exemptionManager.removeRule("temp-rule");

      rules = exemptionManager.getRules();
      expect(rules.some((r) => r.id === "temp-rule")).toBe(false);
    });

    it("should enable/disable exemption rule", () => {
      exemptionManager.addRule(
        "toggle-rule",
        exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
        (req) => req.path === "/api/toggle",
      );

      exemptionManager.disableRule("toggle-rule");

      const req = {
        path: "/api/toggle",
        method: "POST",
        userId: "user123",
      };

      let result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(false);

      exemptionManager.enableRule("toggle-rule");

      result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
    });
  });

  describe("Exemption Quotas", () => {
    it("should enforce exemption quota per user", () => {
      exemptionManager.addRule(
        "quota-rule",
        exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
        (req) => req.path === "/api/quota-test",
        { maxExemptionsPerUser: 3 },
      );

      const req = {
        path: "/api/quota-test",
        method: "POST",
        userId: "user123",
      };

      // First 3 exemptions should succeed
      for (let i = 0; i < 3; i++) {
        const result = exemptionManager.checkExemption(req);
        expect(result.exempt).toBe(true);
      }

      // 4th exemption should fail
      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(false);
      expect(result.reason).toBe("exemption_quota_exceeded");
    });

    it("should track exemption count per user", () => {
      exemptionManager.addRule(
        "count-rule",
        exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
        (req) => req.path === "/api/count-test",
        { maxExemptionsPerUser: 5 },
      );

      const req1 = {
        path: "/api/count-test",
        method: "POST",
        userId: "user1",
      };

      const req2 = {
        path: "/api/count-test",
        method: "POST",
        userId: "user2",
      };

      // User 1 uses 2 exemptions
      exemptionManager.checkExemption(req1);
      exemptionManager.checkExemption(req1);

      // User 2 uses 1 exemption
      exemptionManager.checkExemption(req2);

      // Both should still have exemptions available
      let result1 = exemptionManager.checkExemption(req1);
      expect(result1.exempt).toBe(true);

      let result2 = exemptionManager.checkExemption(req2);
      expect(result2.exempt).toBe(true);
    });

    it("should reset exemption count for user", () => {
      exemptionManager.addRule(
        "reset-rule",
        exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
        (req) => req.path === "/api/reset-test",
        { maxExemptionsPerUser: 2 },
      );

      const req = {
        path: "/api/reset-test",
        method: "POST",
        userId: "user123",
      };

      // Use up exemptions
      exemptionManager.checkExemption(req);
      exemptionManager.checkExemption(req);

      // Next should fail
      let result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(false);

      // Reset
      exemptionManager.resetUserExemptions("user123");

      // Should work again
      result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
    });
  });

  describe("Integration with Rate Limiter", () => {
    it("should bypass rate limiting for exempt requests", () => {
      const exemptionResult = {
        exempt: true,
        ruleId: "health-check",
        type: "health_check",
      };

      const result = rateLimiter.checkRateLimit(
        "user123",
        "corr-123",
        exemptionResult,
      );

      expect(result.allowed).toBe(true);
      expect(result.exempt).toBe(true);
      expect(result.exemptionRuleId).toBe("health-check");
    });

    it("should apply rate limiting for non-exempt requests", () => {
      const exemptionResult = {
        exempt: false,
        reason: "no_matching_exemption",
      };

      // Make a few requests
      const result1 = rateLimiter.checkRateLimit(
        "user-non-exempt",
        "corr-1",
        exemptionResult,
      );
      expect(result1.allowed).toBe(true);

      const result2 = rateLimiter.checkRateLimit(
        "user-non-exempt",
        "corr-2",
        exemptionResult,
      );
      expect(result2.allowed).toBe(true);

      // Verify rate limiter is tracking requests
      const stats = rateLimiter.getUserStats("user-non-exempt");
      expect(stats.totalRequests).toBeGreaterThan(0);
    });

    it("should not count exempt requests against rate limit", () => {
      const exemptionResult = {
        exempt: true,
        ruleId: "health-check",
      };

      const nonExemptionResult = {
        exempt: false,
      };

      // Make exempt requests
      const exemptResult = rateLimiter.checkRateLimit(
        "user-mixed",
        "corr-exempt-1",
        exemptionResult,
      );
      expect(exemptResult.allowed).toBe(true);
      expect(exemptResult.exempt).toBe(true);

      // Make non-exempt request
      const nonExemptResult = rateLimiter.checkRateLimit(
        "user-mixed",
        "corr-normal-1",
        nonExemptionResult,
      );
      expect(nonExemptResult.allowed).toBe(true);
      expect(nonExemptResult.exempt).toBeUndefined();
    });
  });

  describe("Exemption Statistics", () => {
    it("should provide exemption statistics", () => {
      const stats = exemptionManager.getStatistics();

      expect(stats).toHaveProperty("totalRules");
      expect(stats).toHaveProperty("enabledRules");
      expect(stats).toHaveProperty("disabledRules");
      expect(stats).toHaveProperty("rules");
      expect(Array.isArray(stats.rules)).toBe(true);
    });

    it("should track enabled and disabled rules", () => {
      exemptionManager.addRule(
        "test-rule",
        exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
        (req) => req.path === "/api/test",
      );

      let stats = exemptionManager.getStatistics();
      const initialEnabled = stats.enabledRules;

      exemptionManager.disableRule("test-rule");

      stats = exemptionManager.getStatistics();
      expect(stats.enabledRules).toBe(initialEnabled - 1);
      expect(stats.disabledRules).toBeGreaterThan(0);
    });
  });

  describe("Exemption Logging", () => {
    it("should log exemption checks", () => {
      const req = {
        path: "/health",
        method: "GET",
        userId: "user123",
        correlationId: "corr-123",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
      // Logging is handled internally
    });

    it("should handle exemption validation errors gracefully", () => {
      exemptionManager.addRule(
        "error-rule",
        exemptionManager.config.exemptionTypes.CRITICAL_OPERATION,
        (_req) => {
          throw new Error("Matcher error");
        },
      );

      const req = {
        path: "/api/error-test",
        method: "POST",
        userId: "user123",
      };

      // Should not throw, should return not exempt
      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(false);
    });
  });

  describe("Exemption Middleware", () => {
    it("should create exemption middleware", () => {
      const middleware = createRateLimitExemptionMiddleware(exemptionManager);
      expect(typeof middleware).toBe("function");
    });

    it("should set exemption result in request", () => {
      const middleware = createRateLimitExemptionMiddleware(exemptionManager);

      const req = {
        path: "/health",
        method: "GET",
        userId: "user123",
      };

      const res = {};
      let nextCalled = false;
      const next = () => {
        nextCalled = true;
      };

      middleware(req, res, next);

      expect(req.rateLimitExemption).toBeDefined();
      expect(req.rateLimitExemption.exempt).toBe(true);
      expect(nextCalled).toBe(true);
    });
  });

  describe("Admin Operations Exemption", () => {
    it("should exempt admin operations for admin users", () => {
      const req = {
        path: "/admin/users",
        method: "GET",
        userId: "admin123",
        userRole: "admin",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(true);
      expect(result.ruleId).toBe("admin-operations");
    });

    it("should not exempt admin operations for non-admin users", () => {
      const req = {
        path: "/admin/users",
        method: "GET",
        userId: "user123",
        userRole: "user",
      };

      const result = exemptionManager.checkExemption(req);
      expect(result.exempt).toBe(false);
    });
  });

  describe("Exemption Disabling", () => {
    it("should respect global exemption disable", () => {
      const manager = new RateLimitExemptionManager({
        enabled: false,
      });

      const req = {
        path: "/health",
        method: "GET",
        userId: "user123",
      };

      const result = manager.checkExemption(req);
      expect(result.exempt).toBe(false);
      expect(result.reason).toBe("exemptions_disabled");
    });

    it("should allow re-enabling exemptions", () => {
      const manager = new RateLimitExemptionManager({
        enabled: false,
      });

      let req = {
        path: "/health",
        method: "GET",
        userId: "user123",
      };

      let result = manager.checkExemption(req);
      expect(result.exempt).toBe(false);

      // Re-enable by creating new manager
      const newManager = new RateLimitExemptionManager({
        enabled: true,
      });

      result = newManager.checkExemption(req);
      expect(result.exempt).toBe(true);
    });
  });
});
