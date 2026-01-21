/**
 * @fileoverview Rate limit exemptions middleware
 * Provides mechanism to exempt critical operations from rate limiting
 */

import { TunnelLogger } from '../utils/logger.js';
import { rateLimitMetricsService } from '../services/rate-limit-metrics-service.js';

/**
 * Rate limit exemption configuration
 */
const DEFAULT_EXEMPTION_CONFIG = {
  // Enable/disable exemptions globally
  enabled: true,

  // Exemption types
  exemptionTypes: {
    CRITICAL_OPERATION: 'critical_operation',
    ADMIN_OPERATION: 'admin_operation',
    HEALTH_CHECK: 'health_check',
    AUTHENTICATION: 'authentication',
    EMERGENCY: 'emergency',
  },

  // Logging
  logExemptions: true,
  logExemptionValidation: true,
};

/**
 * Exemption rule definition
 */
class ExemptionRule {
  constructor(id, type, matcher, options = {}) {
    this.id = id;
    this.type = type;
    this.matcher = matcher; // Function that returns true if request matches
    this.options = options;
    this.createdAt = new Date();
    this.enabled = options.enabled !== false;
    this.description = options.description || '';
    this.maxExemptionsPerUser = options.maxExemptionsPerUser || null; // null = unlimited
    this.exemptionCount = new Map(); // userId -> count
  }

  /**
   * Check if request matches this exemption rule
   * @param {Object} req - Express request object
   * @returns {boolean} True if request matches
   */
  matches(req) {
    if (!this.enabled) {
      return false;
    }

    try {
      return this.matcher(req);
    } catch {
      // If matcher throws, don't exempt
      return false;
    }
  }

  /**
   * Check if user has exceeded exemption quota
   * @param {string} userId - User ID
   * @returns {boolean} True if user can still use exemptions
   */
  canExempt(userId) {
    if (!this.maxExemptionsPerUser) {
      return true; // Unlimited
    }

    const count = this.exemptionCount.get(userId) || 0;
    return count < this.maxExemptionsPerUser;
  }

  /**
   * Record an exemption for a user
   * @param {string} userId - User ID
   */
  recordExemption(userId) {
    if (!this.maxExemptionsPerUser) {
      return; // Don't track unlimited exemptions
    }

    const count = this.exemptionCount.get(userId) || 0;
    this.exemptionCount.set(userId, count + 1);
  }

  /**
   * Reset exemption count for a user
   * @param {string} userId - User ID
   */
  resetExemptionCount(userId) {
    this.exemptionCount.delete(userId);
  }

  /**
   * Get exemption count for a user
   * @param {string} userId - User ID
   * @returns {number} Exemption count
   */
  getExemptionCount(userId) {
    return this.exemptionCount.get(userId) || 0;
  }
}

/**
 * Rate limit exemption manager
 */
export class RateLimitExemptionManager {
  constructor(config = {}) {
    this.config = { ...DEFAULT_EXEMPTION_CONFIG, ...config };
    this.rules = new Map();
    this.logger = new TunnelLogger('rate-limit-exemptions');

    // Initialize default exemption rules
    this.initializeDefaultRules();

    this.logger.info('Rate limit exemption manager initialized', {
      enabled: this.config.enabled,
      exemptionTypes: Object.keys(this.config.exemptionTypes),
    });
  }

  /**
   * Initialize default exemption rules
   */
  initializeDefaultRules() {
    // Health check endpoints are always exempt
    this.addRule(
      'health-check',
      this.config.exemptionTypes.HEALTH_CHECK,
      (req) => {
        return (
          req.path === '/health' ||
          req.path === '/api/health' ||
          req.path === '/db/health' ||
          req.path === '/api/db/health'
        );
      },
      {
        description: 'Health check endpoints',
        enabled: true,
      },
    );

    // Authentication endpoints are exempt (login, token refresh)
    this.addRule(
      'authentication',
      this.config.exemptionTypes.AUTHENTICATION,
      (req) => {
        return (
          req.path === '/auth/login' ||
          req.path === '/api/auth/login' ||
          req.path === '/auth/refresh' ||
          req.path === '/api/auth/refresh' ||
          req.path === '/auth/logout' ||
          req.path === '/api/auth/logout' ||
          req.path === '/auth/callback' ||
          req.path === '/api/auth/callback'
        );
      },
      {
        description: 'Authentication endpoints',
        enabled: true,
      },
    );

    // Admin operations are exempt (with RBAC validation)
    this.addRule(
      'admin-operations',
      this.config.exemptionTypes.ADMIN_OPERATION,
      (req) => {
        // Only exempt if user has admin role
        return (
          (req.path.startsWith('/admin') ||
            req.path.startsWith('/api/admin')) &&
          req.userRole === 'admin'
        );
      },
      {
        description: 'Admin operations (requires admin role)',
        enabled: true,
      },
    );
  }

