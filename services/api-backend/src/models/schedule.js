import Joi from 'joi';

// Schedule validation schema
export const scheduleSchema = Joi.object({
  title: Joi.string()
    .min(1)
    .max(100)
    .required()
    .messages({
      'string.min': 'Title must be at least 1 character long',
      'string.max': 'Title cannot be more than 100 characters long',
      'string.empty': 'Title is required',
    }),
    
  description: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Description cannot be more than 2000 characters long',
    }),
    
  startTime: Joi.date()
    .iso()
    .required()
    .messages({
      'date.base': 'Start time must be a valid date',
      'date.iso': 'Start time must be in ISO format',
      'date.empty': 'Start time is required',
    }),
    
  endTime: Joi.date()
    .iso()
    .greater(Joi.ref('startTime'))
    .optional()
    .allow(null)
    .messages({
      'date.base': 'End time must be a valid date',
      'date.iso': 'End time must be in ISO format',
      'date.greater': 'End time must be after start time',
    }),
    
  isRecurring: Joi.boolean()
    .default(false)
    .required()
    .messages({
      'boolean.base': 'Is recurring must be a boolean',
    }),
    
  recurrence: Joi.object({
    frequency: Joi.string()
      .valid('daily', 'weekly', 'monthly', 'yearly')
      .required()
      .messages({
        'any.only': 'Frequency must be one of: daily, weekly, monthly, yearly',
      }),
      
    interval: Joi.number()
      .integer()
      .min(1)
      .max(365)
      .default(1)
      .optional()
      .messages({
        'number.base': 'Interval must be a number',
        'number.integer': 'Interval must be an integer',
        'number.min': 'Interval must be at least 1',
        'number.max': 'Interval cannot exceed 365',
      }),
      
    endDate: Joi.date()
      .iso()
      .optional()
      .allow(null)
      .messages({
        'date.base': 'End date must be a valid date',
        'date.iso': 'End date must be in ISO format',
      }),
      
    daysOfWeek: Joi.array()
      .items(Joi.string().valid('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'))
      .when('frequency', {
        is: 'weekly',
        then: Joi.required(),
        otherwise: Joi.optional().allow([]),
      })
      .max(7)
      .messages({
        'array.base': 'Days of week must be an array',
        'array.max': 'Cannot have more than 7 days',
        'string.base': 'Each day must be a string',
        'any.only': 'Days must be valid day names',
      }),
      
    dayOfMonth: Joi.number()
      .integer()
      .min(1)
      .max(31)
      .when('frequency', {
        is: 'monthly',
        then: Joi.required(),
        otherwise: Joi.optional().allow(null),
      })
      .messages({
        'number.base': 'Day of month must be a number',
        'number.integer': 'Day of month must be an integer',
        'number.min': 'Day of month must be between 1 and 31',
        'number.max': 'Day of month must be between 1 and 31',
      }),
      
    monthsOfYear: Joi.array()
      .items(Joi.string().valid('january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'))
      .when('frequency', {
        is: 'yearly',
        then: Joi.required(),
        otherwise: Joi.optional().allow([]),
      })
      .max(12)
      .messages({
        'array.base': 'Months of year must be an array',
        'array.max': 'Cannot have more than 12 months',
        'string.base': 'Each month must be a string',
        'any.only': 'Months must be valid month names',
      }),
      
    count: Joi.number()
      .integer()
      .min(1)
      .max(1000)
      .optional()
      .messages({
        'number.base': 'Count must be a number',
        'number.integer': 'Count must be an integer',
        'number.min': 'Count must be at least 1',
        'number.max': 'Count cannot exceed 1000',
      }),
      
    exDates: Joi.array()
      .items(Joi.date().iso())
      .max(100)
      .optional()
      .default([])
      .messages({
        'array.base': 'Exception dates must be an array',
        'array.max': 'Cannot have more than 100 exception dates',
        'date.base': 'Exception dates must be valid dates',
        'date.iso': 'Exception dates must be in ISO format',
      }),
  })
  .optional()
  .default({})
  .messages({
    'object.base': 'Recurrence rules must be an object',
  }),
    
  location: Joi.string()
    .max(200)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Location cannot be more than 200 characters long',
    }),
    
  agentId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
});

