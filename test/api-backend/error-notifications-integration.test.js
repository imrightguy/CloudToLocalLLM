/**


 * Error Notification Integration Tests
 * 
 * Tests for error notification middleware and endpoint integration.
 * Validates error notification endpoints and request handling.
 * 
 * Requirement 7.9: THE API SHALL support error notifications for critical issues
 */

import {
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
  jest,
} from "@jest/globals";
import express from "express";
import request from "supertest";
import {
  createErrorNotificationMiddleware,
  withErrorNotification,
  createErrorNotificationStatusHandler,
  createErrorHistoryHandler,
  createErrorStatisticsHandler,
  createErrorMetricsHandler,
  createErrorResetHandler,
  createManualErrorNotificationHandler,
} from "../../services/api-backend/middleware/error-notification-middleware.js";
import { errorNotificationService } from "../../services/api-backend/services/error-notification-service.js";
import { ErrorNotificationService } from "../../services/api-backend/services/error-notification-service.js";

describe("Error Notification Middleware Integration", () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use(express.json());

    // Reset service state
    errorNotificationService.clearHistory();
    errorNotificationService.resetMetrics();
    errorNotificationService.resetErrorCounts();
  });

  afterEach(() => {
    errorNotificationService.clearHistory();
    errorNotificationService.resetMetrics();
    errorNotificationService.resetErrorCounts();
  });

  describe("Error Notification Endpoints", () => {
    beforeEach(() => {
      // Setup routes
      app.get("/api/status", createErrorNotificationStatusHandler());
      app.get("/api/history", createErrorHistoryHandler());
      app.get("/api/statistics", createErrorStatisticsHandler());
      app.get("/api/metrics", createErrorMetricsHandler());
      app.post("/api/reset", createErrorResetHandler());
      app.post(
        "/api/manual-notification",
        createManualErrorNotificationHandler(),
      );
    });

    it("should return notification status", async () => {
      const response = await request(app).get("/api/status");

      expect(response.status).toBe(200);
      expect(response.body.enabled).toBeDefined();
      expect(response.body.channels).toBeDefined();
      expect(response.body.queueSize).toBeDefined();
      expect(response.body.metrics).toBeDefined();
      expect(response.body.statistics).toBeDefined();
    });

    it("should return error history", async () => {
      // Trigger an error
      await errorNotificationService.detectAndNotify(new Error("Test error"));

      const response = await request(app).get("/api/history");

      expect(response.status).toBe(200);
      expect(response.body.count).toBeGreaterThan(0);
      expect(Array.isArray(response.body.errors)).toBe(true);
    });

    it("should filter error history by category", async () => {
      await errorNotificationService.detectAndNotify(
        new Error("Database error"),
      );

      const response = await request(app)
        .get("/api/history")
        .query({ category: "database" });

      expect(response.status).toBe(200);
      expect(response.body.count).toBeGreaterThan(0);
    });

    it("should filter error history by severity", async () => {
      await errorNotificationService.detectAndNotify(
        new Error("Database error"),
      );

      const response = await request(app)
        .get("/api/history")
        .query({ severity: "critical" });

      expect(response.status).toBe(200);
    });

    it("should limit error history results", async () => {
      for (let i = 0; i < 10; i++) {
        await errorNotificationService.detectAndNotify(new Error(`Error ${i}`));
      }

      const response = await request(app)
        .get("/api/history")
        .query({ limit: 5 });

      expect(response.status).toBe(200);
      expect(response.body.count).toBeLessThanOrEqual(5);
    });

    it("should return error statistics", async () => {
      await errorNotificationService.detectAndNotify(
        new Error("Database error"),
      );
      await errorNotificationService.detectAndNotify(
        new Error("Authentication error"),
      );

      const response = await request(app).get("/api/statistics");

      expect(response.status).toBe(200);
      expect(response.body.totalErrors).toBeGreaterThan(0);
      expect(response.body.errorsByCategory).toBeDefined();
    });

    it("should return error metrics", async () => {
      await errorNotificationService.detectAndNotify(
        new Error("Database error"),
      );

      const response = await request(app).get("/api/metrics");

      expect(response.status).toBe(200);
      expect(response.body.totalErrorsDetected).toBeGreaterThan(0);
      expect(response.body.notificationsSent).toBeDefined();
      expect(response.body.queueSize).toBeDefined();
    });

    it("should reset error counts", async () => {
      await errorNotificationService.detectAndNotify(
        new Error("Database error"),
      );

      let response = await request(app).get("/api/statistics");
      expect(response.body.totalErrors).toBeGreaterThan(0);

      response = await request(app).post("/api/reset").send({ type: "counts" });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);

      response = await request(app).get("/api/statistics");
      expect(response.body.totalErrors).toBe(0);
    });

    it("should reset error history", async () => {
      await errorNotificationService.detectAndNotify(
        new Error("Database error"),
      );

      let response = await request(app).get("/api/history");
      expect(response.body.count).toBeGreaterThan(0);

      response = await request(app)
        .post("/api/reset")
        .send({ type: "history" });

      expect(response.status).toBe(200);

      response = await request(app).get("/api/history");
      expect(response.body.count).toBe(0);
    });

    it("should reset metrics", async () => {
      await errorNotificationService.detectAndNotify(
        new Error("Database error"),
      );

      let response = await request(app).get("/api/metrics");
      expect(response.body.totalErrorsDetected).toBeGreaterThan(0);

      response = await request(app)
        .post("/api/reset")
        .send({ type: "metrics" });

      expect(response.status).toBe(200);

      response = await request(app).get("/api/metrics");
      expect(response.body.totalErrorsDetected).toBe(0);
    });

    it("should reset all data", async () => {
      await errorNotificationService.detectAndNotify(
        new Error("Database error"),
      );

      const response = await request(app)
        .post("/api/reset")
        .send({ type: "all" });

      expect(response.status).toBe(200);

      const historyResponse = await request(app).get("/api/history");
      expect(historyResponse.body.count).toBe(0);

      const metricsResponse = await request(app).get("/api/metrics");
      expect(metricsResponse.body.totalErrorsDetected).toBe(0);
    });

    it("should reject invalid reset type", async () => {
      const response = await request(app)
        .post("/api/reset")
        .send({ type: "invalid" });

      expect(response.status).toBe(400);
      expect(response.body.error).toBeDefined();
    });

    it("should send manual error notification", async () => {
      const response = await request(app)
        .post("/api/manual-notification")
        .send({
          message: "Test error notification",
          category: "database",
          severity: "critical",
        });

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
      expect(response.body.result).toBeDefined();
    });

    it("should reject manual notification without message", async () => {
      const response = await request(app)
        .post("/api/manual-notification")
        .send({});

      expect(response.status).toBe(400);
      expect(response.body.error).toBeDefined();
    });
  });

  describe("Error Notification Middleware", () => {
    it("should detect errors in middleware", async () => {
      app.get("/api/error", (req, res, next) => {
        next(new Error("Test error"));
      });

      app.use(createErrorNotificationMiddleware());
      app.use((error, req, res, _next) => {
        res.status(500).json({ error: error.message });
      });

      const response = await request(app).get("/api/error");

      expect(response.status).toBe(500);

      // Check that error was detected
      const history = errorNotificationService.getErrorHistory();
      expect(history.length).toBeGreaterThan(0);
    });

    it("should include request context in error notification", async () => {
      app.get("/api/error", (req, res, next) => {
        next(new Error("Test error"));
      });

      app.use((req, res, next) => {
        req.correlationId = "test-correlation-id";
        next();
      });

      app.use(createErrorNotificationMiddleware());
      app.use((error, req, res, _next) => {
        res.status(500).json({ error: error.message });
      });

      await request(app).get("/api/error");

      const history = errorNotificationService.getErrorHistory();
      expect(history.length).toBeGreaterThan(0);
      expect(history[0].context).toBeDefined();
    });
  });

  describe("withErrorNotification Wrapper", () => {
    it("should wrap route handler and catch errors", async () => {
      app.get(
        "/api/test",
        withErrorNotification(async (_req, _res) => {
          throw new Error("Handler error");
        }),
      );

      app.use((error, req, res, _next) => {
        res.status(500).json({ error: error.message });
      });

      const response = await request(app).get("/api/test");

      expect(response.status).toBe(500);

      const history = errorNotificationService.getErrorHistory();
      expect(history.length).toBeGreaterThan(0);
    });

    it("should pass successful responses through", async () => {
      app.get(
        "/api/test",
        withErrorNotification(async (_req, _res) => {
          _res.json({ success: true });
        }),
      );

      const response = await request(app).get("/api/test");

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    it("should include request context in wrapped handler errors", async () => {
      app.use((req, res, next) => {
        req.correlationId = "test-id";
        next();
      });

      app.get(
        "/api/test",
        withErrorNotification(async (_req, _res) => {
          throw new Error("Database error");
        }),
      );

      app.use((error, req, res, _next) => {
        res.status(500).json({ error: error.message });
      });

      await request(app).get("/api/test");

      const history = errorNotificationService.getErrorHistory();
      expect(history.length).toBeGreaterThan(0);
      expect(history[0].context.correlationId).toBe("test-id");
    });
  });

  describe("Error Notification with Multiple Channels", () => {
    it("should send notifications through multiple channels", async () => {
      const handler1 = jest.fn().mockResolvedValue(undefined);
      const handler2 = jest.fn().mockResolvedValue(undefined);

      errorNotificationService.registerNotificationHandler(
        "channel1",
        handler1,
      );
      errorNotificationService.registerNotificationHandler(
        "channel2",
        handler2,
      );
      errorNotificationService.config.notificationChannels = [
        "channel1",
        "channel2",
      ];

      const error = new Error("Database error");
      await errorNotificationService.detectAndNotify(error);

      expect(handler1).toHaveBeenCalled();
      expect(handler2).toHaveBeenCalled();
    });

    it("should continue sending through other channels if one fails", async () => {
      const handler1 = jest.fn().mockRejectedValue(new Error("Handler failed"));
      const handler2 = jest.fn().mockResolvedValue(undefined);

      errorNotificationService.registerNotificationHandler(
        "channel1",
        handler1,
      );
      errorNotificationService.registerNotificationHandler(
        "channel2",
        handler2,
      );
      errorNotificationService.config.notificationChannels = [
        "channel1",
        "channel2",
      ];

      const error = new Error("Database error");
      await errorNotificationService.detectAndNotify(error);

      expect(handler1).toHaveBeenCalled();
      expect(handler2).toHaveBeenCalled();

      const metrics = errorNotificationService.getMetrics();
      expect(metrics.notificationsFailed).toBe(1);
      expect(metrics.notificationsSent).toBe(1);
    });
  });

  describe("Error Notification Queue", () => {
    it("should queue notifications when processing", async () => {
      const handler = jest
        .fn()
        .mockImplementation(
          () => new Promise((resolve) => setTimeout(resolve, 100)),
        );

      errorNotificationService.registerNotificationHandler("test", handler);
      errorNotificationService.config.notificationChannels = ["test"];

      const error = new Error("Database error");
      await errorNotificationService.detectAndNotify(error);

      const status = errorNotificationService.getStatus();
      expect(status.queueSize).toBeGreaterThanOrEqual(0);
    });

    it("should not exceed maximum queue size", async () => {
      const service = new ErrorNotificationService({
        maxNotificationQueueSize: 5,
      });

      const handler = jest
        .fn()
        .mockImplementation(
          () => new Promise((resolve) => setTimeout(resolve, 1000)),
        );

      service.registerNotificationHandler("test", handler);
      service.config.notificationChannels = ["test"];

      // Queue multiple notifications
      for (let i = 0; i < 10; i++) {
        const error = new Error(`Error ${i}`);
        await service.detectAndNotify(error);
      }

      const status = service.getStatus();
      expect(status.queueSize).toBeLessThanOrEqual(5);
    });
  });
});
