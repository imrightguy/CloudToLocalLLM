/**
 * Admin Center Metrics Endpoint
 *
 * Exposes Prometheus metrics for the Admin Center API
 *
 * Requirements: Task 31.2, Requirement 12
 */

import express from 'express';
import {
  exportAdminMetricsAsText,
  initializeAdminMetrics,
} from '../middleware/admin-metrics.js';

const router = express.Router();

// Initialize metrics on startup
initializeAdminMetrics();

/**
 * GET /metrics
 *
 * Export Prometheus metrics in text format
 *
 * Response: text/plain with Prometheus metrics
 */
router.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
    const metrics = await exportAdminMetricsAsText();
    res.send(metrics);
  } catch (error) {
    console.error('Error exporting metrics:', error);
    res.status(500).send('Error exporting metrics');
  }
});

export default router;
