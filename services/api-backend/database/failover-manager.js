/**
 * Database Failover and High Availability Manager
 *
 * Manages database failover and high availability with:
 * - Automatic failover from primary to standby
 * - Health monitoring and detection
 * - Failover state management
 * - Automatic recovery and promotion
 * - Metrics and logging
 * - Configuration management
 *
 * Requirements: 9.9 (Database failover and high availability)
 */

import pg from 'pg';
import logger from '../logger.js';

const { Pool } = pg;

/**
 * Failover states
 */
export const FailoverState = {
  HEALTHY: 'healthy',
  DEGRADED: 'degraded',
  FAILOVER_IN_PROGRESS: 'failover_in_progress',
  FAILOVER_COMPLETE: 'failover_complete',
  RECOVERY_IN_PROGRESS: 'recovery_in_progress',
  UNKNOWN: 'unknown',
};

/**
 * Database Failover Manager
 * Manages primary and standby database connections with automatic failover
 */
export class FailoverManager {
  constructor() {
    this.primaryConfig = null;
    this.standbyConfigs = [];
    this.primaryPool = null;
    this.standbyPools = [];
    this.currentPrimaryIndex = 0;
    this.failoverState = FailoverState.UNKNOWN;
    this.lastFailoverTime = null;
    this.failoverCount = 0;
    this.healthCheckInterval = null;
    this.metrics = {
      failovers: 0,
      healthCheckFailures: 0,
      recoveries: 0,
      totalDowntime: 0,
      lastStateChange: null,
    };
    this.standbyHealthStatus = new Map();
    this.primaryHealthStatus = {
      healthy: false,
      lastHealthCheck: null,
      failureCount: 0,
      responseTime: 0,
      downSince: null,
    };
  }

  /**
   * Initialize the failover manager
   * Sets up primary and standby connections
   *
   * @param {Object} primaryConfig - Primary database configuration
   * @param {Array} standbyConfigs - Array of standby database configurations
   * @returns {Promise<void>}
   */
  async initialize(primaryConfig, standbyConfigs = []) {
    logger.info('🔵 [Failover] Initializing database failover manager', {
      primaryHost: primaryConfig.host,
      standbyCount: standbyConfigs.length,
    });

    try {
      this.primaryConfig = primaryConfig;
      this.standbyConfigs = standbyConfigs;

      // Initialize primary pool
      this.primaryPool = new Pool(primaryConfig);
      logger.info('✅ [Failover] Primary pool initialized', {
        host: primaryConfig.host,
      });

      // Initialize standby pools
      for (let i = 0; i < standbyConfigs.length; i++) {
        const standbyConfig = standbyConfigs[i];
        const standbyPool = new Pool(standbyConfig);

        this.standbyPools.push(standbyPool);
        this.standbyHealthStatus.set(i, {
          healthy: false,
          lastHealthCheck: null,
          failureCount: 0,
          responseTime: 0,
          promotionEligible: false,
        });

        logger.info('✅ [Failover] Standby pool initialized', {
          index: i,
          host: standbyConfig.host,
        });
      }

      // Perform initial health checks
      await this.checkPrimaryHealth();
      for (let i = 0; i < this.standbyPools.length; i++) {
        await this.checkStandbyHealth(i);
      }

      // Update failover state
      this.updateFailoverState();

      // Start periodic health checks
      this.startHealthChecks();

      logger.info(
        '✅ [Failover] Database failover manager initialized successfully',
        {
          state: this.failoverState,
        },
      );
    } catch (error) {
      logger.error('🔴 [Failover] Failed to initialize failover manager', {
        error: error.message,
      });
      this.failoverState = FailoverState.UNKNOWN;
      throw error;
    }
  }

