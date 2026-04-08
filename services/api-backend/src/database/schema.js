const { sql } = require('drizzle-orm');
const { pgTable, text, varchar, integer, timestamp, boolean, jsonb, uuid } = require('drizzle-orm/pg-core');

// Users table
const usersTable = pgTable('users', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  password: text('password').notNull(),
  role: text('role').notNull().default('agent'), // admin, agent, manager
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// Buildings table
const buildingsTable = pgTable('buildings', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  name: text('name').notNull(),
  address: text('address').notNull(),
  totalUnits: integer('total_units').notNull().default(0),
  occupiedUnits: integer('occupied_units').notNull().default(0),
  monthlyRevenue: integer('monthly_revenue').notNull().default(0),
  managerId: uuid('manager_id').references(() => agentsTable.id),
  properties: jsonb('properties').default('{}'), // Additional building properties
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// Units table
const unitsTable = pgTable('units', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  buildingId: uuid('building_id').notNull().references(() => buildingsTable.id, { onDelete: 'cascade' }),
  label: text('label').notNull(), // e.g., "201 - 3 1/2"
  rent: integer('rent').notNull(),
  status: text('status').notNull().default('vacant'), // occupied, vacant, maintenance
  amenities: jsonb('amenities').default('{}'), // Array of amenities
  squareFeet: integer('square_feet'),
  bedrooms: integer('bedrooms'),
  bathrooms: integer('bathrooms'),
  description: text('description'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// Agents table
const agentsTable = pgTable('agents', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  phone: text('phone'),
  specialties: text('specialties').array(), // Array of specialties
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// Leads table
const leadsTable = pgTable('leads', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  fullName: text('full_name').notNull(),
  email: text('email').notNull(),
  phone: text('phone'),
  budget: integer('budget'), // Monthly budget in CAD
  desiredUnit: text('desired_unit'), // Unit preferences
  source: text('source').notNull().default('other'), // facebook, website, referral, other
  stage: text('stage').notNull().default('nouveau'), // leasing pipeline stages
  notes: text('notes'),
  tags: text('tags').array(), // Array of tags
  assignedAgentId: uuid('assigned_agent_id').references(() => agentsTable.id),
  buildingId: uuid('building_id').references(() => buildingsTable.id),
  unitId: uuid('unit_id').references(() => unitsTable.id),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// Visits table
const visitsTable = pgTable('visits', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  unitLabel: text('unit_label').notNull(),
  buildingName: text('building_name').notNull(),
  dateTime: timestamp('date_time').notNull(),
  status: text('status').notNull().default('scheduled'), // scheduled, confirmed, potential, completed, cancelled
  agentId: uuid('agent_id').notNull().references(() => agentsTable.id),
  clientId: uuid('client_id').notNull().references(() => leadsTable.id),
  notes: text('notes'),
  followUp: text('follow_up'), // Follow-up instructions
  duration: integer('duration'), // Visit duration in minutes
  completedAt: timestamp('completed_at'),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// Documents table
const documentsTable = pgTable('documents', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  name: text('name').notNull(),
  type: text('type').notNull(), // lease, application, id, incomeProof, other
  category: text('category'), // Document category
  fileSize: integer('file_size'), // in bytes
  mimeType: text('mime_type'),
  url: text('url').notNull(), // File URL
  status: text('status').notNull().default('pending'), // pending, approved, rejected
  referenceId: uuid('reference_id'), // Reference to related entity (lead, building, etc.)
  metadata: jsonb('metadata').default('{}'), // Additional document metadata
  uploadedBy: uuid('uploaded_by').notNull().references(() => usersTable.id),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// Documents leads relationship (for many-to-many relationship)
const documentsLeadsTable = pgTable('documents_leads', {
  documentId: uuid('document_id').notNull().references(() => documentsTable.id, { onDelete: 'cascade' }),
  leadId: uuid('lead_id').notNull().references(() => leadsTable.id, { onDelete: 'cascade' }),
  assignedAt: timestamp('assigned_at').notNull().defaultNow(),
  
  primaryKey: { columns: [documentId, leadId] },
});

// Schedules table for recurring events
const schedulesTable = pgTable('schedules', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  title: text('title').notNull(),
  description: text('description'),
  startTime: timestamp('start_time').notNull(),
  endTime: timestamp('end_time'),
  isRecurring: boolean('is_recurring').notNull().default(false),
  recurrence: jsonb('recurrence').default('{}'), // Recurrence rules
  location: text('location'),
  agentId: uuid('agent_id').references(() => agentsTable.id),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
  updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// Communication logs table
const communicationLogsTable = pgTable('communication_logs', {
  id: uuid('id').primaryKey().default(sql`gen_random_uuid()`),
  leadId: uuid('lead_id').references(() => leadsTable.id),
  type: text('type').notNull(), // email, sms, phone, fb, email
  direction: text('direction').notNull(), // incoming, outgoing
  content: text('content'),
  attachments: jsonb('attachments').default('{}'), // Array of file URLs
  status: text('status').notNull().default('sent'), // sent, delivered, read, failed
  agentId: uuid('agent_id').references(() => agentsTable.id),
  isActive: boolean('is_active').notNull().default(true),
  createdAt: timestamp('created_at').notNull().defaultNow(),
});

// Indexes for better query performance
const indexes = {
  users_email: sql`CREATE UNIQUE INDEX idx_users_email ON users(email)`,
  buildings_manager: sql`CREATE INDEX idx_buildings_manager ON buildings(manager_id)`,
  units_building: sql`CREATE INDEX idx_units_building ON units(building_id)`,
  units_status: sql`CREATE INDEX idx_units_status ON units(status)`,
  leads_stage: sql`CREATE INDEX idx_leads_stage ON leads(stage)`,
  leads_agent: sql`CREATE INDEX idx_leads_agent ON leads(assigned_agent_id)`,
  visits_agent: sql`CREATE INDEX idx_visits_agent ON visits(agent_id)`,
  visits_date: sql`CREATE INDEX idx_visits_date ON visits(date_time)`,
  documents_type: sql`CREATE INDEX idx_documents_type ON documents(type)`,
  documents_reference: sql`CREATE INDEX idx_documents_reference ON documents(reference_id)`,
  documents_leads: sql`CREATE INDEX idx_documents_leads ON documents_leads(lead_id)`,
};


// Schema object for drizzle ORM convenience
const schema = {
  users: usersTable,
  buildings: buildingsTable,
  units: unitsTable,
  agents: agentsTable,
  leads: leadsTable,
  visits: visitsTable,
  documents: documentsTable,
  documentsLeads: documentsLeadsTable,
  schedules: schedulesTable,
  communicationLogs: communicationLogsTable,
  indexes,
};

module.exports = {
  schema,
  usersTable,
  buildingsTable,
  unitsTable,
  agentsTable,
  leadsTable,
  visitsTable,
  documentsTable,
  documentsLeadsTable,
  schedulesTable,
  communicationLogsTable,
  indexes,
};
