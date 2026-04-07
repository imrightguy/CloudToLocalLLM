import {
  CircuitBreaker,
  CircuitBreakerManager,
} from "../../services/api-backend/services/circuit-breaker.js";

describe("CircuitBreaker", () => {
  let breaker;

  beforeEach(() => {
    breaker = new CircuitBreaker({
      name: "TestBreaker",
      failureThreshold: 3,
      successThreshold: 2,
      timeout: 100,
    });
  });

  describe("State Transitions", () => {
    test("should start in CLOSED state", () => {
      expect(breaker.getState()).toBe("CLOSED");
    });

    test("should transition from CLOSED to OPEN after failure threshold", async () => {
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      // Fail 3 times to reach threshold
      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      expect(breaker.getState()).toBe("OPEN");
    });

    test("should transition from OPEN to HALF_OPEN after timeout", async () => {
      // Open the circuit
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      expect(breaker.getState()).toBe("OPEN");

      // Wait for timeout
      await new Promise((resolve) => setTimeout(resolve, 150));

      // Next execution should transition to HALF_OPEN
      const successFn = async () => "success";
      const result = await breaker.execute(successFn);
      expect(result).toBe("success");
      expect(breaker.getState()).toBe("HALF_OPEN");
    });

    test("should transition from HALF_OPEN to CLOSED after success threshold", async () => {
      // Open the circuit
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      // Wait for timeout
      await new Promise((resolve) => setTimeout(resolve, 150));

      // Succeed twice to reach success threshold
      const successFn = async () => "success";
      await breaker.execute(successFn);
      expect(breaker.getState()).toBe("HALF_OPEN");

      await breaker.execute(successFn);
      expect(breaker.getState()).toBe("CLOSED");
    });

    test("should transition from HALF_OPEN back to OPEN on failure", async () => {
      // Open the circuit
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      // Wait for timeout
      await new Promise((resolve) => setTimeout(resolve, 150));

      // Transition to HALF_OPEN
      const successFn = async () => "success";
      await breaker.execute(successFn);
      expect(breaker.getState()).toBe("HALF_OPEN");

      // Fail in HALF_OPEN state
      try {
        await breaker.execute(failingFn);
      } catch (e) {
        // Expected
      }

      expect(breaker.getState()).toBe("OPEN");
    });
  });

  describe("Request Handling", () => {
    test("should allow requests when CLOSED", async () => {
      const fn = async () => "success";
      const result = await breaker.execute(fn);
      expect(result).toBe("success");
    });

    test("should reject requests when OPEN", async () => {
      // Open the circuit
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      // Try to execute when OPEN
      const fn = async () => "success";
      await expect(breaker.execute(fn)).rejects.toThrow(
        "Circuit breaker is OPEN",
      );
    });

    test("should allow limited requests when HALF_OPEN", async () => {
      // Open the circuit
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      // Wait for timeout
      await new Promise((resolve) => setTimeout(resolve, 150));

      // Should allow request in HALF_OPEN
      const successFn = async () => "success";
      const result = await breaker.execute(successFn);
      expect(result).toBe("success");
      expect(breaker.getState()).toBe("HALF_OPEN");
    });
  });

  describe("Metrics", () => {
    test("should track total requests", async () => {
      const fn = async () => "success";
      await breaker.execute(fn);
      await breaker.execute(fn);

      const metrics = breaker.getMetrics();
      expect(metrics.totalRequests).toBe(2);
      expect(metrics.successfulRequests).toBe(2);
    });

    test("should track failed requests", async () => {
      const failingFn = async () => {
        throw new Error("Failed");
      };

      try {
        await breaker.execute(failingFn);
      } catch (e) {
        // Expected
      }

      const metrics = breaker.getMetrics();
      expect(metrics.failedRequests).toBe(1);
    });

    test("should track rejected requests", async () => {
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      // Open the circuit
      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      // Try to execute when OPEN
      const fn = async () => "success";
      try {
        await breaker.execute(fn);
      } catch (e) {
        // Expected
      }

      const metrics = breaker.getMetrics();
      expect(metrics.rejectedRequests).toBe(1);
    });

    test("should track state changes", async () => {
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      // Open the circuit
      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      const metrics = breaker.getMetrics();
      expect(metrics.stateChanges.length).toBeGreaterThan(0);
      expect(metrics.stateChanges[0].from).toBe("CLOSED");
      expect(metrics.stateChanges[0].to).toBe("OPEN");
    });
  });

  describe("Manual Control", () => {
    test("should manually open the circuit", () => {
      breaker.open();
      expect(breaker.getState()).toBe("OPEN");
    });

    test("should manually close the circuit", () => {
      breaker.open();
      expect(breaker.getState()).toBe("OPEN");

      breaker.close();
      expect(breaker.getState()).toBe("CLOSED");
    });

    test("should reset the circuit", async () => {
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      // Open the circuit
      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      expect(breaker.getState()).toBe("OPEN");

      breaker.reset();
      expect(breaker.getState()).toBe("CLOSED");
      expect(breaker.failureCount).toBe(0);
      expect(breaker.successCount).toBe(0);
    });
  });

  describe("State Change Callbacks", () => {
    test("should call onStateChange callback", async () => {
      const stateChanges = [];
      const breaker2 = new CircuitBreaker({
        name: "TestBreaker2",
        failureThreshold: 2,
        onStateChange: (change) => {
          stateChanges.push(change);
        },
      });

      const failingFn = async () => {
        throw new Error("Service failed");
      };

      // Trigger state change
      for (let i = 0; i < 2; i++) {
        try {
          await breaker2.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      expect(stateChanges.length).toBeGreaterThan(0);
      expect(stateChanges[0].newState).toBe("OPEN");
    });
  });

  describe("Function Context and Arguments", () => {
    test("should execute function with correct context", async () => {
      const obj = {
        value: 42,
        getValue() {
          return this.value;
        },
      };

      const result = await breaker.execute(obj.getValue, obj);
      expect(result).toBe(42);
    });

    test("should execute function with arguments", async () => {
      const fn = async (a, b) => a + b;
      const result = await breaker.execute(fn, null, [5, 3]);
      expect(result).toBe(8);
    });
  });

  describe("Error Handling", () => {
    test("should throw error with CIRCUIT_BREAKER_OPEN code when open", async () => {
      const failingFn = async () => {
        throw new Error("Service failed");
      };

      // Open the circuit
      for (let i = 0; i < 3; i++) {
        try {
          await breaker.execute(failingFn);
        } catch (e) {
          // Expected
        }
      }

      try {
        await breaker.execute(async () => "success");
        fail("Should have thrown");
      } catch (error) {
        expect(error.code).toBe("CIRCUIT_BREAKER_OPEN");
      }
    });

    test("should propagate original error when CLOSED", async () => {
      const fn = async () => {
        throw new Error("Original error");
      };

      try {
        await breaker.execute(fn);
        fail("Should have thrown");
      } catch (error) {
        expect(error.message).toBe("Original error");
      }
    });
  });
});

describe("CircuitBreakerManager", () => {
  let manager;

  beforeEach(() => {
    manager = new CircuitBreakerManager();
  });

  test("should create and retrieve circuit breakers", () => {
    const breaker1 = manager.getOrCreate("service1");
    const breaker2 = manager.getOrCreate("service1");

    expect(breaker1).toBe(breaker2);
  });

  test("should get all circuit breakers", () => {
    manager.getOrCreate("service1");
    manager.getOrCreate("service2");
    manager.getOrCreate("service3");

    const all = manager.getAll();
    expect(all.length).toBe(3);
  });

  test("should get metrics for all circuit breakers", async () => {
    const breaker1 = manager.getOrCreate("service1");
    const breaker2 = manager.getOrCreate("service2");

    await breaker1.execute(async () => "success");
    await breaker2.execute(async () => "success");

    const metrics = manager.getAllMetrics();
    expect(metrics.service1.totalRequests).toBe(1);
    expect(metrics.service2.totalRequests).toBe(1);
  });

  test("should reset all circuit breakers", async () => {
    const breaker1 = manager.getOrCreate("service1", { failureThreshold: 1 });
    const breaker2 = manager.getOrCreate("service2", { failureThreshold: 1 });

    // Open both
    try {
      await breaker1.execute(async () => {
        throw new Error("fail");
      });
    } catch (e) {
      // Expected
    }

    try {
      await breaker2.execute(async () => {
        throw new Error("fail");
      });
    } catch (e) {
      // Expected
    }

    expect(breaker1.getState()).toBe("OPEN");
    expect(breaker2.getState()).toBe("OPEN");

    manager.resetAll();

    expect(breaker1.getState()).toBe("CLOSED");
    expect(breaker2.getState()).toBe("CLOSED");
  });

  test("should remove circuit breaker", () => {
    manager.getOrCreate("service1");
    expect(manager.get("service1")).toBeDefined();

    manager.remove("service1");
    expect(manager.get("service1")).toBeUndefined();
  });
});
