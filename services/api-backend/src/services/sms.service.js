const {
  eq, and, sql, lte, gte, ne,
} = require('drizzle-orm');
const logger = require('../utils/logger');
const { db } = require('../database/connection');
const {
  visitsTable,
  employeesTable,
  leadsTable,
  unitsTable,
  buildingsTable,
  smsLogsTable,
  usersTable,
  smsTemplatesTable,
  smsCampaignsTable,
  smsQueueTable,
  smsOptOutsTable,
  leasesTable,
} = require('../database/schema');
const { sendSMS, handleIncomingMessage } = require('./twilio.service');

// ─── Helpers ────────────────────────────────────────────────────────────────────

const formatDateTime = (dateTime) => {
  const d = new Date(dateTime);
  return d.toLocaleDateString('fr-CA', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
};

const logSMS = async (params) => {
  try {
    const {
      twilioSid, visitId, employeeId, leadId, phoneNumber, direction, messageBody, status, twilioStatus, errorMessage,
    } = params;
    await db.insert(smsLogsTable).values({
      twilioSid: twilioSid || null,
      visitId: visitId || null,
      employeeId: employeeId || null,
      leadId: leadId || null,
      phoneNumber,
      direction,
      messageBody: messageBody || null,
      status: status || 'queued',
      twilioStatus: twilioStatus || null,
      errorMessage: errorMessage || null,
    });
  } catch (error) {
    logger.error('❌ Failed to log SMS:', error.message);
  }
};

/**
 * Get full visit context (joins employee, lead, unit, building).
 */
const getVisitContext = async (visitId) => {
  const rows = await db
    .select({
      visit: visitsTable,
      employee: employeesTable,
      lead: leadsTable,
      unit: unitsTable,
      building: buildingsTable,
    })
    .from(visitsTable)
    .leftJoin(employeesTable, eq(visitsTable.employeeId, employeesTable.id))
    .leftJoin(leadsTable, eq(visitsTable.leadId, leadsTable.id))
    .leftJoin(unitsTable, eq(visitsTable.unitId, unitsTable.id))
    .leftJoin(buildingsTable, eq(unitsTable.buildingId, buildingsTable.id))
    .where(eq(visitsTable.id, visitId))
    .limit(1);

  return rows.length ? rows[0] : null;
};

// ─── Tenant message templates (FR / EN) ────────────────────────────────────────

const tenantMessages = {
  fr: {
    confirmationRequest: (dateTime, buildingName, confirmationToken) => {
      const baseUrl = process.env.PUBLIC_URL || process.env.PAPERCLIP_PUBLIC_URL || '';
      const confirmUrl = `${baseUrl}/api/confirm/${confirmationToken}`;
      return `Visite confirmée! ${formatDateTime(dateTime)} à ${buildingName}. Confirmez: ${confirmUrl} ou répondez 1=Oui, 2=Non`;
    },
  },
  en: {
    confirmationRequest: (dateTime, buildingName, confirmationToken) => {
      const baseUrl = process.env.PUBLIC_URL || process.env.PAPERCLIP_PUBLIC_URL || '';
      const confirmUrl = `${baseUrl}/api/confirm/${confirmationToken}`;
      return `Visit confirmed! ${new Date(dateTime).toLocaleDateString('en-CA', {
        weekday: 'long', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit',
      })} at ${buildingName}. Confirm: ${confirmUrl} or reply 1=Yes, 2=No`;
    },
  },
};

// ─── Occupant (current tenant) message templates ───────────────────────────────

const occupantMessages = {
  fr: {
    accessRequest: (dateTime, buildingName, unitLabel) => `🔑 Bonjour! Une visite pour l'appartement ${unitLabel} à ${buildingName} est prévue le ${formatDateTime(dateTime)}. Autorisez-vous l'accès? 1=Oui, 2=Non`,
    accessConfirmed: (dateTime, buildingName, unitLabel) => `✅ Merci! Accès confirmé pour la visite du ${formatDateTime(dateTime)} à ${buildingName} ${unitLabel}.`,
    accessDenied: () => '❌ D\'accord, merci de nous avoir informé. Nous allons annuler ou replanifier la visite.',
  },
  en: {
    accessRequest: (dateTime, buildingName, unitLabel) => `🔑 Hi! A visit for apartment ${unitLabel} at ${buildingName} is scheduled for ${formatDateTime(dateTime)}. Do you allow access? 1=Yes, 2=No`,
    accessConfirmed: (dateTime, buildingName, unitLabel) => `✅ Thanks! Access confirmed for the visit on ${formatDateTime(dateTime)} at ${buildingName} ${unitLabel}.`,
    accessDenied: () => '❌ OK, thanks for letting us know. We\'ll cancel or reschedule the visit.',
  },
};

// ─── Business Functions ────────────────────────────────────────────────────────

/**
 * Send visit confirmation SMS to the employee.
 */
const sendVisitConfirmation = async (visitId) => {
  try {
    const ctx = await getVisitContext(visitId);
    if (!ctx) {
      logger.error(`❌ sendVisitConfirmation: visit ${visitId} not found`);
      return { success: false, error: 'Visit not found' };
    }

    const {
      visit, employee, lead, unit, building,
    } = ctx;
    if (!employee || !lead || !building) {
      return { success: false, error: 'Missing related data for visit confirmation' };
    }

    const message = `📍 Visite planifiée: ${formatDateTime(visit.dateTime)} à ${building.name} ${unit ? unit.label : ''} avec ${lead.fullName}. Confirmez: 1=Oui, 2=Non`;

    const result = await sendSMS(employee.phone, message);

    await logSMS({
      twilioSid: result.sid || null,
      visitId,
      employeeId: employee.id,
      leadId: lead.id,
      phoneNumber: employee.phone,
      direction: 'outbound',
      messageBody: message,
      status: result.success ? 'sent' : 'failed',
      twilioStatus: result.status || null,
      errorMessage: result.error || null,
    });

    return result;
  } catch (error) {
    logger.error('❌ sendVisitConfirmation error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Send visit confirmation request SMS to the tenant (lead).
 * Checks lead.language for FR/EN.
 */
const sendTenantConfirmationRequest = async (visitId) => {
  try {
    const ctx = await getVisitContext(visitId);
    if (!ctx) {
      logger.error(`❌ sendTenantConfirmationRequest: visit ${visitId} not found`);
      return { success: false, error: 'Visit not found' };
    }

    const { visit, lead, building } = ctx;
    if (!lead || !building || !lead.phone) {
      return { success: false, error: 'Missing lead phone or building for tenant confirmation' };
    }

    const lang = (lead.language === 'en') ? 'en' : 'fr';
    const message = tenantMessages[lang].confirmationRequest(
      visit.dateTime,
      building.name,
      visit.confirmationToken,
    );

    const result = await sendSMS(lead.phone, message);

    await logSMS({
      twilioSid: result.sid || null,
      visitId,
      leadId: lead.id,
      phoneNumber: lead.phone,
      direction: 'outbound',
      messageBody: message,
      status: result.success ? 'sent' : 'failed',
      twilioStatus: result.status || null,
      errorMessage: result.error || null,
    });

    return result;
  } catch (error) {
    logger.error('❌ sendTenantConfirmationRequest error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Send access request SMS to the current occupant of a unit.
 * Triggered when a visit is created for an occupied unit.
 * Returns { success, needsNotice } where needsNotice = true if < 24h before visit.
 */
const sendOccupantAccessRequest = async (visitId, lang = 'fr') => {
  try {
    const ctx = await getVisitContext(visitId);
    if (!ctx) {
      logger.error(`❌ sendOccupantAccessRequest: visit ${visitId} not found`);
      return { success: false, error: 'Visit not found' };
    }

    const { visit, unit, building } = ctx;
    if (!unit || !building) {
      return { success: false, error: 'Missing unit or building data' };
    }

    // Check if unit has an occupant with a phone
    if (!unit.tenantPhone) {
      return { success: false, error: 'No occupant phone on unit — cannot request access' };
    }

    // Check if occupant's lease is still active (or no lease end = assume active)
    const occupantActive = !unit.tenantLeaseEnd || new Date(unit.tenantLeaseEnd) > new Date();
    if (!occupantActive) {
      return { success: false, error: 'Occupant lease has ended — unit should be vacant' };
    }

    // Check 24h notice requirement
    const now = new Date();
    const visitTime = new Date(visit.dateTime);
    const hoursUntilVisit = (visitTime - now) / (1000 * 60 * 60);
    const needsNotice = hoursUntilVisit < 24;

    const language = lang === 'en' ? 'en' : 'fr';
    const message = occupantMessages[language].accessRequest(
      visit.dateTime,
      building.name,
      unit.label,
    );

    const result = await sendSMS(unit.tenantPhone, message);

    // Log with occupant phone (not lead)
    await logSMS({
      twilioSid: result.sid || null,
      visitId,
      phoneNumber: unit.tenantPhone,
      direction: 'outbound',
      messageBody: message,
      status: result.success ? 'sent' : 'failed',
      twilioStatus: result.status || null,
      errorMessage: result.error || null,
    });

    // Mark occupantNotified on the visit
    if (result.success) {
      await db
        .update(visitsTable)
        .set({ occupantNotified: true, updatedAt: new Date() })
        .where(eq(visitsTable.id, visitId));
    }

    return { success: result.success, needsNotice, ...result };
  } catch (error) {
    logger.error('❌ sendOccupantAccessRequest error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Handle an occupant's SMS reply to access request.
 * Matches by unit tenantPhone (not lead phone).
 */
const handleOccupantReply = async (occupantPhone, reply) => {
  try {
    const parsed = handleIncomingMessage(reply);
    if (!parsed.action) {
      logger.info(`ℹ️  Unrecognised occupant reply from ${occupantPhone}: "${reply}"`);
      await logSMS({
        phoneNumber: occupantPhone,
        direction: 'inbound',
        messageBody: reply,
        status: 'received',
      });
      return { success: false, error: 'Unrecognised reply' };
    }

    // Find unit by tenant phone
    const cleanedPhone = occupantPhone.replace(/[\s\-()+]/g, '');

    let units = await db
      .select()
      .from(unitsTable)
      .where(eq(unitsTable.tenantPhone, cleanedPhone))
      .limit(1);

    if (!units.length) {
      // Try with +1 prefix
      const altPhone = cleanedPhone.startsWith('1') ? `+${cleanedPhone}` : `+1${cleanedPhone}`;
      units = await db
        .select()
        .from(unitsTable)
        .where(eq(unitsTable.tenantPhone, altPhone))
        .limit(1);
    }

    if (!units.length) {
      logger.warn(`⚠️  No unit found for occupant phone ${occupantPhone}`);
      await logSMS({
        phoneNumber: occupantPhone,
        direction: 'inbound',
        messageBody: reply,
        status: 'received',
        errorMessage: 'No unit found for occupant phone',
      });
      return { success: false, error: 'No unit found for occupant phone' };
    }

    const unit = units[0];

    // Find the most recent active visit for this unit
    const visits = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.unitId, unit.id),
        eq(visitsTable.isActive, true),
        eq(visitsTable.occupantNotified, true),
      ))
      .orderBy(sql`${visitsTable.dateTime} desc`)
      .limit(1);

    if (!visits.length) {
      logger.warn(`⚠️  No active visit needing occupant confirmation for unit ${unit.id}`);
      await logSMS({
        phoneNumber: occupantPhone,
        direction: 'inbound',
        messageBody: reply,
        status: 'received',
        errorMessage: 'No pending visit for this unit',
      });
      return { success: false, error: 'No pending visit found' };
    }

    const visit = visits[0];

    // Log inbound
    await logSMS({
      visitId: visit.id,
      employeeId: visit.employeeId,
      leadId: visit.leadId,
      phoneNumber: occupantPhone,
      direction: 'inbound',
      messageBody: reply,
      status: 'received',
    });

    const accessGranted = parsed.action === 'yes';

    // Update visit
    await db
      .update(visitsTable)
      .set({ tenantConfirmed: accessGranted, updatedAt: new Date() })
      .where(eq(visitsTable.id, visit.id));

    // Send acknowledgment to occupant
    if (accessGranted) {
      // Get building name for acknowledgment
      const buildings = await db
        .select()
        .from(buildingsTable)
        .where(eq(buildingsTable.id, unit.buildingId))
        .limit(1);
      const building = buildings[0];
      const ackMessage = occupantMessages.fr.accessConfirmed(
        visit.dateTime,
        building ? building.name : '',
        unit.label,
      );
      await sendSMS(occupantPhone, ackMessage);
      await logSMS({
        visitId: visit.id,
        phoneNumber: occupantPhone,
        direction: 'outbound',
        messageBody: ackMessage,
        status: 'sent',
      });
    } else {
      const ackMessage = occupantMessages.fr.accessDenied();
      await sendSMS(occupantPhone, ackMessage);
      await logSMS({
        visitId: visit.id,
        phoneNumber: occupantPhone,
        direction: 'outbound',
        messageBody: ackMessage,
        status: 'sent',
      });
    }

    return {
      success: true,
      action: accessGranted ? 'occupant_access_granted' : 'occupant_access_denied',
      visitId: visit.id,
    };
  } catch (error) {
    logger.error('❌ handleOccupantReply error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Send morning-of reminder to the employee.
 * - If tenant confirmed → positive reminder
 * - If tenant NOT confirmed → warning + call prompt
 */
const sendMorningOfReminder = async (visitId) => {
  try {
    const ctx = await getVisitContext(visitId);
    if (!ctx) {
      logger.error(`❌ sendMorningOfReminder: visit ${visitId} not found`);
      return { success: false, error: 'Visit not found' };
    }

    const {
      visit, employee, lead, unit, building,
    } = ctx;
    if (!employee || !building) {
      return { success: false, error: 'Missing employee or building for morning reminder' };
    }

    let message;
    if (visit.tenantConfirmed) {
      message = `✅ Rappel: Visite confirmée ${formatDateTime(visit.dateTime)} à ${building.name} ${unit ? unit.label : ''} avec ${lead ? lead.fullName : 'locataire'}. Bonne visite!`;
    } else {
      message = `⚠️ Le locataire n'a pas confirmé la visite de ${formatDateTime(visit.dateTime)} à ${building.name} ${unit ? unit.label : ''}. Appelez? 1=Oui, 2=Pas nécessaire`;
    }

    const result = await sendSMS(employee.phone, message);

    // Mark morningOfSent on the visit
    await db
      .update(visitsTable)
      .set({ morningOfSent: true, updatedAt: new Date() })
      .where(eq(visitsTable.id, visitId));

    await logSMS({
      twilioSid: result.sid || null,
      visitId,
      employeeId: employee.id,
      leadId: lead ? lead.id : null,
      phoneNumber: employee.phone,
      direction: 'outbound',
      messageBody: message,
      status: result.success ? 'sent' : 'failed',
      twilioStatus: result.status || null,
      errorMessage: result.error || null,
    });

    return result;
  } catch (error) {
    logger.error('❌ sendMorningOfReminder error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Send post-visit survey SMS to the employee.
 */
const sendPostVisitSurvey = async (visitId) => {
  try {
    const ctx = await getVisitContext(visitId);
    if (!ctx) {
      logger.error(`❌ sendPostVisitSurvey: visit ${visitId} not found`);
      return { success: false, error: 'Visit not found' };
    }

    const {
      employee, lead, building,
    } = ctx;
    if (!employee || !lead) {
      return { success: false, error: 'Missing employee or lead for post-visit survey' };
    }

    const message = `Comment s'est passée la visite avec ${lead.fullName} à ${building ? building.name : ''}? 1=Intéressé, 2=Pas intéressé, 3=Ne s'est pas présenté`;

    const result = await sendSMS(employee.phone, message);

    await logSMS({
      twilioSid: result.sid || null,
      visitId,
      employeeId: employee.id,
      leadId: lead.id,
      phoneNumber: employee.phone,
      direction: 'outbound',
      messageBody: message,
      status: result.success ? 'sent' : 'failed',
      twilioStatus: result.status || null,
      errorMessage: result.error || null,
    });

    return result;
  } catch (error) {
    logger.error('❌ sendPostVisitSurvey error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Notify Simon (or first admin) that a lead is interested.
 */
const sendLeadArrivalNotification = async (visitId) => {
  try {
    const ctx = await getVisitContext(visitId);
    if (!ctx) {
      logger.error(`sendLeadArrivalNotification: visit ${visitId} not found`);
      return { success: false, error: 'Visit not found' };
    }

    const { lead, building } = ctx;
    if (!lead || !lead.phone) {
      return { success: false, error: 'Missing lead data for arrival notification' };
    }

    const message = `Votre visiteur est arrivé! ${building ? building.name : ''}. Bienvenue!`;

    const result = await sendSMS(lead.phone, message);

    await logSMS({
      twilioSid: result.sid || null,
      visitId,
      leadId: lead.id,
      phoneNumber: lead.phone,
      direction: 'outbound',
      messageBody: message,
      status: result.success ? 'sent' : 'failed',
      twilioStatus: result.status || null,
      errorMessage: result.error || null,
    });

    return result;
  } catch (error) {
    logger.error('sendLeadArrivalNotification error:', error.message);
    return { success: false, error: error.message };
  }
};

const sendLeadFeedbackRequest = async (visitId) => {
  try {
    const ctx = await getVisitContext(visitId);
    if (!ctx) {
      logger.error(`sendLeadFeedbackRequest: visit ${visitId} not found`);
      return { success: false, error: 'Visit not found' };
    }

    const { lead } = ctx;
    if (!lead || !lead.phone) {
      return { success: false, error: 'Missing lead data for feedback request' };
    }

    const message = `Comment s'est passée votre visite? Répondez 1=Satisfait, 2=Insatisfait`;

    const result = await sendSMS(lead.phone, message);

    await logSMS({
      twilioSid: result.sid || null,
      visitId,
      leadId: lead.id,
      phoneNumber: lead.phone,
      direction: 'outbound',
      messageBody: message,
      status: result.success ? 'sent' : 'failed',
      twilioStatus: result.status || null,
      errorMessage: result.error || null,
    });

    return result;
  } catch (error) {
    logger.error('sendLeadFeedbackRequest error:', error.message);
    return { success: false, error: error.message };
  }
};

const notifySimonInterested = async (visitId) => {
  try {
    const ctx = await getVisitContext(visitId);
    if (!ctx) {
      logger.error(`❌ notifySimonInterested: visit ${visitId} not found`);
      return { success: false, error: 'Visit not found' };
    }

    const {
      visit, lead, unit, building,
    } = ctx;
    if (!lead) {
      return { success: false, error: 'Missing lead data' };
    }

    // Determine Simon's phone number
    let simonPhone = process.env.SIMON_PHONE || null;
    if (!simonPhone) {
      // Fallback: first admin user with a phone
      const admins = await db
        .select()
        .from(usersTable)
        .where(eq(usersTable.role, 'admin'))
        .limit(1);
      if (admins.length && admins[0].phone) {
        simonPhone = admins[0].phone;
      }
    }

    if (!simonPhone) {
      logger.warn('⚠️  No SIMON_PHONE env var and no admin with phone found — skipping notification');
      return { success: false, error: 'No recipient phone configured' };
    }

    const message = `🔥 Intéressé! ${lead.fullName} - ${lead.phone || 'N/A'} a visité ${building ? building.name : ''} ${unit ? unit.label : ''} le ${formatDateTime(visit.dateTime)}. Appelez!`;

    const result = await sendSMS(simonPhone, message);

    await logSMS({
      twilioSid: result.sid || null,
      visitId,
      leadId: lead.id,
      phoneNumber: simonPhone,
      direction: 'outbound',
      messageBody: message,
      status: result.success ? 'sent' : 'failed',
      twilioStatus: result.status || null,
      errorMessage: result.error || null,
    });

    return result;
  } catch (error) {
    logger.error('❌ notifySimonInterested error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Handle an employee's SMS reply.
 * Finds the most recent active visit for that employee and updates based on reply.
 */
const handleEmployeeReply = async (employeePhone, reply) => {
  try {
    const parsed = handleIncomingMessage(reply);
    if (!parsed.action) {
      logger.info(`ℹ️  Unrecognised employee reply from ${employeePhone}: "${reply}"`);
      // Log the inbound message anyway
      await logSMS({
        phoneNumber: employeePhone,
        direction: 'inbound',
        messageBody: reply,
        status: 'received',
      });
      return { success: false, error: 'Unrecognised reply' };
    }

    // Clean phone for matching
    const cleanedPhone = employeePhone.replace(/[\s\-()+]/g, '');

    // Find employee
    const employees = await db
      .select()
      .from(employeesTable)
      .where(eq(employeesTable.phone, cleanedPhone))
      .limit(1);

    let employee;
    if (employees.length) {
      [employee] = employees;
    } else {
      const altPhone = cleanedPhone.startsWith('1') ? `+${cleanedPhone}` : `+1${cleanedPhone}`;
      const altEmployees = await db
        .select()
        .from(employeesTable)
        .where(eq(employeesTable.phone, altPhone))
        .limit(1);

      if (!altEmployees.length) {
        logger.warn(`⚠️  No employee found for phone ${employeePhone}`);
        await logSMS({
          phoneNumber: employeePhone,
          direction: 'inbound',
          messageBody: reply,
          status: 'received',
          errorMessage: 'Employee not found',
        });
        return { success: false, error: 'Employee not found' };
      }
      [employee] = altEmployees;
    }

    // Find the most recent active visit for this employee
    const visits = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.employeeId, employee.id),
        eq(visitsTable.isActive, true),
      ))
      .orderBy(sql`${visitsTable.dateTime} desc`)
      .limit(1);

    if (!visits.length) {
      logger.warn(`⚠️  No active visit for employee ${employee.id}`);
      await logSMS({
        employeeId: employee.id,
        phoneNumber: employeePhone,
        direction: 'inbound',
        messageBody: reply,
        status: 'received',
        errorMessage: 'No active visit found',
      });
      return { success: false, error: 'No active visit found' };
    }

    const visit = visits[0];

    // Log inbound
    await logSMS({
      visitId: visit.id,
      employeeId: employee.id,
      leadId: visit.leadId,
      phoneNumber: employeePhone,
      direction: 'inbound',
      messageBody: reply,
      status: 'received',
    });

    // Route based on visit status and reply action
    switch (parsed.action) {
      case 'yes':
        if (visit.status === 'scheduled') {
          // Employee confirmed visit → mark confirmed, send tenant confirmation
          await db
            .update(visitsTable)
            .set({ status: 'confirmed', employeeConfirmed: true, updatedAt: new Date() })
            .where(eq(visitsTable.id, visit.id));

          // Trigger tenant confirmation request
          await sendTenantConfirmationRequest(visit.id);
          return { success: true, action: 'visit_confirmed', visitId: visit.id };
        }
        if (visit.status === 'confirmed' && visit.morningOfSent && !visit.tenantConfirmed) {
          // Employee said "yes" to calling the tenant
          // No further automated action — employee will call manually
          return { success: true, action: 'employee_will_call', visitId: visit.id };
        }
        break;

      case 'no':
        if (visit.status === 'scheduled') {
          // Employee declined visit → cancel
          await db
            .update(visitsTable)
            .set({ status: 'cancelled', updatedAt: new Date() })
            .where(eq(visitsTable.id, visit.id));
          return { success: true, action: 'visit_cancelled', visitId: visit.id };
        }
        if (visit.status === 'confirmed' && visit.morningOfSent && !visit.tenantConfirmed) {
          // Employee said "not necessary" to call
          return { success: true, action: 'employee_no_call_needed', visitId: visit.id };
        }
        break;

      case 'interested':
        // Post-visit: lead is interested → notify Simon
        await db
          .update(visitsTable)
          .set({
            status: 'completed',
            outcome: 'interesse',
            updatedAt: new Date(),
          })
          .where(eq(visitsTable.id, visit.id));

        // Update lead stage
        if (visit.leadId) {
          await db
            .update(leadsTable)
            .set({ stage: 'interesse', updatedAt: new Date() })
            .where(eq(leadsTable.id, visit.leadId));
        }

        await notifySimonInterested(visit.id);
        return { success: true, action: 'lead_interested', visitId: visit.id };

      case 'no_interest':
        await db
          .update(visitsTable)
          .set({
            status: 'completed',
            outcome: 'pas_interesse',
            updatedAt: new Date(),
          })
          .where(eq(visitsTable.id, visit.id));

        if (visit.leadId) {
          await db
            .update(leadsTable)
            .set({ stage: 'visite_completee', updatedAt: new Date() })
            .where(eq(leadsTable.id, visit.leadId));
        }

        return { success: true, action: 'lead_not_interested', visitId: visit.id };

      case 'no_show':
        await db
          .update(visitsTable)
          .set({
            status: 'no_show',
            outcome: 'no_show',
            updatedAt: new Date(),
          })
          .where(eq(visitsTable.id, visit.id));

        if (visit.leadId) {
          await db
            .update(leadsTable)
            .set({ stage: 'inactif', updatedAt: new Date() })
            .where(eq(leadsTable.id, visit.leadId));
        }

        return { success: true, action: 'lead_no_show', visitId: visit.id };

      case 'arrive':
        if (visit.status === 'confirmed') {
          await db
            .update(visitsTable)
            .set({ status: 'in_progress', updatedAt: new Date() })
            .where(eq(visitsTable.id, visit.id));

          await sendLeadArrivalNotification(visit.id);
          return { success: true, action: 'employee_arrived', visitId: visit.id };
        }
        return { success: false, action: 'arrive_invalid_state', visitId: visit.id };

      case 'termine':
        if (visit.status === 'in_progress' || visit.status === 'confirmed') {
          await db
            .update(visitsTable)
            .set({ status: 'completed', updatedAt: new Date() })
            .where(eq(visitsTable.id, visit.id));

          await sendLeadFeedbackRequest(visit.id);
          await sendPostVisitSurvey(visit.id);
          return { success: true, action: 'visit_completed', visitId: visit.id };
        }
        return { success: false, action: 'termine_invalid_state', visitId: visit.id };

      default:
        return { success: false, action: 'unrecognised', visitId: visit.id };
    }

    return { success: true, action: parsed.action, visitId: visit.id };
  } catch (error) {
    logger.error('❌ handleEmployeeReply error:', error.message);
    return { success: false, error: error.message };
  }
};

/**
 * Handle a tenant's (lead's) SMS reply — confirmation of attendance.
 */
const handleTenantReply = async (leadPhone, reply) => {
  try {
    const parsed = handleIncomingMessage(reply);
    if (!parsed.action) {
      logger.info(`ℹ️  Unrecognised tenant reply from ${leadPhone}: "${reply}"`);
      await logSMS({
        phoneNumber: leadPhone,
        direction: 'inbound',
        messageBody: reply,
        status: 'received',
      });
      return { success: false, error: 'Unrecognised reply' };
    }

    const cleanedPhone = leadPhone.replace(/[\s\-()+]/g, '');

    // Find lead by phone
    let leads = await db
      .select()
      .from(leadsTable)
      .where(eq(leadsTable.phone, cleanedPhone))
      .limit(1);

    if (!leads.length) {
      // Try with +1 prefix
      const altPhone = cleanedPhone.startsWith('1') ? `+${cleanedPhone}` : `+1${cleanedPhone}`;
      leads = await db
        .select()
        .from(leadsTable)
        .where(eq(leadsTable.phone, altPhone))
        .limit(1);
    }

    if (!leads.length) {
      logger.warn(`⚠️  No lead found for phone ${leadPhone}`);
      await logSMS({
        phoneNumber: leadPhone,
        direction: 'inbound',
        messageBody: reply,
        status: 'received',
        errorMessage: 'Lead not found',
      });
      return { success: false, error: 'Lead not found' };
    }

    const lead = leads[0];

    // Find the most recent active visit for this lead
    const visits = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.leadId, lead.id),
        eq(visitsTable.isActive, true),
      ))
      .orderBy(sql`${visitsTable.dateTime} desc`)
      .limit(1);

    if (!visits.length) {
      logger.warn(`⚠️  No active visit for lead ${lead.id}`);
      await logSMS({
        leadId: lead.id,
        phoneNumber: leadPhone,
        direction: 'inbound',
        messageBody: reply,
        status: 'received',
        errorMessage: 'No active visit found',
      });
      return { success: false, error: 'No active visit found' };
    }

    const visit = visits[0];

    // Log inbound
    await logSMS({
      visitId: visit.id,
      employeeId: visit.employeeId,
      leadId: lead.id,
      phoneNumber: leadPhone,
      direction: 'inbound',
      messageBody: reply,
      status: 'received',
    });

    const tenantConfirmed = parsed.action === 'yes';

    await db
      .update(visitsTable)
      .set({ tenantConfirmed, updatedAt: new Date() })
      .where(eq(visitsTable.id, visit.id));

    return {
      success: true,
      action: tenantConfirmed ? 'tenant_confirmed' : 'tenant_declined',
      visitId: visit.id,
    };
  } catch (error) {
    logger.error('❌ handleTenantReply error:', error.message);
    return { success: false, error: error.message };
  }
};

// ─── Scheduler helpers (called by scheduler.service.js) ────────────────────────

/**
 * Find all visits happening tomorrow that still need morning-of reminders.
 */
const getVisitsNeedingMorningReminder = async () => {
  try {
    // Tomorrow 00:00 → tomorrow 23:59:59
    const now = new Date();
    const tomorrowStart = new Date(now);
    tomorrowStart.setDate(tomorrowStart.getDate() + 1);
    tomorrowStart.setHours(0, 0, 0, 0);

    const tomorrowEnd = new Date(tomorrowStart);
    tomorrowEnd.setHours(23, 59, 59, 999);

    const visits = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.isActive, true),
        eq(visitsTable.status, 'confirmed'),
        eq(visitsTable.morningOfSent, false),
        gte(visitsTable.dateTime, tomorrowStart),
        lte(visitsTable.dateTime, tomorrowEnd),
      ));

    return visits;
  } catch (error) {
    logger.error('❌ getVisitsNeedingMorningReminder error:', error.message);
    return [];
  }
};

/**
 * Find completed visits from ~2 hours ago that need post-visit surveys.
 */
const getVisitsNeedingPostSurvey = async () => {
  try {
    const now = new Date();
    const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);
    const threeHoursAgo = new Date(now.getTime() - 3 * 60 * 60 * 1000);

    const visits = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.isActive, true),
        eq(visitsTable.status, 'confirmed'),
        sql`${visitsTable.dateTime} < ${twoHoursAgo}`,
        sql`${visitsTable.dateTime} >= ${threeHoursAgo}`,
        sql`${visitsTable.outcome} IS NULL`,
      ));

    return visits;
  } catch (error) {
    logger.error('❌ getVisitsNeedingPostSurvey error:', error.message);
    return [];
  }
};

// ─── Template Rendering ───────────────────────────────────────────────────────

const renderTemplate = (templateBody, variables) => {
  let rendered = templateBody;
  for (const [key, value] of Object.entries(variables || {})) {
    rendered = rendered.replace(new RegExp(`\\{\\{${key}\\}\\}`, 'g'), value || '');
  }
  return rendered;
};

const extractVariables = (templateBody) => {
  const matches = templateBody.match(/\{\{(\w+)\}\}/g) || [];
  return [...new Set(matches.map((m) => m.replace(/\{\{|\}\}/g, '')))];
};

// ─── Opt-out Handling ──────────────────────────────────────────────────────────

const addToOptOut = async (phoneNumber, reason = 'stop') => {
  try {
    const cleanedPhone = phoneNumber.replace(/[\s\-()+]/g, '');
    const existing = await db
      .select()
      .from(smsOptOutsTable)
      .where(and(
        eq(smsOptOutsTable.phoneNumber, cleanedPhone),
        eq(smsOptOutsTable.isActive, true),
      ))
      .limit(1);

    if (existing.length) {
      return { success: true, alreadyOptedOut: true };
    }

    await db.insert(smsOptOutsTable).values({
      phoneNumber: cleanedPhone,
      reason,
    });

    logger.info(`🔇 Phone ${cleanedPhone} opted out (reason: ${reason})`);
    return { success: true, alreadyOptedOut: false };
  } catch (error) {
    logger.error('addToOptOut error:', error.message);
    return { success: false, error: error.message };
  }
};

const isOptedOut = async (phoneNumber) => {
  try {
    const cleanedPhone = phoneNumber.replace(/[\s\-()+]/g, '');
    const results = await db
      .select()
      .from(smsOptOutsTable)
      .where(and(
        eq(smsOptOutsTable.phoneNumber, cleanedPhone),
        eq(smsOptOutsTable.isActive, true),
      ))
      .limit(1);

    return results.length > 0;
  } catch (error) {
    logger.error('isOptedOut error:', error.message);
    return false;
  }
};

const handleOptOutReply = async (phoneNumber) => {
  await addToOptOut(phoneNumber, 'stop');
  await sendSMS(phoneNumber, 'Vous avez ete desabonne. Vous ne recevrez plus de SMS. Repondez START pour vous reinscrire.');
  await logSMS({
    phoneNumber,
    direction: 'outbound',
    messageBody: 'Vous avez ete desabonne. Vous ne recevrez plus de SMS. Repondez START pour vous reinscrire.',
    status: 'sent',
  });
  return { success: true, action: 'opted_out' };
};

// ─── Template Validation ───────────────────────────────────────────────────────

const validateTemplateRender = (renderedBody) => {
  const unreplaced = renderedBody.match(/\{\{(\w+)\}\}/g);
  if (unreplaced && unreplaced.length > 0) {
    return {
      valid: false,
      unreplacedVariables: unreplaced.map((m) => m.replace(/\{\{|\}\}/g, '')),
    };
  }
  return { valid: true, unreplacedVariables: [] };
};

// ─── Business Hours ────────────────────────────────────────────────────────────

const QUEBEC_TIMEZONE_OFFSET = -5;

const isWithinBusinessHours = (date = new Date()) => {
  const utc = date.getTime() + date.getTimezoneOffset() * 60000;
  const quebecTime = new Date(utc + QUEBEC_TIMEZONE_OFFSET * 3600000);
  const hour = quebecTime.getHours();
  const day = quebecTime.getDay();
  if (day === 0) return false;
  if (day === 6 && hour >= 13) return false;
  return hour >= 8 && hour < 21;
};

const getNextBusinessHour = (date = new Date()) => {
  const d = new Date(date);
  const utc = d.getTime() + d.getTimezoneOffset() * 60000;
  const quebecTime = new Date(utc + QUEBEC_TIMEZONE_OFFSET * 3600000);
  const hour = quebecTime.getHours();
  const day = quebecTime.getDay();

  if (day === 0) {
    quebecTime.setDate(quebecTime.getDate() + 1);
    quebecTime.setHours(8, 0, 0, 0);
    return new Date(quebecTime.getTime() - QUEBEC_TIMEZONE_OFFSET * 3600000 - d.getTimezoneOffset() * 60000);
  }

  if (day === 6 && hour >= 13) {
    quebecTime.setDate(quebecTime.getDate() + 2);
    quebecTime.setHours(8, 0, 0, 0);
    return new Date(quebecTime.getTime() - QUEBEC_TIMEZONE_OFFSET * 3600000 - d.getTimezoneOffset() * 60000);
  }

  if (hour >= 21) {
    quebecTime.setDate(quebecTime.getDate() + 1);
    if (quebecTime.getDay() === 0) quebecTime.setDate(quebecTime.getDate() + 1);
    quebecTime.setHours(8, 0, 0, 0);
    return new Date(quebecTime.getTime() - QUEBEC_TIMEZONE_OFFSET * 3600000 - d.getTimezoneOffset() * 60000);
  }

  if (hour < 8) {
    quebecTime.setHours(8, 0, 0, 0);
    return new Date(quebecTime.getTime() - QUEBEC_TIMEZONE_OFFSET * 3600000 - d.getTimezoneOffset() * 60000);
  }

  if (day === 6 && hour >= 8) {
    quebecTime.setHours(13, 0, 0, 0);
    return new Date(quebecTime.getTime() - QUEBEC_TIMEZONE_OFFSET * 3600000 - d.getTimezoneOffset() * 60000);
  }

  return d;
};

// ─── Template CRUD ────────────────────────────────────────────────────────────

const createTemplate = async (data) => {
  const variables = extractVariables(data.body);
  const [template] = await db
    .insert(smsTemplatesTable)
    .values({
      name: data.name,
      body: data.body,
      language: data.language || 'fr',
      category: data.category,
      description: data.description || null,
      variables,
    })
    .returning();
  return template;
};

const getTemplates = async (filters = {}) => {
  const conditions = [eq(smsTemplatesTable.isActive, true)];
  if (filters.category) conditions.push(eq(smsTemplatesTable.category, filters.category));
  if (filters.language) conditions.push(eq(smsTemplatesTable.language, filters.language));

  const templates = await db
    .select()
    .from(smsTemplatesTable)
    .where(and(...conditions))
    .orderBy(sql`${smsTemplatesTable.createdAt} desc`);
  return templates;
};

const getTemplateById = async (id) => {
  const [template] = await db
    .select()
    .from(smsTemplatesTable)
    .where(eq(smsTemplatesTable.id, id))
    .limit(1);
  return template || null;
};

const updateTemplate = async (id, data) => {
  const updateData = { updatedAt: new Date() };
  if (data.name !== undefined) updateData.name = data.name;
  if (data.body !== undefined) {
    updateData.body = data.body;
    updateData.variables = extractVariables(data.body);
  }
  if (data.language !== undefined) updateData.language = data.language;
  if (data.category !== undefined) updateData.category = data.category;
  if (data.description !== undefined) updateData.description = data.description;
  if (data.variables !== undefined) updateData.variables = data.variables;

  const [updated] = await db
    .update(smsTemplatesTable)
    .set(updateData)
    .where(eq(smsTemplatesTable.id, id))
    .returning();
  return updated || null;
};

const deleteTemplate = async (id) => {
  const [deleted] = await db
    .update(smsTemplatesTable)
    .set({ isActive: false, updatedAt: new Date() })
    .where(eq(smsTemplatesTable.id, id))
    .returning();
  return deleted || null;
};

// ─── Campaign CRUD ────────────────────────────────────────────────────────────

const createCampaign = async (data, createdBy) => {
  const values = {
    name: data.name,
    description: data.description || null,
    templateId: data.templateId || null,
    targetAudience: data.targetAudience,
    buildingId: data.buildingId || null,
    scheduleType: data.scheduleType || 'once',
    cronExpression: data.cronExpression || null,
    scheduledAt: data.scheduledAt ? new Date(data.scheduledAt) : null,
    templateData: data.templateData || {},
    status: 'draft',
    createdBy: createdBy || null,
  };

  if (data.scheduleType === 'once' && data.scheduledAt) {
    values.nextRunAt = new Date(data.scheduledAt);
  }

  const [campaign] = await db
    .insert(smsCampaignsTable)
    .values(values)
    .returning();
  return campaign;
};

const getCampaigns = async (filters = {}) => {
  const conditions = [eq(smsCampaignsTable.isActive, true)];
  if (filters.status) conditions.push(eq(smsCampaignsTable.status, filters.status));
  if (filters.targetAudience) conditions.push(eq(smsCampaignsTable.targetAudience, filters.targetAudience));
  if (filters.buildingId) conditions.push(eq(smsCampaignsTable.buildingId, filters.buildingId));

  const campaigns = await db
    .select()
    .from(smsCampaignsTable)
    .where(and(...conditions))
    .orderBy(sql`${smsCampaignsTable.createdAt} desc`);
  return campaigns;
};

const getCampaignById = async (id) => {
  const [campaign] = await db
    .select()
    .from(smsCampaignsTable)
    .where(eq(smsCampaignsTable.id, id))
    .limit(1);
  return campaign || null;
};

const updateCampaign = async (id, data) => {
  const updateData = { updatedAt: new Date() };
  if (data.name !== undefined) updateData.name = data.name;
  if (data.description !== undefined) updateData.description = data.description;
  if (data.templateId !== undefined) updateData.templateId = data.templateId;
  if (data.targetAudience !== undefined) updateData.targetAudience = data.targetAudience;
  if (data.buildingId !== undefined) updateData.buildingId = data.buildingId;
  if (data.scheduleType !== undefined) updateData.scheduleType = data.scheduleType;
  if (data.cronExpression !== undefined) updateData.cronExpression = data.cronExpression;
  if (data.scheduledAt !== undefined) {
    updateData.scheduledAt = data.scheduledAt ? new Date(data.scheduledAt) : null;
    updateData.nextRunAt = data.scheduledAt ? new Date(data.scheduledAt) : null;
  }
  if (data.templateData !== undefined) updateData.templateData = data.templateData;

  const [updated] = await db
    .update(smsCampaignsTable)
    .set(updateData)
    .where(eq(smsCampaignsTable.id, id))
    .returning();
  return updated || null;
};

const setCampaignStatus = async (id, status) => {
  const updateData = { status, updatedAt: new Date() };

  if (status === 'active') {
    const [existing] = await db
      .select()
      .from(smsCampaignsTable)
      .where(eq(smsCampaignsTable.id, id))
      .limit(1);

    if (existing) {
      if (existing.scheduleType === 'recurring' && existing.cronExpression) {
        updateData.nextRunAt = new Date();
      } else if (existing.scheduledAt && new Date(existing.scheduledAt) > new Date()) {
        updateData.nextRunAt = new Date(existing.scheduledAt);
      } else if (existing.scheduleType === 'once') {
        updateData.nextRunAt = new Date();
      }
    }
  }

  if (status === 'cancelled') {
    updateData.nextRunAt = null;
  }

  const [updated] = await db
    .update(smsCampaignsTable)
    .set(updateData)
    .where(eq(smsCampaignsTable.id, id))
    .returning();
  return updated || null;
};

const deleteCampaign = async (id) => {
  await db
    .update(smsCampaignsTable)
    .set({ isActive: false, status: 'cancelled', updatedAt: new Date() })
    .where(eq(smsCampaignsTable.id, id));

  await db
    .update(smsQueueTable)
    .set({ status: 'cancelled', updatedAt: new Date() })
    .where(eq(smsQueueTable.campaignId, id));
};

// ─── Campaign Execution ───────────────────────────────────────────────────────

const resolveRecipients = async (campaign) => {
  const recipients = [];

  if (campaign.targetAudience === 'all_tenants') {
    const units = await db
      .select()
      .from(unitsTable)
      .where(and(
        eq(unitsTable.isActive, true),
        eq(unitsTable.status, 'occupied'),
        sql`${unitsTable.tenantPhone} IS NOT NULL`,
      ));

    for (const unit of units) {
      const buildings = await db
        .select()
        .from(buildingsTable)
        .where(eq(buildingsTable.id, unit.buildingId))
        .limit(1);
      const building = buildings[0];

      recipients.push({
        phone: unit.tenantPhone,
        variables: {
          tenant_name: unit.tenantName || '',
          building_address: building ? `${building.address}, ${building.city}` : '',
          unit_label: unit.label || '',
        },
      });
    }
  } else if (campaign.targetAudience === 'building_tenants') {
    if (!campaign.buildingId) return recipients;

    const units = await db
      .select()
      .from(unitsTable)
      .where(and(
        eq(unitsTable.isActive, true),
        eq(unitsTable.status, 'occupied'),
        eq(unitsTable.buildingId, campaign.buildingId),
        sql`${unitsTable.tenantPhone} IS NOT NULL`,
      ));

    const buildings = await db
      .select()
      .from(buildingsTable)
      .where(eq(buildingsTable.id, campaign.buildingId))
      .limit(1);
    const building = buildings[0];

    for (const unit of units) {
      recipients.push({
        phone: unit.tenantPhone,
        variables: {
          tenant_name: unit.tenantName || '',
          building_address: building ? `${building.address}, ${building.city}` : '',
          unit_label: unit.label || '',
        },
      });
    }
  } else if (campaign.targetAudience === 'specific_leads') {
    const leads = await db
      .select()
      .from(leadsTable)
      .where(and(
        eq(leadsTable.isActive, true),
        sql`${leadsTable.phone} IS NOT NULL`,
      ));

    for (const lead of leads) {
      let buildingAddress = '';
      if (lead.buildingId) {
        const buildings = await db
          .select()
          .from(buildingsTable)
          .where(eq(buildingsTable.id, lead.buildingId))
          .limit(1);
        if (buildings[0]) {
          buildingAddress = `${buildings[0].address}, ${buildings[0].city}`;
        }
      }

      recipients.push({
        phone: lead.phone,
        variables: {
          tenant_name: lead.fullName || '',
          building_address: buildingAddress,
        },
      });
    }
  }

  return recipients;
};

const executeCampaign = async (campaignId) => {
  const campaign = await getCampaignById(campaignId);
  if (!campaign) {
    logger.error(`❌ executeCampaign: campaign ${campaignId} not found`);
    return { success: false, error: 'Campaign not found' };
  }

  let template = null;
  if (campaign.templateId) {
    template = await getTemplateById(campaign.templateId);
  }

  const recipients = await resolveRecipients(campaign);
  if (recipients.length === 0) {
    logger.info(`📋 No recipients for campaign ${campaignId}`);
    await db
      .update(smsCampaignsTable)
      .set({ lastRunAt: new Date(), updatedAt: new Date() })
      .where(eq(smsCampaignsTable.id, campaignId));
    return { success: true, processed: 0 };
  }

  let queued = 0;
  let skippedOptOut = 0;
  let skippedValidation = 0;
  const now = new Date();
  const staggerDelayMs = 5000;
  const maxBatchTimeMs = 30 * 60 * 1000;
  let batchStart = Date.now();

  for (const recipient of recipients) {
    if (Date.now() - batchStart > maxBatchTimeMs) break;

    if (await isOptedOut(recipient.phone)) {
      skippedOptOut++;
      continue;
    }

    let messageBody;
    if (template) {
      const vars = { ...campaign.templateData, ...recipient.variables };
      messageBody = renderTemplate(template.body, vars);
    } else {
      messageBody = recipient.messageBody || '';
    }

    if (!messageBody || !recipient.phone) continue;

    const validation = validateTemplateRender(messageBody);
    if (!validation.valid) {
      logger.warn(`Template validation failed for ${recipient.phone}: unrendered vars ${validation.unreplacedVariables.join(', ')}`);
      skippedValidation++;
      continue;
    }

    const scheduledAt = isWithinBusinessHours(now)
      ? new Date(now.getTime() + queued * staggerDelayMs)
      : new Date(getNextBusinessHour(now).getTime() + queued * staggerDelayMs);

    await db.insert(smsQueueTable).values({
      campaignId,
      phoneNumber: recipient.phone,
      messageBody,
      scheduledAt,
      status: 'pending',
      reminderType: null,
    });
    queued++;
  }

  await db
    .update(smsCampaignsTable)
    .set({
      lastRunAt: new Date(),
      updatedAt: new Date(),
      nextRunAt: campaign.scheduleType === 'recurring' ? new Date(Date.now() + 60 * 60 * 1000) : null,
      status: campaign.scheduleType === 'once' ? 'completed' : campaign.status,
    })
    .where(eq(smsCampaignsTable.id, campaignId));

  return { success: true, processed: queued };
};

// ─── SMS Queue Processing ─────────────────────────────────────────────────────

const processQueue = async () => {
  try {
    const now = new Date();
    const messages = await db
      .select()
      .from(smsQueueTable)
      .where(and(
        eq(smsQueueTable.status, 'pending'),
        lte(smsQueueTable.scheduledAt, now),
        sql`${smsQueueTable.retryCount} < ${smsQueueTable.maxRetries}`,
      ))
      .orderBy(sql`${smsQueueTable.scheduledAt} asc`)
      .limit(50);

    if (messages.length === 0) return { processed: 0 };

    let sent = 0;
    let failed = 0;

    for (const msg of messages) {
      await db
        .update(smsQueueTable)
        .set({ status: 'processing', updatedAt: new Date() })
        .where(eq(smsQueueTable.id, msg.id));

      const result = await sendSMS(msg.phoneNumber, msg.messageBody);

      if (result.success) {
        await db
          .update(smsQueueTable)
          .set({
            status: 'sent',
            processedAt: new Date(),
            twilioSid: result.sid || null,
            updatedAt: new Date(),
          })
          .where(eq(smsQueueTable.id, msg.id));

        await logSMS({
          twilioSid: result.sid || null,
          campaignId: msg.campaignId,
          visitId: msg.visitId,
          phoneNumber: msg.phoneNumber,
          direction: 'outbound',
          messageBody: msg.messageBody,
          status: 'sent',
          twilioStatus: result.status || null,
        });

        if (msg.campaignId) {
          await db
            .update(smsCampaignsTable)
            .set({
              totalSent: sql`${smsCampaignsTable.totalSent} + 1`,
              updatedAt: new Date(),
            })
            .where(eq(smsCampaignsTable.id, msg.campaignId));
        }

        sent++;
      } else {
        const newRetryCount = msg.retryCount + 1;
        const isFinalRetry = newRetryCount >= msg.maxRetries;

        await db
          .update(smsQueueTable)
          .set({
            status: isFinalRetry ? 'failed' : 'pending',
            retryCount: newRetryCount,
            lastError: result.error || null,
            updatedAt: new Date(),
            scheduledAt: isFinalRetry
              ? msg.scheduledAt
              : new Date(Date.now() + Math.pow(2, newRetryCount) * 60 * 1000),
          })
          .where(eq(smsQueueTable.id, msg.id));

        if (isFinalRetry && msg.campaignId) {
          await db
            .update(smsCampaignsTable)
            .set({
              totalFailed: sql`${smsCampaignsTable.totalFailed} + 1`,
              updatedAt: new Date(),
            })
            .where(eq(smsCampaignsTable.id, msg.campaignId));
        }

        failed++;
      }
    }

    return { processed: messages.length, sent, failed };
  } catch (error) {
    logger.error('❌ processQueue error:', error.message);
    return { processed: 0, error: error.message };
  }
};

const retryFailedMessages = async () => {
  try {
    const messages = await db
      .select()
      .from(smsQueueTable)
      .where(and(
        eq(smsQueueTable.status, 'failed'),
        sql`${smsQueueTable.retryCount} < ${smsQueueTable.maxRetries}`,
      ))
      .orderBy(sql`${smsQueueTable.updatedAt} asc`)
      .limit(20);

    for (const msg of messages) {
      await db
        .update(smsQueueTable)
        .set({
          status: 'pending',
          scheduledAt: new Date(),
          updatedAt: new Date(),
        })
        .where(eq(smsQueueTable.id, msg.id));
    }

    return { reset: messages.length };
  } catch (error) {
    logger.error('❌ retryFailedMessages error:', error.message);
    return { reset: 0, error: error.message };
  }
};

// ─── Automated Reminder Queries ───────────────────────────────────────────────

const getVisitsNeeding24hReminder = async () => {
  try {
    const now = new Date();
    const windowStart = new Date(now.getTime() + 23 * 60 * 60 * 1000);
    const windowEnd = new Date(now.getTime() + 25 * 60 * 60 * 1000);

    const visits = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.isActive, true),
        eq(visitsTable.status, 'confirmed'),
        gte(visitsTable.dateTime, windowStart),
        lte(visitsTable.dateTime, windowEnd),
      ));

    const results = [];
    for (const visit of visits) {
      const existing = await db
        .select()
        .from(smsQueueTable)
        .where(and(
          eq(smsQueueTable.visitId, visit.id),
          eq(smsQueueTable.reminderType, 'visit_24h'),
          ne(smsQueueTable.status, 'cancelled'),
        ))
        .limit(1);

      if (!existing.length) {
        results.push(visit);
      }
    }
    return results;
  } catch (error) {
    logger.error('❌ getVisitsNeeding24hReminder error:', error.message);
    return [];
  }
};

const getVisitsNeeding2hReminder = async () => {
  try {
    const now = new Date();
    const windowStart = new Date(now.getTime() + 1.5 * 60 * 60 * 1000);
    const windowEnd = new Date(now.getTime() + 2.5 * 60 * 60 * 1000);

    const visits = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.isActive, true),
        eq(visitsTable.status, 'confirmed'),
        gte(visitsTable.dateTime, windowStart),
        lte(visitsTable.dateTime, windowEnd),
      ));

    const results = [];
    for (const visit of visits) {
      const existing = await db
        .select()
        .from(smsQueueTable)
        .where(and(
          eq(smsQueueTable.visitId, visit.id),
          eq(smsQueueTable.reminderType, 'visit_2h'),
          ne(smsQueueTable.status, 'cancelled'),
        ))
        .limit(1);

      if (!existing.length) {
        results.push(visit);
      }
    }
    return results;
  } catch (error) {
    logger.error('❌ getVisitsNeeding2hReminder error:', error.message);
    return [];
  }
};

