/**
 * Authentication Audit Logging Middleware for CloudToLocalLLM API Backend
 *
 * Automatically logs all authentication attempts, successes, and failures
 * with full context including IP address, user agent, and timestamp.
 *
 * Validates: Requirements 2.6, 11.10
 * - Logs all authentication attempts (success and failure)
 * - Creates audit log entries for auth events
 * - Includes IP address, user agent, and timestamp
 */

import logger from '../logger.js';
import {
  logLoginSuccess,
  logLoginFailure,
  logLogout,
  logTokenRefresh,
  logTokenRevoke,
  logSessionTimeout,
} from '../services/auth-audit-service.js';

/**
 * Middleware to log successful authentication
 * Should be called after successful JWT validation
 *
 * @returns {Function} Express middleware function
 */
export function authSuccessAuditMiddleware() {
  return async (req, res, next) => {
    // Store original json method
    const originalJson = res.json;

    // Override json method to intercept responses
    res.json = function (data) {
      // Check if this is a successful auth response
      if (req.path === '/auth/me' && res.statusCode === 200 && req.user) {
        // Log successful authentication
        logLoginSuccess({
          userId: req.user.sub || req.userId,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          details: {
            endpoint: req.path,
            method: req.method,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log auth success', {
            error: error.message,
          });
        });
      }

      // Call original json method
      return originalJson.call(this, data);
    };

    next();
  };
}

/**
 * Middleware to log failed authentication attempts
 * Should be called in error handling middleware
 *
 * @returns {Function} Express middleware function
 */
export function authFailureAuditMiddleware() {
  return async (req, res, next) => {
    // Store original json method
    const originalJson = res.json;

    // Override json method to intercept error responses
    res.json = function (data) {
      // Check if this is an authentication error
      if (
        res.statusCode === 401 &&
        data.error &&
        (data.code === 'INVALID_TOKEN' ||
          data.code === 'TOKEN_EXPIRED' ||
          data.code === 'TOKEN_VERIFICATION_FAILED' ||
          data.code === 'MISSING_TOKEN' ||
          data.code === 'INVALID_TOKEN_FORMAT')
      ) {
        // Log failed authentication
        logLoginFailure({
          userId: req.user?.sub || req.userId || null,
          email: req.body?.email || null,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          reason: data.error || 'Authentication failed',
          details: {
            code: data.code,
            endpoint: req.path,
            method: req.method,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log auth failure', {
            error: error.message,
          });
        });
      }

      // Call original json method
      return originalJson.call(this, data);
    };

    next();
  };
}

/**
 * Middleware to log logout events
 * Should be called on logout endpoint
 *
 * @returns {Function} Express middleware function
 */
export function logoutAuditMiddleware() {
  return async (req, res, next) => {
    // Store original json method
    const originalJson = res.json;

    // Override json method to intercept logout responses
    res.json = function (data) {
      // Check if this is a successful logout response
      if (
        req.path === '/auth/logout' &&
        res.statusCode === 200 &&
        data.success
      ) {
        // Log logout
        logLogout({
          userId: req.user?.sub || req.userId,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          details: {
            endpoint: req.path,
            method: req.method,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log logout', {
            error: error.message,
          });
        });
      }

      // Call original json method
      return originalJson.call(this, data);
    };

    next();
  };
}

/**
 * Middleware to log token refresh events
 * Should be called on token refresh endpoint
 *
 * @returns {Function} Express middleware function
 */
export function tokenRefreshAuditMiddleware() {
  return async (req, res, next) => {
    // Store original json method
    const originalJson = res.json;

    // Override json method to intercept token refresh responses
    res.json = function (data) {
      // Check if this is a successful token refresh response
      if (
        req.path === '/auth/token/refresh' &&
        res.statusCode === 200 &&
        data.accessToken
      ) {
        // Log token refresh
        logTokenRefresh({
          userId: req.user?.sub || req.userId || null,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          details: {
            endpoint: req.path,
            method: req.method,
            expiresIn: data.expiresIn,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log token refresh', {
            error: error.message,
          });
        });
      }

      // Call original json method
      return originalJson.call(this, data);
    };

    next();
  };
}

/**
 * Middleware to log token revocation events
 * Should be called on token revocation endpoint
 *
 * @returns {Function} Express middleware function
 */
