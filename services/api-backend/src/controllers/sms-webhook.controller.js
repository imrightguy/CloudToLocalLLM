const { eq } = require('drizzle-orm');
const logger = require('../utils/logger');
const {
  handleEmployeeReply, handleTenantReply, handleOccupantReply, sendMorningOfReminder, sendPostVisitSurvey,
} = require('../services/sms.service');
const { db } = require('../database/connection');
const { smsLogsTable } = require('../database/schema');

/**
 * POST /webhooks/sms/incoming
 * Receives incoming SMS from Twilio webhook.
 * Determines whether sender is an employee or tenant (lead) and routes accordingly.
 */
const handleIncoming = async (req, res) => {
  try {
    const { From, Body, MessageSid } = req.body;

    if (!From || !Body) {
      logger.warn('⚠️  Incoming SMS webhook missing From or Body');
      return res.status(400).send('Missing required fields');
    }

    logger.info(`📩 Incoming SMS from ${From}: "${Body}" (SID: ${MessageSid})`);

    // Try employee first, then tenant
    const employeeResult = await handleEmployeeReply(From, Body);

    if (employeeResult.success) {
      logger.info(`✅ Employee reply processed: action=${employeeResult.action}, visit=${employeeResult.visitId}`);
      return res.status(200).type('text/xml').send('<Response></Response>');
    }

    // If employee not found or no active visit, try tenant
    if (employeeResult.error === 'Employee not found' || employeeResult.error === 'No active visit found') {
      const tenantResult = await handleTenantReply(From, Body);
      if (tenantResult.success) {
        logger.info(`✅ Tenant reply processed: action=${tenantResult.action}, visit=${tenantResult.visitId}`);
        return res.status(200).type('text/xml').send('<Response></Response>');
      }

      // If tenant not found, try occupant (current tenant of occupied unit)
      if (tenantResult.error === 'Lead not found' || tenantResult.error === 'No active visit found') {
        const occupantResult = await handleOccupantReply(From, Body);
        if (occupantResult.success) {
          logger.info(`✅ Occupant reply processed: action=${occupantResult.action}, visit=${occupantResult.visitId}`);
          return res.status(200).type('text/xml').send('<Response></Response>');
        }
      }
    }

    // Unrecognised sender/reply — still return 200 so Twilio doesn't retry
    logger.info(`ℹ️  Could not route incoming SMS from ${From}`);
    return res.status(200).type('text/xml').send('<Response></Response>');
  } catch (error) {
    logger.error('❌ handleIncoming webhook error:', error.message);
    // Always return 200 to Twilio to prevent retries on server errors
    return res.status(200).type('text/xml').send('<Response></Response>');
  }
};

/**
 * POST /webhooks/sms/status
 * Receives Twilio delivery status callbacks.
 * Updates the sms_logs table with the latest Twilio status.
 */
const handleStatus = async (req, res) => {
  try {
    const { MessageSid, SmsStatus, ErrorMessage } = req.body;

    if (!MessageSid) {
      return res.status(400).send('Missing MessageSid');
    }

    const statusMap = {
      queued: 'queued',
      sent: 'sent',
      delivered: 'delivered',
      undelivered: 'failed',
      failed: 'failed',
      read: 'read',
    };

    const mappedStatus = statusMap[SmsStatus] || SmsStatus || 'unknown';

    await db
      .update(smsLogsTable)
      .set({
        twilioStatus: SmsStatus || null,
        status: mappedStatus,
        errorMessage: ErrorMessage || null,
        updatedAt: new Date(),
      })
      .where(eq(smsLogsTable.twilioSid, MessageSid));

    logger.info(`📊 SMS status update: SID=${MessageSid} → ${SmsStatus}`);

    return res.status(200).send('OK');
  } catch (error) {
    logger.error('❌ handleStatus webhook error:', error.message);
    return res.status(200).send('OK');
  }
};

/**
 * POST /webhooks/sms/schedule (authenticated)
 * Internal endpoint to manually trigger scheduled SMS tasks.
 * Body can include: { action: 'morning_reminder' | 'post_survey', visitId?: string }
 * If no visitId, runs the full sweep (used by cron / manual trigger).
 */
const handleSchedule = async (req, res) => {
  try {
    const { action, visitId } = req.body;

    if (!action || !['morning_reminder', 'post_survey'].includes(action)) {
      return res.status(400).json({
        success: false,
        error: { message: 'Action must be "morning_reminder" or "post_survey"', code: 'INVALID_ACTION' },
      });
    }

    const results = [];

    if (action === 'morning_reminder') {
      if (visitId) {
        const result = await sendMorningOfReminder(visitId);
        results.push({ visitId, ...result });
      } else {
        // Full sweep
        const {
          getVisitsNeedingMorningReminder,
        } = require('../services/sms.service');
        const visits = await getVisitsNeedingMorningReminder();
        logger.info(`⏰ Morning reminder sweep: ${visits.length} visits`);

        for (const visit of visits) {
          const result = await sendMorningOfReminder(visit.id);
          results.push({ visitId: visit.id, ...result });
        }
      }
    }

    if (action === 'post_survey') {
      if (visitId) {
        const result = await sendPostVisitSurvey(visitId);
        results.push({ visitId, ...result });
      } else {
        // Full sweep
        const {
          getVisitsNeedingPostSurvey,
        } = require('../services/sms.service');
        const visits = await getVisitsNeedingPostSurvey();
        logger.info(`📝 Post-visit survey sweep: ${visits.length} visits`);

        for (const visit of visits) {
          const result = await sendPostVisitSurvey(visit.id);
          results.push({ visitId: visit.id, ...result });
        }
      }
    }

    return res.json({
      success: true,
      data: {
        action,
        processed: results.length,
        results,
      },
    });
  } catch (error) {
    logger.error('❌ handleSchedule error:', error.message);
    return res.status(500).json({
      success: false,
      error: { message: 'Failed to process scheduled SMS', code: 'SCHEDULE_FAILED' },
    });
  }
};

module.exports = {
  handleIncoming,
  handleStatus,
  handleSchedule,
};
