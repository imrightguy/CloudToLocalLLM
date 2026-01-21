/**
 * Error Recovery Service
 *
 * Implements error recovery procedures and manual intervention endpoints.
 * Provides recovery status reporting and recovery procedure execution.
 *
 * Requirement 7.7: THE API SHALL provide error recovery endpoints for manual intervention
 */

import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'error-recovery' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

/**
 * Error Recovery Service
 * Manages error recovery procedures and recovery status
 */
export class ErrorRecoveryService {
  constructor() {
    // Track recovery procedures
    this.recoveryProcedures = new Map();

    // Track recovery status for each service
    this.recoveryStatus = new Map();

    // Track recovery history
    this.recoveryHistory = [];

    // Metrics
    this.metrics = {
      totalRecoveryAttempts: 0,
      successfulRecoveries: 0,
      failedRecoveries: 0,
      averageRecoveryTime: 0,
      recoveryTimes: [],
    };
  }

  /**
   * Register a recovery procedure for a service
   * @param {string} serviceName - Name of the service
   * @param {Object} config - Configuration for the recovery procedure
   * @param {Function} config.procedure - Recovery procedure function
   * @param {string} config.description - Description of the recovery procedure
   * @param {Array<string>} config.prerequisites - Prerequisites for recovery
   * @param {number} config.timeoutMs - Timeout for recovery procedure (default: 30000)
   */
  registerRecoveryProcedure(serviceName, config = {}) {
    if (!serviceName) {
      throw new Error('Service name is required');
    }

    if (!config.procedure || typeof config.procedure !== 'function') {
      throw new Error('Recovery procedure function is required');
    }

    this.recoveryProcedures.set(serviceName, {
      procedure: config.procedure,
      description:
        config.description || `Recovery procedure for ${serviceName}`,
      prerequisites: config.prerequisites || [],
      timeoutMs: config.timeoutMs || 30000,
      lastAttempt: null,
      lastSuccess: null,
    });

    this.recoveryStatus.set(serviceName, {
      isRecovering: false,
      lastRecoveryAttempt: null,
      lastRecoveryResult: null,
      recoveryCount: 0,
      successCount: 0,
      failureCount: 0,
    });

    logger.info(`Recovery procedure registered for service: ${serviceName}`);
  }

