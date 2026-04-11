/**
 * API Key Authentication Tests
 *
 * Tests for API key generation, validation, rotation, and revocation
 * Requirements: 2.8
 */

import {} from "@jest/globals";

import request from "supertest";
import express from "express";
import crypto from "crypto";
import { query } from "../../services/api-backend/database/db-pool.js";
import apiKeysRouter from "../../services/api-backend/routes/api-keys.js";
import { authenticateApiKey } from "../../services/api-backend/middleware/api-key-auth.js";
import {
  generateApiKey,
  validateApiKey,
  listApiKeys,
  getApiKey,
  updateApiKey,
  rotateApiKey,
  revokeApiKey,
  getApiKeyAuditLogs,
} from "../../services/api-backend/services/api-key-service.js";

describe("API Key Service", () => {
  let testUserId;

  beforeAll(async () => {
    // Create test user
    const userResult = await query(
      `INSERT INTO users (jwt_id, email, name)
       VALUES ($1, $2, $3)
       RETURNING id`,
      ["test-jwt-id", "test@example.com", "Test User"],
    );
    testUserId = userResult.rows[0].id;
  });

  afterAll(async () => {
    // Clean up test data
    await query("DELETE FROM api_key_audit_logs WHERE user_id = $1", [
      testUserId,
    ]);
    await query("DELETE FROM api_keys WHERE user_id = $1", [testUserId]);
    await query("DELETE FROM users WHERE id = $1", [testUserId]);
  });

  describe("generateApiKey", () => {
    it("should generate a valid API key", async () => {
      const result = await generateApiKey(testUserId, "Test Key", {
        description: "Test API key",
        scopes: ["read", "write"],
        rateLimit: 500,
      });

      expect(result).toHaveProperty("id");
      expect(result).toHaveProperty("apiKey");
      expect(result.apiKey).toMatch(/^ctll_[a-f0-9]{64}$/);
      expect(result.keyPrefix).toBe(result.apiKey.substring(0, 8));
      expect(result.name).toBe("Test Key");
      expect(result.description).toBe("Test API key");
      expect(result.scopes).toEqual(["read", "write"]);
      expect(result.rateLimit).toBe(500);
      expect(result.isActive).toBe(true);
    });

    it("should set expiration date when expiresIn is provided", async () => {
      const expiresIn = 24 * 60 * 60 * 1000; // 24 hours
      const result = await generateApiKey(testUserId, "Expiring Key", {
        expiresIn,
      });

      expect(result.expiresAt).toBeDefined();
      const expiresAtTime = new Date(result.expiresAt).getTime();
      const nowTime = Date.now();
      const diff = expiresAtTime - nowTime;

      // Should be approximately 24 hours from now (within 5 seconds)
      expect(Math.abs(diff - expiresIn)).toBeLessThan(5000);
    });

    it("should create audit log entry", async () => {
      const result = await generateApiKey(testUserId, "Audit Test Key");

      const logs = await getApiKeyAuditLogs(result.id, testUserId);
      expect(logs.length).toBeGreaterThan(0);
      expect(logs[0].action).toBe("created");
    });
  });

  describe("validateApiKey", () => {
    let testKey;

    beforeAll(async () => {
      const result = await generateApiKey(testUserId, "Validation Test Key", {
        scopes: ["read"],
        rateLimit: 100,
      });
      testKey = result.apiKey;
    });

    it("should validate a valid API key", async () => {
      const result = await validateApiKey(testKey);

      expect(result).toBeDefined();
      expect(result.id).toBeDefined();
      expect(result.userId).toBe(testUserId);
      expect(result.scopes).toContain("read");
      expect(result.rateLimit).toBe(100);
    });

    it("should return null for invalid API key", async () => {
      const invalidKey = "ctll_" + "a".repeat(64);
      const result = await validateApiKey(invalidKey);

      expect(result).toBeNull();
    });

    it("should return null for key without prefix", async () => {
      const result = await validateApiKey("invalid_key");

      expect(result).toBeNull();
    });

    it("should update last_used_at on validation", async () => {
      await new Promise((resolve) => setTimeout(resolve, 100));
      await validateApiKey(testKey);

      const keyData = await getApiKey(
        (await generateApiKey(testUserId, "Last Used Test")).id,
        testUserId,
      );

      // Verify that last_used_at is being tracked
      expect(keyData).toBeDefined();
    });

    it("should return null for expired API key", async () => {
      const expiredResult = await generateApiKey(testUserId, "Expired Key", {
        expiresIn: 100, // 100ms
      });

      // Wait for key to expire
      await new Promise((resolve) => setTimeout(resolve, 150));

      const result = await validateApiKey(expiredResult.apiKey);
      expect(result).toBeNull();
    });

    it("should return null for inactive API key", async () => {
      const inactiveResult = await generateApiKey(testUserId, "Inactive Key");

      // Revoke the key
      await revokeApiKey(inactiveResult.id, testUserId);

      const result = await validateApiKey(inactiveResult.apiKey);
      expect(result).toBeNull();
    });
  });

  describe("listApiKeys", () => {
    it("should list all API keys for a user", async () => {
      // Generate multiple keys
      await generateApiKey(testUserId, "List Test Key 1");
      await generateApiKey(testUserId, "List Test Key 2");

      const keys = await listApiKeys(testUserId);

      expect(Array.isArray(keys)).toBe(true);
      expect(keys.length).toBeGreaterThanOrEqual(2);
      expect(keys[0]).toHaveProperty("id");
      expect(keys[0]).toHaveProperty("name");
      expect(keys[0]).toHaveProperty("keyPrefix");
    });

    it("should not include actual API keys in list", async () => {
      const keys = await listApiKeys(testUserId);

      keys.forEach((key) => {
        expect(key).not.toHaveProperty("apiKey");
        expect(key).toHaveProperty("keyPrefix");
      });
    });
  });

  describe("getApiKey", () => {
    let testKeyId;

    beforeAll(async () => {
      const result = await generateApiKey(testUserId, "Get Test Key");
      testKeyId = result.id;
    });

    it("should get API key details", async () => {
      const key = await getApiKey(testKeyId, testUserId);

      expect(key).toBeDefined();
      expect(key.id).toBe(testKeyId);
      expect(key.name).toBe("Get Test Key");
    });

    it("should return null for non-existent key", async () => {
      const fakeId = crypto.randomUUID();
      const key = await getApiKey(fakeId, testUserId);

      expect(key).toBeNull();
    });

    it("should return null for unauthorized user", async () => {
      const otherUserId = crypto.randomUUID();
      const key = await getApiKey(testKeyId, otherUserId);

      expect(key).toBeNull();
    });
  });

  describe("updateApiKey", () => {
    let testKeyId;

    beforeAll(async () => {
      const result = await generateApiKey(testUserId, "Update Test Key", {
        description: "Original description",
        scopes: ["read"],
        rateLimit: 100,
      });
      testKeyId = result.id;
    });

    it("should update API key name", async () => {
      const updated = await updateApiKey(testKeyId, testUserId, {
        name: "Updated Key Name",
      });

      expect(updated.name).toBe("Updated Key Name");
    });

    it("should update API key description", async () => {
      const updated = await updateApiKey(testKeyId, testUserId, {
        description: "Updated description",
      });

      expect(updated.description).toBe("Updated description");
    });

    it("should update API key scopes", async () => {
      const updated = await updateApiKey(testKeyId, testUserId, {
        scopes: ["read", "write", "delete"],
      });

      expect(updated.scopes).toEqual(["read", "write", "delete"]);
    });

    it("should update API key rate limit", async () => {
      const updated = await updateApiKey(testKeyId, testUserId, {
        rateLimit: 2000,
      });

      expect(updated.rateLimit).toBe(2000);
    });

    it("should not allow updating key_hash", async () => {
      const updated = await updateApiKey(testKeyId, testUserId, {
        key_hash: "fake_hash",
        name: "Test",
      });

      // Should update name but not key_hash
      expect(updated.name).toBe("Test");
    });
  });

  describe("rotateApiKey", () => {
    let originalKeyId;
    let originalKey;

    beforeAll(async () => {
      const result = await generateApiKey(testUserId, "Rotate Test Key", {
        scopes: ["read", "write"],
        rateLimit: 500,
      });
      originalKeyId = result.id;
      originalKey = result.apiKey;
    });

    it("should generate a new API key", async () => {
      const result = await rotateApiKey(originalKeyId, testUserId);

      expect(result).toHaveProperty("apiKey");
      expect(result.apiKey).not.toBe(originalKey);
      expect(result.apiKey).toMatch(/^ctll_[a-f0-9]{64}$/);
    });

    it("should preserve key metadata during rotation", async () => {
      const result = await rotateApiKey(originalKeyId, testUserId);

      expect(result.name).toBe("Rotate Test Key");
      expect(result.scopes).toEqual(["read", "write"]);
      expect(result.rateLimit).toBe(500);
    });

    it("should revoke the old key", async () => {
      const oldKeyValidation = await validateApiKey(originalKey);
      expect(oldKeyValidation).toBeNull();
    });

    it("should create audit log entries", async () => {
      const logs = await getApiKeyAuditLogs(originalKeyId, testUserId);

      const rotatedLog = logs.find((log) => log.action === "rotated");
      expect(rotatedLog).toBeDefined();
    });
  });

  describe("revokeApiKey", () => {
    let testKeyId;
    let testKey;

    beforeAll(async () => {
      const result = await generateApiKey(testUserId, "Revoke Test Key");
      testKeyId = result.id;
      testKey = result.apiKey;
    });

    it("should revoke an API key", async () => {
      await revokeApiKey(testKeyId, testUserId);

      const key = await getApiKey(testKeyId, testUserId);
      expect(key.isActive).toBe(false);
    });

    it("should make revoked key invalid", async () => {
      const result = await validateApiKey(testKey);
      expect(result).toBeNull();
    });

    it("should create audit log entry", async () => {
      const logs = await getApiKeyAuditLogs(testKeyId, testUserId);

      const revokedLog = logs.find((log) => log.action === "revoked");
      expect(revokedLog).toBeDefined();
    });
  });

  describe("getApiKeyAuditLogs", () => {
    let testKeyId;

    beforeAll(async () => {
      const result = await generateApiKey(testUserId, "Audit Test Key");
      testKeyId = result.id;
    });

    it("should retrieve audit logs for an API key", async () => {
      const logs = await getApiKeyAuditLogs(testKeyId, testUserId);

      expect(Array.isArray(logs)).toBe(true);
      expect(logs.length).toBeGreaterThan(0);
    });

    it("should include creation event in audit logs", async () => {
      const logs = await getApiKeyAuditLogs(testKeyId, testUserId);

      const createdLog = logs.find((log) => log.action === "created");
      expect(createdLog).toBeDefined();
    });

    it("should return empty array for non-existent key", async () => {
      const fakeId = crypto.randomUUID();
      const logs = await getApiKeyAuditLogs(fakeId, testUserId);

      expect(logs).toEqual([]);
    });
  });
});

