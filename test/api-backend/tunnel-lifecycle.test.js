/**


 * Tunnel Lifecycle Management Tests
 *
 * Tests for tunnel creation, retrieval, updates, deletion, and status management
 *
 * Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.6
 * - Provides endpoints for tunnel lifecycle management (create, start, stop, delete)
 * - Tracks tunnel status and health metrics
 * - Implements tunnel configuration management
 * - Supports multiple tunnel endpoints for failover
 * - Implements tunnel metrics collection and aggregation
 *
 * @fileoverview Tunnel lifecycle management tests
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
import { TunnelService } from "../../services/api-backend/services/tunnel-service.js";
import {
  getPool,
  initializePool,
} from "../../services/api-backend/database/db-pool.js";
import { DatabaseMigratorPG } from "../../services/api-backend/database/migrate-pg.js";

describe("Tunnel Lifecycle Management", () => {
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

    // Initialize tunnel service
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
    // Clean up
    if (pool) {
      await pool.end();
    }
  });

  beforeEach(async () => {
    // Clean up tunnels before each test
    await pool.query("DELETE FROM tunnels WHERE user_id = $1", [testUserId]);
  });

  describe("Tunnel Creation", () => {
    it("should create a tunnel with valid data", async () => {
      const tunnelData = {
        name: "Test Tunnel",
        config: {
          maxConnections: 100,
          timeout: 30000,
          compression: true,
        },
        endpoints: [
          {
            url: "http://localhost:8000",
            priority: 1,
            weight: 1,
          },
        ],
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      expect(tunnel).toBeDefined();
      expect(tunnel.id).toBeDefined();
      expect(tunnel.user_id).toBe(testUserId);
      expect(tunnel.name).toBe("Test Tunnel");
      expect(tunnel.status).toBe("created");
      expect(tunnel.config.maxConnections).toBe(100);
      expect(tunnel.endpoints).toHaveLength(1);
      expect(tunnel.endpoints[0].url).toBe("http://localhost:8000");
    });

    it("should reject tunnel creation with empty name", async () => {
      const tunnelData = {
        name: "",
        config: {},
      };

      await expect(
        tunnelService.createTunnel(
          testUserId,
          tunnelData,
          "127.0.0.1",
          "test-agent",
        ),
      ).rejects.toThrow("Tunnel name is required");
    });

    it("should reject tunnel creation with duplicate name", async () => {
      const tunnelData = {
        name: "Duplicate Tunnel",
        config: {},
      };

      // Create first tunnel
      await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      // Try to create duplicate
      await expect(
        tunnelService.createTunnel(
          testUserId,
          tunnelData,
          "127.0.0.1",
          "test-agent",
        ),
      ).rejects.toThrow("already exists");
    });

    it("should reject tunnel name exceeding 255 characters", async () => {
      const tunnelData = {
        name: "a".repeat(256),
        config: {},
      };

      await expect(
        tunnelService.createTunnel(
          testUserId,
          tunnelData,
          "127.0.0.1",
          "test-agent",
        ),
      ).rejects.toThrow("must not exceed 255 characters");
    });
  });

  describe("Tunnel Retrieval", () => {
    it("should retrieve tunnel by ID", async () => {
      const tunnelData = {
        name: "Retrieve Test",
        config: { maxConnections: 50 },
      };

      const created = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      const retrieved = await tunnelService.getTunnelById(
        created.id,
        testUserId,
      );

      expect(retrieved).toBeDefined();
      expect(retrieved.id).toBe(created.id);
      expect(retrieved.name).toBe("Retrieve Test");
      expect(retrieved.config.maxConnections).toBe(50);
    });

    it("should reject retrieval of non-existent tunnel", async () => {
      await expect(
        tunnelService.getTunnelById("non-existent-id", testUserId),
      ).rejects.toThrow("Tunnel not found");
    });

    it("should reject retrieval of tunnel owned by different user", async () => {
      const tunnelData = {
        name: "Auth Test",
        config: {},
      };

      const tunnel = await tunnelService.createTunnel(
        testUserId,
        tunnelData,
        "127.0.0.1",
        "test-agent",
      );

      // Create another user
      const otherUserResult = await pool.query(
        `INSERT INTO users (jwt_id, email, name)
         VALUES ($1, $2, $3)
         RETURNING id`,
        ["other-jwt-id", "other@example.com", "Other User"],
      );
      const otherUserId = otherUserResult.rows[0].id;

      await expect(
        tunnelService.getTunnelById(tunnel.id, otherUserId),
      ).rejects.toThrow("Tunnel not found");
    });
  });

  describe("Tunnel Listing", () => {
    it("should list tunnels for user", async () => {
      // Create multiple tunnels
      for (let i = 0; i < 3; i++) {
        await tunnelService.createTunnel(
          testUserId,
          { name: `Tunnel ${i}`, config: {} },
          "127.0.0.1",
          "test-agent",
        );
      }

      const result = await tunnelService.listTunnels(testUserId);

      expect(result.tunnels).toHaveLength(3);
      expect(result.total).toBe(3);
      expect(result.limit).toBe(50);
      expect(result.offset).toBe(0);
    });

    it("should support pagination", async () => {
      // Create 5 tunnels
      for (let i = 0; i < 5; i++) {
        await tunnelService.createTunnel(
          testUserId,
          { name: `Tunnel ${i}`, config: {} },
          "127.0.0.1",
          "test-agent",
        );
      }

      const result = await tunnelService.listTunnels(testUserId, {
        limit: 2,
        offset: 0,
      });

      expect(result.tunnels).toHaveLength(2);
      expect(result.total).toBe(5);
    });
  });

  describe("Tunnel Updates", () => {
    it("should update tunnel name", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Original Name", config: {} },
        "127.0.0.1",
        "test-agent",
      );

      const updated = await tunnelService.updateTunnel(
        tunnel.id,
        testUserId,
        { name: "Updated Name" },
        "127.0.0.1",
        "test-agent",
      );

      expect(updated.name).toBe("Updated Name");
    });

    it("should update tunnel config", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Config Test", config: { maxConnections: 50 } },
        "127.0.0.1",
        "test-agent",
      );

      const updated = await tunnelService.updateTunnel(
        tunnel.id,
        testUserId,
        { config: { maxConnections: 200 } },
        "127.0.0.1",
        "test-agent",
      );

      expect(updated.config.maxConnections).toBe(200);
    });

    it("should update tunnel endpoints", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        {
          name: "Endpoint Test",
          config: {},
          endpoints: [{ url: "http://localhost:8000", priority: 1 }],
        },
        "127.0.0.1",
        "test-agent",
      );

      const updated = await tunnelService.updateTunnel(
        tunnel.id,
        testUserId,
        {
          endpoints: [
            { url: "http://localhost:9000", priority: 1 },
            { url: "http://localhost:9001", priority: 2 },
          ],
        },
        "127.0.0.1",
        "test-agent",
      );

      expect(updated.endpoints).toHaveLength(2);
      expect(updated.endpoints[0].url).toBe("http://localhost:9000");
    });
  });

  describe("Tunnel Status Management", () => {
    it("should update tunnel status to connecting", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Status Test", config: {} },
        "127.0.0.1",
        "test-agent",
      );

      const updated = await tunnelService.updateTunnelStatus(
        tunnel.id,
        testUserId,
        "connecting",
        "127.0.0.1",
        "test-agent",
      );

      expect(updated.status).toBe("connecting");
    });

    it("should update tunnel status to connected", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Status Test", config: {} },
        "127.0.0.1",
        "test-agent",
      );

      const updated = await tunnelService.updateTunnelStatus(
        tunnel.id,
        testUserId,
        "connected",
        "127.0.0.1",
        "test-agent",
      );

      expect(updated.status).toBe("connected");
    });

    it("should update tunnel status to disconnected", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Status Test", config: {} },
        "127.0.0.1",
        "test-agent",
      );

      const updated = await tunnelService.updateTunnelStatus(
        tunnel.id,
        testUserId,
        "disconnected",
        "127.0.0.1",
        "test-agent",
      );

      expect(updated.status).toBe("disconnected");
    });

    it("should reject invalid status", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Status Test", config: {} },
        "127.0.0.1",
        "test-agent",
      );

      await expect(
        tunnelService.updateTunnelStatus(
          tunnel.id,
          testUserId,
          "invalid-status",
          "127.0.0.1",
          "test-agent",
        ),
      ).rejects.toThrow("Invalid status");
    });
  });

  describe("Tunnel Deletion", () => {
    it("should delete tunnel", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Delete Test", config: {} },
        "127.0.0.1",
        "test-agent",
      );

      await tunnelService.deleteTunnel(
        tunnel.id,
        testUserId,
        "127.0.0.1",
        "test-agent",
      );

      await expect(
        tunnelService.getTunnelById(tunnel.id, testUserId),
      ).rejects.toThrow("Tunnel not found");
    });

    it("should reject deletion of non-existent tunnel", async () => {
      await expect(
        tunnelService.deleteTunnel(
          "non-existent-id",
          testUserId,
          "127.0.0.1",
          "test-agent",
        ),
      ).rejects.toThrow("Tunnel not found");
    });
  });

  describe("Tunnel Metrics", () => {
    it("should retrieve tunnel metrics", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Metrics Test", config: {} },
        "127.0.0.1",
        "test-agent",
      );

      const metrics = await tunnelService.getTunnelMetrics(
        tunnel.id,
        testUserId,
      );

      expect(metrics).toBeDefined();
      expect(metrics.requestCount).toBe(0);
      expect(metrics.successCount).toBe(0);
      expect(metrics.errorCount).toBe(0);
      expect(metrics.averageLatency).toBe(0);
    });

    it("should update tunnel metrics", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Metrics Test", config: {} },
        "127.0.0.1",
        "test-agent",
      );

      const newMetrics = {
        requestCount: 100,
        successCount: 95,
        errorCount: 5,
        averageLatency: 150,
      };

      await tunnelService.updateTunnelMetrics(tunnel.id, newMetrics);

      const metrics = await tunnelService.getTunnelMetrics(
        tunnel.id,
        testUserId,
      );

      expect(metrics.requestCount).toBe(100);
      expect(metrics.successCount).toBe(95);
      expect(metrics.errorCount).toBe(5);
      expect(metrics.averageLatency).toBe(150);
    });
  });

  describe("Tunnel Activity Logs", () => {
    it("should retrieve tunnel activity logs", async () => {
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        { name: "Activity Test", config: {} },
        "127.0.0.1",
        "test-agent",
      );

      // Perform some operations
      await tunnelService.updateTunnelStatus(
        tunnel.id,
        testUserId,
        "connecting",
        "127.0.0.1",
        "test-agent",
      );

      const logs = await tunnelService.getTunnelActivityLogs(
        tunnel.id,
        testUserId,
      );

      expect(logs).toBeDefined();
      expect(logs.length).toBeGreaterThan(0);
      expect(logs[0].action).toBeDefined();
      expect(logs[0].status).toBeDefined();
    });
  });
});
