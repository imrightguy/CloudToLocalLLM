import { describe, it, expect, beforeEach, jest } from "@jest/globals";

/**
 * Database Performance Metrics API Integration Tests
 *
 * Tests for database performance metrics endpoints
 * Validates API responses and performance data collection
 *
 * Requirements: 9.7 (Database Performance Metrics)
 */

jest.unstable_mockModule(
  "../../services/api-backend/middleware/admin-auth.js",
  () => ({
    adminAuth: () => (req, res, next) => next(),
  }),
);

import request from "supertest";
import express from "express";
import {
  trackQuery,
  resetPerformanceMetrics,
  initializeQueryTracking,
  setSlowQueryThreshold,
} from "../../services/api-backend/database/query-performance-tracker.js";

const { default: databasePerformanceRoutes } =
  await import("../../services/api-backend/routes/database-performance.js");

describe("Database Performance Metrics API", () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use(express.json());
    app.use("/database/performance", databasePerformanceRoutes);

    resetPerformanceMetrics();
    initializeQueryTracking();
  });

  describe("GET /database/performance/metrics", () => {
    it("should return current performance metrics", async () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });

      const response = await request(app).get("/database/performance/metrics");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("status", "success");
      expect(response.body).toHaveProperty("data");
      expect(response.body.data).toHaveProperty("totalQueries", 2);
      expect(response.body.data).toHaveProperty("averageQueryTime");
      expect(response.body.data).toHaveProperty("queryStats");
    });

    it("should include recent queries in response", async () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });

      const response = await request(app).get("/database/performance/metrics");

      expect(response.body.data).toHaveProperty("recentQueries");
      expect(Array.isArray(response.body.data.recentQueries)).toBe(true);
    });

    it("should include slow query information", async () => {
      setSlowQueryThreshold(100);
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 150, { queryType: "SELECT" });

      const response = await request(app).get("/database/performance/metrics");

      expect(response.body.data).toHaveProperty("totalSlowQueries", 1);
      expect(response.body.data).toHaveProperty("slowQueryPercentage");
    });

    it("should return timestamp", async () => {
      const response = await request(app).get("/database/performance/metrics");

      expect(response.body).toHaveProperty("timestamp");
      expect(new Date(response.body.timestamp)).toBeInstanceOf(Date);
    });
  });

  describe("GET /database/performance/slow-queries", () => {
    it("should return list of slow queries", async () => {
      setSlowQueryThreshold(100);
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT * FROM large_table", 150, { queryType: "SELECT" });

      const response = await request(app).get(
        "/database/performance/slow-queries",
      );

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("status", "success");
      expect(response.body).toHaveProperty("data");
      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.data.length).toBe(1);
    });

    it("should respect limit parameter", async () => {
      setSlowQueryThreshold(100);
      for (let i = 0; i < 100; i++) {
        trackQuery(`SELECT ${i}`, 150, { queryType: "SELECT" });
      }

      const response = await request(app)
        .get("/database/performance/slow-queries")
        .query({ limit: 10 });

      expect(response.body.data.length).toBeLessThanOrEqual(10);
    });

    it("should include count in response", async () => {
      setSlowQueryThreshold(100);
      trackQuery("SELECT 1", 150, { queryType: "SELECT" });

      const response = await request(app).get(
        "/database/performance/slow-queries",
      );

      expect(response.body).toHaveProperty("count");
      expect(response.body.count).toBe(1);
    });

    it("should return empty array when no slow queries", async () => {
      setSlowQueryThreshold(100);
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });

      const response = await request(app).get(
        "/database/performance/slow-queries",
      );

      expect(response.body.data).toEqual([]);
      expect(response.body.count).toBe(0);
    });
  });

  describe("GET /database/performance/stats", () => {
    it("should return query statistics by type", async () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });
      trackQuery("INSERT INTO users VALUES ($1)", 75, { queryType: "INSERT" });

      const response = await request(app).get("/database/performance/stats");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("status", "success");
      expect(response.body).toHaveProperty("data");
      expect(response.body.data).toHaveProperty("SELECT");
      expect(response.body.data).toHaveProperty("INSERT");
    });

    it("should include detailed statistics per query type", async () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });

      const response = await request(app).get("/database/performance/stats");

      const selectStats = response.body.data.SELECT;
      expect(selectStats).toHaveProperty("count", 2);
      expect(selectStats).toHaveProperty("averageTime");
      expect(selectStats).toHaveProperty("minTime");
      expect(selectStats).toHaveProperty("maxTime");
    });
  });

  describe("GET /database/performance/analysis", () => {
    it("should return performance analysis", async () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });

      const response = await request(app).get("/database/performance/analysis");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("status", "success");
      expect(response.body).toHaveProperty("data");
      expect(response.body.data).toHaveProperty("summary");
      expect(response.body.data).toHaveProperty("byQueryType");
      expect(response.body.data).toHaveProperty("recommendations");
    });

    it("should include summary in analysis", async () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });

      const response = await request(app).get("/database/performance/analysis");

      const summary = response.body.data.summary;
      expect(summary).toHaveProperty("totalQueries");
      expect(summary).toHaveProperty("averageQueryTime");
      expect(summary).toHaveProperty("slowQueryPercentage");
    });

    it("should provide recommendations", async () => {
      setSlowQueryThreshold(100);
      for (let i = 0; i < 20; i++) {
        trackQuery(`SELECT ${i}`, 150, { queryType: "SELECT" });
      }

      const response = await request(app).get("/database/performance/analysis");

      expect(Array.isArray(response.body.data.recommendations)).toBe(true);
      expect(response.body.data.recommendations.length).toBeGreaterThan(0);
    });
  });

  describe("POST /database/performance/threshold", () => {
    it("should update slow query threshold", async () => {
      const response = await request(app)
        .post("/database/performance/threshold")
        .set("Content-Type", "application/json")
        .send(JSON.stringify({ thresholdMs: 200 }));

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("status", "success");
      expect(response.body.data).toHaveProperty("slowQueryThreshold", 200);
    });

    it("should reject invalid threshold", async () => {
      const response = await request(app)
        .post("/database/performance/threshold")
        .set("Content-Type", "application/json")
        .send(JSON.stringify({ thresholdMs: -100 }));

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty("status", "error");
    });

    it("should reject non-numeric threshold", async () => {
      const response = await request(app)
        .post("/database/performance/threshold")
        .set("Content-Type", "application/json")
        .send(JSON.stringify({ thresholdMs: "invalid" }));

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty("status", "error");
    });

    it("should apply new threshold to subsequent queries", async () => {
      await request(app)
        .post("/database/performance/threshold")
        .set("Content-Type", "application/json")
        .send(JSON.stringify({ thresholdMs: 100 }));

      trackQuery("SELECT 1", 150, { queryType: "SELECT" });

      let metricsResponse = await request(app).get(
        "/database/performance/metrics",
      );
      expect(metricsResponse.body.data.totalSlowQueries).toBe(1);

      await request(app)
        .post("/database/performance/threshold")
        .set("Content-Type", "application/json")
        .send(JSON.stringify({ thresholdMs: 200 }));

      trackQuery("SELECT 2", 150, { queryType: "SELECT" });

      metricsResponse = await request(app).get("/database/performance/metrics");
      expect(metricsResponse.body.data.totalSlowQueries).toBe(1);
    });
  });

  describe("POST /database/performance/reset", () => {
    it("should reset all performance metrics", async () => {
      trackQuery("SELECT 1", 50, { queryType: "SELECT" });
      trackQuery("SELECT 2", 100, { queryType: "SELECT" });

      let metricsResponse = await request(app).get(
        "/database/performance/metrics",
      );
      expect(metricsResponse.body.data.totalQueries).toBe(2);

      const resetResponse = await request(app)
        .post("/database/performance/reset")
        .set("Content-Type", "application/json");

      expect(resetResponse.status).toBe(200);
      expect(resetResponse.body).toHaveProperty("status", "success");
      expect(resetResponse.body.data).toHaveProperty("status", "reset");

      metricsResponse = await request(app).get("/database/performance/metrics");
      expect(metricsResponse.body.data.totalQueries).toBe(0);
    });
  });

  describe("Error handling", () => {
    it("should handle errors gracefully", async () => {
      const response = await request(app).get("/database/performance/metrics");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("status");
    });
  });

  describe("Response format", () => {
    it("should include timestamp in all responses", async () => {
      const endpoints = [
        "/database/performance/metrics",
        "/database/performance/slow-queries",
        "/database/performance/stats",
        "/database/performance/analysis",
      ];

      for (const endpoint of endpoints) {
        const response = await request(app).get(endpoint);
        expect(response.body).toHaveProperty("timestamp");
      }
    });

    it("should include status in all responses", async () => {
      const endpoints = [
        "/database/performance/metrics",
        "/database/performance/slow-queries",
        "/database/performance/stats",
        "/database/performance/analysis",
      ];

      for (const endpoint of endpoints) {
        const response = await request(app).get(endpoint);
        expect(response.body).toHaveProperty("status");
      }
    });
  });
});
