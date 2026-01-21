/**
 * @fileoverview Comprehensive JWT token validation middleware
 * Provides enhanced JWT validation with proper expiration handling, token refresh, and security checks
 */

import jwt from 'jsonwebtoken';
import {
  TunnelLogger,
  ERROR_CODES,
  ErrorResponseBuilder,
} from '../utils/logger.js';
import { AuthService } from '../auth/auth-service.js';

/**
 * JWT validation configuration
 */
const DEFAULT_CONFIG = {
  // Token validation settings
  clockTolerance: 30, // seconds of clock skew tolerance
  maxAge: '1h', // maximum token age

  // Refresh settings
  refreshThreshold: 5 * 60, // seconds before expiry to suggest refresh (5 minutes)

  // Security settings
  requireAudience: true,
  requireIssuer: true,
  requireSubject: true,

  // Rate limiting for token validation
  maxValidationAttempts: 10,
  validationWindowMs: 60 * 1000, // 1 minute

  // Caching
  enableCaching: true,
  cacheMaxAge: 5 * 60 * 1000, // 5 minutes
  cacheMaxSize: 1000,
};

/**
 * Token validation cache entry
 */
class TokenCacheEntry {
  constructor(userId, claims, expiresAt) {
    this.userId = userId;
    this.claims = claims;
    this.expiresAt = expiresAt;
    this.createdAt = new Date();
    this.accessCount = 1;
    this.lastAccessed = new Date();
  }

  /**
   * Check if cache entry is still valid
   * @param {number} maxAge - Maximum cache age in milliseconds
   * @returns {boolean} True if valid
   */
  isValid(maxAge) {
    const now = new Date();
    const cacheAge = now.getTime() - this.createdAt.getTime();
    const tokenExpired = now >= this.expiresAt;

    return cacheAge < maxAge && !tokenExpired;
  }

  /**
   * Access the cache entry (update stats)
   */
  access() {
    this.accessCount++;
    this.lastAccessed = new Date();
  }
}

/**
 * Validation attempt tracker for rate limiting
 */
class ValidationAttemptTracker {
  constructor() {
    this.attempts = [];
  }

  /**
   * Add validation attempt
   * @param {Date} timestamp - Attempt timestamp
   */
  addAttempt(timestamp = new Date()) {
    this.attempts.push(timestamp);
  }

  /**
   * Get attempt count within window
   * @param {number} windowMs - Window size in milliseconds
   * @returns {number} Attempt count
   */
  getAttemptCount(windowMs) {
    const cutoff = new Date(Date.now() - windowMs);
    this.attempts = this.attempts.filter((timestamp) => timestamp > cutoff);
    return this.attempts.length;
  }
}

/**
 * Comprehensive JWT validator class
 */
export class JWTValidator {
  constructor(config = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.logger = new TunnelLogger('jwt-validator');

    // Token cache
    this.tokenCache = new Map();
    this.cacheStats = {
      hits: 0,
      misses: 0,
      evictions: 0,
      totalValidations: 0,
    };

    // Validation attempt tracking
    this.validationAttempts = new Map(); // IP -> ValidationAttemptTracker

    // AuthService for JWT validation (replaces JWKS clients)
    this.authServices = new Map();

    // Start cache cleanup interval
    this.cacheCleanupInterval = setInterval(() => {
      this.cleanupCache();
    }, 60 * 1000); // Every minute

    this.logger.info('JWT validator initialized', {
      clockTolerance: this.config.clockTolerance,
      maxAge: this.config.maxAge,
      refreshThreshold: this.config.refreshThreshold,
      enableCaching: this.config.enableCaching,
      cacheMaxSize: this.config.cacheMaxSize,
    });
  }

  /**
   * Get or create AuthService
   * @returns {AuthService} AuthService instance
   */
  getAuthService() {
    const key = 'default';
    if (!this.authServices.has(key)) {
      const authService = new AuthService({
        AUTH_ISSUER_URL:
          process.env.AUTH0_ISSUER_URL || process.env.AUTH_ISSUER_URL,
        AUTH_AUDIENCE: process.env.AUTH0_AUDIENCE || process.env.AUTH_AUDIENCE,
      });

      this.authServices.set(key, authService);
      this.logger.debug('Created provider-agnostic AuthService');
    }

    return this.authServices.get(key);
  }

  /**
   * Check validation rate limit for IP
   * @param {string} ip - Client IP address
   * @returns {boolean} True if within rate limit
   */
  checkValidationRateLimit(ip) {
    if (!this.validationAttempts.has(ip)) {
      this.validationAttempts.set(ip, new ValidationAttemptTracker());
    }

    const tracker = this.validationAttempts.get(ip);
    const attemptCount = tracker.getAttemptCount(
      this.config.validationWindowMs,
    );

    if (attemptCount >= this.config.maxValidationAttempts) {
      this.logger.logSecurity('jwt_validation_rate_limit_exceeded', null, {
        ip,
        attemptCount,
        maxAttempts: this.config.maxValidationAttempts,
        windowMs: this.config.validationWindowMs,
      });
      return false;
    }

    tracker.addAttempt();
    return true;
  }

