/**
 * Email Queue Service
 *
 * Handles email queue management including:
 * - Queue persistence in PostgreSQL
 * - Retry logic with exponential backoff
 * - Dead letter queue for failed emails
 * - Rate limiting (100/hour per user, 1000/hour per system)
 * - Delivery tracking and status updates
 * - Fallback to SMTP relay if Gmail API fails
 */

import logger from '../logger.js';
import { v4 as uuidv4 } from 'uuid';
import nodemailer from 'nodemailer';

class EmailQueueService {
  constructor(db, googleWorkspaceService, emailConfigService) {
    this.db = db;
    this.googleWorkspaceService = googleWorkspaceService;
    this.emailConfigService = emailConfigService;

    // Rate limiting tracking
    this.userRateLimits = new Map(); // userId -> { count, resetTime }
    this.systemRateLimit = { count: 0, resetTime: Date.now() + 3600000 };

    // Configuration
    this.USER_RATE_LIMIT = 100; // emails per hour
    this.SYSTEM_RATE_LIMIT = 1000; // emails per hour
    this.MAX_RETRIES = 3;
    this.INITIAL_RETRY_DELAY = 5000; // 5 seconds
    this.MAX_RETRY_DELAY = 3600000; // 1 hour

    // Processing state
    this.isProcessing = false;
    this.processingInterval = null;
  }

  /**
   * Start the queue processor
   * Processes pending emails at regular intervals
   *
   * @param {number} [intervalMs=5000] - Processing interval in milliseconds
   */
  startProcessor(intervalMs = 5000) {
    if (this.isProcessing) {
      logger.warn('Email queue processor already running');
      return;
    }

    this.isProcessing = true;
    logger.info('Starting email queue processor', { intervalMs });

    this.processingInterval = setInterval(() => {
      this.processPendingEmails().catch((error) => {
        logger.error('Error processing email queue', { error: error.message });
      });
    }, intervalMs);
  }

  /**
   * Stop the queue processor
   */
  stopProcessor() {
    if (this.processingInterval) {
      clearInterval(this.processingInterval);
      this.processingInterval = null;
      this.isProcessing = false;
      logger.info('Stopped email queue processor');
    }
  }

