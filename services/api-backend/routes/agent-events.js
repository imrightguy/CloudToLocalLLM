import express from 'express';
import { z } from 'zod';
import crypto from 'crypto';
import { getPool } from '../database/db-pool.js';
import dashboardWSManager from '../websocket/dashboard-ws.js';
import logger from '../logger.js';
import { validateSchema } from '../middleware/schema-validation.js';

const router = express.Router();

const agentEventBodySchema = z.object({
  agent_id: z.string().min(1),
  event_type: z.string().min(1),
  event_data: z.object({
    agent_name: z.string().optional(),
    agent_type: z.string().optional(),
  }).optional(),
  correlation_id: z.string().optional(),
});

// Middleware: Verify webhook signature
const verifyWebhookSignature = (req, res, next) => {
  const webhookSecret =
    process.env.OPENCLAW_WEBHOOK_SECRET || process.env.JWT_SECRET;
  const signature = req.headers['x-openclaw-signature'];

  if (!webhookSecret) {
    logger.error('OpenClaw webhook secret not configured', {
      agentId: req.body?.agent_id,
    });
    return res.status(500).json({ error: 'Webhook secret not configured' });
  }

  const expectedSignature = crypto
    .createHmac('sha256', webhookSecret)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (!signature || signature !== expectedSignature) {
    logger.warn('Invalid OpenClaw webhook signature', {
      hasSignature: !!signature,
      agentId: req.body?.agent_id,
    });
    return res.status(401).json({ error: 'Invalid webhook signature' });
  }
  next();
};

router.post('/', verifyWebhookSignature, validateSchema({ body: agentEventBodySchema }), async (req, res) => {
  logger.info('Received agent event request');
  const { agent_id, event_type, event_data, correlation_id } = req.body;
  const pool = getPool();

  try {
    // 1. Find or create agent
    let agentResult = await pool.query(
      'SELECT * FROM agents WHERE agent_id = $1',
      [agent_id],
    );
    let agent = agentResult.rows[0];

    if (!agent) {
      // Create new agent
      const newAgentResult = await pool.query(
        `INSERT INTO agents (name, agent_id, type, status, avatar_url)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [
          event_data.agent_name || agent_id,
          agent_id,
          event_data.agent_type || 'custom',
          'idle',
          `https://api.dicebear.com/7.x/bottts/svg?seed=${agent_id}`,
        ],
      );
      agent = newAgentResult.rows[0];
    }

    // 2. Update agent status based on event
    const newStatus = determineAgentStatus(event_type, event_data);
    await pool.query(
      'UPDATE agents SET status = $1, updated_at = NOW() WHERE id = $2',
      [newStatus, agent.id],
    );

    // 3. Store event
    await pool.query(
      `INSERT INTO agent_events (agent_id, event_type, event_data, correlation_id)
       VALUES ($1, $2, $3, $4)`,
      [agent.id, event_type, JSON.stringify(event_data), correlation_id],
    );

    // 4. Update metrics (placeholder)
    // updateAgentMetrics(agent.id, event_type, event_data);

    // 5. Broadcast to WebSocket clients
    dashboardWSManager.broadcast({
      type: 'agent_update',
      agent: {
        id: agent.id,
        agent_id: agent.agent_id,
        name: agent.name,
        status: newStatus,
        event: { event_type, event_data },
      },
    });

    res.json({ success: true, agent_id: agent.id });
  } catch (error) {
    logger.error('Failed to process agent event', {
      error: error.message,
      stack: error.stack,
    });
    res.status(500).json({ error: 'Failed to process event' });
  }
});

function determineAgentStatus(eventType, _eventData) {
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

export default router;
