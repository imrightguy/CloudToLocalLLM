/**


 * @fileoverview Tests for Adaptive Rate Limiting
 * Tests system load monitoring and adaptive rate limit adjustment
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import { SystemLoadMonitor } from "../../services/api-backend/services/system-load-monitor.js";
import { AdaptiveRateLimiter } from "../../services/api-backend/middleware/adaptive-rate-limiter.js";

describe("Adaptive Rate Limiting", () => {
  describe("SystemLoadMonitor", () => {
    let monitor;

    beforeEach(() => {
      monitor = new SystemLoadMonitor({
        sampleIntervalMs: 100, // Fast sampling for tests
        historySize: 10,
      });
    });

    afterEach(() => {
      if (monitor) {
        monitor.destroy();
      }
    });

    it("should initialize with default configuration", () => {
      expect(monitor).toBeDefined();
      expect(monitor.config.sampleIntervalMs).toBe(100);
      expect(monitor.config.historySize).toBe(10);
      expect(monitor.adaptiveMultiplier).toBe(1.0);
    });

    it("should collect system metrics", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const metrics = monitor.getCurrentMetrics();

        expect(metrics).toBeDefined();
        expect(metrics.cpuUsage).toBeDefined();
        expect(metrics.memoryUsage).toBeDefined();
        expect(metrics.loadPercentage).toBeDefined();
        expect(metrics.loadLevel).toBeDefined();
        expect(metrics.adaptiveMultiplier).toBeDefined();

        // Verify metrics are numbers
        expect(typeof parseFloat(metrics.cpuUsage)).toBe("number");
        expect(typeof parseFloat(metrics.memoryUsage)).toBe("number");
        expect(typeof parseFloat(metrics.loadPercentage)).toBe("number");

        done();
      }, 150);
    });

    it("should track active requests", () => {
      monitor.recordActiveRequest();
      monitor.recordActiveRequest();
      expect(monitor.activeRequests).toBe(2);

      monitor.recordCompletedRequest();
      expect(monitor.activeRequests).toBe(1);
    });

    it("should track queued requests", () => {
      monitor.recordQueuedRequest();
      monitor.recordQueuedRequest();
      expect(monitor.queuedRequests).toBe(2);

      monitor.recordDequeuedRequest();
      expect(monitor.queuedRequests).toBe(1);
    });

    it("should calculate load percentage correctly", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const load = monitor.currentMetrics.getLoadPercentage();

        expect(load).toBeGreaterThanOrEqual(0);
        expect(load).toBeLessThanOrEqual(100);

        done();
      }, 150);
    });

    it("should determine load level correctly", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const level = monitor.currentMetrics.getLoadLevel();

        expect(["low", "medium", "high", "critical"]).toContain(level);

        done();
      }, 150);
    });

    it("should maintain metrics history", (done) => {
      let collectionCount = 0;

      const interval = setInterval(() => {
        monitor.collectMetrics();
        collectionCount++;

        if (collectionCount >= 3) {
          clearInterval(interval);

          expect(monitor.metricsHistory.length).toBeGreaterThan(0);
          expect(monitor.metricsHistory.length).toBeLessThanOrEqual(10);

          done();
        }
      }, 50);
    });

    it("should calculate average metrics", (done) => {
      let collectionCount = 0;

      const interval = setInterval(() => {
        monitor.collectMetrics();
        collectionCount++;

        if (collectionCount >= 3) {
          clearInterval(interval);

          const avgMetrics = monitor.getAverageMetrics();

          expect(avgMetrics.cpuUsage).toBeDefined();
          expect(avgMetrics.memoryUsage).toBeDefined();
          expect(avgMetrics.loadPercentage).toBeDefined();
          expect(avgMetrics.sampleCount).toBeGreaterThan(0);

          done();
        }
      }, 50);
    });

    it("should provide adaptive limits based on system load", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const limits = monitor.getAdaptiveLimits(1000);

        expect(limits.baseLimit).toBe(1000);
        expect(limits.adaptiveLimit).toBeDefined();
        expect(limits.multiplier).toBeDefined();
        expect(limits.loadLevel).toBeDefined();
        expect(limits.recommendation).toBeDefined();

        // Adaptive limit should be <= base limit
        expect(limits.adaptiveLimit).toBeLessThanOrEqual(limits.baseLimit);

        done();
      }, 150);
    });

    it("should provide system status", (done) => {
      setTimeout(() => {
        monitor.collectMetrics();
        const status = monitor.getSystemStatus();

        expect(status.current).toBeDefined();
        expect(status.average).toBeDefined();
        expect(status.requests).toBeDefined();
        expect(status.adaptive).toBeDefined();
        expect(status.system).toBeDefined();

        expect(status.requests.active).toBeDefined();
        expect(status.requests.queued).toBeDefined();
        expect(status.requests.total).toBeDefined();

        done();
      }, 150);
    });

    it("should adjust adaptive multiplier based on load", (done) => {
      // Simulate high load
      monitor.currentMetrics.cpuUsage = 85;
      monitor.currentMetrics.memoryUsage = 80;

      monitor.updateAdaptiveMultiplier(true); // Force immediate update

      // Should reduce multiplier under high load
      expect(monitor.adaptiveMultiplier).toBeLessThan(1.0);

      done();
    });

    it("should not adjust multiplier during cooldown period", (done) => {
      monitor.currentMetrics.cpuUsage = 85;
      monitor.currentMetrics.memoryUsage = 80;

      monitor.updateAdaptiveMultiplier();
      const firstMultiplier = monitor.adaptiveMultiplier;

      // Try to adjust again immediately
      monitor.currentMetrics.cpuUsage = 95;
      monitor.currentMetrics.memoryUsage = 95;

      monitor.updateAdaptiveMultiplier();

      // Multiplier should not change due to cooldown
      expect(monitor.adaptiveMultiplier).toBe(firstMultiplier);

      done();
    });
  });

  describe("AdaptiveRateLimiter", () => {
    let limiter;

    beforeEach(() => {
      limiter = new AdaptiveRateLimiter({
        baseWindowMs: 60000,
        baseMaxRequests: 100,
        baseBurstWindowMs: 10000,
        baseBurstRequests: 20,
        sampleIntervalMs: 100,
      });
    });

    afterEach(() => {
      if (limiter) {
        limiter.destroy();
      }
    });

    it("should initialize with default configuration", () => {
      expect(limiter).toBeDefined();
      expect(limiter.config.baseMaxRequests).toBe(100);
      expect(limiter.config.baseBurstRequests).toBe(20);
      expect(limiter.systemLoadMonitor).toBeDefined();
    });

    it("should allow requests under normal load", () => {
      const result = limiter.checkRateLimit("user1", "corr-1", {});

      expect(result.allowed).toBe(true);
      expect(result.limits).toBeDefined();
      expect(result.limits.window).toBeDefined();
      expect(result.limits.burst).toBeDefined();
    });

    it("should track multiple requests for a user", () => {
      for (let i = 0; i < 5; i++) {
        const result = limiter.checkRateLimit("user1", `corr-${i}`, {});
        expect(result.allowed).toBe(true);
      }

      const stats = limiter.getUserStats("user1");
      expect(stats.totalRequests).toBe(5);
    });

    it("should enforce burst rate limit", () => {
      // Fill up burst limit
      for (let i = 0; i < 20; i++) {
        const result = limiter.checkRateLimit("user1", `corr-${i}`, {});
        expect(result.allowed).toBe(true);
      }

      // Next request should be blocked
      const result = limiter.checkRateLimit("user1", "corr-burst", {});
      expect(result.allowed).toBe(false);
      expect(result.reason).toBe("burst_limit_exceeded");
    });

    it("should enforce window rate limit", () => {
      // Set burst limit higher than window limit so burst doesn't interfere
      const fixedLimiter = new AdaptiveRateLimiter({
        baseWindowMs: 60000,
        baseMaxRequests: 10,
        baseBurstWindowMs: 60000,
        baseBurstRequests: 100,
        sampleIntervalMs: 60000,
        enableAdaptiveAdjustment: false,
      });

      fixedLimiter.systemLoadMonitor.collectMetrics();

      const limits = fixedLimiter.getAdaptiveLimits();
      expect(limits.maxRequests).toBe(10);
      expect(limits.multiplier).toBe(1.0);

      // Send exactly maxRequests requests — all should be allowed
      // (check-then-add: count checked before addRequest, so N requests pass)
      let allowedCount = 0;
      for (let i = 0; i < 10; i++) {
        const result = fixedLimiter.checkRateLimit(
          "window-user",
          `corr-${i}`,
          {},
        );
        if (result.allowed) allowedCount++;
      }
      expect(allowedCount).toBe(10);

      // Next request should be blocked by window limit
      const blocked = fixedLimiter.checkRateLimit(
        "window-user",
        "corr-blocked",
        {},
      );
      expect(blocked.allowed).toBe(false);
      expect(blocked.reason).toBe("window_limit_exceeded");

      fixedLimiter.destroy();
    });

    it("should get adaptive limits", () => {
      const limits = limiter.getAdaptiveLimits();

      expect(limits.maxRequests).toBeDefined();
      expect(limits.burstRequests).toBeDefined();
      expect(limits.multiplier).toBeDefined();

      // Under normal load, multiplier should be 1.0
      expect(limits.multiplier).toBe(1.0);
    });

    it("should reduce limits under high load", (done) => {
      // Simulate high load
      limiter.systemLoadMonitor.currentMetrics.cpuUsage = 85;
      limiter.systemLoadMonitor.currentMetrics.memoryUsage = 80;

      limiter.systemLoadMonitor.updateAdaptiveMultiplier(true); // Force immediate update

      setTimeout(() => {
        const limits = limiter.getAdaptiveLimits();

        // Limits should be reduced
        expect(limits.maxRequests).toBeLessThan(100);
        expect(limits.burstRequests).toBeLessThan(20);
        expect(limits.multiplier).toBeLessThan(1.0);

        done();
      }, 50);
    });

    it("should track active requests", () => {
      limiter.recordActiveRequest();
      limiter.recordActiveRequest();

      const metrics = limiter.getSystemMetrics();
      expect(metrics.activeRequests).toBe(2);
    });

    it("should complete requests", () => {
      limiter.recordActiveRequest();
      limiter.recordActiveRequest();

      limiter.completeRequest("user1");

      const metrics = limiter.getSystemMetrics();
      expect(metrics.activeRequests).toBe(1);
    });

    it("should get system metrics", (done) => {
      setTimeout(() => {
        const metrics = limiter.getSystemMetrics();

        expect(metrics).toBeDefined();
        expect(metrics.cpuUsage).toBeDefined();
        expect(metrics.memoryUsage).toBeDefined();
        expect(metrics.loadPercentage).toBeDefined();
        expect(metrics.loadLevel).toBeDefined();

        done();
      }, 150);
    });

    it("should get system status", (done) => {
      setTimeout(() => {
        const status = limiter.getSystemStatus();

        expect(status).toBeDefined();
        expect(status.current).toBeDefined();
        expect(status.average).toBeDefined();
        expect(status.requests).toBeDefined();
        expect(status.adaptive).toBeDefined();
        expect(status.system).toBeDefined();

        done();
      }, 150);
    });

    it("should get user statistics", () => {
      limiter.checkRateLimit("user1", "corr-1", {});
      limiter.checkRateLimit("user1", "corr-2", {});

      const stats = limiter.getUserStats("user1");

      expect(stats.userId).toBe("user1");
      expect(stats.totalRequests).toBe(2);
    });

    it("should handle multiple users independently", () => {
      for (let i = 0; i < 5; i++) {
        limiter.checkRateLimit("user1", `corr-1-${i}`, {});
        limiter.checkRateLimit("user2", `corr-2-${i}`, {});
      }

      const stats1 = limiter.getUserStats("user1");
      const stats2 = limiter.getUserStats("user2");

      expect(stats1.totalRequests).toBe(5);
      expect(stats2.totalRequests).toBe(5);
    });

    it("should clean up inactive user trackers", (done) => {
      limiter.checkRateLimit("user1", "corr-1", {});

      expect(limiter.userTrackers.size).toBe(1);

      // Manually trigger cleanup
      limiter.cleanup();

      // User should still be there (not inactive yet)
      expect(limiter.userTrackers.size).toBe(1);

      done();
    });

    it("should disable adaptive adjustment when configured", () => {
      const noAdaptiveLimiter = new AdaptiveRateLimiter({
        enableAdaptiveAdjustment: false,
        baseMaxRequests: 100,
      });

      const limits = noAdaptiveLimiter.getAdaptiveLimits();

      // Multiplier should always be 1.0
      expect(limits.multiplier).toBe(1.0);
      expect(limits.maxRequests).toBe(100);

      noAdaptiveLimiter.destroy();
    });
  });

  describe("Adaptive Rate Limiting Integration", () => {
    let limiter;

    beforeEach(() => {
      limiter = new AdaptiveRateLimiter({
        baseWindowMs: 60000,
        baseMaxRequests: 100,
        baseBurstWindowMs: 10000,
        baseBurstRequests: 20,
        sampleIntervalMs: 100,
      });
    });

    afterEach(() => {
      if (limiter) {
        limiter.destroy();
      }
    });

    it("should adapt limits as system load changes", (done) => {
      // Get initial limits
      const initialLimits = limiter.getAdaptiveLimits();
      expect(initialLimits.multiplier).toBe(1.0);

      // Simulate high load
      limiter.systemLoadMonitor.currentMetrics.cpuUsage = 85;
      limiter.systemLoadMonitor.currentMetrics.memoryUsage = 80;
      limiter.systemLoadMonitor.updateAdaptiveMultiplier(true); // Force immediate update

      setTimeout(() => {
        const highLoadLimits = limiter.getAdaptiveLimits();

        // Limits should be reduced
        expect(highLoadLimits.maxRequests).toBeLessThan(
          initialLimits.maxRequests,
        );
        expect(highLoadLimits.multiplier).toBeLessThan(1.0);

        done();
      }, 50);
    });

    it("should provide adaptive information in rate limit response", () => {
      const result = limiter.checkRateLimit("user1", "corr-1", {});

      expect(result.allowed).toBe(true);
      expect(result.limits.window.adaptive).toBe(true);
      expect(result.limits.window.multiplier).toBeDefined();
    });

    it("should handle critical load scenario", (done) => {
      // Simulate critical load with values that exceed 80% threshold
      // Load calculation: CPU*0.4 + Memory*0.4 + Queue*0.2
      // To reach >= 80% with CPU=100 and Memory=100: 100*0.4 + 100*0.4 = 80%
      limiter.systemLoadMonitor.currentMetrics.cpuUsage = 100;
      limiter.systemLoadMonitor.currentMetrics.memoryUsage = 100;
      limiter.systemLoadMonitor.updateAdaptiveMultiplier(true); // Force immediate update

      setTimeout(() => {
        const limits = limiter.getAdaptiveLimits();

        // Should be at 25% of normal limits
        expect(limits.multiplier).toBe(0.25);
        expect(limits.maxRequests).toBe(25); // 100 * 0.25

        done();
      }, 50);
    });

    it("should handle recovery from high load", (done) => {
      // Simulate high load
      limiter.systemLoadMonitor.currentMetrics.cpuUsage = 85;
      limiter.systemLoadMonitor.currentMetrics.memoryUsage = 80;
      limiter.systemLoadMonitor.updateAdaptiveMultiplier(true); // Force immediate update

      setTimeout(() => {
        const highLoadLimits = limiter.getAdaptiveLimits();
        expect(highLoadLimits.multiplier).toBeLessThan(1.0);

        // Simulate recovery
        limiter.systemLoadMonitor.currentMetrics.cpuUsage = 20;
        limiter.systemLoadMonitor.currentMetrics.memoryUsage = 30;
        limiter.systemLoadMonitor.lastAdjustmentTime = 0; // Reset cooldown

        limiter.systemLoadMonitor.updateAdaptiveMultiplier(true); // Force immediate update

        setTimeout(() => {
          const recoveredLimits = limiter.getAdaptiveLimits();

          // Should return to normal
          expect(recoveredLimits.multiplier).toBe(1.0);

          done();
        }, 50);
      }, 50);
    });
  });
});
