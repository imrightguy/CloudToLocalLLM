import winston from 'winston';

/**
 * ProxyHealthService - Manages proxy health checks and auto-recovery
 * Implements health monitoring, status tracking, and automatic recovery mechanisms
 * for streaming proxy instances
 */
export class ProxyHealthService {
  constructor(logger = null) {
    this.logger =
      logger ||
      winston.createLogger({
        level: process.env.LOG_LEVEL || 'info',
        format: winston.format.combine(
          winston.format.timestamp(),
          winston.format.errors({ stack: true }),
          winston.format.json(),
        ),
        defaultMeta: { service: 'proxy-health' },
        transports: [
          new winston.transports.Console({
            format: winston.format.combine(
              winston.format.timestamp(),
              winston.format.simple(),
            ),
          }),
        ],
      });

    // Track proxy health status
    this.proxyHealthStatus = new Map(); // proxyId -> health status
    this.proxyRecoveryAttempts = new Map(); // proxyId -> recovery attempt count
    this.proxyLastHealthCheck = new Map(); // proxyId -> last health check timestamp
    this.proxyMetrics = new Map(); // proxyId -> metrics data

    // Configuration
    this.healthCheckIntervalMs = parseInt(
      process.env.PROXY_HEALTH_CHECK_INTERVAL || '30000',
      10,
    );
    this.maxRecoveryAttempts = parseInt(
      process.env.PROXY_MAX_RECOVERY_ATTEMPTS || '3',
      10,
    );
    this.recoveryBackoffMs = parseInt(
      process.env.PROXY_RECOVERY_BACKOFF || '5000',
      10,
    );
    this.healthCheckTimeoutMs = parseInt(
      process.env.PROXY_HEALTH_CHECK_TIMEOUT || '5000',
      10,
    );
    this.unhealthyThresholdMs = parseInt(
      process.env.PROXY_UNHEALTHY_THRESHOLD || '60000',
      10,
    );

    // Health check interval
    this.healthCheckInterval = null;

    // Recovery callbacks
    this.onRecoveryNeeded = null;
    this.onHealthStatusChanged = null;
  }

  /**
   * Register a proxy for health monitoring
   * @param {string} proxyId - Unique proxy identifier
   * @param {Object} proxyMetadata - Proxy metadata (userId, containerId, etc.)
   */
  registerProxy(proxyId, proxyMetadata) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    this.proxyHealthStatus.set(proxyId, {
      status: 'unknown',
      lastCheck: null,
      consecutiveFailures: 0,
      recoveryAttempts: 0,
    });

    this.proxyRecoveryAttempts.set(proxyId, 0);
    this.proxyLastHealthCheck.set(proxyId, null);
    this.proxyMetrics.set(proxyId, {
      requestCount: 0,
      successCount: 0,
      errorCount: 0,
      averageLatency: 0,
      lastUpdated: new Date(),
    });

