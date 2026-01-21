/**
 * @fileoverview Rate limiting middleware for tunnel requests
 * Implements per-user rate limiting with configurable windows and limits
 */

import {
  TunnelLogger,
  ERROR_CODES,
  ErrorResponseBuilder,
} from '../utils/logger.js';
import { RateLimitViolationsService } from '../services/rate-limit-violations-service.js';
import { rateLimitMetricsService } from '../services/rate-limit-metrics-service.js';

/**
 * Rate limiter configuration
 */
const DEFAULT_CONFIG = {
  // Standard rate limits
  windowMs: 15 * 60 * 1000, // 15 minutes
  maxRequests: 1000, // requests per window

  // Burst protection
  burstWindowMs: 60 * 1000, // 1 minute
  maxBurstRequests: 100, // requests per burst window

  // Connection limits
  maxConcurrentRequests: 50, // concurrent requests per user

  // Cleanup intervals
  cleanupIntervalMs: 5 * 60 * 1000, // 5 minutes

  // Headers
  includeHeaders: true,
  skipSuccessfulRequests: false,
  skipFailedRequests: false,
};

/**
 * User request tracking data structure
 */
class UserRequestTracker {
  constructor(userId) {
    this.userId = userId;
    this.requests = [];
    this.burstRequests = [];
    this.concurrentRequests = 0;
    this.totalRequests = 0;
    this.blockedRequests = 0;
    this.lastRequestTime = new Date();
    this.firstRequestTime = new Date();
  }

  /**
   * Add a new request to tracking
   * @param {Date} timestamp - Request timestamp
   */
  addRequest(timestamp = new Date()) {
    this.requests.push(timestamp);
    this.burstRequests.push(timestamp);
    this.concurrentRequests++;
    this.totalRequests++;
    this.lastRequestTime = timestamp;

    if (this.totalRequests === 1) {
      this.firstRequestTime = timestamp;
    }
  }

  /**
   * Complete a request (reduce concurrent count)
   */
  completeRequest() {
    if (this.concurrentRequests > 0) {
      this.concurrentRequests--;
    }
  }

  /**
   * Block a request (increment blocked count)
   */
  blockRequest() {
    this.blockedRequests++;
    this.lastRequestTime = new Date();
  }

  /**
   * Clean up old request timestamps
   * @param {number} windowMs - Window size in milliseconds
   * @param {number} burstWindowMs - Burst window size in milliseconds
   */
  cleanup(windowMs, burstWindowMs) {
    const now = new Date();
    const windowCutoff = new Date(now.getTime() - windowMs);
    const burstCutoff = new Date(now.getTime() - burstWindowMs);

    // Clean up main window requests
    this.requests = this.requests.filter(
      (timestamp) => timestamp > windowCutoff,
    );

    // Clean up burst window requests
    this.burstRequests = this.burstRequests.filter(
      (timestamp) => timestamp > burstCutoff,
    );
  }

  /**
   * Get current request counts
   * @param {number} windowMs - Window size in milliseconds
   * @param {number} burstWindowMs - Burst window size in milliseconds
   * @returns {Object} Request counts
   */
  getCounts(windowMs, burstWindowMs) {
    this.cleanup(windowMs, burstWindowMs);

    return {
      windowRequests: this.requests.length,
      burstRequests: this.burstRequests.length,
      concurrentRequests: this.concurrentRequests,
      totalRequests: this.totalRequests,
      blockedRequests: this.blockedRequests,
    };
  }

  /**
   * Get rate limiting statistics
   * @returns {Object} Statistics
   */
  getStats() {
    const now = new Date();
    const sessionDuration = now.getTime() - this.firstRequestTime.getTime();

    return {
      userId: this.userId,
      totalRequests: this.totalRequests,
      blockedRequests: this.blockedRequests,
      concurrentRequests: this.concurrentRequests,
      successRate:
        this.totalRequests > 0
          ? (
              ((this.totalRequests - this.blockedRequests) /
                this.totalRequests) *
              100
            ).toFixed(2)
          : 100,
      sessionDuration: Math.round(sessionDuration / 1000), // seconds
      lastRequestTime: this.lastRequestTime,
      requestsPerMinute:
        sessionDuration > 0
          ? Math.round((this.totalRequests * 60000) / sessionDuration)
          : 0,
    };
  }
}

