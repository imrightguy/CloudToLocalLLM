const Joi = require('joi');

const VALID_RENOVATION_STATUSES = ['planned', 'active', 'blocked', 'ready_for_leasing', 'completed', 'archived'];
const VALID_RENOVATION_STATUS_TRANSITIONS = {
  planned: ['active', 'blocked', 'archived'],
  active: ['blocked', 'ready_for_leasing', 'archived'],
  blocked: ['active', 'ready_for_leasing', 'archived'],
  ready_for_leasing: ['completed', 'archived'],
  completed: ['archived'],
  archived: [],
};

const VALID_RENOVATION_READINESS_STATES = [
  'not_started',
  'in_progress',
  'blocked',
  'ready_to_list',
  'ready_for_leasing',
  'ready',
];
const VALID_RENOVATION_READINESS_TRANSITIONS = {
  not_started: ['in_progress'],
  in_progress: ['blocked', 'ready_to_list'],
  blocked: ['in_progress', 'ready_to_list'],
  ready_to_list: ['ready_for_leasing'],
  ready_for_leasing: ['ready'],
  ready: [],
};

const VALID_RENOVATION_TASK_STATUSES = ['todo', 'in_progress', 'blocked', 'done', 'cancelled'];
const VALID_RENOVATION_TASK_TRANSITIONS = {
  todo: ['in_progress', 'blocked', 'cancelled'],
  in_progress: ['blocked', 'done', 'cancelled'],
  blocked: ['in_progress', 'cancelled'],
  done: [],
  cancelled: [],
};

const VALID_RENOVATION_ORDER_STATUSES = ['draft', 'ordered', 'partially_received', 'received', 'cancelled'];
const VALID_RENOVATION_ORDER_TRANSITIONS = {
  draft: ['ordered', 'cancelled'],
  ordered: ['partially_received', 'received', 'cancelled'],
  partially_received: ['received', 'cancelled'],
  received: [],
  cancelled: [],
};

const VALID_RENOVATION_SURPLUS_STATUSES = ['available', 'reserved', 'used', 'discarded'];
const VALID_RENOVATION_SURPLUS_TRANSITIONS = {
  available: ['reserved', 'used', 'discarded'],
  reserved: ['available', 'used', 'discarded'],
  used: [],
  discarded: [],
};

const VALID_RENOVATION_INTAKE_MESSAGE_KINDS = ['update', 'missing_material', 'blocker', 'completion', 'surplus', 'general_note'];
const VALID_RENOVATION_INTAKE_STATUSES = ['new', 'triaged', 'linked', 'resolved', 'dismissed'];
const VALID_RENOVATION_INTAKE_STATUS_TRANSITIONS = {
  new: ['triaged', 'linked', 'resolved', 'dismissed'],
  triaged: ['linked', 'resolved', 'dismissed'],
  linked: ['resolved', 'dismissed'],
  resolved: [],
  dismissed: [],
};

const renovationRecordSchema = Joi.object({
  unitId: Joi.string().uuid().required().messages({
    'string.guid': "L'identifiant de l'appartement doit être un UUID valide",
    'any.required': "L'identifiant de l'appartement est requis",
  }),
  title: Joi.string().trim().min(1).max(255).required().messages({
    'string.min': 'Le titre du chantier est requis',
    'string.max': 'Le titre du chantier ne peut pas dépasser 255 caractères',
    'any.required': 'Le titre du chantier est requis',
  }),
  status: Joi.string().valid(...VALID_RENOVATION_STATUSES).default('planned'),
  readinessState: Joi.string().valid(...VALID_RENOVATION_READINESS_STATES).default('not_started'),
  startDate: Joi.date().iso().optional().allow(null),
  targetEndDate: Joi.date().iso().optional().allow(null),
  notes: Joi.string().max(5000).optional().allow(null, ''),
});

const updateRenovationRecordSchema = Joi.object({
  title: Joi.string().trim().min(1).max(255),
  status: Joi.string().valid(...VALID_RENOVATION_STATUSES),
  readinessState: Joi.string().valid(...VALID_RENOVATION_READINESS_STATES),
  startDate: Joi.date().iso().optional().allow(null),
  targetEndDate: Joi.date().iso().optional().allow(null),
  notes: Joi.string().max(5000).optional().allow(null, ''),
}).min(1);

