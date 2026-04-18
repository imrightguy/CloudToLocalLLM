/**
 * Cache Metrics Routes
 *
 * Provides endpoints for monitoring cache performance
 * Exposes cache statistics and management operations
 *
 * Requirements: 9.8 (Query Optimization and Caching)
 */

import express from 'express';
import { getCacheStats, clearCache } from '../database/cached-query-wrapper.js';
import { getQueryCache } from '../database/query-cache.js';
import { adminAuth } from '../middleware/admin-auth.js';
import logger from '../logger.js';

const router = express.Router();

/**
 * GET /cache/stats
 * Get cache statistics
 */
router.get('/stats', (req, res) => {
  try {
    const stats = getCacheStats();
    res.json({
      success: true,
      data: stats,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Cache Metrics] Error getting stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to get cache statistics',
    });
  }
});

/**
 * POST /cache/clear
 * Clear all cache entries
 */
router.post('/clear', adminAuth(['manage_system']), (req, res) => {
  try {
    clearCache();
    res.json({
      success: true,
      message: 'Cache cleared successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Cache Metrics] Error clearing cache:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to clear cache',
    });
  }
});

/**
 * POST /cache/invalidate
 * Invalidate cache by pattern
 */
router.post('/invalidate', adminAuth(['manage_system']), (req, res) => {
  try {
    const { pattern, table } = req.body;

    if (!pattern && !table) {
      return res.status(400).json({
        success: false,
        error: 'Either pattern or table must be provided',
      });
    }

    const cache = getQueryCache();
    let invalidatedCount = 0;

    if (table) {
      invalidatedCount = cache.invalidateByTable(table);
    } else if (pattern) {
      try {
        const regex = new RegExp(pattern);
        invalidatedCount = cache.invalidate(regex);
      } catch {
        return res.status(400).json({
          success: false,
          error: 'Invalid regex pattern',
        });
      }
    }

    res.json({
      success: true,
      invalidatedCount,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Cache Metrics] Error invalidating cache:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to invalidate cache',
    });
  }
});

/**
 * GET /cache/reset-metrics
 * Reset cache metrics
 */
router.get('/reset-metrics', adminAuth(['manage_system']), (req, res) => {
  try {
    const cache = getQueryCache();
    cache.resetMetrics();
    res.json({
      success: true,
      message: 'Cache metrics reset successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Cache Metrics] Error resetting metrics:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to reset cache metrics',
    });
  }
});

export default router;
