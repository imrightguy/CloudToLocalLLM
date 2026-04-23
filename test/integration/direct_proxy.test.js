/**
 * Integration Tests for Direct Proxy Routes
 *
 * Tests the direct proxy functionality for free tier users,
 * including security, error handling, and proper request forwarding.
 */

import {
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
  jest,
} from "@jest/globals";
import request from "supertest";
import express from "express";
import { createDirectProxyRoutes } from "../../services/api-backend/routes/direct-proxy-routes.js";

describe("Direct Proxy Integration Tests", () => {
  let app;
  let mockTunnelProxy;
  let mockAuth;

  beforeEach(() => {
    // Mock tunnel proxy
    mockTunnelProxy = {
      forwardRequest: jest.fn(),
      isUserConnected: jest.fn(),
    };
    mockTunnelProxy.isUserConnected.mockReturnValue(true);

    // Mock auth middleware
    mockAuth = (req, res, next) => {
      req.user = {
        sub: "jwt|test-user-123",
        "https://CloudToLocalLLM.com/user_metadata": { tier: "free" },
      };
      next();
    };

    // Create test app
    app = express();
    app.disable("x-powered-by");
    app.use(express.json({ limit: "20mb" }));
    app.use("/test", mockAuth);
    app.use("/test", createDirectProxyRoutes(mockTunnelProxy));
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe("Health Check Endpoint", () => {
    it("should return health status for authenticated free tier user", async () => {
      mockTunnelProxy.isUserConnected.mockReturnValue(true);

      const response = await request(app).get("/test/health").expect(200);

      expect(response.body).toMatchObject({
        status: "ok",
        service: "direct-proxy",
        userTier: "free",
        directTunnelEnabled: true,
        tunnelConnected: true,
      });

      expect(response.body.timestamp).toBeDefined();
      expect(mockTunnelProxy.isUserConnected).toHaveBeenCalledWith(
        "jwt|test-user-123",
      );
    });

    it("should handle tunnel proxy errors gracefully", async () => {
      mockTunnelProxy.isUserConnected.mockImplementation(() => {
        throw new Error("Connection check failed");
      });

      const response = await request(app).get("/test/health").expect(500);

      expect(response.body).toMatchObject({
        status: "error",
        service: "direct-proxy",
        error: "Health check failed",
      });
    });
  });

  describe("Ollama Proxy Endpoint", () => {
    beforeEach(() => {
      mockTunnelProxy.isUserConnected.mockReturnValue(true);
    });

    it("should forward GET requests to Ollama API", async () => {
      const mockResponse = {
        statusCode: 200,
        headers: { "content-type": "application/json" },
        body: { models: [] },
      };

      mockTunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      const response = await request(app)
        .get("/test/ollama/api/tags")
        .expect(200);

      expect(response.body).toEqual({ models: [] });
      expect(mockTunnelProxy.forwardRequest).toHaveBeenCalledWith(
        "jwt|test-user-123",
        expect.objectContaining({
          method: "GET",
          path: "/api/tags",
          timeout: expect.any(Number),
        }),
      );
    });

    it("should forward POST requests with body", async () => {
      const mockResponse = {
        statusCode: 200,
        headers: { "content-type": "application/json" },
        body: { success: true },
      };

      mockTunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      const requestBody = { model: "llama2", prompt: "Hello" };

      const response = await request(app)
        .post("/test/ollama/api/generate")
        .send(requestBody)
        .expect(200);

      expect(response.body).toEqual({ success: true });
      expect(mockTunnelProxy.forwardRequest).toHaveBeenCalledWith(
        "jwt|test-user-123",
        expect.objectContaining({
          method: "POST",
          path: "/api/generate",
          body: JSON.stringify(requestBody),
        }),
      );
    });

    it("should reject requests when desktop client is not connected", async () => {
      mockTunnelProxy.isUserConnected.mockReturnValue(false);

      const response = await request(app)
        .get("/test/ollama/api/tags")
        .expect(503);

      expect(response.body).toMatchObject({
        error: "Desktop client not connected",
        code: "DESKTOP_CLIENT_DISCONNECTED",
      });

      expect(mockTunnelProxy.forwardRequest).not.toHaveBeenCalled();
    });

    it("should handle tunnel proxy timeouts", async () => {
      mockTunnelProxy.forwardRequest.mockRejectedValue(
        new Error("Request timeout"),
      );

      const response = await request(app)
        .get("/test/ollama/api/tags")
        .expect(504);

      expect(response.body).toMatchObject({
        error: "Request timeout",
        code: "REQUEST_TIMEOUT",
      });
    });

    it("should handle connection refused errors", async () => {
      const error = new Error("Connection refused");
      error.code = "ECONNREFUSED";
      mockTunnelProxy.forwardRequest.mockRejectedValue(error);

      const response = await request(app)
        .get("/test/ollama/api/tags")
        .expect(502);

      expect(response.body).toMatchObject({
        error: "Local service unavailable",
        code: "LOCAL_SERVICE_UNAVAILABLE",
      });
    });

    it("should sanitize request headers", async () => {
      const mockResponse = {
        statusCode: 200,
        headers: {},
        body: "OK",
      };

      mockTunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      await request(app)
        .get("/test/ollama/api/tags")
        .set("Authorization", "Bearer token")
        .set("Cookie", "session=123")
        .set("Host", "malicious.com")
        .expect(200);

      const forwardedRequest = mockTunnelProxy.forwardRequest.mock.calls[0][1];

      // Security-sensitive headers should be removed
      expect(forwardedRequest.headers.authorization).toBeUndefined();
      expect(forwardedRequest.headers.cookie).toBeUndefined();
      expect(forwardedRequest.headers.host).toBeUndefined();
    });

    it("should prevent path traversal attacks", async () => {
      const response = await request(app)
        .get("/test/ollama/..%2F..%2F..%2Fetc/passwd")
        .expect(400);

      expect(response.body).toMatchObject({
        error: "Invalid path",
        code: "INVALID_PATH",
      });

      expect(mockTunnelProxy.forwardRequest).not.toHaveBeenCalled();
    });

    it("should handle large request bodies appropriately", async () => {
      // This would need to be configured based on MAX_REQUEST_SIZE
      const largeBody = "x".repeat(11 * 1024 * 1024); // 11MB

      const response = await request(app)
        .post("/test/ollama/api/generate")
        .send({ data: largeBody })
        .expect(413);

      expect(response.body).toMatchObject({
        error: "Request entity too large",
        code: "REQUEST_TOO_LARGE",
      });
    });
  });

  describe("Security Tests", () => {
    it("should reject non-free tier users", async () => {
      // Override auth middleware for premium user
      app.use("/premium-test", (req, res, next) => {
        req.user = {
          sub: "jwt|premium-user-123",
          "https://CloudToLocalLLM.com/user_metadata": { tier: "premium" },
        };
        next();
      });
      app.use("/premium-test", createDirectProxyRoutes(mockTunnelProxy));

      const response = await request(app)
        .get("/premium-test/ollama/api/tags")
        .expect(403);

      expect(response.body).toMatchObject({
        error: "Direct proxy access is only available for free tier users",
        code: "DIRECT_PROXY_FORBIDDEN",
      });

      expect(mockTunnelProxy.forwardRequest).not.toHaveBeenCalled();
    });

    it("should include request ID in all responses for tracing", async () => {
      mockTunnelProxy.isUserConnected.mockReturnValue(false);

      const response = await request(app)
        .get("/test/ollama/api/tags")
        .expect(503);

      expect(response.body.requestId).toBeDefined();
      expect(typeof response.body.requestId).toBe("string");
      expect(response.body.requestId).toMatch(/^dp-\d+-[a-z0-9]+$/);
    });

    it("should sanitize response headers", async () => {
      const mockResponse = {
        statusCode: 200,
        headers: {
          "content-type": "application/json",
          "set-cookie": "session=abc123",
          server: "nginx/1.0",
          "x-powered-by": "Express",
        },
        body: { data: "test" },
      };

      mockTunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      const response = await request(app)
        .get("/test/ollama/api/tags")
        .expect(200);

      // Safe headers should be preserved
      expect(response.headers["content-type"]).toBeDefined();

      // Security-sensitive headers should be removed
      expect(response.headers["set-cookie"]).toBeUndefined();
      expect(response.headers["server"]).toBeUndefined();
      expect(response.headers["x-powered-by"]).toBeUndefined();
    });
  });

  describe("Error Handling", () => {
    it("should handle invalid tunnel proxy responses", async () => {
      mockTunnelProxy.isUserConnected.mockReturnValue(true);
      mockTunnelProxy.forwardRequest.mockResolvedValue(null);

      const response = await request(app)
        .get("/test/ollama/api/tags")
        .expect(500);

      expect(response.body).toMatchObject({
        error: "Internal proxy error",
        code: "PROXY_ERROR",
      });
    });

    it("should handle malformed response headers gracefully", async () => {
      const mockResponse = {
        statusCode: 200,
        headers: {
          "invalid-header": null,
          "another-invalid": undefined,
          "valid-header": "value",
        },
        body: "OK",
      };

      mockTunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      const response = await request(app)
        .get("/test/ollama/api/tags")
        .expect(200);

      expect(response.text).toBe("OK");
      expect(response.headers["valid-header"]).toBe("value");
    });

    it("should handle invalid status codes", async () => {
      const mockResponse = {
        statusCode: "invalid",
        headers: {},
        body: "OK",
      };

      mockTunnelProxy.forwardRequest.mockResolvedValue(mockResponse);

      const response = await request(app)
        .get("/test/ollama/api/tags")
        .expect(200); // Should default to 200

      expect(response.text).toBe("OK");
    });
  });
});
