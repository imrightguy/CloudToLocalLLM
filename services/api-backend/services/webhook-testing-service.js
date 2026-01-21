/**
 * Webhook Testing and Debugging Service
 *
 * Provides utilities for testing and debugging webhook functionality including:
 * - Test payload generation for various event types
 * - Webhook delivery simulation
 * - Debugging utilities for webhook inspection
 * - Test event tracking and history
 *
 * Validates: Requirements 10.8
 * - Provides webhook testing and debugging tools
 * - Generates test payloads
 * - Tracks test events
 *
 * @fileoverview Webhook testing and debugging service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';
import crypto from 'crypto';

// Allow-list of domains/hosts for webhook testing
// Change or extend these values to suit your trusted set
const ALLOWED_WEBHOOK_HOSTS = [
  'example.com',
  'webhook.site',
  // Add more allowed hostnames here
];
/**
 * Webhook Testing and Debugging Service
 *
 * Provides comprehensive testing and debugging capabilities for webhooks
 */
export class WebhookTestingService {
  constructor() {
    this.pool = null;
    this.testEventCache = new Map();
  }

  /**
   * Initialize the testing service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info('[WebhookTesting] Webhook testing service initialized');
    } catch (error) {
      logger.error('[WebhookTesting] Failed to initialize testing service', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Generate test payload for a specific event type
   *
   * @param {string} eventType - Type of event (tunnel.status_changed, proxy.metrics, etc.)
   * @param {object} customData - Optional custom data to merge with generated payload
   * @returns {object} Generated test payload
   */
  generateTestPayload(eventType, customData = {}) {
    const basePayload = {
      id: crypto.randomUUID(),
      type: eventType,
      timestamp: new Date().toISOString(),
      version: '1.0',
    };

    // Generate event-specific data
    const eventData = this.generateEventData(eventType);

    return {
      ...basePayload,
      data: {
        ...eventData,
        ...customData,
      },
    };
  }

  /**
   * Generate event-specific data based on event type
   *
   * @private
   * @param {string} eventType - Type of event
   * @returns {object} Event-specific data
   */
  generateEventData(eventType) {
    const eventDataGenerators = {
      'tunnel.status_changed': () => ({
        tunnelId: crypto.randomUUID(),
        userId: crypto.randomUUID(),
        previousStatus: 'connected',
        newStatus: 'disconnected',
        reason: 'user_initiated',
        timestamp: new Date().toISOString(),
      }),
      'tunnel.created': () => ({
        tunnelId: crypto.randomUUID(),
        userId: crypto.randomUUID(),
        name: 'Test Tunnel',
        config: {
          maxConnections: 100,
          timeout: 30000,
          compression: true,
        },
        timestamp: new Date().toISOString(),
      }),
      'tunnel.deleted': () => ({
        tunnelId: crypto.randomUUID(),
        userId: crypto.randomUUID(),
        reason: 'user_initiated',
        timestamp: new Date().toISOString(),
      }),
      'tunnel.metrics': () => ({
        tunnelId: crypto.randomUUID(),
        userId: crypto.randomUUID(),
        metrics: {
          requestCount: Math.floor(Math.random() * 1000),
          successCount: Math.floor(Math.random() * 900),
          errorCount: Math.floor(Math.random() * 100),
          averageLatency: Math.floor(Math.random() * 500),
          totalDataTransferred: Math.floor(Math.random() * 1000000),
        },
        timestamp: new Date().toISOString(),
      }),
      'proxy.status_changed': () => ({
        proxyId: crypto.randomUUID(),
        previousStatus: 'running',
        newStatus: 'stopped',
        reason: 'maintenance',
        timestamp: new Date().toISOString(),
      }),
      'proxy.metrics': () => ({
        proxyId: crypto.randomUUID(),
        metrics: {
          activeConnections: Math.floor(Math.random() * 1000),
          requestsPerSecond: Math.floor(Math.random() * 100),
          cpuUsage: Math.random() * 100,
          memoryUsage: Math.random() * 100,
          uptime: Math.floor(Math.random() * 86400),
        },
        timestamp: new Date().toISOString(),
      }),
      'user.activity': () => ({
        userId: crypto.randomUUID(),
        action: 'tunnel_created',
        resource: 'tunnel',
        resourceId: crypto.randomUUID(),
        details: {
          ipAddress: '192.168.1.1',
          userAgent: 'Mozilla/5.0',
        },
        timestamp: new Date().toISOString(),
      }),
    };

    const generator = eventDataGenerators[eventType];
    if (!generator) {
      // Return generic event data for unknown types
      return {
        eventType,
        timestamp: new Date().toISOString(),
        data: {},
      };
    }

    return generator();
  }

