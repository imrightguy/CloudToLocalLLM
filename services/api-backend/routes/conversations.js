/**
 * @fileoverview API routes for conversation management
 * Handles CRUD operations for user conversations stored in PostgreSQL
 */

import express from 'express';
import winston from 'winston';
import { z } from 'zod';
import { validateSchema } from '../middleware/schema-validation.js';

const messageSchema = z.object({
  role: z.string().default('user'),
  content: z.string().default(''),
  model: z.string().optional(),
  status: z.string().default('sent'),
  error: z.string().nullable().optional(),
  timestamp: z.string().datetime({ offset: true }).optional(),
  metadata: z.record(z.unknown()).optional(),
});

const createConversationSchema = {
  body: z.object({
    title: z.string().min(1).max(500),
    model: z.string().min(1).max(200),
    metadata: z.record(z.unknown()).optional(),
    messages: z.array(messageSchema).optional(),
  }),
};

const updateConversationSchema = {
  params: z.object({
    id: z.string().min(1).max(200),
  }),
  body: z.object({
    title: z.string().min(1).max(500).optional(),
    model: z.string().min(1).max(200).optional(),
    metadata: z.record(z.unknown()).optional(),
    messages: z.array(messageSchema).optional(),
  }).refine((data) => data.title || data.model || data.metadata || data.messages, {
    message: 'At least one field must be provided for update',
  }),
};

const conversationIdSchema = {
  params: z.object({
    id: z.string().min(1).max(200),
  }),
};