/**
 * Tunnel rate limiter class
 */
export class TunnelRateLimiter {
  constructor(config = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.userTrackers = new Map();
    this.logger = new TunnelLogger('rate-limiter');
    this.violationsService = new RateLimitViolationsService();

    // Start cleanup interval
    this.cleanupInterval = setInterval(() => {
      this.cleanup();
    }, this.config.cleanupIntervalMs);

    this.logger.info('Tunnel rate limiter initialized', {
      windowMs: this.config.windowMs,
      maxRequests: this.config.maxRequests,
      burstWindowMs: this.config.burstWindowMs,
      maxBurstRequests: this.config.maxBurstRequests,
      maxConcurrentRequests: this.config.maxConcurrentRequests,
    });
  }

  /**
   * Get or create user tracker
   * @param {string} userId - User ID
   * @returns {UserRequestTracker} User tracker
   */
  getUserTracker(userId) {
    if (!this.userTrackers.has(userId)) {
      this.userTrackers.set(userId, new UserRequestTracker(userId));
    }
    return this.userTrackers.get(userId);
  }

  /**
   * Check if request should be rate limited
   * @param {string} userId - User ID
   * @param {string} correlationId - Request correlation ID
   * @param {Object} exemptionResult - Exemption check result (optional)
   * @param {Object} requestContext - Request context for logging
   * @returns {Object} Rate limit result
   */
  checkRateLimit(
    userId,
    correlationId,
    exemptionResult = null,
    requestContext = {},
  ) {
    // Check if request is exempt from rate limiting
    if (exemptionResult && exemptionResult.exempt) {
      this.logger.debug('Request exempt from rate limiting', {
        correlationId,
        userId,
        exemptionRuleId: exemptionResult.ruleId,
        exemptionType: exemptionResult.type,
      });

      return {
        allowed: true,
        exempt: true,
        exemptionRuleId: exemptionResult.ruleId,
        exemptionType: exemptionResult.type,
        limits: {
          window: { current: 0, max: this.config.maxRequests },
          burst: { current: 0, max: this.config.maxBurstRequests },
          concurrent: { current: 0, max: this.config.maxConcurrentRequests },
        },
      };
    }

    const tracker = this.getUserTracker(userId);
    const counts = tracker.getCounts(
      this.config.windowMs,
      this.config.burstWindowMs,
    );

    // Check concurrent requests limit
    if (counts.concurrentRequests >= this.config.maxConcurrentRequests) {
      tracker.blockRequest();

      this.logger.logSecurity('rate_limit_concurrent_exceeded', userId, {
        correlationId,
        concurrentRequests: counts.concurrentRequests,
        maxConcurrentRequests: this.config.maxConcurrentRequests,
        totalRequests: counts.totalRequests,
        blockedRequests: counts.blockedRequests,
      });

      // Record metrics
      rateLimitMetricsService.recordViolation({
        violationType: 'concurrent_limit_exceeded',
        userId,
        ipAddress: requestContext.ipAddress,
      });
      rateLimitMetricsService.recordRequestBlocked({
        violationType: 'concurrent_limit_exceeded',
        userId,
      });

      // Log violation asynchronously
      this.logViolation({
        userId,
        violationType: 'concurrent_limit_exceeded',
        endpoint: requestContext.endpoint,
        method: requestContext.method,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        context: {
          correlationId,
          concurrentRequests: counts.concurrentRequests,
          maxConcurrentRequests: this.config.maxConcurrentRequests,
          totalRequests: counts.totalRequests,
          blockedRequests: counts.blockedRequests,
        },
      }).catch((error) => {
        this.logger.error('Failed to log rate limit violation', {
          error: error.message,
          userId,
          violationType: 'concurrent_limit_exceeded',
        });
      });

      return {
        allowed: false,
        reason: 'concurrent_limit_exceeded',
        retryAfter: Math.ceil(this.config.burstWindowMs / 1000),
        limits: {
          concurrent: {
            current: counts.concurrentRequests,
            max: this.config.maxConcurrentRequests,
          },
        },
      };
    }

    // Check burst rate limit
    if (counts.burstRequests >= this.config.maxBurstRequests) {
      tracker.blockRequest();

      this.logger.logSecurity('rate_limit_burst_exceeded', userId, {
        correlationId,
        burstRequests: counts.burstRequests,
        maxBurstRequests: this.config.maxBurstRequests,
        burstWindowMs: this.config.burstWindowMs,
        totalRequests: counts.totalRequests,
        blockedRequests: counts.blockedRequests,
      });

      // Record metrics
      rateLimitMetricsService.recordViolation({
        violationType: 'burst_limit_exceeded',
        userId,
        ipAddress: requestContext.ipAddress,
      });
      rateLimitMetricsService.recordRequestBlocked({
        violationType: 'burst_limit_exceeded',
        userId,
      });

      // Log violation asynchronously
      this.logViolation({
        userId,
        violationType: 'burst_limit_exceeded',
        endpoint: requestContext.endpoint,
        method: requestContext.method,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        context: {
          correlationId,
          burstRequests: counts.burstRequests,
          maxBurstRequests: this.config.maxBurstRequests,
          burstWindowMs: this.config.burstWindowMs,
          totalRequests: counts.totalRequests,
          blockedRequests: counts.blockedRequests,
        },
      }).catch((error) => {
        this.logger.error('Failed to log rate limit violation', {
          error: error.message,
          userId,
          violationType: 'burst_limit_exceeded',
        });
      });

      return {
        allowed: false,
        reason: 'burst_limit_exceeded',
        retryAfter: Math.ceil(this.config.burstWindowMs / 1000),
        limits: {
          burst: {
            current: counts.burstRequests,
            max: this.config.maxBurstRequests,
            windowMs: this.config.burstWindowMs,
          },
        },
      };
    }

    // Check main window rate limit
    if (counts.windowRequests >= this.config.maxRequests) {
      tracker.blockRequest();

      this.logger.logSecurity('rate_limit_window_exceeded', userId, {
        correlationId,
        windowRequests: counts.windowRequests,
        maxRequests: this.config.maxRequests,
        windowMs: this.config.windowMs,
        totalRequests: counts.totalRequests,
        blockedRequests: counts.blockedRequests,
      });

      // Record metrics
      rateLimitMetricsService.recordViolation({
        violationType: 'window_limit_exceeded',
        userId,
        ipAddress: requestContext.ipAddress,
      });
      rateLimitMetricsService.recordRequestBlocked({
        violationType: 'window_limit_exceeded',
        userId,
      });

      // Log violation asynchronously
      this.logViolation({
        userId,
        violationType: 'window_limit_exceeded',
        endpoint: requestContext.endpoint,
        method: requestContext.method,
        ipAddress: requestContext.ipAddress,
        userAgent: requestContext.userAgent,
        context: {
          correlationId,
          windowRequests: counts.windowRequests,
          maxRequests: this.config.maxRequests,
          windowMs: this.config.windowMs,
          totalRequests: counts.totalRequests,
          blockedRequests: counts.blockedRequests,
        },
      }).catch((error) => {
        this.logger.error('Failed to log rate limit violation', {
          error: error.message,
          userId,
          violationType: 'window_limit_exceeded',
        });
      });

      return {
        allowed: false,
        reason: 'window_limit_exceeded',
        retryAfter: Math.ceil(this.config.windowMs / 1000),
        limits: {
          window: {
            current: counts.windowRequests,
            max: this.config.maxRequests,
            windowMs: this.config.windowMs,
          },
        },
      };
    }

    // Request is allowed
    tracker.addRequest();

    // Record metrics
    rateLimitMetricsService.recordRequestAllowed({
      userId,
    });
    rateLimitMetricsService.updateWindowUsage(
      userId,
      counts.windowRequests + 1,
      this.config.maxRequests,
    );
    rateLimitMetricsService.updateBurstUsage(
      userId,
      counts.burstRequests + 1,
      this.config.maxBurstRequests,
    );
    rateLimitMetricsService.updateConcurrentRequests(
      userId,
      counts.concurrentRequests + 1,
    );

    this.logger.debug('Rate limit check passed', {
      correlationId,
      userId,
      windowRequests: counts.windowRequests,
      burstRequests: counts.burstRequests,
      concurrentRequests: counts.concurrentRequests,
    });

    return {
      allowed: true,
      limits: {
        window: {
          current: counts.windowRequests + 1,
          max: this.config.maxRequests,
          windowMs: this.config.windowMs,
        },
        burst: {
          current: counts.burstRequests + 1,
          max: this.config.maxBurstRequests,
          windowMs: this.config.burstWindowMs,
        },
        concurrent: {
          current: counts.concurrentRequests + 1,
          max: this.config.maxConcurrentRequests,
        },
      },
    };
  }

