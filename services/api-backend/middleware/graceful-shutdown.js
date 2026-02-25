/**
 * Graceful Shutdown Manager for CloudToLocalLLM API Backend
 *
 * Manages graceful shutdown of the HTTP server with in-flight request completion.
 * Ensures all active requests are completed before closing the server.
 *
 * @fileoverview Graceful shutdown management
 * @version 1.0.0
 */

import logger from '../logger.js';

/**
 * Create graceful shutdown manager
 * @param {Object} server - HTTP server instance
 * @param {Object} options - Configuration options
 * @returns {Object} Shutdown manager with control methods
 */
export function createGracefulShutdownManager(server, options = {}) {
  const { shutdownTimeoutMs = 10000, onShutdown = null } = options;

  let isShuttingDown = false;
  const activeRequests = new Set();

  /**
   * Track active requests
   */
  server.on('connection', (socket) => {
    activeRequests.add(socket);

    socket.on('close', () => {
      activeRequests.delete(socket);
    });
  });

  /**
   * Handle request completion
   */
  server.on('request', (req, res) => {
    // Mark request as active
    const requestId = `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    req.requestId = requestId;

    // Log request start
    logger.debug('Request started', {
      requestId,
      method: req.method,
      path: req.url,
    });

    // Track response completion
    const originalEnd = res.end;
    res.end = function (...args) {
      logger.debug('Request completed', {
        requestId,
        method: req.method,
        path: req.url,
        statusCode: res.statusCode,
      });

      return originalEnd.apply(this, args);
    };
  });

  /**
   * Initiate graceful shutdown
   */
  async function shutdown() {
    if (isShuttingDown) {
      logger.warn('Shutdown already in progress');
      return;
    }

    isShuttingDown = true;
    logger.info('Starting graceful shutdown', {
      activeConnections: activeRequests.size,
      shutdownTimeoutMs,
    });

    // Call custom shutdown handler if provided
    if (onShutdown && typeof onShutdown === 'function') {
      try {
        await onShutdown();
      } catch (error) {
        logger.error('Error in custom shutdown handler', {
          error: error.message,
        });
      }
    }

    // Stop accepting new connections
    server.close(() => {
      logger.info('Server closed, no longer accepting connections');
    });

    // Close all idle connections
    for (const socket of activeRequests) {
      if (!socket.writable) {
        socket.destroy();
        activeRequests.delete(socket);
      }
    }

    // Wait for in-flight requests to complete
    const shutdownPromise = new Promise((resolve) => {
      const checkInterval = setInterval(() => {
        if (activeRequests.size === 0) {
          clearInterval(checkInterval);
          logger.info('All in-flight requests completed');
          resolve();
        }
      }, 100);

      // Force shutdown after timeout
      setTimeout(() => {
        clearInterval(checkInterval);
        logger.warn('Shutdown timeout reached, forcing closure', {
          remainingConnections: activeRequests.size,
        });

        // Force close remaining connections
        for (const socket of activeRequests) {
          socket.destroy();
        }

        resolve();
      }, shutdownTimeoutMs);
    });

    await shutdownPromise;
    logger.info('Graceful shutdown completed');
  }

  /**
   * Get current active request count
   */
  function getActiveRequestCount() {
    return activeRequests.size;
  }

  /**
   * Check if shutdown is in progress
   */
  function isShutdownInProgress() {
    return isShuttingDown;
  }

  return {
    shutdown,
    getActiveRequestCount,
    isShutdownInProgress,
  };
}

/**
 * Setup graceful shutdown handlers
 * @param {Object} server - HTTP server instance
 * @param {Object} options - Configuration options
 * @returns {Object} Shutdown manager
 */
export function setupGracefulShutdown(server, options = {}) {
  const shutdownManager = createGracefulShutdownManager(server, options);

  // Handle SIGTERM signal
  process.on('SIGTERM', async () => {
    logger.info('Received SIGTERM signal');
    await shutdownManager.shutdown();
    process.exit(0);
  });

  // Handle SIGINT signal (Ctrl+C)
  process.on('SIGINT', async () => {
    logger.info('Received SIGINT signal');
    await shutdownManager.shutdown();
    process.exit(0);
  });

  // Handle uncaught exceptions
  process.on('uncaughtException', (error) => {
    logger.error('Uncaught exception', {
      error: error.message,
      stack: error.stack,
    });
    process.exit(1);
  });

  // Handle unhandled promise rejections
  process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled promise rejection', {
      reason: reason instanceof Error ? reason.message : String(reason),
      promise: String(promise),
    });
    process.exit(1);
  });

  return shutdownManager;
}

export default {
  createGracefulShutdownManager,
  setupGracefulShutdown,
};
