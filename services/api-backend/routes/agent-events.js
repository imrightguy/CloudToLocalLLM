import express from 'express';
import crypto from 'crypto';
import { query } from '../database/db-pool.js';
import logger from '../logger.js';

const router = express.Router();

/**
 * Middleware: Verify webhook signature
 * Ensures the request is coming from a trusted OpenClaw instance
 */
const verifyWebhookSignature = (req, res, next) => {
  const secret = process.env.OPENCLAW_WEBHOOK_SECRET;
  if (!secret) {
    logger.error('[AgentEvents] OPENCLAW_WEBHOOK_SECRET not set');
    return res.status(500).json({ error: 'Server configuration error' });
  }

  const signature = req.headers['x-openclaw-signature'];
  const body = JSON.stringify(req.body);
  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(body)
    .digest('hex');

  if (!signature || signature !== expectedSignature) {
    logger.warn('[AgentEvents] Invalid signature received', {
      received: signature,
      expected: expectedSignature
    });
    return res.status(401).json({ error: 'Invalid signature' });
  }
  next();
};

/**
 * Determine agent status based on event type
 */
function determineAgentStatus(eventType, eventData) {
  switch (eventType) {
    case 'message:received':
    case 'message:thinking':
    case 'tool:start':
      return 'active';
    case 'tool:end':
    case 'reply':
      return 'idle';
    case 'error':
      return 'error';
    case 'agent:stopped':
      return 'offline';
    default:
      return 'idle';
  }
}

/**
 * Generate a default avatar URL for new agents
 */
function generateAvatarUrl(agentId) {
  return `https://api.dicebear.com/7.x/bottts/svg?seed=${agentId}`;
}

/**
 * POST /api/agent/events
 * Receive and process events from OpenClaw agents
 */
router.post('/', verifyWebhookSignature, async (req, res) => {
  const { agent_id, event_type, event_data, correlation_id } = req.body;

  try {
    // 1. Find or create agent
    const agentResult = await query(
      'SELECT * FROM agents WHERE agent_id = $1',
      [agent_id]
    );

    let agent = agentResult.rows[0];

    if (!agent) {
      // Create new agent
      const insertResult = await query(
        `INSERT INTO agents (user_id, name, agent_id, type, status, avatar_url)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [
          null, // user_id can be assigned later via dashboard
          event_data?.agent_name || agent_id,
          agent_id,
          event_data?.agent_type || 'custom',
          'idle',
          generateAvatarUrl(agent_id)
        ]
      );
      agent = insertResult.rows[0];
      logger.info('[AgentEvents] Created new agent', { agent_id, name: agent.name });
    }

    // 2. Update agent status based on event
    const newStatus = determineAgentStatus(event_type, event_data);
    await query(
      'UPDATE agents SET status = $1, updated_at = NOW() WHERE id = $2',
      [newStatus, agent.id]
    );

    // 3. Store event
    await query(
      `INSERT INTO agent_events (agent_id, event_type, event_data, correlation_id)
       VALUES ($1, $2, $3, $4)`,
      [agent.id, event_type, JSON.stringify(event_data), correlation_id]
    );

    // 4. Update metrics (basic error tracking for now)
    if (event_type === 'error') {
       await query(
         `INSERT INTO agent_metrics (agent_id, metric_name, metric_value, metric_window)
          VALUES ($1, $2, $3, $4)`,
         [agent.id, 'error_count', 1, 'hourly']
       );
    }

    // Note: Real-time broadcast via WebSocket will be implemented in a future step

    res.json({ success: true, agent_db_id: agent.id });
  } catch (error) {
    logger.error('[AgentEvents] Error processing event:', error);
    res.status(500).json({ error: 'Failed to process event' });
  }
});

export default router;
