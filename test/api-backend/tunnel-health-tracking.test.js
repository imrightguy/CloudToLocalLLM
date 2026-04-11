/**


 * Tunnel Health and Status Tracking Tests
 *
 * Tests for tunnel status tracking, health checking, and metrics collection
 *
 * Validates: Requirements 4.2, 4.6
 * - Tracks tunnel status and health metrics
 * - Implements tunnel metrics collection and aggregation
 *
 * **Feature: api-backend-enhancement, Property 6: Tunnel state transitions consistency**
 * **Feature: api-backend-enhancement, Property 7: Metrics aggregation consistency**
 *
 * @fileoverview Tunnel health and status tracking tests
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
import { TunnelHealthService } from "../../services/api-backend/services/tunnel-health-service.js";
import { TunnelService } from "../../services/api-backend/services/tunnel-service.js";
import {
  getPool,
  initializePool,
} from "../../services/api-backend/database/db-pool.js";
import { DatabaseMigratorPG } from "../../services/api-backend/database/migrate-pg.js";

describe("Tunnel Health and Status Tracking", () => {
  let tunnelHealthService;
  let tunnelService;
  let dbMigrator;
  let pool;
  let testUserId;

  beforeAll(async () => {
    // Initialize database
    initializePool();
    pool = getPool();

    dbMigrator = new DatabaseMigratorPG();
    await dbMigrator.initialize();
    await dbMigrator.createMigrationsTable();
    await dbMigrator.applyInitialSchema();

    // Initialize services
    tunnelHealthService = new TunnelHealthService();
    await tunnelHealthService.initialize();

    tunnelService = new TunnelService();
    await tunnelService.initialize();

    // Create test user
    const userResult = await pool.query(
      `INSERT INTO users (jwt_id, email, name)
       VALUES ($1, $2, $3)
       RETURNING id`,
      ["test-jwt-id", "test@example.com", "Test User"],
    );
    testUserId = userResult.rows[0].id;
  });

  afterAll(async () => {
    tunnelHealthService.cleanup();
    if (pool) {
      await pool.end();
    }
  });

  beforeEach(async () => {
    // Clean up tunnels before each test
    await pool.query("DELETE FROM tunnels WHERE user_id = $1", [testUserId]);
  });

  describe("Tunnel Status Tracking", () => {
    it("should track tunnel status changes", async () => {
      const tunnelData = {
        name: "Status Test Tunnel",
        config: { maxConnections: 100 },
        endpoints: [{ url: "http://localhost:8000", priority: 1, weight: 1 }],
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      expect(tunnel.status).toBe("created");

      // Update status to connecting
      const updatedTunnel = await tunnelService.updateTunnelStatus(
        tunnel.id,
        testUserId,
        "connecting",
        "127.0.0.1",
        "test-agent",
      );

      expect(updatedTunnel.status).toBe("connecting");

      // Update status to connected
      const connectedTunnel = await tunnelService.updateTunnelStatus(
        tunnel.id,
        testUserId,
        "connected",
        "127.0.0.1",
        "test-agent",
      );

      expect(connectedTunnel.status).toBe("connected");
    });

    it("should reject invalid tunnel status", async () => {
      const tunnelData = {
        name: "Invalid Status Tunnel",
        config: { maxConnections: 100 },
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      await expect(
        tunnelService.updateTunnelStatus(
          tunnel.id,
          testUserId,
          "invalid_status",
          "127.0.0.1",
          "test-agent",
        ),
      ).rejects.toThrow("Invalid status");
    });
  });

  describe("Endpoint Health Checking", () => {
    it("should get endpoint health status", async () => {
      const tunnelData = {
        name: "Health Check Tunnel",
        config: { maxConnections: 100 },
        endpoints: [
          { url: "http://localhost:8000", priority: 1, weight: 1 },
          { url: "http://localhost:8001", priority: 2, weight: 1 },
        ],
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      const healthStatus = await tunnelHealthService.getEndpointHealthStatus(
        tunnel.id,
        testUserId,
      );

      expect(healthStatus).toHaveLength(2);
      expect(healthStatus[0]).toHaveProperty("url");
      expect(healthStatus[0]).toHaveProperty("healthStatus");
      expect(healthStatus[0]).toHaveProperty("lastHealthCheck");
    });

    it("should update endpoint health status", async () => {
      const tunnelData = {
        name: "Update Health Tunnel",
        config: { maxConnections: 100 },
        endpoints: [{ url: "http://localhost:8000", priority: 1, weight: 1 }],
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      const endpoints = await tunnelHealthService.getEndpointHealthStatus(
        tunnel.id,
        testUserId,
      );

      const endpointId = endpoints[0].id;

      await tunnelHealthService.updateEndpointHealthStatus(
        endpointId,
        "healthy",
      );

      const updatedEndpoints =
        await tunnelHealthService.getEndpointHealthStatus(
          tunnel.id,
          testUserId,
        );

      expect(updatedEndpoints[0].healthStatus).toBe("healthy");
    });
  });

  describe("Metrics Collection and Aggregation", () => {
    it("should record request metrics", async () => {
      const tunnelData = {
        name: "Metrics Tunnel",
        config: { maxConnections: 100 },
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      tunnelHealthService.recordRequestMetrics(tunnel.id, {
        latency: 100,
        success: true,
        statusCode: 200,
      });

      tunnelHealthService.recordRequestMetrics(tunnel.id, {
        latency: 150,
        success: true,
        statusCode: 200,
      });

      tunnelHealthService.recordRequestMetrics(tunnel.id, {
        latency: 200,
        success: false,
        statusCode: 500,
      });

      const metrics = tunnelHealthService.getAggregatedMetrics(tunnel.id);

      expect(metrics.requestCount).toBe(3);
      expect(metrics.successCount).toBe(2);
      expect(metrics.errorCount).toBe(1);
      expect(metrics.successRate).toBeCloseTo(66.67, 1);
      expect(metrics.averageLatency).toBeCloseTo(150, 0);
      expect(metrics.minLatency).toBe(100);
      expect(metrics.maxLatency).toBe(200);
    });

    it("should flush metrics to database", async () => {
      const tunnelData = {
        name: "Flush Metrics Tunnel",
        config: { maxConnections: 100 },
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      tunnelHealthService.recordRequestMetrics(tunnel.id, {
        latency: 100,
        success: true,
        statusCode: 200,
      });

      tunnelHealthService.recordRequestMetrics(tunnel.id, {
        latency: 200,
        success: false,
        statusCode: 500,
      });

      await tunnelHealthService.flushMetricsToDatabase(tunnel.id);

      const storedTunnel = await tunnelService.getTunnelById(
        tunnel.id,
        testUserId,
      );
      const storedMetrics = storedTunnel.metrics;

      expect(storedMetrics.requestCount).toBe(2);
      expect(storedMetrics.successCount).toBe(1);
      expect(storedMetrics.errorCount).toBe(1);
    });

    it("should calculate success rate correctly", async () => {
      const tunnelData = {
        name: "Success Rate Tunnel",
        config: { maxConnections: 100 },
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      // Record 10 successful requests
      for (let i = 0; i < 10; i++) {
        tunnelHealthService.recordRequestMetrics(tunnel.id, {
          latency: 100,
          success: true,
          statusCode: 200,
        });
      }

      const metrics = tunnelHealthService.getAggregatedMetrics(tunnel.id);

      expect(metrics.successRate).toBe(100);
    });

    it("should handle empty metrics", async () => {
      const tunnelData = {
        name: "Empty Metrics Tunnel",
        config: { maxConnections: 100 },
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      const metrics = tunnelHealthService.getAggregatedMetrics(tunnel.id);

      expect(metrics.requestCount).toBe(0);
      expect(metrics.successCount).toBe(0);
      expect(metrics.errorCount).toBe(0);
      expect(metrics.successRate).toBe(0);
      expect(metrics.averageLatency).toBe(0);
    });
  });

  describe("Tunnel Status Summary", () => {
    it("should get tunnel status summary", async () => {
      const tunnelData = {
        name: "Summary Tunnel",
        config: { maxConnections: 100 },
        endpoints: [
          { url: "http://localhost:8000", priority: 1, weight: 1 },
          { url: "http://localhost:8001", priority: 2, weight: 1 },
        ],
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      const summary = await tunnelHealthService.getTunnelStatusSummary(
        tunnel.id,
        testUserId,
      );

      expect(summary).toHaveProperty("tunnelId");
      expect(summary).toHaveProperty("status");
      expect(summary).toHaveProperty("metrics");
      expect(summary).toHaveProperty("endpoints");
      expect(summary.endpoints.total).toBe(2);
      expect(summary).toHaveProperty("lastUpdated");
    });

    it("should include endpoint details in status summary", async () => {
      const tunnelData = {
        name: "Endpoint Details Tunnel",
        config: { maxConnections: 100 },
        endpoints: [{ url: "http://localhost:8000", priority: 1, weight: 1 }],
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      const summary = await tunnelHealthService.getTunnelStatusSummary(
        tunnel.id,
        testUserId,
      );

      expect(summary.endpoints.details).toHaveLength(1);
      expect(summary.endpoints.details[0]).toHaveProperty("id");
      expect(summary.endpoints.details[0]).toHaveProperty("url");
      expect(summary.endpoints.details[0]).toHaveProperty("healthStatus");
      expect(summary.endpoints.details[0]).toHaveProperty("priority");
      expect(summary.endpoints.details[0]).toHaveProperty("weight");
    });
  });

  describe("Health Check Lifecycle", () => {
    it("should start and stop health checks", async () => {
      const tunnelData = {
        name: "Health Check Lifecycle Tunnel",
        config: { maxConnections: 100 },
        endpoints: [{ url: "http://localhost:8000", priority: 1, weight: 1 }],
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      tunnelHealthService.startHealthChecks(tunnel.id, 1000);
      expect(tunnelHealthService.healthCheckIntervals.has(tunnel.id)).toBe(
        true,
      );

      tunnelHealthService.stopHealthChecks(tunnel.id);
      expect(tunnelHealthService.healthCheckIntervals.has(tunnel.id)).toBe(
        false,
      );
    });

    it("should not start duplicate health checks", async () => {
      const tunnelData = {
        name: "Duplicate Health Check Tunnel",
        config: { maxConnections: 100 },
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      tunnelHealthService.startHealthChecks(tunnel.id, 1000);
      const firstInterval = tunnelHealthService.healthCheckIntervals.get(
        tunnel.id,
      );

      tunnelHealthService.startHealthChecks(tunnel.id, 1000);
      const secondInterval = tunnelHealthService.healthCheckIntervals.get(
        tunnel.id,
      );

      expect(firstInterval).toBe(secondInterval);

      tunnelHealthService.stopHealthChecks(tunnel.id);
    });
  });
});