  /**
   * Complete a request (reduce concurrent count)
   * @param {string} userId - User ID
   */
  completeRequest(userId) {
    const tracker = this.userTrackers.get(userId);
    if (tracker) {
      tracker.completeRequest();
    }
  }

  /**
   * Log a rate limit violation
   * @param {Object} violation - Violation details
   * @returns {Promise<void>}
   */
  async logViolation(violation) {
    try {
      await this.violationsService.logViolation(violation);
    } catch (error) {
      this.logger.error('Failed to log violation', {
        error: error.message,
        userId: violation.userId,
      });
    }
  }

  /**
   * Get rate limiting statistics for a user
   * @param {string} userId - User ID
   * @returns {Object} User statistics
   */
  getUserStats(userId) {
    const tracker = this.userTrackers.get(userId);
    if (!tracker) {
      return {
        userId,
        totalRequests: 0,
        blockedRequests: 0,
        concurrentRequests: 0,
        successRate: 100,
        sessionDuration: 0,
        requestsPerMinute: 0,
      };
    }

    return tracker.getStats();
  }

  /**
   * Get overall rate limiting statistics
   * @returns {Object} Overall statistics
   */
  getOverallStats() {
    const stats = {
      totalUsers: this.userTrackers.size,
      totalRequests: 0,
      totalBlockedRequests: 0,
      totalConcurrentRequests: 0,
      averageRequestsPerUser: 0,
      averageSuccessRate: 0,
      topUsers: [],
    };

    const userStats = [];

    for (const tracker of this.userTrackers.values()) {
      const userStat = tracker.getStats();
      userStats.push(userStat);

      stats.totalRequests += userStat.totalRequests;
      stats.totalBlockedRequests += userStat.blockedRequests;
      stats.totalConcurrentRequests += userStat.concurrentRequests;
    }

    if (stats.totalUsers > 0) {
      stats.averageRequestsPerUser = Math.round(
        stats.totalRequests / stats.totalUsers,
      );
      stats.averageSuccessRate =
        userStats.reduce((sum, stat) => sum + parseFloat(stat.successRate), 0) /
        stats.totalUsers;
      stats.averageSuccessRate = stats.averageSuccessRate.toFixed(2);
    }

    // Get top 10 users by request count
    stats.topUsers = userStats
      .sort((a, b) => b.totalRequests - a.totalRequests)
      .slice(0, 10)
      .map((stat) => ({
        userId: stat.userId,
        totalRequests: stat.totalRequests,
        blockedRequests: stat.blockedRequests,
        successRate: stat.successRate,
        requestsPerMinute: stat.requestsPerMinute,
      }));

    return stats;
  }

