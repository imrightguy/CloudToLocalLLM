import express from 'express';
import { z } from 'zod';
import { authenticateJWT } from '../middleware/auth.js';
import { TunnelLogger } from '../utils/logger.js';
import { validateSchema } from '../middleware/schema-validation.js';
import db from '../database/db-pool.js';

const logger = new TunnelLogger('subagent-registry-routes');
const router = express.Router();
router.use(authenticateJWT);

const createSubagentSchema = {
  body: z.object({
    subagentId: z.string().min(1),
    label: z.string().optional(),
    agentId: z.string().min(1),
    task: z.string().optional(),
  }),
};

const updateSubagentStatusSchema = {
  body: z.object({
    status: z.enum(['pending', 'running', 'completed', 'failed']),
    result: z.record(z.unknown()).optional(),
    logs: z.string().optional(),
    error: z.string().optional(),
  }),
};

/**
 * GET /api/admin/subagents
 * List all subagents (filtered by status if provided)
 * Accessible to all agents (internal coordination)
 */
router.get('/', async (req, res) => {
  try {
    const { status, agentId } = req.query;

    let sql = `
      SELECT id, subagent_id, label, agent_id, task, status,
             created_at, started_at, completed_at,
             result_json, logs, error_message
      FROM subagent_registry
      WHERE 1=1
    `;
    const params = [];

    if (status) {
      params.push(status);
      sql += ` AND status = $${params.length}`;
    }

    if (agentId) {
      params.push(agentId);
      sql += ` AND agent_id = $${params.length}`;
    }

    sql += ` ORDER BY created_at DESC`;

    const result = await db.query(sql, params);

    res.json({
      success: true,
      subagents: result.rows,
    });
  } catch (error) {
    logger.error('Failed to list subagents', { error: error.message });
    res.status(500).json({
      success: false,
      error: 'Failed to list subagents',
    });
  }
});

/**
 * POST /api/admin/subagents
 * Register a new subagent
 * Accessible to all agents
 */
router.post('/', validateSchema(createSubagentSchema), async (req, res) => {
  try {
    const { subagentId, label, agentId, task } = req.body;

    const result = await db.query(
      `INSERT INTO subagent_registry (subagent_id, label, agent_id, task, status)
       VALUES ($1, $2, $3, $4, 'pending')
       ON CONFLICT (subagent_id) DO UPDATE SET
         label = EXCLUDED.label,
         agent_id = EXCLUDED.agent_id,
         task = EXCLUDED.task,
         status = 'pending',
         created_at = NOW(),
         started_at = NULL,
         completed_at = NULL,
         result_json = NULL,
         error_message = NULL
       RETURNING *`,
      [subagentId, label, agentId, task],
    );

    res.json({
      success: true,
      subagent: result.rows[0],
    });
  } catch (error) {
    logger.error('Failed to register subagent', { error: error.message });
    res.status(500).json({
      success: false,
      error: 'Failed to register subagent',
    });
  }
});

/**
 * GET /api/admin/subagents/:subagentId
 * Get details of a specific subagent
 * Accessible to all agents
 */
router.get('/:subagentId', async (req, res) => {
  const { subagentId } = req.params;

  try {
    const result = await db.query(
      `SELECT * FROM subagent_registry WHERE subagent_id = $1`,
      [subagentId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Subagent not found',
      });
    }

    res.json({
      success: true,
      subagent: result.rows[0],
    });
  } catch (error) {
    logger.error('Failed to get subagent', {
      error: error.message,
      subagentId,
    });
    res.status(500).json({
      success: false,
      error: 'Failed to get subagent',
    });
  }
});

/**
 * PATCH /api/admin/subagents/:subagentId/status
 * Update subagent status (start, complete, fail)
 * Accessible to all agents
 */
router.patch('/:subagentId/status', validateSchema(updateSubagentStatusSchema), async (req, res) => {
  const { subagentId } = req.params;
  try {
    const { status, result, logs, error } = req.body;

    const updates = ['status = $1'];
    const params = [status, subagentId];
    let paramIndex = 3;

    if (status === 'running') {
      updates.push(`started_at = NOW()`);
    }

    if (status === 'completed' || status === 'failed') {
      updates.push(`completed_at = NOW()`);
    }

    if (result !== undefined) {
      updates.push(`result_json = $${paramIndex++}`);
      params.push(JSON.stringify(result));
    }

    if (logs !== undefined) {
      updates.push(`logs = $${paramIndex++}`);
      params.push(logs);
    }

    if (error !== undefined) {
      updates.push(`error_message = $${paramIndex++}`);
      params.push(error);
    }

    const dbResult = await db.query(
      `UPDATE subagent_registry SET ${updates.join(', ')} WHERE subagent_id = $2 RETURNING *`,
      params,
    );

    if (dbResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Subagent not found',
      });
    }

    res.json({
      success: true,
      subagent: dbResult.rows[0],
    });
  } catch (error) {
    logger.error('Failed to update subagent status', {
      error: error.message,
      subagentId,
    });
    res.status(500).json({
      success: false,
      error: 'Failed to update subagent status',
    });
  }
});

/**
 * DELETE /api/admin/subagents/:subagentId
 * Remove a subagent from registry
 * Accessible to all agents
 */
router.delete('/:subagentId', async (req, res) => {
  const { subagentId } = req.params;

  try {
    const result = await db.query(
      `DELETE FROM subagent_registry WHERE subagent_id = $1 RETURNING *`,
      [subagentId],
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Subagent not found',
      });
    }

    res.json({
      success: true,
      message: 'Subagent removed',
    });
  } catch (error) {
    logger.error('Failed to delete subagent', {
      error: error.message,
      subagentId,
    });
    res.status(500).json({
      success: false,
      error: 'Failed to delete subagent',
    });
  }
});

export default router;
