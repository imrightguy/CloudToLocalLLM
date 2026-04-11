/**
 * Unit Tests for Retry Service
 *
 * Tests retry logic with exponential backoff, jitter, and configuration.
 * Simplified version without jest mocks for ES modules compatibility.
 */

import {
  RetryService,
  RetryManager,
} from "../../services/api-backend/services/retry-service.js";

describe("RetryService", () => {
  let retryService;

  beforeEach(() => {
    retryService = new RetryService({
      name: "TestService",
      maxRetries: 3,
      initialDelayMs: 10,
      maxDelayMs: 100,
      backoffMultiplier: 2,
      jitterFactor: 0.1,
    });
  });

  describe("constructor", () => {
    it("should initialize with default options", () => {
      const service = new RetryService();
      expect(service.name).toBe("RetryService");
      expect(service.maxRetries).toBe(3);
      expect(service.initialDelayMs).toBe(100);
      expect(service.maxDelayMs).toBe(10000);
      expect(service.backoffMultiplier).toBe(2);
      expect(service.jitterFactor).toBe(0.1);
    });

    it("should initialize with custom options", () => {
      const service = new RetryService({
        name: "CustomService",
        maxRetries: 5,
        initialDelayMs: 50,
        maxDelayMs: 5000,
        backoffMultiplier: 3,
        jitterFactor: 0.2,
      });
      expect(service.name).toBe("CustomService");
      expect(service.maxRetries).toBe(5);
      expect(service.initialDelayMs).toBe(50);
      expect(service.maxDelayMs).toBe(5000);
      expect(service.backoffMultiplier).toBe(3);
      expect(service.jitterFactor).toBe(0.2);
    });

    it("should initialize metrics", () => {
      expect(retryService.metrics).toEqual({
        totalAttempts: 0,
        successfulAttempts: 0,
        failedAttempts: 0,
        retriedAttempts: 0,
        totalRetries: 0,
        averageRetries: 0,
      });
    });
  });

  describe("calculateDelay", () => {
    it("should calculate exponential backoff correctly", () => {
      // Attempt 0: 10ms
      expect(retryService.calculateDelay(0)).toBeGreaterThanOrEqual(9);
      expect(retryService.calculateDelay(0)).toBeLessThanOrEqual(11);

      // Attempt 1: 20ms (10 * 2^1)
      expect(retryService.calculateDelay(1)).toBeGreaterThanOrEqual(18);
      expect(retryService.calculateDelay(1)).toBeLessThanOrEqual(22);

      // Attempt 2: 40ms (10 * 2^2)
      expect(retryService.calculateDelay(2)).toBeGreaterThanOrEqual(36);
      expect(retryService.calculateDelay(2)).toBeLessThanOrEqual(44);
    });

    it("should cap delay at maxDelayMs", () => {
      // Attempt 10 would be 10 * 2^10 = 10240ms, but capped at 100ms
      // With jitter (10%), delay can be up to 110ms
      const delay = retryService.calculateDelay(10);
      expect(delay).toBeLessThanOrEqual(110);
    });

    it("should apply jitter to delay", () => {
      const delays = [];
      for (let i = 0; i < 10; i++) {
        delays.push(retryService.calculateDelay(0));
      }

      // Check that delays vary (jitter is applied)
      const uniqueDelays = new Set(delays);
      expect(uniqueDelays.size).toBeGreaterThan(1);
    });

    it("should never return negative delay", () => {
      for (let i = 0; i < 10; i++) {
        const delay = retryService.calculateDelay(i);
        expect(delay).toBeGreaterThanOrEqual(0);
      }
    });
  });

  describe("defaultShouldRetry", () => {
    it("should retry on network errors", () => {
      const errors = [
        { code: "ECONNREFUSED" },
        { code: "ECONNRESET" },
        { code: "ETIMEDOUT" },
        { code: "EHOSTUNREACH" },
        { code: "ENETUNREACH" },
      ];

      for (const error of errors) {
        expect(retryService.defaultShouldRetry(error)).toBe(true);
      }
    });

    it("should retry on 5xx status codes", () => {
      const errors = [
        { statusCode: 500 },
        { statusCode: 502 },
        { statusCode: 503 },
        { statusCode: 504 },
      ];

      for (const error of errors) {
        expect(retryService.defaultShouldRetry(error)).toBe(true);
      }
    });

    it("should not retry on 4xx status codes", () => {
      const errors = [
        { statusCode: 400 },
        { statusCode: 401 },
        { statusCode: 403 },
        { statusCode: 404 },
      ];

      for (const error of errors) {
        expect(retryService.defaultShouldRetry(error)).toBe(false);
      }
    });

    it("should retry on timeout errors", () => {
      const error = { message: "Request timeout" };
      expect(retryService.defaultShouldRetry(error)).toBe(true);
    });

    it("should not retry on unknown errors", () => {
      const error = { message: "Unknown error" };
      expect(retryService.defaultShouldRetry(error)).toBe(false);
    });
  });

  describe("execute", () => {
    it("should execute function successfully on first attempt", async () => {
      let callCount = 0;
      const fn = async () => {
        callCount++;
        return "success";
      };

      const result = await retryService.execute(fn);

      expect(result).toBe("success");
      expect(callCount).toBe(1);
      expect(retryService.metrics.totalAttempts).toBe(1);
      expect(retryService.metrics.successfulAttempts).toBe(1);
      expect(retryService.metrics.failedAttempts).toBe(0);
    });

    it("should retry on transient failure", async () => {
      let callCount = 0;
      const fn = async () => {
        callCount++;
        if (callCount === 1) {
          throw { code: "ECONNREFUSED" };
        }
        return "success";
      };

      const result = await retryService.execute(fn);

      expect(result).toBe("success");
      expect(callCount).toBe(2);
      expect(retryService.metrics.totalAttempts).toBe(1);
      expect(retryService.metrics.successfulAttempts).toBe(1);
      expect(retryService.metrics.retriedAttempts).toBe(1);
      expect(retryService.metrics.totalRetries).toBe(1);
    });

    it("should not retry on client error", async () => {
      let callCount = 0;
      const fn = async () => {
        callCount++;
        throw { statusCode: 400 };
      };

      try {
        await retryService.execute(fn);
        throw new Error("Should have thrown");
      } catch (e) {
        expect(e.statusCode).toBe(400);
      }

      expect(callCount).toBe(1);
      expect(retryService.metrics.failedAttempts).toBe(1);
    });

    it("should fail after max retries exceeded", async () => {
      let callCount = 0;
      const fn = async () => {
        callCount++;
        throw { code: "ECONNREFUSED" };
      };

      try {
        await retryService.execute(fn);
        throw new Error("Should have thrown");
      } catch (e) {
        expect(e.code).toBe("ECONNREFUSED");
      }

      expect(callCount).toBe(4); // 1 initial + 3 retries
      expect(retryService.metrics.failedAttempts).toBe(1);
    });

    it("should pass context and arguments to function", async () => {
      const context = { value: 42 };
      const fn = async function (a, b) {
        return this.value + a + b;
      };

      const result = await retryService.execute(fn, context, [1, 2]);

      expect(result).toBe(45);
    });

    it("should calculate average retries correctly", async () => {
      let callCount = 0;
      const fn = async () => {
        callCount++;
        if (callCount <= 2) {
          throw { code: "ECONNREFUSED" };
        }
        return "success";
      };

      await retryService.execute(fn);

      expect(retryService.metrics.totalRetries).toBe(2);
      expect(retryService.metrics.retriedAttempts).toBe(1);
      expect(retryService.metrics.averageRetries).toBe(2);
    });

    it("should support custom shouldRetry function", async () => {
      const customRetry = new RetryService({
        maxRetries: 2,
        shouldRetry: (error) => error.code === "CUSTOM_ERROR",
      });

      let callCount = 0;
      const fn = async () => {
        callCount++;
        if (callCount === 1) {
          throw { code: "CUSTOM_ERROR" };
        }
        return "success";
      };

      const result = await customRetry.execute(fn);

      expect(result).toBe("success");
      expect(callCount).toBe(2);
    });
  });

  describe("getMetrics", () => {
    it("should return current metrics", async () => {
      const fn = async () => "success";
      await retryService.execute(fn);

      const metrics = retryService.getMetrics();

      expect(metrics).toHaveProperty("totalAttempts", 1);
      expect(metrics).toHaveProperty("successfulAttempts", 1);
      expect(metrics).toHaveProperty("name", "TestService");
      expect(metrics).toHaveProperty("config");
      expect(metrics.config).toHaveProperty("maxRetries", 3);
    });
  });

  describe("resetMetrics", () => {
    it("should reset all metrics", async () => {
      const fn = async () => "success";
      await retryService.execute(fn);

      expect(retryService.metrics.totalAttempts).toBe(1);

      retryService.resetMetrics();

      expect(retryService.metrics).toEqual({
        totalAttempts: 0,
        successfulAttempts: 0,
        failedAttempts: 0,
        retriedAttempts: 0,
        totalRetries: 0,
        averageRetries: 0,
      });
    });
  });
});