const queueVisit24hReminder = async (visitId) => {
  const ctx = await getVisitContext(visitId);
  if (!ctx || !ctx.employee || !ctx.building) {
    return { success: false, error: 'Missing visit context' };
  }

  const { visit, employee, lead, unit, building } = ctx;
  const message = `📍 Rappel: Visite demain ${formatDateTime(visit.dateTime)} à ${building.name} ${unit ? unit.label : ''} avec ${lead ? lead.fullName : 'locataire'}. Confirmez votre présence.`;

  await db.insert(smsQueueTable).values({
    reminderType: 'visit_24h',
    visitId,
    phoneNumber: employee.phone,
    messageBody: message,
    scheduledAt: new Date(),
    status: 'pending',
    maxRetries: 3,
  });

  if (lead && lead.phone) {
    const leadMessage = `📍 Rappel: Votre visite est demain ${formatDateTime(visit.dateTime)} à ${building.name} ${unit ? unit.label : ''}. Confirmez: 1=Oui, 2=Non`;
    await db.insert(smsQueueTable).values({
      reminderType: 'visit_24h',
      visitId,
      leadId: lead.id,
      phoneNumber: lead.phone,
      messageBody: leadMessage,
      scheduledAt: new Date(),
      status: 'pending',
      maxRetries: 3,
    });
  }

  return { success: true };
};

