/**
 * Webhook Event Filter Service
 *
 * Manages webhook event filtering including:
 * - Filter configuration and validation
 * - Event matching against filters
 * - Filter persistence and retrieval
 *
 * Validates: Requirements 10.5
 * - Implements webhook event filtering
 * - Supports filter configuration
 * - Validates filter rules
 *
 * @fileoverview Webhook event filtering service
 * @version 1.0.0
 */

import { v4 as uuidv4 } from 'uuid';
import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class WebhookEventFilter {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize the filter service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info('[WebhookEventFilter] Event filter service initialized');
    } catch (error) {
      logger.error('[WebhookEventFilter] Failed to initialize filter service', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Validate filter configuration
   *
   * @param {Object} filterConfig - Filter configuration
   * @returns {Object} Validation result with isValid and errors
   */
  validateFilterConfig(filterConfig) {
    const errors = [];

    if (!filterConfig) {
      return { isValid: true, errors: [] };
    }

    // Validate filter type
    if (
      filterConfig.type &&
      !['include', 'exclude'].includes(filterConfig.type)
    ) {
      errors.push('Filter type must be "include" or "exclude"');
    }

    // Validate event patterns
    if (filterConfig.eventPatterns) {
      if (!Array.isArray(filterConfig.eventPatterns)) {
        errors.push('Event patterns must be an array');
      } else {
        for (let i = 0; i < filterConfig.eventPatterns.length; i++) {
          const pattern = filterConfig.eventPatterns[i];
          if (typeof pattern !== 'string' || pattern.trim().length === 0) {
            errors.push(
              `Event pattern at index ${i} must be a non-empty string`,
            );
          }
          // Validate pattern format (simple validation)
          if (!this._isValidEventPattern(pattern)) {
            errors.push(`Invalid event pattern format: ${pattern}`);
          }
        }
      }
    }

    // Validate property filters
    if (filterConfig.propertyFilters) {
      if (
        typeof filterConfig.propertyFilters !== 'object' ||
        Array.isArray(filterConfig.propertyFilters)
      ) {
        errors.push('Property filters must be an object');
      } else {
        for (const [key, value] of Object.entries(
          filterConfig.propertyFilters,
        )) {
          if (!this._isValidPropertyFilter(value)) {
            errors.push(
              `Invalid property filter for "${key}": ${JSON.stringify(value)}`,
            );
          }
        }
      }
    }

    // Validate rate limit
    if (filterConfig.rateLimit !== undefined) {
      if (typeof filterConfig.rateLimit !== 'object') {
        errors.push('Rate limit must be an object');
      } else {
        if (
          filterConfig.rateLimit.maxEvents !== undefined &&
          typeof filterConfig.rateLimit.maxEvents !== 'number'
        ) {
          errors.push('Rate limit maxEvents must be a number');
        }
        if (
          filterConfig.rateLimit.windowSeconds !== undefined &&
          typeof filterConfig.rateLimit.windowSeconds !== 'number'
        ) {
          errors.push('Rate limit windowSeconds must be a number');
        }
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
    };
  }

  /**
   * Check if event pattern is valid
   *
   * @param {string} pattern - Event pattern
   * @returns {boolean} True if valid
   */
  _isValidEventPattern(pattern) {
    // Allow patterns like: tunnel.status_changed, tunnel.*, *.status_changed, *
    const validPattern = /^[a-z0-9_*]+(\.[a-z0-9_*]+)*$/i;
    return validPattern.test(pattern);
  }

  /**
   * Check if property filter is valid
   *
   * @param {Object} filter - Property filter
   * @returns {boolean} True if valid
   */
  _isValidPropertyFilter(filter) {
    if (typeof filter !== 'object' || Array.isArray(filter)) {
      return false;
    }

    const { operator, value } = filter;

    // Validate operator
    const validOperators = [
      'equals',
      'contains',
      'startsWith',
      'endsWith',
      'in',
      'regex',
    ];
    if (!validOperators.includes(operator)) {
      return false;
    }

    // Validate value based on operator
    if (operator === 'in') {
      return Array.isArray(value);
    }

    if (operator === 'regex') {
      try {
        new RegExp(value);
        return true;
      } catch {
        return false;
      }
    }

    return (
      typeof value === 'string' ||
      typeof value === 'number' ||
      typeof value === 'boolean'
    );
  }

  /**
   * Create filter configuration for a webhook
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @param {Object} filterConfig - Filter configuration
   * @returns {Promise<Object>} Created filter
   */
  async createFilter(webhookId, userId, filterConfig) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Validate filter configuration
      const validation = this.validateFilterConfig(filterConfig);
      if (!validation.isValid) {
        throw new Error(
          `Invalid filter configuration: ${validation.errors.join(', ')}`,
        );
      }

      // Verify webhook ownership
      const webhookResult = await client.query(
        'SELECT id FROM tunnel_webhooks WHERE id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (webhookResult.rows.length === 0) {
        throw new Error('Webhook not found');
      }

      // Create filter
      const filterId = uuidv4();
      const result = await client.query(
        `INSERT INTO webhook_event_filters (id, webhook_id, user_id, filter_config, is_active)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [filterId, webhookId, userId, JSON.stringify(filterConfig), true],
      );

      await client.query('COMMIT');

      logger.info('[WebhookEventFilter] Filter created', {
        filterId,
        webhookId,
        userId,
      });

      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[WebhookEventFilter] Failed to create filter', {
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
   * Get filter for a webhook
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Filter configuration
   */
  async getFilter(webhookId, userId) {
    try {
      const result = await this.pool.query(
        'SELECT * FROM webhook_event_filters WHERE webhook_id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (result.rows.length === 0) {
        return null;
      }

      return result.rows[0];
    } catch (error) {
      logger.error('[WebhookEventFilter] Failed to get filter', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update filter configuration
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @param {Object} filterConfig - New filter configuration
   * @returns {Promise<Object>} Updated filter
   */
  async updateFilter(webhookId, userId, filterConfig) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Validate filter configuration
      const validation = this.validateFilterConfig(filterConfig);
      if (!validation.isValid) {
        throw new Error(
          `Invalid filter configuration: ${validation.errors.join(', ')}`,
        );
      }

      // Verify webhook ownership
      const webhookResult = await client.query(
        'SELECT id FROM tunnel_webhooks WHERE id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (webhookResult.rows.length === 0) {
        throw new Error('Webhook not found');
      }

      // Update filter
      const result = await client.query(
        `UPDATE webhook_event_filters 
         SET filter_config = $1, updated_at = NOW()
         WHERE webhook_id = $2 AND user_id = $3
         RETURNING *`,
        [JSON.stringify(filterConfig), webhookId, userId],
      );

      await client.query('COMMIT');

      logger.info('[WebhookEventFilter] Filter updated', {
        webhookId,
        userId,
      });

      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[WebhookEventFilter] Failed to update filter', {
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
   * Delete filter for a webhook
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @returns {Promise<void>}
   */
  async deleteFilter(webhookId, userId) {
    try {
      const result = await this.pool.query(
        'DELETE FROM webhook_event_filters WHERE webhook_id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (result.rowCount === 0) {
        logger.warn('[WebhookEventFilter] Filter not found for deletion', {
          webhookId,
          userId,
        });
      } else {
        logger.info('[WebhookEventFilter] Filter deleted', {
          webhookId,
          userId,
        });
      }
    } catch (error) {
      logger.error('[WebhookEventFilter] Failed to delete filter', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Check if event matches filter
   *
   * @param {Object} event - Event object
   * @param {Object} filterConfig - Filter configuration
   * @returns {boolean} True if event matches filter
   */
  matchesFilter(event, filterConfig) {
    if (!filterConfig) {
      return true;
    }

    const filterType = filterConfig.type || 'include';

    // Check event pattern matching
    if (filterConfig.eventPatterns && filterConfig.eventPatterns.length > 0) {
      const eventMatches = this._matchesEventPattern(
        event.type,
        filterConfig.eventPatterns,
      );

      if (filterType === 'include' && !eventMatches) {
        return false;
      }

      if (filterType === 'exclude' && eventMatches) {
        return false;
      }
    }

    // Check property filters
    if (filterConfig.propertyFilters) {
      for (const [key, filter] of Object.entries(
        filterConfig.propertyFilters,
      )) {
        const value = this._getNestedProperty(event, key);

        if (!this._matchesPropertyFilter(value, filter)) {
          return false;
        }
      }
    }

    return true;
  }

  /**
   * Check if event type matches any pattern
   *
   * @param {string} eventType - Event type
   * @param {Array<string>} patterns - Event patterns
   * @returns {boolean} True if matches
   */
  _matchesEventPattern(eventType, patterns) {
    return patterns.some((pattern) => {
      // Handle global wildcard
      if (pattern === '*') {
        return true;
      }

      // Convert glob pattern to regex
      const regexPattern = pattern
        .replace(/\./g, '\\.')
        .replace(/\*/g, '[a-z0-9_]*');
      const regex = new RegExp(`^${regexPattern}$`, 'i');
      return regex.test(eventType);
    });
  }

  /**
   * Get nested property from object
   *
   * @param {Object} obj - Object
   * @param {string} path - Property path (e.g., "data.status")
   * @returns {*} Property value
   */
  _getNestedProperty(obj, path) {
    return path.split('.').reduce((current, prop) => current?.[prop], obj);
  }

  /**
   * Check if value matches property filter
   *
   * @param {*} value - Value to check
   * @param {Object} filter - Property filter
   * @returns {boolean} True if matches
   */
  _matchesPropertyFilter(value, filter) {
    const { operator, value: filterValue } = filter;

    switch (operator) {
      case 'equals':
        return value === filterValue;

      case 'contains':
        return String(value).includes(String(filterValue));

      case 'startsWith':
        return String(value).startsWith(String(filterValue));

      case 'endsWith':
        return String(value).endsWith(String(filterValue));

      case 'in':
        return filterValue.includes(value);

      case 'regex':
        try {
          const regex = new RegExp(filterValue);
          return regex.test(String(value));
        } catch {
          return false;
        }

      default:
        return false;
    }
  }
}

export default WebhookEventFilter;
