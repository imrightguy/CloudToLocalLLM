/**
 * Alerting Service
 *
 * Provides alerting capabilities for critical system events:
 * - Email alerts via nodemailer
 * - Slack webhook notifications
 * - PagerDuty integration
 *
 * Configuration via environment variables:
 * - ALERT_EMAIL_ENABLED=true
 * - ALERT_EMAIL_TO=admin@example.com
 * - ALERT_SLACK_ENABLED=true
 * - ALERT_SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...
 * - ALERT_PAGERDUTY_ENABLED=true
 * - ALERT_PAGERDUTY_INTEGRATION_KEY=...
 */

import logger from '../logger.js';
import nodemailer from 'nodemailer';
import fetch from 'node-fetch';

// Configuration from environment
const EMAIL_ENABLED = process.env.ALERT_EMAIL_ENABLED === 'true';
const EMAIL_TO = process.env.ALERT_EMAIL_TO || '';
const EMAIL_FROM =
  process.env.ALERT_EMAIL_FROM || 'alerts@cloudtolocalllm.online';
const EMAIL_SMTP_HOST = process.env.ALERT_EMAIL_SMTP_HOST || 'smtp.gmail.com';
const EMAIL_SMTP_PORT = parseInt(
  process.env.ALERT_EMAIL_SMTP_PORT || '587',
  10
);
const EMAIL_SMTP_USER = process.env.ALERT_EMAIL_SMTP_USER || '';
const EMAIL_SMTP_PASS = process.env.ALERT_EMAIL_SMTP_PASS || '';

const SLACK_ENABLED = process.env.ALERT_SLACK_ENABLED === 'true';
const SLACK_WEBHOOK_URL = process.env.ALERT_SLACK_WEBHOOK_URL || '';

const PAGERDUTY_ENABLED = process.env.ALERT_PAGERDUTY_ENABLED === 'true';
const PAGERDUTY_INTEGRATION_KEY =
  process.env.ALERT_PAGERDUTY_INTEGRATION_KEY || '';

// Email transporter (lazy initialization)
let emailTransporter = null;

/**
 * Initialize email transporter
 */
function initializeEmailTransporter() {
  if (!EMAIL_ENABLED || !EMAIL_SMTP_USER || !EMAIL_SMTP_PASS) {
    logger.warn('[Alerting] Email alerts disabled or not configured');
    return null;
  }

  try {
    emailTransporter = nodemailer.createTransport({
      host: EMAIL_SMTP_HOST,
      port: EMAIL_SMTP_PORT,
      secure: EMAIL_SMTP_PORT === 465,
      auth: {
        user: EMAIL_SMTP_USER,
        pass: EMAIL_SMTP_PASS,
      },
    });
    logger.info('[Alerting] Email transporter initialized');
    return emailTransporter;
  } catch (error) {
    logger.error('[Alerting] Failed to initialize email transporter', {
      error: error.message,
    });
    return null;
  }
}

/**
 * Send email alert
 *
 * @param {string} subject - Alert subject
 * @param {string} message - Alert message
 * @param {Object} metadata - Additional metadata
 */
async function sendEmailAlert(subject, message, metadata = {}) {
  if (!EMAIL_ENABLED || !EMAIL_TO) {
    return { success: false, reason: 'Email alerts not configured' };
  }

  if (!emailTransporter) {
    emailTransporter = initializeEmailTransporter();
    if (!emailTransporter) {
      return { success: false, reason: 'Email transporter not available' };
    }
  }

  try {
    const htmlBody = `
      <h2>${subject}</h2>
      <p>${message}</p>
      ${
        Object.keys(metadata).length > 0
          ? `
        <h3>Details:</h3>
        <pre>${JSON.stringify(metadata, null, 2)}</pre>
      `
          : ''
      }
      <hr>
      <p><small>CloudToLocalLLM Alerting System</small></p>
    `;

    const info = await emailTransporter.sendMail({
      from: EMAIL_FROM,
      to: EMAIL_TO,
      subject: `[ALERT] ${subject}`,
      text: `${message}\n\nDetails:\n${JSON.stringify(metadata, null, 2)}`,
      html: htmlBody,
    });

    logger.info('[Alerting] Email alert sent', { messageId: info.messageId });
    return { success: true, messageId: info.messageId };
  } catch (error) {
    logger.error('[Alerting] Failed to send email alert', {
      error: error.message,
    });
    return { success: false, reason: error.message };
  }
}

/**
 * Send Slack alert
 *
 * @param {string} title - Alert title
 * @param {string} message - Alert message
 * @param {Object} metadata - Additional metadata
 */