  /**
   * Execute a recovery procedure for a service
   * @param {string} serviceName - Name of the service
   * @param {Object} options - Options for recovery
   * @param {string} options.initiatedBy - User or system that initiated recovery
   * @param {string} options.reason - Reason for recovery
   * @returns {Promise<Object>} - Recovery result
   */
  async executeRecovery(serviceName, options = {}) {
    if (!this.recoveryProcedures.has(serviceName)) {
      throw new Error(
        `No recovery procedure registered for service: ${serviceName}`,
      );
    }

    const procedure = this.recoveryProcedures.get(serviceName);
    const status = this.recoveryStatus.get(serviceName);

    // Check if already recovering
    if (status.isRecovering) {
      throw new Error(
        `Recovery already in progress for service: ${serviceName}`,
      );
    }

    const startTime = Date.now();
    const recoveryId = `recovery-${serviceName}-${startTime}`;

    try {
      status.isRecovering = true;
      status.lastRecoveryAttempt = new Date().toISOString();
      this.metrics.totalRecoveryAttempts++;

      logger.info(`Starting recovery procedure for service: ${serviceName}`, {
        recoveryId,
        initiatedBy: options.initiatedBy || 'system',
        reason: options.reason || 'unknown',
      });

      // Execute recovery procedure with timeout
      const result = await this._executeWithTimeout(
        procedure.procedure,
        procedure.timeoutMs,
        recoveryId,
      );

      const duration = Date.now() - startTime;
      status.recoveryCount++;
      status.successCount++;
      status.lastRecoveryResult = {
        status: 'success',
        result,
        duration,
        timestamp: new Date().toISOString(),
      };

      this.metrics.successfulRecoveries++;
      this.metrics.recoveryTimes.push(duration);
      this._updateAverageRecoveryTime();

      procedure.lastSuccess = new Date().toISOString();

      logger.info(
        `Recovery procedure completed successfully for service: ${serviceName}`,
        {
          recoveryId,
          duration,
          result,
        },
      );

      this._addToHistory({
        serviceName,
        recoveryId,
        status: 'success',
        duration,
        initiatedBy: options.initiatedBy || 'system',
        reason: options.reason || 'unknown',
        result,
      });

      return {
        recoveryId,
        service: serviceName,
        status: 'success',
        duration,
        result,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      status.recoveryCount++;
      status.failureCount++;
      status.lastRecoveryResult = {
        status: 'failed',
        error: error.message,
        duration,
        timestamp: new Date().toISOString(),
      };

      this.metrics.failedRecoveries++;

      logger.error(`Recovery procedure failed for service: ${serviceName}`, {
        recoveryId,
        error: error.message,
        duration,
      });

      this._addToHistory({
        serviceName,
        recoveryId,
        status: 'failed',
        duration,
        initiatedBy: options.initiatedBy || 'system',
        reason: options.reason || 'unknown',
        error: error.message,
      });

      throw error;
    } finally {
      status.isRecovering = false;
    }
  }

  /**
   * Execute a function with timeout
   * @private
   * @param {Function} fn - Function to execute
   * @param {number} timeoutMs - Timeout in milliseconds
   * @param {string} recoveryId - Recovery ID for logging
   * @returns {Promise} - Result of function
   */
  async _executeWithTimeout(fn, timeoutMs, _recoveryId) {
    let timeoutId;

    const timeoutPromise = new Promise((_, reject) => {
      timeoutId = setTimeout(() => {
        reject(new Error(`Recovery procedure timeout after ${timeoutMs}ms`));
      }, timeoutMs);
    });

    try {
      return await Promise.race([fn(), timeoutPromise]);
    } finally {
      if (timeoutId) {
        clearTimeout(timeoutId);
      }
    }
  }

  /**
   * Get recovery status for a service
   * @param {string} serviceName - Name of the service
   * @returns {Object} - Recovery status
   */
  getRecoveryStatus(serviceName) {
    if (!this.recoveryStatus.has(serviceName)) {
      return {
        service: serviceName,
        status: 'unknown',
        message: 'No recovery procedure registered for this service',
      };
    }

    const status = this.recoveryStatus.get(serviceName);
    const procedure = this.recoveryProcedures.get(serviceName);

    return {
      service: serviceName,
      isRecovering: status.isRecovering,
      lastRecoveryAttempt: status.lastRecoveryAttempt,
      lastRecoveryResult: status.lastRecoveryResult,
      recoveryCount: status.recoveryCount,
      successCount: status.successCount,
      failureCount: status.failureCount,
      successRate:
        status.recoveryCount > 0
          ? ((status.successCount / status.recoveryCount) * 100).toFixed(2) +
            '%'
          : 'N/A',
      description: procedure?.description || 'Unknown',
      prerequisites: procedure?.prerequisites || [],
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Get recovery status for all services
   * @returns {Array} - Array of recovery statuses
   */
  getAllRecoveryStatuses() {
    const statuses = [];
    for (const [serviceName] of this.recoveryStatus) {
      statuses.push(this.getRecoveryStatus(serviceName));
    }
    return statuses;
  }

  /**
   * Get recovery history
   * @param {Object} options - Options for filtering history
   * @param {string} options.serviceName - Filter by service name
   * @param {string} options.status - Filter by status (success, failed)
   * @param {number} options.limit - Limit number of results
   * @returns {Array} - Recovery history
   */
  getRecoveryHistory(options = {}) {
    let history = [...this.recoveryHistory];

    if (options.serviceName) {
      history = history.filter((h) => h.serviceName === options.serviceName);
    }

    if (options.status) {
      history = history.filter((h) => h.status === options.status);
    }

    if (options.limit) {
      history = history.slice(-options.limit);
    }

    return history;
  }

  /**
   * Add entry to recovery history
   * @private
   * @param {Object} entry - History entry
   */
  _addToHistory(entry) {
    this.recoveryHistory.push({
      ...entry,
      timestamp: new Date().toISOString(),
    });

    // Keep history size manageable (max 1000 entries)
    if (this.recoveryHistory.length > 1000) {
      this.recoveryHistory = this.recoveryHistory.slice(-1000);
    }
  }

  /**
   * Update average recovery time
   * @private
   */
  _updateAverageRecoveryTime() {
    if (this.metrics.recoveryTimes.length === 0) {
      this.metrics.averageRecoveryTime = 0;
      return;
    }

    const sum = this.metrics.recoveryTimes.reduce((a, b) => a + b, 0);
    this.metrics.averageRecoveryTime = Math.round(
      sum / this.metrics.recoveryTimes.length,
    );

    // Keep only last 100 recovery times for memory efficiency
    if (this.metrics.recoveryTimes.length > 100) {
      this.metrics.recoveryTimes = this.metrics.recoveryTimes.slice(-100);
    }
  }

  /**
   * Get recovery metrics
   * @returns {Object} - Recovery metrics
   */
  getMetrics() {
    return {
      ...this.metrics,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Get recovery report
   * @returns {Object} - Comprehensive recovery report
   */
  getReport() {
    const statuses = this.getAllRecoveryStatuses();
    const recentHistory = this.getRecoveryHistory({ limit: 10 });

    return {
      timestamp: new Date().toISOString(),
      summary: {
        totalServices: statuses.length,
        servicesRecovering: statuses.filter((s) => s.isRecovering).length,
        totalRecoveryAttempts: this.metrics.totalRecoveryAttempts,
        successfulRecoveries: this.metrics.successfulRecoveries,
        failedRecoveries: this.metrics.failedRecoveries,
        successRate:
          this.metrics.totalRecoveryAttempts > 0
            ? (
                (this.metrics.successfulRecoveries /
                  this.metrics.totalRecoveryAttempts) *
                100
              ).toFixed(2) + '%'
            : 'N/A',
        averageRecoveryTime: this.metrics.averageRecoveryTime + 'ms',
      },
      services: statuses,
      recentHistory,
    };
  }

  /**
   * Clear recovery history
   */
  clearHistory() {
    this.recoveryHistory = [];
    logger.info('Recovery history cleared');
  }

  /**
   * Reset all recovery metrics
   */
  resetMetrics() {
    this.metrics = {
      totalRecoveryAttempts: 0,
      successfulRecoveries: 0,
      failedRecoveries: 0,
      averageRecoveryTime: 0,
      recoveryTimes: [],
    };
    logger.info('Recovery metrics reset');
  }
}

// Singleton instance
export const errorRecoveryService = new ErrorRecoveryService();
