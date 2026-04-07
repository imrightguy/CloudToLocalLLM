/**


 * Cached Query Wrapper Tests
 *
 * Tests for cached query wrapper functionality
 * Validates query caching, invalidation, and integration
 *
 * Requirements: 9.8 (Query Optimization and Caching)
 */

import {
  jest,
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
} from "@jest/globals";
import {
  executeCachedQuery,
  wrapPoolWithCache,
  wrapClientWithCache,
  invalidateCacheForTable,
  getCacheStats,
  clearCache,
} from "../../services/api-backend/database/cached-query-wrapper.js";
import { getQueryCache } from "../../services/api-backend/database/query-cache.js";

describe("Cached Query Wrapper", () => {
  beforeEach(() => {
    clearCache();
  });

  afterEach(() => {
    clearCache();
  });

  describe("executeCachedQuery", () => {
    it("should execute query and cache SELECT results", async () => {
      const mockResult = { rows: [{ id: 1, name: "John" }] };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      const result = await executeCachedQuery(
        queryFn,
        "SELECT * FROM users WHERE id = ?",
        [1],
      );

      expect(result).toEqual(mockResult);
      expect(queryFn).toHaveBeenCalledTimes(1);
    });

    it("should return cached result on second call", async () => {
      const mockResult = { rows: [{ id: 1, name: "John" }] };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      // First call
      await executeCachedQuery(
        queryFn,
        "SELECT * FROM users WHERE id = ?",
        [1],
      );

      // Second call
      const result = await executeCachedQuery(
        queryFn,
        "SELECT * FROM users WHERE id = ?",
        [1],
      );

      expect(result).toEqual(mockResult);
      expect(queryFn).toHaveBeenCalledTimes(1); // Should only be called once
    });

    it("should not cache INSERT queries", async () => {
      const mockResult = { rowCount: 1 };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      await executeCachedQuery(queryFn, "INSERT INTO users (name) VALUES (?)", [
        "John",
      ]);

      await executeCachedQuery(queryFn, "INSERT INTO users (name) VALUES (?)", [
        "John",
      ]);

      expect(queryFn).toHaveBeenCalledTimes(2); // Should be called twice
    });

    it("should not cache UPDATE queries", async () => {
      const mockResult = { rowCount: 1 };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      await executeCachedQuery(
        queryFn,
        "UPDATE users SET name = ? WHERE id = ?",
        ["Jane", 1],
      );

      await executeCachedQuery(
        queryFn,
        "UPDATE users SET name = ? WHERE id = ?",
        ["Jane", 1],
      );

      expect(queryFn).toHaveBeenCalledTimes(2); // Should be called twice
    });

    it("should not cache DELETE queries", async () => {
      const mockResult = { rowCount: 1 };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      await executeCachedQuery(queryFn, "DELETE FROM users WHERE id = ?", [1]);

      await executeCachedQuery(queryFn, "DELETE FROM users WHERE id = ?", [1]);

      expect(queryFn).toHaveBeenCalledTimes(2); // Should be called twice
    });

    it("should handle query errors", async () => {
      const error = new Error("Query failed");
      const queryFn = jest.fn().mockRejectedValue(error);

      await expect(
        executeCachedQuery(queryFn, "SELECT * FROM users", []),
      ).rejects.toThrow("Query failed");
    });

    it("should respect custom TTL", async () => {
      const mockResult = { rows: [{ id: 1 }] };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      await executeCachedQuery(queryFn, "SELECT * FROM users", [], {
        ttl: 500,
      });

      // Wait for TTL to expire
      await new Promise((resolve) => setTimeout(resolve, 600));

      // Second call should execute query again
      await executeCachedQuery(queryFn, "SELECT * FROM users", [], {
        ttl: 500,
      });

      expect(queryFn).toHaveBeenCalledTimes(2);
    });
  });

  describe("wrapPoolWithCache", () => {
    it("should wrap pool query method", () => {
      const originalQuery = jest.fn().mockResolvedValue({ rows: [{ id: 1 }] });
      const mockPool = {
        query: originalQuery,
      };

      const wrappedPool = wrapPoolWithCache(mockPool);

      expect(wrappedPool.query).toBeDefined();
      expect(typeof wrappedPool.query).toBe("function");
    });

    it("should cache queries on wrapped pool", async () => {
      const originalQuery = jest.fn().mockResolvedValue({ rows: [{ id: 1 }] });
      const mockPool = {
        query: originalQuery,
      };

      const wrappedPool = wrapPoolWithCache(mockPool);

      // First call
      await wrappedPool.query("SELECT * FROM users", []);

      // Second call
      await wrappedPool.query("SELECT * FROM users", []);

      expect(originalQuery).toHaveBeenCalledTimes(1); // Should only be called once
    });
  });

  describe("wrapClientWithCache", () => {
    it("should wrap client query method", () => {
      const originalQuery = jest.fn().mockResolvedValue({ rows: [{ id: 1 }] });
      const mockClient = {
        query: originalQuery,
      };

      const wrappedClient = wrapClientWithCache(mockClient);

      expect(wrappedClient.query).toBeDefined();
      expect(typeof wrappedClient.query).toBe("function");
    });

    it("should cache queries on wrapped client", async () => {
      const originalQuery = jest.fn().mockResolvedValue({ rows: [{ id: 1 }] });
      const mockClient = {
        query: originalQuery,
      };

      const wrappedClient = wrapClientWithCache(mockClient);

      // First call
      await wrappedClient.query("SELECT * FROM users", []);

      // Second call
      await wrappedClient.query("SELECT * FROM users", []);

      expect(originalQuery).toHaveBeenCalledTimes(1); // Should only be called once
    });
  });

  describe("invalidateCacheForTable", () => {
    it("should invalidate cache for specific table", async () => {
      const mockResult = { rows: [{ id: 1 }] };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      // Cache a query
      await executeCachedQuery(
        queryFn,
        "SELECT * FROM users WHERE id = ?",
        [1],
      );

      // Invalidate cache for users table
      invalidateCacheForTable("users");

      // Second call should execute query again
      await executeCachedQuery(
        queryFn,
        "SELECT * FROM users WHERE id = ?",
        [1],
      );

      expect(queryFn).toHaveBeenCalledTimes(2);
    });
  });

  describe("getCacheStats", () => {
    it("should return cache statistics", async () => {
      const mockResult = { rows: [{ id: 1 }] };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      // Execute some queries
      await executeCachedQuery(queryFn, "SELECT * FROM users", []);
      await executeCachedQuery(queryFn, "SELECT * FROM users", []);
      await executeCachedQuery(queryFn, "SELECT * FROM posts", []);

      const stats = getCacheStats();

      expect(stats).toHaveProperty("size");
      expect(stats).toHaveProperty("hits");
      expect(stats).toHaveProperty("misses");
      expect(stats).toHaveProperty("hitRate");
    });
  });

  describe("clearCache", () => {
    it("should clear all cache entries", async () => {
      const mockResult = { rows: [{ id: 1 }] };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      // Cache some queries
      await executeCachedQuery(queryFn, "SELECT * FROM users", []);
      await executeCachedQuery(queryFn, "SELECT * FROM posts", []);

      let stats = getCacheStats();
      expect(stats.size).toBeGreaterThan(0);

      clearCache();

      stats = getCacheStats();
      expect(stats.size).toBe(0);
    });
  });

  describe("table name extraction", () => {
    it("should extract table names from SELECT queries", async () => {
      const mockResult = { rows: [] };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      await executeCachedQuery(
        queryFn,
        "SELECT * FROM users WHERE id = ?",
        [1],
      );

      const cache = getQueryCache();
      const stats = cache.getStats();
      expect(stats.size).toBe(1);
    });

    it("should extract table names from JOIN queries", async () => {
      const mockResult = { rows: [] };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      await executeCachedQuery(
        queryFn,
        "SELECT u.* FROM users u JOIN posts p ON u.id = p.user_id",
        [],
      );

      const cache = getQueryCache();
      const stats = cache.getStats();
      expect(stats.size).toBe(1);
    });
  });

  describe("cache hit rate", () => {
    it("should track cache hit rate correctly", async () => {
      // Clear cache and reset metrics before this test
      clearCache();
      const cache = getQueryCache();
      cache.resetMetrics();

      const mockResult = { rows: [{ id: 1 }] };
      const queryFn = jest.fn().mockResolvedValue(mockResult);

      // Execute same query 3 times
      await executeCachedQuery(queryFn, "SELECT * FROM users", []);
      await executeCachedQuery(queryFn, "SELECT * FROM users", []);
      await executeCachedQuery(queryFn, "SELECT * FROM users", []);

      const stats = getCacheStats();
      // First call is a miss, second and third are hits = 2 hits, 1 miss = 66.67%
      expect(parseFloat(stats.hitRate)).toBeCloseTo(66.67, 1);
    });
  });
});
