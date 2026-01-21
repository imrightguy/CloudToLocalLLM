/**
 * Cached Query Wrapper
 *
 * Wraps database queries with caching support
 * Automatically caches SELECT queries and invalidates on mutations
 *
 * Requirements: 9.8 (Query Optimization and Caching)
 */

import { executeTrackedQuery } from './query-wrapper.js';
import { getQueryCache } from './query-cache.js';
import logger from '../logger.js';

/**
 * Determine if a query should be cached
 * Only cache SELECT queries
 *
 * @param {string} queryText - SQL query text
 * @returns {boolean} True if query should be cached
 */
function shouldCacheQuery(queryText) {
  const trimmed = queryText.trim().toUpperCase();
  return trimmed.startsWith('SELECT');
}

/**
 * Extract table names from a query
 * Used for cache invalidation
 *
 * @param {string} queryText - SQL query text
 * @returns {Array<string>} Table names
 */
function extractTableNames(queryText) {
  const tables = [];
  const trimmed = queryText.toUpperCase();

  // Match FROM clause
  const fromMatch = trimmed.match(/FROM\s+(\w+)/gi);
  if (fromMatch) {
    fromMatch.forEach((match) => {
      const tableName = match.replace(/FROM\s+/i, '').trim();
      if (tableName && !tables.includes(tableName)) {
        tables.push(tableName);
      }
    });
  }

  // Match JOIN clauses
  const joinMatch = trimmed.match(/JOIN\s+(\w+)/gi);
  if (joinMatch) {
    joinMatch.forEach((match) => {
      const tableName = match.replace(/JOIN\s+/i, '').trim();
      if (tableName && !tables.includes(tableName)) {
        tables.push(tableName);
      }
    });
  }

  // Match INSERT/UPDATE/DELETE
  const mutationMatch = trimmed.match(
    /(?:INSERT INTO|UPDATE|DELETE FROM)\s+(\w+)/i,
  );
  if (mutationMatch) {
    const tableName = mutationMatch[1];
    if (tableName && !tables.includes(tableName)) {
      tables.push(tableName);
    }
  }

  return tables;
}

/**
 * Execute a query with caching support
 *
 * @param {Function} queryFn - Function that executes the query
 * @param {string} queryText - SQL query text
 * @param {Array} params - Query parameters
 * @param {Object} options - Caching options
 * @returns {Promise} Query result
 */
export async function executeCachedQuery(
  queryFn,
  queryText,
  params = [],
  options = {},
) {
  const cache = getQueryCache();
  const shouldCache = shouldCacheQuery(queryText);
  const cacheKey = cache.generateKey(queryText, params);

  // Try to get from cache
  if (shouldCache) {
    const cachedResult = cache.get(cacheKey);
    if (cachedResult) {
      logger.debug('[Cached Query] Cache hit', {
        query: queryText.substring(0, 50),
        cacheKey,
      });
      return cachedResult;
    }
  }

  // Execute query with tracking
  const result = await executeTrackedQuery(queryFn, queryText, params);

  // Cache the result if it's a SELECT query
  if (shouldCache && result) {
    const ttl = options.ttl || 5 * 60 * 1000; // 5 minutes default
    const tables = extractTableNames(queryText);
    const dependencies = tables.map((table) => `table:${table}`);
    const tableNamesUpperCase = tables.map((t) => t.toUpperCase());

    cache.set(cacheKey, result, ttl, dependencies, tableNamesUpperCase);

    logger.debug('[Cached Query] Result cached', {
      query: queryText.substring(0, 50),
      cacheKey,
      ttl,
      tables,
    });
  }

  return result;
}

/**
 * Wrap a pool query method with caching
 *
 * @param {Function} originalQuery - Original pool.query method
 * @param {Object} options - Caching options
 * @returns {Function} Wrapped query function
 */
export function wrapPoolQueryWithCache(originalQuery, options = {}) {
  return async function wrappedQuery(queryText, params) {
    return executeCachedQuery(
      () => originalQuery.call(this, queryText, params),
      queryText,
      params,
      options,
    );
  };
}

/**
 * Wrap a client query method with caching
 *
 * @param {Function} originalQuery - Original client.query method
 * @param {Object} options - Caching options
 * @returns {Function} Wrapped query function
 */
export function wrapClientQueryWithCache(originalQuery, options = {}) {
  return async function wrappedQuery(queryText, params) {
    return executeCachedQuery(
      () => originalQuery.call(this, queryText, params),
      queryText,
      params,
      options,
    );
  };
}

/**
 * Wrap a pool object with caching
 *
 * @param {Pool} pool - PostgreSQL connection pool
 * @param {Object} options - Caching options
 * @returns {Pool} Same pool with wrapped query method
 */
export function wrapPoolWithCache(pool, options = {}) {
  const originalQuery = pool.query.bind(pool);

  pool.query = async function (queryText, params) {
    return executeCachedQuery(
      () => originalQuery(queryText, params),
      queryText,
      params,
      options,
    );
  };

  logger.info(
    '🔵 [Cached Query Wrapper] Pool query method wrapped with caching',
  );

  return pool;
}

/**
 * Wrap a client object with caching
 *
 * @param {PoolClient} client - PostgreSQL pool client
 * @param {Object} options - Caching options
 * @returns {PoolClient} Same client with wrapped query method
 */
export function wrapClientWithCache(client, options = {}) {
  const originalQuery = client.query.bind(client);

  client.query = async function (queryText, params) {
    return executeCachedQuery(
      () => originalQuery(queryText, params),
      queryText,
      params,
      options,
    );
  };

  return client;
}

/**
 * Invalidate cache for a specific table
 *
 * @param {string} tableName - Table name
 */
export function invalidateCacheForTable(tableName) {
  const cache = getQueryCache();
  const count = cache.invalidateByTable(tableName);
  logger.debug(
    `[Cached Query] Invalidated ${count} cache entries for table: ${tableName}`,
  );
  return count;
}

/**
 * Get cache statistics
 *
 * @returns {Object} Cache statistics
 */
export function getCacheStats() {
  const cache = getQueryCache();
  return cache.getStats();
}

/**
 * Clear all cache
 */
export function clearCache() {
  const cache = getQueryCache();
  cache.clear();
}

export default {
  executeCachedQuery,
  wrapPoolQueryWithCache,
  wrapClientQueryWithCache,
  wrapPoolWithCache,
  wrapClientWithCache,
  invalidateCacheForTable,
  getCacheStats,
  clearCache,
};
