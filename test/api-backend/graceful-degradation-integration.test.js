/**


 * Graceful Degradation Integration Tests
 * 
 * Tests for graceful degradation middleware integration with Express.
 * Validates middleware behavior and endpoint responses during degradation.
 * 
 * Requirement 7.6: THE API SHALL implement graceful degradation when services are unavailable
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import express from "express";
import request from "supertest";
import {
  createGracefulDegradationMiddleware,
  degradationStatusMiddleware,
  getDegradationStatus,
  markServiceDegraded,
  markServiceRecovered,
  getDegradationMetrics,
  resetAllDegradation,
  createReducedFunctionalityMiddleware,
} from "../../services/api-backend/middleware/graceful-degradation-middleware.js";
import { gracefulDegradationService } from "../../services/api-backend/services/graceful-degradation.js";

describe("Graceful Degradation Middleware Integration", () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use(express.json());

    // Reset degradation service
    gracefulDegradationService.resetAll();
  });

  afterEach(() => {
    gracefulDegradationService.resetAll();
  });

  describe("Graceful Degradation Middleware", () => {
    it("should allow requests when service is healthy", async () => {
      gracefulDegradationService.registerService("test-service", {
        criticalEndpoints: ["/api/critical"],
      });

      app.get(
        "/api/data",
        createGracefulDegradationMiddleware("test-service"),
        (req, res) => {
          res.json({ data: "success" });
        },
      );

      const response = await request(app).get("/api/data");

      expect(response.status).toBe(200);
      expect(response.body).toEqual({ data: "success" });
    });

    it("should reject critical endpoints when service is degraded", async () => {
      gracefulDegradationService.registerService("test-service", {
        criticalEndpoints: ["/api/critical"],
      });

      app.get(
        "/api/critical",
        createGracefulDegradationMiddleware("test-service"),
        (req, res) => {
          res.json({ data: "success" });
        },
      );

      gracefulDegradationService.markDegraded(
        "test-service",
        "Database unavailable",
      );

      const response = await request(app).get("/api/critical");

      expect(response.status).toBe(503);
      expect(response.body.error.code).toBe("SERVICE_DEGRADED");
      expect(response.body.error.message).toContain("Database unavailable");
    });

    it("should allow non-critical endpoints when service is degraded", async () => {
      gracefulDegradationService.registerService("test-service", {
        criticalEndpoints: ["/api/critical"],
      });

      app.get(
        "/api/data",
        createGracefulDegradationMiddleware("test-service"),
        (req, res) => {
          res.json({ data: "success" });
        },
      );

      gracefulDegradationService.markDegraded(
        "test-service",
        "Database unavailable",
      );

      const response = await request(app).get("/api/data");

      expect(response.status).toBe(200);
      expect(response.body).toEqual({ data: "success" });
    });

    it("should add degradation status to request", async () => {
      gracefulDegradationService.registerService("test-service");

      app.get(
        "/api/data",
        createGracefulDegradationMiddleware("test-service"),
        (req, res) => {
          res.json({ degradationStatus: req.degradationStatus });
        },
      );

      const response = await request(app).get("/api/data");

      expect(response.body.degradationStatus).toBeDefined();
      expect(response.body.degradationStatus.service).toBe("test-service");
    });

    it("should include degradation info in error response", async () => {
      gracefulDegradationService.registerService("test-service", {
        criticalEndpoints: ["/api/critical"],
      });

      app.get(
        "/api/critical",
        createGracefulDegradationMiddleware("test-service"),
        (req, res) => {
          res.json({ data: "success" });
        },
      );

      gracefulDegradationService.markDegraded(
        "test-service",
        "Connection timeout",
        "critical",
      );

      const response = await request(app).get("/api/critical");

      expect(response.body.error.degradationInfo).toBeDefined();
      expect(response.body.error.degradationInfo.service).toBe("test-service");
      expect(response.body.error.degradationInfo.severity).toBe("critical");
    });
  });

  describe("Degradation Status Middleware", () => {
    it("should add service status headers when degraded", async () => {
      gracefulDegradationService.registerService("service-1");
      gracefulDegradationService.registerService("service-2");

      app.get("/api/data", degradationStatusMiddleware, (req, res) => {
        res.json({ data: "success" });
      });

      gracefulDegradationService.markDegraded("service-1", "Degradation 1");
      gracefulDegradationService.markDegraded("service-2", "Degradation 2");

      const response = await request(app).get("/api/data");

      expect(response.headers["x-service-status"]).toBe("degraded");
      expect(response.headers["x-degraded-services"]).toBe("2");
    });

    it("should not add status headers when all services healthy", async () => {
      gracefulDegradationService.registerService("service-1");

      app.get("/api/data", degradationStatusMiddleware, (req, res) => {
        res.json({ data: "success" });
      });

      const response = await request(app).get("/api/data");

      expect(response.headers["x-service-status"]).toBeUndefined();
    });
  });

  describe("Degradation Status Endpoints", () => {
    beforeEach(() => {
      app.get("/api/degradation/status/:serviceName", getDegradationStatus);
      app.get("/api/degradation/status", getDegradationStatus);
      gracefulDegradationService.resetAll();
    });

    it("should get status for specific service", async () => {
      gracefulDegradationService.registerService("test-service-status");
      gracefulDegradationService.markDegraded(
        "test-service-status",
        "Test degradation",
      );

      const response = await request(app).get(
        "/api/degradation/status/test-service-status",
      );

      expect(response.status).toBe(200);
      expect(response.body.status.service).toBe("test-service-status");
      expect(response.body.status.isDegraded).toBe(true);
    });

    it("should get all statuses", async () => {
      gracefulDegradationService.registerService("service-1-status");
      gracefulDegradationService.registerService("service-2-status");
      gracefulDegradationService.markDegraded(
        "service-1-status",
        "Degradation 1",
      );

      const response = await request(app).get("/api/degradation/status");

      expect(response.status).toBe(200);
      const services = response.body.services.filter((s) =>
        s.service.includes("status"),
      );
      expect(services.length).toBeGreaterThanOrEqual(2);
      expect(
        services.filter((s) => s.isDegraded).length,
      ).toBeGreaterThanOrEqual(1);
    });

    it("should include timestamp in response", async () => {
      gracefulDegradationService.registerService("test-service");

      const response = await request(app).get(
        "/api/degradation/status/test-service",
      );

      expect(response.body.timestamp).toBeDefined();
      expect(new Date(response.body.timestamp)).toBeInstanceOf(Date);
    });
  });

  describe("Mark Service Degraded Endpoint", () => {
    beforeEach(() => {
      app.post("/api/degradation/mark-degraded", markServiceDegraded);
      gracefulDegradationService.resetAll();
    });

    it("should mark service as degraded", async () => {
      gracefulDegradationService.registerService("test-service-degrade");

      const response = await request(app)
        .post("/api/degradation/mark-degraded")
        .set("Content-Type", "application/json")
        .send({
          serviceName: "test-service-degrade",
          reason: "Manual degradation",
          severity: "warning",
        });

      expect(response.status).toBe(200);
      expect(response.body.status.isDegraded).toBe(true);
      expect(response.body.status.reason).toBe("Manual degradation");
    });

    it("should return error if serviceName is missing", async () => {
      const response = await request(app)
        .post("/api/degradation/mark-degraded")
        .set("Content-Type", "application/json")
        .send({
          reason: "Manual degradation",
        });

      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe("INVALID_REQUEST");
    });

    it("should use default reason if not provided", async () => {
      gracefulDegradationService.registerService("test-service-degrade2");

      const response = await request(app)
        .post("/api/degradation/mark-degraded")
        .set("Content-Type", "application/json")
        .send({
          serviceName: "test-service-degrade2",
        });

      expect(response.status).toBe(200);
      expect(response.body.status.reason).toBe("Manual degradation");
    });
  });

  describe("Mark Service Recovered Endpoint", () => {
    beforeEach(() => {
      app.post("/api/degradation/mark-recovered", markServiceRecovered);
      gracefulDegradationService.resetAll();
    });

    it("should mark service as recovered", async () => {
      gracefulDegradationService.registerService("test-service-recover");
      gracefulDegradationService.markDegraded(
        "test-service-recover",
        "Test degradation",
      );

      const response = await request(app)
        .post("/api/degradation/mark-recovered")
        .set("Content-Type", "application/json")
        .send({
          serviceName: "test-service-recover",
        });

      expect(response.status).toBe(200);
      expect(response.body.status.isDegraded).toBe(false);
    });

    it("should return error if serviceName is missing", async () => {
      const response = await request(app)
        .post("/api/degradation/mark-recovered")
        .set("Content-Type", "application/json")
        .send({});

      expect(response.status).toBe(400);
      expect(response.body.error.code).toBe("INVALID_REQUEST");
    });
  });

  describe("Degradation Metrics Endpoint", () => {
    beforeEach(() => {
      app.get("/api/degradation/metrics", getDegradationMetrics);
    });

    it("should return degradation metrics", async () => {
      gracefulDegradationService.registerService("test-service");
      gracefulDegradationService.markDegraded(
        "test-service",
        "Test degradation",
      );

      const response = await request(app).get("/api/degradation/metrics");

      expect(response.status).toBe(200);
      expect(response.body.metrics).toBeDefined();
      expect(response.body.metrics.totalDegradations).toBeGreaterThan(0);
      expect(response.body.metrics.activeDegradations).toBe(1);
    });

    it("should include timestamp in metrics", async () => {
      const response = await request(app).get("/api/degradation/metrics");

      expect(response.body.timestamp).toBeDefined();
      expect(new Date(response.body.timestamp)).toBeInstanceOf(Date);
    });
  });

  describe("Reset All Degradation Endpoint", () => {
    beforeEach(() => {
      app.post("/api/degradation/reset", resetAllDegradation);
    });

    it("should reset all degradation states", async () => {
      gracefulDegradationService.registerService("service-1");
      gracefulDegradationService.registerService("service-2");
      gracefulDegradationService.markDegraded("service-1", "Degradation 1");
      gracefulDegradationService.markDegraded("service-2", "Degradation 2");

      const response = await request(app).post("/api/degradation/reset");

      expect(response.status).toBe(200);
      expect(response.body.message).toContain("reset");

      const status1 = gracefulDegradationService.getStatus("service-1");
      const status2 = gracefulDegradationService.getStatus("service-2");

      expect(status1.isDegraded).toBe(false);
      expect(status2.isDegraded).toBe(false);
    });
  });

  describe("Reduced Functionality Middleware", () => {
    it("should add reduced functionality info for non-critical endpoints", async () => {
      gracefulDegradationService.registerService("test-service", {
        criticalEndpoints: ["/api/critical"],
        reducedFunctionality: {
          availableFeatures: ["read"],
          unavailableFeatures: ["write"],
        },
      });

      app.get(
        "/api/data",
        createReducedFunctionalityMiddleware("test-service"),
        (req, res) => {
          res.json({ reducedFunctionality: req.reducedFunctionality });
        },
      );

      gracefulDegradationService.markDegraded(
        "test-service",
        "Database unavailable",
      );

      const response = await request(app).get("/api/data");

      expect(response.body.reducedFunctionality).toBeDefined();
      expect(response.body.reducedFunctionality.isDegraded).toBe(true);
      expect(response.body.reducedFunctionality.availableFeatures).toContain(
        "read",
      );
    });

    it("should not add reduced functionality info for critical endpoints", async () => {
      gracefulDegradationService.registerService("test-service", {
        criticalEndpoints: ["/api/critical"],
      });

      app.get(
        "/api/critical",
        createReducedFunctionalityMiddleware("test-service"),
        (req, res) => {
          res.json({ reducedFunctionality: req.reducedFunctionality });
        },
      );

      gracefulDegradationService.markDegraded(
        "test-service",
        "Database unavailable",
      );

      const response = await request(app).get("/api/critical");

      expect(response.body.reducedFunctionality).toBeUndefined();
    });
  });

  describe("Multiple Service Degradation Scenarios", () => {
    it("should handle multiple services with different degradation states", async () => {
      gracefulDegradationService.registerService("service-1", {
        criticalEndpoints: ["/api/critical-1"],
      });
      gracefulDegradationService.registerService("service-2", {
        criticalEndpoints: ["/api/critical-2"],
      });

      app.get(
        "/api/critical-1",
        createGracefulDegradationMiddleware("service-1"),
        (req, res) => res.json({ data: "success" }),
      );

      app.get(
        "/api/critical-2",
        createGracefulDegradationMiddleware("service-2"),
        (req, res) => res.json({ data: "success" }),
      );

      gracefulDegradationService.markDegraded("service-1", "Degradation 1");

      const response1 = await request(app).get("/api/critical-1");
      const response2 = await request(app).get("/api/critical-2");

      expect(response1.status).toBe(503);
      expect(response2.status).toBe(200);
    });

    it("should recover services independently", async () => {
      gracefulDegradationService.registerService("service-1", {
        criticalEndpoints: ["/api/critical-1"],
      });
      gracefulDegradationService.registerService("service-2", {
        criticalEndpoints: ["/api/critical-2"],
      });

      app.get(
        "/api/critical-1",
        createGracefulDegradationMiddleware("service-1"),
        (req, res) => res.json({ data: "success" }),
      );

      app.get(
        "/api/critical-2",
        createGracefulDegradationMiddleware("service-2"),
        (req, res) => res.json({ data: "success" }),
      );

      gracefulDegradationService.markDegraded("service-1", "Degradation 1");
      gracefulDegradationService.markDegraded("service-2", "Degradation 2");

      gracefulDegradationService.markRecovered("service-1");

      const response1 = await request(app).get("/api/critical-1");
      const response2 = await request(app).get("/api/critical-2");

      expect(response1.status).toBe(200);
      expect(response2.status).toBe(503);
    });
  });

  describe("Error Response Format", () => {
    it("should include correlation ID in error response", async () => {
      gracefulDegradationService.registerService("test-service", {
        criticalEndpoints: ["/api/critical"],
      });

      app.use((req, res, next) => {
        req.correlationId = "test-correlation-id";
        next();
      });

      app.get(
        "/api/critical",
        createGracefulDegradationMiddleware("test-service"),
        (req, res) => res.json({ data: "success" }),
      );

      gracefulDegradationService.markDegraded(
        "test-service",
        "Test degradation",
      );

      const response = await request(app).get("/api/critical");

      expect(response.body.error.correlationId).toBe("test-correlation-id");
    });

    it("should include suggestion in error response", async () => {
      gracefulDegradationService.registerService("test-service", {
        criticalEndpoints: ["/api/critical"],
      });

      app.get(
        "/api/critical",
        createGracefulDegradationMiddleware("test-service"),
        (req, res) => res.json({ data: "success" }),
      );

      gracefulDegradationService.markDegraded(
        "test-service",
        "Test degradation",
      );

      const response = await request(app).get("/api/critical");

      expect(response.body.error.suggestion).toBeDefined();
      expect(response.body.error.suggestion).toContain("try again");
    });
  });
});