describe("RetryManager", () => {
  let retryManager;

  beforeEach(() => {
    retryManager = new RetryManager();
  });

  describe("getOrCreate", () => {
    it("should create a new retry service", () => {
      const service = retryManager.getOrCreate("service1");
      expect(service).toBeInstanceOf(RetryService);
      expect(service.name).toBe("service1");
    });

    it("should return existing retry service", () => {
      const service1 = retryManager.getOrCreate("service1");
      const service2 = retryManager.getOrCreate("service1");
      expect(service1).toBe(service2);
    });

    it("should apply custom options", () => {
      const service = retryManager.getOrCreate("service1", { maxRetries: 5 });
      expect(service.maxRetries).toBe(5);
    });
  });

  describe("get", () => {
    it("should return existing service", () => {
      retryManager.getOrCreate("service1");
      const service = retryManager.get("service1");
      expect(service).toBeInstanceOf(RetryService);
    });

    it("should return undefined for non-existent service", () => {
      const service = retryManager.get("nonexistent");
      expect(service).toBeUndefined();
    });
  });

  describe("getAll", () => {
    it("should return all retry services", () => {
      retryManager.getOrCreate("service1");
      retryManager.getOrCreate("service2");
      const services = retryManager.getAll();
      expect(services).toHaveLength(2);
    });
  });

  describe("getAllMetrics", () => {
    it("should return metrics for all services", async () => {
      const service1 = retryManager.getOrCreate("service1");
      retryManager.getOrCreate("service2");

      const fn = async () => "success";
      await service1.execute(fn);

      const metrics = retryManager.getAllMetrics();
      expect(metrics).toHaveProperty("service1");
      expect(metrics).toHaveProperty("service2");
      expect(metrics.service1.totalAttempts).toBe(1);
    });
  });

  describe("resetAllMetrics", () => {
    it("should reset metrics for all services", async () => {
      const service1 = retryManager.getOrCreate("service1");
      const service2 = retryManager.getOrCreate("service2");

      const fn = async () => "success";
      await service1.execute(fn);
      await service2.execute(fn);

      retryManager.resetAllMetrics();

      const metrics = retryManager.getAllMetrics();
      expect(metrics.service1.totalAttempts).toBe(0);
      expect(metrics.service2.totalAttempts).toBe(0);
    });
  });

  describe("remove", () => {
    it("should remove a retry service", () => {
      retryManager.getOrCreate("service1");
      retryManager.remove("service1");
      expect(retryManager.get("service1")).toBeUndefined();
    });
  });

  describe("removeAll", () => {
    it("should remove all retry services", () => {
      retryManager.getOrCreate("service1");
      retryManager.getOrCreate("service2");
      retryManager.removeAll();
      expect(retryManager.getAll()).toHaveLength(0);
    });
  });
});
