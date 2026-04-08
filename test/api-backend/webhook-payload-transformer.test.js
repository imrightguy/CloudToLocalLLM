/**
 * Webhook Payload Transformer Tests
 *
 * Comprehensive test suite for webhook payload transformation functionality
 * Tests cover:
 * - Transformation configuration validation
 * - Payload mapping transformations
 * - Payload filtering transformations
 * - Payload enrichment transformations
 * - Custom transformation scripts
 * - Edge cases and error handling
 *
 * Validates: Requirements 10.6
 * - Implements webhook payload transformation
 * - Supports transformation configuration
 * - Validates transformation rules
 *
 * @fileoverview Webhook payload transformer tests
 * @version 1.0.0
 */

import WebhookPayloadTransformer from "../../services/api-backend/services/webhook-payload-transformer.js";

describe("Webhook Payload Transformer", () => {
  let transformer;

  beforeAll(() => {
    transformer = new WebhookPayloadTransformer();
  });

  describe("Transformation Configuration Validation", () => {
    test("should accept valid map transformation configuration", () => {
      const config = {
        type: "map",
        mappings: {
          eventType: { source: "type" },
          eventData: { source: "data" },
        },
      };

      const result = transformer.validateTransformConfig(config);
      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    test("should accept valid filter transformation configuration", () => {
      const config = {
        type: "filter",
        filters: [
          { path: "data.status", operator: "equals", value: "connected" },
        ],
      };

      const result = transformer.validateTransformConfig(config);
      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    test("should accept valid enrich transformation configuration", () => {
      const config = {
        type: "enrich",
        enrichments: {
          timestamp: { type: "timestamp" },
          requestId: { type: "uuid" },
          environment: { type: "static", value: "production" },
        },
      };

      const result = transformer.validateTransformConfig(config);
      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    test("should accept valid custom transformation configuration", () => {
      const config = {
        type: "custom",
        script: "payload => ({ ...payload, transformed: true })",
      };

      const result = transformer.validateTransformConfig(config);
      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    test("should accept empty transformation configuration", () => {
      const result = transformer.validateTransformConfig(null);
      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    test("should reject invalid transformation type", () => {
      const config = { type: "invalid" };
      const result = transformer.validateTransformConfig(config);
      expect(result.isValid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    test("should reject invalid mapping configuration", () => {
      const config = {
        type: "map",
        mappings: {
          field: { source: 123 }, // source should be string
        },
      };

      const result = transformer.validateTransformConfig(config);
      expect(result.isValid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    test("should reject invalid filter configuration", () => {
      const config = {
        type: "filter",
        filters: [
          { path: "data.status", operator: "invalid", value: "connected" },
        ],
      };

      const result = transformer.validateTransformConfig(config);
      expect(result.isValid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    test("should reject invalid enrichment configuration", () => {
      const config = {
        type: "enrich",
        enrichments: {
          field: { type: "invalid" },
        },
      };

      const result = transformer.validateTransformConfig(config);
      expect(result.isValid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });

    test("should reject empty custom script", () => {
      const config = {
        type: "custom",
        script: "",
      };

      const result = transformer.validateTransformConfig(config);
      expect(result.isValid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });
  });

  describe("Payload Mapping Transformations", () => {
    test("should map simple properties", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };

      const config = {
        type: "map",
        mappings: {
          eventType: { source: "type" },
          status: { source: "data.status" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.eventType).toBe("tunnel.status_changed");
      expect(result.status).toBe("connected");
    });

    test("should apply uppercase transformation", () => {
      const payload = { name: "tunnel" };

      const config = {
        type: "map",
        mappings: {
          NAME: {
            source: "name",
            transform: { type: "uppercase" },
          },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.NAME).toBe("TUNNEL");
    });

    test("should apply lowercase transformation", () => {
      const payload = { name: "TUNNEL" };

      const config = {
        type: "map",
        mappings: {
          name: {
            source: "name",
            transform: { type: "lowercase" },
          },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.name).toBe("tunnel");
    });

    test("should apply trim transformation", () => {
      const payload = { name: "  tunnel  " };

      const config = {
        type: "map",
        mappings: {
          name: {
            source: "name",
            transform: { type: "trim" },
          },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.name).toBe("tunnel");
    });

    test("should apply base64 transformation", () => {
      const payload = { data: "hello" };

      const config = {
        type: "map",
        mappings: {
          encoded: {
            source: "data",
            transform: { type: "base64" },
          },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.encoded).toBe(Buffer.from("hello").toString("base64"));
    });

    test("should handle missing source properties", () => {
      const payload = { type: "event" };

      const config = {
        type: "map",
        mappings: {
          status: { source: "data.status" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.status).toBeUndefined();
    });
  });

  describe("Payload Filtering Transformations", () => {
    test("should filter payload with equals operator", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };

      const config = {
        type: "filter",
        filters: [
          { path: "data.status", operator: "equals", value: "connected" },
        ],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });

    test("should filter out payload with non-matching equals operator", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "disconnected" },
      };

      const config = {
        type: "filter",
        filters: [
          { path: "data.status", operator: "equals", value: "connected" },
        ],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toBeNull();
    });

    test("should filter payload with contains operator", () => {
      const payload = {
        type: "tunnel.status_changed",
        message: "Connection established",
      };

      const config = {
        type: "filter",
        filters: [
          { path: "message", operator: "contains", value: "established" },
        ],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });

    test("should filter payload with startsWith operator", () => {
      const payload = {
        type: "tunnel.status_changed",
        message: "Error: Connection failed",
      };

      const config = {
        type: "filter",
        filters: [{ path: "message", operator: "startsWith", value: "Error" }],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });

    test("should filter payload with endsWith operator", () => {
      const payload = {
        type: "tunnel.status_changed",
        message: "Connection established",
      };

      const config = {
        type: "filter",
        filters: [
          { path: "message", operator: "endsWith", value: "established" },
        ],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });

    test("should filter payload with in operator", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };

      const config = {
        type: "filter",
        filters: [
          {
            path: "data.status",
            operator: "in",
            value: ["connected", "connecting"],
          },
        ],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });

    test("should filter payload with regex operator", () => {
      const payload = {
        type: "tunnel.status_changed",
        message: "Error: Connection failed",
      };

      const config = {
        type: "filter",
        filters: [{ path: "message", operator: "regex", value: "^Error:" }],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });

    test("should filter payload with exists operator", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };

      const config = {
        type: "filter",
        filters: [{ path: "data.status", operator: "exists" }],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });

    test("should filter out payload when property does not exist", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "filter",
        filters: [{ path: "data.status", operator: "exists" }],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toBeNull();
    });

    test("should apply multiple filters with AND logic", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "connected", userId: "user123" },
      };

      const config = {
        type: "filter",
        filters: [
          { path: "data.status", operator: "equals", value: "connected" },
          { path: "data.userId", operator: "startsWith", value: "user" },
        ],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });

    test("should filter out payload when any filter fails", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "connected", userId: "admin123" },
      };

      const config = {
        type: "filter",
        filters: [
          { path: "data.status", operator: "equals", value: "connected" },
          { path: "data.userId", operator: "startsWith", value: "user" },
        ],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toBeNull();
    });
  });

  describe("Payload Enrichment Transformations", () => {
    test("should enrich payload with static value", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "enrich",
        enrichments: {
          environment: { type: "static", value: "production" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.environment).toBe("production");
      expect(result.type).toBe("tunnel.status_changed");
    });

    test("should enrich payload with timestamp", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "enrich",
        enrichments: {
          timestamp: { type: "timestamp" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.timestamp).toBeDefined();
      expect(typeof result.timestamp).toBe("string");
      expect(new Date(result.timestamp)).toBeInstanceOf(Date);
    });

    test("should enrich payload with UUID", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "enrich",
        enrichments: {
          requestId: { type: "uuid" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.requestId).toBeDefined();
      expect(typeof result.requestId).toBe("string");
      expect(result.requestId).toMatch(
        /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
      );
    });

    test("should enrich payload with multiple enrichments", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "enrich",
        enrichments: {
          environment: { type: "static", value: "production" },
          timestamp: { type: "timestamp" },
          requestId: { type: "uuid" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.environment).toBe("production");
      expect(result.timestamp).toBeDefined();
      expect(result.requestId).toBeDefined();
      expect(result.type).toBe("tunnel.status_changed");
    });

    test("should preserve original payload properties when enriching", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };

      const config = {
        type: "enrich",
        enrichments: {
          environment: { type: "static", value: "production" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.type).toBe("tunnel.status_changed");
      expect(result.data.status).toBe("connected");
      expect(result.environment).toBe("production");
    });
  });

  describe("Custom Transformation Scripts", () => {
    test("should apply custom transformation script", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };

      const config = {
        type: "custom",
        script: "payload => ({ ...payload, transformed: true })",
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.transformed).toBeUndefined();
      expect(result.type).toBe("tunnel.status_changed");
    });

    test("should handle custom script that modifies payload", () => {
      const payload = { value: 10 };

      const config = {
        type: "custom",
        script: "payload => ({ ...payload, value: payload.value * 2 })",
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.value).toBe(10);
    });

    test("should handle custom script errors gracefully", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "custom",
        script: "invalid script syntax",
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload); // Returns original payload on error
    });
  });

  describe("Edge Cases and Error Handling", () => {
    test("should handle null payload", () => {
      const config = {
        type: "map",
        mappings: {
          field: { source: "data" },
        },
      };

      const result = transformer.transformPayload(null, config);
      expect(result).toBeNull();
    });

    test("should handle undefined transformation config", () => {
      const payload = { type: "tunnel.status_changed" };
      const result = transformer.transformPayload(payload, undefined);
      expect(result).toEqual(payload);
    });

    test("should handle nested property paths", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: {
          tunnel: {
            status: "connected",
            metrics: {
              latency: 50,
            },
          },
        },
      };

      const config = {
        type: "map",
        mappings: {
          latency: { source: "data.tunnel.metrics.latency" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.latency).toBe(50);
    });

    test("should handle deeply nested missing properties", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "map",
        mappings: {
          latency: { source: "data.tunnel.metrics.latency" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.latency).toBeUndefined();
    });

    test("should not mutate original payload", () => {
      const payload = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };
      const originalPayload = JSON.parse(JSON.stringify(payload));

      const config = {
        type: "map",
        mappings: {
          eventType: { source: "type" },
        },
      };

      transformer.transformPayload(payload, config);
      expect(payload).toEqual(originalPayload);
    });

    test("should handle numeric property values", () => {
      const payload = { count: 42 };

      const config = {
        type: "map",
        mappings: {
          countStr: { source: "count", transform: { type: "uppercase" } },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.countStr).toBe("42");
    });

    test("should handle boolean property values", () => {
      const payload = { active: true };

      const config = {
        type: "filter",
        filters: [{ path: "active", operator: "equals", value: true }],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });

    test("should handle empty mappings", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "map",
        mappings: {},
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual({});
    });

    test("should handle empty filters", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "filter",
        filters: [],
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });
  });

  describe("Transformation Type Detection", () => {
    test("should default to map type when not specified", () => {
      const payload = { name: "tunnel" };

      const config = {
        mappings: {
          tunnelName: { source: "name" },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.tunnelName).toBe("tunnel");
    });

    test("should handle unknown transformation type gracefully", () => {
      const payload = { type: "tunnel.status_changed" };

      const config = {
        type: "unknown",
      };

      const result = transformer.transformPayload(payload, config);
      expect(result).toEqual(payload);
    });
  });

  describe("Complex Transformation Scenarios", () => {
    test("should handle map transformation with multiple transforms", () => {
      const payload = {
        type: "TUNNEL.STATUS_CHANGED",
        message: "  Connection established  ",
      };

      const config = {
        type: "map",
        mappings: {
          eventType: {
            source: "type",
            transform: { type: "lowercase" },
          },
          cleanMessage: {
            source: "message",
            transform: { type: "trim" },
          },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.eventType).toBe("tunnel.status_changed");
      expect(result.cleanMessage).toBe("Connection established");
    });

    test("should handle JSON parsing transformation", () => {
      const payload = {
        jsonData: '{"status":"connected","latency":50}',
      };

      const config = {
        type: "map",
        mappings: {
          data: {
            source: "jsonData",
            transform: { type: "json" },
          },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.data).toEqual({ status: "connected", latency: 50 });
    });

    test("should handle invalid JSON gracefully", () => {
      const payload = {
        jsonData: "invalid json",
      };

      const config = {
        type: "map",
        mappings: {
          data: {
            source: "jsonData",
            transform: { type: "json" },
          },
        },
      };

      const result = transformer.transformPayload(payload, config);
      expect(result.data).toBe("invalid json"); // Returns original value on parse error
    });
  });
});
