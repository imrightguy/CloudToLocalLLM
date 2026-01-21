/**
 * Tunnel Webhook Service
 *
 * Manages tunnel status webhooks including:
 * - Webhook registration and management
 * - Webhook delivery with retry logic
 * - Signature verification
 * - Event tracking and audit logging
 *
 * Validates: Requirements 4.10, 10.1, 10.2, 10.3, 10.4
 * - Provides tunnel status webhooks for real-time updates
 * - Supports webhook registration for events
 * - Implements webhook delivery with retry logic
 * - Supports webhook signature verification
 * - Tracks webhook delivery status and failures
 *
 * @fileoverview Tunnel webhook management service
 * @version 1.0.0
 */

import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';
import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class TunnelWebhookService {
  constructor() {
    this.pool = null;
    this.maxRetries = 5;
    this.retryDelays = [1, 5, 30, 300, 3600]; // seconds: 1s, 5s, 30s, 5m, 1h
  }

  /**
   * Initialize the webhook service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info('[TunnelWebhookService] Tunnel webhook service initialized');
    } catch (error) {
      logger.error(
        '[TunnelWebhookService] Failed to initialize webhook service',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Register a webhook for tunnel events
   *
   * @param {string} userId - User ID
   * @param {string} tunnelId - Tunnel ID (optional, null for all tunnels)
   * @param {string} url - Webhook URL
   * @param {Array<string>} events - Events to subscribe to
   * @returns {Promise<Object>} Registered webhook
   */
  async registerWebhook(
    userId,
    tunnelId,
    url,
    events = ['tunnel.status_changed'],
  ) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Validate URL
      if (!url || typeof url !== 'string' || url.trim().length === 0) {
        throw new Error('Webhook URL is required');
      }

      try {
        new URL(url);
      } catch {
        throw new Error('Invalid webhook URL format');
      }

      // Validate events
      if (!Array.isArray(events) || events.length === 0) {
        throw new Error('At least one event must be specified');
      }

      const validEvents = [
        'tunnel.status_changed',
        'tunnel.created',
        'tunnel.deleted',
        'tunnel.metrics_updated',
      ];
      for (const event of events) {
        if (!validEvents.includes(event)) {
          throw new Error(`Invalid event type: ${event}`);
        }
      }

      // If tunnelId is provided, verify ownership
      if (tunnelId) {
        const tunnelResult = await client.query(
          'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
          [tunnelId, userId],
        );

        if (tunnelResult.rows.length === 0) {
          throw new Error('Tunnel not found');
        }
      }

      // Generate webhook secret
      const secret = crypto.randomBytes(32).toString('hex');

      // Register webhook
      const webhookId = uuidv4();
      const result = await client.query(
        `INSERT INTO tunnel_webhooks (id, user_id, tunnel_id, url, events, secret)
         VALUES ($1, $2, $3, $4, $5, $6)
         RETURNING *`,
        [webhookId, userId, tunnelId, url, events, secret],
      );

      await client.query('COMMIT');

      logger.info('[TunnelWebhookService] Webhook registered', {
        webhookId,
        userId,
        tunnelId,
        url,
      });

      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelWebhookService] Failed to register webhook', {
        userId,
        tunnelId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get webhook by ID
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID (for authorization)
   * @returns {Promise<Object>} Webhook data
   */
  async getWebhookById(webhookId, userId) {
    try {
      const result = await this.pool.query(
        'SELECT * FROM tunnel_webhooks WHERE id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (result.rows.length === 0) {
        throw new Error('Webhook not found');
      }

      return result.rows[0];
    } catch (error) {
      logger.error('[TunnelWebhookService] Failed to get webhook', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * List webhooks for a user
   *
   * @param {string} userId - User ID
   * @param {string} tunnelId - Optional tunnel ID filter
   * @param {Object} options - Query options
   * @returns {Promise<Array>} Webhooks
   */
  async listWebhooks(userId, tunnelId = null, options = {}) {
    try {
      const { limit = 50, offset = 0 } = options;

      let query = 'SELECT * FROM tunnel_webhooks WHERE user_id = $1';
      const params = [userId];
      let paramIndex = 2;

      if (tunnelId) {
        query += ` AND tunnel_id = $${paramIndex}`;
        params.push(tunnelId);
        paramIndex++;
      }

      query += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
      params.push(limit, offset);

      const result = await this.pool.query(query, params);

      return result.rows;
    } catch (error) {
      logger.error('[TunnelWebhookService] Failed to list webhooks', {
        userId,
        tunnelId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update webhook
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID (for authorization)
   * @param {Object} updateData - Data to update
   * @returns {Promise<Object>} Updated webhook
   */
  async updateWebhook(webhookId, userId, updateData) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Verify webhook ownership
      const webhookResult = await client.query(
        'SELECT * FROM tunnel_webhooks WHERE id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (webhookResult.rows.length === 0) {
        throw new Error('Webhook not found');
      }

      const { url, events, is_active } = updateData;

      let updateQuery = 'UPDATE tunnel_webhooks SET updated_at = NOW()';
      const params = [];
      let paramIndex = 1;

      if (url !== undefined) {
        if (!url || typeof url !== 'string' || url.trim().length === 0) {
          throw new Error('Webhook URL must be a non-empty string');
        }

        try {
          new URL(url);
        } catch {
          throw new Error('Invalid webhook URL format');
        }

        updateQuery += `, url = $${paramIndex}`;
        params.push(url);
        paramIndex++;
      }

      if (events !== undefined) {
        if (!Array.isArray(events) || events.length === 0) {
          throw new Error('At least one event must be specified');
        }

        updateQuery += `, events = $${paramIndex}`;
        params.push(events);
        paramIndex++;
      }

      if (is_active !== undefined) {
        updateQuery += `, is_active = $${paramIndex}`;
        params.push(is_active);
        paramIndex++;
      }

      updateQuery += ` WHERE id = $${paramIndex} AND user_id = $${paramIndex + 1}`;
      params.push(webhookId, userId);

      await client.query(updateQuery, params);

      await client.query('COMMIT');

      logger.info('[TunnelWebhookService] Webhook updated', {
        webhookId,
        userId,
      });

      return this.getWebhookById(webhookId, userId);
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelWebhookService] Failed to update webhook', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Delete webhook
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID (for authorization)
   * @returns {Promise<void>}
   */
  async deleteWebhook(webhookId, userId) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Verify webhook ownership
      const webhookResult = await client.query(
        'SELECT * FROM tunnel_webhooks WHERE id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (webhookResult.rows.length === 0) {
        throw new Error('Webhook not found');
      }

      // Delete webhook (cascades to deliveries and events)
      await client.query('DELETE FROM tunnel_webhooks WHERE id = $1', [
        webhookId,
      ]);

      await client.query('COMMIT');

      logger.info('[TunnelWebhookService] Webhook deleted', {
        webhookId,
        userId,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelWebhookService] Failed to delete webhook', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Trigger webhook event for tunnel status change
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID
   * @param {string} eventType - Event type
   * @param {Object} eventData - Event data
   * @returns {Promise<void>}
   */
  async triggerWebhookEvent(tunnelId, userId, eventType, eventData) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Get all active webhooks for this tunnel or user
      const webhooksResult = await client.query(
        `SELECT * FROM tunnel_webhooks 
         WHERE user_id = $1 AND is_active = true 
         AND (tunnel_id IS NULL OR tunnel_id = $2)
         AND $3 = ANY(events)`,
        [userId, tunnelId, eventType],
      );

      const webhooks = webhooksResult.rows;

      // Log event
      for (const webhook of webhooks) {
        await client.query(
          `INSERT INTO tunnel_webhook_events (webhook_id, tunnel_id, user_id, event_type, event_data)
           VALUES ($1, $2, $3, $4, $5)`,
          [webhook.id, tunnelId, userId, eventType, JSON.stringify(eventData)],
        );
      }

      await client.query('COMMIT');

      // Queue deliveries asynchronously
      for (const webhook of webhooks) {
        this.queueWebhookDelivery(
          webhook.id,
          tunnelId,
          userId,
          eventType,
          eventData,
        ).catch((error) => {
          logger.error(
            '[TunnelWebhookService] Failed to queue webhook delivery',
            {
              webhookId: webhook.id,
              error: error.message,
            },
          );
        });
      }

      logger.debug('[TunnelWebhookService] Webhook event triggered', {
        tunnelId,
        userId,
        eventType,
        webhookCount: webhooks.length,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelWebhookService] Failed to trigger webhook event', {
        tunnelId,
        userId,
        eventType,
        error: error.message,
      });
    } finally {
      client.release();
    }
  }

  /**
   * Queue webhook delivery
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID
   * @param {string} eventType - Event type
   * @param {Object} eventData - Event data
   * @returns {Promise<void>}
   */
  async queueWebhookDelivery(
    webhookId,
    tunnelId,
    userId,
    eventType,
    eventData,
  ) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Create delivery record
      const deliveryId = uuidv4();
      const payload = {
        id: deliveryId,
        event: eventType,
        timestamp: new Date().toISOString(),
        data: eventData,
      };

      await client.query(
        `INSERT INTO tunnel_webhook_deliveries (id, webhook_id, tunnel_id, user_id, event_type, payload, status)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          deliveryId,
          webhookId,
          tunnelId,
          userId,
          eventType,
          JSON.stringify(payload),
          'pending',
        ],
      );

      await client.query('COMMIT');

      // Attempt delivery immediately
      setImmediate(() => {
        this.deliverWebhook(deliveryId).catch((error) => {
          logger.error('[TunnelWebhookService] Failed to deliver webhook', {
            deliveryId,
            error: error.message,
          });
        });
      });
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelWebhookService] Failed to queue webhook delivery', {
        webhookId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Deliver webhook to endpoint
   *
   * @param {string} deliveryId - Delivery ID
   * @returns {Promise<void>}
   */
  async deliverWebhook(deliveryId) {
    const client = await this.pool.connect();
    try {
      // Get delivery and webhook details
      const deliveryResult = await client.query(
        `SELECT d.*, w.url, w.secret FROM tunnel_webhook_deliveries d
         JOIN tunnel_webhooks w ON d.webhook_id = w.id
         WHERE d.id = $1`,
        [deliveryId],
      );

      if (deliveryResult.rows.length === 0) {
        logger.warn('[TunnelWebhookService] Delivery not found', {
          deliveryId,
        });
        return;
      }

      const delivery = deliveryResult.rows[0];

      // Skip if already delivered
      if (delivery.status === 'delivered') {
        logger.debug('[TunnelWebhookService] Delivery already completed', {
          deliveryId,
        });
        return;
      }

      // Check if max retries exceeded
      if (delivery.attempt_count >= delivery.max_attempts) {
        await client.query(
          'UPDATE tunnel_webhook_deliveries SET status = $1, updated_at = NOW() WHERE id = $2',
          ['failed', deliveryId],
        );

        logger.warn('[TunnelWebhookService] Max retries exceeded', {
          deliveryId,
          attempts: delivery.attempt_count,
        });

        client.release();
        return;
      }

      // Generate signature
      const payload = JSON.stringify(delivery.payload);
      const signature = crypto
        .createHmac('sha256', delivery.secret)
        .update(payload)
        .digest('hex');

      // Attempt delivery
      try {
        const response = await fetch(delivery.url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-Webhook-Signature': signature,
            'X-Webhook-ID': delivery.webhook_id,
            'X-Delivery-ID': deliveryId,
          },
          body: payload,
          timeout: 10000,
        });

        const statusCode = response.status;

        if (statusCode >= 200 && statusCode < 300) {
          // Success
          await client.query(
            `UPDATE tunnel_webhook_deliveries 
             SET status = $1, http_status_code = $2, delivered_at = NOW(), updated_at = NOW()
             WHERE id = $3`,
            ['delivered', statusCode, deliveryId],
          );

          logger.info('[TunnelWebhookService] Webhook delivered successfully', {
            deliveryId,
            statusCode,
            url: delivery.url,
          });
        } else {
          // Retry
          this.scheduleRetry(
            deliveryId,
            delivery.attempt_count,
            statusCode,
            'HTTP ' + statusCode,
          );
        }
      } catch (error) {
        // Network error, retry
        this.scheduleRetry(
          deliveryId,
          delivery.attempt_count,
          null,
          error.message,
        );
      }
    } catch (error) {
      logger.error('[TunnelWebhookService] Failed to deliver webhook', {
        deliveryId,
        error: error.message,
      });
    } finally {
      client.release();
    }
  }

  /**
   * Schedule webhook retry
   *
   * @param {string} deliveryId - Delivery ID
   * @param {number} attemptCount - Current attempt count
   * @param {number} httpStatusCode - HTTP status code
   * @param {string} errorMessage - Error message
   * @returns {Promise<void>}
   */
  async scheduleRetry(deliveryId, attemptCount, httpStatusCode, errorMessage) {
    const client = await this.pool.connect();
    try {
      const nextAttempt = attemptCount + 1;
      const delaySeconds =
        this.retryDelays[Math.min(attemptCount, this.retryDelays.length - 1)];
      const nextRetryAt = new Date(Date.now() + delaySeconds * 1000);

      await client.query(
        `UPDATE tunnel_webhook_deliveries 
         SET status = $1, attempt_count = $2, http_status_code = $3, error_message = $4, 
             next_retry_at = $5, updated_at = NOW()
         WHERE id = $6`,
        [
          'retrying',
          nextAttempt,
          httpStatusCode,
          errorMessage,
          nextRetryAt,
          deliveryId,
        ],
      );

      logger.info('[TunnelWebhookService] Webhook retry scheduled', {
        deliveryId,
        nextAttempt,
        delaySeconds,
        nextRetryAt,
      });
    } catch (error) {
      logger.error('[TunnelWebhookService] Failed to schedule retry', {
        deliveryId,
        error: error.message,
      });
    } finally {
      client.release();
    }
  }

  /**
   * Get webhook delivery status
   *
   * @param {string} deliveryId - Delivery ID
   * @returns {Promise<Object>} Delivery status
   */
  async getDeliveryStatus(deliveryId) {
    try {
      const result = await this.pool.query(
        'SELECT * FROM tunnel_webhook_deliveries WHERE id = $1',
        [deliveryId],
      );

      if (result.rows.length === 0) {
        throw new Error('Delivery not found');
      }

      return result.rows[0];
    } catch (error) {
      logger.error('[TunnelWebhookService] Failed to get delivery status', {
        deliveryId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get webhook delivery history
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID (for authorization)
   * @param {Object} options - Query options
   * @returns {Promise<Array>} Delivery history
   */
  async getDeliveryHistory(webhookId, userId, options = {}) {
    try {
      // Verify webhook ownership
      const webhookResult = await this.pool.query(
        'SELECT id FROM tunnel_webhooks WHERE id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (webhookResult.rows.length === 0) {
        throw new Error('Webhook not found');
      }

      const { limit = 50, offset = 0 } = options;

      const result = await this.pool.query(
        `SELECT * FROM tunnel_webhook_deliveries WHERE webhook_id = $1 
         ORDER BY created_at DESC LIMIT $2 OFFSET $3`,
        [webhookId, limit, offset],
      );

      return result.rows;
    } catch (error) {
      logger.error('[TunnelWebhookService] Failed to get delivery history', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Retry failed deliveries
   * Called periodically to retry pending/retrying deliveries
   *
   * @returns {Promise<void>}
   */
  async retryFailedDeliveries() {
    try {
      const result = await this.pool.query(
        `SELECT id FROM tunnel_webhook_deliveries 
         WHERE status IN ('pending', 'retrying') 
         AND (next_retry_at IS NULL OR next_retry_at <= NOW())
         AND attempt_count < max_attempts
         LIMIT 100`,
      );

      const deliveries = result.rows;

      logger.debug('[TunnelWebhookService] Retrying failed deliveries', {
        count: deliveries.length,
      });

      for (const delivery of deliveries) {
        this.deliverWebhook(delivery.id).catch((error) => {
          logger.error('[TunnelWebhookService] Failed to retry delivery', {
            deliveryId: delivery.id,
            error: error.message,
          });
        });
      }
    } catch (error) {
      logger.error('[TunnelWebhookService] Failed to retry failed deliveries', {
        error: error.message,
      });
    }
  }
}
