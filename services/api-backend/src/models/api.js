import Joi from 'joi';

// Common API request/response schemas

// Pagination schema
export const paginationSchema = Joi.object({
  page: Joi.number()
    .integer()
    .min(1)
    .default(1)
    .messages({
      'number.base': 'Page must be a number',
      'number.integer': 'Page must be an integer',
      'number.min': 'Page must be at least 1',
    }),
    
  limit: Joi.number()
    .integer()
    .min(1)
    .max(100)
    .default(20)
    .messages({
      'number.base': 'Limit must be a number',
      'number.integer': 'Limit must be an integer',
      'number.min': 'Limit must be at least 1',
      'number.max': 'Limit cannot exceed 100',
    }),
    
  sortBy: Joi.string()
    .max(50)
    .optional()
    .messages({
      'string.max': 'Sort by cannot be more than 50 characters long',
    }),
    
  sortOrder: Joi.string()
    .valid('asc', 'desc')
    .default('asc')
    .optional()
    .messages({
      'any.only': 'Sort order must be either asc or desc',
    }),
});

// Generic search filter schema
export const searchFilterSchema = Joi.object({
  search: Joi.string()
    .max(200)
    .optional()
    .messages({
      'string.max': 'Search term cannot be more than 200 characters long',
    }),
    
  filters: Joi.object()
    .max(20) // Max 20 filter conditions
    .optional()
    .default({})
    .messages({
      'object.base': 'Filters must be an object',
      'object.max': 'Cannot have more than 20 filter conditions',
    }),
});

// API response metadata schema
export const responseMetadataSchema = Joi.object({
  total: Joi.number()
    .integer()
    .min(0)
    .required()
    .messages({
      'number.base': 'Total must be a number',
      'number.integer': 'Total must be an integer',
      'number.min': 'Total cannot be negative',
    }),
    
  page: Joi.number()
    .integer()
    .min(1)
    .required()
    .messages({
      'number.base': 'Page must be a number',
      'number.integer': 'Page must be an integer',
      'number.min': 'Page must be at least 1',
    }),
    
  limit: Joi.number()
    .integer()
    .min(1)
    .required()
    .messages({
      'number.base': 'Limit must be a number',
      'number.integer': 'Limit must be an integer',
      'number.min': 'Limit must be at least 1',
    }),
    
  totalPages: Joi.number()
    .integer()
    .min(0)
    .required()
    .messages({
      'number.base': 'Total pages must be a number',
      'number.integer': 'Total pages must be an integer',
      'number.min': 'Total pages cannot be negative',
    }),
    
  hasMore: Joi.boolean()
    .required()
    .messages({
      'boolean.base': 'Has more must be a boolean',
    }),
});

// API response wrapper schema
export const apiResponseSchema = Joi.object({
  success: Joi.boolean()
    .required()
    .messages({
      'boolean.base': 'Success must be a boolean',
    }),
    
  data: Joi.any()
    .optional()
    .allow(null),
    
  error: Joi.object({
    code: Joi.string()
      .max(50)
      .optional()
      .messages({
        'string.max': 'Error code cannot be more than 50 characters long',
      }),
      
    message: Joi.string()
      .max(500)
      .required()
      .messages({
        'string.base': 'Error message must be a string',
        'string.max': 'Error message cannot be more than 500 characters long',
        'string.empty': 'Error message is required',
      }),
      
    details: Joi.any()
      .optional()
      .allow(null),
  })
  .optional()
  .allow(null),
  
  metadata: responseMetadataSchema
    .optional(),
});

// Bulk operation schema
export const bulkOperationSchema = Joi.object({
  action: Joi.string()
    .min(1)
    .max(50)
    .required()
    .messages({
      'string.min': 'Action must be at least 1 character long',
      'string.max': 'Action cannot be more than 50 characters long',
      'string.empty': 'Action is required',
    }),
    
  ids: Joi.array()
    .items(Joi.string().guid())
    .min(1)
    .max(100)
    .required()
    .messages({
      'array.base': 'IDs must be an array',
      'array.min': 'At least one ID is required',
      'array.max': 'Cannot process more than 100 items at once',
      'string.guid': 'Each ID must be a valid UUID',
    }),
    
  options: Joi.object()
    .max(50)
    .optional()
    .default({})
    .messages({
      'object.base': 'Options must be an object',
      'object.max': 'Cannot have more than 50 options',
    }),
});

