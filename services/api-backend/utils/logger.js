/**
 * @fileoverview Enhanced logging utility with structured JSON logging and correlation IDs
 * Provides consistent logging across the simplified tunnel system
 */

import winston from 'winston';
import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';

/**
 * Log levels for different types of events
 */
export const LOG_LEVELS = {
  ERROR: 'error',
  WARN: 'warn',
  INFO: 'info',
  DEBUG: 'debug',
};

/**
 * Error codes for different types of tunnel errors
 */
export const ERROR_CODES = {
  // Authentication errors (401)
  AUTH_TOKEN_MISSING: 'AUTH_TOKEN_MISSING',
  AUTH_TOKEN_INVALID: 'AUTH_TOKEN_INVALID',
  AUTH_TOKEN_EXPIRED: 'AUTH_TOKEN_EXPIRED',

  // Connection errors (503)
  DESKTOP_CLIENT_DISCONNECTED: 'DESKTOP_CLIENT_DISCONNECTED',
  WEBSOCKET_CONNECTION_FAILED: 'WEBSOCKET_CONNECTION_FAILED',
  CONNECTION_LOST: 'CONNECTION_LOST',

  // Request errors (400)
  INVALID_REQUEST_FORMAT: 'INVALID_REQUEST_FORMAT',
  INVALID_MESSAGE_FORMAT: 'INVALID_MESSAGE_FORMAT',
  MISSING_REQUIRED_FIELD: 'MISSING_REQUIRED_FIELD',

  // Timeout errors (504)
  REQUEST_TIMEOUT: 'REQUEST_TIMEOUT',
  PING_TIMEOUT: 'PING_TIMEOUT',

  // Server errors (500)
  MESSAGE_SERIALIZATION_FAILED: 'MESSAGE_SERIALIZATION_FAILED',
  INTERNAL_SERVER_ERROR: 'INTERNAL_SERVER_ERROR',
  WEBSOCKET_SEND_FAILED: 'WEBSOCKET_SEND_FAILED',
};

/**
 * HTTP status codes for different error types
 */
export const HTTP_STATUS_CODES = {
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
  NOT_FOUND: 404,
  INTERNAL_SERVER_ERROR: 500,
  SERVICE_UNAVAILABLE: 503,
  GATEWAY_TIMEOUT: 504,
};

/**
 * Enhanced logger class with correlation ID support and structured logging
 */
export class TunnelLogger {
  constructor(service = 'tunnel-system') {
    this.service = service;
    this.logger = winston.createLogger({
      level: process.env.LOG_LEVEL || 'info',
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.errors({ stack: true }),
        winston.format.json(),
        winston.format.printf(
          ({
            timestamp,
            level,
            message,
            service,
            correlationId,
            userId,
            ...meta
          }) => {
            const logEntry = {
              timestamp,
              level,
              service,
              message,
              ...(correlationId && { correlationId }),
              ...(userId && { userId: this.hashUserId(userId) }),
              ...meta,
            };
            return JSON.stringify(logEntry);
          }
        )
      ),
      defaultMeta: { service: this.service },
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
            winston.format.colorize(),
            winston.format.printf(
              ({ timestamp, level, message, correlationId, userId }) => {
                const correlationStr = correlationId
                  ? ` [${correlationId}]`
                  : '';
                const userStr = userId
                  ? ` [user:${userId.substring(0, 8)}...]`
                  : '';
                return `${timestamp} ${level}:${correlationStr}${userStr} ${message}`;
              }
            )
          ),
        }),
      ],
    });
  }

  /**
   * Hash user ID for logging (privacy protection)
   * @param {string} userId - User ID to hash
   * @returns {string} Hashed user ID
   */
  hashUserId(userId) {
    if (!userId) {
      return null;
    }
    // Simple hash for logging - first 8 chars + hash of full ID
    const hash = crypto.createHash('sha256').update(userId).digest('hex');
    return `${userId.substring(0, 8)}...${hash.substring(0, 8)}`;
  }

  /**
   * Generate a new correlation ID
   * @returns {string} Correlation ID
   */
  generateCorrelationId() {
    return uuidv4();
  }

  /**
   * Log an info message
   * @param {string} message - Log message
   * @param {Object} meta - Additional metadata
   */
  info(message, meta = {}) {
    this.logger.info(message, meta);
  }

  /**
   * Log a debug message
   * @param {string} message - Log message
   * @param {Object} meta - Additional metadata
   */
  debug(message, meta = {}) {
    this.logger.debug(message, meta);
  }

  /**
   * Log a warning message
   * @param {string} message - Log message
   * @param {Object} meta - Additional metadata
   */
  warn(message, meta = {}) {
    this.logger.warn(message, meta);
  }

  /**
   * Log an error message
   * @param {string} message - Log message
   * @param {Error|Object} error - Error object or metadata
   * @param {Object} meta - Additional metadata
   */
  error(message, error = {}, meta = {}) {
    const errorMeta = {
      ...meta,
      ...(error instanceof Error && {
        error: {
          name: error.name,
          message: error.message,
          stack: error.stack,
          code: error.code,
        },
      }),
      ...(!(error instanceof Error) && { error }),
    };

    this.logger.error(message, errorMeta);
  }

  /**
   * Log a connection event
   * @param {string} event - Event type (connected, disconnected, error)
   * @param {string} connectionId - Connection ID
   * @param {string} userId - User ID
   * @param {Object} meta - Additional metadata
   */
  logConnection(event, connectionId, userId, meta = {}) {
    this.info(`Connection ${event}`, {
      event: 'connection',
      connectionEvent: event,
      connectionId,
      userId,
      ...meta,
    });
  }

  /**
   * Log a request event
   * @param {string} event - Event type (started, completed, failed, timeout)
   * @param {string} requestId - Request correlation ID
   * @param {string} userId - User ID
   * @param {Object} meta - Additional metadata
   */
  logRequest(event, requestId, userId, meta = {}) {
    const level = event === 'failed' || event === 'timeout' ? 'warn' : 'info';
    this.logger[level](`Request ${event}`, {
      event: 'request',
      requestEvent: event,
      correlationId: requestId,
      userId,
      ...meta,
    });
  }

  /**
   * Log a tunnel error with structured information
   * @param {string} errorCode - Error code from ERROR_CODES
   * @param {string} message - Error message
   * @param {Object} context - Error context
   */
  logTunnelError(errorCode, message, context = {}) {
    this.error(`Tunnel error: ${message}`, {
      event: 'tunnel_error',
      errorCode,
      ...context,
    });
  }

  /**
   * Log performance metrics
   * @param {string} operation - Operation name
   * @param {number} duration - Duration in milliseconds
   * @param {Object} meta - Additional metadata
   */
  logPerformance(operation, duration, meta = {}) {
    this.info(`Performance: ${operation}`, {
      event: 'performance',
      operation,
      duration,
      ...meta,
    });
  }

  /**
   * Log security events
   * @param {string} event - Security event type
   * @param {string} userId - User ID (will be hashed)
   * @param {Object} meta - Additional metadata
   */
  logSecurity(event, userId, meta = {}) {
    this.warn(`Security event: ${event}`, {
      event: 'security',
      securityEvent: event,
      userId,
      ...meta,
    });
  }

  /**
   * Create a child logger with additional context
   * @param {Object} context - Additional context to include in all logs
   * @returns {TunnelLogger} Child logger
   */
  child(context = {}) {
    const childLogger = new TunnelLogger(this.service);
    childLogger.logger = this.logger.child(context);
    return childLogger;
  }
}

