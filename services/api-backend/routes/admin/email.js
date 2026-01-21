/**
 * Admin Email Configuration API Routes
 *
 * Provides secure administrative endpoints for email configuration management:
 * - Google Workspace OAuth setup and authentication
 * - Email configuration management
 * - Test email sending
 * - Email service status and quota monitoring
 * - Email template management
 * - Delivery metrics and tracking
 *
 * Security Features:
 * - Admin authentication required
 * - Role-based permission checking
 * - Comprehensive audit logging
 * - Encrypted credential storage
 */

import express from 'express';
import { adminAuth } from '../../middleware/admin-auth.js';
import { logAdminAction } from '../../utils/audit-logger.js';
import logger from '../../logger.js';
import { getPool } from '../../database/db-pool.js';
import {
  adminReadOnlyLimiter,
  adminRateLimiter,
} from '../../middleware/admin-rate-limiter.js';
import GoogleWorkspaceService from '../../services/google-workspace-service.js';
import EmailConfigService from '../../services/email-config-service.js';
import EmailQueueService from '../../services/email-queue-service.js';
import crypto from 'crypto';

const router = express.Router();

// Initialize services (will be set up in route handlers)
let googleWorkspaceService;
let emailConfigService;
let emailQueueService;

/**
 * Initialize services with database pool
 */
function initializeServices(pool) {
  if (!googleWorkspaceService) {
    googleWorkspaceService = new GoogleWorkspaceService(pool);
    googleWorkspaceService.initialize();
  }
  if (!emailConfigService) {
    emailConfigService = new EmailConfigService(pool);
  }
  if (!emailQueueService) {
    emailQueueService = new EmailQueueService(
      pool,
      googleWorkspaceService,
      emailConfigService,
    );
  }
}

/**
 * POST /api/admin/email/oauth/start
 * Start Google Workspace OAuth flow
 */
