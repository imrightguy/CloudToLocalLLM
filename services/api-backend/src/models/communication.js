import Joi from 'joi';

// Communication log validation schema
export const communicationLogSchema = Joi.object({
  leadId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Lead ID must be a valid UUID',
    }),
    
  type: Joi.string()
    .valid('email', 'sms', 'phone', 'fb', 'email')
    .required()
    .messages({
      'any.only': 'Type must be one of: email, sms, phone, fb, email',
    }),
    
  direction: Joi.string()
    .valid('incoming', 'outgoing')
    .required()
    .messages({
      'any.only': 'Direction must be either incoming or outgoing',
    }),
    
  content: Joi.string()
    .max(10000) // Large text for emails
    .optional()
    .allow('')
    .messages({
      'string.max': 'Content cannot be more than 10000 characters long',
    }),
    
  attachments: Joi.array()
    .items(Joi.string().uri())
    .max(10)
    .optional()
    .default([])
    .messages({
      'array.base': 'Attachments must be an array',
      'array.max': 'Cannot have more than 10 attachments',
      'string.uri': 'Attachment URLs must be valid URIs',
    }),
    
  status: Joi.string()
    .valid('sent', 'delivered', 'read', 'failed')
    .default('sent')
    .required()
    .messages({
      'any.only': 'Status must be one of: sent, delivered, read, failed',
    }),
    
  agentId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
});

// Communication log update schema (partial schema)
export const updateCommunicationLogSchema = Joi.object({
  content: Joi.string()
    .max(10000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Content cannot be more than 10000 characters long',
    }),
    
  status: Joi.string()
    .valid('sent', 'delivered', 'read', 'failed')
    .optional()
    .messages({
      'any.only': 'Status must be one of: sent, delivered, read, failed',
    }),
    
  attachments: Joi.array()
    .items(Joi.string().uri())
    .max(10)
    .optional()
    .messages({
      'array.base': 'Attachments must be an array',
      'array.max': 'Cannot have more than 10 attachments',
      'string.uri': 'Attachment URLs must be valid URIs',
    }),
});

// Email communication schema
export const emailCommunicationSchema = Joi.object({
  leadId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Lead ID must be a valid UUID',
    }),
    
  to: Joi.array()
    .items(Joi.string().email())
    .min(1)
    .max(10)
    .required()
    .messages({
      'array.base': 'Recipients must be an array',
      'array.min': 'At least one recipient is required',
      'array.max': 'Cannot have more than 10 recipients',
      'string.base': 'Each recipient must be a string',
      'string.email': 'Recipients must be valid email addresses',
    }),
    
  subject: Joi.string()
    .min(1)
    .max(200)
    .required()
    .messages({
      'string.min': 'Subject must be at least 1 character long',
      'string.max': 'Subject cannot be more than 200 characters long',
      'string.empty': 'Subject is required',
    }),
    
  content: Joi.string()
    .max(10000)
    .required()
    .messages({
      'string.base': 'Content must be a string',
      'string.max': 'Content cannot be more than 10000 characters long',
      'string.empty': 'Content is required',
    }),
    
  htmlContent: Joi.string()
    .max(50000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'HTML content cannot be more than 50000 characters long',
    }),
    
  attachments: Joi.array()
    .items(Joi.object({
      filename: Joi.string().min(1).max(255).required(),
      contentType: Joi.string().required(),
      size: Joi.number().integer().min(0).max(50 * 1024 * 1024).required(),
      url: Joi.string().uri().required(),
    }))
    .max(5)
    .optional()
    .messages({
      'array.base': 'Attachments must be an array',
      'array.max': 'Cannot have more than 5 attachments',
    }),
    
  cc: Joi.array()
    .items(Joi.string().email())
    .max(10)
    .optional()
    .default([])
    .messages({
      'array.base': 'CC recipients must be an array',
      'array.max': 'Cannot have more than 10 CC recipients',
      'string.base': 'Each CC recipient must be a string',
      'string.email': 'CC recipients must be valid email addresses',
    }),
    
  bcc: Joi.array()
    .items(Joi.string().email())
    .max(10)
    .optional()
    .default([])
    .messages({
      'array.base': 'BCC recipients must be an array',
      'array.max': 'Cannot have more than 10 BCC recipients',
      'string.base': 'Each BCC recipient must be a string',
      'string.email': 'BCC recipients must be valid email addresses',
    }),
    
  priority: Joi.string()
    .valid('low', 'normal', 'high')
    .default('normal')
    .optional()
    .messages({
      'any.only': 'Priority must be one of: low, normal, high',
    }),
    
  schedule: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Schedule time must be a valid date',
      'date.iso': 'Schedule time must be in ISO format',
    }),
});

