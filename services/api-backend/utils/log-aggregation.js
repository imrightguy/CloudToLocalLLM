/**
 * Log Aggregation Configuration and Utilities
 *
 * Provides support for log aggregation systems like Loki and ELK.
 * Formats logs for compatibility with various aggregation backends.
 */

/**
 * Log aggregation configuration
 */
export const logAggregationConfig = {
  // Loki configuration
  loki: {
    enabled: process.env.LOKI_ENABLED === 'true',
    url: process.env.LOKI_URL || 'http://localhost:3100',
    labels: {
      service: 'cloudtolocalllm-api',
      environment: process.env.NODE_ENV || 'development',
      version: process.env.npm_package_version || '1.0.0',
    },
    batchSize: parseInt(process.env.LOKI_BATCH_SIZE || '100', 10),
    batchTimeout: parseInt(process.env.LOKI_BATCH_TIMEOUT || '5000', 10),
  },

  // ELK (Elasticsearch) configuration
  elk: {
    enabled: process.env.ELK_ENABLED === 'true',
    hosts: (process.env.ELK_HOSTS || 'localhost:9200').split(','),
    index: process.env.ELK_INDEX || 'cloudtolocalllm-api',
    indexPattern: process.env.ELK_INDEX_PATTERN || 'cloudtolocalllm-api-%DATE%',
    batchSize: parseInt(process.env.ELK_BATCH_SIZE || '100', 10),
    batchTimeout: parseInt(process.env.ELK_BATCH_TIMEOUT || '5000', 10),
  },

  // Generic log routing configuration
  routing: {
    // Route logs to specific destinations based on level
    errorToSentry: process.env.LOG_ERRORS_TO_SENTRY !== 'false',
    errorToFile: process.env.LOG_ERRORS_TO_FILE !== 'false',
    warningToFile: process.env.LOG_WARNINGS_TO_FILE !== 'false',
    infoToConsole: process.env.LOG_INFO_TO_CONSOLE !== 'false',
  },
};

/**
 * Format log entry for Loki compatibility
 * Loki expects logs in a specific format with labels
 *
 * @param {Object} logEntry - The log entry to format
 * @returns {Object} Formatted log entry for Loki
 */
export function formatForLoki(logEntry) {
  const {
    timestamp,
    level,
    message,
    correlationId,
    userId,
    requestId,
    ...metadata
  } = logEntry;

  return {
    timestamp: new Date(timestamp).getTime() * 1000000, // Nanoseconds for Loki
    stream: {
      level,
      service: logAggregationConfig.loki.labels.service,
      environment: logAggregationConfig.loki.labels.environment,
      ...(correlationId && { correlationId }),
      ...(userId && { userId }),
      ...(requestId && { requestId }),
    },
    values: [
      [
        new Date(timestamp).getTime() * 1000000,
        JSON.stringify({
          message,
          level,
          timestamp,
          correlationId,
          userId,
          requestId,
          ...metadata,
        }),
      ],
    ],
  };
}

/**
 * Format log entry for ELK (Elasticsearch) compatibility
 * ELK expects logs in JSON format with specific fields
 *
 * @param {Object} logEntry - The log entry to format
 * @returns {Object} Formatted log entry for ELK
 */
export function formatForELK(logEntry) {
  const {
    timestamp,
    level,
    message,
    correlationId,
    userId,
    requestId,
    stack,
    ...metadata
  } = logEntry;

  return {
    '@timestamp': new Date(timestamp).toISOString(),
    level,
    message,
    service: logAggregationConfig.elk.index,
    environment: logAggregationConfig.elk.enabled
      ? logAggregationConfig.elk.indexPattern.split('-')[0]
      : 'development',
    correlationId,
    userId,
    requestId,
    stack,
    metadata,
    host: process.env.HOSTNAME || 'unknown',
    version: logAggregationConfig.loki.labels.version,
  };
}

/**
 * Batch logs for efficient transmission to aggregation systems
 */
export class LogBatcher {
  constructor(config = {}) {
    this.batchSize = config.batchSize || 100;
    this.batchTimeout = config.batchTimeout || 5000;
    this.batch = [];
    this.timer = null;
    this.onFlush = config.onFlush || (() => {});
  }

