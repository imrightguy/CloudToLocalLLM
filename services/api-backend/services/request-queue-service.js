/**
 * Request Queue Service for CloudToLocalLLM API Backend
 *
 * Implements request queuing when rate limit is approached.
 * Queues requests and processes them in FIFO order when capacity becomes available.
 *
 * @fileoverview Request queue service for rate limit management
 * @version 1.0.0
 */

import logger from '../logger.js';

/**
 * Request Queue Service
 * Manages queuing of requests when rate limit is approached
 */
export class RequestQueueService {
  constructor(options = {}) {
    this.maxQueueSize = options.maxQueueSize || 1000;
    this.queueTimeoutMs = options.queueTimeoutMs || 30000; // 30 seconds
    this.queueThresholdPercent = options.queueThresholdPercent || 80; // Start queuing at 80% of limit

    // Per-user queues: Map<userId, Queue>
    this.userQueues = new Map();

    // Per-IP queues: Map<ip, Queue>
    this.ipQueues = new Map();

    // Queue statistics
    this.stats = {
      totalQueued: 0,
      totalProcessed: 0,
      totalExpired: 0,
      totalRejected: 0,
      currentQueuedRequests: 0,
    };
  }

  /**
   * Check if request should be queued based on rate limit status
   * @param {number} remainingRequests - Remaining requests in current window
   * @param {number} maxRequests - Maximum requests allowed in window
   * @returns {boolean} True if request should be queued
   */
  shouldQueue(remainingRequests, maxRequests) {
    const usagePercent =
      ((maxRequests - remainingRequests) / maxRequests) * 100;
    return usagePercent >= this.queueThresholdPercent;
  }

