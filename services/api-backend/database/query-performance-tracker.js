/**
 * Database Query Performance Tracking Service
 *
 * Provides comprehensive query performance monitoring including:
 * - Query execution time tracking
 * - Slow query logging and detection
 * - Performance metrics collection and aggregation
 * - Query statistics and analysis
 * - Performance alerts for degraded queries
 *
 * Requirements: 9.7 (Database Performance Metrics)
 */

import logger from '../logger.js';

/**
 * Query performance metrics storage
 * Stores metrics for analysis and reporting
 */
const performanceMetrics = {
  queries: [], // Array of query execution records
  slowQueries: [], // Array of slow query records
  queryStats: {}, // Aggregated statistics by query type
  totalQueries: 0,
  totalSlowQueries: 0,
  averageQueryTime: 0,
  slowQueryThreshold: 100, // milliseconds - configurable
};

/**
 * Initialize query performance tracking
 * Sets up the slow query threshold from environment
 *
 * @returns {Object} Performance metrics configuration
 */
export function initializeQueryTracking() {
  const threshold = parseInt(process.env.DB_SLOW_QUERY_THRESHOLD || '100', 10);
  performanceMetrics.slowQueryThreshold = threshold;

  logger.info(
    '🔵 [Query Performance] Initializing query performance tracking',
    {
      slowQueryThreshold: `${threshold}ms`,
      maxStoredQueries: 1000,
    },
  );

  return {
    slowQueryThreshold: threshold,
    status: 'initialized',
  };
}

/**
 * Track a query execution
 * Records query performance metrics and detects slow queries
 *
 * @param {string} queryText - SQL query text
 * @param {number} duration - Query execution time in milliseconds
 * @param {Object} options - Additional tracking options
 * @returns {Object} Query performance record
 */
export function trackQuery(queryText, duration, options = {}) {
  const {
    params = [],
    success = true,
    error = null,
    queryType = 'unknown',
  } = options;

  const record = {
    timestamp: new Date().toISOString(),
    queryText: truncateQuery(queryText),
    duration,
    params: params.length,
    success,
    error: error ? error.message : null,
    queryType,
  };

  // Store query record (keep last 1000 queries)
  performanceMetrics.queries.push(record);
  if (performanceMetrics.queries.length > 1000) {
    performanceMetrics.queries.shift();
  }

  performanceMetrics.totalQueries++;

  // Update query statistics
  updateQueryStats(queryText, duration, queryType);

  // Check if query is slow
  if (duration > performanceMetrics.slowQueryThreshold) {
    performanceMetrics.totalSlowQueries++;
    performanceMetrics.slowQueries.push({
      ...record,
      detectedAt: new Date().toISOString(),
    });

    // Keep last 100 slow queries
    if (performanceMetrics.slowQueries.length > 100) {
      performanceMetrics.slowQueries.shift();
    }

    // Log slow query
    logger.warn('🟡 [Query Performance] Slow query detected', {
      duration,
      threshold: performanceMetrics.slowQueryThreshold,
      query: truncateQuery(queryText),
      queryType,
    });
  }

  // Calculate average query time
  performanceMetrics.averageQueryTime =
    performanceMetrics.queries.reduce((sum, q) => sum + q.duration, 0) /
    performanceMetrics.queries.length;

  return record;
}

/**
 * Update aggregated query statistics
 * Maintains statistics by query type for analysis
 *
 * @param {string} queryText - SQL query text
 * @param {number} duration - Query execution time
 * @param {string} queryType - Type of query (SELECT, INSERT, UPDATE, DELETE)
 */
function updateQueryStats(queryText, duration, queryType) {
  if (!performanceMetrics.queryStats[queryType]) {
    performanceMetrics.queryStats[queryType] = {
      count: 0,
      totalTime: 0,
      minTime: Infinity,
      maxTime: 0,
      averageTime: 0,
      slowCount: 0,
    };
  }

  const stats = performanceMetrics.queryStats[queryType];
  stats.count++;
  stats.totalTime += duration;
  stats.minTime = Math.min(stats.minTime, duration);
  stats.maxTime = Math.max(stats.maxTime, duration);
  stats.averageTime = stats.totalTime / stats.count;

  if (duration > performanceMetrics.slowQueryThreshold) {
    stats.slowCount++;
  }
}

/**
 * Truncate query text for logging
 * Prevents excessively long query strings in logs
 *
 * @param {string} queryText - SQL query text
 * @returns {string} Truncated query text
 */
function truncateQuery(queryText) {
  const maxLength = 200;
  if (queryText.length > maxLength) {
    return queryText.substring(0, maxLength) + '...';
  }
  return queryText;
}