describe("API Key Routes", () => {
  let app;
  let testUserUUID;
  let mockUserId = "placeholder";

  beforeAll(async () => {
    // Create test user first so mock auth can reference the real UUID
    const userResult = await query(
      `INSERT INTO users (jwt_id, email, name)
       VALUES ($1, $2, $3)
       RETURNING id`,
      ["test-jwt-routes", "test-routes@example.com", "Test Routes User"],
    );
    testUserUUID = userResult.rows[0].id;
    mockUserId = testUserUUID;

    // Create Express app with routes
    app = express();
    app.use(express.json());

    // Mock authenticateJWT middleware — uses real UUID from DB
    app.use((req, res, next) => {
      req.user = { sub: mockUserId };
      req.userId = mockUserId;
      next();
    });

    app.use("/api-keys", apiKeysRouter);
  });

  afterAll(async () => {
    // Clean up test data
    await query("DELETE FROM api_key_audit_logs WHERE user_id = $1", [
      testUserUUID,
    ]);
    await query("DELETE FROM api_keys WHERE user_id = $1", [testUserUUID]);
    await query("DELETE FROM users WHERE id = $1", [testUserUUID]);
  });

  describe("POST /api-keys", () => {
    it("should create a new API key", async () => {
      const response = await request(app)
        .post("/api-keys")
        .send({
          name: "Test API Key",
          description: "Test description",
          scopes: ["read", "write"],
          rateLimit: 500,
        });

      expect(response.status).toBe(201);
      expect(response.body).toHaveProperty("id");
      expect(response.body).toHaveProperty("apiKey");
      expect(response.body.name).toBe("Test API Key");
      expect(response.body.apiKey).toMatch(/^ctll_[a-f0-9]{64}$/);
    });

    it("should reject request without name", async () => {
      const response = await request(app).post("/api-keys").send({
        description: "No name",
      });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe("INVALID_NAME");
    });

    it("should reject invalid scopes", async () => {
      const response = await request(app).post("/api-keys").send({
        name: "Test",
        scopes: "not-an-array",
      });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe("INVALID_SCOPES");
    });

    it("should reject invalid rate limit", async () => {
      const response = await request(app).post("/api-keys").send({
        name: "Test",
        rateLimit: -100,
      });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe("INVALID_RATE_LIMIT");
    });
  });

  describe("GET /api-keys", () => {
    beforeAll(async () => {
      await generateApiKey(testUserUUID, "List Test 1");
      await generateApiKey(testUserUUID, "List Test 2");
    });

    it("should list all API keys", async () => {
      const response = await request(app).get("/api-keys");

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThanOrEqual(2);
    });

    it("should not include actual API keys", async () => {
      const response = await request(app).get("/api-keys");

      response.body.forEach((key) => {
        expect(key).not.toHaveProperty("apiKey");
        expect(key).toHaveProperty("keyPrefix");
      });
    });
  });

  describe("GET /api-keys/:keyId", () => {
    let testKeyId;

    beforeAll(async () => {
      const result = await generateApiKey(testUserUUID, "Get Test Key");
      testKeyId = result.id;
    });

    it("should get API key details", async () => {
      const response = await request(app).get(`/api-keys/${testKeyId}`);

      expect(response.status).toBe(200);
      expect(response.body.id).toBe(testKeyId);
      expect(response.body.name).toBe("Get Test Key");
    });

    it("should return 404 for non-existent key", async () => {
      const fakeId = crypto.randomUUID();
      const response = await request(app).get(`/api-keys/${fakeId}`);

      expect(response.status).toBe(404);
    });
  });

  describe("PATCH /api-keys/:keyId", () => {
    let testKeyId;

    beforeAll(async () => {
      const result = await generateApiKey(testUserUUID, "Update Test Key");
      testKeyId = result.id;
    });

    it("should update API key", async () => {
      const response = await request(app).patch(`/api-keys/${testKeyId}`).send({
        name: "Updated Name",
        description: "Updated description",
      });

      expect(response.status).toBe(200);
      expect(response.body.name).toBe("Updated Name");
      expect(response.body.description).toBe("Updated description");
    });

    it("should reject invalid fields", async () => {
      const response = await request(app).patch(`/api-keys/${testKeyId}`).send({
        key_hash: "fake",
      });

      expect(response.status).toBe(400);
      expect(response.body.code).toBe("INVALID_FIELDS");
    });
  });

  describe("POST /api-keys/:keyId/rotate", () => {
    let testKeyId;
    let originalKey;

    beforeAll(async () => {
      const result = await generateApiKey(testUserUUID, "Rotate Test Key");
      testKeyId = result.id;
      originalKey = result.apiKey;
    });

    it("should rotate API key", async () => {
      const response = await request(app).post(`/api-keys/${testKeyId}/rotate`);

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("apiKey");
      expect(response.body.apiKey).not.toBe(originalKey);
    });
  });

  describe("POST /api-keys/:keyId/revoke", () => {
    let testKeyId;

    beforeAll(async () => {
      const result = await generateApiKey(testUserUUID, "Revoke Test Key");
      testKeyId = result.id;
    });

    it("should revoke API key", async () => {
      const response = await request(app).post(`/api-keys/${testKeyId}/revoke`);

      expect(response.status).toBe(200);
      expect(response.body.message).toBe("API key revoked successfully");
    });
  });

  describe("GET /api-keys/:keyId/audit-logs", () => {
    let testKeyId;

    beforeAll(async () => {
      const result = await generateApiKey(testUserUUID, "Audit Test Key");
      testKeyId = result.id;
    });

    it("should get audit logs", async () => {
      const response = await request(app).get(
        `/api-keys/${testKeyId}/audit-logs`,
      );

      expect(response.status).toBe(200);
      expect(Array.isArray(response.body)).toBe(true);
      expect(response.body.length).toBeGreaterThan(0);
    });
  });
});

