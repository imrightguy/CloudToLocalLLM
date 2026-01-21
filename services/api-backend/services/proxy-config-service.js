import winston from 'winston';

/**
 * ProxyConfigService - Manages proxy configuration settings
 * Implements configuration management, validation, and audit trails
 * Validates: Requirements 5.4
 */
export class ProxyConfigService {
  constructor(db = null, logger = null) {
    this.db = db;
    this.logger =
      logger ||
      winston.createLogger({
        level: process.env.LOG_LEVEL || 'info',
        format: winston.format.combine(
          winston.format.timestamp(),
          winston.format.errors({ stack: true }),
          winston.format.json(),
        ),
        defaultMeta: { service: 'proxy-config' },
        transports: [
          new winston.transports.Console({
            format: winston.format.combine(
              winston.format.timestamp(),
              winston.format.simple(),
            ),
          }),
        ],
      });

    // Default configuration values
    this.defaultConfig = {
      max_connections: 100,
      timeout_seconds: 30,
      compression_enabled: true,
      compression_level: 6,
      buffer_size_kb: 64,
      keep_alive_enabled: true,
      keep_alive_interval_seconds: 30,
      ssl_verify: true,
      rate_limit_enabled: false,
      rate_limit_requests_per_second: 1000,
      rate_limit_burst_size: 100,
      retry_enabled: true,
      retry_max_attempts: 3,
      retry_backoff_ms: 1000,
      logging_level: 'info',
      metrics_collection_enabled: true,
      metrics_collection_interval_seconds: 60,
      health_check_enabled: true,
      health_check_interval_seconds: 30,
      health_check_timeout_seconds: 5,
    };

    // Configuration validation rules
    this.validationRules = {
      max_connections: { type: 'number', min: 1, max: 10000 },
      timeout_seconds: { type: 'number', min: 1, max: 300 },
      compression_enabled: { type: 'boolean' },
      compression_level: { type: 'number', min: 1, max: 9 },
      buffer_size_kb: { type: 'number', min: 1, max: 10000 },
      keep_alive_enabled: { type: 'boolean' },
      keep_alive_interval_seconds: { type: 'number', min: 1, max: 300 },
      ssl_verify: { type: 'boolean' },
      ssl_cert_path: { type: 'string', maxLength: 512 },
      ssl_key_path: { type: 'string', maxLength: 512 },
      rate_limit_enabled: { type: 'boolean' },
      rate_limit_requests_per_second: { type: 'number', min: 1, max: 100000 },
      rate_limit_burst_size: { type: 'number', min: 1, max: 10000 },
      retry_enabled: { type: 'boolean' },
      retry_max_attempts: { type: 'number', min: 1, max: 10 },
      retry_backoff_ms: { type: 'number', min: 100, max: 60000 },
      logging_level: {
        type: 'enum',
        values: ['debug', 'info', 'warn', 'error'],
      },
      metrics_collection_enabled: { type: 'boolean' },
      metrics_collection_interval_seconds: {
        type: 'number',
        min: 1,
        max: 3600,
      },
      health_check_enabled: { type: 'boolean' },
      health_check_interval_seconds: { type: 'number', min: 1, max: 300 },
      health_check_timeout_seconds: { type: 'number', min: 1, max: 60 },
    };
  }

