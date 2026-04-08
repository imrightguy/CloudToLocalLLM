import Joi from 'joi';

// Visit validation schema
export const visitSchema = Joi.object({
  unitLabel: Joi.string()
    .min(1)
    .max(50)
    .required()
    .pattern(/^[A-Za-z0-9\-\/\s]+$/)
    .messages({
      'string.min': 'Unit label must be at least 1 character long',
      'string.max': 'Unit label cannot be more than 50 characters long',
      'string.empty': 'Unit label is required',
      'string.pattern.base': 'Unit label can only contain letters, numbers, hyphens, slashes, and spaces',
    }),
    
  buildingName: Joi.string()
    .min(1)
    .max(100)
    .required()
    .messages({
      'string.min': 'Building name must be at least 1 character long',
      'string.max': 'Building name cannot be more than 100 characters long',
      'string.empty': 'Building name is required',
    }),
    
  dateTime: Joi.date()
    .iso()
    .required()
    .messages({
      'date.base': 'Visit date must be a valid date',
      'date.iso': 'Visit date must be in ISO format',
      'date.empty': 'Visit date is required',
    }),
    
  status: Joi.string()
    .valid('scheduled', 'confirmed', 'potential', 'completed', 'cancelled')
    .default('scheduled')
    .required()
    .messages({
      'any.only': 'Status must be one of: scheduled, confirmed, potential, completed, cancelled',
    }),
    
  agentId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
    
  clientId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Client ID must be a valid UUID',
    }),
    
  notes: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Notes cannot be more than 2000 characters long',
    }),
    
  followUp: Joi.string()
    .max(1000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Follow-up notes cannot be more than 1000 characters long',
    }),
    
  duration: Joi.number()
    .integer()
    .min(5)
    .max(480) // Max 8 hours
    .optional()
    .messages({
      'number.base': 'Duration must be a number',
      'number.integer': 'Duration must be an integer',
      'number.min': 'Duration must be at least 5 minutes',
      'number.max': 'Duration cannot exceed 8 hours (480 minutes)',
    }),
});

// Visit update schema (partial visit schema)
export const updateVisitSchema = Joi.object({
  unitLabel: Joi.string()
    .min(1)
    .max(50)
    .optional()
    .pattern(/^[A-Za-z0-9\-\/\s]+$/)
    .messages({
      'string.min': 'Unit label must be at least 1 character long',
      'string.max': 'Unit label cannot be more than 50 characters long',
      'string.pattern.base': 'Unit label can only contain letters, numbers, hyphens, slashes, and spaces',
    }),
    
  buildingName: Joi.string()
    .min(1)
    .max(100)
    .optional()
    .messages({
      'string.min': 'Building name must be at least 1 character long',
      'string.max': 'Building name cannot be more than 100 characters long',
    }),
    
  dateTime: Joi.date()
    .iso()
    .optional()
    .messages({
      'date.base': 'Visit date must be a valid date',
      'date.iso': 'Visit date must be in ISO format',
    }),
    
  status: Joi.string()
    .valid('scheduled', 'confirmed', 'potential', 'completed', 'cancelled')
    .optional()
    .messages({
      'any.only': 'Status must be one of: scheduled, confirmed, potential, completed, cancelled',
    }),
    
  agentId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
    
  clientId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Client ID must be a valid UUID',
    }),
    
  notes: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Notes cannot be more than 2000 characters long',
    }),
    
  followUp: Joi.string()
    .max(1000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Follow-up notes cannot be more than 1000 characters long',
    }),
    
  duration: Joi.number()
    .integer()
    .min(5)
    .max(480)
    .optional()
    .messages({
      'number.base': 'Duration must be a number',
      'number.integer': 'Duration must be an integer',
      'number.min': 'Duration must be at least 5 minutes',
      'number.max': 'Duration cannot exceed 8 hours (480 minutes)',
    }),
});

// Visit status update schema
export const visitStatusSchema = Joi.object({
  status: Joi.string()
    .valid('scheduled', 'confirmed', 'potential', 'completed', 'cancelled')
    .required()
    .messages({
      'any.only': 'Status must be one of: scheduled, confirmed, potential, completed, cancelled',
    }),
    
  notes: Joi.string()
    .max(1000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Status change notes cannot be more than 1000 characters long',
    }),
});

// Visit completion schema
export const visitCompletionSchema = Joi.object({
  status: Joi.string()
    .valid('completed')
    .required()
    .messages({
      'any.only': 'Status must be completed',
    }),
    
  notes: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Completion notes cannot be more than 2000 characters long',
    }),
    
  followUp: Joi.string()
    .max(1000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Follow-up notes cannot be more than 1000 characters long',
    }),
    
  duration: Joi.number()
    .integer()
    .min(5)
    .max(480)
    .optional()
    .messages({
      'number.base': 'Duration must be a number',
      'number.integer': 'Duration must be an integer',
      'number.min': 'Duration must be at least 5 minutes',
      'number.max': 'Duration cannot exceed 8 hours (480 minutes)',
    }),
});