  /**
   * Get the current active pool (primary or promoted standby)
   *
   * @returns {Pool} Active database pool
   */
  getActivePool() {
    if (this.primaryHealthStatus.healthy && this.primaryPool) {
      return this.primaryPool;
    }

    // Primary is down, find a healthy standby
    for (let i = 0; i < this.standbyPools.length; i++) {
      const status = this.standbyHealthStatus.get(i);
      if (status && status.healthy) {
        logger.warn('⚠️ [Failover] Using standby as active pool', {
          standbyIndex: i,
          host: this.standbyConfigs[i].host,
        });
        return this.standbyPools[i];
      }
    }

    // No healthy standby, return primary (will fail)
    logger.error('🔴 [Failover] No healthy database available');
    return this.primaryPool;
  }

  /**
   * Execute a query using the active pool
   *
   * @param {string} queryText - SQL query text
   * @param {Array} params - Query parameters
   * @returns {Promise<Object>} Query result
   */
  async query(queryText, params) {
    const pool = this.getActivePool();

    try {
      const result = await pool.query(queryText, params);
      return result;
    } catch (error) {
      logger.error('🔴 [Failover] Query execution failed', {
        error: error.message,
        pool: this.primaryHealthStatus.healthy ? 'primary' : 'standby',
      });
      throw error;
    }
  }

  /**
   * Get a client from the active pool
   *
   * @returns {Promise<PoolClient>} Database client
   */
  async getClient() {
    const pool = this.getActivePool();
    return pool.connect();
  }

  /**
   * Check health of the primary database
   *
   * @returns {Promise<void>}
   */
  async checkPrimaryHealth() {
    const startTime = Date.now();

    try {
      const client = await this.primaryPool.connect();
      try {
        await client.query('SELECT 1 as health_check');
        const responseTime = Date.now() - startTime;

        const wasUnhealthy = !this.primaryHealthStatus.healthy;

        this.primaryHealthStatus.healthy = true;
        this.primaryHealthStatus.lastHealthCheck = new Date().toISOString();
        this.primaryHealthStatus.failureCount = 0;
        this.primaryHealthStatus.responseTime = responseTime;
        this.primaryHealthStatus.downSince = null;

        if (wasUnhealthy) {
          logger.info('✅ [Failover] Primary database recovered', {
            responseTime,
          });
          this.metrics.recoveries++;
        } else {
          logger.debug('✅ [Failover] Primary health check passed', {
            responseTime,
          });
        }

        this.updateFailoverState();
      } finally {
        client.release();
      }
    } catch (error) {
      this.primaryHealthStatus.failureCount++;

      if (this.primaryHealthStatus.failureCount === 1) {
        this.primaryHealthStatus.downSince = new Date().toISOString();
      }

      if (this.primaryHealthStatus.failureCount >= 3) {
        const wasHealthy = this.primaryHealthStatus.healthy;
        this.primaryHealthStatus.healthy = false;

        if (wasHealthy) {
          logger.error('🔴 [Failover] Primary database marked as unhealthy', {
            failureCount: this.primaryHealthStatus.failureCount,
            error: error.message,
          });
          this.metrics.healthCheckFailures++;
          this.updateFailoverState();

          // Trigger failover if needed
          await this.triggerFailoverIfNeeded();
        }
      } else {
        logger.warn('⚠️ [Failover] Primary health check failed', {
          failureCount: this.primaryHealthStatus.failureCount,
          error: error.message,
        });
      }

      this.primaryHealthStatus.lastHealthCheck = new Date().toISOString();
    }
  }

  /**
   * Check health of a specific standby database
   *
   * @param {number} standbyIndex - Index of standby to check
   * @returns {Promise<void>}
   */
  async checkStandbyHealth(standbyIndex) {
    const startTime = Date.now();

    try {
      const client = await this.standbyPools[standbyIndex].connect();
      try {
        await client.query('SELECT 1 as health_check');
        const responseTime = Date.now() - startTime;

        const status = this.standbyHealthStatus.get(standbyIndex);
        status.healthy = true;
        status.lastHealthCheck = new Date().toISOString();
        status.failureCount = 0;
        status.responseTime = responseTime;
        status.promotionEligible = true;

        logger.debug('✅ [Failover] Standby health check passed', {
          standbyIndex,
          responseTime,
        });

        this.updateFailoverState();
      } finally {
        client.release();
      }
    } catch (error) {
      const status = this.standbyHealthStatus.get(standbyIndex);
      status.failureCount++;

      if (status.failureCount >= 3) {
        status.healthy = false;
        status.promotionEligible = false;

        logger.error('🔴 [Failover] Standby marked as unhealthy', {
          standbyIndex,
          failureCount: status.failureCount,
          error: error.message,
        });
        this.metrics.healthCheckFailures++;
      } else {
        logger.warn('⚠️ [Failover] Standby health check failed', {
          standbyIndex,
          failureCount: status.failureCount,
          error: error.message,
        });
      }

      status.lastHealthCheck = new Date().toISOString();
    }
  }

