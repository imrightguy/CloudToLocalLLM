/**
 * Retry Middleware
 *
 * Integrates retry logic with circuit breaker for resilient service calls.
 * Provides a unified interface for executing operations with both retry and circuit breaker protection.
 */

import { retryManager } from '../services/retry-service.js';
import { circuitBreakerManager } from '../services/circuit-breaker.js';
import { logger } from '../utils/logger.js';

/**
 * Execute a function with retry and circuit breaker protection
 * @param {string} serviceName - The name of the service
 * @param {Function} fn - The function to execute
 * @param {Object} options - Configuration options
 * @returns {Promise} - The result of the function
 */
export async function executeWithRetryAndCircuitBreaker(
  serviceName,
  fn,
  options = {},
) {
  const {
    retryConfig = {},
    circuitBreakerConfig = {},
    context = null,
    args = [],
    correlationId = null,
  } = options;

  // Get or create retry service
  const retryService = retryManager.getOrCreate(serviceName, {
    maxRetries: retryConfig.maxRetries || 3,
    initialDelayMs: retryConfig.initialDelayMs || 100,
    maxDelayMs: retryConfig.maxDelayMs || 10000,
    backoffMultiplier: retryConfig.backoffMultiplier || 2,
    jitterFactor: retryConfig.jitterFactor || 0.1,
    shouldRetry: retryConfig.shouldRetry,
  });

  // Get or create circuit breaker
  const circuitBreaker = circuitBreakerManager.getOrCreate(serviceName, {
    failureThreshold: circuitBreakerConfig.failureThreshold || 5,
    successThreshold: circuitBreakerConfig.successThreshold || 2,
    timeout: circuitBreakerConfig.timeout || 60000,
  });

  try {
    // Execute through circuit breaker, which will execute through retry
    return await circuitBreaker.execute(async () => {
      return await retryService.execute(fn, context, args);
    });
  } catch (error) {
    // Log the error with correlation ID if available
    if (correlationId) {
      logger.error(`Service call failed for ${serviceName}`, {
        correlationId,
        serviceName,
        error: error.message,
        code: error.code,
        statusCode: error.statusCode,
      });
    }
    throw error;
  }
}

/**
 * Create a retry-enabled service client
 * @param {string} serviceName - The name of the service
 * @param {Object} client - The service client
 * @param {Object} options - Configuration options
 * @returns {Object} - Wrapped client with retry logic
 */
export function createRetryableClient(serviceName, client, options = {}) {
  const {
    retryConfig = {},
    circuitBreakerConfig = {},
    methodsToWrap = [],
  } = options;

  const wrappedClient = { ...client };

  // Wrap specified methods
  for (const methodName of methodsToWrap) {
    if (typeof client[methodName] === 'function') {
      const originalMethod = client[methodName];

      wrappedClient[methodName] = async function (...args) {
        return executeWithRetryAndCircuitBreaker(
          `${serviceName}.${methodName}`,
          originalMethod,
          {
            retryConfig,
            circuitBreakerConfig,
            context: client,
            args,
          },
        );
      };
    }
  }

  return wrappedClient;
}

/**
 * Middleware for Express to add retry context to requests
 */
export function retryContextMiddleware(req, res, next) {
  // Add retry execution helper to request
  req.executeWithRetry = async (serviceName, fn, options = {}) => {
    return executeWithRetryAndCircuitBreaker(serviceName, fn, {
      ...options,
      correlationId: req.correlationId,
    });
  };

  // Add retry manager access
  req.retryManager = retryManager;

  next();
}

/**
 * Get retry and circuit breaker metrics for a service
 * @param {string} serviceName - The name of the service
 * @returns {Object} - Combined metrics
 */
export function getServiceMetrics(serviceName) {
  const retryService = retryManager.get(serviceName);
  const circuitBreaker = circuitBreakerManager.get(serviceName);

  return {
    retry: retryService ? retryService.getMetrics() : null,
    circuitBreaker: circuitBreaker ? circuitBreaker.getMetrics() : null,
  };
}

/**
 * Get all service metrics
 * @returns {Object} - All service metrics
 */
export function getAllServiceMetrics() {
  return {
    retry: retryManager.getAllMetrics(),
    circuitBreaker: circuitBreakerManager.getAllMetrics(),
  };
}
