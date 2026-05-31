import { describe, it, beforeAll, afterAll, expect, jest } from "@jest/globals";

// Mock express-oauth2-jwt-bearer and jwks-rsa to prevent ES module loading issues in Jest
jest.mock("express-oauth2-jwt-bearer", () => {
  return {
    auth: jest.fn().mockImplementation(() => {
      return (req, res, next) => next(new Error("Mocked Auth0 failure"));
    }),
  };
});
jest.mock("jwks-rsa", () => {
  const mockClient = jest.fn(() => ({
    getSigningKey: jest.fn(),
  }));
  mockClient.expressJwtSecret = jest.fn();
  return mockClient;
});

import express from "express";
import request from "supertest";

let checkJwt;
let optionalAuth;

// Mock AuthService to prevent real database and JWKS calls
jest.mock("../../../services/api-backend/auth/auth-service.js", () => {
  return {
    AuthService: jest.fn().mockImplementation(() => {
      return {
        initialize: jest.fn().mockResolvedValue(true),
        syncSession: jest.fn().mockResolvedValue({ success: true }),
        validateToken: jest.fn().mockResolvedValue({ valid: true }),
      };
    }),
  };
});

describe("Developer Mock Bypass Authentication", () => {
  let app;
  let originalNodeEnv;

  beforeAll(async () => {
    originalNodeEnv = process.env.NODE_ENV;
    // Set NODE_ENV to development so the bypass code paths are active and testable
    process.env.NODE_ENV = "development";

    const authModule = await import("../../../services/api-backend/middleware/auth.js");
    checkJwt = authModule.checkJwt;
    optionalAuth = authModule.optionalAuth;

    app = express();
    app.use(express.json());

    // Protected endpoint
    app.get("/api/test-protected", checkJwt, (req, res) => {
      res.json({
        message: "success",
        user: req.user,
        userId: req.userId,
        auth: req.auth,
      });
    });

    // Optional endpoint
    app.get("/api/test-optional", optionalAuth, (req, res) => {
      res.json({
        message: "success",
        user: req.user,
        userId: req.userId,
        auth: req.auth,
      });
    });
  });

  afterAll(() => {
    process.env.NODE_ENV = originalNodeEnv;
  });

  it("should successfully bypass Auth0 verification for mock_dev_access_token", async () => {
    const response = await request(app)
      .get("/api/test-protected")
      .set("Authorization", "Bearer mock_dev_access_token")
      .expect(200);

    expect(response.body.message).toBe("success");
    expect(response.body.auth).toBeDefined();
    expect(response.body.auth.token).toBe("mock_dev_access_token");
    expect(response.body.auth.payload.email).toBe("dev@cloudtolocalllm.online");
    expect(response.body.auth.payload.name).toBe("Christopher (Dev)");
    expect(response.body.auth.payload.nickname).toBe("rightguy");
  });

  it("should successfully populate auth credentials under optionalAuth for mock_dev_access_token", async () => {
    const response = await request(app)
      .get("/api/test-optional")
      .set("Authorization", "Bearer mock_dev_access_token")
      .expect(200);

    expect(response.body.message).toBe("success");
    expect(response.body.auth).toBeDefined();
    expect(response.body.auth.payload.email).toBe("dev@cloudtolocalllm.online");
  });

  it("should reject unrecognized tokens (delegating to express-jwt/express-oauth2-jwt-bearer)", async () => {
    const response = await request(app)
      .get("/api/test-protected")
      .set("Authorization", "Bearer invalid_or_unsupported_token");

    // Should fail with an authentication error (non-200 status code)
    expect(response.status).not.toBe(200);
  });
});