/**
 * Create standardized error responses for HTTP endpoints
 */
export class ErrorResponseBuilder {
  /**
   * Create a standardized error response
   * @param {string} errorCode - Error code from ERROR_CODES
   * @param {string} message - User-friendly error message
   * @param {number} statusCode - HTTP status code
   * @param {Object} details - Additional error details
   * @returns {Object} Error response object
   */
  static createErrorResponse(errorCode, message, statusCode, details = {}) {
    return {
      error: {
        code: errorCode,
        message,
        timestamp: new Date().toISOString(),
        ...details,
      },
    };
  }

  /**
   * Create authentication error response (401)
   * @param {string} message - Error message
   * @param {string} errorCode - Specific error code
   * @returns {Object} Error response
   */
  static authenticationError(
    message = 'Authentication required',
    errorCode = ERROR_CODES.AUTH_TOKEN_MISSING
  ) {
    return this.createErrorResponse(
      errorCode,
      message,
      HTTP_STATUS_CODES.UNAUTHORIZED
    );
  }

  /**
   * Create service unavailable error response (503)
   * @param {string} message - Error message
   * @param {string} errorCode - Specific error code
   * @returns {Object} Error response
   */
  static serviceUnavailableError(
    message = 'Service temporarily unavailable',
    errorCode = ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED
  ) {
    return this.createErrorResponse(
      errorCode,
      message,
      HTTP_STATUS_CODES.SERVICE_UNAVAILABLE
    );
  }

  /**
   * Create gateway timeout error response (504)
   * @param {string} message - Error message
   * @param {string} errorCode - Specific error code
   * @returns {Object} Error response
   */
  static gatewayTimeoutError(
    message = 'Request timed out',
    errorCode = ERROR_CODES.REQUEST_TIMEOUT
  ) {
    return this.createErrorResponse(
      errorCode,
      message,
      HTTP_STATUS_CODES.GATEWAY_TIMEOUT
    );
  }

  /**
   * Create bad request error response (400)
   * @param {string} message - Error message
   * @param {string} errorCode - Specific error code
   * @returns {Object} Error response
   */
  static badRequestError(
    message = 'Invalid request format',
    errorCode = ERROR_CODES.INVALID_REQUEST_FORMAT
  ) {
    return this.createErrorResponse(
      errorCode,
      message,
      HTTP_STATUS_CODES.BAD_REQUEST
    );
  }

  /**
   * Create internal server error response (500)
   * @param {string} message - Error message
   * @param {string} errorCode - Specific error code
   * @returns {Object} Error response
   */
  static internalServerError(
    message = 'Internal server error',
    errorCode = ERROR_CODES.INTERNAL_SERVER_ERROR
  ) {
    return this.createErrorResponse(
      errorCode,
      message,
      HTTP_STATUS_CODES.INTERNAL_SERVER_ERROR
    );
  }
}

// Export default logger instance
export const logger = new TunnelLogger('tunnel-system');
