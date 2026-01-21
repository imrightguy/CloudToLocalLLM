/**
 * Email Configuration Service
 *
 * Handles email configuration management including:
 * - Google OAuth token encryption/decryption (AES-256-GCM)
 * - Configuration validation and persistence
 * - Email template management
 * - Delivery metrics tracking
 * - Error handling and logging
 */

import crypto from 'crypto';
import logger from '../logger.js';
import { v4 as uuidv4 } from 'uuid';

class EmailConfigService {
  constructor(db) {
    this.db = db;
    this.configCache = new Map();
    this.templateCache = new Map();
    this.cacheTTL = 5 * 60 * 1000; // 5 minutes
  }

  /**
   * Validate email configuration
   *
   * @param {Object} config - Configuration object
   * @returns {Object} Validation result with errors array
   */
  validateConfiguration(config) {
    const errors = [];

    if (!config.provider) {
      errors.push('Provider is required');
    }

    if (
      !['google_workspace', 'smtp_relay', 'sendgrid'].includes(config.provider)
    ) {
      errors.push(
        'Invalid provider. Must be one of: google_workspace, smtp_relay, sendgrid',
      );
    }

    if (!config.from_address) {
      errors.push('From address is required');
    } else if (!this._isValidEmail(config.from_address)) {
      errors.push('Invalid from address format');
    }

    if (
      config.reply_to_address &&
      !this._isValidEmail(config.reply_to_address)
    ) {
      errors.push('Invalid reply-to address format');
    }

    if (config.provider === 'smtp_relay') {
      if (!config.smtp_host) {
        errors.push('SMTP host is required for SMTP relay provider');
      }
      if (!config.smtp_port) {
        errors.push('SMTP port is required for SMTP relay provider');
      } else if (config.smtp_port < 1 || config.smtp_port > 65535) {
        errors.push('SMTP port must be between 1 and 65535');
      }
      if (!config.smtp_username) {
        errors.push('SMTP username is required for SMTP relay provider');
      }
      if (!config.smtp_password) {
        errors.push('SMTP password is required for SMTP relay provider');
      }
    }

    return {
      valid: errors.length === 0,
      errors,
    };
  }

