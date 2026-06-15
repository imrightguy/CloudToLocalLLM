// ─── Departure / Arrival Photos Service ───
// Stores the move-out / move-in état des lieux photos (or photo-request
// placeholders) created by PlexFlow webhooks and uploaded by tenants.

const {
  eq, and, desc, sql,
} = require('drizzle-orm');
const { db } = require('../database/connection');
const { departurePhotosTable } = require('../database/schema');

const VALID_EVENT_TYPES = ['departure', 'arrival'];

/**
 * List photos with optional filters and pagination.
 * @param {object} filters - page, limit, buildingId, unitId, eventType
 */
async function listPhotos({
  page = 1,
  limit = 50,
  buildingId,
  unitId,
  eventType,
} = {}) {
  const validPage = Math.max(1, parseInt(page, 10) || 1);
  const validLimit = Math.min(200, Math.max(1, parseInt(limit, 10) || 50));
  const offset = (validPage - 1) * validLimit;

  const conditions = [eq(departurePhotosTable.isActive, true)];
  if (buildingId) {
    conditions.push(eq(departurePhotosTable.buildingId, buildingId));
  }
  if (unitId) {
    conditions.push(eq(departurePhotosTable.unitId, unitId));
  }
  if (eventType && VALID_EVENT_TYPES.includes(eventType)) {
    conditions.push(eq(departurePhotosTable.eventType, eventType));
  }

  const whereClause = and(...conditions);

  const [[{ count: total }], photos] = await Promise.all([
    db
      .select({ count: sql`count(*)::int` })
      .from(departurePhotosTable)
      .where(whereClause),
    db
      .select()
      .from(departurePhotosTable)
      .where(whereClause)
      .orderBy(desc(departurePhotosTable.createdAt))
      .limit(validLimit)
      .offset(offset),
  ]);

  const totalPages = Math.ceil(total / validLimit);

  return {
    photos,
    metadata: {
      total,
      page: validPage,
      limit: validLimit,
      totalPages,
      hasMore: validPage < totalPages,
    },
  };
}

async function getPhoto(id) {
  const [photo] = await db
    .select()
    .from(departurePhotosTable)
    .where(eq(departurePhotosTable.id, id))
    .limit(1);
  return photo || null;
}

/**
 * Create a photo (or photo-request placeholder) record.
 * @param {object} data - buildingId, unitId, tenantName, eventType, photoUrl, notes
 */
async function createPhoto(data = {}) {
  const eventType = VALID_EVENT_TYPES.includes(data.eventType) ? data.eventType : 'departure';

  const [photo] = await db
    .insert(departurePhotosTable)
    .values({
      buildingId: data.buildingId || null,
      unitId: data.unitId || null,
      tenantName: data.tenantName || null,
      eventType,
      photoUrl: data.photoUrl || null,
      notes: data.notes || null,
    })
    .returning();

  return photo;
}

async function deletePhoto(id) {
  const [photo] = await db
    .update(departurePhotosTable)
    .set({ isActive: false })
    .where(eq(departurePhotosTable.id, id))
    .returning();
  return photo || null;
}

module.exports = {
  VALID_EVENT_TYPES,
  listPhotos,
  getPhoto,
  createPhoto,
  deletePhoto,
};
