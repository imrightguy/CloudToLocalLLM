const Joi = require('joi');
const { VALID_LEAD_STAGES } = require('../constants/lead-stages');
const {
  QUALIFICATION_STATES,
  BOOKING_STATES,
  MARKETPLACE_REASON_CODES,
} = require('../constants/marketplace-states');
const {
  buildingSchema,
  updateBuildingSchema,
} = require('../models/building');
const {
  tenantChecklistStartSchema,
  tenantChecklistResumeSchema,
  tenantChecklistPauseSchema,
  tenantChecklistSubmitSchema,
  tenantChecklistSummaryParamsSchema,
} = require('../models/tenant-checklist');
const {
  photoRecordCreateSchema,
  photoRecordUploadSchema,
  photoRecordUpdateSchema,
  photoRecordListQuerySchema,
} = require('../models/photo');

const uuid = Joi.string().uuid();

const pagination = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
});

const uuidParam = { params: Joi.object({ id: uuid }) };

const buildingIdParam = { params: Joi.object({ buildingId: uuid }) };

const photoRecordSchemas = {
  list: {
    params: Joi.object({ companyId: uuid.required() }),
    query: photoRecordListQuerySchema,
  },
  create: {
    params: Joi.object({ companyId: uuid.required() }),
    body: photoRecordCreateSchema,
  },
  upload: {
    params: Joi.object({ companyId: uuid.required() }),
    body: photoRecordUploadSchema,
  },
  download: {
    params: Joi.object({
      companyId: uuid.required(),
      photoId: uuid.required(),
    }),
  },
  update: {
    params: Joi.object({
      companyId: uuid.required(),
      photoId: uuid.required(),
    }),
    body: photoRecordUpdateSchema,
  },
  remove: {
    params: Joi.object({
      companyId: uuid.required(),
      photoId: uuid.required(),
    }),
  },
};

const buildingSchemas = {
  create: {
    body: buildingSchema,
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: updateBuildingSchema.min(1),
  },
  createUnit: {
    body: Joi.object({
      buildingId: uuid.required(),
      unitNumber: Joi.string().trim().min(1).max(50).required(),
      type: Joi.string().valid('studio', '1br', '2br', '3br', '4br', 'other'),
      rentAmount: Joi.number().min(0),
      sqft: Joi.number().integer().min(0),
      isAvailable: Joi.boolean().default(true),
      bedrooms: Joi.number().integer().min(0).max(20),
      bathrooms: Joi.number().integer().min(0).max(20),
    }),
  },
  updateUnit: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      unitNumber: Joi.string().trim().min(1).max(50),
      type: Joi.string().valid('studio', '1br', '2br', '3br', '4br', 'other'),
      rentAmount: Joi.number().min(0),
      sqft: Joi.number().integer().min(0),
      isAvailable: Joi.boolean(),
      bedrooms: Joi.number().integer().min(0).max(20),
      bathrooms: Joi.number().integer().min(0).max(20),
    }).min(1),
  },
};

