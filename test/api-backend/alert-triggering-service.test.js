import { jest } from '@jest/globals';
import AlertTriggeringService from '../../services/api-backend/services/alert-triggering-service.js';

describe('AlertTriggeringService', () => {
  let service;

  beforeEach(() => {
    service = new AlertTriggeringService();
  });

  afterEach(() => {
    service.stop();
  });

  describe('start/stop lifecycle', () => {
    test('should start and set isRunning to true', () => {
      service.start();
      expect(service.isRunning).toBe(true);
    });

    test('should not start twice', () => {
      service.start();
      service.start();
      expect(service.isRunning).toBe(true);
    });

    test('should stop and set isRunning to false', () => {
      service.start();
      service.stop();
      expect(service.isRunning).toBe(false);
    });

    test('should not throw when stopping a non-running service', () => {
      expect(() => service.stop()).not.toThrow();
      expect(service.isRunning).toBe(false);
    });

    test('should clear evaluation timer on stop', () => {
      service.start();
      expect(service.evaluationTimer).not.toBeNull();
      service.stop();
      expect(service.evaluationTimer).toBeNull();
    });

    test('should be safe to stop multiple times', () => {
      service.start();
      service.stop();
      service.stop();
      expect(service.isRunning).toBe(false);
      expect(service.evaluationTimer).toBeNull();
    });
  });

  describe('recordMetric', () => {
    test('should record a single metric value', () => {
      service.recordMetric('cpu_usage', 85.5);
      const stats = service.getMetricStats('cpu_usage');
      expect(stats).not.toBeNull();
      expect(stats.count).toBe(1);
      expect(stats.latest).toBe(85.5);
    });

    test('should record multiple values for same metric', () => {
      service.recordMetric('cpu_usage', 50);
      service.recordMetric('cpu_usage', 70);
      service.recordMetric('cpu_usage', 90);
      const stats = service.getMetricStats('cpu_usage');
      expect(stats.count).toBe(3);
      expect(stats.average).toBeCloseTo(70);
      expect(stats.min).toBe(50);
      expect(stats.max).toBe(90);
      expect(stats.latest).toBe(90);
    });

    test('should track multiple metrics independently', () => {
      service.recordMetric('cpu_usage', 80);
      service.recordMetric('memory_usage', 60);
      service.recordMetric('disk_usage', 45);
      const cpuStats = service.getMetricStats('cpu_usage');
      const memStats = service.getMetricStats('memory_usage');
      const diskStats = service.getMetricStats('disk_usage');
      expect(cpuStats.latest).toBe(80);
      expect(memStats.latest).toBe(60);
      expect(diskStats.latest).toBe(45);
    });

    test('should respect buffer size limit', () => {
      service.bufferSize = 5;
      for (let i = 0; i < 10; i++) {
        service.recordMetric('cpu_usage', i);
      }
      const stats = service.getMetricStats('cpu_usage');
      expect(stats.count).toBe(5);
      expect(stats.latest).toBe(9);
      expect(stats.min).toBe(5);
    });

    test('should store metadata with metric', () => {
      service.recordMetric('cpu_usage', 85, { host: 'server-1', region: 'us-east' });
      const buffer = service.metricsBuffer.get('cpu_usage');
      expect(buffer[0].metadata).toEqual({ host: 'server-1', region: 'us-east' });
    });

    test('should store timestamp with metric', () => {
      const before = Date.now();
      service.recordMetric('cpu_usage', 85);
      const after = Date.now();
      const buffer = service.metricsBuffer.get('cpu_usage');
      expect(buffer[0].timestamp).toBeGreaterThanOrEqual(before);
      expect(buffer[0].timestamp).toBeLessThanOrEqual(after);
    });

    test('should default metadata to empty object', () => {
      service.recordMetric('cpu_usage', 85);
      const buffer = service.metricsBuffer.get('cpu_usage');
      expect(buffer[0].metadata).toEqual({});
    });

    test('should handle zero values', () => {
      service.recordMetric('error_rate', 0);
      const stats = service.getMetricStats('error_rate');
      expect(stats.latest).toBe(0);
      expect(stats.min).toBe(0);
      expect(stats.max).toBe(0);
    });

    test('should handle negative values', () => {
      service.recordMetric('temperature_delta', -5.3);
      const stats = service.getMetricStats('temperature_delta');
      expect(stats.latest).toBe(-5.3);
    });
  });

  describe('getMetricStats', () => {
    test('should return null for unknown metric', () => {
      expect(service.getMetricStats('nonexistent')).toBeNull();
    });

    test('should compute correct statistics for single value', () => {
      service.recordMetric('latency', 150);
      const stats = service.getMetricStats('latency');
      expect(stats.count).toBe(1);
      expect(stats.average).toBe(150);
      expect(stats.min).toBe(150);
      expect(stats.max).toBe(150);
      expect(stats.latest).toBe(150);
    });

    test('should compute correct statistics for multiple values', () => {
      service.recordMetric('latency', 100);
      service.recordMetric('latency', 200);
      service.recordMetric('latency', 300);
      service.recordMetric('latency', 400);
      const stats = service.getMetricStats('latency');
      expect(stats.count).toBe(4);
      expect(stats.average).toBeCloseTo(250);
      expect(stats.min).toBe(100);
      expect(stats.max).toBe(400);
      expect(stats.latest).toBe(400);
    });

    test('should include timestamp from latest reading', () => {
      service.recordMetric('latency', 100);
      const stats = service.getMetricStats('latency');
      expect(typeof stats.timestamp).toBe('number');
      expect(stats.timestamp).toBeGreaterThan(0);
    });
  });

  describe('getStatus', () => {
    test('should return correct status when not running', () => {
      const status = service.getStatus();
      expect(status.isRunning).toBe(false);
      expect(status.metricsTracked).toBe(0);
      expect(status.metrics).toEqual([]);
    });

    test('should return correct status when running with metrics', () => {
      service.start();
      service.recordMetric('cpu_usage', 80);
      service.recordMetric('memory', 60);
      const status = service.getStatus();
      expect(status.isRunning).toBe(true);
      expect(status.metricsTracked).toBe(2);
      expect(status.metrics).toContain('cpu_usage');
      expect(status.metrics).toContain('memory');
    });

    test('should include evaluation interval', () => {
      service.evaluationInterval = 30000;
      const status = service.getStatus();
      expect(status.evaluationInterval).toBe(30000);
    });
  });

  describe('getAllMetricStats', () => {
    test('should return stats for all tracked metrics', () => {
      service.recordMetric('cpu', 80);
      service.recordMetric('mem', 60);
      const allStats = service.getAllMetricStats();
      expect(Object.keys(allStats)).toEqual(['cpu', 'mem']);
      expect(allStats.cpu.latest).toBe(80);
      expect(allStats.mem.latest).toBe(60);
    });

    test('should return empty object when no metrics tracked', () => {
      expect(service.getAllMetricStats()).toEqual({});
    });

    test('should include full stats for each metric', () => {
      service.recordMetric('latency', 10);
      service.recordMetric('latency', 20);
      service.recordMetric('cpu', 50);
      const allStats = service.getAllMetricStats();
      expect(allStats.latency).toMatchObject({
        count: 2,
        average: 15,
        min: 10,
        max: 20,
        latest: 20,
      });
      expect(allStats.cpu).toMatchObject({
        count: 1,
        average: 50,
        min: 50,
        max: 50,
        latest: 50,
      });
    });
  });

  describe('constructor defaults', () => {
    test('should set default bufferSize', () => {
      expect(service.bufferSize).toBe(100);
    });

    test('should set default evaluationInterval', () => {
      expect(service.evaluationInterval).toBe(10000);
    });

    test('should initialize as not running', () => {
      expect(service.isRunning).toBe(false);
    });

    test('should initialize with null timer', () => {
      expect(service.evaluationTimer).toBeNull();
    });

    test('should initialize with empty metrics buffer', () => {
      expect(service.metricsBuffer.size).toBe(0);
    });
  });
});
