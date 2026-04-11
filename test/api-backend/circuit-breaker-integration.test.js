import {} from "@jest/globals";

import express from "express";

import request from "supertest";
import {
  createCircuitBreakerMiddleware,
  circuitBreakerErrorHandler,
  executeWithCircuitBreaker,
  getCircuitBreakerMetrics,
  resetAllCircuitBreakers,
  getCircuitBreakerStatus,
  openCircuitBreaker,
  closeCircuitBreaker,
} from "../../services/api-backend/middleware/circuit-breaker-middleware.js";
import { circuitBreakerManager } from "../../services/api-backend/services/circuit-breaker.js";

// Import for route handlers
import { executeWithCircuitBreaker as executeWithCB } from "../../services/api-backend/middleware/circuit-breaker-middleware.js";

describe("Circuit Breaker Middleware Integration", () => {
  let app;

  beforeEach(() => {
    app = express();
    circuitBreakerManager.resetAll();

    // Add middleware
    app.use(express.json());

    // Add correlation ID middleware
    app.use((req, res, next) => {
      req.correlationId = "test-correlation-id";
      next();
    });

    // Test routes with circuit breaker execution
    app.get(
      "/test-service",
      createCircuitBreakerMiddleware("test-service", {
        failureThreshold: 2,
        successThreshold: 1,
        timeout: 100,
      }),
      async (req, res, next) => {
        try {
          const result = await executeWithCB("test-service", async () => {
            return { status: "ok" };
          });
          res.json(result);
        } catch (error) {
          next(error);
        }
      },
    );

    app.get(
      "/failing-service",
      createCircuitBreakerMiddleware("failing-service", {
        failureThreshold: 2,
        successThreshold: 1,
        timeout: 100,
      }),
      async (req, res, next) => {
        try {
          await executeWithCB("failing-service", async () => {
            throw new Error("Service error");
          });
        } catch (error) {
          next(error);
        }
      },
    );

    app.get("/metrics", getCircuitBreakerMetrics);
    app.post("/reset", resetAllCircuitBreakers);
    app.get("/status/:serviceName", getCircuitBreakerStatus);
    app.post("/open/:serviceName", openCircuitBreaker);
    app.post("/close/:serviceName", closeCircuitBreaker);

    // Error handlers
    app.use(circuitBreakerErrorHandler);

    // Generic error handler
    app.use((err, req, res, _next) => {
      if (err.code === "CIRCUIT_BREAKER_OPEN") {
        return res.status(503).json({
          error: {
            code: "SERVICE_UNAVAILABLE",
            message: `Service is temporarily unavailable`,
            category: "service_unavailable",
            statusCode: 503,
            correlationId: req.correlationId,
            suggestion: "Please try again in a few moments",
          },
        });
      }
      res.status(500).json({ error: err.message });
    });
  });

  describe("Middleware Integration", () => {
    test("should allow requests when circuit is CLOSED", async () => {
      const response = await request(app).get("/test-service");
      expect(response.status).toBe(200);
      expect(response.body.status).toBe("ok");
    });

    test("should reject requests when circuit is OPEN", async () => {
      // Fail twice to open circuit
      await request(app).get("/failing-service");
      await request(app).get("/failing-service");

      // Next request should be rejected
      const response = await request(app).get("/failing-service");
      expect(response.status).toBe(503);
      expect(response.body.error.code).toBe("SERVICE_UNAVAILABLE");
    });

    test("should include correlation ID in error response", async () => {
      // Fail twice to open circuit
      await request(app).get("/failing-service");
      await request(app).get("/failing-service");

      // Next request should include correlation ID
      const response = await request(app).get("/failing-service");
      expect(response.body.error.correlationId).toBe("test-correlation-id");
    });
  });

  describe("Metrics Endpoint", () => {
    test("should return metrics for all circuit breakers", async () => {
      await request(app).get("/test-service");
      await request(app).get("/failing-service");

      const response = await request(app).get("/metrics");
      expect(response.status).toBe(200);
      expect(response.body.circuitBreakers).toBeDefined();
      expect(response.body.circuitBreakers["test-service"]).toBeDefined();
      expect(response.body.circuitBreakers["failing-service"]).toBeDefined();
    });

    test("should include timestamp in metrics response", async () => {
      const response = await request(app).get("/metrics");
      expect(response.body.timestamp).toBeDefined();
    });
  });

  describe("Reset Endpoint", () => {
    test("should reset all circuit breakers", async () => {
      // Open a circuit
      await request(app).get("/failing-service");
      await request(app).get("/failing-service");

      // Verify it's open
      let response = await request(app).get("/status/failing-service");
      expect(response.body.metrics.state).toBe("OPEN");

      // Reset
      await request(app).post("/reset");

      // Verify it's closed
      response = await request(app).get("/status/failing-service");
      expect(response.body.metrics.state).toBe("CLOSED");
    });
  });

  describe("Status Endpoint", () => {
    test("should return status for specific circuit breaker", async () => {
      await request(app).get("/test-service");

      const response = await request(app).get("/status/test-service");
      expect(response.status).toBe(200);
      expect(response.body.service).toBe("test-service");
      expect(response.body.metrics).toBeDefined();
      expect(response.body.metrics.state).toBe("CLOSED");
    });

    test("should return 404 for non-existent circuit breaker", async () => {
      const response = await request(app).get("/status/non-existent");
      expect(response.status).toBe(404);
      expect(response.body.error.code).toBe("NOT_FOUND");
    });
  });

  describe("Manual Control Endpoints", () => {
    test("should manually open a circuit breaker", async () => {
      const response = await request(app).post("/open/test-service");
      expect(response.status).toBe(200);
      expect(response.body.state).toBe("OPEN");

      // Verify it's actually open
      const statusResponse = await request(app).get("/status/test-service");
      expect(statusResponse.body.metrics.state).toBe("OPEN");
    });

    test("should manually close a circuit breaker", async () => {
      // First open it
      await request(app).post("/open/test-service");

      // Then close it
      const response = await request(app).post("/close/test-service");
      expect(response.status).toBe(200);
      expect(response.body.state).toBe("CLOSED");

      // Verify it's actually closed
      const statusResponse = await request(app).get("/status/test-service");
      expect(statusResponse.body.metrics.state).toBe("CLOSED");
    });

    test("should return 404 when opening non-existent circuit breaker", async () => {
      const response = await request(app).post("/open/non-existent");
      expect(response.status).toBe(404);
    });

    test("should return 404 when closing non-existent circuit breaker", async () => {
      const response = await request(app).post("/close/non-existent");
      expect(response.status).toBe(404);
    });
  });
});

