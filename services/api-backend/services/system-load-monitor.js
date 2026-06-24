/**
 * @fileoverview System Load Monitor Service
 * Monitors system metrics and provides load information for adaptive rate limiting
 * Tracks CPU usage, memory usage, and request queue depth
 */

import os from 'os';
import { TunnelLogger } from '../utils/logger.js';

/**
 * System metrics snapshot
 */
class SystemMetricsSnapshot {
  constructor() {
    this.timestamp = new Date();
    this.cpuUsage = 0;
    this.memoryUsage = 0;
    this.activeRequests = 0;
    this.queuedRequests = 0;
    this.uptime = process.uptime();
  }

  /**
   * Calculate overall system load (0-100)
   * @returns {number} Load percentage
   */
  getLoadPercentage() {
    // Weight: CPU 40%, Memory 40%, Queue 20%
    const cpuWeight = 0.4;
    const memoryWeight = 0.4;
    const queueWeight = 0.2;

    return (
      this.cpuUsage * cpuWeight +
      this.memoryUsage * memoryWeight +
      Math.min(this.queuedRequests * 2, 100) * queueWeight
    );
  }

  /**
   * Get load level (low, medium, high, critical)
   * @returns {string} Load level
   */
  getLoadLevel() {
    const load = this.getLoadPercentage();
    if (load < 30) {
      return 'low';
    }
    if (load < 60) {
      return 'medium';
    }
    if (load < 80) {
      return 'high';
    }
    return 'critical';
  }

  /**
   * Check if system is under high load
   * @returns {boolean} True if load is high or critical
   */
  isHighLoad() {
    return this.getLoadPercentage() >= 60;
  }

  /**
   * Check if system is under critical load
   * @returns {boolean} True if load is critical
   */
  isCriticalLoad() {
    return this.getLoadPercentage() >= 80;
  }
}

/**
 * System Load Monitor
 * Tracks system metrics and provides adaptive rate limiting recommendations
 */
export class SystemLoadMonitor {
  constructor(options = {}) {
    this.logger = new TunnelLogger('system-load-monitor');

    // Configuration
    this.config = {
      sampleIntervalMs: options.sampleIntervalMs || 5000, // 5 seconds
      historySize: options.historySize || 60, // Keep 5 minutes of history
      cpuThresholdHigh: options.cpuThresholdHigh || 70,
      cpuThresholdCritical: options.cpuThresholdCritical || 90,
      memoryThresholdHigh: options.memoryThresholdHigh || 75,
      memoryThresholdCritical: options.memoryThresholdCritical || 90,
      ...options,
    };

    // Metrics storage
    this.metricsHistory = [];
    this.currentMetrics = new SystemMetricsSnapshot();
    this.previousCpuUsage = process.cpuUsage();
    this.previousTime = Date.now();

    // Request tracking
    this.activeRequests = 0;
    this.queuedRequests = 0;
    this.totalRequests = 0;
    this.totalProcessedRequests = 0;

    // Adaptive rate limiting state
    this.adaptiveMultiplier = 1.0; // 1.0 = normal, 0.5 = 50% of normal limits
    this.lastAdjustmentTime = Date.now();
    this.adjustmentCooldownMs = 10000; // 10 seconds between adjustments

    // Start monitoring
    this.startMonitoring();

    this.logger.info('System load monitor initialized', {
      sampleIntervalMs: this.config.sampleIntervalMs,
      historySize: this.config.historySize,
      cpuThresholdHigh: this.config.cpuThresholdHigh,
      cpuThresholdCritical: this.config.cpuThresholdCritical,
      memoryThresholdHigh: this.config.memoryThresholdHigh,
      memoryThresholdCritical: this.config.memoryThresholdCritical,
    });
  }

  /**
   * Start monitoring system metrics
   */
  startMonitoring() {
    this.monitoringInterval = setInterval(() => {
      this.collectMetrics();
      this.updateAdaptiveMultiplier();
    }, this.config.sampleIntervalMs);
  }

