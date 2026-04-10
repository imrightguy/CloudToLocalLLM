import {} from "@jest/globals";

/**


 * Query Cache Tests
 *
 * Tests for query caching mechanism
 * Validates cache hit/miss, TTL, invalidation, and metrics
 *
 * Requirements: 9.8 (Query Optimization and Caching)
 */

import {
  QueryCacheService,
  getQueryCache,
} from "../../services/api-backend/database/query-cache.js";

describe("QueryCacheService", () => {
  let cache;

  beforeEach(() => {
    cache = new QueryCacheService({
      defaultTTL: 1000,
      maxCacheSize: 10,
      enableMetrics: true,
    });
  });

  afterEach(() => {
    cache.clear();
  });

  describe("generateKey", () => {
    it("should generate consistent keys for same query and params", () => {
      const query = "SELECT * FROM users WHERE id = ?";
      const params = [1];

      const key1 = cache.generateKey(query, params);
      const key2 = cache.generateKey(query, params);

      expect(key1).toBe(key2);
    });

    it("should generate different keys for different queries", () => {
      const query1 = "SELECT * FROM users WHERE id = ?";
      const query2 = "SELECT * FROM users WHERE name = ?";
      const params = [1];

      const key1 = cache.generateKey(query1, params);
      const key2 = cache.generateKey(query2, params);

      expect(key1).not.toBe(key2);
    });

    it("should generate different keys for different params", () => {
      const query = "SELECT * FROM users WHERE id = ?";
      const key1 = cache.generateKey(query, [1]);
      const key2 = cache.generateKey(query, [2]);

      expect(key1).not.toBe(key2);
    });

    it("should normalize query case", () => {
      const query1 = "SELECT * FROM users";
      const query2 = "select * from users";

      const key1 = cache.generateKey(query1);
      const key2 = cache.generateKey(query2);

      expect(key1).toBe(key2);
    });
  });

  describe("set and get", () => {
    it("should store and retrieve values", () => {
      const key = "test-key";
      const value = { id: 1, name: "John" };

      cache.set(key, value);
      const result = cache.get(key);

      expect(result).toEqual(value);
    });

    it("should return null for non-existent keys", () => {
      const result = cache.get("non-existent");
      expect(result).toBeNull();
    });

    it("should increment hit count on cache hit", () => {
      const key = "test-key";
      cache.set(key, { data: "test" });

      cache.get(key);
      cache.get(key);

      expect(cache.metrics.hits).toBe(2);
    });

    it("should increment miss count on cache miss", () => {
      cache.get("non-existent");
      cache.get("another-non-existent");

      expect(cache.metrics.misses).toBe(2);
    });
  });

  describe("TTL expiration", () => {
    it("should expire entries after TTL", async () => {
      const key = "test-key";
      const value = { data: "test" };

      cache.set(key, value, 100); // 100ms TTL

      // Should be available immediately
      expect(cache.get(key)).toEqual(value);

      // Wait for TTL to expire
      await new Promise((resolve) => setTimeout(resolve, 150));

      // Should be expired
      expect(cache.get(key)).toBeNull();
    });

    it("should use default TTL when not specified", () => {
      const key = "test-key";
      cache.set(key, { data: "test" });

      const ttlEntry = cache.ttlMap.get(key);
      expect(ttlEntry.ttl).toBe(cache.defaultTTL);
    });
  });

  describe("invalidation", () => {
    it("should invalidate by exact key", () => {
      const key = "test-key";
      cache.set(key, { data: "test" });

      expect(cache.get(key)).not.toBeNull();

      cache.invalidate(key);

      expect(cache.get(key)).toBeNull();
    });

    it("should invalidate by regex pattern", () => {
      cache.set("query:users:1", { data: "user1" });
      cache.set("query:users:2", { data: "user2" });
      cache.set("query:posts:1", { data: "post1" });

      const pattern = /query:users/;
      const count = cache.invalidate(pattern);

      expect(count).toBe(2);
      expect(cache.get("query:users:1")).toBeNull();
      expect(cache.get("query:users:2")).toBeNull();
      expect(cache.get("query:posts:1")).not.toBeNull();
    });

    it("should invalidate by table name", () => {
      cache.set("table:users:1", { data: "user1" }, undefined, undefined, [
        "users",
      ]);
      cache.set("table:users:2", { data: "user2" }, undefined, undefined, [
        "users",
      ]);
      cache.set("table:posts:1", { data: "post1" }, undefined, undefined, [
        "posts",
      ]);

      const count = cache.invalidateByTable("users");

      expect(count).toBe(2);
      expect(cache.get("table:users:1")).toBeNull();
      expect(cache.get("table:users:2")).toBeNull();
      expect(cache.get("table:posts:1")).not.toBeNull();
    });

    it("should increment invalidation count", () => {
      cache.set("key1", { data: "test1" });
      cache.set("key2", { data: "test2" });

      cache.invalidate(/key/);

      expect(cache.metrics.invalidations).toBe(2);
    });
  });

  describe("cache eviction", () => {
    it("should evict oldest entry when cache is full", () => {
      const cacheSmall = new QueryCacheService({
        maxCacheSize: 3,
        enableMetrics: true,
      });

      cacheSmall.set("key1", { data: "test1" });
      cacheSmall.set("key2", { data: "test2" });
      cacheSmall.set("key3", { data: "test3" });

      expect(cacheSmall.cache.size).toBe(3);

      // Adding a 4th entry should evict the oldest
      cacheSmall.set("key4", { data: "test4" });

      expect(cacheSmall.cache.size).toBe(3);
      expect(cacheSmall.metrics.evictions).toBe(1);
      expect(cacheSmall.get("key1")).toBeNull(); // First entry should be evicted
    });
  });

  describe("clear", () => {
    it("should clear all cache entries", () => {
      cache.set("key1", { data: "test1" });
      cache.set("key2", { data: "test2" });

      expect(cache.cache.size).toBe(2);

      cache.clear();

      expect(cache.cache.size).toBe(0);
      expect(cache.ttlMap.size).toBe(0);
      expect(cache.dependencyMap.size).toBe(0);
    });
  });

  describe("getStats", () => {
    it("should return cache statistics", () => {
      cache.set("key1", { data: "test1" });
      cache.get("key1"); // hit
      cache.get("key2"); // miss

      const stats = cache.getStats();

      expect(stats).toHaveProperty("size");
      expect(stats).toHaveProperty("maxSize");
      expect(stats).toHaveProperty("hits");
      expect(stats).toHaveProperty("misses");
      expect(stats).toHaveProperty("hitRate");
      expect(stats).toHaveProperty("invalidations");
      expect(stats).toHaveProperty("evictions");

      expect(stats.size).toBe(1);
      expect(stats.hits).toBe(1);
      expect(stats.misses).toBe(1);
      expect(parseFloat(stats.hitRate)).toBe(50);
    });

    it("should calculate hit rate correctly", () => {
      cache.set("key1", { data: "test1" });
      cache.get("key1"); // hit
      cache.get("key1"); // hit
      cache.get("key2"); // miss

      const stats = cache.getStats();
      expect(parseFloat(stats.hitRate)).toBeCloseTo(66.67, 1);
    });

    it("should handle zero hits and misses", () => {
      const stats = cache.getStats();
      expect(parseFloat(stats.hitRate)).toBe(0);
    });
  });

  describe("resetMetrics", () => {
    it("should reset all metrics", () => {
      cache.set("key1", { data: "test1" });
      cache.get("key1");
      cache.get("key2");

      expect(cache.metrics.hits).toBeGreaterThan(0);
      expect(cache.metrics.misses).toBeGreaterThan(0);

      cache.resetMetrics();

      expect(cache.metrics.hits).toBe(0);
      expect(cache.metrics.misses).toBe(0);
      expect(cache.metrics.invalidations).toBe(0);
      expect(cache.metrics.evictions).toBe(0);
    });
  });

  describe("dependencies", () => {
    it("should store dependencies", () => {
      const key = "test-key";
      const dependencies = ["table:users", "table:posts"];

      cache.set(key, { data: "test" }, 1000, dependencies);

      expect(cache.dependencyMap.get(key)).toEqual(dependencies);
    });
  });

  describe("singleton instance", () => {
    it("should return same instance on multiple calls", () => {
      const instance1 = getQueryCache();
      const instance2 = getQueryCache();

      expect(instance1).toBe(instance2);
    });
  });

  describe("metrics disabled", () => {
    it("should not track metrics when disabled", () => {
      const cacheNoMetrics = new QueryCacheService({
        enableMetrics: false,
      });

      cacheNoMetrics.set("key1", { data: "test1" });
      cacheNoMetrics.get("key1");
      cacheNoMetrics.get("key2");

      expect(cacheNoMetrics.metrics.hits).toBe(0);
      expect(cacheNoMetrics.metrics.misses).toBe(0);
    });
  });
});
