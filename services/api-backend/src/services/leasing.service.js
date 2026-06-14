const { db } = require('../database/connection');
const { leadsTable } = require('../database/schema');
const { child } = require('../utils/logger');

const log = child({ service: 'leasing' });

const HERMES_TIMEOUT_MS = 8000;

function firstNonEmpty(...values) {
  for (const value of values) {
    if (typeof value === 'string' && value.trim()) {
      return value.trim();
    }
  }
  return null;
}

function normalizeMarketplacePayload(payload = {}) {
  const fullName = firstNonEmpty(
    payload.fullName,
    payload.name,
    payload.senderName,
    [payload.firstName, payload.lastName].filter(Boolean).join(' '),
  ) || 'Prospect inconnu';

  const source = firstNonEmpty(
    payload.source,
    payload.channel,
    payload.platform,
  ) || 'marketplace';

  const notes = firstNonEmpty(
    payload.message,
    payload.notes,
    payload.body,
    payload.text,
  );

  const desiredUnit = firstNonEmpty(
    payload.desiredUnit,
    payload.listingTitle,
    payload.listingId,
    payload.adId,
  );

  let budgetCents = null;
  if (Number.isFinite(payload.budgetCents)) {
    budgetCents = Math.round(payload.budgetCents);
  } else if (Number.isFinite(payload.budget)) {
    budgetCents = Math.round(payload.budget * 100);
  }

  const language = payload.language === 'en' ? 'en' : 'fr';

  return {
    fullName,
    email: firstNonEmpty(payload.email),
    phone: firstNonEmpty(payload.phone, payload.phoneNumber),
    source,
    notes,
    desiredUnit,
    budgetCents,
    language,
  };
}

async function ingestMarketplaceLead(payload = {}) {
  const normalized = normalizeMarketplacePayload(payload);

  const [lead] = await db
    .insert(leadsTable)
    .values({
      fullName: normalized.fullName,
      email: normalized.email,
      phone: normalized.phone,
      budgetCents: normalized.budgetCents,
      desiredUnit: normalized.desiredUnit,
      source: normalized.source,
      stage: 'nouveau',
      qualificationState: 'unknown',
      notes: normalized.notes,
      language: normalized.language,
    })
    .returning();

  log.info('Marketplace lead ingested', { leadId: lead.id, source: lead.source });
  return lead;
}

async function notifyHermes(event, lead) {
  const webhookUrl = process.env.HERMES_WEBHOOK_URL;
  if (!webhookUrl) {
    return { delivered: false, reason: 'hermes_not_configured' };
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), HERMES_TIMEOUT_MS);

  try {
    const headers = { 'Content-Type': 'application/json' };
    if (process.env.HERMES_WEBHOOK_SECRET) {
      headers['X-Hermes-Secret'] = process.env.HERMES_WEBHOOK_SECRET;
    }

    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify({ event, lead }),
      signal: controller.signal,
    });

    if (!response.ok) {
      log.warn('Hermes notification non-2xx', { event, status: response.status });
      return { delivered: false, reason: `hermes_status_${response.status}` };
    }

    return { delivered: true };
  } catch (error) {
    log.warn('Hermes notification failed', { event, error: error.message });
    return { delivered: false, reason: error.message };
  } finally {
    clearTimeout(timeout);
  }
}

module.exports = { ingestMarketplaceLead, notifyHermes, normalizeMarketplacePayload };
