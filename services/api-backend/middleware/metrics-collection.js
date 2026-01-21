/**
 * @fileoverview Metrics collection middleware for HTTP requests
 * Automatically collects request latency, throughput, and error metrics
 */

import { metricsService } from '../services/metrics-service.js';
import { TunnelLogger } from '../utils/logger.js';

const logger = new TunnelLogger('metrics-collection-middleware');

/**
 * Create metrics collection middleware
 * Collects HTTP request metrics for Prometheus
 * @returns {Function} Express middleware function
 */
export function createMetricsCollectionMiddleware() {
  return (req, res, next) => {
    // Record request start time
    const startTime = Date.now();

    // Get route path (normalize for metrics)
    const route = req.route?.path || req.path || 'unknown';

    // Intercept response to collect metrics
    const originalSend = res.send;
    const originalJson = res.json;

    res.send = function (data) {
      const duration = Date.now() - startTime;
      const status = res.statusCode || 500;

      // Record metrics
      try {
        metricsService.recordHttpRequest({
          method: req.method,
          route,
          status,
          duration,
          error: null,
        });
      } catch (error) {
        logger.error('Failed to record HTTP metrics', {
          error: error.message,
        });
      }

      return originalSend.call(this, data);
    };

    res.json = function (data) {
      const duration = Date.now() - startTime;
      const status = res.statusCode || 500;

      // Record metrics
      try {
        metricsService.recordHttpRequest({
          method: req.method,
          route,
          status,
          duration,
          error: null,
        });
      } catch (error) {
        logger.error('Failed to record HTTP metrics', {
          error: error.message,
        });
      }

      return originalJson.call(this, data);
    };

    // Handle errors
    const originalStatus = res.status;
    res.status = function (code) {
      res.statusCode = code;
      return originalStatus.call(this, code);
    };

    next();
  };
}

/**
 * Default metrics collection middleware
 */
export const metricsCollectionMiddleware = createMetricsCollectionMiddleware();

export default metricsCollectionMiddleware;