  /**
   * Add a log entry to the batch
   *
   * @param {Object} logEntry - The log entry to add
   */
  add(logEntry) {
    this.batch.push(logEntry);

    // Flush if batch is full
    if (this.batch.length >= this.batchSize) {
      this.flush();
    } else if (!this.timer) {
      // Start timer if not already running
      this.timer = setTimeout(() => this.flush(), this.batchTimeout);
    }
  }

  /**
   * Flush the current batch
   */
  flush() {
    if (this.timer) {
      clearTimeout(this.timer);
      this.timer = null;
    }

    if (this.batch.length > 0) {
      const logsToFlush = [...this.batch];
      this.batch = [];
      this.onFlush(logsToFlush);
    }
  }

  /**
   * Destroy the batcher and flush remaining logs
   */
  destroy() {
    this.flush();
  }
}

/**
 * Log routing configuration
 * Determines where logs should be sent based on level and configuration
 */
export class LogRouter {
  constructor(config = {}) {
    this.config = { ...logAggregationConfig.routing, ...config };
  }

  /**
   * Determine destinations for a log entry
   *
   * @param {string} level - Log level (error, warn, info, debug)
   * @returns {Array<string>} Array of destinations (console, file, sentry, loki, elk)
   */
  getDestinations(level) {
    const destinations = [];

    // Always log to console for info and above
    if (
      this.config.infoToConsole &&
      ['error', 'warn', 'info'].includes(level)
    ) {
      destinations.push('console');
    }

    // Route errors
    if (level === 'error') {
      if (this.config.errorToSentry) {
        destinations.push('sentry');
      }
      if (this.config.errorToFile) {
        destinations.push('file');
      }
    }

    // Route warnings
    if (level === 'warn' && this.config.warningToFile) {
      destinations.push('file');
    }

    // Always route to aggregation systems if enabled
    if (logAggregationConfig.loki.enabled) {
      destinations.push('loki');
    }
    if (logAggregationConfig.elk.enabled) {
      destinations.push('elk');
    }

    return destinations;
  }

  /**
   * Check if a destination is enabled
   *
   * @param {string} destination - The destination to check
   * @returns {boolean} True if destination is enabled
   */
  isDestinationEnabled(destination) {
    switch (destination) {
      case 'loki':
        return logAggregationConfig.loki.enabled;
      case 'elk':
        return logAggregationConfig.elk.enabled;
      case 'sentry':
        return this.config.errorToSentry;
      case 'file':
        return this.config.errorToFile || this.config.warningToFile;
      case 'console':
        return this.config.infoToConsole;
      default:
        return false;
    }
  }
}

/**
 * Create a structured log entry with all required fields
 *
 * @param {Object} options - Log entry options
 * @returns {Object} Structured log entry
 */
export function createStructuredLogEntry(options = {}) {
  const {
    level = 'info',
    message = '',
    correlationId = null,
    userId = null,
    requestId = null,
    timestamp = new Date().toISOString(),
    stack = null,
    ...metadata
  } = options;

  return {
    timestamp,
    level,
    message,
    correlationId,
    userId,
    requestId,
    stack,
    ...metadata,
  };
}

/**
 * Extract correlation ID from request
 *
 * @param {Object} req - Express request object
 * @returns {string|null} Correlation ID or null
 */
export function getCorrelationId(req) {
  if (!req || typeof req !== 'object') {
    return null;
  }

  const headers = req.headers || {};
  return (
    headers['x-correlation-id'] || headers['x-request-id'] || req.id || null
  );
}

/**
 * Extract user ID from request
 *
 * @param {Object} req - Express request object
 * @returns {string|null} User ID or null
 */
export function getUserIdFromRequest(req) {
  return req.userId || req.user?.id || null;
}

export default {
  logAggregationConfig,
  formatForLoki,
  formatForELK,
  LogBatcher,
  LogRouter,
  createStructuredLogEntry,
  getCorrelationId,
  getUserIdFromRequest,
};
