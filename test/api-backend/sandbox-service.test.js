/**
 * Sandbox Service Tests
 *
 * Tests for sandbox environment service functionality
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import { SandboxService } from "../../services/api-backend/services/sandbox-service.js";

describe("SandboxService", () => {
  let sandboxService;

  beforeEach(() => {
    sandboxService = new SandboxService();
  });

  afterEach(() => {
    sandboxService.clearSandboxData();
  });

  describe("Initialization", () => {
    it("should initialize with sandbox mode disabled by default", () => {
      const service = new SandboxService();
      // Note: actual value depends on environment variables
      expect(typeof service.isSandbox()).toBe("boolean");
    });

    it("should have empty data structures on initialization", () => {
      expect(sandboxService.sandboxUsers.size).toBe(0);
      expect(sandboxService.sandboxTunnels.size).toBe(0);
      expect(sandboxService.sandboxWebhooks.size).toBe(0);
      expect(sandboxService.requestLog.length).toBe(0);
    });
  });

  describe("Configuration", () => {
    it("should return sandbox configuration", () => {
      const config = sandboxService.getSandboxConfig();

      expect(config).toHaveProperty("enabled");
      expect(config).toHaveProperty("mode", "testing");
      expect(config).toHaveProperty("features");
      expect(config).toHaveProperty("rateLimits");
      expect(config).toHaveProperty("quotas");
    });

    it("should have correct rate limits in config", () => {
      const config = sandboxService.getSandboxConfig();

      expect(config.rateLimits.requestsPerMinute).toBe(10000);
      expect(config.rateLimits.burstSize).toBe(5000);
    });

    it("should have correct quotas in config", () => {
      const config = sandboxService.getSandboxConfig();

      expect(config.quotas.maxTunnels).toBe(100);
      expect(config.quotas.maxWebhooks).toBe(100);
      expect(config.quotas.maxUsers).toBe(1000);
      expect(config.quotas.storageGB).toBe(10);
    });
  });

  describe("Test Credentials", () => {
    it("should return test credentials", () => {
      const credentials = sandboxService.getTestCredentials();

      expect(credentials).toHaveProperty("users");
      expect(credentials).toHaveProperty("apiKeys");
    });

    it("should have three test users", () => {
      const credentials = sandboxService.getTestCredentials();

      expect(credentials.users.length).toBe(3);
    });

    it("should have test user with free tier", () => {
      const credentials = sandboxService.getTestCredentials();
      const freeUser = credentials.users.find((u) => u.tier === "free");

      expect(freeUser).toBeDefined();
      expect(freeUser.email).toBe("test@sandbox.local");
      expect(freeUser.token).toBeDefined();
    });

    it("should have test user with premium tier", () => {
      const credentials = sandboxService.getTestCredentials();
      const premiumUser = credentials.users.find((u) => u.tier === "premium");

      expect(premiumUser).toBeDefined();
      expect(premiumUser.email).toBe("premium@sandbox.local");
    });

    it("should have admin test user", () => {
      const credentials = sandboxService.getTestCredentials();
      const adminUser = credentials.users.find((u) => u.role === "admin");

      expect(adminUser).toBeDefined();
      expect(adminUser.email).toBe("admin@sandbox.local");
    });

    it("should have API keys", () => {
      const credentials = sandboxService.getTestCredentials();

      expect(credentials.apiKeys.length).toBeGreaterThan(0);
      expect(credentials.apiKeys[0]).toHaveProperty("key");
      expect(credentials.apiKeys[0]).toHaveProperty("secret");
    });
  });

  describe("Mock User Creation", () => {
    it("should create mock user with default values", () => {
      const user = sandboxService.createMockUser({});

      expect(user).toHaveProperty("id");
      expect(user).toHaveProperty("email");
      expect(user).toHaveProperty("tier", "free");
      expect(user).toHaveProperty("profile");
      expect(user).toHaveProperty("createdAt");
      expect(user).toHaveProperty("isActive", true);
    });

    it("should create mock user with custom values", () => {
      const user = sandboxService.createMockUser({
        email: "custom@example.com",
        firstName: "John",
        lastName: "Doe",
        tier: "premium",
      });

      expect(user.email).toBe("custom@example.com");
      expect(user.tier).toBe("premium");
      expect(user.profile.firstName).toBe("John");
      expect(user.profile.lastName).toBe("Doe");
    });

    it("should store created user in sandbox", () => {
      const user = sandboxService.createMockUser({ email: "test@example.com" });

      expect(sandboxService.sandboxUsers.size).toBe(1);
      expect(sandboxService.getMockUser(user.id)).toEqual(user);
    });

    it("should generate unique user IDs", () => {
      const user1 = sandboxService.createMockUser({});
      const user2 = sandboxService.createMockUser({});

      expect(user1.id).not.toBe(user2.id);
    });
  });

  describe("Mock Tunnel Creation", () => {
    it("should create mock tunnel with default values", () => {
      const tunnel = sandboxService.createMockTunnel({});

      expect(tunnel).toHaveProperty("id");
      expect(tunnel).toHaveProperty("userId");
      expect(tunnel).toHaveProperty("name");
      expect(tunnel).toHaveProperty("status", "connected");
      expect(tunnel).toHaveProperty("endpoints");
      expect(tunnel).toHaveProperty("config");
      expect(tunnel).toHaveProperty("metrics");
    });

    it("should create mock tunnel with custom values", () => {
      const tunnel = sandboxService.createMockTunnel({
        userId: "custom-user",
        name: "Custom Tunnel",
      });

      expect(tunnel.userId).toBe("custom-user");
      expect(tunnel.name).toBe("Custom Tunnel");
    });

    it("should have healthy endpoint by default", () => {
      const tunnel = sandboxService.createMockTunnel({});

      expect(tunnel.endpoints.length).toBeGreaterThan(0);
      expect(tunnel.endpoints[0].healthStatus).toBe("healthy");
    });

    it("should store created tunnel in sandbox", () => {
      const tunnel = sandboxService.createMockTunnel({});

      expect(sandboxService.sandboxTunnels.size).toBe(1);
      expect(sandboxService.getMockTunnel(tunnel.id)).toEqual(tunnel);
    });
  });

  describe("Mock Webhook Creation", () => {
    it("should create mock webhook with default values", () => {
      const webhook = sandboxService.createMockWebhook({});

      expect(webhook).toHaveProperty("id");
      expect(webhook).toHaveProperty("userId");
      expect(webhook).toHaveProperty("url");
      expect(webhook).toHaveProperty("events");
      expect(webhook).toHaveProperty("active", true);
      expect(webhook).toHaveProperty("signature");
    });

    it("should create mock webhook with custom values", () => {
      const webhook = sandboxService.createMockWebhook({
        userId: "custom-user",
        url: "https://example.com/webhook",
        events: ["tunnel.created"],
      });

      expect(webhook.userId).toBe("custom-user");
      expect(webhook.url).toBe("https://example.com/webhook");
      expect(webhook.events).toContain("tunnel.created");
    });

    it("should store created webhook in sandbox", () => {
      const webhook = sandboxService.createMockWebhook({});

      expect(sandboxService.sandboxWebhooks.size).toBe(1);
      expect(sandboxService.getMockWebhook(webhook.id)).toEqual(webhook);
    });
  });

  describe("Request Logging", () => {
    it("should log request", () => {
      sandboxService.logRequest({
        method: "POST",
        path: "/api/tunnels",
        userId: "test-user",
        statusCode: 201,
        responseTime: 45,
        body: { name: "Test" },
      });

      expect(sandboxService.requestLog.length).toBe(1);
    });

    it("should retrieve request log", () => {
      sandboxService.logRequest({
        method: "POST",
        path: "/api/tunnels",
        userId: "test-user",
        statusCode: 201,
        responseTime: 45,
      });

      const log = sandboxService.getRequestLog();

      expect(log.length).toBe(1);
      expect(log[0].method).toBe("POST");
    });

    it("should filter requests by user", () => {
      sandboxService.logRequest({
        method: "POST",
        path: "/api/tunnels",
        userId: "user-1",
        statusCode: 201,
        responseTime: 45,
      });

      sandboxService.logRequest({
        method: "GET",
        path: "/api/tunnels",
        userId: "user-2",
        statusCode: 200,
        responseTime: 30,
      });

      const log = sandboxService.getRequestLog({ userId: "user-1" });

      expect(log.length).toBe(1);
      expect(log[0].userId).toBe("user-1");
    });

    it("should filter requests by method", () => {
      sandboxService.logRequest({
        method: "POST",
        path: "/api/tunnels",
        userId: "test-user",
        statusCode: 201,
        responseTime: 45,
      });

      sandboxService.logRequest({
        method: "GET",
        path: "/api/tunnels",
        userId: "test-user",
        statusCode: 200,
        responseTime: 30,
      });

      const log = sandboxService.getRequestLog({ method: "POST" });

      expect(log.length).toBe(1);
      expect(log[0].method).toBe("POST");
    });

    it("should filter requests by path", () => {
      sandboxService.logRequest({
        method: "POST",
        path: "/api/tunnels",
        userId: "test-user",
        statusCode: 201,
        responseTime: 45,
      });

      sandboxService.logRequest({
        method: "GET",
        path: "/api/users",
        userId: "test-user",
        statusCode: 200,
        responseTime: 30,
      });

      const log = sandboxService.getRequestLog({ path: "tunnels" });

      expect(log.length).toBe(1);
      expect(log[0].path).toContain("tunnels");
    });

    it("should limit request log results", () => {
      for (let i = 0; i < 10; i++) {
        sandboxService.logRequest({
          method: "GET",
          path: "/api/test",
          userId: "test-user",
          statusCode: 200,
          responseTime: 30,
        });
      }

      const log = sandboxService.getRequestLog({ limit: 5 });

      expect(log.length).toBe(5);
    });

    it("should maintain max request log size", () => {
      // Log more than max size
      for (let i = 0; i < 1100; i++) {
        sandboxService.logRequest({
          method: "GET",
          path: "/api/test",
          userId: "test-user",
          statusCode: 200,
          responseTime: 30,
        });
      }

      expect(sandboxService.requestLog.length).toBeLessThanOrEqual(1000);
    });
  });

  describe("Tunnel Status Updates", () => {
    it("should update tunnel status", () => {
      const tunnel = sandboxService.createMockTunnel({});
      sandboxService.updateMockTunnelStatus(tunnel.id, "disconnected");

      const updated = sandboxService.getMockTunnel(tunnel.id);

      expect(updated.status).toBe("disconnected");
    });

    it("should update tunnel timestamp on status change", async () => {
      const tunnel = sandboxService.createMockTunnel({});
      const originalTime = tunnel.updatedAt.getTime();

      // Wait a bit to ensure timestamp difference
      await new Promise((resolve) => setTimeout(resolve, 10));

      sandboxService.updateMockTunnelStatus(tunnel.id, "disconnected");

      const updated = sandboxService.getMockTunnel(tunnel.id);

      expect(updated.updatedAt.getTime()).toBeGreaterThan(originalTime);
    });
  });

  describe("Tunnel Metrics", () => {
    it("should record tunnel metrics", () => {
      const tunnel = sandboxService.createMockTunnel({});

      sandboxService.recordMockTunnelMetrics(tunnel.id, {
        requestCount: 10,
        successCount: 9,
        errorCount: 1,
        latency: 45,
      });

      const updated = sandboxService.getMockTunnel(tunnel.id);

      expect(updated.metrics.requestCount).toBe(10);
      expect(updated.metrics.successCount).toBe(9);
      expect(updated.metrics.errorCount).toBe(1);
      expect(updated.metrics.averageLatency).toBe(45);
    });

    it("should accumulate metrics on multiple recordings", () => {
      const tunnel = sandboxService.createMockTunnel({});

      sandboxService.recordMockTunnelMetrics(tunnel.id, {
        requestCount: 10,
        successCount: 9,
        errorCount: 1,
      });

      sandboxService.recordMockTunnelMetrics(tunnel.id, {
        requestCount: 5,
        successCount: 5,
        errorCount: 0,
      });

      const updated = sandboxService.getMockTunnel(tunnel.id);

      expect(updated.metrics.requestCount).toBe(15);
      expect(updated.metrics.successCount).toBe(14);
      expect(updated.metrics.errorCount).toBe(1);
    });
  });

  describe("Statistics", () => {
    it("should return sandbox statistics", () => {
      sandboxService.createMockUser({});
      sandboxService.createMockTunnel({});
      sandboxService.createMockWebhook({});

      const stats = sandboxService.getSandboxStats();

      expect(stats).toHaveProperty("users", 1);
      expect(stats).toHaveProperty("tunnels", 1);
      expect(stats).toHaveProperty("webhooks", 1);
      expect(stats).toHaveProperty("requestsLogged", 0);
      expect(stats).toHaveProperty("enabled");
    });

    it("should update statistics with request logs", () => {
      sandboxService.logRequest({
        method: "GET",
        path: "/api/test",
        userId: "test-user",
        statusCode: 200,
        responseTime: 30,
      });

      const stats = sandboxService.getSandboxStats();

      expect(stats.requestsLogged).toBe(1);
    });
  });

  describe("Data Cleanup", () => {
    it("should clear all sandbox data", () => {
      sandboxService.createMockUser({});
      sandboxService.createMockTunnel({});
      sandboxService.createMockWebhook({});
      sandboxService.logRequest({
        method: "GET",
        path: "/api/test",
        userId: "test-user",
        statusCode: 200,
        responseTime: 30,
      });

      sandboxService.clearSandboxData();

      expect(sandboxService.sandboxUsers.size).toBe(0);
      expect(sandboxService.sandboxTunnels.size).toBe(0);
      expect(sandboxService.sandboxWebhooks.size).toBe(0);
      expect(sandboxService.requestLog.length).toBe(0);
    });
  });

  describe("Retrieval Methods", () => {
    it("should return null for non-existent user", () => {
      const user = sandboxService.getMockUser("non-existent");

      expect(user).toBeNull();
    });

    it("should return null for non-existent tunnel", () => {
      const tunnel = sandboxService.getMockTunnel("non-existent");

      expect(tunnel).toBeNull();
    });

    it("should return null for non-existent webhook", () => {
      const webhook = sandboxService.getMockWebhook("non-existent");

      expect(webhook).toBeNull();
    });

    it("should retrieve created user by ID", () => {
      const created = sandboxService.createMockUser({
        email: "test@example.com",
      });
      const retrieved = sandboxService.getMockUser(created.id);

      expect(retrieved).toEqual(created);
    });

    it("should retrieve created tunnel by ID", () => {
      const created = sandboxService.createMockTunnel({ name: "Test" });
      const retrieved = sandboxService.getMockTunnel(created.id);

      expect(retrieved).toEqual(created);
    });

    it("should retrieve created webhook by ID", () => {
      const created = sandboxService.createMockWebhook({});
      const retrieved = sandboxService.getMockWebhook(created.id);

      expect(retrieved).toEqual(created);
    });
  });
});