const queueVisit2hReminder = async (visitId) => {
  const ctx = await getVisitContext(visitId);
  if (!ctx || !ctx.employee || !ctx.building) {
    return { success: false, error: 'Missing visit context' };
  }

  const { visit, employee, lead, unit, building } = ctx;
  const message = `⏰ Visite dans 2h! ${formatDateTime(visit.dateTime)} à ${building.name} ${unit ? unit.label : ''} avec ${lead ? lead.fullName : 'locataire'}. Départ imminent!`;

  await db.insert(smsQueueTable).values({
    reminderType: 'visit_2h',
    visitId,
    phoneNumber: employee.phone,
    messageBody: message,
    scheduledAt: new Date(),
    status: 'pending',
    maxRetries: 3,
  });

  return { success: true };
};

const getLeasesNeedingRenewalReminder = async () => {
  try {
    const now = new Date();
    const windowStart = new Date(now.getTime() + 28 * 24 * 60 * 60 * 1000);
    const windowEnd = new Date(now.getTime() + 32 * 24 * 60 * 60 * 1000);

    const leases = await db
      .select()
      .from(leasesTable)
      .where(and(
        eq(leasesTable.isActive, true),
        eq(leasesTable.status, 'active'),
        gte(leasesTable.endDate, windowStart),
        lte(leasesTable.endDate, windowEnd),
      ));

    const results = [];
    for (const lease of leases) {
      const existing = await db
        .select()
        .from(smsQueueTable)
        .where(and(
          eq(smsQueueTable.leaseId, lease.id),
          eq(smsQueueTable.reminderType, 'lease_renewal'),
          ne(smsQueueTable.status, 'cancelled'),
        ))
        .limit(1);

      if (!existing.length) {
        results.push(lease);
      }
    }
    return results;
  } catch (error) {
    logger.error('❌ getLeasesNeedingRenewalReminder error:', error.message);
    return [];
  }
};

