const Joi = require('joi');

const VALID_PAYMENT_STATUSES = ['pending', 'paid', 'late', 'partial'];
const VALID_PAYMENT_METHODS = ['check', 'transfer', 'cash', 'interac', 'auto_debit'];

const VALID_STATUS_TRANSITIONS = {
  pending: ['paid', 'late', 'partial'],
  late: ['paid', 'partial'],
  partial: ['paid'],
  paid: [],
};

const paymentSchema = Joi.object({
  leaseId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': "L'identifiant du bail doit être un UUID valide",
      'any.required': "L'identifiant du bail est requis",
    }),

  amount: Joi.number()
    .positive()
    .max(1000000)
    .required()
    .messages({
      'number.base': 'Le montant doit être un nombre',
      'number.positive': 'Le montant doit être supérieur à 0',
      'number.max': 'Le montant ne peut pas dépasser 10 000 $',
      'any.required': 'Le montant est requis',
    }),

  dueDate: Joi.date()
    .iso()
    .required()
    .messages({
      'date.format': 'La date d\'échéance doit être une date ISO valide',
      'any.required': 'La date d\'échéance est requise',
    }),

  method: Joi.string()
    .valid(...VALID_PAYMENT_METHODS)
    .optional()
    .allow(null)
    .messages({
      'any.only': 'La méthode de paiement doit être l\'une des suivantes : chèque, virement, espèces, Interac, prélèvement automatique',
    }),

  reference: Joi.string()
    .max(200)
    .optional()
    .allow(null, '')
    .messages({
      'string.max': 'La référence ne peut pas dépasser 200 caractères',
    }),

  notes: Joi.string()
    .max(1000)
    .optional()
    .allow(null, '')
    .messages({
      'string.max': 'Les notes ne peuvent pas dépasser 1000 caractères',
    }),
});

const updatePaymentSchema = Joi.object({
  amount: Joi.number()
    .positive()
    .max(1000000)
    .optional()
    .messages({
      'number.base': 'Le montant doit être un nombre',
      'number.positive': 'Le montant doit être supérieur à 0',
      'number.max': 'Le montant ne peut pas dépasser 10 000 $',
    }),

  paidDate: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.format': 'La date de paiement doit être une date ISO valide',
    }),

  method: Joi.string()
    .valid(...VALID_PAYMENT_METHODS)
    .optional()
    .allow(null),

  reference: Joi.string()
    .max(200)
    .optional()
    .allow(null, ''),

  notes: Joi.string()
    .max(1000)
    .optional()
    .allow(null, ''),

  lateFeeCents: Joi.number()
    .integer()
    .min(0)
    .optional()
    .messages({
      'number.base': 'Les frais de retard doivent être un nombre',
      'number.integer': 'Les frais de retard doivent être un nombre entier',
      'number.min': 'Les frais de retard ne peuvent pas être négatifs',
    }),
});

const paymentStatusSchema = Joi.object({
  status: Joi.string()
    .valid(...VALID_PAYMENT_STATUSES)
    .required()
    .messages({
      'any.only': 'Le statut doit être l\'un des suivants : en attente, payé, en retard, partiel',
      'any.required': 'Le statut est requis',
    }),
});

module.exports = {
  paymentSchema,
  updatePaymentSchema,
  paymentStatusSchema,
  VALID_PAYMENT_STATUSES,
  VALID_PAYMENT_METHODS,
  VALID_STATUS_TRANSITIONS,
};
