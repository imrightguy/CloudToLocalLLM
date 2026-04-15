/**
 * WebhookEventFilter Unit Tests
 *
 * Tests for filter config validation, event pattern matching,
 * property filter validation, and event matching logic.
 */

import { jest, describe, it, expect } from "@jest/globals";

const { WebhookEventFilter } = await import(
  "../../services/api-backend/services/webhook-event-filter.js"
);

describe("WebhookEventFilter", () => {
  let filter;

  beforeEach(() => {
    filter = new WebhookEventFilter();
  });

  describe("constructor", () => {
    it("should initialize with null pool", () => {
      expect(filter.pool).toBeNull();
    });
  });

  describe("validateFilterConfig", () => {
    it("should return valid for null config", () => {
      const result = filter.validateFilterConfig(null);
      expect(result.isValid).toBe(true);
      expect(result.errors).toEqual([]);
    });

    it("should return valid for undefined config", () => {
      const result = filter.validateFilterConfig(undefined);
      expect(result.isValid).toBe(true);
      expect(result.errors).toEqual([]);
    });

    it("should return valid for empty object", () => {
      const result = filter.validateFilterConfig({});
      expect(result.isValid).toBe(true);
      expect(result.errors).toEqual([]);
    });

    it("should validate include type", () => {
      const result = filter.validateFilterConfig({ type: "include" });
      expect(result.isValid).toBe(true);
    });

    it("should validate exclude type", () => {
      const result = filter.validateFilterConfig({ type: "exclude" });
      expect(result.isValid).toBe(true);
    });

    it("should reject invalid type", () => {
      const result = filter.validateFilterConfig({ type: "invalid" });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        'Filter type must be "include" or "exclude"'
      );
    });

    it("should reject event patterns that is not an array", () => {
      const result = filter.validateFilterConfig({
        eventPatterns: "not-array",
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("Event patterns must be an array");
    });

    it("should reject empty string event pattern", () => {
      const result = filter.validateFilterConfig({
        eventPatterns: ["valid.pattern", ""],
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "Event pattern at index 1 must be a non-empty string"
      );
    });

    it("should reject non-string event pattern", () => {
      const result = filter.validateFilterConfig({
        eventPatterns: [123],
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "Event pattern at index 0 must be a non-empty string"
      );
    });

    it("should reject invalid event pattern format", () => {
      const result = filter.validateFilterConfig({
        eventPatterns: ["invalid pattern!@#"],
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "Invalid event pattern format: invalid pattern!@#"
      );
    });

    it("should accept valid event patterns", () => {
      const result = filter.validateFilterConfig({
        eventPatterns: ["tunnel.status_changed", "tunnel.*", "*.created"],
      });
      expect(result.isValid).toBe(true);
    });

    it("should reject property filters that is an array", () => {
      const result = filter.validateFilterConfig({
        propertyFilters: [],
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("Property filters must be an object");
    });

    it("should reject property filters that is a string", () => {
      const result = filter.validateFilterConfig({
        propertyFilters: "not-object",
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("Property filters must be an object");
    });

    it("should reject invalid property filter operator", () => {
      const result = filter.validateFilterConfig({
        propertyFilters: {
          status: { operator: "invalid", value: "active" },
        },
      });
      expect(result.isValid).toBe(false);
    });

    it("should accept valid property filters", () => {
      const result = filter.validateFilterConfig({
        propertyFilters: {
          status: { operator: "equals", value: "active" },
          name: { operator: "contains", value: "test" },
        },
      });
      expect(result.isValid).toBe(true);
    });

    it("should reject rate limit that is not an object", () => {
      const result = filter.validateFilterConfig({
        rateLimit: "not-object",
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("Rate limit must be an object");
    });

    it("should reject non-number maxEvents in rate limit", () => {
      const result = filter.validateFilterConfig({
        rateLimit: { maxEvents: "not-number" },
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "Rate limit maxEvents must be a number"
      );
    });

    it("should reject non-number windowSeconds in rate limit", () => {
      const result = filter.validateFilterConfig({
        rateLimit: { windowSeconds: "not-number" },
      });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "Rate limit windowSeconds must be a number"
      );
    });

    it("should accept valid rate limit", () => {
      const result = filter.validateFilterConfig({
        rateLimit: { maxEvents: 100, windowSeconds: 60 },
      });
      expect(result.isValid).toBe(true);
    });

    it("should collect multiple errors", () => {
      const result = filter.validateFilterConfig({
        type: "bad",
        eventPatterns: [123],
        rateLimit: "bad",
      });
      expect(result.isValid).toBe(false);
      expect(result.errors.length).toBeGreaterThanOrEqual(3);
    });
  });

  describe("_isValidEventPattern", () => {
    it("should accept simple event names", () => {
      expect(filter._isValidEventPattern("tunnel")).toBe(true);
    });

    it("should accept dotted event names", () => {
      expect(filter._isValidEventPattern("tunnel.status_changed")).toBe(true);
    });

    it("should accept wildcard patterns", () => {
      expect(filter._isValidEventPattern("tunnel.*")).toBe(true);
    });

    it("should accept global wildcard", () => {
      expect(filter._isValidEventPattern("*")).toBe(true);
    });

    it("should accept prefix wildcard", () => {
      expect(filter._isValidEventPattern("*.status_changed")).toBe(true);
    });

    it("should reject patterns with spaces", () => {
      expect(filter._isValidEventPattern("tunnel event")).toBe(false);
    });

    it("should reject patterns with special characters", () => {
      expect(filter._isValidEventPattern("tunnel@event")).toBe(false);
    });
  });

  describe("_isValidPropertyFilter", () => {
    it("should reject non-object filter", () => {
      expect(filter._isValidPropertyFilter("string")).toBe(false);
    });

    it("should reject array filter", () => {
      expect(filter._isValidPropertyFilter([])).toBe(false);
    });

    it("should reject invalid operator", () => {
      expect(
        filter._isValidPropertyFilter({ operator: "bad", value: "test" })
      ).toBe(false);
    });

    it("should accept equals with string value", () => {
      expect(
        filter._isValidPropertyFilter({ operator: "equals", value: "active" })
      ).toBe(true);
    });

    it("should accept equals with number value", () => {
      expect(
        filter._isValidPropertyFilter({ operator: "equals", value: 42 })
      ).toBe(true);
    });

    it("should accept equals with boolean value", () => {
      expect(
        filter._isValidPropertyFilter({ operator: "equals", value: true })
      ).toBe(true);
    });

    it("should accept contains operator", () => {
      expect(
        filter._isValidPropertyFilter({ operator: "contains", value: "test" })
      ).toBe(true);
    });

    it("should accept startsWith operator", () => {
      expect(
        filter._isValidPropertyFilter({
          operator: "startsWith",
          value: "tun",
        })
      ).toBe(true);
    });

    it("should accept endsWith operator", () => {
      expect(
        filter._isValidPropertyFilter({ operator: "endsWith", value: "nel" })
      ).toBe(true);
    });

    it("should accept in operator with array value", () => {
      expect(
        filter._isValidPropertyFilter({
          operator: "in",
          value: ["a", "b"],
        })
      ).toBe(true);
    });

    it("should reject in operator with non-array value", () => {
      expect(
        filter._isValidPropertyFilter({ operator: "in", value: "not-array" })
      ).toBe(false);
    });

    it("should accept regex operator with valid regex", () => {
      expect(
        filter._isValidPropertyFilter({ operator: "regex", value: "^test.*$" })
      ).toBe(true);
    });

    it("should reject regex operator with invalid regex", () => {
      expect(
        filter._isValidPropertyFilter({ operator: "regex", value: "[invalid" })
      ).toBe(false);
    });
  });

  describe("matchesFilter", () => {
    it("should return true for null filter config", () => {
      expect(filter.matchesFilter({ type: "test" }, null)).toBe(true);
    });

    it("should return true for undefined filter config", () => {
      expect(filter.matchesFilter({ type: "test" }, undefined)).toBe(true);
    });

    it("should match event with include type", () => {
      const result = filter.matchesFilter(
        { type: "tunnel.created" },
        { type: "include", eventPatterns: ["tunnel.*"] }
      );
      expect(result).toBe(true);
    });

    it("should reject event not matching include patterns", () => {
      const result = filter.matchesFilter(
        { type: "user.login" },
        { type: "include", eventPatterns: ["tunnel.*"] }
      );
      expect(result).toBe(false);
    });

    it("should reject event matching exclude patterns", () => {
      const result = filter.matchesFilter(
        { type: "tunnel.created" },
        { type: "exclude", eventPatterns: ["tunnel.*"] }
      );
      expect(result).toBe(false);
    });

    it("should allow event not matching exclude patterns", () => {
      const result = filter.matchesFilter(
        { type: "user.login" },
        { type: "exclude", eventPatterns: ["tunnel.*"] }
      );
      expect(result).toBe(true);
    });

    it("should match with property filter equals", () => {
      const result = filter.matchesFilter(
        { type: "test", status: "active" },
        {
          propertyFilters: {
            status: { operator: "equals", value: "active" },
          },
        }
      );
      expect(result).toBe(true);
    });

    it("should reject non-matching property filter", () => {
      const result = filter.matchesFilter(
        { type: "test", status: "inactive" },
        {
          propertyFilters: {
            status: { operator: "equals", value: "active" },
          },
        }
      );
      expect(result).toBe(false);
    });

    it("should match with nested property filter", () => {
      const result = filter.matchesFilter(
        { type: "test", data: { status: "active" } },
        {
          propertyFilters: {
            "data.status": { operator: "equals", value: "active" },
          },
        }
      );
      expect(result).toBe(true);
    });

    it("should reject when nested property does not exist", () => {
      const result = filter.matchesFilter(
        { type: "test" },
        {
          propertyFilters: {
            "data.status": { operator: "equals", value: "active" },
          },
        }
      );
      expect(result).toBe(false);
    });

    it("should default to include type when type is not specified", () => {
      const result = filter.matchesFilter(
        { type: "tunnel.created" },
        { eventPatterns: ["tunnel.*"] }
      );
      expect(result).toBe(true);
    });

    it("should match with global wildcard pattern", () => {
      const result = filter.matchesFilter(
        { type: "anything.here" },
        { eventPatterns: ["*"] }
      );
      expect(result).toBe(true);
    });

    it("should combine event patterns and property filters", () => {
      const result = filter.matchesFilter(
        { type: "tunnel.created", region: "us-east" },
        {
          type: "include",
          eventPatterns: ["tunnel.*"],
          propertyFilters: {
            region: { operator: "equals", value: "us-east" },
          },
        }
      );
      expect(result).toBe(true);
    });

    it("should reject when event matches but property does not", () => {
      const result = filter.matchesFilter(
        { type: "tunnel.created", region: "eu-west" },
        {
          type: "include",
          eventPatterns: ["tunnel.*"],
          propertyFilters: {
            region: { operator: "equals", value: "us-east" },
          },
        }
      );
      expect(result).toBe(false);
    });
  });

  describe("_matchesEventPattern", () => {
    it("should match exact event type", () => {
      expect(
        filter._matchesEventPattern("tunnel.created", ["tunnel.created"])
      ).toBe(true);
    });

    it("should match wildcard suffix", () => {
      expect(
        filter._matchesEventPattern("tunnel.created", ["tunnel.*"])
      ).toBe(true);
    });

    it("should match wildcard prefix", () => {
      expect(
        filter._matchesEventPattern("tunnel.created", ["*.created"])
      ).toBe(true);
    });

    it("should match global wildcard", () => {
      expect(filter._matchesEventPattern("any.event", ["*"])).toBe(true);
    });

    it("should not match non-matching pattern", () => {
      expect(
        filter._matchesEventPattern("user.login", ["tunnel.*"])
      ).toBe(false);
    });

    it("should match any of multiple patterns", () => {
      expect(
        filter._matchesEventPattern("tunnel.created", [
          "user.*",
          "tunnel.created",
        ])
      ).toBe(true);
    });

    it("should be case insensitive", () => {
      expect(
        filter._matchesEventPattern("TUNNEL.CREATED", ["tunnel.*"])
      ).toBe(true);
    });
  });

  describe("_getNestedProperty", () => {
    it("should get top-level property", () => {
      expect(filter._getNestedProperty({ name: "test" }, "name")).toBe("test");
    });

    it("should get nested property", () => {
      expect(
        filter._getNestedProperty({ a: { b: "deep" } }, "a.b")
      ).toBe("deep");
    });

    it("should get deeply nested property", () => {
      expect(
        filter._getNestedProperty({ a: { b: { c: 42 } } }, "a.b.c")
      ).toBe(42);
    });

    it("should return undefined for missing property", () => {
      expect(filter._getNestedProperty({ a: 1 }, "b")).toBeUndefined();
    });

    it("should return undefined for missing nested path", () => {
      expect(
        filter._getNestedProperty({ a: { b: 1 } }, "a.c.d")
      ).toBeUndefined();
    });
  });

  describe("_matchesPropertyFilter", () => {
    it("should match equals operator", () => {
      expect(
        filter._matchesPropertyFilter("active", {
          operator: "equals",
          value: "active",
        })
      ).toBe(true);
    });

    it("should not match equals with different value", () => {
      expect(
        filter._matchesPropertyFilter("inactive", {
          operator: "equals",
          value: "active",
        })
      ).toBe(false);
    });

    it("should match contains operator", () => {
      expect(
        filter._matchesPropertyFilter("hello world", {
          operator: "contains",
          value: "world",
        })
      ).toBe(true);
    });

    it("should not match contains when substring absent", () => {
      expect(
        filter._matchesPropertyFilter("hello", {
          operator: "contains",
          value: "world",
        })
      ).toBe(false);
    });

    it("should match startsWith operator", () => {
      expect(
        filter._matchesPropertyFilter("tunnel.created", {
          operator: "startsWith",
          value: "tunnel",
        })
      ).toBe(true);
    });

    it("should not match startsWith when prefix differs", () => {
      expect(
        filter._matchesPropertyFilter("user.login", {
          operator: "startsWith",
          value: "tunnel",
        })
      ).toBe(false);
    });

    it("should match endsWith operator", () => {
      expect(
        filter._matchesPropertyFilter("tunnel.created", {
          operator: "endsWith",
          value: "created",
        })
      ).toBe(true);
    });

    it("should match in operator", () => {
      expect(
        filter._matchesPropertyFilter("active", {
          operator: "in",
          value: ["active", "pending"],
        })
      ).toBe(true);
    });

    it("should not match in operator when value not in list", () => {
      expect(
        filter._matchesPropertyFilter("deleted", {
          operator: "in",
          value: ["active", "pending"],
        })
      ).toBe(false);
    });

    it("should match regex operator", () => {
      expect(
        filter._matchesPropertyFilter("tunnel-123", {
          operator: "regex",
          value: "^tunnel-\\d+$",
        })
      ).toBe(true);
    });

    it("should not match regex operator when no match", () => {
      expect(
        filter._matchesPropertyFilter("user-abc", {
          operator: "regex",
          value: "^tunnel-\\d+$",
        })
      ).toBe(false);
    });

    it("should return false for unknown operator", () => {
      expect(
        filter._matchesPropertyFilter("any", {
          operator: "unknown",
          value: "any",
        })
      ).toBe(false);
    });

    it("should handle numeric values with contains", () => {
      expect(
        filter._matchesPropertyFilter(12345, {
          operator: "contains",
          value: "34",
        })
      ).toBe(true);
    });
  });
});
