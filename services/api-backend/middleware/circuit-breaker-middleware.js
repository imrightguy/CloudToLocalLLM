/**
 * Circuit Breaker Middleware
 *
 * Integrates circuit breaker pattern into Express middleware pipeline
 * for protecting service-to-service calls and external API calls.
 */

import { circuitBreakerManager } from '../services/circuit-breaker.js';
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'cloudtolocalllm-api' },
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
 * Create a circuit breaker middleware for a specific service
 * @param {string} serviceName - Name of the service
 * @param {Object} options - Circuit breaker options
 * @returns {Function} Express middleware
 */
export function createCircuitBreakerMiddleware(serviceName, options = {}) {
  const breaker = circuitBreakerManager.getOrCreate(serviceName, {
    failureThreshold: options.failureThreshold || 5,
    successThreshold: options.successThreshold || 2,
    timeout: options.timeout || 60000,
    onStateChange: (change) => {
      logger.warn('Circuit breaker state change', {
        service: serviceName,
        ...change,
      });
    },
  });

  return (req, res, next) => {
    // Attach circuit breaker to request for use in route handlers
    req.circuitBreaker = breaker;
    req.serviceName = serviceName;
    next();
  };
}

/**
 * Middleware to handle circuit breaker errors
 * Should be placed after route handlers
 */
export function circuitBreakerErrorHandler(err, req, res, next) {
  if (err.code === 'CIRCUIT_BREAKER_OPEN') {
    logger.warn('Circuit breaker is open', {
      service: req.serviceName,
      correlationId: req.correlationId,
    });

    return res.status(503).json({
      error: {
        code: 'SERVICE_UNAVAILABLE',
        message: `Service ${req.serviceName} is temporarily unavailable`,
        category: 'service_unavailable',
        statusCode: 503,
        correlationId: req.correlationId,
        suggestion: 'Please try again in a few moments',
      },
    });
  }

  next(err);
}

/**
 * Utility function to execute a function through a circuit breaker
 * @param {string} serviceName - Name of the service
 * @param {Function} fn - Function to execute
 * @param {Object} options - Execution options
 * @returns {Promise} Result of the function
 */
export async function executeWithCircuitBreaker(serviceName, fn, options = {}) {
  const breaker = circuitBreakerManager.getOrCreate(serviceName, {
    failureThreshold: options.failureThreshold || 5,
    successThreshold: options.successThreshold || 2,
    timeout: options.timeout || 60000,
  });

  try {
    return await breaker.execute(fn);
  } catch (error) {
    if (error.code === 'CIRCUIT_BREAKER_OPEN') {
      logger.error('Circuit breaker open for service', {
        service: serviceName,
        error: error.message,
      });
    }
    throw error;
  }
}

/**
 * Get circuit breaker metrics endpoint handler
 */
export function getCircuitBreakerMetrics(req, res) {
  const metrics = circuitBreakerManager.getAllMetrics();
  res.json({
    circuitBreakers: metrics,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Reset all circuit breakers endpoint handler
 */
export function resetAllCircuitBreakers(req, res) {
  circuitBreakerManager.resetAll();
  logger.info('All circuit breakers reset');
  res.json({
    message: 'All circuit breakers have been reset',
    timestamp: new Date().toISOString(),
  });
}

/**
 * Get specific circuit breaker status
 */
export function getCircuitBreakerStatus(req, res) {
  const { serviceName } = req.params;
  const breaker = circuitBreakerManager.get(serviceName);

  if (!breaker) {
    return res.status(404).json({
      error: {
        code: 'NOT_FOUND',
        message: `Circuit breaker for service ${serviceName} not found`,
      },
    });
  }

  res.json({
    service: serviceName,
    metrics: breaker.getMetrics(),
    timestamp: new Date().toISOString(),
  });
}

/**
 * Manually open a circuit breaker
 */
export function openCircuitBreaker(req, res) {
  const { serviceName } = req.params;
  const breaker = circuitBreakerManager.get(serviceName);

  if (!breaker) {
    return res.status(404).json({
      error: {
        code: 'NOT_FOUND',
        message: `Circuit breaker for service ${serviceName} not found`,
      },
    });
  }

  breaker.open();
  logger.warn('Circuit breaker manually opened', { service: serviceName });

  res.json({
    service: serviceName,
    state: breaker.getState(),
    message: 'Circuit breaker opened',
    timestamp: new Date().toISOString(),
  });
}

/**
 * Manually close a circuit breaker
 */
export function closeCircuitBreaker(req, res) {
  const { serviceName } = req.params;
  const breaker = circuitBreakerManager.get(serviceName);

  if (!breaker) {
    return res.status(404).json({
      error: {
        code: 'NOT_FOUND',
        message: `Circuit breaker for service ${serviceName} not found`,
      },
    });
  }

  breaker.close();
  logger.info('Circuit breaker manually closed', { service: serviceName });

  res.json({
    service: serviceName,
    state: breaker.getState(),
    message: 'Circuit breaker closed',
    timestamp: new Date().toISOString(),
  });
}
