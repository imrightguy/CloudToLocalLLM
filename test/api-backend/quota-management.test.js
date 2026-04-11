/**


 * Quota Management Service Tests
 *
 * Tests for quota management functionality:
 * - Creating quota tracking mechanism
 * - Implementing quota enforcement
 * - Adding quota reporting endpoints
 *
 * Validates: Requirements 6.6
 * - Implements quota management for resource usage
 * - Tracks quota usage per user
 * - Enforces quota limits
 * - Provides quota reporting
 *
 * @fileoverview Quota management service tests
 * @version 1.0.0
 */

import { describe, it, expect, beforeEach, jest } from "@jest/globals";
import { v4 as uuidv4 } from "uuid";
import { QuotaService } from "../../services/api-backend/services/quota-service.js";

describe("QuotaService", () => {
  let quotaService;
  let mockPool;
  let testUserId;

  beforeEach(() => {
    // Create mock pool
    mockPool = {
      query: jest.fn(),
      connect: jest.fn(),
    };

    quotaService = new QuotaService();
    quotaService.pool = mockPool;

    testUserId = uuidv4();
  });

  describe("getQuotaDefinition", () => {
    it("should get quota definition for free tier", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            tier: "free",
            resource_type: "api_requests",
            limit_value: 10000,
            limit_unit: "requests",
            reset_period: "monthly",
          },
        ],
      });

      const definition = await quotaService.getQuotaDefinition(
        "free",
        "api_requests",
      );

      expect(definition).toBeDefined();
      expect(definition.tier).toBe("free");
      expect(definition.resourceType).toBe("api_requests");
      expect(definition.limitValue).toBe(10000);
      expect(definition.limitUnit).toBe("requests");
    });

    it("should throw error for non-existent quota definition", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(
        quotaService.getQuotaDefinition("invalid", "invalid"),
      ).rejects.toThrow("Quota definition not found");
    });
  });

  describe("initializeUserQuotas", () => {
    it("should initialize quotas for free tier user", async () => {
      const quotaId = uuidv4();

      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: quotaId,
            user_id: testUserId,
            resource_type: "api_requests",
            limit_value: 10000,
            current_usage: 0,
            reset_period: "monthly",
          },
        ],
      });

      mockPool.connect.mockResolvedValueOnce({
        query: jest
          .fn()
          .mockResolvedValueOnce({ rows: [] }) // BEGIN
          .mockResolvedValueOnce({
            rows: [
              {
                resource_type: "api_requests",
                limit_value: 10000,
                reset_period: "monthly",
              },
            ],
          }) // SELECT definitions
          .mockResolvedValueOnce({
            rows: [
              {
                id: quotaId,
                user_id: testUserId,
                resource_type: "api_requests",
                limit_value: 10000,
                current_usage: 0,
              },
            ],
          }) // INSERT quota
          .mockResolvedValueOnce({ rows: [] }), // COMMIT
        release: jest.fn(),
      });

      const quotas = await quotaService.initializeUserQuotas(
        testUserId,
        "free",
      );

      expect(quotas).toBeDefined();
      expect(Array.isArray(quotas)).toBe(true);
    });
  });

  describe("recordQuotaUsage", () => {
    it("should record quota usage", async () => {
      const quotaId = uuidv4();

      const mockClient = {
        query: jest
          .fn()
          .mockResolvedValueOnce({ rows: [] }) // BEGIN
          .mockResolvedValueOnce({
            rows: [
              {
                id: quotaId,
                user_id: testUserId,
                resource_type: "api_requests",
                limit_value: 10000,
                current_usage: 0,
              },
            ],
          }) // SELECT quota
          .mockResolvedValueOnce({
            rows: [
              {
                id: quotaId,
                user_id: testUserId,
                resource_type: "api_requests",
                limit_value: 10000,
                current_usage: 100,
                is_exceeded: false,
              },
            ],
          }) // UPDATE quota
          .mockResolvedValueOnce({ rows: [] }) // INSERT event
          .mockResolvedValueOnce({ rows: [] }), // COMMIT
        release: jest.fn(),
      };

      mockPool.connect.mockResolvedValueOnce(mockClient);

      const quota = await quotaService.recordQuotaUsage(
        testUserId,
        "api_requests",
        100,
      );

      expect(quota).toBeDefined();
      expect(quota.currentUsage).toBe(100);
      expect(quota.isExceeded).toBe(false);
    });

    it("should detect quota exceeded", async () => {
      const quotaId = uuidv4();

      const mockClient = {
        query: jest
          .fn()
          .mockResolvedValueOnce({ rows: [] }) // BEGIN
          .mockResolvedValueOnce({
            rows: [
              {
                id: quotaId,
                user_id: testUserId,
                resource_type: "api_requests",
                limit_value: 10000,
                current_usage: 9900,
              },
            ],
          }) // SELECT quota
          .mockResolvedValueOnce({
            rows: [
              {
                id: quotaId,
                user_id: testUserId,
                resource_type: "api_requests",
                limit_value: 10000,
                current_usage: 10100,
                is_exceeded: true,
                exceeded_at: new Date(),
              },
            ],
          }) // UPDATE quota
          .mockResolvedValueOnce({ rows: [] }) // INSERT event
          .mockResolvedValueOnce({ rows: [] }), // COMMIT
        release: jest.fn(),
      };

      mockPool.connect.mockResolvedValueOnce(mockClient);

      const quota = await quotaService.recordQuotaUsage(
        testUserId,
        "api_requests",
        200,
      );

      expect(quota).toBeDefined();
      expect(quota.currentUsage).toBe(10100);
      expect(quota.isExceeded).toBe(true);
    });
  });

  describe("getUserQuotaUsage", () => {
    it("should get current quota usage", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "api_requests",
            limit_value: 10000,
            current_usage: 500,
            is_exceeded: false,
            exceeded_at: null,
            period_start: "2024-01-01",
            period_end: "2024-01-31",
          },
        ],
      });

      const quota = await quotaService.getUserQuotaUsage(
        testUserId,
        "api_requests",
      );

      expect(quota).toBeDefined();
      expect(quota.currentUsage).toBe(500);
      expect(quota.limitValue).toBe(10000);
      expect(quota.percentageUsed).toBe(5);
    });

    it("should throw error for non-existent quota", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [],
      });

      await expect(
        quotaService.getUserQuotaUsage(testUserId, "invalid_resource"),
      ).rejects.toThrow("Quota not found");
    });
  });

  describe("isQuotaExceeded", () => {
    it("should return false when quota not exceeded", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "api_requests",
            limit_value: 10000,
            current_usage: 100,
            is_exceeded: false,
            exceeded_at: null,
            period_start: "2024-01-01",
            period_end: "2024-01-31",
          },
        ],
      });

      const isExceeded = await quotaService.isQuotaExceeded(
        testUserId,
        "api_requests",
      );

      expect(isExceeded).toBe(false);
    });

    it("should return true when quota exceeded", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "api_requests",
            limit_value: 10000,
            current_usage: 10100,
            is_exceeded: true,
            exceeded_at: new Date(),
            period_start: "2024-01-01",
            period_end: "2024-01-31",
          },
        ],
      });

      const isExceeded = await quotaService.isQuotaExceeded(
        testUserId,
        "api_requests",
      );

      expect(isExceeded).toBe(true);
    });
  });

  describe("getUserAllQuotas", () => {
    it("should get all quotas for user", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "api_requests",
            limit_value: 10000,
            current_usage: 100,
            is_exceeded: false,
            exceeded_at: null,
            period_start: "2024-01-01",
            period_end: "2024-01-31",
          },
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "data_transfer",
            limit_value: 1073741824,
            current_usage: 0,
            is_exceeded: false,
            exceeded_at: null,
            period_start: "2024-01-01",
            period_end: "2024-01-31",
          },
        ],
      });

      const quotas = await quotaService.getUserAllQuotas(testUserId);

      expect(quotas).toBeDefined();
      expect(quotas.length).toBe(2);
      expect(quotas[0].resourceType).toBe("api_requests");
      expect(quotas[1].resourceType).toBe("data_transfer");
    });
  });

  describe("getQuotaEvents", () => {
    it("should get quota events for user", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "api_requests",
            event_type: "usage_recorded",
            usage_delta: 100,
            total_usage: 100,
            limit_value: 10000,
            percentage_used: 1,
            details: {},
            created_at: new Date(),
          },
        ],
      });

      const events = await quotaService.getQuotaEvents(testUserId);

      expect(events).toBeDefined();
      expect(events.length).toBe(1);
      expect(events[0].usageDelta).toBe(100);
    });

    it("should filter events by resource type", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "api_requests",
            event_type: "usage_recorded",
            usage_delta: 100,
            total_usage: 100,
            limit_value: 10000,
            percentage_used: 1,
            details: {},
            created_at: new Date(),
          },
        ],
      });

      const events = await quotaService.getQuotaEvents(testUserId, {
        resourceType: "api_requests",
      });

      expect(events).toBeDefined();
      expect(events.every((e) => e.resourceType === "api_requests")).toBe(true);
    });
  });

  describe("resetQuota", () => {
    it("should reset quota usage", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "api_requests",
            limit_value: 10000,
            current_usage: 0,
            is_exceeded: false,
            exceeded_at: null,
            period_start: "2024-01-01",
            period_end: "2024-01-31",
          },
        ],
      });

      const quota = await quotaService.resetQuota(testUserId, "api_requests");

      expect(quota).toBeDefined();
      expect(quota.current_usage).toBe(0);
      expect(quota.is_exceeded).toBe(false);
    });
  });

  describe("getQuotaSummary", () => {
    it("should get quota summary", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "api_requests",
            limit_value: 10000,
            current_usage: 100,
            is_exceeded: false,
            exceeded_at: null,
            period_start: "2024-01-01",
            period_end: "2024-01-31",
          },
        ],
      });

      const summary = await quotaService.getQuotaSummary(testUserId);

      expect(summary).toBeDefined();
      expect(summary.userId).toBe(testUserId);
      expect(summary.totalQuotas).toBe(1);
      expect(summary.quotasExceeded).toBe(0);
      expect(summary.quotas).toBeDefined();
    });

    it("should count quotas near limit", async () => {
      mockPool.query.mockResolvedValueOnce({
        rows: [
          {
            id: uuidv4(),
            user_id: testUserId,
            resource_type: "api_requests",
            limit_value: 10000,
            current_usage: 8500,
            is_exceeded: false,
            exceeded_at: null,
            period_start: "2024-01-01",
            period_end: "2024-01-31",
          },
        ],
      });

      const summary = await quotaService.getQuotaSummary(testUserId);

      expect(summary).toBeDefined();
      expect(summary.quotasNearLimit).toBe(1);
    });
  });
});