  /**
   * Store email configuration
   *
   * @param {Object} params - Configuration parameters
   * @param {string} params.userId - User ID
   * @param {string} params.provider - Email provider
   * @param {string} params.from_address - From email address
   * @param {string} [params.from_name] - From name
   * @param {string} [params.reply_to_address] - Reply-to address
   * @param {Object} [params.googleOAuth] - Google OAuth tokens
   * @param {Object} [params.smtpConfig] - SMTP configuration
   * @returns {Promise<Object>} Stored configuration
   */
  async storeConfiguration({
    userId,
    provider,
    from_address,
    from_name = null,
    reply_to_address = null,
    googleOAuth = null,
    smtpConfig = null,
  }) {
    const configId = uuidv4();

    try {
      // Validate configuration
      const validation = this.validateConfiguration({
        provider,
        from_address,
        reply_to_address,
        smtp_host: smtpConfig?.host,
        smtp_port: smtpConfig?.port,
        smtp_username: smtpConfig?.username,
        smtp_password: smtpConfig?.password,
      });

      if (!validation.valid) {
        throw new Error(
          `Configuration validation failed: ${validation.errors.join(', ')}`,
        );
      }

      // Encrypt sensitive data
      let encryptedGoogleToken = null;
      let encryptedGoogleRefreshToken = null;
      let encryptedSmtpPassword = null;

      if (googleOAuth) {
        encryptedGoogleToken = this._encryptData(googleOAuth.accessToken);
        encryptedGoogleRefreshToken = this._encryptData(
          googleOAuth.refreshToken,
        );
      }

      if (smtpConfig?.password) {
        encryptedSmtpPassword = this._encryptData(smtpConfig.password);
      }

      const query = `
        INSERT INTO email_configurations (
          id, user_id, provider, google_oauth_token_encrypted,
          google_oauth_refresh_token_encrypted, smtp_host, smtp_port,
          smtp_username, smtp_password_encrypted, from_address, from_name,
          reply_to_address, is_active, created_at, updated_at, created_by, updated_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, NOW(), NOW(), $14, $14)
        ON CONFLICT (user_id, provider) DO UPDATE SET
          google_oauth_token_encrypted = $4,
          google_oauth_refresh_token_encrypted = $5,
          smtp_host = $6,
          smtp_port = $7,
          smtp_username = $8,
          smtp_password_encrypted = $9,
          from_address = $10,
          from_name = $11,
          reply_to_address = $12,
          is_active = $13,
          updated_at = NOW(),
          updated_by = $14
        RETURNING *
      `;

      const result = await this.db.query(query, [
        configId,
        userId,
        provider,
        encryptedGoogleToken,
        encryptedGoogleRefreshToken,
        smtpConfig?.host || null,
        smtpConfig?.port || null,
        smtpConfig?.username || null,
        encryptedSmtpPassword,
        from_address,
        from_name,
        reply_to_address,
        true,
        userId,
      ]);

      // Clear cache
      this.configCache.delete(`config_${userId}_${provider}`);

      logger.info('Stored email configuration', {
        userId,
        provider,
        configId,
        from_address,
      });

      return result.rows[0];
    } catch (error) {
      logger.error('Failed to store email configuration', {
        userId,
        provider,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Retrieve email configuration
   *
   * @param {string} userId - User ID
   * @param {string} provider - Email provider
   * @returns {Promise<Object>} Configuration object
   */
  async getConfiguration(userId, provider) {
    try {
      // Check cache first
      const cacheKey = `config_${userId}_${provider}`;
      const cached = this.configCache.get(cacheKey);

      if (cached && Date.now() - cached.timestamp < this.cacheTTL) {
        return cached.data;
      }

      const query = `
        SELECT * FROM email_configurations
        WHERE user_id = $1 AND provider = $2
      `;

      const result = await this.db.query(query, [userId, provider]);

      if (result.rows.length === 0) {
        return null;
      }

      const config = result.rows[0];

      // Decrypt sensitive fields
      if (config.google_oauth_token_encrypted) {
        config.googleOAuthToken = this._decryptData(
          config.google_oauth_token_encrypted,
        );
      }
      if (config.google_oauth_refresh_token_encrypted) {
        config.googleOAuthRefreshToken = this._decryptData(
          config.google_oauth_refresh_token_encrypted,
        );
      }
      if (config.smtp_password_encrypted) {
        config.smtpPassword = this._decryptData(config.smtp_password_encrypted);
      }

      // Cache the result
      this.configCache.set(cacheKey, {
        data: config,
        timestamp: Date.now(),
      });

      logger.info('Retrieved email configuration', {
        userId,
        provider,
      });

      return config;
    } catch (error) {
      logger.error('Failed to retrieve email configuration', {
        userId,
        provider,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get all configurations for a user
   *
   * @param {string} userId - User ID
   * @returns {Promise<Array>} Array of configurations
   */
  async getAllConfigurations(userId) {
    try {
      const query = `
        SELECT * FROM email_configurations
        WHERE user_id = $1
        ORDER BY created_at DESC
      `;

      const result = await this.db.query(query, [userId]);

      // Decrypt sensitive fields for each config
      const configs = result.rows.map((config) => {
        if (config.google_oauth_token_encrypted) {
          config.googleOAuthToken = this._decryptData(
            config.google_oauth_token_encrypted,
          );
        }
        if (config.google_oauth_refresh_token_encrypted) {
          config.googleOAuthRefreshToken = this._decryptData(
            config.google_oauth_refresh_token_encrypted,
          );
        }
        if (config.smtp_password_encrypted) {
          config.smtpPassword = this._decryptData(
            config.smtp_password_encrypted,
          );
        }
        return config;
      });

      logger.info('Retrieved all email configurations', {
        userId,
        count: configs.length,
      });

      return configs;
    } catch (error) {
      logger.error('Failed to retrieve all email configurations', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Delete email configuration
   *
   * @param {string} userId - User ID
   * @param {string} provider - Email provider
   * @returns {Promise<void>}
   */
  async deleteConfiguration(userId, provider) {
    try {
      const query = `
        DELETE FROM email_configurations
        WHERE user_id = $1 AND provider = $2
      `;

      await this.db.query(query, [userId, provider]);

      // Clear cache
      this.configCache.delete(`config_${userId}_${provider}`);

      logger.info('Deleted email configuration', {
        userId,
        provider,
      });
    } catch (error) {
      logger.error('Failed to delete email configuration', {
        userId,
        provider,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Create or update email template
   *
   * @param {Object} params - Template parameters
   * @param {string} params.userId - User ID (null for system templates)
   * @param {string} params.name - Template name
   * @param {string} params.subject - Email subject
   * @param {string} params.html_body - HTML body
   * @param {string} [params.text_body] - Text body
   * @param {string} [params.description] - Template description
   * @param {Array} [params.variables] - Template variables
   * @param {boolean} [params.is_system_template] - Is system template
   * @returns {Promise<Object>} Created/updated template
   */
  async saveTemplate({
    userId = null,
    name,
    subject,
    html_body,
    text_body = null,
    description = null,
    variables = [],
    is_system_template = false,
  }) {
    const templateId = uuidv4();

    try {
      // Validate template
      if (!name || name.trim().length === 0) {
        throw new Error('Template name is required');
      }
      if (!subject || subject.trim().length === 0) {
        throw new Error('Template subject is required');
      }
      if (!html_body || html_body.trim().length === 0) {
        throw new Error('Template HTML body is required');
      }

      const query = `
        INSERT INTO email_templates (
          id, user_id, name, subject, html_body, text_body,
          description, variables, is_system_template,
          created_at, updated_at, created_by, updated_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW(), NOW(), $10, $10)
        ON CONFLICT (user_id, name) DO UPDATE SET
          subject = $4,
          html_body = $5,
          text_body = $6,
          description = $7,
          variables = $8,
          updated_at = NOW(),
          updated_by = $10
        RETURNING *
      `;

      const result = await this.db.query(query, [
        templateId,
        userId,
        name,
        subject,
        html_body,
        text_body,
        description,
        JSON.stringify(variables),
        is_system_template,
        userId,
      ]);

      // Clear cache
      this.templateCache.delete(`template_${userId}_${name}`);

      logger.info('Saved email template', {
        userId,
        templateName: name,
        templateId,
      });

      return result.rows[0];
    } catch (error) {
      logger.error('Failed to save email template', {
        userId,
        templateName: name,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get email template
   *
   * @param {string} name - Template name
   * @param {string} [userId] - User ID (for user-specific templates)
   * @returns {Promise<Object>} Template object
   */
  async getTemplate(name, userId = null) {
    try {
      // Check cache first
      const cacheKey = `template_${userId}_${name}`;
      const cached = this.templateCache.get(cacheKey);

      if (cached && Date.now() - cached.timestamp < this.cacheTTL) {
        return cached.data;
      }

      // Try user-specific template first, then system template
      let query = `
        SELECT * FROM email_templates
        WHERE name = $1 AND (user_id = $2 OR (user_id IS NULL AND is_system_template = true))
        ORDER BY user_id DESC NULLS LAST
        LIMIT 1
      `;

      const result = await this.db.query(query, [name, userId]);

      if (result.rows.length === 0) {
        logger.warn('Email template not found', {
          templateName: name,
          userId,
        });
        return null;
      }

      const template = result.rows[0];

      // Parse variables if stored as JSON string
      if (typeof template.variables === 'string') {
        template.variables = JSON.parse(template.variables);
      }

      // Cache the result
      this.templateCache.set(cacheKey, {
        data: template,
        timestamp: Date.now(),
      });

      logger.info('Retrieved email template', {
        templateName: name,
        userId,
      });

      return template;
    } catch (error) {
      logger.error('Failed to retrieve email template', {
        templateName: name,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * List email templates
   *
   * @param {string} [userId] - User ID (null for system templates)
   * @param {Object} [options] - Query options
   * @param {number} [options.limit] - Result limit
   * @param {number} [options.offset] - Result offset
   * @returns {Promise<Array>} Array of templates
   */
  async listTemplates(userId = null, options = {}) {
    const { limit = 50, offset = 0 } = options;

    try {
      let query = `
        SELECT * FROM email_templates
        WHERE user_id = $1 OR (user_id IS NULL AND is_system_template = true)
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
      `;

      const result = await this.db.query(query, [userId, limit, offset]);

      const templates = result.rows.map((template) => {
        if (typeof template.variables === 'string') {
          template.variables = JSON.parse(template.variables);
        }
        return template;
      });

      logger.info('Listed email templates', {
        userId,
        count: templates.length,
      });

      return templates;
    } catch (error) {
      logger.error('Failed to list email templates', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Delete email template
   *
   * @param {string} templateId - Template ID
   * @param {string} userId - User ID
   * @returns {Promise<void>}
   */
  async deleteTemplate(templateId, userId) {
    try {
      const query = `
        DELETE FROM email_templates
        WHERE id = $1 AND (user_id = $2 OR user_id IS NULL)
      `;

      await this.db.query(query, [templateId, userId]);

      // Clear all template caches for this user
      for (const key of this.templateCache.keys()) {
        if (key.startsWith(`template_${userId}_`)) {
          this.templateCache.delete(key);
        }
      }

      logger.info('Deleted email template', {
        templateId,
        userId,
      });
    } catch (error) {
      logger.error('Failed to delete email template', {
        templateId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Render email template with variables
   *
   * @param {Object} template - Template object
   * @param {Object} variables - Template variables
   * @returns {Object} Rendered email with subject and body
   */
  renderTemplate(template, variables = {}) {
    try {
      if (!template) {
        throw new Error('Template not found');
      }

      // Simple variable replacement: {{variableName}}
      const replaceVariables = (text) => {
        if (!text) {
          return text;
        }

        return text.replace(/\{\{(\w+)\}\}/g, (match, key) => {
          return variables[key] !== undefined ? variables[key] : match;
        });
      };

      const renderedSubject = replaceVariables(template.subject);
      const renderedHtmlBody = replaceVariables(template.html_body);
      const renderedTextBody = template.text_body
        ? replaceVariables(template.text_body)
        : null;

      logger.info('Rendered email template', {
        templateId: template.id,
        templateName: template.name,
      });

      return {
        subject: renderedSubject,
        htmlBody: renderedHtmlBody,
        textBody: renderedTextBody,
      };
    } catch (error) {
      logger.error('Failed to render email template', {
        templateId: template?.id,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get delivery metrics
   *
   * @param {string} userId - User ID
   * @param {Object} [options] - Query options
   * @param {string} [options.startDate] - Start date (ISO format)
   * @param {string} [options.endDate] - End date (ISO format)
   * @returns {Promise<Object>} Delivery metrics
   */
  async getDeliveryMetrics(userId, options = {}) {
    const { startDate = null, endDate = null } = options;

    try {
      let query = `
        SELECT
          COUNT(*) as total_emails,
          SUM(CASE WHEN status = 'sent' THEN 1 ELSE 0 END) as sent_count,
          SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count,
          SUM(CASE WHEN status = 'bounced' THEN 1 ELSE 0 END) as bounced_count,
          SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count,
          AVG(EXTRACT(EPOCH FROM (delivered_at - created_at))) as avg_delivery_time_seconds,
          MIN(created_at) as earliest_email,
          MAX(created_at) as latest_email
        FROM email_queue
        WHERE user_id = $1
      `;

      const params = [userId];

      if (startDate) {
        query += ` AND created_at >= $${params.length + 1}`;
        params.push(startDate);
      }

      if (endDate) {
        query += ` AND created_at <= $${params.length + 1}`;
        params.push(endDate);
      }

      const result = await this.db.query(query, params);

      const metrics = result.rows[0] || {
        total_emails: 0,
        sent_count: 0,
        failed_count: 0,
        bounced_count: 0,
        pending_count: 0,
        avg_delivery_time_seconds: null,
      };

      // Calculate success rate
      metrics.success_rate =
        metrics.total_emails > 0
          ? ((metrics.sent_count / metrics.total_emails) * 100).toFixed(2)
          : 0;

      logger.info('Retrieved delivery metrics', {
        userId,
        totalEmails: metrics.total_emails,
        successRate: metrics.success_rate,
      });

      return metrics;
    } catch (error) {
      logger.error('Failed to retrieve delivery metrics', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get delivery logs
   *
   * @param {string} userId - User ID
   * @param {Object} [options] - Query options
   * @param {string} [options.status] - Filter by status
   * @param {number} [options.limit] - Result limit
   * @param {number} [options.offset] - Result offset
   * @returns {Promise<Array>} Delivery logs
   */
  async getDeliveryLogs(userId, options = {}) {
    const { status = null, limit = 50, offset = 0 } = options;

    try {
      let query = `
        SELECT
          eq.id,
          eq.recipient_email,
          eq.subject,
          eq.status,
          eq.created_at,
          eq.sent_at,
          eq.delivered_at,
          eq.last_error,
          eq.retry_count,
          edl.event_type,
          edl.error_message
        FROM email_queue eq
        LEFT JOIN email_delivery_logs edl ON eq.id = edl.email_queue_id
        WHERE eq.user_id = $1
      `;

      const params = [userId];

      if (status) {
        query += ` AND eq.status = $${params.length + 1}`;
        params.push(status);
      }

      query += ` ORDER BY eq.created_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
      params.push(limit, offset);

      const result = await this.db.query(query, params);

      logger.info('Retrieved delivery logs', {
        userId,
        count: result.rows.length,
      });

      return result.rows;
    } catch (error) {
      logger.error('Failed to retrieve delivery logs', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Encrypt data using AES-256-GCM
   * @private
   */
  _encryptData(data) {
    const encryptionKey = process.env.ENCRYPTION_KEY;

    if (!encryptionKey) {
      throw new Error('ENCRYPTION_KEY not configured');
    }

    const iv = crypto.randomBytes(16);
    const cipher = crypto.createCipheriv(
      'aes-256-gcm',
      Buffer.from(encryptionKey, 'hex'),
      iv,
    );

    let encrypted = cipher.update(data, 'utf8', 'hex');
    encrypted += cipher.final('hex');

    const authTag = cipher.getAuthTag();

    return JSON.stringify({
      iv: iv.toString('hex'),
      encrypted,
      authTag: authTag.toString('hex'),
    });
  }

  /**
   * Decrypt data using AES-256-GCM
   * @private
   */
  _decryptData(encryptedData) {
    const encryptionKey = process.env.ENCRYPTION_KEY;

    if (!encryptionKey) {
      throw new Error('ENCRYPTION_KEY not configured');
    }

    const { iv, encrypted, authTag } = JSON.parse(encryptedData);

    const decipher = crypto.createDecipheriv(
      'aes-256-gcm',
      Buffer.from(encryptionKey, 'hex'),
      Buffer.from(iv, 'hex'),
    );

    decipher.setAuthTag(Buffer.from(authTag, 'hex'));

    let decrypted = decipher.update(encrypted, 'hex', 'utf8');
    decrypted += decipher.final('utf8');

    return decrypted;
  }

  /**
   * Validate email address format
   * @private
   */
  _isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }
}

export default EmailConfigService;
