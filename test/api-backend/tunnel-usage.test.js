/**


 * Tunnel Usage Service Tests
 *
 * Tests for tunnel usage tracking and billing functionality:
 * - Recording usage events
 * - Getting tunnel usage metrics
 * - Aggregating user usage
 * - Generating usage reports
 * - Calculating billing summaries
 *
 * Validates: Requirements 4.9
 * - Tracks tunnel usage metrics (connections, data transferred)
 * - Implements usage aggregation per user/tier
 * - Creates usage reporting endpoints
 *
 * @fileoverview Tunnel usage service tests
 * @version 1.0.0
 */

import {
  describe,
  it,
  expect,
  beforeAll,
  afterAll,
  beforeEach,
} from "@jest/globals";
import { v4 as uuidv4 } from "uuid";
import { TunnelUsageService } from "../../services/api-backend/services/tunnel-usage-service.js";
import { getPool } from "../../services/api-backend/database/db-pool.js";

describe("TunnelUsageService", () => {
  let usageService;
  let pool;
  let testUserId;
  let testTunnelId;
  const testDate = new Date().toISOString().split("T")[0];

  beforeAll(async () => {
    pool = getPool();
    usageService = new TunnelUsageService();
    await usageService.initialize();

    // Create test user
    const userResult = await pool.query(
      `INSERT INTO users (jwt_id, email, name) 
       VALUES ($1, $2, $3) 
       RETURNING id`,
      [uuidv4(), `test-${uuidv4()}@example.com`, "Test User"],
    );
    testUserId = userResult.rows[0].id;

    // Create test tunnel
    const tunnelResult = await pool.query(
      `INSERT INTO tunnels (user_id, name, status) 
       VALUES ($1, $2, $3) 
       RETURNING id`,
      [testUserId, `test-tunnel-${uuidv4()}`, "connected"],
    );
    testTunnelId = tunnelResult.rows[0].id;
  });

  afterAll(async () => {
    // Cleanup
    await pool.query("DELETE FROM tunnel_usage_events WHERE user_id = $1", [
      testUserId,
    ]);
    await pool.query(
      "DELETE FROM tunnel_usage_aggregation WHERE user_id = $1",
      [testUserId],
    );
    await pool.query("DELETE FROM tunnel_usage_metrics WHERE user_id = $1", [
      testUserId,
    ]);
    await pool.query("DELETE FROM tunnels WHERE user_id = $1", [testUserId]);
    await pool.query("DELETE FROM users WHERE id = $1", [testUserId]);
  });

  describe("recordUsageEvent", () => {
    it("should record a connection_start event", async () => {
      const event = await usageService.recordUsageEvent(
        testTunnelId,
        testUserId,
        "connection_start",
        {
          connectionId: "conn-123",
          ipAddress: "192.168.1.1",
        },
      );

      expect(event).toBeDefined();
      expect(event.tunnel_id).toBe(testTunnelId);
      expect(event.user_id).toBe(testUserId);
      expect(event.event_type).toBe("connection_start");
      expect(event.connection_id).toBe("conn-123");
    });

    it("should record a data_transfer event", async () => {
      const event = await usageService.recordUsageEvent(
        testTunnelId,
        testUserId,
        "data_transfer",
        {
          connectionId: "conn-123",
          dataBytes: 1024 * 1024, // 1 MB
        },
      );

      expect(event).toBeDefined();
      expect(event.event_type).toBe("data_transfer");
      expect(event.data_bytes).toBe(1024 * 1024);
    });

    it("should record a connection_end event", async () => {
      const event = await usageService.recordUsageEvent(
        testTunnelId,
        testUserId,
        "connection_end",
        {
          connectionId: "conn-123",
          durationSeconds: 300,
        },
      );

      expect(event).toBeDefined();
      expect(event.event_type).toBe("connection_end");
      expect(event.duration_seconds).toBe(300);
    });

    it("should record an error event", async () => {
      const event = await usageService.recordUsageEvent(
        testTunnelId,
        testUserId,
        "error",
        {
          connectionId: "conn-123",
          errorMessage: "Connection timeout",
        },
      );

      expect(event).toBeDefined();
      expect(event.event_type).toBe("error");
      expect(event.error_message).toBe("Connection timeout");
    });

    it("should reject invalid event type", async () => {
      await expect(
        usageService.recordUsageEvent(
          testTunnelId,
          testUserId,
          "invalid_type",
          {},
        ),
      ).rejects.toThrow("Invalid event type");
    });
  });

  describe("getTunnelUsageMetrics", () => {
    beforeEach(async () => {
      // Insert test metrics
      await pool.query(
        `INSERT INTO tunnel_usage_metrics 
         (tunnel_id, user_id, date, connection_count, data_transferred_bytes, data_received_bytes, 
          peak_concurrent_connections, average_connection_duration_seconds, error_count, success_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
        [
          testTunnelId,
          testUserId,
          testDate,
          100,
          1024 * 1024 * 100,
          1024 * 1024 * 50,
          10,
          300,
          5,
          95,
        ],
      );
    });

    it("should get tunnel usage metrics for a specific date", async () => {
      const metrics = await usageService.getTunnelUsageMetrics(
        testTunnelId,
        testUserId,
        testDate,
      );

      expect(metrics).toBeDefined();
      expect(metrics.tunnelId).toBe(testTunnelId);
      expect(metrics.date).toBe(testDate);
      expect(metrics.connectionCount).toBe(100);
      expect(metrics.dataTransferredBytes).toBe(1024 * 1024 * 100);
      expect(metrics.peakConcurrentConnections).toBe(10);
    });

    it("should return zero metrics if no data exists", async () => {
      const futureDate = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];
      const metrics = await usageService.getTunnelUsageMetrics(
        testTunnelId,
        testUserId,
        futureDate,
      );

      expect(metrics).toBeDefined();
      expect(metrics.connectionCount).toBe(0);
      expect(metrics.dataTransferredBytes).toBe(0);
    });

    it("should reject if tunnel not found", async () => {
      const nonExistentTunnelId = uuidv4();
      await expect(
        usageService.getTunnelUsageMetrics(
          nonExistentTunnelId,
          testUserId,
          testDate,
        ),
      ).rejects.toThrow("Tunnel not found");
    });

    it("should reject if user is not tunnel owner", async () => {
      const otherUserId = uuidv4();
      await expect(
        usageService.getTunnelUsageMetrics(testTunnelId, otherUserId, testDate),
      ).rejects.toThrow("Tunnel not found");
    });
  });

  describe("getTunnelUsageMetricsRange", () => {
    beforeEach(async () => {
      // Insert test metrics for multiple days
      const today = new Date();
      for (let i = 0; i < 7; i++) {
        const date = new Date(today.getTime() - i * 86400000)
          .toISOString()
          .split("T")[0];
        await pool.query(
          `INSERT INTO tunnel_usage_metrics 
           (tunnel_id, user_id, date, connection_count, data_transferred_bytes, data_received_bytes, 
            peak_concurrent_connections, average_connection_duration_seconds, error_count, success_count)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (tunnel_id, date) DO NOTHING`,
          [
            testTunnelId,
            testUserId,
            date,
            100 + i * 10,
            1024 * 1024 * (100 + i * 10),
            1024 * 1024 * 50,
            10,
            300,
            5,
            95,
          ],
        );
      }
    });

    it("should get tunnel usage metrics for a date range", async () => {
      const today = new Date();
      const startDate = new Date(today.getTime() - 6 * 86400000)
        .toISOString()
        .split("T")[0];
      const endDate = today.toISOString().split("T")[0];

      const metrics = await usageService.getTunnelUsageMetricsRange(
        testTunnelId,
        testUserId,
        startDate,
        endDate,
      );

      expect(metrics).toBeDefined();
      expect(Array.isArray(metrics)).toBe(true);
      expect(metrics.length).toBeGreaterThan(0);
      expect(metrics[0].tunnelId).toBe(testTunnelId);
    });

    it("should return empty array if no data in range", async () => {
      const futureStart = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];
      const futureEnd = new Date(Date.now() + 172800000)
        .toISOString()
        .split("T")[0];

      const metrics = await usageService.getTunnelUsageMetricsRange(
        testTunnelId,
        testUserId,
        futureStart,
        futureEnd,
      );

      expect(metrics).toBeDefined();
      expect(Array.isArray(metrics)).toBe(true);
      expect(metrics.length).toBe(0);
    });
  });

  describe("aggregateUserUsage", () => {
    beforeEach(async () => {
      // Insert test metrics
      const today = new Date();
      for (let i = 0; i < 30; i++) {
        const date = new Date(today.getTime() - i * 86400000)
          .toISOString()
          .split("T")[0];
        await pool.query(
          `INSERT INTO tunnel_usage_metrics 
           (tunnel_id, user_id, date, connection_count, data_transferred_bytes, data_received_bytes, 
            peak_concurrent_connections, average_connection_duration_seconds, error_count, success_count)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (tunnel_id, date) DO NOTHING`,
          [
            testTunnelId,
            testUserId,
            date,
            100,
            1024 * 1024 * 100,
            1024 * 1024 * 50,
            10,
            300,
            5,
            95,
          ],
        );
      }
    });

    it("should aggregate user usage for a period", async () => {
      const today = new Date();
      const periodStart = new Date(today.getTime() - 29 * 86400000)
        .toISOString()
        .split("T")[0];
      const periodEnd = today.toISOString().split("T")[0];

      const aggregation = await usageService.aggregateUserUsage(
        testUserId,
        "premium",
        periodStart,
        periodEnd,
      );

      expect(aggregation).toBeDefined();
      expect(aggregation.user_id).toBe(testUserId);
      expect(aggregation.user_tier).toBe("premium");
      expect(aggregation.total_connections).toBeGreaterThan(0);
      expect(aggregation.total_data_transferred_bytes).toBeGreaterThan(0);
    });

    it("should handle user with no tunnels", async () => {
      const newUserId = uuidv4();
      await pool.query(
        `INSERT INTO users (jwt_id, email, name) 
         VALUES ($1, $2, $3)`,
        [uuidv4(), `test-${uuidv4()}@example.com`, "Test User 2"],
      );

      const today = new Date();
      const periodStart = new Date(today.getTime() - 29 * 86400000)
        .toISOString()
        .split("T")[0];
      const periodEnd = today.toISOString().split("T")[0];

      const aggregation = await usageService.aggregateUserUsage(
        newUserId,
        "free",
        periodStart,
        periodEnd,
      );

      expect(aggregation).toBeDefined();
      expect(aggregation.total_connections).toBe(0);
    });
  });

  describe("getUserUsageReport", () => {
    beforeEach(async () => {
      // Insert test metrics
      const today = new Date();
      for (let i = 0; i < 7; i++) {
        const date = new Date(today.getTime() - i * 86400000)
          .toISOString()
          .split("T")[0];
        await pool.query(
          `INSERT INTO tunnel_usage_metrics 
           (tunnel_id, user_id, date, connection_count, data_transferred_bytes, data_received_bytes, 
            peak_concurrent_connections, average_connection_duration_seconds, error_count, success_count)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
           ON CONFLICT (tunnel_id, date) DO NOTHING`,
          [
            testTunnelId,
            testUserId,
            date,
            100 + i * 10,
            1024 * 1024 * (100 + i * 10),
            1024 * 1024 * 50,
            10,
            300,
            5,
            95,
          ],
        );
      }
    });

    it("should get usage report grouped by day", async () => {
      const today = new Date();
      const startDate = new Date(today.getTime() - 6 * 86400000)
        .toISOString()
        .split("T")[0];
      const endDate = today.toISOString().split("T")[0];

      const report = await usageService.getUserUsageReport(testUserId, {
        startDate,
        endDate,
        groupBy: "day",
      });

      expect(report).toBeDefined();
      expect(report.groupBy).toBe("day");
      expect(Array.isArray(report.data)).toBe(true);
      expect(report.data.length).toBeGreaterThan(0);
    });

    it("should get usage report grouped by tunnel", async () => {
      const today = new Date();
      const startDate = new Date(today.getTime() - 6 * 86400000)
        .toISOString()
        .split("T")[0];
      const endDate = today.toISOString().split("T")[0];

      const report = await usageService.getUserUsageReport(testUserId, {
        startDate,
        endDate,
        groupBy: "tunnel",
      });

      expect(report).toBeDefined();
      expect(report.groupBy).toBe("tunnel");
      expect(Array.isArray(report.data)).toBe(true);
    });

    it("should reject invalid groupBy parameter", async () => {
      const today = new Date();
      const startDate = new Date(today.getTime() - 6 * 86400000)
        .toISOString()
        .split("T")[0];
      const endDate = today.toISOString().split("T")[0];

      await expect(
        usageService.getUserUsageReport(testUserId, {
          startDate,
          endDate,
          groupBy: "invalid",
        }),
      ).rejects.toThrow('groupBy must be either "day" or "tunnel"');
    });

    it("should require startDate and endDate", async () => {
      await expect(
        usageService.getUserUsageReport(testUserId, {}),
      ).rejects.toThrow("startDate and endDate are required");
    });
  });

  describe("getBillingSummary", () => {
    beforeEach(async () => {
      // Insert test metrics
      const today = new Date();
      const date = today.toISOString().split("T")[0];
      await pool.query(
        `INSERT INTO tunnel_usage_metrics 
         (tunnel_id, user_id, date, connection_count, data_transferred_bytes, data_received_bytes, 
          peak_concurrent_connections, average_connection_duration_seconds, error_count, success_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (tunnel_id, date) DO NOTHING`,
        [
          testTunnelId,
          testUserId,
          date,
          100,
          1024 * 1024 * 1024,
          1024 * 1024 * 512,
          10,
          300,
          5,
          95,
        ],
      );
    });

    it("should calculate billing for free tier", async () => {
      const today = new Date();
      const periodStart = today.toISOString().split("T")[0];
      const periodEnd = today.toISOString().split("T")[0];

      const billing = await usageService.getBillingSummary(
        testUserId,
        "free",
        periodStart,
        periodEnd,
      );

      expect(billing).toBeDefined();
      expect(billing.userTier).toBe("free");
      expect(billing.billing.amount).toBe(0);
    });

    it("should calculate billing for premium tier", async () => {
      const today = new Date();
      const periodStart = today.toISOString().split("T")[0];
      const periodEnd = today.toISOString().split("T")[0];

      const billing = await usageService.getBillingSummary(
        testUserId,
        "premium",
        periodStart,
        periodEnd,
      );

      expect(billing).toBeDefined();
      expect(billing.userTier).toBe("premium");
      expect(billing.billing.amount).toBeGreaterThanOrEqual(10);
      expect(billing.billing.breakdown.baseCharge).toBe(10);
    });

    it("should calculate billing for enterprise tier", async () => {
      const today = new Date();
      const periodStart = today.toISOString().split("T")[0];
      const periodEnd = today.toISOString().split("T")[0];

      const billing = await usageService.getBillingSummary(
        testUserId,
        "enterprise",
        periodStart,
        periodEnd,
      );

      expect(billing).toBeDefined();
      expect(billing.userTier).toBe("enterprise");
      expect(billing.billing.breakdown.note).toBeDefined();
    });
  });

  describe("getUserUsageAggregation", () => {
    it("should get user usage aggregation", async () => {
      const today = new Date();
      const periodStart = today.toISOString().split("T")[0];
      const periodEnd = today.toISOString().split("T")[0];

      const aggregation = await usageService.getUserUsageAggregation(
        testUserId,
        "premium",
        periodStart,
        periodEnd,
      );

      expect(aggregation).toBeDefined();
      expect(aggregation.userId).toBe(testUserId);
      expect(aggregation.userTier).toBe("premium");
    });

    it("should return zero aggregation if no data exists", async () => {
      const futureDate = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      const aggregation = await usageService.getUserUsageAggregation(
        testUserId,
        "premium",
        futureDate,
        futureDate,
      );

      expect(aggregation).toBeDefined();
      expect(aggregation.totalConnections).toBe(0);
    });
  });
});
