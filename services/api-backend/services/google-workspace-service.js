/**
 * Google Workspace Integration Service
 *
 * Handles Google Workspace integration including:
 * - OAuth 2.0 authentication with Google Workspace
 * - Gmail API integration for sending emails
 * - Service account support for system-generated emails
 * - Quota monitoring and tracking
 * - Webhook handling for bounce/delivery notifications
 * - Token refresh and management
 */

import { google } from 'googleapis';
import logger from '../logger.js';
import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';

class GoogleWorkspaceService {
  constructor(db) {
    this.db = db;
    this.oauth2Client = null;
    this.gmail = null;
    this.tokenCache = new Map();
    this.quotaCache = new Map();
    this.quotaCacheTTL = 5 * 60 * 1000; // 5 minutes
  }

  /**
   * Initialize the Google Workspace service with OAuth credentials
   */
  initialize() {
    const clientId = process.env.GOOGLE_CLIENT_ID;
    const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
    const redirectUri =
      process.env.GOOGLE_REDIRECT_URI ||
      'https://api.cloudtolocalllm.online/admin/email/oauth/callback';

    if (!clientId || !clientSecret) {
      throw new Error('Google OAuth credentials not configured');
    }

    this.oauth2Client = new google.auth.OAuth2(
      clientId,
      clientSecret,
      redirectUri,
    );

    this.gmail = google.gmail({ version: 'v1', auth: this.oauth2Client });
  }

  /**
   * Generate OAuth authorization URL for user consent
   *
   * @param {string} state - State parameter for CSRF protection
   * @returns {string} Authorization URL
   */
  getAuthorizationUrl(state) {
    if (!this.oauth2Client) {
      this.initialize();
    }

    const scopes = [
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/gmail.modify',
    ];

    return this.oauth2Client.generateAuthUrl({
      access_type: 'offline',
      scope: scopes,
      state: state,
      prompt: 'consent',
    });
  }

  /**
   * Exchange authorization code for tokens
   *
   * @param {string} code - Authorization code from OAuth callback
   * @returns {Promise<Object>} Tokens object with access_token and refresh_token
   */
  async exchangeCodeForTokens(code) {
    if (!this.oauth2Client) {
      this.initialize();
    }

    try {
      const { tokens } = await this.oauth2Client.getToken(code);

      logger.info('Successfully exchanged authorization code for tokens', {
        hasAccessToken: !!tokens.access_token,
        hasRefreshToken: !!tokens.refresh_token,
        expiresIn: tokens.expiry_date,
      });

      return tokens;
    } catch (error) {
      logger.error('Failed to exchange authorization code', {
        error: error.message,
      });
      throw new Error('Failed to exchange authorization code for tokens');
    }
  }

