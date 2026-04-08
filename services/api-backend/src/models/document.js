import Joi from 'joi';

// Document validation schema
export const documentSchema = Joi.object({
  name: Joi.string()
    .min(1)
    .max(255)
    .required()
    .messages({
      'string.min': 'Document name must be at least 1 character long',
      'string.max': 'Document name cannot be more than 255 characters long',
      'string.empty': 'Document name is required',
    }),
    
  type: Joi.string()
    .valid('lease', 'application', 'id', 'incomeProof', 'other')
    .required()
    .messages({
      'any.only': 'Type must be one of: lease, application, id, incomeProof, other',
    }),
    
  category: Joi.string()
    .max(100)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Category cannot be more than 100 characters long',
    }),
    
  url: Joi.string()
    .uri()
    .required()
    .messages({
      'string.uri': 'URL must be a valid URI',
      'string.empty': 'URL is required',
    }),
    
  status: Joi.string()
    .valid('pending', 'approved', 'rejected')
    .default('pending')
    .required()
    .messages({
      'any.only': 'Status must be one of: pending, approved, rejected',
    }),
    
  referenceId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Reference ID must be a valid UUID',
    }),
    
  metadata: Joi.object()
    .max(100) // Max 100 metadata fields
    .optional()
    .default({})
    .messages({
      'object.base': 'Metadata must be an object',
      'object.max': 'Cannot have more than 100 metadata fields',
    }),
});

// Document update schema (partial document schema)
export const updateDocumentSchema = Joi.object({
  name: Joi.string()
    .min(1)
    .max(255)
    .optional()
    .messages({
      'string.min': 'Document name must be at least 1 character long',
      'string.max': 'Document name cannot be more than 255 characters long',
    }),
    
  category: Joi.string()
    .max(100)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Category cannot be more than 100 characters long',
    }),
    
  status: Joi.string()
    .valid('pending', 'approved', 'rejected')
    .optional()
    .messages({
      'any.only': 'Status must be one of: pending, approved, rejected',
    }),
    
  referenceId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Reference ID must be a valid UUID',
    }),
    
  metadata: Joi.object()
    .max(100)
    .optional()
    .messages({
      'object.base': 'Metadata must be an object',
      'object.max': 'Cannot have more than 100 metadata fields',
    }),
});

// Document upload schema
export const documentUploadSchema = Joi.object({
  file: Joi.object({
    mimetype: Joi.string()
      .valid(
        'application/pdf',
        'image/jpeg',
        'image/png',
        'image/webp',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/plain'
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
  }).required(),
    
  type: Joi.string()
    .valid('lease', 'application', 'id', 'incomeProof', 'other')
    .required()
    .messages({
      'any.only': 'Type must be one of: lease, application, id, incomeProof, other',
    }),
    
  category: Joi.string()
    .max(100)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Category cannot be more than 100 characters long',
    }),
    
  referenceId: Joi.string()
    .guid()
    .optional()
    .allow(null)
    .messages({
      'string.guid': 'Reference ID must be a valid UUID',
    }),
    
  metadata: Joi.object()
    .max(100)
    .optional()
    .default({})
    .messages({
      'object.base': 'Metadata must be an object',
      'object.max': 'Cannot have more than 100 metadata fields',
    }),
});

// Document search schema for filters
export const documentSearchSchema = Joi.object({
  type: Joi.string()
    .valid('lease', 'application', 'id', 'incomeProof', 'other')
    .optional()
    .messages({
      'any.only': 'Type must be one of: lease, application, id, incomeProof, other',
    }),
    
  category: Joi.string()
    .max(100)
    .optional()
    .messages({
      'string.max': 'Category cannot be more than 100 characters long',
    }),
    
  referenceId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Reference ID must be a valid UUID',
    }),
    
  status: Joi.string()
    .valid('pending', 'approved', 'rejected')
    .optional()
    .messages({
      'any.only': 'Status must be one of: pending, approved, rejected',
    }),
    
  search: Joi.string()
    .max(200)
    .optional()
    .messages({
      'string.max': 'Search term cannot be more than 200 characters long',
    }),
    
  uploadedBy: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Uploaded by must be a valid UUID',
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
    
  mimeType: Joi.string()
    .max(100)
    .optional()
    .messages({
      'string.max': 'MIME type cannot be more than 100 characters long',
    }),
});

// Document sharing schema
export const documentShareSchema = Joi.object({
  email: Joi.string()
    .email()
    .required()
    .messages({
      'string.email': 'Must be a valid email address',
      'string.empty': 'Email is required',
    }),
    
  message: Joi.string()
    .max(1000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Share message cannot be more than 1000 characters long',
    }),
    
  accessLevel: Joi.string()
    .valid('view', 'edit', 'download')
    .default('view')
    .optional()
    .messages({
      'any.only': 'Access level must be one of: view, edit, download',
    }),
    
  expiration: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Expiration date must be a valid date',
      'date.iso': 'Expiration date must be in ISO format',
    }),
});

