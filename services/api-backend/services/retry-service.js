/**
 * Retry Service with Exponential Backoff
 *
 * Implements retry logic with exponential backoff for transient failures.
 * Supports per-service configuration and metrics collection.
 *
 * Features:
 * - Exponential backoff with jitter
 * - Per-service retry configuration
 * - Retry metrics collection
 * - Configurable retry conditions
 * - Max retry attempts and timeout
 */

export class RetryService {
  constructor(options = {}) {
    this.name = options.name || 'RetryService';
    this.maxRetries = options.maxRetries || 3;
    this.initialDelayMs = options.initialDelayMs || 100;
    this.maxDelayMs = options.maxDelayMs || 10000;
    this.backoffMultiplier = options.backoffMultiplier || 2;
    this.jitterFactor = options.jitterFactor || 0.1; // 10% jitter
    this.shouldRetry = options.shouldRetry || this.defaultShouldRetry;

    // Metrics
    this.metrics = {
      totalAttempts: 0,
      successfulAttempts: 0,
      failedAttempts: 0,
      retriedAttempts: 0,
      totalRetries: 0,
      averageRetries: 0,
    };
  }

  /**
   * Default retry condition - retry on network errors and 5xx status codes
   * @param {Error} error - The error that occurred
   * @returns {boolean} - Whether to retry
   */
  defaultShouldRetry(error) {
    // Don't retry on client errors (4xx)
    if (error.statusCode && error.statusCode >= 400 && error.statusCode < 500) {
      return false;
    }

    // Retry on network errors
    if (
      error.code === 'ECONNREFUSED' ||
      error.code === 'ECONNRESET' ||
      error.code === 'ETIMEDOUT' ||
      error.code === 'EHOSTUNREACH' ||
      error.code === 'ENETUNREACH'
    ) {
      return true;
    }

    // Retry on 5xx errors
    if (error.statusCode && error.statusCode >= 500) {
      return true;
    }

    // Retry on timeout errors
    if (error.message && error.message.includes('timeout')) {
      return true;
    }

    return false;
  }

  /**
   * Calculate delay with exponential backoff and jitter
   * @param {number} attemptNumber - The current attempt number (0-indexed)
   * @returns {number} - Delay in milliseconds
   */
  calculateDelay(attemptNumber) {
    // Exponential backoff: initialDelay * (multiplier ^ attemptNumber)
    const exponentialDelay =
      this.initialDelayMs * Math.pow(this.backoffMultiplier, attemptNumber);

    // Cap at max delay
    const cappedDelay = Math.min(exponentialDelay, this.maxDelayMs);

    // Add jitter: random value between -jitterFactor and +jitterFactor of the delay
    const jitter = cappedDelay * this.jitterFactor * (Math.random() * 2 - 1);

    return Math.max(0, Math.round(cappedDelay + jitter));
  }

  /**
   * Sleep for a specified duration
   * @param {number} ms - Milliseconds to sleep
   * @returns {Promise} - Resolves after the delay
   */
  sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  /**
   * Execute a function with retry logic
   * @param {Function} fn - The function to execute
   * @param {Object} context - The context to bind to the function
   * @param {Array} args - Arguments to pass to the function
   * @returns {Promise} - The result of the function
   */
  async execute(fn, context = null, args = []) {
    this.metrics.totalAttempts++;
    let lastError;

    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      try {
        const result = await fn.apply(context, args);
        this.metrics.successfulAttempts++;

        // Record retry count if this wasn't the first attempt
        if (attempt > 0) {
          this.metrics.retriedAttempts++;
          this.metrics.totalRetries += attempt;
          this.metrics.averageRetries =
            this.metrics.totalRetries / this.metrics.retriedAttempts;
        }

        return result;
      } catch (error) {
        lastError = error;

        // Check if we should retry
        if (attempt < this.maxRetries && this.shouldRetry(error)) {
          const delay = this.calculateDelay(attempt);
          await this.sleep(delay);
          continue;
        }

        // No more retries or shouldn't retry
        this.metrics.failedAttempts++;
        throw error;
      }
    }

    // Should not reach here, but just in case
    this.metrics.failedAttempts++;
    throw lastError;
  }

  /**
   * Get current metrics
   */
  getMetrics() {
    return {
      ...this.metrics,
      name: this.name,
      config: {
        maxRetries: this.maxRetries,
        initialDelayMs: this.initialDelayMs,
        maxDelayMs: this.maxDelayMs,
        backoffMultiplier: this.backoffMultiplier,
        jitterFactor: this.jitterFactor,
      },
    };
  }

  /**
   * Reset metrics
   */
  resetMetrics() {
    this.metrics = {
      totalAttempts: 0,
      successfulAttempts: 0,
      failedAttempts: 0,
      retriedAttempts: 0,
      totalRetries: 0,
      averageRetries: 0,
    };
  }
}

/**
 * Retry Manager for managing multiple retry services per service
 */
export class RetryManager {
  constructor() {
    this.retryServices = new Map();
  }

  /**
   * Create or get a retry service for a specific service
   * @param {string} serviceName - The name of the service
   * @param {Object} options - Configuration options
   * @returns {RetryService} - The retry service instance
   */
  getOrCreate(serviceName, options = {}) {
    if (!this.retryServices.has(serviceName)) {
      this.retryServices.set(
        serviceName,
        new RetryService({ name: serviceName, ...options }),
      );
    }
    return this.retryServices.get(serviceName);
  }

  /**
   * Get a retry service by name
   * @param {string} serviceName - The name of the service
   * @returns {RetryService} - The retry service instance
   */
  get(serviceName) {
    return this.retryServices.get(serviceName);
  }

  /**
   * Get all retry services
   * @returns {Array} - Array of all retry services
   */
  getAll() {
    return Array.from(this.retryServices.values());
  }

  /**
   * Get metrics for all retry services
   * @returns {Object} - Metrics for all services
   */
  getAllMetrics() {
    const metrics = {};
    for (const [name, service] of this.retryServices) {
      metrics[name] = service.getMetrics();
    }
    return metrics;
  }

  /**
   * Reset metrics for all retry services
   */
  resetAllMetrics() {
    for (const service of this.retryServices.values()) {
      service.resetMetrics();
    }
  }

  /**
   * Remove a retry service
   * @param {string} serviceName - The name of the service
   */
  remove(serviceName) {
    this.retryServices.delete(serviceName);
  }

  /**
   * Remove all retry services
   */
  removeAll() {
    this.retryServices.clear();
  }
}

// Export singleton instance
export const retryManager = new RetryManager();