const leadSchemas = {
  list: {
    query: Joi.object({
      page: pagination.extract('page'),
      limit: pagination.extract('limit'),
      stage: Joi.string().valid(...VALID_LEAD_STAGES),
      buildingId: uuid,
      search: Joi.string().trim().max(255),
      sortBy: Joi.string().valid('fullName', 'email', 'stage', 'source', 'createdAt', 'updatedAt'),
      sortOrder: Joi.string().valid('asc', 'desc'),
    }),
  },
  create: {
    body: Joi.object({
      fullName: Joi.string().trim().min(1).max(255).required(),
      email: Joi.string().email().trim().max(255),
      phone: Joi.string().trim().max(50),
      budgetCents: Joi.number().integer().min(0),
      desiredUnit: Joi.string().trim().max(100),
      source: Joi.string().trim().max(100).default('other'),
      stage: Joi.string().valid(...VALID_LEAD_STAGES).default('nouveau'),
      qualificationState: Joi.string().valid(...QUALIFICATION_STATES).default('unknown'),
      qualificationReasonCode: Joi.string().valid(...MARKETPLACE_REASON_CODES),
      qualificationReasonNote: Joi.string().trim().max(1000),
      notes: Joi.string().trim().max(5000),
      tags: Joi.array().items(Joi.string().trim().max(100)).max(20),
      language: Joi.string().valid('fr', 'en').default('fr'),
      assignedEmployeeId: uuid,
      buildingId: uuid,
      unitId: uuid,
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      fullName: Joi.string().trim().min(1).max(255),
      email: Joi.string().email().trim().max(255),
      phone: Joi.string().trim().max(50),
      budgetCents: Joi.number().integer().min(0),
      desiredUnit: Joi.string().trim().max(100),
      source: Joi.string().trim().max(100),
      stage: Joi.string().valid(...VALID_LEAD_STAGES),
      qualificationState: Joi.string().valid(...QUALIFICATION_STATES),
      qualificationReasonCode: Joi.string().valid(...MARKETPLACE_REASON_CODES),
      qualificationReasonNote: Joi.string().trim().max(1000),
      notes: Joi.string().trim().max(5000),
      tags: Joi.array().items(Joi.string().trim().max(100)).max(20),
      language: Joi.string().valid('fr', 'en'),
      assignedEmployeeId: uuid,
      buildingId: uuid,
      unitId: uuid,
    }).min(1),
  },
  updateStatus: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      status: Joi.string().valid(...VALID_LEAD_STAGES).required(),
    }),
  },
  bulkUpdate: {
    body: Joi.object({
      leadIds: Joi.array().items(uuid).min(1).max(200).required(),
      updates: Joi.object({
        status: Joi.string().valid(...VALID_LEAD_STAGES),
        qualificationState: Joi.string().valid(...QUALIFICATION_STATES),
        qualificationReasonCode: Joi.string().valid(...MARKETPLACE_REASON_CODES),
        qualificationReasonNote: Joi.string().trim().max(1000),
        buildingId: uuid,
        employeeId: uuid,
      }).min(1).required(),
    }),
  },
  marketplaceWebhook: {
    body: Joi.object({
      fullName: Joi.string().trim().max(255),
      name: Joi.string().trim().max(255),
      firstName: Joi.string().trim().max(255),
      lastName: Joi.string().trim().max(255),
      senderName: Joi.string().trim().max(255),
      email: Joi.string().trim().max(255),
      phone: Joi.string().trim().max(50),
      phoneNumber: Joi.string().trim().max(50),
      source: Joi.string().trim().max(50),
      channel: Joi.string().trim().max(50),
      platform: Joi.string().trim().max(50),
      message: Joi.string().trim().max(5000),
      notes: Joi.string().trim().max(5000),
      body: Joi.string().trim().max(5000),
      text: Joi.string().trim().max(5000),
      desiredUnit: Joi.string().trim().max(255),
      listingTitle: Joi.string().trim().max(255),
      listingId: Joi.string().trim().max(255),
      adId: Joi.string().trim().max(255),
      budget: Joi.number().min(0),
      budgetCents: Joi.number().integer().min(0),
      language: Joi.string().valid('fr', 'en'),
    }).unknown(true),
  },
};

const leaseSchemas = {
  list: {
    query: Joi.object({
      page: pagination.extract('page'),
      limit: pagination.extract('limit'),
      status: Joi.string().valid('draft', 'active', 'expired', 'terminated'),
      buildingId: uuid,
      unitId: uuid,
      sortBy: Joi.string().valid('createdAt', 'updatedAt', 'startDate', 'endDate', 'rentCents', 'status'),
      sortOrder: Joi.string().valid('asc', 'desc'),
    }),
  },
  create: {
    body: Joi.object({
      unitId: uuid.required(),
      buildingId: uuid,
      tenantId: uuid.required(),
      startDate: Joi.date().iso().required(),
      endDate: Joi.date().iso().greater(Joi.ref('startDate')).required(),
      rentAmount: Joi.number().min(0).required(),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      startDate: Joi.date().iso(),
      endDate: Joi.date().iso(),
      rentAmount: Joi.number().min(0),
    }).min(1),
  },
  updateStatus: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      status: Joi.string().valid('draft', 'active', 'expired', 'terminated').required(),
    }),
  },
  sign: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      signatureType: Joi.string().valid('tenant', 'landlord', 'both').default('tenant'),
    }),
  },
};

const tenantChecklistSchemas = {
  start: {
    body: tenantChecklistStartSchema,
  },
  resume: {
    params: Joi.object({ id: uuid }),
    body: tenantChecklistResumeSchema,
  },
  pause: {
    params: Joi.object({ id: uuid }),
    body: tenantChecklistPauseSchema,
  },
  submit: {
    params: Joi.object({ id: uuid }),
    body: tenantChecklistSubmitSchema,
  },
  summary: {
    params: tenantChecklistSummaryParamsSchema,
  },
};

