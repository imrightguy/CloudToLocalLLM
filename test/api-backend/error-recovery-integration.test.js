/**


 * Error Recovery Endpoints Integration Tests
 * 
 * Tests for error recovery API endpoints.
 * Validates that recovery endpoints work correctly with authentication and authorization.
 * 
 * Requirement 7.7: THE API SHALL provide error recovery endpoints for manual intervention
 */

import {
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
  jest,
} from "@jest/globals";

// Set environment variables BEFORE any other imports
process.env.AUTH0_DOMAIN = "test.jwt.com";
process.env.AUTH0_AUDIENCE = "test-audience";
process.env.NODE_ENV = "test";

// Mock express-oauth2-jwt-bearer BEFORE imports
jest.mock("express-oauth2-jwt-bearer", () => ({
  auth: jest.fn(() => (req, res, next) => next()),
}));

// Mock AuthService to avoid database calls in syncSession
jest.mock("../../services/api-backend/auth/auth-service.js", () => {
  return {
    AuthService: jest.fn().mockImplementation(() => ({
      initialize: jest.fn().mockResolvedValue(true),
      isTokenActive: jest.fn().mockResolvedValue(true),
      syncSession: jest
        .fn()
        .mockResolvedValue({ id: "mock-session", is_active: true }),
    })),
  };
});

import express from "express";
import request from "supertest";
import jwt from "jsonwebtoken";

// Use dynamic imports
const { default: errorRecoveryRoutes } =
  await import("../../services/api-backend/routes/error-recovery.js");
const errorRecoveryServiceModule =
  await import("../../services/api-backend/services/error-recovery-service.js");
const { errorRecoveryService } = errorRecoveryServiceModule;

// Mock authentication middleware
const mockAuthMiddleware = (req, res, next) => {
  const token = req.headers.authorization?.split(" ")[1];
  if (!token) {
    return res.status(401).json({ error: "Unauthorized" });
  }

  try {
    const decoded = jwt.decode(token);
    req.auth = { payload: decoded };
    req.user = decoded;
    req.userId = decoded.sub;

    // Set user roles for RBAC middleware compatibility
    if (decoded.role === "admin") {
      req.userRoles = ["super_admin"];
    } else {
      req.userRoles = ["user"];
    }

    next();
  } catch (error) {
    res.status(401).json({ error: "Invalid token" });
  }
};

// Mock RBAC middleware factory
const mockRBACMiddlewareFactory = () => {
  return (req, res, next) => {
    // Check for admin role in several places to be compatible with both mock and real RBAC
    const roles =
      req.auth?.payload?.["https://cloudtolocalllm.online/roles"] || [];
    const role = req.auth?.payload?.role;

    if (
      role === "admin" ||
      roles.includes("super_admin") ||
      roles.includes("admin")
    ) {
      return next();
    }
    return res.status(403).json({ error: "Forbidden" });
  };
};

// Create test app
const createTestApp = () => {
  const app = express();
  app.use(express.json());

  // Apply mock middleware
  app.use(mockAuthMiddleware);
  app.use(mockRBACMiddlewareFactory());

  app.use("/error-recovery", errorRecoveryRoutes);

  return app;
};

// Helper to create admin token
const createAdminToken = () => {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      sub: "admin-user",
      role: "admin",
      "https://cloudtolocalllm.online/roles": ["super_admin"],
      iat: now,
      exp: now + 3600,
      aud: "test-audience",
      iss: "https://test.jwt.com/",
    },
    "test-secret",
  );
};

// Helper to create non-admin token
const createUserToken = () => {
  const now = Math.floor(Date.now() / 1000);
  return jwt.sign(
    {
      sub: "regular-user",
      role: "user",
      "https://cloudtolocalllm.online/roles": ["user"],
      iat: now,
      exp: now + 3600,
      aud: "test-audience",
      iss: "https://test.jwt.com/",
    },
    "test-secret",
  );
};

