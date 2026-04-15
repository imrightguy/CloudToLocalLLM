/**
 * Email Queue Service Unit Tests
 *
 * Tests EmailQueueService constructor, rate limiting, backoff calculation,
 * email validation, message creation, queue operations, and failure handling.
 * All external dependencies (db, googleWorkspaceService, emailConfigService, logger) are mocked.
 */

import { jest, describe, it, expect, beforeEach, afterEach } from '@jest/globals';

// Mock logger before importing service
jest.mock('../../services/api-backend/logger.js', () => ({
  default: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
    debug: jest.fn(),
  },
}));

// Mock uuid
jest.mock('uuid', () => ({
  v4: jest.fn(() => 'test-uuid-' + Math.random().toString(36).slice(2, 8)),
}));

// Mock nodemailer - use jest.fn() so createTransport can be manipulated per-test
const mockCreateTransport = jest.fn();
jest.mock('nodemailer', () => ({
  default: {
    createTransport: mockCreateTransport,
  },
}));

import EmailQueueService from '../../services/api-backend/services/email-queue-service.js';

/**
 * Helper: create a fresh EmailQueueService with mocked dependencies.
 */
function createService(dbOverrides = {}, emailConfigOverrides = {}, googleOverrides = {}) {
  const db = {
    query: jest.fn(),
    ...dbOverrides,
  };
  const googleWorkspaceService = {
    getAccessToken: jest.fn(),
    sendEmail: jest.fn(),
    ...googleOverrides,
  };
  const emailConfigService = {
    getConfiguration: jest.fn(),
    getTemplate: jest.fn(),
    renderTemplate: jest.fn(),
    ...emailConfigOverrides,
  };
  const service = new EmailQueueService(db, googleWorkspaceService, emailConfigService);
  return { service, db, googleWorkspaceService, emailConfigService };
}

// ─── Constructor ───────────────────────────────────────────────────────────────