// SMS communication schema
export const smsCommunicationSchema = Joi.object({
  leadId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Lead ID must be a valid UUID',
    }),
    
  to: Joi.array()
    .items(Joi.string().pattern(/^[+]?[0-9\s\-\(\)]{10,20}$/))
    .min(1)
    .max(5)
    .required()
    .messages({
      'array.base': 'Recipients must be an array',
      'array.min': 'At least one recipient is required',
      'array.max': 'Cannot have more than 5 recipients',
      'string.pattern.base': 'Phone numbers must be valid (10-20 digits, + allowed)',
    }),
    
  content: Joi.string()
    .max(160)
    .required()
    .messages({
      'string.base': 'Content must be a string',
      'string.max': 'Content cannot exceed 160 characters (SMS limit)',
      'string.empty': 'Content is required',
    }),
    
  attachments: Joi.array()
    .items(Joi.object({
      filename: Joi.string().min(1).max(255).required(),
      contentType: Joi.string().required(),
      size: Joi.number().integer().min(0).max(10 * 1024 * 1024).required(),
      url: Joi.string().uri().required(),
    }))
    .max(3)
    .optional()
    .messages({
      'array.base': 'Attachments must be an array',
      'array.max': 'Cannot have more than 3 attachments',
    }),
    
  schedule: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Schedule time must be a valid date',
      'date.iso': 'Schedule time must be in ISO format',
    }),
});

// Phone communication schema
export const phoneCommunicationSchema = Joi.object({
  leadId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Lead ID must be a valid UUID',
    }),
    
  phoneNumber: Joi.string()
    .pattern(/^[+]?[0-9\s\-\(\)]{10,20}$/)
    .required()
    .messages({
      'string.pattern.base': 'Phone number must be valid (10-20 digits, + allowed)',
      'string.empty': 'Phone number is required',
    }),
    
  callType: Joi.string()
    .valid('inbound', 'outbound')
    .required()
    .messages({
      'any.only': 'Call type must be either inbound or outbound',
    }),
    
  duration: Joi.number()
    .integer()
    .min(0)
    .max(3600) // Max 1 hour
    .optional()
    .messages({
      'number.base': 'Duration must be a number',
      'number.integer': 'Duration must be an integer',
      'number.min': 'Duration cannot be negative',
      'number.max': 'Duration cannot exceed 1 hour (3600 seconds)',
    }),
    
  recordingUrl: Joi.string()
    .uri()
    .optional()
    .allow('')
    .messages({
      'string.uri': 'Recording URL must be a valid URI',
    }),
    
  notes: Joi.string()
    .max(2000)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Call notes cannot be more than 2000 characters long',
    }),
});

// Facebook messenger communication schema
export const fbCommunicationSchema = Joi.object({
  leadId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Lead ID must be a valid UUID',
    }),
    
  recipientId: Joi.string()
    .min(1)
    .max(50)
    .required()
    .messages({
      'string.min': 'Recipient ID must be at least 1 character long',
      'string.max': 'Recipient ID cannot be more than 50 characters long',
      'string.empty': 'Recipient ID is required',
    }),
    
  message: Joi.string()
    .max(1000)
    .required()
    .messages({
      'string.base': 'Message must be a string',
      'string.max': 'Message cannot be more than 1000 characters long',
      'string.empty': 'Message is required',
    }),
    
  messageType: Joi.string()
    .valid('text', 'image', 'file', 'button', 'generic')
    .default('text')
    .required()
    .messages({
      'any.only': 'Message type must be one of: text, image, file, button, generic',
    }),
    
  attachments: Joi.array()
    .items(Joi.object({
      type: Joi.string().valid('image', 'file', 'audio', 'video').required(),
      url: Joi.string().uri().required(),
      filename: Joi.string().min(1).max(255).required(),
      size: Joi.number().integer().min(0).max(25 * 1024 * 1024).required(),
    }))
    .max(5)
    .optional()
    .messages({
      'array.base': 'Attachments must be an array',
      'array.max': 'Cannot have more than 5 attachments',
    }),
    
  quickReplies: Joi.array()
    .items(Joi.object({
      contentType: Joi.string().valid('text').required(),
      title: Joi.string().min(1).max(20).required(),
      payload: Joi.string().min(1).max(2000).required(),
    }))
    .max(11)
    .optional()
    .messages({
      'array.base': 'Quick replies must be an array',
      'array.max': 'Cannot have more than 11 quick replies',
    }),
});