const employeeSchemas = {
  create: {
    body: Joi.object({
      firstName: Joi.string().trim().min(1).max(100).required(),
      lastName: Joi.string().trim().min(1).max(100).required(),
      email: Joi.string().email().trim().max(255).required(),
      phone: Joi.string().trim().max(50),
      role: Joi.string().valid('admin', 'manager', 'agent', 'maintenance').default('agent'),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      firstName: Joi.string().trim().min(1).max(100),
      lastName: Joi.string().trim().min(1).max(100),
      email: Joi.string().email().trim().max(255),
      phone: Joi.string().trim().max(50),
      role: Joi.string().valid('admin', 'manager', 'agent', 'maintenance'),
      isActive: Joi.boolean(),
    }).min(1),
  },
  assign: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      buildingId: uuid.required(),
      role: Joi.string().valid('manager', 'agent', 'maintenance').required(),
    }),
  },
  removeAssignment: {
    params: Joi.object({
      id: uuid,
      assignmentId: uuid,
    }),
  },
  capacity: {
    query: Joi.object({
      buildingId: uuid.required(),
      date: Joi.date().iso().required(),
    }),
  },
};

const visitExpand = Joi.string().pattern(
  /^\s*(unit|building|employee|lead)\s*(,\s*(unit|building|employee|lead)\s*)*$/,
);

const visitReasonCodes = Joi.string().valid(
  'tenant_request',
  'tenant_conflict',
  'host_unavailable',
  'access_issue',
  'weather',
  'tenant_no_show',
  'other',
);

const visitSchemas = {
  list: {
    query: Joi.object({
      page: pagination.extract('page'),
      limit: pagination.extract('limit'),
      status: Joi.string().valid('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'),
      employeeId: uuid,
      leadId: uuid,
      dateFrom: Joi.date(),
      dateTo: Joi.date(),
      sortBy: Joi.string().valid('dateTime', 'createdAt', 'status', 'durationMinutes', 'updatedAt').default('dateTime'),
      sortOrder: Joi.string().valid('asc', 'desc').default('desc'),
      expand: visitExpand,
    }),
  },
  create: {
    body: Joi.object({
      unitId: uuid.required(),
      employeeId: uuid.required(),
      leadId: uuid.required(),
      dateTime: Joi.date().iso().required(),
      durationMinutes: Joi.number().integer().min(1).max(1440),
      status: Joi.string().valid('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'),
      notes: Joi.string().trim().max(5000),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      unitId: uuid,
      employeeId: uuid,
      leadId: uuid,
      dateTime: Joi.date().iso(),
      durationMinutes: Joi.number().integer().min(1).max(1440),
      status: Joi.string().valid('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'),
      tenantConfirmed: Joi.boolean(),
      employeeConfirmed: Joi.boolean(),
      morningOfSent: Joi.boolean(),
      outcome: Joi.string().valid('interesse', 'pas_interesse', 'no_show').allow(null),
      reasonCode: visitReasonCodes.allow(null),
      completedAt: Joi.date().iso(),
      cancelledAt: Joi.date().iso(),
      noShowAt: Joi.date().iso(),
      rescheduledAt: Joi.date().iso(),
      notes: Joi.string().trim().max(5000),
      isActive: Joi.boolean(),
    }).min(1),
  },
  updateStatus: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      status: Joi.string().valid('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show').required(),
      outcome: Joi.string().valid('interesse', 'pas_interesse', 'no_show').allow(null),
      reasonCode: visitReasonCodes.allow(null),
      notes: Joi.string().trim().max(5000),
    }),
  },
  reschedule: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      dateTime: Joi.date().iso().required(),
      sendSms: Joi.boolean().default(true),
      reasonCode: visitReasonCodes.required(),
      notes: Joi.string().trim().max(5000),
    }),
  },
};



const paymentSchemas = {
  create: {
    body: Joi.object({
      leaseId: uuid.required(),
      amount: Joi.number().positive().required(),
      dueDate: Joi.date().iso().required(),
      method: Joi.string().valid('check', 'transfer', 'cash', 'interac', 'auto_debit'),
      reference: Joi.string().trim().max(255),
      notes: Joi.string().trim().max(5000),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      amount: Joi.number().positive(),
      paidDate: Joi.date().iso(),
      method: Joi.string().valid('check', 'transfer', 'cash', 'interac', 'auto_debit'),
      reference: Joi.string().trim().max(255),
      notes: Joi.string().trim().max(5000),
    }).min(1),
  },
  updateStatus: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      status: Joi.string().valid('pending', 'paid', 'late', 'partial').required(),
    }),
  },
};

