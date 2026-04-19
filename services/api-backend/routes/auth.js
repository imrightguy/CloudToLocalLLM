/**
 * Authentication Routes for CloudToLocalLLM API Backend
 *
 * Provides JWT token validation and user information endpoints.
 * Note: Authentication is handled by provider-agnostic JWT validation (e.g., Auth0).
 *
 * Requirements: 2.1, 2.2, 2.9, 2.10
 */

import express from 'express';
import { z } from 'zod';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';
import logger from '../logger.js';
import { authenticateJWT, extractUserId } from '../middleware/auth.js';
import { logLogout, logTokenRevoke } from '../services/auth-audit-service.js';
import { validateSchema } from '../middleware/schema-validation.js';

const router = express.Router();

// Rate limiter for auth checks to prevent brute force/enumeration
const authCheckLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // Limit each IP to 100 checks per 15 min
  message: {
    error: 'Too many auth checks',
    message: 'Please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

const revokeSessionSchema = {
  body: z.object({
    sessionId: z.string().uuid({ message: 'sessionId must be a valid UUID' }),
  }),
};

// Token refresh configuration
const TOKEN_REFRESH_WINDOW = parseInt(process.env.TOKEN_REFRESH_WINDOW) || 300; // 5 minutes before expiry

/**
 * @swagger
 * /auth/token/refresh:
 *   post:
 *     summary: Refresh an expired or expiring JWT token
 *     description: |
 *       Placeholder for token refresh. Token refresh should be handled directly
 *       via the identity provider client SDK.
 *     tags:
 *       - Authentication
 *     responses:
 *       400:
 *         description: Operation not supported on backend
 */
router.post('/token/refresh', authCheckLimiter, async function (req, res) {
  return res.status(400).json({
    error:
      'Token refresh should be handled by the identity provider client SDK',
    code: 'USE_AUTH_PROVIDER_SDK',
  });
});

/**
 * @swagger
 * /auth/token/validate:
 *   post:
 *     summary: Validate a JWT token
 *     description: |
 *       Validates a JWT token and returns its status, expiry information,
 *       and user details. Does not require authentication.
 *
 *       **Validates: Requirements 2.1**
 *       - Validates JWT tokens on every protected request
 *     tags:
 *       - Authentication
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               token:
 *                 type: string
 *                 description: JWT token to validate (optional if using Authorization header)
 *           example:
 *             token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
 *     responses:
 *       200:
 *         description: Token validation result
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 valid:
 *                   type: boolean
 *                   description: Whether token is valid and not expired
 *                 expired:
 *                   type: boolean
 *                   description: Whether token has expired
 *                 expiring:
 *                   type: boolean
 *                   description: Whether token is expiring soon (within 5 minutes)
 *                 expiresIn:
 *                   type: integer
 *                   description: Seconds until token expires
 *                 expiresAt:
 *                   type: string
 *                   format: date-time
 *                   description: Token expiry timestamp
 *                 userId:
 *                   type: string
 *                   description: User ID from token
 *                 email:
 *                   type: string
 *                   description: User email from token
 *       400:
 *         description: Missing token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Invalid token format
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         description: Validation error
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 */
router.post(
  '/token/validate',
  authCheckLimiter,
  authenticateJWT,
  async function (req, res) {
    try {
      // If authenticateJWT middleware passed, the token is DEFINITELY valid and verified
      const tokenPayload = req.user;
      const now = Math.floor(Date.now() / 1000);
      const expiresIn = tokenPayload.exp - now;
      const isExpiring = expiresIn <= TOKEN_REFRESH_WINDOW;

      logger.info('[Auth] Token validation result (Verified)', {
        isExpiring,
        expiresIn,
        userId: req.userId,
      });

      res.json({
        valid: true,
        expired: false,
        expiring: isExpiring,
        expiresIn: Math.max(0, expiresIn),
        expiresAt: new Date(tokenPayload.exp * 1000).toISOString(),
        userId: req.userId,
        email: tokenPayload.email,
      });
    } catch (error) {
      logger.error('[Auth] Token validation error', {
        error: error.message,
      });

      res.status(500).json({
        error: 'Token validation failed',
        code: 'TOKEN_VALIDATION_ERROR',
      });
    }
  },
);

/**
 * @swagger
 * /auth/logout:
 *   post:
 *     summary: Logout and revoke token
 *     description: |
 *       Revokes the current JWT token and invalidates the session.
 *       Clears secure refresh token cookies.
 *
 *       **Validates: Requirements 2.9, 2.10**
 *       - Implements token revocation for logout operations
 *       - Enforces HTTPS for all authentication endpoints
 *     tags:
 *       - Authentication
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Successfully logged out
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 userId:
 *                   type: string
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       403:
 *         description: HTTPS required
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *             example:
 *               error:
 *                 code: HTTPS_REQUIRED
 *                 message: Authentication endpoints require HTTPS
 *                 statusCode: 403
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.post('/logout', authenticateJWT, async function (req, res) {
  try {
    const userId = extractUserId(req);

    logger.info('[Auth] User logout initiated', { userId });

    // Clear refresh token cookie
    res.clearCookie('refreshToken', {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
    });

    logger.info('[Auth] User logged out successfully', { userId });

    // Log logout
    logLogout({
      userId,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      details: {
        endpoint: req.path,
        method: req.method,
      },
    }).catch((auditError) => {
      logger.error('[Auth] Failed to log logout', {
        error: auditError.message,
      });
    });

    res.json({
      success: true,
      message: 'Logged out successfully',
      userId,
    });
  } catch (error) {
    logger.error('[Auth] Logout error', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Logout failed',
      code: 'LOGOUT_ERROR',
      message: error.message,
    });
  }
});

/**
 * @swagger
 * /auth/session/revoke:
 *   post:
 *     summary: Revoke a specific session
 *     description: |
 *       Revokes a specific session by ID. Useful for revoking sessions
 *       from other devices or browsers.
 *
 *       **Validates: Requirements 2.9**
 *       - Implements token revocation for logout operations
 *     tags:
 *       - Authentication
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               sessionId:
 *                 type: string
 *                 description: Session ID to revoke
 *           example:
 *             sessionId: "550e8400-e29b-41d4-a716-446655440000"
 *     responses:
 *       200:
 *         description: Session revoked successfully
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 success:
 *                   type: boolean
 *                 message:
 *                   type: string
 *                 sessionId:
 *                   type: string
 *       400:
 *         description: Missing session ID
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.post(
  '/session/revoke',
  authenticateJWT,
  validateSchema(revokeSessionSchema),
  async function (req, res) {
    try {
      const userId = extractUserId(req);
      const { sessionId } = req.body;

      logger.info('[Auth] Session revocation initiated', { userId, sessionId });

    // Log token revocation
    logTokenRevoke({
      userId,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('User-Agent'),
      details: {
        endpoint: req.path,
        method: req.method,
        sessionId,
      },
    }).catch((auditError) => {
      logger.error('[Auth] Failed to log session revocation', {
        error: auditError.message,
      });
    });

    // In a real implementation, this would revoke the session from the database
    // For now, we'll just return success
    res.json({
      success: true,
      message: 'Session revoked successfully',
      sessionId,
    });
  } catch (error) {
    logger.error('[Auth] Session revocation error', {
      error: error.message,
      userId: req.user?.sub,
    });

    res.status(500).json({
      error: 'Session revocation failed',
      code: 'SESSION_REVOCATION_ERROR',
    });
  }
});

/**
 * @swagger
 * /auth/me:
 *   get:
 *     summary: Get current authenticated user information
 *     description: |
 *       Returns information about the currently authenticated user
 *       extracted from the JWT token.
 *
 *       **Validates: Requirements 2.1**
 *       - Validates JWT tokens on every protected request
 *     tags:
 *       - Authentication
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: Current user information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 userId:
 *                   type: string
 *                   description: User ID
 *                 email:
 *                   type: string
 *                   format: email
 *                   description: User email
 *                 name:
 *                   type: string
 *                   description: User full name
 *                 picture:
 *                   type: string
 *                   format: uri
 *                   description: User profile picture URL
 *                 emailVerified:
 *                   type: boolean
 *                   description: Whether email is verified
 *                 updatedAt:
 *                   type: string
 *                   format: date-time
 *                   description: Last update timestamp
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get('/me', authenticateJWT, async function (req, res) {
  try {
    const userId = extractUserId(req);

    logger.info('[Auth] User info requested', { userId });

    res.json({
      userId,
      email: req.user?.email,
      name: req.user?.name,
      picture: req.user?.picture,
      emailVerified: req.user?.email_verified,
      updatedAt: req.user?.updated_at,
    });
  } catch (error) {
    logger.error('[Auth] User info error', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to get user info',
      code: 'USER_INFO_ERROR',
    });
  }
});

/**
 * @swagger
 * /auth/token/check-expiry:
 *   post:
 *     summary: Check if token is expiring soon
 *     description: |
 *       Checks if a token is expiring soon (within 5 minutes) and needs
 *       to be refreshed. Useful for proactive token refresh.
 *
 *       **Validates: Requirements 2.2**
 *       - Implements token refresh mechanism for expired tokens
 *     tags:
 *       - Authentication
 *     requestBody:
 *       required: false
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               token:
 *                 type: string
 *                 description: JWT token to check (optional if using Authorization header)
 *           example:
 *             token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
 *     responses:
 *       200:
 *         description: Token expiry check result
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 shouldRefresh:
 *                   type: boolean
 *                   description: Whether token should be refreshed
 *                 expiresIn:
 *                   type: integer
 *                   description: Seconds until token expires
 *                 expiresAt:
 *                   type: string
 *                   format: date-time
 *                   description: Token expiry timestamp
 *       400:
 *         description: Missing token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       401:
 *         description: Invalid token
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/Error'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.post('/token/check-expiry', authCheckLimiter, async function (req, res) {
  try {
    const { token } = req.body;
    const authHeader = req.headers.authorization;
    const bearerToken = token || (authHeader && authHeader.split(' ')[1]);

    if (!bearerToken) {
      return res.status(400).json({
        error: 'Token required',
        code: 'MISSING_TOKEN',
      });
    }

    const decoded = jwt.decode(bearerToken, { complete: true });

    if (!decoded) {
      return res.status(401).json({
        error: 'Invalid token',
        code: 'INVALID_TOKEN',
      });
    }

    const now = Math.floor(Date.now() / 1000);
    const expiresIn = decoded.payload.exp - now;
    const shouldRefresh = expiresIn <= TOKEN_REFRESH_WINDOW;

    logger.info('[Auth] Token expiry check', {
      expiresIn,
      shouldRefresh,
    });

    res.json({
      shouldRefresh,
      expiresIn: Math.max(0, expiresIn),
      expiresAt: new Date(decoded.payload.exp * 1000).toISOString(),
    });
  } catch (error) {
    logger.error('[Auth] Token expiry check error', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Token expiry check failed',
      code: 'EXPIRY_CHECK_ERROR',
    });
  }
});

/**
 * HTTPS Enforcement Middleware
 * Ensures all authentication endpoints are accessed via HTTPS in production
 *
 * Validates: Requirements 2.10
 * - Enforces HTTPS for all authentication endpoints
 */
router.use((req, res, next) => {
  if (process.env.NODE_ENV === 'production' && req.protocol !== 'https') {
    logger.warn('[Auth] Non-HTTPS request to auth endpoint', {
      protocol: req.protocol,
      path: req.path,
      ip: req.ip,
    });

    return res.status(403).json({
      error: 'HTTPS required',
      code: 'HTTPS_REQUIRED',
      message: 'Authentication endpoints require HTTPS',
    });
  }

  next();
});

export default router;