  /**
   * Collect current system metrics
   */
  collectMetrics() {
    const snapshot = new SystemMetricsSnapshot();

    // Calculate CPU usage
    const cpuUsage = process.cpuUsage(this.previousCpuUsage);
    const timeDiff = Date.now() - this.previousTime;
    const totalCpuTime = cpuUsage.user + cpuUsage.system;
    const cpuPercent = (totalCpuTime / (timeDiff * 1000)) * 100;

    snapshot.cpuUsage = Math.min(cpuPercent, 100);
    this.previousCpuUsage = process.cpuUsage();
    this.previousTime = Date.now();

    // Calculate memory usage
    const memUsage = process.memoryUsage();
    const totalMemory = os.totalmem();
    const usedMemory = memUsage.heapUsed;
    snapshot.memoryUsage = (usedMemory / totalMemory) * 100;

    // Add request metrics
    snapshot.activeRequests = this.activeRequests;
    snapshot.queuedRequests = this.queuedRequests;

    // Store metrics
    this.currentMetrics = snapshot;
    this.metricsHistory.push(snapshot);

    // Keep history size limited
    if (this.metricsHistory.length > this.config.historySize) {
      this.metricsHistory.shift();
    }

    this.logger.debug('System metrics collected', {
      cpuUsage: snapshot.cpuUsage.toFixed(2),
      memoryUsage: snapshot.memoryUsage.toFixed(2),
      activeRequests: snapshot.activeRequests,
      queuedRequests: snapshot.queuedRequests,
      loadPercentage: snapshot.getLoadPercentage().toFixed(2),
      loadLevel: snapshot.getLoadLevel(),
      adaptiveMultiplier: this.adaptiveMultiplier.toFixed(2),
    });
  }

  /**
   * Update adaptive rate limiting multiplier based on system load
   * @param {boolean} force - Force update regardless of cooldown (for testing)
   */
  updateAdaptiveMultiplier(force = false) {
    const now = Date.now();
    const timeSinceLastAdjustment = now - this.lastAdjustmentTime;

    // Only adjust if cooldown period has passed, unless forced
    if (!force && timeSinceLastAdjustment < this.adjustmentCooldownMs) {
      return;
    }

    // Use current metrics for immediate response, or average if history is available
    const useCurrentMetrics = force || this.metricsHistory.length === 0;

    const load = useCurrentMetrics
      ? this.currentMetrics.getLoadPercentage()
      : parseFloat(this.getAverageMetrics().loadPercentage);

    let newMultiplier;

    // Determine load level based on average load
    const isCritical = load >= 80;
    const isHigh = load >= 60;
    const isMedium = load > 40;

    if (isCritical) {
      // Critical load: reduce to 25% of normal limits
      newMultiplier = 0.25;
    } else if (isHigh) {
      // High load: reduce to 50% of normal limits
      newMultiplier = 0.5;
    } else if (isMedium) {
      // Medium load: reduce to 75% of normal limits
      newMultiplier = 0.75;
    } else {
      // Low load: normal limits
      newMultiplier = 1.0;
    }

    // Only log if multiplier changed
    if (newMultiplier !== this.adaptiveMultiplier) {
      // Get metrics for logging
      const metricsForLogging = useCurrentMetrics
        ? {
            cpuUsage: this.currentMetrics.cpuUsage.toFixed(2),
            memoryUsage: this.currentMetrics.memoryUsage.toFixed(2),
            sampleCount: 0,
          }
        : this.getAverageMetrics();

      this.logger.info('Adaptive rate limit multiplier adjusted', {
        previousMultiplier: this.adaptiveMultiplier.toFixed(2),
        newMultiplier: newMultiplier.toFixed(2),
        averageSystemLoad: load.toFixed(2),
        loadLevel: isCritical
          ? 'critical'
          : isHigh
            ? 'high'
            : isMedium
              ? 'medium'
              : 'low',
        cpuUsage: metricsForLogging.cpuUsage,
        memoryUsage: metricsForLogging.memoryUsage,
        sampleCount: metricsForLogging.sampleCount,
        activeRequests: this.currentMetrics.activeRequests,
        queuedRequests: this.currentMetrics.queuedRequests,
      });

      this.adaptiveMultiplier = newMultiplier;
      this.lastAdjustmentTime = now;
    }
  }

  /**
   * Record an active request
   */
  recordActiveRequest() {
    this.activeRequests++;
    this.totalRequests++;
    // Update current metrics immediately
    this.currentMetrics.activeRequests = this.activeRequests;
  }

  /**
   * Record a completed request
   */
  recordCompletedRequest() {
    if (this.activeRequests > 0) {
      this.activeRequests--;
      // Update current metrics immediately
      this.currentMetrics.activeRequests = this.activeRequests;
    }
    this.totalProcessedRequests++;
  }

