/**
 * User Tier Checking Middleware for CloudToLocalLLM API Backend
 *
 * Provides tier detection and feature access control for API endpoints
 * based on JWT user metadata. Implements secure tier validation with
 * comprehensive error handling and audit logging.
 *
 * @fileoverview Tier-based access control middleware
 * @version 1.0.0
 * @author CloudToLocalLLM Team
 */

import { logger } from '../utils/logger.js';

// Environment configuration
const UPGRADE_URL =
  process.env.UPGRADE_URL || 'https://app.cloudtolocalllm.online/upgrade';

// User tier definitions
export const USER_TIERS = {
  FREE: 'free',
  PREMIUM: 'premium',
  ENTERPRISE: 'enterprise',
};

// Feature definitions by tier
export const TIER_FEATURES = {
  [USER_TIERS.FREE]: {
    containerOrchestration: false,
    teamFeatures: false,
    apiAccess: false,
    prioritySupport: false,
    advancedNetworking: false,
    multipleInstances: false,
    maxConnections: 1,
    maxModels: 5,
    directTunnelOnly: true,
  },
  [USER_TIERS.PREMIUM]: {
    containerOrchestration: true,
    teamFeatures: true,
    apiAccess: true,
    prioritySupport: true,
    advancedNetworking: true,
    multipleInstances: true,
    maxConnections: 10,
    maxModels: 50,
    directTunnelOnly: false,
  },
  [USER_TIERS.ENTERPRISE]: {
    containerOrchestration: true,
    teamFeatures: true,
    apiAccess: true,
    prioritySupport: true,
    advancedNetworking: true,
    multipleInstances: true,
    maxConnections: -1, // unlimited
    maxModels: -1, // unlimited
    directTunnelOnly: false,
  },
};

/**
 * Extract user tier from JWT JWT token with comprehensive validation
 * @param {Object} user - Decoded JWT user object
 * @returns {string} User tier (free, premium, enterprise)
 * @throws {Error} If user object is malformed
 */
export function getUserTier(user) {
  // Input validation
  if (!user || typeof user !== 'object') {
    logger.debug(
      ' [TierCheck] No user object provided, defaulting to free tier',
    );
    return USER_TIERS.FREE;
  }

  // Validate user has required fields
  if (!user.sub || typeof user.sub !== 'string') {
    logger.warn(
      ' [TierCheck] Invalid user object - missing or invalid sub field',
      {
        userObject: typeof user,
        hasSub: !!user.sub,
      },
    );
    return USER_TIERS.FREE;
  }

  try {
    // Safely extract metadata with validation (Supabase and Auth0 structures)
    const userMetadata =
      user.user_metadata ||
      user['https://cloudtolocalllm.com/user_metadata'] ||
      {};
    const appMetadata =
      user.app_metadata ||
      user['https://cloudtolocalllm.com/app_metadata'] ||
      {};

    // Validate metadata objects
    if (typeof userMetadata !== 'object' || typeof appMetadata !== 'object') {
      logger.warn(' [TierCheck] Invalid metadata format in user token', {
        userId: user.sub,
        userMetadataType: typeof userMetadata,
        appMetadataType: typeof appMetadata,
      });
      return USER_TIERS.FREE;
    }

    // Check multiple possible locations for tier information (priority order)
    const tierSources = [
      userMetadata.tier,
      appMetadata.tier,
      userMetadata.subscription,
      userMetadata.plan,
      appMetadata.subscription,
      appMetadata.plan,
    ];

    let tierValue = null;
    for (const source of tierSources) {
      if (source && typeof source === 'string') {
        tierValue = source;
        break;
      }
    }

    // Validate and normalize tier value
    if (!tierValue) {
      logger.debug(
        ' [TierCheck] No tier information found, defaulting to free',
        {
          userId: user.sub,
        },
      );
      return USER_TIERS.FREE;
    }

    const normalizedTier = tierValue.toLowerCase().trim();

    // Validate against known tiers
    if (Object.values(USER_TIERS).includes(normalizedTier)) {
      logger.debug(' [TierCheck] Valid tier detected', {
        userId: user.sub,
        tier: normalizedTier,
      });
      return normalizedTier;
    } else {
      logger.warn(' [TierCheck] Unknown tier value, defaulting to free', {
        userId: user.sub,
        invalidTier: tierValue,
      });
      return USER_TIERS.FREE;
    }
  } catch (error) {
    logger.error(
      ' [TierCheck] Error extracting user tier, defaulting to free',
      {
        userId: user.sub,
        error: error.message,
        stack: error.stack,
      },
    );
    return USER_TIERS.FREE;
  }
}

