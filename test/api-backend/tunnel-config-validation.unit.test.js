/**
 * Tunnel Config Validation Unit Tests
 *
 * Tests for tunnel configuration validation utilities:
 * - validateTunnelConfig function
 *
 * Validates: Requirements 4.3
 * - Implements tunnel configuration management
 * - Supports max connections, timeout, compression settings
 *
 * @fileoverview Tunnel config validation tests
 * @version 1.0.0
 */

import { describe, it, expect } from "@jest/globals";
import {
  validateTunnelConfig,
  getDefaultTunnelConfig,
  mergeTunnelConfig,
  sanitizeTunnelConfig,
} from "../../services/api-backend/utils/tunnel-config-validation.js";

describe("validateTunnelConfig", () => {
  it("should return valid for empty config", () => {
    const result = validateTunnelConfig({});
    expect(result.isValid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  it("should return valid for undefined config", () => {
    const result = validateTunnelConfig(undefined);
    expect(result.isValid).toBe(false);
    expect(result.errors).toContain("Configuration must be an object");
  });

  it("should return valid for null config", () => {
    const result = validateTunnelConfig(null);
    expect(result.isValid).toBe(false);
  });

  it("should return valid for non-object config", () => {
    const result = validateTunnelConfig("string");
    expect(result.isValid).toBe(false);
  });

  describe("maxConnections validation", () => {
    it("should accept valid maxConnections", () => {
      const result = validateTunnelConfig({ maxConnections: 100 });
      expect(result.isValid).toBe(true);
    });

    it("should reject non-integer maxConnections", () => {
      const result = validateTunnelConfig({ maxConnections: 10.5 });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("maxConnections must be an integer");
    });

    it("should reject maxConnections below 1", () => {
      const result = validateTunnelConfig({ maxConnections: 0 });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "maxConnections must be between 1 and 10000",
      );
    });

    it("should reject maxConnections above 10000", () => {
      const result = validateTunnelConfig({ maxConnections: 10001 });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "maxConnections must be between 1 and 10000",
      );
    });

    it("should accept boundary value 1", () => {
      const result = validateTunnelConfig({ maxConnections: 1 });
      expect(result.isValid).toBe(true);
    });

    it("should accept boundary value 10000", () => {
      const result = validateTunnelConfig({ maxConnections: 10000 });
      expect(result.isValid).toBe(true);
    });
  });

  describe("timeout validation", () => {
    it("should accept valid timeout", () => {
      const result = validateTunnelConfig({ timeout: 30000 });
      expect(result.isValid).toBe(true);
    });

    it("should reject non-integer timeout", () => {
      const result = validateTunnelConfig({ timeout: 5000.5 });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("timeout must be an integer");
    });

    it("should reject timeout below 1000", () => {
      const result = validateTunnelConfig({ timeout: 500 });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "timeout must be between 1000ms and 300000ms (5 minutes)",
      );
    });

    it("should reject timeout above 300000", () => {
      const result = validateTunnelConfig({ timeout: 300001 });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "timeout must be between 1000ms and 300000ms (5 minutes)",
      );
    });

    it("should accept boundary value 1000", () => {
      const result = validateTunnelConfig({ timeout: 1000 });
      expect(result.isValid).toBe(true);
    });

    it("should accept boundary value 300000", () => {
      const result = validateTunnelConfig({ timeout: 300000 });
      expect(result.isValid).toBe(true);
    });
  });

  describe("compression validation", () => {
    it("should accept compression: true", () => {
      const result = validateTunnelConfig({ compression: true });
      expect(result.isValid).toBe(true);
    });

    it("should accept compression: false", () => {
      const result = validateTunnelConfig({ compression: false });
      expect(result.isValid).toBe(true);
    });

    it("should reject compression as string", () => {
      const result = validateTunnelConfig({ compression: "true" });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("compression must be a boolean");
    });

    it("should reject compression as number", () => {
      const result = validateTunnelConfig({ compression: 1 });
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("compression must be a boolean");
    });
  });

  it("should accept valid full config", () => {
    const result = validateTunnelConfig({
      maxConnections: 500,
      timeout: 60000,
      compression: true,
    });
    expect(result.isValid).toBe(true);
  });

  it("should return multiple errors for invalid config", () => {
    const result = validateTunnelConfig({
      maxConnections: -1,
      timeout: 999,
      compression: "yes",
    });
    expect(result.isValid).toBe(false);
    expect(result.errors.length).toBeGreaterThanOrEqual(3);
  });
});

describe("getDefaultTunnelConfig", () => {
  it("should return default configuration", () => {
    const defaults = getDefaultTunnelConfig();
    expect(defaults).toBeDefined();
    expect(defaults.maxConnections).toBeDefined();
    expect(defaults.timeout).toBeDefined();
    expect(defaults.compression).toBeDefined();
  });
});

describe("mergeTunnelConfig", () => {
  it("should merge user config with defaults", () => {
    const defaults = getDefaultTunnelConfig();
    const userConfig = { maxConnections: 500 };
    const merged = mergeTunnelConfig(userConfig);
    expect(merged.maxConnections).toBe(500);
  });
});

describe("sanitizeTunnelConfig", () => {
  it("should remove unknown keys", () => {
    const config = { maxConnections: 100, unknownKey: "bad" };
    const sanitized = sanitizeTunnelConfig(config);
    expect(sanitized.unknownKey).toBeUndefined();
  });
});
