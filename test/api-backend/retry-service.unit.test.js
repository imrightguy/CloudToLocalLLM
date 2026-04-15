import { jest, describe, it, expect, beforeEach } from '@jest/globals';
import {
  RetryService,
  RetryManager,
  retryManager,
} from '../../services/api-backend/services/retry-service.js';

describe('RetryService', () => {
  let service;

  beforeEach(() => {
    service = new RetryService({
      name: 'test-retry',
      maxRetries: 3,
      initialDelayMs: 10,
      maxDelayMs: 1000,
      backoffMultiplier: 2,
    });
  });

  // --- Construction ---
  describe('constructor', () => {
    it('should set defaults when no options provided', () => {
      const s = new RetryService();
      expect(s.name).toBe('RetryService');
      expect(s.maxRetries).toBe(3);
      expect(s.initialDelayMs).toBe(100);
      expect(s.maxDelayMs).toBe(10000);
      expect(s.backoffMultiplier).toBe(2);
      expect(s.jitterFactor).toBe(0.1);
    });

    it('should accept custom options', () => {
      const shouldRetry = () => true;
      const s = new RetryService({
        name: 'custom',
        maxRetries: 5,
        initialDelayMs: 200,
        maxDelayMs: 5000,
        backoffMultiplier: 3,
        jitterFactor: 0.2,
        shouldRetry,
      });
      expect(s.name).toBe('custom');
      expect(s.maxRetries).toBe(5);
      expect(s.initialDelayMs).toBe(200);
      expect(s.maxDelayMs).toBe(5000);
      expect(s.backoffMultiplier).toBe(3);
      expect(s.jitterFactor).toBe(0.2);
      expect(s.shouldRetry).toBe(shouldRetry);
    });

    it('should initialize metrics to zero', () => {
      expect(service.metrics.totalAttempts).toBe(0);
      expect(service.metrics.successfulAttempts).toBe(0);
      expect(service.metrics.failedAttempts).toBe(0);
      expect(service.metrics.retriedAttempts).toBe(0);
      expect(service.metrics.totalRetries).toBe(0);
      expect(service.metrics.averageRetries).toBe(0);
    });
  });

  // --- defaultShouldRetry ---
  describe('defaultShouldRetry', () => {
    it('should not retry on 4xx client errors', () => {
      const err = new Error('Bad Request');
      err.statusCode = 400;
      expect(service.defaultShouldRetry(err)).toBe(false);
    });

    it('should not retry on 404', () => {
      const err = new Error('Not Found');
      err.statusCode = 404;
      expect(service.defaultShouldRetry(err)).toBe(false);
    });

    it('should not retry on 499', () => {
      const err = new Error('Client Closed');
      err.statusCode = 499;
      expect(service.defaultShouldRetry(err)).toBe(false);
    });

    it('should retry on ECONNREFUSED', () => {
      const err = new Error('connect refused');
      err.code = 'ECONNREFUSED';
      expect(service.defaultShouldRetry(err)).toBe(true);
    });

    it('should retry on ECONNRESET', () => {
      const err = new Error('connection reset');
      err.code = 'ECONNRESET';
      expect(service.defaultShouldRetry(err)).toBe(true);
    });

    it('should retry on ETIMEDOUT', () => {
      const err = new Error('timed out');
      err.code = 'ETIMEDOUT';
      expect(service.defaultShouldRetry(err)).toBe(true);
    });

    it('should retry on EHOSTUNREACH', () => {
      const err = new Error('host unreachable');
      err.code = 'EHOSTUNREACH';
      expect(service.defaultShouldRetry(err)).toBe(true);
    });

    it('should retry on ENETUNREACH', () => {
      const err = new Error('network unreachable');
      err.code = 'ENETUNREACH';
      expect(service.defaultShouldRetry(err)).toBe(true);
    });

    it('should retry on 5xx server errors', () => {
      const err = new Error('Internal Server Error');
      err.statusCode = 500;
      expect(service.defaultShouldRetry(err)).toBe(true);
    });

    it('should retry on 503', () => {
      const err = new Error('Service Unavailable');
      err.statusCode = 503;
      expect(service.defaultShouldRetry(err)).toBe(true);
    });

    it('should retry on timeout in error message', () => {
      const err = new Error('request timeout exceeded');
      expect(service.defaultShouldRetry(err)).toBe(true);
    });

    it('should not retry on unknown errors without special properties', () => {
      const err = new Error('something went wrong');
      expect(service.defaultShouldRetry(err)).toBe(false);
    });
  });

  // --- calculateDelay ---
  describe('calculateDelay', () => {
    it('should return approximate initialDelay for attempt 0', () => {
      const delay = service.calculateDelay(0);
      expect(delay).toBeGreaterThanOrEqual(9);
      expect(delay).toBeLessThanOrEqual(11);
    });

    it('should approximately double delay for attempt 1', () => {
      const delay = service.calculateDelay(1);
      expect(delay).toBeGreaterThanOrEqual(18);
      expect(delay).toBeLessThanOrEqual(22);
    });

    it('should approximately quadruple delay for attempt 2', () => {
      const delay = service.calculateDelay(2);
      expect(delay).toBeGreaterThanOrEqual(36);
      expect(delay).toBeLessThanOrEqual(44);
    });

    it('should cap delay at maxDelayMs', () => {
      const s = new RetryService({ initialDelayMs: 500, maxDelayMs: 800, backoffMultiplier: 2 });
      const delay0 = s.calculateDelay(0);
      expect(delay0).toBeGreaterThanOrEqual(450);
      expect(delay0).toBeLessThanOrEqual(550);
      // At higher attempts, delay is capped at maxDelayMs ± jitter
      // jitter = cappedDelay * 0.1 * (random*2-1), so range is [720, 880]
      const delay1 = s.calculateDelay(1);
      expect(delay1).toBeGreaterThanOrEqual(700);
      expect(delay1).toBeLessThanOrEqual(900);
      const delay2 = s.calculateDelay(2);
      expect(delay2).toBeGreaterThanOrEqual(700);
      expect(delay2).toBeLessThanOrEqual(900);
    });

    it('should apply jitter within range', () => {
      const s = new RetryService({ initialDelayMs: 1000, maxDelayMs: 10000, backoffMultiplier: 2, jitterFactor: 0.5 });
      const delays = new Set();
      for (let i = 0; i < 50; i++) {
        delays.add(s.calculateDelay(0));
      }
      expect(delays.size).toBeGreaterThan(1);
      for (const d of delays) {
        expect(d).toBeGreaterThanOrEqual(500);
        expect(d).toBeLessThanOrEqual(1500);
      }
    });
  });

  // --- sleep ---
  describe('sleep', () => {
    it('should resolve after specified duration', async () => {
      const start = Date.now();
      await service.sleep(20);
      const elapsed = Date.now() - start;
      expect(elapsed).toBeGreaterThanOrEqual(15);
    });
  });

  // --- execute ---
  describe('execute', () => {
    it('should return result on first successful attempt', async () => {
      const fn = jest.fn().mockResolvedValue('success');
      const result = await service.execute(fn);
      expect(result).toBe('success');
      expect(fn).toHaveBeenCalledTimes(1);
      expect(service.metrics.totalAttempts).toBe(1);
      expect(service.metrics.successfulAttempts).toBe(1);
      expect(service.metrics.failedAttempts).toBe(0);
    });

    it('should retry on retryable error and succeed', async () => {
      const retryableError = new Error('ECONNREFUSED');
      retryableError.code = 'ECONNREFUSED';
      const fn = jest
        .fn()
        .mockRejectedValueOnce(retryableError)
        .mockResolvedValueOnce('recovered');
      const result = await service.execute(fn);
      expect(result).toBe('recovered');
      expect(fn).toHaveBeenCalledTimes(2);
      expect(service.metrics.retriedAttempts).toBe(1);
      expect(service.metrics.totalRetries).toBe(1);
    });

    it('should exhaust retries and throw', async () => {
      const retryableError = new Error('ETIMEDOUT');
      retryableError.code = 'ETIMEDOUT';
      const fn = jest.fn().mockRejectedValue(retryableError);
      await expect(service.execute(fn)).rejects.toThrow('ETIMEDOUT');
      expect(fn).toHaveBeenCalledTimes(4);
      expect(service.metrics.failedAttempts).toBe(1);
    });

    it('should not retry on non-retryable error', async () => {
      const err = new Error('Bad Request');
      err.statusCode = 400;
      const fn = jest.fn().mockRejectedValue(err);
      await expect(service.execute(fn)).rejects.toThrow('Bad Request');
      expect(fn).toHaveBeenCalledTimes(1);
      expect(service.metrics.failedAttempts).toBe(1);
    });

    it('should pass context and args to function', async () => {
      const ctx = { key: 'value' };
      const fn = jest.fn().mockResolvedValue('ok');
      await service.execute(fn, ctx, ['arg1', 'arg2']);
      expect(fn).toHaveBeenCalledTimes(1);
      expect(fn).toHaveBeenCalledWith('arg1', 'arg2');
    });

    it('should track average retries correctly across multiple calls', async () => {
      const retryableError = new Error('timeout');
      const fn = jest
        .fn()
        .mockRejectedValueOnce(retryableError)
        .mockResolvedValueOnce('ok1')
        .mockRejectedValueOnce(retryableError)
        .mockRejectedValueOnce(retryableError)
        .mockResolvedValueOnce('ok2');

      await service.execute(fn);
      await service.execute(fn);

      expect(service.metrics.retriedAttempts).toBe(2);
      expect(service.metrics.totalRetries).toBe(3);
      expect(service.metrics.averageRetries).toBe(1.5);
    });

    it('should use custom shouldRetry when provided', async () => {
      const customService = new RetryService({
        maxRetries: 2,
        initialDelayMs: 1,
        jitterFactor: 0,
        shouldRetry: () => false,
      });
      const err = new Error('ECONNREFUSED');
      err.code = 'ECONNREFUSED';
      const fn = jest.fn().mockRejectedValue(err);
      await expect(customService.execute(fn)).rejects.toThrow('ECONNREFUSED');
      expect(fn).toHaveBeenCalledTimes(1);
    });
  });

  // --- getMetrics ---
  describe('getMetrics', () => {
    it('should return metrics with config', () => {
      const m = service.getMetrics();
      expect(m.name).toBe('test-retry');
      expect(m.config.maxRetries).toBe(3);
      expect(m.config.initialDelayMs).toBe(10);
      expect(m.config.maxDelayMs).toBe(1000);
      expect(m.config.backoffMultiplier).toBe(2);
      expect(m.config.jitterFactor).toBe(0.1);
      expect(m.totalAttempts).toBe(0);
    });
  });

  // --- resetMetrics ---
  describe('resetMetrics', () => {
    it('should reset all metrics to zero', async () => {
      const fn = jest.fn().mockResolvedValue('ok');
      await service.execute(fn);
      expect(service.metrics.totalAttempts).toBe(1);
      service.resetMetrics();
      expect(service.metrics.totalAttempts).toBe(0);
      expect(service.metrics.successfulAttempts).toBe(0);
      expect(service.metrics.failedAttempts).toBe(0);
      expect(service.metrics.retriedAttempts).toBe(0);
      expect(service.metrics.totalRetries).toBe(0);
      expect(service.metrics.averageRetries).toBe(0);
    });
  });
});

