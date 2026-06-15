// ─── Message Templates Service ───
// CRUD for the customizable automatic-message templates used by PlexFlow
// webhooks (departure / arrival / renewal SMS + vacant / occupied emails).

const { eq, asc } = require('drizzle-orm');
const { db } = require('../database/connection');
const { messageTemplatesTable } = require('../database/schema');
const logger = require('../utils/logger');

// Canonical event types and their channel + built-in default content. Used as a
// fallback when the DB row is missing (e.g. migration seed not yet applied).
const DEFAULT_TEMPLATES = {
  tenant_deactivated: {
    channel: 'sms',
    subject: null,
    body: "Bonjour {tenantName}, votre départ du {unitLabel} est prévu le {date}. Prenez des photos de l'état du logement et envoyez-les ici. Merci! — Simon Gravel",
  },
  tenant_activated: {
    channel: 'sms',
    subject: null,
    body: 'Bienvenue {tenantName} au {unitLabel}! Votre bail débute le {date}. Prenez des photos de votre arrivée pour l\'état des lieux. Des questions? Contactez-moi. — Simon Gravel',
  },
  lease_created: {
    channel: 'sms',
    subject: null,
    body: 'Bonjour {tenantName}, votre bail au {unitLabel} est confirmé et débute le {date}. Bienvenue! — Simon Gravel',
  },
  lease_renewed: {
    channel: 'sms',
    subject: null,
    body: 'Bonjour {tenantName}, votre bail au {unitLabel} a été renouvelé jusqu\'au {date}. Merci de votre confiance! — Simon Gravel',
  },
  unit_vacant: {
    channel: 'email',
    subject: 'Unité vacante — {unitLabel}',
    body: '{unitLabel} ({buildingName}) sera vacant dès le {date}. Locataire sortant: {tenantName}. Action: mettre en annonce.',
  },
  unit_occupied: {
    channel: 'email',
    subject: 'Unité occupée — {unitLabel}',
    body: '{unitLabel} ({buildingName}) est maintenant occupé par {tenantName}. Bail début: {date}.',
  },
};

const VALID_EVENT_TYPES = Object.keys(DEFAULT_TEMPLATES);

/**
 * Replace {placeholder} tokens with values. Unknown placeholders are left as a
 * readable fallback ("—") rather than printing the raw token.
 * @param {string} template
 * @param {Record<string, string>} variables
 * @returns {string}
 */
function renderTemplate(template, variables = {}) {
  if (!template) {
    return '';
  }
  return template.replace(/\{(\w+)\}/g, (match, key) => {
    const value = variables[key];
    return value === undefined || value === null || value === '' ? '—' : String(value);
  });
}

/**
 * Return every template, merging DB rows over the built-in defaults so the full
 * set of event types is always present (used by the settings screen).
 * @returns {Promise<Array>}
 */
async function listTemplates() {
  let rows = [];
  try {
    rows = await db
      .select()
      .from(messageTemplatesTable)
      .orderBy(asc(messageTemplatesTable.eventType));
  } catch (error) {
    logger.warn('[message-templates.service] listTemplates DB error, using defaults', { error: error.message });
  }

  const byType = new Map(rows.map((row) => [row.eventType, row]));

  return VALID_EVENT_TYPES.map((eventType) => {
    const fallback = DEFAULT_TEMPLATES[eventType];
    const row = byType.get(eventType);
    if (row) {
      return row;
    }
    return {
      id: null,
      eventType,
      channel: fallback.channel,
      subject: fallback.subject,
      body: fallback.body,
      isActive: true,
      createdAt: null,
      updatedAt: null,
    };
  });
}

/**
 * Resolve a single template by event type, falling back to the built-in default.
 * @param {string} eventType
 * @returns {Promise<{eventType: string, channel: string, subject: string|null, body: string, isActive: boolean}>}
 */
async function getTemplate(eventType) {
  const fallback = DEFAULT_TEMPLATES[eventType] || { channel: 'sms', subject: null, body: '' };
  try {
    const [row] = await db
      .select()
      .from(messageTemplatesTable)
      .where(eq(messageTemplatesTable.eventType, eventType))
      .limit(1);
    if (row) {
      return row;
    }
  } catch (error) {
    logger.warn('[message-templates.service] getTemplate DB error, using default', { error: error.message, eventType });
  }
  return {
    eventType,
    channel: fallback.channel,
    subject: fallback.subject,
    body: fallback.body,
    isActive: true,
  };
}

/**
 * Create or update the template for an event type.
 * @param {string} eventType
 * @param {{ body?: string, subject?: string|null, channel?: string, isActive?: boolean }} data
 * @returns {Promise<Object>}
 */
async function upsertTemplate(eventType, data = {}) {
  if (!VALID_EVENT_TYPES.includes(eventType)) {
    const error = new Error(`Unknown message template event type: ${eventType}`);
    error.code = 'INVALID_EVENT_TYPE';
    throw error;
  }

  const fallback = DEFAULT_TEMPLATES[eventType];
  const channel = data.channel || fallback.channel;

  const [existing] = await db
    .select()
    .from(messageTemplatesTable)
    .where(eq(messageTemplatesTable.eventType, eventType))
    .limit(1);

  if (existing) {
    const updateData = { updatedAt: new Date() };
    if (data.body !== undefined) {
      updateData.body = data.body;
    }
    if (data.subject !== undefined) {
      updateData.subject = data.subject || null;
    }
    if (data.channel !== undefined) {
      updateData.channel = channel;
    }
    if (data.isActive !== undefined) {
      updateData.isActive = data.isActive;
    }

    const [row] = await db
      .update(messageTemplatesTable)
      .set(updateData)
      .where(eq(messageTemplatesTable.eventType, eventType))
      .returning();
    return row;
  }

  const [row] = await db
    .insert(messageTemplatesTable)
    .values({
      eventType,
      channel,
      subject: data.subject !== undefined ? (data.subject || null) : fallback.subject,
      body: data.body !== undefined ? data.body : fallback.body,
      isActive: data.isActive !== undefined ? data.isActive : true,
    })
    .returning();
  return row;
}

module.exports = {
  DEFAULT_TEMPLATES,
  VALID_EVENT_TYPES,
  renderTemplate,
  listTemplates,
  getTemplate,
  upsertTemplate,
};
