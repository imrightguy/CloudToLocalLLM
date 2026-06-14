const { sql } = require('drizzle-orm');
const {
  pgTable, text, integer, timestamp, boolean, jsonb, uuid, index, uniqueIndex, numeric,
} = require('drizzle-orm/pg-core');
const {
  QUALIFICATION_STATES,
  BOOKING_STATES,
  MARKETPLACE_REASON_CODES,
} = require('../constants/marketplace-states');

// ─── Users (app login — Simon + future admins only) ───
const usersTable = pgTable('users', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  email: text('email').notNull().unique(),
  passwordHash: text('password_hash').notNull(),
  firstName: text('first_name').notNull(),
  lastName: text('last_name').notNull(),
  phone: text('phone'),
  role: text('role').notNull().default('user'),
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

// ─── Renovation Ops ───
const renovationsTable = pgTable('renovations', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  unitId: uuid('unit_id').notNull().references(() => unitsTable.id, { onDelete: 'cascade' }),
  buildingId: uuid('building_id').notNull().references(() => buildingsTable.id, { onDelete: 'cascade' }),
  title: text('title').notNull(),
  status: text('status').notNull().default('planned'), // planned | active | blocked | ready_for_leasing | completed | archived
  readinessState: text('readiness_state').notNull().default('not_started'), // not_started | in_progress | blocked | ready_to_list | ready_for_leasing | ready
  startDate: timestamp('start_date', { mode: 'date' }),
  targetEndDate: timestamp('target_end_date', { mode: 'date' }),
  notes: text('notes'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  unitIdx: uniqueIndex('renovations_unit_id_unique').on(table.unitId),
  buildingIdx: index('renovations_building_id_idx').on(table.buildingId),
  statusIdx: index('renovations_status_idx').on(table.status),
  readinessIdx: index('renovations_readiness_state_idx').on(table.readinessState),
}));

const renovationTasksTable = pgTable('renovation_tasks', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  renovationRecordId: uuid('renovation_record_id').notNull().references(() => renovationsTable.id, { onDelete: 'cascade' }),
  assigneeEmployeeId: uuid('assignee_employee_id').references(() => employeesTable.id, { onDelete: 'set null' }),
  title: text('title').notNull(),
  description: text('description'),
  status: text('status').notNull().default('todo'), // todo | in_progress | blocked | done | cancelled
  dueDate: timestamp('due_date', { mode: 'date' }),
  completedAt: timestamp('completed_at'),
  verificationEvidence: jsonb('verification_evidence').notNull().default('[]'),
  notes: text('notes'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  renovationIdx: index('renovation_tasks_renovation_record_id_idx').on(table.renovationRecordId),
  statusIdx: index('renovation_tasks_status_idx').on(table.status),
  assigneeIdx: index('renovation_tasks_assignee_employee_id_idx').on(table.assigneeEmployeeId),
}));

const renovationOrdersTable = pgTable('renovation_orders', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  renovationRecordId: uuid('renovation_record_id').notNull().references(() => renovationsTable.id, { onDelete: 'cascade' }),
  taskId: uuid('task_id').references(() => renovationTasksTable.id, { onDelete: 'set null' }),
  vendorName: text('vendor_name').notNull(),
  itemName: text('item_name').notNull(),
  quantityOrdered: integer('quantity_ordered').notNull(),
  quantityReceived: integer('quantity_received').notNull().default(0),
  status: text('status').notNull().default('draft'), // draft | ordered | partially_received | received | cancelled
  orderedAt: timestamp('ordered_at', { mode: 'date' }),
  expectedAt: timestamp('expected_at', { mode: 'date' }),
  notes: text('notes'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  renovationIdx: index('renovation_orders_renovation_record_id_idx').on(table.renovationRecordId),
  taskIdx: index('renovation_orders_task_id_idx').on(table.taskId),
  statusIdx: index('renovation_orders_status_idx').on(table.status),
}));

const renovationReceivingEventsTable = pgTable('renovation_receiving_events', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  orderId: uuid('order_id').notNull().references(() => renovationOrdersTable.id, { onDelete: 'cascade' }),
  quantityReceived: integer('quantity_received').notNull(),
  receivedAt: timestamp('received_at').notNull().defaultNow(),
  notes: text('notes'),
  createdAt: timestamp('created_at').notNull().defaultNow(),
}, (table) => ({
  orderIdx: index('renovation_receiving_events_order_id_idx').on(table.orderId),
}));