const renewalSchemas = {
  create: {
    body: Joi.object({
      leaseId: uuid.required(),
      newStartDate: Joi.date().iso().required(),
      newEndDate: Joi.date().iso().greater(Joi.ref('newStartDate')).required(),
      newRent: Joi.number().min(0).required(),
      newDeposit: Joi.number().min(0),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      newRent: Joi.number().min(0),
      newDeposit: Joi.number().min(0),
    }).min(1),
  },
  updateStatus: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      status: Joi.string().valid('pending', 'sent', 'accepted', 'declined', 'expired').required(),
      tenantResponse: Joi.string().trim().max(5000),
    }),
  },
  send: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      channel: Joi.string().valid('sms', 'email', 'both').default('both'),
    }),
  },
  bulk: {
    body: Joi.object({
      windowDays: Joi.number().integer().min(1).max(365).default(90),
      defaultRentIncrease: Joi.number().min(0).max(1).default(0.02),
      newLeaseDurationMonths: Joi.number().integer().min(1).max(60).default(12),
    }),
  },
};

const validCommunicationActivityTypes = [
  'lead_created',
  'visit_scheduled',
  'visit_completed',
  'visit_cancelled',
  'visit_no_show',
  'visit_rescheduled',
  'sms_sent',
  'sms_received',
  'communication_logged',
];

const communicationActivityTypeFilter = Joi.string().custom((value, helpers) => {
  const requestedTypes = value.split(',').map((part) => part.trim()).filter(Boolean);
  const hasInvalidType = requestedTypes.some((type) => !validCommunicationActivityTypes.includes(type));

  if (requestedTypes.length === 0 || hasInvalidType) {
    return helpers.error('any.invalid');
  }

  return requestedTypes.join(',');
}, 'communication activity type filter');

const communicationSchemas = {
  list: {
    query: Joi.object({
      page: pagination.extract('page'),
      limit: pagination.extract('limit'),
      leadId: uuid,
      employeeId: uuid,
      type: Joi.string().valid('email', 'phone', 'sms', 'fb_messenger'),
      direction: Joi.string().valid('inbound', 'outbound'),
      status: Joi.string().trim().max(100),
    }),
  },
  activity: {
    query: Joi.object({
      limit: Joi.number().integer().min(1).max(100).default(20),
      hoursAgo: Joi.number().integer().min(1).max(720).default(168),
      type: communicationActivityTypeFilter,
    }),
  },
  threads: {
    query: Joi.object({
      page: pagination.extract('page'),
      limit: pagination.extract('limit'),
      leadId: uuid,
      employeeId: uuid,
      type: Joi.string().valid('email', 'phone', 'sms', 'fb_messenger'),
      direction: Joi.string().valid('inbound', 'outbound'),
      status: Joi.string().trim().max(100),
      includeMessages: Joi.boolean().default(true),
    }),
  },
  logs: {
    query: Joi.object({
      page: pagination.extract('page'),
      limit: pagination.extract('limit'),
      leadId: uuid,
      employeeId: uuid,
      type: Joi.string().valid('email', 'phone', 'sms', 'fb_messenger'),
      direction: Joi.string().valid('inbound', 'outbound'),
      status: Joi.string().trim().max(100),
    }),
  },
  log: {
    body: Joi.object({
      leadId: uuid.allow(null),
      employeeId: uuid.allow(null),
      type: Joi.string().valid('email', 'phone', 'sms', 'fb_messenger').required(),
      direction: Joi.string().valid('inbound', 'outbound').required(),
      subject: Joi.string().trim().max(500),
      content: Joi.string().trim().max(10000),
      body: Joi.string().trim().max(10000),
      attachments: Joi.array().items(Joi.alternatives(Joi.string(), Joi.object())).default([]),
      status: Joi.string().trim().max(100),
      metadata: Joi.object().unknown(true).default({}),
    }),
  },
  updateLog: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      subject: Joi.string().trim().max(500),
      content: Joi.string().trim().max(10000),
      body: Joi.string().trim().max(10000),
      attachments: Joi.array().items(Joi.alternatives(Joi.string(), Joi.object())),
      status: Joi.string().valid('sent', 'delivered', 'read', 'failed'),
      metadata: Joi.object().unknown(true),
    }).min(1),
  },
};

