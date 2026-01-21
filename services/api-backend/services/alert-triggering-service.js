/**
 * Alert Triggering Service
 *
 * Implements alert triggering logic for critical metrics:
 * - Evaluates metrics against configured thresholds
 * - Triggers alerts when thresholds are exceeded
 * - Manages alert cooldown to prevent alert storms
 * - Integrates with alerting channels
 *
 * Requirements: 8.10 (Real-time alerting for critical metrics)
 */

import logger from '../logger.js';
import { alertConfigService } from './alert-configuration-service.js';
import { sendAlert } from './alerting-service.js';

/**
 * Alert Triggering Service
 */
class AlertTriggeringService {
  constructor() {
    this.metricsBuffer = new Map();
    this.bufferSize = 100;
    this.evaluationInterval = 10000; // 10 seconds
    this.isRunning = false;
    this.evaluationTimer = null;
  }

  /**
   * Start alert triggering service
   */
  start() {
    if (this.isRunning) {
      logger.warn('[Alert Triggering] Service already running');
      return;
    }

    logger.info('[Alert Triggering] Starting alert triggering service');
    this.isRunning = true;

    // Start periodic evaluation
    this.evaluationTimer = setInterval(() => {
      this.evaluateMetrics();
    }, this.evaluationInterval);
  }

  /**
   * Stop alert triggering service
   */
  stop() {
    if (!this.isRunning) {
      logger.warn('[Alert Triggering] Service not running');
      return;
    }

    logger.info('[Alert Triggering] Stopping alert triggering service');
    this.isRunning = false;

    if (this.evaluationTimer) {
      clearInterval(this.evaluationTimer);
      this.evaluationTimer = null;
    }
  }

  /**
   * Record metric for evaluation
   * @param {string} metric - Metric name
   * @param {number} value - Metric value
   * @param {Object} metadata - Additional metadata
   */
  recordMetric(metric, value, metadata = {}) {
    try {
      if (!this.metricsBuffer.has(metric)) {
        this.metricsBuffer.set(metric, []);
      }

      const buffer = this.metricsBuffer.get(metric);
      buffer.push({
        value,
        timestamp: Date.now(),
        metadata,
      });

      // Maintain buffer size
      if (buffer.length > this.bufferSize) {
        buffer.shift();
      }
    } catch (error) {
      logger.error('[Alert Triggering] Failed to record metric', {
        metric,
        error: error.message,
      });
    }
  }

  /**
   * Get metric statistics
   * @param {string} metric - Metric name
   * @returns {Object} Statistics
   */
  getMetricStats(metric) {
    const buffer = this.metricsBuffer.get(metric) || [];

    if (buffer.length === 0) {
      return null;
    }

    const values = buffer.map((m) => m.value);
    const sum = values.reduce((a, b) => a + b, 0);
    const avg = sum / values.length;
    const max = Math.max(...values);
    const min = Math.min(...values);

    return {
      count: values.length,
      average: avg,
      max,
      min,
      latest: values[values.length - 1],
      timestamp: buffer[buffer.length - 1].timestamp,
    };
  }
  /**
   * Evaluate all metrics and trigger alerts
   */
  async evaluateMetrics() {
    try {
      const thresholds = alertConfigService.getThresholds();

      for (const metric of Object.keys(thresholds)) {
        const stats = this.getMetricStats(metric);

        if (!stats) {
          continue;
        }

        // Check against threshold
        const { shouldAlert, severity } = alertConfigService.checkThreshold(
          metric,
          stats.latest,
        );

        if (shouldAlert) {
          await this.triggerAlert(metric, stats, severity);
        } else {
          // Clear alert if condition resolved
          const alertKey = `${metric}_alert`;
          alertConfigService.clearAlert(alertKey);
        }
      }
    } catch (error) {
      logger.error('[Alert Triggering] Failed to evaluate metrics', {
        error: error.message,
      });
    }
  }

  /**
   * Trigger alert for a metric
   * @param {string} metric - Metric name
   * @param {Object} stats - Metric statistics
   * @param {string} severity - Alert severity
   */
  async triggerAlert(metric, stats, severity) {
    try {
      const alertKey = `${metric}_alert`;

      // Check cooldown
      if (alertConfigService.isInCooldown(alertKey)) {
        return;
      }

      // Record alert
      alertConfigService.recordAlert(alertKey, {
        metric,
        severity,
        value: stats.latest,
        average: stats.average,
        max: stats.max,
        min: stats.min,
      });

      // Prepare alert message
      const title = `${severity.toUpperCase()}: ${metric} threshold exceeded`;
      const message = `The ${metric} metric has exceeded the ${severity} threshold. Current value: ${stats.latest.toFixed(2)}, Average: ${stats.average.toFixed(2)}`;

      const metadata = {
        metric,
        severity,
        currentValue: stats.latest,
        average: stats.average,
        max: stats.max,
        min: stats.min,
        timestamp: new Date(stats.timestamp).toISOString(),
      };

      // Send alert
      await sendAlert(
        `metric_threshold_${metric}`,
        title,
        message,
        metadata,
        severity === 'critical' ? 'critical' : 'error',
      );

      logger.warn('[Alert Triggering] Alert triggered', {
        metric,
        severity,
        value: stats.latest,
      });
    } catch (error) {
      logger.error('[Alert Triggering] Failed to trigger alert', {
        metric,
        error: error.message,
      });
    }
  }

  /**
   * Manually trigger alert for testing
   * @param {string} metric - Metric name
   * @param {number} value - Metric value
   * @param {string} severity - Alert severity
   */
  async manualTrigger(metric, value, severity = 'warning') {
    try {
      const stats = {
        latest: value,
        average: value,
        max: value,
        min: value,
        timestamp: Date.now(),
      };

      await this.triggerAlert(metric, stats, severity);

      logger.info('[Alert Triggering] Manual alert triggered', {
        metric,
        value,
        severity,
      });
    } catch (error) {
      logger.error('[Alert Triggering] Failed to manually trigger alert', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get service status
   * @returns {Object} Service status
   */
  getStatus() {
    return {
      isRunning: this.isRunning,
      evaluationInterval: this.evaluationInterval,
      metricsTracked: this.metricsBuffer.size,
      metrics: Array.from(this.metricsBuffer.keys()),
    };
  }

  /**
   * Get all metric statistics
   * @returns {Object} All metrics statistics
   */
  getAllMetricStats() {
    const stats = {};

    for (const metric of this.metricsBuffer.keys()) {
      stats[metric] = this.getMetricStats(metric);
    }

    return stats;
  }
}

// Export singleton instance
export const alertTriggeringService = new AlertTriggeringService();

export default AlertTriggeringService;
