/**
 * Alert Configuration Service
 *
 * Manages alert configuration for critical metrics:
 * - Alert thresholds for various metrics
 * - Alert channels (email, Slack, PagerDuty)
 * - Alert rules and conditions
 * - Alert history and tracking
 *
 * Requirements: 8.10 (Real-time alerting for critical metrics)
 */

import logger from '../logger.js';

/**
 * Default alert thresholds
 */
const DEFAULT_ALERT_THRESHOLDS = {
  // Response time thresholds (milliseconds)
  responseTime: {
    warning: 500,
    critical: 1000,
  },
  // Error rate thresholds (percentage)
  errorRate: {
    warning: 5,
    critical: 10,
  },
  // CPU usage thresholds (percentage)
  cpuUsage: {
    warning: 70,
    critical: 90,
  },
  // Memory usage thresholds (percentage)
  memoryUsage: {
    warning: 75,
    critical: 90,
  },
  // Database connection pool usage (percentage)
  poolUsage: {
    warning: 80,
    critical: 95,
  },
  // Request queue depth
  queueDepth: {
    warning: 100,
    critical: 500,
  },
  // Active connections
  activeConnections: {
    warning: 1000,
    critical: 5000,
  },
  // Tunnel failures (count in 5 minutes)
  tunnelFailures: {
    warning: 5,
    critical: 20,
  },
};

/**
 * Alert Configuration Service
 */
class AlertConfigurationService {
  constructor() {
    this.thresholds = { ...DEFAULT_ALERT_THRESHOLDS };
    this.enabledChannels = {
      email: process.env.ALERT_EMAIL_ENABLED === 'true',
      slack: process.env.ALERT_SLACK_ENABLED === 'true',
      pagerduty: process.env.ALERT_PAGERDUTY_ENABLED === 'true',
    };
    this.alertHistory = [];
    this.maxHistorySize = 1000;
    this.alertCooldown = new Map(); // Track cooldown for duplicate alerts
    this.cooldownDuration = 5 * 60 * 1000; // 5 minutes
    this.activeAlerts = new Map(); // Track active alerts
  }

  /**
   * Get current alert thresholds
   * @returns {Object} Current thresholds
   */
  getThresholds() {
    return { ...this.thresholds };
  }

