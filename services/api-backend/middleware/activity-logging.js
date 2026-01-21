/**
 * Activity Logging Middleware
 *
 * Automatically logs user activities for all API requests
 * Tracks user operations for audit and analytics purposes
 *
 * Validates: Requirements 3.4, 3.10
 * - Tracks user activity and usage metrics
 * - Implements activity audit logs
 */

import {
  logUserActivity,
  ACTIVITY_ACTIONS,
} from '../services/user-activity-service.js';
import logger from '../logger.js';

/**
 * Map of route patterns to activity actions
 * Used to automatically determine the activity action based on the request
 */
const ROUTE_ACTION_MAP = {
  // User profile routes
  'GET /api/users/profile': ACTIVITY_ACTIONS.PROFILE_VIEW,
  'PUT /api/users/profile': ACTIVITY_ACTIONS.PROFILE_UPDATE,
  'DELETE /api/users/profile': ACTIVITY_ACTIONS.PROFILE_DELETE,
  'PUT /api/users/avatar': ACTIVITY_ACTIONS.AVATAR_UPLOAD,
  'PUT /api/users/preferences': ACTIVITY_ACTIONS.PREFERENCES_UPDATE,

  // Tunnel routes
  'POST /api/tunnels': ACTIVITY_ACTIONS.TUNNEL_CREATE,
  'GET /api/tunnels/:id': ACTIVITY_ACTIONS.TUNNEL_STATUS_CHECK,
  'PUT /api/tunnels/:id': ACTIVITY_ACTIONS.TUNNEL_UPDATE,
  'DELETE /api/tunnels/:id': ACTIVITY_ACTIONS.TUNNEL_DELETE,
  'POST /api/tunnels/:id/start': ACTIVITY_ACTIONS.TUNNEL_START,
  'POST /api/tunnels/:id/stop': ACTIVITY_ACTIONS.TUNNEL_STOP,

  // API key routes
  'POST /api/api-keys': ACTIVITY_ACTIONS.API_KEY_CREATE,
  'DELETE /api/api-keys/:id': ACTIVITY_ACTIONS.API_KEY_DELETE,
  'POST /api/api-keys/:id/rotate': ACTIVITY_ACTIONS.API_KEY_ROTATE,

  // Session routes
  'POST /api/auth/login': ACTIVITY_ACTIONS.SESSION_CREATE,
  'POST /api/auth/logout': ACTIVITY_ACTIONS.SESSION_DESTROY,
  'POST /api/auth/refresh': ACTIVITY_ACTIONS.SESSION_REFRESH,

  // Admin routes
  'GET /api/admin/users/:id': ACTIVITY_ACTIONS.ADMIN_USER_VIEW,
  'PUT /api/admin/users/:id': ACTIVITY_ACTIONS.ADMIN_USER_UPDATE,
  'DELETE /api/admin/users/:id': ACTIVITY_ACTIONS.ADMIN_USER_DELETE,
  'POST /api/admin/users/:id/tier': ACTIVITY_ACTIONS.ADMIN_TIER_CHANGE,
};

/**
 * Get activity action for a request
 *
 * @param {string} method - HTTP method
 * @param {string} path - Request path
 * @returns {string|null} Activity action or null if not found
 */
function getActivityAction(method, path) {
  // Try exact match first
  const exactKey = `${method} ${path}`;
  if (ROUTE_ACTION_MAP[exactKey]) {
    return ROUTE_ACTION_MAP[exactKey];
  }

  // Try pattern matching for parameterized routes
  for (const [pattern, action] of Object.entries(ROUTE_ACTION_MAP)) {
    const [patternMethod, patternPath] = pattern.split(' ');

    if (method !== patternMethod) {
      continue;
    }

    // Convert pattern to regex (e.g., /api/tunnels/:id -> /api/tunnels/[^/]+)
    const regexPattern = patternPath.replace(/:[^/]+/g, '[^/]+');
    const regex = new RegExp(`^${regexPattern}$`);

    if (regex.test(path)) {
      return action;
    }
  }

  return null;
}

/**
 * Extract resource information from request
 *
 * @param {string} method - HTTP method
 * @param {string} path - Request path
 * @param {Object} body - Request body
 * @returns {Object} Resource information {type, id}
 */
/* eslint-disable space-before-function-paren */
function extractResourceInfo(method, path, _body = {}) {
  const pathParts = path.split('/');

  // Extract resource type and ID from path
  if (pathParts.includes('tunnels')) {
    const tunnelIndex = pathParts.indexOf('tunnels');
    const tunnelId = pathParts[tunnelIndex + 1];
    return {
      resourceType: 'tunnel',
      resourceId: tunnelId || null,
    };
  }

  if (pathParts.includes('api-keys')) {
    const keyIndex = pathParts.indexOf('api-keys');
    const keyId = pathParts[keyIndex + 1];
    return {
      resourceType: 'api_key',
      resourceId: keyId || null,
    };
  }

  if (pathParts.includes('users')) {
    const userIndex = pathParts.indexOf('users');
    const userId = pathParts[userIndex + 1];
    return {
      resourceType: 'user',
      resourceId: userId || null,
    };
  }

  return {
    resourceType: null,
    resourceId: null,
  };
}

/**
 * Activity logging middleware
 *
 * Logs user activities for audit and analytics purposes
 * Attaches activity logging to response object for use in route handlers
 *
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next middleware function
 */
export function activityLoggingMiddleware(req, res, next) {
  // Skip logging for non-authenticated requests
  if (!req.user) {
    return next();
  }

  // Skip logging for health checks and metrics
  if (req.path === '/health' || req.path === '/metrics') {
    return next();
  }

  // Get activity action for this request
  const action = getActivityAction(req.method, req.path);

  // If no action found, skip logging
  if (!action) {
    return next();
  }

  // Extract resource information
  const { resourceType, resourceId } = extractResourceInfo(
    req.method,
    req.path,
    req.body,
  );

  // Get client IP address
  const ipAddress = req.ip || req.connection.remoteAddress || 'unknown';

  // Get user agent
  const userAgent = req.get('user-agent') || 'unknown';

  // Attach activity logging function to response for use in route handlers
  res.logActivity = async (options = {}) => {
    try {
      await logUserActivity({
        userId: req.user.sub,
        action: options.action || action,
        resourceType: options.resourceType || resourceType,
        resourceId: options.resourceId || resourceId,
        ipAddress,
        userAgent,
        details: options.details || {},
        severity: options.severity || 'info',
      });
    } catch (error) {
      logger.error('[ActivityLogging] Failed to log activity', {
        error: error.message,
        userId: req.user.sub,
        action,
      });
    }
  };

  // Log activity after response is sent
  const originalSend = res.send;
  res.send = function (data) {
    // Only log successful requests (2xx status codes)
    if (res.statusCode >= 200 && res.statusCode < 300) {
      logUserActivity({
        userId: req.user.sub,
        action,
        resourceType,
        resourceId,
        ipAddress,
        userAgent,
        details: {
          method: req.method,
          path: req.path,
          statusCode: res.statusCode,
        },
        severity: 'info',
      }).catch((error) => {
        logger.error('[ActivityLogging] Failed to log activity', {
          error: error.message,
          userId: req.user.sub,
          action,
        });
      });
    }

    return originalSend.call(this, data);
  };

  next();
}

export default activityLoggingMiddleware;
