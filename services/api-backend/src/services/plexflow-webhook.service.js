// ─── PlexFlow Webhook Service (dispatcher) ───
// Receives PlexFlow events (tenant move-out / move-in, unit vacant / occupied,
// lease created / renewed) and triggers the matching automatic communication:
//   • SMS to the tenant (departure / arrival / lease confirmation / renewal)
//   • Email to Simon (unit vacant / occupied)
// Photos requests are tracked in the departure_photos table.

const { eq, and, sql } = require('drizzle-orm');
const { db } = require('../database/connection');
const { unitsTable, usersTable, smsLogsTable } = require('../database/schema');
const { sendSMS } = require('./twilio.service');
const notificationService = require('./notification.service');
const messageTemplates = require('./message-templates.service');
const departurePhotosService = require('./departure-photos.service');
const { child } = require('../utils/logger');

const log = child({ service: 'plexflow-webhook' });

// Which canonical event types send an SMS vs an email, and (for SMS) whether a
// photo request should be tracked.
const EVENT_CONFIG = {
  tenant_deactivated: { channel: 'sms', photoEvent: 'departure' },
  tenant_activated: { channel: 'sms', photoEvent: 'arrival' },
  lease_created: { channel: 'sms', photoEvent: 'arrival' },
  lease_renewed: { channel: 'sms', photoEvent: null },
  unit_vacant: { channel: 'email', photoEvent: null },
  unit_occupied: { channel: 'email', photoEvent: null },
};

// ─── Helpers ───

function normalizePhone(value) {
  if (!value) {
    return null;
  }
  const digits = String(value).replace(/\D/g, '');
  if (digits.length < 10) {
    return digits || null;
  }
  return digits.slice(-10);
}

/**
 * Map a raw PlexFlow event string to one of our canonical event types.
 * @param {object} payload
 * @returns {string|null}
 */
function detectEventType(payload = {}) {
  const raw = String(
    payload.event
    || payload.eventType
    || payload.event_name
    || payload.type
    || payload.action
    || '',
  ).toLowerCase();

  if (!raw) {
    return null;
  }

  // Order matters — check the most specific signals first. Note: accented
  // "désactivé" must be caught here before the generic "activ" branch below.
  if (/d[ée]sactiv|deactiv|d[ée]part|move[\s_-]?out|removed|terminated/.test(raw)) {
    return 'tenant_deactivated';
  }
  if (/renew|renouvel/.test(raw)) {
    return 'lease_renewed';
  }
  if (/vacant|vacat/.test(raw)) {
    return 'unit_vacant';
  }
  if (/occup/.test(raw)) {
    return 'unit_occupied';
  }
  if (/lease|bail/.test(raw) && /creat|cr[ée]/.test(raw)) {
    return 'lease_created';
  }
  if (/activ|move[\s_-]?in|arriv|bienvenue/.test(raw)) {
    return 'tenant_activated';
  }
  return null;
}

/** First non-empty value across a list of source objects for any of the keys. */
function pick(sources, keys) {
  for (const source of sources) {
    if (!source || typeof source !== 'object') {
      continue;
    }
    for (const key of keys) {
      const value = source[key];
      if (value !== undefined && value !== null && String(value).trim() !== '') {
        return value;
      }
    }
  }
  return null;
}

function formatDate(value) {
  if (!value) {
    return null;
  }
  // Parse bare YYYY-MM-DD as local time so it isn't shifted a day by UTC parsing.
  const str = String(value).trim();
  const dateOnly = /^\d{4}-\d{2}-\d{2}$/.test(str) ? `${str}T00:00:00` : str;
  const date = new Date(dateOnly);
  if (Number.isNaN(date.getTime())) {
    return str;
  }
  return date.toLocaleDateString('fr-CA', { year: 'numeric', month: 'long', day: 'numeric' });
}

/**
 * Pull the relevant context out of an arbitrary PlexFlow payload shape.
 * @param {object} payload
 */
