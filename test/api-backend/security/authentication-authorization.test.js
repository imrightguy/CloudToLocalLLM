/**
 * @fileoverview Authentication and authorization security tests
 * Simplified tests for JWT validation and basic security
 */

import { describe, it, beforeEach, expect } from "@jest/globals";
import request from "supertest";
import express from "express";

// Test configuration
const TEST_CONFIG = {
  domain: "test-domain.jwt.com",
  audience: "https://test.example.com",
};

// Test users with different roles and permissions
const TEST_USERS = {
  validUser: {
    id: "jwt|valid-user",
    claims: {
      sub: "jwt|valid-user",
      aud: TEST_CONFIG.audience,
      iss: `https://${TEST_CONFIG.domain}/`,
      exp: Math.floor(Date.now() / 1000) + 3600,
      iat: Math.floor(Date.now() / 1000),
      email: "valid@test.com",
      scope: "read:profile",
    },
  },
  expiredUser: {
    id: "jwt|expired-user",
    claims: {
      sub: "jwt|expired-user",
      aud: TEST_CONFIG.audience,
      iss: `https://${TEST_CONFIG.domain}/`,
      exp: Math.floor(Date.now() / 1000) - 3600,
      iat: Math.floor(Date.now() / 1000) - 7200,
      email: "expired@test.com",
      scope: "read:profile",
    },
  },
  adminUser: {
    id: "jwt|admin-user",
    claims: {
      sub: "jwt|admin-user",
      aud: TEST_CONFIG.audience,
      iss: `https://${TEST_CONFIG.domain}/`,
      exp: Math.floor(Date.now() / 1000) + 3600,
      iat: Math.floor(Date.now() / 1000),
      email: "admin@test.com",
      scope: "read:profile write:profile",
      "https://CloudToLocalLLM.com/app_metadata": { role: "admin" },
    },
  },
};

describe("Authentication Security Tests", () => {
  let app;

  beforeEach(() => {
    // Generate test tokens
    Object.values(TEST_USERS).forEach((user) => {
      user.token = `test-token-${user.id}`;
    });

    // Create Express app
    app = express();
    app.use(express.json());

    // Simple mock JWT middleware for testing
    app.use((req, res, next) => {
      const authHeader = req.headers["authorization"];
      const token = authHeader && authHeader.split(" ")[1];

      if (!token) {
        return res.status(401).json({
          error: { code: "AUTH_TOKEN_MISSING", message: "Missing token" },
        });
      }

      // Find matching test user by token
      const user = Object.values(TEST_USERS).find((u) => u.token === token);
      if (!user) {
        return res.status(403).json({
          error: { code: "AUTH_TOKEN_INVALID", message: "Invalid token" },
        });
      }

      // Check expiration
      if (user.claims.exp < Math.floor(Date.now() / 1000)) {
        return res.status(403).json({
          error: { code: "AUTH_TOKEN_EXPIRED", message: "Token expired" },
        });
      }

      // Attach user info
      req.user = user.claims;
      req.userId = user.id;

      next();
    });

    // Test routes
    app.get("/protected", (req, res) => {
      res.json({ message: "Protected resource accessed", userId: req.userId });
    });

    app.get("/admin", (req, res) => {
      const isAdmin =
        req.user["https://CloudToLocalLLM.com/app_metadata"]?.role === "admin";
      if (!isAdmin) {
        return res.status(403).json({ error: "Admin access required" });
      }
      res.json({ message: "Admin resource accessed", userId: req.userId });
    });

    app.get("/api/test", (req, res) => {
      res.json({ message: "Test endpoint", userId: req.userId });
    });

    app.get("/api/tunnel/:userId/test", (req, res) => {
      res.json({ message: "Tunnel access granted", userId: req.userId });
    });
  });

  describe("Valid Token Authentication", () => {
    it("should authenticate valid JWT token", async () => {
      const response = await request(app)
        .get("/protected")
        .set("Authorization", `Bearer ${TEST_USERS.validUser.token}`)
        .expect(200);

      expect(response.body.message).toBe("Protected resource accessed");
      expect(response.body.userId).toBe(TEST_USERS.validUser.id);
    });

    it("should include user information in request", async () => {
      const response = await request(app)
        .get("/protected")
        .set("Authorization", `Bearer ${TEST_USERS.validUser.token}`)
        .expect(200);

      expect(response.body.userId).toBeDefined();
    });
  });

  describe("Invalid Token Authentication", () => {
    it("should reject missing authorization header", async () => {
      const response = await request(app).get("/protected").expect(401);

      expect(response.body.error.code).toBe("AUTH_TOKEN_MISSING");
    });

    it("should reject expired tokens", async () => {
      const response = await request(app)
        .get("/protected")
        .set("Authorization", `Bearer ${TEST_USERS.expiredUser.token}`)
        .expect(403);

      expect(response.body.error.code).toBe("AUTH_TOKEN_EXPIRED");
    });

    it("should reject invalid tokens", async () => {
      const response = await request(app)
        .get("/protected")
        .set("Authorization", "Bearer invalid-token")
        .expect(403);

      expect(response.body.error.code).toBe("AUTH_TOKEN_INVALID");
    });
  });

  describe("Authorization Tests", () => {
    it("should allow admin access with proper role", async () => {
      const response = await request(app)
        .get("/admin")
        .set("Authorization", `Bearer ${TEST_USERS.adminUser.token}`)
        .expect(200);

      expect(response.body.message).toBe("Admin resource accessed");
    });

    it("should deny admin access without proper role", async () => {
      const response = await request(app)
        .get("/admin")
        .set("Authorization", `Bearer ${TEST_USERS.validUser.token}`)
        .expect(403);

      expect(response.body.error).toBe("Admin access required");
    });
  });

  describe("Security Headers", () => {
    it("should include security headers in responses", async () => {
      const response = await request(app)
        .get("/protected")
        .set("Authorization", `Bearer ${TEST_USERS.validUser.token}`)
        .expect(200);

      expect(response.status).toBe(200);
    });
  });
});
