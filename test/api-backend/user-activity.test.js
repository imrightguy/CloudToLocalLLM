/**


 * User Activity Tracking Tests
 *
 * Tests for user activity tracking functionality:
 * - Activity logging
 * - Usage metrics tracking
 * - Activity audit logs retrieval
 * - Activity summaries
 *
 * Validates: Requirements 3.4, 3.10
 * - Tracks user activity and usage metrics
 * - Implements activity audit logs
 * - Provides user activity audit logs
 *
 * @fileoverview User activity tracking tests
 * @version 1.0.0
 */

import { describe, it, expect, beforeAll, afterAll } from "@jest/globals";
import crypto from "crypto";
import { query } from "../../services/api-backend/database/db-pool.js";
import {
  logUserActivity,
  updateUserUsageMetrics,
  getUserActivityLogs,
  getUserActivityLogsCount,
  getUserUsageMetrics,
  getUserActivitySummary,
  getAllUserActivityLogs,
  getAllUserActivityLogsCount,
  ACTIVITY_ACTIONS,
  SEVERITY_LEVELS,
} from "../../services/api-backend/services/user-activity-service.js";

describe("User Activity Tracking Service", () => {
  const testUserId = `test-user-${crypto.randomUUID()}`;
  const testIpAddress = "192.168.1.100";
  const testUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)";

  beforeAll(async () => {
    // Ensure user_activity_logs table exists
    try {
      await query(`
        CREATE TABLE IF NOT EXISTS user_activity_logs (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id TEXT NOT NULL,
          action TEXT NOT NULL,
          resource_type TEXT,
          resource_id TEXT,
          details JSONB DEFAULT '{}'::jsonb,
          ip_address INET,
          user_agent TEXT,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          severity TEXT DEFAULT 'info'
        );
        CREATE INDEX IF NOT EXISTS idx_user_activity_logs_user_id ON user_activity_logs(user_id);
        CREATE INDEX IF NOT EXISTS idx_user_activity_logs_action ON user_activity_logs(action);
        CREATE INDEX IF NOT EXISTS idx_user_activity_logs_created_at ON user_activity_logs(created_at DESC);
      `);
    } catch (error) {
      console.log(
        "[Test Setup] user_activity_logs table setup:",
        error.message,
      );
    }

    // Ensure user_usage_metrics table exists
    try {
      await query(`
        CREATE TABLE IF NOT EXISTS user_usage_metrics (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id TEXT NOT NULL UNIQUE,
          total_requests INTEGER DEFAULT 0,
          total_api_calls INTEGER DEFAULT 0,
          total_tunnels_created INTEGER DEFAULT 0,
          total_tunnels_active INTEGER DEFAULT 0,
          total_data_transferred_bytes BIGINT DEFAULT 0,
          last_activity TIMESTAMPTZ DEFAULT NOW(),
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW(),
          metadata JSONB DEFAULT '{}'::jsonb
        );
        CREATE INDEX IF NOT EXISTS idx_user_usage_metrics_user_id ON user_usage_metrics(user_id);
      `);
    } catch (error) {
      console.log(
        "[Test Setup] user_usage_metrics table setup:",
        error.message,
      );
    }

    // Ensure user_activity_summary table exists
    try {
      await query(`
        CREATE TABLE IF NOT EXISTS user_activity_summary (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id TEXT NOT NULL,
          period TEXT NOT NULL,
          period_start TIMESTAMPTZ NOT NULL,
          period_end TIMESTAMPTZ NOT NULL,
          total_actions INTEGER DEFAULT 0,
          total_api_calls INTEGER DEFAULT 0,
          total_tunnels_created INTEGER DEFAULT 0,
          total_data_transferred_bytes BIGINT DEFAULT 0,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          updated_at TIMESTAMPTZ DEFAULT NOW()
        );
        CREATE INDEX IF NOT EXISTS idx_user_activity_summary_user_id ON user_activity_summary(user_id);
      `);
    } catch (error) {
      console.log(
        "[Test Setup] user_activity_summary table setup:",
        error.message,
      );
    }
  });

  afterAll(async () => {
    // Clean up test data
    try {
      await query("DELETE FROM user_activity_logs WHERE user_id = $1", [
        testUserId,
      ]);
      await query("DELETE FROM user_usage_metrics WHERE user_id = $1", [
        testUserId,
      ]);
      await query("DELETE FROM user_activity_summary WHERE user_id = $1", [
        testUserId,
      ]);
    } catch (error) {
      // Ignore cleanup errors
    }
  });

  describe("logUserActivity", () => {
    it("should log user activity successfully", async () => {
      const action = ACTIVITY_ACTIONS.PROFILE_UPDATE;

      const result = await logUserActivity({
        userId: testUserId,
        action,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        details: {
          field: "email",
          oldValue: "old@example.com",
          newValue: "new@example.com",
        },
      });

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
      expect(result.created_at).toBeDefined();
    });

    it("should throw error when userId is missing", async () => {
      await expect(
        logUserActivity({
          action: ACTIVITY_ACTIONS.PROFILE_UPDATE,
          ipAddress: testIpAddress,
          userAgent: testUserAgent,
        }),
      ).rejects.toThrow("userId is required");
    });

    it("should throw error when action is missing", async () => {
      await expect(
        logUserActivity({
          userId: testUserId,
          ipAddress: testIpAddress,
          userAgent: testUserAgent,
        }),
      ).rejects.toThrow("action is required");
    });

    it("should throw error when ipAddress is missing", async () => {
      await expect(
        logUserActivity({
          userId: testUserId,
          action: ACTIVITY_ACTIONS.PROFILE_UPDATE,
          userAgent: testUserAgent,
        }),
      ).rejects.toThrow("ipAddress is required");
    });
  });

  describe("updateUserUsageMetrics", () => {
    it("should create new metrics record for new user", async () => {
      const newUserId = `new-user-${crypto.randomUUID()}`;

      const result = await updateUserUsageMetrics(newUserId);

      expect(result).toBeDefined();
      expect(result.user_id).toBe(newUserId);
      expect(result.total_requests).toBe(1);

      // Clean up
      await query("DELETE FROM user_usage_metrics WHERE user_id = $1", [
        newUserId,
      ]);
    });

    it("should update existing metrics record", async () => {
      // First create a metrics record
      await updateUserUsageMetrics(testUserId);

      // Update it again
      const result = await updateUserUsageMetrics(testUserId);

      expect(result).toBeDefined();
      expect(result.user_id).toBe(testUserId);
      expect(result.total_requests).toBeGreaterThan(1);
    });

    it("should throw error when userId is missing", async () => {
      await expect(updateUserUsageMetrics()).rejects.toThrow(
        "userId is required",
      );
    });
  });

  describe("getUserActivityLogs", () => {
    it("should retrieve user activity logs successfully", async () => {
      // Log some activities first
      await logUserActivity({
        userId: testUserId,
        action: ACTIVITY_ACTIONS.PROFILE_UPDATE,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
      });

      await logUserActivity({
        userId: testUserId,
        action: ACTIVITY_ACTIONS.TUNNEL_CREATE,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
      });

      const result = await getUserActivityLogs(testUserId, {
        limit: 50,
        offset: 0,
      });

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      expect(result.length).toBeGreaterThanOrEqual(2);
    });

    it("should filter logs by action", async () => {
      const action = ACTIVITY_ACTIONS.PROFILE_UPDATE;

      const result = await getUserActivityLogs(testUserId, { action });

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      if (result.length > 0) {
        expect(result[0].action).toBe(action);
      }
    });

    it("should throw error when userId is missing", async () => {
      await expect(getUserActivityLogs()).rejects.toThrow("userId is required");
    });
  });

  describe("getUserActivityLogsCount", () => {
    it("should return count of user activity logs", async () => {
      const result = await getUserActivityLogsCount(testUserId);

      expect(typeof result).toBe("number");
      expect(result).toBeGreaterThanOrEqual(0);
    });

    it("should throw error when userId is missing", async () => {
      await expect(getUserActivityLogsCount()).rejects.toThrow(
        "userId is required",
      );
    });
  });

  describe("getUserUsageMetrics", () => {
    it("should retrieve user usage metrics successfully", async () => {
      // Create metrics first
      await updateUserUsageMetrics(testUserId);

      const result = await getUserUsageMetrics(testUserId);

      expect(result).toBeDefined();
      expect(result.user_id).toBe(testUserId);
      expect(result.total_requests).toBeGreaterThanOrEqual(1);
    });

    it("should return null when no metrics found", async () => {
      const nonExistentUserId = `non-existent-${crypto.randomUUID()}`;

      const result = await getUserUsageMetrics(nonExistentUserId);

      expect(result).toBeNull();
    });

    it("should throw error when userId is missing", async () => {
      await expect(getUserUsageMetrics()).rejects.toThrow("userId is required");
    });
  });

  describe("getUserActivitySummary", () => {
    it("should retrieve user activity summary successfully", async () => {
      const period = "daily";

      const result = await getUserActivitySummary(testUserId, { period });

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it("should throw error for invalid period", async () => {
      await expect(
        getUserActivitySummary(testUserId, { period: "invalid" }),
      ).rejects.toThrow("period must be one of: daily, weekly, monthly");
    });

    it("should throw error when userId is missing", async () => {
      await expect(getUserActivitySummary()).rejects.toThrow(
        "userId is required",
      );
    });
  });

  describe("getAllUserActivityLogs", () => {
    it("should retrieve all user activity logs for admin", async () => {
      const result = await getAllUserActivityLogs({ limit: 100, offset: 0 });

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
    });

    it("should filter logs by action", async () => {
      const action = ACTIVITY_ACTIONS.PROFILE_UPDATE;

      const result = await getAllUserActivityLogs({ action });

      expect(result).toBeDefined();
      expect(Array.isArray(result)).toBe(true);
      if (result.length > 0) {
        expect(result[0].action).toBe(action);
      }
    });
  });

  describe("getAllUserActivityLogsCount", () => {
    it("should return count of all user activity logs", async () => {
      const result = await getAllUserActivityLogsCount();

      expect(typeof result).toBe("number");
      expect(result).toBeGreaterThanOrEqual(0);
    });
  });

  describe("Activity Actions Constants", () => {
    it("should have all required activity action types", () => {
      expect(ACTIVITY_ACTIONS.PROFILE_VIEW).toBe("profile_view");
      expect(ACTIVITY_ACTIONS.PROFILE_UPDATE).toBe("profile_update");
      expect(ACTIVITY_ACTIONS.TUNNEL_CREATE).toBe("tunnel_create");
      expect(ACTIVITY_ACTIONS.TUNNEL_START).toBe("tunnel_start");
      expect(ACTIVITY_ACTIONS.API_KEY_CREATE).toBe("api_key_create");
      expect(ACTIVITY_ACTIONS.SESSION_CREATE).toBe("session_create");
      expect(ACTIVITY_ACTIONS.ADMIN_USER_VIEW).toBe("admin_user_view");
    });
  });

  describe("Severity Levels Constants", () => {
    it("should have all required severity levels", () => {
      expect(SEVERITY_LEVELS.DEBUG).toBe("debug");
      expect(SEVERITY_LEVELS.INFO).toBe("info");
      expect(SEVERITY_LEVELS.WARN).toBe("warn");
      expect(SEVERITY_LEVELS.ERROR).toBe("error");
      expect(SEVERITY_LEVELS.CRITICAL).toBe("critical");
    });
  });
});