// File upload schema
export const fileUploadSchema = Joi.object({
  file: Joi.object({
    mimetype: Joi.string()
      .valid(
        'image/jpeg',
        'image/png',
        'image/webp',
        'image/gif',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/plain',
        'text/csv',
        'application/json'
      )
      .required()
      .messages({
        'any.only': 'File type not supported',
      }),
      
    size: Joi.number()
      .max(50 * 1024 * 1024) // 50MB max
      .required()
      .messages({
        'number.base': 'File size must be a number',
        'number.max': 'File size cannot exceed 50MB',
      }),
      
    originalname: Joi.string()
      .min(1)
      .max(255)
      .required()
      .messages({
        'string.min': 'Original filename must be at least 1 character long',
        'string.max': 'Original filename cannot be more than 255 characters long',
      }),
  })
  .required(),
  
  purpose: Joi.string()
    .max(50)
    .required()
    .messages({
      'string.max': 'Purpose cannot be more than 50 characters long',
    }),
    
  metadata: Joi.object()
    .max(50)
    .optional()
    .default({})
    .messages({
      'object.base': 'Metadata must be an object',
      'object.max': 'Cannot have more than 50 metadata fields',
    }),
});

// Export schema
export const exportSchema = Joi.object({
  format: Joi.string()
    .valid('csv', 'json', 'pdf', 'xlsx')
    .required()
    .messages({
      'any.only': 'Format must be one of: csv, json, pdf, xlsx',
    }),
    
  filters: Joi.object()
    .max(20)
    .optional()
    .default({})
    .messages({
      'object.base': 'Filters must be an object',
      'object.max': 'Cannot have more than 20 filter conditions',
    }),
    
  fields: Joi.array()
    .items(Joi.string())
    .max(100)
    .optional()
    .default([])
    .messages({
      'array.base': 'Fields must be an array',
      'array.max': 'Cannot select more than 100 fields',
    }),
});