  /**
   * Get list of supported event types for testing
   *
   * @returns {array} Array of supported event types
   */
  getSupportedEventTypes() {
    return [
      'tunnel.status_changed',
      'tunnel.created',
      'tunnel.deleted',
      'tunnel.metrics',
      'proxy.status_changed',
      'proxy.metrics',
      'user.activity',
    ];
  }

  /**
   * Simulate webhook delivery to a test endpoint
   *
   * @param {string} webhookUrl - URL to send test webhook to
   * @param {object} payload - Webhook payload to send
   * @param {string} secret - Optional webhook secret for signature
   * @returns {object} Delivery result with status and response
   */
  async simulateWebhookDelivery(webhookUrl, payload, secret = null) {
    const testId = crypto.randomUUID();
    const timestamp = Date.now();

    try {
      // Validate URL
      const url = new URL(webhookUrl);
      if (!['http:', 'https:'].includes(url.protocol)) {
        throw new Error('Invalid webhook URL protocol');
      }

      // SSRF protection: allow only approved hosts/domains
      // Strip leading 'www.' if present
      let hostname = url.hostname.replace(/^www\./, '');
      if (!ALLOWED_WEBHOOK_HOSTS.includes(hostname)) {
        throw new Error(
          'Destination host not permitted for webhook testing: ' + hostname,
        );
      }

      // Generate signature if secret provided
      let headers = {
        'Content-Type': 'application/json',
        'X-Webhook-Test-ID': testId,
        'X-Webhook-Timestamp': timestamp.toString(),
      };

      if (secret) {
        const signature = this.generateWebhookSignature(
          payload,
          secret,
          timestamp,
        );
        headers['X-Webhook-Signature'] = signature;
      }

      // Simulate delivery
      const response = await fetch(webhookUrl, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
        timeout: 10000,
      });

      const result = {
        testId,
        success: response.ok,
        statusCode: response.status,
        statusText: response.statusText,
        responseTime: Date.now() - timestamp,
        headers: Object.fromEntries(response.headers),
        payload,
      };

      // Try to parse response body
      try {
        const contentType = response.headers.get('content-type');
        if (contentType && contentType.includes('application/json')) {
          result.responseBody = await response.json();
        } else {
          result.responseBody = await response.text();
        }
      } catch {
        result.responseBody = null;
      }

      // Cache test event
      this.cacheTestEvent(testId, result);

      logger.info('[WebhookTesting] Webhook delivery simulated', {
        testId,
        webhookUrl,
        statusCode: result.statusCode,
        responseTime: result.responseTime,
      });

      return result;
    } catch (error) {
      const result = {
        testId,
        success: false,
        error: error.message,
        responseTime: Date.now() - timestamp,
        payload,
      };

      this.cacheTestEvent(testId, result);

      logger.error('[WebhookTesting] Webhook delivery simulation failed', {
        testId,
        webhookUrl,
        error: error.message,
      });

      return result;
    }
  }

  /**
   * Generate webhook signature for testing
   *
   * @private
   * @param {object} payload - Webhook payload
   * @param {string} secret - Webhook secret
   * @param {number} timestamp - Timestamp in milliseconds
   * @returns {string} Generated signature
   */
  generateWebhookSignature(payload, secret, timestamp) {
    const message = `${timestamp}.${JSON.stringify(payload)}`;
    const signature = crypto
      .createHmac('sha256', secret)
      .update(message)
      .digest('hex');
    return `sha256=${signature}`;
  }

  /**
   * Validate webhook signature
   *
   * @param {string} signature - Signature from webhook header
   * @param {object} payload - Webhook payload
   * @param {string} secret - Webhook secret
   * @param {number} timestamp - Timestamp from webhook header
   * @returns {boolean} True if signature is valid
   */
  validateWebhookSignature(signature, payload, secret, timestamp) {
    try {
      const expectedSignature = this.generateWebhookSignature(
        payload,
        secret,
        timestamp,
      );
      const signatureBuf = Buffer.from(signature);
      const expectedBuf = Buffer.from(expectedSignature);

      // Check if buffers have same length before timing safe comparison
      if (signatureBuf.length !== expectedBuf.length) {
        return false;
      }

      return crypto.timingSafeEqual(signatureBuf, expectedBuf);
    } catch {
      // If any error occurs during validation, return false
      return false;
    }
  }

  /**
   * Cache test event for debugging
   *
   * @private
   * @param {string} testId - Test event ID
   * @param {object} result - Test result
   */
  cacheTestEvent(testId, result) {
    this.testEventCache.set(testId, {
      ...result,
      cachedAt: new Date().toISOString(),
    });

    // Keep cache size manageable (max 1000 entries)
    if (this.testEventCache.size > 1000) {
      const firstKey = this.testEventCache.keys().next().value;
      this.testEventCache.delete(firstKey);
    }
  }

  /**
   * Get test event by ID
   *
   * @param {string} testId - Test event ID
   * @returns {object|null} Test event or null if not found
   */
  getTestEvent(testId) {
    return this.testEventCache.get(testId) || null;
  }

  /**
   * Get all cached test events
   *
   * @param {number} limit - Maximum number of events to return
   * @returns {array} Array of test events
   */
  getAllTestEvents(limit = 100) {
    const events = Array.from(this.testEventCache.values());
    return events.slice(-limit);
  }

  /**
   * Clear test event cache
   */
  clearTestEventCache() {
    this.testEventCache.clear();
    logger.info('[WebhookTesting] Test event cache cleared');
  }

  /**
   * Get webhook debugging information
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @returns {object} Debugging information
   */
  async getWebhookDebugInfo(webhookId, userId) {
    try {
      const client = await this.pool.connect();
      try {
        // Get webhook details
        const webhookResult = await client.query(
          `SELECT id, url, events, active, created_at, updated_at
           FROM webhooks
           WHERE id = $1 AND user_id = $2`,
          [webhookId, userId],
        );

        if (webhookResult.rows.length === 0) {
          return { error: 'Webhook not found' };
        }

        const webhook = webhookResult.rows[0];

        // Get recent deliveries
        const deliveriesResult = await client.query(
          `SELECT id, status, attempt_count, last_error, created_at, updated_at
           FROM webhook_deliveries
           WHERE webhook_id = $1
           ORDER BY created_at DESC
           LIMIT 10`,
          [webhookId],
        );

        // Get delivery statistics
        const statsResult = await client.query(
          `SELECT 
             COUNT(*) as total_deliveries,
             SUM(CASE WHEN status = 'delivered' THEN 1 ELSE 0 END) as successful,
             SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed,
             SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending,
             AVG(EXTRACT(EPOCH FROM (updated_at - created_at))) as avg_delivery_time
           FROM webhook_deliveries
           WHERE webhook_id = $1`,
          [webhookId],
        );

        const stats = statsResult.rows[0];

        return {
          webhook,
          recentDeliveries: deliveriesResult.rows,
          statistics: {
            totalDeliveries: parseInt(stats.total_deliveries),
            successful: parseInt(stats.successful) || 0,
            failed: parseInt(stats.failed) || 0,
            pending: parseInt(stats.pending) || 0,
            averageDeliveryTime: parseFloat(stats.avg_delivery_time) || 0,
            successRate:
              stats.total_deliveries > 0
                ? (
                    (parseInt(stats.successful) /
                      parseInt(stats.total_deliveries)) *
                    100
                  ).toFixed(2)
                : 0,
          },
        };
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('[WebhookTesting] Failed to get webhook debug info', {
        webhookId,
        userId,
        error: error.message,
      });
      return { error: error.message };
    }
  }

  /**
   * Get webhook delivery details
   *
   * @param {string} deliveryId - Delivery ID
   * @param {string} userId - User ID
   * @returns {object} Delivery details
   */
  async getDeliveryDetails(deliveryId, userId) {
    try {
      const client = await this.pool.connect();
      try {
        const result = await client.query(
          `SELECT d.*, w.url, w.events
           FROM webhook_deliveries d
           JOIN webhooks w ON d.webhook_id = w.id
           WHERE d.id = $1 AND w.user_id = $2`,
          [deliveryId, userId],
        );

        if (result.rows.length === 0) {
          return { error: 'Delivery not found' };
        }

        return result.rows[0];
      } finally {
        client.release();
      }
    } catch (error) {
      logger.error('[WebhookTesting] Failed to get delivery details', {
        deliveryId,
        userId,
        error: error.message,
      });
      return { error: error.message };
    }
  }

  /**
   * Validate webhook payload structure
   *
   * @param {object} payload - Webhook payload to validate
   * @returns {object} Validation result with isValid and errors
   */
  validatePayloadStructure(payload) {
    const errors = [];

    if (!payload || typeof payload !== 'object') {
      errors.push('Payload must be an object');
      return { isValid: false, errors };
    }

    // Check required fields
    if (!payload.id) {
      errors.push('Payload must have an id field');
    }
    if (!payload.type) {
      errors.push('Payload must have a type field');
    }
    if (!payload.timestamp) {
      errors.push('Payload must have a timestamp field');
    }
    if (!payload.data || typeof payload.data !== 'object') {
      errors.push('Payload must have a data object');
    }

    // Validate timestamp format - must be ISO 8601
    if (payload.timestamp) {
      const iso8601Regex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z?$/;
      if (!iso8601Regex.test(payload.timestamp)) {
        errors.push('Timestamp must be a valid ISO 8601 date string');
      } else {
        try {
          const date = new Date(payload.timestamp);
          if (isNaN(date.getTime())) {
            errors.push('Timestamp must be a valid ISO 8601 date string');
          }
        } catch {
          errors.push('Timestamp must be a valid ISO 8601 date string');
        }
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
    };
  }
}

// Export singleton instance
export const webhookTestingService = new WebhookTestingService();