  /**
   * Clean up old user trackers and request data
   */
  cleanup() {
    const now = new Date();
    const inactiveThreshold = new Date(
      now.getTime() - this.config.windowMs * 2,
    );
    const trackersToRemove = [];

    for (const [userId, tracker] of this.userTrackers.entries()) {
      // Clean up old requests
      tracker.cleanup(this.config.windowMs, this.config.burstWindowMs);

      // Mark inactive trackers for removal
      if (
        tracker.lastRequestTime < inactiveThreshold &&
        tracker.concurrentRequests === 0
      ) {
        trackersToRemove.push(userId);
      }
    }

    // Remove inactive trackers
    for (const userId of trackersToRemove) {
      this.userTrackers.delete(userId);
    }

    if (trackersToRemove.length > 0) {
      this.logger.debug('Cleaned up inactive user trackers', {
        removedTrackers: trackersToRemove.length,
        activeTrackers: this.userTrackers.size,
      });
    }
  }

  /**
   * Destroy the rate limiter and clean up resources
   */
  destroy() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }

    this.userTrackers.clear();
    this.logger.info('Tunnel rate limiter destroyed');
  }
}

/**
 * Create Express middleware for tunnel rate limiting
 * @param {Object} config - Rate limiter configuration
 * @returns {Function} Express middleware
 */
