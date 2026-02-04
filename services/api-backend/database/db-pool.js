/**
 * Centralized Database Connection Pool Configuration
 *
 * Provides a singleton PostgreSQL connection pool with:
 * - Maximum pool size of 50 connections
 * - Connection timeout of 30 seconds
 * - Idle connection timeout of 10 minutes
 * - Connection reuse and health monitoring
 * - Comprehensive error handling and logging
 *
 * Requirements: 17 (Data Persistence and Storage)
 */

import pg from 'pg';
import logger from '../logger.js';
import { wrapPool } from './query-wrapper.js';
import { initializeQueryTracking } from './query-performance-tracker.js';

const { Pool } = pg;

// Singleton pool instance
let pool = null;
let poolMetrics = {
  totalConnections: 0,
  idleConnections: 0,
  waitingClients: 0,
  errors: 0,
  lastHealthCheck: null,
  healthCheckStatus: 'unknown',
};

/**
 * Database pool configuration
 * All values can be overridden via environment variables
 */
const getPoolConfig = () => ({
  // Connection settings
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432', 10),
  database: process.env.DB_NAME || 'zoidbot',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,

  // SSL configuration
  ssl:
    process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,

  // Pool settings (Requirement 17)
  max: parseInt(process.env.DB_POOL_MAX || '50', 10), // Maximum pool size: 50 connections
  min: parseInt(process.env.DB_POOL_MIN || '5', 10), // Minimum pool size: 5 connections

  // Timeout settings (Requirement 17)
  connectionTimeoutMillis: parseInt(
    process.env.DB_POOL_CONNECT_TIMEOUT || '30000',
    10,
  ), // 30 seconds
  idleTimeoutMillis: parseInt(process.env.DB_POOL_IDLE || '600000', 10), // 10 minutes

  // Connection reuse settings
  allowExitOnIdle: false, // Keep pool alive even when idle

  // Statement timeout (prevent long-running queries)
  statement_timeout: parseInt(process.env.DB_STATEMENT_TIMEOUT || '60000', 10), // 60 seconds
});

/**
 * Initialize the database connection pool
 * Creates a singleton pool instance with health monitoring
 *
 * @returns {Pool} PostgreSQL connection pool
 */
export function initializePool() {
  if (pool) {
    return pool;
  }

  const poolConfig = getPoolConfig();

  // Support for testing without real database (Requirement: CI Stability)
  if (process.env.NODE_ENV === 'test' && !process.env.DB_HOST) {
    logger.info('🟡 [DB Pool] Using mock pool for test environment');
    pool = {
      query: async () => ({
        rows: [
          {
            id: 'mock-id-' + Math.random().toString(36).substr(2, 5),
            user_id: 'mock-user-id',
            tunnel_id: 'mock-tunnel-id',
            email: 'test@example.com',
            tier: 'premium',
            is_active: true,
            status: 'active',
          },
        ],
        rowCount: 1,
      }),
      connect: async () => ({
        query: async () => ({
          rows: [
            {
              id: 'mock-id-' + Math.random().toString(36).substr(2, 5),
              user_id: 'mock-user-id',
              tunnel_id: 'mock-tunnel-id',
              email: 'test@example.com',
              tier: 'premium',
              is_active: true,
              status: 'active',
            },
          ],
          rowCount: 1,
        }),
        release: () => {},
        on: () => {},
      }),
      on: () => {},
      end: async () => {},
      totalCount: 0,
      idleCount: 0,
      waitingCount: 0,
    };
    return pool;
  }

  logger.info('🔵 [DB Pool] Initializing PostgreSQL connection pool', {
    host: poolConfig.host,
    database: poolConfig.database,
    maxConnections: poolConfig.max,
    minConnections: poolConfig.min,
    connectionTimeout: `${poolConfig.connectionTimeoutMillis}ms`,
    idleTimeout: `${poolConfig.idleTimeoutMillis}ms`,
  });

  // Initialize query performance tracking
  initializeQueryTracking();

  console.log('DEBUG: Creating new Pool instance');
  pool = new Pool(poolConfig);
  console.log('DEBUG: Pool instance created successfully');

  // Wrap pool to track query performance
  console.log('DEBUG: Wrapping pool for query tracking');
  wrapPool(pool);
  console.log('DEBUG: Pool wrapped successfully');

  // Handle pool errors
  pool.on('error', (err, _client) => {
    poolMetrics.errors++;
    logger.error('🔴 [DB Pool] Unexpected error on idle client', {
      error: err.message,
      stack: err.stack,
      totalErrors: poolMetrics.errors,
    });
  });

  // Handle client connection
  pool.on('connect', (_client) => {
    poolMetrics.totalConnections++;
    logger.debug('🟢 [DB Pool] New client connected', {
      totalConnections: poolMetrics.totalConnections,
    });
  });

  // Handle client acquisition
  pool.on('acquire', (_client) => {
    logger.debug('🟡 [DB Pool] Client acquired from pool', {
      totalCount: pool.totalCount,
      idleCount: pool.idleCount,
      waitingCount: pool.waitingCount,
    });
  });

  // Handle client release
  pool.on('release', (err, _client) => {
    if (err) {
      logger.error('🔴 [DB Pool] Error releasing client', {
        error: err.message,
      });
    }
  });

  // Handle client removal
  pool.on('remove', (_client) => {
    logger.debug('🔴 [DB Pool] Client removed from pool', {
      totalCount: pool.totalCount,
      idleCount: pool.idleCount,
    });
  });

  logger.info(
    '✅ [DB Pool] PostgreSQL connection pool initialized successfully',
  );

  return pool;
}

