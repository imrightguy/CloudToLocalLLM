/**
 * Database Performance Metrics Routes
 *
 * Provides endpoints for monitoring and analyzing database query performance
 * Includes metrics collection, slow query analysis, and performance recommendations
 *
 * Requirements: 9.7 (Database Performance Metrics)
 */

import express from 'express';
import {
  getPerformanceMetrics,
  getSlowQueries,
  getQueryStatsByType,
  analyzePerformance,
  setSlowQueryThreshold,
  resetPerformanceMetrics,
} from '../database/query-performance-tracker.js';
import logger from '../logger.js';
import { adminAuth } from '../middleware/admin-auth.js';

const router = express.Router();

/**
 * GET /database/performance/metrics
 * Get current database performance metrics
 *
 * Returns:
 * - Total queries executed
 * - Total slow queries detected
 * - Average query time
 * - Query statistics by type
 * - Recent queries and slow queries
 */
router.get('/metrics', adminAuth(['view_system_metrics']), (req, res) => {
  try {
    const metrics = getPerformanceMetrics();

    logger.info('📊 [Database Performance] Metrics retrieved', {
      totalQueries: metrics.totalQueries,
      slowQueries: metrics.totalSlowQueries,
    });

    res.json({
      status: 'success',
      data: metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Database Performance] Error retrieving metrics', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      message: 'Failed to retrieve performance metrics',
      error: error.message,
    });
  }
});

/**
 * GET /database/performance/slow-queries
 * Get list of detected slow queries
 *
 * Query Parameters:
 * - limit: Maximum number of slow queries to return (default: 50)
 *
 * Returns:
 * - Array of slow query records with execution times
 * - Query text and parameters
 * - Detection timestamp
 */
router.get('/slow-queries', adminAuth(['view_system_metrics']), (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit || '50', 10), 100);
    const slowQueries = getSlowQueries(limit);

    logger.info('🟡 [Database Performance] Slow queries retrieved', {
      count: slowQueries.length,
      limit,
    });

    res.json({
      status: 'success',
      data: slowQueries,
      count: slowQueries.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Database Performance] Error retrieving slow queries', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      message: 'Failed to retrieve slow queries',
      error: error.message,
    });
  }
});

/**
 * GET /database/performance/stats
 * Get aggregated query statistics by type
 *
 * Returns:
 * - Statistics for each query type (SELECT, INSERT, UPDATE, DELETE, etc.)
 * - Count, average time, min/max times
 * - Slow query count and percentage
 */
router.get('/stats', adminAuth(['view_system_metrics']), (req, res) => {
  try {
    const stats = getQueryStatsByType();

    logger.info('📈 [Database Performance] Query statistics retrieved', {
      queryTypes: Object.keys(stats).length,
    });

    res.json({
      status: 'success',
      data: stats,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Database Performance] Error retrieving statistics', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      message: 'Failed to retrieve query statistics',
      error: error.message,
    });
  }
});

/**
 * GET /database/performance/analysis
 * Get detailed performance analysis and recommendations
 *
 * Returns:
 * - Performance summary
 * - Analysis by query type
 * - Recommendations for optimization
 */
router.get('/analysis', adminAuth(['view_system_metrics']), (req, res) => {
  try {
    const analysis = analyzePerformance();

    logger.info('🔍 [Database Performance] Performance analysis generated', {
      recommendations: analysis.recommendations.length,
    });

    res.json({
      status: 'success',
      data: analysis,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Database Performance] Error generating analysis', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      message: 'Failed to generate performance analysis',
      error: error.message,
    });
  }
});

/**
 * POST /database/performance/threshold
 * Set the slow query threshold
 *
 * Request Body:
 * - thresholdMs: New threshold in milliseconds
 *
 * Returns:
 * - Updated threshold configuration
 */
router.post('/threshold', adminAuth(['manage_system']), (req, res) => {
  try {
    const { thresholdMs } = req.body;

    if (typeof thresholdMs !== 'number' || thresholdMs < 0) {
      return res.status(400).json({
        status: 'error',
        message: 'Invalid threshold value - must be a positive number',
      });
    }

    const result = setSlowQueryThreshold(thresholdMs);

    logger.info('🔵 [Database Performance] Slow query threshold updated', {
      newThreshold: thresholdMs,
    });

    res.json({
      status: 'success',
      data: result,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Database Performance] Error updating threshold', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      message: 'Failed to update threshold',
      error: error.message,
    });
  }
});

/**
 * POST /database/performance/reset
 * Reset all performance metrics (admin only)
 *
 * Returns:
 * - Reset confirmation
 */
router.post('/reset', adminAuth(['manage_system']), (req, res) => {
  try {
    const result = resetPerformanceMetrics();

    logger.warn('🔵 [Database Performance] Performance metrics reset', {
      timestamp: result.timestamp,
    });

    res.json({
      status: 'success',
      data: result,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('🔴 [Database Performance] Error resetting metrics', {
      error: error.message,
    });

    res.status(500).json({
      status: 'error',
      message: 'Failed to reset metrics',
      error: error.message,
    });
  }
});

export default router;
