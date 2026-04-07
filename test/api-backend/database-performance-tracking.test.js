/**
 * Database Performance Tracking Unit Tests
 *
 * Tests for query performance tracking, slow query detection,
 * and performance metrics collection
 *
 * Requirements: 9.7 (Database Performance Metrics)
 */

import {
  initializeQueryTracking,
  trackQuery,
  getPerformanceMetrics,
  getSlowQueries,
  getQueryStatsByType,
  resetPerformanceMetrics,
  setSlowQueryThreshold,
  analyzePerformance,
} from "../../services/api-backend/database/query-performance-tracker.js";

describe("Database Performance Tracking", () => {
  beforeEach(() => {
    resetPerformanceMetrics();
  });

  describe("initializeQueryTracking", () => {
    it("should initialize query tracking with default threshold", () => {
      const result = initializeQueryTracking();

      expect(result).toHaveProperty("slowQueryThreshold");
      expect(result).toHaveProperty("status", "initialized");
      expect(result.slowQueryThreshold).toBeGreaterThan(0);
    });

    it("should use environment variable for threshold if set", () => {
      const originalEnv = process.env.DB_SLOW_QUERY_THRESHOLD;
      process.env.DB_SLOW_QUERY_THRESHOLD = "200";

      const result = initializeQueryTracking();

      expect(result.slowQueryThreshold).toBe(200);

      // Restore original
      if (originalEnv) {
        process.env.DB_SLOW_QUERY_THRESHOLD = originalEnv;
      } else {
        delete process.env.DB_SLOW_QUERY_THRESHOLD;
      }
    });
  });

  describe("trackQuery", () => {
    beforeEach(() => {
      initializeQueryTracking();
    });

    it("should track a successful query", () => {
      const queryText = "SELECT * FROM users WHERE id = $1";
      const duration = 50;

      const record = trackQuery(queryText, duration, {
        params: [1],
        success: true,
        queryType: "SELECT",
      });

      expect(record).toHaveProperty("timestamp");
      expect(record).toHaveProperty("queryText");
      expect(record).toHaveProperty("duration", duration);
      expect(record).toHaveProperty("success", true);
      expect(record).toHaveProperty("queryType", "SELECT");
    });

    it("should track a failed query", () => {
      const queryText = "SELECT * FROM invalid_table";
      const duration = 10;
      const error = new Error("Table not found");

      const record = trackQuery(queryText, duration, {
        success: false,
        error,
        queryType: "SELECT",
      });

      expect(record).toHaveProperty("success", false);
      expect(record).toHaveProperty("error", "Table not found");
    });

    it("should detect slow queries", () => {
      initializeQueryTracking();
      setSlowQueryThreshold(100);

      // Track a fast query
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });

      // Track a slow query
      trackQuery("SELECT * FROM large_table", 150, { queryType: "SELECT" });

      const metrics = getPerformanceMetrics();

      expect(metrics.totalQueries).toBe(2);
      expect(metrics.totalSlowQueries).toBe(1);
    });

    it("should truncate long query text", () => {
      const longQuery = "SELECT " + "column, ".repeat(100) + "FROM table";
      const record = trackQuery(longQuery, 50, { queryType: "SELECT" });

      expect(record.queryText.length).toBeLessThanOrEqual(205);
      expect(record.queryText).toContain("...");
    });

    it("should maintain query history limit", () => {
      // Track more than 1000 queries
      for (let i = 0; i < 1100; i++) {
        trackQuery(`SELECT ${i}`, 10, { queryType: "SELECT" });
      }

      const metrics = getPerformanceMetrics();

      // Should only keep last 1000
      expect(metrics.recentQueries.length).toBeLessThanOrEqual(10);
      expect(metrics.totalQueries).toBe(1100);
    });
  });

  describe("getPerformanceMetrics", () => {
    beforeEach(() => {
      initializeQueryTracking();
    });

    it("should return current performance metrics", () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("INSERT INTO users VALUES ($1)", 75, { queryType: "INSERT" });

      const metrics = getPerformanceMetrics();

      expect(metrics).toHaveProperty("totalQueries", 2);
      expect(metrics).toHaveProperty("totalSlowQueries");
      expect(metrics).toHaveProperty("slowQueryPercentage");
      expect(metrics).toHaveProperty("averageQueryTime");
      expect(metrics).toHaveProperty("slowQueryThreshold");
      expect(metrics).toHaveProperty("queryStats");
      expect(metrics).toHaveProperty("recentQueries");
      expect(metrics).toHaveProperty("recentSlowQueries");
    });

    it("should calculate average query time correctly", () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });
      trackQuery("SELECT 3", 150, { queryType: "SELECT" });

      const metrics = getPerformanceMetrics();

      expect(parseFloat(metrics.averageQueryTime)).toBe(100);
    });

    it("should calculate slow query percentage", () => {
      setSlowQueryThreshold(100);

      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 150, { queryType: "SELECT" });
      trackQuery("SELECT 3", 150, { queryType: "SELECT" });

      const metrics = getPerformanceMetrics();

      expect(parseFloat(metrics.slowQueryPercentage)).toBeCloseTo(66.67, 1);
    });
  });

  describe("getSlowQueries", () => {
    beforeEach(() => {
      initializeQueryTracking();
      setSlowQueryThreshold(100);
    });

    it("should return list of slow queries", () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT * FROM large_table", 150, { queryType: "SELECT" });
      trackQuery("SELECT * FROM another_large_table", 200, {
        queryType: "SELECT",
      });

      const slowQueries = getSlowQueries();

      expect(slowQueries.length).toBe(2);
      expect(slowQueries[0].duration).toBeGreaterThan(100);
    });

    it("should respect limit parameter", () => {
      for (let i = 0; i < 100; i++) {
        trackQuery(`SELECT ${i}`, 150, { queryType: "SELECT" });
      }

      const slowQueries = getSlowQueries(10);

      expect(slowQueries.length).toBeLessThanOrEqual(10);
    });
  });

  describe("getQueryStatsByType", () => {
    beforeEach(() => {
      initializeQueryTracking();
    });

    it("should aggregate statistics by query type", () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });
      trackQuery("INSERT INTO users VALUES ($1)", 75, { queryType: "INSERT" });
      trackQuery("UPDATE users SET name = $1", 80, { queryType: "UPDATE" });

      const stats = getQueryStatsByType();

      expect(stats).toHaveProperty("SELECT");
      expect(stats).toHaveProperty("INSERT");
      expect(stats).toHaveProperty("UPDATE");

      expect(stats.SELECT.count).toBe(2);
      expect(stats.SELECT.averageTime).toBe(75);
      expect(stats.INSERT.count).toBe(1);
    });

    it("should track min and max times per query type", () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });
      trackQuery("SELECT 3", 75, { queryType: "SELECT" });

      const stats = getQueryStatsByType();

      expect(stats.SELECT.minTime).toBe(50);
      expect(stats.SELECT.maxTime).toBe(100);
    });

    it("should count slow queries per type", () => {
      setSlowQueryThreshold(100);

      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 150, { queryType: "SELECT" });
      trackQuery("INSERT INTO users VALUES ($1)", 75, { queryType: "INSERT" });
      trackQuery("INSERT INTO users VALUES ($1)", 150, { queryType: "INSERT" });

      const stats = getQueryStatsByType();

      expect(stats.SELECT.slowCount).toBe(1);
      expect(stats.INSERT.slowCount).toBe(1);
    });
  });

  describe("setSlowQueryThreshold", () => {
    beforeEach(() => {
      initializeQueryTracking();
    });

    it("should update slow query threshold", () => {
      const result = setSlowQueryThreshold(200);

      expect(result).toHaveProperty("slowQueryThreshold", 200);
      expect(result).toHaveProperty("status", "updated");
    });

    it("should reject negative threshold", () => {
      expect(() => {
        setSlowQueryThreshold(-100);
      }).toThrow();
    });

    it("should apply new threshold to subsequent queries", () => {
      setSlowQueryThreshold(100);
      trackQuery("SELECT 1", 150, { queryType: "SELECT" });

      let metrics = getPerformanceMetrics();
      expect(metrics.totalSlowQueries).toBe(1);

      // Change threshold
      setSlowQueryThreshold(200);
      trackQuery("SELECT 2", 150, { queryType: "SELECT" });

      metrics = getPerformanceMetrics();
      // Second query should not be slow with new threshold
      expect(metrics.totalSlowQueries).toBe(1);
    });
  });

  describe("resetPerformanceMetrics", () => {
    beforeEach(() => {
      initializeQueryTracking();
    });

    it("should reset all metrics", () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });

      let metrics = getPerformanceMetrics();
      expect(metrics.totalQueries).toBe(2);

      resetPerformanceMetrics();

      metrics = getPerformanceMetrics();
      expect(metrics.totalQueries).toBe(0);
      expect(metrics.totalSlowQueries).toBe(0);
      expect(parseFloat(metrics.averageQueryTime)).toBe(0);
    });
  });

  describe("analyzePerformance", () => {
    beforeEach(() => {
      initializeQueryTracking();
      setSlowQueryThreshold(100);
    });

    it("should generate performance analysis", () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 150, { queryType: "SELECT" });
      trackQuery("INSERT INTO users VALUES ($1)", 75, { queryType: "INSERT" });

      const analysis = analyzePerformance();

      expect(analysis).toHaveProperty("timestamp");
      expect(analysis).toHaveProperty("summary");
      expect(analysis).toHaveProperty("byQueryType");
      expect(analysis).toHaveProperty("recommendations");
    });

    it("should include summary statistics", () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 150, { queryType: "SELECT" });

      const analysis = analyzePerformance();

      expect(analysis.summary).toHaveProperty("totalQueries", 2);
      expect(analysis.summary).toHaveProperty("totalSlowQueries", 1);
      expect(analysis.summary).toHaveProperty("averageQueryTime");
      expect(analysis.summary).toHaveProperty("slowQueryPercentage");
    });

    it("should provide recommendations for high slow query rates", () => {
      // Create scenario with high slow query rate
      for (let i = 0; i < 10; i++) {
        trackQuery(`SELECT ${i}`, 150, { queryType: "SELECT" });
      }

      const analysis = analyzePerformance();

      expect(analysis.recommendations.length).toBeGreaterThan(0);
      expect(analysis.recommendations[0]).toContain("SELECT");
    });

    it("should analyze by query type", () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });
      trackQuery("INSERT INTO users VALUES ($1)", 75, { queryType: "INSERT" });

      const analysis = analyzePerformance();

      expect(analysis.byQueryType).toHaveProperty("SELECT");
      expect(analysis.byQueryType).toHaveProperty("INSERT");

      expect(analysis.byQueryType.SELECT).toHaveProperty("count", 2);
      expect(analysis.byQueryType.INSERT).toHaveProperty("count", 1);
    });
  });

  describe("Query type detection", () => {
    beforeEach(() => {
      initializeQueryTracking();
    });

    it("should correctly identify SELECT queries", () => {
      trackQuery("SELECT * FROM users", 50, { queryType: "SELECT" });
      const stats = getQueryStatsByType();
      expect(stats).toHaveProperty("SELECT");
    });

    it("should correctly identify INSERT queries", () => {
      trackQuery("INSERT INTO users VALUES ($1)", 50, { queryType: "INSERT" });
      const stats = getQueryStatsByType();
      expect(stats).toHaveProperty("INSERT");
    });

    it("should correctly identify UPDATE queries", () => {
      trackQuery("UPDATE users SET name = $1", 50, { queryType: "UPDATE" });
      const stats = getQueryStatsByType();
      expect(stats).toHaveProperty("UPDATE");
    });

    it("should correctly identify DELETE queries", () => {
      trackQuery("DELETE FROM users WHERE id = $1", 50, {
        queryType: "DELETE",
      });
      const stats = getQueryStatsByType();
      expect(stats).toHaveProperty("DELETE");
    });
  });

  describe("Performance metrics accuracy", () => {
    beforeEach(() => {
      initializeQueryTracking();
    });

    it("should accurately track query duration", () => {
      const durations = [10, 25, 50, 75, 100];

      durations.forEach((duration) => {
        trackQuery(`SELECT ${duration}`, duration, { queryType: "SELECT" });
      });

      const metrics = getPerformanceMetrics();
      const expectedAverage =
        durations.reduce((a, b) => a + b) / durations.length;

      expect(parseFloat(metrics.averageQueryTime)).toBe(expectedAverage);
    });

    it("should handle zero duration queries", () => {
      trackQuery("SELECT 1", 0, { queryType: "SELECT" });
      const metrics = getPerformanceMetrics();

      expect(metrics.totalQueries).toBe(1);
      expect(parseFloat(metrics.averageQueryTime)).toBe(0);
    });

    it("should handle very large duration values", () => {
      trackQuery("SELECT * FROM huge_table", 10000, { queryType: "SELECT" });
      const metrics = getPerformanceMetrics();

      expect(metrics.totalQueries).toBe(1);
      expect(parseFloat(metrics.averageQueryTime)).toBe(10000);
    });
  });
});
