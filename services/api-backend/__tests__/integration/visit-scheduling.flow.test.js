const { getTestDb, createTestApp, runMigrations, cleanAllTables, registerTestUser, authHeader, createTestBuilding, createTestUnit, createTestEmployee, createTestLead, createTestSchedule, createTestVisit } = require('./helpers');
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

describe('Visit scheduling integration flow', () => {
  it('Create Building -> Create Unit -> Create Employee -> Create Schedule -> Create Visit -> Confirm', async () => {
    const email = `visit-flow-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });

    const { building } = await createTestBuilding(app, tokens, {
      name: 'Visit Test Building',
      address: '456 Rue Sainte-Catherine',
    });
    expect(building.id).toBeDefined();

    const { unit } = await createTestUnit(app, tokens, building.id, {
      label: '5A',
      rent: 1400,
    });
    expect(unit.id).toBeDefined();

    const { employee } = await createTestEmployee(app, tokens, {
      firstName: 'Marc',
      lastName: 'Lefebvre',
      phone: '+15145557777',
    });
    expect(employee.id).toBeDefined();

    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 5);
    const dayOfWeek = futureDate.getDay();
    const scheduleDay = dayOfWeek === 0 ? 6 : dayOfWeek - 1;

    const { schedule } = await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building.id,
      dayOfWeek: scheduleDay,
      startTime: '08:00',
      endTime: '18:00',
    });
    expect(schedule.id).toBeDefined();

    const { lead } = await createTestLead(app, tokens, {
      fullName: 'Visiteur Test',
      phone: '+15145558888',
    });
    expect(lead.id).toBeDefined();

    futureDate.setHours(10, 0, 0, 0);

    const { visit, response: visitRes } = await createTestVisit(app, tokens, {
      unitId: unit.id,
      employeeId: employee.id,
      leadId: lead.id,
      dateTime: futureDate.toISOString(),
    });

    expect(visitRes.status).toBe(201);
    expect(visit.id).toBeDefined();
    expect(visit.status).toBe('scheduled');

    const confirmRes = await request(app)
      .patch(`/api/visits/${visit.id}/status`)
      .set(authHeader(tokens))
      .send({ status: 'confirmed' });

    expect(confirmRes.status).toBe(200);
    expect(confirmRes.body.data.status).toBe('confirmed');
    expect(confirmRes.body.data.tenantConfirmed).toBe(true);
    expect(confirmRes.body.data.employeeConfirmed).toBe(true);

    const completeRes = await request(app)
      .patch(`/api/visits/${visit.id}/status`)
      .set(authHeader(tokens))
      .send({ status: 'completed', outcome: 'interesse' });

    expect(completeRes.status).toBe(200);
    expect(completeRes.body.data.status).toBe('completed');
    expect(completeRes.body.data.outcome).toBe('interesse');
  });

  it('rejects visit creation when employee has no schedule', async () => {
    const email = `visit-nosched-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { building } = await createTestBuilding(app, tokens);
    const { unit } = await createTestUnit(app, tokens, building.id);
    const { employee } = await createTestEmployee(app, tokens);
    const { lead } = await createTestLead(app, tokens);

    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 3);
    futureDate.setHours(10, 0, 0, 0);

    const res = await request(app)
      .post('/api/visits')
      .set(authHeader(tokens))
      .send({
        unitId: unit.id,
        employeeId: employee.id,
        leadId: lead.id,
        dateTime: futureDate.toISOString(),
      });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('SCHEDULE_CONFLICT');
  });

  it('rejects visit creation outside schedule hours', async () => {
    const email = `visit-outhours-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { building } = await createTestBuilding(app, tokens);
    const { unit } = await createTestUnit(app, tokens, building.id);
    const { employee } = await createTestEmployee(app, tokens);
    const { lead } = await createTestLead(app, tokens);

    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 4);
    const dayOfWeek = futureDate.getDay();
    const scheduleDay = dayOfWeek === 0 ? 6 : dayOfWeek - 1;

    await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building.id,
      dayOfWeek: scheduleDay,
      startTime: '09:00',
      endTime: '12:00',
    });

    futureDate.setHours(14, 0, 0, 0);

    const res = await request(app)
      .post('/api/visits')
      .set(authHeader(tokens))
      .send({
        unitId: unit.id,
        employeeId: employee.id,
        leadId: lead.id,
        dateTime: futureDate.toISOString(),
      });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('SCHEDULE_CONFLICT');
  });

  it('lists visits with expanded relations', async () => {
    const email = `visit-list-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { building } = await createTestBuilding(app, tokens, { name: 'List Building' });
    const { unit } = await createTestUnit(app, tokens, building.id, { label: 'B2' });
    const { employee } = await createTestEmployee(app, tokens, { firstName: 'List', lastName: 'Emp' });
    const { lead } = await createTestLead(app, tokens, { fullName: 'List Lead' });

    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 6);
    const dayOfWeek = futureDate.getDay();
    const scheduleDay = dayOfWeek === 0 ? 6 : dayOfWeek - 1;

    await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building.id,
      dayOfWeek: scheduleDay,
      startTime: '08:00',
      endTime: '20:00',
    });

    futureDate.setHours(11, 0, 0, 0);

    await createTestVisit(app, tokens, {
      unitId: unit.id,
      employeeId: employee.id,
      leadId: lead.id,
      dateTime: futureDate.toISOString(),
    });

    const listRes = await request(app)
      .get('/api/visits?expand=unit,building,employee,lead')
      .set(authHeader(tokens));

    expect(listRes.status).toBe(200);
    expect(listRes.body.data.length).toBe(1);
    expect(listRes.body.data[0].unit).toBeDefined();
    expect(listRes.body.data[0].building).toBeDefined();
    expect(listRes.body.data[0].building.name).toBe('List Building');
    expect(listRes.body.data[0].employee).toBeDefined();
    expect(listRes.body.data[0].lead).toBeDefined();
  });
});