const renovationTaskSchema = Joi.object({
  renovationRecordId: Joi.string().uuid().required(),
  assigneeEmployeeId: Joi.string().uuid().optional().allow(null),
  title: Joi.string().trim().min(1).max(255).required(),
  description: Joi.string().max(5000).optional().allow(null, ''),
  status: Joi.string().valid(...VALID_RENOVATION_TASK_STATUSES).default('todo'),
  dueDate: Joi.date().iso().optional().allow(null),
  notes: Joi.string().max(5000).optional().allow(null, ''),
});

const updateRenovationTaskSchema = Joi.object({
  assigneeEmployeeId: Joi.string().uuid().optional().allow(null),
  title: Joi.string().trim().min(1).max(255),
  description: Joi.string().max(5000).optional().allow(null, ''),
  status: Joi.string().valid(...VALID_RENOVATION_TASK_STATUSES),
  dueDate: Joi.date().iso().optional().allow(null),
  notes: Joi.string().max(5000).optional().allow(null, ''),
}).min(1);

const renovationOrderSchema = Joi.object({
  renovationRecordId: Joi.string().uuid().required(),
  taskId: Joi.string().uuid().optional().allow(null),
  vendorName: Joi.string().trim().min(1).max(255).required(),
  itemName: Joi.string().trim().min(1).max(255).required(),
  quantityOrdered: Joi.number().integer().min(1).required(),
  quantityReceived: Joi.number().integer().min(0).default(0),
  status: Joi.string().valid(...VALID_RENOVATION_ORDER_STATUSES).default('draft'),
  orderedAt: Joi.date().iso().optional().allow(null),
  expectedAt: Joi.date().iso().optional().allow(null),
  notes: Joi.string().max(5000).optional().allow(null, ''),
});

const updateRenovationOrderSchema = Joi.object({
  taskId: Joi.string().uuid().optional().allow(null),
  vendorName: Joi.string().trim().min(1).max(255),
  itemName: Joi.string().trim().min(1).max(255),
  quantityOrdered: Joi.number().integer().min(1),
  quantityReceived: Joi.number().integer().min(0),
  status: Joi.string().valid(...VALID_RENOVATION_ORDER_STATUSES),
  orderedAt: Joi.date().iso().optional().allow(null),
  expectedAt: Joi.date().iso().optional().allow(null),
  notes: Joi.string().max(5000).optional().allow(null, ''),
}).min(1);

const receivingEventSchema = Joi.object({
  quantityReceived: Joi.number().integer().min(1).required(),
  notes: Joi.string().max(5000).optional().allow(null, ''),
});

const surplusItemSchema = Joi.object({
  renovationRecordId: Joi.string().uuid().required(),
  sourceOrderId: Joi.string().uuid().optional().allow(null),
  taskId: Joi.string().uuid().optional().allow(null),
  itemName: Joi.string().trim().min(1).max(255).required(),
  quantityAvailable: Joi.number().integer().min(1).required(),
  status: Joi.string().valid(...VALID_RENOVATION_SURPLUS_STATUSES).default('available'),
  location: Joi.string().trim().max(255).optional().allow(null, ''),
  notes: Joi.string().max(5000).optional().allow(null, ''),
});

const updateRenovationSurplusItemSchema = Joi.object({
  sourceOrderId: Joi.string().uuid().optional().allow(null),
  taskId: Joi.string().uuid().optional().allow(null),
  itemName: Joi.string().trim().min(1).max(255),
  quantityAvailable: Joi.number().integer().min(1),
  status: Joi.string().valid(...VALID_RENOVATION_SURPLUS_STATUSES),
  location: Joi.string().trim().max(255).optional().allow(null, ''),
  notes: Joi.string().max(5000).optional().allow(null, ''),
}).min(1);