export function createConversationRoutes(
  dbMigrator,
  logger = winston.createLogger(),
) {
  logger.info('Creating conversation routes...');
  const router = express.Router();
  logger.info('Express router created successfully');

  /**
   * GET /api/conversations
   * Get all conversations for the authenticated user
   */
  router.get('/', async (req, res) => {
    try {
      const userId = req.auth?.payload?.sub || req.user?.sub;

      if (!userId) {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'User ID not found in token',
        });
      }

      if (!dbMigrator || !dbMigrator.pool) {
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'Database not initialized',
        });
      }

      // Get conversations for user, ordered by most recently updated
      const { rows: conversations } = await dbMigrator.pool.query(
        `SELECT
id,
  title,
  model,
  created_at,
  updated_at,
  metadata
        FROM conversations
        WHERE user_id = $1
        ORDER BY updated_at DESC`,
        [userId],
      );

      // Get message counts for each conversation
      const conversationIds = conversations.map((c) => c.id);
      let messageCounts = {};

      if (conversationIds.length > 0) {
        const { rows: counts } = await dbMigrator.pool.query(
          `SELECT conversation_id, COUNT(*) as count
          FROM messages
          WHERE conversation_id = ANY($1)
          GROUP BY conversation_id`,
          [conversationIds],
        );

        messageCounts = counts.reduce((acc, row) => {
          acc[row.conversation_id] = parseInt(row.count, 10);
          return acc;
        }, {});
      }

      const conversationsWithCounts = conversations.map((conv) => ({
        ...conv,
        messageCount: messageCounts[conv.id] || 0,
      }));

      res.json({
        success: true,
        conversations: conversationsWithCounts,
        count: conversationsWithCounts.length,
      });
    } catch (error) {
      logger.error('Failed to get conversations', {
        error: error.message,
        stack: error.stack,
        userId: req.auth?.payload?.sub || req.user?.sub,
      });
      res.status(500).json({
        error: 'Internal Server Error',
        message: 'Failed to retrieve conversations',
      });
    }
  });

  /**
   * GET /api/conversations/:id
   * Get a specific conversation with all its messages
   */
  router.get('/:id', validateSchema(conversationIdSchema), async (req, res) => {
    try {
      const userId = req.auth?.payload?.sub || req.user?.sub;
      const conversationId = req.params.id;

      if (!userId) {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'User ID not found in token',
        });
      }

      if (!dbMigrator || !dbMigrator.pool) {
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'Database not initialized',
        });
      }

      // Get conversation
      const { rows: conversationRows } = await dbMigrator.pool.query(
        `SELECT id, title, model, created_at, updated_at, metadata
        FROM conversations
        WHERE id = $1 AND user_id = $2`,
        [conversationId, userId],
      );

      if (conversationRows.length === 0) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Conversation not found',
        });
      }

      const conversation = conversationRows[0];

      // Get messages for this conversation
      const { rows: messages } = await dbMigrator.pool.query(
        `SELECT
id,
  role,
  content,
  model,
  status,
  error,
  timestamp,
  metadata
        FROM messages
        WHERE conversation_id = $1
        ORDER BY timestamp ASC`,
        [conversationId],
      );

      res.json({
        success: true,
        conversation: {
          ...conversation,
          messages: messages,
        },
      });
    } catch (error) {
      logger.error('Failed to get conversation', {
        error: error.message,
        stack: error.stack,
        userId: req.auth?.payload?.sub || req.user?.sub,
        conversationId: req.params.id,
      });
      res.status(500).json({
        error: 'Internal Server Error',
        message: 'Failed to retrieve conversation',
      });
    }
  });

  /**
   * POST /api/conversations
   * Create a new conversation
   */
  router.post('/', validateSchema(createConversationSchema), async (req, res) => {
    try {
      const userId = req.auth?.payload?.sub || req.user?.sub;
      const { title, model, messages, metadata } = req.body;

      if (!userId) {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'User ID not found in token',
        });
      }

      if (!dbMigrator || !dbMigrator.pool) {
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'Database not initialized',
        });
      }

      const client = await dbMigrator.pool.connect();

      try {
        await client.query('BEGIN');

        // Create conversation
        const { rows: conversationRows } = await client.query(
          `INSERT INTO conversations(user_id, title, model, metadata)
VALUES($1, $2, $3, $4:: jsonb)
          RETURNING id, title, model, created_at, updated_at, metadata`,
          [userId, title, model, JSON.stringify(metadata || {})],
        );

        const conversation = conversationRows[0];
        const conversationId = conversation.id;

        // Insert messages if provided
        if (messages && Array.isArray(messages) && messages.length > 0) {
          const messageValues = messages.map((msg) => ({
            conversation_id: conversationId,
            role: msg.role || 'user',
            content: msg.content || '',
            model: msg.model || model,
            status: msg.status || 'sent',
            error: msg.error || null,
            timestamp: msg.timestamp ? new Date(msg.timestamp) : new Date(),
            metadata: msg.metadata ? JSON.stringify(msg.metadata) : '{}',
          }));

          for (const msg of messageValues) {
            await client.query(
              `INSERT INTO messages(
  conversation_id, role, content, model, status, error, timestamp, metadata
) VALUES($1, $2, $3, $4, $5, $6, $7, $8:: jsonb)`,
              [
                msg.conversation_id,
                msg.role,
                msg.content,
                msg.model,
                msg.status,
                msg.error,
                msg.timestamp,
                msg.metadata,
              ],
            );
          }
        }

        await client.query('COMMIT');

        // Get full conversation with messages
        const { rows: messageRows } = await dbMigrator.pool.query(
          `SELECT id, role, content, model, status, error, timestamp, metadata
          FROM messages
          WHERE conversation_id = $1
          ORDER BY timestamp ASC`,
          [conversationId],
        );

        res.status(201).json({
          success: true,
          conversation: {
            ...conversation,
            messages: messageRows,
          },
        });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('Failed to create conversation', {
        error: error.message,
        stack: error.stack,
        userId: req.auth?.payload?.sub || req.user?.sub,
      });
      res.status(500).json({
        error: 'Internal Server Error',
        message: 'Failed to create conversation',
      });
    }
  });

  /**
   * PUT /api/conversations/:id
   * Update a conversation (title, metadata, or add/update messages)
   */
  router.put('/:id', validateSchema(updateConversationSchema), async (req, res) => {
    try {
      const userId = req.auth?.payload?.sub || req.user?.sub;
      const conversationId = req.params.id;
      const { title, messages, model, metadata } = req.body;

      if (!userId) {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'User ID not found in token',
        });
      }

      if (!dbMigrator || !dbMigrator.pool) {
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'Database not initialized',
        });
      }

      const client = await dbMigrator.pool.connect();

      try {
        await client.query('BEGIN');

        // Check if conversation exists
        const { rows: conversationRows } = await client.query(
          `SELECT id FROM conversations
          WHERE id = $1 AND user_id = $2`,
          [conversationId, userId],
        );

        if (conversationRows.length === 0) {
          // Conversation not found - handle as Upsert (Create)
          // This supports client-generated IDs (e.g. conv_timestamp)

          // For creation, we need at least a model. Title can be defaulted.
          const newModel = model || 'gpt-3.5-turbo'; // Default if missing
          const newTitle = title || 'New Conversation';

          await client.query(
            `INSERT INTO conversations(id, user_id, title, model, metadata)
VALUES($1, $2, $3, $4, $5:: jsonb)`,
            [
              conversationId,
              userId,
              newTitle,
              newModel,
              JSON.stringify(metadata || {}),
            ],
          );
        } else {
          // Update existing conversation
          if (title) {
            await client.query(
              'UPDATE conversations SET title = $1 WHERE id = $2',
              [title, conversationId],
            );
          }

          // Update metadata if provided
          if (metadata) {
            await client.query(
              'UPDATE conversations SET metadata = $1::jsonb WHERE id = $2',
              [JSON.stringify(metadata), conversationId],
            );
          }
        }

        // Replace all messages if provided
        if (messages && Array.isArray(messages)) {
          // Delete existing messages
          await client.query(
            'DELETE FROM messages WHERE conversation_id = $1',
            [conversationId],
          );

          // Insert new messages
          for (const msg of messages) {
            await client.query(
              `INSERT INTO messages(
  conversation_id, role, content, model, status, error, timestamp, metadata
) VALUES($1, $2, $3, $4, $5, $6, $7, $8:: jsonb)`,
              [
                conversationId,
                msg.role || 'user',
                msg.content || '',
                msg.model || model || null,
                msg.status || 'sent',
                msg.error || null,
                msg.timestamp ? new Date(msg.timestamp) : new Date(),
                msg.metadata ? JSON.stringify(msg.metadata) : '{}',
              ],
            );
          }
        }

        await client.query('COMMIT');

        // Get updated/created conversation
        const { rows: updatedConversation } = await dbMigrator.pool.query(
          `SELECT id, title, model, created_at, updated_at, metadata
          FROM conversations
          WHERE id = $1`,
          [conversationId],
        );

        const { rows: messageRows } = await dbMigrator.pool.query(
          `SELECT id, role, content, model, status, error, timestamp, metadata
          FROM messages
          WHERE conversation_id = $1
          ORDER BY timestamp ASC`,
          [conversationId],
        );

        res.json({
          success: true,
          conversation: {
            ...updatedConversation[0],
            messages: messageRows,
          },
        });
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('Failed to update conversation', {
        error: error.message,
        stack: error.stack,
        userId: req.auth?.payload?.sub || req.user?.sub,
        conversationId: req.params.id,
      });
      res.status(500).json({
        error: 'Internal Server Error',
        message: 'Failed to update conversation',
      });
    }
  });

  /**
   * DELETE /api/conversations/:id
   * Delete a conversation and all its messages
   */
  router.delete('/:id', validateSchema(conversationIdSchema), async (req, res) => {
    try {
      const userId = req.auth?.payload?.sub || req.user?.sub;
      const conversationId = req.params.id;

      if (!userId) {
        return res.status(401).json({
          error: 'Unauthorized',
          message: 'User ID not found in token',
        });
      }

      if (!dbMigrator || !dbMigrator.pool) {
        return res.status(503).json({
          error: 'Service Unavailable',
          message: 'Database not initialized',
        });
      }

      // Verify conversation belongs to user and delete (CASCADE will delete messages)
      const { rows } = await dbMigrator.pool.query(
        `DELETE FROM conversations
        WHERE id = $1 AND user_id = $2
        RETURNING id`,
        [conversationId, userId],
      );

      if (rows.length === 0) {
        return res.status(404).json({
          error: 'Not Found',
          message: 'Conversation not found',
        });
      }

      res.json({
        success: true,
        message: 'Conversation deleted successfully',
      });
    } catch (error) {
      logger.error('Failed to delete conversation', {
        error: error.message,
        stack: error.stack,
        userId: req.auth?.payload?.sub || req.user?.sub,
        conversationId: req.params.id,
      });
      res.status(500).json({
        error: 'Internal Server Error',
        message: 'Failed to delete conversation',
      });
    }
  });

  try {
    logger.info('Conversation routes created successfully');
    return router;
  } catch (error) {
    logger.error('Failed to create conversation routes', {
      error: error.message,
      stack: error.stack,
    });
    throw error;
  }
}