  /**
   * Add email to queue
   *
   * @param {Object} params - Email parameters
   * @param {string} params.userId - User ID
   * @param {string} params.recipientEmail - Recipient email address
   * @param {string} [params.recipientName] - Recipient name
   * @param {string} params.subject - Email subject
   * @param {string} [params.templateName] - Template name
   * @param {Object} [params.templateData] - Template variables
   * @param {string} [params.htmlBody] - HTML body (if not using template)
   * @param {string} [params.textBody] - Text body (if not using template)
   * @returns {Promise<Object>} Queued email record
   */
  async queueEmail({
    userId,
    recipientEmail,
    recipientName = null,
    subject,
    templateName = null,
    templateData = {},
    htmlBody = null,
    textBody = null,
  }) {
    const emailId = uuidv4();

    try {
      // Validate rate limits
      this._checkRateLimit(userId);

      // Validate email address
      if (!this._isValidEmail(recipientEmail)) {
        throw new Error(`Invalid recipient email: ${recipientEmail}`);
      }

      // If using template, render it
      let finalHtmlBody = htmlBody;
      let finalTextBody = textBody;

      if (templateName) {
        const template = await this.emailConfigService.getTemplate(
          templateName,
          userId,
        );
        if (!template) {
          throw new Error(`Template not found: ${templateName}`);
        }

        const rendered = this.emailConfigService.renderTemplate(
          template,
          templateData,
        );
        finalHtmlBody = rendered.htmlBody;
        finalTextBody = rendered.textBody;
      }

      if (!finalHtmlBody && !finalTextBody) {
        throw new Error('Either htmlBody or templateName must be provided');
      }

      // Insert into queue
      const query = `
        INSERT INTO email_queue (
          id, user_id, recipient_email, recipient_name, subject,
          template_name, template_data, html_body, text_body,
          status, retry_count, max_retries, created_at, updated_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW())
        RETURNING *
      `;

      const result = await this.db.query(query, [
        emailId,
        userId,
        recipientEmail,
        recipientName,
        subject,
        templateName,
        JSON.stringify(templateData),
        finalHtmlBody,
        finalTextBody,
        'pending',
        0,
        this.MAX_RETRIES,
      ]);

      // Update rate limits
      this._updateRateLimit(userId);

      logger.info('Email queued successfully', {
        emailId,
        userId,
        recipientEmail,
        subject,
      });

      return result.rows[0];
    } catch (error) {
      logger.error('Failed to queue email', {
        userId,
        recipientEmail,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Process pending emails from the queue
   * Attempts to send emails and handles retries
   *
   * @returns {Promise<Object>} Processing results
   */
  async processPendingEmails() {
    try {
      // Get pending emails (limit to 10 per batch)
      const query = `
        SELECT * FROM email_queue
        WHERE status IN ('pending', 'queued')
        AND (last_retry_at IS NULL OR last_retry_at < NOW() - INTERVAL '1 minute')
        ORDER BY created_at ASC
        LIMIT 10
      `;

      const result = await this.db.query(query);
      const pendingEmails = result.rows;

      if (pendingEmails.length === 0) {
        return { processed: 0, sent: 0, failed: 0 };
      }

      let sent = 0;
      let failed = 0;

      for (const email of pendingEmails) {
        try {
          await this._sendEmail(email);
          sent++;
        } catch (error) {
          await this._handleEmailFailure(email, error);
          failed++;
        }
      }

      logger.info('Email queue processing completed', {
        processed: pendingEmails.length,
        sent,
        failed,
      });

      return { processed: pendingEmails.length, sent, failed };
    } catch (error) {
      logger.error('Error processing email queue', {
        error: error.message,
      });
      return { processed: 0, sent: 0, failed: 0 };
    }
  }

  /**
   * Send a single email
   * @private
   */
  async _sendEmail(email) {
    try {
      // Update status to sending
      await this._updateEmailStatus(email.id, 'sending');

      // Get user's email configuration
      const config = await this.emailConfigService.getConfiguration(
        email.user_id,
        'google_workspace',
      );

      if (!config || !config.is_active) {
        // Try SMTP relay fallback
        const smtpConfig = await this.emailConfigService.getConfiguration(
          email.user_id,
          'smtp_relay',
        );

        if (smtpConfig && smtpConfig.is_active) {
          await this._sendViaSMTP(email, smtpConfig);
        } else {
          throw new Error('No active email configuration found');
        }
      } else {
        // Send via Google Workspace Gmail API
        await this._sendViaGmail(email, config);
      }

      // Update status to sent
      await this._updateEmailStatus(email.id, 'sent', {
        sent_at: new Date(),
      });

      logger.info('Email sent successfully', {
        emailId: email.id,
        recipientEmail: email.recipient_email,
      });
    } catch (error) {
      logger.error('Failed to send email', {
        emailId: email.id,
        recipientEmail: email.recipient_email,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Send email via Gmail API
   * @private
   */
  async _sendViaGmail(email, config) {
    try {
      // Get fresh access token
      const accessToken = await this.googleWorkspaceService.getAccessToken(
        email.user_id,
        config.google_oauth_token_encrypted,
      );

      // Create email message
      const message = this._createEmailMessage({
        from: config.from_address,
        to: email.recipient_email,
        subject: email.subject,
        htmlBody: email.html_body,
        textBody: email.text_body,
      });

      // Send via Gmail API
      const result = await this.googleWorkspaceService.sendEmail(
        accessToken,
        message,
      );

      // Store message ID for tracking
      await this._updateEmailStatus(email.id, 'sent', {
        message_id: result.id,
        sent_at: new Date(),
      });

      logger.info('Email sent via Gmail API', {
        emailId: email.id,
        messageId: result.id,
      });
    } catch (error) {
      logger.error('Failed to send email via Gmail', {
        emailId: email.id,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Send email via SMTP relay (fallback)
   * @private
   */
  async _sendViaSMTP(email, config) {
    try {
      // Create SMTP transporter
      const transporter = nodemailer.createTransport({
        host: config.smtp_host,
        port: config.smtp_port,
        secure: config.tls_enabled,
        auth: {
          user: config.smtp_username,
          pass: config.smtpPassword,
        },
      });

      // Send email
      const result = await transporter.sendMail({
        from: config.from_address,
        to: email.recipient_email,
        subject: email.subject,
        html: email.html_body,
        text: email.text_body,
      });

      // Store message ID for tracking
      await this._updateEmailStatus(email.id, 'sent', {
        message_id: result.messageId,
        sent_at: new Date(),
      });

      logger.info('Email sent via SMTP relay', {
        emailId: email.id,
        messageId: result.messageId,
      });
    } catch (error) {
      logger.error('Failed to send email via SMTP', {
        emailId: email.id,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Handle email delivery failure with retry logic
   * @private
   */
  async _handleEmailFailure(email, error) {
    try {
      const retryCount = email.retry_count + 1;
      const maxRetries = email.max_retries || this.MAX_RETRIES;

      // Log delivery failure
      await this._logDeliveryEvent(email.id, email.user_id, 'failed', {
        error_message: error.message,
        retry_count: retryCount,
      });

      if (retryCount >= maxRetries) {
        // Move to dead letter queue
        await this._updateEmailStatus(email.id, 'failed', {
          last_error: error.message,
          retry_count: retryCount,
        });

        logger.warn('Email moved to dead letter queue', {
          emailId: email.id,
          recipientEmail: email.recipient_email,
          retryCount,
          maxRetries,
        });
      } else {
        // Schedule retry with exponential backoff
        const delayMs = this._calculateBackoffDelay(retryCount);
        const nextRetryAt = new Date(Date.now() + delayMs);

        await this._updateEmailStatus(email.id, 'queued', {
          last_error: error.message,
          retry_count: retryCount,
          last_retry_at: nextRetryAt,
        });

        logger.info('Email scheduled for retry', {
          emailId: email.id,
          recipientEmail: email.recipient_email,
          retryCount,
          nextRetryAt,
          delayMs,
        });
      }
    } catch (error) {
      logger.error('Error handling email failure', {
        emailId: email.id,
        error: error.message,
      });
    }
  }

  /**
   * Update email status in database
   * @private
   */
  async _updateEmailStatus(emailId, status, updates = {}) {
    try {
      let query = `
        UPDATE email_queue
        SET status = $1, updated_at = NOW()
      `;

      const params = [status, emailId];
      let paramIndex = 3;

      // Add optional updates
      if (updates.sent_at) {
        query += `, sent_at = $${paramIndex}`;
        params.splice(paramIndex - 1, 0, updates.sent_at);
        paramIndex++;
      }

      if (updates.message_id) {
        query += `, message_id = $${paramIndex}`;
        params.splice(paramIndex - 1, 0, updates.message_id);
        paramIndex++;
      }

      if (updates.last_error) {
        query += `, last_error = $${paramIndex}`;
        params.splice(paramIndex - 1, 0, updates.last_error);
        paramIndex++;
      }

      if (updates.retry_count !== undefined) {
        query += `, retry_count = $${paramIndex}`;
        params.splice(paramIndex - 1, 0, updates.retry_count);
        paramIndex++;
      }

      if (updates.last_retry_at) {
        query += `, last_retry_at = $${paramIndex}`;
        params.splice(paramIndex - 1, 0, updates.last_retry_at);
        paramIndex++;
      }

      query += ' WHERE id = $2';

      await this.db.query(query, params);
    } catch (error) {
      logger.error('Failed to update email status', {
        emailId,
        status,
        error: error.message,
      });
    }
  }

  /**
   * Log delivery event
   * @private
   */
  async _logDeliveryEvent(emailQueueId, userId, eventType, metadata = {}) {
    try {
      const query = `
        INSERT INTO email_delivery_logs (
          id, email_queue_id, user_id, event_type, event_status,
          error_message, created_at, metadata
        ) VALUES ($1, $2, $3, $4, $5, $6, NOW(), $7)
      `;

      await this.db.query(query, [
        uuidv4(),
        emailQueueId,
        userId,
        eventType,
        'completed',
        metadata.error_message || null,
        JSON.stringify(metadata),
      ]);
    } catch (error) {
      logger.error('Failed to log delivery event', {
        emailQueueId,
        eventType,
        error: error.message,
      });
    }
  }

  /**
   * Calculate exponential backoff delay
   * @private
   */
  _calculateBackoffDelay(retryCount) {
    // Exponential backoff: 5s, 25s, 125s, etc.
    const delay = this.INITIAL_RETRY_DELAY * Math.pow(5, retryCount - 1);
    return Math.min(delay, this.MAX_RETRY_DELAY);
  }

  /**
   * Check rate limits
   * @private
   */
  _checkRateLimit(userId) {
    const now = Date.now();

    // Check user rate limit
    const userLimit = this.userRateLimits.get(userId);
    if (userLimit && now < userLimit.resetTime) {
      if (userLimit.count >= this.USER_RATE_LIMIT) {
        throw new Error(
          `User rate limit exceeded (${this.USER_RATE_LIMIT}/hour)`,
        );
      }
    }

    // Check system rate limit
    if (now < this.systemRateLimit.resetTime) {
      if (this.systemRateLimit.count >= this.SYSTEM_RATE_LIMIT) {
        throw new Error(
          `System rate limit exceeded (${this.SYSTEM_RATE_LIMIT}/hour)`,
        );
      }
    }
  }

  /**
   * Update rate limit counters
   * @private
   */
  _updateRateLimit(userId) {
    const now = Date.now();

    // Update user rate limit
    const userLimit = this.userRateLimits.get(userId);
    if (!userLimit || now >= userLimit.resetTime) {
      this.userRateLimits.set(userId, {
        count: 1,
        resetTime: now + 3600000, // 1 hour
      });
    } else {
      userLimit.count++;
    }

    // Update system rate limit
    if (now >= this.systemRateLimit.resetTime) {
      this.systemRateLimit = {
        count: 1,
        resetTime: now + 3600000, // 1 hour
      };
    } else {
      this.systemRateLimit.count++;
    }
  }

  /**
   * Create email message in RFC 2822 format
   * @private
   */
  _createEmailMessage({ from, to, subject, htmlBody, textBody }) {
    const boundary = `boundary_${Date.now()}`;
    let message = `From: ${from}\r\n`;
    message += `To: ${to}\r\n`;
    message += `Subject: ${subject}\r\n`;
    message += 'MIME-Version: 1.0\r\n';
    message += `Content-Type: multipart/alternative; boundary="${boundary}"\r\n\r\n`;

    if (textBody) {
      message += `--${boundary}\r\n`;
      message += 'Content-Type: text/plain; charset="UTF-8"\r\n\r\n';
      message += `${textBody}\r\n`;
    }

    if (htmlBody) {
      message += `--${boundary}\r\n`;
      message += 'Content-Type: text/html; charset="UTF-8"\r\n\r\n';
      message += `${htmlBody}\r\n`;
    }

    message += `--${boundary}--`;

    return message;
  }

  /**
   * Validate email address format
   * @private
   */
  _isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  /**
   * Get queue statistics
   *
   * @param {string} [userId] - User ID (optional, for user-specific stats)
   * @returns {Promise<Object>} Queue statistics
   */
  async getQueueStats(userId = null) {
    try {
      let query = `
        SELECT
          COUNT(*) as total_queued,
          SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) as pending_count,
          SUM(CASE WHEN status = 'queued' THEN 1 ELSE 0 END) as queued_count,
          SUM(CASE WHEN status = 'sending' THEN 1 ELSE 0 END) as sending_count,
          SUM(CASE WHEN status = 'sent' THEN 1 ELSE 0 END) as sent_count,
          SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) as failed_count,
          SUM(CASE WHEN status = 'bounced' THEN 1 ELSE 0 END) as bounced_count,
          AVG(EXTRACT(EPOCH FROM (delivered_at - created_at))) as avg_delivery_time_seconds
        FROM email_queue
      `;

      const params = [];

      if (userId) {
        query += ' WHERE user_id = $1';
        params.push(userId);
      }

      const result = await this.db.query(query, params);

      return (
        result.rows[0] || {
          total_queued: 0,
          pending_count: 0,
          queued_count: 0,
          sending_count: 0,
          sent_count: 0,
          failed_count: 0,
          bounced_count: 0,
          avg_delivery_time_seconds: null,
        }
      );
    } catch (error) {
      logger.error('Failed to get queue statistics', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get dead letter queue (failed emails)
   *
   * @param {string} [userId] - User ID (optional)
   * @param {Object} [options] - Query options
   * @param {number} [options.limit] - Result limit
   * @param {number} [options.offset] - Result offset
   * @returns {Promise<Array>} Failed emails
   */
  async getDeadLetterQueue(userId = null, options = {}) {
    const { limit = 50, offset = 0 } = options;

    try {
      let query = `
        SELECT * FROM email_queue
        WHERE status = 'failed'
      `;

      const params = [];

      if (userId) {
        query += ` AND user_id = $${params.length + 1}`;
        params.push(userId);
      }

      query += ` ORDER BY updated_at DESC LIMIT $${params.length + 1} OFFSET $${params.length + 2}`;
      params.push(limit, offset);

      const result = await this.db.query(query, params);

      logger.info('Retrieved dead letter queue', {
        userId,
        count: result.rows.length,
      });

      return result.rows;
    } catch (error) {
      logger.error('Failed to retrieve dead letter queue', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Retry a failed email
   *
   * @param {string} emailId - Email ID
   * @returns {Promise<Object>} Updated email record
   */
  async retryFailedEmail(emailId) {
    try {
      const query = `
        UPDATE email_queue
        SET status = 'queued', retry_count = 0, last_error = NULL, updated_at = NOW()
        WHERE id = $1 AND status = 'failed'
        RETURNING *
      `;

      const result = await this.db.query(query, [emailId]);

      if (result.rows.length === 0) {
        throw new Error('Email not found or not in failed status');
      }

      logger.info('Retried failed email', {
        emailId,
      });

      return result.rows[0];
    } catch (error) {
      logger.error('Failed to retry email', {
        emailId,
        error: error.message,
      });
      throw error;
    }
  }
}

export default EmailQueueService;
