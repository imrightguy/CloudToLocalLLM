/**
 * @fileoverview Rate limit exemptions management routes
 * Provides endpoints for managing rate limit exemptions
 */

import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';
import { TunnelLogger } from '../utils/logger.js';

const router = express.Router();
router.use(authenticateJWT);
const logger = new TunnelLogger('rate-limit-exemptions-routes');

// Global exemption manager (will be injected)
let exemptionManager = null;

// Zod schemas for validation
const exemptionIdSchema = z.object({
  id: z.string().min(1),
});

const userIdSchema = z.object({
  userId: z.string().min(1),
});

const addExemptionRuleSchema = z.object({
  id: z.string().min(1),
  type: z.string().min(1),
  description: z.string().optional(),
  enabled: z.boolean().optional(),
  maxExemptionsPerUser: z.number().int().positive().optional(),
  pathPatterns: z.array(z.string()).optional(),
});

/**
 * Initialize exemption routes with manager
 * @param {RateLimitExemptionManager} manager - Exemption manager instance
 */
export function initializeExemptionRoutes(manager) {
  exemptionManager = manager;
}

/**
 * GET /api/admin/rate-limit-exemptions
 * Get all exemption rules
 */
router.get('/', (req, res) => {
  try {
    if (!exemptionManager) {
      return res.status(503).json({
        code: 'EXEMPTION_MANAGER_NOT_INITIALIZED',
        message: 'Exemption manager not initialized',
      });
    }

    const rules = exemptionManager.getRules();
    const stats = exemptionManager.getStatistics();

    res.json({
      success: true,
      data: {
        rules,
        statistics: stats,
      },
    });
  } catch (error) {
    logger.error('Error retrieving exemption rules', error);
    res.status(500).json({
      code: 'EXEMPTION_RETRIEVAL_ERROR',
      message: 'Failed to retrieve exemption rules',
      error: error.message,
    });
  }
});

/**
 * POST /api/admin/rate-limit-exemptions
 * Add a new exemption rule
 */
router.post('/', validateSchema({ body: addExemptionRuleSchema }), (req, res) => {
  try {
    if (!exemptionManager) {
      return res.status(503).json({
        code: 'EXEMPTION_MANAGER_NOT_INITIALIZED',
        message: 'Exemption manager not initialized',
      });
    }

    const { id, type, description, enabled, maxExemptionsPerUser, pathPatterns } = req.body;

    // Validate type
    const validTypes = Object.values(exemptionManager.config.exemptionTypes);
    if (!validTypes.includes(type)) {
      return res.status(400).json({
        code: 'INVALID_EXEMPTION_TYPE',
        message: `Invalid exemption type. Valid types: ${validTypes.join(', ')}`,
      });
    }
    const matcher = (request) => {
      return pathPatterns.some((pattern) => {
        if (pattern.startsWith('/')) {
          return request.path === pattern || request.path.startsWith(pattern);
        }
        return false;
      });
    };

    exemptionManager.addRule(id, type, matcher, {
      description: description || '',
      enabled: enabled !== false,
      maxExemptionsPerUser: maxExemptionsPerUser || null,
    });

    logger.info('Added exemption rule via API', {
      ruleId: id,
      type,
      userId: req.userId,
    });

    res.status(201).json({
      success: true,
      message: 'Exemption rule added successfully',
      data: {
        id,
        type,
        description,
        enabled: enabled !== false,
      },
    });
  } catch (error) {
    logger.error('Error adding exemption rule', error);
    res.status(500).json({
      code: 'EXEMPTION_ADD_ERROR',
      message: 'Failed to add exemption rule',
      error: error.message,
    });
  }
});

/**
 * PATCH /api/admin/rate-limit-exemptions/:id/enable
 * Enable an exemption rule
 */
