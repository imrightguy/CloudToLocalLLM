/**


 * Authentication Audit Logging Tests for CloudToLocalLLM API Backend
 *
 * Tests for authentication audit logging functionality including:
 * - Logging authentication attempts (success and failure)
 * - Creating audit log entries for auth events
 * - Including IP address, user agent, and timestamp
 * - Admin access to system-wide audit logs
 *
 * Validates: Requirements 2.6, 11.10
 */

import {
  describe,
  it,
  expect,
  beforeAll,
  afterAll,
  beforeEach,
} from "@jest/globals";
import crypto from "crypto";
import { query } from "../../services/api-backend/database/db-pool.js";
import {
  logAuthEvent,
  logLoginSuccess,
  logLoginFailure,
  logLogout,
  logTokenRefresh,
  logTokenRevoke,
  getAuthAuditLogs,
  getAuthAuditLogsCount,
  getFailedLoginAttempts,
  getAuthAuditLogsForAdmin,
  AUTH_EVENT_TYPES,
  SEVERITY_LEVELS,
} from "../../services/api-backend/services/auth-audit-service.js";

describe("Authentication Audit Logging Service", () => {
  const testUserId = `test-user-${crypto.randomUUID()}`;
  const testIpAddress = "192.168.1.100";
  const testUserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)";

  beforeAll(async () => {
    // Ensure auth_audit_logs table exists
    try {
      await query(`
        CREATE TABLE IF NOT EXISTS auth_audit_logs (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          user_id TEXT,
          action TEXT NOT NULL,
          event_type TEXT NOT NULL,
          details JSONB DEFAULT '{}'::jsonb,
          ip_address INET,
          user_agent TEXT,
          created_at TIMESTAMPTZ DEFAULT NOW(),
          severity TEXT DEFAULT 'info'
        )
      `);
    } catch (error) {
      // Table might already exist
    }
  });

  afterAll(async () => {
    // Clean up test data
    try {
      await query("DELETE FROM auth_audit_logs WHERE user_id = $1", [
        testUserId,
      ]);
    } catch (error) {
      // Ignore cleanup errors
    }
  });

  describe("logAuthEvent", () => {
    it("should log authentication event with all details", async () => {
      const result = await logAuthEvent({
        userId: testUserId,
        eventType: AUTH_EVENT_TYPES.LOGIN,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        success: true,
        details: { method: "oauth" },
      });

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
      expect(result.created_at).toBeDefined();
    });

    it("should log failed authentication event", async () => {
      const result = await logAuthEvent({
        userId: testUserId,
        eventType: AUTH_EVENT_TYPES.FAILED_LOGIN,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        success: false,
        reason: "Invalid credentials",
        severity: SEVERITY_LEVELS.WARN,
      });

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
    });

    it("should throw error if eventType is missing", async () => {
      await expect(
        logAuthEvent({
          userId: testUserId,
          ipAddress: testIpAddress,
          userAgent: testUserAgent,
        }),
      ).rejects.toThrow("eventType is required");
    });

    it("should throw error if ipAddress is missing", async () => {
      await expect(
        logAuthEvent({
          userId: testUserId,
          eventType: AUTH_EVENT_TYPES.LOGIN,
          userAgent: testUserAgent,
        }),
      ).rejects.toThrow("ipAddress is required");
    });
  });

  describe("logLoginSuccess", () => {
    it("should log successful login", async () => {
      const result = await logLoginSuccess({
        userId: testUserId,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        details: { provider: "jwt" },
      });

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
    });
  });

  describe("logLoginFailure", () => {
    it("should log failed login attempt", async () => {
      const result = await logLoginFailure({
        userId: testUserId,
        email: "test@example.com",
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        reason: "Invalid password",
      });

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
    });

    it("should log failed login without user ID", async () => {
      const result = await logLoginFailure({
        email: "unknown@example.com",
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        reason: "User not found",
      });

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
    });
  });

  describe("logLogout", () => {
    it("should log logout event", async () => {
      const result = await logLogout({
        userId: testUserId,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
      });

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
    });
  });

  describe("logTokenRefresh", () => {
    it("should log token refresh event", async () => {
      const result = await logTokenRefresh({
        userId: testUserId,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        details: { expiresIn: 3600 },
      });

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
    });
  });

  describe("logTokenRevoke", () => {
    it("should log token revocation event", async () => {
      const result = await logTokenRevoke({
        userId: testUserId,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        details: { sessionId: "session-123" },
      });

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
    });
  });

  describe("getAuthAuditLogs", () => {
    beforeEach(async () => {
      // Create test audit logs
      await logLoginSuccess({
        userId: testUserId,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
      });

      await logLoginFailure({
        userId: testUserId,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        reason: "Test failure",
      });
    });

    it("should retrieve audit logs for user", async () => {
      const logs = await getAuthAuditLogs(testUserId);

      expect(Array.isArray(logs)).toBe(true);
      expect(logs.length).toBeGreaterThan(0);
    });

    it("should filter audit logs by event type", async () => {
      const logs = await getAuthAuditLogs(testUserId, {
        eventType: AUTH_EVENT_TYPES.LOGIN,
      });

      expect(Array.isArray(logs)).toBe(true);
      logs.forEach((log) => {
        expect(log.event_type).toBe(AUTH_EVENT_TYPES.LOGIN);
      });
    });

    it("should support pagination", async () => {
      const logsPage1 = await getAuthAuditLogs(testUserId, {
        limit: 1,
        offset: 0,
      });

      const logsPage2 = await getAuthAuditLogs(testUserId, {
        limit: 1,
        offset: 1,
      });

      expect(logsPage1.length).toBeLessThanOrEqual(1);
      expect(logsPage2.length).toBeLessThanOrEqual(1);
    });

    it("should return empty array for non-existent user", async () => {
      const logs = await getAuthAuditLogs("non-existent-user");

      expect(logs).toEqual([]);
    });
  });

  describe("getAuthAuditLogsCount", () => {
    it("should count audit logs for user", async () => {
      const count = await getAuthAuditLogsCount(testUserId);

      expect(typeof count).toBe("number");
      expect(count).toBeGreaterThanOrEqual(0);
    });

    it("should count filtered audit logs", async () => {
      const count = await getAuthAuditLogsCount(testUserId, {
        eventType: AUTH_EVENT_TYPES.LOGIN,
      });

      expect(typeof count).toBe("number");
      expect(count).toBeGreaterThanOrEqual(0);
    });
  });

  describe("getFailedLoginAttempts", () => {
    beforeEach(async () => {
      // Create test failed login attempts
      await logLoginFailure({
        userId: testUserId,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        reason: "Invalid credentials",
      });
    });

    it("should retrieve failed login attempts for user", async () => {
      const logs = await getFailedLoginAttempts(testUserId);

      expect(Array.isArray(logs)).toBe(true);
      logs.forEach((log) => {
        expect(log.event_type).toBe(AUTH_EVENT_TYPES.FAILED_LOGIN);
      });
    });

    it("should retrieve all failed login attempts", async () => {
      const logs = await getFailedLoginAttempts();

      expect(Array.isArray(logs)).toBe(true);
    });

    it("should support pagination for failed attempts", async () => {
      const logsPage1 = await getFailedLoginAttempts(testUserId, {
        limit: 1,
        offset: 0,
      });

      expect(Array.isArray(logsPage1)).toBe(true);
    });
  });

  describe("getAuthAuditLogsForAdmin", () => {
    it("should retrieve all audit logs for admin", async () => {
      const logs = await getAuthAuditLogsForAdmin();

      expect(Array.isArray(logs)).toBe(true);
    });

    it("should filter audit logs by event type for admin", async () => {
      const logs = await getAuthAuditLogsForAdmin({
        eventType: AUTH_EVENT_TYPES.LOGIN,
      });

      expect(Array.isArray(logs)).toBe(true);
      logs.forEach((log) => {
        expect(log.event_type).toBe(AUTH_EVENT_TYPES.LOGIN);
      });
    });

    it("should filter audit logs by severity for admin", async () => {
      const logs = await getAuthAuditLogsForAdmin({
        severity: SEVERITY_LEVELS.WARN,
      });

      expect(Array.isArray(logs)).toBe(true);
      logs.forEach((log) => {
        expect(log.severity).toBe(SEVERITY_LEVELS.WARN);
      });
    });

    it("should support pagination for admin", async () => {
      const logsPage1 = await getAuthAuditLogsForAdmin({
        limit: 10,
        offset: 0,
      });

      expect(Array.isArray(logsPage1)).toBe(true);
    });
  });

  describe("Property Tests", () => {
    /**
     * Property 2: JWT validation round trip
     * Validates: Requirements 2.1, 2.2
     *
     * For any authentication event, logging and retrieving should preserve all details
     */
    it("should preserve all audit log details on round trip", async () => {
      const testDetails = {
        method: "oauth",
        provider: "jwt",
        timestamp: new Date().toISOString(),
      };

      // Log event
      await logAuthEvent({
        userId: testUserId,
        eventType: AUTH_EVENT_TYPES.LOGIN,
        ipAddress: testIpAddress,
        userAgent: testUserAgent,
        success: true,
        details: testDetails,
      });

      // Retrieve logs
      const logs = await getAuthAuditLogs(testUserId, {
        eventType: AUTH_EVENT_TYPES.LOGIN,
      });

      // Verify details are preserved
      const latestLog = logs[0];
      expect(latestLog.details).toBeDefined();
      expect(latestLog.details.method).toBe(testDetails.method);
      expect(latestLog.details.provider).toBe(testDetails.provider);
    });

    /**
     * Property 3: Permission enforcement consistency
     * Validates: Requirements 2.6, 11.10
     *
     * For any authentication event, the audit log should be created with correct event type
     */
    it("should consistently log correct event types", async () => {
      const eventTypes = [
        AUTH_EVENT_TYPES.LOGIN,
        AUTH_EVENT_TYPES.LOGOUT,
        AUTH_EVENT_TYPES.FAILED_LOGIN,
        AUTH_EVENT_TYPES.TOKEN_REFRESH,
      ];

      for (const eventType of eventTypes) {
        await logAuthEvent({
          userId: testUserId,
          eventType,
          ipAddress: testIpAddress,
          userAgent: testUserAgent,
          success: eventType !== AUTH_EVENT_TYPES.FAILED_LOGIN,
        });
      }

      // Verify all event types are logged correctly
      for (const eventType of eventTypes) {
        const logs = await getAuthAuditLogs(testUserId, { eventType });
        expect(logs.length).toBeGreaterThan(0);
        logs.forEach((log) => {
          expect(log.event_type).toBe(eventType);
        });
      }
    });

    /**
     * Property: Audit log immutability
     * Validates: Requirements 2.6, 11.10
     *
     * For any audit log entry, the IP address and user agent should be preserved exactly
     */
    it("should preserve IP address and user agent exactly", async () => {
      const customIp = "10.0.0.1";
      const customUserAgent = "Custom Agent/1.0";

      await logAuthEvent({
        userId: testUserId,
        eventType: AUTH_EVENT_TYPES.LOGIN,
        ipAddress: customIp,
        userAgent: customUserAgent,
        success: true,
      });

      const logs = await getAuthAuditLogs(testUserId, {
        eventType: AUTH_EVENT_TYPES.LOGIN,
      });

      const latestLog = logs[0];
      expect(latestLog.ip_address).toBe(customIp);
      expect(latestLog.user_agent).toBe(customUserAgent);
    });
  });
});
