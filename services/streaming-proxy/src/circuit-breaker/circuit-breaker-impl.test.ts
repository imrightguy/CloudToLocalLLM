import { jest, describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import { CircuitBreakerImpl } from './circuit-breaker-impl';
import { CircuitState } from '../interfaces/circuit-breaker';

const defaultConfig = {
  failureThreshold: 3,
  successThreshold: 2,
  timeout: 100,
  resetTimeout: 200,
};

describe('CircuitBreakerImpl', () => {
  let breaker: CircuitBreakerImpl;

  beforeEach(() => {
    breaker = new CircuitBreakerImpl(defaultConfig);
  });

  afterEach(() => {
    breaker.reset();
    breaker.removeAllListeners();
  });

  describe('initial state', () => {
    it('starts in CLOSED state', () => {
      expect(breaker.getState()).toBe(CircuitState.CLOSED);
    });

    it('reports zero failure and success counts', () => {
      const metrics = breaker.getMetrics();
      expect(metrics.failureCount).toBe(0);
      expect(metrics.successCount).toBe(0);
    });

    it('has a lastStateChange timestamp', () => {
      const metrics = breaker.getMetrics();
      expect(metrics.lastStateChange).toBeInstanceOf(Date);
    });

    it('has no lastFailureTime initially', () => {
      const metrics = breaker.getMetrics();
      expect(metrics.lastFailureTime).toBeUndefined();
    });
  });

  describe('CLOSED state', () => {
    it('executes successful operations', async () => {
      const result = await breaker.execute(async () => 42);
      expect(result).toBe(42);
    });

    it('resets failure count on success', async () => {
      const failing = async () => { throw new Error('fail'); };
      for (let i = 0; i < 2; i++) {
        try { await breaker.execute(failing); } catch {}
      }
      expect(breaker.getMetrics().failureCount).toBe(2);

      await breaker.execute(async () => 'ok');
      expect(breaker.getMetrics().failureCount).toBe(0);
      expect(breaker.getState()).toBe(CircuitState.CLOSED);
    });

    it('transitions to OPEN when failure threshold is reached', async () => {
      const failing = async () => { throw new Error('fail'); };
      for (let i = 0; i < 3; i++) {
        try { await breaker.execute(failing); } catch {}
      }
      expect(breaker.getState()).toBe(CircuitState.OPEN);
    });

    it('sets lastFailureTime on failure', async () => {
      const failing = async () => { throw new Error('fail'); };
      try { await breaker.execute(failing); } catch {}
      expect(breaker.getMetrics().lastFailureTime).toBeInstanceOf(Date);
    });

    it('emits success event on successful operation', async () => {
      const listener = jest.fn();
      breaker.on('success', listener);
      await breaker.execute(async () => 'ok');
      expect(listener).toHaveBeenCalledTimes(1);
      expect(listener).toHaveBeenCalledWith(
        expect.objectContaining({ state: CircuitState.CLOSED }),
      );
    });

    it('emits failure event on failed operation', async () => {
      const listener = jest.fn();
      breaker.on('failure', listener);
      try { await breaker.execute(async () => { throw new Error('boom'); }); } catch {}
      expect(listener).toHaveBeenCalledTimes(1);
    });

    it('times out slow operations', async () => {
      const slow = async () =>
        new Promise((resolve) => setTimeout(resolve, 500));
      await expect(breaker.execute(slow)).rejects.toThrow('Operation timeout');
    });
  });

  describe('OPEN state', () => {
    beforeEach(async () => {
      const failing = async () => { throw new Error('fail'); };
      for (let i = 0; i < 3; i++) {
        try { await breaker.execute(failing); } catch {}
      }
      expect(breaker.getState()).toBe(CircuitState.OPEN);
    });

    it('rejects operations immediately', async () => {
      await expect(
        breaker.execute(async () => 'should not run'),
      ).rejects.toThrow('Circuit breaker is OPEN');
    });

    it('emits stateChange event when opening', () => {
      const b = new CircuitBreakerImpl(defaultConfig);
      const listener = jest.fn();
      b.on('stateChange', listener);
      b.open();
      expect(listener).toHaveBeenCalledWith(
        expect.objectContaining({
          from: CircuitState.CLOSED,
          to: CircuitState.OPEN,
        }),
      );
      b.removeAllListeners();
    });

    it('transitions to HALF_OPEN after resetTimeout', async () => {
      jest.useFakeTimers();
      const b = new CircuitBreakerImpl({ ...defaultConfig, resetTimeout: 300 });
      b.open();
      expect(b.getState()).toBe(CircuitState.OPEN);

      jest.advanceTimersByTime(300);
      expect(b.getState()).toBe(CircuitState.HALF_OPEN);

      b.removeAllListeners();
      jest.useRealTimers();
    });
  });

  describe('HALF_OPEN state', () => {
    it('transitions to CLOSED after enough successes', async () => {
      jest.useFakeTimers();
      const b = new CircuitBreakerImpl({ ...defaultConfig, resetTimeout: 50 });
      const failing = async () => { throw new Error('fail'); };
      for (let i = 0; i < 3; i++) {
        try { await b.execute(failing); } catch {}
      }
      expect(b.getState()).toBe(CircuitState.OPEN);

      jest.advanceTimersByTime(50);
      expect(b.getState()).toBe(CircuitState.HALF_OPEN);

      await b.execute(async () => 'ok');
      await b.execute(async () => 'ok');
      expect(b.getState()).toBe(CircuitState.CLOSED);

      b.removeAllListeners();
      jest.useRealTimers();
    });

    it('transitions back to OPEN on any failure', async () => {
      jest.useFakeTimers();
      const b = new CircuitBreakerImpl({ ...defaultConfig, resetTimeout: 50 });
      const failing = async () => { throw new Error('fail'); };
      for (let i = 0; i < 3; i++) {
        try { await b.execute(failing); } catch {}
      }

      jest.advanceTimersByTime(50);
      expect(b.getState()).toBe(CircuitState.HALF_OPEN);

      try {
        await b.execute(async () => { throw new Error('still failing'); });
      } catch {}
      expect(b.getState()).toBe(CircuitState.OPEN);

      b.removeAllListeners();
      jest.useRealTimers();
    });
  });

  describe('manual controls', () => {
    it('manually opens the circuit', () => {
      breaker.open();
      expect(breaker.getState()).toBe(CircuitState.OPEN);
    });

    it('manually closes the circuit and resets counters', async () => {
      const failing = async () => { throw new Error('fail'); };
      for (let i = 0; i < 3; i++) {
        try { await breaker.execute(failing); } catch {}
      }
      expect(breaker.getState()).toBe(CircuitState.OPEN);

      breaker.close();
      expect(breaker.getState()).toBe(CircuitState.CLOSED);
      expect(breaker.getMetrics().failureCount).toBe(0);
      expect(breaker.getMetrics().successCount).toBe(0);
    });

    it('reset clears all state', () => {
      breaker.open();
      breaker.reset();
      expect(breaker.getState()).toBe(CircuitState.CLOSED);
      expect(breaker.getMetrics().failureCount).toBe(0);
      expect(breaker.getMetrics().successCount).toBe(0);
      expect(breaker.getMetrics().lastFailureTime).toBeUndefined();
    });

    it('reset emits reset event', () => {
      const listener = jest.fn();
      breaker.on('reset', listener);
      breaker.reset();
      expect(listener).toHaveBeenCalledTimes(1);
    });
  });

  describe('configure', () => {
    it('emits configured event with new config', () => {
      const listener = jest.fn();
      breaker.on('configured', listener);
      const newConfig = { ...defaultConfig, failureThreshold: 10 };
      breaker.configure(newConfig);
      expect(listener).toHaveBeenCalledWith(newConfig);
    });

    it('uses updated config for subsequent operations', async () => {
      breaker.configure({ ...defaultConfig, failureThreshold: 1 });
      try { await breaker.execute(async () => { throw new Error('fail'); }); } catch {}
      expect(breaker.getState()).toBe(CircuitState.OPEN);
    });
  });

  describe('stateChange events', () => {
    it('includes from, to, and timestamp', () => {
      const listener = jest.fn();
      breaker.on('stateChange', listener);
      breaker.open();
      const event = listener.mock.calls[0][0] as Record<string, unknown>;
      expect(event).toHaveProperty('from', CircuitState.CLOSED);
      expect(event).toHaveProperty('to', CircuitState.OPEN);
      expect(event.timestamp).toBeInstanceOf(Date);
    });
  });
});