export function tokenRevokeAuditMiddleware() {
  return async (req, res, next) => {
    // Store original json method
    const originalJson = res.json;

    // Override json method to intercept token revocation responses
    res.json = function (data) {
      // Check if this is a successful token revocation response
      if (
        req.path === '/auth/session/revoke' &&
        res.statusCode === 200 &&
        data.success
      ) {
        // Log token revocation
        logTokenRevoke({
          userId: req.user?.sub || req.userId,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          details: {
            endpoint: req.path,
            method: req.method,
            sessionId: data.sessionId,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log token revocation', {
            error: error.message,
          });
        });
      }

      // Call original json method
      return originalJson.call(this, data);
    };

    next();
  };
}

/**
 * Middleware to log session timeout events
 * Should be called when session expires
 *
 * @returns {Function} Express middleware function
 */
export function sessionTimeoutAuditMiddleware() {
  return async (req, res, next) => {
    // Store original json method
    const originalJson = res.json;

    // Override json method to intercept session timeout responses
    res.json = function (data) {
      // Check if this is a session timeout error
      if (res.statusCode === 401 && data.code === 'SESSION_TIMEOUT') {
        // Log session timeout
        logSessionTimeout({
          userId: req.user?.sub || req.userId || null,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          details: {
            endpoint: req.path,
            method: req.method,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log session timeout', {
            error: error.message,
          });
        });
      }

      // Call original json method
      return originalJson.call(this, data);
    };

    next();
  };
}

/**
 * Comprehensive authentication audit middleware
 * Logs all authentication-related events
 *
 * @returns {Function} Express middleware function
 */
export function comprehensiveAuthAuditMiddleware() {
  return async (req, res, next) => {
    // Store original json method
    const originalJson = res.json;

    // Override json method to intercept all responses
    res.json = function (data) {
      // Log successful authentication
      if (req.path === '/auth/me' && res.statusCode === 200 && req.user) {
        logLoginSuccess({
          userId: req.user.sub || req.userId,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          details: {
            endpoint: req.path,
            method: req.method,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log auth success', {
            error: error.message,
          });
        });
      }

      // Log failed authentication
      if (
        res.statusCode === 401 &&
        data.error &&
        (data.code === 'INVALID_TOKEN' ||
          data.code === 'TOKEN_EXPIRED' ||
          data.code === 'TOKEN_VERIFICATION_FAILED' ||
          data.code === 'MISSING_TOKEN' ||
          data.code === 'INVALID_TOKEN_FORMAT')
      ) {
        logLoginFailure({
          userId: req.user?.sub || req.userId || null,
          email: req.body?.email || null,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          reason: data.error || 'Authentication failed',
          details: {
            code: data.code,
            endpoint: req.path,
            method: req.method,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log auth failure', {
            error: error.message,
          });
        });
      }

      // Log logout
      if (
        req.path === '/auth/logout' &&
        res.statusCode === 200 &&
        data.success
      ) {
        logLogout({
          userId: req.user?.sub || req.userId,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          details: {
            endpoint: req.path,
            method: req.method,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log logout', {
            error: error.message,
          });
        });
      }

      // Log token refresh
      if (
        req.path === '/auth/token/refresh' &&
        res.statusCode === 200 &&
        data.accessToken
      ) {
        logTokenRefresh({
          userId: req.user?.sub || req.userId || null,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          details: {
            endpoint: req.path,
            method: req.method,
            expiresIn: data.expiresIn,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log token refresh', {
            error: error.message,
          });
        });
      }

      // Log token revocation
      if (
        req.path === '/auth/session/revoke' &&
        res.statusCode === 200 &&
        data.success
      ) {
        logTokenRevoke({
          userId: req.user?.sub || req.userId,
          ipAddress: req.ip || req.connection.remoteAddress,
          userAgent: req.get('User-Agent'),
          details: {
            endpoint: req.path,
            method: req.method,
            sessionId: data.sessionId,
          },
        }).catch((error) => {
          logger.error('[AuthAudit] Failed to log token revocation', {
            error: error.message,
          });
        });
      }

      // Call original json method
      return originalJson.call(this, data);
    };

    next();
  };
}

export default {
  authSuccessAuditMiddleware,
  authFailureAuditMiddleware,
  logoutAuditMiddleware,
  tokenRefreshAuditMiddleware,
  tokenRevokeAuditMiddleware,
  sessionTimeoutAuditMiddleware,
  comprehensiveAuthAuditMiddleware,
};