const marketplaceSchemas = {
  inbox: {
    query: Joi.object({
      page: pagination.extract('page'),
      limit: pagination.extract('limit'),
      search: Joi.string().trim().max(255),
      stage: Joi.string().valid(...VALID_LEAD_STAGES),
      assignedEmployeeId: uuid,
      source: Joi.string().trim().max(100),
    }),
  },
  timeline: {
    params: Joi.object({ leadId: uuid }),
    query: Joi.object({
      limit: Joi.number().integer().min(1).max(100).default(50),
      hoursAgo: Joi.number().integer().min(1).max(720).default(168),
      type: communicationActivityTypeFilter,
    }),
  },
  leadMessage: {
    params: Joi.object({ leadId: uuid }),
    body: Joi.object({
      employeeId: uuid.allow(null),
      type: Joi.string().valid('email', 'phone', 'sms', 'fb_messenger').required(),
      direction: Joi.string().valid('inbound', 'outbound').required(),
      subject: Joi.string().trim().max(500),
      content: Joi.string().trim().max(10000),
      body: Joi.string().trim().max(10000),
      attachments: Joi.array().items(Joi.alternatives(Joi.string(), Joi.object())).default([]),
      status: Joi.string().trim().max(100),
      metadata: Joi.object().unknown(true).default({}),
    }).or('content', 'body'),
  },
  leadVisit: {
    params: Joi.object({ leadId: uuid }),
    body: Joi.object({
      unitId: uuid.required(),
      employeeId: uuid.required(),
      dateTime: Joi.date().iso().required(),
      durationMinutes: Joi.number().integer().min(1).max(1440),
      status: Joi.string().valid('scheduled', 'confirmed', 'in_progress', 'completed', 'cancelled', 'no_show'),
      notes: Joi.string().trim().max(5000),
    }),
  },
};

const validDocumentTypes = ['lease', 'application', 'id', 'income_proof', 'other'];
const validReferenceTypes = ['lead', 'building', 'unit'];

const documentSchemas = {
  create: {
    body: Joi.object({
      name: Joi.string().trim().min(1).max(255).required(),
      type: Joi.string().valid(...validDocumentTypes).required(),
      category: Joi.string().trim().max(100),
      fileSize: Joi.number().integer().min(0),
      mimeType: Joi.string().trim().max(100),
      url: Joi.string().uri({ scheme: ['http', 'https'] }).required(),
      referenceId: uuid,
      referenceType: Joi.string().valid(...validReferenceTypes),
      metadata: Joi.object().max(50).default({}),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      name: Joi.string().trim().min(1).max(255),
      type: Joi.string().valid(...validDocumentTypes),
      category: Joi.string().trim().max(100),
      fileSize: Joi.number().integer().min(0),
      mimeType: Joi.string().trim().max(100),
      url: Joi.string().uri({ scheme: ['http', 'https'] }),
      referenceId: uuid,
      referenceType: Joi.string().valid(...validReferenceTypes),
      metadata: Joi.object().max(50),
    }).min(1),
  },
  approve: {
    params: Joi.object({ id: uuid }),
  },
  reject: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      reason: Joi.string().trim().max(5000),
    }),
  },
};

const scheduleSchemas = {
  create: {
    body: Joi.object({
      employeeId: uuid.required(),
      buildingId: uuid.required(),
      dayOfWeek: Joi.number().integer().min(0).max(6).required(),
      startTime: Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/).required(),
      endTime: Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/).required(),
      isAvailable: Joi.boolean().default(true),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      buildingId: uuid,
      dayOfWeek: Joi.number().integer().min(0).max(6),
      startTime: Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/),
      endTime: Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/),
      isAvailable: Joi.boolean(),
    }).min(1),
  },
  getAvailability: {
    params: Joi.object({ employeeId: uuid.required() }),
    query: Joi.object({ date: Joi.date().iso() }),
  },
};

const notificationSchemas = {
  updatePreferences: {
    body: Joi.object({
      email: Joi.boolean(),
      sms: Joi.boolean(),
      inApp: Joi.boolean(),
      visitReminders: Joi.boolean(),
      leadUpdates: Joi.boolean(),
      leaseAlerts: Joi.boolean(),
    }).min(1),
  },
};

const observationResultDomainValues = ['lead', 'message', 'visit', 'follow-up'];
const observationResultStatusValues = ['new', 'reviewed', 'dismissed', 'converted'];