// Visit search schema for filters
export const visitSearchSchema = Joi.object({
  date: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Date must be a valid date',
      'date.iso': 'Date must be in ISO format',
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
    
  agentId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
    
  status: Joi.string()
    .valid('scheduled', 'confirmed', 'potential', 'completed', 'cancelled')
    .optional()
    .messages({
      'any.only': 'Status must be one of: scheduled, confirmed, potential, completed, cancelled',
    }),
    
  clientId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Client ID must be a valid UUID',
    }),
    
  buildingName: Joi.string()
    .min(1)
    .max(100)
    .optional()
    .messages({
      'string.min': 'Building name must be at least 1 character long',
      'string.max': 'Building name cannot be more than 100 characters long',
    }),
    
  search: Joi.string()
    .max(200)
    .optional()
    .messages({
      'string.max': 'Search term cannot be more than 200 characters long',
    }),
});

// Visit availability check schema
export const visitAvailabilitySchema = Joi.object({
  unitId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Unit ID must be a valid UUID',
    }),
    
  dateTime: Joi.date()
    .iso()
    .required()
    .messages({
      'date.base': 'Visit date must be a valid date',
      'date.iso': 'Visit date must be in ISO format',
    }),
    
  duration: Joi.number()
    .integer()
    .min(5)
    .max(480)
    .default(30)
    .messages({
      'number.base': 'Duration must be a number',
      'number.integer': 'Duration must be an integer',
      'number.min': 'Duration must be at least 5 minutes',
      'number.max': 'Duration cannot exceed 8 hours (480 minutes)',
    }),
    
  bufferTime: Joi.number()
    .integer()
    .min(5)
    .max(60)
    .default(15)
    .messages({
      'number.base': 'Buffer time must be a number',
      'number.integer': 'Buffer time must be an integer',
      'number.min': 'Buffer time must be at least 5 minutes',
      'number.max': 'Buffer time cannot exceed 1 hour (60 minutes)',
    }),
});

// Visit reschedule schema
export const visitRescheduleSchema = Joi.object({
  newDateTime: Joi.date()
    .iso()
    .required()
    .messages({
      'date.base': 'New visit date must be a valid date',
      'date.iso': 'New visit date must be in ISO format',
    }),
    
  duration: Joi.number()
    .integer()
    .min(5)
    .max(480)
    .optional()
    .messages({
      'number.base': 'Duration must be a number',
      'number.integer': 'Duration must be an integer',
      'number.min': 'Duration must be at least 5 minutes',
      'number.max': 'Duration cannot exceed 8 hours (480 minutes)',
    }),
    
  notes: Joi.string()
    .max(1000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Reschedule notes cannot be more than 1000 characters long',
    }),
});

// Visit bulk action schema
export const visitBulkActionSchema = Joi.object({
  action: Joi.string()
    .valid('cancel', 'complete', 'reschedule', 'assign')
    .required()
    .messages({
      'any.only': 'Action must be one of: cancel, complete, reschedule, assign',
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
    
  newDateTime: Joi.date()
    .iso()
    .when('action', {
      is: 'reschedule',
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'date.base': 'New visit date must be a valid date',
      'date.iso': 'New visit date must be in ISO format',
    }),
    
  status: Joi.string()
    .valid('cancelled', 'completed')
    .when('action', {
      is: Joi.boolean().valid(true),
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'any.only': 'Status must be cancelled or completed',
    }),
    
  visitIds: Joi.array()
    .items(Joi.string().guid())
    .min(1)
    .max(100)
    .required()
    .messages({
      'array.base': 'Visit IDs must be an array',
      'array.min': 'At least one visit ID is required',
      'array.max': 'Cannot process more than 100 visits at once',
      'string.guid': 'Each visit ID must be a valid UUID',
    }),
});

// Visit reminder schema
export const visitReminderSchema = Joi.object({
  visitId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Visit ID must be a valid UUID',
    }),
    
  reminderType: Joi.string()
    .valid('email', 'sms', 'notification')
    .required()
    .messages({
      'any.only': 'Reminder type must be one of: email, sms, notification',
    }),
    
  reminderTime: Joi.date()
    .iso()
    .required()
    .messages({
      'date.base': 'Reminder time must be a valid date',
      'date.iso': 'Reminder time must be in ISO format',
    }),
    
  message: Joi.string()
    .max(500)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Reminder message cannot be more than 500 characters long',
    }),
});