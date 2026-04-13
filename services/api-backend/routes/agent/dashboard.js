import express from 'express';
import { query } from '../../database/db-pool.js';
import logger from '../../logger.js';
import { authenticateJWT } from '../../middleware/auth.js';

const router = express.Router();

/**
 * GET /api/agent/dashboard/metrics
 * Get overview metrics for the Agent Dashboard
 */
router.get('/metrics', authenticateJWT, async (req, res) => {
  try {
    const userId = req.user.id;

    // 1. Get agent counts by status
    const statusQuery = `
      SELECT status, COUNT(*) as count
      FROM agents
      WHERE user_id = $1 OR user_id IS NULL
      GROUP BY status
    `;
    const statusResult = await query(statusQuery, [userId]);

    const counts = {
      total: 0,
      active: 0,
      idle: 0,
      error: 0,
      offline: 0,
    };

    statusResult.rows.forEach((row) => {
      counts[row.status] = parseInt(row.count);
      counts.total += parseInt(row.count);
    });

    // 2. Get recent events summary
    const eventsQuery = `
      SELECT event_type, COUNT(*) as count
      FROM agent_events ae
      JOIN agents a ON ae.agent_id = a.id
      WHERE (a.user_id = $1 OR a.user_id IS NULL)
        AND ae.timestamp > NOW() - INTERVAL '24 hours'
      GROUP BY event_type
    `;
    const eventsResult = await query(eventsQuery, [userId]);

    const eventsSummary = {};
    eventsResult.rows.forEach((row) => {
      eventsSummary[row.event_type] = parseInt(row.count);
    });

    res.json({
      success: true,
      data: {
        agents: counts,
        recent_events_24h: eventsSummary,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    logger.error('[AgentDashboard] Error fetching metrics:', error);
    res.status(500).json({ error: 'Failed to fetch agent metrics' });
  }
});

/**
 * GET /api/agent/dashboard/agents
 * List all agents with their current status
 */
router.get('/agents', authenticateJWT, async (req, res) => {
  try {
    const userId = req.user.id;

    const agentsQuery = `
      SELECT * FROM agents
      WHERE user_id = $1 OR user_id IS NULL
      ORDER BY updated_at DESC
    `;
    const result = await query(agentsQuery, [userId]);

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('[AgentDashboard] Error fetching agents:', error);
    res.status(500).json({ error: 'Failed to fetch agents' });
  }
});

/**
 * GET /api/agent/dashboard/events
 * Get recent event stream
 */
router.get('/events', authenticateJWT, async (req, res) => {
  try {
    const userId = req.user.id;
    const limit = parseInt(req.query.limit) || 50;

    const eventsQuery = `
      SELECT ae.*, a.name as agent_name, a.agent_id as agent_external_id
      FROM agent_events ae
      JOIN agents a ON ae.agent_id = a.id
      WHERE a.user_id = $1 OR a.user_id IS NULL
      ORDER BY ae.timestamp DESC
      LIMIT $2
    `;
    const result = await query(eventsQuery, [userId, limit]);

    res.json({
      success: true,
      data: result.rows,
    });
  } catch (error) {
    logger.error('[AgentDashboard] Error fetching events:', error);
    res.status(500).json({ error: 'Failed to fetch events' });
  }
});

export default router;
