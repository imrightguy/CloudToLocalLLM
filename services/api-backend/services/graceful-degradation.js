/**
 * Graceful Degradation Service
 *
 * Implements graceful degradation when services are unavailable.
 * Provides fallback mechanisms and reduced functionality modes.
 *
 * Requirement 7.6: THE API SHALL implement graceful degradation when services are unavailable
 */

import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'graceful-degradation' },
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
 * Graceful Degradation Service
 * Manages service degradation states and fallback mechanisms
 */
export class GracefulDegradationService {
  constructor() {
    // Track degradation state for each service
    this.degradationStates = new Map();

    // Define fallback strategies for each service
    this.fallbackStrategies = new Map();

    // Track when degradation started
    this.degradationStartTimes = new Map();

    // Metrics
    this.metrics = {
      totalDegradations: 0,
      activeDegradations: 0,
      fallbacksUsed: 0,
      recoveries: 0,
    };
  }

  /**
   * Register a service for degradation management
   * @param {string} serviceName - Name of the service
   * @param {Object} config - Configuration for the service
   * @param {Function} config.fallback - Fallback function to use when service is unavailable
   * @param {Array<string>} config.criticalEndpoints - Endpoints that cannot be degraded
   * @param {Object} config.reducedFunctionality - Reduced functionality configuration
   */
  registerService(serviceName, config = {}) {
    if (!serviceName) {
      throw new Error('Service name is required');
    }

    this.degradationStates.set(serviceName, {
      isDegraded: false,
      reason: null,
      severity: 'none', // none, warning, critical
      affectedEndpoints: [],
      fallbackActive: false,
    });

    this.fallbackStrategies.set(serviceName, {
      fallback: config.fallback || null,
      criticalEndpoints: config.criticalEndpoints || [],
      reducedFunctionality: config.reducedFunctionality || {},
      retryConfig: config.retryConfig || { maxRetries: 3, backoffMs: 1000 },
    });

    logger.info(
      `Service registered for degradation management: ${serviceName}`,
    );
  }

  /**
   * Mark a service as degraded
   * @param {string} serviceName - Name of the service
   * @param {string} reason - Reason for degradation
   * @param {string} severity - Severity level (warning, critical)
   */
  markDegraded(serviceName, reason = 'Unknown', severity = 'warning') {
    if (!this.degradationStates.has(serviceName)) {
      logger.warn(`Service not registered for degradation: ${serviceName}`);
      return;
    }

    const state = this.degradationStates.get(serviceName);
    if (!state.isDegraded) {
      this.metrics.totalDegradations++;
      this.metrics.activeDegradations++;
      this.degradationStartTimes.set(serviceName, Date.now());
    }

    state.isDegraded = true;
    state.reason = reason;
    state.severity = severity;

    logger.warn(`Service degraded: ${serviceName}`, {
      reason,
      severity,
      timestamp: new Date().toISOString(),
    });
  }

  /**
   * Mark a service as recovered
   * @param {string} serviceName - Name of the service
   */
  markRecovered(serviceName) {
    if (!this.degradationStates.has(serviceName)) {
      logger.warn(`Service not registered for degradation: ${serviceName}`);
      return;
    }

    const state = this.degradationStates.get(serviceName);
    if (state.isDegraded) {
      this.metrics.activeDegradations--;
      this.metrics.recoveries++;

      const degradationDuration =
        Date.now() -
        (this.degradationStartTimes.get(serviceName) || Date.now());
      logger.info(`Service recovered: ${serviceName}`, {
        degradationDurationMs: degradationDuration,
        timestamp: new Date().toISOString(),
      });
    }

    state.isDegraded = false;
    state.reason = null;
    state.severity = 'none';
    state.fallbackActive = false;
    state.affectedEndpoints = [];
    this.degradationStartTimes.delete(serviceName);
  }

  /**
   * Get degradation status for a service
   * @param {string} serviceName - Name of the service
   * @returns {Object} - Degradation status
   */
  getStatus(serviceName) {
    if (!this.degradationStates.has(serviceName)) {
      return {
        service: serviceName,
        isDegraded: false,
        status: 'unknown',
      };
    }

    const state = this.degradationStates.get(serviceName);
    return {
      service: serviceName,
      isDegraded: state.isDegraded,
      reason: state.reason,
      severity: state.severity,
      affectedEndpoints: state.affectedEndpoints,
      fallbackActive: state.fallbackActive,
      degradationStartTime: this.degradationStartTimes.get(serviceName) || null,
      status: state.isDegraded ? 'degraded' : 'healthy',
    };
  }

