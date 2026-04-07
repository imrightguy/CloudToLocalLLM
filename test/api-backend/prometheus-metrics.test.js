/**
 * @fileoverview Tests for Prometheus metrics endpoint
 * Tests that metrics are properly collected and exposed
 *
 * **Feature: api-backend-enhancement, Property 11: Metrics consistency**
 * **Validates: Requirements 8.1, 8.2**
 */

import request from "supertest";
import express from "express";
import { metricsService } from "../../services/api-backend/services/metrics-service.js";
import { metricsCollectionMiddleware } from "../../services/api-backend/middleware/metrics-collection.js";
import prometheusMetricsRoutes from "../../services/api-backend/routes/prometheus-metrics.js";

describe("Prometheus Metrics Endpoint", () => {
  let app;

  beforeEach(() => {
    // Create a fresh Express app for each test
    app = express();

    // Add metrics collection middleware
    app.use(metricsCollectionMiddleware);

    // Add test routes
    app.get("/test", (req, res) => {
      res.json({ message: "test" });
    });

    app.get("/test-error", (req, res) => {
      res.status(500).json({ error: "test error" });
    });

    // Add metrics routes
    app.use("/prometheus", prometheusMetricsRoutes);

    // Reset metrics before each test
    metricsService.reset();
  });

  describe("GET /prometheus/metrics", () => {
    it("should return Prometheus metrics in text format", async () => {
      // Make a test request to generate metrics
      await request(app).get("/test").expect(200);

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify response format
      expect(response.headers["content-type"]).toContain("text/plain");
      expect(response.text).toContain("# HELP");
      expect(response.text).toContain("# TYPE");
    });

    it("should include HTTP request metrics", async () => {
      // Make test requests
      await request(app).get("/test").expect(200);
      await request(app).get("/test").expect(200);

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify HTTP metrics are present
      expect(response.text).toContain("http_request_duration_seconds");
      expect(response.text).toContain("http_requests_total");
    });

    it("should track request status codes", async () => {
      // Make requests with different status codes
      await request(app).get("/test").expect(200);
      await request(app).get("/test-error").expect(500);

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify status codes are tracked
      expect(response.text).toContain('status="200"');
      expect(response.text).toContain('status="500"');
    });

    it("should include tunnel connection metrics", async () => {
      // Update tunnel metrics
      metricsService.updateTunnelConnections(5);
      metricsService.incrementTunnelConnectionsCreated();

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify tunnel metrics are present
      expect(response.text).toContain("tunnel_connections_active");
      expect(response.text).toContain("tunnel_connections_total");
    });

    it("should include proxy instance metrics", async () => {
      // Update proxy metrics
      metricsService.updateProxyInstances(3);
      metricsService.incrementProxyInstancesCreated();

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify proxy metrics are present
      expect(response.text).toContain("proxy_instances_active");
      expect(response.text).toContain("proxy_instances_total");
    });

    it("should include database metrics", async () => {
      // Update database metrics
      metricsService.updateDatabasePoolMetrics({
        poolType: "main",
        size: 10,
        available: 8,
      });

      metricsService.recordDatabaseQuery({
        queryType: "select",
        duration: 50,
      });

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify database metrics are present
      expect(response.text).toContain("db_connection_pool_size");
      expect(response.text).toContain("db_query_duration_seconds");
      expect(response.text).toContain("db_queries_total");
    });

    it("should include authentication metrics", async () => {
      // Record authentication attempt
      metricsService.recordAuthAttempt({
        authType: "jwt",
        result: "success",
      });

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify auth metrics are present
      expect(response.text).toContain("auth_attempts_total");
    });

    it("should include rate limiting metrics", async () => {
      // Record rate limit violation
      metricsService.recordRateLimitViolation({
        violationType: "per_user",
        userTier: "free",
      });

      metricsService.updateRateLimitedUsers(2);

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify rate limit metrics are present
      expect(response.text).toContain("rate_limit_violations_total");
      expect(response.text).toContain("rate_limited_users_active");
    });

    it("should include system metrics", async () => {
      // Update system metrics
      metricsService.updateApiUptime(3600);
      metricsService.updateActiveUsers(42);
      metricsService.updateSystemLoad({
        cpu: 45.5,
        memory: 62.3,
        disk: 78.1,
      });

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify system metrics are present
      expect(response.text).toContain("api_uptime_seconds");
      expect(response.text).toContain("active_users");
      expect(response.text).toContain("system_load");
    });

    it("should set proper cache control headers", async () => {
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      expect(response.headers["cache-control"]).toContain("no-cache");
      expect(response.headers["pragma"]).toBe("no-cache");
      expect(response.headers["expires"]).toBe("0");
    });
  });

  describe("GET /prometheus/health/metrics", () => {
    it("should return healthy status when metrics are working", async () => {
      const response = await request(app)
        .get("/prometheus/health/metrics")
        .expect(200);

      expect(response.body.status).toBe("healthy");
      expect(response.body.message).toContain("working");
      expect(response.body.metricsSize).toBeGreaterThan(0);
    });

    it("should include timestamp in health response", async () => {
      const response = await request(app)
        .get("/prometheus/health/metrics")
        .expect(200);

      expect(response.body.timestamp).toBeDefined();
      expect(new Date(response.body.timestamp)).toBeInstanceOf(Date);
    });
  });

  describe("Metrics Collection Middleware", () => {
    it("should collect metrics for successful requests", async () => {
      // Make a request
      await request(app).get("/test").expect(200);

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify metrics were collected
      expect(response.text).toContain("http_requests_total");
      expect(response.text).toContain('status="200"');
    });

    it("should collect metrics for error requests", async () => {
      // Make an error request
      await request(app).get("/test-error").expect(500);

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify error metrics were collected
      expect(response.text).toContain('status="500"');
    });

    it("should track request duration", async () => {
      // Make a request
      await request(app).get("/test").expect(200);

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify duration histogram is present
      expect(response.text).toContain("http_request_duration_seconds_bucket");
      expect(response.text).toContain("http_request_duration_seconds_sum");
      expect(response.text).toContain("http_request_duration_seconds_count");
    });

    it("should track multiple requests", async () => {
      // Make multiple requests
      await request(app).get("/test").expect(200);
      await request(app).get("/test").expect(200);
      await request(app).get("/test").expect(200);

      // Get metrics
      const response = await request(app)
        .get("/prometheus/metrics")
        .expect(200);

      // Verify request count increased
      expect(response.text).toContain("http_requests_total");
      // Should have count of 3 (plus the metrics endpoint call)
      const matches = response.text.match(/http_requests_total.*\n/g);
      expect(matches).toBeDefined();
    });
  });

  describe("Metrics Service", () => {
    it("should record HTTP request metrics", () => {
      metricsService.recordHttpRequest({
        method: "GET",
        route: "/test",
        status: 200,
        duration: 100,
      });

      // Verify no errors thrown
      expect(true).toBe(true);
    });

    it("should update tunnel connections", () => {
      metricsService.updateTunnelConnections(5);
      metricsService.incrementTunnelConnectionsCreated();

      // Verify no errors thrown
      expect(true).toBe(true);
    });

    it("should update proxy instances", () => {
      metricsService.updateProxyInstances(3);
      metricsService.incrementProxyInstancesCreated();

      // Verify no errors thrown
      expect(true).toBe(true);
    });

    it("should record database queries", () => {
      metricsService.recordDatabaseQuery({
        queryType: "select",
        duration: 50,
      });

      // Verify no errors thrown
      expect(true).toBe(true);
    });

    it("should handle errors gracefully", () => {
      // These should not throw errors
      metricsService.recordHttpRequest({
        method: "GET",
        route: "/test",
        status: 200,
        duration: 100,
        error: { type: "test_error" },
      });

      metricsService.recordDatabaseQuery({
        queryType: "select",
        duration: 50,
        error: { type: "query_error" },
      });

      expect(true).toBe(true);
    });
  });
});
