const nodeCrypto = require('crypto');
const photoService = require('../services/photo.service');
const photoStorage = require('../services/photo-storage.service');
const { child } = require('../utils/logger');

const log = child({ controller: 'photo' });

const success = (res, data, message, metadata) => {
  const payload = { success: true, data, message };
  if (metadata) {
    payload.metadata = metadata;
  }
  return res.json(payload);
};

const error = (res, status, code, message) => res.status(status).json({
  success: false,
  error: { code, message },
});

const handleServiceError = (res, err, fallbackCode) => {
  const status = err.statusCode || 500;
  const code = err.code || fallbackCode;
  const message = err.message || 'Internal server error';

  if (status === 500) {
    log.error('Photo controller error', { error: message, code: code || fallbackCode });
  }

  return error(res, status, code, message);
};

const createDownloadUrl = (companyId, photoId) => `/api/companies/${companyId}/photos/${photoId}/file`;

const quoteFileName = (name) => String(name || 'photo')
  .replace(/\\/g, '_')
  .replace(/"/g, "'");

exports.listPropertyPhotos = async (req, res) => {
  try {
    const result = await photoService.listPropertyPhotos({
      companyId: req.params.companyId,
      buildingId: req.query.buildingId || null,
      unitId: req.query.unitId || null,
      useCase: req.query.useCase || null,
      roomContext: req.query.roomContext || null,
      includeInactive: req.query.includeInactive || false,
      page: req.query.page,
      limit: req.query.limit,
    });

    return success(res, result.rows, 'Photo records retrieved successfully', result.metadata);
  } catch (err) {
    return handleServiceError(res, err, 'PHOTO_RECORD_LIST_FAILED');
  }
};

exports.createPropertyPhoto = async (req, res) => {
  try {
    const created = await photoService.createPropertyPhoto({
      companyId: req.params.companyId,
      buildingId: req.body.buildingId,
      unitId: req.body.unitId || null,
      roomContext: req.body.roomContext || null,
      useCase: req.body.useCase,
      displayOrder: req.body.displayOrder,
      fileName: req.body.fileName,
      storedFileName: req.body.storedFileName || null,
      storageProvider: req.body.storageProvider || null,
      storageKey: req.body.storageKey || null,
      storagePath: req.body.storagePath || null,
      fileSizeBytes: req.body.fileSizeBytes ?? null,
      mimeType: req.body.mimeType || null,
      url: req.body.url,
      documentRefId: req.body.documentRefId || null,
      capturedAt: req.body.capturedAt || null,
      uploadedByUserId: req.user?.id || null,
      metadata: req.body.metadata || {},
    });

    return res.status(201).json({
      success: true,
      data: created,
      message: 'Photo record created successfully',
    });
  } catch (err) {
    return handleServiceError(res, err, 'PHOTO_RECORD_CREATE_FAILED');
  }
};

exports.uploadPropertyPhoto = async (req, res) => {
  let storedFile = null;

  try {
    if (!req.photoUpload) {
      throw Object.assign(new Error('Photo file is required'), {
        statusCode: 400,
        code: 'PHOTO_UPLOAD_FILE_REQUIRED',
      });
    }

    storedFile = await photoStorage.storePropertyPhotoFile({
      file: req.photoUpload,
      companyId: req.params.companyId,
      buildingId: req.body.buildingId,
      unitId: req.body.unitId || null,
      useCase: req.body.useCase,
    });

    const id = nodeCrypto.randomUUID();
    const url = createDownloadUrl(req.params.companyId, id);
    const created = await photoService.createPropertyPhoto({
      id,
      companyId: req.params.companyId,
      buildingId: req.body.buildingId,
      unitId: req.body.unitId || null,
      roomContext: req.body.roomContext || null,
      useCase: req.body.useCase,
      displayOrder: req.body.displayOrder,
      fileName: req.photoUpload.originalFilename || storedFile.originalFileName,
      storedFileName: storedFile.storedFileName,
      storageProvider: storedFile.storageProvider,
      storageKey: storedFile.storageKey,
      storagePath: storedFile.storagePath,
      fileSizeBytes: storedFile.fileSizeBytes,
      mimeType: storedFile.mimeType,
      url,
      documentRefId: req.body.documentRefId || null,
      capturedAt: req.body.capturedAt || null,
      uploadedByUserId: req.user?.id || null,
      metadata: req.body.metadata || {},
    });

    return res.status(201).json({
      success: true,
      data: created,
      message: 'Photo file uploaded successfully',
    });
  } catch (err) {
    if (storedFile?.storagePath) {
      await photoStorage.deleteStoredPropertyPhotoFile(storedFile.storagePath).catch((cleanupError) => {
        log.warn('Failed to clean up photo file after upload error', {
          storagePath: storedFile.storagePath,
          error: cleanupError.message,
        });
      });
    }

    return handleServiceError(res, err, 'PHOTO_FILE_UPLOAD_FAILED');
  }
};

exports.updatePropertyPhoto = async (req, res) => {
  try {
    const updated = await photoService.updatePropertyPhoto({
      companyId: req.params.companyId,
      photoId: req.params.photoId,
      useCase: req.body.useCase,
      roomContext: req.body.roomContext,
      displayOrder: req.body.displayOrder,
      caption: req.body.caption,
      tags: req.body.tags,
      metadata: req.body.metadata,
    });

    return success(res, updated, 'Photo record updated successfully');
  } catch (err) {
    return handleServiceError(res, err, 'PHOTO_RECORD_UPDATE_FAILED');
  }
};

exports.deletePropertyPhoto = async (req, res) => {
  try {
    const removed = await photoService.deletePropertyPhoto({
      companyId: req.params.companyId,
      photoId: req.params.photoId,
    });

    return success(res, removed, 'Photo record deleted successfully');
  } catch (err) {
    return handleServiceError(res, err, 'PHOTO_RECORD_DELETE_FAILED');
  }
};

exports.downloadPropertyPhotoFile = async (req, res) => {
  try {
    const photo = await photoService.getPropertyPhotoById({
      companyId: req.params.companyId,
      photoId: req.params.photoId,
    });

    if (!photo.storagePath) {
      throw Object.assign(new Error('Stored photo file path is missing'), {
        statusCode: 500,
        code: 'PHOTO_STORAGE_PATH_MISSING',
      });
    }

    await new Promise((resolve, reject) => {
      res.type(photo.mimeType || 'application/octet-stream');
      res.setHeader('Content-Disposition', `inline; filename="${quoteFileName(photo.fileName)}"`);
      res.sendFile(photo.storagePath, (sendFileError) => {
        if (sendFileError) {
          reject(sendFileError);
          return;
        }
        resolve();
      });
    });
  } catch (err) {
    return handleServiceError(res, err, 'PHOTO_FILE_DOWNLOAD_FAILED');
  }
};
