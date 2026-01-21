/**
 * Alert Configuration Routes
 *
 * Provides endpoints for managing alert configuration:
 * - GET /alert-config - Get current configuration
 * - PUT /alert-config/thresholds - Update thresholds
 * - PUT /alert-config/channels - Update enabled channels
 * - GET /alert-config/history - Get alert history
 * - GET /alert-config/active - Get active alerts
 * - POST /alert-config/test - Test alert triggering
 * - POST /alert-config/reset - Reset to defaults
 *
 * Requirements: 8.10 (Real-time alerting for critical metrics)
 */

import express from 'express';
import logger from '../logger.js';
import { adminAuth } from '../middleware/admin-auth.js';
import { alertConfigService } from '../services/alert-configuration-service.js';
import { alertTriggeringService } from '../services/alert-triggering-service.js';

const router = express.Router();

/**
 * GET /alert-config
 * Get current alert configuration
 * Requires: admin authentication
 */
router.get('/', adminAuth(['manage_alerts']), (req, res) => {
  try {
    const config = alertConfigService.getStatus();

    res.json({
      success: true,
      data: config,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to get configuration', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to retrieve alert configuration',
      code: 'ALERT_CONFIG_RETRIEVAL_FAILED',
    });
  }
});

/**
 * GET /alert-config/thresholds
 * Get current alert thresholds
 * Requires: admin authentication
 */
router.get('/thresholds', adminAuth(['manage_alerts']), (req, res) => {
  try {
    const thresholds = alertConfigService.getThresholds();

    res.json({
      success: true,
      data: thresholds,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to get thresholds', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to retrieve thresholds',
      code: 'THRESHOLDS_RETRIEVAL_FAILED',
    });
  }
});

/**
 * PUT /alert-config/thresholds
 * Update alert thresholds
 * Requires: admin authentication
 * Body: { metric: { warning: number, critical: number } }
 */
router.put('/thresholds', adminAuth(['manage_alerts']), (req, res) => {
  try {
    const { thresholds } = req.body;

    if (!thresholds || typeof thresholds !== 'object') {
      return res.status(400).json({
        success: false,
        error: 'Invalid thresholds format',
        code: 'INVALID_THRESHOLDS',
      });
    }

    const updated = alertConfigService.updateThresholds(thresholds);

    logger.info('[Alert Config Routes] Thresholds updated', {
      userId: req.user?.sub,
      thresholds: updated,
    });

    res.json({
      success: true,
      data: updated,
      message: 'Thresholds updated successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to update thresholds', {
      error: error.message,
    });

    res.status(400).json({
      success: false,
      error: error.message,
      code: 'THRESHOLDS_UPDATE_FAILED',
    });
  }
});

/**
 * GET /alert-config/channels
 * Get enabled alert channels
 * Requires: admin authentication
 */
router.get('/channels', adminAuth(['manage_alerts']), (req, res) => {
  try {
    const channels = alertConfigService.getEnabledChannels();

    res.json({
      success: true,
      data: channels,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to get channels', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to retrieve channels',
      code: 'CHANNELS_RETRIEVAL_FAILED',
    });
  }
});

/**
 * PUT /alert-config/channels
 * Update enabled alert channels
 * Requires: admin authentication
 * Body: { email: boolean, slack: boolean, pagerduty: boolean }
 */
router.put('/channels', adminAuth(['manage_alerts']), (req, res) => {
  try {
    const { channels } = req.body;

    if (!channels || typeof channels !== 'object') {
      return res.status(400).json({
        success: false,
        error: 'Invalid channels format',
        code: 'INVALID_CHANNELS',
      });
    }

    const updated = alertConfigService.updateEnabledChannels(channels);

    logger.info('[Alert Config Routes] Channels updated', {
      userId: req.user?.sub,
      channels: updated,
    });

    res.json({
      success: true,
      data: updated,
      message: 'Channels updated successfully',
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to update channels', {
      error: error.message,
    });

    res.status(400).json({
      success: false,
      error: error.message,
      code: 'CHANNELS_UPDATE_FAILED',
    });
  }
});

/**
 * GET /alert-config/history
 * Get alert history
 * Requires: admin authentication
 * Query: limit (default 100), metric, severity
 */
router.get('/history', adminAuth(['view_alerts']), (req, res) => {
  try {
    const { limit = 100, metric, severity } = req.query;

    const history = alertConfigService.getAlertHistory({
      limit: parseInt(limit, 10),
      metric,
      severity,
    });

    res.json({
      success: true,
      data: history,
      count: history.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to get history', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to retrieve alert history',
      code: 'HISTORY_RETRIEVAL_FAILED',
    });
  }
});

/**
 * GET /alert-config/active
 * Get active alerts
 * Requires: admin authentication
 */
router.get('/active', adminAuth(['view_alerts']), (req, res) => {
  try {
    const activeAlerts = alertConfigService.getActiveAlerts();

    res.json({
      success: true,
      data: activeAlerts,
      count: activeAlerts.length,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to get active alerts', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to retrieve active alerts',
      code: 'ACTIVE_ALERTS_RETRIEVAL_FAILED',
    });
  }
});

/**
 * POST /alert-config/test
 * Test alert triggering
 * Requires: admin authentication
 * Body: { metric: string, value: number, severity: string }
 */
router.post('/test', adminAuth(['manage_alerts']), async (req, res) => {
  try {
    const { metric, value, severity = 'warning' } = req.body;

    if (!metric || value === undefined) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: metric, value',
        code: 'MISSING_FIELDS',
      });
    }

    await alertTriggeringService.manualTrigger(metric, value, severity);

    logger.info('[Alert Config Routes] Test alert triggered', {
      userId: req.user?.sub,
      metric,
      value,
      severity,
    });

    res.json({
      success: true,
      message: 'Test alert triggered successfully',
      data: { metric, value, severity },
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to trigger test alert', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to trigger test alert',
      code: 'TEST_ALERT_FAILED',
    });
  }
});

/**
 * POST /alert-config/reset
 * Reset to default thresholds
 * Requires: admin authentication
 */
router.post('/reset', adminAuth(['manage_alerts']), (req, res) => {
  try {
    alertConfigService.resetToDefaults();

    logger.info('[Alert Config Routes] Thresholds reset to defaults', {
      userId: req.user?.sub,
    });

    res.json({
      success: true,
      message: 'Thresholds reset to defaults',
      data: alertConfigService.getThresholds(),
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to reset thresholds', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to reset thresholds',
      code: 'RESET_FAILED',
    });
  }
});

/**
 * GET /alert-config/metrics
 * Get all metric statistics
 * Requires: admin authentication
 */
router.get('/metrics', adminAuth(['view_alerts']), (req, res) => {
  try {
    const metrics = alertTriggeringService.getAllMetricStats();

    res.json({
      success: true,
      data: metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    logger.error('[Alert Config Routes] Failed to get metric stats', {
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to retrieve metric statistics',
      code: 'METRICS_RETRIEVAL_FAILED',
    });
  }
});

export default router;