router.post(
  '/oauth/start',
  adminRateLimiter,
  adminAuth(['manage_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const state = crypto.randomBytes(32).toString('hex');

      if (!global.oauthStates) {
        global.oauthStates = new Map();
      }
      global.oauthStates.set(state, {
        userId: req.adminUser.id,
        createdAt: Date.now(),
        expiresAt: Date.now() + 10 * 60 * 1000,
      });

      const authUrl = googleWorkspaceService.getAuthorizationUrl(state);

      logger.info('✅ [AdminEmail] OAuth flow started', {
        adminUserId: req.adminUser.id,
        state: state.substring(0, 8) + '...',
      });

      res.json({
        success: true,
        data: {
          authorizationUrl: authUrl,
          state: state,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to start OAuth flow', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to start OAuth flow',
        code: 'OAUTH_START_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/email/oauth/callback
 * Handle Google OAuth callback
 */
router.post(
  '/oauth/callback',
  adminRateLimiter,
  adminAuth(['manage_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const { code, state } = req.body;

      if (!code || !state) {
        return res.status(400).json({
          error: 'Missing required parameters: code and state',
          code: 'MISSING_PARAMS',
        });
      }

      if (!global.oauthStates || !global.oauthStates.has(state)) {
        logger.warn('🔴 [AdminEmail] Invalid or expired OAuth state', {
          adminUserId: req.adminUser.id,
          state: state.substring(0, 8) + '...',
        });

        return res.status(400).json({
          error: 'Invalid or expired state parameter',
          code: 'INVALID_STATE',
        });
      }

      const stateData = global.oauthStates.get(state);

      if (Date.now() > stateData.expiresAt) {
        global.oauthStates.delete(state);
        return res.status(400).json({
          error: 'State parameter expired',
          code: 'STATE_EXPIRED',
        });
      }

      if (stateData.userId !== req.adminUser.id) {
        logger.warn('🔴 [AdminEmail] State mismatch - possible CSRF attempt', {
          adminUserId: req.adminUser.id,
          stateUserId: stateData.userId,
        });

        return res.status(403).json({
          error: 'State parameter does not match current user',
          code: 'STATE_MISMATCH',
        });
      }

      const tokens = await googleWorkspaceService.exchangeCodeForTokens(code);
      const userEmail = tokens.email || 'unknown@gmail.com';

      const config = await googleWorkspaceService.storeOAuthConfiguration({
        userId: req.adminUser.id,
        accessToken: tokens.access_token,
        refreshToken: tokens.refresh_token,
        expiresIn: tokens.expiry_date
          ? Math.floor((tokens.expiry_date - Date.now()) / 1000)
          : 3600,
        userEmail: userEmail,
      });

      global.oauthStates.delete(state);

      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'email_oauth_configured',
        resourceType: 'email_configuration',
        resourceId: config.id,
        details: {
          provider: 'google_workspace',
          userEmail: userEmail,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminEmail] OAuth callback processed successfully', {
        adminUserId: req.adminUser.id,
        userEmail: userEmail,
        configId: config.id,
      });

      res.json({
        success: true,
        data: {
          configuration: {
            id: config.id,
            provider: config.provider,
            from_address: config.from_address,
            is_active: config.is_active,
            created_at: config.created_at,
          },
          userEmail: userEmail,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to process OAuth callback', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to process OAuth callback',
        code: 'OAUTH_CALLBACK_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/email/config
 * Get current email configuration
 */
router.get(
  '/config',
  adminReadOnlyLimiter,
  adminAuth(['view_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const configs = await emailConfigService.getAllConfigurations(
        req.adminUser.id,
      );

      const sanitizedConfigs = configs.map((config) => ({
        id: config.id,
        provider: config.provider,
        from_address: config.from_address,
        from_name: config.from_name,
        reply_to_address: config.reply_to_address,
        is_active: config.is_active,
        created_at: config.created_at,
        updated_at: config.updated_at,
      }));

      logger.info('✅ [AdminEmail] Email configuration retrieved', {
        adminUserId: req.adminUser.id,
        configCount: sanitizedConfigs.length,
      });

      res.json({
        success: true,
        data: {
          configurations: sanitizedConfigs,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to retrieve email configuration', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve email configuration',
        code: 'CONFIG_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * DELETE /api/admin/email/config
 * Delete email configuration
 */
router.delete(
  '/config',
  adminRateLimiter,
  adminAuth(['manage_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const provider = req.query.provider || 'google_workspace';

      if (!['google_workspace', 'smtp_relay', 'sendgrid'].includes(provider)) {
        return res.status(400).json({
          error: 'Invalid provider',
          code: 'INVALID_PROVIDER',
        });
      }

      await emailConfigService.deleteConfiguration(req.adminUser.id, provider);

      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'email_config_deleted',
        resourceType: 'email_configuration',
        resourceId: `${req.adminUser.id}_${provider}`,
        details: {
          provider: provider,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminEmail] Email configuration deleted', {
        adminUserId: req.adminUser.id,
        provider: provider,
      });

      res.json({
        success: true,
        message: `${provider} configuration deleted successfully`,
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to delete email configuration', {
        adminUserId: req.adminUser?.id,
        provider: req.query.provider,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to delete email configuration',
        code: 'CONFIG_DELETE_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/email/test
 * Send test email
 */
router.post(
  '/test',
  adminRateLimiter,
  adminAuth(['manage_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const { recipientEmail, subject = 'Test Email from CloudToLocalLLM' } =
        req.body;

      if (!recipientEmail) {
        return res.status(400).json({
          error: 'Missing required parameter: recipientEmail',
          code: 'MISSING_RECIPIENT',
        });
      }

      const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
      if (!emailRegex.test(recipientEmail)) {
        return res.status(400).json({
          error: 'Invalid email format',
          code: 'INVALID_EMAIL',
        });
      }

      const config = await googleWorkspaceService.getOAuthConfiguration(
        req.adminUser.id,
      );

      if (!config) {
        return res.status(400).json({
          error:
            'No Google Workspace configuration found. Please set up OAuth first.',
          code: 'NO_CONFIG',
        });
      }

      const htmlBody = `
      <html>
        <body style="font-family: Arial, sans-serif;">
          <h2>Test Email from CloudToLocalLLM</h2>
          <p>This is a test email to verify your email configuration is working correctly.</p>
          <p><strong>Configuration Details:</strong></p>
          <ul>
            <li>Provider: Google Workspace</li>
            <li>From: ${config.from_address}</li>
            <li>Sent at: ${new Date().toISOString()}</li>
          </ul>
          <p>If you received this email, your email configuration is working properly!</p>
        </body>
      </html>
    `;

      const result = await googleWorkspaceService.sendEmail({
        userId: req.adminUser.id,
        to: recipientEmail,
        subject: subject,
        body: htmlBody,
      });

      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'test_email_sent',
        resourceType: 'email_test',
        resourceId: result.messageId || 'unknown',
        details: {
          recipientEmail: recipientEmail,
          subject: subject,
          success: result.success,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      if (!result.success) {
        logger.warn('⚠️ [AdminEmail] Test email failed to send', {
          adminUserId: req.adminUser.id,
          recipientEmail: recipientEmail,
          error: result.error,
        });

        return res.status(500).json({
          success: false,
          error: 'Failed to send test email',
          code: 'TEST_EMAIL_FAILED',
          details: result.error,
        });
      }

      logger.info('✅ [AdminEmail] Test email sent successfully', {
        adminUserId: req.adminUser.id,
        recipientEmail: recipientEmail,
        messageId: result.messageId,
      });

      res.json({
        success: true,
        data: {
          messageId: result.messageId,
          recipientEmail: recipientEmail,
          subject: subject,
          sentAt: result.timestamp,
        },
        message: 'Test email sent successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to send test email', {
        adminUserId: req.adminUser?.id,
        recipientEmail: req.body?.recipientEmail,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to send test email',
        code: 'TEST_EMAIL_ERROR',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/email/status
 * Get email service status
 */
router.get(
  '/status',
  adminReadOnlyLimiter,
  adminAuth(['view_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const config = await googleWorkspaceService.getOAuthConfiguration(
        req.adminUser.id,
      );

      const status = {
        configured: !!config,
        provider: config?.provider || null,
        from_address: config?.from_address || null,
        is_active: config?.is_active || false,
        created_at: config?.created_at || null,
        updated_at: config?.updated_at || null,
      };

      logger.info('✅ [AdminEmail] Email service status retrieved', {
        adminUserId: req.adminUser.id,
        configured: status.configured,
      });

      res.json({
        success: true,
        data: {
          status: status,
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to retrieve email service status', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve email service status',
        code: 'STATUS_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/email/quota
 * Get Google Workspace quota usage
 */
router.get(
  '/quota',
  adminReadOnlyLimiter,
  adminAuth(['view_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const config = await googleWorkspaceService.getOAuthConfiguration(
        req.adminUser.id,
      );

      if (!config) {
        return res.status(400).json({
          error: 'No Google Workspace configuration found',
          code: 'NO_CONFIG',
        });
      }

      const quotaData = await googleWorkspaceService.getQuotaUsage(
        req.adminUser.id,
      );

      logger.info('✅ [AdminEmail] Gmail quota retrieved', {
        adminUserId: req.adminUser.id,
        messagesTotal: quotaData.messagesTotal,
      });

      res.json({
        success: true,
        data: {
          quota: {
            messagesTotal: quotaData.messagesTotal,
            messagesUnread: quotaData.messagesUnread,
            emailAddress: quotaData.emailAddress,
            historyId: quotaData.historyId,
            retrievedAt: quotaData.timestamp,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to retrieve Gmail quota', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve Gmail quota',
        code: 'QUOTA_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/email/templates
 * List email templates
 */
router.get(
  '/templates',
  adminReadOnlyLimiter,
  adminAuth(['view_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const limit = Math.min(parseInt(req.query.limit) || 50, 100);
      const offset = parseInt(req.query.offset) || 0;

      const templates = await emailConfigService.listTemplates(
        req.adminUser.id,
        {
          limit,
          offset,
        },
      );

      const countQuery = `
      SELECT COUNT(*) as total FROM email_templates
      WHERE user_id = $1 OR (user_id IS NULL AND is_system_template = true)
    `;
      const countResult = await pool.query(countQuery, [req.adminUser.id]);
      const totalCount = parseInt(countResult.rows[0].total);

      logger.info('✅ [AdminEmail] Email templates listed', {
        adminUserId: req.adminUser.id,
        count: templates.length,
        totalCount,
      });

      res.json({
        success: true,
        data: {
          templates: templates.map((t) => ({
            id: t.id,
            name: t.name,
            description: t.description,
            subject: t.subject,
            variables: t.variables,
            is_system_template: t.is_system_template,
            is_active: t.is_active,
            created_at: t.created_at,
            updated_at: t.updated_at,
          })),
          pagination: {
            limit,
            offset,
            total: totalCount,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to list email templates', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to list email templates',
        code: 'TEMPLATES_LIST_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * POST /api/admin/email/templates
 * Create or update email template
 */
router.post(
  '/templates',
  adminRateLimiter,
  adminAuth(['manage_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const {
        name,
        subject,
        html_body,
        text_body = null,
        description = null,
        variables = [],
      } = req.body;

      if (!name || name.trim().length === 0) {
        return res.status(400).json({
          error: 'Template name is required',
          code: 'MISSING_NAME',
        });
      }

      if (!subject || subject.trim().length === 0) {
        return res.status(400).json({
          error: 'Template subject is required',
          code: 'MISSING_SUBJECT',
        });
      }

      if (!html_body || html_body.trim().length === 0) {
        return res.status(400).json({
          error: 'Template HTML body is required',
          code: 'MISSING_HTML_BODY',
        });
      }

      if (!Array.isArray(variables)) {
        return res.status(400).json({
          error: 'Variables must be an array',
          code: 'INVALID_VARIABLES',
        });
      }

      const template = await emailConfigService.saveTemplate({
        userId: req.adminUser.id,
        name: name.trim(),
        subject: subject.trim(),
        html_body: html_body.trim(),
        text_body: text_body ? text_body.trim() : null,
        description: description ? description.trim() : null,
        variables: variables,
        is_system_template: false,
      });

      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'email_template_created',
        resourceType: 'email_template',
        resourceId: template.id,
        details: {
          templateName: template.name,
          hasTextBody: !!template.text_body,
          variableCount: variables.length,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminEmail] Email template created/updated', {
        adminUserId: req.adminUser.id,
        templateId: template.id,
        templateName: template.name,
      });

      res.json({
        success: true,
        data: {
          template: {
            id: template.id,
            name: template.name,
            description: template.description,
            subject: template.subject,
            variables: template.variables,
            is_active: template.is_active,
            created_at: template.created_at,
            updated_at: template.updated_at,
          },
        },
        message: 'Template created/updated successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to create/update email template', {
        adminUserId: req.adminUser?.id,
        templateName: req.body?.name,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to create/update email template',
        code: 'TEMPLATE_SAVE_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * PUT /api/admin/email/templates/:id
 * Update specific email template
 */
router.put(
  '/templates/:id',
  adminRateLimiter,
  adminAuth(['manage_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const templateId = req.params.id;
      const { name, subject, html_body, text_body, description, variables } =
        req.body;

      const getQuery = `
      SELECT * FROM email_templates
      WHERE id = $1 AND (user_id = $2 OR user_id IS NULL)
    `;
      const getResult = await pool.query(getQuery, [
        templateId,
        req.adminUser.id,
      ]);

      if (getResult.rows.length === 0) {
        return res.status(404).json({
          error: 'Template not found',
          code: 'TEMPLATE_NOT_FOUND',
        });
      }

      const existingTemplate = getResult.rows[0];

      const updateName =
        name !== undefined ? name.trim() : existingTemplate.name;
      const updateSubject =
        subject !== undefined ? subject.trim() : existingTemplate.subject;
      const updateHtmlBody =
        html_body !== undefined ? html_body.trim() : existingTemplate.html_body;
      const updateTextBody =
        text_body !== undefined
          ? text_body
            ? text_body.trim()
            : null
          : existingTemplate.text_body;
      const updateDescription =
        description !== undefined
          ? description
            ? description.trim()
            : null
          : existingTemplate.description;
      const updateVariables =
        variables !== undefined
          ? variables
          : typeof existingTemplate.variables === 'string'
            ? JSON.parse(existingTemplate.variables)
            : existingTemplate.variables;

      if (!updateName || updateName.length === 0) {
        return res.status(400).json({
          error: 'Template name cannot be empty',
          code: 'INVALID_NAME',
        });
      }

      if (!updateSubject || updateSubject.length === 0) {
        return res.status(400).json({
          error: 'Template subject cannot be empty',
          code: 'INVALID_SUBJECT',
        });
      }

      if (!updateHtmlBody || updateHtmlBody.length === 0) {
        return res.status(400).json({
          error: 'Template HTML body cannot be empty',
          code: 'INVALID_HTML_BODY',
        });
      }

      const updateQuery = `
      UPDATE email_templates
      SET name = $1, subject = $2, html_body = $3, text_body = $4,
          description = $5, variables = $6, updated_at = NOW(), updated_by = $7
      WHERE id = $8 AND (user_id = $9 OR user_id IS NULL)
      RETURNING *
    `;

      const updateResult = await pool.query(updateQuery, [
        updateName,
        updateSubject,
        updateHtmlBody,
        updateTextBody,
        updateDescription,
        JSON.stringify(updateVariables),
        req.adminUser.id,
        templateId,
        req.adminUser.id,
      ]);

      if (updateResult.rows.length === 0) {
        return res.status(404).json({
          error: 'Template not found or cannot be updated',
          code: 'TEMPLATE_UPDATE_FAILED',
        });
      }

      const updatedTemplate = updateResult.rows[0];

      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'email_template_updated',
        resourceType: 'email_template',
        resourceId: templateId,
        details: {
          templateName: updateName,
          fieldsUpdated: Object.keys(req.body).filter(
            (k) => req.body[k] !== undefined,
          ),
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminEmail] Email template updated', {
        adminUserId: req.adminUser.id,
        templateId,
        templateName: updateName,
      });

      res.json({
        success: true,
        data: {
          template: {
            id: updatedTemplate.id,
            name: updatedTemplate.name,
            description: updatedTemplate.description,
            subject: updatedTemplate.subject,
            variables: updatedTemplate.variables,
            is_active: updatedTemplate.is_active,
            created_at: updatedTemplate.created_at,
            updated_at: updatedTemplate.updated_at,
          },
        },
        message: 'Template updated successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to update email template', {
        adminUserId: req.adminUser?.id,
        templateId: req.params.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to update email template',
        code: 'TEMPLATE_UPDATE_ERROR',
        details: error.message,
      });
    }
  },
);

/**
 * DELETE /api/admin/email/templates/:id
 * Delete email template
 */
router.delete(
  '/templates/:id',
  adminRateLimiter,
  adminAuth(['manage_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      const templateId = req.params.id;

      const getQuery = `
      SELECT * FROM email_templates
      WHERE id = $1 AND (user_id = $2 OR user_id IS NULL)
    `;
      const getResult = await pool.query(getQuery, [
        templateId,
        req.adminUser.id,
      ]);

      if (getResult.rows.length === 0) {
        return res.status(404).json({
          error: 'Template not found',
          code: 'TEMPLATE_NOT_FOUND',
        });
      }

      const template = getResult.rows[0];

      const deleteQuery = `
      DELETE FROM email_templates
      WHERE id = $1 AND (user_id = $2 OR user_id IS NULL)
    `;

      await pool.query(deleteQuery, [templateId, req.adminUser.id]);

      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'email_template_deleted',
        resourceType: 'email_template',
        resourceId: templateId,
        details: {
          templateName: template.name,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminEmail] Email template deleted', {
        adminUserId: req.adminUser.id,
        templateId,
        templateName: template.name,
      });

      res.json({
        success: true,
        message: 'Template deleted successfully',
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to delete email template', {
        adminUserId: req.adminUser?.id,
        templateId: req.params.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to delete email template',
        code: 'TEMPLATE_DELETE_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/email/metrics
 * Get email delivery metrics
 *
 * Query Parameters:
 * - startDate: Start date for metrics (ISO 8601 format, default: 7 days ago)
 * - endDate: End date for metrics (ISO 8601 format, default: now)
 *
 * Returns:
 * - Delivery metrics (sent, failed, bounced counts)
 * - Delivery time statistics
 * - Hourly breakdown
 * - Failure reasons
 */
router.get(
  '/metrics',
  adminReadOnlyLimiter,
  adminAuth(['view_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      // Parse date parameters
      const endDate = req.query.endDate
        ? new Date(req.query.endDate)
        : new Date();
      const startDate = req.query.startDate
        ? new Date(req.query.startDate)
        : new Date(endDate.getTime() - 7 * 24 * 60 * 60 * 1000);

      // Validate dates
      if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
        return res.status(400).json({
          error:
            'Invalid date format. Use ISO 8601 format (e.g., 2024-01-15T10:30:00Z)',
          code: 'INVALID_DATE_FORMAT',
        });
      }

      if (startDate > endDate) {
        return res.status(400).json({
          error: 'Start date must be before end date',
          code: 'INVALID_DATE_RANGE',
        });
      }

      // Get metrics from email_queue table (since email_delivery_logs is for detailed event tracking)
      const metricsQuery = `
      SELECT
        COUNT(*) FILTER (WHERE status = 'sent') as sent_count,
        COUNT(*) FILTER (WHERE status = 'failed') as failed_count,
        COUNT(*) FILTER (WHERE status = 'bounced') as bounced_count,
        COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
        COUNT(*) as total_count,
        AVG(EXTRACT(EPOCH FROM (sent_at - created_at))) FILTER (WHERE sent_at IS NOT NULL) as avg_delivery_time_seconds,
        MIN(EXTRACT(EPOCH FROM (sent_at - created_at))) FILTER (WHERE sent_at IS NOT NULL) as min_delivery_time_seconds,
        MAX(EXTRACT(EPOCH FROM (sent_at - created_at))) FILTER (WHERE sent_at IS NOT NULL) as max_delivery_time_seconds,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (sent_at - created_at))) FILTER (WHERE sent_at IS NOT NULL) as p50_delivery_time_seconds,
        PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (sent_at - created_at))) FILTER (WHERE sent_at IS NOT NULL) as p95_delivery_time_seconds,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (sent_at - created_at))) FILTER (WHERE sent_at IS NOT NULL) as p99_delivery_time_seconds
      FROM email_queue
      WHERE created_at >= $1 AND created_at <= $2
    `;

      const metricsResult = await pool.query(metricsQuery, [
        startDate,
        endDate,
      ]);
      const metrics = metricsResult.rows[0];

      // Get hourly breakdown
      const hourlyQuery = `
      SELECT
        DATE_TRUNC('hour', created_at) as hour,
        COUNT(*) FILTER (WHERE status = 'sent') as sent_count,
        COUNT(*) FILTER (WHERE status = 'failed') as failed_count,
        COUNT(*) FILTER (WHERE status = 'bounced') as bounced_count,
        COUNT(*) as total_count
      FROM email_queue
      WHERE created_at >= $1 AND created_at <= $2
      GROUP BY DATE_TRUNC('hour', created_at)
      ORDER BY hour ASC
    `;

      const hourlyResult = await pool.query(hourlyQuery, [startDate, endDate]);

      // Get failure reasons breakdown
      const failureReasonsQuery = `
      SELECT
        last_error as error_reason,
        COUNT(*) as count
      FROM email_queue
      WHERE created_at >= $1 AND created_at <= $2 AND status = 'failed'
      GROUP BY last_error
      ORDER BY count DESC
      LIMIT 10
    `;

      const failureReasonsResult = await pool.query(failureReasonsQuery, [
        startDate,
        endDate,
      ]);

      // Log audit action
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'email_metrics_viewed',
        resourceType: 'email_metrics',
        resourceId: 'metrics_query',
        details: {
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString(),
          metricsRetrieved: true,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminEmail] Email metrics retrieved', {
        adminUserId: req.adminUser.id,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        totalEmails: metrics.total_count,
      });

      res.json({
        success: true,
        data: {
          metrics: {
            summary: {
              sent: parseInt(metrics.sent_count) || 0,
              failed: parseInt(metrics.failed_count) || 0,
              bounced: parseInt(metrics.bounced_count) || 0,
              pending: parseInt(metrics.pending_count) || 0,
              total: parseInt(metrics.total_count) || 0,
              successRate:
                metrics.total_count > 0
                  ? ((metrics.sent_count / metrics.total_count) * 100).toFixed(
                      2,
                    )
                  : 0,
            },
            deliveryTime: {
              average: metrics.avg_delivery_time_seconds
                ? parseFloat(metrics.avg_delivery_time_seconds).toFixed(2)
                : null,
              min: metrics.min_delivery_time_seconds
                ? parseFloat(metrics.min_delivery_time_seconds).toFixed(2)
                : null,
              max: metrics.max_delivery_time_seconds
                ? parseFloat(metrics.max_delivery_time_seconds).toFixed(2)
                : null,
              p50: metrics.p50_delivery_time_seconds
                ? parseFloat(metrics.p50_delivery_time_seconds).toFixed(2)
                : null,
              p95: metrics.p95_delivery_time_seconds
                ? parseFloat(metrics.p95_delivery_time_seconds).toFixed(2)
                : null,
              p99: metrics.p99_delivery_time_seconds
                ? parseFloat(metrics.p99_delivery_time_seconds).toFixed(2)
                : null,
            },
            hourlyBreakdown: hourlyResult.rows.map((row) => ({
              hour: row.hour,
              sent: parseInt(row.sent_count) || 0,
              failed: parseInt(row.failed_count) || 0,
              bounced: parseInt(row.bounced_count) || 0,
              total: parseInt(row.total_count) || 0,
            })),
            failureReasons: failureReasonsResult.rows.map((row) => ({
              reason: row.error_reason || 'Unknown',
              count: parseInt(row.count) || 0,
            })),
          },
          timeRange: {
            startDate: startDate.toISOString(),
            endDate: endDate.toISOString(),
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to retrieve email metrics', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve email metrics',
        code: 'METRICS_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

/**
 * GET /api/admin/email/delivery-logs
 * Get email delivery logs with filtering
 *
 * Query Parameters:
 * - limit: Number of logs to return (default: 50, max: 500)
 * - offset: Number of logs to skip (default: 0)
 * - status: Filter by status (sent, failed, bounced, pending, all - default: all)
 * - startDate: Start date for logs (ISO 8601 format, default: 7 days ago)
 * - endDate: End date for logs (ISO 8601 format, default: now)
 * - recipientEmail: Filter by recipient email (partial match)
 * - subject: Filter by email subject (partial match)
 * - sortBy: Sort field (created_at, sent_at, status - default: created_at)
 * - sortOrder: Sort order (asc, desc - default: desc)
 *
 * Returns:
 * - Array of delivery logs
 * - Pagination info
 * - Total count
 */
router.get(
  '/delivery-logs',
  adminReadOnlyLimiter,
  adminAuth(['view_email_config']),
  async (req, res) => {
    try {
      const pool = getPool();
      initializeServices(pool);

      // Parse pagination parameters
      const limit = Math.min(parseInt(req.query.limit) || 50, 500);
      const offset = Math.max(parseInt(req.query.offset) || 0, 0);

      // Parse filter parameters
      const status = req.query.status || 'all';
      const recipientEmail = req.query.recipientEmail || '';
      const subject = req.query.subject || '';

      // Parse date parameters
      const endDate = req.query.endDate
        ? new Date(req.query.endDate)
        : new Date();
      const startDate = req.query.startDate
        ? new Date(req.query.startDate)
        : new Date(endDate.getTime() - 7 * 24 * 60 * 60 * 1000);

      // Validate dates
      if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) {
        return res.status(400).json({
          error:
            'Invalid date format. Use ISO 8601 format (e.g., 2024-01-15T10:30:00Z)',
          code: 'INVALID_DATE_FORMAT',
        });
      }

      if (startDate > endDate) {
        return res.status(400).json({
          error: 'Start date must be before end date',
          code: 'INVALID_DATE_RANGE',
        });
      }

      // Validate status filter
      const validStatuses = ['sent', 'failed', 'bounced', 'pending', 'all'];
      if (!validStatuses.includes(status)) {
        return res.status(400).json({
          error:
            'Invalid status filter. Valid values: sent, failed, bounced, pending, all',
          code: 'INVALID_STATUS',
        });
      }

      // Validate sort parameters
      const sortBy = ['created_at', 'sent_at', 'status'].includes(
        req.query.sortBy,
      )
        ? req.query.sortBy
        : 'created_at';
      const sortOrder = ['asc', 'desc'].includes(req.query.sortOrder)
        ? req.query.sortOrder.toUpperCase()
        : 'DESC';

      // Build WHERE clause
      let whereConditions = ['created_at >= $1 AND created_at <= $2'];
      let queryParams = [startDate, endDate];
      let paramIndex = 3;

      if (status !== 'all') {
        whereConditions.push(`status = $${paramIndex}`);
        queryParams.push(status);
        paramIndex++;
      }

      if (recipientEmail.trim()) {
        whereConditions.push(`recipient_email ILIKE $${paramIndex}`);
        queryParams.push(`%${recipientEmail}%`);
        paramIndex++;
      }

      if (subject.trim()) {
        whereConditions.push(`subject ILIKE $${paramIndex}`);
        queryParams.push(`%${subject}%`);
        paramIndex++;
      }

      const whereClause = whereConditions.join(' AND ');

      // Get total count
      const countQuery = `
      SELECT COUNT(*) as total FROM email_queue
      WHERE ${whereClause}
    `;
      const countResult = await pool.query(countQuery, queryParams);
      const totalCount = parseInt(countResult.rows[0].total);

      // Get delivery logs
      const logsQuery = `
      SELECT
        id,
        recipient_email,
        subject,
        status,
        retry_count,
        last_error,
        created_at,
        sent_at
      FROM email_queue
      WHERE ${whereClause}
      ORDER BY ${sortBy} ${sortOrder}
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1}
    `;

      queryParams.push(limit, offset);
      const logsResult = await pool.query(logsQuery, queryParams);

      // Log audit action
      await logAdminAction({
        adminUserId: req.adminUser.id,
        adminRole: req.adminRoles[0],
        action: 'email_delivery_logs_viewed',
        resourceType: 'email_delivery_logs',
        resourceId: 'logs_query',
        details: {
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString(),
          statusFilter: status,
          logsRetrieved: logsResult.rows.length,
        },
        ipAddress: req.ip,
        userAgent: req.get('User-Agent'),
      });

      logger.info('✅ [AdminEmail] Email delivery logs retrieved', {
        adminUserId: req.adminUser.id,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        statusFilter: status,
        logsCount: logsResult.rows.length,
        totalCount,
      });

      res.json({
        success: true,
        data: {
          logs: logsResult.rows.map((log) => ({
            id: log.id,
            recipientEmail: log.recipient_email,
            subject: log.subject,
            status: log.status,
            retryCount: log.retry_count,
            lastError: log.last_error,
            createdAt: log.created_at,
            sentAt: log.sent_at,
          })),
          pagination: {
            limit,
            offset,
            total: totalCount,
            hasMore: offset + limit < totalCount,
          },
        },
        timestamp: new Date().toISOString(),
      });
    } catch (error) {
      logger.error('🔴 [AdminEmail] Failed to retrieve email delivery logs', {
        adminUserId: req.adminUser?.id,
        error: error.message,
        stack: error.stack,
      });

      res.status(500).json({
        error: 'Failed to retrieve email delivery logs',
        code: 'DELIVERY_LOGS_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

export default router;