/**
 * Get the database connection pool
 * Initializes the pool if it doesn't exist
 *
 * @returns {Pool} PostgreSQL connection pool
 */
export function getPool() {
  if (!pool) {
    return initializePool();
  }
  return pool;
}

/**
 * Get current pool metrics
 *
 * @returns {Object} Pool metrics including connection counts and health status
 */
export function getPoolMetrics() {
  if (!pool) {
    return {
      ...poolMetrics,
      totalCount: 0,
      idleCount: 0,
      waitingCount: 0,
      status: 'not_initialized',
    };
  }

  return {
    ...poolMetrics,
    totalCount: pool.totalCount,
    idleCount: pool.idleCount,
    waitingCount: pool.waitingCount,
    status: 'active',
  };
}

/**
 * Perform a health check on the database connection
 * Tests connectivity and measures response time
 *
 * @returns {Promise<Object>} Health check result with status and response time
 */
export async function healthCheck() {
  const startTime = Date.now();

  try {
    if (!pool) {
      return {
        healthy: false,
        error: 'Pool not initialized',
        timestamp: new Date().toISOString(),
      };
    }

    // Execute a simple query to test connectivity
    const client = await pool.connect();
    try {
      await client.query('SELECT 1 as health_check');
      const responseTime = Date.now() - startTime;

      poolMetrics.lastHealthCheck = new Date().toISOString();
      poolMetrics.healthCheckStatus = 'healthy';

      return {
        healthy: true,
        responseTime,
        poolMetrics: getPoolMetrics(),
        timestamp: poolMetrics.lastHealthCheck,
      };
    } finally {
      client.release();
    }
  } catch (error) {
    const responseTime = Date.now() - startTime;
    poolMetrics.lastHealthCheck = new Date().toISOString();
    poolMetrics.healthCheckStatus = 'unhealthy';
    poolMetrics.errors++;

    logger.error('🔴 [DB Pool] Health check failed', {
      error: error.message,
      responseTime,
    });

    return {
      healthy: false,
      error: error.message,
      responseTime,
      timestamp: poolMetrics.lastHealthCheck,
    };
  }
}

/**
 * Close the database connection pool
 * Gracefully shuts down all connections
 *
 * @returns {Promise<void>}
 */
export async function closePool() {
  if (!pool) {
    logger.warn('⚠️ [DB Pool] Pool already closed or not initialized');
    return;
  }

  logger.info('🔵 [DB Pool] Closing database connection pool');

  try {
    await pool.end();
    pool = null;

    logger.info('✅ [DB Pool] Database connection pool closed successfully');
  } catch (error) {
    logger.error('🔴 [DB Pool] Error closing database pool', {
      error: error.message,
    });
    throw error;
  }
}

/**
 * Execute a query with automatic connection management
 * Convenience method that handles connection acquisition and release
 *
 * @param {string} text - SQL query text
 * @param {Array} params - Query parameters
 * @returns {Promise<Object>} Query result
 */
export async function query(text, params) {
  const pool = getPool();
  return pool.query(text, params);
}

/**
 * Get a client from the pool for transaction management
 * Caller is responsible for releasing the client
 *
 * @returns {Promise<PoolClient>} Database client
 */
export async function getClient() {
  const pool = getPool();
  return pool.connect();
}

// Export pool configuration for reference
export const poolConfig = getPoolConfig();

// Default export
export default {
  initializePool,
  getPool,
  getPoolMetrics,
  healthCheck,
  closePool,
  query,
  getClient,
  poolConfig,
};
