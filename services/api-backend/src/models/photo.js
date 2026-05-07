const Joi = require('joi');

const VALID_PHOTO_USE_CASES = ['maintenance', 'marketing', 'inventory'];

const photoRecordCreateSchema = Joi.object({
  buildingId: Joi.string().uuid().required(),
  unitId: Joi.string().uuid().allow(null),
  roomContext: Joi.string().trim().max(120).allow(null, ''),
  useCase: Joi.string().valid(...VALID_PHOTO_USE_CASES).required(),
  displayOrder: Joi.number().integer().min(0).default(0),
  fileName: Joi.string().trim().min(1).max(255).required(),
  storedFileName: Joi.string().trim().min(1).max(255),
  storageProvider: Joi.string().trim().max(50),
  storageKey: Joi.string().trim().min(1).max(1024),
  storagePath: Joi.string().trim().min(1).max(1024),
  fileSizeBytes: Joi.number().integer().min(0).allow(null),
  mimeType: Joi.string().trim().max(120).allow(null, ''),
  url: Joi.string().uri().required(),
  documentRefId: Joi.string().trim().max(255).allow(null, ''),
  capturedAt: Joi.date().iso().allow(null),
  metadata: Joi.object().default({}),
});

const photoRecordUploadSchema = Joi.object({
  buildingId: Joi.string().uuid().required(),
  unitId: Joi.string().uuid().allow(null),
  roomContext: Joi.string().trim().max(120).allow(null, ''),
  useCase: Joi.string().valid(...VALID_PHOTO_USE_CASES).required(),
  displayOrder: Joi.number().integer().min(0).default(0),
  documentRefId: Joi.string().trim().max(255).allow(null, ''),
  capturedAt: Joi.date().iso().allow(null),
  metadata: Joi.object().default({}),
});

const photoRecordListQuerySchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
  buildingId: Joi.string().uuid(),
  unitId: Joi.string().uuid(),
  useCase: Joi.string().valid(...VALID_PHOTO_USE_CASES),
  roomContext: Joi.string().trim().max(120),
  includeInactive: Joi.boolean().default(false),
});

module.exports = {
  VALID_PHOTO_USE_CASES,
  photoRecordCreateSchema,
  photoRecordUploadSchema,
  photoRecordListQuerySchema,
};
