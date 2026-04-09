/**
 * API Deprecation Middleware
 *
 * Handles deprecation warnings, headers, and sunset enforcement.
 * Adds deprecation headers to responses for deprecated endpoints.
 *
 * Requirements: 12.5
 */

import logger from '../logger.js';
import {
  isDeprecated,
  isSunset,
  getDeprecationHeaders,
  getDeprecationInfo,
  getMigrationGuide,
  formatDeprecationWarning,
} from '../services/deprecation-service.js';

/**
 * Deprecation middleware
 * Adds deprecation headers and warnings to responses
 *
 * @returns {Function} Express middleware
 */
export function deprecationMiddleware() {
  return (req, res, next) => {
    // Check if endpoint is sunset (no longer available)
    if (isSunset(req.path)) {
      const info = getDeprecationInfo(req.path);
      return res.status(410).json({
        error: {
          code: 'ENDPOINT_SUNSET',
          message: `This API endpoint has been removed as of ${info.sunsetAt}`,
          statusCode: 410,
          replacedBy: info.replacedBy,
          suggestion: `Please use ${info.replacedBy} instead`,
          migrationGuide: getMigrationGuide(req.path),
        },
      });
    }

    // Check if endpoint is deprecated
    if (isDeprecated(req.path)) {
      const deprecationHeaders = getDeprecationHeaders(req.path);

      // Add deprecation headers to response
      Object.entries(deprecationHeaders).forEach(([key, value]) => {
        res.set(key, value);
      });

      // Store deprecation info in request for logging
      req.deprecationInfo = getDeprecationInfo(req.path);
    }

    next();
  };
}

/**
 * Deprecation warning middleware
 * Logs deprecation warnings for monitoring
 *
 * @returns {Function} Express middleware
 */
export function deprecationWarningMiddleware() {
  return (req, res, next) => {
    if (isDeprecated(req.path)) {
      const warning = formatDeprecationWarning(req.path);

      // Log deprecation warning
      logger.warn(`[DEPRECATION] ${warning}`, {
        path: req.path,
        method: req.method,
        timestamp: new Date().toISOString(),
        userId: req.user?.id,
      });

      // Store warning in request for potential response inclusion
      req.deprecationWarning = warning;
    }

    next();
  };
}

/**
 * Deprecation response middleware
 * Includes deprecation info in response body for deprecated endpoints
 *
 * @returns {Function} Express middleware
 */
export function deprecationResponseMiddleware() {
  return (req, res, next) => {
    if (isDeprecated(req.path)) {
      // Store original json method
      const originalJson = res.json;

      // Override json to include deprecation info
      res.json = function (data) {
        // Add deprecation info to response
        if (typeof data === 'object' && data !== null && !Array.isArray(data)) {
          data._deprecation = {
            deprecated: true,
            message: formatDeprecationWarning(req.path),
            replacedBy: getDeprecationInfo(req.path).replacedBy,
            sunsetAt: getDeprecationInfo(req.path).sunsetAt,
            migrationGuide: getMigrationGuide(req.path),
          };
        }

        return originalJson.call(this, data);
      };
    }

    next();
  };
}

/**
 * Deprecation enforcement middleware
 * Can be used to block deprecated endpoints after a certain date
 *
 * @param {Object} options - Configuration options
 * @param {boolean} options.blockDeprecated - Block deprecated endpoints (default: false)
 * @param {boolean} options.blockSunset - Block sunset endpoints (default: true)
 * @returns {Function} Express middleware
 */
export function deprecationEnforcementMiddleware(options = {}) {
  const { blockDeprecated = false, blockSunset = true } = options;

  return (req, res, next) => {
    // Always block sunset endpoints
    if (blockSunset && isSunset(req.path)) {
      const info = getDeprecationInfo(req.path);
      return res.status(410).json({
        error: {
          code: 'ENDPOINT_SUNSET',
          message: `This API endpoint has been removed as of ${info.sunsetAt}`,
          statusCode: 410,
          replacedBy: info.replacedBy,
          suggestion: `Please use ${info.replacedBy} instead`,
        },
      });
    }

    // Optionally block deprecated endpoints
    if (blockDeprecated && isDeprecated(req.path)) {
      const info = getDeprecationInfo(req.path);
      return res.status(410).json({
        error: {
          code: 'ENDPOINT_DEPRECATED',
          message: `This API endpoint is deprecated and will be removed on ${info.sunsetAt}`,
          statusCode: 410,
          replacedBy: info.replacedBy,
          suggestion: `Please migrate to ${info.replacedBy} before ${info.sunsetAt}`,
          migrationGuide: getMigrationGuide(req.path),
        },
      });
    }

    next();
  };
}

export default {
  deprecationMiddleware,
  deprecationWarningMiddleware,
  deprecationResponseMiddleware,
  deprecationEnforcementMiddleware,
};
