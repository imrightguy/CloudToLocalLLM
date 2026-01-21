/**
 * Database Connection Pool Monitoring Service
 *
 * Provides periodic health checks and monitoring for the database connection pool:
 * - Periodic health check queries every 30 seconds
 * - Connection pool metrics logging
 * - Alerts on connection pool exhaustion
 * - Automatic recovery attempts
 *
 * Requirements: 17 (Data Persistence and Storage)
 */

import logger from '../logger.js';
import { getPool, getPoolMetrics, healthCheck } from './db-pool.js';
import { sendAlert } from '../services/alerting-service.js';

// Monitoring configuration
const HEALTH_CHECK_INTERVAL = parseInt(
  process.env.DB_HEALTH_CHECK_INTERVAL || '30000',
  10
); // 30 seconds
const POOL_EXHAUSTION_THRESHOLD = 0.9; // Alert when 90% of pool is in use
const METRICS_LOG_INTERVAL = parseInt(
  process.env.DB_METRICS_LOG_INTERVAL || '60000',
  10
); // 60 seconds

let healthCheckTimer = null;
let metricsLogTimer = null;
let isMonitoring = false;

/**
 * Start monitoring the database connection pool
 * Begins periodic health checks and metrics logging
 */
export function startMonitoring() {
  if (isMonitoring) {
    logger.warn('⚠️ [Pool Monitor] Monitoring already started');
    return;
  }

  logger.info('🔵 [Pool Monitor] Starting database pool monitoring', {
    healthCheckInterval: `${HEALTH_CHECK_INTERVAL}ms`,
    metricsLogInterval: `${METRICS_LOG_INTERVAL}ms`,
    exhaustionThreshold: `${POOL_EXHAUSTION_THRESHOLD * 100}%`,
  });

  isMonitoring = true;

  // Start periodic health checks
  healthCheckTimer = setInterval(async () => {
    try {
      await performHealthCheck();
    } catch (error) {
      logger.error('🔴 [Pool Monitor] Health check error', {
        error: error.message,
      });
    }
  }, HEALTH_CHECK_INTERVAL);

  // Start periodic metrics logging
  metricsLogTimer = setInterval(() => {
    try {
      logPoolMetrics();
    } catch (error) {
      logger.error('🔴 [Pool Monitor] Metrics logging error', {
        error: error.message,
      });
    }
  }, METRICS_LOG_INTERVAL);

  // Perform initial health check
  performHealthCheck().catch((error) => {
    logger.error('🔴 [Pool Monitor] Initial health check failed', {
      error: error.message,
    });
  });

  logger.info('✅ [Pool Monitor] Database pool monitoring started');
}

/**
 * Stop monitoring the database connection pool
 * Clears all monitoring timers
 */
export function stopMonitoring() {
  if (!isMonitoring) {
    logger.warn('⚠️ [Pool Monitor] Monitoring not started');
    return;
  }

  logger.info('🔵 [Pool Monitor] Stopping database pool monitoring');

  if (healthCheckTimer) {
    clearInterval(healthCheckTimer);
    healthCheckTimer = null;
  }

  if (metricsLogTimer) {
    clearInterval(metricsLogTimer);
    metricsLogTimer = null;
  }

  isMonitoring = false;

  logger.info('✅ [Pool Monitor] Database pool monitoring stopped');
}

/**
 * Perform a health check on the database connection pool
 * Logs results and alerts on failures
 */
async function performHealthCheck() {
  const result = await healthCheck();

  if (result.healthy) {
    logger.debug('🟢 [Pool Monitor] Health check passed', {
      responseTime: `${result.responseTime}ms`,
      poolMetrics: result.poolMetrics,
    });
  } else {
    logger.error('🔴 [Pool Monitor] Health check failed', {
      error: result.error,
      responseTime: `${result.responseTime}ms`,
      timestamp: result.timestamp,
    });

    // Alert on health check failure
    await alertHealthCheckFailure(result);
  }

  // Check for pool exhaustion
  await checkPoolExhaustion(result.poolMetrics);
}

/**
 * Log current pool metrics
 * Provides visibility into pool usage and performance
 */
