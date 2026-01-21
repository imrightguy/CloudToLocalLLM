/**
 * Read Replica Manager
 *
 * Manages read replica configuration and routing for scaling read operations.
 * Provides:
 * - Read/write routing based on query type
 * - Replica health checking
 * - Automatic failover to primary on replica failure
 * - Load balancing across multiple replicas
 * - Replica status tracking and metrics
 *
 * Requirements: 9.5 (Read replica support for scaling read operations)
 */

import pg from 'pg';
import logger from '../logger.js';

const { Pool } = pg;

/**
 * Read Replica Manager
 * Manages primary and replica database connections
 */
export class ReadReplicaManager {
  constructor() {
    this.primaryPool = null;
    this.replicaPools = [];
    this.replicaConfigs = [];
    this.replicaHealthStatus = new Map();
    this.currentReplicaIndex = 0;
    this.metrics = {
      readQueries: 0,
      writeQueries: 0,
      replicaFailovers: 0,
      healthCheckFailures: 0,
    };
  }

  /**
   * Initialize the read replica manager
   * Sets up primary and replica connections
   *
   * @param {Object} primaryConfig - Primary database configuration
   * @param {Array} replicaConfigs - Array of replica configurations
   * @returns {Promise<void>}
   */
  async initialize(primaryConfig, replicaConfigs = []) {
    logger.info('🔵 [Read Replica] Initializing read replica manager', {
      primaryHost: primaryConfig.host,
      replicaCount: replicaConfigs.length,
    });

    try {
      // Initialize primary pool
      this.primaryPool = new Pool(primaryConfig);
      logger.info('✅ [Read Replica] Primary pool initialized', {
        host: primaryConfig.host,
      });

      // Initialize replica pools
      this.replicaConfigs = replicaConfigs;
      for (let i = 0; i < replicaConfigs.length; i++) {
        const replicaConfig = replicaConfigs[i];
        const replicaPool = new Pool(replicaConfig);

        this.replicaPools.push(replicaPool);
        this.replicaHealthStatus.set(i, {
          healthy: true,
          lastHealthCheck: null,
          failureCount: 0,
          responseTime: 0,
        });

        logger.info('✅ [Read Replica] Replica pool initialized', {
          index: i,
          host: replicaConfig.host,
        });
      }

      // Start health checks
      if (this.replicaPools.length > 0) {
        this.startHealthChecks();
      }

      logger.info(
        '✅ [Read Replica] Read replica manager initialized successfully',
      );
    } catch (error) {
      logger.error(
        '🔴 [Read Replica] Failed to initialize read replica manager',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Determine if a query is a read operation
   * Checks if query starts with SELECT, WITH, or EXPLAIN
   *
   * @param {string} queryText - SQL query text
   * @returns {boolean} True if query is a read operation
   */
  isReadQuery(queryText) {
    if (!queryText || typeof queryText !== 'string') {
      return false;
    }

    const trimmedQuery = queryText.trim().toUpperCase();
    return (
      trimmedQuery.startsWith('SELECT') ||
      trimmedQuery.startsWith('WITH') ||
      trimmedQuery.startsWith('EXPLAIN')
    );
  }

  /**
   * Get the appropriate pool for a query
   * Routes read queries to replicas, write queries to primary
   *
   * @param {string} queryText - SQL query text
   * @returns {Pool} Database pool to use
   */
  getPoolForQuery(queryText) {
    if (!this.isReadQuery(queryText)) {
      // Write query - use primary
      this.metrics.writeQueries++;
      return this.primaryPool;
    }

    // Read query - use replica if available
    this.metrics.readQueries++;

    if (this.replicaPools.length === 0) {
      // No replicas configured - use primary
      return this.primaryPool;
    }

    // Find a healthy replica
    const healthyReplicas = Array.from(this.replicaHealthStatus.entries())
      .filter(([_, status]) => status.healthy)
      .map(([index, _]) => index);

    if (healthyReplicas.length === 0) {
      // No healthy replicas - use primary
      logger.warn(
        '⚠️ [Read Replica] No healthy replicas available, using primary',
      );
      this.metrics.replicaFailovers++;
      return this.primaryPool;
    }

    // Round-robin load balancing across healthy replicas
    const replicaIndex =
      healthyReplicas[this.currentReplicaIndex % healthyReplicas.length];
    this.currentReplicaIndex++;

    return this.replicaPools[replicaIndex];
  }

  /**
   * Execute a query with automatic read/write routing
   *
   * @param {string} queryText - SQL query text
   * @param {Array} params - Query parameters
   * @returns {Promise<Object>} Query result
   */
  async query(queryText, params) {
    const pool = this.getPoolForQuery(queryText);
    const isRead = this.isReadQuery(queryText);

    try {
      const result = await pool.query(queryText, params);
      return result;
    } catch (error) {
      // If read query fails on replica, retry on primary
      if (isRead && pool !== this.primaryPool) {
        logger.warn(
          '⚠️ [Read Replica] Read query failed on replica, retrying on primary',
          {
            error: error.message,
          },
        );

        try {
          const result = await this.primaryPool.query(queryText, params);
          return result;
        } catch (primaryError) {
          logger.error(
            '🔴 [Read Replica] Query failed on both replica and primary',
            {
              error: primaryError.message,
            },
          );
          throw primaryError;
        }
      }

      throw error;
    }
  }

  /**
   * Get a client from the appropriate pool
   * Used for transactions and multi-statement operations
   *
   * @param {string} queryType - 'read' or 'write'
   * @returns {Promise<PoolClient>} Database client
   */
  async getClient(queryType = 'read') {
    const pool =
      queryType === 'write' ? this.primaryPool : this.getHealthyReplicaPool();
    return pool.connect();
  }

  /**
   * Get a healthy replica pool
   * Returns primary if no healthy replicas available
   *
   * @returns {Pool} Database pool
   */
  getHealthyReplicaPool() {
    if (this.replicaPools.length === 0) {
      return this.primaryPool;
    }

    const healthyReplicas = Array.from(this.replicaHealthStatus.entries())
      .filter(([_, status]) => status.healthy)
      .map(([index, _]) => index);

    if (healthyReplicas.length === 0) {
      return this.primaryPool;
    }

    const replicaIndex =
      healthyReplicas[this.currentReplicaIndex % healthyReplicas.length];
    this.currentReplicaIndex++;

    return this.replicaPools[replicaIndex];
  }

  /**
   * Start periodic health checks for all replicas
   * Checks every 30 seconds by default
   */
  startHealthChecks() {
    const interval = parseInt(
      process.env.REPLICA_HEALTH_CHECK_INTERVAL || '30000',
      10,
    );

    this.healthCheckInterval = setInterval(async () => {
      for (let i = 0; i < this.replicaPools.length; i++) {
        await this.checkReplicaHealth(i);
      }
    }, interval);

    logger.info('✅ [Read Replica] Health checks started', {
      interval: `${interval}ms`,
    });
  }

  /**
   * Check health of a specific replica
   *
   * @param {number} replicaIndex - Index of replica to check
   * @returns {Promise<void>}
   */
  async checkReplicaHealth(replicaIndex) {
    const startTime = Date.now();

    try {
      const client = await this.replicaPools[replicaIndex].connect();
      try {
        await client.query('SELECT 1 as health_check');
        const responseTime = Date.now() - startTime;

        const status = this.replicaHealthStatus.get(replicaIndex);
        status.healthy = true;
        status.lastHealthCheck = new Date().toISOString();
        status.failureCount = 0;
        status.responseTime = responseTime;

        logger.debug('✅ [Read Replica] Replica health check passed', {
          replicaIndex,
          responseTime,
        });
      } finally {
        client.release();
      }
    } catch (error) {
      const status = this.replicaHealthStatus.get(replicaIndex);
      status.failureCount++;

      if (status.failureCount >= 3) {
        status.healthy = false;
        logger.error('🔴 [Read Replica] Replica marked as unhealthy', {
          replicaIndex,
          failureCount: status.failureCount,
          error: error.message,
        });
        this.metrics.healthCheckFailures++;
      } else {
        logger.warn('⚠️ [Read Replica] Replica health check failed', {
          replicaIndex,
          failureCount: status.failureCount,
          error: error.message,
        });
      }

      status.lastHealthCheck = new Date().toISOString();
    }
  }

  /**
   * Get replica status information
   *
   * @returns {Object} Status of all replicas
   */
  getReplicaStatus() {
    const status = {};

    for (let i = 0; i < this.replicaConfigs.length; i++) {
      const config = this.replicaConfigs[i];
      const health = this.replicaHealthStatus.get(i);

      status[`replica_${i}`] = {
        host: config.host,
        port: config.port,
        database: config.database,
        healthy: health.healthy,
        lastHealthCheck: health.lastHealthCheck,
        failureCount: health.failureCount,
        responseTime: health.responseTime,
      };
    }

    return status;
  }

  /**
   * Get read replica metrics
   *
   * @returns {Object} Metrics including query counts and failovers
   */
  getMetrics() {
    return {
      ...this.metrics,
      replicaCount: this.replicaPools.length,
      replicaStatus: this.getReplicaStatus(),
    };
  }

  /**
   * Stop health checks
   */
  stopHealthChecks() {
    if (this.healthCheckInterval) {
      clearInterval(this.healthCheckInterval);
      logger.info('✅ [Read Replica] Health checks stopped');
    }
  }

  /**
   * Close all database connections
   *
   * @returns {Promise<void>}
   */
  async close() {
    logger.info('🔵 [Read Replica] Closing read replica manager');

    this.stopHealthChecks();

    try {
      // Close primary pool
      if (this.primaryPool) {
        await this.primaryPool.end();
        logger.info('✅ [Read Replica] Primary pool closed');
      }

      // Close replica pools
      for (let i = 0; i < this.replicaPools.length; i++) {
        await this.replicaPools[i].end();
        logger.info('✅ [Read Replica] Replica pool closed', { index: i });
      }

      logger.info('✅ [Read Replica] Read replica manager closed successfully');
    } catch (error) {
      logger.error('🔴 [Read Replica] Error closing read replica manager', {
        error: error.message,
      });
      throw error;
    }
  }
}

// Singleton instance
let replicaManager = null;

/**
 * Initialize the read replica manager singleton
 *
 * @param {Object} primaryConfig - Primary database configuration
 * @param {Array} replicaConfigs - Array of replica configurations
 * @returns {Promise<ReadReplicaManager>} Initialized replica manager
 */
export async function initializeReadReplicaManager(
  primaryConfig,
  replicaConfigs = [],
) {
  if (replicaManager) {
    return replicaManager;
  }

  replicaManager = new ReadReplicaManager();
  await replicaManager.initialize(primaryConfig, replicaConfigs);

  return replicaManager;
}

/**
 * Get the read replica manager singleton
 *
 * @returns {ReadReplicaManager} Replica manager instance
 */
export function getReadReplicaManager() {
  if (!replicaManager) {
    throw new Error('Read replica manager not initialized');
  }
  return replicaManager;
}

/**
 * Close the read replica manager
 *
 * @returns {Promise<void>}
 */
export async function closeReadReplicaManager() {
  if (replicaManager) {
    await replicaManager.close();
    replicaManager = null;
  }
}

export default {
  ReadReplicaManager,
  initializeReadReplicaManager,
  getReadReplicaManager,
  closeReadReplicaManager,
};
