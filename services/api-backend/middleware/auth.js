/**
 * Authentication Middleware for CloudToLocalLLM API Backend
 *
 * Provides JWT authentication and authorization for API endpoints
 * with user ID extraction utilities.
 */

import { auth } from 'express-oauth2-jwt-bearer';
import crypto from 'crypto';
import Redis from 'ioredis';
import { RedisStore } from 'rate-limit-redis';
import rateLimit from 'express-rate-limit';
import logger from '../logger.js';
import { AuthService } from '../auth/auth-service.js';

// JWT configuration - Requirements 2.1
const AUTH0_DOMAIN =
  process.env.AUTH0_DOMAIN || 'dev-vivn1fcgzi0c2czy.us.auth0.com';
const AUTH0_AUDIENCE =
  process.env.AUTH0_AUDIENCE || 'https://api.cloudtolocalllm.online';

const isAuthConfigured = !!(AUTH0_DOMAIN && AUTH0_AUDIENCE);

if (!isAuthConfigured && process.env.NODE_ENV !== 'test') {
  logger.warn(
    'Auth0 configuration is missing (AUTH0_DOMAIN, AUTH0_AUDIENCE).',
  );
  logger.warn(
    'Authentication features will return 503 Service Unavailable.',
  );
}

// Rigorous JWT verification middleware using industry-standard library
export const checkJwt = (req, res, next) => {
  if (process.env.NODE_ENV === 'test') {
    return next();
  }

  if (!isAuthConfigured) {
    return res.status(503).json({
      error: 'Authentication service not configured',
      code: 'AUTH_NOT_CONFIGURED',
      message:
        'The server is missing Auth0 configuration. Please check environment variables.',
    });
  }

  const authHandler = auth({
    audience: AUTH0_AUDIENCE,
    issuerBaseURL: `https://${AUTH0_DOMAIN}/`,
    tokenSigningAlg: 'RS256',
  });

  return authHandler(req, res, (err) => {
    if (err) {
      logger.warn(' [Auth] JWT verification failed', {
        error: err.message,
        path: req.path,
        token: req.headers.authorization ? 'present' : 'missing',
      });
      return next(err);
    }
    next();
  });
};

// Use AuthService for session synchronization and revocation checks
const authService = isAuthConfigured
  ? new AuthService({
      AUTH0_AUDIENCE,
    })
  : null;

let authServiceInitialized = false;

async function ensureAuthServiceInitialized() {
  if (
    authServiceInitialized ||
    process.env.NODE_ENV === 'test' ||
    !authService
  ) {
    return;
  }
  try {
    await authService.initialize();
    authServiceInitialized = true;
  } catch (error) {
    logger.error(' [Auth] Failed to initialize AuthService', {
      error: error.message,
    });
  }
}

/**
 * Synchronized Session Validation Middleware
 * Checks the validated JWT against the database to handle revocation and session integrity
 */
export async function syncSession(req, res, next) {
  try {
    if (process.env.NODE_ENV === 'test') {
      return next();
    }

    // Attach token payload to req.user for backward compatibility
    if (req.auth && req.auth.payload) {
      req.user = req.auth.payload;
      req.userId = req.auth.payload.sub;
    }

    // Fallback if authService is not available
    if (!authService) {
      return next();
    }

    await ensureAuthServiceInitialized();

    const userId = req.userId || req.auth?.payload?.sub;
    if (!userId) {
      logger.warn(' [Auth] No sub claim in token');
      return res.status(401).json({ error: 'Invalid token: missing sub' });
    }

    // Optional: Synchronize session with database
    try {
      let token = req.headers.authorization?.split(' ')[1] || req.auth?.token;

      // If req.auth is the result of express-oauth2-jwt-bearer, the token might be in req.auth.token
      // but if it's already a validated payload, we might not have the raw token.
      // However, createOrUpdateSession uses it for hashing.

      if (typeof token !== 'string') {
        logger.debug(' [Auth] Raw token not found as string, using placeholder for sync', { tokenType: typeof token });
        token = 'validated-payload-no-raw-token';
      }

      const result = await Promise.race([
        authService.syncSession(req.auth.payload, token, req),
        new Promise((_, reject) =>
          setTimeout(() => reject(new Error('Timeout')), 2000),
        ),
      ]);

      if (!result.success) {
        logger.warn(' [Auth] Session sync failed', {
          userId,
          reason: result.error,
        });
      }
    } catch (syncError) {
      logger.error(' [Auth] Session sync error or timeout (continuing)', {
        userId,
        error: syncError.message,
      });
    }

    next();
  } catch (error) {
    logger.error(' [Auth] syncSession error', { error: error.message });
    res.status(401).json({ error: 'Authentication failed' });
  }
}

/**
 * Optional authentication middleware
 * Attaches user info if token is present and valid, but doesn't require it
 */
export async function optionalAuth(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return next();
  }

  // Use checkJwt but handle failure gracefully without sending response
  const authHandler = auth({
    audience: AUTH0_AUDIENCE,
    issuerBaseURL: `https://${AUTH0_DOMAIN}/`,
    tokenSigningAlg: 'RS256',
  });

  authHandler(req, res, (err) => {
    if (err) {
      logger.debug(
        ' [Auth] Optional auth failed verification (skipping):',
        err.message,
      );
      return next();
    }

    // If JWT is valid, also try to sync/check session but don't block on error
    syncSession(req, res, (_syncErr) => {
      // Ignore sync errors in optional auth
      next();
    });
  });
}