// Communication search schema
export const communicationSearchSchema = Joi.object({
  leadId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Lead ID must be a valid UUID',
    }),
    
  agentId: Joi.string()
    .guid()
    .optional()
    .messages({
      'string.guid': 'Agent ID must be a valid UUID',
    }),
    
  type: Joi.string()
    .valid('email', 'sms', 'phone', 'fb', 'email')
    .optional()
    .messages({
      'any.only': 'Type must be one of: email, sms, phone, fb, email',
    }),
    
  direction: Joi.string()
    .valid('incoming', 'outgoing')
    .optional()
    .messages({
      'any.only': 'Direction must be either incoming or outgoing',
    }),
    
  status: Joi.string()
    .valid('sent', 'delivered', 'read', 'failed')
    .optional()
    .messages({
      'any.only': 'Status must be one of: sent, delivered, read, failed',
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
});

// Communication template schema
export const communicationTemplateSchema = Joi.object({
  name: Joi.string()
    .min(1)
    .max(100)
    .required()
    .messages({
      'string.min': 'Template name must be at least 1 character long',
      'string.max': 'Template name cannot be more than 100 characters long',
      'string.empty': 'Template name is required',
    }),
    
  type: Joi.string()
    .valid('email', 'sms', 'fb')
    .required()
    .messages({
      'any.only': 'Type must be one of: email, sms, fb',
    }),
    
  subject: Joi.string()
    .min(1)
    .max(200)
    .when('type', {
      is: 'email',
      then: Joi.required(),
      otherwise: Joi.optional().allow(''),
    })
    .messages({
      'string.min': 'Subject must be at least 1 character long',
      'string.max': 'Subject cannot be more than 200 characters long',
    }),
    
  content: Joi.string()
    .min(1)
    .max(10000)
    .required()
    .messages({
      'string.min': 'Content must be at least 1 character long',
      'string.max': 'Content cannot be more than 10000 characters long',
      'string.empty': 'Content is required',
    }),
    
  htmlContent: Joi.string()
    .max(50000)
    .when('type', {
      is: 'email',
      then: Joi.optional().allow(''),
      otherwise: Joi.optional().allow(''),
    })
    .messages({
      'string.max': 'HTML content cannot be more than 50000 characters long',
    }),
    
  variables: Joi.array()
    .items(Joi.string().min(1).max(50))
    .max(50)
    .optional()
    .default([])
    .messages({
      'array.base': 'Variables must be an array',
      'array.max': 'Cannot have more than 50 variables',
    }),
    
  category: Joi.string()
    .max(50)
    .optional()
    .allow('')
    .messages({
      'string.max': 'Category cannot be more than 50 characters long',
    }),
    
  tags: Joi.array()
    .items(Joi.string())
    .max(20)
    .optional()
    .default([])
    .messages({
      'array.max': 'Cannot have more than 20 tags',
    }),
    
  isActive: Joi.boolean()
    .default(true)
    .messages({
      'boolean.base': 'Is active must be a boolean',
    }),
});

// Communication batch schema
export const communicationBatchSchema = Joi.object({
  templateId: Joi.string()
    .guid()
    .required()
    .messages({
      'string.guid': 'Template ID must be a valid UUID',
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
    
  variables: Joi.object()
    .max(100)
    .optional()
    .default({})
    .messages({
      'object.base': 'Variables must be an object',
      'object.max': 'Cannot have more than 100 variables',
    }),
    
  schedule: Joi.date()
    .iso()
    .optional()
    .allow(null)
    .messages({
      'date.base': 'Schedule time must be a valid date',
      'date.iso': 'Schedule time must be in ISO format',
    }),
    
  priority: Joi.string()
    .valid('low', 'normal', 'high')
    .default('normal')
    .optional()
    .messages({
      'any.only': 'Priority must be one of: low, normal, high',
    }),
});