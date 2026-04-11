import {
  jest,
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
} from "@jest/globals";

import fc from "fast-check";
import { ProxyHealthService } from "../../services/api-backend/services/proxy-health-service.js";

/**
 * Property-Based Tests for Proxy Health Service
 * **Feature: api-backend-enhancement, Property 8: Proxy state consistency**
 * **Validates: Requirements 5.3**
 *
 * These tests verify that proxy health state transitions are consistent
 * and predictable across all possible inputs and scenarios.
 */
describe("ProxyHealthService - Property-Based Tests", () => {
  let proxyHealthService;

  beforeEach(() => {
    proxyHealthService = new ProxyHealthService();
  });

  afterEach(() => {
    proxyHealthService.shutdown();
  });

  /**
   * Property: Health status consistency after registration
   * For any proxy ID, after registration, the proxy should have unknown status
   * and zero consecutive failures and recovery attempts
   */
  it("should maintain consistent initial state for all registered proxies", () => {
    fc.assert(
      fc.property(fc.string({ minLength: 1, maxLength: 255 }), (proxyId) => {
        proxyHealthService.registerProxy(proxyId, {});

        const status = proxyHealthService.getProxyHealthStatus(proxyId);

        // Invariant: Initial state is always unknown with zero failures
        expect(status.status).toBe("unknown");
        expect(status.consecutiveFailures).toBe(0);
        expect(status.recoveryAttempts).toBe(0);
      }),
      { numRuns: 100 },
    );
  });

  /**
   * Property: Metrics initialization consistency
   * For any registered proxy, metrics should be initialized with zero values
   */
  it("should initialize metrics consistently for all proxies", () => {
    fc.assert(
      fc.property(fc.string({ minLength: 1, maxLength: 255 }), (proxyId) => {
        proxyHealthService.registerProxy(proxyId, {});

        const metrics = proxyHealthService.getProxyMetrics(proxyId);

        // Invariant: Metrics always start at zero
        expect(metrics.requestCount).toBe(0);
        expect(metrics.successCount).toBe(0);
        expect(metrics.errorCount).toBe(0);
        expect(metrics.averageLatency).toBe(0);
      }),
      { numRuns: 100 },
    );
  });

  /**
   * Property: Unregistration removes all tracking
   * For any registered proxy, after unregistration, it should return unknown status
   */
  it("should completely remove proxy tracking after unregistration", () => {
    fc.assert(
      fc.property(fc.string({ minLength: 1, maxLength: 255 }), (proxyId) => {
        proxyHealthService.registerProxy(proxyId, {});
        proxyHealthService.unregisterProxy(proxyId);

        const status = proxyHealthService.getProxyHealthStatus(proxyId);

        // Invariant: Unregistered proxy returns unknown status
        expect(status.status).toBe("unknown");
        expect(status.message).toBe("Proxy not registered");
      }),
      { numRuns: 100 },
    );
  });

  /**
   * Property: Recovery attempts are bounded
   * For any proxy, recovery attempts should never exceed max attempts
   */
  it("should enforce maximum recovery attempts for all proxies", () => {
    fc.assert(
      fc.property(
        fc
          .string({ minLength: 1, maxLength: 255 })
          .filter((s) => s.trim().length > 0),
        fc.integer({ min: 1, max: 10 }),
        (proxyId, attemptCount) => {
          proxyHealthService.shutdown();
          proxyHealthService = new ProxyHealthService();
          proxyHealthService.registerProxy(proxyId, {});

          let canRecover = true;
          for (let i = 0; i < attemptCount; i++) {
            canRecover = proxyHealthService.recordRecoveryAttempt(proxyId);
          }

          const status = proxyHealthService.getProxyHealthStatus(proxyId);

          // Invariant: Recovery attempts never exceed max
          expect(status.recoveryAttempts).toBeLessThanOrEqual(
            proxyHealthService.maxRecoveryAttempts,
          );

          // Invariant: canRecover is false when max attempts exceeded
          if (attemptCount > proxyHealthService.maxRecoveryAttempts) {
            expect(canRecover).toBe(false);
          }
        },
      ),
      { numRuns: 100 },
    );
  });

  /**
   * Property: Metrics update preserves non-updated fields
   * For any proxy and any partial metrics update, non-updated fields should remain unchanged
   */
  it("should preserve non-updated metric fields during partial updates", () => {
    fc.assert(
      fc.property(
        fc.string({ minLength: 1, maxLength: 255 }),
        fc.integer({ min: 0, max: 10000 }),
        fc.integer({ min: 0, max: 10000 }),
        (proxyId, requestCount, _successCount) => {
          proxyHealthService.registerProxy(proxyId, {});

          // Update only requestCount
          proxyHealthService.updateProxyMetrics(proxyId, {
            requestCount,
          });

          const metrics = proxyHealthService.getProxyMetrics(proxyId);

          // Invariant: Updated field is changed
          expect(metrics.requestCount).toBe(requestCount);

          // Invariant: Non-updated fields remain at initial values
          expect(metrics.successCount).toBe(0);
          expect(metrics.errorCount).toBe(0);
          expect(metrics.averageLatency).toBe(0);
        },
      ),
      { numRuns: 100 },
    );
  });

  /**
   * Property: Health check result consistency
   * For any proxy with successful health check, status should be healthy
   * and consecutive failures should be zero
   */
  it("should consistently mark proxies as healthy on successful checks", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 1, maxLength: 255 }),
        async (proxyId) => {
          proxyHealthService.registerProxy(proxyId, {});

          const healthCheckFn = jest.fn().mockResolvedValue({ status: "ok" });
          const result = await proxyHealthService.checkProxyHealth(
            proxyId,
            healthCheckFn,
          );

          // Invariant: Successful check results in healthy status
          expect(result.status).toBe("healthy");

          const status = proxyHealthService.getProxyHealthStatus(proxyId);

          // Invariant: Consecutive failures reset to zero
          expect(status.consecutiveFailures).toBe(0);
        },
      ),
      { numRuns: 50 },
    );
  });

  /**
   * Property: Consecutive failure counting
   * For any proxy with N consecutive failures, consecutive failure count should equal N
   * (up to the unhealthy threshold)
   */
  it("should accurately count consecutive failures for all proxies", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 1, maxLength: 255 }),
        fc.integer({ min: 1, max: 5 }),
        async (proxyId, failureCount) => {
          proxyHealthService.registerProxy(proxyId, {});

          const healthCheckFn = jest
            .fn()
            .mockRejectedValue(new Error("Connection failed"));

          for (let i = 0; i < failureCount; i++) {
            await proxyHealthService.checkProxyHealth(proxyId, healthCheckFn);
          }

          const status = proxyHealthService.getProxyHealthStatus(proxyId);

          // Invariant: Consecutive failures match attempt count
          expect(status.consecutiveFailures).toBe(failureCount);
        },
      ),
      { numRuns: 50 },
    );
  });

  /**
   * Property: Status transition from degraded to healthy
   * For any proxy in degraded state, a successful health check should transition to healthy
   */
  it("should transition from degraded to healthy on successful check", async () => {
    await fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 1, maxLength: 255 }),
        async (proxyId) => {
          proxyHealthService.registerProxy(proxyId, {});

          // Fail once to get degraded status
          const failingHealthCheck = jest
            .fn()
            .mockRejectedValue(new Error("Connection failed"));
          await proxyHealthService.checkProxyHealth(
            proxyId,
            failingHealthCheck,
          );

          let status = proxyHealthService.getProxyHealthStatus(proxyId);
          expect(status.status).toBe("degraded");

          // Succeed to transition to healthy
          const successfulHealthCheck = jest
            .fn()
            .mockResolvedValue({ status: "ok" });
          await proxyHealthService.checkProxyHealth(
            proxyId,
            successfulHealthCheck,
          );

          status = proxyHealthService.getProxyHealthStatus(proxyId);

          // Invariant: Status transitions to healthy
          expect(status.status).toBe("healthy");
          expect(status.consecutiveFailures).toBe(0);
        },
      ),
      { numRuns: 50 },
    );
  });

  /**
   * Property: Reset clears all failure tracking
   * For any proxy with recovery attempts and failures, reset should clear both
   */
  it("should completely clear failure tracking on reset", () => {
    fc.assert(
      fc.property(
        fc.string({ minLength: 1, maxLength: 255 }),
        fc.integer({ min: 1, max: 5 }),
        (proxyId, failureCount) => {
          proxyHealthService.registerProxy(proxyId, {});

          // Record some failures and recovery attempts
          for (let i = 0; i < failureCount; i++) {
            proxyHealthService.recordRecoveryAttempt(proxyId);
          }

          // Reset
          proxyHealthService.resetRecoveryAttempts(proxyId);

          const status = proxyHealthService.getProxyHealthStatus(proxyId);

          // Invariant: Both recovery attempts and consecutive failures are zero
          expect(status.recoveryAttempts).toBe(0);
          expect(status.consecutiveFailures).toBe(0);
        },
      ),
      { numRuns: 100 },
    );
  });

  /**
   * Property: All proxies in getAllProxyHealthStatus are registered
   * For any set of registered proxies, getAllProxyHealthStatus should return
   * exactly those proxies with their correct IDs
   */
  it("should return all and only registered proxies in getAllProxyHealthStatus", () => {
    fc.assert(
      fc.property(
        fc.array(fc.string({ minLength: 1, maxLength: 50 }), {
          minLength: 1,
          maxLength: 10,
        }),
        (proxyIds) => {
          const uniqueIds = [...new Set(proxyIds)];
          proxyHealthService.shutdown();
          proxyHealthService = new ProxyHealthService();

          uniqueIds.forEach((id) => {
            proxyHealthService.registerProxy(id, {});
          });

          const allStatuses = proxyHealthService.getAllProxyHealthStatus();

          expect(allStatuses).toHaveLength(uniqueIds.length);

          const returnedIds = allStatuses.map((s) => s.proxyId);
          expect(returnedIds.sort()).toEqual([...uniqueIds].sort());
        },
      ),
      { numRuns: 50 },
    );
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
});
