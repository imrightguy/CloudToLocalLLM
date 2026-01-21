/**
 * User Tier Management API Routes
 *
 * Provides user-facing endpoints for:
 * - Retrieving user tier information
 * - Checking feature availability
 * - Viewing tier upgrade options
 * - Managing tier-based preferences
 *
 * All endpoints require authentication via JWT token.
 * Tier information is extracted from JWT user metadata.
 *
 * @fileoverview User tier management endpoints
 * @version 1.0.0
 */

import express from 'express';
import { authenticateJWT } from '../middleware/auth.js';
import {
  getUserTier,
  getTierFeatures,
  hasFeature,
  USER_TIERS,
  TIER_FEATURES,
  getUpgradeMessage,
} from '../middleware/tier-check.js';
import logger from '../logger.js';

const router = express.Router();

/**
 * @swagger
 * /users/tier:
 *   get:
 *     summary: Get current user's tier information
 *     description: |
 *       Returns the current user's subscription tier and available features.
 *       Includes feature descriptions, limits, and upgrade options.
 *
 *       **Validates: Requirements 3.3**
 *       - Implements user tier management and upgrades
 *     tags:
 *       - Users
 *     security:
 *       - bearerAuth: []
 *     responses:
 *       200:
 *         description: User tier information
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 currentTier:
 *                   type: string
 *                   enum: [free, premium, enterprise]
 *                   description: Current subscription tier
 *                 features:
 *                   type: array
 *                   items:
 *                     type: object
 *                     properties:
 *                       name:
 *                         type: string
 *                       enabled:
 *                         type: boolean
 *                       description:
 *                         type: string
 *                       value:
 *                         type: [string, number, boolean]
 *                 limits:
 *                   type: object
 *                   properties:
 *                     maxConnections:
 *                       type: integer
 *                     maxModels:
 *                       type: integer
 *       401:
 *         $ref: '#/components/responses/UnauthorizedError'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
router.get('/tier', authenticateJWT, (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
        message: 'Please authenticate to access tier information',
      });
    }

    const userTier = getUserTier(req.user);
    const tierFeatures = getTierFeatures(userTier);

    logger.debug('[UserTier] Tier information requested', {
      userId: req.user.sub,
      tier: userTier,
    });

    // Build feature list with descriptions
    const featureDescriptions = {
      containerOrchestration: 'Container orchestration and management',
      teamFeatures: 'Team collaboration features',
      apiAccess: 'API access for integrations',
      prioritySupport: 'Priority support',
      advancedNetworking: 'Advanced networking capabilities',
      multipleInstances: 'Multiple concurrent instances',
      maxConnections: 'Maximum concurrent connections',
      maxModels: 'Maximum AI models',
      directTunnelOnly: 'Direct tunnel only (no containers)',
    };

    // Format features with descriptions
    const featuresWithDescriptions = Object.entries(tierFeatures).map(
      ([feature, enabled]) => ({
        name: feature,
        enabled,
        description: featureDescriptions[feature] || feature,
        value: tierFeatures[feature],
      })
    );

    // Determine upgrade path
    const tierHierarchy = [
      USER_TIERS.FREE,
      USER_TIERS.PREMIUM,
      USER_TIERS.ENTERPRISE,
    ];
    const currentTierIndex = tierHierarchy.indexOf(userTier);
    const nextTier =
      currentTierIndex < tierHierarchy.length - 1
        ? tierHierarchy[currentTierIndex + 1]
        : null;

    const response = {
      currentTier: userTier,
      features: featuresWithDescriptions,
      limits: {
        maxConnections: tierFeatures.maxConnections,
        maxModels: tierFeatures.maxModels,
      },
      capabilities: {
        containerOrchestration: tierFeatures.containerOrchestration,
        teamFeatures: tierFeatures.teamFeatures,
        apiAccess: tierFeatures.apiAccess,
        prioritySupport: tierFeatures.prioritySupport,
        advancedNetworking: tierFeatures.advancedNetworking,
        multipleInstances: tierFeatures.multipleInstances,
      },
      upgrade: nextTier
        ? {
            availableTier: nextTier,
            message: getUpgradeMessage(userTier, 'advanced features'),
            benefits: getTierFeatures(nextTier),
          }
        : null,
      timestamp: new Date().toISOString(),
    };

    res.json({
      success: true,
      data: response,
    });
  } catch (error) {
    logger.error('[UserTier] Error retrieving tier information', {
      userId: req.user?.sub,
      error: error.message,
      stack: error.stack,
    });

    res.status(500).json({
      error: 'Failed to retrieve tier information',
      code: 'TIER_RETRIEVAL_FAILED',
      message: 'An error occurred while retrieving your tier information',
    });
  }
});

/**
 * GET /api/users/tier/features
 *
 * Get list of all available features and their tier requirements
 *
 * Returns:
 * - All available features
 * - Tier requirements for each feature
 * - Current user's access to each feature
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/tier/features', authenticateJWT, (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    const userTier = getUserTier(req.user);
    const userFeatures = getTierFeatures(userTier);

    logger.debug('[UserTier] Features list requested', {
      userId: req.user.sub,
      tier: userTier,
    });

    // Build comprehensive feature matrix
    const featureMatrix = {};

    // Iterate through all tiers to build feature availability matrix
    Object.entries(TIER_FEATURES).forEach(([tier, features]) => {
      Object.entries(features).forEach(([feature, available]) => {
        if (!featureMatrix[feature]) {
          featureMatrix[feature] = {
            name: feature,
            description: '',
            availableIn: [],
            userHasAccess: false,
          };
        }

        if (available) {
          featureMatrix[feature].availableIn.push(tier);
        }

        // Check if user has access to this feature
        if (userFeatures[feature]) {
          featureMatrix[feature].userHasAccess = true;
        }
      });
    });

    // Convert to array and sort
    const features = Object.values(featureMatrix).sort((a, b) =>
      a.name.localeCompare(b.name)
    );

    res.json({
      success: true,
      data: {
        currentTier: userTier,
        features,
        summary: {
          totalFeatures: features.length,
          accessibleFeatures: features.filter((f) => f.userHasAccess).length,
          lockedFeatures: features.filter((f) => !f.userHasAccess).length,
        },
      },
    });
  } catch (error) {
    logger.error('[UserTier] Error retrieving features list', {
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to retrieve features list',
      code: 'FEATURES_RETRIEVAL_FAILED',
    });
  }
});

/**
 * GET /api/users/tier/check/:feature
 *
 * Check if user has access to a specific feature
 *
 * Path Parameters:
 * - feature: Feature name to check
 *
 * Returns:
 * - Whether user has access to the feature
 * - Current tier
 * - Minimum tier required for the feature
 * - Upgrade information if not available
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/tier/check/:feature', authenticateJWT, (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    const { feature } = req.params;

    if (!feature || typeof feature !== 'string') {
      return res.status(400).json({
        error: 'Invalid feature name',
        code: 'INVALID_FEATURE',
        message: 'Feature name must be a non-empty string',
      });
    }

    const userTier = getUserTier(req.user);
    const hasAccess = hasFeature(req.user, feature);

    logger.debug('[UserTier] Feature access check', {
      userId: req.user.sub,
      feature,
      hasAccess,
      tier: userTier,
    });

    // Find minimum tier required for this feature
    let minimumTier = null;
    const tierHierarchy = [
      USER_TIERS.FREE,
      USER_TIERS.PREMIUM,
      USER_TIERS.ENTERPRISE,
    ];

    for (const tier of tierHierarchy) {
      const tierFeatures = getTierFeatures(tier);
      if (tierFeatures[feature]) {
        minimumTier = tier;
        break;
      }
    }

    const response = {
      feature,
      userHasAccess: hasAccess,
      currentTier: userTier,
      minimumTierRequired: minimumTier,
      timestamp: new Date().toISOString(),
    };

    // Add upgrade information if user doesn't have access
    if (!hasAccess && minimumTier) {
      response.upgrade = {
        requiredTier: minimumTier,
        message: getUpgradeMessage(userTier, feature),
        upgradeUrl:
          process.env.UPGRADE_URL ||
          'https://app.cloudtolocalllm.online/upgrade',
      };
    }

    res.json({
      success: true,
      data: response,
    });
  } catch (error) {
    logger.error('[UserTier] Error checking feature access', {
      userId: req.user?.sub,
      feature: req.params.feature,
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to check feature access',
      code: 'FEATURE_CHECK_FAILED',
    });
  }
});

/**
 * GET /api/users/tier/limits
 *
 * Get tier-based limits for the current user
 *
 * Returns:
 * - Maximum connections allowed
 * - Maximum models allowed
 * - Other tier-specific limits
 *
 * Authentication: Required (JWT)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/tier/limits', authenticateJWT, (req, res) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        error: 'Authentication required',
        code: 'AUTH_REQUIRED',
      });
    }

    const userTier = getUserTier(req.user);
    const tierFeatures = getTierFeatures(userTier);

    logger.debug('[UserTier] Tier limits requested', {
      userId: req.user.sub,
      tier: userTier,
    });

    const limits = {
      tier: userTier,
      maxConnections:
        tierFeatures.maxConnections === -1
          ? 'unlimited'
          : tierFeatures.maxConnections,
      maxModels:
        tierFeatures.maxModels === -1 ? 'unlimited' : tierFeatures.maxModels,
      directTunnelOnly: tierFeatures.directTunnelOnly,
      containerOrchestration: tierFeatures.containerOrchestration,
      multipleInstances: tierFeatures.multipleInstances,
      timestamp: new Date().toISOString(),
    };

    res.json({
      success: true,
      data: limits,
    });
  } catch (error) {
    logger.error('[UserTier] Error retrieving tier limits', {
      userId: req.user?.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to retrieve tier limits',
      code: 'LIMITS_RETRIEVAL_FAILED',
    });
  }
});

/**
 * GET /api/users/tier/tiers
 *
 * Get information about all available tiers
 *
 * Returns:
 * - All available tiers
 * - Features for each tier
 * - Comparison information
 *
 * Authentication: Optional (public endpoint)
 * Rate Limit: Standard (100 req/min)
 */
router.get('/tier/tiers', (req, res) => {
  try {
    logger.debug('[UserTier] All tiers information requested');

    const tiers = Object.entries(TIER_FEATURES).map(([tierName, features]) => ({
      name: tierName,
      displayName:
        tierName.charAt(0).toUpperCase() + tierName.slice(1).toLowerCase(),
      features,
      limits: {
        maxConnections: features.maxConnections,
        maxModels: features.maxModels,
      },
    }));

    res.json({
      success: true,
      data: {
        tiers,
        tierHierarchy: [
          USER_TIERS.FREE,
          USER_TIERS.PREMIUM,
          USER_TIERS.ENTERPRISE,
        ],
      },
    });
  } catch (error) {
    logger.error('[UserTier] Error retrieving tiers information', {
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to retrieve tiers information',
      code: 'TIERS_RETRIEVAL_FAILED',
    });
  }
});

export default router;
