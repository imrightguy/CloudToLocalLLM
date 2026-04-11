const { sql } = require('drizzle-orm');
const {
  pgTable, text, integer, timestamp, boolean, jsonb, uuid,
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
});

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
});

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
});

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
});

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
});

// ─── Visits ───
const visitsTable = pgTable('visits', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  unitId: uuid('unit_id').notNull().references(() => unitsTable.id),
  employeeId: uuid('employee_id').notNull().references(() => employeesTable.id),
  leadId: uuid('lead_id').notNull().references(() => leadsTable.id),
  dateTime: timestamp('date_time').notNull(),
  durationMinutes: integer('duration_minutes').notNull().default(30),
  status: text('status').notNull().default('scheduled'), // scheduled | confirmed | completed | cancelled | no_show
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
});

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
});

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
});

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

// ─── Document-Lead junction ───
const documentsLeadsTable = pgTable('documents_leads', {
  documentId: uuid('document_id').notNull().references(() => documentsTable.id, { onDelete: 'cascade' }),
  leadId: uuid('lead_id').notNull().references(() => leadsTable.id, { onDelete: 'cascade' }),
  assignedAt: timestamp('assigned_at').notNull().defaultNow(),
}, (table) => ({
  pk: { primaryKey: { columns: [table.documentId, table.leadId] } },
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
};