const workerIntakeRecordSchema = Joi.object({
  renovationRecordId: Joi.string().uuid().required(),
  taskId: Joi.string().uuid().optional().allow(null),
  orderId: Joi.string().uuid().optional().allow(null),
  sourcePhone: Joi.string().trim().min(5).max(32).required(),
  workerName: Joi.string().trim().max(255).optional().allow(null, ''),
  messageBody: Joi.string().trim().min(1).max(5000).required(),
  messageKind: Joi.string().valid(...VALID_RENOVATION_INTAKE_MESSAGE_KINDS).default('update'),
  status: Joi.string().valid(...VALID_RENOVATION_INTAKE_STATUSES).default('new'),
  confidence: Joi.number().min(0).max(1).optional().allow(null),
  summary: Joi.string().max(1000).optional().allow(null, ''),
  rawPayload: Joi.object().unknown(true).default({}),
  twilioMessageSid: Joi.string().trim().max(64).optional().allow(null, ''),
  mediaUrls: Joi.array().items(Joi.string().uri({ scheme: ['http', 'https'] })).default([]),
  mediaContentTypes: Joi.array().items(Joi.string().trim().max(255)).default([]),
  photoCount: Joi.number().integer().min(0).default(0),
  receivedAt: Joi.date().iso().optional().allow(null),
  reviewedAt: Joi.date().iso().optional().allow(null),
  resolvedAt: Joi.date().iso().optional().allow(null),
  notes: Joi.string().max(5000).optional().allow(null, ''),
});

const updateWorkerIntakeRecordSchema = Joi.object({
  taskId: Joi.string().uuid().optional().allow(null),
  orderId: Joi.string().uuid().optional().allow(null),
  sourcePhone: Joi.string().trim().min(5).max(32),
  workerName: Joi.string().trim().max(255).optional().allow(null, ''),
  messageBody: Joi.string().trim().min(1).max(5000),
  messageKind: Joi.string().valid(...VALID_RENOVATION_INTAKE_MESSAGE_KINDS),
  status: Joi.string().valid(...VALID_RENOVATION_INTAKE_STATUSES),
  confidence: Joi.number().min(0).max(1).optional().allow(null),
  summary: Joi.string().max(1000).optional().allow(null, ''),
  rawPayload: Joi.object().unknown(true),
  twilioMessageSid: Joi.string().trim().max(64).optional().allow(null, ''),
  mediaUrls: Joi.array().items(Joi.string().uri({ scheme: ['http', 'https'] })),
  mediaContentTypes: Joi.array().items(Joi.string().trim().max(255)),
  photoCount: Joi.number().integer().min(0),
  receivedAt: Joi.date().iso().optional().allow(null),
  reviewedAt: Joi.date().iso().optional().allow(null),
  resolvedAt: Joi.date().iso().optional().allow(null),
  notes: Joi.string().max(5000).optional().allow(null, ''),
}).min(1);

module.exports = {
  renovationRecordSchema,
  updateRenovationRecordSchema,
  renovationTaskSchema,
  updateRenovationTaskSchema,
  renovationOrderSchema,
  updateRenovationOrderSchema,
  receivingEventSchema,
  surplusItemSchema,
  updateRenovationSurplusItemSchema,
  workerIntakeRecordSchema,
  updateWorkerIntakeRecordSchema,
  VALID_RENOVATION_STATUSES,
  VALID_RENOVATION_STATUS_TRANSITIONS,
  VALID_RENOVATION_READINESS_STATES,
  VALID_RENOVATION_READINESS_TRANSITIONS,
  VALID_RENOVATION_TASK_STATUSES,
  VALID_RENOVATION_TASK_TRANSITIONS,
  VALID_RENOVATION_ORDER_STATUSES,
  VALID_RENOVATION_ORDER_TRANSITIONS,
  VALID_RENOVATION_SURPLUS_STATUSES,
  VALID_RENOVATION_SURPLUS_TRANSITIONS,
  VALID_RENOVATION_INTAKE_MESSAGE_KINDS,
  VALID_RENOVATION_INTAKE_STATUSES,
  VALID_RENOVATION_INTAKE_STATUS_TRANSITIONS,
};
