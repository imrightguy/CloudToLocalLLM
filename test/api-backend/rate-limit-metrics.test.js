import {} from "@jest/globals";

/**


 * @fileoverview Tests for rate limit metrics service
 * Tests metrics collection, recording, and retrieval
 */

import { RateLimitMetricsService } from "../../services/api-backend/services/rate-limit-metrics-service.js";

describe("RateLimitMetricsService", () => {
  let metricsService;

  beforeEach(() => {
    metricsService = new RateLimitMetricsService();
  });

  afterEach(() => {
    metricsService.reset();
  });

  describe("Violation Recording", () => {
    test("should record a rate limit violation", () => {
      const violation = {
        violationType: "window_limit_exceeded",
        userId: "user-123",
        ipAddress: "192.168.1.100",
        userTier: "free",
      };

      metricsService.recordViolation(violation);

      const summary = metricsService.getMetricsSummary();
      expect(summary.topViolators.length).toBeGreaterThan(0);
      expect(summary.topViolators[0].userId).toBe("user-123");
    });

    test("should track multiple violations for same user", () => {
      const violation = {
        violationType: "window_limit_exceeded",
        userId: "user-123",
        ipAddress: "192.168.1.100",
      };

      metricsService.recordViolation(violation);
      metricsService.recordViolation(violation);
      metricsService.recordViolation(violation);

      const topViolators = metricsService.getTopViolators(10);
      expect(topViolators[0].violationCount).toBe(3);
    });

    test("should track violations by IP address", () => {
      const violation1 = {
        violationType: "window_limit_exceeded",
        userId: "user-123",
        ipAddress: "192.168.1.100",
      };

      const violation2 = {
        violationType: "burst_limit_exceeded",
        userId: "user-456",
        ipAddress: "192.168.1.100",
      };

      metricsService.recordViolation(violation1);
      metricsService.recordViolation(violation2);

      const topIps = metricsService.getTopViolatingIps(10);
      expect(topIps[0].ipAddress).toBe("192.168.1.100");
      expect(topIps[0].violationCount).toBe(2);
    });

    test("should handle violations without userId", () => {
      const violation = {
        violationType: "window_limit_exceeded",
        ipAddress: "192.168.1.100",
      };

      expect(() => {
        metricsService.recordViolation(violation);
      }).not.toThrow();
    });

    test("should handle violations without ipAddress", () => {
      const violation = {
        violationType: "window_limit_exceeded",
        userId: "user-123",
      };

      expect(() => {
        metricsService.recordViolation(violation);
      }).not.toThrow();
    });
  });

  describe("Exemption Recording", () => {
    test("should record a rate limit exemption", () => {
      const exemption = {
        exemptionType: "critical_operation",
        userId: "user-123",
        ruleId: "rule-1",
      };

      expect(() => {
        metricsService.recordExemption(exemption);
      }).not.toThrow();
    });

    test("should handle exemptions without userId", () => {
      const exemption = {
        exemptionType: "critical_operation",
        ruleId: "rule-1",
      };

      expect(() => {
        metricsService.recordExemption(exemption);
      }).not.toThrow();
    });
  });

  describe("Request Recording", () => {
    test("should record allowed requests", () => {
      const request = {
        userId: "user-123",
        userTier: "premium",
      };

      expect(() => {
        metricsService.recordRequestAllowed(request);
      }).not.toThrow();
    });

    test("should record blocked requests", () => {
      const request = {
        userId: "user-123",
        violationType: "window_limit_exceeded",
        userTier: "free",
      };

      expect(() => {
        metricsService.recordRequestBlocked(request);
      }).not.toThrow();
    });
  });

  describe("Usage Tracking", () => {
    test("should update window usage", () => {
      expect(() => {
        metricsService.updateWindowUsage("user-123", 50, 100);
      }).not.toThrow();
    });

    test("should update burst usage", () => {
      expect(() => {
        metricsService.updateBurstUsage("user-123", 25, 50);
      }).not.toThrow();
    });

    test("should update concurrent requests", () => {
      expect(() => {
        metricsService.updateConcurrentRequests("user-123", 5);
      }).not.toThrow();
    });

    test("should record check duration", () => {
      expect(() => {
        metricsService.recordCheckDuration(0.005);
      }).not.toThrow();
    });

    test("should update active rate limited users", () => {
      expect(() => {
        metricsService.updateActiveRateLimitedUsers(10);
      }).not.toThrow();
    });
  });

  describe("Top Violators", () => {
    test("should return top violators sorted by count", () => {
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        userId: "user-1",
      });
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        userId: "user-2",
      });
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        userId: "user-2",
      });
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        userId: "user-3",
      });
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        userId: "user-3",
      });
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        userId: "user-3",
      });

      const topViolators = metricsService.getTopViolators(10);

      expect(topViolators.length).toBe(3);
      expect(topViolators[0].userId).toBe("user-3");
      expect(topViolators[0].violationCount).toBe(3);
      expect(topViolators[1].userId).toBe("user-2");
      expect(topViolators[1].violationCount).toBe(2);
      expect(topViolators[2].userId).toBe("user-1");
      expect(topViolators[2].violationCount).toBe(1);
    });

    test("should respect limit parameter", () => {
      for (let i = 0; i < 20; i++) {
        metricsService.recordViolation({
          violationType: "window_limit_exceeded",
          userId: `user-${i}`,
        });
      }

      const topViolators = metricsService.getTopViolators(5);
      expect(topViolators.length).toBe(5);
    });
  });

  describe("Top Violating IPs", () => {
    test("should return top violating IPs sorted by count", () => {
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        ipAddress: "192.168.1.1",
      });
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        ipAddress: "192.168.1.2",
      });
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        ipAddress: "192.168.1.2",
      });

      const topIps = metricsService.getTopViolatingIps(10);

      expect(topIps.length).toBe(2);
      expect(topIps[0].ipAddress).toBe("192.168.1.2");
      expect(topIps[0].violationCount).toBe(2);
      expect(topIps[1].ipAddress).toBe("192.168.1.1");
      expect(topIps[1].violationCount).toBe(1);
    });
  });

  describe("Metrics Summary", () => {
    test("should return metrics summary", () => {
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        userId: "user-123",
        ipAddress: "192.168.1.100",
      });

      const summary = metricsService.getMetricsSummary();

      expect(summary).toHaveProperty("timestamp");
      expect(summary).toHaveProperty("topViolators");
      expect(summary).toHaveProperty("topViolatingIps");
      expect(summary).toHaveProperty("totalViolators");
      expect(summary).toHaveProperty("totalViolatingIps");
      expect(summary.totalViolators).toBe(1);
      expect(summary.totalViolatingIps).toBe(1);
    });
  });

  describe("Reset", () => {
    test("should reset all metrics", () => {
      metricsService.recordViolation({
        violationType: "window_limit_exceeded",
        userId: "user-123",
        ipAddress: "192.168.1.100",
      });

      let summary = metricsService.getMetricsSummary();
      expect(summary.totalViolators).toBe(1);

      metricsService.reset();

      summary = metricsService.getMetricsSummary();
      expect(summary.totalViolators).toBe(0);
      expect(summary.totalViolatingIps).toBe(0);
    });
  });
});
