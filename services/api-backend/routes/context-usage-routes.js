import express from 'express';
import { z } from 'zod';
import { TunnelLogger } from '../utils/logger.js';
import db from '../database/db-pool.js';
import { authenticateJWT, requireAdmin } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';

const logger = new TunnelLogger('context-usage-routes');

const router = express.Router();

router.use(authenticateJWT, requireAdmin);

const contextUsageQuerySchema = z.object({
  sessionKey: z.string().min(1),
});

/**
 * GET /api/admin/context-usage
 * Get current context usage for a session
 */
router.get('/', validateSchema({ query: contextUsageQuerySchema }), async (req, res) => {
  try {
    const { sessionKey } = req.query;

    // Get current context usage
    const result = await db.query(
      `SELECT agent_id, context_tokens, total_tokens
       FROM agent_context_usage
       WHERE session_key = $1
       ORDER BY timestamp DESC
       LIMIT 1`,
      [sessionKey],
    );

    if (result.rows.length === 0) {
      return res.json({
        success: true,
        context_tokens: 0,
        total_tokens: 0,
        message: 'No context usage recorded for this session',
      });
    }

    const usage = result.rows[0];
    res.json({
      success: true,
      agent_id: usage.agent_id,
      context_tokens: usage.context_tokens,
      total_tokens: usage.total_tokens,
    });
  } catch (error) {
    logger.error('Failed to fetch context usage', {
      error: error.message,
      sessionKey: req.query.sessionKey,
    });
    res.status(500).json({
      success: false,
      error: 'Failed to fetch context usage',
    });
  }
});

export default router;
