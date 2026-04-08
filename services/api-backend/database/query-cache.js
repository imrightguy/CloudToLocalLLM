/**
 * Query Cache Service
 *
 * Implements a query caching mechanism with TTL support and cache invalidation
 * Provides transparent caching for frequently accessed queries
 *
 * Requirements: 9.8 (Query Optimization and Caching)
 */

import logger from '../logger.js';

/**
 * Query Cache Service
 * Manages caching of query results with TTL and invalidation
 */
export class QueryCacheService {
  constructor(options = {}) {
    this.cache = new Map();
    this.ttlMap = new Map();
    this.dependencyMap = new Map(); // Maps cache keys to dependent keys
    this.tableMap = new Map(); // Maps table names to cache keys
    this.metrics = {
      hits: 0,
      misses: 0,
      invalidations: 0,
      evictions: 0,
    };

    // Configuration
    this.defaultTTL = options.defaultTTL || 5 * 60 * 1000; // 5 minutes
    this.maxCacheSize = options.maxCacheSize || 1000;
    this.enableMetrics = options.enableMetrics !== false;

    logger.info('🔵 [Query Cache] Service initialized', {
      defaultTTL: this.defaultTTL,
      maxCacheSize: this.maxCacheSize,
    });
  }

  /**
   * Generate a cache key from query and parameters
   * @param {string} query - SQL query
   * @param {Array} params - Query parameters
   * @returns {string} Cache key
   */
  generateKey(query, params = []) {
    const queryNormalized = query.trim().toLowerCase();
    const paramsStr = JSON.stringify(params);
    return `query:${Buffer.from(queryNormalized + paramsStr).toString('base64')}`;
  }

  /**
   * Get a value from cache
   * @param {string} key - Cache key
   * @returns {*} Cached value or null
   */
  get(key) {
    if (!this.cache.has(key)) {
      if (this.enableMetrics) {
        this.metrics.misses++;
      }
      return null;
    }

    // Check if TTL has expired
    const ttlEntry = this.ttlMap.get(key);
    if (ttlEntry && Date.now() > ttlEntry.expiresAt) {
      this.cache.delete(key);
      this.ttlMap.delete(key);
      if (this.enableMetrics) {
        this.metrics.misses++;
      }
      return null;
    }

    if (this.enableMetrics) {
      this.metrics.hits++;
    }
    return this.cache.get(key);
  }

  /**
   * Set a value in cache with TTL
   * @param {string} key - Cache key
   * @param {*} value - Value to cache
   * @param {number} ttl - Time to live in milliseconds
   * @param {Array} dependencies - Keys that invalidate this cache entry
   * @param {Array} tables - Table names associated with this cache entry
   */
  set(key, value, ttl = this.defaultTTL, dependencies = [], tables = []) {
    // Evict oldest entry if cache is full
    if (this.cache.size >= this.maxCacheSize) {
      const oldestKey = this.cache.keys().next().value;
      this.cache.delete(oldestKey);
      this.ttlMap.delete(oldestKey);
      this.dependencyMap.delete(oldestKey);

      // Remove from table map
      for (const [table, keys] of this.tableMap.entries()) {
        const idx = keys.indexOf(oldestKey);
        if (idx > -1) {
          keys.splice(idx, 1);
          if (keys.length === 0) {
            this.tableMap.delete(table);
          }
        }
      }

      if (this.enableMetrics) {
        this.metrics.evictions++;
      }
    }

    this.cache.set(key, value);
    this.ttlMap.set(key, {
      expiresAt: Date.now() + ttl,
      ttl,
    });

    // Register dependencies
    if (dependencies && dependencies.length > 0) {
      this.dependencyMap.set(key, dependencies);
    }

    // Register table associations
    if (tables && tables.length > 0) {
      for (const table of tables) {
        const normalizedName = table.toUpperCase();
        if (!this.tableMap.has(normalizedName)) {
          this.tableMap.set(normalizedName, []);
        }
        this.tableMap.get(normalizedName).push(key);
      }
    }
  }

  /**
   * Invalidate cache entries by key pattern
   * @param {string|RegExp} pattern - Key pattern to invalidate
   */
  invalidate(pattern) {
    let invalidatedCount = 0;

    if (typeof pattern === 'string') {
      // Exact match
      if (this.cache.has(pattern)) {
        this.cache.delete(pattern);
        this.ttlMap.delete(pattern);
        this.dependencyMap.delete(pattern);
        invalidatedCount++;
      }
    } else if (pattern instanceof RegExp) {
      // Pattern match
      for (const key of this.cache.keys()) {
        if (pattern.test(key)) {
          this.cache.delete(key);
          this.ttlMap.delete(key);
          this.dependencyMap.delete(key);
          invalidatedCount++;
        }
      }
    }

    if (this.enableMetrics) {
      this.metrics.invalidations += invalidatedCount;
    }

    if (invalidatedCount > 0) {
      logger.debug(`[Query Cache] Invalidated ${invalidatedCount} entries`, {
        pattern: pattern.toString(),
      });
    }

    return invalidatedCount;
  }

  /**
   * Invalidate cache entries by table name
   * Useful for invalidating all queries related to a table
   * @param {string} tableName - Table name
   */
  invalidateByTable(tableName) {
    const keys = this.tableMap.get(tableName.toUpperCase());
    if (!keys || keys.length === 0) {
      return 0;
    }

    let invalidatedCount = 0;
    for (const key of keys) {
      if (this.cache.has(key)) {
        this.cache.delete(key);
        this.ttlMap.delete(key);
        this.dependencyMap.delete(key);
        invalidatedCount++;
      }
    }

    this.tableMap.delete(tableName.toUpperCase());
    if (this.enableMetrics) {
      this.metrics.invalidations += invalidatedCount;
    }

    return invalidatedCount;
  }

  /**
   * Clear all cache entries
   */
  clear() {
    const size = this.cache.size;
    this.cache.clear();
    this.ttlMap.clear();
    this.dependencyMap.clear();
    this.tableMap.clear();
    logger.info(`[Query Cache] Cleared ${size} entries`);
  }

  /**
   * Get cache statistics
   * @returns {Object} Cache statistics
   */
  getStats() {
    const hitRate =
      this.metrics.hits + this.metrics.misses > 0
        ? (this.metrics.hits / (this.metrics.hits + this.metrics.misses)) * 100
        : 0;

    return {
      size: this.cache.size,
      maxSize: this.maxCacheSize,
      hits: this.metrics.hits,
      misses: this.metrics.misses,
      hitRate: hitRate.toFixed(2),
      invalidations: this.metrics.invalidations,
      evictions: this.metrics.evictions,
    };
  }

  /**
   * Reset metrics
   */
  resetMetrics() {
    this.metrics = {
      hits: 0,
      misses: 0,
      invalidations: 0,
      evictions: 0,
    };
  }

  /**
   * Shutdown cache service
   */
  shutdown() {
    this.clear();
    logger.info('🔵 [Query Cache] Service shutdown complete');
  }
}

// Create singleton instance
let cacheInstance = null;

/**
 * Get or create cache instance
 * @param {Object} options - Cache options
 * @returns {QueryCacheService} Cache service instance
 */
export function getQueryCache(options = {}) {
  if (!cacheInstance) {
    cacheInstance = new QueryCacheService(options);
  }
  return cacheInstance;
}

export default QueryCacheService;