/**
 * Get features available for a specific tier with validation
 * @param {string} tier - User tier
 * @returns {Object} Available features object
 * @throws {Error} If tier is invalid
 */
export function getTierFeatures(tier) {
  // Input validation
  if (!tier || typeof tier !== 'string') {
    logger.warn(' [TierCheck] Invalid tier provided to getTierFeatures', {
      tier: tier,
      type: typeof tier,
    });
    return TIER_FEATURES[USER_TIERS.FREE];
  }

  const normalizedTier = tier.toLowerCase().trim();

  // Validate tier exists
  if (!TIER_FEATURES[normalizedTier]) {
    logger.warn(
      ' [TierCheck] Unknown tier requested, returning free tier features',
      {
        requestedTier: tier,
        normalizedTier: normalizedTier,
      },
    );
    return TIER_FEATURES[USER_TIERS.FREE];
  }

  return TIER_FEATURES[normalizedTier];
}

/**
 * Check if user has access to a specific feature with validation
 * @param {Object} user - Decoded JWT user object
 * @param {string} feature - Feature name to check
 * @returns {boolean} Whether user has access to the feature
 */
export function hasFeature(user, feature) {
  // Input validation
  if (!feature || typeof feature !== 'string') {
    logger.warn(' [TierCheck] Invalid feature name provided to hasFeature', {
      feature: feature,
      type: typeof feature,
      userId: user?.sub,
    });
    return false;
  }

  try {
    const tier = getUserTier(user);
    const features = getTierFeatures(tier);

    // Check if feature exists in the features object
    if (!(feature in features)) {
      logger.warn(' [TierCheck] Unknown feature requested', {
        feature: feature,
        tier: tier,
        userId: user?.sub,
        availableFeatures: Object.keys(features),
      });
      return false;
    }

    return features[feature] === true;
  } catch (error) {
    logger.error(' [TierCheck] Error checking feature access', {
      feature: feature,
      userId: user?.sub,
      error: error.message,
    });
    return false;
  }
}

/**
 * Middleware to check if user has required tier with comprehensive validation
 * @param {string} requiredTier - Minimum required tier
 * @returns {Function} Express middleware function
 * @throws {Error} If requiredTier is invalid
 */
