/**
 * Log Routing Middleware
 *
 * Middleware for routing logs to appropriate destinations based on
 * log level and configuration. Integrates with Loki, ELK, and other
 * log aggregation systems.
 */

import logger from '../logger.js';
import {
  LogRouter,
  LogBatcher,
  formatForLoki,
  formatForELK,
  createStructuredLogEntry,
  getCorrelationId,
  getUserIdFromRequest,
  logAggregationConfig,
} from '../utils/log-aggregation.js';

// Initialize log router
export const logRouter = new LogRouter();

// Initialize batchers for aggregation systems
let lokiBatcher = null;
let elkBatcher = null;

if (logAggregationConfig.loki.enabled) {
  lokiBatcher = new LogBatcher({
    batchSize: logAggregationConfig.loki.batchSize,
    batchTimeout: logAggregationConfig.loki.batchTimeout,
    onFlush: (logs) => {
      sendToLoki(logs).catch((err) => {
        logger.error('Failed to send logs to Loki', { error: err.message });
      });
    },
  });
}

if (logAggregationConfig.elk.enabled) {
  elkBatcher = new LogBatcher({
    batchSize: logAggregationConfig.elk.batchSize,
    batchTimeout: logAggregationConfig.elk.batchTimeout,
    onFlush: (logs) => {
      sendToELK(logs).catch((err) => {
        logger.error('Failed to send logs to ELK', { error: err.message });
      });
    },
  });
}

/**
 * Send logs to Loki
 *
 * @param {Array} logs - Array of log entries
 */
async function sendToLoki(logs) {
  if (!logAggregationConfig.loki.enabled || !logs.length) {
    return;
  }

  try {
    const streams = {};

    // Group logs by stream labels
    logs.forEach((log) => {
      const formatted = formatForLoki(log);
      const streamKey = JSON.stringify(formatted.stream);

      if (!streams[streamKey]) {
        streams[streamKey] = {
          stream: formatted.stream,
          values: [],
        };
      }

      streams[streamKey].values.push(...formatted.values);
    });

    const payload = {
      streams: Object.values(streams),
    };

    const response = await fetch(
      `${logAggregationConfig.loki.url}/loki/api/v1/push`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      },
    );

    if (!response.ok) {
      throw new Error(
        `Loki returned ${response.status}: ${response.statusText}`,
      );
    }
  } catch (error) {
    logger.error('Error sending logs to Loki', {
      error: error.message,
      logsCount: logs.length,
    });
  }
}

/**
 * Send logs to ELK (Elasticsearch)
 *
 * @param {Array} logs - Array of log entries
 */
async function sendToELK(logs) {
  if (!logAggregationConfig.elk.enabled || !logs.length) {
    return;
  }

  try {
    const bulkPayload = logs
      .map((log) => {
        const formatted = formatForELK(log);
        const indexName = `${logAggregationConfig.elk.index}-${new Date().toISOString().split('T')[0]}`;

        return (
          JSON.stringify({
            index: {
              _index: indexName,
              _type: '_doc',
            },
          }) +
          '\n' +
          JSON.stringify(formatted) +
          '\n'
        );
      })
      .join('');

    const response = await fetch(
      `http://${logAggregationConfig.elk.hosts[0]}/_bulk`,
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-ndjson',
        },
        body: bulkPayload,
      },
    );

    if (!response.ok) {
      throw new Error(
        `ELK returned ${response.status}: ${response.statusText}`,
      );
    }

    const result = await response.json();
    if (result.errors) {
      logger.warn('Some logs failed to index in ELK', {
        errors: result.items.filter((item) => item.index?.error),
      });
    }
  } catch (error) {
    logger.error('Error sending logs to ELK', {
      error: error.message,
      logsCount: logs.length,
    });
  }
}

/**
 * Route a log entry to appropriate destinations
 *
 * @param {Object} logEntry - The log entry to route
 * @param {Object} req - Express request object (optional)
 */
export function routeLog(logEntry, req = null) {
  const destinations = logRouter.getDestinations(logEntry.level);

  // Enrich log entry with request context
  if (req && typeof req === 'object') {
    logEntry.correlationId = logEntry.correlationId || getCorrelationId(req);
    logEntry.userId = logEntry.userId || getUserIdFromRequest(req);
    logEntry.requestId = logEntry.requestId || req.id;
  }

  // Send to each destination
  destinations.forEach((destination) => {
    switch (destination) {
      case 'loki':
        if (lokiBatcher) {
          lokiBatcher.add(logEntry);
        }
        break;
      case 'elk':
        if (elkBatcher) {
          elkBatcher.add(logEntry);
        }
        break;
      case 'console':
        // Already handled by Winston
        break;
      case 'file':
        // Already handled by Winston
        break;
      case 'sentry':
        // Handled by Sentry middleware
        break;
      default:
        break;
    }
  });
}

/**
 * Middleware to capture and route logs
 * Wraps the logger to intercept log calls
 */
export function createLogRoutingMiddleware() {
  return (req, res, next) => {
    // Store original logger methods
    const originalLog = logger.log.bind(logger);
    const originalInfo = logger.info.bind(logger);
    const originalWarn = logger.warn.bind(logger);
    const originalError = logger.error.bind(logger);
    const originalDebug = logger.debug.bind(logger);

    // Override logger methods to route logs
    logger.log = function (level, message, meta = {}) {
      const logEntry = createStructuredLogEntry({
        level,
        message,
        ...meta,
      });
      routeLog(logEntry, req);
      return originalLog(level, message, meta);
    };

    logger.info = function (message, meta = {}) {
      const logEntry = createStructuredLogEntry({
        level: 'info',
        message,
        ...meta,
      });
      routeLog(logEntry, req);
      return originalInfo(message, meta);
    };

    logger.warn = function (message, meta = {}) {
      const logEntry = createStructuredLogEntry({
        level: 'warn',
        message,
        ...meta,
      });
      routeLog(logEntry, req);
      return originalWarn(message, meta);
    };

    logger.error = function (message, meta = {}) {
      const logEntry = createStructuredLogEntry({
        level: 'error',
        message,
        ...meta,
      });
      routeLog(logEntry, req);
      return originalError(message, meta);
    };

    logger.debug = function (message, meta = {}) {
      const logEntry = createStructuredLogEntry({
        level: 'debug',
        message,
        ...meta,
      });
      routeLog(logEntry, req);
      return originalDebug(message, meta);
    };

    // Restore original methods on response finish
    res.on('finish', () => {
      logger.log = originalLog;
      logger.info = originalInfo;
      logger.warn = originalWarn;
      logger.error = originalError;
      logger.debug = originalDebug;
    });

    next();
  };
}

/**
 * Flush all pending logs
 * Should be called during graceful shutdown
 */
export async function flushLogs() {
  const flushPromises = [];

  if (lokiBatcher) {
    lokiBatcher.flush();
    flushPromises.push(new Promise((resolve) => setTimeout(resolve, 100)));
  }

  if (elkBatcher) {
    elkBatcher.flush();
    flushPromises.push(new Promise((resolve) => setTimeout(resolve, 100)));
  }

  await Promise.all(flushPromises);
}

/**
 * Destroy log routing resources
 * Should be called during application shutdown
 */
export function destroyLogRouting() {
  if (lokiBatcher) {
    lokiBatcher.destroy();
  }

  if (elkBatcher) {
    elkBatcher.destroy();
  }
}

export default {
  createLogRoutingMiddleware,
  routeLog,
  flushLogs,
  destroyLogRouting,
  logRouter,
};
