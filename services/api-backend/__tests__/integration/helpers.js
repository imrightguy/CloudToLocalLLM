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

const DEFAULT_TEST_DB_URL = 'postgres://postgres:postgres@127.0.0.1:55432/immogestion_test';
const TEST_DB_URL = process.env.TEST_DATABASE_URL || process.env.DATABASE_URL || DEFAULT_TEST_DB_URL;

process.env.TEST_DATABASE_URL = TEST_DB_URL;
process.env.DATABASE_URL = process.env.DATABASE_URL || TEST_DB_URL;
process.env.JWT_SECRET = process.env.JWT_SECRET || 'integration-test-jwt-secret-0123456789abcdef';
process.env.JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'integration-test-refresh-secret-0123456789abcdef';

let testPool;
let testDb;

function assertSafeTestDatabaseUrl() {
  let pathname;
  try {
    pathname = new URL(TEST_DB_URL).pathname;
  } catch {
    throw new Error(`Invalid TEST_DATABASE_URL: ${TEST_DB_URL}`);
  }

  const databaseName = pathname.replace(/^\//, '');
  if (!databaseName || !databaseName.endsWith('_test')) {
    throw new Error(`Refusing to run integration tests against non-test database: ${TEST_DB_URL}`);
  }
}

function getTestDb() {
  if (!testDb) {
    assertSafeTestDatabaseUrl();
    testPool = new Pool({ connectionString: TEST_DB_URL });
    testDb = drizzle(testPool);
  }
  return { db: testDb, pool: testPool };
}

function createTestApp() {
  process.env.DATABASE_URL = TEST_DB_URL;
  const app = express();
  app.set('trust proxy', 1);
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

async function resetSchema(pool) {
  assertSafeTestDatabaseUrl();
  const client = await pool.connect();
  try {
    await client.query('DROP SCHEMA IF EXISTS public CASCADE');
    await client.query('CREATE SCHEMA public');
  } finally {
    client.release();
  }
}

async function runMigrations(pool) {
  await resetSchema(pool);
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
    const { rows } = await client.query(`
      SELECT tablename
      FROM pg_tables
      WHERE schemaname = 'public'
        AND tablename <> '_applied_migrations'
      ORDER BY tablename
    `);

    if (!rows.length) {
      return;
    }

    const tableList = rows
      .map(({ tablename }) => `"${tablename.replace(/"/g, '""')}"`)
      .join(', ');

    await client.query(`TRUNCATE TABLE ${tableList} RESTART IDENTITY CASCADE`);
  } finally {
    client.release();
  }
}

async function registerTestUser(app, overrides = {}) {
  const res = await request(app)
    .post('/api/auth/register')
    .set('X-Forwarded-For', overrides.ip || `127.0.0.${Math.floor(Math.random() * 200) + 10}`)
    .send({
      email: overrides.email || `test-${Date.now()}@example.com`,
      password: overrides.password || 'TestPass123!',
      firstName: overrides.firstName || 'Test',
      lastName: overrides.lastName || 'User',
      phone: overrides.phone || '+15145551234',
    });

  if (!res.body?.data?.user || !res.body?.data?.tokens) {
    throw new Error(`registerTestUser failed with ${res.status}: ${JSON.stringify(res.body)}`);
  }

  return {
    user: res.body.data.user,
    tokens: res.body.data.tokens,
    response: res,
  };
}

async function loginTestUser(app, email, password = 'TestPass123!') {
  const res = await request(app)
    .post('/api/auth/login')
    .set('X-Forwarded-For', `127.0.1.${Math.floor(Math.random() * 200) + 10}`)
    .send({ email, password });

  if (!res.body?.data?.user || !res.body?.data?.tokens) {
    throw new Error(`loginTestUser failed with ${res.status}: ${JSON.stringify(res.body)}`);
  }

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
      address: overrides.address || '123 Test Street',
      city: overrides.city || 'Montréal',
      province: overrides.province || 'QC',
      postalCode: overrides.postalCode,
      totalUnits: overrides.totalUnits || 2,
      occupiedUnits: overrides.occupiedUnits || 0,
    });

  if (!res.body?.data?.id) {
    throw new Error(`createTestBuilding failed with ${res.status}: ${JSON.stringify(res.body)}`);
  }

  return { building: res.body.data, response: res };
}

async function createTestUnit(app, tokens, buildingId, overrides = {}) {
  const res = await request(app)
    .post('/api/buildings/units')
    .set(authHeader(tokens))
    .send({
      buildingId,
      unitNumber: overrides.unitNumber || `Unit-${Date.now()}`,
      type: overrides.type || '2br',
      rentAmount: overrides.rentAmount || 1200,
      isAvailable: overrides.isAvailable ?? true,
      bedrooms: overrides.bedrooms || 2,
      bathrooms: overrides.bathrooms || 1,
      sqft: overrides.sqft,
    });

  if (!res.body?.data?.id) {
    throw new Error(`createTestUnit failed with ${res.status}: ${JSON.stringify(res.body)}`);
  }

  return { unit: res.body.data, response: res };
}

async function createTestEmployee(app, tokens, overrides = {}) {
  const res = await request(app)
    .post('/api/employees')
    .set(authHeader(tokens))
    .send({
      firstName: overrides.firstName || 'Emp',
      lastName: overrides.lastName || `Test${Date.now()}`,
      phone: overrides.phone || `+151455${String(Math.floor(Math.random() * 10000)).padStart(4, '0')}`,
      email: overrides.email || `employee-${Date.now()}@example.com`,
    });

  if (!res.body?.data?.id) {
    throw new Error(`createTestEmployee failed with ${res.status}: ${JSON.stringify(res.body)}`);
  }

  return { employee: res.body.data, response: res };
}

async function createTestLead(app, tokens, overrides = {}) {
  const res = await request(app)
    .post('/api/leads')
    .set(authHeader(tokens))
    .send({
      fullName: overrides.fullName || `Lead ${Date.now()}`,
      email: overrides.email || `lead-${Date.now()}@example.com`,
      phone: overrides.phone || `+151455${String(Math.floor(Math.random() * 10000)).padStart(4, '0')}`,
      source: overrides.source || 'website',
      stage: overrides.stage || 'nouveau',
      language: overrides.language || 'fr',
      buildingId: overrides.buildingId,
      unitId: overrides.unitId,
    });

  if (!res.body?.data?.id) {
    throw new Error(`createTestLead failed with ${res.status}: ${JSON.stringify(res.body)}`);
  }

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
      isAvailable: overrides.isAvailable ?? true,
    });

  if (!res.body?.data?.id) {
    throw new Error(`createTestSchedule failed with ${res.status}: ${JSON.stringify(res.body)}`);
  }

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

  if (!res.body?.data?.id) {
    throw new Error(`createTestVisit failed with ${res.status}: ${JSON.stringify(res.body)}`);
  }

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