    this.logger.info(`Registered proxy for health monitoring: ${proxyId}`, {
      proxyId,
      metadata: proxyMetadata,
    });
  }

  /**
   * Unregister a proxy from health monitoring
   * @param {string} proxyId - Unique proxy identifier
   */
  unregisterProxy(proxyId) {
    this.proxyHealthStatus.delete(proxyId);
    this.proxyRecoveryAttempts.delete(proxyId);
    this.proxyLastHealthCheck.delete(proxyId);
    this.proxyMetrics.delete(proxyId);

    this.logger.info(`Unregistered proxy from health monitoring: ${proxyId}`, {
      proxyId,
    });
  }

  /**
   * Perform health check on a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {Function} healthCheckFn - Async function that performs the health check
   * @returns {Promise<Object>} Health check result
   */
  async checkProxyHealth(proxyId, healthCheckFn) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    if (!this.proxyHealthStatus.has(proxyId)) {
      throw new Error(`Proxy not registered: ${proxyId}`);
    }

    const startTime = Date.now();

    try {
      // Execute health check with timeout. Always clear the timeout after
      // Promise.race resolves so successful checks do not leave open handles in
      // tests or long-lived processes.
      const healthCheckPromise = healthCheckFn();
      let timeoutId;
      const timeoutPromise = new Promise((_, reject) => {
        timeoutId = setTimeout(
          () => reject(new Error('Health check timeout')),
          this.healthCheckTimeoutMs,
        );
      });

      let result;
      try {
        result = await Promise.race([healthCheckPromise, timeoutPromise]);
      } finally {
        if (timeoutId) {
          clearTimeout(timeoutId);
        }
      }

      // Update health status
      const currentStatus = this.proxyHealthStatus.get(proxyId);
      const previousStatus = currentStatus.status;

      currentStatus.status = 'healthy';
      currentStatus.lastCheck = new Date();
      currentStatus.consecutiveFailures = 0;
      this.proxyLastHealthCheck.set(proxyId, new Date());

      // Log status change
      if (previousStatus !== 'healthy') {
        this.logger.info(`Proxy health status changed: ${proxyId}`, {
          proxyId,
          previousStatus,
          newStatus: 'healthy',
          checkDuration: Date.now() - startTime,
        });

        if (this.onHealthStatusChanged) {
          this.onHealthStatusChanged(proxyId, previousStatus, 'healthy');
        }
      }

      return {
        proxyId,
        status: 'healthy',
        checkDuration: Date.now() - startTime,
        result,
      };
    } catch (error) {
      // Update health status
      const currentStatus = this.proxyHealthStatus.get(proxyId);
      const previousStatus = currentStatus.status;

      currentStatus.consecutiveFailures += 1;
      currentStatus.lastCheck = new Date();
      this.proxyLastHealthCheck.set(proxyId, new Date());

      // Determine if proxy is unhealthy
      const isUnhealthy = currentStatus.consecutiveFailures >= 3;
      const newStatus = isUnhealthy ? 'unhealthy' : 'degraded';

      if (previousStatus !== newStatus) {
        currentStatus.status = newStatus;

        this.logger.warn(`Proxy health status changed: ${proxyId}`, {
          proxyId,
          previousStatus,
          newStatus,
          consecutiveFailures: currentStatus.consecutiveFailures,
          error: error.message,
          checkDuration: Date.now() - startTime,
        });

        if (this.onHealthStatusChanged) {
          this.onHealthStatusChanged(proxyId, previousStatus, newStatus);
        }

        // Trigger recovery if unhealthy and recovery attempts not exceeded
        if (
          newStatus === 'unhealthy' &&
          this.onRecoveryNeeded &&
          currentStatus.recoveryAttempts < this.maxRecoveryAttempts
        ) {
          this.onRecoveryNeeded(proxyId, error);
        }
      }

      return {
        proxyId,
        status: newStatus,
        checkDuration: Date.now() - startTime,
        error: error.message,
        consecutiveFailures: currentStatus.consecutiveFailures,
      };
    }
  }

  /**
   * Get health status for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Object} Current health status
   */
  getProxyHealthStatus(proxyId) {
    if (!this.proxyHealthStatus.has(proxyId)) {
      return {
        proxyId,
        status: 'unknown',
        message: 'Proxy not registered',
      };
    }

    const status = this.proxyHealthStatus.get(proxyId);
    const metrics = this.proxyMetrics.get(proxyId);

    return {
      proxyId,
      status: status.status,
      lastCheck: status.lastCheck,
      consecutiveFailures: status.consecutiveFailures,
      recoveryAttempts: status.recoveryAttempts,
      metrics: metrics || {},
    };
  }

  /**
   * Get health status for all proxies
   * @returns {Array} Array of health statuses
   */
  getAllProxyHealthStatus() {
    const statuses = [];

    for (const [proxyId, status] of this.proxyHealthStatus.entries()) {
      const metrics = this.proxyMetrics.get(proxyId);
      statuses.push({
        proxyId,
        status: status.status,
        lastCheck: status.lastCheck,
        consecutiveFailures: status.consecutiveFailures,
        recoveryAttempts: status.recoveryAttempts,
        metrics: metrics || {},
      });
    }

    return statuses;
  }

  /**
   * Record recovery attempt for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @returns {boolean} Whether recovery should be attempted
   */
  recordRecoveryAttempt(proxyId) {
    if (!this.proxyHealthStatus.has(proxyId)) {
      return false;
    }

    const status = this.proxyHealthStatus.get(proxyId);
    const wasBelowMax = status.recoveryAttempts < this.maxRecoveryAttempts;
    status.recoveryAttempts = Math.min(
      status.recoveryAttempts + 1,
      this.maxRecoveryAttempts,
    );

    this.logger.info(`Recorded recovery attempt for proxy: ${proxyId}`, {
      proxyId,
      recoveryAttempts: status.recoveryAttempts,
      maxAttempts: this.maxRecoveryAttempts,
    });

    return wasBelowMax;
  }

  /**
   * Reset recovery attempts for a proxy
   * @param {string} proxyId - Unique proxy identifier
   */
  resetRecoveryAttempts(proxyId) {
    if (!this.proxyHealthStatus.has(proxyId)) {
      return;
    }

    const status = this.proxyHealthStatus.get(proxyId);
    status.recoveryAttempts = 0;
    status.consecutiveFailures = 0;

    this.logger.info(`Reset recovery attempts for proxy: ${proxyId}`, {
      proxyId,
    });
  }

  /**
   * Update proxy metrics
   * @param {string} proxyId - Unique proxy identifier
   * @param {Object} metrics - Metrics to update
   */
  updateProxyMetrics(proxyId, metrics) {
    if (!this.proxyMetrics.has(proxyId)) {
      return;
    }

    const currentMetrics = this.proxyMetrics.get(proxyId);

    if (metrics.requestCount !== undefined) {
      currentMetrics.requestCount = metrics.requestCount;
    }
    if (metrics.successCount !== undefined) {
      currentMetrics.successCount = metrics.successCount;
    }
    if (metrics.errorCount !== undefined) {
      currentMetrics.errorCount = metrics.errorCount;
    }
    if (metrics.averageLatency !== undefined) {
      currentMetrics.averageLatency = metrics.averageLatency;
    }

    currentMetrics.lastUpdated = new Date();
  }

  /**
   * Get proxy metrics
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Object} Proxy metrics
   */
  getProxyMetrics(proxyId) {
    if (!this.proxyMetrics.has(proxyId)) {
      return null;
    }

    return this.proxyMetrics.get(proxyId);
  }

  /**
   * Start periodic health checks
   * @param {Function} healthCheckFn - Async function that performs health checks for all proxies
   */
  startHealthChecks(healthCheckFn) {
    if (this.healthCheckInterval) {
      this.logger.warn('Health checks already running');
      return;
    }

    this.logger.info('Starting proxy health checks', {
      intervalMs: this.healthCheckIntervalMs,
    });

    this.healthCheckInterval = setInterval(async () => {
      try {
        await healthCheckFn();
      } catch (error) {
        this.logger.error('Error during health check cycle', {
          error: error.message,
        });
      }
    }, this.healthCheckIntervalMs);
  }

  /**
   * Stop periodic health checks
   */
  stopHealthChecks() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
      this.healthCheckInterval = null;
      this.logger.info('Stopped proxy health checks');
    }
  }

  /**
   * Set callback for when recovery is needed
   * @param {Function} callback - Callback function
   */
  setRecoveryCallback(callback) {
    this.onRecoveryNeeded = callback;
  }

  /**
   * Set callback for when health status changes
   * @param {Function} callback - Callback function
   */
  setHealthStatusChangeCallback(callback) {
    this.onHealthStatusChanged = callback;
  }

  /**
   * Get health check configuration
   * @returns {Object} Configuration object
   */
  getConfiguration() {
    return {
      healthCheckIntervalMs: this.healthCheckIntervalMs,
      maxRecoveryAttempts: this.maxRecoveryAttempts,
      recoveryBackoffMs: this.recoveryBackoffMs,
      healthCheckTimeoutMs: this.healthCheckTimeoutMs,
      unhealthyThresholdMs: this.unhealthyThresholdMs,
    };
  }

  /**
   * Shutdown health service
   */
  shutdown() {
    this.stopHealthChecks();
    this.proxyHealthStatus.clear();
    this.proxyRecoveryAttempts.clear();
    this.proxyLastHealthCheck.clear();
    this.proxyMetrics.clear();

    this.logger.info('Proxy health service shutdown complete');
  }
}

export default ProxyHealthService;
