import Joi from 'joi';

// Lead validation schema
export const leadSchema = Joi.object({
  fullName: Joi.string()
    .min(2)
    .max(100)
    .required()
    .pattern(/^[A-Za-zÀ-ÿ\s\-']+$/)
    .messages({
      'string.min': 'Full name must be at least 2 characters long',
      'string.max': 'Full name cannot be more than 100 characters long',
      'string.empty': 'Full name is required',
      'string.pattern.base': 'Full name can only contain letters, spaces, hyphens, and apostrophes',
    }),
    
  email: Joi.string()
    .email()
    .required()
    .messages({
      'string.email': 'Must be a valid email address',
      'string.empty': 'Email is required',
    }),
    
  phone: Joi.string()
    .pattern(/^[+]?[0-9\s\-\(\)]{10,20}$/)
    .optional()
    .allow('')
    .messages({
      'string.pattern.base': 'Phone number must be valid (10-20 digits, + allowed)',
    }),
    
  budget: Joi.number()
    .integer()
    .min(0)
    .max(100000) // Max $100,000 budget
    .optional()
    .messages({
      'number.base': 'Budget must be a number',
      'number.integer': 'Budget must be an integer',
      'number.min': 'Budget cannot be negative',
      'number.max': 'Budget cannot exceed $100,000',
    }),
    
  desiredUnit: Joi.string()
    .max(200)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Desired unit description cannot be more than 200 characters long',
    }),
    
  source: Joi.string()
    .valid('facebook', 'website', 'referral', 'other')
    .default('other')
    .required()
    .messages({
      'any.only': 'Source must be one of: facebook, website, referral, other',
    }),
    
  stage: Joi.string()
    .valid('nouveau', 'contacte', 'qualifie', 'visitePlanifiee', 'offreEnvoyee', 'negociation', 'bailSigne')
    .default('nouveau')
    .required()
    .messages({
      'any.only': 'Stage must be one of the predefined leasing pipeline stages',
    }),
    
  notes: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Notes cannot be more than 2000 characters long',
    }),
    
  tags: Joi.array()
    .items(Joi.string())
    .max(20)
    .optional()
    .default([])
    .messages({
      'array.max': 'Cannot have more than 20 tags',
    }),
    
  assignedAgentId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Assigned agent ID must be a valid UUID',
    }),
    
  buildingId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Building ID must be a valid UUID',
    }),
    
  unitId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Unit ID must be a valid UUID',
    }),
});

// Lead update schema (partial lead schema)
export const updateLeadSchema = Joi.object({
  fullName: Joi.string()
    .min(2)
    .max(100)
    .optional()
    .pattern(/^[A-Za-zÀ-ÿ\s\-']+$/)
    .messages({
      'string.min': 'Full name must be at least 2 characters long',
      'string.max': 'Full name cannot be more than 100 characters long',
      'string.pattern.base': 'Full name can only contain letters, spaces, hyphens, and apostrophes',
    }),
    
  email: Joi.string()
    .email()
    .optional()
    .messages({
      'string.email': 'Must be a valid email address',
    }),
    
  phone: Joi.string()
    .pattern(/^[+]?[0-9\s\-\(\)]{10,20}$/)
    .optional()
    .allow('')
    .messages({
      'string.pattern.base': 'Phone number must be valid (10-20 digits, + allowed)',
    }),
    
  budget: Joi.number()
    .integer()
    .min(0)
    .max(100000)
    .optional()
    .messages({
      'number.base': 'Budget must be a number',
      'number.integer': 'Budget must be an integer',
      'number.min': 'Budget cannot be negative',
      'number.max': 'Budget cannot exceed $100,000',
    }),
    
  desiredUnit: Joi.string()
    .max(200)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Desired unit description cannot be more than 200 characters long',
    }),
    
  source: Joi.string()
    .valid('facebook', 'website', 'referral', 'other')
    .optional()
    .messages({
      'any.only': 'Source must be one of: facebook, website, referral, other',
    }),
    
  stage: Joi.string()
    .valid('nouveau', 'contacte', 'qualifie', 'visitePlanifiee', 'offreEnvoyee', 'negociation', 'bailSigne')
    .optional()
    .messages({
      'any.only': 'Stage must be one of the predefined leasing pipeline stages',
    }),
    
  notes: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Notes cannot be more than 2000 characters long',
    }),
    
  tags: Joi.array()
    .items(Joi.string())
    .max(20)
    .optional()
    .messages({
      'array.max': 'Cannot have more than 20 tags',
    }),
    
  assignedAgentId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Assigned agent ID must be a valid UUID',
    }),
    
  buildingId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Building ID must be a valid UUID',
    }),
    
  unitId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Unit ID must be a valid UUID',
    }),
});

