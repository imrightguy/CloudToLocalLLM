/**
 * Graceful Degradation Middleware
 *
 * Implements graceful degradation for API endpoints when services are unavailable.
 * Provides fallback responses and reduced functionality modes.
 *
 * Requirement 7.6: THE API SHALL implement graceful degradation when services are unavailable
 */

import { gracefulDegradationService } from '../services/graceful-degradation.js';
import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'graceful-degradation-middleware' },
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
 * Create graceful degradation middleware for a service
 * @param {string} serviceName - Name of the service
 * @param {Object} options - Configuration options
 * @returns {Function} - Express middleware
 */
export function createGracefulDegradationMiddleware(
  serviceName,
  _options = {},
) {
  return (req, res, next) => {
    const status = gracefulDegradationService.getStatus(serviceName);

    // Add degradation status to request
    req.degradationStatus = status;

    // If service is degraded and endpoint is critical, return error
    if (
      status.isDegraded &&
      gracefulDegradationService.isCriticalEndpoint(serviceName, req.path)
    ) {
      logger.warn(
        `Critical endpoint accessed during degradation: ${req.path}`,
        {
          service: serviceName,
          degradationReason: status.reason,
        },
      );

      return res.status(503).json({
        error: {
          code: 'SERVICE_DEGRADED',
          message: `Service is temporarily unavailable: ${status.reason}`,
          category: 'service_unavailable',
          statusCode: 503,
          correlationId: req.correlationId,
          suggestion: 'Please try again in a few moments',
          degradationInfo: {
            service: serviceName,
            severity: status.severity,
            degradationStartTime: status.degradationStartTime,
          },
        },
      });
    }

    next();
  };
}

/**
 * Middleware to handle degradation status reporting
 * @returns {Function} - Express middleware
 */
export function degradationStatusMiddleware(req, res, next) {
  // Add degradation status to response headers
  const report = gracefulDegradationService.getReport();

  if (report.summary.overallStatus === 'degraded') {
    res.set('X-Service-Status', 'degraded');
    res.set('X-Degraded-Services', report.degradedServices.toString());
  }

  next();
}

/**
 * Endpoint to get degradation status
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
export function getDegradationStatus(req, res) {
  const serviceName = req.params.serviceName;

  if (serviceName) {
    const status = gracefulDegradationService.getStatus(serviceName);
    return res.json({
      status,
      timestamp: new Date().toISOString(),
    });
  }

  const report = gracefulDegradationService.getReport();
  res.json(report);
}

/**
 * Endpoint to get all degradation statuses
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
export function getAllDegradationStatuses(req, res) {
  const statuses = gracefulDegradationService.getAllStatuses();
  res.json({
    services: statuses,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Endpoint to manually mark a service as degraded
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
export function markServiceDegraded(req, res) {
  const { serviceName, reason, severity } = req.body;

  if (!serviceName) {
    return res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: 'serviceName is required',
      },
    });
  }

  gracefulDegradationService.markDegraded(
    serviceName,
    reason || 'Manual degradation',
    severity || 'warning',
  );

  const status = gracefulDegradationService.getStatus(serviceName);
  res.json({
    message: `Service marked as degraded: ${serviceName}`,
    status,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Endpoint to manually mark a service as recovered
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
export function markServiceRecovered(req, res) {
  const { serviceName } = req.body;

  if (!serviceName) {
    return res.status(400).json({
      error: {
        code: 'INVALID_REQUEST',
        message: 'serviceName is required',
      },
    });
  }

  gracefulDegradationService.markRecovered(serviceName);

  const status = gracefulDegradationService.getStatus(serviceName);
  res.json({
    message: `Service marked as recovered: ${serviceName}`,
    status,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Endpoint to get degradation metrics
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
export function getDegradationMetrics(req, res) {
  const metrics = gracefulDegradationService.getMetrics();
  res.json({
    metrics,
    timestamp: new Date().toISOString(),
  });
}

/**
 * Endpoint to reset all degradation states
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 */
export function resetAllDegradation(req, res) {
  gracefulDegradationService.resetAll();

  res.json({
    message: 'All degradation states reset',
    timestamp: new Date().toISOString(),
  });
}

/**
 * Utility function to execute with graceful degradation
 * @param {string} serviceName - Name of the service
 * @param {Function} primaryFn - Primary function to execute
 * @param {*} context - Context to bind to the function
 * @param {Array} args - Arguments to pass to the function
 * @returns {Promise} - Result of primary or fallback function
 */
export async function executeWithGracefulDegradation(
  serviceName,
  primaryFn,
  context = null,
  args = [],
) {
  return gracefulDegradationService.executeWithFallback(
    serviceName,
    primaryFn,
    context,
    args,
  );
}

/**
 * Middleware to handle reduced functionality responses
 * @param {string} serviceName - Name of the service
 * @returns {Function} - Express middleware
 */
export function createReducedFunctionalityMiddleware(serviceName) {
  return (req, res, next) => {
    const status = gracefulDegradationService.getStatus(serviceName);

    if (
      status.isDegraded &&
      !gracefulDegradationService.isCriticalEndpoint(serviceName, req.path)
    ) {
      // Add reduced functionality info to request
      req.reducedFunctionality =
        gracefulDegradationService.getReducedFunctionalityResponse(
          serviceName,
          req.path,
        );
    }

    next();
  };
}
