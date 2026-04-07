/**


 * User Deletion API Tests
 *
 * Tests for user account deletion endpoints:
 * - DELETE /api/users/:id - Delete user account (hard or soft delete)
 * - POST /api/users/:id/restore - Restore soft-deleted account
 * - GET /api/users/:id/deletion-status - Check deletion status
 * - POST /api/users/:id/permanent-delete - Permanently delete account (admin)
 *
 * Validates: Requirements 3.5
 * - Supports user account deletion with data cleanup
 * - Implements cascading data cleanup (sessions, tunnels, audit logs)
 * - Adds soft delete option for compliance
 *
 * @fileoverview User deletion endpoint tests
 * @version 1.0.0
 */

import {
  jest,
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
} from "@jest/globals";
import { UserDeletionService } from "../../services/api-backend/services/user-deletion-service.js";

describe("UserDeletionService", () => {
  let userDeletionService;
  let mockPool;
  let mockClient;

  beforeEach(() => {
    // Create mock client
    mockClient = {
      query: jest.fn(),
      release: jest.fn(),
    };

    // Create mock pool
    mockPool = {
      query: jest.fn(),
      connect: jest.fn().mockResolvedValue(mockClient),
    };

    userDeletionService = new UserDeletionService();
    userDeletionService.pool = mockPool;
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe("deleteUserAccount - Soft Delete", () => {
    it("should soft delete user account successfully", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";
      const reason = "User requested deletion";

      // Setup mock sequence for soft delete
      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 1 }) // UPDATE user (soft delete)
        .mockResolvedValueOnce(undefined); // COMMIT

      const result = await userDeletionService.deleteUserAccount(userId, {
        softDelete: true,
        reason,
      });

      expect(result.success).toBe(true);
      expect(result.userId).toBe(userId);
      expect(result.deletionType).toBe("soft");
      expect(result.cleanupStats.userDeleted).toBe(true);
    });

    it("should include deletion reason in metadata", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";
      const reason = "Account no longer needed";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 1 }) // UPDATE user
        .mockResolvedValueOnce(undefined); // COMMIT

      await userDeletionService.deleteUserAccount(userId, {
        softDelete: true,
        reason,
      });

      // Verify the soft delete query includes the reason
      const updateCall = mockClient.query.mock.calls[2];
      expect(updateCall[0]).toContain("UPDATE users");
      expect(updateCall[1]).toContain(reason);
    });

    it("should rollback on error during soft delete", async () => {
      const userId = "jwt|123456";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: "user-uuid-1" }] }) // SELECT user
        .mockRejectedValueOnce(new Error("Database error")); // UPDATE user fails

      await expect(
        userDeletionService.deleteUserAccount(userId, { softDelete: true }),
      ).rejects.toThrow("Database error");

      expect(mockClient.query).toHaveBeenCalledWith("ROLLBACK");
    });

    it("should throw error when user not found", async () => {
      const userId = "jwt|nonexistent";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [] }); // SELECT user returns empty

      await expect(
        userDeletionService.deleteUserAccount(userId, { softDelete: true }),
      ).rejects.toThrow("User not found");
    });

    it("should throw error for invalid user ID", async () => {
      await expect(
        userDeletionService.deleteUserAccount(null, { softDelete: true }),
      ).rejects.toThrow("Invalid user ID");

      await expect(
        userDeletionService.deleteUserAccount("", { softDelete: true }),
      ).rejects.toThrow("Invalid user ID");
    });
  });

  describe("deleteUserAccount - Hard Delete", () => {
    it("should hard delete user account with cascading cleanup", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 2 }) // DELETE sessions
        .mockResolvedValueOnce({ rowCount: 3 }) // DELETE tunnels
        .mockResolvedValueOnce({ rowCount: 5 }) // DELETE audit logs
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE api usage
        .mockResolvedValueOnce({ rowCount: 4 }) // DELETE messages
        .mockResolvedValueOnce({ rowCount: 2 }) // DELETE conversations
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE preferences
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE user
        .mockResolvedValueOnce(undefined); // COMMIT

      const result = await userDeletionService.deleteUserAccount(userId, {
        softDelete: false,
      });

      expect(result.success).toBe(true);
      expect(result.userId).toBe(userId);
      expect(result.deletionType).toBe("hard");
      expect(result.cleanupStats.sessionsDeleted).toBe(2);
      expect(result.cleanupStats.tunnelsDeleted).toBe(3);
      expect(result.cleanupStats.auditLogsDeleted).toBe(5);
      expect(result.cleanupStats.apiUsageDeleted).toBe(1);
      expect(result.cleanupStats.messagesDeleted).toBe(4);
      expect(result.cleanupStats.conversationsDeleted).toBe(2);
      expect(result.cleanupStats.preferencesDeleted).toBe(1);
      expect(result.cleanupStats.userDeleted).toBe(true);
    });

    it("should handle zero records deleted gracefully", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 0 }) // DELETE sessions
        .mockResolvedValueOnce({ rowCount: 0 }) // DELETE tunnels
        .mockResolvedValueOnce({ rowCount: 0 }) // DELETE audit logs
        .mockResolvedValueOnce({ rowCount: 0 }) // DELETE api usage
        .mockResolvedValueOnce({ rowCount: 0 }) // DELETE messages
        .mockResolvedValueOnce({ rowCount: 0 }) // DELETE conversations
        .mockResolvedValueOnce({ rowCount: 0 }) // DELETE preferences
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE user
        .mockResolvedValueOnce(undefined); // COMMIT

      const result = await userDeletionService.deleteUserAccount(userId, {
        softDelete: false,
      });

      expect(result.success).toBe(true);
      expect(result.cleanupStats.sessionsDeleted).toBe(0);
      expect(result.cleanupStats.userDeleted).toBe(true);
    });

    it("should rollback on error during hard delete", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 2 }) // DELETE sessions
        .mockRejectedValueOnce(new Error("Database error")); // DELETE tunnels fails

      await expect(
        userDeletionService.deleteUserAccount(userId, { softDelete: false }),
      ).rejects.toThrow("Database error");

      expect(mockClient.query).toHaveBeenCalledWith("ROLLBACK");
    });
  });

  describe("restoreUserAccount", () => {
    it("should restore soft-deleted user account", async () => {
      const userId = "jwt|123456";

      mockPool.query.mockResolvedValueOnce({
        rows: [{ id: "user-uuid-1" }],
      });

      const result = await userDeletionService.restoreUserAccount(userId);

      expect(result.success).toBe(true);
      expect(result.userId).toBe(userId);
      expect(result.message).toBe("User account restored successfully");
    });

    it("should throw error when user not found or not deleted", async () => {
      const userId = "jwt|nonexistent";

      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(
        userDeletionService.restoreUserAccount(userId),
      ).rejects.toThrow("User not found or not soft-deleted");
    });

    it("should throw error for invalid user ID", async () => {
      await expect(
        userDeletionService.restoreUserAccount(null),
      ).rejects.toThrow("Invalid user ID");

      await expect(userDeletionService.restoreUserAccount("")).rejects.toThrow(
        "Invalid user ID",
      );
    });
  });

  describe("isUserDeleted", () => {
    it("should return true for deleted user", async () => {
      const userId = "jwt|123456";

      mockPool.query.mockResolvedValueOnce({
        rows: [{ is_deleted: "true" }],
      });

      const result = await userDeletionService.isUserDeleted(userId);

      expect(result).toBe(true);
    });

    it("should return false for active user", async () => {
      const userId = "jwt|123456";

      mockPool.query.mockResolvedValueOnce({
        rows: [{ is_deleted: "false" }],
      });

      const result = await userDeletionService.isUserDeleted(userId);

      expect(result).toBe(false);
    });

    it("should throw error when user not found", async () => {
      const userId = "jwt|nonexistent";

      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(userDeletionService.isUserDeleted(userId)).rejects.toThrow(
        "User not found",
      );
    });

    it("should throw error for invalid user ID", async () => {
      await expect(userDeletionService.isUserDeleted(null)).rejects.toThrow(
        "Invalid user ID",
      );
    });
  });

  describe("getDeletionInfo", () => {
    it("should retrieve deletion information for deleted user", async () => {
      const userId = "jwt|123456";
      const deletedAt = "2024-01-15T10:30:00Z";
      const reason = "User requested deletion";

      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            deleted_at: deletedAt,
            deletion_reason: reason,
            is_deleted: "true",
          },
        ],
      });

      const result = await userDeletionService.getDeletionInfo(userId);

      expect(result.userId).toBe(userId);
      expect(result.deletedAt).toBe(deletedAt);
      expect(result.deletionReason).toBe(reason);
      expect(result.isDeleted).toBe(true);
    });

    it("should throw error for non-deleted user", async () => {
      const userId = "jwt|123456";

      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            deleted_at: null,
            deletion_reason: null,
            is_deleted: "false",
          },
        ],
      });

      await expect(userDeletionService.getDeletionInfo(userId)).rejects.toThrow(
        "User is not deleted",
      );
    });

    it("should throw error when user not found", async () => {
      const userId = "jwt|nonexistent";

      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(userDeletionService.getDeletionInfo(userId)).rejects.toThrow(
        "User not found",
      );
    });

    it("should throw error for invalid user ID", async () => {
      await expect(userDeletionService.getDeletionInfo(null)).rejects.toThrow(
        "Invalid user ID",
      );
    });
  });

  describe("permanentlyDeleteUser", () => {
    it("should permanently delete user with all related data", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 2 }) // DELETE sessions
        .mockResolvedValueOnce({ rowCount: 3 }) // DELETE tunnels
        .mockResolvedValueOnce({ rowCount: 5 }) // DELETE audit logs
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE api usage
        .mockResolvedValueOnce({ rowCount: 4 }) // DELETE messages
        .mockResolvedValueOnce({ rowCount: 2 }) // DELETE conversations
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE preferences
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE user
        .mockResolvedValueOnce(undefined); // COMMIT

      const result = await userDeletionService.permanentlyDeleteUser(userId);

      expect(result.success).toBe(true);
      expect(result.userId).toBe(userId);
      expect(result.deletionType).toBe("permanent");
      expect(result.cleanupStats.userDeleted).toBe(true);
    });

    it("should rollback on error during permanent deletion", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 2 }) // DELETE sessions
        .mockRejectedValueOnce(new Error("Database error")); // DELETE tunnels fails

      await expect(
        userDeletionService.permanentlyDeleteUser(userId),
      ).rejects.toThrow("Database error");

      expect(mockClient.query).toHaveBeenCalledWith("ROLLBACK");
    });

    it("should throw error when user not found", async () => {
      const userId = "jwt|nonexistent";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [] }); // SELECT user returns empty

      await expect(
        userDeletionService.permanentlyDeleteUser(userId),
      ).rejects.toThrow("User not found");
    });

    it("should throw error for invalid user ID", async () => {
      await expect(
        userDeletionService.permanentlyDeleteUser(null),
      ).rejects.toThrow("Invalid user ID");
    });
  });

  describe("Cascading Cleanup Verification", () => {
    it("should delete all related data in correct order", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE sessions
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE tunnels
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE audit logs
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE api usage
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE messages
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE conversations
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE preferences
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE user
        .mockResolvedValueOnce(undefined); // COMMIT

      await userDeletionService.deleteUserAccount(userId, {
        softDelete: false,
      });

      // Verify deletion order
      const calls = mockClient.query.mock.calls;
      const deleteQueries = calls.filter((call) => call[0].includes("DELETE"));

      expect(deleteQueries.length).toBeGreaterThanOrEqual(7);
      expect(deleteQueries[0][0]).toContain("user_sessions");
      expect(deleteQueries[1][0]).toContain("tunnel_connections");
      expect(deleteQueries[2][0]).toContain("audit_logs");
      expect(deleteQueries[3][0]).toContain("api_usage");
      expect(deleteQueries[4][0]).toContain("messages");
      expect(deleteQueries[5][0]).toContain("conversations");
      expect(deleteQueries[6][0]).toContain("user_preferences");
    });

    it("should track cleanup statistics accurately", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 5 }) // DELETE sessions
        .mockResolvedValueOnce({ rowCount: 10 }) // DELETE tunnels
        .mockResolvedValueOnce({ rowCount: 20 }) // DELETE audit logs
        .mockResolvedValueOnce({ rowCount: 3 }) // DELETE api usage
        .mockResolvedValueOnce({ rowCount: 15 }) // DELETE messages
        .mockResolvedValueOnce({ rowCount: 8 }) // DELETE conversations
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE preferences
        .mockResolvedValueOnce({ rowCount: 1 }) // DELETE user
        .mockResolvedValueOnce(undefined); // COMMIT

      const result = await userDeletionService.deleteUserAccount(userId, {
        softDelete: false,
      });

      expect(result.cleanupStats.sessionsDeleted).toBe(5);
      expect(result.cleanupStats.tunnelsDeleted).toBe(10);
      expect(result.cleanupStats.auditLogsDeleted).toBe(20);
      expect(result.cleanupStats.apiUsageDeleted).toBe(3);
      expect(result.cleanupStats.messagesDeleted).toBe(15);
      expect(result.cleanupStats.conversationsDeleted).toBe(8);
      expect(result.cleanupStats.preferencesDeleted).toBe(1);
      expect(result.cleanupStats.userDeleted).toBe(true);
    });
  });

  describe("Default Options", () => {
    it("should default to soft delete when not specified", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 1 }) // UPDATE user
        .mockResolvedValueOnce(undefined); // COMMIT

      const result = await userDeletionService.deleteUserAccount(userId);

      expect(result.deletionType).toBe("soft");
    });

    it("should use default reason when not provided", async () => {
      const userId = "jwt|123456";
      const userUuid = "user-uuid-1";

      mockClient.query
        .mockResolvedValueOnce(undefined) // BEGIN
        .mockResolvedValueOnce({ rows: [{ id: userUuid }] }) // SELECT user
        .mockResolvedValueOnce({ rowCount: 1 }) // UPDATE user
        .mockResolvedValueOnce(undefined); // COMMIT

      await userDeletionService.deleteUserAccount(userId, { softDelete: true });

      const updateCall = mockClient.query.mock.calls[2];
      expect(updateCall[1]).toContain("User requested deletion");
    });
  });
});
