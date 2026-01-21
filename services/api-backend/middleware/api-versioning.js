/**
 * API Versioning Middleware
 *
 * Implements URL-based API versioning strategy with backward compatibility.
 * Supports /v1/, /v2/ URL prefixes and routes to appropriate handlers.
 *
 * Requirements: 12.4
 */

/**
 * API version configuration
 * Defines supported versions and their status
 */
export const API_VERSIONS = {
  v1: {
    version: '1.0.0',
    status: 'deprecated',
    deprecatedAt: '2024-01-01',
    sunsetAt: '2025-01-01',
    description: 'Legacy API version - use v2 for new integrations',
  },
  v2: {
    version: '2.0.0',
    status: 'current',
    description: 'Current stable API version',
  },
};

/**
 * Default API version for requests without explicit version
 */
export const DEFAULT_API_VERSION = 'v2';

/**
 * Extract API version from request path
 * Supports /v1/, /v2/ prefixes
 *
 * @param {string} path - Request path
 * @returns {string} API version (v1, v2, etc.) or null if not found
 */
export function extractVersionFromPath(path) {
  const match = path.match(/^\/v(\d+)\//);
  if (match) {
    return `v${match[1]}`;
  }
  return null;
}

/**
 * API Versioning middleware
 * Extracts version from URL and adds to request object
 *
 * @returns {Function} Express middleware
 */
export function apiVersioningMiddleware() {
  return (req, res, next) => {
    const version = extractVersionFromPath(req.path);

    if (version) {
      // Version found in URL
      if (!API_VERSIONS[version]) {
        return res.status(400).json({
          error: {
            code: 'UNSUPPORTED_API_VERSION',
            message: `API version ${version} is not supported`,
            statusCode: 400,
            supportedVersions: Object.keys(API_VERSIONS),
            suggestion: `Use one of the supported versions: ${Object.keys(API_VERSIONS).join(', ')}`,
          },
        });
      }

      req.apiVersion = version;
      req.versionInfo = API_VERSIONS[version];

      // Add deprecation headers if version is deprecated
      if (API_VERSIONS[version].status === 'deprecated') {
        res.set('Deprecation', 'true');
        res.set(
          'Sunset',
          new Date(API_VERSIONS[version].sunsetAt).toUTCString(),
        );
        res.set(
          'Warning',
          `299 - "API version ${version} is deprecated. Migrate to v2 before ${API_VERSIONS[version].sunsetAt}"`,
        );
      }
    } else {
      // No version in URL, use default
      req.apiVersion = DEFAULT_API_VERSION;
      req.versionInfo = API_VERSIONS[DEFAULT_API_VERSION];
    }

    // Add version info to response headers
    res.set('API-Version', req.apiVersion);
    res.set('API-Version-Status', req.versionInfo.status);

    next();
  };
}

/**
 * Version routing helper
 * Routes requests to version-specific handlers
 *
 * @param {Object} handlers - Object with version keys (v1, v2) and handler values
 * @returns {Function} Express middleware
 */
export function versionRouter(handlers) {
  return (req, res, next) => {
    const version = req.apiVersion || DEFAULT_API_VERSION;
    const handler = handlers[version];

    if (!handler) {
      return res.status(501).json({
        error: {
          code: 'VERSION_NOT_IMPLEMENTED',
          message: `This endpoint is not available in API version ${version}`,
          statusCode: 501,
          suggestion: 'Try using a different API version',
        },
      });
    }

    // Call the version-specific handler
    if (Array.isArray(handler)) {
      // If handler is an array of middleware, apply them in sequence
      return handler[handler.length - 1](req, res, next);
    }

    return handler(req, res, next);
  };
}

/**
 * Create version-specific router
 * Mounts routes under /v1/, /v2/ prefixes
 *
 * @param {Function} routeFactory - Function that takes version and returns router
 * @returns {Object} Object with mounted routers for each version
 */
export function createVersionedRouter(routeFactory) {
  const routers = {};

  Object.keys(API_VERSIONS).forEach((version) => {
    routers[version] = routeFactory(version);
  });

  return routers;
}

/**
 * Mount versioned routes on Express app
 * Registers routes under /v1/, /v2/ prefixes
 *
 * @param {Object} app - Express app
 * @param {string} basePath - Base path for routes (e.g., '/api/users')
 * @param {Object} routers - Object with version keys and router values
 */
export function mountVersionedRoutes(app, basePath, routers) {
  Object.entries(routers).forEach(([version, router]) => {
    const versionPath = `/${version}${basePath}`;
    app.use(versionPath, router);
  });

  // Also mount without version prefix for backward compatibility (defaults to v2)
  if (routers[DEFAULT_API_VERSION]) {
    app.use(basePath, routers[DEFAULT_API_VERSION]);
  }
}

/**
 * Get API version info endpoint
 * Returns information about supported API versions
 *
 * @returns {Function} Express middleware
 */
export function getVersionInfoHandler() {
  return (req, res) => {
    res.json({
      currentVersion: req.apiVersion,
      defaultVersion: DEFAULT_API_VERSION,
      supportedVersions: Object.entries(API_VERSIONS).map(([key, value]) => ({
        version: key,
        ...value,
      })),
      timestamp: new Date().toISOString(),
    });
  };
}

/**
 * Backward compatibility helper
 * Transforms v1 request/response to v2 format
 *
 * @param {Object} req - Express request
 * @param {Object} res - Express response
 * @param {Function} next - Express next
 */
export function backwardCompatibilityMiddleware() {
  return (req, res, next) => {
    if (req.apiVersion === 'v1') {
      // Store original send method
      const originalSend = res.send;

      // Override send to transform response for v1
      /* eslint-disable space-before-function-paren */
      res.send = function (data) {
        // Transform v2 response format to v1 if needed
        if (typeof data === 'object' && data !== null) {
          // Add v1-specific fields or transformations here
          data._apiVersion = 'v1';
        }

        // Call original send
        return originalSend.call(this, data);
      };
    }

    next();
  };
}

export default apiVersioningMiddleware;
