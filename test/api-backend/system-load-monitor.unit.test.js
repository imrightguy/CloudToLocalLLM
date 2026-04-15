/**
 * Unit tests for System Load Monitor Service
 *
 * Tests SystemMetricsSnapshot load calculations and SystemLoadMonitor
 * adaptive rate limiting behavior, request tracking, and metrics history.
 */

import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import { SystemLoadMonitor } from '../../services/api-backend/services/system-load-monitor.js';

describe('SystemMetricsSnapshot', () => {
  it('should return low load level when load is under 30', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 10;
    monitor.currentMetrics.memoryUsage = 10;
    monitor.currentMetrics.queuedRequests = 0;
    expect(monitor.currentMetrics.getLoadLevel()).toBe('low');
    monitor.destroy();
  });

  it('should return medium load level when load is between 30 and 59', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 50;
    monitor.currentMetrics.memoryUsage = 40;
    monitor.currentMetrics.queuedRequests = 0;
    // load = 50*0.4 + 40*0.4 = 36, which is medium
    expect(monitor.currentMetrics.getLoadLevel()).toBe('medium');
    monitor.destroy();
  });

  it('should return high load level when load is between 60 and 79', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 80;
    monitor.currentMetrics.memoryUsage = 80;
    monitor.currentMetrics.queuedRequests = 0;
    // load = 80*0.4 + 80*0.4 = 64, which is high
    expect(monitor.currentMetrics.getLoadLevel()).toBe('high');
    monitor.destroy();
  });

  it('should return critical load level when load is 80 or above', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 100;
    monitor.currentMetrics.memoryUsage = 100;
    monitor.currentMetrics.queuedRequests = 0;
    // load = 100*0.4 + 100*0.4 = 80, which is critical
    expect(monitor.currentMetrics.getLoadLevel()).toBe('critical');
    monitor.destroy();
  });

  it('should calculate load percentage with correct weights', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 100;
    monitor.currentMetrics.memoryUsage = 0;
    monitor.currentMetrics.queuedRequests = 0;
    // CPU weight 0.4: 100 * 0.4 = 40
    expect(monitor.currentMetrics.getLoadPercentage()).toBeCloseTo(40, 1);
    monitor.destroy();
  });

  it('should cap queuedRequests contribution at 100 in load calculation', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 0;
    monitor.currentMetrics.memoryUsage = 0;
    monitor.currentMetrics.queuedRequests = 200;
    // min(200*2, 100) = 100, weight 0.2: 100 * 0.2 = 20
    expect(monitor.currentMetrics.getLoadPercentage()).toBeCloseTo(20, 1);
    monitor.destroy();
  });

  it('should detect high load when percentage >= 60', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 80;
    monitor.currentMetrics.memoryUsage = 80;
    monitor.currentMetrics.queuedRequests = 0;
    expect(monitor.currentMetrics.isHighLoad()).toBe(true);
    monitor.destroy();
  });

  it('should not report high load when percentage < 60', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 10;
    monitor.currentMetrics.memoryUsage = 10;
    monitor.currentMetrics.queuedRequests = 0;
    expect(monitor.currentMetrics.isHighLoad()).toBe(false);
    monitor.destroy();
  });

  it('should detect critical load when percentage >= 80', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 100;
    monitor.currentMetrics.memoryUsage = 100;
    monitor.currentMetrics.queuedRequests = 0;
    expect(monitor.currentMetrics.isCriticalLoad()).toBe(true);
    monitor.destroy();
  });

  it('should not report critical load when percentage < 80', () => {
    const monitor = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
    monitor.stop();
    monitor.currentMetrics.cpuUsage = 50;
    monitor.currentMetrics.memoryUsage = 50;
    monitor.currentMetrics.queuedRequests = 0;
    expect(monitor.currentMetrics.isCriticalLoad()).toBe(false);
    monitor.destroy();
  });
});

