const fs = require('fs/promises');
const path = require('path');
const nodeCrypto = require('crypto');

const DEFAULT_STORAGE_ROOT = path.resolve(__dirname, '..', '..', 'data', 'property-photos');
const STORAGE_PROVIDER = 'local_fs';

const getPropertyPhotoStorageRoot = () => (
  process.env.PROPERTY_PHOTO_STORAGE_DIR
    ? path.resolve(process.env.PROPERTY_PHOTO_STORAGE_DIR)
    : DEFAULT_STORAGE_ROOT
);

const sanitizeSegment = (value, fallback = 'photo') => {
  const cleaned = String(value || fallback)
    .trim()
    .replace(/[^a-zA-Z0-9._-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^[-._]+|[-._]+$/g, '');

  return cleaned || fallback;
};

const buildStorageKey = ({ companyId, buildingId, unitId = null, useCase, storedFileName }) => {
  const unitSegment = unitId ? `units/${sanitizeSegment(unitId, 'unit')}` : 'units/unassigned';
  return [
    sanitizeSegment(companyId, 'company'),
    'buildings',
    sanitizeSegment(buildingId, 'building'),
    unitSegment,
    sanitizeSegment(useCase, 'general'),
    storedFileName,
  ].join('/');
};

const storePropertyPhotoFile = async ({
  file,
  companyId,
  buildingId,
  unitId = null,
  useCase,
}) => {
  if (!file || !file.filepath) {
    const error = new Error('Photo file is required');
    error.statusCode = 400;
    error.code = 'PHOTO_UPLOAD_FILE_REQUIRED';
    throw error;
  }

  const originalFileName = sanitizeSegment(
    file.originalFilename || file.newFilename || 'photo',
    'photo',
  );
  const extension = path.extname(file.originalFilename || file.newFilename || '');
  const storedFileName = `${originalFileName}-${nodeCrypto.randomUUID()}${extension}`;
  const storageKey = buildStorageKey({
    companyId,
    buildingId,
    unitId,
    useCase,
    storedFileName,
  });
  const storageRoot = getPropertyPhotoStorageRoot();
  const storagePath = path.join(storageRoot, storageKey);

  await fs.mkdir(path.dirname(storagePath), { recursive: true });
  await fs.copyFile(file.filepath, storagePath);

  const fileStats = await fs.stat(storagePath);

  return {
    storageProvider: STORAGE_PROVIDER,
    storageRoot,
    storageKey,
    storagePath,
    storedFileName,
    originalFileName: file.originalFilename || file.newFilename || 'photo',
    mimeType: file.mimetype || file.mimeType || 'application/octet-stream',
    fileSizeBytes: Number.isFinite(file.size) ? file.size : fileStats.size,
  };
};

const deleteStoredPropertyPhotoFile = async (storagePath) => {
  if (!storagePath) {
    return false;
  }

  try {
    await fs.unlink(storagePath);
    return true;
  } catch (error) {
    if (error.code === 'ENOENT') {
      return false;
    }
    throw error;
  }
};

module.exports = {
  STORAGE_PROVIDER,
  getPropertyPhotoStorageRoot,
  storePropertyPhotoFile,
  deleteStoredPropertyPhotoFile,
};
