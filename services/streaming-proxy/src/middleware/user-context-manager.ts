/**
 * User Context Manager
 * Manages user context extraction and attachment to requests
 * Implements tier-based permissions and rate limit loading
 */

import {
  UserContext,
  UserTier,
  RateLimitConfig,
} from '../interfaces/auth-middleware';

interface RequestWithContext extends Request {
  userContext?: UserContext;
}

/**
 * User Context Manager
 * Extracts and manages user context from JWT tokens
 */
export class UserContextManager {
  private readonly contextCache: Map<string, UserContext> = new Map();
  private readonly cacheDuration = 5 * 60 * 1000; // 5 minutes

  /**
   * Extract user context from JWT payload
   */
  extractUserContext(payload: any): UserContext {
    const userId = payload.sub;
    
    // Check cache
    const cached = this.contextCache.get(userId);
    if (cached) {
      return cached;
    }

    // Extract tier
    const tier = this.extractTier(payload);

    // Extract permissions
    const permissions = this.extractPermissions(payload);

    // Get rate limit config
    const rateLimit = this.getRateLimitForTier(tier);

    const context: UserContext = {
      userId,
      tier,
      permissions,
      rateLimit,
    };

    // Cache context
    this.contextCache.set(userId, context);

    return context;
  }

  /**
   * Attach user context to request
   */
  attachContextToRequest(req: RequestWithContext, context: UserContext): void {
    req.userContext = context;
  }

  /**
   * Get user context from request
   */
  getContextFromRequest(req: RequestWithContext): UserContext | undefined {
    return req.userContext;
  }

  /**
   * Load user-specific rate limits
   */
  loadUserRateLimits(userId: string, tier: UserTier): RateLimitConfig {
    // In a production system, this might load from a database
    // For now, return tier-based defaults
    return this.getRateLimitForTier(tier);
  }

  /**
   * Check if user has permission
   */
  hasPermission(context: UserContext, permission: string): boolean {
    return context.permissions.includes(permission);
  }

  /**
   * Check if user has any of the specified permissions
   */
  hasAnyPermission(context: UserContext, permissions: string[]): boolean {
    return permissions.some(p => context.permissions.includes(p));
  }

  /**
   * Check if user has all of the specified permissions
   */
  hasAllPermissions(context: UserContext, permissions: string[]): boolean {
    return permissions.every(p => context.permissions.includes(p));
  }

  /**
   * Get tier-based feature flags
   */
  getFeatureFlags(tier: UserTier): Record<string, boolean> {
    switch (tier) {
      case UserTier.ENTERPRISE:
        return {
          advancedMetrics: true,
          prioritySupport: true,
          customIntegrations: true,
          unlimitedModels: true,
          dedicatedResources: true,
        };
      case UserTier.PREMIUM:
        return {
          advancedMetrics: true,
          prioritySupport: true,
          customIntegrations: false,
          unlimitedModels: true,
          dedicatedResources: false,
        };
      case UserTier.FREE:
      default:
        return {
          advancedMetrics: false,
          prioritySupport: false,
          customIntegrations: false,
          unlimitedModels: false,
          dedicatedResources: false,
        };
    }
  }

  /**
   * Clear context cache for user
   */
  clearUserCache(userId: string): void {
    this.contextCache.delete(userId);
  }

  /**
   * Clear all cached contexts
   */
  clearAllCache(): void {
    this.contextCache.clear();
  }

  /**
   * Extract user tier from JWT payload
   */
  private extractTier(payload: any): UserTier {
    // Check multiple possible locations for tier information
    const tier = payload['https://CloudToLocalLLM.com/tier'] || 
                 payload.tier || 
                 payload['app_metadata']?.tier ||
                 payload['user_metadata']?.tier;

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
   * Extract permissions from JWT payload
   */
  private extractPermissions(payload: any): string[] {
    // Check multiple possible locations for permissions
    const permissions = payload.permissions || 
                       payload['https://CloudToLocalLLM.com/permissions'] ||
                       payload.scope?.split(' ') ||
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

/**
 * Express middleware factory for user context
 */
export function createUserContextMiddleware(
  jwtMiddleware: any,
  contextManager: UserContextManager
) {
  return async (req: RequestWithContext, res: any, next: any) => {
    try {
      // Extract token from Authorization header
      const authHeader = req.headers.get('authorization');
      if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({ error: 'Missing or invalid authorization header' });
        return;
      }

      const token = authHeader.substring(7);

      // Validate token
      const validation = await jwtMiddleware.validateToken(token);
      if (!validation.valid) {
        res.status(401).json({ error: validation.error });
        return;
      }

      // Get user context
      const userContext = await jwtMiddleware.getUserContext(token);

      // Attach to request
      contextManager.attachContextToRequest(req, userContext);

      next();
    } catch (error) {
      console.error('User context middleware error:', error);
      res.status(500).json({ error: 'Internal server error' });
    }
  };
}

/**
 * Permission check middleware factory
 */
export function requirePermission(
  contextManager: UserContextManager,
  permission: string
) {
  return (req: RequestWithContext, res: any, next: any) => {
    const context = contextManager.getContextFromRequest(req);
    
    if (!context) {
      res.status(401).json({ error: 'User context not found' });
      return;
    }

    if (!contextManager.hasPermission(context, permission)) {
      res.status(403).json({ error: `Missing required permission: ${permission}` });
      return;
    }

    next();
  };
}

/**
 * Tier check middleware factory
 */
export function requireTier(
  contextManager: UserContextManager,
  minTier: UserTier
) {
  const tierOrder = {
    [UserTier.FREE]: 0,
    [UserTier.PREMIUM]: 1,
    [UserTier.ENTERPRISE]: 2,
  };

  return (req: RequestWithContext, res: any, next: any) => {
    const context = contextManager.getContextFromRequest(req);
    
    if (!context) {
      res.status(401).json({ error: 'User context not found' });
      return;
    }

    if (tierOrder[context.tier] < tierOrder[minTier]) {
      res.status(403).json({ 
        error: `This feature requires ${minTier} tier or higher`,
        currentTier: context.tier,
        requiredTier: minTier,
      });
      return;
    }

    next();
  };
}