export function requireTier(requiredTier) {
  // Validate required tier at middleware creation time
  if (!requiredTier || typeof requiredTier !== 'string') {
    throw new Error(
      `Invalid requiredTier provided to requireTier middleware: ${requiredTier}`,
    );
  }

  const normalizedRequiredTier = requiredTier.toLowerCase().trim();
  if (!Object.values(USER_TIERS).includes(normalizedRequiredTier)) {
    throw new Error(
      `Unknown tier provided to requireTier middleware: ${requiredTier}`,
    );
  }

  return (req, res, next) => {
    try {
      // Authentication check
      if (!req.user) {
        logger.warn(' [TierCheck] Unauthenticated access attempt', {
          endpoint: req.path,
          method: req.method,
          ip: req.ip,
          userAgent: req.get('User-Agent'),
        });

        return res.status(401).json({
          error: 'Authentication required',
          code: 'AUTH_REQUIRED',
          message: 'Please authenticate to access this resource',
        });
      }

      const userTier = getUserTier(req.user);
      const tierHierarchy = [
        USER_TIERS.FREE,
        USER_TIERS.PREMIUM,
        USER_TIERS.ENTERPRISE,
      ];

      const userTierLevel = tierHierarchy.indexOf(userTier);
      const requiredTierLevel = tierHierarchy.indexOf(normalizedRequiredTier);

      // Security check - ensure valid tier levels
      if (userTierLevel === -1 || requiredTierLevel === -1) {
        logger.error(' [TierCheck] Invalid tier configuration detected', {
          userId: req.user.sub,
          userTier,
          requiredTier: normalizedRequiredTier,
          endpoint: req.path,
        });

        return res.status(500).json({
          error: 'Internal server error',
          code: 'TIER_CONFIG_ERROR',
          message: 'Tier configuration error',
        });
      }

      if (userTierLevel < requiredTierLevel) {
        logger.warn(' [TierCheck] Access denied - insufficient tier', {
          userId: req.user.sub,
          userTier,
          requiredTier: normalizedRequiredTier,
          endpoint: req.path,
          method: req.method,
          ip: req.ip,
        });

        return res.status(403).json({
          error: 'Insufficient subscription tier',
          code: 'TIER_INSUFFICIENT',
          userTier,
          requiredTier: normalizedRequiredTier,
          upgradeUrl: UPGRADE_URL,
          message: `This feature requires ${normalizedRequiredTier} tier or higher`,
        });
      }

      // Add tier information to request for downstream use
      req.userTier = userTier;
      req.tierFeatures = getTierFeatures(userTier);

      logger.debug(' [TierCheck] Tier check passed', {
        userId: req.user.sub,
        userTier,
        requiredTier: normalizedRequiredTier,
        endpoint: req.path,
      });

      next();
    } catch (error) {
      logger.error(' [TierCheck] Error in requireTier middleware', {
        userId: req.user?.sub,
        requiredTier: normalizedRequiredTier,
        endpoint: req.path,
        error: error.message,
        stack: error.stack,
      });

      return res.status(500).json({
        error: 'Internal server error',
        code: 'TIER_CHECK_ERROR',
        message: 'Error validating user tier',
      });
    }
  };
}

/**
 * Middleware to check if user has access to a specific feature
 * @param {string} feature - Feature name to check
 * @returns {Function} Express middleware function
 */
export function requireFeature(feature) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    if (!hasFeature(req.user, feature)) {
      const userTier = getUserTier(req.user);

      logger.warn(' [TierCheck] Feature access denied', {
        userId: req.user.sub,
        userTier,
        feature,
        endpoint: req.path,
      });

      return res.status(403).json({
        error: `Feature '${feature}' not available in your subscription tier`,
        code: 'FEATURE_UNAVAILABLE',
        userTier,
        feature,
        upgradeUrl: UPGRADE_URL,
      });
    }

    // Add tier information to request for downstream use
    req.userTier = getUserTier(req.user);
    req.tierFeatures = getTierFeatures(req.userTier);

    logger.debug(' [TierCheck] Feature access granted', {
      userId: req.user.sub,
      userTier: req.userTier,
      feature,
      endpoint: req.path,
    });

    next();
  };
}

/**
 * Middleware to add tier information to all authenticated requests
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {Function} next - Express next function
 */
export function addTierInfo(req, res, next) {
  if (req.user) {
    req.userTier = getUserTier(req.user);
    req.tierFeatures = getTierFeatures(req.userTier);

    logger.debug(' [TierCheck] Added tier info to request', {
      userId: req.user.sub,
      userTier: req.userTier,
    });
  }

  next();
}

/**
 * Check if user should use direct tunnel (free tier) or containers (premium+)
 * @param {Object} user - Decoded JWT user object
 * @returns {boolean} Whether user should use direct tunnel only
 */
export function shouldUseDirectTunnel(user) {
  const tier = getUserTier(user);
  const features = getTierFeatures(tier);
  return features.directTunnelOnly;
}

/**
 * Get upgrade message for a specific feature
 * @param {string} userTier - Current user tier
 * @param {string} feature - Feature name
 * @returns {string} Upgrade message
 */
export function getUpgradeMessage(userTier, feature) {
  if (userTier === USER_TIERS.FREE) {
    return `Upgrade to Premium to unlock ${feature} and other advanced features.`;
  } else if (userTier === USER_TIERS.PREMIUM) {
    return `Upgrade to Enterprise for unlimited ${feature} and priority support.`;
  }
  return 'This feature is available in your current plan.';
}

export default {
  USER_TIERS,
  TIER_FEATURES,
  getUserTier,
  getTierFeatures,
  hasFeature,
  requireTier,
  requireFeature,
  addTierInfo,
  shouldUseDirectTunnel,
  getUpgradeMessage,
};