  /**
   * Trigger failover if primary is down and healthy standby is available
   *
   * @returns {Promise<void>}
   */
  async triggerFailoverIfNeeded() {
    if (this.primaryHealthStatus.healthy) {
      return; // Primary is healthy, no failover needed
    }

    // Find a healthy standby
    let healthyStandbyIndex = -1;
    for (let i = 0; i < this.standbyPools.length; i++) {
      const status = this.standbyHealthStatus.get(i);
      if (status && status.healthy && status.promotionEligible) {
        healthyStandbyIndex = i;
        break;
      }
    }

    if (healthyStandbyIndex === -1) {
      logger.error('🔴 [Failover] No healthy standby available for failover');
      return;
    }

    await this.performFailover(healthyStandbyIndex);
  }

  /**
   * Perform failover to a standby database
   *
   * @param {number} standbyIndex - Index of standby to promote
   * @returns {Promise<void>}
   */
  async performFailover(standbyIndex) {
    logger.warn('⚠️ [Failover] Starting failover to standby', {
      standbyIndex,
      host: this.standbyConfigs[standbyIndex].host,
    });

    this.failoverState = FailoverState.FAILOVER_IN_PROGRESS;
    this.metrics.lastStateChange = new Date().toISOString();

    try {
      // Verify standby is ready
      const client = await this.standbyPools[standbyIndex].connect();
      try {
        await client.query('SELECT 1 as failover_check');
      } finally {
        client.release();
      }

      // Update current primary index
      this.currentPrimaryIndex = standbyIndex;
      this.lastFailoverTime = new Date().toISOString();
      this.failoverCount++;
      this.metrics.failovers++;

      logger.info('✅ [Failover] Failover completed successfully', {
        standbyIndex,
        failoverCount: this.failoverCount,
        timestamp: this.lastFailoverTime,
      });

      this.failoverState = FailoverState.FAILOVER_COMPLETE;
      this.metrics.lastStateChange = new Date().toISOString();

      this.updateFailoverState();
    } catch (error) {
      logger.error('🔴 [Failover] Failover failed', {
        standbyIndex,
        error: error.message,
      });

      this.failoverState = FailoverState.DEGRADED;
      this.metrics.lastStateChange = new Date().toISOString();
      throw error;
    }
  }

  /**
   * Update the overall failover state based on component health
   */
  updateFailoverState() {
    const primaryHealthy = this.primaryHealthStatus.healthy;
    const healthyStandbyCount = Array.from(
      this.standbyHealthStatus.values(),
    ).filter((s) => s.healthy).length;

    if (primaryHealthy && healthyStandbyCount > 0) {
      this.failoverState = FailoverState.HEALTHY;
    } else if (primaryHealthy || healthyStandbyCount > 0) {
      this.failoverState = FailoverState.DEGRADED;
    } else {
      this.failoverState = FailoverState.UNKNOWN;
    }

    logger.debug('🔵 [Failover] Failover state updated', {
      state: this.failoverState,
      primaryHealthy,
      healthyStandbyCount,
    });
  }

  /**
   * Start periodic health checks
   */
  startHealthChecks() {
    const interval = parseInt(
      process.env.FAILOVER_HEALTH_CHECK_INTERVAL || '10000',
      10,
    );

    this.healthCheckInterval = setInterval(async () => {
      try {
        await this.checkPrimaryHealth();

        for (let i = 0; i < this.standbyPools.length; i++) {
          await this.checkStandbyHealth(i);
        }
      } catch (error) {
        logger.error('🔴 [Failover] Error during health check cycle', {
          error: error.message,
        });
      }
    }, interval);

    logger.info('✅ [Failover] Health checks started', {
      interval: `${interval}ms`,
    });
  }