// Schedule update schema (partial schedule schema)
export const updateScheduleSchema = Joi.object({
  title: Joi.string()
    .min(1)
    .max(100)
    .optional()
    .messages({
      'string.min': 'Title must be at least 1 character long',
      'string.max': 'Title cannot be more than 100 characters long',
    }),
    
  description: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Description cannot be more than 2000 characters long',
    }),
    
  startTime: Joi.date()
    .iso()
    .optional()
    .messages({
      'date.base': 'Start time must be a valid date',
      'date.iso': 'Start time must be in ISO format',
    }),
    
  endTime: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'End time must be a valid date',
      'date.iso': 'End time must be in ISO format',
    }),
    
  isRecurring: Joi.boolean()
    .optional()
    .messages({
      'boolean.base': 'Is recurring must be a boolean',
    }),
    
  recurrence: Joi.object({
    frequency: Joi.string()
      .valid('daily', 'weekly', 'monthly', 'yearly')
      .optional()
      .messages({
        'any.only': 'Frequency must be one of: daily, weekly, monthly, yearly',
      }),
      
    interval: Joi.number()
      .integer()
      .min(1)
      .max(365)
      .optional()
      .messages({
        'number.base': 'Interval must be a number',
        'number.integer': 'Interval must be an integer',
        'number.min': 'Interval must be at least 1',
        'number.max': 'Interval cannot exceed 365',
      }),
      
    endDate: Joi.date()
      .iso()
      .optional()
      .allow(null)
      .messages({
        'date.base': 'End date must be a valid date',
        'date.iso': 'End date must be in ISO format',
      }),
      
    daysOfWeek: Joi.array()
      .items(Joi.string().valid('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'))
      .max(7)
      .optional()
      .messages({
        'array.base': 'Days of week must be an array',
        'array.max': 'Cannot have more than 7 days',
        'string.base': 'Each day must be a string',
        'any.only': 'Days must be valid day names',
      }),
      
    dayOfMonth: Joi.number()
      .integer()
      .min(1)
      .max(31)
      .optional()
      .messages({
        'number.base': 'Day of month must be a number',
        'number.integer': 'Day of month must be an integer',
        'number.min': 'Day of month must be between 1 and 31',
        'number.max': 'Day of month must be between 1 and 31',
      }),
      
    monthsOfYear: Joi.array()
      .items(Joi.string().valid('january', 'february', 'march', 'april', 'may', 'june', 'july', 'august', 'september', 'october', 'november', 'december'))
      .max(12)
      .optional()
      .messages({
        'array.base': 'Months of year must be an array',
        'array.max': 'Cannot have more than 12 months',
        'string.base': 'Each month must be a string',
        'any.only': 'Months must be valid month names',
      }),
      
    count: Joi.number()
      .integer()
      .min(1)
      .max(1000)
      .optional()
      .messages({
        'number.base': 'Count must be a number',
        'number.integer': 'Count must be an integer',
        'number.min': 'Count must be at least 1',
        'number.max': 'Count cannot exceed 1000',
      }),
      
    exDates: Joi.array()
      .items(Joi.date().iso())
      .max(100)
      .optional()
      .messages({
        'array.base': 'Exception dates must be an array',
        'array.max': 'Cannot have more than 100 exception dates',
        'date.base': 'Exception dates must be valid dates',
        'date.iso': 'Exception dates must be in ISO format',
      }),
  })
  .optional()
  .messages({
    'object.base': 'Recurrence rules must be an object',
  }),
    
  location: Joi.string()
    .max(200)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Location cannot be more than 200 characters long',
    }),
    
  agentId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
});

// Schedule search schema for filters
export const scheduleSearchSchema = Joi.object({
  agentId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
    
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
    
  search: Joi.string()
    .max(200)
    .optional()
    .messages({
      'string.max': 'Search term cannot be more than 200 characters long',
    }),
    
  isRecurring: Joi.boolean()
    .optional()
    .messages({
      'boolean.base': 'Is recurring must be a boolean',
    }),
});

// Schedule bulk action schema
export const scheduleBulkActionSchema = Joi.object({
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
    
  newStartTime: Joi.date()
    .iso()
    .when('action', {
      is: 'reschedule',
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'date.base': 'New start time must be a valid date',
      'date.iso': 'New start time must be in ISO format',
    }),
    
  newEndTime: Joi.date()
    .iso()
    .when('action', {
      is: 'reschedule',
      then: Joi.optional().allow(null),
    })
    .messages({
      'date.base': 'New end time must be a valid date',
      'date.iso': 'New end time must be in ISO format',
    }),
    
  scheduleIds: Joi.array()
    .items(Joi.string().guid())
    .min(1)
    .max(100)
    .required()
    .messages({
      'array.base': 'Schedule IDs must be an array',
      'array.min': 'At least one schedule ID is required',
      'array.max': 'Cannot process more than 100 schedules at once',
      'string.guid': 'Each schedule ID must be a valid UUID',
    }),
});

// Schedule availability schema
export const scheduleAvailabilitySchema = Joi.object({
  agentId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
    
  date: Joi.date()
    .iso()
    .required()
    .messages({
      'date.base': 'Date must be a valid date',
      'date.iso': 'Date must be in ISO format',
    }),
    
  startTime: Joi.time()
    .required()
    .messages({
      'time.base': 'Start time must be a valid time',
      'time.empty': 'Start time is required',
    }),
    
  endTime: Joi.time()
    .required()
    .greater(Joi.ref('startTime'))
    .messages({
      'time.base': 'End time must be a valid time',
      'time.empty': 'End time is required',
      'time.greater': 'End time must be after start time',
    }),
    
  bufferTime: Joi.number()
    .integer()
    .min(0)
    .max(60)
    .default(0)
    .messages({
      'number.base': 'Buffer time must be a number',
      'number.integer': 'Buffer time must be an integer',
      'number.min': 'Buffer time must be at least 0',
      'number.max': 'Buffer time cannot exceed 1 hour (60 minutes)',
    }),
});

// Schedule reminder schema
export const scheduleReminderSchema = Joi.object({
  scheduleId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Schedule ID must be a valid UUID',
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

// Schedule import schema
export const scheduleImportSchema = Joi.object({
  schedules: Joi.array()
    .items(scheduleSchema)
    .min(1)
    .max(1000)
    .required()
    .messages({
      'array.base': 'Schedules must be an array',
      'array.min': 'At least one schedule is required',
      'array.max': 'Cannot import more than 1000 schedules at once',
    }),
    
  existingSchedules: Joi.object({
    skip: Joi.boolean().default(false),
    update: Joi.boolean().default(false),
    matchBy: Joi.string()
      .valid('title', 'startTime', 'both')
      .default('title')
      .messages({
        'any.only': 'Match by must be one of: title, startTime, both',
      }),
  })
  .default({ skip: true, update: false, matchBy: 'title' })
  .messages({
    'object.base': 'Existing schedules configuration must be an object',
  }),
});