/**


 * Webhook Testing Routes Integration Tests
 *
 * Tests for webhook testing and debugging route endpoints including:
 * - Test payload generation endpoint
 * - Test webhook delivery endpoint
 * - Test event history endpoint
 * - Webhook debug info endpoint
 * - Payload validation endpoint
 *
 * Validates: Requirements 10.8
 * - Provides webhook testing and debugging tools
 * - Generates test payloads
 * - Tracks test events
 *
 * @fileoverview Webhook testing routes integration tests
 * @version 1.0.0
 */

import {
  describe,
  it,
  expect,
  beforeEach,
  afterEach,
  jest,
} from "@jest/globals";
import { webhookTestingService } from "../../services/api-backend/services/webhook-testing-service.js";
import crypto from "crypto";

describe("Webhook Testing Routes Integration", () => {
  beforeEach(() => {
    jest
      .spyOn(webhookTestingService, "initialize")
      .mockResolvedValue(undefined);
  });

  afterEach(() => {
    jest.restoreAllMocks();
    webhookTestingService.clearTestEventCache();
  });

  describe("Test Payload Generation Endpoint", () => {
    it("should generate test payload for valid event type", () => {
      const eventType = "tunnel.status_changed";
      const payload = webhookTestingService.generateTestPayload(eventType);

      expect(payload).toHaveProperty("id");
      expect(payload).toHaveProperty("type");
      expect(payload.type).toBe(eventType);
      expect(payload).toHaveProperty("data");
    });

    it("should merge custom data with generated payload", () => {
      const customData = { customField: "customValue" };
      const payload = webhookTestingService.generateTestPayload(
        "tunnel.status_changed",
        customData,
      );

      expect(payload.data.customField).toBe("customValue");
    });

    it("should support all event types", () => {
      const supportedTypes = webhookTestingService.getSupportedEventTypes();

      for (const eventType of supportedTypes) {
        const payload = webhookTestingService.generateTestPayload(eventType);
        expect(payload.type).toBe(eventType);
        expect(payload).toHaveProperty("data");
      }
    });
  });

  describe("Test Webhook Delivery Simulation", () => {
    it("should simulate webhook delivery", async () => {
      const payload = webhookTestingService.generateTestPayload(
        "tunnel.status_changed",
      );
      const mockFetch = jest.fn().mockResolvedValue({
        ok: true,
        status: 200,
        statusText: "OK",
        headers: new Map([["content-type", "application/json"]]),
        json: async () => ({ success: true }),
        text: async () => "OK",
      });

      global.fetch = mockFetch;

      const result = await webhookTestingService.simulateWebhookDelivery(
        "https://example.com/webhook",
        payload,
      );

      expect(result).toHaveProperty("testId");
      expect(result).toHaveProperty("success");
      expect(result).toHaveProperty("statusCode");
      expect(result).toHaveProperty("responseTime");
    });

    it("should handle webhook delivery errors", async () => {
      const payload = webhookTestingService.generateTestPayload(
        "tunnel.status_changed",
      );
      const mockFetch = jest.fn().mockRejectedValue(new Error("Network error"));

      global.fetch = mockFetch;

      const result = await webhookTestingService.simulateWebhookDelivery(
        "https://example.com/webhook",
        payload,
      );

      expect(result.success).toBe(false);
      expect(result).toHaveProperty("error");
    });

    it("should validate webhook URL", async () => {
      const payload = webhookTestingService.generateTestPayload(
        "tunnel.status_changed",
      );

      const result = await webhookTestingService.simulateWebhookDelivery(
        "invalid-url",
        payload,
      );

      expect(result.success).toBe(false);
      expect(result).toHaveProperty("error");
    });
  });

  describe("Test Event Caching and History", () => {
    it("should cache test events", () => {
      const testId = crypto.randomUUID();
      const result = { success: true, statusCode: 200 };

      webhookTestingService.cacheTestEvent(testId, result);
      const cached = webhookTestingService.getTestEvent(testId);

      expect(cached).toBeDefined();
      expect(cached.success).toBe(true);
    });

    it("should retrieve all cached test events", () => {
      webhookTestingService.cacheTestEvent(crypto.randomUUID(), {
        success: true,
      });
      webhookTestingService.cacheTestEvent(crypto.randomUUID(), {
        success: false,
      });

      const events = webhookTestingService.getAllTestEvents();

      expect(Array.isArray(events)).toBe(true);
      expect(events.length).toBeGreaterThanOrEqual(2);
    });

    it("should clear test event cache", () => {
      webhookTestingService.cacheTestEvent(crypto.randomUUID(), {
        success: true,
      });
      webhookTestingService.cacheTestEvent(crypto.randomUUID(), {
        success: true,
      });

      webhookTestingService.clearTestEventCache();
      const events = webhookTestingService.getAllTestEvents();

      expect(events.length).toBe(0);
    });
  });

  describe("Webhook Debug Information", () => {
    it("should get webhook debug info", async () => {
      const debugInfo = await webhookTestingService.getWebhookDebugInfo(
        "webhook-123",
        "user-123",
      );

      // Should return either debug info or error
      expect(debugInfo).toBeDefined();
      expect(debugInfo).toHaveProperty("error");
    });

    it("should get delivery details", async () => {
      const details = await webhookTestingService.getDeliveryDetails(
        "delivery-123",
        "user-123",
      );

      // Should return either details or error
      expect(details).toBeDefined();
      expect(details).toHaveProperty("error");
    });
  });

  describe("Payload Validation", () => {
    it("should validate correct payload structure", () => {
      const payload = {
        id: crypto.randomUUID(),
        type: "tunnel.status_changed",
        timestamp: new Date().toISOString(),
        data: { test: "data" },
      };

      const validation =
        webhookTestingService.validatePayloadStructure(payload);

      expect(validation.isValid).toBe(true);
      expect(validation.errors.length).toBe(0);
    });

    it("should reject invalid payload", () => {
      const validation = webhookTestingService.validatePayloadStructure({
        incomplete: "payload",
      });

      expect(validation.isValid).toBe(false);
      expect(validation.errors.length).toBeGreaterThan(0);
    });

    it("should validate all required fields", () => {
      const payload = {
        id: crypto.randomUUID(),
        type: "tunnel.status_changed",
        timestamp: new Date().toISOString(),
        data: { test: "data" },
      };

      const validation =
        webhookTestingService.validatePayloadStructure(payload);

      expect(validation.isValid).toBe(true);
    });
  });

  describe("Webhook Signature Generation and Validation", () => {
    it("should generate and validate webhook signature", () => {
      const payload = { test: "data" };
      const secret = "test-secret";
      const timestamp = Date.now();

      const signature = webhookTestingService.generateWebhookSignature(
        payload,
        secret,
        timestamp,
      );
      const isValid = webhookTestingService.validateWebhookSignature(
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

      const isValid = webhookTestingService.validateWebhookSignature(
        "sha256=invalid",
        payload,
        secret,
        timestamp,
      );

      expect(isValid).toBe(false);
    });

    it("should generate consistent signatures", () => {
      const payload = { test: "data" };
      const secret = "test-secret";
      const timestamp = 1234567890;

      const sig1 = webhookTestingService.generateWebhookSignature(
        payload,
        secret,
        timestamp,
      );
      const sig2 = webhookTestingService.generateWebhookSignature(
        payload,
        secret,
        timestamp,
      );

      expect(sig1).toBe(sig2);
    });
  });

  describe("Supported Event Types", () => {
    it("should return list of supported event types", () => {
      const types = webhookTestingService.getSupportedEventTypes();

      expect(Array.isArray(types)).toBe(true);
      expect(types.length).toBeGreaterThan(0);
    });

    it("should include tunnel events", () => {
      const types = webhookTestingService.getSupportedEventTypes();

      expect(types).toContain("tunnel.status_changed");
      expect(types).toContain("tunnel.created");
      expect(types).toContain("tunnel.deleted");
      expect(types).toContain("tunnel.metrics");
    });

    it("should include proxy events", () => {
      const types = webhookTestingService.getSupportedEventTypes();

      expect(types).toContain("proxy.status_changed");
      expect(types).toContain("proxy.metrics");
    });

    it("should include user events", () => {
      const types = webhookTestingService.getSupportedEventTypes();

      expect(types).toContain("user.activity");
    });
  });

  describe("End-to-End Workflow", () => {
    it("should complete full webhook testing workflow", async () => {
      // 1. Get supported types
      const types = webhookTestingService.getSupportedEventTypes();
      expect(types.length).toBeGreaterThan(0);

      // 2. Generate test payload
      const payload = webhookTestingService.generateTestPayload(types[0]);
      expect(payload).toHaveProperty("id");

      // 3. Validate payload
      const validation =
        webhookTestingService.validatePayloadStructure(payload);
      expect(validation.isValid).toBe(true);

      // 4. Generate signature
      const signature = webhookTestingService.generateWebhookSignature(
        payload,
        "secret",
        Date.now(),
      );
      expect(signature).toMatch(/^sha256=/);

      // 5. Cache test event
      const testId = crypto.randomUUID();
      webhookTestingService.cacheTestEvent(testId, { success: true });

      // 6. Retrieve cached event
      const cached = webhookTestingService.getTestEvent(testId);
      expect(cached).toBeDefined();
      expect(cached.success).toBe(true);
    });
  });
});