  /**
   * Get token from cache
   * @param {string} tokenHash - Token hash
   * @returns {TokenCacheEntry|null} Cache entry or null
   */
  getCachedToken(tokenHash) {
    if (!this.config.enableCaching) {
      return null;
    }

    const entry = this.tokenCache.get(tokenHash);
    if (!entry) {
      this.cacheStats.misses++;
      return null;
    }

    if (!entry.isValid(this.config.cacheMaxAge)) {
      this.tokenCache.delete(tokenHash);
      this.cacheStats.evictions++;
      this.cacheStats.misses++;
      return null;
    }

    entry.access();
    this.cacheStats.hits++;
    return entry;
  }

  /**
   * Cache validated token
   * @param {string} tokenHash - Token hash
   * @param {string} userId - User ID
   * @param {Object} claims - Token claims
   * @param {Date} expiresAt - Token expiration
   */
  cacheToken(tokenHash, userId, claims, expiresAt) {
    if (!this.config.enableCaching) {
      return;
    }

    // Check cache size limit
    if (this.tokenCache.size >= this.config.cacheMaxSize) {
      // Remove oldest entries (LRU-style)
      const entries = Array.from(this.tokenCache.entries());
      entries.sort((a, b) => a[1].lastAccessed - b[1].lastAccessed);

      const toRemove = Math.ceil(this.config.cacheMaxSize * 0.1); // Remove 10%
      for (let i = 0; i < toRemove; i++) {
        this.tokenCache.delete(entries[i][0]);
        this.cacheStats.evictions++;
      }
    }

    const entry = new TokenCacheEntry(userId, claims, expiresAt);
    this.tokenCache.set(tokenHash, entry);
  }

  /**
   * Create token hash for caching
   * @param {string} token - JWT token
   * @returns {string} Token hash
   */
  createTokenHash(token) {
    const crypto = require('crypto');
    return crypto.createHash('sha256').update(token).digest('hex');
  }

  /**
   * Validate JWT token with comprehensive checks
   * @param {string} token - JWT token
   * @param {Object} options - Validation options
   * @param {string} options.audience - Expected audience
   * @param {string} options.issuer - Expected issuer
   * @param {string} options.domain - JWT domain
   * @param {string} [options.ip] - Client IP for rate limiting
   * @returns {Promise<Object>} Validation result
   */
  async validateToken(token, options = {}) {
    const { ip } = options;
    const correlationId = this.logger.generateCorrelationId();

    this.cacheStats.totalValidations++;

    try {
      // Check validation rate limit
      if (ip && !this.checkValidationRateLimit(ip)) {
        throw new Error('Validation rate limit exceeded');
      }

      // Check token cache first
      const tokenHash = this.createTokenHash(token);
      const cachedEntry = this.getCachedToken(tokenHash);

      if (cachedEntry) {
        this.logger.debug('Token validation cache hit', {
          correlationId,
          userId: cachedEntry.userId,
          cacheAge: Date.now() - cachedEntry.createdAt.getTime(),
          accessCount: cachedEntry.accessCount,
        });

        return {
          valid: true,
          userId: cachedEntry.userId,
          claims: cachedEntry.claims,
          cached: true,
          expiresAt: cachedEntry.expiresAt,
          needsRefresh: this.checkNeedsRefresh(cachedEntry.expiresAt),
        };
      }

      // Decode token header to get key ID
      const decoded = jwt.decode(token, { complete: true });
      if (!decoded || !decoded.header || !decoded.header.kid) {
        throw new Error('Invalid token format - missing key ID');
      }

      // Validate token structure
      if (!decoded.payload) {
        throw new Error('Invalid token format - missing payload');
      }

      // Verify token using AuthService
      const authService = this.getAuthService();
      const verified = await authService.validateToken(token);

      // Additional security checks
      if (this.config.requireSubject && !verified.sub) {
        throw new Error('Token missing required subject claim');
      }

      // Check for suspicious claims
      this.validateTokenClaims(verified, correlationId);

      // Calculate expiration
      const expiresAt = new Date(verified.exp * 1000);
      const needsRefresh = this.checkNeedsRefresh(expiresAt);

      // Cache the validated token
      this.cacheToken(tokenHash, verified.sub, verified, expiresAt);

      this.logger.debug('Token validation successful', {
        correlationId,
        userId: verified.sub,
        expiresAt,
        needsRefresh,
        audience: verified.aud,
        issuer: verified.iss,
      });

      return {
        valid: true,
        userId: verified.sub,
        claims: verified,
        cached: false,
        expiresAt,
        needsRefresh,
      };
    } catch (error) {
      this.logger.logSecurity('jwt_validation_failed', null, {
        correlationId,
        error: error.message,
        errorName: error.name,
        ip,
      });

      // Categorize error for better handling
      let errorCode = ERROR_CODES.AUTH_TOKEN_INVALID;
      let statusCode = 403;

      if (error.name === 'TokenExpiredError') {
        errorCode = ERROR_CODES.AUTH_TOKEN_EXPIRED;
        statusCode = 401;
      } else if (error.name === 'JsonWebTokenError') {
        errorCode = ERROR_CODES.AUTH_TOKEN_INVALID;
        statusCode = 403;
      } else if (error.name === 'NotBeforeError') {
        errorCode = ERROR_CODES.AUTH_TOKEN_INVALID;
        statusCode = 403;
      } else if (error.message.includes('rate limit')) {
        errorCode = ERROR_CODES.RATE_LIMIT_EXCEEDED || 'RATE_LIMIT_EXCEEDED';
        statusCode = 429;
      }

      return {
        valid: false,
        error: error.message,
        errorCode,
        statusCode,
        correlationId,
      };
    }
  }

