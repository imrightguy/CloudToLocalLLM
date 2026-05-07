const Joi = require('joi');

const VALID_CHECKLIST_TYPES = ['move_in', 'move_out'];
const VALID_SESSION_STATUSES = ['draft', 'in_progress', 'paused', 'awaiting_confirmation', 'completed', 'reviewed', 'archived'];
const VALID_STEP_STATUSES = ['pending', 'completed', 'blocked', 'skipped'];
const VALID_SIGNATURE_TYPES = ['tenant_confirmation', 'manager_confirmation', 'key_handoff'];
const VALID_SIGNATURE_METHODS = ['typed', 'drawn', 'captured_photo', 'verified'];
const VALID_EVENT_TYPES = [
  'session_started',
  'session_resumed',
  'session_paused',
  'session_submitted',
  'step_completed',
  'step_blocked',
  'attachment_added',
  'signature_recorded',
];

const MOVE_IN_STEPS = [
  {
    stepKey: 'identity_unit_confirmation',
    stepOrder: 1,
    title: 'Confirmation de l’unité',
    description: 'Confirmer l’identité du locataire et l’unité concernée.',
    requiredFields: ['tenantName', 'unitLabel'],
  },
  {
    stepKey: 'unit_condition',
    stepOrder: 2,
    title: 'État de l’unité',
    description: 'Décrire l’état général au moment de la remise des clés.',
    requiredFields: ['notes'],
  },
  {
    stepKey: 'room_photos',
    stepOrder: 3,
    title: 'Photos de l’unité',
    description: 'Ajouter des photos des pièces importantes et des éléments notables.',
    requiredFields: ['attachments'],
  },
  {
    stepKey: 'key_handoff',
    stepOrder: 4,
    title: 'Remise des clés',
    description: 'Confirmer la remise des clés, télécommandes ou accès spéciaux.',
    requiredFields: ['confirmation'],
  },
  {
    stepKey: 'final_acknowledgment',
    stepOrder: 5,
    title: 'Confirmation finale',
    description: 'Confirmer que la checklist peut être transmise au gestionnaire.',
    requiredFields: ['signature'],
  },
];

const MOVE_OUT_STEPS = [
  {
    stepKey: 'identity_unit_confirmation',
    stepOrder: 1,
    title: 'Confirmation de l’unité',
    description: 'Confirmer l’identité du locataire et l’unité quittée.',
    requiredFields: ['tenantName', 'unitLabel'],
  },
  {
    stepKey: 'unit_condition',
    stepOrder: 2,
    title: 'État à la sortie',
    description: 'Décrire l’état de l’unité au moment du retour.',
    requiredFields: ['notes'],
  },
  {
    stepKey: 'room_photos',
    stepOrder: 3,
    title: 'Photos de sortie',
    description: 'Ajouter des photos des pièces importantes et des dommages visibles.',
    requiredFields: ['attachments'],
  },
  {
    stepKey: 'key_return',
    stepOrder: 4,
    title: 'Retour des clés',
    description: 'Confirmer le retour des clés, télécommandes ou accès spéciaux.',
    requiredFields: ['confirmation'],
  },
  {
    stepKey: 'damage_notes',
    stepOrder: 5,
    title: 'Notes sur les dommages',
    description: 'Indiquer les dommages, manques ou éléments à suivre.',
    requiredFields: ['notes'],
  },
  {
    stepKey: 'final_acknowledgment',
    stepOrder: 6,
    title: 'Confirmation finale',
    description: 'Confirmer que la checklist peut être transmise au gestionnaire.',
    requiredFields: ['signature'],
  },
];

const buildChecklistTemplate = (checklistType) => {
  const template = checklistType === 'move_out' ? MOVE_OUT_STEPS : MOVE_IN_STEPS;
  return template.map((step) => ({
    ...step,
    status: 'pending',
    metadata: {},
  }));
};

const tenantChecklistStartSchema = Joi.object({
  unitId: Joi.string().uuid().required(),
  leaseId: Joi.string().uuid().allow(null, ''),
  checklistType: Joi.string().valid(...VALID_CHECKLIST_TYPES).required(),
  tenantName: Joi.string().trim().max(255).allow(null, ''),
  tenantPhone: Joi.string().trim().max(50).allow(null, ''),
  metadata: Joi.object().default({}),
});

const tenantChecklistResumeSchema = Joi.object({
  resumedByUserId: Joi.string().uuid().allow(null, ''),
  metadata: Joi.object().default({}),
});

const tenantChecklistPauseSchema = Joi.object({
  reason: Joi.string().trim().max(1000).allow(null, ''),
  pausedByUserId: Joi.string().uuid().allow(null, ''),
  metadata: Joi.object().default({}),
});

const checklistStepUpdateSchema = Joi.object({
  stepKey: Joi.string().trim().max(100).required(),
  status: Joi.string().valid(...VALID_STEP_STATUSES).required(),
  notes: Joi.string().trim().max(5000).allow(null, ''),
  blockedReason: Joi.string().trim().max(1000).allow(null, ''),
  metadata: Joi.object().default({}),
});

const checklistAttachmentSchema = Joi.object({
  stepKey: Joi.string().trim().max(100).required(),
  documentRefId: Joi.string().trim().max(255).allow(null, ''),
  fileName: Joi.string().trim().max(255).allow(null, ''),
  mimeType: Joi.string().trim().max(100).allow(null, ''),
  url: Joi.string().trim().uri({ scheme: ['http', 'https'] }).allow(null, ''),
  caption: Joi.string().trim().max(1000).allow(null, ''),
  takenAt: Joi.date().iso().allow(null),
  metadata: Joi.object().default({}),
});

const checklistSignatureSchema = Joi.object({
  signatureType: Joi.string().valid(...VALID_SIGNATURE_TYPES).required(),
  signerName: Joi.string().trim().max(255).allow(null, ''),
  signerRole: Joi.string().trim().max(100).allow(null, ''),
  method: Joi.string().valid(...VALID_SIGNATURE_METHODS).default('typed'),
  signedAt: Joi.date().iso().allow(null),
  signatureData: Joi.object().default({}),
  metadata: Joi.object().default({}),
});

const tenantChecklistSubmitSchema = Joi.object({
  submittedByUserId: Joi.string().uuid().allow(null, ''),
  confirmationNote: Joi.string().trim().max(2000).allow(null, ''),
  forceComplete: Joi.boolean().default(false),
  stepUpdates: Joi.array().items(checklistStepUpdateSchema).default([]),
  attachments: Joi.array().items(checklistAttachmentSchema).default([]),
  signatures: Joi.array().items(checklistSignatureSchema).default([]),
  metadata: Joi.object().default({}),
});

const tenantChecklistSummaryParamsSchema = Joi.object({
  id: Joi.string().uuid().required(),
});

module.exports = {
  VALID_CHECKLIST_TYPES,
  VALID_SESSION_STATUSES,
  VALID_STEP_STATUSES,
  VALID_SIGNATURE_TYPES,
  VALID_SIGNATURE_METHODS,
  VALID_EVENT_TYPES,
  buildChecklistTemplate,
  tenantChecklistStartSchema,
  tenantChecklistResumeSchema,
  tenantChecklistPauseSchema,
  tenantChecklistSubmitSchema,
  tenantChecklistSummaryParamsSchema,
};