  /**
   * Add request to queue
   * @param {string} identifier - User ID or IP address
   * @param {string} queueType - 'user' or 'ip'
   * @param {Object} requestData - Request data to queue
   * @returns {Object} Queue entry with id and promise
   */
  queueRequest(identifier, queueType, requestData) {
    const queueMap = queueType === 'user' ? this.userQueues : this.ipQueues;

    if (!queueMap.has(identifier)) {
      queueMap.set(identifier, []);
    }

    const queue = queueMap.get(identifier);

    // Check if queue is full
    if (queue.length >= this.maxQueueSize) {
      this.stats.totalRejected++;
      logger.warn(`Queue full for ${queueType} ${identifier}`, {
        queueType,
        identifier,
        queueSize: queue.length,
        maxQueueSize: this.maxQueueSize,
      });

      return {
        queued: false,
        error: 'QUEUE_FULL',
        message: 'Request queue is full, please try again later',
      };
    }

    // Create queue entry
    const queueEntry = {
      id: `${identifier}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      identifier,
      queueType,
      requestData,
      queuedAt: Date.now(),
      promise: null,
      resolve: null,
      reject: null,
      processed: false,
    };

    // Create promise for this request
    queueEntry.promise = new Promise((resolve, reject) => {
      queueEntry.resolve = resolve;
      queueEntry.reject = reject;

      // Set timeout for queued request
      const timeoutId = setTimeout(() => {
        if (this.removeFromQueue(identifier, queueType, queueEntry.id)) {
          this.stats.totalExpired++;

          logger.warn(`Queued request expired for ${queueType} ${identifier}`, {
            queueType,
            identifier,
            queuedDuration: Date.now() - queueEntry.queuedAt,
          });
        }
      }, this.queueTimeoutMs);

      queueEntry.timeoutId = timeoutId;
    });

    queue.push(queueEntry);
    this.stats.totalQueued++;
    this.stats.currentQueuedRequests++;

    logger.debug(`Request queued for ${queueType} ${identifier}`, {
      queueType,
      identifier,
      queueSize: queue.length,
      queuedRequestId: queueEntry.id,
    });

    return {
      queued: true,
      queueEntryId: queueEntry.id,
      promise: queueEntry.promise,
      position: queue.length,
      estimatedWaitMs: (queue.length - 1) * 100, // Rough estimate
    };
  }

  /**
   * Process next request in queue
   * @param {string} identifier - User ID or IP address
   * @param {string} queueType - 'user' or 'ip'
   * @returns {Object|null} Next queue entry or null if queue is empty
   */
  processNextRequest(identifier, queueType) {
    const queueMap = queueType === 'user' ? this.userQueues : this.ipQueues;
    const queue = queueMap.get(identifier);

    if (!queue || queue.length === 0) {
      return null;
    }

    const queueEntry = queue.shift();

    // Check if already processed
    if (queueEntry.processed) {
      return null;
    }

    queueEntry.processed = true;

    // Clear timeout
    if (queueEntry.timeoutId) {
      clearTimeout(queueEntry.timeoutId);
    }

    this.stats.totalProcessed++;
    this.stats.currentQueuedRequests--;

    logger.debug(`Processing queued request for ${queueType} ${identifier}`, {
      queueType,
      identifier,
      queuedDuration: Date.now() - queueEntry.queuedAt,
      remainingInQueue: queue.length,
    });

    // Resolve the promise to allow request to proceed
    queueEntry.resolve({
      processed: true,
      queuedDuration: Date.now() - queueEntry.queuedAt,
    });

    return queueEntry;
  }

  /**
   * Remove request from queue
   * @param {string} identifier - User ID or IP address
   * @param {string} queueType - 'user' or 'ip'
   * @param {string} queueEntryId - Queue entry ID
   * @returns {boolean} True if removed successfully
   */
  removeFromQueue(identifier, queueType, queueEntryId) {
    const queueMap = queueType === 'user' ? this.userQueues : this.ipQueues;
    const queue = queueMap.get(identifier);

    if (!queue) {
      return false;
    }

    const index = queue.findIndex((entry) => entry.id === queueEntryId);
    if (index === -1) {
      return false;
    }

    const queueEntry = queue[index];

    // Check if already processed
    if (queueEntry.processed) {
      return false;
    }

    queueEntry.processed = true;

    // Clear timeout
    if (queueEntry.timeoutId) {
      clearTimeout(queueEntry.timeoutId);
    }

    queue.splice(index, 1);
    this.stats.currentQueuedRequests--;

    // Reject the promise for timeout
    queueEntry.reject(new Error('QUEUE_TIMEOUT'));

    return true;
  }

  /**
   * Get queue status for identifier
   * @param {string} identifier - User ID or IP address
   * @param {string} queueType - 'user' or 'ip'
   * @returns {Object} Queue status
   */
  getQueueStatus(identifier, queueType) {
    const queueMap = queueType === 'user' ? this.userQueues : this.ipQueues;
    const queue = queueMap.get(identifier) || [];

    return {
      identifier,
      queueType,
      queueSize: queue.length,
      maxQueueSize: this.maxQueueSize,
      isFull: queue.length >= this.maxQueueSize,
      estimatedWaitMs: queue.length * 100, // Rough estimate
      oldestRequestAge: queue.length > 0 ? Date.now() - queue[0].queuedAt : 0,
    };
  }

  /**
   * Get global queue statistics
   * @returns {Object} Global statistics
   */
  getStatistics() {
    return {
      ...this.stats,
      userQueuesCount: this.userQueues.size,
      ipQueuesCount: this.ipQueues.size,
      totalQueuesCount: this.userQueues.size + this.ipQueues.size,
    };
  }

  /**
   * Clear all queues (for testing or shutdown)
   */
  clearAllQueues() {
    // Clear user queues
    for (const queue of this.userQueues.values()) {
      for (const entry of queue) {
        if (entry.timeoutId) {
          clearTimeout(entry.timeoutId);
        }
        if (!entry.processed) {
          entry.processed = true;
          entry.reject(new Error('Queue cleared'));
        }
      }
    }
    this.userQueues.clear();

    // Clear IP queues
    for (const queue of this.ipQueues.values()) {
      for (const entry of queue) {
        if (entry.timeoutId) {
          clearTimeout(entry.timeoutId);
        }
        if (!entry.processed) {
          entry.processed = true;
          entry.reject(new Error('Queue cleared'));
        }
      }
    }
    this.ipQueues.clear();

    this.stats.currentQueuedRequests = 0;
    logger.info('All request queues cleared');
  }

  /**
   * Get queue health status
   * @returns {Object} Health status
   */
  getHealthStatus() {
    const stats = this.getStatistics();
    const avgQueueSize =
      stats.totalQueuesCount > 0
        ? stats.currentQueuedRequests / stats.totalQueuesCount
        : 0;

    return {
      status: stats.currentQueuedRequests > 100 ? 'degraded' : 'healthy',
      currentQueuedRequests: stats.currentQueuedRequests,
      averageQueueSize: avgQueueSize,
      totalQueues: stats.totalQueuesCount,
      totalProcessed: stats.totalProcessed,
      totalExpired: stats.totalExpired,
      totalRejected: stats.totalRejected,
    };
  }
}

// Create singleton instance
let queueServiceInstance = null;

/**
 * Get or create request queue service instance
 * @param {Object} options - Configuration options
 * @returns {RequestQueueService} Queue service instance
 */
export function getRequestQueueService(options = {}) {
  if (!queueServiceInstance) {
    queueServiceInstance = new RequestQueueService(options);
  }
  return queueServiceInstance;
}

export default RequestQueueService;
