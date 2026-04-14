const Joi = require('joi');

const VALID_TEMPLATE_CATEGORIES = [
  'visit_reminder',
  'lease_renewal',
  'payment_reminder',
  'custom',
];

const VALID_AUDIENCES = [
  'all_tenants',
  'building_tenants',
  'specific_leads',
];

const VALID_SCHEDULE_TYPES = ['once', 'recurring'];

const VALID_CAMPAIGN_STATUSES = [
  'draft',
  'active',
  'paused',
  'completed',
  'cancelled',
];

const templateSchema = Joi.object({
  name: Joi.string().min(2).max(100).required().messages({
    'string.min': 'Template name must be at least 2 characters',
    'string.max': 'Template name cannot exceed 100 characters',
    'string.empty': 'Template name is required',
  }),

  body: Joi.string().min(1).max(1000).required().messages({
    'string.min': 'Template body must not be empty',
    'string.max': 'Template body cannot exceed 1000 characters',
    'string.empty': 'Template body is required',
  }),

  language: Joi.string().valid('fr', 'en').default('fr').messages({
    'any.only': 'Language must be "fr" or "en"',
  }),

  category: Joi.string()
    .valid(...VALID_TEMPLATE_CATEGORIES)
    .required()
    .messages({
      'any.only': `Category must be one of: ${VALID_TEMPLATE_CATEGORIES.join(', ')}`,
      'string.empty': 'Category is required',
    }),

  description: Joi.string().max(500).optional().allow(null, '').messages({
    'string.max': 'Description cannot exceed 500 characters',
  }),

  variables: Joi.array().items(Joi.string()).max(20).optional().default([]).messages({
    'array.max': 'Cannot have more than 20 variables',
  }),
});

const updateTemplateSchema = Joi.object({
  name: Joi.string().min(2).max(100).optional().messages({
    'string.min': 'Template name must be at least 2 characters',
    'string.max': 'Template name cannot exceed 100 characters',
  }),

  body: Joi.string().min(1).max(1000).optional().messages({
    'string.min': 'Template body must not be empty',
    'string.max': 'Template body cannot exceed 1000 characters',
  }),

  language: Joi.string().valid('fr', 'en').optional().messages({
    'any.only': 'Language must be "fr" or "en"',
  }),

  category: Joi.string()
    .valid(...VALID_TEMPLATE_CATEGORIES)
    .optional()
    .messages({
      'any.only': `Category must be one of: ${VALID_TEMPLATE_CATEGORIES.join(', ')}`,
    }),

  description: Joi.string().max(500).optional().allow(null, '').messages({
    'string.max': 'Description cannot exceed 500 characters',
  }),

  variables: Joi.array().items(Joi.string()).max(20).optional().messages({
    'array.max': 'Cannot have more than 20 variables',
  }),
});

const campaignSchema = Joi.object({
  name: Joi.string().min(2).max(200).required().messages({
    'string.min': 'Campaign name must be at least 2 characters',
    'string.max': 'Campaign name cannot exceed 200 characters',
    'string.empty': 'Campaign name is required',
  }),

  description: Joi.string().max(1000).optional().allow(null, '').messages({
    'string.max': 'Description cannot exceed 1000 characters',
  }),

  templateId: Joi.string().guid().optional().allow(null).messages({
    'string.guid': 'Template ID must be a valid UUID',
  }),

  targetAudience: Joi.string()
    .valid(...VALID_AUDIENCES)
    .required()
    .messages({
      'any.only': `Target audience must be one of: ${VALID_AUDIENCES.join(', ')}`,
      'string.empty': 'Target audience is required',
    }),

  buildingId: Joi.string().guid().optional().allow(null).messages({
    'string.guid': 'Building ID must be a valid UUID',
  }),

  scheduleType: Joi.string()
    .valid(...VALID_SCHEDULE_TYPES)
    .default('once')
    .messages({
      'any.only': `Schedule type must be one of: ${VALID_SCHEDULE_TYPES.join(', ')}`,
    }),

  cronExpression: Joi.string()
    .max(100)
    .optional()
    .allow(null)
    .when('scheduleType', {
      is: 'recurring',
      then: Joi.string().required().messages({
        'any.required': 'Cron expression is required for recurring campaigns',
      }),
    })
    .messages({
      'string.max': 'Cron expression cannot exceed 100 characters',
    }),

  scheduledAt: Joi.date().iso().optional().allow(null).when('scheduleType', {
    is: 'once',
    then: Joi.date().greater('now').required().messages({
      'any.required': 'Scheduled date is required for one-time campaigns',
      'date.greater': 'Scheduled date must be in the future',
    }),
  }),

  templateData: Joi.object().optional().default({}),
});

const updateCampaignSchema = Joi.object({
  name: Joi.string().min(2).max(200).optional().messages({
    'string.min': 'Campaign name must be at least 2 characters',
    'string.max': 'Campaign name cannot exceed 200 characters',
  }),

  description: Joi.string().max(1000).optional().allow(null, '').messages({
    'string.max': 'Description cannot exceed 1000 characters',
  }),

  templateId: Joi.string().guid().optional().allow(null).messages({
    'string.guid': 'Template ID must be a valid UUID',
  }),

  targetAudience: Joi.string()
    .valid(...VALID_AUDIENCES)
    .optional()
    .messages({
      'any.only': `Target audience must be one of: ${VALID_AUDIENCES.join(', ')}`,
    }),

  buildingId: Joi.string().guid().optional().allow(null).messages({
    'string.guid': 'Building ID must be a valid UUID',
  }),

  scheduleType: Joi.string()
    .valid(...VALID_SCHEDULE_TYPES)
    .optional()
    .messages({
      'any.only': `Schedule type must be one of: ${VALID_SCHEDULE_TYPES.join(', ')}`,
    }),

  cronExpression: Joi.string().max(100).optional().allow(null),
  scheduledAt: Joi.date().iso().optional().allow(null),
  templateData: Joi.object().optional(),
});

const activateCampaignSchema = Joi.object({
  status: Joi.string()
    .valid('active', 'paused', 'cancelled')
    .required()
    .messages({
      'any.only': 'Status must be "active", "paused", or "cancelled"',
      'string.empty': 'Status is required',
    }),
});

module.exports = {
  templateSchema,
  updateTemplateSchema,
  campaignSchema,
  updateCampaignSchema,
  activateCampaignSchema,
  VALID_TEMPLATE_CATEGORIES,
  VALID_AUDIENCES,
  VALID_SCHEDULE_TYPES,
  VALID_CAMPAIGN_STATUSES,
};
