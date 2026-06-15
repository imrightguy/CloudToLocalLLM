const Joi = require('joi');

// Original ops use cases + field-survey categories (acquisition / renovation /
// relocation / état des lieux). Adding values is backwards-compatible — existing
// rows ('maintenance', 'marketing', 'inventory') stay valid.
const VALID_PHOTO_USE_CASES = [
  'maintenance',
  'marketing',
  'inventory',
  'exterior',
  'interior',
  'renovation',
  'departure',
  'arrival',
  'general',
];

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

// Metadata update — caption + tags live in the metadata jsonb so we can reuse
// the existing table without a migration.
const photoRecordUpdateSchema = Joi.object({
  useCase: Joi.string().valid(...VALID_PHOTO_USE_CASES),
  roomContext: Joi.string().trim().max(120).allow(null, ''),
  displayOrder: Joi.number().integer().min(0),
  caption: Joi.string().trim().max(500).allow(null, ''),
  tags: Joi.array().items(Joi.string().trim().max(60)).max(30),
  metadata: Joi.object(),
}).min(1);

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
  photoRecordUpdateSchema,
  photoRecordListQuerySchema,
};
