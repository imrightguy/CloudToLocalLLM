/**
 * Request Queuing Middleware for CloudToLocalLLM API Backend
 *
 * Implements request queuing when rate limit is approached.
 * Queues requests and processes them in FIFO order when capacity becomes available.
 *
 * @fileoverview Request queuing middleware
 * @version 1.0.0
 */

import { getRequestQueueService } from '../services/request-queue-service.js';
import logger from '../logger.js';

/**
 * Create request queuing middleware
 * @param {Object} options - Configuration options
 * @returns {Function} Express middleware function
 */
export function createRequestQueuingMiddleware(options = {}) {
  const queueService = getRequestQueueService(options);

  return async (req, res, next) => {
    // Skip queuing for certain request types
    if (
      req.method === 'OPTIONS' ||
      req.method === 'GET' ||
      req.method === 'HEAD'
    ) {
      return next();
    }

    // Get rate limit info from response headers (set by rate limiter)
    const rateLimitLimit = parseInt(req.get('X-RateLimit-Limit') || '100');
    const rateLimitRemaining = parseInt(
      req.get('X-RateLimit-Remaining') || rateLimitLimit,
    );

    // Check if we should queue this request
    if (!queueService.shouldQueue(rateLimitRemaining, rateLimitLimit)) {
      // Not approaching limit, proceed normally
      return next();
    }

    // Determine identifier (user ID or IP)
    const userId = req.user?.sub;
    const clientIp = req.ip || req.connection.remoteAddress;
    const identifier = userId || clientIp;
    const queueType = userId ? 'user' : 'ip';

    // Check if request is already queued (avoid double-queuing)
    if (req.isQueued) {
      return next();
    }

    // Queue the request
    const queueResult = queueService.queueRequest(identifier, queueType, {
      method: req.method,
      path: req.path,
      userId,
      clientIp,
    });

    if (!queueResult.queued) {
      // Queue is full, reject request
      logger.warn(
        `Request rejected - queue full for ${queueType} ${identifier}`,
        {
          queueType,
          identifier,
          method: req.method,
          path: req.path,
        },
      );

      return res.status(429).json({
        error: 'Too many requests',
        code: 'QUEUE_FULL',
        message: 'Request queue is full. Please try again later.',
        retryAfter: 60,
        correlationId: req.correlationId,
      });
    }

    // Wait for request to be processed from queue
    try {
      const result = await queueResult.promise;

      // Mark request as processed from queue
      req.isQueued = true;
      req.queuedDuration = result.queuedDuration;
      req.queuePosition = queueResult.position;

      logger.debug(
        `Request processed from queue for ${queueType} ${identifier}`,
        {
          queueType,
          identifier,
          queuedDuration: result.queuedDuration,
          method: req.method,
          path: req.path,
        },
      );

      // Add queue info to response headers
      res.set('X-Queue-Position', queueResult.position);
      res.set('X-Queue-Wait-Time', result.queuedDuration);

      next();
    } catch (error) {
      logger.error(
        `Error processing queued request for ${queueType} ${identifier}`,
        {
          queueType,
          identifier,
          error: error.message,
          method: req.method,
          path: req.path,
        },
      );

      if (error.message === 'QUEUE_TIMEOUT') {
        return res.status(504).json({
          error: 'Request timeout',
          code: 'QUEUE_TIMEOUT',
          message:
            'Your request was queued but timed out waiting for processing.',
          correlationId: req.correlationId,
        });
      }

      return res.status(503).json({
        error: 'Service unavailable',
        code: 'QUEUE_ERROR',
        message: 'Error processing queued request.',
        correlationId: req.correlationId,
      });
    }
  };
}

/**
 * Create queue status reporting middleware
 * @returns {Function} Express middleware function
 */
export function createQueueStatusMiddleware() {
  const queueService = getRequestQueueService();

  return (req, res, next) => {
    // Add queue status to request object for use in route handlers
    req.queueStatus = {
      getStatus: (identifier, queueType) => {
        return queueService.getQueueStatus(identifier, queueType);
      },
      getStatistics: () => {
        return queueService.getStatistics();
      },
      getHealthStatus: () => {
        return queueService.getHealthStatus();
      },
    };

    next();
  };
}

/**
 * Create queue management route handler
 * @returns {Function} Express route handler
 */
export function createQueueStatusHandler() {
  const queueService = getRequestQueueService();

  return (req, res) => {
    try {
      const stats = queueService.getStatistics();
      const health = queueService.getHealthStatus();

      res.json({
        status: health.status,
        queue: {
          currentQueued: stats.currentQueuedRequests,
          totalQueues: stats.totalQueuesCount,
          userQueues: stats.userQueuesCount,
          ipQueues: stats.ipQueuesCount,
          maxQueueSize: queueService.maxQueueSize,
        },
        statistics: {
          totalQueued: stats.totalQueued,
          totalProcessed: stats.totalProcessed,
          totalExpired: stats.totalExpired,
          totalRejected: stats.totalRejected,
        },
        health: {
          averageQueueSize: health.averageQueueSize,
          status: health.status,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error getting queue status:', error);
      res.status(500).json({
        error: 'Failed to get queue status',
        code: 'QUEUE_STATUS_ERROR',
        message: error.message,
      });
    }
  };
}

/**
 * Create queue drain handler (for testing/debugging)
 * @returns {Function} Express route handler
 */
export function createQueueDrainHandler() {
  const queueService = getRequestQueueService();

  return (req, res) => {
    try {
      const userId = req.user?.sub;
      const clientIp = req.ip || req.connection.remoteAddress;
      const identifier = userId || clientIp;
      const queueType = userId ? 'user' : 'ip';

      const queueStatus = queueService.getQueueStatus(identifier, queueType);

      // Process all queued requests for this identifier
      let processed = 0;
      while (true) {
        const entry = queueService.processNextRequest(identifier, queueType);
        if (!entry) {
          break;
        }
        processed++;
      }

      res.json({
        success: true,
        message: `Drained ${processed} requests from queue`,
        identifier,
        queueType,
        processed,
        remainingInQueue: queueStatus.queueSize - processed,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('Error draining queue:', error);
      res.status(500).json({
        error: 'Failed to drain queue',
        code: 'QUEUE_DRAIN_ERROR',
        message: error.message,
      });
    }
  };
}

export default {
  createRequestQueuingMiddleware,
  createQueueStatusMiddleware,
  createQueueStatusHandler,
  createQueueDrainHandler,
};