  /**
   * Update alert thresholds
   * @param {Object} newThresholds - New threshold values
   * @returns {Object} Updated thresholds
   */
  updateThresholds(newThresholds) {
    try {
      // Validate thresholds
      for (const [metric, levels] of Object.entries(newThresholds)) {
        if (!this.thresholds[metric]) {
          logger.warn(`[Alert Config] Unknown metric: ${metric}`);
          continue;
        }

        if (levels.warning && levels.critical) {
          if (levels.warning >= levels.critical) {
            throw new Error(
              `Warning threshold must be less than critical for ${metric}`,
            );
          }
        }

        this.thresholds[metric] = {
          ...this.thresholds[metric],
          ...levels,
        };
      }

      logger.info('[Alert Config] Thresholds updated', {
        thresholds: this.thresholds,
      });

      return this.thresholds;
    } catch (error) {
      logger.error('[Alert Config] Failed to update thresholds', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get enabled alert channels
   * @returns {Object} Enabled channels
   */
  getEnabledChannels() {
    return { ...this.enabledChannels };
  }

  /**
   * Update enabled channels
   * @param {Object} channels - Channel configuration
   * @returns {Object} Updated channels
   */
  updateEnabledChannels(channels) {
    try {
      for (const [channel, enabled] of Object.entries(channels)) {
        if (
          Object.prototype.hasOwnProperty.call(this.enabledChannels, channel)
        ) {
          this.enabledChannels[channel] = Boolean(enabled);
        }
      }

      logger.info('[Alert Config] Enabled channels updated', {
        channels: this.enabledChannels,
      });

      return this.enabledChannels;
    } catch (error) {
      logger.error('[Alert Config] Failed to update channels', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Check if alert should be triggered based on thresholds
   * @param {string} metric - Metric name
   * @param {number} value - Current metric value
   * @returns {Object} Alert status {shouldAlert: boolean, severity: string}
   */
  checkThreshold(metric, value) {
    if (!this.thresholds[metric]) {
      return { shouldAlert: false, severity: null };
    }

    const { warning, critical } = this.thresholds[metric];

    if (value >= critical) {
      return { shouldAlert: true, severity: 'critical' };
    }

    if (value >= warning) {
      return { shouldAlert: true, severity: 'warning' };
    }

    return { shouldAlert: false, severity: null };
  }

  /**
   * Check if alert is in cooldown period
   * @param {string} alertKey - Unique alert identifier
   * @returns {boolean} True if in cooldown
   */
  isInCooldown(alertKey) {
    const lastAlertTime = this.alertCooldown.get(alertKey);
    if (!lastAlertTime) {
      return false;
    }

    const timeSinceLastAlert = Date.now() - lastAlertTime;
    return timeSinceLastAlert < this.cooldownDuration;
  }

  /**
   * Record alert in history and cooldown
   * @param {string} alertKey - Unique alert identifier
   * @param {Object} alertData - Alert data
   */
  recordAlert(alertKey, alertData) {
    try {
      // Update cooldown
      this.alertCooldown.set(alertKey, Date.now());

      // Add to history
      const alertRecord = {
        key: alertKey,
        timestamp: new Date().toISOString(),
        ...alertData,
      };

      this.alertHistory.push(alertRecord);

      // Maintain max history size
      if (this.alertHistory.length > this.maxHistorySize) {
        this.alertHistory.shift();
      }

      // Track active alert
      this.activeAlerts.set(alertKey, alertRecord);

      logger.info('[Alert Config] Alert recorded', {
        alertKey,
        severity: alertData.severity,
      });
    } catch (error) {
      logger.error('[Alert Config] Failed to record alert', {
        error: error.message,
      });
    }
  }

  /**
   * Clear alert (when condition resolves)
   * @param {string} alertKey - Unique alert identifier
   */
  clearAlert(alertKey) {
    try {
      this.activeAlerts.delete(alertKey);
      logger.info('[Alert Config] Alert cleared', { alertKey });
    } catch (error) {
      logger.error('[Alert Config] Failed to clear alert', {
        error: error.message,
      });
    }
  }

  /**
   * Get alert history
   * @param {Object} options - Query options
   * @returns {Array} Alert history
   */
  getAlertHistory(options = {}) {
    const { limit = 100, metric = null, severity = null } = options;

    let filtered = this.alertHistory;

    if (metric) {
      filtered = filtered.filter((a) => a.metric === metric);
    }

    if (severity) {
      filtered = filtered.filter((a) => a.severity === severity);
    }

    return filtered.slice(-limit);
  }

  /**
   * Get active alerts
   * @returns {Array} Active alerts
   */
  getActiveAlerts() {
    return Array.from(this.activeAlerts.values());
  }

  /**
   * Get alert configuration status
   * @returns {Object} Configuration status
   */
  getStatus() {
    return {
      thresholds: this.thresholds,
      enabledChannels: this.enabledChannels,
      activeAlerts: this.getActiveAlerts(),
      alertHistorySize: this.alertHistory.length,
      cooldownDuration: this.cooldownDuration,
    };
  }

  /**
   * Reset to default thresholds
   */
  resetToDefaults() {
    try {
      this.thresholds = { ...DEFAULT_ALERT_THRESHOLDS };
      logger.info('[Alert Config] Reset to default thresholds');
    } catch (error) {
      logger.error('[Alert Config] Failed to reset thresholds', {
        error: error.message,
      });
      throw error;
    }
  }
}

// Export singleton instance
export const alertConfigService = new AlertConfigurationService();

export default AlertConfigurationService;
