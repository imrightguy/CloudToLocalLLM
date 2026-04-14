/**
 * JWT Validation Middleware Implementation
 * Integrates with Supabase JWKS for token validation (RS256)
 * Implements caching and distinguishes between expired and invalid tokens
 */

import {
  AuthMiddleware,
  TokenValidationResult,
  UserContext,
  UserTier,
  RateLimitConfig,
  AuthEvent,
} from '../interfaces/auth-middleware';
import jwt from 'jsonwebtoken';
import { JWTValidator } from './jwt-validator.interface';

import { ConsoleLogger } from '../utils/logger';

interface JWTPayload {
  sub: string;
  iss: string;
  aud: string | string[];
  exp: number;
  iat: number;
  [key: string]: any;
}

interface CachedValidation {
  result: TokenValidationResult;
  cachedAt: Date;
}

/**
 * JWT Validation Middleware with Strategy Pattern
 */
export class JWTValidationMiddleware implements AuthMiddleware {
  private readonly validator: JWTValidator;
  private readonly validationCache: Map<string, CachedValidation> = new Map();
  private readonly cacheDuration = 5 * 60 * 1000; // 5 minutes
  private readonly logger = new ConsoleLogger('JWTValidationMiddleware');

  constructor(validator: JWTValidator) {
    this.validator = validator;
  }

  /**
   * Validate JWT token with caching
   */
  async validateToken(token: string): Promise<TokenValidationResult> {
    // Check cache first
    const cached = this.validationCache.get(token);
    if (cached && Date.now() - cached.cachedAt.getTime() < this.cacheDuration) {
      return cached.result;
    }

    const result = await this.validator.validateToken(token);

    // Cache the result
    if (result.valid || result.error === 'Token expired') {
      // Optional: decide if you want to cache expired tokens
    }

    this.cacheValidation(token, result);
    return result;
  }

  /**
   * Refresh expired token (placeholder - actual implementation depends on Auth0 setup)
   */
  async refreshToken(token: string): Promise<string> {
    // This would typically involve calling Auth0's token refresh endpoint
    // For now, throw an error indicating the client should re-authenticate
    this.logger.warn('Token refresh requested - returning original token for re-authentication');
    // Auth0 typically uses refresh_token grant type for token refresh
    // This requires storing refresh_token during initial authentication
    // For now, return the original token and let client handle re-auth
    return token;
  }

  /**
   * Get user context from validated token
   */
  async getUserContext(token: string): Promise<UserContext> {
    const validation = await this.validateToken(token);

    if (!validation.valid || !validation.userId) {
      throw new Error('Invalid token - cannot extract user context');
    }

    const decoded = jwt.decode(token) as JWTPayload;
    if (!decoded) {
      throw new Error('Failed to decode token');
    }

    // Extract user tier from token claims
    const tier = this.extractUserTier(decoded);

    // Extract permissions
    const permissions = this.extractPermissions(decoded);

    // Get rate limit config based on tier
    const rateLimit = this.getRateLimitForTier(tier);

    return {
      userId: validation.userId,
      tier,
      permissions,
      rateLimit,
    };
  }

  /**
   * Log authentication attempt
   */
  logAuthAttempt(userId: string, success: boolean, reason?: string): void {
    const logDetails = {
      userId,
      success,
      reason,
      type: 'auth_attempt',
    };

    this.logger.info('Auth attempt', logDetails);
  }

  /**
   * Log authentication event
   */
  logAuthEvent(event: AuthEvent): void {
    const logDetails = {
      userId: event.userId,
      eventType: event.eventType,
      metadata: event.metadata,
      type: 'auth_event',
    };

    this.logger.info('Auth event', logDetails);
  }

  /**
   * Cache validation result
   */
  private cacheValidation(token: string, result: TokenValidationResult): void {
    this.validationCache.set(token, {
      result,
      cachedAt: new Date(),
    });

    // Clean up old cache entries periodically
    if (this.validationCache.size > 1000) {
      this.cleanupCache();
    }
  }

  /**
   * Clean up expired cache entries
   */
  private cleanupCache(): void {
    const now = Date.now();
    for (const [token, cached] of this.validationCache.entries()) {
      if (now - cached.cachedAt.getTime() > this.cacheDuration) {
        this.validationCache.delete(token);
      }
    }
  }

  /**
   * Extract user tier from token payload
   */
  private extractUserTier(payload: JWTPayload): UserTier {
    // Check for tier in custom claims
    const tier =
      payload['https://CloudToLocalLLM.com/tier'] ||
      payload.tier ||
      payload['app_metadata']?.tier;

    switch (tier?.toLowerCase()) {
      case 'premium':
        return UserTier.PREMIUM;
      case 'enterprise':
        return UserTier.ENTERPRISE;
      default:
        return UserTier.FREE;
    }
  }

  /**
   * Extract permissions from token payload
   */
  private extractPermissions(payload: JWTPayload): string[] {
    const permissions =
      payload.permissions ||
      payload['https://CloudToLocalLLM.com/permissions'] ||
      [];

    return Array.isArray(permissions) ? permissions : [];
  }

  /**
   * Get rate limit configuration for user tier
   */
  private getRateLimitForTier(tier: UserTier): RateLimitConfig {
    switch (tier) {
      case UserTier.ENTERPRISE:
        return {
          requestsPerMinute: 1000,
          maxConcurrentConnections: 10,
          maxQueueSize: 500,
        };
      case UserTier.PREMIUM:
        return {
          requestsPerMinute: 300,
          maxConcurrentConnections: 5,
          maxQueueSize: 200,
        };
      case UserTier.FREE:
      default:
        return {
          requestsPerMinute: 100,
          maxConcurrentConnections: 3,
          maxQueueSize: 100,
        };
    }
  }
}