const observationResultItemSchema = Joi.object({
  projectId: uuid,
  domain: Joi.string().valid(...observationResultDomainValues).required(),
  sourceKind: Joi.string().trim().min(1).max(100).required(),
  sourceRef: Joi.string().trim().max(255),
  sourceFingerprint: Joi.string().trim().max(255),
  title: Joi.string().trim().min(1).max(500).required(),
  summary: Joi.string().trim().min(1).max(5000).required(),
  details: Joi.object().unknown(true).default({}),
  privacyClass: Joi.string().valid('redacted', 'summary').default('redacted'),
  confidence: Joi.number().min(0).max(1),
  leadId: uuid,
  visitId: uuid,
  communicationLogId: uuid,
  followUpType: Joi.string().trim().max(100),
  followUpDueAt: Joi.date().iso(),
});

const observationResultReviewSchema = Joi.object({
  title: Joi.string().trim().min(1).max(500),
  summary: Joi.string().trim().min(1).max(5000),
  details: Joi.object().unknown(true),
  confidence: Joi.number().min(0).max(1),
  projectId: uuid.allow(null),
  leadId: uuid.allow(null),
  visitId: uuid.allow(null),
  communicationLogId: uuid.allow(null),
  followUpType: Joi.string().trim().max(100).allow(null),
  followUpDueAt: Joi.date().iso().allow(null),
}).min(1);

const observationResultDismissSchema = Joi.object({
  reason: Joi.string().trim().min(1).max(2000).allow(null, ''),
});

const maintenanceUrgencies = ['basse', 'moyenne', 'haute', 'urgence'];
const maintenanceStatuses = ['ouvert', 'en_cours', 'resolu'];

const maintenanceSchemas = {
  commandCenter: {
    query: Joi.object({
      buildingId: uuid,
      limit: Joi.number().integer().min(1).max(50).default(12),
    }),
  },
  listTickets: {
    query: Joi.object({
      page: pagination.extract('page'),
      limit: pagination.extract('limit'),
      status: Joi.string().valid(...maintenanceStatuses),
      urgency: Joi.string().valid(...maintenanceUrgencies),
      buildingId: uuid,
      search: Joi.string().trim().max(255),
    }),
  },
  ticketId: {
    params: Joi.object({ id: uuid }),
  },
  createTicket: {
    body: Joi.object({
      title: Joi.string().trim().min(1).max(255).required(),
      description: Joi.string().trim().max(5000),
      urgency: Joi.string().valid(...maintenanceUrgencies).default('moyenne'),
      status: Joi.string().valid(...maintenanceStatuses).default('ouvert'),
      source: Joi.string().trim().max(50),
      tenantId: uuid,
      tenantName: Joi.string().trim().max(255),
      callerPhone: Joi.string().trim().max(50),
      unitId: uuid,
      buildingId: uuid,
      photos: Joi.array().items(Joi.string().trim().max(1000)).max(20),
    }),
  },
  updateTicket: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      title: Joi.string().trim().min(1).max(255),
      description: Joi.string().trim().max(5000).allow(null, ''),
      urgency: Joi.string().valid(...maintenanceUrgencies),
      status: Joi.string().valid(...maintenanceStatuses),
      tenantName: Joi.string().trim().max(255).allow(null, ''),
      unitId: uuid.allow(null),
      buildingId: uuid.allow(null),
      photos: Joi.array().items(Joi.string().trim().max(1000)).max(20),
      isActive: Joi.boolean(),
    }).min(1),
  },
  vapiWebhook: {
    body: Joi.object().unknown(true),
  },
};

const observationResultSchemas = {
  import: {
    params: Joi.object({ companyId: uuid.required() }),
    body: Joi.alternatives().try(
      observationResultItemSchema,
      Joi.array().items(observationResultItemSchema).min(1).max(100),
    ),
  },
  list: {
    params: Joi.object({ companyId: uuid.required() }),
    query: Joi.object({
      page: pagination.extract('page'),
      limit: pagination.extract('limit'),
      status: Joi.string().valid(...observationResultStatusValues),
      domain: Joi.string().valid(...observationResultDomainValues),
      leadId: uuid,
      visitId: uuid,
      communicationLogId: uuid,
      followUpType: Joi.string().trim().max(100),
      sourceKind: Joi.string().trim().max(100),
      projectId: uuid,
    }),
  },
  detail: {
    params: Joi.object({ companyId: uuid.required(), id: uuid.required() }),
  },
  review: {
    params: Joi.object({ companyId: uuid.required(), id: uuid.required() }),
    body: observationResultReviewSchema,
  },
  dismiss: {
    params: Joi.object({ companyId: uuid.required(), id: uuid.required() }),
    body: observationResultDismissSchema,
  },
};

const dossierCaseCategoryValues = ['maintenance', 'payment', 'visit', 'lease', 'documents', 'general'];
const dossierCaseStatusValues = ['draft', 'in_review', 'approved', 'exported', 'archived'];

