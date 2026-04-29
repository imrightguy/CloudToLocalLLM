import {
  jest,
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
} from "@jest/globals";
import { ProxyHealthService } from "../../services/api-backend/services/proxy-health-service.js";

describe("ProxyHealthService", () => {
  let proxyHealthService;

  beforeEach(() => {
    proxyHealthService = new ProxyHealthService();
  });

  afterEach(() => {
    proxyHealthService.shutdown();
  });

  describe("registerProxy", () => {
    it("should register a proxy for health monitoring", () => {
      const proxyId = "proxy-123";
      const metadata = { userId: "user-1", containerId: "container-1" };

      proxyHealthService.registerProxy(proxyId, metadata);

      const status = proxyHealthService.getProxyHealthStatus(proxyId);
      expect(status.proxyId).toBe(proxyId);
      expect(status.status).toBe("unknown");
      expect(status.consecutiveFailures).toBe(0);
      expect(status.recoveryAttempts).toBe(0);
    });

    it("should throw error if proxyId is missing", () => {
      expect(() => {
        proxyHealthService.registerProxy(null, {});
      }).toThrow("proxyId is required");
    });

    it("should initialize metrics for registered proxy", () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const metrics = proxyHealthService.getProxyMetrics(proxyId);
      expect(metrics).toBeDefined();
      expect(metrics.requestCount).toBe(0);
      expect(metrics.successCount).toBe(0);
      expect(metrics.errorCount).toBe(0);
      expect(metrics.averageLatency).toBe(0);
    });
  });

  describe("unregisterProxy", () => {
    it("should unregister a proxy from health monitoring", () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      proxyHealthService.unregisterProxy(proxyId);

      const status = proxyHealthService.getProxyHealthStatus(proxyId);
      expect(status.status).toBe("unknown");
      expect(status.message).toBe("Proxy not registered");
    });

    it("should handle unregistering non-existent proxy gracefully", () => {
      expect(() => {
        proxyHealthService.unregisterProxy("non-existent");
      }).not.toThrow();
    });
  });

  describe("checkProxyHealth", () => {
    it("should mark proxy as healthy when health check succeeds", async () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const healthCheckFn = jest.fn().mockResolvedValue({ status: "ok" });
      const result = await proxyHealthService.checkProxyHealth(
        proxyId,
        healthCheckFn,
      );

      expect(result.status).toBe("healthy");
      expect(result.proxyId).toBe(proxyId);
      expect(result.checkDuration).toBeGreaterThanOrEqual(0);
    });

    it("should mark proxy as degraded on first health check failure", async () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const healthCheckFn = jest
        .fn()
        .mockRejectedValue(new Error("Connection failed"));
      const result = await proxyHealthService.checkProxyHealth(
        proxyId,
        healthCheckFn,
      );

      expect(result.status).toBe("degraded");
      expect(result.consecutiveFailures).toBe(1);
      expect(result.error).toBe("Connection failed");
    });

    it("should mark proxy as unhealthy after 3 consecutive failures", async () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const healthCheckFn = jest
        .fn()
        .mockRejectedValue(new Error("Connection failed"));

      // First failure
      let result = await proxyHealthService.checkProxyHealth(
        proxyId,
        healthCheckFn,
      );
      expect(result.status).toBe("degraded");

      // Second failure
      result = await proxyHealthService.checkProxyHealth(
        proxyId,
        healthCheckFn,
      );
      expect(result.status).toBe("degraded");

      // Third failure
      result = await proxyHealthService.checkProxyHealth(
        proxyId,
        healthCheckFn,
      );
      expect(result.status).toBe("unhealthy");
      expect(result.consecutiveFailures).toBe(3);
    });

    it("should reset consecutive failures on successful health check", async () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const failingHealthCheck = jest
        .fn()
        .mockRejectedValue(new Error("Connection failed"));
      const successfulHealthCheck = jest
        .fn()
        .mockResolvedValue({ status: "ok" });

      // Fail twice
      await proxyHealthService.checkProxyHealth(proxyId, failingHealthCheck);
      await proxyHealthService.checkProxyHealth(proxyId, failingHealthCheck);

      let status = proxyHealthService.getProxyHealthStatus(proxyId);
      expect(status.consecutiveFailures).toBe(2);

      // Succeed
      await proxyHealthService.checkProxyHealth(proxyId, successfulHealthCheck);

      status = proxyHealthService.getProxyHealthStatus(proxyId);
      expect(status.status).toBe("healthy");
      expect(status.consecutiveFailures).toBe(0);
    });

    it("should timeout health check if it takes too long", async () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const slowHealthCheck = jest.fn(() => new Promise(() => {}));

      const result = await proxyHealthService.checkProxyHealth(
        proxyId,
        slowHealthCheck,
      );

      expect(result.status).toBe("degraded");
      expect(result.error).toBe("Health check timeout");
    }, 15000);

    it("should throw error if proxy not registered", async () => {
      const healthCheckFn = jest.fn().mockResolvedValue({ status: "ok" });

      await expect(
        proxyHealthService.checkProxyHealth("non-existent", healthCheckFn),
      ).rejects.toThrow("Proxy not registered");
    });

    it("should call recovery callback when proxy becomes unhealthy", async () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const recoveryCallback = jest.fn();
      proxyHealthService.setRecoveryCallback(recoveryCallback);

      const healthCheckFn = jest
        .fn()
        .mockRejectedValue(new Error("Connection failed"));

      // Fail 3 times to trigger unhealthy status
      await proxyHealthService.checkProxyHealth(proxyId, healthCheckFn);
      await proxyHealthService.checkProxyHealth(proxyId, healthCheckFn);
      await proxyHealthService.checkProxyHealth(proxyId, healthCheckFn);

      expect(recoveryCallback).toHaveBeenCalledWith(proxyId, expect.any(Error));
    });

    it("should call health status change callback when status changes", async () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const statusChangeCallback = jest.fn();
      proxyHealthService.setHealthStatusChangeCallback(statusChangeCallback);

      const failingHealthCheck = jest
        .fn()
        .mockRejectedValue(new Error("Connection failed"));
      const successfulHealthCheck = jest
        .fn()
        .mockResolvedValue({ status: "ok" });

      // Fail to trigger status change
      await proxyHealthService.checkProxyHealth(proxyId, failingHealthCheck);
      expect(statusChangeCallback).toHaveBeenCalledWith(
        proxyId,
        "unknown",
        "degraded",
      );

      // Succeed to trigger status change back
      await proxyHealthService.checkProxyHealth(proxyId, successfulHealthCheck);
      expect(statusChangeCallback).toHaveBeenCalledWith(
        proxyId,
        "degraded",
        "healthy",
      );
    });
  });

  describe("getProxyHealthStatus", () => {
    it("should return health status for registered proxy", () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const status = proxyHealthService.getProxyHealthStatus(proxyId);

      expect(status.proxyId).toBe(proxyId);
      expect(status.status).toBe("unknown");
      expect(status.consecutiveFailures).toBe(0);
      expect(status.recoveryAttempts).toBe(0);
    });

    it("should return unknown status for unregistered proxy", () => {
      const status = proxyHealthService.getProxyHealthStatus("non-existent");

      expect(status.status).toBe("unknown");
      expect(status.message).toBe("Proxy not registered");
    });
  });

  describe("getAllProxyHealthStatus", () => {
    it("should return health status for all registered proxies", () => {
      proxyHealthService.registerProxy("proxy-1", {});
      proxyHealthService.registerProxy("proxy-2", {});
      proxyHealthService.registerProxy("proxy-3", {});

      const statuses = proxyHealthService.getAllProxyHealthStatus();

      expect(statuses).toHaveLength(3);
      expect(statuses.map((s) => s.proxyId)).toEqual([
        "proxy-1",
        "proxy-2",
        "proxy-3",
      ]);
    });

    it("should return empty array when no proxies registered", () => {
      const statuses = proxyHealthService.getAllProxyHealthStatus();

      expect(statuses).toEqual([]);
    });
  });

  describe("recordRecoveryAttempt", () => {
    it("should record recovery attempt and return true if under max attempts", () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const canRecover = proxyHealthService.recordRecoveryAttempt(proxyId);

      expect(canRecover).toBe(true);

      const status = proxyHealthService.getProxyHealthStatus(proxyId);
      expect(status.recoveryAttempts).toBe(1);
    });

    it("should return false when max recovery attempts exceeded", () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      // Record max attempts
      proxyHealthService.recordRecoveryAttempt(proxyId);
      proxyHealthService.recordRecoveryAttempt(proxyId);
      proxyHealthService.recordRecoveryAttempt(proxyId);

      const canRecover = proxyHealthService.recordRecoveryAttempt(proxyId);

      expect(canRecover).toBe(false);
    });

    it("should return false for unregistered proxy", () => {
      const canRecover =
        proxyHealthService.recordRecoveryAttempt("non-existent");

      expect(canRecover).toBe(false);
    });
  });

  describe("resetRecoveryAttempts", () => {
    it("should reset recovery attempts and consecutive failures", () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      // Record some attempts
      proxyHealthService.recordRecoveryAttempt(proxyId);
      proxyHealthService.recordRecoveryAttempt(proxyId);

      let status = proxyHealthService.getProxyHealthStatus(proxyId);
      expect(status.recoveryAttempts).toBe(2);

      // Reset
      proxyHealthService.resetRecoveryAttempts(proxyId);

      status = proxyHealthService.getProxyHealthStatus(proxyId);
      expect(status.recoveryAttempts).toBe(0);
      expect(status.consecutiveFailures).toBe(0);
    });

    it("should handle resetting non-existent proxy gracefully", () => {
      expect(() => {
        proxyHealthService.resetRecoveryAttempts("non-existent");
      }).not.toThrow();
    });
  });

  describe("updateProxyMetrics", () => {
    it("should update proxy metrics", () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      proxyHealthService.updateProxyMetrics(proxyId, {
        requestCount: 100,
        successCount: 95,
        errorCount: 5,
        averageLatency: 150,
      });

      const metrics = proxyHealthService.getProxyMetrics(proxyId);

      expect(metrics.requestCount).toBe(100);
      expect(metrics.successCount).toBe(95);
      expect(metrics.errorCount).toBe(5);
      expect(metrics.averageLatency).toBe(150);
    });

    it("should partially update metrics", () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      proxyHealthService.updateProxyMetrics(proxyId, {
        requestCount: 100,
      });

      const metrics = proxyHealthService.getProxyMetrics(proxyId);

      expect(metrics.requestCount).toBe(100);
      expect(metrics.successCount).toBe(0);
      expect(metrics.errorCount).toBe(0);
    });

    it("should handle updating non-existent proxy gracefully", () => {
      expect(() => {
        proxyHealthService.updateProxyMetrics("non-existent", {
          requestCount: 100,
        });
      }).not.toThrow();
    });
  });

  describe("getProxyMetrics", () => {
    it("should return metrics for registered proxy", () => {
      const proxyId = "proxy-123";
      proxyHealthService.registerProxy(proxyId, {});

      const metrics = proxyHealthService.getProxyMetrics(proxyId);

      expect(metrics).toBeDefined();
      expect(metrics.requestCount).toBe(0);
      expect(metrics.lastUpdated).toBeDefined();
    });

    it("should return null for unregistered proxy", () => {
      const metrics = proxyHealthService.getProxyMetrics("non-existent");

      expect(metrics).toBeNull();
    });
  });

  describe("startHealthChecks and stopHealthChecks", () => {
    it("should start periodic health checks", (done) => {
      const healthCheckFn = jest.fn().mockResolvedValue(undefined);

      // Override interval to be shorter for testing
      proxyHealthService.healthCheckIntervalMs = 50;

      proxyHealthService.startHealthChecks(healthCheckFn);

      // Wait for at least one health check cycle
      setTimeout(() => {
        proxyHealthService.stopHealthChecks();
        expect(healthCheckFn).toHaveBeenCalled();
        done();
      }, 150);
    }, 10000);

    it("should stop periodic health checks", (done) => {
      const healthCheckFn = jest.fn().mockResolvedValue(undefined);

      // Override interval to be shorter for testing
      proxyHealthService.healthCheckIntervalMs = 50;

      proxyHealthService.startHealthChecks(healthCheckFn);

      setTimeout(() => {
        const callCountBefore = healthCheckFn.mock.calls.length;
        proxyHealthService.stopHealthChecks();

        setTimeout(() => {
          const callCountAfter = healthCheckFn.mock.calls.length;
          expect(callCountAfter).toBe(callCountBefore);
          done();
        }, 150);
      }, 150);
    }, 10000);

    it("should warn if health checks already running", () => {
      const healthCheckFn = jest.fn().mockResolvedValue(undefined);
      const warnSpy = jest.spyOn(proxyHealthService.logger, "warn");

      proxyHealthService.startHealthChecks(healthCheckFn);
      proxyHealthService.startHealthChecks(healthCheckFn);

      expect(warnSpy).toHaveBeenCalledWith("Health checks already running");

      proxyHealthService.stopHealthChecks();
      warnSpy.mockRestore();
    });
  });

  describe("getConfiguration", () => {
    it("should return health check configuration", () => {
      const config = proxyHealthService.getConfiguration();

      expect(config.healthCheckIntervalMs).toBeDefined();
      expect(config.maxRecoveryAttempts).toBeDefined();
      expect(config.recoveryBackoffMs).toBeDefined();
      expect(config.healthCheckTimeoutMs).toBeDefined();
      expect(config.unhealthyThresholdMs).toBeDefined();
    });
  });

  describe("shutdown", () => {
    it("should shutdown health service and clear data", () => {
      proxyHealthService.registerProxy("proxy-1", {});
      proxyHealthService.registerProxy("proxy-2", {});

      proxyHealthService.shutdown();

      const statuses = proxyHealthService.getAllProxyHealthStatus();
      expect(statuses).toHaveLength(0);
    });
  });

  /**
   * Property-Based Tests for Proxy Lifecycle
   * **Feature: api-backend-enhancement, Property 8: Proxy state consistency**
   * **Validates: Requirements 5.1, 5.2**
   *
   * These tests verify that proxy lifecycle state transitions are consistent
   * and predictable across all possible inputs and scenarios.
   */
  describe("Proxy Lifecycle - Property-Based Tests", () => {
    /**
     * Property: Proxy registration creates valid initial state
     * For any proxy ID, after registration, the proxy should be in unknown state
     * with zero failures and zero recovery attempts
     */
    it("should create consistent initial state for all registered proxies", () => {
      const proxyIds = ["proxy-1", "proxy-2", "proxy-3", "proxy-test-123"];

      proxyIds.forEach((proxyId) => {
        proxyHealthService.registerProxy(proxyId, { userId: "test-user" });

        const status = proxyHealthService.getProxyHealthStatus(proxyId);

        // Invariant: Initial state is always unknown
        expect(status.status).toBe("unknown");
        // Invariant: No failures recorded initially
        expect(status.consecutiveFailures).toBe(0);
        // Invariant: No recovery attempts initially
        expect(status.recoveryAttempts).toBe(0);
        // Invariant: Metrics are initialized
        expect(status.metrics).toBeDefined();
      });
    });

    /**
     * Property: Proxy unregistration removes all state
     * For any registered proxy, after unregistration, querying it should return unknown status
     */
    it("should completely remove proxy state after unregistration", () => {
      const proxyIds = ["proxy-1", "proxy-2", "proxy-3"];

      proxyIds.forEach((proxyId) => {
        proxyHealthService.registerProxy(proxyId, {});
        proxyHealthService.unregisterProxy(proxyId);

        const status = proxyHealthService.getProxyHealthStatus(proxyId);

        // Invariant: Unregistered proxy returns unknown status
        expect(status.status).toBe("unknown");
        expect(status.message).toBe("Proxy not registered");
      });
    });

    /**
     * Property: Successful health check transitions to healthy
     * For any registered proxy, a successful health check should result in healthy status
     * and zero consecutive failures
     */
    it("should transition to healthy state on successful health check", async () => {
      const proxyIds = ["proxy-1", "proxy-2", "proxy-3"];

      for (const proxyId of proxyIds) {
        proxyHealthService.registerProxy(proxyId, {});

        const healthCheckFn = jest.fn().mockResolvedValue({ status: "ok" });
        const result = await proxyHealthService.checkProxyHealth(
          proxyId,
          healthCheckFn,
        );

        // Invariant: Result status is healthy
        expect(result.status).toBe("healthy");

        const status = proxyHealthService.getProxyHealthStatus(proxyId);

        // Invariant: Status is healthy
        expect(status.status).toBe("healthy");
        // Invariant: Consecutive failures reset to zero
        expect(status.consecutiveFailures).toBe(0);
        // Invariant: Last check is recorded
        expect(status.lastCheck).toBeDefined();
      }
    });

    /**
     * Property: Failed health checks increment failure counter
     * For any registered proxy with N failed health checks, consecutive failures should equal N
     * (up to the unhealthy threshold of 3)
     */
    it("should increment consecutive failures on failed health checks", async () => {
      const testCases = [
        { proxyId: "proxy-1", failureCount: 1 },
        { proxyId: "proxy-2", failureCount: 2 },
        { proxyId: "proxy-3", failureCount: 3 },
        { proxyId: "proxy-4", failureCount: 5 },
      ];

      for (const testCase of testCases) {
        proxyHealthService.registerProxy(testCase.proxyId, {});

        const healthCheckFn = jest
          .fn()
          .mockRejectedValue(new Error("Connection failed"));

        for (let i = 0; i < testCase.failureCount; i++) {
          await proxyHealthService.checkProxyHealth(
            testCase.proxyId,
            healthCheckFn,
          );
        }

        const status = proxyHealthService.getProxyHealthStatus(
          testCase.proxyId,
        );

        // Invariant: Consecutive failures match attempt count
        expect(status.consecutiveFailures).toBe(testCase.failureCount);
      }
    });

    /**
     * Property: State transitions follow valid paths
     * For any proxy, state transitions should only follow valid paths:
     * unknown -> degraded/unhealthy, degraded -> healthy/unhealthy, etc.
     */
    it("should follow valid state transition paths", async () => {
      const proxyId = "proxy-lifecycle-test";
      proxyHealthService.registerProxy(proxyId, {});

      const healthCheckResults = [false, true, false, true];
      let previousStatus = "unknown";

      for (const isHealthy of healthCheckResults) {
        const healthCheckFn = isHealthy
          ? jest.fn().mockResolvedValue({ status: "ok" })
          : jest.fn().mockRejectedValue(new Error("Failed"));

        await proxyHealthService.checkProxyHealth(proxyId, healthCheckFn);

        const status = proxyHealthService.getProxyHealthStatus(proxyId);
        const currentStatus = status.status;

        // Invariant: State transitions are valid
        const validTransitions = {
          unknown: ["healthy", "degraded", "unhealthy"],
          healthy: ["degraded", "unhealthy"],
          degraded: ["healthy", "unhealthy"],
          unhealthy: ["degraded", "healthy"],
        };

        expect(validTransitions[previousStatus]).toContain(currentStatus);
        previousStatus = currentStatus;
      }
    });

    /**
     * Property: Recovery attempts are bounded
     * For any proxy, recovery attempts should never exceed the configured maximum
     */
    it("should enforce maximum recovery attempts for all proxies", () => {
      const testCases = [
        { proxyId: "proxy-1", attemptCount: 1 },
        { proxyId: "proxy-2", attemptCount: 3 },
        { proxyId: "proxy-3", attemptCount: 5 },
        { proxyId: "proxy-4", attemptCount: 10 },
      ];

      for (const testCase of testCases) {
        proxyHealthService.registerProxy(testCase.proxyId, {});

        let canRecover = true;
        for (let i = 0; i < testCase.attemptCount; i++) {
          canRecover = proxyHealthService.recordRecoveryAttempt(
            testCase.proxyId,
          );
        }

        proxyHealthService.getProxyHealthStatus(testCase.proxyId);

        // Invariant: canRecover is false when max attempts exceeded
        if (testCase.attemptCount > proxyHealthService.maxRecoveryAttempts) {
          expect(canRecover).toBe(false);
        } else {
          expect(canRecover).toBe(true);
        }
      }
    });

    /**
     * Property: Reset clears all failure tracking
     * For any proxy with failures and recovery attempts, reset should clear both
     */
    it("should completely clear failure tracking on reset", async () => {
      const testCases = [
        { proxyId: "proxy-1", failureCount: 1 },
        { proxyId: "proxy-2", failureCount: 2 },
        { proxyId: "proxy-3", failureCount: 5 },
      ];

      for (const testCase of testCases) {
        proxyHealthService.registerProxy(testCase.proxyId, {});

        // Record some failures
        const healthCheckFn = jest.fn().mockRejectedValue(new Error("Failed"));
        for (let i = 0; i < testCase.failureCount; i++) {
          await proxyHealthService.checkProxyHealth(
            testCase.proxyId,
            healthCheckFn,
          );
        }

        // Record recovery attempts
        for (let i = 0; i < 2; i++) {
          proxyHealthService.recordRecoveryAttempt(testCase.proxyId);
        }

        // Reset
        proxyHealthService.resetRecoveryAttempts(testCase.proxyId);

        const status = proxyHealthService.getProxyHealthStatus(
          testCase.proxyId,
        );

        // Invariant: Both recovery attempts and consecutive failures are zero
        expect(status.recoveryAttempts).toBe(0);
        expect(status.consecutiveFailures).toBe(0);
      }
    });

    /**
     * Property: Metrics are preserved across state transitions
     * For any proxy, metrics should be preserved when state changes
     */
    it("should preserve metrics across state transitions", async () => {
      const testCases = [
        { proxyId: "proxy-1", requestCount: 100 },
        { proxyId: "proxy-2", requestCount: 500 },
        { proxyId: "proxy-3", requestCount: 1000 },
      ];

      for (const testCase of testCases) {
        proxyHealthService.registerProxy(testCase.proxyId, {});

        // Set initial metrics
        proxyHealthService.updateProxyMetrics(testCase.proxyId, {
          requestCount: testCase.requestCount,
          successCount: Math.floor(testCase.requestCount * 0.9),
          errorCount: Math.floor(testCase.requestCount * 0.1),
          averageLatency: 50,
        });

        // Perform health check (state transition)
        const healthCheckFn = jest.fn().mockResolvedValue({ status: "ok" });
        await proxyHealthService.checkProxyHealth(
          testCase.proxyId,
          healthCheckFn,
        );

        const status = proxyHealthService.getProxyHealthStatus(
          testCase.proxyId,
        );

        // Invariant: Metrics are preserved
        expect(status.metrics.requestCount).toBe(testCase.requestCount);
        expect(status.metrics.successCount).toBe(
          Math.floor(testCase.requestCount * 0.9),
        );
        expect(status.metrics.errorCount).toBe(
          Math.floor(testCase.requestCount * 0.1),
        );
        expect(status.metrics.averageLatency).toBe(50);
      }
    });

    /**
     * Property: All registered proxies are returned in getAllProxyHealthStatus
     * For any set of registered proxies, getAllProxyHealthStatus should return
     * exactly those proxies with their correct IDs
     */
    it("should return all and only registered proxies in getAllProxyHealthStatus", () => {
      const proxyIds = ["proxy-1", "proxy-2", "proxy-3", "proxy-4", "proxy-5"];

      // Register all proxies
      proxyIds.forEach((id) => {
        proxyHealthService.registerProxy(id, {});
      });

      const allStatuses = proxyHealthService.getAllProxyHealthStatus();

      // Invariant: All registered proxies are returned
      expect(allStatuses).toHaveLength(proxyIds.length);

      const returnedIds = allStatuses.map((s) => s.proxyId);

      // Invariant: Returned IDs match registered IDs
      expect(returnedIds.sort()).toEqual(proxyIds.sort());

      // Invariant: All returned proxies have valid status
      allStatuses.forEach((status) => {
        expect(["unknown", "healthy", "degraded", "unhealthy"]).toContain(
          status.status,
        );
      });
    });

    /**
     * Property: Successful check after failures resets failure counter
     * For any proxy with consecutive failures, a successful health check should reset
     * the consecutive failure counter to zero
     */
    it("should reset consecutive failures on successful health check after failures", async () => {
      const testCases = [
        { proxyId: "proxy-1", failureCount: 1 },
        { proxyId: "proxy-2", failureCount: 2 },
        { proxyId: "proxy-3", failureCount: 3 },
      ];

      for (const testCase of testCases) {
        proxyHealthService.registerProxy(testCase.proxyId, {});

        // Record failures
        const failingHealthCheck = jest
          .fn()
          .mockRejectedValue(new Error("Failed"));
        for (let i = 0; i < testCase.failureCount; i++) {
          await proxyHealthService.checkProxyHealth(
            testCase.proxyId,
            failingHealthCheck,
          );
        }

        let status = proxyHealthService.getProxyHealthStatus(testCase.proxyId);
        expect(status.consecutiveFailures).toBe(testCase.failureCount);

        // Succeed
        const successfulHealthCheck = jest
          .fn()
          .mockResolvedValue({ status: "ok" });
        await proxyHealthService.checkProxyHealth(
          testCase.proxyId,
          successfulHealthCheck,
        );

        status = proxyHealthService.getProxyHealthStatus(testCase.proxyId);

        // Invariant: Consecutive failures reset to zero
        expect(status.consecutiveFailures).toBe(0);
        // Invariant: Status is healthy
        expect(status.status).toBe("healthy");
      }
    });

    /**
     * Property: Metrics update preserves non-updated fields
     * For any proxy and any partial metrics update, non-updated fields should remain unchanged
     */
    it("should preserve non-updated metric fields during partial updates", () => {
      const testCases = [
        { proxyId: "proxy-1", requestCount: 100 },
        { proxyId: "proxy-2", requestCount: 500 },
        { proxyId: "proxy-3", requestCount: 1000 },
      ];

      for (const testCase of testCases) {
        proxyHealthService.registerProxy(testCase.proxyId, {});

        // Update only requestCount
        proxyHealthService.updateProxyMetrics(testCase.proxyId, {
          requestCount: testCase.requestCount,
        });

        const metrics = proxyHealthService.getProxyMetrics(testCase.proxyId);

        // Invariant: Updated field is changed
        expect(metrics.requestCount).toBe(testCase.requestCount);

        // Invariant: Non-updated fields remain at initial values
        expect(metrics.successCount).toBe(0);
        expect(metrics.errorCount).toBe(0);
        expect(metrics.averageLatency).toBe(0);
      }
    });

    /**
     * Property: Configuration values are always positive
     * For any proxy health service, configuration values should be positive integers
     */
    it("should maintain positive configuration values", () => {
      const config = proxyHealthService.getConfiguration();

      // Invariant: All configuration values are positive
      expect(config.healthCheckIntervalMs).toBeGreaterThan(0);
      expect(config.maxRecoveryAttempts).toBeGreaterThan(0);
      expect(config.recoveryBackoffMs).toBeGreaterThan(0);
      expect(config.healthCheckTimeoutMs).toBeGreaterThan(0);
      expect(config.unhealthyThresholdMs).toBeGreaterThan(0);
    });

    /**
     * Property: Unhealthy state is reached after 3 consecutive failures
     * For any proxy, after exactly 3 consecutive failures, status should be unhealthy
     */
    it("should transition to unhealthy after 3 consecutive failures", async () => {
      const proxyId = "proxy-unhealthy-test";
      proxyHealthService.registerProxy(proxyId, {});

      const healthCheckFn = jest.fn().mockRejectedValue(new Error("Failed"));

      // First failure -> degraded
      await proxyHealthService.checkProxyHealth(proxyId, healthCheckFn);
      let status = proxyHealthService.getProxyHealthStatus(proxyId);
      expect(status.status).toBe("degraded");

      // Second failure -> degraded
      await proxyHealthService.checkProxyHealth(proxyId, healthCheckFn);
      status = proxyHealthService.getProxyHealthStatus(proxyId);
      expect(status.status).toBe("degraded");

      // Third failure -> unhealthy
      await proxyHealthService.checkProxyHealth(proxyId, healthCheckFn);
      status = proxyHealthService.getProxyHealthStatus(proxyId);

      // Invariant: Status is unhealthy after 3 failures
      expect(status.status).toBe("unhealthy");
      expect(status.consecutiveFailures).toBe(3);
    });
  });
});