router.patch('/:id/enable', validateSchema({ params: exemptionIdSchema }), (req, res) => {
  try {
    if (!exemptionManager) {
      return res.status(503).json({
        code: 'EXEMPTION_MANAGER_NOT_INITIALIZED',
        message: 'Exemption manager not initialized',
      });
    }

    const { id } = req.params;

    exemptionManager.enableRule(id);

    logger.info('Enabled exemption rule via API', {
      ruleId: id,
      userId: req.userId,
    });

    res.json({
      success: true,
      message: 'Exemption rule enabled successfully',
      data: { id, enabled: true },
    });
  } catch (error) {
    logger.error('Error enabling exemption rule', error);
    res.status(500).json({
      code: 'EXEMPTION_ENABLE_ERROR',
      message: 'Failed to enable exemption rule',
      error: error.message,
    });
  }
});

/**
 * PATCH /api/admin/rate-limit-exemptions/:id/disable
 * Disable an exemption rule
 */
router.patch('/:id/disable', validateSchema({ params: exemptionIdSchema }), (req, res) => {
  try {
    if (!exemptionManager) {
      return res.status(503).json({
        code: 'EXEMPTION_MANAGER_NOT_INITIALIZED',
        message: 'Exemption manager not initialized',
      });
    }

    const { id } = req.params;

    exemptionManager.disableRule(id);

    logger.info('Disabled exemption rule via API', {
      ruleId: id,
      userId: req.userId,
    });

    res.json({
      success: true,
      message: 'Exemption rule disabled successfully',
      data: { id, enabled: false },
    });
  } catch (error) {
    logger.error('Error disabling exemption rule', error);
    res.status(500).json({
      code: 'EXEMPTION_DISABLE_ERROR',
      message: 'Failed to disable exemption rule',
      error: error.message,
    });
  }
});

/**
 * DELETE /api/admin/rate-limit-exemptions/:id
 * Remove an exemption rule
 */
router.delete('/:id', validateSchema({ params: exemptionIdSchema }), (req, res) => {
  try {
    if (!exemptionManager) {
      return res.status(503).json({
        code: 'EXEMPTION_MANAGER_NOT_INITIALIZED',
        message: 'Exemption manager not initialized',
      });
    }

    const { id } = req.params;

    exemptionManager.removeRule(id);

    logger.info('Removed exemption rule via API', {
      ruleId: id,
      userId: req.userId,
    });

    res.json({
      success: true,
      message: 'Exemption rule removed successfully',
      data: { id },
    });
  } catch (error) {
    logger.error('Error removing exemption rule', error);
    res.status(500).json({
      code: 'EXEMPTION_REMOVE_ERROR',
      message: 'Failed to remove exemption rule',
      error: error.message,
    });
  }
});

/**
 * POST /api/admin/rate-limit-exemptions/reset/user/:userId
 * Reset exemption counts for a user
 */
router.post('/reset/user/:userId', validateSchema({ params: userIdSchema }), (req, res) => {
  try {
    if (!exemptionManager) {
      return res.status(503).json({
        code: 'EXEMPTION_MANAGER_NOT_INITIALIZED',
        message: 'Exemption manager not initialized',
      });
    }

    const { userId } = req.params;

    exemptionManager.resetUserExemptions(userId);

    logger.info('Reset exemption counts for user via API', {
      targetUserId: userId,
      adminUserId: req.userId,
    });

    res.json({
      success: true,
      message: 'Exemption counts reset for user',
      data: { userId },
    });
  } catch (error) {
    logger.error('Error resetting user exemptions', error);
    res.status(500).json({
      code: 'EXEMPTION_RESET_ERROR',
      message: 'Failed to reset exemption counts',
      error: error.message,
    });
  }
});

/**
 * POST /api/admin/rate-limit-exemptions/reset/all
 * Reset all exemption counts
 */
router.post('/reset/all', (req, res) => {
  try {
    if (!exemptionManager) {
      return res.status(503).json({
        code: 'EXEMPTION_MANAGER_NOT_INITIALIZED',
        message: 'Exemption manager not initialized',
      });
    }

    exemptionManager.resetAllExemptions();

    logger.info('Reset all exemption counts via API', {
      adminUserId: req.userId,
    });

    res.json({
      success: true,
      message: 'All exemption counts reset successfully',
    });
  } catch (error) {
    logger.error('Error resetting all exemptions', error);
    res.status(500).json({
      code: 'EXEMPTION_RESET_ERROR',
      message: 'Failed to reset all exemption counts',
      error: error.message,
    });
  }
});

export default router;