describe('EmailQueueService', () => {
  describe('constructor', () => {
    it('should initialize with default configuration', () => {
      const { service } = createService();
      expect(service.USER_RATE_LIMIT).toBe(100);
      expect(service.SYSTEM_RATE_LIMIT).toBe(1000);
      expect(service.MAX_RETRIES).toBe(3);
      expect(service.INITIAL_RETRY_DELAY).toBe(5000);
      expect(service.MAX_RETRY_DELAY).toBe(3600000);
      expect(service.isProcessing).toBe(false);
      expect(service.processingInterval).toBeNull();
    });

    it('should initialize empty rate limit maps', () => {
      const { service } = createService();
      expect(service.userRateLimits).toBeInstanceOf(Map);
      expect(service.userRateLimits.size).toBe(0);
      expect(service.systemRateLimit.count).toBe(0);
      expect(service.systemRateLimit.resetTime).toBeGreaterThan(Date.now());
    });

    it('should store provided dependencies', () => {
      const { service, db, googleWorkspaceService, emailConfigService } = createService();
      expect(service.db).toBe(db);
      expect(service.googleWorkspaceService).toBe(googleWorkspaceService);
      expect(service.emailConfigService).toBe(emailConfigService);
    });
  });

  // ─── Processor lifecycle ───────────────────────────────────────────────────

  describe('startProcessor / stopProcessor', () => {
    it('should start processor and set isProcessing flag', () => {
      const { service } = createService();
      service.startProcessor(1000);
      expect(service.isProcessing).toBe(true);
      expect(service.processingInterval).not.toBeNull();
      service.stopProcessor();
    });

    it('should warn if processor already running', () => {
      const { service } = createService();
      service.startProcessor(60000);
      service.startProcessor(60000); // second call
      // Should not create a second interval
      expect(service.isProcessing).toBe(true);
      service.stopProcessor();
    });

    it('should stop processor and clear interval', () => {
      const { service } = createService();
      service.startProcessor(60000);
      expect(service.isProcessing).toBe(true);
      service.stopProcessor();
      expect(service.isProcessing).toBe(false);
      expect(service.processingInterval).toBeNull();
    });

    it('should handle stopProcessor when not started', () => {
      const { service } = createService();
      expect(() => service.stopProcessor()).not.toThrow();
    });
  });

  // ─── Email validation ──────────────────────────────────────────────────────

  describe('_isValidEmail', () => {
    const { service } = createService();

    it('should accept valid email addresses', () => {
      expect(service._isValidEmail('user@example.com')).toBe(true);
      expect(service._isValidEmail('user.name@example.com')).toBe(true);
      expect(service._isValidEmail('user+tag@example.co.uk')).toBe(true);
    });

    it('should reject invalid email addresses', () => {
      expect(service._isValidEmail('')).toBe(false);
      expect(service._isValidEmail('notanemail')).toBe(false);
      expect(service._isValidEmail('@example.com')).toBe(false);
      expect(service._isValidEmail('user@')).toBe(false);
      expect(service._isValidEmail('user@.com')).toBe(false);
      expect(service._isValidEmail('user @example.com')).toBe(false);
    });
  });

  // ─── Backoff calculation ───────────────────────────────────────────────────

  describe('_calculateBackoffDelay', () => {
    const { service } = createService();

    it('should calculate exponential backoff with base 5', () => {
      // retryCount 1: 5000 * 5^0 = 5000
      expect(service._calculateBackoffDelay(1)).toBe(5000);
      // retryCount 2: 5000 * 5^1 = 25000
      expect(service._calculateBackoffDelay(2)).toBe(25000);
      // retryCount 3: 5000 * 5^2 = 125000
      expect(service._calculateBackoffDelay(3)).toBe(125000);
    });

    it('should cap delay at MAX_RETRY_DELAY', () => {
      // Very high retry count should cap at 3600000 (1 hour)
      expect(service._calculateBackoffDelay(20)).toBe(3600000);
    });

    it('should return INITIAL_RETRY_DELAY for retryCount=1', () => {
      expect(service._calculateBackoffDelay(1)).toBe(service.INITIAL_RETRY_DELAY);
    });
  });

  // ─── Rate limiting ─────────────────────────────────────────────────────────

  describe('_checkRateLimit / _updateRateLimit', () => {
    it('should allow emails under rate limit', () => {
      const { service } = createService();
      expect(() => service._checkRateLimit('user-1')).not.toThrow();
    });

    it('should track and enforce user rate limit', () => {
      const { service } = createService();
      // Simulate hitting the user limit
      for (let i = 0; i < service.USER_RATE_LIMIT; i++) {
        service._updateRateLimit('user-1');
      }
      expect(() => service._checkRateLimit('user-1')).toThrow(/User rate limit exceeded/);
    });

    it('should track different users independently', () => {
      const { service } = createService();
      // Fill user-1 to limit
      for (let i = 0; i < service.USER_RATE_LIMIT; i++) {
        service._updateRateLimit('user-1');
      }
      // user-2 should still be fine
      expect(() => service._checkRateLimit('user-2')).not.toThrow();
    });

    it('should reset user rate limit after window expires', () => {
      const { service } = createService();
      // Fill user-1 to limit
      for (let i = 0; i < service.USER_RATE_LIMIT; i++) {
        service._updateRateLimit('user-1');
      }
      expect(() => service._checkRateLimit('user-1')).toThrow(/User rate limit exceeded/);

      // Expire the window by setting resetTime to past
      const limit = service.userRateLimits.get('user-1');
      limit.resetTime = Date.now() - 1;
      expect(() => service._checkRateLimit('user-1')).not.toThrow();
    });

    it('should enforce system rate limit', () => {
      const { service } = createService();
      // Simulate system limit hit
      service.systemRateLimit = {
        count: service.SYSTEM_RATE_LIMIT,
        resetTime: Date.now() + 3600000,
      };
      expect(() => service._checkRateLimit('any-user')).toThrow(/System rate limit exceeded/);
    });

    it('should reset system rate limit after window expires', () => {
      const { service } = createService();
      service.systemRateLimit = {
        count: service.SYSTEM_RATE_LIMIT,
        resetTime: Date.now() - 1, // expired
      };
      expect(() => service._checkRateLimit('any-user')).not.toThrow();
    });

    it('should reset system counter when window expires during update', () => {
      const { service } = createService();
      service.systemRateLimit = {
        count: 999,
        resetTime: Date.now() - 1, // expired
      };
      service._updateRateLimit('user-1');
      expect(service.systemRateLimit.count).toBe(1);
    });
  });

  // ─── Email message creation ────────────────────────────────────────────────

  describe('_createEmailMessage', () => {
    const { service } = createService();

    it('should create RFC 2822 message with both html and text', () => {
      const msg = service._createEmailMessage({
        from: 'sender@example.com',
        to: 'recipient@example.com',
        subject: 'Test Subject',
        htmlBody: '<p>Hello</p>',
        textBody: 'Hello',
      });
      expect(msg).toContain('From: sender@example.com');
      expect(msg).toContain('To: recipient@example.com');
      expect(msg).toContain('Subject: Test Subject');
      expect(msg).toContain('MIME-Version: 1.0');
      expect(msg).toContain('multipart/alternative');
      expect(msg).toContain('<p>Hello</p>');
      expect(msg).toContain('Hello');
    });

    it('should work with only htmlBody', () => {
      const msg = service._createEmailMessage({
        from: 'a@b.com',
        to: 'c@d.com',
        subject: 'HTML only',
        htmlBody: '<b>Bold</b>',
      });
      expect(msg).toContain('<b>Bold</b>');
      expect(msg).toContain('text/html');
    });

    it('should work with only textBody', () => {
      const msg = service._createEmailMessage({
        from: 'a@b.com',
        to: 'c@d.com',
        subject: 'Text only',
        textBody: 'Plain text',
      });
      expect(msg).toContain('Plain text');
      expect(msg).toContain('text/plain');
    });

    it('should include boundary delimiter', () => {
      const msg = service._createEmailMessage({
        from: 'a@b.com',
        to: 'c@d.com',
        subject: 'Test',
        htmlBody: 'html',
        textBody: 'text',
      });
      expect(msg).toContain('boundary_');
    });
  });

  // ─── queueEmail ────────────────────────────────────────────────────────────

  describe('queueEmail', () => {
    it('should queue an email with htmlBody successfully', async () => {
      const { service, db } = createService();
      db.query.mockResolvedValue({
        rows: [{ id: 'test-id', status: 'pending', recipient_email: 'user@example.com' }],
      });

      const result = await service.queueEmail({
        userId: 'user-1',
        recipientEmail: 'user@example.com',
        subject: 'Test Subject',
        htmlBody: '<p>Hello</p>',
      });

      expect(result).toBeDefined();
      expect(result.status).toBe('pending');
      expect(db.query).toHaveBeenCalledTimes(1);
      // Verify INSERT query
      const query = db.query.mock.calls[0][0];
      expect(query).toContain('INSERT INTO email_queue');
    });

    it('should reject invalid email address', async () => {
      const { service } = createService();
      await expect(
        service.queueEmail({
          userId: 'user-1',
          recipientEmail: 'not-an-email',
          subject: 'Test',
          htmlBody: '<p>Hello</p>',
        }),
      ).rejects.toThrow(/Invalid recipient email/);
    });

    it('should reject when neither htmlBody nor templateName provided', async () => {
      const { service } = createService();
      await expect(
        service.queueEmail({
          userId: 'user-1',
          recipientEmail: 'user@example.com',
          subject: 'Test',
        }),
      ).rejects.toThrow(/Either htmlBody or templateName must be provided/);
    });

    it('should render template when templateName provided', async () => {
      const { service, db, emailConfigService } = createService();
      emailConfigService.getTemplate.mockResolvedValue({ html: 'tmpl-html', text: 'tmpl-text' });
      emailConfigService.renderTemplate.mockReturnValue({
        htmlBody: '<p>Rendered HTML</p>',
        textBody: 'Rendered Text',
      });
      db.query.mockResolvedValue({
        rows: [{ id: 'test-id', status: 'pending' }],
      });

      const result = await service.queueEmail({
        userId: 'user-1',
        recipientEmail: 'user@example.com',
        subject: 'Template Test',
        templateName: 'welcome',
        templateData: { name: 'John' },
      });

      expect(emailConfigService.getTemplate).toHaveBeenCalledWith('welcome', 'user-1');
      expect(emailConfigService.renderTemplate).toHaveBeenCalledWith(
        { html: 'tmpl-html', text: 'tmpl-text' },
        { name: 'John' },
      );
      expect(result).toBeDefined();
    });

    it('should throw if template not found', async () => {
      const { service, emailConfigService } = createService();
      emailConfigService.getTemplate.mockResolvedValue(null);

      await expect(
        service.queueEmail({
          userId: 'user-1',
          recipientEmail: 'user@example.com',
          subject: 'Test',
          templateName: 'nonexistent',
        }),
      ).rejects.toThrow(/Template not found/);
    });

    it('should throw when user rate limit exceeded', async () => {
      const { service } = createService();
      // Fill rate limit
      for (let i = 0; i < service.USER_RATE_LIMIT; i++) {
        service._updateRateLimit('user-1');
      }

      await expect(
        service.queueEmail({
          userId: 'user-1',
          recipientEmail: 'user@example.com',
          subject: 'Test',
          htmlBody: '<p>Hello</p>',
        }),
      ).rejects.toThrow(/User rate limit exceeded/);
    });
  });

  // ─── processPendingEmails ──────────────────────────────────────────────────

  describe('processPendingEmails', () => {
    it('should return zeros when no pending emails', async () => {
      const { service, db } = createService();
      db.query.mockResolvedValue({ rows: [] });

      const result = await service.processPendingEmails();
      expect(result).toEqual({ processed: 0, sent: 0, failed: 0 });
    });

    it('should process pending emails successfully', async () => {
      const { service, db, emailConfigService, googleWorkspaceService } = createService();

      const email = {
        id: 'email-1',
        user_id: 'user-1',
        recipient_email: 'recipient@example.com',
        subject: 'Test',
        html_body: '<p>Hi</p>',
        text_body: 'Hi',
        retry_count: 0,
        max_retries: 3,
      };

      // First query: get pending emails
      db.query.mockResolvedValueOnce({ rows: [email] });
      // _updateEmailStatus('sending')
      db.query.mockResolvedValueOnce({ rows: [] });
      // emailConfigService.getConfiguration('google_workspace') returns active config
      emailConfigService.getConfiguration.mockResolvedValue({ is_active: true, from_address: 'from@example.com', google_oauth_token_encrypted: 'token' });
      // googleWorkspaceService.getAccessToken
      googleWorkspaceService.getAccessToken.mockResolvedValue('access-token');
      // googleWorkspaceService.sendEmail
      googleWorkspaceService.sendEmail.mockResolvedValue({ id: 'msg-id' });
      // _updateEmailStatus('sent') from _sendViaGmail
      db.query.mockResolvedValueOnce({ rows: [] });
      // _updateEmailStatus('sent') from _sendEmail
      db.query.mockResolvedValueOnce({ rows: [] });

      const result = await service.processPendingEmails();
      expect(result.processed).toBe(1);
      expect(result.sent).toBe(1);
      expect(result.failed).toBe(0);
    });

    it('should handle send failure and retry', async () => {
      const { service, db, emailConfigService } = createService();

      const email = {
        id: 'email-1',
        user_id: 'user-1',
        recipient_email: 'recipient@example.com',
        subject: 'Test',
        html_body: '<p>Hi</p>',
        retry_count: 0,
        max_retries: 3,
      };

      // get pending emails
      db.query.mockResolvedValueOnce({ rows: [email] });
      // _updateEmailStatus('sending') - first call in _sendEmail
      db.query.mockResolvedValueOnce({ rows: [] });
      // getConfiguration throws
      emailConfigService.getConfiguration.mockResolvedValue(null);
      // _logDeliveryEvent
      db.query.mockResolvedValueOnce({ rows: [] });
      // _updateEmailStatus('queued') for retry
      db.query.mockResolvedValueOnce({ rows: [] });

      const result = await service.processPendingEmails();
      expect(result.processed).toBe(1);
      expect(result.sent).toBe(0);
      expect(result.failed).toBe(1);
    });

    it('should handle database error gracefully', async () => {
      const { service, db } = createService();
      db.query.mockRejectedValue(new Error('DB connection failed'));

      const result = await service.processPendingEmails();
      expect(result).toEqual({ processed: 0, sent: 0, failed: 0 });
    });
  });

  // ─── _handleEmailFailure ───────────────────────────────────────────────────

  describe('_handleEmailFailure', () => {
    it('should schedule retry when under max retries', async () => {
      const { service, db } = createService();
      const email = { id: 'e1', user_id: 'u1', recipient_email: 'a@b.com', retry_count: 0, max_retries: 3 };

      // _logDeliveryEvent
      db.query.mockResolvedValueOnce({ rows: [] });
      // _updateEmailStatus('queued')
      db.query.mockResolvedValueOnce({ rows: [] });

      await service._handleEmailFailure(email, new Error('SMTP timeout'));
      // Status 'queued' should be passed as $1 param
      const statusCall = db.query.mock.calls[1];
      expect(statusCall[1][0]).toBe('queued');
    });

    it('should move to dead letter queue at max retries', async () => {
      const { service, db } = createService();
      const email = { id: 'e1', user_id: 'u1', recipient_email: 'a@b.com', retry_count: 2, max_retries: 3 };

      // _logDeliveryEvent
      db.query.mockResolvedValueOnce({ rows: [] });
      // _updateEmailStatus('failed')
      db.query.mockResolvedValueOnce({ rows: [] });

      await service._handleEmailFailure(email, new Error('Permanent failure'));
      // Status 'failed' should be passed as $1 param
      const statusCall = db.query.mock.calls[1];
      expect(statusCall[1][0]).toBe('failed');
    });

    it('should handle errors in failure handler gracefully', async () => {
      const { service, db } = createService();
      const email = { id: 'e1', user_id: 'u1', recipient_email: 'a@b.com', retry_count: 0, max_retries: 3 };

      // _logDeliveryEvent throws
      db.query.mockRejectedValue(new Error('DB error'));

      // Should not throw
      await expect(service._handleEmailFailure(email, new Error('Send failed'))).resolves.toBeUndefined();
    });
  });

  // ─── getQueueStats ─────────────────────────────────────────────────────────

  describe('getQueueStats', () => {
    it('should return queue stats for all users', async () => {
      const { service, db } = createService();
      const stats = {
        total_queued: '10',
        pending_count: '3',
        queued_count: '2',
        sending_count: '1',
        sent_count: '3',
        failed_count: '1',
        bounced_count: '0',
        avg_delivery_time_seconds: '1.5',
      };
      db.query.mockResolvedValue({ rows: [stats] });

      const result = await service.getQueueStats();
      expect(result.total_queued).toBe('10');
      expect(result.sent_count).toBe('3');
    });

    it('should filter by userId when provided', async () => {
      const { service, db } = createService();
      db.query.mockResolvedValue({
        rows: [{ total_queued: '5', pending_count: '1', queued_count: '0', sending_count: '0', sent_count: '4', failed_count: '0', bounced_count: '0', avg_delivery_time_seconds: null }],
      });

      await service.getQueueStats('user-123');
      expect(db.query).toHaveBeenCalledTimes(1);
      const call = db.query.mock.calls[0];
      expect(call[0]).toContain('WHERE user_id = $1');
      expect(call[1]).toContain('user-123');
    });

    it('should throw on database error', async () => {
      const { service, db } = createService();
      db.query.mockRejectedValue(new Error('DB error'));
      await expect(service.getQueueStats()).rejects.toThrow('DB error');
    });
  });

  // ─── getDeadLetterQueue ────────────────────────────────────────────────────

  describe('getDeadLetterQueue', () => {
    it('should return failed emails', async () => {
      const { service, db } = createService();
      const failedEmails = [
        { id: 'e1', status: 'failed', recipient_email: 'a@b.com' },
        { id: 'e2', status: 'failed', recipient_email: 'c@d.com' },
      ];
      db.query.mockResolvedValue({ rows: failedEmails });

      const result = await service.getDeadLetterQueue();
      expect(result).toHaveLength(2);
    });

    it('should filter by userId', async () => {
      const { service, db } = createService();
      db.query.mockResolvedValue({ rows: [] });

      await service.getDeadLetterQueue('user-1');
      const call = db.query.mock.calls[0];
      expect(call[0]).toContain('user_id = $1');
    });

    it('should respect limit and offset options', async () => {
      const { service, db } = createService();
      db.query.mockResolvedValue({ rows: [] });

      await service.getDeadLetterQueue(null, { limit: 10, offset: 20 });
      const call = db.query.mock.calls[0];
      expect(call[0]).toContain('LIMIT');
      expect(call[0]).toContain('OFFSET');
    });

    it('should throw on database error', async () => {
      const { service, db } = createService();
      db.query.mockRejectedValue(new Error('DB error'));
      await expect(service.getDeadLetterQueue()).rejects.toThrow('DB error');
    });
  });

  // ─── retryFailedEmail ──────────────────────────────────────────────────────

  describe('retryFailedEmail', () => {
    it('should reset failed email to queued status', async () => {
      const { service, db } = createService();
      db.query.mockResolvedValue({
        rows: [{ id: 'e1', status: 'queued', retry_count: 0 }],
      });

      const result = await service.retryFailedEmail('e1');
      expect(result.status).toBe('queued');
      expect(result.retry_count).toBe(0);
    });

    it('should throw if email not found or not failed', async () => {
      const { service, db } = createService();
      db.query.mockResolvedValue({ rows: [] });

      await expect(service.retryFailedEmail('nonexistent')).rejects.toThrow(
        /Email not found or not in failed status/,
      );
    });

    it('should throw on database error', async () => {
      const { service, db } = createService();
      db.query.mockRejectedValue(new Error('DB error'));
      await expect(service.retryFailedEmail('e1')).rejects.toThrow('DB error');
    });
  });

  // ─── _sendEmail fallback to SMTP ───────────────────────────────────────────

  describe('_sendEmail SMTP fallback', () => {
    it('should call _sendViaSMTP when Gmail config is inactive', async () => {
      const { service, db, emailConfigService } = createService();

      // Mock _sendViaSMTP directly since nodemailer ESM mocking is tricky
      const smtpSpy = jest.spyOn(service, '_sendViaSMTP').mockResolvedValue(undefined);
      // Mock _updateEmailStatus to prevent DB calls inside _sendViaSMTP
      jest.spyOn(service, '_updateEmailStatus').mockResolvedValue(undefined);

      const email = {
        id: 'e1',
        user_id: 'u1',
        recipient_email: 'recipient@example.com',
        subject: 'Test',
        html_body: '<p>Hi</p>',
        text_body: 'Hi',
      };

      // Gmail config inactive
      emailConfigService.getConfiguration.mockResolvedValueOnce({ is_active: false });
      // SMTP config active
      emailConfigService.getConfiguration.mockResolvedValueOnce({
        is_active: true,
        smtp_host: 'localhost',
        smtp_port: 1025,
        from_address: 'from@example.com',
      });

      await service._sendEmail(email);
      expect(smtpSpy).toHaveBeenCalled();
      const smtpCall = smtpSpy.mock.calls[0];
      expect(smtpCall[1]).toEqual(expect.objectContaining({ is_active: true }));
    });

    it('should throw when no active config found', async () => {
      const { service, db, emailConfigService } = createService();

      const email = {
        id: 'e1',
        user_id: 'u1',
        recipient_email: 'recipient@example.com',
        subject: 'Test',
        html_body: '<p>Hi</p>',
      };

      // _updateEmailStatus('sending')
      db.query.mockResolvedValueOnce({ rows: [] });
      // No active configs
      emailConfigService.getConfiguration.mockResolvedValue({ is_active: false });

      await expect(service._sendEmail(email)).rejects.toThrow(/No active email configuration/);
    });
  });
});