export function createTunnelRateLimitMiddleware(config = {}) {
  const rateLimiter = new TunnelRateLimiter(config);

  return (req, res, next) => {
    const userId = req.userId;
    const correlationId = req.correlationId;

    if (!userId) {
      // If no user ID, skip rate limiting (should be handled by auth middleware)
      return next();
    }

    // Get exemption result if available (set by exemption middleware)
    const exemptionResult = req.rateLimitExemption;

    // Prepare request context for violation logging
    const requestContext = {
      endpoint: req.path,
      method: req.method,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('user-agent'),
    };

    const result = rateLimiter.checkRateLimit(
      userId,
      correlationId,
      exemptionResult,
      requestContext,
    );

    if (!result.allowed) {
      // Set rate limit headers
      if (rateLimiter.config.includeHeaders) {
        res.set({
          'X-RateLimit-Limit':
            result.limits?.window?.max || rateLimiter.config.maxRequests,
          'X-RateLimit-Remaining': Math.max(
            0,
            (result.limits?.window?.max || rateLimiter.config.maxRequests) -
              (result.limits?.window?.current || 0),
          ),
          'X-RateLimit-Reset': new Date(
            Date.now() + result.retryAfter * 1000,
          ).toISOString(),
          'Retry-After': result.retryAfter,
        });
      }

      const errorResponse = ErrorResponseBuilder.createErrorResponse(
        ERROR_CODES.RATE_LIMIT_EXCEEDED || 'RATE_LIMIT_EXCEEDED',
        `Rate limit exceeded: ${result.reason.replace(/_/g, ' ')}`,
        429,
        {
          reason: result.reason,
          retryAfter: result.retryAfter,
          limits: result.limits,
        },
      );

      return res.status(429).json(errorResponse);
    }

    // Set rate limit headers for successful requests
    if (rateLimiter.config.includeHeaders) {
      res.set({
        'X-RateLimit-Limit': result.limits.window.max,
        'X-RateLimit-Remaining': Math.max(
          0,
          result.limits.window.max - result.limits.window.current,
        ),
        'X-RateLimit-Reset': new Date(
          Date.now() + result.limits.window.windowMs,
        ).toISOString(),
      });

      // Add exemption header if request is exempt
      if (result.exempt) {
        res.set({
          'X-RateLimit-Exempt': 'true',
          'X-RateLimit-Exempt-Rule': result.exemptionRuleId,
        });
      }
    }

    // Store rate limiter in request for cleanup
    req.rateLimiter = rateLimiter;

    // Set up response completion handler
    const originalEnd = res.end;
    res.end = function (...args) {
      rateLimiter.completeRequest(userId);
      originalEnd.apply(this, args);
    };

    next();
  };
}

// Add rate limit exceeded error code to ERROR_CODES if not already present
if (!ERROR_CODES.RATE_LIMIT_EXCEEDED) {
  ERROR_CODES.RATE_LIMIT_EXCEEDED = 'RATE_LIMIT_EXCEEDED';
}

export default TunnelRateLimiter;
