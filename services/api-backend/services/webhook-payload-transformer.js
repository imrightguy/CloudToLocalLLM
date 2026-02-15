/**
 * Webhook Payload Transformer Service
 *
 * Manages webhook payload transformation including:
 * - Transformation configuration and validation
 * - Payload transformation execution
 * - Transformation persistence and retrieval
 *
 * Validates: Requirements 10.6
 * - Implements webhook payload transformation
 * - Supports transformation configuration
 * - Validates transformation rules
 *
 * @fileoverview Webhook payload transformation service
 * @version 1.0.0
 */

import { v4 as uuidv4 } from 'uuid';
import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class WebhookPayloadTransformer {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize the transformer service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info(
        '[WebhookPayloadTransformer] Payload transformer service initialized',
      );
    } catch (error) {
      logger.error(
        '[WebhookPayloadTransformer] Failed to initialize transformer service',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Validate transformation configuration
   *
   * @param {Object} transformConfig - Transformation configuration
   * @returns {Object} Validation result with isValid and errors
   */
  validateTransformConfig(transformConfig) {
    const errors = [];

    if (!transformConfig) {
      return { isValid: true, errors: [] };
    }

    // Validate transformation type
    if (
      transformConfig.type &&
      !['map', 'filter', 'enrich', 'custom'].includes(transformConfig.type)
    ) {
      errors.push(
        'Transformation type must be "map", "filter", "enrich", or "custom"',
      );
    }

    // Validate mappings for map type
    if (
      transformConfig.type === 'map' ||
      (!transformConfig.type && transformConfig.mappings)
    ) {
      if (transformConfig.mappings) {
        if (
          typeof transformConfig.mappings !== 'object' ||
          Array.isArray(transformConfig.mappings)
        ) {
          errors.push('Mappings must be an object');
        } else {
          for (const [key, value] of Object.entries(transformConfig.mappings)) {
            if (!this._isValidMapping(value)) {
              errors.push(
                `Invalid mapping for "${key}": ${JSON.stringify(value)}`,
              );
            }
          }
        }
      }
    }

    // Validate filters for filter type
    if (
      transformConfig.type === 'filter' ||
      (!transformConfig.type && transformConfig.filters)
    ) {
      if (transformConfig.filters) {
        if (!Array.isArray(transformConfig.filters)) {
          errors.push('Filters must be an array');
        } else {
          for (let i = 0; i < transformConfig.filters.length; i++) {
            const filter = transformConfig.filters[i];
            if (!this._isValidFilterRule(filter)) {
              errors.push(
                `Invalid filter at index ${i}: ${JSON.stringify(filter)}`,
              );
            }
          }
        }
      }
    }

    // Validate enrichments for enrich type
    if (
      transformConfig.type === 'enrich' ||
      (!transformConfig.type && transformConfig.enrichments)
    ) {
      if (transformConfig.enrichments) {
        if (
          typeof transformConfig.enrichments !== 'object' ||
          Array.isArray(transformConfig.enrichments)
        ) {
          errors.push('Enrichments must be an object');
        } else {
          for (const [key, value] of Object.entries(
            transformConfig.enrichments,
          )) {
            if (!this._isValidEnrichment(value)) {
              errors.push(
                `Invalid enrichment for "${key}": ${JSON.stringify(value)}`,
              );
            }
          }
        }
      }
    }

    // Validate custom script for custom type
    if (transformConfig.type === 'custom') {
      if (
        !transformConfig.script ||
        typeof transformConfig.script !== 'string' ||
        transformConfig.script.trim().length === 0
      ) {
        errors.push('Custom script must be a non-empty string');
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
    };
  }

  /**
   * Check if mapping is valid
   *
   * @param {Object} mapping - Mapping configuration
   * @returns {boolean} True if valid
   */
  _isValidMapping(mapping) {
    if (typeof mapping !== 'object' || Array.isArray(mapping)) {
      return false;
    }

    const { source, transform } = mapping;

    // Source is required (target is optional, defaults to source)
    if (!source || typeof source !== 'string') {
      return false;
    }

    // Transform is optional but if provided must be valid
    if (transform) {
      if (
        ![
          'uppercase',
          'lowercase',
          'trim',
          'json',
          'base64',
          'custom',
        ].includes(transform.type)
      ) {
        return false;
      }

      if (
        transform.type === 'custom' &&
        (!transform.fn || typeof transform.fn !== 'string')
      ) {
        return false;
      }
    }

    return true;
  }

  /**
   * Check if filter rule is valid
   *
   * @param {Object} filter - Filter rule
   * @returns {boolean} True if valid
   */
  _isValidFilterRule(filter) {
    if (typeof filter !== 'object' || Array.isArray(filter)) {
      return false;
    }

    const { path, operator, value } = filter;

    if (!path || typeof path !== 'string') {
      return false;
    }

    const validOperators = [
      'equals',
      'notEquals',
      'contains',
      'startsWith',
      'endsWith',
      'in',
      'regex',
      'exists',
    ];
    if (!validOperators.includes(operator)) {
      return false;
    }

    // Value is optional for 'exists' operator
    if (operator === 'exists') {
      return true;
    }

    return value !== undefined;
  }

  /**
   * Check if enrichment is valid
   *
   * @param {Object} enrichment - Enrichment configuration
   * @returns {boolean} True if valid
   */
  _isValidEnrichment(enrichment) {
    if (typeof enrichment !== 'object' || Array.isArray(enrichment)) {
      return false;
    }

    const { type, value } = enrichment;

    const validTypes = ['static', 'timestamp', 'uuid', 'custom'];
    if (!validTypes.includes(type)) {
      return false;
    }

    if (type === 'static' && value === undefined) {
      return false;
    }

    if (type === 'custom' && (!value || typeof value !== 'string')) {
      return false;
    }

    return true;
  }

  /**
   * Create transformation configuration for a webhook
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @param {Object} transformConfig - Transformation configuration
   * @returns {Promise<Object>} Created transformation
   */
  async createTransformation(webhookId, userId, transformConfig) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Validate transformation configuration
      const validation = this.validateTransformConfig(transformConfig);
      if (!validation.isValid) {
        throw new Error(
          `Invalid transformation configuration: ${validation.errors.join(', ')}`,
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

      // Create transformation
      const transformId = uuidv4();
      const result = await client.query(
        `INSERT INTO webhook_payload_transformations (id, webhook_id, user_id, transform_config, is_active)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [transformId, webhookId, userId, JSON.stringify(transformConfig), true],
      );

      await client.query('COMMIT');

      logger.info('[WebhookPayloadTransformer] Transformation created', {
        transformId,
        webhookId,
        userId,
      });

      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error(
        '[WebhookPayloadTransformer] Failed to create transformation',
        {
          webhookId,
          userId,
          error: error.message,
        },
      );
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get transformation for a webhook
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Transformation configuration
   */
  async getTransformation(webhookId, userId) {
    try {
      const result = await this.pool.query(
        'SELECT * FROM webhook_payload_transformations WHERE webhook_id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (result.rows.length === 0) {
        return null;
      }

      return result.rows[0];
    } catch (error) {
      logger.error('[WebhookPayloadTransformer] Failed to get transformation', {
        webhookId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update transformation configuration
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @param {Object} transformConfig - New transformation configuration
   * @returns {Promise<Object>} Updated transformation
   */
  async updateTransformation(webhookId, userId, transformConfig) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Validate transformation configuration
      const validation = this.validateTransformConfig(transformConfig);
      if (!validation.isValid) {
        throw new Error(
          `Invalid transformation configuration: ${validation.errors.join(', ')}`,
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

      // Update transformation
      const result = await client.query(
        `UPDATE webhook_payload_transformations 
         SET transform_config = $1, updated_at = NOW()
         WHERE webhook_id = $2 AND user_id = $3
         RETURNING *`,
        [JSON.stringify(transformConfig), webhookId, userId],
      );

      await client.query('COMMIT');

      logger.info('[WebhookPayloadTransformer] Transformation updated', {
        webhookId,
        userId,
      });

      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error(
        '[WebhookPayloadTransformer] Failed to update transformation',
        {
          webhookId,
          userId,
          error: error.message,
        },
      );
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Delete transformation for a webhook
   *
   * @param {string} webhookId - Webhook ID
   * @param {string} userId - User ID
   * @returns {Promise<void>}
   */
  async deleteTransformation(webhookId, userId) {
    try {
      const result = await this.pool.query(
        'DELETE FROM webhook_payload_transformations WHERE webhook_id = $1 AND user_id = $2',
        [webhookId, userId],
      );

      if (result.rowCount === 0) {
        logger.warn(
          '[WebhookPayloadTransformer] Transformation not found for deletion',
          {
            webhookId,
            userId,
          },
        );
      } else {
        logger.info('[WebhookPayloadTransformer] Transformation deleted', {
          webhookId,
          userId,
        });
      }
    } catch (error) {
      logger.error(
        '[WebhookPayloadTransformer] Failed to delete transformation',
        {
          webhookId,
          userId,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Transform payload according to configuration
   *
   * @param {Object} payload - Original payload
   * @param {Object} transformConfig - Transformation configuration
   * @returns {Object} Transformed payload
   */
  transformPayload(payload, transformConfig) {
    if (!transformConfig || !payload) {
      return payload;
    }

    let result = JSON.parse(JSON.stringify(payload)); // Deep copy

    const transformType = transformConfig.type || 'map';

    switch (transformType) {
      case 'map':
        result = this._applyMappings(result, transformConfig.mappings);
        break;

      case 'filter':
        result = this._applyFilters(result, transformConfig.filters);
        break;

      case 'enrich':
        result = this._applyEnrichments(result, transformConfig.enrichments);
        break;

      case 'custom':
        result = this._applyCustomTransform(result, transformConfig.script);
        break;

      default:
        logger.warn('[WebhookPayloadTransformer] Unknown transformation type', {
          transformType,
        });
    }

    return result;
  }

  /**
   * Apply mappings to payload
   *
   * @param {Object} payload - Payload
   * @param {Object} mappings - Mappings configuration
   * @returns {Object} Mapped payload
   */
  _applyMappings(payload, mappings) {
    if (!mappings) {
      return payload;
    }

    const result = {};

    for (const [targetKey, mapping] of Object.entries(mappings)) {
      const sourceValue = this._getNestedProperty(payload, mapping.source);

      if (mapping.transform) {
        result[targetKey] = this._applyTransform(
          sourceValue,
          mapping.transform,
        );
      } else {
        result[targetKey] = sourceValue;
      }
    }

    return result;
  }

  /**
   * Apply filters to payload
   *
   * @param {Object} payload - Payload
   * @param {Array} filters - Filter rules
   * @returns {Object} Filtered payload
   */
  _applyFilters(payload, filters) {
    if (!filters || filters.length === 0) {
      return payload;
    }

    for (const filter of filters) {
      if (!this._matchesFilterRule(payload, filter)) {
        return null; // Payload filtered out
      }
    }

    return payload;
  }

  /**
   * Apply enrichments to payload
   *
   * @param {Object} payload - Payload
   * @param {Object} enrichments - Enrichments configuration
   * @returns {Object} Enriched payload
   */
  _applyEnrichments(payload, enrichments) {
    if (!enrichments) {
      return payload;
    }

    const result = JSON.parse(JSON.stringify(payload)); // Deep copy

    for (const [key, enrichment] of Object.entries(enrichments)) {
      result[key] = this._generateEnrichmentValue(enrichment);
    }

    return result;
  }

  /**
   * Apply custom transformation script
   * SECURITY: Custom scripts are disabled due to code injection risk.
   * Use predefined transform types (map, filter, enrich) instead.
   *
   * @param {Object} payload - Payload
   * @param {string} script - Custom script (IGNORED for security)
   * @returns {Object} Original payload (custom scripts disabled)
   */
  _applyCustomTransform(payload, _script) {
    logger.warn(
      '[WebhookPayloadTransformer] Custom transformation disabled for security. Use map/filter/enrich instead.',
    );
    return payload;
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
   * Apply transformation function to value
   *
   * @param {*} value - Value to transform
   * @param {Object} transform - Transform configuration
   * @returns {*} Transformed value
   */
  _applyTransform(value, transform) {
    if (!transform) {
      return value;
    }

    switch (transform.type) {
      case 'uppercase':
        return String(value).toUpperCase();

      case 'lowercase':
        return String(value).toLowerCase();

      case 'trim':
        return String(value).trim();

      case 'json':
        try {
          return JSON.parse(String(value));
        } catch {
          return value;
        }

      case 'base64':
        return Buffer.from(String(value)).toString('base64');

      case 'custom':
        logger.warn(
          '[WebhookPayloadTransformer] Custom transform disabled for security',
        );
        return value;

      default:
        return value;
    }
  }

  /**
   * Check if payload matches filter rule
   *
   * @param {Object} payload - Payload
   * @param {Object} filter - Filter rule
   * @returns {boolean} True if matches
   */
  _matchesFilterRule(payload, filter) {
    const { path, operator, value } = filter;
    const payloadValue = this._getNestedProperty(payload, path);

    switch (operator) {
      case 'equals':
        return payloadValue === value;

      case 'notEquals':
        return payloadValue !== value;

      case 'contains':
        return String(payloadValue).includes(String(value));

      case 'startsWith':
        return String(payloadValue).startsWith(String(value));

      case 'endsWith':
        return String(payloadValue).endsWith(String(value));

      case 'in':
        return Array.isArray(value) && value.includes(payloadValue);

      case 'regex':
        try {
          const regex = new RegExp(value);
          return regex.test(String(payloadValue));
        } catch {
          return false;
        }

      case 'exists':
        return payloadValue !== undefined && payloadValue !== null;

      default:
        return false;
    }
  }

  /**
   * Generate enrichment value
   *
   * @param {Object} enrichment - Enrichment configuration
   * @returns {*} Enrichment value
   */
  _generateEnrichmentValue(enrichment) {
    switch (enrichment.type) {
      case 'static':
        return enrichment.value;

      case 'timestamp':
        return new Date().toISOString();

      case 'uuid':
        return uuidv4();

      case 'custom':
        logger.warn(
          '[WebhookPayloadTransformer] Custom enrichment disabled for security',
        );
        return null;

      default:
        return null;
    }
  }
}

export default WebhookPayloadTransformer;