  /**
   * Add a new exemption rule
   * @param {string} id - Rule ID
   * @param {string} type - Exemption type
   * @param {Function} matcher - Function that returns true if request matches
   * @param {Object} options - Rule options
   */
  addRule(id, type, matcher, options = {}) {
    if (this.rules.has(id)) {
      this.logger.warn(`Exemption rule '${id}' already exists, overwriting`);
    }

    const rule = new ExemptionRule(id, type, matcher, options);
    this.rules.set(id, rule);

    this.logger.info(`Added exemption rule: ${id}`, {
      type,
      description: rule.description,
      enabled: rule.enabled,
    });
  }

  /**
   * Remove an exemption rule
   * @param {string} id - Rule ID
   */
  removeRule(id) {
    if (this.rules.delete(id)) {
      this.logger.info(`Removed exemption rule: ${id}`);
    }
  }

  /**
   * Enable an exemption rule
   * @param {string} id - Rule ID
   */
  enableRule(id) {
    const rule = this.rules.get(id);
    if (rule) {
      rule.enabled = true;
      this.logger.info(`Enabled exemption rule: ${id}`);
    }
  }

  /**
   * Disable an exemption rule
   * @param {string} id - Rule ID
   */
  disableRule(id) {
    const rule = this.rules.get(id);
    if (rule) {
      rule.enabled = false;
      this.logger.info(`Disabled exemption rule: ${id}`);
    }
  }

  /**
   * Check if request is exempt from rate limiting
   * @param {Object} req - Express request object
   * @returns {Object} Exemption result
   */
  checkExemption(req) {
    if (!this.config.enabled) {
      return {
        exempt: false,
        reason: 'exemptions_disabled',
      };
    }

    const userId = req.userId;
    const correlationId = req.correlationId;

    // Check all rules
    for (const [ruleId, rule] of this.rules.entries()) {
      if (rule.matches(req)) {
        // Check if user has exceeded exemption quota
        if (!rule.canExempt(userId)) {
          if (this.config.logExemptionValidation) {
            this.logger.warn('Exemption quota exceeded for user', {
              correlationId,
              userId,
              ruleId,
              exemptionCount: rule.getExemptionCount(userId),
              maxExemptions: rule.maxExemptionsPerUser,
            });
          }

          return {
            exempt: false,
            reason: 'exemption_quota_exceeded',
            ruleId,
          };
        }

        // Record the exemption
        rule.recordExemption(userId);

        if (this.config.logExemptions) {
          this.logger.info('Request exempt from rate limiting', {
            correlationId,
            userId,
            ruleId,
            type: rule.type,
            path: req.path,
            method: req.method,
          });
        }

        // Record exemption metric
        rateLimitMetricsService.recordExemption({
          exemptionType: rule.type,
          userId,
          ruleId,
        });

        return {
          exempt: true,
          ruleId,
          type: rule.type,
          description: rule.description,
        };
      }
    }

    return {
      exempt: false,
      reason: 'no_matching_exemption',
    };
  }

  /**
   * Get all exemption rules
   * @returns {Array} Array of exemption rules
   */
  getRules() {
    return Array.from(this.rules.values()).map((rule) => ({
      id: rule.id,
      type: rule.type,
      description: rule.description,
      enabled: rule.enabled,
      createdAt: rule.createdAt,
      maxExemptionsPerUser: rule.maxExemptionsPerUser,
    }));
  }

  /**
   * Get exemption statistics
   * @returns {Object} Statistics
   */
  getStatistics() {
    const stats = {
      totalRules: this.rules.size,
      enabledRules: 0,
      disabledRules: 0,
      rules: [],
    };

    for (const rule of this.rules.values()) {
      if (rule.enabled) {
        stats.enabledRules++;
      } else {
        stats.disabledRules++;
      }

      stats.rules.push({
        id: rule.id,
        type: rule.type,
        enabled: rule.enabled,
        description: rule.description,
        exemptionCount: rule.exemptionCount.size,
      });
    }

    return stats;
  }

  /**
   * Reset exemption counts for a user
   * @param {string} userId - User ID
   */
  resetUserExemptions(userId) {
    for (const rule of this.rules.values()) {
      rule.resetExemptionCount(userId);
    }

    this.logger.info('Reset exemption counts for user', { userId });
  }

  /**
   * Reset all exemption counts
   */
  resetAllExemptions() {
    for (const rule of this.rules.values()) {
      rule.exemptionCount.clear();
    }

    this.logger.info('Reset all exemption counts');
  }
}

/**
 * Create Express middleware for rate limit exemptions
 * @param {RateLimitExemptionManager} exemptionManager - Exemption manager instance
 * @returns {Function} Express middleware
 */
export function createRateLimitExemptionMiddleware(exemptionManager) {
  return (req, res, next) => {
    const result = exemptionManager.checkExemption(req);

    // Store exemption result in request for rate limiter to check
    req.rateLimitExemption = result;

    next();
  };
}

export default RateLimitExemptionManager;