const queueLeaseRenewalReminder = async (leaseId) => {
  const [lease] = await db
    .select()
    .from(leasesTable)
    .where(eq(leasesTable.id, leaseId))
    .limit(1);

  if (!lease || !lease.tenantPhone) {
    return { success: false, error: 'Lease or tenant phone not found' };
  }

  const [unit] = await db
    .select()
    .from(unitsTable)
    .where(eq(unitsTable.id, lease.unitId))
    .limit(1);

  let buildingAddress = '';
  if (unit) {
    const [building] = await db
      .select()
      .from(buildingsTable)
      .where(eq(buildingsTable.id, unit.buildingId))
      .limit(1);
    if (building) buildingAddress = `${building.address}, ${building.city}`;
  }

  const endDate = new Date(lease.endDate).toLocaleDateString('fr-CA', {
    year: 'numeric', month: 'long', day: 'numeric',
  });

  const message = `📋 Rappel: Votre bail expire le ${endDate} à ${buildingAddress}. Contactez-nous pour le renouvellement.`;

  await db.insert(smsQueueTable).values({
    reminderType: 'lease_renewal',
    leaseId,
    phoneNumber: lease.tenantPhone,
    messageBody: message,
    scheduledAt: new Date(),
    status: 'pending',
    maxRetries: 3,
  });

  return { success: true };
};