const renovationSurplusItemsTable = pgTable('renovation_surplus_items', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  renovationRecordId: uuid('renovation_record_id').notNull().references(() => renovationsTable.id, { onDelete: 'cascade' }),
  sourceOrderId: uuid('source_order_id').references(() => renovationOrdersTable.id, { onDelete: 'set null' }),
  taskId: uuid('task_id').references(() => renovationTasksTable.id, { onDelete: 'set null' }),
  itemName: text('item_name').notNull(),
  quantityAvailable: integer('quantity_available').notNull(),
  status: text('status').notNull().default('available'), // available | reserved | used | discarded
  location: text('location'),
  notes: text('notes'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  renovationIdx: index('renovation_surplus_items_renovation_record_id_idx').on(table.renovationRecordId),
  sourceOrderIdx: index('renovation_surplus_items_source_order_id_idx').on(table.sourceOrderId),
  statusIdx: index('renovation_surplus_items_status_idx').on(table.status),
}));

const renovationJobTemplatesTable = pgTable('renovation_job_templates', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  companyId: uuid('company_id').notNull(),
  name: text('name').notNull(),
  description: text('description'),
  isFavorite: boolean('is_favorite').notNull().default(false),
  materials: jsonb('materials').notNull().default('[]'),
  notes: text('notes'),
  manualProductLinks: jsonb('manual_product_links').notNull().default('[]'),
  suggestedMissingItems: jsonb('suggested_missing_items').notNull().default('[]'),
  sourceTags: jsonb('source_tags').notNull().default('[]'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  companyIdx: index('renovation_job_templates_company_id_idx').on(table.companyId),
  companyFavoriteIdx: index('renovation_job_templates_company_favorite_idx').on(table.companyId, table.isFavorite),
  companyNameIdx: index('renovation_job_templates_company_name_idx').on(table.companyId, table.name),
}));

const workerIntakeRecordsTable = pgTable('worker_intake_records', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  twilioMessageSid: text('twilio_message_sid').unique(),
  renovationRecordId: uuid('renovation_record_id').notNull().references(() => renovationsTable.id, { onDelete: 'cascade' }),
  taskId: uuid('task_id').references(() => renovationTasksTable.id, { onDelete: 'set null' }),
  orderId: uuid('order_id').references(() => renovationOrdersTable.id, { onDelete: 'set null' }),
  sourcePhone: text('source_phone').notNull(),
  workerName: text('worker_name'),
  messageBody: text('message_body').notNull(),
  messageKind: text('message_kind').notNull().default('update'),
  status: text('status').notNull().default('new'),
  confidence: numeric('confidence', { precision: 5, scale: 4 }),
  summary: text('summary'),
  rawPayload: jsonb('raw_payload').notNull().default('{}'),
  mediaUrls: jsonb('media_urls').notNull().default('[]'),
  mediaContentTypes: jsonb('media_content_types').notNull().default('[]'),
  photoCount: integer('photo_count').notNull().default(0),
  receivedAt: timestamp('received_at').notNull().defaultNow(),
  reviewedAt: timestamp('reviewed_at'),
  resolvedAt: timestamp('resolved_at'),
  notes: text('notes'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  twilioMessageSidIdx: uniqueIndex('worker_intake_records_twilio_message_sid_unique').on(table.twilioMessageSid),
  renovationIdx: index('worker_intake_records_renovation_record_id_idx').on(table.renovationRecordId),
  taskIdx: index('worker_intake_records_task_id_idx').on(table.taskId),
  statusIdx: index('worker_intake_records_status_idx').on(table.status),
  messageKindIdx: index('worker_intake_records_message_kind_idx').on(table.messageKind),
}));

