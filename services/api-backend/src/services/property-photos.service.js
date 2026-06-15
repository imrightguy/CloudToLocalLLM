// ─── Property Photos Service ───
// CRUD + upload pour les photos de bâtiments/logements.

const path = require('path');
const fs = require('fs/promises');
const crypto = require('crypto');
const logger = require('../utils/logger');
const { db } = require('../database/connection');
const { propertyPhotosTable, buildingsTable, unitsTable } = require('../database/schema');
const { eq, and, desc, asc, inArray } = require('drizzle-orm');

const UPLOAD_DIR = process.env.PHOTOS_UPLOAD_DIR || '/app/uploads/photos';
const ALLOWED_MIME = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'];
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB

async function ensureUploadDir() {
  await fs.mkdir(UPLOAD_DIR, { recursive: true });
}

/**
 * Upload une photo.
 * @param {object} file - { originalname, buffer, mimetype, size }
 * @param {object} metadata - { buildingId, unitId?, useCase, roomContext?, capturedAt?, companyId, userId }
 */
async function uploadPhoto(file, metadata) {
  await ensureUploadDir();

  if (!ALLOWED_MIME.includes(file.mimetype)) {
    throw Object.assign(new Error(`Format non supporté: ${file.mimetype}`), { statusCode: 400, code: 'INVALID_FILE_TYPE' });
  }
  if (file.size > MAX_FILE_SIZE) {
    throw Object.assign(new Error(`Fichier trop volumineux (max 10 MB)`), { statusCode: 400, code: 'FILE_TOO_LARGE' });
  }

  const ext = path.extname(file.originalname) || '.jpg';
  const storedName = `${crypto.randomUUID()}${ext}`;
  const filePath = path.join(UPLOAD_DIR, storedName);

  await fs.writeFile(filePath, file.buffer);

  const [photo] = await db.insert(propertyPhotosTable).values({
    companyId: metadata.companyId,
    buildingId: metadata.buildingId,
    unitId: metadata.unitId || null,
    roomContext: metadata.roomContext || null,
    useCase: metadata.useCase || 'general',
    displayOrder: metadata.displayOrder || 0,
    documentRefId: metadata.documentRefId || null,
    fileName: file.originalname,
    storedFileName: storedName,
    storageProvider: 'local',
    storageKey: storedName,
    storagePath: filePath,
    fileSizeBytes: file.size,
    mimeType: file.mimetype,
    url: `/uploads/photos/${storedName}`,
    capturedAt: metadata.capturedAt ? new Date(metadata.capturedAt) : null,
    metadata: metadata.metadata || {},
    uploadedByUserId: metadata.userId || null,
  }).returning();

  logger.info('[property-photos] uploaded', { id: photo.id, buildingId: metadata.buildingId, fileName: file.originalname });
  return photo;
}

/**
 * Liste les photos d'un bâtiment, avec filtres optionnels.
 */
async function getPhotosByBuilding(buildingId, { useCase, unitId, page = 1, limit = 50 } = {}) {
  const conditions = [
    eq(propertyPhotosTable.buildingId, buildingId),
    eq(propertyPhotosTable.isActive, true),
  ];
  if (useCase) conditions.push(eq(propertyPhotosTable.useCase, useCase));
  if (unitId) conditions.push(eq(propertyPhotosTable.unitId, unitId));

  const offset = (Math.max(1, page) - 1) * Math.min(100, Math.max(1, limit));
  const validLimit = Math.min(100, Math.max(1, limit));

  const photos = await db.select()
    .from(propertyPhotosTable)
    .where(and(...conditions))
    .orderBy(desc(propertyPhotosTable.capturedAt), desc(propertyPhotosTable.createdAt))
    .limit(validLimit)
    .offset(offset);

  const [{ count }] = await db.select({ count: propertyPhotosTable.id })
    .from(propertyPhotosTable)
    .where(and(...conditions));

  return { photos, total: Number(count), page, limit: validLimit };
}

/**
 * Photos d'un logement spécifique.
 */
async function getPhotosByUnit(unitId, { page = 1, limit = 50 } = {}) {
  const offset = (Math.max(1, page) - 1) * Math.min(100, Math.max(1, limit));
  const validLimit = Math.min(100, Math.max(1, limit));

  const photos = await db.select()
    .from(propertyPhotosTable)
    .where(and(eq(propertyPhotosTable.unitId, unitId), eq(propertyPhotosTable.isActive, true)))
    .orderBy(desc(propertyPhotosTable.capturedAt), desc(propertyPhotosTable.createdAt))
    .limit(validLimit)
    .offset(offset);

  const [{ count }] = await db.select({ count: propertyPhotosTable.id })
    .from(propertyPhotosTable)
    .where(and(eq(propertyPhotosTable.unitId, unitId), eq(propertyPhotosTable.isActive, true)));

  return { photos, total: Number(count), page, limit: validLimit };
}

/**
 * Soft-delete une photo.
 */
async function deletePhoto(id) {
  const [updated] = await db.update(propertyPhotosTable)
    .set({ isActive: false, updatedAt: new Date() })
    .where(eq(propertyPhotosTable.id, id))
    .returning();
  return updated;
}

/**
 * Met à jour les métadonnées d'une photo.
 */
async function updatePhoto(id, data) {
  const allowed = ['roomContext', 'useCase', 'displayOrder', 'capturedAt', 'metadata'];
  const setData = {};
  for (const key of allowed) {
    if (data[key] !== undefined) setData[key] = data[key];
  }
  setData.updatedAt = new Date();

  const [updated] = await db.update(propertyPhotosTable)
    .set(setData)
    .where(eq(propertyPhotosTable.id, id))
    .returning();
  return updated;
}

module.exports = { uploadPhoto, getPhotosByBuilding, getPhotosByUnit, deletePhoto, updatePhoto };