  /**
   * Validate configuration values
   * @param {Object} config - Configuration object to validate
   * @returns {Object} Validation result with errors array
   */
  validateConfig(config) {
    const errors = [];

    for (const [key, value] of Object.entries(config)) {
      if (!this.validationRules[key]) {
        errors.push({
          field: key,
          message: `Unknown configuration field: ${key}`,
        });
        continue;
      }

      const rule = this.validationRules[key];

      // Type validation
      if (rule.type === 'boolean' && typeof value !== 'boolean') {
        errors.push({
          field: key,
          message: `${key} must be a boolean`,
        });
        continue;
      }

      if (rule.type === 'number' && typeof value !== 'number') {
        errors.push({
          field: key,
          message: `${key} must be a number`,
        });
        continue;
      }

      if (rule.type === 'string' && typeof value !== 'string') {
        errors.push({
          field: key,
          message: `${key} must be a string`,
        });
        continue;
      }

      // Range validation for numbers
      if (rule.type === 'number') {
        if (rule.min !== undefined && value < rule.min) {
          errors.push({
            field: key,
            message: `${key} must be at least ${rule.min}`,
          });
        }
        if (rule.max !== undefined && value > rule.max) {
          errors.push({
            field: key,
            message: `${key} must be at most ${rule.max}`,
          });
        }
      }

      // Length validation for strings
      if (
        rule.type === 'string' &&
        rule.maxLength &&
        value.length > rule.maxLength
      ) {
        errors.push({
          field: key,
          message: `${key} must be at most ${rule.maxLength} characters`,
        });
      }

      // Enum validation
      if (rule.type === 'enum' && !rule.values.includes(value)) {
        errors.push({
          field: key,
          message: `${key} must be one of: ${rule.values.join(', ')}`,
        });
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
    };
  }

  /**
   * Create a new proxy configuration
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {Object} config - Configuration object
   * @returns {Promise<Object>} Created configuration
   */
  async createProxyConfig(proxyId, userId, config = {}) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    // Merge with defaults
    const mergedConfig = { ...this.defaultConfig, ...config };

    // Validate configuration
    const validation = this.validateConfig(mergedConfig);
    if (!validation.isValid) {
      const error = new Error('Configuration validation failed');
      error.validationErrors = validation.errors;
      throw error;
    }

    try {
      const result = await this.db.query(
        `INSERT INTO proxy_configurations (
          proxy_id, user_id, max_connections, timeout_seconds, compression_enabled,
          compression_level, buffer_size_kb, keep_alive_enabled, keep_alive_interval_seconds,
          ssl_verify, ssl_cert_path, ssl_key_path, rate_limit_enabled,
          rate_limit_requests_per_second, rate_limit_burst_size, retry_enabled,
          retry_max_attempts, retry_backoff_ms, logging_level, metrics_collection_enabled,
          metrics_collection_interval_seconds, health_check_enabled,
          health_check_interval_seconds, health_check_timeout_seconds
        ) VALUES (
          $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24
        ) RETURNING *`,
        [
          proxyId,
          userId,
          mergedConfig.max_connections,
          mergedConfig.timeout_seconds,
          mergedConfig.compression_enabled,
          mergedConfig.compression_level,
          mergedConfig.buffer_size_kb,
          mergedConfig.keep_alive_enabled,
          mergedConfig.keep_alive_interval_seconds,
          mergedConfig.ssl_verify,
          mergedConfig.ssl_cert_path || null,
          mergedConfig.ssl_key_path || null,
          mergedConfig.rate_limit_enabled,
          mergedConfig.rate_limit_requests_per_second,
          mergedConfig.rate_limit_burst_size,
          mergedConfig.retry_enabled,
          mergedConfig.retry_max_attempts,
          mergedConfig.retry_backoff_ms,
          mergedConfig.logging_level,
          mergedConfig.metrics_collection_enabled,
          mergedConfig.metrics_collection_interval_seconds,
          mergedConfig.health_check_enabled,
          mergedConfig.health_check_interval_seconds,
          mergedConfig.health_check_timeout_seconds,
        ],
      );

      this.logger.info('Proxy configuration created', {
        proxyId,
        userId,
        configId: result.rows[0].id,
      });

      return this.formatConfigResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error creating proxy configuration', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get proxy configuration
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Promise<Object>} Proxy configuration
   */
  async getProxyConfig(proxyId) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        'SELECT * FROM proxy_configurations WHERE proxy_id = $1',
        [proxyId],
      );

      if (result.rows.length === 0) {
        return null;
      }

      return this.formatConfigResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error retrieving proxy configuration', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update proxy configuration
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {Object} updates - Configuration updates
   * @param {string} changeReason - Reason for the change
   * @returns {Promise<Object>} Updated configuration
   */
  async updateProxyConfig(
    proxyId,
    userId,
    updates,
    changeReason = 'Manual update',
  ) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    // Get current configuration
    const currentConfig = await this.getProxyConfig(proxyId);
    if (!currentConfig) {
      throw new Error(`Proxy configuration not found: ${proxyId}`);
    }