  /**
   * Stop health checks
   */
  stopHealthChecks() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
      this.healthCheckInterval = null;
      logger.info('✅ [Failover] Health checks stopped');
    }
  }

  /**
   * Get failover status information
   *
   * @returns {Object} Failover status
   */
  getFailoverStatus() {
    const standbyStatus = {};

    for (let i = 0; i < this.standbyConfigs.length; i++) {
      const config = this.standbyConfigs[i];
      const health = this.standbyHealthStatus.get(i);

      standbyStatus[`standby_${i}`] = {
        host: config.host,
        port: config.port,
        database: config.database,
        healthy: health.healthy,
        lastHealthCheck: health.lastHealthCheck,
        failureCount: health.failureCount,
        responseTime: health.responseTime,
        promotionEligible: health.promotionEligible,
      };
    }

    return {
      state: this.failoverState,
      primary: {
        host: this.primaryConfig.host,
        port: this.primaryConfig.port,
        database: this.primaryConfig.database,
        healthy: this.primaryHealthStatus.healthy,
        lastHealthCheck: this.primaryHealthStatus.lastHealthCheck,
        failureCount: this.primaryHealthStatus.failureCount,
        responseTime: this.primaryHealthStatus.responseTime,
        downSince: this.primaryHealthStatus.downSince,
      },
      standbys: standbyStatus,
      currentPrimaryIndex: this.currentPrimaryIndex,
      lastFailoverTime: this.lastFailoverTime,
      failoverCount: this.failoverCount,
    };
  }

  /**
   * Get failover metrics
   *
   * @returns {Object} Failover metrics
   */
  getMetrics() {
    return {
      ...this.metrics,
      state: this.failoverState,
      failoverStatus: this.getFailoverStatus(),
    };
  }

  /**
   * Close all database connections
   *
   * @returns {Promise<void>}
   */
  async close() {
    logger.info('🔵 [Failover] Closing failover manager');

    this.stopHealthChecks();

    try {
      // Close primary pool
      if (this.primaryPool) {
        await this.primaryPool.end();
        logger.info('✅ [Failover] Primary pool closed');
      }

      // Close standby pools
      for (let i = 0; i < this.standbyPools.length; i++) {
        await this.standbyPools[i].end();
        logger.info('✅ [Failover] Standby pool closed', { index: i });
      }

      logger.info('✅ [Failover] Failover manager closed successfully');
    } catch (error) {
      logger.error('🔴 [Failover] Error closing failover manager', {
        error: error.message,
      });
      throw error;
    }
  }
}

// Singleton instance
let failoverManager = null;

/**
 * Initialize the failover manager singleton
 *
 * @param {Object} primaryConfig - Primary database configuration
 * @param {Array} standbyConfigs - Array of standby configurations
 * @returns {Promise<FailoverManager>} Initialized failover manager
 */
export async function initializeFailoverManager(
  primaryConfig,
  standbyConfigs = [],
) {
  if (failoverManager) {
    return failoverManager;
  }

  failoverManager = new FailoverManager();
  await failoverManager.initialize(primaryConfig, standbyConfigs);

  return failoverManager;
}

/**
 * Get the failover manager singleton
 *
 * @returns {FailoverManager} Failover manager instance
 */
export function getFailoverManager() {
  if (!failoverManager) {
    throw new Error('Failover manager not initialized');
  }
  return failoverManager;
}

/**
 * Close the failover manager
 *
 * @returns {Promise<void>}
 */
export async function closeFailoverManager() {
  if (failoverManager) {
    await failoverManager.close();
    failoverManager = null;
  }
}

export default {
  FailoverManager,
  FailoverState,
  initializeFailoverManager,
  getFailoverManager,
  closeFailoverManager,
};