describe("Error Recovery Endpoints", () => {
  let app;
  const adminToken = createAdminToken();
  const userToken = createUserToken();

  beforeEach(() => {
    app = createTestApp();
    errorRecoveryService.clearHistory();
    errorRecoveryService.resetMetrics();
  });

  afterEach(() => {
    errorRecoveryService.clearHistory();
    errorRecoveryService.resetMetrics();
  });

  describe("GET /error-recovery/status", () => {
    it("should return recovery statuses for all services", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      const response = await request(app)
        .get("/error-recovery/status")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.status).toBe("success");
      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.data.length).toBeGreaterThan(0);
    });

    it("should require admin role", async () => {
      const response = await request(app)
        .get("/error-recovery/status")
        .set("Authorization", `Bearer ${userToken}`);

      expect(response.status).toBe(403);
    });

    it("should require authentication", async () => {
      const response = await request(app).get("/error-recovery/status");

      expect(response.status).toBe(401);
    });
  });

  describe("GET /error-recovery/status/:serviceName", () => {
    it("should return recovery status for specific service", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
        description: "Test recovery procedure",
      });

      const response = await request(app)
        .get("/error-recovery/status/test-service")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.status).toBe("success");
      expect(response.body.data.service).toBe("test-service");
      expect(response.body.data.description).toBe("Test recovery procedure");
    });

    it("should return unknown status for unregistered service", async () => {
      const response = await request(app)
        .get("/error-recovery/status/unknown-service")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.status).toBe("unknown");
    });

    it("should require service name parameter", async () => {
      const response = await request(app)
        .get("/error-recovery/status/too/many/parts")
        .set("Authorization", `Bearer ${adminToken}`);

      // Express will not match this route
      expect(response.status).toBe(404);
    });
  });

  describe("POST /error-recovery/recover/:serviceName", () => {
    it("should execute recovery procedure successfully", async () => {
      const procedure = jest.fn().mockResolvedValue({ status: "recovered" });
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      const response = await request(app)
        .post("/error-recovery/recover/test-service")
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ reason: "Manual intervention" });

      expect(response.status).toBe(200);
      expect(response.body.status).toBe("success");
      expect(response.body.data.service).toBe("test-service");
      expect(response.body.data.status).toBe("success");
    });

    it("should return 404 if no recovery procedure registered", async () => {
      const response = await request(app)
        .post("/error-recovery/recover/unknown-service")
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ reason: "Test" });

      expect(response.status).toBe(404);
      expect(response.body.status).toBe("error");
    });

    it("should return 409 if recovery already in progress", async () => {
      const procedure = jest
        .fn()
        .mockImplementation(
          () => new Promise((resolve) => setTimeout(resolve, 1000)),
        );
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      // Start first recovery
      const promise1 = request(app)
        .post("/error-recovery/recover/test-service")
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ reason: "First" });

      // Try to start second recovery immediately
      const promise2 = request(app)
        .post("/error-recovery/recover/test-service")
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ reason: "Second" });

      const [response1, response2] = await Promise.all([promise1, promise2]);

      expect(response1.status).toBe(200);
      expect(response2.status).toBe(409);
    });

    it("should require admin role", async () => {
      const response = await request(app)
        .post("/error-recovery/recover/test-service")
        .set("Authorization", `Bearer ${userToken}`)
        .send({ reason: "Test" });

      expect(response.status).toBe(403);
    });

    it("should track recovery in history", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      await request(app)
        .post("/error-recovery/recover/test-service")
        .set("Authorization", `Bearer ${adminToken}`)
        .send({ reason: "Test recovery" });

      const history = errorRecoveryService.getRecoveryHistory();
      expect(history.length).toBe(1);
      expect(history[0].reason).toBe("Test recovery");
    });
  });

  describe("GET /error-recovery/history", () => {
    it("should return recovery history", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      await request(app)
        .post("/error-recovery/recover/test-service")
        .set("Authorization", `Bearer ${adminToken}`);

      const response = await request(app)
        .get("/error-recovery/history")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.status).toBe("success");
      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.count).toBeGreaterThan(0);
    });

    it("should filter history by service name", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("service-1", {
        procedure,
      });
      errorRecoveryService.registerRecoveryProcedure("service-2", {
        procedure,
      });

      await request(app)
        .post("/error-recovery/recover/service-1")
        .set("Authorization", `Bearer ${adminToken}`);

      await request(app)
        .post("/error-recovery/recover/service-2")
        .set("Authorization", `Bearer ${adminToken}`);

      const response = await request(app)
        .get("/error-recovery/history?serviceName=service-1")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.length).toBe(1);
      expect(response.body.data[0].serviceName).toBe("service-1");
    });

    it("should filter history by status", async () => {
      const successProcedure = jest.fn().mockResolvedValue({});
      const failProcedure = jest.fn().mockRejectedValue(new Error("Failed"));

      errorRecoveryService.registerRecoveryProcedure("service-1", {
        procedure: successProcedure,
      });
      errorRecoveryService.registerRecoveryProcedure("service-2", {
        procedure: failProcedure,
      });

      await request(app)
        .post("/error-recovery/recover/service-1")
        .set("Authorization", `Bearer ${adminToken}`);

      await request(app)
        .post("/error-recovery/recover/service-2")
        .set("Authorization", `Bearer ${adminToken}`);

      const response = await request(app)
        .get("/error-recovery/history?status=success")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.length).toBe(1);
      expect(response.body.data[0].status).toBe("success");
    });

    it("should limit history results", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      for (let i = 0; i < 5; i++) {
        await request(app)
          .post("/error-recovery/recover/test-service")
          .set("Authorization", `Bearer ${adminToken}`);
      }

      const response = await request(app)
        .get("/error-recovery/history?limit=2")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.length).toBe(2);
    });
  });

  describe("GET /error-recovery/metrics", () => {
    it("should return recovery metrics", async () => {
      const response = await request(app)
        .get("/error-recovery/metrics")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.status).toBe("success");
      expect(response.body.data.totalRecoveryAttempts).toBe(0);
      expect(response.body.data.successfulRecoveries).toBe(0);
      expect(response.body.data.failedRecoveries).toBe(0);
    });

    it("should update metrics after recovery", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      await request(app)
        .post("/error-recovery/recover/test-service")
        .set("Authorization", `Bearer ${adminToken}`);

      const response = await request(app)
        .get("/error-recovery/metrics")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.data.totalRecoveryAttempts).toBe(1);
      expect(response.body.data.successfulRecoveries).toBe(1);
    });
  });

  describe("GET /error-recovery/report", () => {
    it("should return comprehensive recovery report", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      const response = await request(app)
        .get("/error-recovery/report")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.status).toBe("success");
      expect(response.body.data.summary).toBeDefined();
      expect(response.body.data.services).toBeDefined();
      expect(response.body.data.recentHistory).toBeDefined();
    });
  });

  describe("DELETE /error-recovery/history", () => {
    it("should clear recovery history", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      await request(app)
        .post("/error-recovery/recover/test-service")
        .set("Authorization", `Bearer ${adminToken}`);

      let history = errorRecoveryService.getRecoveryHistory();
      expect(history.length).toBe(1);

      const response = await request(app)
        .delete("/error-recovery/history")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.status).toBe("success");

      history = errorRecoveryService.getRecoveryHistory();
      expect(history.length).toBe(0);
    });

    it("should require admin role", async () => {
      const response = await request(app)
        .delete("/error-recovery/history")
        .set("Authorization", `Bearer ${userToken}`);

      expect(response.status).toBe(403);
    });
  });

  describe("POST /error-recovery/reset-metrics", () => {
    it("should reset recovery metrics", async () => {
      const procedure = jest.fn().mockResolvedValue({});
      errorRecoveryService.registerRecoveryProcedure("test-service", {
        procedure,
      });

      await request(app)
        .post("/error-recovery/recover/test-service")
        .set("Authorization", `Bearer ${adminToken}`);

      let metrics = errorRecoveryService.getMetrics();
      expect(metrics.totalRecoveryAttempts).toBe(1);

      const response = await request(app)
        .post("/error-recovery/reset-metrics")
        .set("Authorization", `Bearer ${adminToken}`);

      expect(response.status).toBe(200);
      expect(response.body.status).toBe("success");

      metrics = errorRecoveryService.getMetrics();
      expect(metrics.totalRecoveryAttempts).toBe(0);
    });

    it("should require admin role", async () => {
      const response = await request(app)
        .post("/error-recovery/reset-metrics")
        .set("Authorization", `Bearer ${userToken}`);

      expect(response.status).toBe(403);
    });
  });
});