  /**
   * Record a queued request
   */
  recordQueuedRequest() {
    this.queuedRequests++;
    // Update current metrics immediately
    this.currentMetrics.queuedRequests = this.queuedRequests;
  }

  /**
   * Record a dequeued request
   */
  recordDequeuedRequest() {
    if (this.queuedRequests > 0) {
      this.queuedRequests--;
      // Update current metrics immediately
      this.currentMetrics.queuedRequests = this.queuedRequests;
    }
  }

  /**
   * Get current system metrics
   * @returns {Object} Current metrics
   */
  getCurrentMetrics() {
    return {
      timestamp: this.currentMetrics.timestamp,
      cpuUsage: this.currentMetrics.cpuUsage.toFixed(2),
      memoryUsage: this.currentMetrics.memoryUsage.toFixed(2),
      activeRequests: this.currentMetrics.activeRequests,
      queuedRequests: this.currentMetrics.queuedRequests,
      loadPercentage: this.currentMetrics.getLoadPercentage().toFixed(2),
      loadLevel: this.currentMetrics.getLoadLevel(),
      adaptiveMultiplier: this.adaptiveMultiplier.toFixed(2),
      uptime: this.currentMetrics.uptime.toFixed(2),
    };
  }

  /**
   * Get average metrics over history
   * @returns {Object} Average metrics
   */
  getAverageMetrics() {
    if (this.metricsHistory.length === 0) {
      return this.getCurrentMetrics();
    }

    const avgCpu =
      this.metricsHistory.reduce((sum, m) => sum + m.cpuUsage, 0) /
      this.metricsHistory.length;
    const avgMemory =
      this.metricsHistory.reduce((sum, m) => sum + m.memoryUsage, 0) /
      this.metricsHistory.length;
    const avgLoad =
      this.metricsHistory.reduce((sum, m) => sum + m.getLoadPercentage(), 0) /
      this.metricsHistory.length;

    return {
      cpuUsage: avgCpu.toFixed(2),
      memoryUsage: avgMemory.toFixed(2),
      loadPercentage: avgLoad.toFixed(2),
      sampleCount: this.metricsHistory.length,
    };
  }

  /**
   * Get adaptive rate limiting recommendations
   * @param {number} baseLimit - Base rate limit
   * @returns {Object} Adaptive limit recommendations
   */
  getAdaptiveLimits(baseLimit) {
    const adaptiveLimit = Math.ceil(baseLimit * this.adaptiveMultiplier);

    return {
      baseLimit,
      adaptiveLimit,
      multiplier: this.adaptiveMultiplier.toFixed(2),
      loadLevel: this.currentMetrics.getLoadLevel(),
      systemLoad: this.currentMetrics.getLoadPercentage().toFixed(2),
      recommendation:
        this.adaptiveMultiplier < 1.0
          ? 'System under load - rate limits reduced'
          : 'System normal - standard rate limits applied',
    };
  }

  /**
   * Get detailed system status
   * @returns {Object} Detailed status
   */
  getSystemStatus() {
    return {
      current: this.getCurrentMetrics(),
      average: this.getAverageMetrics(),
      requests: {
        active: this.activeRequests,
        queued: this.queuedRequests,
        total: this.totalRequests,
        processed: this.totalProcessedRequests,
      },
      adaptive: {
        multiplier: this.adaptiveMultiplier.toFixed(2),
        lastAdjustmentTime: new Date(this.lastAdjustmentTime).toISOString(),
        adjustmentCooldownMs: this.adjustmentCooldownMs,
      },
      system: {
        cpus: os.cpus().length,
        totalMemory: (os.totalmem() / 1024 / 1024 / 1024).toFixed(2) + ' GB',
        freeMemory: (os.freemem() / 1024 / 1024 / 1024).toFixed(2) + ' GB',
        uptime: os.uptime().toFixed(2) + ' seconds',
        platform: os.platform(),
      },
    };
  }

  /**
   * Stop monitoring
   */
  stop() {
    if (this.monitoringInterval) {
      clearInterval(this.monitoringInterval);
      this.monitoringInterval = null;
    }
    this.logger.info('System load monitor stopped');
  }

  /**
   * Destroy the monitor
   */
  destroy() {
    this.stop();
    this.metricsHistory = [];
    this.logger.info('System load monitor destroyed');
  }
}

export default SystemLoadMonitor;