// Import schema
export const importSchema = Joi.object({
  file: Joi.object({
    mimetype: Joi.string()
      .valid('text/csv', 'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      .required()
      .messages({
        'any.only': 'File type not supported',
      }),
      
    size: Joi.number()
      .max(10 * 1024 * 1024) // 10MB max for imports
      .required()
      .messages({
        'number.base': 'File size must be a number',
        'number.max': 'File size cannot exceed 10MB',
      }),
  })
  .required(),
  
  type: Joi.string()
    .max(50)
    .required()
    .messages({
      'string.max': 'Import type cannot be more than 50 characters long',
    }),
    
  options: Joi.object({
      skipHeader: Joi.boolean().default(false),
      delimiter: Joi.string().length(1).default(','),
      encoding: Joi.string().valid('utf8', 'ascii', 'latin1').default('utf8'),
      onError: Joi.string().valid('skip', 'stop', 'log').default('skip'),
    })
    .optional()
    .default({ skipHeader: false, delimiter: ',', encoding: 'utf8', onError: 'skip' })
    .messages({
      'object.base': 'Options must be an object',
    }),
});

// Error response schema
export const errorResponseSchema = Joi.object({
  success: Joi.boolean()
    .invalid(true)
    .required()
    .messages({
      'boolean.base': 'Success must be a boolean',
      'boolean.invalid': 'Success must be false for error responses',
    }),
    
  error: Joi.object({
    code: Joi.string()
      .max(50)
      .optional()
      .messages({
        'string.max': 'Error code cannot be more than 50 characters long',
      }),
      
    message: Joi.string()
      .min(1)
      .max(500)
      .required()
      .messages({
        'string.min': 'Error message must be at least 1 character long',
        'string.max': 'Error message cannot be more than 500 characters long',
        'string.empty': 'Error message is required',
      }),
      
    details: Joi.any()
      .optional()
      .allow(null),
      
    stack: Joi.string()
      .max(10000)
      .optional()
      .allow(null)
      .messages({
        'string.max': 'Stack trace cannot be more than 10000 characters long',
      }),
  })
  .required(),
});

// Health check schema
export const healthCheckSchema = Joi.object({
  status: Joi.string()
    .valid('healthy', 'degraded', 'unhealthy')
    .required()
    .messages({
      'any.only': 'Status must be one of: healthy, degraded, unhealthy',
    }),
    
  timestamp: Joi.date()
    .iso()
    .required()
    .messages({
      'date.base': 'Timestamp must be a valid date',
      'date.iso': 'Timestamp must be in ISO format',
    }),
    
  services: Joi.object({
      database: Joi.string()
        .valid('connected', 'disconnected', 'slow', 'error')
        .required()
        .messages({
          'any.only': 'Database status must be one of: connected, disconnected, slow, error',
        }),
      
      redis: Joi.string()
        .valid('connected', 'disconnected', 'slow', 'error')
        .required()
        .messages({
          'any.only': 'Redis status must be one of: connected, disconnected, slow, error',
        }),
      
      api: Joi.string()
        .valid('ok', 'slow', 'error')
        .required()
        .messages({
          'any.only': 'API status must be one of: ok, slow, error',
        }),
    })
    .required(),
});

// Rate limiting schema
export const rateLimitSchema = Joi.object({
  key: Joi.string()
    .min(1)
    .max(100)
    .required()
    .messages({
      'string.min': 'Rate limit key must be at least 1 character long',
      'string.max': 'Rate limit key cannot be more than 100 characters long',
    }),
    
  limit: Joi.number()
    .integer()
    .min(1)
    .max(10000)
    .required()
    .messages({
      'number.base': 'Rate limit must be a number',
      'number.integer': 'Rate limit must be an integer',
      'number.min': 'Rate limit must be at least 1',
      'number.max': 'Rate limit cannot exceed 10000',
    }),
    
  windowMs: Joi.number()
    .integer()
    .min(1000)
    .max(86400000) // 24 hours max
    .required()
    .messages({
      'number.base': 'Window must be a number',
      'number.integer': 'Window must be an integer',
      'number.min': 'Window must be at least 1000ms (1 second)',
      'number.max': 'Window cannot exceed 86400000ms (24 hours)',
    }),
    
  skipSuccessfulRequests: Joi.boolean()
    .default(false)
    .messages({
      'boolean.base': 'Skip successful requests must be a boolean',
    }),
    
  skipFailedRequests: Joi.boolean()
    .default(false)
    .messages({
      'boolean.base': 'Skip failed requests must be a boolean',
    }),
});

// API key schema
export const apiKeySchema = Joi.object({
  name: Joi.string()
    .min(1)
    .max(100)
    .required()
    .messages({
      'string.min': 'API key name must be at least 1 character long',
      'string.max': 'API key name cannot be more than 100 characters long',
    }),
    
  description: Joi.string()
    .max(500)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Description cannot be more than 500 characters long',
    }),
    
  permissions: Joi.array()
    .items(Joi.string())
    .min(1)
    .max(50)
    .required()
    .messages({
      'array.base': 'Permissions must be an array',
      'array.min': 'At least one permission is required',
      'array.max': 'Cannot have more than 50 permissions',
    }),
    
  expiresAt: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Expires at must be a valid date',
      'date.iso': 'Expires at must be in ISO format',
    }),
    
  rateLimit: Joi.object({
      requests: Joi.number()
        .integer()
        .min(1)
        .max(10000)
        .required()
        .messages({
          'number.base': 'Requests must be a number',
          'number.integer': 'Requests must be an integer',
          'number.min': 'Requests must be at least 1',
          'number.max': 'Requests cannot exceed 10000',
        }),
      
      windowMs: Joi.number()
        .integer()
        .min(1000)
        .max(86400000)
        .required()
        .messages({
          'number.base': 'Window must be a number',
          'number.integer': 'Window must be an integer',
          'number.min': 'Window must be at least 1000ms (1 second)',
          'number.max': 'Window cannot exceed 86400000ms (24 hours)',
        }),
    })
    .optional()
    .default({ requests: 1000, windowMs: 3600000 }), // Default: 1000 requests per hour
});

// Audit log schema
export const auditLogSchema = Joi.object({
  action: Joi.string()
    .min(1)
    .max(100)
    .required()
    .messages({
      'string.min': 'Action must be at least 1 character long',
      'string.max': 'Action cannot be more than 100 characters long',
    }),
    
  resource: Joi.string()
    .min(1)
    .max(100)
    .required()
    .messages({
      'string.min': 'Resource must be at least 1 character long',
      'string.max': 'Resource cannot be more than 100 characters long',
    }),
    
  resourceId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Resource ID must be a valid UUID',
    }),
    
  userId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'User ID must be a valid UUID',
    }),
    
  details: Joi.object()
    .max(100)
    .optional()
    .default({})
    .messages({
      'object.base': 'Details must be an object',
      'object.max': 'Cannot have more than 100 detail fields',
    }),
    
  ipAddress: Joi.string()
    .ip()
    .optional()
    .allow(null)
    .messages({
      'string.ip': 'IP address must be a valid IP address',
    }),
    
  userAgent: Joi.string()
    .max(500)
    .optional()
    .allow(null)
    .messages({
      'string.max': 'User agent cannot be more than 500 characters long',
    }),
});