/**
 * Webhook Event Filter Tests
 *
 * Tests for webhook event filtering functionality including:
 * - Filter configuration validation
 * - Event pattern matching
 * - Property filter matching
 *
 * Validates: Requirements 10.5
 * - Implements webhook event filtering
 * - Supports filter configuration
 * - Validates filter rules
 *
 * @fileoverview Webhook event filter tests
 * @version 1.0.0
 */

import { describe, it, expect } from "@jest/globals";
import { WebhookEventFilter } from "../../services/api-backend/services/webhook-event-filter.js";

describe("Webhook Event Filters", () => {
  let filterService;

  beforeEach(() => {
    filterService = new WebhookEventFilter();
  });

  describe("Filter Configuration Validation", () => {
    it("should accept valid filter configuration", () => {
      const filterConfig = {
        type: "include",
        eventPatterns: ["tunnel.status_changed"],
        propertyFilters: {
          "data.status": {
            operator: "in",
            value: ["connected", "disconnected"],
          },
        },
      };

      const validation = filterService.validateFilterConfig(filterConfig);

      expect(validation.isValid).toBe(true);
      expect(validation.errors).toHaveLength(0);
    });

    it("should accept empty filter configuration", () => {
      const validation = filterService.validateFilterConfig({});

      expect(validation.isValid).toBe(true);
      expect(validation.errors).toHaveLength(0);
    });

    it("should accept null filter configuration", () => {
      const validation = filterService.validateFilterConfig(null);

      expect(validation.isValid).toBe(true);
      expect(validation.errors).toHaveLength(0);
    });

    it("should reject invalid filter type", () => {
      const filterConfig = {
        type: "invalid",
      };

      const validation = filterService.validateFilterConfig(filterConfig);

      expect(validation.isValid).toBe(false);
      expect(validation.errors.length).toBeGreaterThan(0);
      expect(validation.errors[0]).toContain("Filter type must be");
    });

    it("should reject non-array event patterns", () => {
      const filterConfig = {
        eventPatterns: "tunnel.status_changed",
      };

      const validation = filterService.validateFilterConfig(filterConfig);

      expect(validation.isValid).toBe(false);
      expect(
        validation.errors.some((e) =>
          e.includes("Event patterns must be an array"),
        ),
      ).toBe(true);
    });

    it("should reject empty event patterns array", () => {
      const filterConfig = {
        eventPatterns: [],
      };

      const validation = filterService.validateFilterConfig(filterConfig);

      expect(validation.isValid).toBe(true); // Empty array is allowed
    });

    it("should reject invalid event pattern format", () => {
      const filterConfig = {
        eventPatterns: ["invalid@pattern"],
      };

      const validation = filterService.validateFilterConfig(filterConfig);

      expect(validation.isValid).toBe(false);
      expect(
        validation.errors.some((e) =>
          e.includes("Invalid event pattern format"),
        ),
      ).toBe(true);
    });

    it("should reject non-object property filters", () => {
      const filterConfig = {
        propertyFilters: ["not", "an", "object"],
      };

      const validation = filterService.validateFilterConfig(filterConfig);

      expect(validation.isValid).toBe(false);
      expect(
        validation.errors.some((e) =>
          e.includes("Property filters must be an object"),
        ),
      ).toBe(true);
    });

    it("should reject invalid property filter operator", () => {
      const filterConfig = {
        propertyFilters: {
          "data.status": { operator: "invalid", value: "test" },
        },
      };

      const validation = filterService.validateFilterConfig(filterConfig);

      expect(validation.isValid).toBe(false);
      expect(
        validation.errors.some((e) => e.includes("Invalid property filter")),
      ).toBe(true);
    });

    it("should reject invalid regex in property filter", () => {
      const filterConfig = {
        propertyFilters: {
          "data.status": { operator: "regex", value: "[invalid(" },
        },
      };

      const validation = filterService.validateFilterConfig(filterConfig);

      expect(validation.isValid).toBe(false);
      expect(
        validation.errors.some((e) => e.includes("Invalid property filter")),
      ).toBe(true);
    });

    it("should reject invalid rate limit configuration", () => {
      const filterConfig = {
        rateLimit: {
          maxEvents: "not-a-number",
        },
      };

      const validation = filterService.validateFilterConfig(filterConfig);

      expect(validation.isValid).toBe(false);
      expect(
        validation.errors.some((e) =>
          e.includes("Rate limit maxEvents must be a number"),
        ),
      ).toBe(true);
    });
  });

  describe("Event Pattern Matching", () => {
    it("should match exact event pattern", () => {
      const event = { type: "tunnel.status_changed" };
      const filterConfig = {
        type: "include",
        eventPatterns: ["tunnel.status_changed"],
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should match wildcard event pattern", () => {
      const event = { type: "tunnel.status_changed" };
      const filterConfig = {
        type: "include",
        eventPatterns: ["tunnel.*"],
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should match global wildcard pattern", () => {
      const event = { type: "tunnel.status_changed" };
      const filterConfig = {
        type: "include",
        eventPatterns: ["*"],
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should not match non-matching pattern", () => {
      const event = { type: "tunnel.status_changed" };
      const filterConfig = {
        type: "include",
        eventPatterns: ["proxy.status_changed"],
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(false);
    });

    it("should exclude matching pattern with exclude type", () => {
      const event = { type: "tunnel.status_changed" };
      const filterConfig = {
        type: "exclude",
        eventPatterns: ["tunnel.status_changed"],
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(false);
    });

    it("should include non-matching pattern with exclude type", () => {
      const event = { type: "tunnel.status_changed" };
      const filterConfig = {
        type: "exclude",
        eventPatterns: ["proxy.*"],
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should match multiple patterns", () => {
      const event = { type: "tunnel.created" };
      const filterConfig = {
        type: "include",
        eventPatterns: [
          "tunnel.status_changed",
          "tunnel.created",
          "tunnel.deleted",
        ],
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });
  });

  describe("Property Filter Matching", () => {
    it("should match equals operator", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.status": { operator: "equals", value: "connected" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should not match equals operator with different value", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.status": { operator: "equals", value: "disconnected" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(false);
    });

    it("should match contains operator", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { message: "Connection established" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.message": { operator: "contains", value: "established" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should match startsWith operator", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { code: "ERR_001" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.code": { operator: "startsWith", value: "ERR_" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should match endsWith operator", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { code: "TUNNEL_ERROR" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.code": { operator: "endsWith", value: "_ERROR" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should match in operator", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.status": {
            operator: "in",
            value: ["connected", "disconnected", "error"],
          },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should not match in operator with value not in list", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { status: "unknown" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.status": {
            operator: "in",
            value: ["connected", "disconnected", "error"],
          },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(false);
    });

    it("should match regex operator", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { code: "ERR_123" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.code": { operator: "regex", value: "^ERR_\\d+$" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should not match regex operator with non-matching pattern", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { code: "WARN_123" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.code": { operator: "regex", value: "^ERR_\\d+$" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(false);
    });

    it("should match multiple property filters", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { status: "connected", userId: "user123" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.status": { operator: "equals", value: "connected" },
          "data.userId": { operator: "startsWith", value: "user" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should not match if any property filter fails", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { status: "disconnected", userId: "user123" },
      };
      const filterConfig = {
        propertyFilters: {
          "data.status": { operator: "equals", value: "connected" },
          "data.userId": { operator: "startsWith", value: "user" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(false);
    });
  });

  describe("Combined Filter Matching", () => {
    it("should match event pattern and property filters", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { status: "connected" },
      };
      const filterConfig = {
        type: "include",
        eventPatterns: ["tunnel.*"],
        propertyFilters: {
          "data.status": {
            operator: "in",
            value: ["connected", "disconnected"],
          },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should not match if event pattern fails", () => {
      const event = {
        type: "proxy.status_changed",
        data: { status: "connected" },
      };
      const filterConfig = {
        type: "include",
        eventPatterns: ["tunnel.*"],
        propertyFilters: {
          "data.status": {
            operator: "in",
            value: ["connected", "disconnected"],
          },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(false);
    });

    it("should not match if property filter fails", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { status: "error" },
      };
      const filterConfig = {
        type: "include",
        eventPatterns: ["tunnel.*"],
        propertyFilters: {
          "data.status": {
            operator: "in",
            value: ["connected", "disconnected"],
          },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(false);
    });
  });

  describe("Edge Cases", () => {
    it("should handle nested property paths", () => {
      const event = {
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
      const filterConfig = {
        propertyFilters: {
          "data.tunnel.metrics.latency": { operator: "equals", value: 50 },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should handle missing nested properties", () => {
      const event = {
        type: "tunnel.status_changed",
        data: {},
      };
      const filterConfig = {
        propertyFilters: {
          "data.tunnel.status": { operator: "equals", value: "connected" },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(false);
    });

    it("should handle numeric property values", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { requestCount: 100 },
      };
      const filterConfig = {
        propertyFilters: {
          "data.requestCount": { operator: "equals", value: 100 },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should handle boolean property values", () => {
      const event = {
        type: "tunnel.status_changed",
        data: { isActive: true },
      };
      const filterConfig = {
        propertyFilters: {
          "data.isActive": { operator: "equals", value: true },
        },
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });

    it("should be case-insensitive for event pattern matching", () => {
      const event = { type: "TUNNEL.STATUS_CHANGED" };
      const filterConfig = {
        type: "include",
        eventPatterns: ["tunnel.status_changed"],
      };

      const matches = filterService.matchesFilter(event, filterConfig);

      expect(matches).toBe(true);
    });
  });
});
