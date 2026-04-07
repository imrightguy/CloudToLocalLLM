/**
 * Error Recovery Service Unit Tests
 *
 * Tests for error recovery procedures and recovery status reporting.
 * Validates that recovery procedures can be registered, executed, and monitored.
 *
 * Requirement 7.7: THE API SHALL provide error recovery endpoints for manual intervention
 */

import {
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
  jest,
} from "@jest/globals";
import { ErrorRecoveryService } from "../../services/api-backend/services/error-recovery-service.js";

describe("ErrorRecoveryService", () => {
  let service;

  beforeEach(() => {
    service = new ErrorRecoveryService();
  });

  afterEach(() => {
    service.clearHistory();
    service.resetMetrics();
  });

  describe("registerRecoveryProcedure", () => {
    it("should register a recovery procedure for a service", () => {
      const procedure = jest.fn().mockResolvedValue({ status: "recovered" });

      service.registerRecoveryProcedure("test-service", {
        procedure,
        description: "Test recovery procedure",
        prerequisites: ["check-db"],
      });

      const status = service.getRecoveryStatus("test-service");
      expect(status.service).toBe("test-service");
      expect(status.description).toBe("Test recovery procedure");
    });

    it("should throw error if service name is missing", () => {
      expect(() => {
        service.registerRecoveryProcedure(null, {
          procedure: () => {},
        });
      }).toThrow("Service name is required");
    });

    it("should throw error if procedure function is missing", () => {
      expect(() => {
        service.registerRecoveryProcedure("test-service", {
          description: "Test",
        });
      }).toThrow("Recovery procedure function is required");
    });

    it("should initialize recovery status for registered service", () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("test-service", { procedure });

      const status = service.getRecoveryStatus("test-service");
      expect(status.isRecovering).toBe(false);
      expect(status.recoveryCount).toBe(0);
      expect(status.successCount).toBe(0);
      expect(status.failureCount).toBe(0);
    });
  });

  describe("executeRecovery", () => {
    it("should execute a recovery procedure successfully", async () => {
      const procedure = jest.fn().mockResolvedValue({ status: "recovered" });

      service.registerRecoveryProcedure("test-service", { procedure });

      const result = await service.executeRecovery("test-service", {
        initiatedBy: "admin-user",
        reason: "Manual intervention",
      });

      expect(result.status).toBe("success");
      expect(result.service).toBe("test-service");
      expect(result.duration).toBeGreaterThanOrEqual(0);
      expect(procedure).toHaveBeenCalled();
    });

    it("should increment success count on successful recovery", async () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("test-service", { procedure });

      await service.executeRecovery("test-service");

      const status = service.getRecoveryStatus("test-service");
      expect(status.successCount).toBe(1);
      expect(status.recoveryCount).toBe(1);
    });

    it("should handle recovery procedure failure", async () => {
      const error = new Error("Recovery failed");
      const procedure = jest.fn().mockRejectedValue(error);

      service.registerRecoveryProcedure("test-service", { procedure });

      await expect(service.executeRecovery("test-service")).rejects.toThrow(
        "Recovery failed",
      );

      const status = service.getRecoveryStatus("test-service");
      expect(status.failureCount).toBe(1);
      expect(status.recoveryCount).toBe(1);
    });

    it("should prevent concurrent recovery attempts", async () => {
      const procedure = jest
        .fn()
        .mockImplementation(
          () => new Promise((resolve) => setTimeout(resolve, 100)),
        );

      service.registerRecoveryProcedure("test-service", { procedure });

      // Start first recovery
      const promise1 = service.executeRecovery("test-service");

      // Try to start second recovery immediately
      await expect(service.executeRecovery("test-service")).rejects.toThrow(
        "Recovery already in progress",
      );

      // Wait for first recovery to complete
      await promise1;
    });

    it("should throw error if no recovery procedure registered", async () => {
      await expect(service.executeRecovery("unknown-service")).rejects.toThrow(
        "No recovery procedure registered",
      );
    });

    it("should timeout if recovery procedure takes too long", async () => {
      const procedure = jest
        .fn()
        .mockImplementation(
          () => new Promise((resolve) => setTimeout(resolve, 5000)),
        );

      service.registerRecoveryProcedure("test-service", {
        procedure,
        timeoutMs: 100,
      });

      await expect(service.executeRecovery("test-service")).rejects.toThrow(
        "timeout",
      );
    });

    it("should track recovery history", async () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("test-service", { procedure });

      await service.executeRecovery("test-service", {
        initiatedBy: "admin-user",
        reason: "Test recovery",
      });

      const history = service.getRecoveryHistory();
      expect(history.length).toBe(1);
      expect(history[0].serviceName).toBe("test-service");
      expect(history[0].status).toBe("success");
      expect(history[0].initiatedBy).toBe("admin-user");
      expect(history[0].reason).toBe("Test recovery");
    });

    it("should update metrics on successful recovery", async () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("test-service", { procedure });

      await service.executeRecovery("test-service");

      const metrics = service.getMetrics();
      expect(metrics.totalRecoveryAttempts).toBe(1);
      expect(metrics.successfulRecoveries).toBe(1);
      expect(metrics.failedRecoveries).toBe(0);
    });

    it("should update metrics on failed recovery", async () => {
      const procedure = jest.fn().mockRejectedValue(new Error("Failed"));

      service.registerRecoveryProcedure("test-service", { procedure });

      try {
        await service.executeRecovery("test-service");
      } catch (e) {
        // Expected
      }

      const metrics = service.getMetrics();
      expect(metrics.totalRecoveryAttempts).toBe(1);
      expect(metrics.successfulRecoveries).toBe(0);
      expect(metrics.failedRecoveries).toBe(1);
    });
  });

  describe("getRecoveryStatus", () => {
    it("should return status for registered service", () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("test-service", {
        procedure,
        description: "Test procedure",
      });

      const status = service.getRecoveryStatus("test-service");
      expect(status.service).toBe("test-service");
      expect(status.description).toBe("Test procedure");
      expect(status.isRecovering).toBe(false);
    });

    it("should return unknown status for unregistered service", () => {
      const status = service.getRecoveryStatus("unknown-service");
      expect(status.status).toBe("unknown");
    });

    it("should calculate success rate correctly", async () => {
      const procedure = jest
        .fn()
        .mockResolvedValueOnce({})
        .mockRejectedValueOnce(new Error("Failed"))
        .mockResolvedValueOnce({});

      service.registerRecoveryProcedure("test-service", { procedure });

      await service.executeRecovery("test-service");
      try {
        await service.executeRecovery("test-service");
      } catch (e) {
        // Expected
      }
      await service.executeRecovery("test-service");

      const status = service.getRecoveryStatus("test-service");
      expect(status.successRate).toBe("66.67%");
    });
  });

  describe("getRecoveryHistory", () => {
    it("should return empty history initially", () => {
      const history = service.getRecoveryHistory();
      expect(history).toEqual([]);
    });

    it("should filter history by service name", async () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("service-1", { procedure });
      service.registerRecoveryProcedure("service-2", { procedure });

      await service.executeRecovery("service-1");
      await service.executeRecovery("service-2");

      const history = service.getRecoveryHistory({ serviceName: "service-1" });
      expect(history.length).toBe(1);
      expect(history[0].serviceName).toBe("service-1");
    });

    it("should filter history by status", async () => {
      const successProcedure = jest.fn().mockResolvedValue({});
      const failProcedure = jest.fn().mockRejectedValue(new Error("Failed"));

      service.registerRecoveryProcedure("service-1", {
        procedure: successProcedure,
      });
      service.registerRecoveryProcedure("service-2", {
        procedure: failProcedure,
      });

      await service.executeRecovery("service-1");
      try {
        await service.executeRecovery("service-2");
      } catch (e) {
        // Expected
      }

      const successHistory = service.getRecoveryHistory({ status: "success" });
      expect(successHistory.length).toBe(1);
      expect(successHistory[0].status).toBe("success");

      const failHistory = service.getRecoveryHistory({ status: "failed" });
      expect(failHistory.length).toBe(1);
      expect(failHistory[0].status).toBe("failed");
    });

    it("should limit history results", async () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("test-service", { procedure });

      for (let i = 0; i < 5; i++) {
        await service.executeRecovery("test-service");
      }

      const history = service.getRecoveryHistory({ limit: 2 });
      expect(history.length).toBe(2);
    });
  });

  describe("getMetrics", () => {
    it("should return initial metrics", () => {
      const metrics = service.getMetrics();
      expect(metrics.totalRecoveryAttempts).toBe(0);
      expect(metrics.successfulRecoveries).toBe(0);
      expect(metrics.failedRecoveries).toBe(0);
      expect(metrics.averageRecoveryTime).toBe(0);
    });

    it("should calculate average recovery time", async () => {
      const procedure = jest
        .fn()
        .mockImplementation(
          () => new Promise((resolve) => setTimeout(resolve, 50)),
        );

      service.registerRecoveryProcedure("test-service", { procedure });

      await service.executeRecovery("test-service");
      await service.executeRecovery("test-service");

      const metrics = service.getMetrics();
      expect(metrics.averageRecoveryTime).toBeGreaterThan(0);
      expect(metrics.averageRecoveryTime).toBeLessThan(200);
    });
  });

  describe("getReport", () => {
    it("should generate comprehensive recovery report", async () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("service-1", { procedure });
      service.registerRecoveryProcedure("service-2", { procedure });

      await service.executeRecovery("service-1");

      const report = service.getReport();
      expect(report.summary.totalServices).toBe(2);
      expect(report.summary.totalRecoveryAttempts).toBe(1);
      expect(report.summary.successfulRecoveries).toBe(1);
      expect(report.services.length).toBe(2);
    });

    it("should include recent history in report", async () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("test-service", { procedure });

      await service.executeRecovery("test-service");

      const report = service.getReport();
      expect(report.recentHistory.length).toBeGreaterThan(0);
    });
  });

  describe("clearHistory", () => {
    it("should clear recovery history", async () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("test-service", { procedure });

      await service.executeRecovery("test-service");

      let history = service.getRecoveryHistory();
      expect(history.length).toBe(1);

      service.clearHistory();

      history = service.getRecoveryHistory();
      expect(history.length).toBe(0);
    });
  });

  describe("resetMetrics", () => {
    it("should reset all metrics", async () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("test-service", { procedure });

      await service.executeRecovery("test-service");

      let metrics = service.getMetrics();
      expect(metrics.totalRecoveryAttempts).toBe(1);

      service.resetMetrics();

      metrics = service.getMetrics();
      expect(metrics.totalRecoveryAttempts).toBe(0);
      expect(metrics.successfulRecoveries).toBe(0);
      expect(metrics.failedRecoveries).toBe(0);
    });
  });

  describe("getAllRecoveryStatuses", () => {
    it("should return statuses for all registered services", () => {
      const procedure = jest.fn().mockResolvedValue({});

      service.registerRecoveryProcedure("service-1", { procedure });
      service.registerRecoveryProcedure("service-2", { procedure });
      service.registerRecoveryProcedure("service-3", { procedure });

      const statuses = service.getAllRecoveryStatuses();
      expect(statuses.length).toBe(3);
      expect(statuses.map((s) => s.service)).toContain("service-1");
      expect(statuses.map((s) => s.service)).toContain("service-2");
      expect(statuses.map((s) => s.service)).toContain("service-3");
    });
  });
});