const getPaymentsNeedingReminder = async (type) => {
  try {
    const now = new Date();
    const leases = await db
      .select()
      .from(leasesTable)
      .where(and(
        eq(leasesTable.isActive, true),
        eq(leasesTable.status, 'active'),
      ));

    const results = [];

    for (const lease of leases) {
      const startDate = new Date(lease.startDate);
      const dayOfMonth = startDate.getDate();
      const currentMonth = now.getMonth();
      const currentYear = now.getFullYear();

      let dueDate;
      if (dayOfMonth > now.getDate()) {
        dueDate = new Date(currentYear, currentMonth, dayOfMonth);
      } else {
        dueDate = new Date(currentYear, currentMonth + 1, dayOfMonth);
      }

      const daysUntilDue = Math.ceil((dueDate - now) / (1000 * 60 * 60 * 24));

      if (type === 'payment_3d' && daysUntilDue >= 2 && daysUntilDue <= 4) {
        const existing = await db
          .select()
          .from(smsQueueTable)
          .where(and(
            eq(smsQueueTable.leaseId, lease.id),
            eq(smsQueueTable.reminderType, 'payment_3d'),
            sql`${smsQueueTable.createdAt} > ${new Date(currentYear, currentMonth, 1)}`,
          ))
          .limit(1);

        if (!existing.length) {
          results.push({ lease, dueDate });
        }
      } else if (type === 'payment_due' && daysUntilDue === 0) {
        const existing = await db
          .select()
          .from(smsQueueTable)
          .where(and(
            eq(smsQueueTable.leaseId, lease.id),
            eq(smsQueueTable.reminderType, 'payment_due'),
            sql`${smsQueueTable.createdAt} > ${new Date(currentYear, currentMonth, 1)}`,
          ))
          .limit(1);

        if (!existing.length) {
          results.push({ lease, dueDate });
        }
      }
    }

    return results;
  } catch (error) {
    logger.error('❌ getPaymentsNeedingReminder error:', error.message);
    return [];
  }
};

