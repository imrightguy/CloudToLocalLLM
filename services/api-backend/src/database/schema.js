const { sql } = require('drizzle-orm');
const {
  pgTable, text, integer, timestamp, boolean, jsonb, uuid, index,
} = require('drizzle-orm/pg-core');

// ─── Users (app login — Simon + future admins only) ───
const usersTable = pgTable('users', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  email: text('email').notNull().unique(),
  passwordHash: text('password_hash').notNull(),
  firstName: text('first_name').notNull(),
  lastName: text('last_name').notNull(),
  phone: text('phone'),
  role: text('role').notNull().default('admin'),
  isActive: boolean('is_active').notNull().default(true),
  emailVerified: boolean('email_verified').notNull().default(false),
  tokenVersion: integer('token_version').notNull().default(1),
  lastLogin: timestamp('last_login'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// ─── Refresh Tokens ───
const refreshTokensTable = pgTable('refresh_tokens', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => usersTable.id, { onDelete: 'cascade' }),
  token: text('token').notNull().unique(),
  expiresAt: timestamp('expires_at').notNull(),
  ip: text('ip'),
  userAgent: text('user_agent'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
}, (table) => ({
  userIdIdx: index('rt_user_id_idx').on(table.userId),
}));

// ─── Employees (show apartments via SMS only — NO app access) ───
const employeesTable = pgTable('employees', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  firstName: text('first_name').notNull(),
  lastName: text('last_name').notNull(),
  phone: text('phone').notNull().unique(),
  email: text('email'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// ─── Buildings ───
const buildingsTable = pgTable('buildings', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  name: text('name').notNull(),
  address: text('address').notNull(),
  city: text('city').default('Montréal'),
  province: text('province').default('QC'),
  postalCode: text('postal_code'),
  totalUnits: integer('total_units').notNull().default(0),
  occupiedUnits: integer('occupied_units').notNull().default(0),
  description: text('description'),
  properties: jsonb('properties').default('{}'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// ─── Employee-Building Assignments (primary / backup) ───
const employeeAssignmentsTable = pgTable('employee_assignments', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  employeeId: uuid('employee_id').notNull().references(() => employeesTable.id, { onDelete: 'cascade' }),
  buildingId: uuid('building_id').notNull().references(() => buildingsTable.id, { onDelete: 'cascade' }),
  role: text('role').notNull().default('primary'), // primary | backup
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  employeeBuildingIdx: index('ea_employee_building_idx').on(table.employeeId, table.buildingId),
}));

// ─── Units ───
const unitsTable = pgTable('units', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  buildingId: uuid('building_id').notNull().references(() => buildingsTable.id, { onDelete: 'cascade' }),
  label: text('label').notNull(),
  rentCents: integer('rent_cents').notNull(), // stored in CENTS
  status: text('status').notNull().default('vacant'), // vacant | occupied | maintenance
  bedrooms: integer('bedrooms'),
  bathrooms: integer('bathrooms'),
  squareFeet: integer('square_feet'),
  description: text('description'),
  amenities: jsonb('amenities').default('{}'),
  tenantName: text('tenant_name'),
  tenantPhone: text('tenant_phone'),
  tenantLeaseEnd: timestamp('tenant_lease_end'), // null = no tenant / vacant
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  buildingIdx: index('units_building_id_idx').on(table.buildingId),
  statusIdx: index('units_status_idx').on(table.status),
}));

// ─── Employee Weekly Schedule ───
const employeeSchedulesTable = pgTable('employee_schedules', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  employeeId: uuid('employee_id').notNull().references(() => employeesTable.id, { onDelete: 'cascade' }),
  buildingId: uuid('building_id').notNull().references(() => buildingsTable.id, { onDelete: 'cascade' }),
  dayOfWeek: integer('day_of_week').notNull(), // 0=Monday … 6=Sunday
  startTime: text('start_time').notNull(), // "09:00"
  endTime: text('end_time').notNull(), // "17:00"
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  employeeIdx: index('es_employee_id_idx').on(table.employeeId),
  buildingIdx: index('es_building_id_idx').on(table.buildingId),
}));

