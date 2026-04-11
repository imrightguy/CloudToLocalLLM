import {} from "@jest/globals";

/**


 * @fileoverview Tests for Bridge Polling Routes
 * Tests the HTTP polling bridge functionality including the new provider-status endpoint
 */

import request from "supertest";
import express from "express";

// Auth bypassed via BYPASS_AUTH=true env var (ESM mocking limitations)
// Import routes directly
import bridgePollingRoutes from "../../services/api-backend/routes/bridge-polling-routes.js";

describe("Bridge Polling Routes", () => {
  let app;
  let bridgeId;
  const validToken = "valid-token";

  beforeEach(() => {
    app = express();
    app.use(express.json());
    app.use("/api/bridge", bridgePollingRoutes);
  });

  describe("POST /api/bridge/register", () => {
    it("should register a new bridge successfully", async () => {
      const registrationData = {
        clientId: "test-client-123",
        platform: "windows",
        version: "1.0.0",
        capabilities: ["llm-proxy"],
      };

      const response = await request(app)
        .post("/api/bridge/register")
        .set("Authorization", `Bearer ${validToken}`)
        .send(registrationData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.bridgeId).toBeDefined();
      expect(response.body.endpoints.providerStatus).toContain(
        "/provider-status",
      );

      // Store bridgeId for subsequent tests
      bridgeId = response.body.bridgeId;
    });

    it("should reject registration with missing required fields", async () => {
      const incompleteData = {
        clientId: "test-client-123",
        // Missing platform and version
      };

      await request(app)
        .post("/api/bridge/register")
        .set("Authorization", `Bearer ${validToken}`)
        .send(incompleteData)
        .expect(400);
    });
  });

  describe("POST /api/bridge/:bridgeId/provider-status", () => {
    beforeEach(async () => {
      // Register a bridge first
      const registrationData = {
        clientId: "test-client-123",
        platform: "windows",
        version: "1.0.0",
      };

      const response = await request(app)
        .post("/api/bridge/register")
        .set("Authorization", `Bearer ${validToken}`)
        .send(registrationData);

      bridgeId = response.body.bridgeId;
    });

    it("should update provider status successfully", async () => {
      const providerData = {
        providers: [
          {
            id: "ollama-local",
            name: "Ollama Local",
            type: "ollama",
            status: "available",
            models: ["llama2", "codellama"],
          },
          {
            id: "openai-compatible",
            name: "OpenAI Compatible",
            type: "openai",
            status: "available",
            models: ["gpt-3.5-turbo"],
          },
        ],
        timestamp: new Date().toISOString(),
      };

      const response = await request(app)
        .post(`/api/bridge/${bridgeId}/provider-status`)
        .set("Authorization", `Bearer ${validToken}`)
        .send(providerData)
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.message).toBe("Provider status updated");
      expect(response.body.timestamp).toBeDefined();
    });

    it("should reject provider status update for non-existent bridge", async () => {
      const providerData = {
        providers: [],
        timestamp: new Date().toISOString(),
      };

      await request(app)
        .post("/api/bridge/non-existent-bridge/provider-status")
        .set("Authorization", `Bearer ${validToken}`)
        .send(providerData)
        .expect(404);
    });

    it("should reject provider status update with invalid authentication", async () => {
      const providerData = {
        providers: [],
        timestamp: new Date().toISOString(),
      };

      await request(app)
        .post(`/api/bridge/${bridgeId}/provider-status`)
        .set("Authorization", "Bearer invalid-token")
        .send(providerData)
        .expect(401);
    });
  });

  describe("GET /api/bridge/:bridgeId/status", () => {
    beforeEach(async () => {
      // Register a bridge first
      const registrationData = {
        clientId: "test-client-123",
        platform: "windows",
        version: "1.0.0",
      };

      const response = await request(app)
        .post("/api/bridge/register")
        .set("Authorization", `Bearer ${validToken}`)
        .send(registrationData);

      bridgeId = response.body.bridgeId;
    });

    it("should return bridge status including provider information", async () => {
      // First update provider status
      const providerData = {
        providers: [
          {
            id: "test-provider",
            name: "Test Provider",
            type: "ollama",
            status: "available",
          },
        ],
        timestamp: new Date().toISOString(),
      };

      await request(app)
        .post(`/api/bridge/${bridgeId}/provider-status`)
        .set("Authorization", `Bearer ${validToken}`)
        .send(providerData);

      // Then check status
      const response = await request(app)
        .get(`/api/bridge/${bridgeId}/status`)
        .set("Authorization", `Bearer ${validToken}`)
        .expect(200);

      expect(response.body.bridgeId).toBe(bridgeId);
      expect(response.body.status).toBeDefined();
      expect(response.body.providers).toBeDefined();
      expect(response.body.providers).toHaveLength(1);
      expect(response.body.providers[0].id).toBe("test-provider");
      expect(response.body.lastProviderUpdate).toBeDefined();
    });

    it("should return empty providers array when no provider status has been reported", async () => {
      const response = await request(app)
        .get(`/api/bridge/${bridgeId}/status`)
        .set("Authorization", `Bearer ${validToken}`)
        .expect(200);

      expect(response.body.providers).toEqual([]);
      expect(response.body.lastProviderUpdate).toBeNull();
    });
  });

  describe("Rate Limiting", () => {
    beforeEach(async () => {
      // Register a bridge first
      const registrationData = {
        clientId: "test-client-123",
        platform: "windows",
        version: "1.0.0",
      };

      const response = await request(app)
        .post("/api/bridge/register")
        .set("Authorization", `Bearer ${validToken}`)
        .send(registrationData);

      bridgeId = response.body.bridgeId;
    });

    it("should apply rate limiting to provider-status endpoint", async () => {
      const providerData = {
        providers: [
          { id: "test", name: "Test", type: "test", status: "available" },
        ],
        timestamp: new Date().toISOString(),
      };

      // Make requests up to the limit (10 per minute)
      const requests = [];
      for (let i = 0; i < 10; i++) {
        requests.push(
          request(app)
            .post(`/api/bridge/${bridgeId}/provider-status`)
            .set("Authorization", `Bearer ${validToken}`)
            .send(providerData),
        );
      }

      const responses = await Promise.all(requests);

      // All requests within limit should succeed
      responses.forEach((response) => {
        expect(response.status).toBe(200);
      });

      // The 11th request should be rate limited
      const rateLimitedResponse = await request(app)
        .post(`/api/bridge/${bridgeId}/provider-status`)
        .set("Authorization", `Bearer ${validToken}`)
        .send(providerData);

      expect(rateLimitedResponse.status).toBe(429);
      expect(rateLimitedResponse.body.code).toBe("RATE_LIMIT_EXCEEDED");
    }, 10000); // Increase timeout for this test
  });
});