describe('RetryManager', () => {
  let manager;

  beforeEach(() => {
    manager = new RetryManager();
  });

  describe('getOrCreate', () => {
    it('should create a new service if not exists', () => {
      const svc = manager.getOrCreate('my-service', { maxRetries: 5 });
      expect(svc).toBeInstanceOf(RetryService);
      expect(svc.name).toBe('my-service');
      expect(svc.maxRetries).toBe(5);
    });

    it('should return existing service on second call', () => {
      const svc1 = manager.getOrCreate('my-service');
      const svc2 = manager.getOrCreate('my-service');
      expect(svc1).toBe(svc2);
    });

    it('should ignore options on subsequent calls', () => {
      manager.getOrCreate('svc', { maxRetries: 5 });
      const svc = manager.getOrCreate('svc', { maxRetries: 10 });
      expect(svc.maxRetries).toBe(5);
    });
  });

  describe('get', () => {
    it('should return undefined for non-existent service', () => {
      expect(manager.get('missing')).toBeUndefined();
    });

    it('should return the service if it exists', () => {
      manager.getOrCreate('existing');
      expect(manager.get('existing')).toBeInstanceOf(RetryService);
    });
  });

  describe('getAll', () => {
    it('should return empty array when no services', () => {
      expect(manager.getAll()).toEqual([]);
    });

    it('should return all created services', () => {
      manager.getOrCreate('svc1');
      manager.getOrCreate('svc2');
      const all = manager.getAll();
      expect(all).toHaveLength(2);
      expect(all[0]).toBeInstanceOf(RetryService);
      expect(all[1]).toBeInstanceOf(RetryService);
    });
  });

  describe('getAllMetrics', () => {
    it('should return metrics for all services', () => {
      manager.getOrCreate('svc1');
      manager.getOrCreate('svc2');
      const metrics = manager.getAllMetrics();
      expect(metrics.svc1).toBeDefined();
      expect(metrics.svc2).toBeDefined();
      expect(metrics.svc1.name).toBe('svc1');
    });
  });

  describe('resetAllMetrics', () => {
    it('should reset metrics for all services', async () => {
      const svc = manager.getOrCreate('svc');
      const fn = jest.fn().mockResolvedValue('ok');
      await svc.execute(fn);
      expect(svc.metrics.totalAttempts).toBe(1);
      manager.resetAllMetrics();
      expect(svc.metrics.totalAttempts).toBe(0);
    });
  });

  describe('remove', () => {
    it('should remove a service', () => {
      manager.getOrCreate('svc');
      expect(manager.get('svc')).toBeDefined();
      manager.remove('svc');
      expect(manager.get('svc')).toBeUndefined();
    });
  });

  describe('removeAll', () => {
    it('should remove all services', () => {
      manager.getOrCreate('svc1');
      manager.getOrCreate('svc2');
      manager.removeAll();
      expect(manager.getAll()).toEqual([]);
    });
  });
});

describe('retryManager singleton', () => {
  it('should be a RetryManager instance', () => {
    expect(retryManager).toBeInstanceOf(RetryManager);
  });
});