    // Validate updates
    const validation = this.validateConfig(updates);
    if (!validation.isValid) {
      const error = new Error('Configuration validation failed');
      error.validationErrors = validation.errors;
      throw error;
    }

    // Determine changed fields
    const changedFields = Object.keys(updates).filter(
      (key) => currentConfig[key] !== updates[key],
    );

    if (changedFields.length === 0) {
      this.logger.info('No configuration changes detected', { proxyId });
      return currentConfig;
    }

    try {
      // Build update query dynamically
      const updateFields = [];
      const values = [];
      let paramIndex = 1;

      for (const [key, value] of Object.entries(updates)) {
        updateFields.push(`${key} = $${paramIndex}`);
        values.push(value);
        paramIndex += 1;
      }

      updateFields.push(`updated_at = $${paramIndex}`);
      values.push(new Date());
      paramIndex += 1;

      values.push(proxyId);

      const result = await this.db.query(
        `UPDATE proxy_configurations SET ${updateFields.join(', ')} WHERE proxy_id = $${paramIndex} RETURNING *`,
        values,
      );

      const updatedConfig = result.rows[0];

      // Record in history
      await this.db.query(
        `INSERT INTO proxy_config_history (
          proxy_id, user_id, config_id, previous_config, new_config, changed_fields, change_reason
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          proxyId,
          userId,
          updatedConfig.id,
          JSON.stringify(currentConfig),
          JSON.stringify(this.formatConfigResponse(updatedConfig)),
          changedFields,
          changeReason,
        ],
      );

      this.logger.info('Proxy configuration updated', {
        proxyId,
        userId,
        changedFields,
        changeReason,
      });

      return this.formatConfigResponse(updatedConfig);
    } catch (error) {
      this.logger.error('Error updating proxy configuration', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Delete proxy configuration
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Promise<void>}
   */
  async deleteProxyConfig(proxyId) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      await this.db.query(
        'DELETE FROM proxy_configurations WHERE proxy_id = $1',
        [proxyId],
      );

      this.logger.info('Proxy configuration deleted', { proxyId });
    } catch (error) {
      this.logger.error('Error deleting proxy configuration', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get configuration history for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {number} limit - Maximum number of records to return
   * @returns {Promise<Array>} Configuration history
   */
  async getConfigHistory(proxyId, limit = 50) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        `SELECT * FROM proxy_config_history 
         WHERE proxy_id = $1 
         ORDER BY created_at DESC 
         LIMIT $2`,
        [proxyId, limit],
      );

      return result.rows;
    } catch (error) {
      this.logger.error('Error retrieving configuration history', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Create a configuration template
   * @param {string} name - Template name
   * @param {string} userId - User ID (creator)
   * @param {Object} config - Template configuration
   * @param {string} description - Template description
   * @param {boolean} isDefault - Whether this is the default template
   * @returns {Promise<Object>} Created template
   */
  async createConfigTemplate(
    name,
    userId,
    config,
    description = '',
    isDefault = false,
  ) {
    if (!name || !userId) {
      throw new Error('name and userId are required');
    }

    // Validate configuration
    const validation = this.validateConfig(config);
    if (!validation.isValid) {
      const error = new Error('Configuration validation failed');
      error.validationErrors = validation.errors;
      throw error;
    }

    try {
      const result = await this.db.query(
        `INSERT INTO proxy_config_templates (name, description, template_config, is_default, created_by)
         VALUES ($1, $2, $3, $4, $5)
         RETURNING *`,
        [name, description, JSON.stringify(config), isDefault, userId],
      );

      this.logger.info('Configuration template created', {
        templateId: result.rows[0].id,
        name,
        userId,
      });

      return result.rows[0];
    } catch (error) {
      this.logger.error('Error creating configuration template', {
        name,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get configuration template
   * @param {string} templateId - Template ID
   * @returns {Promise<Object>} Configuration template
   */
  async getConfigTemplate(templateId) {
    if (!templateId) {
      throw new Error('templateId is required');
    }

    try {
      const result = await this.db.query(
        'SELECT * FROM proxy_config_templates WHERE id = $1',
        [templateId],
      );

      if (result.rows.length === 0) {
        return null;
      }

      return result.rows[0];
    } catch (error) {
      this.logger.error('Error retrieving configuration template', {
        templateId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get all configuration templates
   * @returns {Promise<Array>} All configuration templates
   */
  async getAllConfigTemplates() {
    try {
      const result = await this.db.query(
        'SELECT * FROM proxy_config_templates ORDER BY is_default DESC, created_at DESC',
      );

      return result.rows;
    } catch (error) {
      this.logger.error('Error retrieving configuration templates', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get default configuration template
   * @returns {Promise<Object>} Default configuration template
   */
  async getDefaultConfigTemplate() {
    try {
      const result = await this.db.query(
        'SELECT * FROM proxy_config_templates WHERE is_default = true LIMIT 1',
      );

      if (result.rows.length === 0) {
        return null;
      }

      return result.rows[0];
    } catch (error) {
      this.logger.error('Error retrieving default configuration template', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Apply configuration template to a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {string} templateId - Template ID
   * @returns {Promise<Object>} Updated configuration
   */
  async applyConfigTemplate(proxyId, userId, templateId) {
    if (!proxyId || !userId || !templateId) {
      throw new Error('proxyId, userId, and templateId are required');
    }

    try {
      const template = await this.getConfigTemplate(templateId);
      if (!template) {
        throw new Error(`Configuration template not found: ${templateId}`);
      }

      const templateConfig = JSON.parse(template.template_config);
      const updatedConfig = await this.updateProxyConfig(
        proxyId,
        userId,
        templateConfig,
        `Applied template: ${template.name}`,
      );

      this.logger.info('Configuration template applied', {
        proxyId,
        userId,
        templateId,
        templateName: template.name,
      });

      return updatedConfig;
    } catch (error) {
      this.logger.error('Error applying configuration template', {
        proxyId,
        userId,
        templateId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Format configuration response
   * @param {Object} row - Database row
   * @returns {Object} Formatted configuration
   */
  formatConfigResponse(row) {
    return {
      id: row.id,
      proxyId: row.proxy_id,
      userId: row.user_id,
      maxConnections: row.max_connections,
      timeoutSeconds: row.timeout_seconds,
      compressionEnabled: row.compression_enabled,
      compressionLevel: row.compression_level,
      bufferSizeKb: row.buffer_size_kb,
      keepAliveEnabled: row.keep_alive_enabled,
      keepAliveIntervalSeconds: row.keep_alive_interval_seconds,
      sslVerify: row.ssl_verify,
      sslCertPath: row.ssl_cert_path,
      sslKeyPath: row.ssl_key_path,
      rateLimitEnabled: row.rate_limit_enabled,
      rateLimitRequestsPerSecond: row.rate_limit_requests_per_second,
      rateLimitBurstSize: row.rate_limit_burst_size,
      retryEnabled: row.retry_enabled,
      retryMaxAttempts: row.retry_max_attempts,
      retryBackoffMs: row.retry_backoff_ms,
      loggingLevel: row.logging_level,
      metricsCollectionEnabled: row.metrics_collection_enabled,
      metricsCollectionIntervalSeconds: row.metrics_collection_interval_seconds,
      healthCheckEnabled: row.health_check_enabled,
      healthCheckIntervalSeconds: row.health_check_interval_seconds,
      healthCheckTimeoutSeconds: row.health_check_timeout_seconds,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  /**
   * Get validation rules
   * @returns {Object} Validation rules
   */
  getValidationRules() {
    return this.validationRules;
  }

  /**
   * Get default configuration
   * @returns {Object} Default configuration
   */
  getDefaultConfig() {
    return { ...this.defaultConfig };
  }
}

export default ProxyConfigService;
