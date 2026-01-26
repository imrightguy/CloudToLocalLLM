# Query Caching Implementation - Quick Reference

## Overview

Query caching mechanism for optimizing database performance by caching SELECT query results with automatic invalidation support.

**Requirements: 9.8 (Query Optimization and Caching)**

## Key Components

### 1. QueryCacheService (`database/query-cache.js`)

- In-memory cache with TTL support
- Automatic eviction when cache is full
- Table-based invalidation tracking
- Metrics collection (hits, misses, invalidations, evictions)

### 2. Cached Query Wrapper (`database/cached-query-wrapper.js`)

- Wraps database queries with caching
- Automatically caches SELECT queries
- Extracts table names for invalidation
- Integrates with query performance tracking

### 3. Cache Metrics Routes (`routes/cache-metrics.js`)

- GET `/cache/stats` - Get cache statistics
- POST `/cache/clear` - Clear all cache
- POST `/cache/invalidate` - Invalidate by pattern or table
- GET `/cache/reset-metrics` - Reset metrics

## Usage

### Basic Caching

```javascript
import { executeCachedQuery } from './database/cached-query-wrapper.js';

// Execute query with automatic caching
const result = await executeCachedQuery(
  () => pool.query('SELECT * FROM users WHERE id = ?', [1]),
  'SELECT * FROM users WHERE id = ?',
  [1],
  { ttl: 5 * 60 * 1000 } // 5 minutes
);
```

### Wrapping Pool/Client

```javascript
import { wrapPoolWithCache, wrapClientWithCache } from './database/cached-query-wrapper.js';

// Wrap pool for automatic caching
const wrappedPool = wrapPoolWithCache(pool);

// Use wrapped pool - queries are automatically cached
const result = await wrappedPool.query('SELECT * FROM users', []);
```

### Cache Invalidation

```javascript
import { invalidateCacheForTable, clearCache } from './database/cached-query-wrapper.js';

// Invalidate all queries for a table
invalidateCacheForTable('users');

// Clear entire cache
clearCache();
```

### Getting Cache Statistics

```javascript
import { getCacheStats } from './database/cached-query-wrapper.js';

const stats = getCacheStats();
console.log(stats);
// {
//   size: 42,
//   maxSize: 1000,
//   hits: 1250,
//   misses: 150,
//   hitRate: "89.29",
//   invalidations: 5,
//   evictions: 0
// }
```

## Configuration

### Cache Options

```javascript
const cache = new QueryCacheService({
  defaultTTL: 5 * 60 * 1000,    // 5 minutes
  maxCacheSize: 1000,            // Max entries
  enableMetrics: true            // Track metrics
});
```

### Query Caching Options

```javascript
await executeCachedQuery(queryFn, query, params, {
  ttl: 10 * 60 * 1000  // 10 minutes
});
```

## Cache Behavior

### What Gets Cached

- SELECT queries only
- Results are cached with TTL
- Cache keys are generated from query + parameters

### What Doesn't Get Cached

- INSERT, UPDATE, DELETE queries
- Queries that fail
- Queries with null results

### Automatic Invalidation

- Cache entries expire after TTL
- Entries are invalidated when table is modified
- Oldest entries are evicted when cache is full

## Performance Metrics

### Cache Hit Rate

- Calculated as: `hits / (hits + misses) * 100`
- Higher hit rate = better performance
- Target: > 80% for optimal performance

### Metrics Tracked

- **hits**: Number of cache hits
- **misses**: Number of cache misses
- **invalidations**: Number of entries invalidated
- **evictions**: Number of entries evicted due to size limit

## API Endpoints

### GET /cache/stats

Returns current cache statistics.

**Response:**

```json
{
  "success": true,
  "data": {
    "size": 42,
    "maxSize": 1000,
    "hits": 1250,
    "misses": 150,
    "hitRate": "89.29",
    "invalidations": 5,
    "evictions": 0
  },
  "timestamp": "2024-01-19T10:30:00.000Z"
}
```

### POST /cache/clear

Clears all cache entries.

**Response:**

```json
{
  "success": true,
  "message": "Cache cleared successfully",
  "timestamp": "2024-01-19T10:30:00.000Z"
}
```

### POST /cache/invalidate

Invalidates cache entries by pattern or table.

**Request:**

```json
{
  "table": "users"
  // OR
  "pattern": "query:users"
}
```

**Response:**

```json
{
  "success": true,
  "invalidatedCount": 5,
  "timestamp": "2024-01-19T10:30:00.000Z"
}
```

### GET /cache/reset-metrics

Resets cache metrics.

**Response:**

```json
{
  "success": true,
  "message": "Cache metrics reset successfully",
  "timestamp": "2024-01-19T10:30:00.000Z"
}
```

## Testing

### Unit Tests

- `test/api-backend/query-cache.test.js` - QueryCacheService tests
- `test/api-backend/cached-query-wrapper.test.js` - Wrapper tests
- `test/api-backend/cache-metrics-routes.test.js` - Metrics tests

### Running Tests

```bash
npm test -- ../test/api-backend/query-cache.test.js
npm test -- ../test/api-backend/cached-query-wrapper.test.js
npm test -- ../test/api-backend/cache-metrics-routes.test.js
```

## Best Practices

1. **Set appropriate TTL**: Balance between freshness and performance
2. **Monitor hit rate**: Aim for > 80% hit rate
3. **Invalidate strategically**: Invalidate only affected tables
4. **Clear cache on deployment**: Ensure fresh data after updates
5. **Monitor cache size**: Adjust maxCacheSize based on memory

## Troubleshooting

### Low Hit Rate

- Increase TTL for frequently accessed queries
- Check if queries are being invalidated too frequently
- Verify cache is not being cleared unexpectedly

### High Memory Usage

- Reduce maxCacheSize
- Decrease TTL for entries
- Monitor eviction count

### Stale Data

- Reduce TTL
- Ensure invalidation is triggered on data changes
- Check if cache is being properly cleared

## Integration Points

- **Query Wrapper**: Automatically tracks performance
- **Health Check**: Monitors cache health
- **Metrics**: Exposes cache statistics to Prometheus
- **Admin Routes**: Provides cache management endpoints

## Future Enhancements

- Redis-backed distributed cache
- Cache warming strategies
- Adaptive TTL based on access patterns
- Cache compression for large results
- Distributed cache invalidation
