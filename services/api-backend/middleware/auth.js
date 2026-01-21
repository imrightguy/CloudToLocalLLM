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

// JWT configuration
const AUTH0_DOMAIN = process.env.AUTH0_DOMAIN;
const AUTH0_AUDIENCE = process.env.AUTH0_AUDIENCE;

const isAuthConfigured = !!(AUTH0_DOMAIN && AUTH0_AUDIENCE);

if (!isAuthConfigured && process.env.NODE_ENV !== 'test') {
  console.warn(
    ' [WARNING] Auth0 configuration is missing (AUTH0_DOMAIN, AUTH0_AUDIENCE).',
  );
  console.warn(
    ' [WARNING] Authentication features will return 503 Service Unavailable.',
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

  return auth({
    audience: AUTH0_AUDIENCE,
    issuerBaseURL: `https://${AUTH0_DOMAIN}/`,
    tokenSigningAlg: 'RS256',
  })(req, res, next);
};

// Use AuthService for session synchronization and revocation checks
const authService = isAuthConfigured
  ? new AuthService({
      AUTH0_AUDIENCE,
    })
  : null;

let authServiceInitialized = false;

async function ensureAuthServiceInitialized() {
  if (authServiceInitialized || process.env.NODE_ENV === 'test') {
    return;
  }
  try {
    await authService.initialize();
    authServiceInitialized = true;
  } catch (error) {
    logger.error(' [Auth] Failed to initialize AuthService', {
      error: error.message,
    });
    throw error;
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
    await ensureAuthServiceInitialized();

    // auth() middleware from express-oauth2-jwt-bearer populates req.auth
    const tokenPayload = req.auth.payload;
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!tokenPayload || !token) {
      return res.status(401).json({
        error: 'Unauthorized',
        message: 'No validated token payload found',
      });
    }

    const userId = tokenPayload.sub;

    // 1. Rigorous session integrity check against database
    // This allows for immediate token revocation via the is_active flag
    const isActive = await authService.isTokenActive(userId, token);

    if (!isActive) {
      // If no active session found, we might want to auto-sync it if it's a fresh valid login
      // But per requirements, we want synchronized validation.
      // For now, let's auto-sync if it's the first time we see this valid JWT.
      const session = await authService.syncSession(tokenPayload, token, req);
      if (!session || !session.is_active) {
        logger.warn(
          ` [Auth] Access denied: Session revoked or inactive for user ${userId}`,
        );
        return res.status(401).json({
          error: 'Unauthorized',
          code: 'SESSION_REVOKED',
          message: 'Your session has been revoked or is no longer active.',
        });
      }
    } else {
      // Update last activity for existing session
      await authService.syncSession(tokenPayload, token, req);
    }

    // Attach user info for convenience
    req.user = tokenPayload;
    req.userId = userId;

    next();
  } catch (error) {
    logger.error(' [Auth] Session synchronization failed', {
      error: error.message,
      userId: req.auth?.payload?.sub,
    });
    next(error);
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

  // Use checkJwt but handle failure gracefully
  checkJwt(req, res, (err) => {
    if (err) {
      logger.debug(' [Auth] Optional auth failed verification:', err.message);
      return next();
    }
    // If JWT is valid, also try to sync/check session but don't block
    syncSession(req, res, (syncErr) => {
      if (syncErr) {
        logger.debug(
          ' [Auth] Optional auth session sync failed:',
          syncErr.message,
        );
      }
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
  if (!req.user || !req.user.sub) {
    throw new Error('User not authenticated or user ID not available');
  }
  return req.user.sub;
}

/**
 * Extract user email from authenticated request
 * @param {Object} req - Express request object
 * @returns {string|null} User email from JWT token
 */
export function extractUserEmail(req) {
  return req.user?.email || null;
}

/**
 * Check if user has specific permission/scope
 * @param {string} requiredScope - Required scope/permission
 * @returns {Function} Express middleware function
 */
export function requireScope(requiredScope) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTHENTICATION_REQUIRED',
      });
    }

    const userScopes = req.user.scope ? req.user.scope.split(' ') : [];

    if (!userScopes.includes(requiredScope)) {
      logger.warn(
        ` [Auth] User ${req.user.sub} missing required scope: ${requiredScope}`,
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
 * Validates container tokens for internal API calls
 */
export function authenticateContainer(req, res, next) {
  const timestamp = req.headers['x-timestamp'];
  const signature = req.headers['x-signature'];
  const containerId = req.headers['x-container-id'];
  const sharedSecret = process.env.CONTAINER_SHARED_SECRET; // Load from secure env var

  if (!timestamp || !signature || !containerId) {
    return res.status(401).json({
      error: 'Container authentication headers required',
      code: 'CONTAINER_AUTH_HEADERS_REQUIRED',
    });
  }

  // 1. Check timestamp validity (e.g., within 5 minutes)
  const now = Date.now();
  const requestTime = new Date(timestamp).getTime();
  if (isNaN(requestTime) || Math.abs(now - requestTime) > 300000) {
    // 5 minutes
    return res.status(403).json({
      error: 'Invalid or expired timestamp',
      code: 'INVALID_TIMESTAMP',
    });
  }

  // 2. Reconstruct the message and generate the expected signature
  const message = `${timestamp}.${req.method}.${req.path}`;
  const expectedSignature = crypto
    .createHmac('sha256', sharedSecret)
    .update(message)
    .digest('hex');

  // 3. Compare signatures
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
  logger.debug(` [Auth] Container authenticated: ${containerId}`);
  next();
}

/**
 * Validate container token (enhanced placeholder implementation)
 * FUTURE ENHANCEMENT: Implement proper container authentication with secure token store
 *
 * Current implementation provides basic validation for premium/enterprise tier containers.
 * This is sufficient for tier-based architecture deployment as free tier users don't use containers.
 */

/**
 * Admin authentication middleware
 * Requires admin role/scope for access with comprehensive role checking
 */
export function requireAdmin(req, res, next) {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    // Check for admin role in multiple possible locations
    const userMetadata =
      req.user['https://cloudtolocalllm.com/user_metadata'] || {};
    const appMetadata =
      req.user['https://cloudtolocalllm.com/app_metadata'] || {};
    const userRoles = req.user['https://cloudtolocalllm.online/roles'] || [];
    const userScopes = req.user.scope ? req.user.scope.split(' ') : [];

    // Check various places where admin role might be stored
    const hasAdminRole =
      userMetadata.role === 'admin' ||
      appMetadata.role === 'admin' ||
      userRoles.includes('admin') ||
      userScopes.includes('admin') ||
      (req.user.permissions && req.user.permissions.includes('admin')) ||
      req.user.role === 'admin';

    if (!hasAdminRole) {
      logger.warn(' [AdminAuth] Admin access denied', {
        userId: req.user.sub,
        userMetadata,
        appMetadata,
        userRoles,
        userScopes,
        permissions: req.user.permissions,
        userAgent: req.get('User-Agent'),
        ipAddress: req.ip,
      });

      return res.status(403).json({
        error: 'Admin access required',
        code: 'ADMIN_ACCESS_REQUIRED',
        message: 'This operation requires administrative privileges',
      });
    }

    logger.info(' [AdminAuth] Admin access granted', {
      userId: req.user.sub,
      role: userMetadata.role || appMetadata.role || 'admin',
      userAgent: req.get('User-Agent'),
    });

    next();
  } catch (error) {
    logger.error(' [AdminAuth] Admin role check failed', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Admin role verification failed',
      code: 'ADMIN_CHECK_FAILED',
    });
  }
}

/**
 * Rate limiting by user ID
 * @param {Object} options - Rate limiting options
 * @returns {Function} Express middleware function
 */
export function rateLimitByUser(options = {}) {
  const { windowMs = 15 * 60 * 1000, max = 100 } = options;

  // Create a Redis client.
  const redisClient = new Redis({
    host: process.env.REDIS_HOST || 'localhost',
    port: process.env.REDIS_PORT || 6379,
    password: process.env.REDIS_PASSWORD,
  });

  // Create a new store for the rate limiter.
  const store = new RedisStore({
    sendCommand: (...args) => redisClient.call(...args),
  });

  // Create a rate limiter that uses the Redis store.
  return rateLimit({
    store,
    windowMs,
    max,
    keyGenerator: (req) => req.userId || req.ip, // Use user ID or fallback to IP
    handler: (req, res) => {
      res.status(429).json({
        error: 'Too many requests',
        code: 'RATE_LIMIT_EXCEEDED',
      });
    },
  });
}