// Lead stage update schema
export const leadStageSchema = Joi.object({
  stage: Joi.string()
    .valid('nouveau', 'contacte', 'qualifie', 'visitePlanifiee', 'offreEnvoyee', 'negociation', 'bailSigne')
    .required()
    .messages({
      'any.only': 'Stage must be one of the predefined leasing pipeline stages',
    }),
    
  notes: Joi.string()
    .max(1000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Stage change notes cannot be more than 1000 characters long',
    }),
});

// Lead contact schema
export const leadContactSchema = Joi.object({
  notes: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Contact notes cannot be more than 2000 characters long',
    }),
    
  nextContact: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Next contact date must be a valid date',
      'date.iso': 'Next contact date must be in ISO format',
    }),
});

// Lead search schema for filters
export const leadSearchSchema = Joi.object({
  stage: Joi.string()
    .valid('nouveau', 'contacte', 'qualifie', 'visitePlanifiee', 'offreEnvoyee', 'negociation', 'bailSigne')
    .optional()
    .messages({
      'any.only': 'Stage must be one of the predefined leasing pipeline stages',
    }),
    
  source: Joi.string()
    .valid('facebook', 'website', 'referral', 'other')
    .optional()
    .messages({
      'any.only': 'Source must be one of: facebook, website, referral, other',
    }),
    
  agentId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
    
  search: Joi.string()
    .max(200)
    .optional()
    .messages({
      'string.max': 'Search term cannot be more than 200 characters long',
    }),
    
  dateFrom: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Date from must be a valid date',
      'date.iso': 'Date from must be in ISO format',
    }),
    
  dateTo: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Date to must be a valid date',
      'date.iso': 'Date to must be in ISO format',
    }),
    
  tags: Joi.array()
    .items(Joi.string())
    .max(10)
    .optional()
    .messages({
      'array.max': 'Cannot filter by more than 10 tags at once',
    }),
});

// Lead bulk action schema
export const leadBulkActionSchema = Joi.object({
  action: Joi.string()
    .valid('assign', 'archive', 'delete', 'stage')
    .required()
    .messages({
      'any.only': 'Action must be one of: assign, archive, delete, stage',
    }),
    
  agentId: Joi.string()
    .guid()
    .when('action', {
      is: 'assign',
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
    
  stage: Joi.string()
    .valid('nouveau', 'contacte', 'qualifie', 'visitePlanifiee', 'offreEnvoyee', 'negociation', 'bailSigne')
    .when('action', {
      is: 'stage',
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'any.only': 'Stage must be one of the predefined leasing pipeline stages',
    }),
    
  leadIds: Joi.array()
    .items(Joi.string().guid())
    .min(1)
    .max(100)
    .required()
    .messages({
      'array.base': 'Lead IDs must be an array',
      'array.min': 'At least one lead ID is required',
      'array.max': 'Cannot process more than 100 leads at once',
      'string.guid': 'Each lead ID must be a valid UUID',
    }),
});

// Lead import schema
export const leadImportSchema = Joi.object({
  leads: Joi.array()
    .items(leadSchema)
    .min(1)
    .max(1000)
    .required()
    .messages({
      'array.base': 'Leads must be an array',
      'array.min': 'At least one lead is required',
      'array.max': 'Cannot import more than 1000 leads at once',
    }),
    
  existingLeads: Joi.object({
    skip: Joi.boolean().default(false),
    update: Joi.boolean().default(false),
    matchBy: Joi.string()
      .valid('email', 'phone', 'both')
      .default('email')
      .messages({
        'any.only': 'Match by must be one of: email, phone, both',
      }),
  })
  .default({ skip: true, update: false, matchBy: 'email' })
  .messages({
    'object.base': 'Existing leads configuration must be an object',
  }),
});