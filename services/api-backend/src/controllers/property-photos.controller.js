// ─── Property Photos Controller ───

const propertyPhotosService = require('../services/property-photos.service');
const { successResponse, paginatedResponse } = require('../utils/apiResponse');
const logger = require('../utils/logger');

/**
 * POST /property-photos/upload
 * Multipart: file + buildingId, unitId?, useCase, roomContext?, capturedAt?, displayOrder?
 */
exports.upload = async (req, res) => {
  const file = req.file;
  if (!file) {
    return res.status(400).json({ success: false, error: { message: 'Aucun fichier fourni', code: 'NO_FILE' } });
  }

  const { buildingId, unitId, useCase, roomContext, capturedAt, displayOrder, documentRefId, metadata } = req.body;

  if (!buildingId) {
    return res.status(400).json({ success: false, error: { message: 'buildingId requis', code: 'MISSING_BUILDING_ID' } });
  }

  const photo = await propertyPhotosService.uploadPhoto(file, {
    companyId: req.user?.companyId || 'default',
    buildingId,
    unitId: unitId || null,
    useCase: useCase || 'general',
    roomContext: roomContext || null,
    capturedAt: capturedAt || null,
    displayOrder: parseInt(displayOrder) || 0,
    documentRefId: documentRefId || null,
    metadata: metadata ? (typeof metadata === 'string' ? JSON.parse(metadata) : metadata) : {},
    userId: req.user?.id || null,
  });

  return successResponse(res, photo, 201);
};

/**
 * GET /property-photos/building/:buildingId
 */
exports.getByBuilding = async (req, res) => {
  const { buildingId } = req.params;
  const { useCase, unitId, page, limit } = req.query;

  const result = await propertyPhotosService.getPhotosByBuilding(buildingId, {
    useCase,
    unitId,
    page: parseInt(page) || 1,
    limit: parseInt(limit) || 50,
  });

  return paginatedResponse(res, result.photos, result.total, result.page, result.limit);
};

/**
 * GET /property-photos/unit/:unitId
 */
exports.getByUnit = async (req, res) => {
  const { unitId } = req.params;
  const { page, limit } = req.query;

  const result = await propertyPhotosService.getPhotosByUnit(unitId, {
    page: parseInt(page) || 1,
    limit: parseInt(limit) || 50,
  });

  return paginatedResponse(res, result.photos, result.total, result.page, result.limit);
};

/**
 * DELETE /property-photos/:id
 */
exports.delete = async (req, res) => {
  const { id } = req.params;
  const photo = await propertyPhotosService.deletePhoto(id);
  if (!photo) {
    return res.status(404).json({ success: false, error: { message: 'Photo introuvable', code: 'NOT_FOUND' } });
  }
  return successResponse(res, photo);
};

/**
 * PATCH /property-photos/:id
 */
exports.update = async (req, res) => {
  const { id } = req.params;
  const photo = await propertyPhotosService.updatePhoto(id, req.body);
  if (!photo) {
    return res.status(404).json({ success: false, error: { message: 'Photo introuvable', code: 'NOT_FOUND' } });
  }
  return successResponse(res, photo);
};
