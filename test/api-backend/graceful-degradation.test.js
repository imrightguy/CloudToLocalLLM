/**
 * Graceful Degradation Service Tests
 *
 * Tests for graceful degradation functionality when services are unavailable.
 * Validates fallback mechanisms and reduced functionality modes.
 *
 * Requirement 7.6: THE API SHALL implement graceful degradation when services are unavailable
 */

import {
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
  jest,
} from "@jest/globals";
import { GracefulDegradationService } from "../../services/api-backend/services/graceful-degradation.js";

describe("GracefulDegradationService", () => {
  let service;

  beforeEach(() => {
    service = new GracefulDegradationService();
  });

  afterEach(() => {
    service.resetAll();
  });

  describe("Service Registration", () => {
    it("should register a service for degradation management", () => {
      service.registerService("test-service", {
        fallback: async () => ({ data: "fallback" }),
        criticalEndpoints: ["/api/critical"],
      });

      const status = service.getStatus("test-service");
      expect(status.service).toBe("test-service");
      expect(status.isDegraded).toBe(false);
    });

    it("should throw error if service name is missing", () => {
      expect(() => {
        service.registerService(null);
      }).toThrow("Service name is required");
    });

    it("should register multiple services", () => {
      service.registerService("service-1");
      service.registerService("service-2");
      service.registerService("service-3");

      const statuses = service.getAllStatuses();
      expect(statuses).toHaveLength(3);
    });
  });

  describe("Degradation State Management", () => {
    beforeEach(() => {
      service.registerService("test-service");
    });

    it("should mark a service as degraded", () => {
      service.markDegraded(
        "test-service",
        "Database connection failed",
        "warning",
      );

      const status = service.getStatus("test-service");
      expect(status.isDegraded).toBe(true);
      expect(status.reason).toBe("Database connection failed");
      expect(status.severity).toBe("warning");
    });

    it("should mark a service as recovered", () => {
      service.markDegraded("test-service", "Connection failed");
      service.markRecovered("test-service");

      const status = service.getStatus("test-service");
      expect(status.isDegraded).toBe(false);
      expect(status.reason).toBeNull();
    });

    it("should track degradation start time", () => {
      service.markDegraded("test-service", "Test degradation");

      const status = service.getStatus("test-service");
      expect(status.degradationStartTime).not.toBeNull();
      expect(typeof status.degradationStartTime).toBe("number");
    });

    it("should support critical severity degradation", () => {
      service.markDegraded("test-service", "Critical failure", "critical");

      const status = service.getStatus("test-service");
      expect(status.severity).toBe("critical");
    });

    it("should not double-count degradations", () => {
      service.markDegraded("test-service", "First degradation");
      const metricsAfterFirst = service.getMetrics();

      service.markDegraded("test-service", "Second degradation");
      const metricsAfterSecond = service.getMetrics();

      expect(metricsAfterSecond.totalDegradations).toBe(
        metricsAfterFirst.totalDegradations,
      );
      expect(metricsAfterSecond.activeDegradations).toBe(1);
    });
  });

  describe("Fallback Mechanisms", () => {
    it("should execute primary function when service is healthy", async () => {
      const primaryFn = jest.fn(async () => ({ data: "primary" }));
      const fallbackFn = jest.fn(async () => ({ data: "fallback" }));

      service.registerService("test-service", {
        fallback: fallbackFn,
      });

      const result = await service.executeWithFallback(
        "test-service",
        primaryFn,
      );

      expect(result).toEqual({ data: "primary" });
      expect(primaryFn).toHaveBeenCalled();
      expect(fallbackFn).not.toHaveBeenCalled();
    });

    it("should execute fallback function when primary fails", async () => {
      const primaryFn = jest.fn(async () => {
        throw new Error("Primary function failed");
      });
      const fallbackFn = jest.fn(async () => ({ data: "fallback" }));

      service.registerService("test-service", {
        fallback: fallbackFn,
      });

      const result = await service.executeWithFallback(
        "test-service",
        primaryFn,
      );

      expect(result).toEqual({ data: "fallback" });
      expect(primaryFn).toHaveBeenCalled();
      expect(fallbackFn).toHaveBeenCalled();
    });

    it("should mark service as degraded when primary fails", async () => {
      const primaryFn = jest.fn(async () => {
        throw new Error("Connection timeout");
      });
      const fallbackFn = jest.fn(async () => ({ data: "fallback" }));

      service.registerService("test-service", {
        fallback: fallbackFn,
      });

      await service.executeWithFallback("test-service", primaryFn);

      const status = service.getStatus("test-service");
      expect(status.isDegraded).toBe(true);
      expect(status.reason).toBe("Connection timeout");
    });

    it("should mark service as recovered when primary succeeds after degradation", async () => {
      let shouldFail = true;
      const primaryFn = jest.fn(async () => {
        if (shouldFail) {
          throw new Error("Temporary failure");
        }
        return { data: "primary" };
      });
      const fallbackFn = jest.fn(async () => ({ data: "fallback" }));

      service.registerService("test-service", {
        fallback: fallbackFn,
      });

      // First call fails
      await service.executeWithFallback("test-service", primaryFn);
      let status = service.getStatus("test-service");
      expect(status.isDegraded).toBe(true);

      // Second call succeeds
      shouldFail = false;
      await service.executeWithFallback("test-service", primaryFn);
      status = service.getStatus("test-service");
      expect(status.isDegraded).toBe(false);
    });

    it("should throw error if fallback also fails", async () => {
      const primaryFn = jest.fn(async () => {
        throw new Error("Primary failed");
      });
      const fallbackFn = jest.fn(async () => {
        throw new Error("Fallback also failed");
      });

      service.registerService("test-service", {
        fallback: fallbackFn,
      });

      await expect(
        service.executeWithFallback("test-service", primaryFn),
      ).rejects.toThrow("Fallback also failed");
    });

    it("should pass context and arguments to functions", async () => {
      const context = { value: 42 };
      const primaryFn = jest.fn(async function (arg1, arg2) {
        return { context: this.value, args: [arg1, arg2] };
      });

      service.registerService("test-service");

      const result = await service.executeWithFallback(
        "test-service",
        primaryFn,
        context,
        ["arg1", "arg2"],
      );

      expect(result).toEqual({ context: 42, args: ["arg1", "arg2"] });
    });

    it("should track fallback usage in metrics", async () => {
      const primaryFn = jest.fn(async () => {
        throw new Error("Failed");
      });
      const fallbackFn = jest.fn(async () => ({ data: "fallback" }));

      service.registerService("test-service", {
        fallback: fallbackFn,
      });

      const metricsBefore = service.getMetrics();
      await service.executeWithFallback("test-service", primaryFn);
      const metricsAfter = service.getMetrics();

      expect(metricsAfter.fallbacksUsed).toBe(metricsBefore.fallbacksUsed + 1);
    });
  });

  describe("Critical Endpoints", () => {
    beforeEach(() => {
      service.registerService("test-service", {
        criticalEndpoints: ["/api/auth", "/api/payment"],
      });
    });

    it("should identify critical endpoints", () => {
      expect(service.isCriticalEndpoint("test-service", "/api/auth")).toBe(
        true,
      );
      expect(service.isCriticalEndpoint("test-service", "/api/payment")).toBe(
        true,
      );
      expect(service.isCriticalEndpoint("test-service", "/api/data")).toBe(
        false,
      );
    });

    it("should return false for non-existent service", () => {
      expect(service.isCriticalEndpoint("non-existent", "/api/auth")).toBe(
        false,
      );
    });
  });

  describe("Reduced Functionality", () => {
    it("should provide reduced functionality response", () => {
      service.registerService("test-service", {
        reducedFunctionality: {
          availableFeatures: ["read", "cache"],
          unavailableFeatures: ["write", "sync"],
          estimatedRecoveryTime: "5 minutes",
        },
      });

      const response = service.getReducedFunctionalityResponse(
        "test-service",
        "/api/data",
      );

      expect(response.isDegraded).toBe(true);
      expect(response.service).toBe("test-service");
      expect(response.availableFeatures).toContain("read");
      expect(response.unavailableFeatures).toContain("write");
      expect(response.estimatedRecoveryTime).toBe("5 minutes");
    });

    it("should include timestamp in reduced functionality response", () => {
      service.registerService("test-service");

      const response = service.getReducedFunctionalityResponse(
        "test-service",
        "/api/data",
      );

      expect(response.timestamp).toBeDefined();
      expect(new Date(response.timestamp)).toBeInstanceOf(Date);
    });
  });

  describe("Status Reporting", () => {
    beforeEach(() => {
      service.registerService("service-1");
      service.registerService("service-2");
      service.registerService("service-3");
    });

    it("should get status for specific service", () => {
      service.markDegraded("service-1", "Test degradation");

      const status = service.getStatus("service-1");
      expect(status.service).toBe("service-1");
      expect(status.isDegraded).toBe(true);
    });

    it("should get all statuses", () => {
      service.markDegraded("service-1", "Degradation 1");
      service.markDegraded("service-2", "Degradation 2");

      const statuses = service.getAllStatuses();
      expect(statuses).toHaveLength(3);
      expect(statuses.filter((s) => s.isDegraded)).toHaveLength(2);
    });

    it("should generate comprehensive report", () => {
      service.markDegraded("service-1", "Warning", "warning");
      service.markDegraded("service-2", "Critical", "critical");

      const report = service.getReport();

      expect(report.totalServices).toBe(3);
      expect(report.degradedServices).toBe(2);
      expect(report.healthyServices).toBe(1);
      expect(report.summary.overallStatus).toBe("degraded");
      expect(report.summary.criticalDegradations).toBe(1);
      expect(report.summary.warningDegradations).toBe(1);
    });

    it("should report healthy status when no services degraded", () => {
      const report = service.getReport();

      expect(report.summary.overallStatus).toBe("healthy");
      expect(report.degradedServices).toBe(0);
      expect(report.healthyServices).toBe(3);
    });
  });

  describe("Metrics", () => {
    beforeEach(() => {
      service.registerService("test-service");
    });

    it("should track total degradations", () => {
      const metricsBefore = service.getMetrics();

      service.markDegraded("test-service", "First");
      service.markRecovered("test-service");
      service.markDegraded("test-service", "Second");

      const metricsAfter = service.getMetrics();
      expect(metricsAfter.totalDegradations).toBe(
        metricsBefore.totalDegradations + 2,
      );
    });

    it("should track active degradations", () => {
      service.registerService("service-2");

      service.markDegraded("test-service", "Degradation 1");
      service.markDegraded("service-2", "Degradation 2");

      const metrics = service.getMetrics();
      expect(metrics.activeDegradations).toBe(2);
    });

    it("should track recoveries", () => {
      const metricsBefore = service.getMetrics();

      service.markDegraded("test-service", "Degradation");
      service.markRecovered("test-service");

      const metricsAfter = service.getMetrics();
      expect(metricsAfter.recoveries).toBe(metricsBefore.recoveries + 1);
    });

    it("should include timestamp in metrics", () => {
      const metrics = service.getMetrics();

      expect(metrics.timestamp).toBeDefined();
      expect(new Date(metrics.timestamp)).toBeInstanceOf(Date);
    });
  });

  describe("Reset Functionality", () => {
    beforeEach(() => {
      service.registerService("service-1");
      service.registerService("service-2");
    });

    it("should reset all degradation states", () => {
      service.markDegraded("service-1", "Degradation 1");
      service.markDegraded("service-2", "Degradation 2");

      service.resetAll();

      const status1 = service.getStatus("service-1");
      const status2 = service.getStatus("service-2");

      expect(status1.isDegraded).toBe(false);
      expect(status2.isDegraded).toBe(false);
    });

    it("should clear degradation start times on reset", () => {
      service.markDegraded("service-1", "Degradation");
      service.resetAll();

      const status = service.getStatus("service-1");
      expect(status.degradationStartTime).toBeNull();
    });
  });

  describe("Error Handling", () => {
    it("should handle unregistered service gracefully", () => {
      const status = service.getStatus("unregistered-service");

      expect(status.service).toBe("unregistered-service");
      expect(status.isDegraded).toBe(false);
      expect(status.status).toBe("unknown");
    });

    it("should throw error when executing with unregistered service", async () => {
      const primaryFn = jest.fn(async () => ({ data: "test" }));

      await expect(
        service.executeWithFallback("unregistered-service", primaryFn),
      ).rejects.toThrow("Service not registered");
    });

    it("should handle null fallback gracefully", async () => {
      const primaryFn = jest.fn(async () => {
        throw new Error("Primary failed");
      });

      service.registerService("test-service", {
        fallback: null,
      });

      await expect(
        service.executeWithFallback("test-service", primaryFn),
      ).rejects.toThrow("Primary failed");
    });
  });

  describe("Degradation Duration Tracking", () => {
    it("should track degradation duration", async () => {
      service.registerService("test-service");

      service.markDegraded("test-service", "Test degradation");

      // Simulate some time passing
      await new Promise((resolve) => setTimeout(resolve, 100));

      service.markRecovered("test-service");

      const status = service.getStatus("test-service");
      expect(status.degradationStartTime).toBeNull();
    });
  });

  describe("Multiple Service Scenarios", () => {
    it("should handle multiple services with different states", () => {
      service.registerService("service-1");
      service.registerService("service-2");
      service.registerService("service-3");

      service.markDegraded("service-1", "Degradation 1", "warning");
      service.markDegraded("service-2", "Degradation 2", "critical");
      // service-3 remains healthy

      const report = service.getReport();

      expect(report.degradedServices).toBe(2);
      expect(report.healthyServices).toBe(1);
      expect(report.summary.criticalDegradations).toBe(1);
      expect(report.summary.warningDegradations).toBe(1);
    });

    it("should recover services independently", () => {
      service.registerService("service-1");
      service.registerService("service-2");

      service.markDegraded("service-1", "Degradation 1");
      service.markDegraded("service-2", "Degradation 2");

      service.markRecovered("service-1");

      const status1 = service.getStatus("service-1");
      const status2 = service.getStatus("service-2");

      expect(status1.isDegraded).toBe(false);
      expect(status2.isDegraded).toBe(true);
    });
  });
});
