/**
 * Integration Tests for Retry Middleware
 *
 * Tests retry logic integration with circuit breaker and Express middleware.
 * Simplified version without jest mocks for ES modules compatibility.
 */

import {
  executeWithRetryAndCircuitBreaker,
  createRetryableClient,
  getServiceMetrics,
  getAllServiceMetrics,
} from "../../services/api-backend/middleware/retry-middleware.js";
import { retryManager } from "../../services/api-backend/services/retry-service.js";
import { circuitBreakerManager } from "../../services/api-backend/services/circuit-breaker.js";

describe("Retry Middleware", () => {
  beforeEach(() => {
    retryManager.removeAll();
    circuitBreakerManager.breakers.clear();
  });

  describe("executeWithRetryAndCircuitBreaker", () => {
    it("should execute function successfully", async () => {
      const fn = async () => "success";

      const result = await executeWithRetryAndCircuitBreaker("testService", fn);

      expect(result).toBe("success");
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

      const result = await executeWithRetryAndCircuitBreaker(
        "testService",
        fn,
        {
          retryConfig: { maxRetries: 3, initialDelayMs: 1 },
        },
      );

      expect(result).toBe("success");
      expect(callCount).toBe(2);
    });

    it("should fail after max retries", async () => {
      const fn = async () => {
        throw { code: "ECONNREFUSED" };
      };

      try {
        await executeWithRetryAndCircuitBreaker("testService", fn, {
          retryConfig: { maxRetries: 2, initialDelayMs: 1 },
        });
        throw new Error("Should have thrown");
      } catch (e) {
        expect(e.code).toBe("ECONNREFUSED");
      }
    });

    it("should open circuit breaker after failures", async () => {
      const fn = async () => {
        throw { code: "ECONNREFUSED" };
      };

      // Trigger multiple failures to open circuit breaker
      for (let i = 0; i < 5; i++) {
        try {
          await executeWithRetryAndCircuitBreaker("testService", fn, {
            retryConfig: { maxRetries: 0, initialDelayMs: 1 },
            circuitBreakerConfig: { failureThreshold: 5 },
          });
        } catch (e) {
          // Expected to fail
        }
      }

      // Circuit breaker should be open now
      const breaker = circuitBreakerManager.get("testService");
      expect(breaker.getState()).toBe("OPEN");
    });

    it("should reject immediately when circuit is open", async () => {
      const fn = async () => "success";

      // Open the circuit breaker
      const breaker = circuitBreakerManager.getOrCreate("testService");
      breaker.open();

      try {
        await executeWithRetryAndCircuitBreaker("testService", fn);
        throw new Error("Should have thrown");
      } catch (e) {
        expect(e.code).toBe("CIRCUIT_BREAKER_OPEN");
      }
    });

    it("should pass context and arguments", async () => {
      const context = { value: 42 };
      const fn = async function (a, b) {
        return this.value + a + b;
      };

      const result = await executeWithRetryAndCircuitBreaker(
        "testService",
        fn,
        {
          context,
          args: [1, 2],
        },
      );

      expect(result).toBe(45);
    });

    it("should support custom retry configuration", async () => {
      let callCount = 0;
      const fn = async () => {
        callCount++;
        if (callCount === 1) {
          throw { code: "ECONNREFUSED" };
        }
        return "success";
      };

      const result = await executeWithRetryAndCircuitBreaker(
        "testService",
        fn,
        {
          retryConfig: {
            maxRetries: 5,
            initialDelayMs: 10,
            maxDelayMs: 1000,
            backoffMultiplier: 3,
            jitterFactor: 0.2,
          },
        },
      );

      expect(result).toBe("success");
      const metrics = retryManager.get("testService").getMetrics();
      expect(metrics.config.maxRetries).toBe(5);
      expect(metrics.config.backoffMultiplier).toBe(3);
    });

    it("should support custom circuit breaker configuration", async () => {
      const fn = async () => "success";

      await executeWithRetryAndCircuitBreaker("testService", fn, {
        circuitBreakerConfig: {
          failureThreshold: 10,
          successThreshold: 5,
          timeout: 120000,
        },
      });

      const breaker = circuitBreakerManager.get("testService");
      expect(breaker.failureThreshold).toBe(10);
      expect(breaker.successThreshold).toBe(5);
      expect(breaker.timeout).toBe(120000);
    });
  });

  describe("createRetryableClient", () => {
    it("should wrap specified methods", async () => {
      let getDataCalls = 0;
      let postDataCalls = 0;

      const client = {
        getData: async () => {
          getDataCalls++;
          return "data";
        },
        postData: async () => {
          postDataCalls++;
          return "posted";
        },
      };

      const wrappedClient = createRetryableClient("testService", client, {
        methodsToWrap: ["getData", "postData"],
      });

      const result1 = await wrappedClient.getData();
      const result2 = await wrappedClient.postData();

      expect(result1).toBe("data");
      expect(result2).toBe("posted");
      expect(getDataCalls).toBe(1);
      expect(postDataCalls).toBe(1);
    });

    it("should retry wrapped methods on failure", async () => {
      let callCount = 0;
      const client = {
        getData: async () => {
          callCount++;
          if (callCount === 1) {
            throw { code: "ECONNREFUSED" };
          }
          return "data";
        },
      };

      const wrappedClient = createRetryableClient("testService", client, {
        methodsToWrap: ["getData"],
        retryConfig: { maxRetries: 3, initialDelayMs: 1 },
      });

      const result = await wrappedClient.getData();

      expect(result).toBe("data");
      expect(callCount).toBe(2);
    });

    it("should preserve method context", async () => {
      const client = {
        value: 42,
        getValue: async function () {
          return this.value;
        },
      };

      const wrappedClient = createRetryableClient("testService", client, {
        methodsToWrap: ["getValue"],
      });

      const result = await wrappedClient.getValue();

      expect(result).toBe(42);
    });

    it("should not wrap non-function properties", () => {
      const client = {
        data: "value",
        getData: async () => "data",
      };

      const wrappedClient = createRetryableClient("testService", client, {
        methodsToWrap: ["data", "getData"],
      });

      expect(wrappedClient.data).toBe("value");
      expect(typeof wrappedClient.getData).toBe("function");
    });

    it("should handle method arguments", async () => {
      let receivedArgs = null;
      const client = {
        add: async (a, b) => {
          receivedArgs = [a, b];
          return a + b;
        },
      };

      const wrappedClient = createRetryableClient("testService", client, {
        methodsToWrap: ["add"],
      });

      const result = await wrappedClient.add(2, 3);

      expect(result).toBe(5);
      expect(receivedArgs).toEqual([2, 3]);
    });
  });

  describe("getServiceMetrics", () => {
    it("should return metrics for a service", async () => {
      const fn = async () => "success";

      await executeWithRetryAndCircuitBreaker("testService", fn);

      const metrics = getServiceMetrics("testService");

      expect(metrics).toHaveProperty("retry");
      expect(metrics).toHaveProperty("circuitBreaker");
      expect(metrics.retry.totalAttempts).toBe(1);
    });

    it("should return null for non-existent service", () => {
      const metrics = getServiceMetrics("nonexistent");

      expect(metrics.retry).toBeNull();
      expect(metrics.circuitBreaker).toBeNull();
    });
  });

  describe("getAllServiceMetrics", () => {
    it("should return metrics for all services", async () => {
      const fn = async () => "success";

      await executeWithRetryAndCircuitBreaker("service1", fn);
      await executeWithRetryAndCircuitBreaker("service2", fn);

      const metrics = getAllServiceMetrics();

      expect(metrics).toHaveProperty("retry");
      expect(metrics).toHaveProperty("circuitBreaker");
      expect(metrics.retry).toHaveProperty("service1");
      expect(metrics.retry).toHaveProperty("service2");
    });
  });

  describe("Retry and Circuit Breaker Integration", () => {
    it("should retry before opening circuit breaker", async () => {
      let callCount = 0;
      const fn = async () => {
        callCount++;
        if (callCount === 1) {
          throw { code: "ECONNREFUSED" };
        }
        return "success";
      };

      const result = await executeWithRetryAndCircuitBreaker(
        "testService",
        fn,
        {
          retryConfig: { maxRetries: 3, initialDelayMs: 1 },
          circuitBreakerConfig: { failureThreshold: 5 },
        },
      );

      expect(result).toBe("success");
      expect(callCount).toBe(2);

      const breaker = circuitBreakerManager.get("testService");
      expect(breaker.getState()).toBe("CLOSED");
    });

    it("should recover from circuit breaker after timeout", async () => {
      // Manually open the circuit breaker
      const breaker = circuitBreakerManager.getOrCreate("testService2", {
        timeout: 100,
        failureThreshold: 1,
        successThreshold: 1,
      });

      // Manually set it to OPEN and record the failure time
      breaker.failureCount = 1;
      breaker.lastFailureTime = Date.now() - 150; // Set failure time 150ms ago
      breaker.transitionTo("OPEN");

      expect(breaker.getState()).toBe("OPEN");

      // Now try to execute - should transition to HALF_OPEN and then CLOSED
      const successFn = async () => "success";
      const result = await executeWithRetryAndCircuitBreaker(
        "testService2",
        successFn,
      );

      expect(result).toBe("success");
      expect(breaker.getState()).toBe("CLOSED");
    });

    it("should handle multiple concurrent requests", async () => {
      const fn = async () => "success";

      const promises = [];
      for (let i = 0; i < 5; i++) {
        promises.push(executeWithRetryAndCircuitBreaker("testService", fn));
      }

      const results = await Promise.all(promises);

      expect(results).toEqual([
        "success",
        "success",
        "success",
        "success",
        "success",
      ]);
    });
  });
});
