/**


 * Tunnel Configuration Management Tests
 *
 * Tests for tunnel configuration endpoints:
 * - GET /api/tunnels/:id/config - Retrieve configuration
 * - PUT /api/tunnels/:id/config - Update configuration
 * - POST /api/tunnels/:id/config/reset - Reset to defaults
 *
 * Validates: Requirements 4.3
 * - Create tunnel config endpoints
 * - Support max connections, timeout, compression settings
 * - Implement config validation
 *
 * @fileoverview Tunnel configuration management tests
 * @version 1.0.0
 */

import { describe, it, expect } from "@jest/globals";
import {
  validateTunnelConfig,
  getDefaultTunnelConfig,
  mergeTunnelConfig,
  sanitizeTunnelConfig,
} from "../../services/api-backend/utils/tunnel-config-validation.js";

describe("Tunnel Configuration Management", () => {
  describe("Configuration Validation", () => {
    it("should validate valid configuration", () => {
      const config = {
        maxConnections: 100,
        timeout: 30000,
        compression: true,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it("should reject invalid maxConnections (not integer)", () => {
      const config = {
        maxConnections: "not-a-number",
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("maxConnections must be an integer");
    });

    it("should reject maxConnections below minimum (1)", () => {
      const config = {
        maxConnections: 0,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "maxConnections must be between 1 and 10000",
      );
    });

    it("should reject maxConnections above maximum (10000)", () => {
      const config = {
        maxConnections: 10001,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "maxConnections must be between 1 and 10000",
      );
    });

    it("should reject invalid timeout (not integer)", () => {
      const config = {
        timeout: "not-a-number",
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("timeout must be an integer");
    });

    it("should reject timeout below minimum (1000ms)", () => {
      const config = {
        timeout: 999,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "timeout must be between 1000ms and 300000ms (5 minutes)",
      );
    });

    it("should reject timeout above maximum (300000ms)", () => {
      const config = {
        timeout: 300001,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toContain(
        "timeout must be between 1000ms and 300000ms (5 minutes)",
      );
    });

    it("should reject invalid compression (not boolean)", () => {
      const config = {
        compression: "yes",
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("compression must be a boolean");
    });

    it("should accept partial configuration", () => {
      const config = {
        maxConnections: 200,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it("should accept empty configuration", () => {
      const config = {};

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it("should reject non-object configuration", () => {
      const result = validateTunnelConfig("not-an-object");

      expect(result.isValid).toBe(false);
      expect(result.errors).toContain("Configuration must be an object");
    });
  });

  describe("Configuration Defaults", () => {
    it("should return default configuration", () => {
      const defaults = getDefaultTunnelConfig();

      expect(defaults.maxConnections).toBe(100);
      expect(defaults.timeout).toBe(30000);
      expect(defaults.compression).toBe(true);
    });

    it("should merge user config with defaults", () => {
      const userConfig = {
        maxConnections: 200,
      };

      const merged = mergeTunnelConfig(userConfig);

      expect(merged.maxConnections).toBe(200);
      expect(merged.timeout).toBe(30000);
      expect(merged.compression).toBe(true);
    });

    it("should use defaults for null config", () => {
      const merged = mergeTunnelConfig(null);

      expect(merged.maxConnections).toBe(100);
      expect(merged.timeout).toBe(30000);
      expect(merged.compression).toBe(true);
    });

    it("should sanitize configuration values", () => {
      const config = {
        maxConnections: 20000, // Above max
        timeout: 500, // Below min
        compression: "yes", // Invalid
      };

      const sanitized = sanitizeTunnelConfig(config);

      expect(sanitized.maxConnections).toBe(10000); // Clamped to max
      expect(sanitized.timeout).toBe(1000); // Clamped to min
      expect(sanitized.compression).toBe(true); // Coerced to boolean
    });
  });

  describe("Configuration Boundary Values", () => {
    it("should accept minimum maxConnections (1)", () => {
      const config = {
        maxConnections: 1,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(true);
    });

    it("should accept maximum maxConnections (10000)", () => {
      const config = {
        maxConnections: 10000,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(true);
    });

    it("should accept minimum timeout (1000ms)", () => {
      const config = {
        timeout: 1000,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(true);
    });

    it("should accept maximum timeout (300000ms)", () => {
      const config = {
        timeout: 300000,
      };

      const result = validateTunnelConfig(config);

      expect(result.isValid).toBe(true);
    });
  });
});