describe('SystemLoadMonitor', () => {
  let monitor;

  beforeEach(() => {
    monitor = new SystemLoadMonitor({
      sampleIntervalMs: 999999,
      historySize: 10,
    });
    monitor.stop();
  });

  afterEach(() => {
    monitor.destroy();
  });

  describe('constructor', () => {
    it('should initialize with default config values', () => {
      const m = new SystemLoadMonitor({ sampleIntervalMs: 999999 });
      m.stop();
      expect(m.config.sampleIntervalMs).toBe(999999);
      expect(m.config.cpuThresholdHigh).toBe(70);
      expect(m.config.cpuThresholdCritical).toBe(90);
      expect(m.config.memoryThresholdHigh).toBe(75);
      expect(m.config.memoryThresholdCritical).toBe(90);
      expect(m.adaptiveMultiplier).toBe(1.0);
      m.destroy();
    });

    it('should accept custom config values', () => {
      const m = new SystemLoadMonitor({
        sampleIntervalMs: 999999,
        historySize: 20,
        cpuThresholdHigh: 60,
      });
      m.stop();
      expect(m.config.historySize).toBe(20);
      expect(m.config.cpuThresholdHigh).toBe(60);
      m.destroy();
    });

    it('should initialize request counters to zero', () => {
      expect(monitor.activeRequests).toBe(0);
      expect(monitor.queuedRequests).toBe(0);
      expect(monitor.totalRequests).toBe(0);
      expect(monitor.totalProcessedRequests).toBe(0);
    });

    it('should start with adaptive multiplier of 1.0', () => {
      expect(monitor.adaptiveMultiplier).toBe(1.0);
    });
  });

  describe('recordActiveRequest', () => {
    it('should increment active and total request counts', () => {
      monitor.recordActiveRequest();
      expect(monitor.activeRequests).toBe(1);
      expect(monitor.totalRequests).toBe(1);
      expect(monitor.currentMetrics.activeRequests).toBe(1);
    });

    it('should track multiple active requests', () => {
      monitor.recordActiveRequest();
      monitor.recordActiveRequest();
      monitor.recordActiveRequest();
      expect(monitor.activeRequests).toBe(3);
      expect(monitor.totalRequests).toBe(3);
    });
  });

  describe('recordCompletedRequest', () => {
    it('should decrement active requests and increment processed count', () => {
      monitor.recordActiveRequest();
      monitor.recordCompletedRequest();
      expect(monitor.activeRequests).toBe(0);
      expect(monitor.totalProcessedRequests).toBe(1);
      expect(monitor.currentMetrics.activeRequests).toBe(0);
    });

    it('should not go below zero active requests', () => {
      monitor.recordCompletedRequest();
      expect(monitor.activeRequests).toBe(0);
    });
  });

  describe('recordQueuedRequest', () => {
    it('should increment queued request count', () => {
      monitor.recordQueuedRequest();
      expect(monitor.queuedRequests).toBe(1);
      expect(monitor.currentMetrics.queuedRequests).toBe(1);
    });

    it('should track multiple queued requests', () => {
      monitor.recordQueuedRequest();
      monitor.recordQueuedRequest();
      expect(monitor.queuedRequests).toBe(2);
    });
  });

  describe('recordDequeuedRequest', () => {
    it('should decrement queued request count', () => {
      monitor.recordQueuedRequest();
      monitor.recordDequeuedRequest();
      expect(monitor.queuedRequests).toBe(0);
      expect(monitor.currentMetrics.queuedRequests).toBe(0);
    });

    it('should not go below zero queued requests', () => {
      monitor.recordDequeuedRequest();
      expect(monitor.queuedRequests).toBe(0);
    });
  });

  describe('collectMetrics', () => {
    it('should store snapshot in metrics history', () => {
      monitor.collectMetrics();
      expect(monitor.metricsHistory.length).toBe(1);
      expect(monitor.metricsHistory[0]).toBe(monitor.currentMetrics);
    });

    it('should respect history size limit', () => {
      for (let i = 0; i < 15; i++) {
        monitor.collectMetrics();
      }
      expect(monitor.metricsHistory.length).toBe(10);
    });

    it('should update currentMetrics with latest snapshot', () => {
      const before = monitor.currentMetrics;
      monitor.collectMetrics();
      expect(monitor.currentMetrics).not.toBe(before);
    });

    it('should capture active and queued request counts in snapshot', () => {
      monitor.recordActiveRequest();
      monitor.recordQueuedRequest();
      monitor.collectMetrics();
      const snapshot = monitor.metricsHistory[0];
      expect(snapshot.activeRequests).toBe(1);
      expect(snapshot.queuedRequests).toBe(1);
    });
  });

  describe('updateAdaptiveMultiplier', () => {
    it('should set multiplier to 0.25 for critical load (>= 80)', () => {
      monitor.currentMetrics.cpuUsage = 100;
      monitor.currentMetrics.memoryUsage = 100;
      monitor.currentMetrics.queuedRequests = 0;
      monitor.updateAdaptiveMultiplier(true);
      expect(monitor.adaptiveMultiplier).toBe(0.25);
    });

    it('should set multiplier to 0.5 for high load (>= 60)', () => {
      monitor.currentMetrics.cpuUsage = 80;
      monitor.currentMetrics.memoryUsage = 80;
      monitor.currentMetrics.queuedRequests = 0;
      // load = 80*0.4 + 80*0.4 = 64, which is >= 60 (high)
      monitor.updateAdaptiveMultiplier(true);
      expect(monitor.adaptiveMultiplier).toBe(0.5);
    });

    it('should set multiplier to 0.75 for medium load (> 40)', () => {
      monitor.currentMetrics.cpuUsage = 65;
      monitor.currentMetrics.memoryUsage = 40;
      monitor.currentMetrics.queuedRequests = 0;
      // load = 65*0.4 + 40*0.4 = 42
      monitor.updateAdaptiveMultiplier(true);
      expect(monitor.adaptiveMultiplier).toBe(0.75);
    });

    it('should keep multiplier at 1.0 for low load', () => {
      monitor.currentMetrics.cpuUsage = 10;
      monitor.currentMetrics.memoryUsage = 10;
      monitor.currentMetrics.queuedRequests = 0;
      monitor.updateAdaptiveMultiplier(true);
      expect(monitor.adaptiveMultiplier).toBe(1.0);
    });

    it('should not update during cooldown period', () => {
      monitor.currentMetrics.cpuUsage = 100;
      monitor.currentMetrics.memoryUsage = 100;
      monitor.currentMetrics.queuedRequests = 0;
      monitor.updateAdaptiveMultiplier(true);
      expect(monitor.adaptiveMultiplier).toBe(0.25);

      monitor.currentMetrics.cpuUsage = 0;
      monitor.currentMetrics.memoryUsage = 0;
      monitor.updateAdaptiveMultiplier(false);
      expect(monitor.adaptiveMultiplier).toBe(0.25);
    });

    it('should use average metrics when history is available', () => {
      // Manually push high-load history entries
      const proto = Object.getPrototypeOf(monitor.currentMetrics);
      const snap1 = Object.create(proto);
      snap1.timestamp = new Date();
      snap1.cpuUsage = 100;
      snap1.memoryUsage = 100;
      snap1.activeRequests = 0;
      snap1.queuedRequests = 0;
      snap1.uptime = 100;
      monitor.metricsHistory.push(snap1);

      const snap2 = Object.create(proto);
      snap2.timestamp = new Date();
      snap2.cpuUsage = 100;
      snap2.memoryUsage = 100;
      snap2.activeRequests = 0;
      snap2.queuedRequests = 0;
      snap2.uptime = 100;
      monitor.metricsHistory.push(snap2);

      // Set current metrics to low load to prove average is used
      monitor.currentMetrics.cpuUsage = 0;
      monitor.currentMetrics.memoryUsage = 0;
      monitor.currentMetrics.queuedRequests = 0;

      // Set cooldown far back so non-forced update proceeds
      monitor.lastAdjustmentTime = Date.now() - 60000;
      monitor.updateAdaptiveMultiplier(false);

      // Average load from history is 80 (100*0.4+100*0.4), so multiplier should be 0.25
      expect(monitor.adaptiveMultiplier).toBe(0.25);
    });
  });

  describe('getCurrentMetrics', () => {
    it('should return formatted metrics object', () => {
      const metrics = monitor.getCurrentMetrics();
      expect(metrics).toHaveProperty('cpuUsage');
      expect(metrics).toHaveProperty('memoryUsage');
      expect(metrics).toHaveProperty('activeRequests');
      expect(metrics).toHaveProperty('queuedRequests');
      expect(metrics).toHaveProperty('loadPercentage');
      expect(metrics).toHaveProperty('loadLevel');
      expect(metrics).toHaveProperty('adaptiveMultiplier');
      expect(metrics).toHaveProperty('uptime');
    });

    it('should return string values for numeric metrics', () => {
      const metrics = monitor.getCurrentMetrics();
      expect(typeof metrics.cpuUsage).toBe('string');
      expect(typeof metrics.memoryUsage).toBe('string');
      expect(typeof metrics.loadPercentage).toBe('string');
    });
  });

  describe('getAverageMetrics', () => {
    it('should return current metrics when no history', () => {
      const avg = monitor.getAverageMetrics();
      expect(avg.cpuUsage).toBeDefined();
      expect(avg.memoryUsage).toBeDefined();
      expect(avg.loadPercentage).toBeDefined();
    });

    it('should compute average from history', () => {
      // Push controlled snapshots instead of using collectMetrics which reads real CPU/mem
      const proto = Object.getPrototypeOf(monitor.currentMetrics);
      const snap1 = Object.create(proto);
      snap1.timestamp = new Date();
      snap1.cpuUsage = 50;
      snap1.memoryUsage = 50;
      snap1.activeRequests = 0;
      snap1.queuedRequests = 0;
      snap1.uptime = 100;
      monitor.metricsHistory.push(snap1);

      const snap2 = Object.create(proto);
      snap2.timestamp = new Date();
      snap2.cpuUsage = 30;
      snap2.memoryUsage = 30;
      snap2.activeRequests = 0;
      snap2.queuedRequests = 0;
      snap2.uptime = 100;
      monitor.metricsHistory.push(snap2);

      const avg = monitor.getAverageMetrics();
      expect(parseFloat(avg.cpuUsage)).toBeCloseTo(40, 0);
      expect(parseFloat(avg.memoryUsage)).toBeCloseTo(40, 0);
      expect(avg.sampleCount).toBe(2);
    });
  });

  describe('getAdaptiveLimits', () => {
    it('should return base limit when multiplier is 1.0', () => {
      monitor.adaptiveMultiplier = 1.0;
      const limits = monitor.getAdaptiveLimits(100);
      expect(limits.adaptiveLimit).toBe(100);
      expect(limits.multiplier).toBe('1.00');
      expect(limits.baseLimit).toBe(100);
    });

    it('should reduce limit when multiplier is below 1.0', () => {
      monitor.adaptiveMultiplier = 0.5;
      const limits = monitor.getAdaptiveLimits(100);
      expect(limits.adaptiveLimit).toBe(50);
      expect(limits.multiplier).toBe('0.50');
    });

    it('should include recommendation when under load', () => {
      monitor.adaptiveMultiplier = 0.5;
      const limits = monitor.getAdaptiveLimits(100);
      expect(limits.recommendation).toContain('reduced');
    });

    it('should include recommendation when system is normal', () => {
      monitor.adaptiveMultiplier = 1.0;
      const limits = monitor.getAdaptiveLimits(100);
      expect(limits.recommendation).toContain('normal');
    });

    it('should ceil the adaptive limit', () => {
      monitor.adaptiveMultiplier = 0.75;
      const limits = monitor.getAdaptiveLimits(10);
      expect(limits.adaptiveLimit).toBe(8); // Math.ceil(10 * 0.75) = 8
    });
  });

  describe('getSystemStatus', () => {
    it('should return comprehensive status object', () => {
      const status = monitor.getSystemStatus();
      expect(status).toHaveProperty('current');
      expect(status).toHaveProperty('average');
      expect(status).toHaveProperty('requests');
      expect(status).toHaveProperty('adaptive');
      expect(status).toHaveProperty('system');
    });

    it('should include request tracking in status', () => {
      monitor.recordActiveRequest();
      monitor.recordQueuedRequest();
      const status = monitor.getSystemStatus();
      expect(status.requests.active).toBe(1);
      expect(status.requests.queued).toBe(1);
      expect(status.requests.total).toBe(1);
    });

    it('should include system info', () => {
      const status = monitor.getSystemStatus();
      expect(status.system).toHaveProperty('cpus');
      expect(status.system).toHaveProperty('totalMemory');
      expect(status.system).toHaveProperty('platform');
    });
  });

  describe('lifecycle', () => {
    it('should stop monitoring on stop()', () => {
      const m = new SystemLoadMonitor({ sampleIntervalMs: 100 });
      m.stop();
      expect(m.monitoringInterval).toBeNull();
      m.destroy();
    });

    it('should clear history on destroy()', () => {
      monitor.collectMetrics();
      monitor.collectMetrics();
      expect(monitor.metricsHistory.length).toBe(2);
      monitor.destroy();
      expect(monitor.metricsHistory.length).toBe(0);
    });
  });
});