const queuePaymentReminder = async (leaseId, type) => {
  const [lease] = await db
    .select()
    .from(leasesTable)
    .where(eq(leasesTable.id, leaseId))
    .limit(1);

  if (!lease || !lease.tenantPhone) {
    return { success: false, error: 'Lease or tenant phone not found' };
  }

  const rentDollars = (lease.rentCents / 100).toFixed(2);
  const [unit] = await db
    .select()
    .from(unitsTable)
    .where(eq(unitsTable.id, lease.unitId))
    .limit(1);

  let buildingAddress = '';
  if (unit) {
    const [building] = await db
      .select()
      .from(buildingsTable)
      .where(eq(buildingsTable.id, unit.buildingId))
      .limit(1);
    if (building) buildingAddress = `${building.address}, ${building.city}`;
  }

  let message;
  if (type === 'payment_3d') {
    message = `💰 Rappel: Votre loyer de ${rentDollars}$ est dû dans 3 jours pour ${buildingAddress}. Préparez votre paiement.`;
  } else {
    message = `💰 Votre loyer de ${rentDollars}$ est dû aujourd'hui pour ${buildingAddress}. Effectuez votre paiement dès que possible.`;
  }

  await db.insert(smsQueueTable).values({
    reminderType: type,
    leaseId,
    phoneNumber: lease.tenantPhone,
    messageBody: message,
    scheduledAt: new Date(),
    status: 'pending',
    maxRetries: 3,
  });

  return { success: true };
};

