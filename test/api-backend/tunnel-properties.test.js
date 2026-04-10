/**


 * Tunnel Lifecycle Property-Based Tests
 *
 * Property-based tests for tunnel state transitions and consistency
 *
 * **Feature: api-backend-enhancement, Property 6: Tunnel state transitions consistency**
 * **Validates: Requirements 4.1, 4.2**
 *
 * Property 6: Tunnel state transitions consistency
 * *For any* tunnel, the state transitions should follow valid paths and maintain consistency
 * between the tunnel status and its operational state.
 *
 * @fileoverview Property-based tests for tunnel lifecycle
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

describe("Tunnel Lifecycle Property-Based Tests", () => {
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
      ["test-jwt-id-pbt", "test-pbt@example.com", "Test User PBT"],
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

  /**
   * Property 6: Tunnel state transitions consistency
   *
   * For any tunnel, the state transitions should follow valid paths and maintain
   * consistency between the tunnel status and its operational state.
   *
   * Valid state transitions:
   * - created -> connecting
   * - connecting -> connected
   * - connecting -> error
   * - connected -> disconnected
   * - disconnected -> connecting
   * - error -> connecting
   *
   * Validates: Requirements 4.1, 4.2
   */
  it("should maintain consistent tunnel state transitions", async () => {
    // Define valid state transitions
    const validTransitions = {
      created: ["connecting"],
      connecting: ["connected", "error"],
      connected: ["disconnected"],
      disconnected: ["connecting"],
      error: ["connecting"],
    };

    // Define valid state transition sequences
    const validSequences = [
      ["created", "connecting", "connected", "disconnected"],
      ["created", "connecting", "error", "connecting", "connected"],
      [
        "created",
        "connecting",
        "connected",
        "disconnected",
        "connecting",
        "connected",
      ],
    ];

    // Property: For any valid state sequence, all transitions should succeed
    for (
      let sequenceIndex = 0;
      sequenceIndex < validSequences.length;
      sequenceIndex++
    ) {
      const sequence = validSequences[sequenceIndex];

      // Create tunnel
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        {
          name: `tunnel-${Date.now()}-${Math.random()}`,
          config: {},
        },
        "127.0.0.1",
        "test-agent",
      );

      expect(tunnel.status).toBe("created");

      // Execute state transitions
      let currentTunnel = tunnel;
      for (let i = 1; i < sequence.length; i++) {
        const targetStatus = sequence[i];

        // Verify transition is valid
        const currentStatus = currentTunnel.status;
        const validNextStates = validTransitions[currentStatus];
        expect(validNextStates).toContain(targetStatus);

        // Perform transition
        currentTunnel = await tunnelService.updateTunnelStatus(
          currentTunnel.id,
          testUserId,
          targetStatus,
          "127.0.0.1",
          "test-agent",
        );

        // Verify status was updated
        expect(currentTunnel.status).toBe(targetStatus);

        // Verify tunnel can be retrieved with new status
        const retrieved = await tunnelService.getTunnelById(
          currentTunnel.id,
          testUserId,
        );
        expect(retrieved.status).toBe(targetStatus);
      }
    }
  });

  /**
   * Property: Tunnel status should be retrievable after any valid transition
   *
   * For any tunnel that has undergone valid state transitions, the tunnel
   * should be retrievable and its status should match the last transition.
   *
   * Validates: Requirements 4.1, 4.2
   */
  it("should maintain retrievable tunnel status after transitions", async () => {
    const validStatuses = [
      "created",
      "connecting",
      "connected",
      "disconnected",
      "error",
    ];

    // Test multiple random transition sequences
    for (let testRun = 0; testRun < 10; testRun++) {
      // Create tunnel
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        {
          name: `tunnel-${Date.now()}-${Math.random()}`,
          config: {},
        },
        "127.0.0.1",
        "test-agent",
      );

      let currentStatus = "created";
      let currentTunnel = tunnel;

      // Apply random transitions
      for (let i = 0; i < 5; i++) {
        const statusIndex = Math.floor(Math.random() * validStatuses.length);
        const targetStatus = validStatuses[statusIndex];

        // Skip if same status
        if (targetStatus === currentStatus) {
          continue;
        }

        // Try to transition (may fail if invalid, which is ok)
        try {
          currentTunnel = await tunnelService.updateTunnelStatus(
            currentTunnel.id,
            testUserId,
            targetStatus,
            "127.0.0.1",
            "test-agent",
          );
          currentStatus = targetStatus;
        } catch (error) {
          // Invalid transition, skip
          continue;
        }
      }

      // Verify tunnel is still retrievable with correct status
      const retrieved = await tunnelService.getTunnelById(
        currentTunnel.id,
        testUserId,
      );
      expect(retrieved.status).toBe(currentStatus);
      expect(retrieved.id).toBe(currentTunnel.id);
      expect(retrieved.user_id).toBe(testUserId);
    }
  });

  /**
   * Property: Tunnel metrics should be consistent with tunnel status
   *
   * For any tunnel, the metrics should be retrievable and should contain
   * valid numeric values regardless of the tunnel's current status.
   *
   * Validates: Requirements 4.1, 4.2
   */
  it("should maintain consistent metrics across tunnel states", async () => {
    const validStatuses = [
      "created",
      "connecting",
      "connected",
      "disconnected",
      "error",
    ];

    // Test multiple random metric scenarios
    for (let testRun = 0; testRun < 10; testRun++) {
      // Create tunnel
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        {
          name: `tunnel-${Date.now()}-${Math.random()}`,
          config: {},
        },
        "127.0.0.1",
        "test-agent",
      );

      // Update to random status
      const statusIndex = Math.floor(Math.random() * validStatuses.length);
      const targetStatus = validStatuses[statusIndex];
      try {
        await tunnelService.updateTunnelStatus(
          tunnel.id,
          testUserId,
          targetStatus,
          "127.0.0.1",
          "test-agent",
        );
      } catch (error) {
        // Invalid transition, skip
      }

      // Update metrics with random values
      const requestCount = Math.floor(Math.random() * 1000);
      const successCount = Math.floor(Math.random() * requestCount);
      const errorCount = Math.floor(Math.random() * requestCount);

      const metrics = {
        requestCount,
        successCount,
        errorCount,
        averageLatency: Math.random() * 1000,
      };

      await tunnelService.updateTunnelMetrics(tunnel.id, metrics);

      // Retrieve and verify metrics
      const retrieved = await tunnelService.getTunnelMetrics(
        tunnel.id,
        testUserId,
      );

      expect(retrieved.requestCount).toBe(metrics.requestCount);
      expect(retrieved.successCount).toBe(metrics.successCount);
      expect(retrieved.errorCount).toBe(metrics.errorCount);
      expect(typeof retrieved.averageLatency).toBe("number");
      expect(retrieved.averageLatency).toBeGreaterThanOrEqual(0);
    }
  });

  /**
   * Property: Tunnel creation should always result in 'created' status
   *
   * For any tunnel creation with valid data, the resulting tunnel should
   * always have status 'created' and be retrievable.
   *
   * Validates: Requirements 4.1
   */
  it("should always create tunnels with created status", async () => {
    // Test multiple tunnel creations with random config
    for (let testRun = 0; testRun < 10; testRun++) {
      const maxConnections = Math.floor(Math.random() * 1000) + 1;
      const compression = Math.random() > 0.5;

      // Create tunnel
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        {
          name: `tunnel-${Date.now()}-${Math.random()}`,
          config: {
            maxConnections,
            compression,
          },
        },
        "127.0.0.1",
        "test-agent",
      );

      // Verify initial status
      expect(tunnel.status).toBe("created");
      expect(tunnel.id).toBeDefined();
      expect(tunnel.user_id).toBe(testUserId);
      expect(tunnel.config.maxConnections).toBe(maxConnections);
      expect(tunnel.config.compression).toBe(compression);

      // Verify retrievable
      const retrieved = await tunnelService.getTunnelById(
        tunnel.id,
        testUserId,
      );
      expect(retrieved.status).toBe("created");
    }
  });

  /**
   * Property: Tunnel status updates should be idempotent
   *
   * For any tunnel, updating to the same status multiple times should
   * result in the same tunnel state.
   *
   * Validates: Requirements 4.2
   */
  it("should handle idempotent status updates", async () => {
    const validStatuses = [
      "created",
      "connecting",
      "connected",
      "disconnected",
      "error",
    ];

    // Test multiple idempotent update scenarios
    for (let testRun = 0; testRun < 10; testRun++) {
      // Create tunnel
      const tunnel = await tunnelService.createTunnel(
        testUserId,
        {
          name: `tunnel-${Date.now()}-${Math.random()}`,
          config: {},
        },
        "127.0.0.1",
        "test-agent",
      );

      const statusIndex = Math.floor(Math.random() * validStatuses.length);
      const targetStatus = validStatuses[statusIndex];
      const updateCount = Math.floor(Math.random() * 5) + 1;

      // Try to update to target status multiple times
      let lastTunnel = tunnel;
      for (let i = 0; i < updateCount; i++) {
        try {
          lastTunnel = await tunnelService.updateTunnelStatus(
            tunnel.id,
            testUserId,
            targetStatus,
            "127.0.0.1",
            "test-agent",
          );
        } catch (error) {
          // Invalid transition, skip
          break;
        }
      }

      // Verify final status
      const retrieved = await tunnelService.getTunnelById(
        tunnel.id,
        testUserId,
      );
      expect(retrieved.status).toBe(lastTunnel.status);
    }
  });
});
