/**


 * Rate Limit Violations Service Tests
 *
 * Tests for rate limit violation logging functionality:
 * - Logging rate limit violations
 * - Retrieving violations by user
 * - Retrieving violations by IP
 * - Analyzing violation statistics
 * - Identifying top violators
 *
 * Validates: Requirements 6.8
 * - Logs all rate limit violations
 * - Includes violation context (user, IP, endpoint)
 * - Provides violation analysis endpoints
 *
 * @fileoverview Rate limit violations service tests
 * @version 1.0.0
 */

import { describe, it, expect, beforeEach, jest } from "@jest/globals";
import { v4 as uuidv4 } from "uuid";
import {
  RateLimitViolationsService,
  VIOLATION_TYPES,
} from "../../services/api-backend/services/rate-limit-violations-service.js";

describe("RateLimitViolationsService", () => {
  let violationsService;
  let mockPool;
  let testUserId;
  let testIpAddress;

  beforeEach(() => {
    // Create mock pool
    mockPool = {
      query: jest.fn(),
      connect: jest.fn(),
    };

    violationsService = new RateLimitViolationsService();
    violationsService.pool = mockPool;

    testUserId = uuidv4();
    testIpAddress = "192.168.1.100";
  });

  describe("logViolation", () => {
    it("should log a window limit exceeded violation", async () => {
      const violationId = uuidv4();
      const now = new Date();

      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: violationId,
            user_id: testUserId,
            violation_type: VIOLATION_TYPES.WINDOW_LIMIT_EXCEEDED,
            endpoint: "/api/tunnels",
            method: "GET",
            ip_address: testIpAddress,
            user_agent: "Mozilla/5.0",
            violation_context: JSON.stringify({
              windowRequests: 1000,
              maxRequests: 1000,
            }),
            timestamp: now,
            created_at: now,
          },
        ],
      });

      const violation = await violationsService.logViolation({
        userId: testUserId,
        violationType: VIOLATION_TYPES.WINDOW_LIMIT_EXCEEDED,
        endpoint: "/api/tunnels",
        method: "GET",
        ipAddress: testIpAddress,
        userAgent: "Mozilla/5.0",
        context: {
          windowRequests: 1000,
          maxRequests: 1000,
        },
      });

      expect(violation).toBeDefined();
      expect(violation.userId).toBe(testUserId);
      expect(violation.violationType).toBe(
        VIOLATION_TYPES.WINDOW_LIMIT_EXCEEDED,
      );
      expect(violation.endpoint).toBe("/api/tunnels");
      expect(violation.ipAddress).toBe(testIpAddress);
      expect(mockPool.query).toHaveBeenCalled();
    });

    it("should log a burst limit exceeded violation", async () => {
      const violationId = uuidv4();
      const now = new Date();

      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: violationId,
            user_id: testUserId,
            violation_type: VIOLATION_TYPES.BURST_LIMIT_EXCEEDED,
            endpoint: "/api/users",
            method: "POST",
            ip_address: testIpAddress,
            user_agent: "Mozilla/5.0",
            violation_context: JSON.stringify({
              burstRequests: 100,
              maxBurstRequests: 100,
            }),
            timestamp: now,
            created_at: now,
          },
        ],
      });

      const violation = await violationsService.logViolation({
        userId: testUserId,
        violationType: VIOLATION_TYPES.BURST_LIMIT_EXCEEDED,
        endpoint: "/api/users",
        method: "POST",
        ipAddress: testIpAddress,
        userAgent: "Mozilla/5.0",
        context: {
          burstRequests: 100,
          maxBurstRequests: 100,
        },
      });

      expect(violation).toBeDefined();
      expect(violation.violationType).toBe(
        VIOLATION_TYPES.BURST_LIMIT_EXCEEDED,
      );
      expect(violation.method).toBe("POST");
    });

    it("should log a concurrent limit exceeded violation", async () => {
      const violationId = uuidv4();
      const now = new Date();

      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: violationId,
            user_id: testUserId,
            violation_type: VIOLATION_TYPES.CONCURRENT_LIMIT_EXCEEDED,
            endpoint: "/api/proxy",
            method: "PUT",
            ip_address: testIpAddress,
            user_agent: "Mozilla/5.0",
            violation_context: JSON.stringify({
              concurrentRequests: 50,
              maxConcurrentRequests: 50,
            }),
            timestamp: now,
            created_at: now,
          },
        ],
      });

      const violation = await violationsService.logViolation({
        userId: testUserId,
        violationType: VIOLATION_TYPES.CONCURRENT_LIMIT_EXCEEDED,
        endpoint: "/api/proxy",
        method: "PUT",
        ipAddress: testIpAddress,
        userAgent: "Mozilla/5.0",
        context: {
          concurrentRequests: 50,
          maxConcurrentRequests: 50,
        },
      });

      expect(violation).toBeDefined();
      expect(violation.violationType).toBe(
        VIOLATION_TYPES.CONCURRENT_LIMIT_EXCEEDED,
      );
    });

    it("should handle violations without user ID", async () => {
      const violationId = uuidv4();
      const now = new Date();

      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: violationId,
            user_id: null,
            violation_type: VIOLATION_TYPES.IP_LIMIT_EXCEEDED,
            endpoint: "/api/auth",
            method: "POST",
            ip_address: testIpAddress,
            user_agent: "Mozilla/5.0",
            violation_context: JSON.stringify({}),
            timestamp: now,
            created_at: now,
          },
        ],
      });

      const violation = await violationsService.logViolation({
        userId: null,
        violationType: VIOLATION_TYPES.IP_LIMIT_EXCEEDED,
        endpoint: "/api/auth",
        method: "POST",
        ipAddress: testIpAddress,
        userAgent: "Mozilla/5.0",
      });

      expect(violation).toBeDefined();
      expect(violation.userId).toBeNull();
    });
  });

  describe("getUserViolations", () => {
    it("should retrieve violations for a user", async () => {
      const now = new Date();
      const violations = [
        {
          id: uuidv4(),
          user_id: testUserId,
          violation_type: VIOLATION_TYPES.WINDOW_LIMIT_EXCEEDED,
          endpoint: "/api/tunnels",
          method: "GET",
          ip_address: testIpAddress,
          user_agent: "Mozilla/5.0",
          violation_context: JSON.stringify({}),
          timestamp: now,
          created_at: now,
        },
        {
          id: uuidv4(),
          user_id: testUserId,
          violation_type: VIOLATION_TYPES.BURST_LIMIT_EXCEEDED,
          endpoint: "/api/users",
          method: "POST",
          ip_address: testIpAddress,
          user_agent: "Mozilla/5.0",
          violation_context: JSON.stringify({}),
          timestamp: now,
          created_at: now,
        },
      ];

      mockPool.query.mockResolvedValueOnce({
        rows: violations,
      });

      const result = await violationsService.getUserViolations(testUserId, {
        limit: 100,
        offset: 0,
      });

      expect(result).toHaveLength(2);
      expect(result[0].userId).toBe(testUserId);
      expect(result[1].userId).toBe(testUserId);
    });

    it("should support pagination", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await violationsService.getUserViolations(testUserId, {
        limit: 50,
        offset: 100,
      });

      expect(mockPool.query).toHaveBeenCalled();
      const query = mockPool.query.mock.calls[0][0];
      expect(query).toContain("LIMIT");
      expect(query).toContain("OFFSET");
    });

    it("should filter by time range", async () => {
      const startTime = new Date("2024-01-01");
      const endTime = new Date("2024-01-31");

      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await violationsService.getUserViolations(testUserId, {
        startTime: startTime.toISOString(),
        endTime: endTime.toISOString(),
      });

      expect(mockPool.query).toHaveBeenCalled();
      const query = mockPool.query.mock.calls[0][0];
      expect(query).toContain("timestamp >=");
      expect(query).toContain("timestamp <=");
    });
  });

  describe("getIpViolations", () => {
    it("should retrieve violations for an IP address", async () => {
      const now = new Date();
      const violations = [
        {
          id: uuidv4(),
          user_id: testUserId,
          violation_type: VIOLATION_TYPES.WINDOW_LIMIT_EXCEEDED,
          endpoint: "/api/tunnels",
          method: "GET",
          ip_address: testIpAddress,
          user_agent: "Mozilla/5.0",
          violation_context: JSON.stringify({}),
          timestamp: now,
          created_at: now,
        },
      ];

      mockPool.query.mockResolvedValueOnce({
        rows: violations,
      });

      const result = await violationsService.getIpViolations(testIpAddress);

      expect(result).toHaveLength(1);
      expect(result[0].ipAddress).toBe(testIpAddress);
    });
  });

  describe("getUserViolationStats", () => {
    it("should return statistics for a user with violations", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            total_violations: 10,
            violation_types_count: 2,
            unique_ips: 3,
            unique_endpoints: 4,
            first_violation: new Date("2024-01-01"),
            last_violation: new Date("2024-01-31"),
            violations_by_type: {
              window_limit_exceeded: 6,
              burst_limit_exceeded: 4,
            },
          },
        ],
      });

      const stats = await violationsService.getUserViolationStats(testUserId);

      expect(stats).toBeDefined();
      expect(stats.userId).toBe(testUserId);
      expect(stats.totalViolations).toBe(10);
      expect(stats.violationTypesCount).toBe(2);
      expect(stats.uniqueIps).toBe(3);
      expect(stats.uniqueEndpoints).toBe(4);
      expect(stats.violationsByType).toEqual({
        window_limit_exceeded: 6,
        burst_limit_exceeded: 4,
      });
    });

    it("should return zero stats for user with no violations", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      const stats = await violationsService.getUserViolationStats(testUserId);

      expect(stats).toBeDefined();
      expect(stats.userId).toBe(testUserId);
      expect(stats.totalViolations).toBe(0);
      expect(stats.violationTypesCount).toBe(0);
    });
  });

  describe("getIpViolationStats", () => {
    it("should return statistics for an IP address", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            total_violations: 15,
            violation_types_count: 3,
            unique_users: 5,
            unique_endpoints: 6,
            first_violation: new Date("2024-01-01"),
            last_violation: new Date("2024-01-31"),
            violations_by_type: {
              window_limit_exceeded: 8,
              burst_limit_exceeded: 5,
              concurrent_limit_exceeded: 2,
            },
          },
        ],
      });

      const stats = await violationsService.getIpViolationStats(testIpAddress);

      expect(stats).toBeDefined();
      expect(stats.ipAddress).toBe(testIpAddress);
      expect(stats.totalViolations).toBe(15);
      expect(stats.uniqueUsers).toBe(5);
    });
  });

  describe("getTopViolators", () => {
    it("should return top violating users", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            user_id: uuidv4(),
            violation_count: 50,
            violation_types: 3,
            unique_ips: 2,
            first_violation: new Date("2024-01-01"),
            last_violation: new Date("2024-01-31"),
          },
          {
            user_id: uuidv4(),
            violation_count: 30,
            violation_types: 2,
            unique_ips: 1,
            first_violation: new Date("2024-01-05"),
            last_violation: new Date("2024-01-30"),
          },
        ],
      });

      const topViolators = await violationsService.getTopViolators({
        limit: 10,
      });

      expect(topViolators).toHaveLength(2);
      expect(topViolators[0].violationCount).toBe(50);
      expect(topViolators[1].violationCount).toBe(30);
    });
  });

  describe("getTopViolatingIps", () => {
    it("should return top violating IP addresses", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            ip_address: "192.168.1.100",
            violation_count: 100,
            violation_types: 3,
            unique_users: 5,
            first_violation: new Date("2024-01-01"),
            last_violation: new Date("2024-01-31"),
          },
          {
            ip_address: "192.168.1.101",
            violation_count: 75,
            violation_types: 2,
            unique_users: 3,
            first_violation: new Date("2024-01-05"),
            last_violation: new Date("2024-01-30"),
          },
        ],
      });

      const topIps = await violationsService.getTopViolatingIps({ limit: 10 });

      expect(topIps).toHaveLength(2);
      expect(topIps[0].violationCount).toBe(100);
      expect(topIps[1].violationCount).toBe(75);
    });
  });

  describe("getEndpointViolations", () => {
    it("should return violations for a specific endpoint", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            violation_count: 25,
            unique_users: 5,
            unique_ips: 3,
            violation_types: 2,
            first_violation: new Date("2024-01-01"),
            last_violation: new Date("2024-01-31"),
            violations_by_type: {
              window_limit_exceeded: 15,
              burst_limit_exceeded: 10,
            },
          },
        ],
      });

      const stats =
        await violationsService.getEndpointViolations("/api/tunnels");

      expect(stats).toBeDefined();
      expect(stats.endpoint).toBe("/api/tunnels");
      expect(stats.violationCount).toBe(25);
      expect(stats.uniqueUsers).toBe(5);
    });
  });

  describe("formatViolation", () => {
    it("should format violation correctly", () => {
      const now = new Date();
      const row = {
        id: uuidv4(),
        user_id: testUserId,
        violation_type: VIOLATION_TYPES.WINDOW_LIMIT_EXCEEDED,
        endpoint: "/api/tunnels",
        method: "GET",
        ip_address: testIpAddress,
        user_agent: "Mozilla/5.0",
        violation_context: JSON.stringify({ test: "data" }),
        timestamp: now,
        created_at: now,
      };

      const formatted = violationsService.formatViolation(row);

      expect(formatted).toBeDefined();
      expect(formatted.id).toBe(row.id);
      expect(formatted.userId).toBe(testUserId);
      expect(formatted.violationType).toBe(
        VIOLATION_TYPES.WINDOW_LIMIT_EXCEEDED,
      );
      expect(formatted.context).toEqual({ test: "data" });
    });
  });
});
