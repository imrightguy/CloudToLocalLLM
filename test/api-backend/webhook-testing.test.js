/**
 * Webhook Testing and Debugging Service Tests
 *
 * Tests for webhook testing and debugging functionality including:
 * - Test payload generation
 * - Webhook delivery simulation
 * - Debugging utilities
 * - Test event tracking
 *
 * Validates: Requirements 10.8
 * - Provides webhook testing and debugging tools
 * - Generates test payloads
 * - Tracks test events
 *
 * @fileoverview Webhook testing service tests
 * @version 1.0.0
 */

import { describe, it, expect, beforeEach, afterEach } from "@jest/globals";
import { WebhookTestingService } from "../../services/api-backend/services/webhook-testing-service.js";
import crypto from "crypto";

describe("Webhook Testing Service", () => {
  let testingService;

  beforeEach(() => {
    testingService = new WebhookTestingService();
  });

  afterEach(() => {
    testingService.clearTestEventCache();
  });

  describe("Test Payload Generation", () => {
    it("should generate test payload with required fields", () => {
      const payload = testingService.generateTestPayload(
        "tunnel.status_changed",
      );

      expect(payload).toHaveProperty("id");
      expect(payload).toHaveProperty("type");
      expect(payload).toHaveProperty("timestamp");
      expect(payload).toHaveProperty("version");
      expect(payload).toHaveProperty("data");
      expect(payload.type).toBe("tunnel.status_changed");
    });

    it("should generate valid UUID for payload id", () => {
      const payload = testingService.generateTestPayload(
        "tunnel.status_changed",
      );

      // UUID v4 format check
      const uuidRegex =
        /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
      expect(payload.id).toMatch(uuidRegex);
    });

    it("should generate valid ISO 8601 timestamp", () => {
      const payload = testingService.generateTestPayload(
        "tunnel.status_changed",
      );

      expect(() => new Date(payload.timestamp)).not.toThrow();
      expect(payload.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
    });

    it("should merge custom data with generated payload", () => {
      const customData = { customField: "customValue" };
      const payload = testingService.generateTestPayload(
        "tunnel.status_changed",
        customData,
      );

      expect(payload.data.customField).toBe("customValue");
    });

    it("should generate tunnel.status_changed event data", () => {
      const payload = testingService.generateTestPayload(
        "tunnel.status_changed",
      );

      expect(payload.data).toHaveProperty("tunnelId");
      expect(payload.data).toHaveProperty("userId");
      expect(payload.data).toHaveProperty("previousStatus");
      expect(payload.data).toHaveProperty("newStatus");
      expect(payload.data.previousStatus).toBe("connected");
      expect(payload.data.newStatus).toBe("disconnected");
    });

    it("should generate tunnel.created event data", () => {
      const payload = testingService.generateTestPayload("tunnel.created");

      expect(payload.data).toHaveProperty("tunnelId");
      expect(payload.data).toHaveProperty("userId");
      expect(payload.data).toHaveProperty("name");
      expect(payload.data).toHaveProperty("config");
      expect(payload.data.config).toHaveProperty("maxConnections");
    });

    it("should generate tunnel.metrics event data", () => {
      const payload = testingService.generateTestPayload("tunnel.metrics");

      expect(payload.data).toHaveProperty("tunnelId");
      expect(payload.data).toHaveProperty("metrics");
      expect(payload.data.metrics).toHaveProperty("requestCount");
      expect(payload.data.metrics).toHaveProperty("successCount");
      expect(payload.data.metrics).toHaveProperty("errorCount");
    });

    it("should generate proxy.status_changed event data", () => {
      const payload = testingService.generateTestPayload(
        "proxy.status_changed",
      );

      expect(payload.data).toHaveProperty("proxyId");
      expect(payload.data).toHaveProperty("previousStatus");
      expect(payload.data).toHaveProperty("newStatus");
    });

    it("should generate proxy.metrics event data", () => {
      const payload = testingService.generateTestPayload("proxy.metrics");

      expect(payload.data).toHaveProperty("proxyId");
      expect(payload.data).toHaveProperty("metrics");
      expect(payload.data.metrics).toHaveProperty("activeConnections");
      expect(payload.data.metrics).toHaveProperty("requestsPerSecond");
    });

    it("should generate user.activity event data", () => {
      const payload = testingService.generateTestPayload("user.activity");

      expect(payload.data).toHaveProperty("userId");
      expect(payload.data).toHaveProperty("action");
      expect(payload.data).toHaveProperty("resource");
    });

    it("should generate generic data for unknown event types", () => {
      const payload = testingService.generateTestPayload("unknown.event");

      expect(payload.data).toHaveProperty("eventType");
      expect(payload.data.eventType).toBe("unknown.event");
    });
  });

  describe("Supported Event Types", () => {
    it("should return list of supported event types", () => {
      const types = testingService.getSupportedEventTypes();

      expect(Array.isArray(types)).toBe(true);
      expect(types.length).toBeGreaterThan(0);
    });

    it("should include tunnel events", () => {
      const types = testingService.getSupportedEventTypes();

      expect(types).toContain("tunnel.status_changed");
      expect(types).toContain("tunnel.created");
      expect(types).toContain("tunnel.deleted");
      expect(types).toContain("tunnel.metrics");
    });

    it("should include proxy events", () => {
      const types = testingService.getSupportedEventTypes();

      expect(types).toContain("proxy.status_changed");
      expect(types).toContain("proxy.metrics");
    });

    it("should include user events", () => {
      const types = testingService.getSupportedEventTypes();

      expect(types).toContain("user.activity");
    });
  });

  describe("Webhook Signature Generation and Validation", () => {
    it("should generate valid webhook signature", () => {
      const payload = { test: "data" };
      const secret = "test-secret";
      const timestamp = Date.now();

      const signature = testingService.generateWebhookSignature(
        payload,
        secret,
        timestamp,
      );

      expect(signature).toMatch(/^sha256=/);
      expect(signature.length).toBeGreaterThan(10);
    });

    it("should generate consistent signatures for same input", () => {
      const payload = { test: "data" };
      const secret = "test-secret";
      const timestamp = 1234567890;

      const sig1 = testingService.generateWebhookSignature(
        payload,
        secret,
        timestamp,
      );
      const sig2 = testingService.generateWebhookSignature(
        payload,
        secret,
        timestamp,
      );

      expect(sig1).toBe(sig2);
    });

    it("should generate different signatures for different payloads", () => {
      const secret = "test-secret";
      const timestamp = 1234567890;

      const sig1 = testingService.generateWebhookSignature(
        { test: "data1" },
        secret,
        timestamp,
      );
      const sig2 = testingService.generateWebhookSignature(
        { test: "data2" },
        secret,
        timestamp,
      );

      expect(sig1).not.toBe(sig2);
    });

    it("should generate different signatures for different secrets", () => {
      const payload = { test: "data" };
      const timestamp = 1234567890;

      const sig1 = testingService.generateWebhookSignature(
        payload,
        "secret1",
        timestamp,
      );
      const sig2 = testingService.generateWebhookSignature(
        payload,
        "secret2",
        timestamp,
      );

      expect(sig1).not.toBe(sig2);
    });

    it("should validate correct signature", () => {
      const payload = { test: "data" };
      const secret = "test-secret";
      const timestamp = 1234567890;

      const signature = testingService.generateWebhookSignature(
        payload,
        secret,
        timestamp,
      );
      const isValid = testingService.validateWebhookSignature(
        signature,
        payload,
        secret,
        timestamp,
      );

      expect(isValid).toBe(true);
    });

    it("should reject invalid signature", () => {
      const payload = { test: "data" };
      const secret = "test-secret";
      const timestamp = 1234567890;

      const invalidSignature = "sha256=invalid";
      const isValid = testingService.validateWebhookSignature(
        invalidSignature,
        payload,
        secret,
        timestamp,
      );

      expect(isValid).toBe(false);
    });

    it("should reject signature with wrong payload", () => {
      const payload1 = { test: "data1" };
      const payload2 = { test: "data2" };
      const secret = "test-secret";
      const timestamp = 1234567890;

      const signature = testingService.generateWebhookSignature(
        payload1,
        secret,
        timestamp,
      );
      const isValid = testingService.validateWebhookSignature(
        signature,
        payload2,
        secret,
        timestamp,
      );

      expect(isValid).toBe(false);
    });
  });

  describe("Test Event Caching", () => {
    it("should cache test event", () => {
      const testId = crypto.randomUUID();
      const result = { success: true, statusCode: 200 };

      testingService.cacheTestEvent(testId, result);
      const cached = testingService.getTestEvent(testId);

      expect(cached).toBeDefined();
      expect(cached.success).toBe(true);
      expect(cached.statusCode).toBe(200);
    });

    it("should retrieve cached test event", () => {
      const testId = crypto.randomUUID();
      const result = { success: true, statusCode: 200 };

      testingService.cacheTestEvent(testId, result);
      const cached = testingService.getTestEvent(testId);

      expect(cached).not.toBeNull();
      expect(cached.cachedAt).toBeDefined();
    });

    it("should return null for non-existent test event", () => {
      const cached = testingService.getTestEvent("non-existent-id");

      expect(cached).toBeNull();
    });

    it("should get all cached test events", () => {
      const testId1 = crypto.randomUUID();
      const testId2 = crypto.randomUUID();

      testingService.cacheTestEvent(testId1, { success: true });
      testingService.cacheTestEvent(testId2, { success: false });

      const events = testingService.getAllTestEvents();

      expect(events.length).toBeGreaterThanOrEqual(2);
    });

    it("should limit returned events by limit parameter", () => {
      for (let i = 0; i < 10; i++) {
        testingService.cacheTestEvent(crypto.randomUUID(), { success: true });
      }

      const events = testingService.getAllTestEvents(5);

      expect(events.length).toBeLessThanOrEqual(5);
    });

    it("should clear test event cache", () => {
      testingService.cacheTestEvent(crypto.randomUUID(), { success: true });
      testingService.cacheTestEvent(crypto.randomUUID(), { success: true });

      testingService.clearTestEventCache();
      const events = testingService.getAllTestEvents();

      expect(events.length).toBe(0);
    });

    it("should maintain cache size limit", () => {
      // Add more than 1000 events
      for (let i = 0; i < 1100; i++) {
        testingService.cacheTestEvent(crypto.randomUUID(), { success: true });
      }

      const events = testingService.getAllTestEvents(2000);

      expect(events.length).toBeLessThanOrEqual(1000);
    });
  });

  describe("Payload Structure Validation", () => {
    it("should validate correct payload structure", () => {
      const payload = {
        id: crypto.randomUUID(),
        type: "tunnel.status_changed",
        timestamp: new Date().toISOString(),
        data: { test: "data" },
      };

      const validation = testingService.validatePayloadStructure(payload);

      expect(validation.isValid).toBe(true);
      expect(validation.errors.length).toBe(0);
    });

    it("should reject null payload", () => {
      const validation = testingService.validatePayloadStructure(null);

      expect(validation.isValid).toBe(false);
      expect(validation.errors.length).toBeGreaterThan(0);
    });

    it("should reject non-object payload", () => {
      const validation =
        testingService.validatePayloadStructure("not an object");

      expect(validation.isValid).toBe(false);
      expect(validation.errors.length).toBeGreaterThan(0);
    });

    it("should reject payload without id", () => {
      const payload = {
        type: "tunnel.status_changed",
        timestamp: new Date().toISOString(),
        data: {},
      };

      const validation = testingService.validatePayloadStructure(payload);

      expect(validation.isValid).toBe(false);
      expect(validation.errors.some((e) => e.includes("id"))).toBe(true);
    });

    it("should reject payload without type", () => {
      const payload = {
        id: crypto.randomUUID(),
        timestamp: new Date().toISOString(),
        data: {},
      };

      const validation = testingService.validatePayloadStructure(payload);

      expect(validation.isValid).toBe(false);
      expect(validation.errors.some((e) => e.includes("type"))).toBe(true);
    });

    it("should reject payload without timestamp", () => {
      const payload = {
        id: crypto.randomUUID(),
        type: "tunnel.status_changed",
        data: {},
      };

      const validation = testingService.validatePayloadStructure(payload);

      expect(validation.isValid).toBe(false);
      expect(validation.errors.some((e) => e.includes("timestamp"))).toBe(true);
    });

    it("should reject payload without data", () => {
      const payload = {
        id: crypto.randomUUID(),
        type: "tunnel.status_changed",
        timestamp: new Date().toISOString(),
      };

      const validation = testingService.validatePayloadStructure(payload);

      expect(validation.isValid).toBe(false);
      expect(validation.errors.some((e) => e.includes("data"))).toBe(true);
    });

    it("should reject payload with invalid timestamp format", () => {
      const payload = {
        id: crypto.randomUUID(),
        type: "tunnel.status_changed",
        timestamp: "not-a-date",
        data: {},
      };

      const validation = testingService.validatePayloadStructure(payload);

      expect(validation.isValid).toBe(false);
      expect(
        validation.errors.some((e) => e.toLowerCase().includes("timestamp")),
      ).toBe(true);
    });

    it("should accept payload with valid ISO 8601 timestamp", () => {
      const payload = {
        id: crypto.randomUUID(),
        type: "tunnel.status_changed",
        timestamp: new Date().toISOString(),
        data: {},
      };

      const validation = testingService.validatePayloadStructure(payload);

      expect(validation.isValid).toBe(true);
    });
  });

  describe("Edge Cases", () => {
    it("should handle empty custom data", () => {
      const payload = testingService.generateTestPayload(
        "tunnel.status_changed",
        {},
      );

      expect(payload).toHaveProperty("data");
      expect(payload.data).toHaveProperty("tunnelId");
    });

    it("should handle large custom data", () => {
      const largeData = {};
      for (let i = 0; i < 100; i++) {
        largeData[`field${i}`] = `value${i}`;
      }

      const payload = testingService.generateTestPayload(
        "tunnel.status_changed",
        largeData,
      );

      expect(payload.data).toHaveProperty("field0");
      expect(payload.data).toHaveProperty("field99");
    });

    it("should generate unique IDs for multiple payloads", () => {
      const payload1 = testingService.generateTestPayload(
        "tunnel.status_changed",
      );
      const payload2 = testingService.generateTestPayload(
        "tunnel.status_changed",
      );

      expect(payload1.id).not.toBe(payload2.id);
    });

    it("should generate different timestamps for sequential payloads", (done) => {
      const payload1 = testingService.generateTestPayload(
        "tunnel.status_changed",
      );

      setTimeout(() => {
        const payload2 = testingService.generateTestPayload(
          "tunnel.status_changed",
        );

        expect(new Date(payload1.timestamp).getTime()).toBeLessThan(
          new Date(payload2.timestamp).getTime(),
        );
        done();
      }, 10);
    });
  });
});