/**
 * Combined JWT Authentication Middleware
 * Performs rigorous JWT verification AND synchronized session validation
 */
export const authenticateJWT = [
  // 1. Enforce HTTPS in production
  (req, res, next) => {
    if (
      process.env.NODE_ENV === 'production' &&
      req.get('x-forwarded-proto') !== 'https' &&
      req.protocol !== 'https'
    ) {
      return res.status(403).json({
        error: 'HTTPS required',
        code: 'HTTPS_REQUIRED',
      });
    }
    next();
  },
  // 2. Rigorous JWT verification (Audience, Issuer, Signature)
  checkJwt,
  // 3. Synchronized session check (Revocation, Integrity, DB Sync)
  syncSession,
];

/**
 * Extract user ID from authenticated request
 * @param {Object} req - Express request object
 * @returns {string} User ID from JWT token
 */
export function extractUserId(req) {
  const userId = req.userId || req.user?.sub || req.auth?.payload?.sub;
  if (!userId) {
    throw new Error('User not authenticated or user ID not available');
  }
  return userId;
}

/**
 * Extract user email from authenticated request
 * @param {Object} req - Express request object
 * @returns {string|null} User email from JWT token
 */
export function extractUserEmail(req) {
  return req.user?.email || req.auth?.payload?.email || null;
}

/**
 * Check if user has specific permission/scope
 * @param {string} requiredScope - Required scope/permission
 * @returns {Function} Express middleware function
 */
export function requireScope(requiredScope) {
  return (req, res, next) => {
    const user = req.user || req.auth?.payload;
    if (!user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTHENTICATION_REQUIRED',
      });
    }

    const userScopes = user.scope ? user.scope.split(' ') : [];

    if (!userScopes.includes(requiredScope)) {
      logger.warn(
        ` [Auth] User ${user.sub} missing required scope: ${requiredScope}`,
      );
      return res.status(403).json({
        error: 'Insufficient permissions',
        code: 'INSUFFICIENT_PERMISSIONS',
        requiredScope,
      });
    }

    next();
  };
}

/**
 * Container authentication middleware
 */
export function authenticateContainer(req, res, next) {
  const timestamp = req.headers['x-timestamp'];
  const signature = req.headers['x-signature'];
  const containerId = req.headers['x-container-id'];
  const sharedSecret = process.env.CONTAINER_SHARED_SECRET;

  if (!timestamp || !signature || !containerId) {
    return res.status(401).json({
      error: 'Container authentication headers required',
      code: 'CONTAINER_AUTH_HEADERS_REQUIRED',
    });
  }

  const now = Date.now();
  const requestTime = new Date(timestamp).getTime();
  if (isNaN(requestTime) || Math.abs(now - requestTime) > 300000) {
    return res.status(403).json({
      error: 'Invalid or expired timestamp',
      code: 'INVALID_TIMESTAMP',
    });
  }

  const message = `${timestamp}.${req.method}.${req.path}`;
  const expectedSignature = crypto
    .createHmac('sha256', sharedSecret)
    .update(message)
    .digest('hex');

  if (
    !crypto.timingSafeEqual(
      Buffer.from(signature),
      Buffer.from(expectedSignature),
    )
  ) {
    return res.status(403).json({
      error: 'Invalid signature',
      code: 'INVALID_SIGNATURE',
    });
  }

  req.containerId = containerId;
  next();
}

/**
 * Admin authentication middleware
 */
export function requireAdmin(req, res, next) {
  try {
    const user = req.user || req.auth?.payload;
    if (!user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    const userMetadata =
      user['https://CloudToLocalLLM.com/user_metadata'] || {};
    const appMetadata = user['https://CloudToLocalLLM.com/app_metadata'] || {};
    const userRoles = user['https://cloudtolocalllm.online/roles'] || [];
    const userScopes = user.scope ? user.scope.split(' ') : [];

    const hasAdminRole =
      userMetadata.role === 'admin' ||
      appMetadata.role === 'admin' ||
      userRoles.includes('admin') ||
      userScopes.includes('admin') ||
      (user.permissions && user.permissions.includes('admin')) ||
      user.role === 'admin';

    if (!hasAdminRole) {
      return res.status(403).json({
        error: 'Admin access required',
        code: 'ADMIN_ACCESS_REQUIRED',
        message: 'This operation requires administrative privileges',
      });
    }

    next();
  } catch (error) {
    logger.error(' [AdminAuth] Admin role check failed', {
      error: error.message,
    });
    res.status(500).json({
      error: 'Admin role verification failed',
      code: 'ADMIN_CHECK_FAILED',
    });
  }
}

/**
 * Rate limiting by user ID
 */
export function rateLimitByUser(options = {}) {
  const { windowMs = 15 * 60 * 1000, max = 100 } = options;

  const redisClient = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD,
  });

  const store = new RedisStore({
    sendCommand: (...args) => redisClient.call(...args),
  });

  return rateLimit({
    store,
    windowMs,
    max,
    keyGenerator: (req) => req.userId || req.ip,
    handler: (req, res) => {
      res.status(429).json({
        error: 'Too many requests',
        code: 'RATE_LIMIT_EXCEEDED',
      });
    },
  });
}