const dossierCaseCreateSchema = Joi.object({
  leadId: uuid.allow(null),
  unitId: uuid.allow(null),
  problemCategory: Joi.string().valid(...dossierCaseCategoryValues).required(),
  incidentWindowStart: Joi.date().iso().allow(null),
  incidentWindowEnd: Joi.date().iso().allow(null),
}).min(1);

const dossierCaseReviewSchema = Joi.object({
  status: Joi.string().valid(...dossierCaseStatusValues).required(),
  reviewNotes: Joi.string().trim().max(5000).allow(null, ''),
}).required();

const dossierCaseSchemas = {
  list: {
    params: Joi.object({ companyId: uuid.required() }),
    query: Joi.object({
      status: Joi.string().valid(...dossierCaseStatusValues),
      limit: pagination.extract('limit'),
    }),
  },
  create: {
    params: Joi.object({ companyId: uuid.required() }),
    body: dossierCaseCreateSchema,
  },
  detail: {
    params: Joi.object({ companyId: uuid.required(), id: uuid.required() }),
  },
  review: {
    params: Joi.object({ companyId: uuid.required(), id: uuid.required() }),
    body: dossierCaseReviewSchema,
  },
  export: {
    params: Joi.object({ companyId: uuid.required(), id: uuid.required() }),
  },
};

const smsWebhookSchemas = {
  incoming: {
    body: Joi.object({
      MessageSid: Joi.string().trim().max(64),
      SmsMessageSid: Joi.string().trim().max(64),
      From: Joi.string().trim().max(50).required(),
      To: Joi.string().trim().max(50).required(),
      Body: Joi.string().trim().max(1600).allow('', null),
      NumMedia: Joi.number().integer().min(0).max(10).default(0),
      MediaUrl0: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaUrl1: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaUrl2: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaUrl3: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaUrl4: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaUrl5: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaUrl6: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaUrl7: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaUrl8: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaUrl9: Joi.string().uri({ scheme: ['http', 'https'] }),
      MediaContentType0: Joi.string().trim().max(255),
      MediaContentType1: Joi.string().trim().max(255),
      MediaContentType2: Joi.string().trim().max(255),
      MediaContentType3: Joi.string().trim().max(255),
      MediaContentType4: Joi.string().trim().max(255),
      MediaContentType5: Joi.string().trim().max(255),
      MediaContentType6: Joi.string().trim().max(255),
      MediaContentType7: Joi.string().trim().max(255),
      MediaContentType8: Joi.string().trim().max(255),
      MediaContentType9: Joi.string().trim().max(255),
    }),
  },
  status: {
    body: Joi.object({
      MessageSid: Joi.string().trim().max(64).required(),
      SmsStatus: Joi.string()
        .valid('queued', 'sent', 'delivered', 'undelivered', 'failed', 'read'),
      MessageStatus: Joi.string()
        .valid('queued', 'sent', 'delivered', 'undelivered', 'failed', 'read'),
      ErrorMessage: Joi.string().trim().max(500),
    }).or('SmsStatus', 'MessageStatus'),
  },
  schedule: {
    body: Joi.object({
      action: Joi.string()
        .valid('morning_reminder', 'post_survey', 'reminder_24h', 'reminder_2h', 'expire_confirmations')
        .required(),
      visitId: Joi.string().uuid(),
    }),
  },
};

const analyticsSchemas = {
  dashboard: {
    query: Joi.object({
      period: Joi.string().valid('today', 'week', 'month', 'quarter', 'year').default('month'),
    }),
  },
  hotLeads: {
    query: Joi.object({
      limit: Joi.number().integer().min(1).max(100).default(10),
    }),
  },
  visitStats: {
    query: Joi.object({
      dateFrom: Joi.date().iso(),
      dateTo: Joi.date().iso().greater(Joi.ref('dateFrom')),
    }),
  },
  visitMetrics: {
    query: Joi.object({
      dateFrom: Joi.date().iso(),
      dateTo: Joi.date().iso().greater(Joi.ref('dateFrom')),
    }),
  },
  trendMonths: {
    query: Joi.object({
      months: Joi.number().integer().min(1).max(60).default(12),
    }),
  },
  buildingPerformance: {
    params: Joi.object({ id: uuid }),
  },
  employeePerformance: {
    params: Joi.object({ id: uuid }),
  },
};

const plexflowSchemas = {
  idParam: {
    params: Joi.object({ id: Joi.string().trim().min(1).max(128).required() }),
  },
};