// ─── Leads (potential tenants) ───
const leadsTable = pgTable('leads', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  fullName: text('full_name').notNull(),
  email: text('email'),
  phone: text('phone'),
  budgetCents: integer('budget_cents'),
  desiredUnit: text('desired_unit'),
  source: text('source').notNull().default('other'), // facebook | website | referral | other
  stage: text('stage').notNull().default('nouveau'), // User-facing: nouveau | contacte | qualifie | visitePlanifiee | visite_planifiee | offreEnvoyee | negociation | bailSigne | signe | Internal SMS-flow: visite_completee | interesse | inactif
  notes: text('notes'),
  tags: jsonb('tags').default('[]'),
  language: text('language').default('fr'), // fr | en
  assignedEmployeeId: uuid('assigned_employee_id').references(() => employeesTable.id),
  buildingId: uuid('building_id').references(() => buildingsTable.id),
  unitId: uuid('unit_id').references(() => unitsTable.id),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  stageIdx: index('leads_stage_idx').on(table.stage),
  buildingIdx: index('leads_building_id_idx').on(table.buildingId),
  sourceIdx: index('leads_source_idx').on(table.source),
  employeeIdx: index('leads_assigned_employee_id_idx').on(table.assignedEmployeeId),
}));

// ─── Visits ───
const visitsTable = pgTable('visits', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  unitId: uuid('unit_id').notNull().references(() => unitsTable.id),
  employeeId: uuid('employee_id').notNull().references(() => employeesTable.id),
  leadId: uuid('lead_id').notNull().references(() => leadsTable.id),
  dateTime: timestamp('date_time').notNull(),
  durationMinutes: integer('duration_minutes').notNull().default(30),
  status: text('status').notNull().default('scheduled'), // scheduled | confirmed | in_progress | completed | cancelled | no_show
  tenantConfirmed: boolean('tenant_confirmed').notNull().default(false),
  occupantNotified: boolean('occupant_notified').notNull().default(false), // SMS sent to current occupant for access
  employeeConfirmed: boolean('employee_confirmed').notNull().default(false),
  morningOfSent: boolean('morning_of_sent').notNull().default(false),
  confirmationToken: text('confirmation_token').unique(), // unique token for tenant web-based confirmation
  outcome: text('outcome'), // interesse | pas_interesse | no_show | null
  notes: text('notes'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  dateTimeIdx: index('visits_date_time_idx').on(table.dateTime),
  statusIdx: index('visits_status_idx').on(table.status),
  employeeIdx: index('visits_employee_id_idx').on(table.employeeId),
  leadIdx: index('visits_lead_id_idx').on(table.leadId),
}));

// ─── SMS Logs (Twilio) ───
const smsLogsTable = pgTable('sms_logs', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  twilioSid: text('twilio_sid').unique(),
  visitId: uuid('visit_id').references(() => visitsTable.id),
  employeeId: uuid('employee_id').references(() => employeesTable.id),
  leadId: uuid('lead_id').references(() => leadsTable.id),
  phoneNumber: text('phone_number').notNull(),
  direction: text('direction').notNull(), // inbound | outbound
  messageBody: text('message_body'),
  status: text('status').notNull().default('queued'), // queued | sent | delivered | read | failed
  twilioStatus: text('twilio_status'),
  errorMessage: text('error_message'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  visitIdx: index('sms_logs_visit_id_idx').on(table.visitId),
  phoneIdx: index('sms_logs_phone_number_idx').on(table.phoneNumber),
  leadIdx: index('sms_logs_lead_id_idx').on(table.leadId),
}));

// ─── Communication Logs ───
const communicationLogsTable = pgTable('communication_logs', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  leadId: uuid('lead_id').references(() => leadsTable.id),
  employeeId: uuid('employee_id').references(() => employeesTable.id),
  type: text('type').notNull(), // sms | email | phone | fb_messenger
  direction: text('direction').notNull(), // inbound | outbound
  content: text('content'),
  subject: text('subject'),
  attachments: jsonb('attachments').default('[]'),
  status: text('status').notNull().default('sent'), // sent | delivered | read | failed
  metadata: jsonb('metadata').default('{}'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
}, (table) => ({
  leadIdx: index('comm_logs_lead_id_idx').on(table.leadId),
}));

