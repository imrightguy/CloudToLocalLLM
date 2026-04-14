const { getTestDb, createTestApp, runMigrations, cleanAllTables, registerTestUser, loginTestUser, authHeader, createTestBuilding, createTestUnit, createTestLead } = require('./helpers');
const request = require('supertest');

jest.setTimeout(30000);

let app;
let pool;
let cleanupUser;

beforeAll(async () => {
  app = createTestApp();
  const result = getTestDb();
  pool = result.pool;
  await runMigrations(pool);
});

afterAll(async () => {
  if (cleanupUser) {
    try { await pool.query(`DELETE FROM users WHERE email = '${cleanupUser}'`); } catch { /* noop */ }
  }
  await pool.end();
});

beforeEach(async () => {
  await cleanAllTables(pool);
});

describe('Auth + Leases integration flow', () => {
  it('Register -> Login -> Create Lease -> Update Status -> Sign Lease', async () => {
    const email = `auth-lease-${Date.now()}@example.com`;
    cleanupUser = email;

    const registerRes = await registerTestUser(app, { email });
    expect(registerRes.response.status).toBe(201);
    expect(registerRes.user.email).toBe(email);
    expect(registerRes.tokens.accessToken).toBeDefined();

    const loginRes = await loginTestUser(app, email);
    expect(loginRes.response.status).toBe(200);
    expect(loginRes.tokens.accessToken).toBeDefined();
    expect(loginRes.user.lastLogin).toBeTruthy();

    const { building } = await createTestBuilding(app, loginRes.tokens, { name: 'Auth Lease Building' });
    expect(building.id).toBeDefined();

    const { unit } = await createTestUnit(app, loginRes.tokens, building.id, { label: 'A1' });
    expect(unit.id).toBeDefined();

    const { lead } = await createTestLead(app, loginRes.tokens, { fullName: 'Tenant Jean' });
    expect(lead.id).toBeDefined();

    const now = new Date();
    const startDate = new Date(now);
    startDate.setDate(startDate.getDate() + 1);
    const endDate = new Date(startDate);
    endDate.setFullYear(endDate.getFullYear() + 1);

    const leaseRes = await request(app)
      .post('/api/leases')
      .set(authHeader(loginRes.tokens))
      .send({
        unitId: unit.id,
        leadId: lead.id,
        tenantFirstName: 'Jean',
        tenantLastName: 'Dupont',
        tenantEmail: 'jean@example.com',
        tenantPhone: '+15145559999',
        rent: 1500,
        deposit: 750,
        startDate: startDate.toISOString().split('T')[0],
        endDate: endDate.toISOString().split('T')[0],
        terms: { parking: true, pets: false },
      });

    expect(leaseRes.status).toBe(201);
    expect(leaseRes.body.data.id).toBeDefined();
    expect(leaseRes.body.data.status).toBe('draft');
    expect(leaseRes.body.data.rent).toBe(1500);

    const leaseId = leaseRes.body.data.id;

    const statusRes = await request(app)
      .patch(`/api/leases/${leaseId}/status`)
      .set(authHeader(loginRes.tokens))
      .send({ status: 'active' });

    expect(statusRes.status).toBe(200);
    expect(statusRes.body.data.status).toBe('active');

    const signRes = await request(app)
      .patch(`/api/leases/${leaseId}/sign`)
      .set(authHeader(loginRes.tokens));

    expect(signRes.status).toBe(200);
    expect(signRes.body.data.signedAt).toBeTruthy();
    expect(signRes.body.data.status).toBe('active');

    const getRes = await request(app)
      .get(`/api/leases/${leaseId}`)
      .set(authHeader(loginRes.tokens));

    expect(getRes.status).toBe(200);
    expect(getRes.body.data.signedAt).toBeTruthy();
    expect(getRes.body.data.unit).toBeDefined();
  });

  it('rejects lease creation without authentication', async () => {
    const res = await request(app)
      .post('/api/leases')
      .send({
        unitId: '00000000-0000-0000-0000-000000000000',
        tenantFirstName: 'Test',
        tenantLastName: 'User',
        rent: 1000,
        startDate: '2026-06-01',
        endDate: '2027-06-01',
      });

    expect(res.status).toBe(401);
  });

  it('prevents double signing of a lease', async () => {
    const email = `double-sign-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { building } = await createTestBuilding(app, tokens);
    const { unit } = await createTestUnit(app, tokens, building.id);
    const { lead } = await createTestLead(app, tokens);

    const now = new Date();
    const startDate = new Date(now);
    startDate.setDate(startDate.getDate() + 1);
    const endDate = new Date(startDate);
    endDate.setFullYear(endDate.getFullYear() + 1);

    const leaseRes = await request(app)
      .post('/api/leases')
      .set(authHeader(tokens))
      .send({
        unitId: unit.id,
        leadId: lead.id,
        tenantFirstName: 'Marie',
        tenantLastName: 'Tremblay',
        rent: 1200,
        startDate: startDate.toISOString().split('T')[0],
        endDate: endDate.toISOString().split('T')[0],
      });

    const leaseId = leaseRes.body.data.id;

    await request(app)
      .patch(`/api/leases/${leaseId}/sign`)
      .set(authHeader(tokens));

    const secondSign = await request(app)
      .patch(`/api/leases/${leaseId}/sign`)
      .set(authHeader(tokens));

    expect(secondSign.status).toBe(400);
    expect(secondSign.body.error.code).toBe('LEASE_ALREADY_SIGNED');
  });
});