const plexflowWebhookSchemas = {
  // PlexFlow payload shapes vary by event — accept anything, parse in service.
  webhook: {
    body: Joi.object().unknown(true),
  },
};

const messageTemplateEventTypes = [
  'tenant_deactivated',
  'tenant_activated',
  'lease_created',
  'lease_renewed',
  'unit_vacant',
  'unit_occupied',
];

const messageTemplateSchemas = {
  update: {
    params: Joi.object({
      eventType: Joi.string().valid(...messageTemplateEventTypes).required(),
    }),
    body: Joi.object({
      body: Joi.string().trim().min(1).max(2000),
      subject: Joi.string().trim().max(255).allow(null, ''),
      channel: Joi.string().valid('sms', 'email'),
      isActive: Joi.boolean(),
    }).min(1),
  },
};

const departurePhotoSchemas = {
  list: {
    query: Joi.object({
      page: pagination.extract('page'),
      limit: Joi.number().integer().min(1).max(200).default(50),
      buildingId: uuid,
      unitId: uuid,
      eventType: Joi.string().valid('departure', 'arrival'),
    }),
  },
  create: {
    body: Joi.object({
      buildingId: uuid,
      unitId: uuid,
      tenantName: Joi.string().trim().max(255),
      eventType: Joi.string().valid('departure', 'arrival').default('departure'),
      photoUrl: Joi.string().uri({ scheme: ['http', 'https'] }).max(1000),
      notes: Joi.string().trim().max(2000),
    }).min(1),
  },
  idParam: {
    params: Joi.object({ id: uuid.required() }),
  },
};

const tenantConfirmationSchemas = {
  submit: {
    params: Joi.object({ token: Joi.string().trim().min(1).max(255).required() }),
    body: Joi.object({
      action: Joi.string().valid('confirm', 'decline').required(),
    }),
  },
  getPage: {
    params: Joi.object({ token: Joi.string().trim().min(1).max(255).required() }),
  },
};

const facebookWebhookSchemas = {
  verify: {
    query: Joi.object({
      'hub.mode': Joi.string().valid('subscribe').required(),
      'hub.verify_token': Joi.string().trim().required(),
      'hub.challenge': Joi.string().trim().required(),
    }),
  },
  webhook: {
    body: Joi.object({
      object: Joi.string().trim(),
      entry: Joi.array().items(
        Joi.object({
          id: Joi.string(),
          messaging: Joi.array(),
          changes: Joi.array().items(
            Joi.object({
              field: Joi.string().trim(),
              value: Joi.object().unknown(true),
            }).unknown(true),
          ),
        }).unknown(true),
      ),
    }),
  },
};

const smsCampaignSchemas = {
  createTemplate: {
    body: Joi.object({
      name: Joi.string().trim().min(1).max(100).required(),
      body: Joi.string().trim().min(1).max(1000).required(),
      category: Joi.string().trim().max(100),
    }),
  },
  updateTemplate: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      name: Joi.string().trim().min(1).max(100),
      body: Joi.string().trim().min(1).max(1000),
      category: Joi.string().trim().max(100),
      isActive: Joi.boolean(),
    }).min(1),
  },
  createCampaign: {
    body: Joi.object({
      name: Joi.string().trim().min(1).max(255).required(),
      templateId: uuid.required(),
      recipientIds: Joi.array().items(uuid).min(1).max(5000).required(),
      scheduledAt: Joi.date().iso(),
    }),
  },
  updateCampaign: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      name: Joi.string().trim().min(1).max(255),
      recipientIds: Joi.array().items(uuid).min(1).max(5000),
      scheduledAt: Joi.date().iso(),
    }).min(1),
  },
};

module.exports = {
  uuidParam,
  buildingIdParam,
  pagination,
  buildingSchemas,
  leadSchemas,
  leaseSchemas,
  tenantChecklistSchemas,
  photoRecordSchemas,
  employeeSchemas,
  visitSchemas,
  paymentSchemas,
  renewalSchemas,
  communicationSchemas,
  marketplaceSchemas,
  documentSchemas,
  scheduleSchemas,
  notificationSchemas,
  maintenanceSchemas,
  observationResultSchemas,
  smsCampaignSchemas,
  dossierCaseSchemas,
  smsWebhookSchemas,
  analyticsSchemas,
  plexflowSchemas,
  plexflowWebhookSchemas,
  messageTemplateSchemas,
  departurePhotoSchemas,
  tenantConfirmationSchemas,
  facebookWebhookSchemas,
};
