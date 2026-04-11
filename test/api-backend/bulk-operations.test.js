/**
 * Bulk Operations Tests
 *
 * Tests for bulk user management operations:
 * - Bulk tier updates
 * - Bulk user suspension/reactivation
 * - Bulk user deletion
 * - Operation tracking and status
 */

import { describe, it, expect, beforeEach } from "@jest/globals";
import { bulkOperationsService } from "../../services/api-backend/services/bulk-operations-service.js";

describe("Bulk Operations Service", () => {
  beforeEach(() => {
    // Clear operations before each test
    bulkOperationsService.operations.clear();
  });

  describe("createBulkOperation", () => {
    it("should create a bulk tier update operation", async () => {
      const userIds = ["user-1", "user-2", "user-3"];
      const operationData = { tier: "premium" };

      const operation = await bulkOperationsService.createBulkOperation(
        "tier_update",
        userIds,
        operationData,
      );

      expect(operation).toHaveProperty("operationId");
      expect(operation.status).toBe("pending");
      expect(operation.totalUsers).toBe(3);
    });

    it("should create a bulk suspend operation", async () => {
      const userIds = ["user-1", "user-2"];
      const operationData = { reason: "Violation of terms" };

      const operation = await bulkOperationsService.createBulkOperation(
        "suspend",
        userIds,
        operationData,
      );

      expect(operation).toHaveProperty("operationId");
      expect(operation.status).toBe("pending");
      expect(operation.totalUsers).toBe(2);
    });

    it("should reject invalid operation type", async () => {
      const userIds = ["user-1"];
      const operationData = {};

      await expect(
        bulkOperationsService.createBulkOperation(
          "invalid_type",
          userIds,
          operationData,
        ),
      ).rejects.toThrow("Invalid operation type");
    });

    it("should reject empty user IDs array", async () => {
      const userIds = [];
      const operationData = { tier: "premium" };

      await expect(
        bulkOperationsService.createBulkOperation(
          "tier_update",
          userIds,
          operationData,
        ),
      ).rejects.toThrow("User IDs must be a non-empty array");
    });

    it("should reject more than 1000 users", async () => {
      const userIds = Array.from({ length: 1001 }, (_, i) => `user-${i}`);
      const operationData = { tier: "premium" };

      await expect(
        bulkOperationsService.createBulkOperation(
          "tier_update",
          userIds,
          operationData,
        ),
      ).rejects.toThrow("Maximum 1000 users per bulk operation");
    });

    it("should reject invalid tier for tier_update", async () => {
      const userIds = ["user-1"];
      const operationData = { tier: "invalid_tier" };

      await expect(
        bulkOperationsService.createBulkOperation(
          "tier_update",
          userIds,
          operationData,
        ),
      ).rejects.toThrow("Invalid subscription tier");
    });

    it("should reject suspend without reason", async () => {
      const userIds = ["user-1"];
      const operationData = {};

      await expect(
        bulkOperationsService.createBulkOperation(
          "suspend",
          userIds,
          operationData,
        ),
      ).rejects.toThrow("Suspension reason is required");
    });
  });

  describe("getOperationStatus", () => {
    it("should return operation status", async () => {
      const userIds = ["user-1", "user-2"];
      const operationData = { tier: "premium" };

      const operation = await bulkOperationsService.createBulkOperation(
        "tier_update",
        userIds,
        operationData,
      );

      const status = bulkOperationsService.getOperationStatus(
        operation.operationId,
      );

      expect(status).toHaveProperty("operationId");
      expect(status.status).toBe("pending");
      expect(status.totalUsers).toBe(2);
      expect(status.processedUsers).toBe(0);
      expect(status.progress).toBe(0);
    });

    it("should return null for non-existent operation", () => {
      const status =
        bulkOperationsService.getOperationStatus("non-existent-id");
      expect(status).toBeNull();
    });

    it("should calculate progress correctly", async () => {
      const userIds = ["user-1", "user-2", "user-3", "user-4"];
      const operationData = { tier: "premium" };

      const operation = await bulkOperationsService.createBulkOperation(
        "tier_update",
        userIds,
        operationData,
      );

      // Simulate progress
      const op = bulkOperationsService.operations.get(operation.operationId);
      op.processedUsers = 2;

      const status = bulkOperationsService.getOperationStatus(
        operation.operationId,
      );

      expect(status.progress).toBe(50);
    });
  });

  describe("getOperationHistory", () => {
    it("should return operation history", async () => {
      const userIds = ["user-1"];
      const operationData = { tier: "premium" };

      await bulkOperationsService.createBulkOperation(
        "tier_update",
        userIds,
        operationData,
      );

      await bulkOperationsService.createBulkOperation("suspend", userIds, {
        reason: "Test",
      });

      const history = bulkOperationsService.getOperationHistory();

      expect(history).toHaveLength(2);
      expect(history[0]).toHaveProperty("operationId");
      expect(history[0]).toHaveProperty("type");
      expect(history[0]).toHaveProperty("status");
    });

    it("should respect limit parameter", async () => {
      const userIds = ["user-1"];
      const operationData = { tier: "premium" };

      for (let i = 0; i < 5; i++) {
        await bulkOperationsService.createBulkOperation(
          "tier_update",
          userIds,
          operationData,
        );
      }

      const history = bulkOperationsService.getOperationHistory(3);

      expect(history).toHaveLength(3);
    });

    it("should sort by creation date descending", async () => {
      const userIds = ["user-1"];
      const operationData = { tier: "premium" };

      const op1 = await bulkOperationsService.createBulkOperation(
        "tier_update",
        userIds,
        operationData,
      );

      // Small delay to ensure different timestamps
      await new Promise((resolve) => setTimeout(resolve, 10));

      const op2 = await bulkOperationsService.createBulkOperation(
        "suspend",
        userIds,
        { reason: "Test" },
      );

      const history = bulkOperationsService.getOperationHistory();

      expect(history[0].operationId).toBe(op2.operationId);
      expect(history[1].operationId).toBe(op1.operationId);
    });
  });

  describe("Operation state transitions", () => {
    it("should prevent execution of non-pending operation", async () => {
      const userIds = ["user-1"];
      const operationData = { tier: "premium" };

      const operation = await bulkOperationsService.createBulkOperation(
        "tier_update",
        userIds,
        operationData,
      );

      // Manually set status to completed
      const op = bulkOperationsService.operations.get(operation.operationId);
      op.status = "completed";

      await expect(
        bulkOperationsService.executeBulkOperation(
          operation.operationId,
          "admin-1",
          "admin",
        ),
      ).rejects.toThrow("Operation is already completed");
    });

    it("should handle operation not found", async () => {
      await expect(
        bulkOperationsService.executeBulkOperation(
          "non-existent-id",
          "admin-1",
          "admin",
        ),
      ).rejects.toThrow("Operation not found");
    });
  });

  describe("Bulk operation validation", () => {
    it("should validate tier values", async () => {
      const validTiers = ["free", "premium", "enterprise"];

      for (const tier of validTiers) {
        const operation = await bulkOperationsService.createBulkOperation(
          "tier_update",
          ["user-1"],
          { tier },
        );

        expect(operation).toHaveProperty("operationId");
      }
    });

    it("should validate operation types", async () => {
      const validTypes = ["tier_update", "suspend", "reactivate", "delete"];

      for (const type of validTypes) {
        let operationData = {};

        if (type === "tier_update") {
          operationData = { tier: "premium" };
        } else if (type === "suspend") {
          operationData = { reason: "Test" };
        }

        const operation = await bulkOperationsService.createBulkOperation(
          type,
          ["user-1"],
          operationData,
        );

        expect(operation).toHaveProperty("operationId");
      }
    });
  });

  describe("Bulk operation data integrity", () => {
    it("should preserve operation data", async () => {
      const userIds = ["user-1", "user-2", "user-3"];
      const operationData = { tier: "enterprise" };

      const operation = await bulkOperationsService.createBulkOperation(
        "tier_update",
        userIds,
        operationData,
      );

      const op = bulkOperationsService.operations.get(operation.operationId);

      expect(op.userIds).toEqual(userIds);
      expect(op.operationData).toEqual(operationData);
      expect(op.type).toBe("tier_update");
    });

    it("should track operation timestamps", async () => {
      const userIds = ["user-1"];
      const operationData = { tier: "premium" };

      const operation = await bulkOperationsService.createBulkOperation(
        "tier_update",
        userIds,
        operationData,
      );

      const op = bulkOperationsService.operations.get(operation.operationId);

      expect(op.createdAt).toBeInstanceOf(Date);
      expect(op.startedAt).toBeNull();
      expect(op.completedAt).toBeNull();
    });
  });
});
