import express from 'express';
import { z } from 'zod';
import { authenticateJWT, requireAdmin } from '../middleware/auth.js';
import { TunnelLogger } from '../utils/logger.js';
import { validateSchema } from '../middleware/schema-validation.js';
import db from '../database/db-pool.js';

const logger = new TunnelLogger('behavior-warnings-routes');

const router = express.Router();
router.use(authenticateJWT, requireAdmin);

const acknowledgeParamsSchema = z.object({
  id: z.coerce.number().int().positive(),
});

/**
 * GET /api/admin/behavior-warnings
 * Get pending behavior warnings (for internal use)
 */
router.get('/', async (req, res) => {
  try {
    const warnings = await db.query(
      `SELECT id, warning_type, message, severity, triggered_at, acknowledged
       FROM behavior_warnings
       WHERE acknowledged = false
       ORDER BY triggered_at ASC
       LIMIT 10`,
    );

    res.json({
      success: true,
      warnings: warnings.rows,
    });
  } catch (error) {
    logger.error('Failed to fetch behavior warnings', { error: error.message });
    res.status(500).json({
      success: false,
      error: 'Failed to fetch warnings',
    });
  }
});

/**
 * POST /api/admin/behavior-warnings/:id/acknowledge
 * Acknowledge a warning
 */
router.post('/:id/acknowledge', validateSchema({ params: acknowledgeParamsSchema }), async (req, res) => {
  const { id } = req.params;
  try {
    await db.query(
      `UPDATE behavior_warnings
       SET acknowledged = true, acknowledged_at = NOW()
       WHERE id = $1`,
      [id],
    );

    res.json({
      success: true,
      message: 'Warning acknowledged',
    });
  } catch (error) {
    logger.error('Failed to acknowledge warning', { error: error.message, id });
    res.status(500).json({
      success: false,
      error: 'Failed to acknowledge warning',
    });
  }
});

/**
 * DELETE /api/admin/behavior-warnings
 * Clear old warnings
 */
router.delete('/', async (req, res) => {
  try {
    // Clear warnings older than 24 hours
    await db.query(
      `DELETE FROM behavior_warnings
       WHERE acknowledged = true AND triggered_at < NOW() - INTERVAL '24 hours'`,
    );

    res.json({
      success: true,
      message: 'Old warnings cleared',
    });
  } catch (error) {
    logger.error('Failed to clear warnings', { error: error.message });
    res.status(500).json({
      success: false,
      error: 'Failed to clear warnings',
    });
  }
});

export default router;