/**
 * Get current performance metrics
 * Returns aggregated performance data for monitoring
 *
 * @returns {Object} Current performance metrics
 */
export function getPerformanceMetrics() {
  return {
    totalQueries: performanceMetrics.totalQueries,
    totalSlowQueries: performanceMetrics.totalSlowQueries,
    slowQueryPercentage:
      performanceMetrics.totalQueries > 0
        ? (
            (performanceMetrics.totalSlowQueries /
              performanceMetrics.totalQueries) *
            100
          ).toFixed(2)
        : 0,
    averageQueryTime: performanceMetrics.averageQueryTime.toFixed(2),
    slowQueryThreshold: performanceMetrics.slowQueryThreshold,
    queryStats: performanceMetrics.queryStats,
    recentQueries: performanceMetrics.queries.slice(-10),
    recentSlowQueries: performanceMetrics.slowQueries.slice(-10),
  };
}

/**
 * Get slow queries
 * Returns list of detected slow queries for analysis
 *
 * @param {number} limit - Maximum number of slow queries to return
 * @returns {Array} Array of slow query records
 */
export function getSlowQueries(limit = 50) {
  return performanceMetrics.slowQueries.slice(-limit);
}

/**
 * Get query statistics by type
 * Returns aggregated statistics for different query types
 *
 * @returns {Object} Query statistics by type
 */
export function getQueryStatsByType() {
  return performanceMetrics.queryStats;
}

/**
 * Reset performance metrics
 * Clears all collected metrics (useful for testing)
 *
 * @returns {Object} Reset confirmation
 */
export function resetPerformanceMetrics() {
  performanceMetrics.queries = [];
  performanceMetrics.slowQueries = [];
  performanceMetrics.queryStats = {};
  performanceMetrics.totalQueries = 0;
  performanceMetrics.totalSlowQueries = 0;
  performanceMetrics.averageQueryTime = 0;

  logger.info('🔵 [Query Performance] Performance metrics reset');

  return {
    status: 'reset',
    timestamp: new Date().toISOString(),
  };
}

/**
 * Set slow query threshold
 * Allows dynamic adjustment of slow query detection threshold
 *
 * @param {number} thresholdMs - New threshold in milliseconds
 * @returns {Object} Updated configuration
 */
export function setSlowQueryThreshold(thresholdMs) {
  if (thresholdMs < 0) {
    throw new Error('Threshold must be a positive number');
  }

  performanceMetrics.slowQueryThreshold = thresholdMs;

  logger.info('🔵 [Query Performance] Slow query threshold updated', {
    newThreshold: `${thresholdMs}ms`,
  });

  return {
    slowQueryThreshold: thresholdMs,
    status: 'updated',
  };
}

/**
 * Analyze query performance
 * Provides detailed analysis of query performance patterns
 *
 * @returns {Object} Performance analysis report
 */
export function analyzePerformance() {
  const stats = performanceMetrics.queryStats;
  const analysis = {
    timestamp: new Date().toISOString(),
    summary: {
      totalQueries: performanceMetrics.totalQueries,
      totalSlowQueries: performanceMetrics.totalSlowQueries,
      averageQueryTime: performanceMetrics.averageQueryTime.toFixed(2),
      slowQueryPercentage:
        performanceMetrics.totalQueries > 0
          ? (
              (performanceMetrics.totalSlowQueries /
                performanceMetrics.totalQueries) *
              100
            ).toFixed(2)
          : 0,
    },
    byQueryType: {},
    recommendations: [],
  };

  // Analyze by query type
  for (const [queryType, typeStats] of Object.entries(stats)) {
    analysis.byQueryType[queryType] = {
      count: typeStats.count,
      averageTime: typeStats.averageTime.toFixed(2),
      minTime: typeStats.minTime,
      maxTime: typeStats.maxTime,
      slowCount: typeStats.slowCount,
      slowPercentage: ((typeStats.slowCount / typeStats.count) * 100).toFixed(
        2,
      ),
    };

    // Generate recommendations
    if (typeStats.slowCount > typeStats.count * 0.1) {
      analysis.recommendations.push(
        `${queryType} queries have ${typeStats.slowPercentage}% slow query rate - consider optimization`,
      );
    }

    if (typeStats.maxTime > performanceMetrics.slowQueryThreshold * 5) {
      analysis.recommendations.push(
        `${queryType} queries have very high max time (${typeStats.maxTime}ms) - investigate outliers`,
      );
    }
  }

  return analysis;
}

// Default export
export default {
  initializeQueryTracking,
  trackQuery,
  getPerformanceMetrics,
  getSlowQueries,
  getQueryStatsByType,
  resetPerformanceMetrics,
  setSlowQueryThreshold,
  analyzePerformance,
};
