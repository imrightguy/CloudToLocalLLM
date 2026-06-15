const { eq, and, asc, desc, sql } = require('drizzle-orm');
const { db } = require('../database/connection');
const { buildingsTable, unitsTable, propertyPhotosTable } = require('../database/schema');

const createError = (statusCode, code, message) => {
  const error = new Error(message);
  error.statusCode = statusCode;
  error.code = code;
  return error;
};

const fetchOne = async (query) => {
  const rows = await query.limit(1);
  return rows[0] || null;
};

const ensureBuildingExists = async (buildingId) => {
  const building = await fetchOne(
    db.select().from(buildingsTable).where(eq(buildingsTable.id, buildingId)),
  );

  if (!building) {
    throw createError(404, 'PHOTO_BUILDING_NOT_FOUND', 'Building not found');
  }

  return building;
};

const ensureUnitMatchesBuilding = async (unitId, buildingId) => {
  if (!unitId) {
    return null;
  }

  const unit = await fetchOne(
    db.select().from(unitsTable).where(eq(unitsTable.id, unitId)),
  );

  if (!unit) {
    throw createError(404, 'PHOTO_UNIT_NOT_FOUND', 'Unit not found');
  }

  if (unit.buildingId !== buildingId) {
    throw createError(409, 'PHOTO_UNIT_BUILDING_MISMATCH', 'Unit must belong to the same building as the photo record');
  }

  return unit;
};

const buildPhotoFilters = ({ companyId, buildingId, unitId, useCase, roomContext, includeInactive }) => {
  const conditions = [eq(propertyPhotosTable.companyId, companyId)];

  if (!includeInactive) {
    conditions.push(eq(propertyPhotosTable.isActive, true));
  }

  if (buildingId) {
    conditions.push(eq(propertyPhotosTable.buildingId, buildingId));
  }

  if (unitId) {
    conditions.push(eq(propertyPhotosTable.unitId, unitId));
  }

  if (useCase) {
    conditions.push(eq(propertyPhotosTable.useCase, useCase));
  }

  if (roomContext) {
    conditions.push(eq(propertyPhotosTable.roomContext, roomContext));
  }

  return conditions;
};

const listPropertyPhotos = async ({
  companyId,
  buildingId = null,
  unitId = null,
  useCase = null,
  roomContext = null,
  includeInactive = false,
  page = 1,
  limit = 20,
}) => {
  const offset = (page - 1) * limit;
  const conditions = buildPhotoFilters({ companyId, buildingId, unitId, useCase, roomContext, includeInactive });

  const [{ count: total }] = await db.select({ count: sql`count(*)::int` })
    .from(propertyPhotosTable)
    .where(and(...conditions));

  const rows = await db.select()
    .from(propertyPhotosTable)
    .where(and(...conditions))
    .orderBy(
      asc(propertyPhotosTable.displayOrder),
      asc(propertyPhotosTable.capturedAt),
      desc(propertyPhotosTable.uploadedAt),
      desc(propertyPhotosTable.createdAt),
    )
    .limit(limit)
    .offset(offset);

  return {
    rows,
    metadata: {
      total,
      page,
      limit,
      totalPages: Math.ceil((total || 0) / limit) || 0,
      hasMore: page * limit < total,
    },
  };
};

const normalizeStorageFields = ({
  fileName,
  storedFileName = null,
  storageProvider = null,
  storageKey = null,
  storagePath = null,
  url,
}) => {
  const resolvedStoredFileName = storedFileName || fileName;
  const resolvedStorageProvider = storageProvider || (storagePath?.startsWith('/') ? 'local_fs' : 'external_url');
  const resolvedStorageKey = storageKey || resolvedStoredFileName;
  const resolvedStoragePath = storagePath || url;

  return {
    storedFileName: resolvedStoredFileName,
    storageProvider: resolvedStorageProvider,
    storageKey: resolvedStorageKey,
    storagePath: resolvedStoragePath,
  };
};

const createPropertyPhoto = async ({
  id = null,
  companyId,
  buildingId,
  unitId = null,
  roomContext = null,
  useCase,
  displayOrder = 0,
  fileName,
  storedFileName = null,
  storageProvider = null,
  storageKey = null,
  storagePath = null,
  fileSizeBytes = null,
  mimeType = null,
  url,
  documentRefId = null,
  capturedAt = null,
  uploadedByUserId = null,
  metadata = {},
}) => {
  await ensureBuildingExists(buildingId);
  await ensureUnitMatchesBuilding(unitId, buildingId);

  const storage = normalizeStorageFields({
    fileName,
    storedFileName,
    storageProvider,
    storageKey,
    storagePath,
    url,
  });

  const [row] = await db.insert(propertyPhotosTable).values({
    ...(id ? { id } : {}),
    companyId,
    buildingId,
    unitId,
    roomContext,
    useCase,
    displayOrder,
    fileName,
    storedFileName: storage.storedFileName,
    storageProvider: storage.storageProvider,
    storageKey: storage.storageKey,
    storagePath: storage.storagePath,
    fileSizeBytes,
    mimeType,
    url,
    documentRefId,
    capturedAt,
    uploadedAt: new Date(),
    uploadedByUserId,
    metadata,
    isActive: true,
  }).returning();

  return row;
};

const getPropertyPhotoById = async ({ companyId, photoId }) => {
  const photo = await fetchOne(
    db.select()
      .from(propertyPhotosTable)
      .where(and(
        eq(propertyPhotosTable.companyId, companyId),
        eq(propertyPhotosTable.id, photoId),
      )),
  );

  if (!photo) {
    throw createError(404, 'PHOTO_RECORD_NOT_FOUND', 'Photo record not found');
  }

  return photo;
};

const updatePropertyPhoto = async ({
  companyId,
  photoId,
  useCase,
  roomContext,
  displayOrder,
  caption,
  tags,
  metadata,
}) => {
  const existing = await getPropertyPhotoById({ companyId, photoId });

  const updates = { updatedAt: new Date() };
  if (useCase !== undefined) updates.useCase = useCase;
  if (roomContext !== undefined) updates.roomContext = roomContext || null;
  if (displayOrder !== undefined) updates.displayOrder = displayOrder;

  // caption + tags live inside the metadata jsonb; merge so we never drop
  // existing keys when only one is supplied.
  const hasMetaChange = caption !== undefined || tags !== undefined || metadata !== undefined;
  if (hasMetaChange) {
    updates.metadata = {
      ...(existing.metadata || {}),
      ...(metadata || {}),
      ...(caption !== undefined ? { caption: caption || null } : {}),
      ...(tags !== undefined ? { tags } : {}),
    };
  }

  const [row] = await db.update(propertyPhotosTable)
    .set(updates)
    .where(and(
      eq(propertyPhotosTable.companyId, companyId),
      eq(propertyPhotosTable.id, photoId),
    ))
    .returning();

  return row;
};

const deletePropertyPhoto = async ({ companyId, photoId }) => {
  await getPropertyPhotoById({ companyId, photoId });

  const [row] = await db.update(propertyPhotosTable)
    .set({ isActive: false, updatedAt: new Date() })
    .where(and(
      eq(propertyPhotosTable.companyId, companyId),
      eq(propertyPhotosTable.id, photoId),
    ))
    .returning();

  return row;
};

module.exports = {
  listPropertyPhotos,
  createPropertyPhoto,
  getPropertyPhotoById,
  updatePropertyPhoto,
  deletePropertyPhoto,
};
