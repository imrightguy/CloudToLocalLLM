const {
  eq, and, sql, lte, gte,
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
    confirmationRequest: (dateTime, buildingName) => `📍 Visite confirmée! ${formatDateTime(dateTime)} à ${buildingName}. Confirmez votre présence: 1=Oui, 2=Non`,
  },
  en: {
    confirmationRequest: (dateTime, buildingName) => `📍 Visit confirmed! ${new Date(dateTime).toLocaleDateString('en-CA', {
      weekday: 'long', month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit',
    })} at ${buildingName}. Confirm your attendance: 1=Yes, 2=No`,
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
    const message = tenantMessages[lang].confirmationRequest(visit.dateTime, building.name);

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

module.exports = {
  sendVisitConfirmation,
  sendTenantConfirmationRequest,
  sendOccupantAccessRequest,
  sendMorningOfReminder,
  sendPostVisitSurvey,
  notifySimonInterested,
  handleEmployeeReply,
  handleTenantReply,
  handleOccupantReply,
  getVisitsNeedingMorningReminder,
  getVisitsNeedingPostSurvey,
};