  /**
   * Validate token claims for suspicious content
   * @param {Object} claims - Token claims
   * @param {string} correlationId - Correlation ID
   */
  validateTokenClaims(claims, correlationId) {
    // Check for required claims
    const requiredClaims = ['sub', 'iat', 'exp'];
    for (const claim of requiredClaims) {
      if (!claims[claim]) {
        throw new Error(`Missing required claim: ${claim}`);
      }
    }

    // Check token age
    const now = Math.floor(Date.now() / 1000);
    const tokenAge = now - claims.iat;
    const maxTokenAge = 24 * 60 * 60; // 24 hours

    if (tokenAge > maxTokenAge) {
      this.logger.logSecurity('suspicious_token_age', claims.sub, {
        correlationId,
        tokenAge,
        maxTokenAge,
        issuedAt: new Date(claims.iat * 1000),
      });
    }

    // Check for suspicious scopes
    if (claims.scope) {
      const scopes = claims.scope.split(' ');
      const suspiciousScopes = ['admin', 'root', 'superuser', 'system'];
      const foundSuspicious = scopes.filter((scope) =>
        suspiciousScopes.some((sus) => scope.toLowerCase().includes(sus)),
      );

      if (foundSuspicious.length > 0) {
        this.logger.logSecurity('suspicious_token_scopes', claims.sub, {
          correlationId,
          suspiciousScopes: foundSuspicious,
          allScopes: scopes,
        });
      }
    }

    // Check for unusual claims
    const standardClaims = [
      'sub',
      'aud',
      'iss',
      'exp',
      'iat',
      'nbf',
      'jti',
      'scope',
      'email',
      'email_verified',
      'name',
      'picture',
      'nickname',
    ];

    const customClaims = Object.keys(claims).filter(
      (claim) =>
        !standardClaims.includes(claim) && !claim.startsWith('https://'),
    );

    if (customClaims.length > 0) {
      this.logger.debug('Token contains custom claims', {
        correlationId,
        userId: claims.sub,
        customClaims,
      });
    }
  }

  /**
   * Check if token needs refresh
   * @param {Date} expiresAt - Token expiration date
   * @returns {boolean} True if needs refresh
   */
  checkNeedsRefresh(expiresAt) {
    const now = new Date();
    const timeUntilExpiry = expiresAt.getTime() - now.getTime();
    const refreshThresholdMs = this.config.refreshThreshold * 1000;

    return timeUntilExpiry <= refreshThresholdMs;
  }

  /**
   * Clean up expired cache entries and old validation attempts
   */
  cleanupCache() {
    let removedEntries = 0;
    let removedAttempts = 0;

    // Clean up token cache
    for (const [tokenHash, entry] of this.tokenCache.entries()) {
      if (!entry.isValid(this.config.cacheMaxAge)) {
        this.tokenCache.delete(tokenHash);
        removedEntries++;
        this.cacheStats.evictions++;
      }
    }

    // Clean up validation attempts
    const cutoff = new Date(Date.now() - this.config.validationWindowMs);
    for (const [ip, tracker] of this.validationAttempts.entries()) {
      tracker.attempts = tracker.attempts.filter(
        (timestamp) => timestamp > cutoff,
      );

      if (tracker.attempts.length === 0) {
        this.validationAttempts.delete(ip);
        removedAttempts++;
      }
    }

    if (removedEntries > 0 || removedAttempts > 0) {
      this.logger.debug('Cache cleanup completed', {
        removedCacheEntries: removedEntries,
        removedAttemptTrackers: removedAttempts,
        activeCacheEntries: this.tokenCache.size,
        activeAttemptTrackers: this.validationAttempts.size,
      });
    }
  }

