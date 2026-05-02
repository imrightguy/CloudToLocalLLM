const { eq } = require('drizzle-orm');
const logger = require('../utils/logger');
const {
  handleEmployeeReply, handleTenantReply, handleOccupantReply, sendMorningOfReminder, sendPostVisitSurvey,
  getVisitsNeeding24hReminder, getVisitsNeeding2hReminder,
  queueVisit24hReminder, queueVisit2hReminder,
  expireVisits,
  handleOptOutReply,
} = require('../services/sms.service');
const { handleIncomingMessage } = require('../services/twilio.service');
const { db } = require('../database/connection');
const { smsLogsTable } = require('../database/schema');

/**
 * POST /webhooks/sms/incoming
 * Receives incoming SMS from Twilio webhook.
 * Determines whether sender is an employee or tenant (lead) and routes accordingly.
 */
const handleIncoming = async (req, res) => {
  try {
    const { From, Body, MessageSid, NumMedia } = req.body;
    const normalizedBody = typeof Body === 'string' ? Body : '';
    const normalizedNumMedia = Number.parseInt(NumMedia, 10) || 0;

    if (!From) {
      logger.warn('⚠️  Incoming SMS webhook missing From');
      return res.status(400).send('Missing required fields');
    }

    logger.info(`📩 Incoming SMS from ${From}: "${normalizedBody}" (SID: ${MessageSid}, media=${normalizedNumMedia})`);

    // Check for opt-out keywords first (STOP, ARRET, etc.)
    const parsed = handleIncomingMessage(normalizedBody);
    if (parsed.action === 'stop') {
      logger.info(`🔇 Opt-out request from ${From}`);
      await handleOptOutReply(From);
      return res.status(200).type('text/xml').send('<Response></Response>');
    }

    // Try employee first, then tenant
    const employeeResult = await handleEmployeeReply(From, normalizedBody);

    if (employeeResult.success) {
      logger.info(`✅ Employee reply processed: action=${employeeResult.action}, visit=${employeeResult.visitId}`);
      return res.status(200).type('text/xml').send('<Response></Response>');
    }

    // If employee not found or no active visit, try tenant
    if (employeeResult.error === 'Employee not found' || employeeResult.error === 'No active visit found') {
      const tenantResult = await handleTenantReply(From, normalizedBody);
      if (tenantResult.success) {
        logger.info(`✅ Tenant reply processed: action=${tenantResult.action}, visit=${tenantResult.visitId}`);
        return res.status(200).type('text/xml').send('<Response></Response>');
      }

      // If tenant not found, try occupant (current tenant of occupied unit)
      if (tenantResult.error === 'Lead not found' || tenantResult.error === 'No active visit found') {
        const occupantResult = await handleOccupantReply(From, normalizedBody);
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

    const validActions = ['morning_reminder', 'post_survey', 'reminder_24h', 'reminder_2h', 'expire_confirmations'];
    if (!action || !validActions.includes(action)) {
      return res.status(400).json({
        success: false,
        error: { message: `Action must be one of: ${validActions.join(', ')}`, code: 'INVALID_ACTION' },
      });
    }

    const results = [];

    if (action === 'morning_reminder') {
      if (visitId) {
        const result = await sendMorningOfReminder(visitId);
        results.push({ visitId, ...result });
      } else {
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

    if (action === 'reminder_24h') {
      if (visitId) {
        const result = await queueVisit24hReminder(visitId);
        results.push({ visitId, ...result });
      } else {
        const visits = await getVisitsNeeding24hReminder();
        logger.info(`📍 24h reminder sweep: ${visits.length} visits`);

        for (const visit of visits) {
          const result = await queueVisit24hReminder(visit.id);
          results.push({ visitId: visit.id, ...result });
        }
      }
    }

    if (action === 'reminder_2h') {
      if (visitId) {
        const result = await queueVisit2hReminder(visitId);
        results.push({ visitId, ...result });
      } else {
        const visits = await getVisitsNeeding2hReminder();
        logger.info(`⏰ 2h reminder sweep: ${visits.length} visits`);

        for (const visit of visits) {
          const result = await queueVisit2hReminder(visit.id);
          results.push({ visitId: visit.id, ...result });
        }
      }
    }

    if (action === 'expire_confirmations') {
      const result = await expireVisits();
      return res.json({
        success: true,
        data: {
          action,
          ...result,
        },
      });
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
