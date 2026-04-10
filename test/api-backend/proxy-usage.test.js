/**


 * Proxy Usage Tracking Tests
 *
 * Tests for proxy usage tracking functionality:
 * - Record usage events
 * - Track usage metrics
 * - Aggregate usage data
 * - Generate usage reports
 * - Calculate billing
 *
 * Validates: Requirements 5.9
 */

import {
  describe,
  it,
  expect,
  beforeAll,
  afterAll,
  beforeEach,
} from "@jest/globals";
import { Pool } from "pg";
import ProxyUsageService from "../../services/api-backend/services/proxy-usage-service.js";
import { v4 as uuidv4 } from "uuid";

describe("Proxy Usage Tracking", () => {
  let pool;
  let proxyUsageService;
  let testUserId;
  let testProxyId;

  beforeAll(async () => {
    // Initialize database connection
    pool = new Pool({
      connectionString:
        process.env.DATABASE_URL ||
        "postgresql://localhost/cloudtolocalllm_test",
    });

    proxyUsageService = new ProxyUsageService();
    proxyUsageService.pool = pool;

    // Create test user
    const userResult = await pool.query(
      `INSERT INTO users (id, email, jwt_id, tier, is_active)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id`,
      [
        uuidv4(),
        "test-proxy-usage@example.com",
        "jwt|test-proxy-usage",
        "premium",
        true,
      ],
    );
    testUserId = userResult.rows[0].id;

    // Create test proxy health status
    testProxyId = `proxy-${uuidv4()}`;
    await pool.query(
      `INSERT INTO proxy_health_status (proxy_id, user_id, status, last_health_check)
       VALUES ($1, $2, $3, $4)`,
      [testProxyId, testUserId, "healthy", new Date()],
    );
  });

  afterAll(async () => {
    // Cleanup
    await pool.query("DELETE FROM proxy_usage_events WHERE user_id = $1", [
      testUserId,
    ]);
    await pool.query("DELETE FROM proxy_usage_metrics WHERE user_id = $1", [
      testUserId,
    ]);
    await pool.query("DELETE FROM proxy_usage_aggregation WHERE user_id = $1", [
      testUserId,
    ]);
    await pool.query("DELETE FROM proxy_usage_summary WHERE user_id = $1", [
      testUserId,
    ]);
    await pool.query("DELETE FROM proxy_health_status WHERE proxy_id = $1", [
      testProxyId,
    ]);
    await pool.query("DELETE FROM users WHERE id = $1", [testUserId]);
    await pool.end();
  });

  describe("Record Usage Events", () => {
    it("should record a connection_start event", async () => {
      const event = await proxyUsageService.recordUsageEvent(
        testProxyId,
        testUserId,
        "connection_start",
        {
          connectionId: "conn-123",
          ipAddress: "192.168.1.1",
        },
      );

      expect(event).toBeDefined();
      expect(event.proxy_id).toBe(testProxyId);
      expect(event.user_id).toBe(testUserId);
      expect(event.event_type).toBe("connection_start");
      expect(event.connection_id).toBe("conn-123");
    });

    it("should record a data_transfer event", async () => {
      const event = await proxyUsageService.recordUsageEvent(
        testProxyId,
        testUserId,
        "data_transfer",
        {
          connectionId: "conn-123",
          dataBytes: 1024,
        },
      );

      expect(event).toBeDefined();
      expect(event.event_type).toBe("data_transfer");
      expect(event.data_bytes).toBe(1024);
    });

    it("should record a connection_end event", async () => {
      const event = await proxyUsageService.recordUsageEvent(
        testProxyId,
        testUserId,
        "connection_end",
        {
          connectionId: "conn-123",
          durationSeconds: 60,
        },
      );

      expect(event).toBeDefined();
      expect(event.event_type).toBe("connection_end");
      expect(event.duration_seconds).toBe(60);
    });

    it("should record an error event", async () => {
      const event = await proxyUsageService.recordUsageEvent(
        testProxyId,
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

    it("should reject invalid event types", async () => {
      await expect(
        proxyUsageService.recordUsageEvent(
          testProxyId,
          testUserId,
          "invalid_type",
          {},
        ),
      ).rejects.toThrow("Invalid event type");
    });
  });

  describe("Get Usage Metrics", () => {
    beforeEach(async () => {
      // Insert test metrics
      const today = new Date().toISOString().split("T")[0];
      await pool.query(
        `INSERT INTO proxy_usage_metrics 
         (proxy_id, user_id, date, connection_count, data_transferred_bytes, 
          data_received_bytes, peak_concurrent_connections, average_connection_duration_seconds,
          error_count, success_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (proxy_id, date) DO UPDATE SET
           connection_count = $4,
           data_transferred_bytes = $5,
           data_received_bytes = $6,
           peak_concurrent_connections = $7,
           average_connection_duration_seconds = $8,
           error_count = $9,
           success_count = $10`,
        [testProxyId, testUserId, today, 100, 5242880, 2621440, 10, 30, 2, 98],
      );
    });

    it("should get usage metrics for a specific date", async () => {
      const today = new Date().toISOString().split("T")[0];
      const metrics = await proxyUsageService.getProxyUsageMetrics(
        testProxyId,
        testUserId,
        today,
      );

      expect(metrics).toBeDefined();
      expect(metrics.proxyId).toBe(testProxyId);
      expect(metrics.date).toBe(today);
      expect(metrics.connectionCount).toBe(100);
      expect(metrics.dataTransferredBytes).toBe(5242880);
      expect(metrics.dataReceivedBytes).toBe(2621440);
      expect(metrics.peakConcurrentConnections).toBe(10);
      expect(metrics.averageConnectionDurationSeconds).toBe(30);
      expect(metrics.errorCount).toBe(2);
      expect(metrics.successCount).toBe(98);
    });

    it("should return zero metrics for non-existent date", async () => {
      const futureDate = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];
      const metrics = await proxyUsageService.getProxyUsageMetrics(
        testProxyId,
        testUserId,
        futureDate,
      );

      expect(metrics).toBeDefined();
      expect(metrics.connectionCount).toBe(0);
      expect(metrics.dataTransferredBytes).toBe(0);
    });

    it("should get usage metrics for a date range", async () => {
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      const metrics = await proxyUsageService.getProxyUsageMetricsRange(
        testProxyId,
        testUserId,
        today,
        tomorrow,
      );

      expect(Array.isArray(metrics)).toBe(true);
      expect(metrics.length).toBeGreaterThan(0);
      expect(metrics[0].proxyId).toBe(testProxyId);
    });

    it("should reject unauthorized access", async () => {
      const otherUserId = uuidv4();
      await expect(
        proxyUsageService.getProxyUsageMetrics(
          testProxyId,
          otherUserId,
          "2024-01-01",
        ),
      ).rejects.toThrow("Proxy not found");
    });
  });

  describe("Usage Aggregation", () => {
    beforeEach(async () => {
      // Insert test metrics for aggregation
      const today = new Date().toISOString().split("T")[0];
      const yesterday = new Date(Date.now() - 86400000)
        .toISOString()
        .split("T")[0];

      await pool.query(
        `INSERT INTO proxy_usage_metrics 
         (proxy_id, user_id, date, connection_count, data_transferred_bytes, 
          data_received_bytes, peak_concurrent_connections, average_connection_duration_seconds,
          error_count, success_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (proxy_id, date) DO UPDATE SET
           connection_count = $4,
           data_transferred_bytes = $5,
           data_received_bytes = $6,
           peak_concurrent_connections = $7,
           average_connection_duration_seconds = $8,
           error_count = $9,
           success_count = $10`,
        [testProxyId, testUserId, today, 100, 5242880, 2621440, 10, 30, 2, 98],
      );

      await pool.query(
        `INSERT INTO proxy_usage_metrics 
         (proxy_id, user_id, date, connection_count, data_transferred_bytes, 
          data_received_bytes, peak_concurrent_connections, average_connection_duration_seconds,
          error_count, success_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (proxy_id, date) DO UPDATE SET
           connection_count = $4,
           data_transferred_bytes = $5,
           data_received_bytes = $6,
           peak_concurrent_connections = $7,
           average_connection_duration_seconds = $8,
           error_count = $9,
           success_count = $10`,
        [
          testProxyId,
          testUserId,
          yesterday,
          80,
          4194304,
          2097152,
          8,
          25,
          1,
          79,
        ],
      );
    });

    it("should aggregate user usage for a period", async () => {
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      const aggregation = await proxyUsageService.aggregateUserUsage(
        testUserId,
        "premium",
        today,
        tomorrow,
      );

      expect(aggregation).toBeDefined();
      expect(aggregation.user_id).toBe(testUserId);
      expect(aggregation.user_tier).toBe("premium");
      expect(aggregation.total_connections).toBeGreaterThan(0);
      expect(aggregation.total_data_transferred_bytes).toBeGreaterThan(0);
    });

    it("should get user usage aggregation", async () => {
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      // First aggregate
      await proxyUsageService.aggregateUserUsage(
        testUserId,
        "premium",
        today,
        tomorrow,
      );

      // Then retrieve
      const aggregation = await proxyUsageService.getUserUsageAggregation(
        testUserId,
        "premium",
        today,
        tomorrow,
      );

      expect(aggregation).toBeDefined();
      expect(aggregation.userId).toBe(testUserId);
      expect(aggregation.userTier).toBe("premium");
    });

    it("should return zero aggregation for user with no proxies", async () => {
      const otherUserId = uuidv4();
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      // Create user without proxies
      await pool.query(
        `INSERT INTO users (id, email, jwt_id, tier, is_active)
         VALUES ($1, $2, $3, $4, $5)`,
        [
          otherUserId,
          "test-no-proxy@example.com",
          "jwt|test-no-proxy",
          "free",
          true,
        ],
      );

      const aggregation = await proxyUsageService.aggregateUserUsage(
        otherUserId,
        "free",
        today,
        tomorrow,
      );

      expect(aggregation).toBeDefined();
      expect(aggregation.total_connections).toBe(0);

      // Cleanup
      await pool.query("DELETE FROM users WHERE id = $1", [otherUserId]);
    });
  });

  describe("Usage Reports", () => {
    beforeEach(async () => {
      // Insert test metrics for reporting
      const today = new Date().toISOString().split("T")[0];
      await pool.query(
        `INSERT INTO proxy_usage_metrics 
         (proxy_id, user_id, date, connection_count, data_transferred_bytes, 
          data_received_bytes, peak_concurrent_connections, average_connection_duration_seconds,
          error_count, success_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (proxy_id, date) DO UPDATE SET
           connection_count = $4,
           data_transferred_bytes = $5,
           data_received_bytes = $6,
           peak_concurrent_connections = $7,
           average_connection_duration_seconds = $8,
           error_count = $9,
           success_count = $10`,
        [testProxyId, testUserId, today, 100, 5242880, 2621440, 10, 30, 2, 98],
      );
    });

    it("should generate usage report grouped by day", async () => {
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      const report = await proxyUsageService.getUserUsageReport(testUserId, {
        startDate: today,
        endDate: tomorrow,
        groupBy: "day",
      });

      expect(report).toBeDefined();
      expect(report.userId).toBe(testUserId);
      expect(report.groupBy).toBe("day");
      expect(Array.isArray(report.data)).toBe(true);
    });

    it("should generate usage report grouped by proxy", async () => {
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      const report = await proxyUsageService.getUserUsageReport(testUserId, {
        startDate: today,
        endDate: tomorrow,
        groupBy: "proxy",
      });

      expect(report).toBeDefined();
      expect(report.userId).toBe(testUserId);
      expect(report.groupBy).toBe("proxy");
      expect(Array.isArray(report.data)).toBe(true);
    });

    it("should reject invalid groupBy parameter", async () => {
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      await expect(
        proxyUsageService.getUserUsageReport(testUserId, {
          startDate: today,
          endDate: tomorrow,
          groupBy: "invalid",
        }),
      ).rejects.toThrow('groupBy must be either "day" or "proxy"');
    });

    it("should require startDate and endDate", async () => {
      await expect(
        proxyUsageService.getUserUsageReport(testUserId, {}),
      ).rejects.toThrow("startDate and endDate are required");
    });
  });

  describe("Billing Summary", () => {
    beforeEach(async () => {
      // Insert test metrics for billing
      const today = new Date().toISOString().split("T")[0];
      await pool.query(
        `INSERT INTO proxy_usage_metrics 
         (proxy_id, user_id, date, connection_count, data_transferred_bytes, 
          data_received_bytes, peak_concurrent_connections, average_connection_duration_seconds,
          error_count, success_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
         ON CONFLICT (proxy_id, date) DO UPDATE SET
           connection_count = $4,
           data_transferred_bytes = $5,
           data_received_bytes = $6,
           peak_concurrent_connections = $7,
           average_connection_duration_seconds = $8,
           error_count = $9,
           success_count = $10`,
        [
          testProxyId,
          testUserId,
          today,
          100,
          5368709120,
          2684354560,
          10,
          30,
          2,
          98,
        ],
      );
    });

    it("should calculate billing for free tier", async () => {
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      const billing = await proxyUsageService.getBillingSummary(
        testUserId,
        "free",
        today,
        tomorrow,
      );

      expect(billing).toBeDefined();
      expect(billing.userTier).toBe("free");
      expect(billing.billing.amount).toBe(0);
      expect(billing.billing.breakdown.baseCharge).toBe(0);
    });

    it("should calculate billing for premium tier", async () => {
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      const billing = await proxyUsageService.getBillingSummary(
        testUserId,
        "premium",
        today,
        tomorrow,
      );

      expect(billing).toBeDefined();
      expect(billing.userTier).toBe("premium");
      expect(billing.billing.amount).toBeGreaterThan(0);
      expect(billing.billing.breakdown.baseCharge).toBe(10);
      expect(billing.billing.breakdown.dataTransferCharge).toBeGreaterThan(0);
    });

    it("should calculate billing for enterprise tier", async () => {
      const today = new Date().toISOString().split("T")[0];
      const tomorrow = new Date(Date.now() + 86400000)
        .toISOString()
        .split("T")[0];

      const billing = await proxyUsageService.getBillingSummary(
        testUserId,
        "enterprise",
        today,
        tomorrow,
      );

      expect(billing).toBeDefined();
      expect(billing.userTier).toBe("enterprise");
      expect(billing.billing.breakdown.note).toBe(
        "Custom pricing - contact sales",
      );
    });
  });
});