  /**
   * Get validation statistics
   * @returns {Object} Statistics
   */
  getStats() {
    const cacheHitRate =
      this.cacheStats.totalValidations > 0
        ? (
            (this.cacheStats.hits / this.cacheStats.totalValidations) *
            100
          ).toFixed(2)
        : 0;

    return {
      cache: {
        ...this.cacheStats,
        hitRate: `${cacheHitRate}%`,
        size: this.tokenCache.size,
        maxSize: this.config.cacheMaxSize,
      },
      validation: {
        activeAttemptTrackers: this.validationAttempts.size,
        maxAttemptsPerWindow: this.config.maxValidationAttempts,
        windowMs: this.config.validationWindowMs,
      },
      authServices: {
        count: this.authServices.size,
        keys: Array.from(this.authServices.keys()),
      },
    };
  }

  /**
   * Destroy the validator and clean up resources
   */
  destroy() {
    if (this.cacheCleanupInterval) {
      clearInterval(this.cacheCleanupInterval);
      this.cacheCleanupInterval = null;
    }

    this.tokenCache.clear();
    this.validationAttempts.clear();
    this.authServices.clear();

    this.logger.info('JWT validator destroyed');
  }
}

/**
 * Create Express middleware for comprehensive JWT validation
 * @param {Object} config - Validator configuration
 * @param {string} config.domain - JWT domain
 * @param {string} config.audience - JWT audience
 * @returns {Function} Express middleware
 */
export function createJWTValidationMiddleware(config = {}) {
  const validator = new JWTValidator(config);

  return async (req, res, next) => {
    const correlationId = validator.logger.generateCorrelationId();
    req.correlationId = correlationId;

    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      const errorResponse = ErrorResponseBuilder.authenticationError(
        'Authorization header with Bearer token is required',
        ERROR_CODES.AUTH_TOKEN_MISSING,
      );

      validator.logger.logSecurity('auth_token_missing', null, {
        correlationId,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        path: req.path,
      });

      return res.status(401).json(errorResponse);
    }

    try {
      const result = await validator.validateToken(token, {
        ip: req.ip,
      });

      if (!result.valid) {
        // Log authentication failure to audit logger if available
        if (req.auditLogger) {
          req.auditLogger.logAuthFailure({
            correlationId: result.correlationId,
            ip: req.ip,
            userAgent: req.get('User-Agent'),
            path: req.path,
            method: req.method,
            authMethod: 'jwt',
            tokenType: 'bearer',
            errorCode: result.errorCode,
            errorMessage: result.error,
            tlsVersion: req.socket?.getProtocol?.() || 'unknown',
          });
        }

        const errorResponse = ErrorResponseBuilder.createErrorResponse(
          result.errorCode,
          result.error,
          result.statusCode,
        );

        return res.status(result.statusCode).json(errorResponse);
      }

      // Attach user info to request
      req.user = result.claims;
      req.userId = result.userId;
      req.tokenInfo = {
        expiresAt: result.expiresAt,
        needsRefresh: result.needsRefresh,
        cached: result.cached,
      };

      // Add refresh warning header if needed
      if (result.needsRefresh) {
        res.set('X-Token-Refresh-Suggested', 'true');
        res.set('X-Token-Expires-At', result.expiresAt.toISOString());
      }

      // Log successful authentication to audit logger if available
      if (req.auditLogger) {
        req.auditLogger.logAuthSuccess({
          correlationId,
          userId: result.userId,
          userEmail: result.claims.email,
          ip: req.ip,
          userAgent: req.get('User-Agent'),
          path: req.path,
          method: req.method,
          authMethod: 'jwt',
          tokenType: 'bearer',
          tlsVersion: req.socket?.getProtocol?.() || 'unknown',
          cached: result.cached,
          needsRefresh: result.needsRefresh,
        });
      }

      validator.logger.debug('JWT validation middleware successful', {
        correlationId,
        userId: result.userId,
        cached: result.cached,
        needsRefresh: result.needsRefresh,
      });

      next();
    } catch (error) {
      validator.logger.error('JWT validation middleware error', error, {
        correlationId,
        ip: req.ip,
        path: req.path,
      });

      const errorResponse = ErrorResponseBuilder.internalServerError(
        'Token validation failed',
        ERROR_CODES.INTERNAL_SERVER_ERROR,
      );

      res.status(500).json(errorResponse);
    }
  };
}

export default JWTValidator;
