/**
 * @fileoverview Adaptive Rate Limiting Middleware
 * Adjusts rate limits based on system load
 * Integrates with SystemLoadMonitor to provide dynamic rate limiting
 */

import {
  TunnelLogger,
  ERROR_CODES,
  ErrorResponseBuilder,
} from '../utils/logger.js';
import { SystemLoadMonitor } from '../services/system-load-monitor.js';

/**
 * Adaptive rate limiter configuration
 */
const DEFAULT_CONFIG = {
  // Base rate limits
  baseWindowMs: 15 * 60 * 1000, // 15 minutes
  baseMaxRequests: 1000, // requests per window
  baseBurstWindowMs: 60 * 1000, // 1 minute
  baseBurstRequests: 100, // requests per burst window

  // System load monitoring
  enableAdaptiveAdjustment: true,
  sampleIntervalMs: 5000, // 5 seconds
  historySize: 60, // 5 minutes of history

  // Headers
  includeHeaders: true,
};

/**
 * User request tracking for adaptive rate limiting
 */
class AdaptiveUserTracker {
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
   * Add a new request
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
   * Complete a request
   */
  completeRequest() {
    if (this.concurrentRequests > 0) {
      this.concurrentRequests--;
    }
  }

  /**
   * Block a request
   */
  blockRequest() {
    this.blockedRequests++;
    this.lastRequestTime = new Date();
  }

  /**
   * Clean up old request timestamps
   */
  cleanup(windowMs, burstWindowMs) {
    const now = new Date();
    const windowCutoff = new Date(now.getTime() - windowMs);
    const burstCutoff = new Date(now.getTime() - burstWindowMs);

    this.requests = this.requests.filter(
      (timestamp) => timestamp > windowCutoff,
    );
    this.burstRequests = this.burstRequests.filter(
      (timestamp) => timestamp > burstCutoff,
    );
  }

  /**
   * Get current request counts
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
}

/**
 * Adaptive Rate Limiter
 * Adjusts rate limits based on system load
 */
export class AdaptiveRateLimiter {
  constructor(config = {}) {
    this.config = { ...DEFAULT_CONFIG, ...config };
    this.logger = new TunnelLogger('adaptive-rate-limiter');
    this.userTrackers = new Map();

    // Initialize system load monitor
    this.systemLoadMonitor = new SystemLoadMonitor({
      sampleIntervalMs: this.config.sampleIntervalMs,
      historySize: this.config.historySize,
    });

    // Cleanup interval
    this.cleanupInterval = setInterval(
      () => {
        this.cleanup();
      },
      5 * 60 * 1000,
    ); // 5 minutes

    this.logger.info('Adaptive rate limiter initialized', {
      baseWindowMs: this.config.baseWindowMs,
      baseMaxRequests: this.config.baseMaxRequests,
      baseBurstWindowMs: this.config.baseBurstWindowMs,
      baseBurstRequests: this.config.baseBurstRequests,
      enableAdaptiveAdjustment: this.config.enableAdaptiveAdjustment,
    });
  }

  /**
   * Get or create user tracker
   */
  getUserTracker(userId) {
    if (!this.userTrackers.has(userId)) {
      this.userTrackers.set(userId, new AdaptiveUserTracker(userId));
    }
    return this.userTrackers.get(userId);
  }

  /**
   * Get adaptive limits based on system load
   */
  getAdaptiveLimits() {
    if (!this.config.enableAdaptiveAdjustment) {
      return {
        maxRequests: this.config.baseMaxRequests,
        burstRequests: this.config.baseBurstRequests,
        multiplier: 1.0,
      };
    }

    const multiplier = this.systemLoadMonitor.adaptiveMultiplier;

    return {
      maxRequests: Math.ceil(this.config.baseMaxRequests * multiplier),
      burstRequests: Math.ceil(this.config.baseBurstRequests * multiplier),
      multiplier,
    };
  }

  /**
   * Check if request should be rate limited
   */
  /* eslint-disable space-before-function-paren */
  checkRateLimit(userId, correlationId, _requestContext = {}) {
    const tracker = this.getUserTracker(userId);
    const adaptiveLimits = this.getAdaptiveLimits();

    const counts = tracker.getCounts(
      this.config.baseWindowMs,
      this.config.baseBurstWindowMs,
    );

    // Check burst rate limit
    if (counts.burstRequests >= adaptiveLimits.burstRequests) {
      tracker.blockRequest();

      this.logger.logSecurity('adaptive_rate_limit_burst_exceeded', userId, {
        correlationId,
        burstRequests: counts.burstRequests,
        maxBurstRequests: adaptiveLimits.burstRequests,
        adaptiveMultiplier: adaptiveLimits.multiplier.toFixed(2),
        systemLoad: this.systemLoadMonitor.currentMetrics
          .getLoadPercentage()
          .toFixed(2),
      });

      return {
        allowed: false,
        reason: 'burst_limit_exceeded',
        retryAfter: Math.ceil(this.config.baseBurstWindowMs / 1000),
        limits: {
          burst: {
            current: counts.burstRequests,
            max: adaptiveLimits.burstRequests,
            adaptive: true,
            multiplier: adaptiveLimits.multiplier.toFixed(2),
          },
        },
      };
    }

    // Check main window rate limit
    if (counts.windowRequests >= adaptiveLimits.maxRequests) {
      tracker.blockRequest();

      this.logger.logSecurity('adaptive_rate_limit_window_exceeded', userId, {
        correlationId,
        windowRequests: counts.windowRequests,
        maxRequests: adaptiveLimits.maxRequests,
        adaptiveMultiplier: adaptiveLimits.multiplier.toFixed(2),
        systemLoad: this.systemLoadMonitor.currentMetrics
          .getLoadPercentage()
          .toFixed(2),
      });

      return {
        allowed: false,
        reason: 'window_limit_exceeded',
        retryAfter: Math.ceil(this.config.baseWindowMs / 1000),
        limits: {
          window: {
            current: counts.windowRequests,
            max: adaptiveLimits.maxRequests,
            adaptive: true,
            multiplier: adaptiveLimits.multiplier.toFixed(2),
          },
        },
      };
    }

    // Request is allowed
    tracker.addRequest();

    this.logger.debug('Adaptive rate limit check passed', {
      correlationId,
      userId,
      windowRequests: counts.windowRequests,
      burstRequests: counts.burstRequests,
      adaptiveMultiplier: adaptiveLimits.multiplier.toFixed(2),
    });

    return {
      allowed: true,
      limits: {
        window: {
          current: counts.windowRequests + 1,
          max: adaptiveLimits.maxRequests,
          adaptive: true,
          multiplier: adaptiveLimits.multiplier.toFixed(2),
        },
        burst: {
          current: counts.burstRequests + 1,
          max: adaptiveLimits.burstRequests,
          adaptive: true,
          multiplier: adaptiveLimits.multiplier.toFixed(2),
        },
      },
    };
  }