const unitReadinessTable = pgTable('unit_readiness', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  unitId: uuid('unit_id').notNull().references(() => unitsTable.id, { onDelete: 'cascade' }),
  currentRenovationRecordId: uuid('current_renovation_record_id').references(() => renovationsTable.id, { onDelete: 'set null' }),
  opsStatus: text('ops_status').notNull().default('not_started'),
  leasingStatus: text('leasing_status').notNull().default('not_ready'),
  blockingCount: integer('blocking_count').notNull().default(0),
  blockingSummary: text('blocking_summary'),
  readyAt: timestamp('ready_at'),
  handedOffAt: timestamp('handed_off_at'),
  leasedAt: timestamp('leased_at'),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
  createdAt: timestamp('created_at').notNull().defaultNow(),
}, (table) => ({
  unitIdx: uniqueIndex('unit_readiness_unit_id_unique').on(table.unitId),
  opsStatusIdx: index('unit_readiness_ops_status_idx').on(table.opsStatus),
  leasingStatusIdx: index('unit_readiness_leasing_status_idx').on(table.leasingStatus),
}));

// ─── Maintenance Tickets (Voice AI / Vapi pillar) ───
const maintenanceTicketsTable = pgTable('maintenance_tickets', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  title: text('title').notNull(),
  description: text('description'),
  urgency: text('urgency').notNull().default('moyenne'), // basse | moyenne | haute | urgence
  status: text('status').notNull().default('ouvert'), // ouvert | en_cours | resolu
  source: text('source').notNull().default('manual'), // manual | vapi | sms | phone
  tenantId: uuid('tenant_id'),
  tenantName: text('tenant_name'),
  callerPhone: text('caller_phone'),
  unitId: uuid('unit_id').references(() => unitsTable.id, { onDelete: 'set null' }),
  buildingId: uuid('building_id').references(() => buildingsTable.id, { onDelete: 'set null' }),
  photos: jsonb('photos').notNull().default('[]'),
  vapiCallId: text('vapi_call_id'),
  resolvedAt: timestamp('resolved_at'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  statusIdx: index('maintenance_tickets_status_idx').on(table.status),
  urgencyIdx: index('maintenance_tickets_urgency_idx').on(table.urgency),
  buildingIdx: index('maintenance_tickets_building_id_idx').on(table.buildingId),
  unitIdx: index('maintenance_tickets_unit_id_idx').on(table.unitId),
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
  qualificationState: text('qualification_state').notNull().default('unknown'), // unknown | qualified | rejected | needs_follow_up
  qualificationReasonCode: text('qualification_reason_code'),
  qualificationReasonNote: text('qualification_reason_note'),
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
  tenantConfirmationRequestedAt: timestamp('tenant_confirmation_requested_at'),
  tenantConfirmedAt: timestamp('tenant_confirmed_at'),
  tenantDeclinedAt: timestamp('tenant_declined_at'),
  occupantNotified: boolean('occupant_notified').notNull().default(false), // SMS sent to current occupant for access
  employeeConfirmed: boolean('employee_confirmed').notNull().default(false),
  employeeConfirmationRequestedAt: timestamp('employee_confirmation_requested_at'),
  employeeConfirmedAt: timestamp('employee_confirmed_at'),
  employeeDeclinedAt: timestamp('employee_declined_at'),
  morningOfSent: boolean('morning_of_sent').notNull().default(false),
  morningReminderSentAt: timestamp('morning_reminder_sent_at'),
  reminder24hQueuedAt: timestamp('reminder_24h_queued_at'),
  reminder2hQueuedAt: timestamp('reminder_2h_queued_at'),
  confirmationToken: text('confirmation_token').unique(), // unique token for tenant web-based confirmation
  sourceThreadId: uuid('source_thread_id'),
  outcome: text('outcome'), // interesse | pas_interesse | no_show | null
  reasonCode: text('reason_code'), // tenant_request | tenant_conflict | host_unavailable | access_issue | weather | tenant_no_show | other
  completedAt: timestamp('completed_at'),
  cancelledAt: timestamp('cancelled_at'),
  noShowAt: timestamp('no_show_at'),
  rescheduledAt: timestamp('rescheduled_at'),
  coordinationState: text('coordination_state').notNull().default('message_only'), // message_only | awaiting_employee_confirmation | awaiting_tenant_confirmation | scheduled | confirmed | in_progress | completed_interested | completed_not_interested | completed_no_show | cancelled | follow_up_required
  notes: text('notes'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  dateTimeIdx: index('visits_date_time_idx').on(table.dateTime),
  statusIdx: index('visits_status_idx').on(table.status),
  coordinationStateIdx: index('visits_coordination_state_idx').on(table.coordinationState),
  employeeIdx: index('visits_employee_id_idx').on(table.employeeId),
  leadIdx: index('visits_lead_id_idx').on(table.leadId),
  sourceThreadIdx: index('visits_source_thread_id_idx').on(table.sourceThreadId),
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
  status: text('status').notNull().default('sent'), // sent | delivered | read | failed | received
  metadata: jsonb('metadata').default('{}'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
}, (table) => ({
  leadIdx: index('comm_logs_lead_id_idx').on(table.leadId),
}));

// ─── Communication Threads ───
const communicationThreadsTable = pgTable('communication_threads', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  leadId: uuid('lead_id').notNull().references(() => leadsTable.id, { onDelete: 'cascade' }).unique(),
  latestVisitId: uuid('latest_visit_id').references(() => visitsTable.id, { onDelete: 'set null' }),
  bookingState: text('booking_state').notNull().default('unbooked'), // unbooked | booking_pending | scheduled | confirmed | in_progress | completed | cancelled | no_show | reschedule_requested
  bookingReasonCode: text('booking_reason_code'),
  bookingStateUpdatedAt: timestamp('booking_state_updated_at'),
  coordinationState: text('coordination_state').notNull().default('message_only'),
  messageCount: integer('message_count').notNull().default(0),
  lastMessageAt: timestamp('last_message_at'),
  lastMessageType: text('last_message_type'),
  lastMessageDirection: text('last_message_direction'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  leadIdx: index('comm_threads_lead_id_idx').on(table.leadId),
  stateIdx: index('comm_threads_coordination_state_idx').on(table.coordinationState),
  bookingStateIdx: index('comm_threads_booking_state_idx').on(table.bookingState),
}));

// ─── Property Photos ───
const propertyPhotosTable = pgTable('property_photos', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  companyId: uuid('company_id').notNull(),
  buildingId: uuid('building_id').notNull().references(() => buildingsTable.id, { onDelete: 'cascade' }),
  unitId: uuid('unit_id').references(() => unitsTable.id, { onDelete: 'set null' }),
  roomContext: text('room_context'),
  useCase: text('use_case').notNull(),
  displayOrder: integer('display_order').notNull().default(0),
  documentRefId: text('document_ref_id'),
  fileName: text('file_name').notNull(),
  storedFileName: text('stored_file_name').notNull(),
  storageProvider: text('storage_provider').notNull().default('external_url'),
  storageKey: text('storage_key').notNull(),
  storagePath: text('storage_path').notNull(),
  fileSizeBytes: integer('file_size_bytes'),
  mimeType: text('mime_type'),
  url: text('url').notNull(),
  capturedAt: timestamp('captured_at'),
  uploadedAt: timestamp('uploaded_at').notNull().defaultNow(),
  metadata: jsonb('metadata').notNull().default('{}'),
  uploadedByUserId: uuid('uploaded_by_user_id').references(() => usersTable.id, { onDelete: 'set null' }),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
}, (table) => ({
  companyIdx: index('property_photos_company_id_idx').on(table.companyId),
  companyBuildingIdx: index('property_photos_company_building_id_idx').on(table.companyId, table.buildingId),
  companyUnitIdx: index('property_photos_company_unit_id_idx').on(table.companyId, table.unitId),
  companyUseCaseIdx: index('property_photos_company_use_case_idx').on(table.companyId, table.useCase),
}));

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

// ─── SMS Opt-outs ───
const smsOptOutsTable = pgTable('sms_opt_outs', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  phoneNumber: text('phone_number').notNull().unique(),
  reason: text('reason').notNull().default('stop'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
});

module.exports = {
  usersTable,
  refreshTokensTable,
  employeesTable,
  buildingsTable,
  employeeAssignmentsTable,
  unitsTable,
  renovationsTable,
  renovationTasksTable,
  renovationOrdersTable,
  renovationReceivingEventsTable,
  renovationSurplusItemsTable,
  renovationJobTemplatesTable,
  workerIntakeRecordsTable,
  unitReadinessTable,
  maintenanceTicketsTable,
  employeeSchedulesTable,
  leadsTable,
  visitsTable,
  smsLogsTable,
  communicationLogsTable,
  communicationThreadsTable,
  propertyPhotosTable,
  leasesTable,
  notificationPreferencesTable,
  notificationsTable,
  smsTemplatesTable,
  smsCampaignsTable,
  smsQueueTable,
  smsOptOutsTable,
  paymentsTable,
  renewalOffersTable,
};
