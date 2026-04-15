const Joi = require('joi');

const VALID_RENEWAL_STATUSES = ['pending', 'sent', 'accepted', 'declined', 'expired'];
const VALID_RENEWAL_CHANNELS = ['sms', 'email', 'both'];

const VALID_RENEWAL_TRANSITIONS = {
  pending: ['sent', 'expired'],
  sent: ['accepted', 'declined', 'expired'],
  accepted: [],
  declined: [],
  expired: [],
};

const renewalOfferSchema = Joi.object({
  leaseId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': "L'identifiant du bail doit être un UUID valide",
      'any.required': "L'identifiant du bail est requis",
    }),

  newStartDate: Joi.date()
    .iso()
    .required()
    .messages({
      'date.format': 'La nouvelle date de début doit être une date ISO valide',
      'any.required': 'La nouvelle date de début est requise',
    }),

  newEndDate: Joi.date()
    .iso()
    .greater(Joi.ref('newStartDate'))
    .required()
    .messages({
      'date.format': 'La nouvelle date de fin doit être une date ISO valide',
      'date.greater': 'La nouvelle date de fin doit être après la nouvelle date de début',
      'any.required': 'La nouvelle date de fin est requise',
    }),

  newRent: Joi.number()
    .positive()
    .max(1000000)
    .required()
    .messages({
      'number.base': 'Le nouveau loyer doit être un nombre',
      'number.positive': 'Le nouveau loyer doit être supérieur à 0',
      'number.max': 'Le nouveau loyer ne peut pas dépasser 10 000 $',
      'any.required': 'Le nouveau loyer est requis',
    }),

  newDeposit: Joi.number()
    .integer()
    .min(0)
    .max(200000)
    .optional()
    .default(0)
    .messages({
      'number.base': 'Le nouveau dépôt doit être un nombre',
      'number.min': 'Le nouveau dépôt ne peut pas être négatif',
    }),

  terms: Joi.object()
    .optional()
    .default({})
    .messages({
      'object.base': 'Les conditions doivent être un objet',
    }),

  notes: Joi.string()
    .max(2000)
    .optional()
    .allow(null, '')
    .messages({
      'string.max': 'Les notes ne peuvent pas dépasser 2000 caractères',
    }),
});

const updateRenewalOfferSchema = Joi.object({
  newRent: Joi.number()
    .positive()
    .max(1000000)
    .optional()
    .messages({
      'number.base': 'Le nouveau loyer doit être un nombre',
      'number.positive': 'Le nouveau loyer doit être supérieur à 0',
    }),

  newDeposit: Joi.number()
    .integer()
    .min(0)
    .max(200000)
    .optional()
    .messages({
      'number.base': 'Le nouveau dépôt doit être un nombre',
      'number.min': 'Le nouveau dépôt ne peut pas être négatif',
    }),

  newStartDate: Joi.date()
    .iso()
    .optional()
    .messages({
      'date.format': 'La nouvelle date de début doit être une date ISO valide',
    }),

  newEndDate: Joi.date()
    .iso()
    .optional()
    .messages({
      'date.format': 'La nouvelle date de fin doit être une date ISO valide',
    }),

  terms: Joi.object()
    .optional()
    .messages({
      'object.base': 'Les conditions doivent être un objet',
    }),

  notes: Joi.string()
    .max(2000)
    .optional()
    .allow(null, ''),
});

const renewalOfferStatusSchema = Joi.object({
  status: Joi.string()
    .valid(...VALID_RENEWAL_STATUSES)
    .required()
    .messages({
      'any.only': 'Le statut doit être l\'un des suivants : en attente, envoyé, accepté, refusé, expiré',
      'any.required': 'Le statut est requis',
    }),

  tenantResponse: Joi.string()
    .max(2000)
    .optional()
    .allow(null, ''),
});

const RENEWAL_WINDOWS = [
  { days: 90, label: '90-day reminder', channel: 'email' },
  { days: 60, label: '60-day reminder', channel: 'email' },
  { days: 30, label: '30-day reminder', channel: 'both' },
];

module.exports = {
  renewalOfferSchema,
  updateRenewalOfferSchema,
  renewalOfferStatusSchema,
  VALID_RENEWAL_STATUSES,
  VALID_RENEWAL_CHANNELS,
  VALID_RENEWAL_TRANSITIONS,
  RENEWAL_WINDOWS,
};