// ─── Documents ───
const documentsTable = pgTable('documents', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  name: text('name').notNull(),
  type: text('type').notNull(), // lease | application | id | income_proof | other
  category: text('category'),
  fileSize: integer('file_size'),
  mimeType: text('mime_type'),
  url: text('url').notNull(),
  status: text('status').notNull().default('pending'), // pending | approved | rejected
  referenceId: uuid('reference_id'),
  referenceType: text('reference_type'), // lead | building | unit
  metadata: jsonb('metadata').default('{}'),
  uploadedBy: uuid('uploaded_by').references(() => usersTable.id),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// ─── Leases ───
const leasesTable = pgTable('leases', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  unitId: uuid('unit_id').notNull().references(() => unitsTable.id, { onDelete: 'cascade' }),
  leadId: uuid('lead_id').references(() => leadsTable.id, { onDelete: 'set null' }),
  tenantFirstName: text('tenant_first_name').notNull(),
  tenantLastName: text('tenant_last_name').notNull(),
  tenantEmail: text('tenant_email'),
  tenantPhone: text('tenant_phone'),
  rentCents: integer('rent_cents').notNull(),
  depositCents: integer('deposit_cents').notNull().default(0),
  startDate: timestamp('start_date', { mode: 'date' }).notNull(),
  endDate: timestamp('end_date', { mode: 'date' }).notNull(),
  status: text('status').notNull().default('draft'), // draft | active | expired | terminated | renewed
  terms: jsonb('terms').default('{}'),
  signedAt: timestamp('signed_at'),
  createdBy: uuid('created_by').references(() => usersTable.id, { onDelete: 'set null' }),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  unitIdx: index('leases_unit_id_idx').on(table.unitId),
  statusIdx: index('leases_status_idx').on(table.status),
}));

// ─── Document-Lead junction ───
const documentsLeadsTable = pgTable('documents_leads', {
  documentId: uuid('document_id').notNull().references(() => documentsTable.id, { onDelete: 'cascade' }),
  leadId: uuid('lead_id').notNull().references(() => leadsTable.id, { onDelete: 'cascade' }),
  assignedAt: timestamp('assigned_at').notNull().defaultNow(),
}, (table) => ({
  pk: { primaryKey: { columns: [table.documentId, table.leadId] } },
}));

