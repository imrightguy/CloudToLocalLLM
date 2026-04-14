const request = require('supertest');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const { drizzle } = require('drizzle-orm/node-postgres');
const { errorHandler, setCORSHeaders } = require('../../src/utils/apiResponse');
const fs = require('fs');
const path = require('path');

const TEST_DB_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL || 'postgres://postgres:postgres@localhost:5432/immogestion_test';

let testPool;
let testDb;

function getTestDb() {
  if (!testDb) {
    testPool = new Pool({ connectionString: TEST_DB_URL });
    testDb = drizzle(testPool);
  }
  return { db: testDb, pool: testPool };
}

function createTestApp() {
  const app = express();
  app.use(helmet());
  app.use(cors());
  app.use(express.json({ limit: '10mb' }));
  app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 10000 }));

  const routes = require('../../src/routes');
  app.use('/api', routes);

  app.use('*', (req, res) => {
    setCORSHeaders(res);
    res.status(404).json({ success: false, error: { message: 'Route not found', code: 'NOT_FOUND' } });
  });

  app.use(errorHandler);
  return app;
}

async function runMigrations(pool) {
  const client = await pool.connect();
  try {
    const migrationsDir = path.join(__dirname, '../../migrations');
    const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();

    for (const file of files) {
      const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf8');
      await client.query(sql);
    }
  } finally {
    client.release();
  }
}

async function cleanAllTables(pool) {
  const client = await pool.connect();
  try {
    await client.query('SET session_replication_role = replica');
    const tables = [
      'sms_queue', 'sms_logs', 'communication_logs',
      'documents_leads', 'documents',
      'visits', 'leads', 'employee_schedules', 'employee_assignments',
      'units', 'employees', 'refresh_tokens', 'users',
      'sms_campaigns', 'sms_templates', 'buildings', 'leases',
    ];
    for (const table of tables) {
      try { await client.query(`DELETE FROM ${table}`); } catch { /* table may not exist yet */ }
    }
    await client.query('SET session_replication_role = DEFAULT');
  } finally {
    client.release();
  }
}

async function registerTestUser(app, overrides = {}) {
  const res = await request(app)
    .post('/api/auth/register')
    .send({
      email: overrides.email || `test-${Date.now()}@example.com`,
      password: overrides.password || 'TestPass123!',
      firstName: overrides.firstName || 'Test',
      lastName: overrides.lastName || 'User',
      phone: overrides.phone || '+15145551234',
    });

  return {
    user: res.body.data.user,
    tokens: res.body.data.tokens,
    response: res,
  };
}

async function loginTestUser(app, email, password = 'TestPass123!') {
  const res = await request(app)
    .post('/api/auth/login')
    .send({ email, password });

  return {
    user: res.body.data.user,
    tokens: res.body.data.tokens,
    response: res,
  };
}

function authHeader(tokens) {
  return { Authorization: `Bearer ${tokens.accessToken}` };
}

async function createTestBuilding(app, tokens, overrides = {}) {
  const res = await request(app)
    .post('/api/buildings')
    .set(authHeader(tokens))
    .send({
      name: overrides.name || `Building ${Date.now()}`,
      address: overrides.address || '123 Test St',
      city: overrides.city || 'Montréal',
      province: overrides.province || 'QC',
      totalUnits: overrides.totalUnits || 2,
      occupiedUnits: overrides.occupiedUnits || 0,
    });

  return { building: res.body.data, response: res };
}

async function createTestUnit(app, tokens, buildingId, overrides = {}) {
  const res = await request(app)
    .post('/api/buildings/units')
    .set(authHeader(tokens))
    .send({
      buildingId,
      label: overrides.label || `Unit ${Date.now()}`,
      rent: overrides.rent || 1200,
      status: overrides.status || 'vacant',
      bedrooms: overrides.bedrooms || 2,
      bathrooms: overrides.bathrooms || 1,
    });

  return { unit: res.body.data, response: res };
}

async function createTestEmployee(app, tokens, overrides = {}) {
  const res = await request(app)
    .post('/api/employees')
    .set(authHeader(tokens))
    .send({
      firstName: overrides.firstName || 'Emp',
      lastName: overrides.lastName || `Test${Date.now()}`,
      phone: overrides.phone || `+1514555${String(Math.floor(Math.random() * 10000)).padStart(4, '0')}`,
      email: overrides.email || null,
    });

  return { employee: res.body.data, response: res };
}

async function createTestLead(app, tokens, overrides = {}) {
  const res = await request(app)
    .post('/api/leads')
    .set(authHeader(tokens))
    .send({
      fullName: overrides.fullName || `Lead ${Date.now()}`,
      email: overrides.email || `lead-${Date.now()}@example.com`,
      phone: overrides.phone || `+1514555${String(Math.floor(Math.random() * 10000)).padStart(4, '0')}`,
      source: overrides.source || 'website',
      stage: overrides.stage || 'nouveau',
      language: overrides.language || 'fr',
    });

  return { lead: res.body.data, response: res };
}

async function createTestSchedule(app, tokens, overrides = {}) {
  const res = await request(app)
    .post('/api/schedules')
    .set(authHeader(tokens))
    .send({
      employeeId: overrides.employeeId,
      buildingId: overrides.buildingId,
      dayOfWeek: overrides.dayOfWeek ?? 0,
      startTime: overrides.startTime || '09:00',
      endTime: overrides.endTime || '17:00',
    });

  return { schedule: res.body.data, response: res };
}

async function createTestVisit(app, tokens, overrides = {}) {
  const futureDate = new Date();
  futureDate.setDate(futureDate.getDate() + 3);
  futureDate.setHours(10, 0, 0, 0);

  const res = await request(app)
    .post('/api/visits')
    .set(authHeader(tokens))
    .send({
      unitId: overrides.unitId,
      employeeId: overrides.employeeId,
      leadId: overrides.leadId,
      dateTime: overrides.dateTime || futureDate.toISOString(),
      durationMinutes: overrides.durationMinutes || 30,
    });

  return { visit: res.body.data, response: res };
}

module.exports = {
  TEST_DB_URL,
  getTestDb,
  createTestApp,
  runMigrations,
  cleanAllTables,
  registerTestUser,
  loginTestUser,
  authHeader,
  createTestBuilding,
  createTestUnit,
  createTestEmployee,
  createTestLead,
  createTestSchedule,
  createTestVisit,
};