// Document approval schema
export const documentApprovalSchema = Joi.object({
  status: Joi.string()
    .valid('approved', 'rejected')
    .required()
    .messages({
      'any.only': 'Status must be approved or rejected',
    }),
    
  notes: Joi.string()
    .max(1000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Approval notes cannot be more than 1000 characters long',
    }),
    
  rejectionReason: Joi.string()
    .max(500)
    .when('status', {
      is: 'rejected',
      then: Joi.required(),
      otherwise: Joi.optional().allow(''),
    })
    .messages({
      'string.max': 'Rejection reason cannot be more than 500 characters long',
    }),
});

// Document bulk action schema
export const documentBulkActionSchema = Joi.object({
  action: Joi.string()
    .valid('approve', 'reject', 'archive', 'delete', 'share')
    .required()
    .messages({
      'any.only': 'Action must be one of: approve, reject, archive, delete, share',
    }),
    
  status: Joi.string()
    .valid('approved', 'rejected')
    .when('action', {
      is: Joi.boolean().valid(true),
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'any.only': 'Status must be approved or rejected',
    }),
    
  rejectionReason: Joi.string()
    .max(500)
    .when('action', {
      is: 'reject',
      then: Joi.required(),
      otherwise: Joi.optional().allow(''),
    })
    .messages({
      'string.max': 'Rejection reason cannot be more than 500 characters long',
    }),
    
  documentIds: Joi.array()
    .items(Joi.string().guid())
    .min(1)
    .max(100)
    .required()
    .messages({
      'array.base': 'Document IDs must be an array',
      'array.min': 'At least one document ID is required',
      'array.max': 'Cannot process more than 100 documents at once',
      'string.guid': 'Each document ID must be a valid UUID',
    }),
});

// Document storage schema
export const documentStorageSchema = Joi.object({
  storageProvider: Joi.string()
    .valid('local', 's3', 'azure', 'gcs')
    .default('local')
    .required()
    .messages({
      'any.only': 'Storage provider must be one of: local, s3, azure, gcs',
    }),
    
  bucketName: Joi.string()
    .max(100)
    .when('storageProvider', {
      is: Joi.not('local'),
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'string.max': 'Bucket name cannot be more than 100 characters long',
    }),
    
  region: Joi.string()
    .max(50)
    .when('storageProvider', {
      is: Joi.not('local'),
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'string.max': 'Region cannot be more than 50 characters long',
    }),
    
  accessKey: Joi.string()
    .max(100)
    .when('storageProvider', {
      is: Joi.not('local'),
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'string.max': 'Access key cannot be more than 100 characters long',
    }),
    
  secretKey: Joi.string()
    .max(100)
    .when('storageProvider', {
      is: Joi.not('local'),
      then: Joi.required(),
      otherwise: Joi.optional().allow(null),
    })
    .messages({
      'string.max': 'Secret key cannot be more than 100 characters long',
    }),
    
  basePath: Joi.string()
    .max(255)
    .default('documents')
    .optional()
    .messages({
      'string.max': 'Base path cannot be more than 255 characters long',
    }),
});

// Document versioning schema
export const documentVersionSchema = Joi.object({
  documentId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Document ID must be a valid UUID',
    }),
    
  version: Joi.number()
    .integer()
    .min(1)
    .required()
    .messages({
      'number.base': 'Version must be a number',
      'number.integer': 'Version must be an integer',
      'number.min': 'Version must be at least 1',
    }),
    
  description: Joi.string()
    .max(500)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Version description cannot be more than 500 characters long',
    }),
    
  changes: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Changes description cannot be more than 2000 characters long',
    }),
    
  isCurrent: Joi.boolean()
    .default(true)
    .messages({
      'boolean.base': 'Is current must be a boolean',
    }),
});

// Document workflow schema
export const documentWorkflowSchema = Joi.object({
  documentId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Document ID must be a valid UUID',
    }),
    
  workflowType: Joi.string()
    .valid('review', 'approval', 'publish')
    .required()
    .messages({
      'any.only': 'Workflow type must be one of: review, approval, publish',
    }),
    
  approvers: Joi.array()
    .items(Joi.string().guid())
    .min(1)
    .max(5)
    .required()
    .messages({
      'array.base': 'Approvers must be an array',
      'array.min': 'At least one approver is required',
      'array.max': 'Cannot have more than 5 approvers',
      'string.guid': 'Each approver must be a valid UUID',
    }),
    
  requiredApprovals: Joi.number()
    .integer()
    .min(1)
    .max(5)
    .default(1)
    .messages({
      'number.base': 'Required approvals must be a number',
      'number.integer': 'Required approvals must be an integer',
      'number.min': 'Required approvals must be at least 1',
      'number.max': 'Required approvals cannot exceed 5',
    }),
    
  dueDate: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Due date must be a valid date',
      'date.iso': 'Due date must be in ISO format',
    }),
    
  instructions: Joi.string()
    .max(1000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Workflow instructions cannot be more than 1000 characters long',
    }),
});