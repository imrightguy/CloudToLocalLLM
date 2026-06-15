const {
  eq, and, desc, ilike, inArray, sql,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const { maintenanceTicketsTable, unitsTable, buildingsTable } = require('../database/schema');
const logger = require('../utils/logger');
const notificationService = require('./notification.service');

const VALID_URGENCIES = ['basse', 'moyenne', 'haute', 'urgence'];
const VALID_STATUSES = ['ouvert', 'en_cours', 'resolu'];

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

async function lookupTenantByPhone(phone) {
  const normalized = normalizePhone(phone);
  if (!normalized) {
    return null;
  }

  const units = await db
    .select({
      id: unitsTable.id,
      buildingId: unitsTable.buildingId,
      tenantName: unitsTable.tenantName,
      tenantPhone: unitsTable.tenantPhone,
    })
    .from(unitsTable)
    .where(and(
      eq(unitsTable.isActive, true),
      sql`${unitsTable.tenantPhone} IS NOT NULL`,
    ));

  const match = units.find((unit) => normalizePhone(unit.tenantPhone) === normalized);
  if (!match) {
    return null;
  }

  return {
    unitId: match.id,
    buildingId: match.buildingId,
    tenantName: match.tenantName,
  };
}

async function listTickets({
  page = 1,
  limit = 20,
  status,
  urgency,
  buildingId,
  search,
} = {}) {
  const validPage = Math.max(1, parseInt(page, 10) || 1);
  const validLimit = Math.min(100, Math.max(1, parseInt(limit, 10) || 20));
  const offset = (validPage - 1) * validLimit;

  const conditions = [eq(maintenanceTicketsTable.isActive, true)];
  if (status) {
    conditions.push(eq(maintenanceTicketsTable.status, status));
  }
  if (urgency) {
    conditions.push(eq(maintenanceTicketsTable.urgency, urgency));
  }
  if (buildingId) {
    conditions.push(eq(maintenanceTicketsTable.buildingId, buildingId));
  }
  if (search) {
    conditions.push(ilike(maintenanceTicketsTable.title, `%${search}%`));
  }

  const whereClause = and(...conditions);

  const [[{ count: total }], tickets] = await Promise.all([
    db
      .select({ count: sql`count(*)::int` })
      .from(maintenanceTicketsTable)
      .where(whereClause),
    db
      .select()
      .from(maintenanceTicketsTable)
      .where(whereClause)
      .orderBy(desc(maintenanceTicketsTable.createdAt))
      .limit(validLimit)
      .offset(offset),
  ]);

  const totalPages = Math.ceil(total / validLimit);

  return {
    tickets,
    metadata: {
      total,
      page: validPage,
      limit: validLimit,
      totalPages,
      hasMore: validPage < totalPages,
    },
  };
}

async function getTicket(id) {
  const [ticket] = await db
    .select()
    .from(maintenanceTicketsTable)
    .where(eq(maintenanceTicketsTable.id, id))
    .limit(1);
  return ticket || null;
}

async function createTicket(data = {}) {
  const urgency = VALID_URGENCIES.includes(data.urgency) ? data.urgency : 'moyenne';
  const status = VALID_STATUSES.includes(data.status) ? data.status : 'ouvert';

  let { unitId, buildingId, tenantName } = data;
  if (data.callerPhone && (!unitId || !buildingId)) {
    const tenant = await lookupTenantByPhone(data.callerPhone);
    if (tenant) {
      unitId = unitId || tenant.unitId;
      buildingId = buildingId || tenant.buildingId;
      tenantName = tenantName || tenant.tenantName;
    }
  }

  const [ticket] = await db
    .insert(maintenanceTicketsTable)
    .values({
      title: data.title,
      description: data.description || null,
      urgency,
      status,
      source: data.source || 'manual',
      tenantId: data.tenantId || null,
      tenantName: tenantName || null,
      callerPhone: data.callerPhone || null,
      unitId: unitId || null,
      buildingId: buildingId || null,
      photos: data.photos || [],
      vapiCallId: data.vapiCallId || null,
    })
    .returning();

  // Notifier les admins en temps réel pour les tickets créés par Voice AI.
  if (data.source === 'voice_ai') {
    notificationService
      .notifyNewMaintenanceTicket(ticket)
      .catch((err) => logger.warn('[maintenance.service] Échec notification:', err.message));
  }

  return ticket;
}

async function updateTicket(id, data = {}) {
  const updateData = { updatedAt: new Date() };
  if (data.title !== undefined) {
    updateData.title = data.title;
  }
  if (data.description !== undefined) {
    updateData.description = data.description || null;
  }
  if (data.urgency !== undefined) {
    updateData.urgency = data.urgency;
  }
  if (data.status !== undefined) {
    updateData.status = data.status;
    updateData.resolvedAt = data.status === 'resolu' ? new Date() : null;
  }
  if (data.tenantName !== undefined) {
    updateData.tenantName = data.tenantName || null;
  }
  if (data.unitId !== undefined) {
    updateData.unitId = data.unitId || null;
  }
  if (data.buildingId !== undefined) {
    updateData.buildingId = data.buildingId || null;
  }
  if (data.photos !== undefined) {
    updateData.photos = data.photos || [];
  }
  if (data.isActive !== undefined) {
    updateData.isActive = data.isActive;
  }

  const [ticket] = await db
    .update(maintenanceTicketsTable)
    .set(updateData)
    .where(eq(maintenanceTicketsTable.id, id))
    .returning();

  return ticket || null;
}

function mapUrgencyFromVapi(payload) {
  const raw = (payload.urgency || payload.priority || '').toString().toLowerCase();
  if (['urgence', 'emergency', 'critical'].includes(raw)) {
    return 'urgence';
  }
  if (['haute', 'high'].includes(raw)) {
    return 'haute';
  }
  if (['basse', 'low'].includes(raw)) {
    return 'basse';
  }
  return 'moyenne';
}

async function ingestVapiWebhook(payload = {}) {
  const message = payload.message || payload;
  const call = message.call || payload.call || {};
  const analysis = message.analysis || payload.analysis || {};

  const callerPhone = payload.callerPhone
    || call.customer?.number
    || message.customer?.number
    || payload.from
    || null;

  const title = payload.title
    || analysis.summary
    || message.summary
    || payload.summary
    || 'Demande de maintenance (Vapi)';

  const description = payload.description
    || analysis.transcript
    || message.transcript
    || payload.transcript
    || null;

  const vapiCallId = call.id || message.callId || payload.callId || null;

  if (vapiCallId) {
    const [existing] = await db
      .select({ id: maintenanceTicketsTable.id })
      .from(maintenanceTicketsTable)
      .where(eq(maintenanceTicketsTable.vapiCallId, vapiCallId))
      .limit(1);
    if (existing) {
      return { ticket: await getTicket(existing.id), created: false };
    }
  }

  const ticket = await createTicket({
    title: String(title).slice(0, 255),
    description,
    urgency: mapUrgencyFromVapi(payload),
    source: 'vapi',
    callerPhone,
    vapiCallId,
  });

  return { ticket, created: true };
}

async function getOpenTicketCountByBuilding(buildingIds = []) {
  if (!Array.isArray(buildingIds) || buildingIds.length === 0) {
    return {};
  }
  try {
    const rows = await db
      .select({
        buildingId: maintenanceTicketsTable.buildingId,
        count: sql`count(*)::int`,
      })
      .from(maintenanceTicketsTable)
      .where(and(
        eq(maintenanceTicketsTable.isActive, true),
        inArray(maintenanceTicketsTable.status, ['ouvert', 'en_cours']),
        inArray(maintenanceTicketsTable.buildingId, buildingIds),
      ))
      .groupBy(maintenanceTicketsTable.buildingId);

    return rows.reduce((acc, row) => {
      acc[row.buildingId] = Number(row.count);
      return acc;
    }, {});
  } catch (error) {
    logger.error('[maintenance.service] getOpenTicketCountByBuilding error:', error);
    return {};
  }
}

/**
 * Regroupe les tickets ouverts (statut 'ouvert' ou 'en_cours') par bâtiment,
 * avec le nom du bâtiment et la répartition par urgence. Utilisé par le
 * tableau de bord (« Tickets par bâtiment »).
 * @returns {Promise<Array<{
 *   buildingId: string|null,
 *   buildingName: string,
 *   total: number,
 *   urgence: number, haute: number, moyenne: number, basse: number
 * }>>}
 */
async function getOpenTicketBreakdownByBuilding() {
  try {
    const rows = await db
      .select({
        buildingId: maintenanceTicketsTable.buildingId,
        buildingName: buildingsTable.name,
        urgency: maintenanceTicketsTable.urgency,
        count: sql`count(*)::int`,
      })
      .from(maintenanceTicketsTable)
      .leftJoin(buildingsTable, eq(maintenanceTicketsTable.buildingId, buildingsTable.id))
      .where(and(
        eq(maintenanceTicketsTable.isActive, true),
        inArray(maintenanceTicketsTable.status, ['ouvert', 'en_cours']),
      ))
      .groupBy(
        maintenanceTicketsTable.buildingId,
        buildingsTable.name,
        maintenanceTicketsTable.urgency,
      );

    const byBuilding = new Map();
    for (const row of rows) {
      const key = row.buildingId || 'unassigned';
      if (!byBuilding.has(key)) {
        byBuilding.set(key, {
          buildingId: row.buildingId || null,
          buildingName: row.buildingName || (row.buildingId ? '—' : 'Non assigné'),
          total: 0,
          urgence: 0,
          haute: 0,
          moyenne: 0,
          basse: 0,
        });
      }
      const entry = byBuilding.get(key);
      const count = Number(row.count) || 0;
      entry.total += count;
      if (VALID_URGENCIES.includes(row.urgency)) {
        entry[row.urgency] += count;
      } else {
        entry.moyenne += count;
      }
    }

    return Array.from(byBuilding.values()).sort((a, b) => b.total - a.total);
  } catch (error) {
    logger.error('[maintenance.service] getOpenTicketBreakdownByBuilding error:', error);
    return [];
  }
}

module.exports = {
  VALID_URGENCIES,
  VALID_STATUSES,
  normalizePhone,
  lookupTenantByPhone,
  listTickets,
  getTicket,
  createTicket,
  updateTicket,
  ingestVapiWebhook,
  getOpenTicketCountByBuilding,
  getOpenTicketBreakdownByBuilding,
};
