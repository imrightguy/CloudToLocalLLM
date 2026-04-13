/**
 * Tunnel Failover Service
 *
 * Manages tunnel endpoint failover and load balancing:
 * - Selects healthy endpoints based on priority and weight
 * - Implements automatic failover when endpoints become unhealthy
 * - Tracks endpoint health status and failure counts
 * - Provides weighted round-robin load balancing
 * - Handles endpoint recovery and health restoration
 *
 * Validates: Requirements 4.4
 * - Supports multiple tunnel endpoints for failover
 * - Implements endpoint health checking
 * - Adds automatic failover logic
 *
 * @fileoverview Tunnel failover and load balancing service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class TunnelFailoverService {
  constructor() {
    this.pool = null;
    this.endpointStates = new Map(); // Track endpoint state and failure counts
    this.failoverThreshold = 3; // Number of failures before marking unhealthy
    this.recoveryCheckInterval = 60000; // Check unhealthy endpoints every 60 seconds
    this.recoveryIntervals = new Map();
  }

  /**
   * Initialize the tunnel failover service
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info(
        '[TunnelFailoverService] Tunnel failover service initialized',
      );
    } catch (error) {
      logger.error(
        '[TunnelFailoverService] Failed to initialize tunnel failover service',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Get the best available endpoint for a tunnel using weighted selection
   *
   * Selects endpoint based on:
   * 1. Health status (healthy endpoints only)
   * 2. Priority (higher priority first)
   * 3. Weight (weighted round-robin among same priority)
   *
   * @param {string} tunnelId - Tunnel ID
   * @returns {Promise<Object>} Selected endpoint or null if none available
   */
  async selectEndpoint(tunnelId) {
    try {
      // Get all endpoints for tunnel, ordered by priority and weight
      const result = await this.pool.query(
        `SELECT * FROM tunnel_endpoints 
         WHERE tunnel_id = $1 
         ORDER BY priority DESC, weight DESC`,
        [tunnelId],
      );

      if (result.rows.length === 0) {
        logger.warn('[TunnelFailoverService] No endpoints found for tunnel', {
          tunnelId,
        });
        return null;
      }

      const endpoints = result.rows;

      // Filter healthy endpoints
      const healthyEndpoints = endpoints.filter(
        (e) => e.health_status === 'healthy',
      );

      if (healthyEndpoints.length === 0) {
        logger.warn(
          '[TunnelFailoverService] No healthy endpoints available for tunnel',
          {
            tunnelId,
            totalEndpoints: endpoints.length,
          },
        );

        // Fallback: return highest priority endpoint even if unhealthy
        return endpoints[0];
      }

      // Group by priority
      const byPriority = {};
      for (const endpoint of healthyEndpoints) {
        if (!byPriority[endpoint.priority]) {
          byPriority[endpoint.priority] = [];
        }
        byPriority[endpoint.priority].push(endpoint);
      }

      // Get highest priority group
      const highestPriority = Math.max(...Object.keys(byPriority).map(Number));
      const priorityGroup = byPriority[highestPriority];

      // Weighted round-robin selection within priority group
      const selected = this.weightedSelection(priorityGroup);

      logger.debug('[TunnelFailoverService] Endpoint selected for tunnel', {
        tunnelId,
        endpointId: selected.id,
        url: selected.url,
        priority: selected.priority,
        weight: selected.weight,
      });

      return selected;
    } catch (error) {
      logger.error('[TunnelFailoverService] Failed to select endpoint', {
        tunnelId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Perform weighted round-robin selection from a list of endpoints
   *
   * @param {Array} endpoints - List of endpoints with weight property
   * @returns {Object} Selected endpoint
   */
  weightedSelection(endpoints) {
    if (endpoints.length === 0) {
      return null;
    }

    if (endpoints.length === 1) {
      return endpoints[0];
    }

    // Calculate total weight
    const totalWeight = endpoints.reduce((sum, e) => sum + (e.weight || 1), 0);

    // Generate random number between 0 and totalWeight
    let random = Math.random() * totalWeight;

    // Select endpoint based on weighted distribution
    for (const endpoint of endpoints) {
      random -= endpoint.weight || 1;
      if (random <= 0) {
        return endpoint;
      }
    }

    // Fallback to first endpoint
    return endpoints[0];
  }

  /**
   * Record endpoint failure and update health status
   *
   * @param {string} endpointId - Endpoint ID
   * @param {string} tunnelId - Tunnel ID
   * @param {string} error - Error message
   * @returns {Promise<Object>} Updated endpoint state
   */
  async recordEndpointFailure(endpointId, tunnelId, error) {
    try {
      // Get or initialize endpoint state
      if (!this.endpointStates.has(endpointId)) {
        this.endpointStates.set(endpointId, {
          failureCount: 0,
          lastFailure: null,
          isUnhealthy: false,
        });
      }

      const state = this.endpointStates.get(endpointId);
      state.failureCount++;
      state.lastFailure = new Date();

      logger.debug('[TunnelFailoverService] Endpoint failure recorded', {
        endpointId,
        tunnelId,
        failureCount: state.failureCount,
        error,
      });

      // Mark as unhealthy if threshold exceeded
      if (state.failureCount >= this.failoverThreshold && !state.isUnhealthy) {
        await this.markEndpointUnhealthy(endpointId);
        state.isUnhealthy = true;

        // Start recovery checks for this endpoint
        this.startRecoveryChecks(endpointId, tunnelId);

        logger.warn('[TunnelFailoverService] Endpoint marked as unhealthy', {
          endpointId,
          tunnelId,
          failureCount: state.failureCount,
        });
      }

      return state;
    } catch (error) {
      logger.error(
        '[TunnelFailoverService] Failed to record endpoint failure',
        {
          endpointId,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Record endpoint success and reset failure count
   *
   * @param {string} endpointId - Endpoint ID
   * @returns {Promise<void>}
   */
  async recordEndpointSuccess(endpointId) {
    try {
      if (this.endpointStates.has(endpointId)) {
        const state = this.endpointStates.get(endpointId);
        state.failureCount = Math.max(0, state.failureCount - 1);

        logger.debug('[TunnelFailoverService] Endpoint success recorded', {
          endpointId,
          failureCount: state.failureCount,
        });
      }
    } catch (error) {
      logger.error(
        '[TunnelFailoverService] Failed to record endpoint success',
        {
          endpointId,
          error: error.message,
        },
      );
    }
  }

  /**
   * Mark endpoint as unhealthy in database
   *
   * @param {string} endpointId - Endpoint ID
   * @returns {Promise<void>}
   */
  async markEndpointUnhealthy(endpointId) {
    try {
      await this.pool.query(
        `UPDATE tunnel_endpoints 
         SET health_status = $1, last_health_check = NOW() 
         WHERE id = $2`,
        ['unhealthy', endpointId],
      );

      logger.info(
        '[TunnelFailoverService] Endpoint marked unhealthy in database',
        {
          endpointId,
        },
      );
    } catch (error) {
      logger.error(
        '[TunnelFailoverService] Failed to mark endpoint unhealthy',
        {
          endpointId,
          error: error.message,
        },
      );
    }
  }

  /**
   * Mark endpoint as healthy in database
   *
   * @param {string} endpointId - Endpoint ID
   * @returns {Promise<void>}
   */
  async markEndpointHealthy(endpointId) {
    try {
      await this.pool.query(
        `UPDATE tunnel_endpoints 
         SET health_status = $1, last_health_check = NOW() 
         WHERE id = $2`,
        ['healthy', endpointId],
      );

      logger.info(
        '[TunnelFailoverService] Endpoint marked healthy in database',
        {
          endpointId,
        },
      );
    } catch (error) {
      logger.error('[TunnelFailoverService] Failed to mark endpoint healthy', {
        endpointId,
        error: error.message,
      });
    }
  }

  /**
   * Start periodic recovery checks for an unhealthy endpoint
   *
   * @param {string} endpointId - Endpoint ID
   * @param {string} tunnelId - Tunnel ID
   */
  startRecoveryChecks(endpointId, tunnelId) {
    if (this.recoveryIntervals.has(endpointId)) {
      return; // Already checking
    }

    const interval = setInterval(async () => {
      try {
        await this.checkEndpointRecovery(endpointId, tunnelId);
      } catch (error) {
        logger.error('[TunnelFailoverService] Recovery check failed', {
          endpointId,
          error: error.message,
        });
      }
    }, this.recoveryCheckInterval);

    this.recoveryIntervals.set(endpointId, interval);
    logger.debug(
      '[TunnelFailoverService] Recovery checks started for endpoint',
      {
        endpointId,
        tunnelId,
      },
    );
  }

  /**
   * Stop recovery checks for an endpoint
   *
   * @param {string} endpointId - Endpoint ID
   */
  stopRecoveryChecks(endpointId) {
    const interval = this.recoveryIntervals.get(endpointId);
    if (interval) {
      clearInterval(interval);
      this.recoveryIntervals.delete(endpointId);
      logger.debug(
        '[TunnelFailoverService] Recovery checks stopped for endpoint',
        {
          endpointId,
        },
      );
    }
  }

  /**
   * Check if an unhealthy endpoint has recovered
   *
   * @param {string} endpointId - Endpoint ID
   * @param {string} tunnelId - Tunnel ID
   * @returns {Promise<boolean>} True if endpoint recovered
   */
  async checkEndpointRecovery(endpointId, tunnelId) {
    try {
      // Get endpoint details
      const result = await this.pool.query(
        'SELECT * FROM tunnel_endpoints WHERE id = $1',
        [endpointId],
      );

      if (result.rows.length === 0) {
        this.stopRecoveryChecks(endpointId);
        return false;
      }

      const endpoint = result.rows[0];

      // Perform health check
      const healthStatus = await this.checkEndpointHealth(endpoint.url);

      if (healthStatus === 'healthy') {
        // Endpoint recovered
        await this.markEndpointHealthy(endpointId);

        // Reset failure count
        if (this.endpointStates.has(endpointId)) {
          const state = this.endpointStates.get(endpointId);
          state.failureCount = 0;
          state.isUnhealthy = false;
        }

        // Stop recovery checks
        this.stopRecoveryChecks(endpointId);

        logger.info('[TunnelFailoverService] Endpoint recovered', {
          endpointId,
          tunnelId,
          url: endpoint.url,
        });

        return true;
      }

      return false;
    } catch (error) {
      logger.error(
        '[TunnelFailoverService] Failed to check endpoint recovery',
        {
          endpointId,
          error: error.message,
        },
      );
      return false;
    }
  }

  /**
   * Check health of a single endpoint
   *
   * @param {string} url - Endpoint URL
   * @returns {Promise<string>} Health status (healthy, unhealthy)
   */
  async checkEndpointHealth(url) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000); // 5 second timeout

      const response = await fetch(url, {
        method: 'HEAD',
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      // Consider 2xx and 3xx as healthy
      if (response.status >= 200 && response.status < 400) {
        return 'healthy';
      }

      return 'unhealthy';
    } catch (error) {
      logger.debug('[TunnelFailoverService] Endpoint health check failed', {
        url,
        error: error.message,
      });
      return 'unhealthy';
    }
  }

  /**
   * Get failover status for a tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @returns {Promise<Object>} Failover status
   */
  async getFailoverStatus(tunnelId, userId) {
    try {
      // Verify tunnel ownership
      const tunnelResult = await this.pool.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      // Get endpoints
      const endpointsResult = await this.pool.query(
        'SELECT * FROM tunnel_endpoints WHERE tunnel_id = $1',
        [tunnelId],
      );

      const endpoints = endpointsResult.rows.map((endpoint) => {
        const state = this.endpointStates.get(endpoint.id) || {
          failureCount: 0,
          lastFailure: null,
          isUnhealthy: false,
        };

        return {
          id: endpoint.id,
          url: endpoint.url,
          priority: endpoint.priority,
          weight: endpoint.weight,
          healthStatus: endpoint.health_status,
          lastHealthCheck: endpoint.last_health_check,
          failureCount: state.failureCount,
          lastFailure: state.lastFailure,
          isUnhealthy: state.isUnhealthy,
          isRecovering: this.recoveryIntervals.has(endpoint.id),
        };
      });

      const healthyCount = endpoints.filter(
        (e) => e.healthStatus === 'healthy',
      ).length;
      const unhealthyCount = endpoints.filter(
        (e) => e.healthStatus === 'unhealthy',
      ).length;

      return {
        tunnelId,
        endpoints,
        summary: {
          total: endpoints.length,
          healthy: healthyCount,
          unhealthy: unhealthyCount,
          recovering: Array.from(this.recoveryIntervals.keys()).filter((id) =>
            endpoints.some((e) => e.id === id),
          ).length,
        },
      };
    } catch (error) {
      logger.error('[TunnelFailoverService] Failed to get failover status', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Manually trigger failover to a specific endpoint
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} endpointId - Endpoint ID to failover to
   * @param {string} userId - User ID (for authorization)
   * @returns {Promise<Object>} Selected endpoint
   */
  async manualFailover(tunnelId, endpointId, userId) {
    try {
      // Verify tunnel ownership
      const tunnelResult = await this.pool.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      // Verify endpoint belongs to tunnel
      const endpointResult = await this.pool.query(
        'SELECT * FROM tunnel_endpoints WHERE id = $1 AND tunnel_id = $2',
        [endpointId, tunnelId],
      );

      if (endpointResult.rows.length === 0) {
        throw new Error('Endpoint not found for this tunnel');
      }

      const endpoint = endpointResult.rows[0];

      logger.info('[TunnelFailoverService] Manual failover triggered', {
        tunnelId,
        endpointId,
        url: endpoint.url,
      });

      return endpoint;
    } catch (error) {
      logger.error(
        '[TunnelFailoverService] Failed to perform manual failover',
        {
          tunnelId,
          endpointId,
          userId,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Reset endpoint failure count
   *
   * @param {string} endpointId - Endpoint ID
   * @returns {Promise<void>}
   */
  async resetEndpointFailureCount(endpointId) {
    try {
      if (this.endpointStates.has(endpointId)) {
        const state = this.endpointStates.get(endpointId);
        state.failureCount = 0;
        state.lastFailure = null;
      }

      logger.info('[TunnelFailoverService] Endpoint failure count reset', {
        endpointId,
      });
    } catch (error) {
      logger.error(
        '[TunnelFailoverService] Failed to reset endpoint failure count',
        {
          endpointId,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Cleanup resources - stop all recovery intervals and clear state
   *
   * Call this when shutting down the service to prevent memory leaks
   */
  cleanup() {
    try {
      // Stop all recovery check intervals
      for (const [endpointId, interval] of this.recoveryIntervals.entries()) {
        clearInterval(interval);
        logger.debug(
          '[TunnelFailoverService] Stopping recovery checks during cleanup',
          {
            endpointId,
          },
        );
      }

      // Clear all state
      this.recoveryIntervals.clear();
      this.endpointStates.clear();

      logger.info('[TunnelFailoverService] Cleanup completed', {
        intervalsCleared: this.recoveryIntervals.size,
        statesCleared: this.endpointStates.size,
      });
    } catch (error) {
      logger.error('[TunnelFailoverService] Error during cleanup', {
        error: error.message,
      });
    }
  }
}
