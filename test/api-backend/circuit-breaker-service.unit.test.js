import { jest, describe, it, expect, beforeEach } from '@jest/globals';
import { CircuitBreaker, CircuitBreakerManager, circuitBreakerManager } from '../../services/api-backend/services/circuit-breaker.js';

describe('CircuitBreaker', () => {
  let breaker;

  beforeEach(() => {
    breaker = new CircuitBreaker({ name: 'test-breaker', failureThreshold: 3, successThreshold: 2, timeout: 1000 });
  });

  // --- Construction ---
  describe('constructor', () => {
    it('should set defaults when no options provided', () => {
      const b = new CircuitBreaker();
      expect(b.name).toBe('CircuitBreaker');
      expect(b.failureThreshold).toBe(5);
      expect(b.successThreshold).toBe(2);
      expect(b.timeout).toBe(60000);
      expect(b.state).toBe('CLOSED');
      expect(b.failureCount).toBe(0);
      expect(b.successCount).toBe(0);
    });

    it('should accept custom options', () => {
      const onStateChange = jest.fn();
      const b = new CircuitBreaker({ name: 'custom', failureThreshold: 10, successThreshold: 5, timeout: 5000, onStateChange });
      expect(b.name).toBe('custom');
      expect(b.failureThreshold).toBe(10);
      expect(b.successThreshold).toBe(5);
      expect(b.timeout).toBe(5000);
      expect(b.onStateChange).toBe(onStateChange);
    });

    it('should initialize metrics', () => {
      expect(breaker.metrics.totalRequests).toBe(0);
      expect(breaker.metrics.successfulRequests).toBe(0);
      expect(breaker.metrics.failedRequests).toBe(0);
      expect(breaker.metrics.rejectedRequests).toBe(0);
      expect(breaker.metrics.stateChanges).toEqual([]);
    });
  });

  // --- CLOSED state (normal operation) ---
  describe('CLOSED state', () => {
    it('should execute successful function and return result', async () => {
      const result = await breaker.execute(() => Promise.resolve('ok'));
      expect(result).toBe('ok');
      expect(breaker.metrics.successfulRequests).toBe(1);
      expect(breaker.metrics.totalRequests).toBe(1);
    });

    it('should increment failure count on error but stay CLOSED below threshold', async () => {
      await expect(breaker.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      expect(breaker.failureCount).toBe(1);
      expect(breaker.state).toBe('CLOSED');
      expect(breaker.metrics.failedRequests).toBe(1);
    });

    it('should transition to OPEN when failures reach threshold', async () => {
      for (let i = 0; i < 3; i++) {
        await expect(breaker.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      }
      expect(breaker.state).toBe('OPEN');
      expect(breaker.metrics.stateChanges).toHaveLength(1);
      expect(breaker.metrics.stateChanges[0]).toMatchObject({ from: 'CLOSED', to: 'OPEN' });
    });

    it('should reset failure count on success', async () => {
      await expect(breaker.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      expect(breaker.failureCount).toBe(1);
      await breaker.execute(() => Promise.resolve('ok'));
      expect(breaker.failureCount).toBe(0);
    });
  });

  // --- OPEN state (failing fast) ---
  describe('OPEN state', () => {
    beforeEach(async () => {
      // Force open by hitting failure threshold
      for (let i = 0; i < 3; i++) {
        await expect(breaker.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      }
      expect(breaker.state).toBe('OPEN');
    });

    it('should reject requests immediately when OPEN', async () => {
      await expect(breaker.execute(() => Promise.resolve('ok'))).rejects.toThrow('Circuit breaker is OPEN for test-breaker');
      expect(breaker.metrics.rejectedRequests).toBe(1);
    });

    it('should set error code to CIRCUIT_BREAKER_OPEN', async () => {
      try {
        await breaker.execute(() => Promise.resolve('ok'));
      } catch (err) {
        expect(err.code).toBe('CIRCUIT_BREAKER_OPEN');
      }
    });

    it('should transition to HALF_OPEN after timeout', async () => {
      // Manually set lastFailureTime in the past
      breaker.lastFailureTime = Date.now() - 2000;
      const result = await breaker.execute(() => Promise.resolve('ok'));
      expect(breaker.state).toBe('HALF_OPEN');
      expect(result).toBe('ok');
    });
  });

  // --- HALF_OPEN state ---
  describe('HALF_OPEN state', () => {
    let stateChanges;

    beforeEach(async () => {
      stateChanges = [];
      breaker = new CircuitBreaker({
        name: 'test-half-open',
        failureThreshold: 3,
        successThreshold: 2,
        timeout: 100,
        onStateChange: (e) => stateChanges.push(e),
      });
      // Force OPEN
      for (let i = 0; i < 3; i++) {
        await expect(breaker.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      }
      // Wait for timeout to trigger HALF_OPEN on next execute
      breaker.lastFailureTime = Date.now() - 200;
    });

    it('should transition to CLOSED after enough successes', async () => {
      await breaker.execute(() => Promise.resolve('ok1'));
      expect(breaker.state).toBe('HALF_OPEN');
      await breaker.execute(() => Promise.resolve('ok2'));
      expect(breaker.state).toBe('CLOSED');
      expect(breaker.successCount).toBe(0); // reset on transition
    });

    it('should transition back to OPEN on failure in HALF_OPEN', async () => {
      await breaker.execute(() => Promise.resolve('ok1'));
      expect(breaker.state).toBe('HALF_OPEN');
      await expect(breaker.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      expect(breaker.state).toBe('OPEN');
    });
  });

  // --- State change callbacks ---
  describe('onStateChange callback', () => {
    it('should be called on state transitions', async () => {
      const callback = jest.fn();
      breaker = new CircuitBreaker({ name: 'cb-callback', failureThreshold: 2, onStateChange: callback });
      await expect(breaker.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      await expect(breaker.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      expect(callback).toHaveBeenCalledTimes(1);
      expect(callback).toHaveBeenCalledWith(expect.objectContaining({
        name: 'cb-callback',
        oldState: 'CLOSED',
        newState: 'OPEN',
      }));
    });
  });

  // --- Manual operations ---
  describe('manual operations', () => {
    it('reset() should return to CLOSED and clear counters', async () => {
      for (let i = 0; i < 3; i++) {
        await expect(breaker.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
      }
      expect(breaker.state).toBe('OPEN');
      breaker.reset();
      expect(breaker.state).toBe('CLOSED');
      expect(breaker.failureCount).toBe(0);
      expect(breaker.successCount).toBe(0);
      expect(breaker.lastFailureTime).toBeNull();
    });

    it('open() should manually open the breaker', () => {
      expect(breaker.state).toBe('CLOSED');
      breaker.open();
      expect(breaker.state).toBe('OPEN');
    });

    it('close() should manually close the breaker and reset counters', () => {
      breaker.open();
      breaker.failureCount = 5;
      breaker.close();
      expect(breaker.state).toBe('CLOSED');
      expect(breaker.failureCount).toBe(0);
      expect(breaker.successCount).toBe(0);
    });
  });

  // --- Getters ---
  describe('getState and getMetrics', () => {
    it('getState returns current state', () => {
      expect(breaker.getState()).toBe('CLOSED');
    });

    it('getMetrics returns metrics with state info', async () => {
      await breaker.execute(() => Promise.resolve('ok'));
      const metrics = breaker.getMetrics();
      expect(metrics.state).toBe('CLOSED');
      expect(metrics.totalRequests).toBe(1);
      expect(metrics.successfulRequests).toBe(1);
      expect(metrics.failureCount).toBe(0);
      expect(metrics.successCount).toBe(0);
    });
  });

  // --- shouldAttemptReset ---
  describe('shouldAttemptReset', () => {
    it('returns false when no lastFailureTime', () => {
      expect(breaker.shouldAttemptReset()).toBe(false);
    });

    it('returns false when timeout has not elapsed', () => {
      breaker.lastFailureTime = Date.now();
      expect(breaker.shouldAttemptReset()).toBe(false);
    });

    it('returns true when timeout has elapsed', () => {
      breaker.lastFailureTime = Date.now() - 2000;
      expect(breaker.shouldAttemptReset()).toBe(true);
    });
  });

  // --- execute with context and args ---
  describe('execute with context and args', () => {
    it('should apply function with context and arguments', async () => {
      const ctx = { multiplier: 10 };
      const fn = function (a, b) { return Promise.resolve((a + b) * this.multiplier); };
      const result = await breaker.execute(fn, ctx, [3, 7]);
      expect(result).toBe(100);
    });
  });
});

describe('CircuitBreakerManager', () => {
  let manager;

  beforeEach(() => {
    manager = new CircuitBreakerManager();
  });

  it('should create a new breaker with getOrCreate', () => {
    const breaker = manager.getOrCreate('service-a');
    expect(breaker).toBeInstanceOf(CircuitBreaker);
    expect(breaker.name).toBe('service-a');
  });

  it('should return existing breaker on second getOrCreate', () => {
    const b1 = manager.getOrCreate('service-a');
    const b2 = manager.getOrCreate('service-a');
    expect(b1).toBe(b2);
  });

  it('should pass options to breaker', () => {
    const b = manager.getOrCreate('service-b', { failureThreshold: 10 });
    expect(b.failureThreshold).toBe(10);
  });

  it('get should return undefined for unknown breaker', () => {
    expect(manager.get('unknown')).toBeUndefined();
  });

  it('getAll should return all breakers', () => {
    manager.getOrCreate('a');
    manager.getOrCreate('b');
    const all = manager.getAll();
    expect(all).toHaveLength(2);
  });

  it('getAllMetrics should return metrics for all breakers', () => {
    manager.getOrCreate('a');
    manager.getOrCreate('b');
    const metrics = manager.getAllMetrics();
    expect(Object.keys(metrics)).toEqual(expect.arrayContaining(['a', 'b']));
    expect(metrics.a.state).toBe('CLOSED');
  });

  it('resetAll should reset all breakers', async () => {
    const b = manager.getOrCreate('a', { failureThreshold: 1 });
    await expect(b.execute(() => Promise.reject(new Error('fail')))).rejects.toThrow('fail');
    expect(b.state).toBe('OPEN');
    manager.resetAll();
    expect(b.state).toBe('CLOSED');
  });

  it('remove should delete a breaker', () => {
    manager.getOrCreate('a');
    manager.remove('a');
    expect(manager.get('a')).toBeUndefined();
  });
});

describe('circuitBreakerManager singleton', () => {
  it('should be an instance of CircuitBreakerManager', () => {
    expect(circuitBreakerManager).toBeInstanceOf(CircuitBreakerManager);
  });
});
