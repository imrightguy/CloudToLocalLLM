import { jest, describe, it, expect, beforeEach } from "@jest/globals";

import { HealthCheckService } from "../../services/api-backend/services/health-check.js";

describe("HealthCheckService", () => {
  let healthCheckService;

  beforeEach(() => {
    healthCheckService = new HealthCheckService();
  });

  describe("checkDatabaseHealth", () => {
    it("should return unknown status when database is not registered", async () => {
      const result = await healthCheckService.checkDatabaseHealth();
      expect(result.status).toBe("unknown");
      expect(result.message).toBe("Database not registered");
    });

    it("should return healthy status when database validation passes", async () => {
      const mockDb = {
        validateSchema: jest.fn().mockResolvedValue({
          allValid: true,
          results: [],
        }),
      };

      healthCheckService.registerDatabase(mockDb);
      const result = await healthCheckService.checkDatabaseHealth();

      expect(result.status).toBe("healthy");
      expect(result.message).toBe("Database is healthy");
      expect(result.details.allTablesValid).toBe(true);
    });

    it("should return degraded status when database validation fails", async () => {
      const mockDb = {
        validateSchema: jest.fn().mockResolvedValue({
          allValid: false,
          results: [{ table: "users", valid: false }],
        }),
      };

      healthCheckService.registerDatabase(mockDb);
      const result = await healthCheckService.checkDatabaseHealth();

      expect(result.status).toBe("degraded");
      expect(result.message).toBe("Database schema validation failed");
    });

    it("should return unhealthy status when database check throws error", async () => {
      const mockDb = {
        validateSchema: jest
          .fn()
          .mockRejectedValue(new Error("Connection failed")),
      };

      healthCheckService.registerDatabase(mockDb);
      const result = await healthCheckService.checkDatabaseHealth();

      expect(result.status).toBe("unhealthy");
      expect(result.message).toBe("Database health check failed");
      expect(result.error).toBe("Connection failed");
    });
  });

  describe("checkCacheHealth", () => {
    it("should return unknown status when cache is not registered", async () => {
      const result = await healthCheckService.checkCacheHealth();
      expect(result.status).toBe("unknown");
      expect(result.message).toBe("Cache not registered");
    });

    it("should return healthy status when cache ping succeeds", async () => {
      const mockCache = {
        ping: jest.fn().mockResolvedValue("PONG"),
      };

      healthCheckService.registerCache(mockCache);
      const result = await healthCheckService.checkCacheHealth();

      expect(result.status).toBe("healthy");
      expect(result.message).toBe("Cache is healthy");
    });

    it("should return unhealthy status when cache ping fails", async () => {
      const mockCache = {
        ping: jest.fn().mockRejectedValue(new Error("Cache connection failed")),
      };

      healthCheckService.registerCache(mockCache);
      const result = await healthCheckService.checkCacheHealth();

      expect(result.status).toBe("unhealthy");
      expect(result.message).toBe("Cache health check failed");
      expect(result.error).toBe("Cache connection failed");
    });

    it("should return unknown status when cache does not have ping method", async () => {
      const mockCache = {};

      healthCheckService.registerCache(mockCache);
      const result = await healthCheckService.checkCacheHealth();

      expect(result.status).toBe("unknown");
      expect(result.message).toBe("Cache health check not available");
    });
  });

  describe("checkServicesHealth", () => {
    it("should return empty object when no services are registered", async () => {
      const result = await healthCheckService.checkServicesHealth();
      expect(result).toEqual({});
    });

    it("should return health status for registered services", async () => {
      const mockHealthCheck = jest.fn().mockResolvedValue({
        status: "healthy",
        message: "Service is running",
      });

      healthCheckService.registerService("test-service", mockHealthCheck);
      const result = await healthCheckService.checkServicesHealth();

      expect(result["test-service"].status).toBe("healthy");
      expect(result["test-service"].message).toBe("Service is running");
    });

    it("should handle service health check failures", async () => {
      const mockHealthCheck = jest
        .fn()
        .mockRejectedValue(new Error("Service error"));

      healthCheckService.registerService("failing-service", mockHealthCheck);
      const result = await healthCheckService.checkServicesHealth();

      expect(result["failing-service"].status).toBe("unhealthy");
      expect(result["failing-service"].message).toContain(
        "Service health check failed",
      );
    });

    it("should handle multiple services", async () => {
      const mockHealthCheck1 = jest.fn().mockResolvedValue({
        status: "healthy",
        message: "Service 1 is running",
      });
      const mockHealthCheck2 = jest.fn().mockResolvedValue({
        status: "degraded",
        message: "Service 2 is degraded",
      });

      healthCheckService.registerService("service-1", mockHealthCheck1);
      healthCheckService.registerService("service-2", mockHealthCheck2);
      const result = await healthCheckService.checkServicesHealth();

      expect(result["service-1"].status).toBe("healthy");
      expect(result["service-2"].status).toBe("degraded");
    });
  });

  describe("getHealthStatus", () => {
    it("should return healthy status when all dependencies are healthy", async () => {
      const mockDb = {
        validateSchema: jest.fn().mockResolvedValue({
          allValid: true,
          results: [],
        }),
      };
      const mockCache = {
        ping: jest.fn().mockResolvedValue("PONG"),
      };
      const mockServiceCheck = jest.fn().mockResolvedValue({
        status: "healthy",
        message: "Service is running",
      });

      healthCheckService.registerDatabase(mockDb);
      healthCheckService.registerCache(mockCache);
      healthCheckService.registerService("test-service", mockServiceCheck);

      const result = await healthCheckService.getHealthStatus();

      expect(result.status).toBe("healthy");
      expect(result.service).toBe("cloudtolocalllm-api");
      expect(result.dependencies.database.status).toBe("healthy");
      expect(result.dependencies.cache.status).toBe("healthy");
      expect(result.dependencies.services["test-service"].status).toBe(
        "healthy",
      );
      expect(result.timestamp).toBeDefined();
      expect(result.uptime).toBeGreaterThan(0);
    });

    it("should return degraded status when any dependency is degraded", async () => {
      const mockDb = {
        validateSchema: jest.fn().mockResolvedValue({
          allValid: false,
          results: [],
        }),
      };

      healthCheckService.registerDatabase(mockDb);

      const result = await healthCheckService.getHealthStatus();

      expect(result.status).toBe("degraded");
      expect(result.dependencies.database.status).toBe("degraded");
    });

    it("should return unhealthy status when any dependency is unhealthy", async () => {
      const mockDb = {
        validateSchema: jest
          .fn()
          .mockRejectedValue(new Error("Connection failed")),
      };

      healthCheckService.registerDatabase(mockDb);

      const result = await healthCheckService.getHealthStatus();

      expect(result.status).toBe("unhealthy");
      expect(result.dependencies.database.status).toBe("unhealthy");
    });

    it("should include timestamp in response", async () => {
      const result = await healthCheckService.getHealthStatus();

      expect(result.timestamp).toBeDefined();
      expect(new Date(result.timestamp)).toBeInstanceOf(Date);
    });

    it("should handle errors gracefully", async () => {
      const mockDb = {
        validateSchema: jest
          .fn()
          .mockRejectedValue(new Error("Unexpected error")),
      };

      healthCheckService.registerDatabase(mockDb);

      const result = await healthCheckService.getHealthStatus();

      expect(result.status).toBe("unhealthy");
      expect(result.dependencies.database.status).toBe("unhealthy");
    });
  });
});
