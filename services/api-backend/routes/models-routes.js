import express from 'express';
import db from '../database/db-pool.js';
import { TunnelLogger } from '../utils/logger.js';

const router = express.Router();
const logger = new TunnelLogger('models-routes');

/**
 * GET /api/admin/models
 * Get all models with their context windows and rate limits
 */
router.get('/', async (req, res) => {
  try {
    const models = await db.query(
      `SELECT model_id, alias, context_window, max_tokens, pricing_input, pricing_output, is_primary
       FROM models
       ORDER BY is_primary DESC, model_id ASC`,
    );

    res.json({
      success: true,
      models: models.rows,
    });
  } catch (error) {
    logger.error('Failed to fetch models', { error: error.message });
    res.status(500).json({
      success: false,
      error: 'Failed to fetch models',
    });
  }
});

/**
 * GET /api/admin/models/:modelId
 * Get a specific model's details
 */
router.get('/:modelId', async (req, res) => {
  const { modelId } = req.params;
  try {
    const model = await db.query(
      `SELECT model_id, alias, context_window, max_tokens, pricing_input, pricing_output, is_primary
       FROM models
       WHERE model_id = $1`,
      [modelId],
    );

    if (model.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Model not found',
      });
    }

    res.json({
      success: true,
      model: model.rows[0],
    });
  } catch (error) {
    logger.error('Failed to fetch model', { error: error.message, modelId });
    res.status(500).json({
      success: false,
      error: 'Failed to fetch model',
    });
  }
});

/**
 * POST /api/admin/models
 * Add or update a model
 */
router.post('/', async (req, res) => {
  try {
    const {
      model_id,
      alias,
      context_window,
      max_tokens,
      pricing_input,
      pricing_output,
      is_primary,
    } = req.body;

    if (!model_id) {
      return res.status(400).json({
        success: false,
        error: 'model_id is required',
      });
    }

    const result = await db.query(
      `INSERT INTO models (model_id, alias, context_window, max_tokens, pricing_input, pricing_output, is_primary)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       ON CONFLICT (model_id) DO UPDATE SET
         alias = EXCLUDED.alias,
         context_window = EXCLUDED.context_window,
         max_tokens = EXCLUDED.max_tokens,
         pricing_input = EXCLUDED.pricing_input,
         pricing_output = EXCLUDED.pricing_output,
         is_primary = EXCLUDED.is_primary,
         updated_at = NOW()
       RETURNING *`,
      [
        model_id,
        alias,
        context_window,
        max_tokens,
        pricing_input,
        pricing_output,
        is_primary,
      ],
    );

    res.json({
      success: true,
      model: result.rows[0],
    });
  } catch (error) {
    logger.error('Failed to add/update model', { error: error.message });
    res.status(500).json({
      success: false,
      error: 'Failed to add/update model',
    });
  }
});

export default router;