async function sendSlackAlert(title, message, metadata = {}) {
  if (!SLACK_ENABLED || !SLACK_WEBHOOK_URL) {
    return { success: false, reason: 'Slack alerts not configured' };
  }

  try {
    const fields = Object.entries(metadata).map(([key, value]) => ({
      title: key,
      value:
        typeof value === 'object'
          ? JSON.stringify(value, null, 2)
          : String(value),
      short: true,
    }));

    const payload = {
      text: `🚨 *${title}*`,
      attachments: [
        {
          color: 'danger',
          text: message,
          fields: fields.length > 0 ? fields : undefined,
          footer: 'CloudToLocalLLM Alerting System',
          ts: Math.floor(Date.now() / 1000),
        },
      ],
    };

    const response = await fetch(SLACK_WEBHOOK_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (response.ok) {
      logger.info('[Alerting] Slack alert sent');
      return { success: true };
    } else {
      const errorText = await response.text();
      logger.error('[Alerting] Failed to send Slack alert', {
        status: response.status,
        error: errorText,
      });
      return {
        success: false,
        reason: `HTTP ${response.status}: ${errorText}`,
      };
    }
  } catch (error) {
    logger.error('[Alerting] Failed to send Slack alert', {
      error: error.message,
    });
    return { success: false, reason: error.message };
  }
}

/**
 * Send PagerDuty alert
 *
 * @param {string} summary - Alert summary
 * @param {string} severity - Alert severity (critical, error, warning, info)
 * @param {Object} metadata - Additional metadata
 */
async function sendPagerDutyAlert(summary, severity = 'error', metadata = {}) {
  if (!PAGERDUTY_ENABLED || !PAGERDUTY_INTEGRATION_KEY) {
    return { success: false, reason: 'PagerDuty alerts not configured' };
  }

  try {
    const payload = {
      routing_key: PAGERDUTY_INTEGRATION_KEY,
      event_action: 'trigger',
      payload: {
        summary: summary,
        severity: severity,
        source: 'cloudtolocalllm-api',
        custom_details: metadata,
      },
    };

    const response = await fetch('https://events.pagerduty.com/v2/enqueue', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (response.ok) {
      const result = await response.json();
      logger.info('[Alerting] PagerDuty alert sent', {
        dedupKey: result.dedup_key,
      });
      return { success: true, dedupKey: result.dedup_key };
    } else {
      const errorText = await response.text();
      logger.error('[Alerting] Failed to send PagerDuty alert', {
        status: response.status,
        error: errorText,
      });
      return {
        success: false,
        reason: `HTTP ${response.status}: ${errorText}`,
      };
    }
  } catch (error) {
    logger.error('[Alerting] Failed to send PagerDuty alert', {
      error: error.message,
    });
    return { success: false, reason: error.message };
  }
}

/**
 * Send alert to all configured channels
 *
 * @param {string} alertType - Type of alert (e.g., 'database_health_check_failed', 'pool_exhaustion')
 * @param {string} title - Alert title
 * @param {string} message - Alert message
 * @param {Object} metadata - Additional metadata
 * @param {string} severity - Alert severity (for PagerDuty)
 */
export async function sendAlert(
  alertType,
  title,
  message,
  metadata = {},
  severity = 'error'
) {
  logger.warn(`[Alerting] Sending alert: ${alertType}`, { title, metadata });

  const results = {
    email: await sendEmailAlert(title, message, { alertType, ...metadata }),
    slack: await sendSlackAlert(title, message, { alertType, ...metadata }),
    pagerduty: await sendPagerDutyAlert(`${title}: ${message}`, severity, {
      alertType,
      ...metadata,
    }),
  };

  const successCount = Object.values(results).filter((r) => r.success).length;
  const totalCount = Object.values(results).filter(
    (r) => r.reason !== 'not configured'
  ).length;

  logger.info(
    `[Alerting] Alert sent to ${successCount}/${totalCount} channels`,
    {
      alertType,
      results,
    }
  );

  return results;
}

/**
 * Get alerting service status
 */
export function getAlertingStatus() {
  return {
    email: {
      enabled: EMAIL_ENABLED,
      configured: !!(EMAIL_TO && EMAIL_SMTP_USER && EMAIL_SMTP_PASS),
      recipient: EMAIL_TO,
    },
    slack: {
      enabled: SLACK_ENABLED,
      configured: !!SLACK_WEBHOOK_URL,
    },
    pagerduty: {
      enabled: PAGERDUTY_ENABLED,
      configured: !!PAGERDUTY_INTEGRATION_KEY,
    },
  };
}
