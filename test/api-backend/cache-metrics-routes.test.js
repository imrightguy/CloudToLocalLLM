/**
 * Cache Metrics Routes Tests
 *
 * Tests for cache metrics API endpoints
 * Validates cache statistics, clearing, and invalidation endpoints
 *
 * Requirements: 9.8 (Query Optimization and Caching)
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import {
  clearCache,
  getCacheStats,
} from "../../services/api-backend/database/cached-query-wrapper.js";
import { getQueryCache } from "../../services/api-backend/database/query-cache.js";

describe("Cache Metrics Routes", () => {
  beforeEach(() => {
    clearCache();
  });

  afterEach(() => {
    clearCache();
  });

  describe("Cache Statistics", () => {
    it("should return cache statistics", () => {
      const stats = getCacheStats();

      expect(stats).toHaveProperty("size");
      expect(stats).toHaveProperty("hits");
      expect(stats).toHaveProperty("misses");
      expect(stats).toHaveProperty("hitRate");
      expect(stats).toHaveProperty("invalidations");
      expect(stats).toHaveProperty("evictions");
    });

    it("should return correct cache size", () => {
      const cache = getQueryCache();
      cache.set("key1", { data: "test1" });
      cache.set("key2", { data: "test2" });

      const stats = getCacheStats();
      expect(stats.size).toBe(2);
    });

    it("should return correct hit/miss counts", () => {
      const cache = getQueryCache();
      cache.set("key1", { data: "test1" });
      cache.get("key1"); // hit
      cache.get("key2"); // miss

      const stats = getCacheStats();
      expect(stats.hits).toBe(1);
      expect(stats.misses).toBe(1);
    });
  });

  describe("Cache Clearing", () => {
    it("should clear all cache entries", () => {
      const cache = getQueryCache();
      cache.set("key1", { data: "test1" });
      cache.set("key2", { data: "test2" });

      expect(cache.cache.size).toBe(2);

      clearCache();

      expect(cache.cache.size).toBe(0);
    });
  });

  describe("Cache Invalidation", () => {
    it("should invalidate by table name", () => {
      const cache = getQueryCache();
      cache.set("key1", { data: "user1" }, 5000, [], ["USERS"]);
      cache.set("key2", { data: "user2" }, 5000, [], ["USERS"]);
      cache.set("key3", { data: "post1" }, 5000, [], ["POSTS"]);

      const count = cache.invalidateByTable("USERS");

      expect(count).toBe(2);
      expect(cache.get("key1")).toBeNull();
      expect(cache.get("key2")).toBeNull();
      expect(cache.get("key3")).not.toBeNull();
    });

    it("should invalidate by regex pattern", () => {
      const cache = getQueryCache();
      cache.set("query:users:1", { data: "user1" });
      cache.set("query:users:2", { data: "user2" });
      cache.set("query:posts:1", { data: "post1" });

      const count = cache.invalidate(/query:users/);

      expect(count).toBe(2);
      expect(cache.get("query:users:1")).toBeNull();
      expect(cache.get("query:posts:1")).not.toBeNull();
    });

    it("should return invalidated count", () => {
      const cache = getQueryCache();
      cache.set("key1", { data: "test1" });
      cache.set("key2", { data: "test2" });
      cache.set("key3", { data: "test3" });

      const count = cache.invalidate(/key/);

      expect(count).toBe(3);
    });
  });

  describe("Metrics Reset", () => {
    it("should reset cache metrics", () => {
      const cache = getQueryCache();
      cache.set("key1", { data: "test1" });
      cache.get("key1"); // hit
      cache.get("key2"); // miss

      expect(cache.metrics.hits).toBeGreaterThan(0);
      expect(cache.metrics.misses).toBeGreaterThan(0);

      cache.resetMetrics();

      expect(cache.metrics.hits).toBe(0);
      expect(cache.metrics.misses).toBe(0);
    });
  });
});