  /**
   * Get all degradation statuses
   * @returns {Array} - Array of degradation statuses
   */
  getAllStatuses() {
    const statuses = [];
    for (const [serviceName] of this.degradationStates) {
      statuses.push(this.getStatus(serviceName));
    }
    return statuses;
  }

  /**
   * Execute a function with fallback support
   * @param {string} serviceName - Name of the service
   * @param {Function} primaryFn - Primary function to execute
   * @param {*} context - Context to bind to the function
   * @param {Array} args - Arguments to pass to the function
   * @returns {Promise} - Result of primary or fallback function
   */
  async executeWithFallback(serviceName, primaryFn, context = null, args = []) {
    if (!this.degradationStates.has(serviceName)) {
      throw new Error(`Service not registered: ${serviceName}`);
    }

    const state = this.degradationStates.get(serviceName);
    const strategy = this.fallbackStrategies.get(serviceName);

    try {
      // Try primary function
      const result = await primaryFn.apply(context, args);

      // If successful and was degraded, mark as recovered
      if (state.isDegraded) {
        this.markRecovered(serviceName);
      }

      return result;
    } catch (error) {
      // Mark as degraded
      this.markDegraded(serviceName, error.message, 'warning');

      // Try fallback if available
      if (strategy.fallback) {
        try {
          this.metrics.fallbacksUsed++;
          state.fallbackActive = true;
          logger.info(`Using fallback for service: ${serviceName}`);
          return await strategy.fallback.apply(context, args);
        } catch (fallbackError) {
          logger.error(`Fallback failed for service: ${serviceName}`, {
            error: fallbackError.message,
          });
          throw fallbackError;
        }
      }

      throw error;
    }
  }

  /**
   * Get reduced functionality response for a service
   * @param {string} serviceName - Name of the service
   * @param {string} endpoint - Endpoint being accessed
   * @returns {Object} - Reduced functionality response
   */
  getReducedFunctionalityResponse(serviceName, endpoint) {
    const strategy = this.fallbackStrategies.get(serviceName);
    if (!strategy) {
      return null;
    }

    const reducedFunctionality = strategy.reducedFunctionality;

    return {
      isDegraded: true,
      service: serviceName,
      endpoint,
      message: 'Service is operating in reduced functionality mode',
      availableFeatures: reducedFunctionality.availableFeatures || [],
      unavailableFeatures: reducedFunctionality.unavailableFeatures || [],
      estimatedRecoveryTime: reducedFunctionality.estimatedRecoveryTime || null,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Check if an endpoint is critical and cannot be degraded
   * @param {string} serviceName - Name of the service
   * @param {string} endpoint - Endpoint to check
   * @returns {boolean} - True if endpoint is critical
   */
  isCriticalEndpoint(serviceName, endpoint) {
    const strategy = this.fallbackStrategies.get(serviceName);
    if (!strategy) {
      return false;
    }

    return strategy.criticalEndpoints.includes(endpoint);
  }

  /**
   * Get metrics for degradation service
   * @returns {Object} - Metrics
   */
  getMetrics() {
    return {
      ...this.metrics,
      activeDegradedServices: Array.from(
        this.degradationStates.values(),
      ).filter((state) => state.isDegraded).length,
      timestamp: new Date().toISOString(),
    };
  }

  /**
   * Reset all degradation states
   */
  resetAll() {
    for (const [serviceName] of this.degradationStates) {
      this.markRecovered(serviceName);
    }
    logger.info('All degradation states reset');
  }

  /**
   * Get degradation report
   * @returns {Object} - Comprehensive degradation report
   */
  getReport() {
    const statuses = this.getAllStatuses();
    const degradedServices = statuses.filter((s) => s.isDegraded);

    return {
      timestamp: new Date().toISOString(),
      totalServices: statuses.length,
      degradedServices: degradedServices.length,
      healthyServices: statuses.length - degradedServices.length,
      services: statuses,
      metrics: this.getMetrics(),
      summary: {
        overallStatus: degradedServices.length === 0 ? 'healthy' : 'degraded',
        criticalDegradations: degradedServices.filter(
          (s) => s.severity === 'critical',
        ).length,
        warningDegradations: degradedServices.filter(
          (s) => s.severity === 'warning',
        ).length,
      },
    };
  }
}

// Singleton instance
export const gracefulDegradationService = new GracefulDegradationService();