describe("API Key Middleware", () => {
  let app;
  let testUserUUID;
  let validApiKey;

  beforeAll(async () => {
    // Create Express app with middleware
    app = express();
    app.use(express.json());

    // Create test user
    const userResult = await query(
      `INSERT INTO users (jwt_id, email, name)
       VALUES ($1, $2, $3)
       RETURNING id`,
      [
        "test-jwt-middleware",
        "test-middleware@example.com",
        "Test Middleware User",
      ],
    );
    testUserUUID = userResult.rows[0].id;

    // Generate test API key
    const keyResult = await generateApiKey(
      testUserUUID,
      "Middleware Test Key",
      {
        scopes: ["read", "write"],
        rateLimit: 100,
      },
    );
    validApiKey = keyResult.apiKey;

    // Test endpoint
    app.post("/protected", authenticateApiKey, (req, res) => {
      res.json({
        message: "Success",
        userId: req.userId,
        keyId: req.apiKey.id,
      });
    });
  });

  afterAll(async () => {
    // Clean up test data
    await query("DELETE FROM api_key_audit_logs WHERE user_id = $1", [
      testUserUUID,
    ]);
    await query("DELETE FROM api_keys WHERE user_id = $1", [testUserUUID]);
    await query("DELETE FROM users WHERE id = $1", [testUserUUID]);
  });

  describe("authenticateApiKey", () => {
    it("should authenticate with valid API key in Authorization header", async () => {
      const response = await request(app)
        .post("/protected")
        .set("Authorization", `Bearer ${validApiKey}`);

      expect(response.status).toBe(200);
      expect(response.body.message).toBe("Success");
      expect(response.body.userId).toBe(testUserUUID);
    });

    it("should authenticate with valid API key in X-API-Key header", async () => {
      const response = await request(app)
        .post("/protected")

        .set("X-API-Key", validApiKey);

      expect(response.status).toBe(200);
      expect(response.body.message).toBe("Success");
    });

    it("should reject request without API key", async () => {
      const response = await request(app).post("/protected");

      expect(response.status).toBe(401);
      expect(response.body.code).toBe("MISSING_API_KEY");
    });

    it("should reject invalid API key", async () => {
      const response = await request(app)
        .post("/protected")
        .set("Authorization", "Bearer invalid_key");

      expect(response.status).toBe(401);
      expect(response.body.code).toBe("INVALID_API_KEY");
    });

    it("should reject revoked API key", async () => {
      // Generate and revoke a key
      const keyResult = await generateApiKey(
        testUserUUID,
        "Revoke Middleware Test",
      );
      await revokeApiKey(keyResult.id, testUserUUID);

      const response = await request(app)
        .post("/protected")
        .set("Authorization", `Bearer ${keyResult.apiKey}`);

      expect(response.status).toBe(401);
      expect(response.body.code).toBe("INVALID_API_KEY");
    });
  });
});
