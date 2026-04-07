/**
 * Sandbox Routes Integration Tests
 *
 * Tests for sandbox environment API endpoints
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import express from "express";
import request from "supertest";
import sandboxRoutes from "../../services/api-backend/routes/sandbox.js";
import { sandboxService } from "../../services/api-backend/services/sandbox-service.js";

describe("Sandbox Routes", () => {
  let app;
  let originalEnv;

  beforeEach(() => {
    // Save original environment
    originalEnv = process.env.SANDBOX_MODE;
    // Enable sandbox mode for tests
    process.env.SANDBOX_MODE = "true";

    app = express();
    app.use(express.json());

    // Mock sandbox detection middleware
    app.use((req, res, next) => {
      req.isSandbox = process.env.SANDBOX_MODE === "true";
      req.sandboxService = sandboxService;
      next();
    });

    app.use("/sandbox", sandboxRoutes);

    // Clear sandbox data before each test
    sandboxService.clearSandboxData();
  });

  afterEach(() => {
    // Restore original environment
    if (originalEnv !== undefined) {
      process.env.SANDBOX_MODE = originalEnv;
    } else {
      delete process.env.SANDBOX_MODE;
    }
  });

  afterEach(() => {
    sandboxService.clearSandboxData();
  });

  describe("GET /sandbox/config", () => {
    it("should return sandbox configuration", async () => {
      const response = await request(app).get("/sandbox/config");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body).toHaveProperty("config");
      expect(response.body.config).toHaveProperty("enabled");
      expect(response.body.config).toHaveProperty("mode", "testing");
    });

    it("should include rate limits in config", async () => {
      const response = await request(app).get("/sandbox/config");

      expect(response.body.config.rateLimits).toHaveProperty(
        "requestsPerMinute",
        10000,
      );
      expect(response.body.config.rateLimits).toHaveProperty("burstSize", 5000);
    });

    it("should include quotas in config", async () => {
      const response = await request(app).get("/sandbox/config");

      expect(response.body.config.quotas).toHaveProperty("maxTunnels", 100);
      expect(response.body.config.quotas).toHaveProperty("maxWebhooks", 100);
    });
  });

  describe("GET /sandbox/credentials", () => {
    it("should return test credentials", async () => {
      const response = await request(app).get("/sandbox/credentials");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body).toHaveProperty("credentials");
    });

    it("should include test users", async () => {
      const response = await request(app).get("/sandbox/credentials");

      expect(response.body.credentials).toHaveProperty("users");
      expect(response.body.credentials.users.length).toBeGreaterThan(0);
    });

    it("should include API keys", async () => {
      const response = await request(app).get("/sandbox/credentials");

      expect(response.body.credentials).toHaveProperty("apiKeys");
      expect(response.body.credentials.apiKeys.length).toBeGreaterThan(0);
    });
  });

  describe("POST /sandbox/users", () => {
    it("should create mock user", async () => {
      const response = await request(app)
        .post("/sandbox/users")
        .set("Content-Type", "application/json")
        .send({
          email: "test@example.com",
          firstName: "John",
          lastName: "Doe",
          tier: "free",
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body).toHaveProperty("user");
      expect(response.body.user.email).toBe("test@example.com");
      expect(response.body.user.tier).toBe("free");
    });

    it("should create user with default values", async () => {
      const response = await request(app)
        .post("/sandbox/users")
        .set("Content-Type", "application/json")
        .send({});

      expect(response.status).toBe(201);
      expect(response.body.user).toHaveProperty("id");
      expect(response.body.user).toHaveProperty("email");
      expect(response.body.user).toHaveProperty("tier", "free");
    });

    it("should store created user", async () => {
      const response = await request(app)
        .post("/sandbox/users")
        .set("Content-Type", "application/json")
        .send({
          email: "test@example.com",
        });

      const userId = response.body.user.id;
      const user = sandboxService.getMockUser(userId);

      expect(user).toBeDefined();
      expect(user.email).toBe("test@example.com");
    });
  });

  describe("GET /sandbox/users/:userId", () => {
    it("should retrieve mock user", async () => {
      const created = sandboxService.createMockUser({
        email: "test@example.com",
      });

      const response = await request(app).get(`/sandbox/users/${created.id}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body.user.id).toBe(created.id);
      expect(response.body.user.email).toBe("test@example.com");
    });

    it("should return 404 for non-existent user", async () => {
      const response = await request(app).get("/sandbox/users/non-existent");

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty("error");
    });
  });

  describe("POST /sandbox/tunnels", () => {
    it("should create mock tunnel", async () => {
      const response = await request(app)
        .post("/sandbox/tunnels")
        .set("Content-Type", "application/json")
        .send({
          userId: "test-user-1",
          name: "Test Tunnel",
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body).toHaveProperty("tunnel");
      expect(response.body.tunnel.name).toBe("Test Tunnel");
      expect(response.body.tunnel.status).toBe("connected");
    });

    it("should create tunnel with default values", async () => {
      const response = await request(app)
        .post("/sandbox/tunnels")
        .set("Content-Type", "application/json")
        .send({});

      expect(response.status).toBe(201);
      expect(response.body.tunnel).toHaveProperty("id");
      expect(response.body.tunnel).toHaveProperty("status", "connected");
      expect(response.body.tunnel).toHaveProperty("endpoints");
    });

    it("should store created tunnel", async () => {
      const response = await request(app)
        .post("/sandbox/tunnels")
        .set("Content-Type", "application/json")
        .send({
          name: "Test Tunnel",
        });

      const tunnelId = response.body.tunnel.id;
      const tunnel = sandboxService.getMockTunnel(tunnelId);

      expect(tunnel).toBeDefined();
      expect(tunnel.name).toBe("Test Tunnel");
    });
  });

  describe("GET /sandbox/tunnels/:tunnelId", () => {
    it("should retrieve mock tunnel", async () => {
      const created = sandboxService.createMockTunnel({ name: "Test Tunnel" });

      const response = await request(app).get(`/sandbox/tunnels/${created.id}`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body.tunnel.id).toBe(created.id);
      expect(response.body.tunnel.name).toBe("Test Tunnel");
    });

    it("should return 404 for non-existent tunnel", async () => {
      const response = await request(app).get("/sandbox/tunnels/non-existent");

      expect(response.status).toBe(404);
      expect(response.body).toHaveProperty("error");
    });
  });

  describe("PATCH /sandbox/tunnels/:tunnelId/status", () => {
    it("should update tunnel status", async () => {
      const tunnel = sandboxService.createMockTunnel({});

      const response = await request(app)
        .patch(`/sandbox/tunnels/${tunnel.id}/status`)
        .set("Content-Type", "application/json")
        .send({ status: "disconnected" });

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body.tunnel.status).toBe("disconnected");
    });

    it("should require status parameter", async () => {
      const tunnel = sandboxService.createMockTunnel({});

      const response = await request(app)
        .patch(`/sandbox/tunnels/${tunnel.id}/status`)
        .set("Content-Type", "application/json")
        .send({});

      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty("error");
    });
  });

  describe("POST /sandbox/tunnels/:tunnelId/metrics", () => {
    it("should record tunnel metrics", async () => {
      const tunnel = sandboxService.createMockTunnel({});

      const response = await request(app)
        .post(`/sandbox/tunnels/${tunnel.id}/metrics`)
        .set("Content-Type", "application/json")
        .send({
          requestCount: 100,
          successCount: 98,
          errorCount: 2,
          latency: 50,
        });

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body.tunnel.metrics.requestCount).toBe(100);
      expect(response.body.tunnel.metrics.successCount).toBe(98);
    });
  });

  describe("POST /sandbox/webhooks", () => {
    it("should create mock webhook", async () => {
      const response = await request(app)
        .post("/sandbox/webhooks")
        .set("Content-Type", "application/json")
        .send({
          userId: "test-user-1",
          url: "https://example.com/webhook",
          events: ["tunnel.created"],
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body).toHaveProperty("webhook");
      expect(response.body.webhook.url).toBe("https://example.com/webhook");
    });

    it("should create webhook with default values", async () => {
      const response = await request(app)
        .post("/sandbox/webhooks")
        .set("Content-Type", "application/json")
        .send({});

      expect(response.status).toBe(201);
      expect(response.body.webhook).toHaveProperty("id");
      expect(response.body.webhook).toHaveProperty("active", true);
    });
  });

  describe("GET /sandbox/requests", () => {
    it("should return request log", async () => {
      sandboxService.logRequest({
        method: "GET",
        path: "/api/test",
        userId: "test-user",
        statusCode: 200,
        responseTime: 30,
      });

      const response = await request(app).get("/sandbox/requests");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body).toHaveProperty("requests");
      expect(response.body).toHaveProperty("count", 1);
    });

    it("should filter requests by user", async () => {
      sandboxService.logRequest({
        method: "GET",
        path: "/api/test",
        userId: "user-1",
        statusCode: 200,
        responseTime: 30,
      });

      sandboxService.logRequest({
        method: "GET",
        path: "/api/test",
        userId: "user-2",
        statusCode: 200,
        responseTime: 30,
      });

      const response = await request(app).get(
        "/sandbox/requests?userId=user-1",
      );

      expect(response.body.count).toBe(1);
      expect(response.body.requests[0].userId).toBe("user-1");
    });

    it("should filter requests by method", async () => {
      sandboxService.logRequest({
        method: "POST",
        path: "/api/test",
        userId: "test-user",
        statusCode: 201,
        responseTime: 30,
      });

      sandboxService.logRequest({
        method: "GET",
        path: "/api/test",
        userId: "test-user",
        statusCode: 200,
        responseTime: 30,
      });

      const response = await request(app).get("/sandbox/requests?method=POST");

      expect(response.body.count).toBe(1);
      expect(response.body.requests[0].method).toBe("POST");
    });

    it("should limit results", async () => {
      for (let i = 0; i < 10; i++) {
        sandboxService.logRequest({
          method: "GET",
          path: "/api/test",
          userId: "test-user",
          statusCode: 200,
          responseTime: 30,
        });
      }

      const response = await request(app).get("/sandbox/requests?limit=5");

      expect(response.body.count).toBe(5);
    });
  });

  describe("GET /sandbox/stats", () => {
    it("should return sandbox statistics", async () => {
      sandboxService.createMockUser({});
      sandboxService.createMockTunnel({});

      const response = await request(app).get("/sandbox/stats");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("success", true);
      expect(response.body).toHaveProperty("stats");
      expect(response.body.stats.users).toBe(1);
      expect(response.body.stats.tunnels).toBe(1);
    });
  });

  describe("DELETE /sandbox/clear", () => {
    it("should clear sandbox data", async () => {
      sandboxService.createMockUser({});
      sandboxService.createMockTunnel({});

      const response = await request(app).delete("/sandbox/clear");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("success", true);

      const stats = sandboxService.getSandboxStats();

      expect(stats.users).toBe(0);
      expect(stats.tunnels).toBe(0);
    });
  });

  describe("Sandbox Disabled", () => {
    it("should return 403 when sandbox is disabled", async () => {
      // Create app without sandbox detection middleware
      const appNoSandbox = express();
      appNoSandbox.use(express.json());

      appNoSandbox.use((req, res, next) => {
        req.isSandbox = false;
        req.sandboxService = sandboxService;
        next();
      });

      appNoSandbox.use("/sandbox", sandboxRoutes);

      const response = await request(appNoSandbox).get("/sandbox/config");

      expect(response.status).toBe(403);
      expect(response.body).toHaveProperty("error");
      expect(response.body.error.code).toBe("SANDBOX_DISABLED");
    });
  });
});
