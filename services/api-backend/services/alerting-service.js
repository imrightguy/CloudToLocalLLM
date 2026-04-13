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

let _fetch = fetch;
let _nodemailer = nodemailer;

function _getConfig() {
  return {
    emailEnabled: process.env.ALERT_EMAIL_ENABLED === 'true',
    emailTo: process.env.ALERT_EMAIL_TO || '',
    emailFrom: process.env.ALERT_EMAIL_FROM || 'alerts@cloudtolocalllm.online',
    emailSmtpHost: process.env.ALERT_EMAIL_SMTP_HOST || 'smtp.gmail.com',
    emailSmtpPort: parseInt(process.env.ALERT_EMAIL_SMTP_PORT || '587', 10),
    emailSmtpUser: process.env.ALERT_EMAIL_SMTP_USER || '',
    emailSmtpPass: process.env.ALERT_EMAIL_SMTP_PASS || '',
    slackEnabled: process.env.ALERT_SLACK_ENABLED === 'true',
    slackWebhookUrl: process.env.ALERT_SLACK_WEBHOOK_URL || '',
    pagerdutyEnabled: process.env.ALERT_PAGERDUTY_ENABLED === 'true',
    pagerdutyKey: process.env.ALERT_PAGERDUTY_INTEGRATION_KEY || '',
  };
}

let emailTransporter = null;
let lastSmtpUser = null;
let lastSmtpPass = null;

function initializeEmailTransporter() {
  const cfg = _getConfig();
  if (!cfg.emailEnabled || !cfg.emailSmtpUser || !cfg.emailSmtpPass) {
    logger.warn('[Alerting] Email alerts disabled or not configured');
    return null;
  }

  if (
    emailTransporter &&
    cfg.emailSmtpUser === lastSmtpUser &&
    cfg.emailSmtpPass === lastSmtpPass
  ) {
    return emailTransporter;
  }

  try {
    emailTransporter = _nodemailer.createTransport({
      host: cfg.emailSmtpHost,
      port: cfg.emailSmtpPort,
      secure: cfg.emailSmtpPort === 465,
      auth: {
        user: cfg.emailSmtpUser,
        pass: cfg.emailSmtpPass,
      },
    });
    lastSmtpUser = cfg.emailSmtpUser;
    lastSmtpPass = cfg.emailSmtpPass;
    logger.info('[Alerting] Email transporter initialized');
    return emailTransporter;
  } catch (error) {
    logger.error('[Alerting] Failed to initialize email transporter', {
      error: error.message,
    });
    return null;
  }
}

async function sendEmailAlert(subject, message, metadata = {}) {
  const cfg = _getConfig();
  if (!cfg.emailEnabled || !cfg.emailTo) {
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
      from: cfg.emailFrom,
      to: cfg.emailTo,
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

async function sendSlackAlert(title, message, metadata = {}) {
  const cfg = _getConfig();
  if (!cfg.slackEnabled || !cfg.slackWebhookUrl) {
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

    const response = await _fetch(cfg.slackWebhookUrl, {
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

async function sendPagerDutyAlert(summary, severity = 'error', metadata = {}) {
  const cfg = _getConfig();
  if (!cfg.pagerdutyEnabled || !cfg.pagerdutyKey) {
    return { success: false, reason: 'PagerDuty alerts not configured' };
  }

  try {
    const payload = {
      routing_key: cfg.pagerdutyKey,
      event_action: 'trigger',
      payload: {
        summary: summary,
        severity: severity,
        source: 'cloudtolocalllm-api',
        custom_details: metadata,
      },
    };

    const response = await _fetch('https://events.pagerduty.com/v2/enqueue', {
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

export async function sendAlert(
  alertType,
  title,
  message,
  metadata = {},
  severity = 'error',
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
    (r) => r.reason !== 'not configured',
  ).length;

  logger.info(
    `[Alerting] Alert sent to ${successCount}/${totalCount} channels`,
    {
      alertType,
      results,
    },
  );

  return results;
}

export function getAlertingStatus() {
  const cfg = _getConfig();
  return {
    email: {
      enabled: cfg.emailEnabled,
      configured: !!(cfg.emailTo && cfg.emailSmtpUser && cfg.emailSmtpPass),
      recipient: cfg.emailTo,
    },
    slack: {
      enabled: cfg.slackEnabled,
      configured: !!cfg.slackWebhookUrl,
    },
    pagerduty: {
      enabled: cfg.pagerdutyEnabled,
      configured: !!cfg.pagerdutyKey,
    },
  };
}

export function _testSetFetch(mockFn) {
  _fetch = mockFn;
}

export function _testSetNodemailer(mockObj) {
  _nodemailer = mockObj;
}

export function _testReset() {
  _fetch = fetch;
  _nodemailer = nodemailer;
  emailTransporter = null;
  lastSmtpUser = null;
  lastSmtpPass = null;
}