function extractContext(payload = {}) {
  const data = payload.data || payload.payload || {};
  const tenant = data.tenant || payload.tenant || {};
  const unit = data.unit || payload.unit || {};
  const building = data.building || payload.building || {};
  const lease = data.lease || payload.lease || {};
  const sources = [data, tenant, unit, building, lease, payload];

  const firstName = pick([tenant, data, payload], ['firstName', 'first_name', 'tenantFirstName']);
  const lastName = pick([tenant, data, payload], ['lastName', 'last_name', 'tenantLastName']);
  // Restrict to tenant-specific sources so a generic "name" on the building
  // object is never mistaken for the tenant's name.
  let tenantName = pick([tenant, data], ['tenantName', 'tenant_name', 'fullName', 'full_name', 'name']);
  if (!tenantName && (firstName || lastName)) {
    tenantName = [firstName, lastName].filter(Boolean).join(' ').trim();
  }
  if (!tenantName) {
    tenantName = pick([payload], ['tenantName', 'tenant_name', 'fullName', 'full_name']);
  }

  const rawDate = pick(sources, [
    'date', 'eventDate', 'effectiveDate', 'effective_date',
    'moveOutDate', 'move_out_date', 'moveInDate', 'move_in_date',
    'endDate', 'end_date', 'startDate', 'start_date',
  ]);

  return {
    tenantName: tenantName || null,
    tenantPhone: pick(sources, ['tenantPhone', 'tenant_phone', 'phone', 'phoneNumber', 'phone_number', 'mobile']),
    tenantEmail: pick(sources, ['tenantEmail', 'tenant_email', 'email']),
    unitLabel: pick([unit, data, payload], ['unitLabel', 'unit_label', 'label', 'unitNumber', 'unit_number', 'number']),
    buildingName: pick([building, data, payload], ['buildingName', 'building_name', 'name', 'label', 'address']),
    plexflowUnitId: pick([unit, data, payload], ['unitId', 'unit_id', 'plexflowUnitId']) || (unit && unit.id),
    plexflowBuildingId: pick([building, data, payload], ['buildingId', 'building_id', 'plexflowBuildingId']) || (building && building.id),
    date: formatDate(rawDate),
  };
}

/**
 * Find the matching local unit (and its building) by PlexFlow id or label.
 * @param {object} context
 * @returns {Promise<{unitId: string, buildingId: string, tenantPhone: string|null}|null>}
 */
async function resolveLocalUnit(context) {
  try {
    if (context.plexflowUnitId) {
      const [byPlexflow] = await db
        .select({
          id: unitsTable.id,
          buildingId: unitsTable.buildingId,
          tenantPhone: unitsTable.tenantPhone,
        })
        .from(unitsTable)
        .where(sql`${unitsTable.amenities}->>'plexflowId' = ${String(context.plexflowUnitId)}`)
        .limit(1);
      if (byPlexflow) {
        return { unitId: byPlexflow.id, buildingId: byPlexflow.buildingId, tenantPhone: byPlexflow.tenantPhone };
      }
    }

    if (context.unitLabel) {
      const [byLabel] = await db
        .select({
          id: unitsTable.id,
          buildingId: unitsTable.buildingId,
          tenantPhone: unitsTable.tenantPhone,
        })
        .from(unitsTable)
        .where(and(eq(unitsTable.isActive, true), eq(unitsTable.label, String(context.unitLabel))))
        .limit(1);
      if (byLabel) {
        return { unitId: byLabel.id, buildingId: byLabel.buildingId, tenantPhone: byLabel.tenantPhone };
      }
    }
  } catch (error) {
    log.warn('resolveLocalUnit failed', { error: error.message });
  }
  return null;
}

/** Collect destination email addresses for Simon / admins. */
async function getAdminEmails() {
  const emails = [];
  try {
    const admins = await db
      .select({ email: usersTable.email })
      .from(usersTable)
      .where(eq(usersTable.role, 'admin'));
    for (const admin of admins) {
      if (admin.email) {
        emails.push(admin.email);
      }
    }
  } catch (error) {
    log.warn('getAdminEmails failed', { error: error.message });
  }
  if (!emails.length && process.env.SIMON_EMAIL) {
    emails.push(process.env.SIMON_EMAIL);
  }
  return [...new Set(emails)];
}

async function logOutboundSms(phoneNumber, messageBody, result) {
  try {
    await db.insert(smsLogsTable).values({
      phoneNumber,
      direction: 'outbound',
      messageBody,
      status: result && result.success ? 'sent' : 'failed',
      twilioSid: (result && result.sid) || null,
      twilioStatus: (result && result.status) || null,
      errorMessage: result && result.success ? null : (result && result.error) || null,
    });
  } catch (error) {
    log.warn('logOutboundSms failed', { error: error.message });
  }
}

