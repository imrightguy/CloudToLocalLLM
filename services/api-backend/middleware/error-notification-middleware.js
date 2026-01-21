/**
 * Error Notification Middleware
 *
 * Integrates error notification service into the request pipeline.
 * Detects critical errors and triggers notifications.
 *
 * Requirement 7.9: THE API SHALL support error notifications for critical issues
 */

import { errorNotificationService } from '../services/error-notification-service.js';
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'error-notification-middleware' },
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
 * Error notification middleware
 * Wraps error handling to detect and notify critical errors
 *
 * @param {Object} options - Middleware options
 * @returns {Function} - Express middleware
 */
export function createErrorNotificationMiddleware(_options = {}) {
  return (error, req, res, next) => {
    // Extract context from request
    const context = {
      method: req.method,
      path: req.path,
      statusCode: error.statusCode || 500,
      userId: req.user?.sub || 'anonymous',
      correlationId: req.correlationId || 'unknown',
      userAgent: req.get('user-agent'),
      ip: req.ip,
      timestamp: new Date().toISOString(),
    };

    // Detect and notify about critical error
    errorNotificationService
      .detectAndNotify(error, context)
      .catch((notificationError) => {
        logger.error('Failed to process error notification', {
          error: notificationError.message,
          originalError: error.message,
        });
      });

    // Continue with normal error handling
    next(error);
  };
}

/**
 * Wrap route handler to catch and notify errors
 *
 * @param {Function} handler - Route handler
 * @returns {Function} - Wrapped handler
 */
export function withErrorNotification(handler) {
  return async (req, res, next) => {
    try {
      await handler(req, res, next);
    } catch (error) {
      // Extract context
      const context = {
        method: req.method,
        path: req.path,
        userId: req.user?.sub || 'anonymous',
        correlationId: req.correlationId || 'unknown',
        userAgent: req.get('user-agent'),
        ip: req.ip,
        timestamp: new Date().toISOString(),
      };

      // Detect and notify
      try {
        await errorNotificationService.detectAndNotify(error, context);
      } catch (notificationError) {
        logger.error('Failed to send error notification', {
          error: notificationError.message,
        });
      }

      // Pass to next error handler
      next(error);
    }
  };
}

/**
 * Create error notification status endpoint
 *
 * @returns {Function} - Express route handler
 */
export function createErrorNotificationStatusHandler() {
  return (req, res) => {
    try {
      const status = errorNotificationService.getStatus();
      res.json(status);
    } catch (error) {
      logger.error('Error getting notification status', {
        error: error.message,
      });
      res.status(500).json({
        error: 'Failed to get notification status',
        message: error.message,
      });
    }
  };
}

/**
 * Create error history endpoint
 *
 * @returns {Function} - Express route handler
 */
export function createErrorHistoryHandler() {
  return (req, res) => {
    try {
      const { category, severity, limit } = req.query;
      const history = errorNotificationService.getErrorHistory({
        category,
        severity,
        limit: limit ? parseInt(limit) : 100,
      });

      res.json({
        count: history.length,
        errors: history,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error getting error history', { error: error.message });
      res.status(500).json({
        error: 'Failed to get error history',
        message: error.message,
      });
    }
  };
}

/**
 * Create error statistics endpoint
 *
 * @returns {Function} - Express route handler
 */
export function createErrorStatisticsHandler() {
  return (req, res) => {
    try {
      const stats = errorNotificationService.getErrorStatistics();
      res.json(stats);
    } catch (error) {
      logger.error('Error getting error statistics', { error: error.message });
      res.status(500).json({
        error: 'Failed to get error statistics',
        message: error.message,
      });
    }
  };
}

/**
 * Create error metrics endpoint
 *
 * @returns {Function} - Express route handler
 */
export function createErrorMetricsHandler() {
  return (req, res) => {
    try {
      const metrics = errorNotificationService.getMetrics();
      res.json(metrics);
    } catch (error) {
      logger.error('Error getting error metrics', { error: error.message });
      res.status(500).json({
        error: 'Failed to get error metrics',
        message: error.message,
      });
    }
  };
}

/**
 * Create error reset endpoint (admin only)
 *
 * @returns {Function} - Express route handler
 */
export function createErrorResetHandler() {
  return (req, res) => {
    try {
      const { type } = req.body;

      if (type === 'counts') {
        errorNotificationService.resetErrorCounts();
      } else if (type === 'history') {
        errorNotificationService.clearHistory();
      } else if (type === 'metrics') {
        errorNotificationService.resetMetrics();
      } else if (type === 'all') {
        errorNotificationService.resetErrorCounts();
        errorNotificationService.clearHistory();
        errorNotificationService.resetMetrics();
      } else {
        return res.status(400).json({
          error: 'Invalid reset type',
          validTypes: ['counts', 'history', 'metrics', 'all'],
        });
      }

      res.json({
        success: true,
        message: `Error ${type} reset successfully`,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error resetting error data', { error: error.message });
      res.status(500).json({
        error: 'Failed to reset error data',
        message: error.message,
      });
    }
  };
}

/**
 * Create manual error notification endpoint (for testing)
 *
 * @returns {Function} - Express route handler
 */
export function createManualErrorNotificationHandler() {
  return async (req, res) => {
    try {
      const { message, category, severity } = req.body;

      if (!message) {
        return res.status(400).json({
          error: 'Message is required',
        });
      }

      const error = new Error(message);
      // Attach category and severity if provided, for testing purposes
      if (category) {
        error.category = category;
      }
      if (severity) {
        error.severity = severity;
      }

      const context = {
        method: req.method,
        path: req.path,
        userId: req.user?.sub || 'admin',
        correlationId: req.correlationId || 'manual-test',
        manual: true,
        timestamp: new Date().toISOString(),
      };

      const result = await errorNotificationService.detectAndNotify(
        error,
        context,
      );

      res.json({
        success: true,
        message: 'Manual error notification sent',
        result,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error sending manual notification', {
        error: error.message,
      });
      res.status(500).json({
        error: 'Failed to send manual notification',
        message: error.message,
      });
    }
  };
}