function logPoolMetrics() {
  const metrics = getPoolMetrics();

  logger.info('📊 [Pool Monitor] Connection pool metrics', {
    totalConnections: metrics.totalConnections,
    activeConnections: metrics.totalCount,
    idleConnections: metrics.idleCount,
    waitingClients: metrics.waitingCount,
    errors: metrics.errors,
    lastHealthCheck: metrics.lastHealthCheck,
    healthStatus: metrics.healthCheckStatus,
    status: metrics.status,
  });

  // Check for pool exhaustion
  checkPoolExhaustion(metrics).catch((error) => {
    logger.error('🔴 [Pool Monitor] Error checking pool exhaustion', {
      error: error.message,
    });
  });
}

/**
 * Check if the connection pool is nearing exhaustion
 * Alerts when usage exceeds the threshold
 *
 * @param {Object} metrics - Current pool metrics
 */
async function checkPoolExhaustion(metrics) {
  if (!metrics || metrics.status === 'not_initialized') {
    return;
  }

  const pool = getPool();
  const maxConnections = pool.options.max || 50;
  const usageRatio = metrics.totalCount / maxConnections;

  if (usageRatio >= POOL_EXHAUSTION_THRESHOLD) {
    logger.warn('⚠️ [Pool Monitor] Connection pool nearing exhaustion', {
      activeConnections: metrics.totalCount,
      maxConnections,
      usagePercentage: `${(usageRatio * 100).toFixed(1)}%`,
      waitingClients: metrics.waitingCount,
      recommendation:
        'Consider increasing DB_POOL_MAX or optimizing query performance',
    });

    // Alert on pool exhaustion
    await alertPoolExhaustion(metrics, maxConnections, usageRatio);
  }

  // Alert if clients are waiting for connections
  if (metrics.waitingCount > 0) {
    logger.warn('⚠️ [Pool Monitor] Clients waiting for database connections', {
      waitingClients: metrics.waitingCount,
      activeConnections: metrics.totalCount,
      idleConnections: metrics.idleCount,
      recommendation: 'Pool may be exhausted or queries are taking too long',
    });
  }
}

/**
 * Alert on health check failure
 * Can be extended to send notifications (email, Slack, etc.)
 *
 * @param {Object} result - Health check result
 */
async function alertHealthCheckFailure(result) {
  // Log critical alert
  logger.error('🚨 [Pool Monitor] ALERT: Database health check failed', {
    error: result.error,
    responseTime: result.responseTime,
    timestamp: result.timestamp,
    action: 'Database connectivity issue detected',
  });

  // Send alert via configured channels
  await sendAlert(
    'database_health_check_failed',
    'Database Health Check Failed',
    'The database connection health check has failed. This may indicate connectivity issues or database unavailability.',
    {
      error: result.error?.message || result.error,
      responseTime: result.responseTime,
      timestamp: result.timestamp,
    },
    'critical'
  );
}

/**
 * Alert on connection pool exhaustion
 * Can be extended to send notifications (email, Slack, etc.)
 *
 * @param {Object} metrics - Current pool metrics
 * @param {number} maxConnections - Maximum pool size
 * @param {number} usageRatio - Current usage ratio (0-1)
 */
async function alertPoolExhaustion(metrics, maxConnections, usageRatio) {
  // Log critical alert
  logger.error('🚨 [Pool Monitor] ALERT: Connection pool exhaustion', {
    activeConnections: metrics.totalCount,
    maxConnections,
    usagePercentage: `${(usageRatio * 100).toFixed(1)}%`,
    waitingClients: metrics.waitingCount,
    action: 'Immediate attention required - pool capacity exceeded',
  });

  // Send alert via configured channels
  await sendAlert(
    'pool_exhaustion',
    'Database Connection Pool Exhaustion',
    `The database connection pool has reached ${(usageRatio * 100).toFixed(1)}% capacity. Immediate attention required.`,
    {
      activeConnections: metrics.totalCount,
      maxConnections,
      usagePercentage: `${(usageRatio * 100).toFixed(1)}%`,
      waitingClients: metrics.waitingCount,
      idleConnections: metrics.idleCount,
    },
    'critical'
  );
}

/**
 * Get monitoring status
 *
 * @returns {Object} Current monitoring status
 */
export function getMonitoringStatus() {
  return {
    isMonitoring,
    healthCheckInterval: HEALTH_CHECK_INTERVAL,
    metricsLogInterval: METRICS_LOG_INTERVAL,
    exhaustionThreshold: POOL_EXHAUSTION_THRESHOLD,
  };
}

// Default export
export default {
  startMonitoring,
  stopMonitoring,
  getMonitoringStatus,
};