// ─── SMS Templates ───
const smsTemplatesTable = pgTable('sms_templates', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  name: text('name').notNull(),
  body: text('body').notNull(),
  language: text('language').notNull().default('fr'),
  category: text('category').notNull(), // visit_reminder | lease_renewal | payment_reminder | custom
  description: text('description'),
  variables: jsonb('variables').default('[]'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// ─── SMS Campaigns ───
const smsCampaignsTable = pgTable('sms_campaigns', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  name: text('name').notNull(),
  description: text('description'),
  templateId: uuid('template_id').references(() => smsTemplatesTable.id, { onDelete: 'set null' }),
  targetAudience: text('target_audience').notNull(), // all_tenants | building_tenants | specific_leads
  buildingId: uuid('building_id').references(() => buildingsTable.id, { onDelete: 'set null' }),
  scheduleType: text('schedule_type').notNull().default('once'), // once | recurring
  cronExpression: text('cron_expression'),
  scheduledAt: timestamp('scheduled_at'),
  status: text('status').notNull().default('draft'), // draft | active | paused | completed | cancelled
  lastRunAt: timestamp('last_run_at'),
  nextRunAt: timestamp('next_run_at'),
  totalSent: integer('total_sent').notNull().default(0),
  totalFailed: integer('total_failed').notNull().default(0),
  templateData: jsonb('template_data').default('{}'),
  isActive: boolean('is_active').notNull().default(true),
  createdBy: uuid('created_by').references(() => usersTable.id, { onDelete: 'set null' }),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// ─── Notification Preferences (per user) ───
const notificationPreferencesTable = pgTable('notification_preferences', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => usersTable.id, { onDelete: 'cascade' }).unique(),
  emailNotifications: boolean('email_notifications').notNull().default(true),
  smsNotifications: boolean('sms_notifications').notNull().default(false),
  weeklyDigest: boolean('weekly_digest').notNull().default(true),
  quietHoursEnabled: boolean('quiet_hours_enabled').notNull().default(false),
  quietHoursStart: text('quiet_hours_start').default('22:00'), // HH:mm
  quietHoursEnd: text('quiet_hours_end').default('08:00'), // HH:mm
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// ─── In-App Notifications ───
const notificationsTable = pgTable('notifications', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  userId: uuid('user_id').notNull().references(() => usersTable.id, { onDelete: 'cascade' }),
  type: text('type').notNull(), // new_lead | lease_signed | visit_scheduled | no_show | weekly_digest | system
  title: text('title').notNull(),
  message: text('message').notNull(),
  data: jsonb('data').default('{}'),
  isRead: boolean('is_read').notNull().default(false),
  createdAt: timestamp('created_at').notNull().defaultNow(),
}, (table) => ({
  userIdReadIdx: index('notifications_user_read_idx').on(table.userId, table.isRead),
}));

// ─── Rent Payments ───
const paymentsTable = pgTable('payments', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  leaseId: uuid('lease_id').notNull().references(() => leasesTable.id, { onDelete: 'cascade' }),
  amountCents: integer('amount_cents').notNull(),
  lateFeeCents: integer('late_fee_cents').notNull().default(0),
  dueDate: timestamp('due_date', { mode: 'date' }).notNull(),
  paidDate: timestamp('paid_date', { mode: 'date' }),
  status: text('status').notNull().default('pending'), // pending | paid | late | partial
  method: text('method'), // check | transfer | cash | interac | auto_debit
  reference: text('reference'),
  notes: text('notes'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  leaseIdx: index('payments_lease_id_idx').on(table.leaseId),
  statusIdx: index('payments_status_idx').on(table.status),
}));

// ─── Renewal Offers ───
const renewalOffersTable = pgTable('renewal_offers', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  leaseId: uuid('lease_id').notNull().references(() => leasesTable.id, { onDelete: 'cascade' }),
  newStartDate: timestamp('new_start_date', { mode: 'date' }).notNull(),
  newEndDate: timestamp('new_end_date', { mode: 'date' }).notNull(),
  newRentCents: integer('new_rent_cents').notNull(),
  newDepositCents: integer('new_deposit_cents').notNull().default(0),
  terms: jsonb('terms').default('{}'),
  status: text('status').notNull().default('pending'), // pending | sent | accepted | declined | expired
  sentAt: timestamp('sent_at'),
  sentVia: text('sent_via'), // sms | email | both
  tenantResponse: text('tenant_response'),
  respondedAt: timestamp('responded_at'),
  notes: text('notes'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  leaseIdx: index('renewal_offers_lease_id_idx').on(table.leaseId),
  statusIdx: index('renewal_offers_status_idx').on(table.status),
}));

// ─── SMS Queue (scheduled messages awaiting delivery) ───
const smsQueueTable = pgTable('sms_queue', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  campaignId: uuid('campaign_id').references(() => smsCampaignsTable.id, { onDelete: 'set null' }),
  reminderType: text('reminder_type'), // visit_24h | visit_2h | lease_renewal | payment_3d | payment_due
  visitId: uuid('visit_id').references(() => visitsTable.id, { onDelete: 'set null' }),
  leaseId: uuid('lease_id').references(() => leasesTable.id, { onDelete: 'set null' }),
  phoneNumber: text('phone_number').notNull(),
  messageBody: text('message_body').notNull(),
  status: text('status').notNull().default('pending'), // pending | processing | sent | failed | cancelled
  scheduledAt: timestamp('scheduled_at').notNull(),
  processedAt: timestamp('processed_at'),
  retryCount: integer('retry_count').notNull().default(0),
  maxRetries: integer('max_retries').notNull().default(3),
  lastError: text('last_error'),
  twilioSid: text('twilio_sid'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  statusScheduledIdx: index('sms_queue_status_scheduled_idx').on(table.status, table.scheduledAt),
}));

module.exports = {
  usersTable,
  refreshTokensTable,
  employeesTable,
  buildingsTable,
  employeeAssignmentsTable,
  unitsTable,
  employeeSchedulesTable,
  leadsTable,
  visitsTable,
  smsLogsTable,
  communicationLogsTable,
  documentsTable,
  documentsLeadsTable,
  leasesTable,
  notificationPreferencesTable,
  notificationsTable,
  smsTemplatesTable,
  smsCampaignsTable,
  smsQueueTable,
  paymentsTable,
  renewalOffersTable,
};
