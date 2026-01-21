/**
 * Database Query Wrapper
 *
 * Wraps database queries to automatically track performance metrics
 * Provides transparent performance monitoring without modifying application code
 *
 * Requirements: 9.7 (Database Performance Metrics)
 */

import { trackQuery } from './query-performance-tracker.js';
import logger from '../logger.js';

/**
 * Determine query type from SQL text
 * Categorizes queries for statistical analysis
 *
 * @param {string} queryText - SQL query text
 * @returns {string} Query type (SELECT, INSERT, UPDATE, DELETE, etc.)
 */
function getQueryType(queryText) {
  const trimmed = queryText.trim().toUpperCase();

  if (trimmed.startsWith('SELECT')) {
    return 'SELECT';
  }
  if (trimmed.startsWith('INSERT')) {
    return 'INSERT';
  }
  if (trimmed.startsWith('UPDATE')) {
    return 'UPDATE';
  }
  if (trimmed.startsWith('DELETE')) {
    return 'DELETE';
  }
  if (trimmed.startsWith('BEGIN')) {
    return 'BEGIN';
  }
  if (trimmed.startsWith('COMMIT')) {
    return 'COMMIT';
  }
  if (trimmed.startsWith('ROLLBACK')) {
    return 'ROLLBACK';
  }
  if (trimmed.startsWith('CREATE')) {
    return 'CREATE';
  }
  if (trimmed.startsWith('ALTER')) {
    return 'ALTER';
  }
  if (trimmed.startsWith('DROP')) {
    return 'DROP';
  }

  return 'OTHER';
}

/**
 * Wrap a query execution with performance tracking
 * Measures execution time and tracks metrics
 *
 * @param {Function} queryFn - Function that executes the query
 * @param {string} queryText - SQL query text
 * @param {Array} params - Query parameters
 * @returns {Promise} Query result
 */
export async function executeTrackedQuery(queryFn, queryText, params = []) {
  const startTime = Date.now();
  const queryType = getQueryType(queryText);

  try {
    const result = await queryFn();
    const duration = Date.now() - startTime;

    // Track successful query
    trackQuery(queryText, duration, {
      params,
      success: true,
      queryType,
    });

    return result;
  } catch (error) {
    const duration = Date.now() - startTime;

    // Track failed query
    trackQuery(queryText, duration, {
      params,
      success: false,
      error,
      queryType,
    });

    throw error;
  }
}

/**
 * Wrap a pool query method
 * Returns a wrapped version that tracks performance
 *
 * @param {Function} originalQuery - Original pool.query method
 * @returns {Function} Wrapped query function
 */
export function wrapPoolQuery(originalQuery) {
  return async function wrappedQuery(queryText, params) {
    return executeTrackedQuery(
      () => originalQuery.call(this, queryText, params),
      queryText,
      params,
    );
  };
}

/**
 * Wrap a client query method
 * Returns a wrapped version that tracks performance
 *
 * @param {Function} originalQuery - Original client.query method
 * @returns {Function} Wrapped query function
 */
export function wrapClientQuery(originalQuery) {
  return async function wrappedQuery(queryText, params) {
    return executeTrackedQuery(
      () => originalQuery.call(this, queryText, params),
      queryText,
      params,
    );
  };
}

/**
 * Wrap a pool object to track all queries
 * Modifies the pool's query method to track performance
 *
 * @param {Pool} pool - PostgreSQL connection pool
 * @returns {Pool} Same pool with wrapped query method
 */
export function wrapPool(pool) {
  const originalQuery = pool.query.bind(pool);

  pool.query = async function (queryText, params) {
    return executeTrackedQuery(
      () => originalQuery(queryText, params),
      queryText,
      params,
    );
  };

  logger.info(
    '🔵 [Query Wrapper] Pool query method wrapped for performance tracking',
  );

  return pool;
}

/**
 * Wrap a client object to track all queries
 * Modifies the client's query method to track performance
 *
 * @param {PoolClient} client - PostgreSQL pool client
 * @returns {PoolClient} Same client with wrapped query method
 */
export function wrapClient(client) {
  const originalQuery = client.query.bind(client);

  client.query = async function (queryText, params) {
    return executeTrackedQuery(
      () => originalQuery(queryText, params),
      queryText,
      params,
    );
  };

  return client;
}

// Default export
export default {
  executeTrackedQuery,
  wrapPoolQuery,
  wrapClientQuery,
  wrapPool,
  wrapClient,
  getQueryType,
};