const getVisitsNeedingExpiry = async () => {
  try {
    const now = new Date();
    const twentyFourHoursAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    const visits = await db
      .select()
      .from(visitsTable)
      .where(and(
        eq(visitsTable.isActive, true),
        eq(visitsTable.status, 'scheduled'),
        eq(visitsTable.employeeConfirmed, false),
        sql`${visitsTable.createdAt} < ${twentyFourHoursAgo}`,
      ));

    return visits;
  } catch (error) {
    logger.error('❌ getVisitsNeedingExpiry error:', error.message);
    return [];
  }
};

const expireVisits = async () => {
  try {
    const visits = await getVisitsNeedingExpiry();

    if (visits.length === 0) return { expired: 0 };

    let expired = 0;
    for (const visit of visits) {
      await db
        .update(visitsTable)
        .set({ status: 'cancelled', updatedAt: new Date() })
        .where(eq(visitsTable.id, visit.id));

      logger.info(`⏰ Visit ${visit.id} auto-cancelled: no confirmation after 24h`);
      expired++;
    }

    return { expired };
  } catch (error) {
    logger.error('❌ expireVisits error:', error.message);
    return { expired: 0, error: error.message };
  }
};

const getActiveCampaignsDue = async () => {
  const now = new Date();
  const campaigns = await db
    .select()
    .from(smsCampaignsTable)
    .where(and(
      eq(smsCampaignsTable.isActive, true),
      eq(smsCampaignsTable.status, 'active'),
      sql`${smsCampaignsTable.nextRunAt} IS NOT NULL`,
      lte(smsCampaignsTable.nextRunAt, now),
    ))
    .orderBy(sql`${smsCampaignsTable.nextRunAt} asc`)
    .limit(10);

  return campaigns;
};

module.exports = {
  sendVisitConfirmation,
  sendTenantConfirmationRequest,
  sendOccupantAccessRequest,
  sendMorningOfReminder,
  sendPostVisitSurvey,
  sendLeadArrivalNotification,
  sendLeadFeedbackRequest,
  notifySimonInterested,
  handleEmployeeReply,
  handleTenantReply,
  handleOccupantReply,
  getVisitsNeedingMorningReminder,
  getVisitsNeedingPostSurvey,
  renderTemplate,
  extractVariables,
  createTemplate,
  getTemplates,
  getTemplateById,
  updateTemplate,
  deleteTemplate,
  createCampaign,
  getCampaigns,
  getCampaignById,
  updateCampaign,
  setCampaignStatus,
  deleteCampaign,
  executeCampaign,
  processQueue,
  retryFailedMessages,
  getVisitsNeeding24hReminder,
  getVisitsNeeding2hReminder,
  queueVisit24hReminder,
  queueVisit2hReminder,
  getLeasesNeedingRenewalReminder,
  queueLeaseRenewalReminder,
  getPaymentsNeedingReminder,
  queuePaymentReminder,
  getActiveCampaignsDue,
  getVisitsNeedingExpiry,
  expireVisits,
};
