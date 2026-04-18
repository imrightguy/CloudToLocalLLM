const Joi = require('joi');
const { VALID_LEAD_STAGES } = require('../constants/lead-stages');

const uuid = Joi.string().uuid();

const pagination = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
});

const uuidParam = { params: Joi.object({ id: uuid }) };

const buildingIdParam = { params: Joi.object({ buildingId: uuid }) };

const buildingSchemas = {
  create: {
    body: Joi.object({
      name: Joi.string().trim().min(1).max(255).required(),
      address: Joi.string().trim().min(1).max(500).required(),
      city: Joi.string().trim().min(1).max(255).required(),
      province: Joi.string().trim().max(10).default('QC'),
      postalCode: Joi.string().trim().max(10),
      totalUnits: Joi.number().integer().min(0),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      name: Joi.string().trim().min(1).max(255),
      address: Joi.string().trim().min(1).max(500),
      city: Joi.string().trim().min(1).max(255),
      province: Joi.string().trim().max(10),
      postalCode: Joi.string().trim().max(10),
      totalUnits: Joi.number().integer().min(0),
    }).min(1),
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
  create: {
    body: Joi.object({
      fullName: Joi.string().trim().min(1).max(255).required(),
      email: Joi.string().email().trim().max(255),
      phone: Joi.string().trim().max(50),
      budgetCents: Joi.number().integer().min(0),
      desiredUnit: Joi.string().trim().max(100),
      source: Joi.string().trim().max(100).default('other'),
      stage: Joi.string().valid(...VALID_LEAD_STAGES).default('nouveau'),
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
        buildingId: uuid,
        employeeId: uuid,
      }).min(1).required(),
    }),
  },
};

const leaseSchemas = {
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
};

const visitSchemas = {
  create: {
    body: Joi.object({
      leadId: uuid.required(),
      buildingId: uuid.required(),
      unitId: uuid,
      employeeId: uuid,
      scheduledAt: Joi.date().iso().greater('now').required(),
      notes: Joi.string().trim().max(5000),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      scheduledAt: Joi.date().iso().greater('now'),
      employeeId: uuid,
      notes: Joi.string().trim().max(5000),
    }).min(1),
  },
  updateStatus: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      status: Joi.string().valid('scheduled', 'completed', 'cancelled', 'no_show').required(),
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

const communicationSchemas = {
  log: {
    body: Joi.object({
      leadId: uuid.required(),
      type: Joi.string().valid('email', 'phone', 'sms', 'in_person', 'whatsapp').required(),
      direction: Joi.string().valid('inbound', 'outbound').required(),
      subject: Joi.string().trim().max(500),
      content: Joi.string().trim().max(10000),
    }),
  },
  updateLog: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
      subject: Joi.string().trim().max(500),
      content: Joi.string().trim().max(10000),
      type: Joi.string().valid('email', 'phone', 'sms', 'in_person', 'whatsapp'),
    }).min(1),
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
      dayOfWeek: Joi.number().integer().min(0).max(6).required(),
      startTime: Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/).required(),
      endTime: Joi.string().pattern(/^([01]\d|2[0-3]):[0-5]\d$/).required(),
      isAvailable: Joi.boolean().default(true),
    }),
  },
  update: {
    params: Joi.object({ id: uuid }),
    body: Joi.object({
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

const smsWebhookSchemas = {
  incoming: {
    body: Joi.object({
      MessageSid: Joi.string().trim().max(64),
      From: Joi.string().trim().max(50).required(),
      To: Joi.string().trim().max(50).required(),
      Body: Joi.string().trim().max(1600).required(),
    }),
  },
  status: {
    body: Joi.object({
      MessageSid: Joi.string().trim().max(64).required(),
      SmsStatus: Joi.string()
        .valid('queued', 'sent', 'delivered', 'undelivered', 'failed', 'read'),
      ErrorMessage: Joi.string().trim().max(500),
    }),
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
        }),
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
  employeeSchemas,
  visitSchemas,
  paymentSchemas,
  renewalSchemas,
  communicationSchemas,
  documentSchemas,
  scheduleSchemas,
  notificationSchemas,
  smsCampaignSchemas,
  smsWebhookSchemas,
  analyticsSchemas,
  tenantConfirmationSchemas,
  facebookWebhookSchemas,
};