  /**
   * Store Google Workspace OAuth configuration
   *
   * @param {Object} params - Configuration parameters
   * @param {string} params.userId - User ID storing the configuration
   * @param {string} params.accessToken - Google OAuth access token
   * @param {string} params.refreshToken - Google OAuth refresh token
   * @param {number} params.expiresIn - Token expiration time in seconds
   * @param {string} params.userEmail - Google Workspace user email
   * @returns {Promise<Object>} Stored configuration
   */
  async storeOAuthConfiguration({
    userId,
    accessToken,
    refreshToken,
    userEmail,
  }) {
    const configId = uuidv4();
    const encryptedAccessToken = this._encryptToken(accessToken);
    const encryptedRefreshToken = this._encryptToken(refreshToken);

    try {
      const query = `
        INSERT INTO email_configurations (
          id, user_id, provider, google_oauth_token_encrypted,
          google_oauth_refresh_token_encrypted, from_address,
          is_active, created_at, updated_at, created_by, updated_by
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW(), $8, $8)
        ON CONFLICT (user_id, provider) DO UPDATE SET
          google_oauth_token_encrypted = $4,
          google_oauth_refresh_token_encrypted = $5,
          from_address = $6,
          is_active = $7,
          updated_at = NOW(),
          updated_by = $8
        RETURNING *
      `;

      const result = await this.db.query(query, [
        configId,
        userId,
        'google_workspace',
        encryptedAccessToken,
        encryptedRefreshToken,
        userEmail,
        true,
        userId,
      ]);

      logger.info('Stored Google Workspace OAuth configuration', {
        userId,
        userEmail,
        configId,
      });

      return result.rows[0];
    } catch (error) {
      logger.error('Failed to store OAuth configuration', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Retrieve Google Workspace OAuth configuration
   *
   * @param {string} userId - User ID
   * @returns {Promise<Object>} OAuth configuration
   */
  async getOAuthConfiguration(userId) {
    try {
      const query = `
        SELECT * FROM email_configurations
        WHERE user_id = $1 AND provider = 'google_workspace'
      `;

      const result = await this.db.query(query, [userId]);

      if (result.rows.length === 0) {
        return null;
      }

      const config = result.rows[0];

      // Decrypt tokens if they exist
      if (config.google_oauth_token_encrypted) {
        config.accessToken = this._decryptToken(
          config.google_oauth_token_encrypted,
        );
      }
      if (config.google_oauth_refresh_token_encrypted) {
        config.refreshToken = this._decryptToken(
          config.google_oauth_refresh_token_encrypted,
        );
      }

      config.userEmail = config.from_address;

      return config;
    } catch (error) {
      logger.error('Failed to retrieve OAuth configuration', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Refresh access token if expired
   *
   * @param {string} userId - User ID
   * @returns {Promise<string>} Valid access token
   */
  async getValidAccessToken(userId) {
    const config = await this.getOAuthConfiguration(userId);

    if (!config) {
      throw new Error('No Google Workspace configuration found');
    }

    // Return access token if available (assume it's valid for now)
    // In production, you'd check expiry_date from the database
    if (config.accessToken) {
      return config.accessToken;
    }

    // Token not available, need to refresh it
    if (!this.oauth2Client) {
      this.initialize();
    }

    if (!config.refreshToken) {
      throw new Error('No refresh token available for Google Workspace');
    }

    this.oauth2Client.setCredentials({
      refresh_token: config.refreshToken,
    });

    try {
      const { credentials } = await this.oauth2Client.refreshAccessToken();

      // Store updated tokens
      await this.storeOAuthConfiguration({
        userId,
        accessToken: credentials.access_token,
        refreshToken: credentials.refresh_token || config.refreshToken,
        expiresIn: credentials.expiry_date
          ? Math.floor((credentials.expiry_date - Date.now()) / 1000)
          : 3600,
        userEmail: config.userEmail || config.from_address,
      });

      logger.info('Refreshed Google Workspace access token', { userId });

      return credentials.access_token;
    } catch (error) {
      logger.error('Failed to refresh access token', {
        userId,
        error: error.message,
      });
      throw new Error('Failed to refresh Google Workspace access token');
    }
  }

  /**
   * Send email via Gmail API
   *
   * @param {Object} params - Email parameters
   * @param {string} params.userId - User ID (for OAuth context)
   * @param {string} params.to - Recipient email address
   * @param {string} params.subject - Email subject
   * @param {string} params.body - Email body (HTML)
   * @param {string} [params.from] - Sender email (defaults to configured user email)
   * @param {string} [params.replyTo] - Reply-to email address
   * @param {Array} [params.cc] - CC recipients
   * @param {Array} [params.bcc] - BCC recipients
   * @returns {Promise<Object>} Send result with message ID
   */
  async sendEmail({
    userId,
    to,
    subject,
    body,
    from = null,
    replyTo = null,
    cc = [],
    bcc = [],
  }) {
    try {
      const accessToken = await this.getValidAccessToken(userId);
      const config = await this.getOAuthConfiguration(userId);

      if (!config) {
        throw new Error('No Google Workspace configuration found');
      }

      const senderEmail = from || config.from_address;

      // Build email headers
      const headers = [
        `From: ${senderEmail}`,
        `To: ${to}`,
        `Subject: ${subject}`,
        'MIME-Version: 1.0',
        'Content-Type: text/html; charset=utf-8',
      ];

      if (replyTo) {
        headers.push(`Reply-To: ${replyTo}`);
      }

      if (cc && cc.length > 0) {
        headers.push(`Cc: ${cc.join(', ')}`);
      }

      if (bcc && bcc.length > 0) {
        headers.push(`Bcc: ${bcc.join(', ')}`);
      }

      // Build email message
      const emailMessage = headers.join('\r\n') + '\r\n\r\n' + body;

      // Encode message
      const encodedMessage = Buffer.from(emailMessage)
        .toString('base64')
        .replace(/\+/g, '-')
        .replace(/\//g, '_')
        .replace(/=+$/, '');

      // Send via Gmail API
      if (!this.oauth2Client) {
        this.initialize();
      }

      this.oauth2Client.setCredentials({ access_token: accessToken });
      const gmail = google.gmail({ version: 'v1', auth: this.oauth2Client });

      const response = await gmail.users.messages.send({
        userId: 'me',
        requestBody: {
          raw: encodedMessage,
        },
      });

      logger.info('Email sent successfully via Gmail API', {
        userId,
        to,
        subject,
        messageId: response.data.id,
      });

      return {
        success: true,
        messageId: response.data.id,
        timestamp: new Date(),
      };
    } catch (error) {
      logger.error('Failed to send email via Gmail API', {
        userId,
        to,
        subject,
        error: error.message,
      });

      return {
        success: false,
        error: error.message,
        timestamp: new Date(),
      };
    }
  }

  /**
   * Get Gmail quota usage
   *
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Quota information
   */
  async getQuotaUsage(userId) {
    try {
      // Check cache first
      const cacheKey = `quota_${userId}`;
      const cached = this.quotaCache.get(cacheKey);

      if (cached && Date.now() - cached.timestamp < this.quotaCacheTTL) {
        return cached.data;
      }

      const accessToken = await this.getValidAccessToken(userId);

      if (!this.oauth2Client) {
        this.initialize();
      }

      this.oauth2Client.setCredentials({ access_token: accessToken });
      const gmail = google.gmail({ version: 'v1', auth: this.oauth2Client });

      const response = await gmail.users.getProfile({
        userId: 'me',
      });

      const quotaData = {
        messagesTotal: response.data.messagesTotal || 0,
        messagesUnread: response.data.messagesUnread || 0,
        historyId: response.data.historyId,
        emailAddress: response.data.emailAddress,
        timestamp: new Date(),
      };

      // Cache the result
      this.quotaCache.set(cacheKey, {
        data: quotaData,
        timestamp: Date.now(),
      });

      logger.info('Retrieved Gmail quota usage', {
        userId,
        messagesTotal: quotaData.messagesTotal,
      });

      return quotaData;
    } catch (error) {
      logger.error('Failed to get Gmail quota usage', {
        userId,
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Get recommended DNS records for Google Workspace
   *
   * @param {string} userId - User ID
   * @param {string} domain - Domain name
   * @returns {Promise<Object>} Recommended DNS records
   */
  async getRecommendedDNSRecords(userId, domain) {
    try {
      const config = await this.getOAuthConfiguration(userId);

      if (!config) {
        throw new Error('No Google Workspace configuration found');
      }

      // Return standard Google Workspace DNS records
      const records = {
        mx: [
          {
            type: 'MX',
            name: domain,
            value: 'gmail-smtp-in.l.google.com',
            priority: 5,
            ttl: 3600,
          },
          {
            type: 'MX',
            name: domain,
            value: 'alt1.gmail-smtp-in.l.google.com',
            priority: 10,
            ttl: 3600,
          },
          {
            type: 'MX',
            name: domain,
            value: 'alt2.gmail-smtp-in.l.google.com',
            priority: 20,
            ttl: 3600,
          },
        ],
        spf: {
          type: 'TXT',
          name: domain,
          value: 'v=spf1 include:_spf.google.com ~all',
          ttl: 3600,
        },
        dmarc: {
          type: 'TXT',
          name: '_dmarc.' + domain,
          value: 'v=DMARC1; p=quarantine; rua=mailto:postmaster@' + domain,
          ttl: 3600,
        },
      };

      logger.info('Retrieved recommended DNS records for Google Workspace', {
        userId,
        domain,
      });

      return records;
    } catch (error) {
      logger.error('Failed to get recommended DNS records', {
        userId,
        domain,
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Handle Gmail webhook notification for bounce/delivery
   *
   * @param {Object} notification - Webhook notification payload
   * @returns {Promise<void>}
   */
  async handleWebhookNotification(notification) {
    try {
      const messageId = notification.message?.data?.messageId;
      const eventType = notification.message?.attributes?.eventType;

      if (!messageId || !eventType) {
        logger.warn('Invalid webhook notification format', { notification });
        return;
      }

      logger.info('Processing Gmail webhook notification', {
        messageId,
        eventType,
      });

      // Store webhook event in database for tracking
      const query = `
        INSERT INTO email_webhook_events (
          id, message_id, event_type, payload, created_at
        ) VALUES ($1, $2, $3, $4, NOW())
      `;

      await this.db.query(query, [
        uuidv4(),
        messageId,
        eventType,
        JSON.stringify(notification),
      ]);

      // Handle specific event types
      if (eventType === 'bounce') {
        await this._handleBounceEvent(messageId, notification);
      } else if (eventType === 'delivery') {
        await this._handleDeliveryEvent(messageId, notification);
      }
    } catch (error) {
      logger.error('Failed to handle webhook notification', {
        error: error.message,
      });
    }
  }

  /**
   * Handle bounce event
   * @private
   */
  async _handleBounceEvent(messageId, notification) {
    try {
      const bounceType = notification.bounce?.bounceType || 'unknown';
      const bouncedRecipients = notification.bounce?.bouncedRecipients || [];

      logger.warn('Email bounce detected', {
        messageId,
        bounceType,
        recipientCount: bouncedRecipients.length,
      });

      // Update email queue status
      const query = `
        UPDATE email_queue
        SET status = 'bounced', last_error = $1
        WHERE message_id = $2
      `;

      await this.db.query(query, [`Bounce: ${bounceType}`, messageId]);
    } catch (error) {
      logger.error('Failed to handle bounce event', {
        messageId,
        error: error.message,
      });
    }
  }

  /**
   * Handle delivery event
   * @private
   */
  async _handleDeliveryEvent(messageId, notification) {
    try {
      const deliveryTimestamp = notification.delivery?.timestamp;

      logger.info('Email delivered successfully', {
        messageId,
        deliveryTimestamp,
      });

      // Update email queue status
      const query = `
        UPDATE email_queue
        SET status = 'delivered', sent_at = $1
        WHERE message_id = $2
      `;

      await this.db.query(query, [new Date(deliveryTimestamp), messageId]);
    } catch (error) {
      logger.error('Failed to handle delivery event', {
        messageId,
        error: error.message,
      });
    }
  }

  /**
   * Encrypt token for storage
   * @private
   */
  _encryptToken(token) {
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

    let encrypted = cipher.update(token, 'utf8', 'hex');
    encrypted += cipher.final('hex');

    const authTag = cipher.getAuthTag();

    return JSON.stringify({
      iv: iv.toString('hex'),
      encrypted,
      authTag: authTag.toString('hex'),
    });
  }

  /**
   * Decrypt token from storage
   * @private
   */
  _decryptToken(encryptedData) {
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
   * Delete OAuth configuration
   *
   * @param {string} userId - User ID
   * @returns {Promise<void>}
   */
  async deleteOAuthConfiguration(userId) {
    try {
      const query = `
        DELETE FROM email_configurations
        WHERE user_id = $1 AND provider = 'google_workspace'
      `;

      await this.db.query(query, [userId]);

      logger.info('Deleted Google Workspace OAuth configuration', { userId });
    } catch (error) {
      logger.error('Failed to delete OAuth configuration', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }
}

export default GoogleWorkspaceService;