  /**
   * Complete a request
   */
  completeRequest(userId) {
    const tracker = this.userTrackers.get(userId);
    if (tracker) {
      tracker.completeRequest();
    }
    this.systemLoadMonitor.recordCompletedRequest();
  }

  /**
   * Record an active request
   */
  recordActiveRequest() {
    this.systemLoadMonitor.recordActiveRequest();
  }

  /**
   * Get system load metrics
   */
  getSystemMetrics() {
    return this.systemLoadMonitor.getCurrentMetrics();
  }

  /**
   * Get system status
   */
  getSystemStatus() {
    return this.systemLoadMonitor.getSystemStatus();
  }

  /**
   * Get user statistics
   */
  getUserStats(userId) {
    const tracker = this.userTrackers.get(userId);
    if (!tracker) {
      return {
        userId,
        totalRequests: 0,
        blockedRequests: 0,
        concurrentRequests: 0,
      };
    }

    const counts = tracker.getCounts(
      this.config.baseWindowMs,
      this.config.baseBurstWindowMs,
    );

    return {
      userId,
      ...counts,
    };
  }

  /**
   * Clean up old user trackers
   */
  cleanup() {
    const now = new Date();
    const inactiveThreshold = new Date(
      now.getTime() - this.config.baseWindowMs * 2,
    );
    const trackersToRemove = [];

    for (const [userId, tracker] of this.userTrackers.entries()) {
      tracker.cleanup(this.config.baseWindowMs, this.config.baseBurstWindowMs);

      if (
        tracker.lastRequestTime < inactiveThreshold &&
        tracker.concurrentRequests === 0
      ) {
        trackersToRemove.push(userId);
      }
    }

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
   * Destroy the rate limiter
   */
  destroy() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }

    if (this.systemLoadMonitor) {
      this.systemLoadMonitor.destroy();
    }

    this.userTrackers.clear();
    this.logger.info('Adaptive rate limiter destroyed');
  }
}

/**
 * Create Express middleware for adaptive rate limiting
 */
export function createAdaptiveRateLimitMiddleware(config = {}) {
  const rateLimiter = new AdaptiveRateLimiter(config);

  return (req, res, next) => {
    const userId = req.userId;
    const correlationId = req.correlationId;

    if (!userId) {
      return next();
    }

    // Record active request
    rateLimiter.recordActiveRequest();

    const requestContext = {
      endpoint: req.path,
      method: req.method,
      ipAddress: req.ip || req.connection.remoteAddress,
      userAgent: req.get('user-agent'),
    };

    const result = rateLimiter.checkRateLimit(
      userId,
      correlationId,
      requestContext,
    );

    if (!result.allowed) {
      // Set rate limit headers
      if (rateLimiter.config.includeHeaders) {
        res.set({
          'X-RateLimit-Limit':
            result.limits?.window?.max || rateLimiter.config.baseMaxRequests,
          'X-RateLimit-Remaining': Math.max(
            0,
            (result.limits?.window?.max || rateLimiter.config.baseMaxRequests) -
              (result.limits?.window?.current || 0),
          ),
          'X-RateLimit-Reset': new Date(
            Date.now() + result.retryAfter * 1000,
          ).toISOString(),
          'X-RateLimit-Adaptive': 'true',
          'X-RateLimit-Adaptive-Multiplier':
            result.limits?.window?.multiplier || '1.0',
          'Retry-After': result.retryAfter,
        });
      }

      const errorResponse = ErrorResponseBuilder.createErrorResponse(
        ERROR_CODES.RATE_LIMIT_EXCEEDED || 'RATE_LIMIT_EXCEEDED',
        `Adaptive rate limit exceeded: ${result.reason.replace(/_/g, ' ')}`,
        429,
        {
          reason: result.reason,
          retryAfter: result.retryAfter,
          limits: result.limits,
          adaptive: true,
        },
      );

      rateLimiter.completeRequest(userId);
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
          Date.now() + this.config.baseWindowMs,
        ).toISOString(),
        'X-RateLimit-Adaptive': 'true',
        'X-RateLimit-Adaptive-Multiplier': result.limits.window.multiplier,
      });
    }

    // Store rate limiter in request
    req.adaptiveRateLimiter = rateLimiter;

    // Set up response completion handler
    const originalEnd = res.end;
    res.end = function (...args) {
      rateLimiter.completeRequest(userId);
      originalEnd.apply(this, args);
    };

    next();
  };
}

export default AdaptiveRateLimiter;