function buildUploadLink(local, context, photoEvent) {
  const base = process.env.APP_PUBLIC_URL || process.env.PUBLIC_BASE_URL;
  if (!base) {
    return null;
  }
  const params = new URLSearchParams({ event: photoEvent });
  if (local && local.unitId) {
    params.set('unitId', local.unitId);
  }
  if (context.unitLabel) {
    params.set('unit', String(context.unitLabel));
  }
  return `${base.replace(/\/$/, '')}/photos/upload?${params.toString()}`;
}

// ─── Dispatcher ───

/**
 * Process a single PlexFlow webhook payload.
 * @param {object} payload
 * @returns {Promise<object>} result summary
 */
async function processWebhook(payload = {}) {
  const eventType = detectEventType(payload);
  if (!eventType) {
    log.warn('Unrecognized PlexFlow event', { event: payload.event || payload.type || null });
    return { handled: false, reason: 'UNRECOGNIZED_EVENT', eventType: null };
  }

  const config = EVENT_CONFIG[eventType];
  const context = extractContext(payload);
  const local = await resolveLocalUnit(context);

  const variables = {
    tenantName: context.tenantName || '',
    unitLabel: context.unitLabel || '',
    buildingName: context.buildingName || '',
    date: context.date || '',
  };

  const template = await messageTemplates.getTemplate(eventType);
  if (template.isActive === false) {
    log.info('Template disabled — skipping', { eventType });
    return { handled: true, skipped: true, reason: 'TEMPLATE_DISABLED', eventType };
  }

  // ─── Email events (notify Simon) ───
  if (config.channel === 'email') {
    const subject = messageTemplates.renderTemplate(template.subject || eventType, variables);
    const body = messageTemplates.renderTemplate(template.body, variables);
    const recipients = await getAdminEmails();

    if (!recipients.length) {
      log.warn('No admin recipients for PlexFlow email event', { eventType });
      return { handled: true, eventType, emailSent: false, reason: 'NO_RECIPIENTS' };
    }

    const html = `<p>${body.replace(/\n/g, '<br>')}</p>`;
    const results = await Promise.all(
      recipients.map((to) => notificationService.sendEmail(to, subject, html)),
    );
    const emailSent = results.some((r) => r && r.success);
    log.info('PlexFlow email event processed', { eventType, emailSent, recipients: recipients.length });
    return { handled: true, eventType, channel: 'email', emailSent, recipients: recipients.length };
  }

  // ─── SMS events (notify tenant) ───
  const body = messageTemplates.renderTemplate(template.body, variables);
  const phone = context.tenantPhone || (local && local.tenantPhone) || null;

  let photoRecordId = null;
  if (config.photoEvent) {
    const uploadLink = buildUploadLink(local, context, config.photoEvent);
    const record = await departurePhotosService.createPhoto({
      buildingId: local ? local.buildingId : null,
      unitId: local ? local.unitId : null,
      tenantName: context.tenantName,
      eventType: config.photoEvent,
      photoUrl: null,
      notes: uploadLink
        ? `Demande de photos envoyée — lien d'upload: ${uploadLink}`
        : 'Demande de photos envoyée au locataire.',
    });
    photoRecordId = record ? record.id : null;
  }

  if (!phone) {
    // No phone anywhere → alert Simon by email instead of silently dropping.
    const recipients = await getAdminEmails();
    if (recipients.length) {
      const subject = `Téléphone manquant — ${context.tenantName || 'locataire'}`;
      const html = `<p>Téléphone manquant pour <strong>${context.tenantName || 'locataire'}</strong> — webhook PlexFlow «${eventType}» reçu mais SMS non envoyé.</p>`
        + `<p>Unité: ${context.unitLabel || '—'} · Bâtiment: ${context.buildingName || '—'}</p>`;
      await Promise.all(recipients.map((to) => notificationService.sendEmail(to, subject, html)));
    }
    log.warn('PlexFlow SMS event has no phone — alerted admins', { eventType, tenantName: context.tenantName });
    return {
      handled: true, eventType, channel: 'sms', smsSent: false, reason: 'NO_PHONE', photoRecordId,
    };
  }

  const result = await sendSMS(phone, body);
  await logOutboundSms(normalizePhone(phone) || phone, body, result);
  log.info('PlexFlow SMS event processed', { eventType, smsSent: !!(result && result.success) });

  return {
    handled: true,
    eventType,
    channel: 'sms',
    smsSent: !!(result && result.success),
    photoRecordId,
  };
}

module.exports = {
  EVENT_CONFIG,
  detectEventType,
  extractContext,
  resolveLocalUnit,
  processWebhook,
};
