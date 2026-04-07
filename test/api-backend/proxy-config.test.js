import { jest, describe, it, expect, beforeEach } from "@jest/globals";
import { ProxyConfigService } from "../../services/api-backend/services/proxy-config-service.js";

describe("ProxyConfigService", () => {
  let service;
  let mockDb;

  beforeEach(() => {
    // Mock database
    mockDb = {
      query: jest.fn(),
    };

    service = new ProxyConfigService(mockDb);
  });

  describe("Configuration Validation", () => {
    it("should validate correct configuration", () => {
      const config = {
        max_connections: 100,
        timeout_seconds: 30,
        compression_enabled: true,
        compression_level: 6,
      };

      const result = service.validateConfig(config);

      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it("should reject invalid field types", () => {
      const config = {
        max_connections: "not a number",
      };

      const result = service.validateConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0].field).toBe("max_connections");
    });

    it("should reject values outside min/max range", () => {
      const config = {
        max_connections: 20000, // max is 10000
      };

      const result = service.validateConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0].message).toContain("at most");
    });

    it("should reject invalid enum values", () => {
      const config = {
        logging_level: "invalid",
      };

      const result = service.validateConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0].message).toContain("must be one of");
    });

    it("should reject unknown configuration fields", () => {
      const config = {
        unknown_field: "value",
      };

      const result = service.validateConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0].message).toContain("Unknown configuration field");
    });

    it("should validate multiple fields correctly", () => {
      const config = {
        max_connections: 100,
        timeout_seconds: 30,
        compression_level: 9,
        logging_level: "debug",
        retry_max_attempts: 5,
      };

      const result = service.validateConfig(config);

      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it("should detect multiple validation errors", () => {
      const config = {
        max_connections: "invalid",
        timeout_seconds: 500, // max is 300
        logging_level: "invalid",
      };

      const result = service.validateConfig(config);

      expect(result.isValid).toBe(false);
      expect(result.errors.length).toBeGreaterThan(1);
    });
  });

  describe("Create Proxy Configuration", () => {
    it("should create configuration with defaults", async () => {
      const mockRow = {
        id: "config-1",
        proxy_id: "proxy-1",
        user_id: "user-1",
        max_connections: 100,
        timeout_seconds: 30,
        compression_enabled: true,
        compression_level: 6,
        buffer_size_kb: 64,
        keep_alive_enabled: true,
        keep_alive_interval_seconds: 30,
        ssl_verify: true,
        ssl_cert_path: null,
        ssl_key_path: null,
        rate_limit_enabled: false,
        rate_limit_requests_per_second: 1000,
        rate_limit_burst_size: 100,
        retry_enabled: true,
        retry_max_attempts: 3,
        retry_backoff_ms: 1000,
        logging_level: "info",
        metrics_collection_enabled: true,
        metrics_collection_interval_seconds: 60,
        health_check_enabled: true,
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockRow] });

      const config = await service.createProxyConfig("proxy-1", "user-1", {});

      expect(config.proxyId).toBe("proxy-1");
      expect(config.maxConnections).toBe(100);
      expect(config.timeoutSeconds).toBe(30);
      expect(mockDb.query).toHaveBeenCalled();
    });

    it("should create configuration with custom values", async () => {
      const mockRow = {
        id: "config-1",
        proxy_id: "proxy-1",
        user_id: "user-1",
        max_connections: 200,
        timeout_seconds: 60,
        compression_enabled: false,
        compression_level: 6,
        buffer_size_kb: 128,
        keep_alive_enabled: true,
        keep_alive_interval_seconds: 30,
        ssl_verify: true,
        ssl_cert_path: null,
        ssl_key_path: null,
        rate_limit_enabled: true,
        rate_limit_requests_per_second: 500,
        rate_limit_burst_size: 50,
        retry_enabled: true,
        retry_max_attempts: 3,
        retry_backoff_ms: 1000,
        logging_level: "debug",
        metrics_collection_enabled: true,
        metrics_collection_interval_seconds: 60,
        health_check_enabled: true,
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockRow] });

      const config = await service.createProxyConfig("proxy-1", "user-1", {
        max_connections: 200,
        timeout_seconds: 60,
        compression_enabled: false,
        logging_level: "debug",
      });

      expect(config.maxConnections).toBe(200);
      expect(config.timeoutSeconds).toBe(60);
      expect(config.compressionEnabled).toBe(false);
      expect(config.loggingLevel).toBe("debug");
    });

    it("should throw error for invalid configuration", async () => {
      await expect(
        service.createProxyConfig("proxy-1", "user-1", {
          max_connections: "invalid",
        }),
      ).rejects.toThrow("Configuration validation failed");
    });

    it("should throw error if proxyId is missing", async () => {
      await expect(
        service.createProxyConfig(null, "user-1", {}),
      ).rejects.toThrow("proxyId and userId are required");
    });
  });

  describe("Get Proxy Configuration", () => {
    it("should retrieve existing configuration", async () => {
      const mockRow = {
        id: "config-1",
        proxy_id: "proxy-1",
        user_id: "user-1",
        max_connections: 100,
        timeout_seconds: 30,
        compression_enabled: true,
        compression_level: 6,
        buffer_size_kb: 64,
        keep_alive_enabled: true,
        keep_alive_interval_seconds: 30,
        ssl_verify: true,
        ssl_cert_path: null,
        ssl_key_path: null,
        rate_limit_enabled: false,
        rate_limit_requests_per_second: 1000,
        rate_limit_burst_size: 100,
        retry_enabled: true,
        retry_max_attempts: 3,
        retry_backoff_ms: 1000,
        logging_level: "info",
        metrics_collection_enabled: true,
        metrics_collection_interval_seconds: 60,
        health_check_enabled: true,
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockRow] });

      const config = await service.getProxyConfig("proxy-1");

      expect(config).not.toBeNull();
      expect(config.proxyId).toBe("proxy-1");
      expect(mockDb.query).toHaveBeenCalledWith(
        "SELECT * FROM proxy_configurations WHERE proxy_id = $1",
        ["proxy-1"],
      );
    });

    it("should return null for non-existent configuration", async () => {
      mockDb.query.mockResolvedValueOnce({ rows: [] });

      const config = await service.getProxyConfig("non-existent");

      expect(config).toBeNull();
    });
  });

  describe("Update Proxy Configuration", () => {
    it("should update configuration with valid changes", async () => {
      const currentConfig = {
        id: "config-1",
        proxy_id: "proxy-1",
        user_id: "user-1",
        max_connections: 100,
        timeout_seconds: 30,
        compression_enabled: true,
        compression_level: 6,
        buffer_size_kb: 64,
        keep_alive_enabled: true,
        keep_alive_interval_seconds: 30,
        ssl_verify: true,
        ssl_cert_path: null,
        ssl_key_path: null,
        rate_limit_enabled: false,
        rate_limit_requests_per_second: 1000,
        rate_limit_burst_size: 100,
        retry_enabled: true,
        retry_max_attempts: 3,
        retry_backoff_ms: 1000,
        logging_level: "info",
        metrics_collection_enabled: true,
        metrics_collection_interval_seconds: 60,
        health_check_enabled: true,
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        created_at: new Date(),
        updated_at: new Date(),
      };

      const updatedRow = {
        ...currentConfig,
        max_connections: 200,
        timeout_seconds: 60,
        updated_at: new Date(),
      };

      mockDb.query
        .mockResolvedValueOnce({ rows: [currentConfig] }) // getProxyConfig
        .mockResolvedValueOnce({ rows: [updatedRow] }) // update query
        .mockResolvedValueOnce({ rows: [] }); // history insert

      const result = await service.updateProxyConfig(
        "proxy-1",
        "user-1",
        {
          max_connections: 200,
          timeout_seconds: 60,
        },
        "Performance tuning",
      );

      expect(result.maxConnections).toBe(200);
      expect(result.timeoutSeconds).toBe(60);
    });

    it("should reject invalid update values", async () => {
      const currentConfig = {
        id: "config-1",
        proxy_id: "proxy-1",
        user_id: "user-1",
        max_connections: 100,
        timeout_seconds: 30,
        compression_enabled: true,
        compression_level: 6,
        buffer_size_kb: 64,
        keep_alive_enabled: true,
        keep_alive_interval_seconds: 30,
        ssl_verify: true,
        ssl_cert_path: null,
        ssl_key_path: null,
        rate_limit_enabled: false,
        rate_limit_requests_per_second: 1000,
        rate_limit_burst_size: 100,
        retry_enabled: true,
        retry_max_attempts: 3,
        retry_backoff_ms: 1000,
        logging_level: "info",
        metrics_collection_enabled: true,
        metrics_collection_interval_seconds: 60,
        health_check_enabled: true,
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [currentConfig] });

      await expect(
        service.updateProxyConfig("proxy-1", "user-1", {
          max_connections: "invalid",
        }),
      ).rejects.toThrow("Configuration validation failed");
    });
  });

  describe("Configuration Templates", () => {
    it("should create configuration template", async () => {
      const mockTemplate = {
        id: "template-1",
        name: "High Performance",
        description: "Optimized for high throughput",
        template_config: JSON.stringify({
          max_connections: 500,
          compression_level: 9,
        }),
        is_default: false,
        created_by: "user-1",
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockTemplate] });

      const template = await service.createConfigTemplate(
        "High Performance",
        "user-1",
        {
          max_connections: 500,
          compression_level: 9,
        },
        "Optimized for high throughput",
      );

      expect(template.name).toBe("High Performance");
      expect(template.is_default).toBe(false);
    });

    it("should retrieve configuration template", async () => {
      const mockTemplate = {
        id: "template-1",
        name: "High Performance",
        description: "Optimized for high throughput",
        template_config: JSON.stringify({
          max_connections: 500,
          compression_level: 9,
        }),
        is_default: false,
        created_by: "user-1",
        created_at: new Date(),
        updated_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockTemplate] });

      const template = await service.getConfigTemplate("template-1");

      expect(template).not.toBeNull();
      expect(template.name).toBe("High Performance");
    });

    it("should get all configuration templates", async () => {
      const mockTemplates = [
        {
          id: "template-1",
          name: "High Performance",
          is_default: true,
          created_at: new Date(),
        },
        {
          id: "template-2",
          name: "Low Latency",
          is_default: false,
          created_at: new Date(),
        },
      ];

      mockDb.query.mockResolvedValueOnce({ rows: mockTemplates });

      const templates = await service.getAllConfigTemplates();

      expect(templates).toHaveLength(2);
      expect(templates[0].is_default).toBe(true);
    });

    it("should get default configuration template", async () => {
      const mockTemplate = {
        id: "template-1",
        name: "Default",
        is_default: true,
        created_at: new Date(),
      };

      mockDb.query.mockResolvedValueOnce({ rows: [mockTemplate] });

      const template = await service.getDefaultConfigTemplate();

      expect(template).not.toBeNull();
      expect(template.is_default).toBe(true);
    });
  });

  describe("Configuration History", () => {
    it("should retrieve configuration history", async () => {
      const mockHistory = [
        {
          id: "history-1",
          proxy_id: "proxy-1",
          changed_fields: ["max_connections", "timeout_seconds"],
          change_reason: "Performance tuning",
          created_at: new Date(),
        },
        {
          id: "history-2",
          proxy_id: "proxy-1",
          changed_fields: ["logging_level"],
          change_reason: "Debug mode enabled",
          created_at: new Date(),
        },
      ];

      mockDb.query.mockResolvedValueOnce({ rows: mockHistory });

      const history = await service.getConfigHistory("proxy-1", 50);

      expect(history).toHaveLength(2);
      expect(history[0].changed_fields).toContain("max_connections");
    });
  });

  describe("Default Configuration", () => {
    it("should return default configuration", () => {
      const defaults = service.getDefaultConfig();

      expect(defaults.max_connections).toBe(100);
      expect(defaults.timeout_seconds).toBe(30);
      expect(defaults.compression_enabled).toBe(true);
      expect(defaults.logging_level).toBe("info");
    });

    it("should return validation rules", () => {
      const rules = service.getValidationRules();

      expect(rules.max_connections).toBeDefined();
      expect(rules.max_connections.type).toBe("number");
      expect(rules.max_connections.min).toBe(1);
      expect(rules.max_connections.max).toBe(10000);
    });
  });

  describe("Configuration Response Formatting", () => {
    it("should format configuration response correctly", () => {
      const row = {
        id: "config-1",
        proxy_id: "proxy-1",
        user_id: "user-1",
        max_connections: 100,
        timeout_seconds: 30,
        compression_enabled: true,
        compression_level: 6,
        buffer_size_kb: 64,
        keep_alive_enabled: true,
        keep_alive_interval_seconds: 30,
        ssl_verify: true,
        ssl_cert_path: null,
        ssl_key_path: null,
        rate_limit_enabled: false,
        rate_limit_requests_per_second: 1000,
        rate_limit_burst_size: 100,
        retry_enabled: true,
        retry_max_attempts: 3,
        retry_backoff_ms: 1000,
        logging_level: "info",
        metrics_collection_enabled: true,
        metrics_collection_interval_seconds: 60,
        health_check_enabled: true,
        health_check_interval_seconds: 30,
        health_check_timeout_seconds: 5,
        created_at: new Date(),
        updated_at: new Date(),
      };

      const formatted = service.formatConfigResponse(row);

      expect(formatted.proxyId).toBe("proxy-1");
      expect(formatted.maxConnections).toBe(100);
      expect(formatted.timeoutSeconds).toBe(30);
      expect(formatted.compressionEnabled).toBe(true);
      expect(formatted.loggingLevel).toBe("info");
    });
  });
});
