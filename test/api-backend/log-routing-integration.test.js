import {} from "@jest/globals";

/**


 * Integration Tests for Log Routing Middleware
 *
 * Tests log routing middleware integration with Express,
 * log batching, and aggregation system communication.
 *
 * **Feature: api-backend-enhancement, Property 11: Metrics consistency**
 * **Validates: Requirements 8.9**
 */

import express from "express";
import request from "supertest";
import {
  createLogRoutingMiddleware,
  routeLog,
  flushLogs,
  destroyLogRouting,
  logRouter,
} from "../../services/api-backend/middleware/log-routing.js";
import {
  createStructuredLogEntry,
  logAggregationConfig,
} from "../../services/api-backend/utils/log-aggregation.js";

describe("Log Routing Integration", () => {
  let app;

  beforeEach(() => {
    app = express();
    app.use(createLogRoutingMiddleware());

    app.get("/test", (req, res) => {
      res.json({ status: "ok" });
    });

    app.get("/error", (req, res) => {
      res.status(500).json({ error: "Internal Server Error" });
    });
  });

  afterEach(async () => {
    await flushLogs();
    destroyLogRouting();
  });

  describe("Log Routing Middleware", () => {
    test("should attach log routing middleware to Express app", async () => {
      const response = await request(app).get("/test");

      expect(response.status).toBe(200);
      expect(response.body.status).toBe("ok");
    });

    test("should handle requests without errors", async () => {
      const response = await request(app).get("/test");

      expect(response.status).toBe(200);
    });

    test("should handle error responses", async () => {
      const response = await request(app).get("/error");

      expect(response.status).toBe(500);
    });
  });

  describe("Log Routing with Request Context", () => {
    test("should route logs with correlation ID from request", () => {
      const req = {
        headers: {
          "x-correlation-id": "corr-123",
        },
        userId: "user-456",
      };

      const logEntry = createStructuredLogEntry({
        level: "info",
        message: "Test log",
      });

      // Should not throw
      expect(() => {
        routeLog(logEntry, req);
      }).not.toThrow();

      // Log entry should be enriched
      expect(logEntry.correlationId).toBe("corr-123");
      expect(logEntry.userId).toBe("user-456");
    });

    test("should route logs without request context", () => {
      const logEntry = createStructuredLogEntry({
        level: "info",
        message: "Test log",
      });

      // Should not throw
      expect(() => {
        routeLog(logEntry);
      }).not.toThrow();
    });

    test("should preserve existing correlation ID in log entry", () => {
      const req = {
        headers: {
          "x-correlation-id": "corr-123",
        },
      };

      const logEntry = createStructuredLogEntry({
        level: "info",
        message: "Test log",
        correlationId: "corr-existing",
      });

      routeLog(logEntry, req);

      // Should preserve existing correlation ID
      expect(logEntry.correlationId).toBe("corr-existing");
    });
  });

  describe("Log Router Destination Selection", () => {
    test("should select appropriate destinations for error logs", () => {
      const router = logRouter;
      const destinations = router.getDestinations("error");

      expect(Array.isArray(destinations)).toBe(true);
      expect(destinations.length).toBeGreaterThan(0);
    });

    test("should select appropriate destinations for info logs", () => {
      const router = logRouter;
      const destinations = router.getDestinations("info");

      expect(Array.isArray(destinations)).toBe(true);
    });

    test("should select appropriate destinations for warn logs", () => {
      const router = logRouter;
      const destinations = router.getDestinations("warn");

      expect(Array.isArray(destinations)).toBe(true);
    });

    test("should select appropriate destinations for debug logs", () => {
      const router = logRouter;
      const destinations = router.getDestinations("debug");

      expect(Array.isArray(destinations)).toBe(true);
    });
  });

  describe("Log Aggregation Configuration", () => {
    test("should have valid Loki configuration", () => {
      expect(logAggregationConfig.loki).toBeDefined();
      expect(logAggregationConfig.loki.url).toBeDefined();
      expect(logAggregationConfig.loki.labels).toBeDefined();
      expect(logAggregationConfig.loki.batchSize).toBeGreaterThan(0);
      expect(logAggregationConfig.loki.batchTimeout).toBeGreaterThan(0);
    });

    test("should have valid ELK configuration", () => {
      expect(logAggregationConfig.elk).toBeDefined();
      expect(logAggregationConfig.elk.hosts).toBeDefined();
      expect(logAggregationConfig.elk.index).toBeDefined();
      expect(logAggregationConfig.elk.batchSize).toBeGreaterThan(0);
      expect(logAggregationConfig.elk.batchTimeout).toBeGreaterThan(0);
    });

    test("should have valid routing configuration", () => {
      expect(logAggregationConfig.routing).toBeDefined();
      expect(typeof logAggregationConfig.routing.errorToSentry).toBe("boolean");
      expect(typeof logAggregationConfig.routing.errorToFile).toBe("boolean");
      expect(typeof logAggregationConfig.routing.warningToFile).toBe("boolean");
      expect(typeof logAggregationConfig.routing.infoToConsole).toBe("boolean");
    });
  });

  describe("Log Flushing", () => {
    test("should flush logs without errors", async () => {
      const logEntry = createStructuredLogEntry({
        level: "info",
        message: "Test log",
      });

      routeLog(logEntry);

      // Should not throw
      await expect(flushLogs()).resolves.toBeUndefined();
    });

    test("should handle multiple log entries", async () => {
      const logEntries = [
        createStructuredLogEntry({ level: "info", message: "Log 1" }),
        createStructuredLogEntry({ level: "warn", message: "Log 2" }),
        createStructuredLogEntry({ level: "error", message: "Log 3" }),
      ];

      logEntries.forEach((entry) => routeLog(entry));

      // Should not throw
      await expect(flushLogs()).resolves.toBeUndefined();
    });
  });

  describe("Log Routing Cleanup", () => {
    test("should destroy log routing resources", () => {
      // Should not throw
      expect(() => {
        destroyLogRouting();
      }).not.toThrow();
    });

    test("should handle multiple destroy calls", () => {
      // Should not throw
      expect(() => {
        destroyLogRouting();
        destroyLogRouting();
      }).not.toThrow();
    });
  });

  describe("Log Entry Enrichment", () => {
    test("should enrich log entries with request metadata", () => {
      const req = {
        headers: {
          "x-correlation-id": "corr-123",
          "user-agent": "test-agent",
        },
        userId: "user-456",
        id: "req-789",
        method: "GET",
        url: "/test",
      };

      const logEntry = createStructuredLogEntry({
        level: "info",
        message: "Test log",
      });

      routeLog(logEntry, req);

      expect(logEntry.correlationId).toBe("corr-123");
      expect(logEntry.userId).toBe("user-456");
      expect(logEntry.requestId).toBe("req-789");
    });

    test("should not overwrite existing enrichment data", () => {
      const req = {
        headers: {
          "x-correlation-id": "corr-new",
        },
        userId: "user-new",
      };

      const logEntry = createStructuredLogEntry({
        level: "info",
        message: "Test log",
        correlationId: "corr-existing",
        userId: "user-existing",
      });

      routeLog(logEntry, req);

      // Should preserve existing values
      expect(logEntry.correlationId).toBe("corr-existing");
      expect(logEntry.userId).toBe("user-existing");
    });
  });

  describe("Log Routing Error Handling", () => {
    test("should handle routing logs with invalid request object", () => {
      const logEntry = createStructuredLogEntry({
        level: "info",
        message: "Test log",
      });

      // Should not throw with null request
      expect(() => {
        routeLog(logEntry, null);
      }).not.toThrow();

      // Should not throw with undefined request
      expect(() => {
        routeLog(logEntry, undefined);
      }).not.toThrow();
    });

    test("should handle routing logs with missing headers", () => {
      const req = {
        // No headers property
      };

      const logEntry = createStructuredLogEntry({
        level: "info",
        message: "Test log",
      });

      // Should not throw
      expect(() => {
        routeLog(logEntry, req);
      }).not.toThrow();
    });

    test("should handle routing logs with empty metadata", () => {
      const logEntry = createStructuredLogEntry({
        level: "info",
        message: "Test log",
      });

      // Should not throw
      expect(() => {
        routeLog(logEntry);
      }).not.toThrow();
    });
  });

  describe("Log Routing Performance", () => {
    test("should route logs efficiently", () => {
      const startTime = Date.now();

      for (let i = 0; i < 100; i++) {
        const logEntry = createStructuredLogEntry({
          level: "info",
          message: `Test log ${i}`,
        });
        routeLog(logEntry);
      }

      const duration = Date.now() - startTime;

      // Should complete 100 log routings in less than 1 second
      expect(duration).toBeLessThan(1000);
    });

    test("should handle concurrent log routing", async () => {
      const promises = [];

      for (let i = 0; i < 50; i++) {
        promises.push(
          Promise.resolve().then(() => {
            const logEntry = createStructuredLogEntry({
              level: "info",
              message: `Concurrent log ${i}`,
            });
            routeLog(logEntry);
          }),
        );
      }

      // Should not throw
      await expect(Promise.all(promises)).resolves.toBeDefined();
    });
  });
});
