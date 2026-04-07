/**


 * Read Replica Routing Unit Tests
 *
 * Tests for read replica routing functionality including:
 * - Read/write query routing
 * - Replica health checking
 * - Automatic failover to primary
 * - Load balancing across replicas
 * - Replica status tracking
 *
 * Requirements: 9.5 (Read replica support for scaling read operations)
 */

import {
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
  jest,
} from "@jest/globals";
import { ReadReplicaManager } from "../../services/api-backend/database/read-replica-manager.js";

describe("Read Replica Routing", () => {
  let replicaManager;

  beforeEach(() => {
    replicaManager = new ReadReplicaManager();
  });

  afterEach(async () => {
    if (replicaManager) {
      replicaManager.stopHealthChecks();
    }
  });

  describe("Query Type Detection", () => {
    it("should identify SELECT queries as read operations", () => {
      const queries = [
        "SELECT * FROM users",
        "select id, name from users",
        "SELECT COUNT(*) FROM tunnels",
        "  SELECT * FROM sessions  ",
      ];

      queries.forEach((query) => {
        expect(replicaManager.isReadQuery(query)).toBe(true);
      });
    });

    it("should identify WITH queries as read operations", () => {
      const queries = [
        "WITH cte AS (SELECT * FROM users) SELECT * FROM cte",
        "with temp as (select id from tunnels) select * from temp",
      ];

      queries.forEach((query) => {
        expect(replicaManager.isReadQuery(query)).toBe(true);
      });
    });

    it("should identify EXPLAIN queries as read operations", () => {
      const queries = [
        "EXPLAIN SELECT * FROM users",
        "explain analyze select * from tunnels",
      ];

      queries.forEach((query) => {
        expect(replicaManager.isReadQuery(query)).toBe(true);
      });
    });

    it("should identify INSERT queries as write operations", () => {
      const queries = [
        "INSERT INTO users (name) VALUES ($1)",
        "insert into tunnels (user_id) values ($1)",
      ];

      queries.forEach((query) => {
        expect(replicaManager.isReadQuery(query)).toBe(false);
      });
    });

    it("should identify UPDATE queries as write operations", () => {
      const queries = [
        "UPDATE users SET name = $1 WHERE id = $2",
        "update tunnels set status = $1 where id = $2",
      ];

      queries.forEach((query) => {
        expect(replicaManager.isReadQuery(query)).toBe(false);
      });
    });

    it("should identify DELETE queries as write operations", () => {
      const queries = [
        "DELETE FROM users WHERE id = $1",
        "delete from tunnels where id = $1",
      ];

      queries.forEach((query) => {
        expect(replicaManager.isReadQuery(query)).toBe(false);
      });
    });

    it("should handle null and empty queries", () => {
      expect(replicaManager.isReadQuery(null)).toBe(false);
      expect(replicaManager.isReadQuery("")).toBe(false);
      expect(replicaManager.isReadQuery("   ")).toBe(false);
    });

    it("should handle non-string queries", () => {
      expect(replicaManager.isReadQuery(123)).toBe(false);
      expect(replicaManager.isReadQuery({})).toBe(false);
      expect(replicaManager.isReadQuery([])).toBe(false);
    });
  });

  describe("Pool Routing", () => {
    it("should route write queries to primary pool", () => {
      const primaryPool = { query: jest.fn() };
      replicaManager.primaryPool = primaryPool;

      const pool = replicaManager.getPoolForQuery(
        "INSERT INTO users (name) VALUES ($1)",
      );

      expect(pool).toBe(primaryPool);
      expect(replicaManager.metrics.writeQueries).toBe(1);
    });

    it("should route read queries to replica pool when available", () => {
      const primaryPool = { query: jest.fn() };
      const replicaPool = { query: jest.fn() };

      replicaManager.primaryPool = primaryPool;
      replicaManager.replicaPools = [replicaPool];
      replicaManager.replicaHealthStatus.set(0, { healthy: true });

      const pool = replicaManager.getPoolForQuery("SELECT * FROM users");

      expect(pool).toBe(replicaPool);
      expect(replicaManager.metrics.readQueries).toBe(1);
    });

    it("should route read queries to primary when no replicas available", () => {
      const primaryPool = { query: jest.fn() };
      replicaManager.primaryPool = primaryPool;
      replicaManager.replicaPools = [];

      const pool = replicaManager.getPoolForQuery("SELECT * FROM users");

      expect(pool).toBe(primaryPool);
      expect(replicaManager.metrics.readQueries).toBe(1);
    });

    it("should route read queries to primary when all replicas unhealthy", () => {
      const primaryPool = { query: jest.fn() };
      const replicaPool = { query: jest.fn() };

      replicaManager.primaryPool = primaryPool;
      replicaManager.replicaPools = [replicaPool];
      replicaManager.replicaHealthStatus.set(0, { healthy: false });

      const pool = replicaManager.getPoolForQuery("SELECT * FROM users");

      expect(pool).toBe(primaryPool);
      expect(replicaManager.metrics.replicaFailovers).toBe(1);
    });
  });

  describe("Load Balancing", () => {
    it("should round-robin across multiple healthy replicas", () => {
      const primaryPool = { query: jest.fn() };
      const replica1 = { query: jest.fn() };
      const replica2 = { query: jest.fn() };

      replicaManager.primaryPool = primaryPool;
      replicaManager.replicaPools = [replica1, replica2];
      replicaManager.replicaHealthStatus.set(0, { healthy: true });
      replicaManager.replicaHealthStatus.set(1, { healthy: true });

      // First read query should go to replica 1
      let pool = replicaManager.getPoolForQuery("SELECT * FROM users");
      expect(pool).toBe(replica1);

      // Second read query should go to replica 2
      pool = replicaManager.getPoolForQuery("SELECT * FROM users");
      expect(pool).toBe(replica2);

      // Third read query should go back to replica 1
      pool = replicaManager.getPoolForQuery("SELECT * FROM users");
      expect(pool).toBe(replica1);
    });

    it("should skip unhealthy replicas during load balancing", () => {
      const primaryPool = { query: jest.fn() };
      const replica1 = { query: jest.fn() };
      const replica2 = { query: jest.fn() };

      replicaManager.primaryPool = primaryPool;
      replicaManager.replicaPools = [replica1, replica2];
      replicaManager.replicaHealthStatus.set(0, { healthy: false });
      replicaManager.replicaHealthStatus.set(1, { healthy: true });

      // Should only use replica 2
      let pool = replicaManager.getPoolForQuery("SELECT * FROM users");
      expect(pool).toBe(replica2);

      pool = replicaManager.getPoolForQuery("SELECT * FROM users");
      expect(pool).toBe(replica2);
    });
  });

  describe("Replica Health Status", () => {
    it("should track replica health status", () => {
      replicaManager.replicaConfigs = [
        { host: "replica1.example.com", port: 5432, database: "test" },
        { host: "replica2.example.com", port: 5432, database: "test" },
      ];

      replicaManager.replicaHealthStatus.set(0, {
        healthy: true,
        lastHealthCheck: "2024-01-01T00:00:00Z",
        failureCount: 0,
        responseTime: 50,
      });

      replicaManager.replicaHealthStatus.set(1, {
        healthy: false,
        lastHealthCheck: "2024-01-01T00:00:00Z",
        failureCount: 3,
        responseTime: 0,
      });

      const status = replicaManager.getReplicaStatus();

      expect(status.replica_0.healthy).toBe(true);
      expect(status.replica_0.responseTime).toBe(50);
      expect(status.replica_1.healthy).toBe(false);
      expect(status.replica_1.failureCount).toBe(3);
    });

    it("should include replica configuration in status", () => {
      replicaManager.replicaConfigs = [
        { host: "replica1.example.com", port: 5432, database: "test" },
      ];

      replicaManager.replicaHealthStatus.set(0, {
        healthy: true,
        lastHealthCheck: "2024-01-01T00:00:00Z",
        failureCount: 0,
        responseTime: 50,
      });

      const status = replicaManager.getReplicaStatus();

      expect(status.replica_0.host).toBe("replica1.example.com");
      expect(status.replica_0.port).toBe(5432);
      expect(status.replica_0.database).toBe("test");
    });
  });

  describe("Metrics Collection", () => {
    it("should track read and write query counts", () => {
      replicaManager.primaryPool = { query: jest.fn() };
      replicaManager.replicaPools = [{ query: jest.fn() }];
      replicaManager.replicaHealthStatus.set(0, { healthy: true });

      // Execute read queries
      replicaManager.getPoolForQuery("SELECT * FROM users");
      replicaManager.getPoolForQuery("SELECT * FROM tunnels");

      // Execute write queries
      replicaManager.getPoolForQuery("INSERT INTO users (name) VALUES ($1)");
      replicaManager.getPoolForQuery("UPDATE tunnels SET status = $1");

      const metrics = replicaManager.getMetrics();

      expect(metrics.readQueries).toBe(2);
      expect(metrics.writeQueries).toBe(2);
    });

    it("should track replica failovers", () => {
      replicaManager.primaryPool = { query: jest.fn() };
      replicaManager.replicaPools = [{ query: jest.fn() }];
      replicaManager.replicaHealthStatus.set(0, { healthy: false });

      // Try to route read query when replica is unhealthy
      replicaManager.getPoolForQuery("SELECT * FROM users");

      const metrics = replicaManager.getMetrics();

      expect(metrics.replicaFailovers).toBe(1);
    });

    it("should include replica count in metrics", () => {
      replicaManager.replicaPools = [
        { query: jest.fn() },
        { query: jest.fn() },
        { query: jest.fn() },
      ];

      const metrics = replicaManager.getMetrics();

      expect(metrics.replicaCount).toBe(3);
    });
  });

  describe("Healthy Replica Selection", () => {
    it("should return primary when no replicas configured", () => {
      const primaryPool = { query: jest.fn() };
      replicaManager.primaryPool = primaryPool;
      replicaManager.replicaPools = [];

      const pool = replicaManager.getHealthyReplicaPool();

      expect(pool).toBe(primaryPool);
    });

    it("should return healthy replica when available", () => {
      const primaryPool = { query: jest.fn() };
      const replicaPool = { query: jest.fn() };

      replicaManager.primaryPool = primaryPool;
      replicaManager.replicaPools = [replicaPool];
      replicaManager.replicaHealthStatus.set(0, { healthy: true });

      const pool = replicaManager.getHealthyReplicaPool();

      expect(pool).toBe(replicaPool);
    });

    it("should return primary when all replicas unhealthy", () => {
      const primaryPool = { query: jest.fn() };
      const replicaPool = { query: jest.fn() };

      replicaManager.primaryPool = primaryPool;
      replicaManager.replicaPools = [replicaPool];
      replicaManager.replicaHealthStatus.set(0, { healthy: false });

      const pool = replicaManager.getHealthyReplicaPool();

      expect(pool).toBe(primaryPool);
    });
  });

  describe("Query Type Parameter", () => {
    it("should route based on explicit query type parameter", async () => {
      const primaryPool = {
        connect: jest.fn().mockResolvedValue({ release: jest.fn() }),
      };
      const replicaPool = {
        connect: jest.fn().mockResolvedValue({ release: jest.fn() }),
      };

      replicaManager.primaryPool = primaryPool;
      replicaManager.replicaPools = [replicaPool];
      replicaManager.replicaHealthStatus.set(0, { healthy: true });

      // Request write client
      await replicaManager.getClient("write");
      expect(primaryPool.connect).toHaveBeenCalled();

      // Request read client
      await replicaManager.getClient("read");
      expect(replicaPool.connect).toHaveBeenCalled();
    });
  });
});
