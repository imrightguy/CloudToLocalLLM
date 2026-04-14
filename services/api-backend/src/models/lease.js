const Joi = require('joi');

const VALID_LEASE_STATUSES = ['draft', 'active', 'expired', 'terminated', 'renewed'];

const VALID_TRANSITIONS = {
  draft: ['active', 'terminated'],
  active: ['expired', 'terminated', 'renewed'],
  expired: ['renewed'],
  terminated: [],
  renewed: [],
};

const leaseSchema = Joi.object({
  unitId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': "L'identifiant de l'unité doit être un UUID valide",
      'any.required': "L'identifiant de l'unité est requis",
    }),

  leadId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': "L'identifiant du prospect doit être un UUID valide",
    }),

  tenantFirstName: Joi.string()
    .min(1)
    .max(200)
    .required()
    .messages({
      'string.min': 'Le prénom du locataire est requis',
      'string.max': 'Le prénom du locataire ne peut pas dépasser 200 caractères',
      'any.required': 'Le prénom du locataire est requis',
    }),

  tenantLastName: Joi.string()
    .min(1)
    .max(200)
    .required()
    .messages({
      'string.min': 'Le nom de famille du locataire est requis',
      'string.max': 'Le nom de famille du locataire ne peut pas dépasser 200 caractères',
      'any.required': 'Le nom de famille du locataire est requis',
    }),

  tenantEmail: Joi.string()
    .email()
    .optional()
    .allow(null, '')
    .messages({
      'string.email': 'Adresse courriel invalide',
    }),

  tenantPhone: Joi.string()
    .pattern(/^\+?[\d\s\-()]{7,20}$/)
    .optional()
    .allow(null, '')
    .messages({
      'string.pattern.base': 'Numéro de téléphone invalide',
    }),

  rent: Joi.number()
    .integer()
    .min(1)
    .max(100000)
    .required()
    .messages({
      'number.base': 'Le loyer doit être un nombre',
      'number.integer': 'Le loyer doit être un nombre entier',
      'number.min': 'Le loyer doit être supérieur à 0',
      'number.max': 'Le loyer ne peut pas dépasser 100 000 $ par mois',
    }),

  deposit: Joi.number()
    .integer()
    .min(0)
    .max(200000)
    .optional()
    .default(0)
    .messages({
      'number.base': 'Le dépôt de sécurité doit être un nombre',
      'number.integer': 'Le dépôt de sécurité doit être un nombre entier',
      'number.min': 'Le dépôt de sécurité ne peut pas être négatif',
    }),

  startDate: Joi.date()
    .iso()
    .required()
    .messages({
      'date.format': 'La date de début doit être une date ISO valide',
      'any.required': 'La date de début est requise',
    }),

  endDate: Joi.date()
    .iso()
    .greater(Joi.ref('startDate'))
    .required()
    .messages({
      'date.format': 'La date de fin doit être une date ISO valide',
      'date.greater': 'La date de fin doit être après la date de début',
      'any.required': 'La date de fin est requise',
    }),

  terms: Joi.object()
    .optional()
    .default({})
    .messages({
      'object.base': 'Les conditions doivent être un objet',
    }),
});

const updateLeaseSchema = Joi.object({
  tenantFirstName: Joi.string()
    .min(1)
    .max(200)
    .optional()
    .messages({
      'string.min': 'Le prénom du locataire est requis',
      'string.max': 'Le prénom du locataire ne peut pas dépasser 200 caractères',
    }),

  tenantLastName: Joi.string()
    .min(1)
    .max(200)
    .optional()
    .messages({
      'string.min': 'Le nom de famille du locataire est requis',
      'string.max': 'Le nom de famille du locataire ne peut pas dépasser 200 caractères',
    }),

  tenantEmail: Joi.string()
    .email()
    .optional()
    .allow(null, '')
    .messages({
      'string.email': 'Adresse courriel invalide',
    }),

  tenantPhone: Joi.string()
    .pattern(/^\+?[\d\s\-()]{7,20}$/)
    .optional()
    .allow(null, '')
    .messages({
      'string.pattern.base': 'Numéro de téléphone invalide',
    }),

  rent: Joi.number()
    .integer()
    .min(1)
    .max(100000)
    .optional()
    .messages({
      'number.base': 'Le loyer doit être un nombre',
      'number.integer': 'Le loyer doit être un nombre entier',
      'number.min': 'Le loyer doit être supérieur à 0',
    }),

  deposit: Joi.number()
    .integer()
    .min(0)
    .max(200000)
    .optional()
    .messages({
      'number.base': 'Le dépôt de sécurité doit être un nombre',
      'number.integer': 'Le dépôt de sécurité doit être un nombre entier',
      'number.min': 'Le dépôt de sécurité ne peut pas être négatif',
    }),

  startDate: Joi.date()
    .iso()
    .optional()
    .messages({
      'date.format': 'La date de début doit être une date ISO valide',
    }),

  endDate: Joi.date()
    .iso()
    .optional()
    .messages({
      'date.format': 'La date de fin doit être une date ISO valide',
    }),

  terms: Joi.object()
    .optional()
    .messages({
      'object.base': 'Les conditions doivent être un objet',
    }),
});

const leaseStatusSchema = Joi.object({
  status: Joi.string()
    .valid(...VALID_LEASE_STATUSES)
    .required()
    .messages({
      'any.only': "Le statut doit être l'un des suivants : brouillon, actif, expiré, résilié, renouvelé",
      'any.required': 'Le statut est requis',
    }),
});

module.exports = {
  leaseSchema,
  updateLeaseSchema,
  leaseStatusSchema,
  VALID_LEASE_STATUSES,
  VALID_TRANSITIONS,
};