describe("executeWithCircuitBreaker Utility", () => {
  beforeEach(() => {
    circuitBreakerManager.resetAll();
  });

  test("should execute function successfully", async () => {
    const fn = async () => "success";
    const result = await executeWithCircuitBreaker("test-service", fn);
    expect(result).toBe("success");
  });

  test("should throw error when circuit is open", async () => {
    const failingFn = async () => {
      throw new Error("Service failed");
    };

    // Open the circuit
    for (let i = 0; i < 5; i++) {
      try {
        await executeWithCircuitBreaker("test-service", failingFn, {
          failureThreshold: 2,
        });
      } catch (e) {
        // Expected
      }
    }

    // Next call should throw circuit breaker error
    const fn = async () => "success";
    try {
      await executeWithCircuitBreaker("test-service", fn);
      fail("Should have thrown");
    } catch (error) {
      expect(error.code).toBe("CIRCUIT_BREAKER_OPEN");
    }
  });

  test("should use custom options", async () => {
    const fn = async () => "success";
    const result = await executeWithCircuitBreaker("custom-service", fn, {
      failureThreshold: 10,
      successThreshold: 5,
      timeout: 5000,
    });

    expect(result).toBe("success");

    const breaker = circuitBreakerManager.get("custom-service");
    expect(breaker).toBeDefined();
  });
});
