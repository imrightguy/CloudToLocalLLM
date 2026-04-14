const { getTestDb, createTestApp, runMigrations, cleanAllTables, registerTestUser, authHeader, createTestBuilding, createTestEmployee, createTestSchedule } = require('./helpers');
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

describe('Employee scheduling integration flow', () => {
  it('Create Employee -> Create Schedule -> Check Availability', async () => {
    const email = `emp-sched-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });

    const { building } = await createTestBuilding(app, tokens, {
      name: 'Sched Building',
      address: '789 Blvd René-Lévesque',
    });

    const { employee } = await createTestEmployee(app, tokens, {
      firstName: 'Julie',
      lastName: 'Gagnon',
      phone: '+15145554444',
    });
    expect(employee.id).toBeDefined();

    const { schedule, response: schedRes } = await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building.id,
      dayOfWeek: 1,
      startTime: '09:00',
      endTime: '17:00',
    });

    expect(schedRes.status).toBe(201);
    expect(schedule.dayOfWeek).toBe(1);
    expect(schedule.startTime).toBe('09:00');
    expect(schedule.endTime).toBe('17:00');

    const nextTuesday = new Date();
    const daysUntilTue = ((1 - nextTuesday.getDay()) + 7) % 7 || 7;
    nextTuesday.setDate(nextTuesday.getDate() + daysUntilTue);
    const dateStr = nextTuesday.toISOString().split('T')[0];

    const availRes = await request(app)
      .get(`/api/schedules/employee/${employee.id}/availability?date=${dateStr}`)
      .set(authHeader(tokens));

    expect(availRes.status).toBe(200);
    expect(availRes.body.data.employeeId).toBe(employee.id);
    expect(availRes.body.data.dayOfWeek).toBe(1);
    expect(availRes.body.data.schedules.length).toBe(1);
    expect(availRes.body.data.schedules[0].startTime).toBe('09:00');
  });

  it('returns no availability when employee has no schedule for that day', async () => {
    const email = `emp-noavail-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { building } = await createTestBuilding(app, tokens);
    const { employee } = await createTestEmployee(app, tokens);

    await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building.id,
      dayOfWeek: 0,
      startTime: '09:00',
      endTime: '17:00',
    });

    const nextWednesday = new Date();
    const daysUntilWed = ((3 - nextWednesday.getDay()) + 7) % 7 || 7;
    nextWednesday.setDate(nextWednesday.getDate() + daysUntilWed);
    const dateStr = nextWednesday.toISOString().split('T')[0];

    const availRes = await request(app)
      .get(`/api/schedules/employee/${employee.id}/availability?date=${dateStr}`)
      .set(authHeader(tokens));

    expect(availRes.status).toBe(200);
    expect(availRes.body.data.schedules.length).toBe(0);
  });

  it('detects overlapping schedule conflicts for visits', async () => {
    const email = `emp-conflict-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { building } = await createTestBuilding(app, tokens);
    const { employee } = await createTestEmployee(app, tokens);

    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 5);
    const dayOfWeek = futureDate.getDay();
    const scheduleDay = dayOfWeek === 0 ? 6 : dayOfWeek - 1;

    await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building.id,
      dayOfWeek: scheduleDay,
      startTime: '08:00',
      endTime: '20:00',
    });

    const { createTestUnit } = require('./helpers');
    const { createTestLead } = require('./helpers');
    const { createTestVisit } = require('./helpers');

    const { unit } = await createTestUnit(app, tokens, building.id);
    const { lead: lead1 } = await createTestLead(app, tokens, { fullName: 'Lead One' });
    const { lead: lead2 } = await createTestLead(app, tokens, { fullName: 'Lead Two' });

    futureDate.setHours(10, 0, 0, 0);

    const { visit: visit1 } = await createTestVisit(app, tokens, {
      unitId: unit.id,
      employeeId: employee.id,
      leadId: lead1.id,
      dateTime: futureDate.toISOString(),
      durationMinutes: 60,
    });

    expect(visit1.id).toBeDefined();

    const conflictingTime = new Date(futureDate);
    conflictingTime.setMinutes(30);

    const conflictRes = await request(app)
      .post('/api/visits')
      .set(authHeader(tokens))
      .send({
        unitId: unit.id,
        employeeId: employee.id,
        leadId: lead2.id,
        dateTime: conflictingTime.toISOString(),
        durationMinutes: 60,
      });

    expect(conflictRes.status).toBe(409);
    expect(conflictRes.body.error.code).toBe('VISIT_CONFLICT');
    expect(conflictRes.body.error.details.conflictingVisitId).toBe(visit1.id);
  });

  it('allows non-overlapping visits for same employee', async () => {
    const email = `emp-noconflict-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { building } = await createTestBuilding(app, tokens);
    const { employee } = await createTestEmployee(app, tokens);

    const futureDate = new Date();
    futureDate.setDate(futureDate.getDate() + 5);
    const dayOfWeek = futureDate.getDay();
    const scheduleDay = dayOfWeek === 0 ? 6 : dayOfWeek - 1;

    await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building.id,
      dayOfWeek: scheduleDay,
      startTime: '08:00',
      endTime: '20:00',
    });

    const { createTestUnit } = require('./helpers');
    const { createTestLead } = require('./helpers');
    const { createTestVisit } = require('./helpers');

    const { unit } = await createTestUnit(app, tokens, building.id);
    const { lead: lead1 } = await createTestLead(app, tokens, { fullName: 'Lead Morning' });
    const { lead: lead2 } = await createTestLead(app, tokens, { fullName: 'Lead Afternoon' });

    futureDate.setHours(9, 0, 0, 0);

    const { visit: visit1 } = await createTestVisit(app, tokens, {
      unitId: unit.id,
      employeeId: employee.id,
      leadId: lead1.id,
      dateTime: futureDate.toISOString(),
      durationMinutes: 60,
    });

    expect(visit1.id).toBeDefined();

    const nonConflictTime = new Date(futureDate);
    nonConflictTime.setHours(14, 0, 0, 0);

    const nonConflictRes = await request(app)
      .post('/api/visits')
      .set(authHeader(tokens))
      .send({
        unitId: unit.id,
        employeeId: employee.id,
        leadId: lead2.id,
        dateTime: nonConflictTime.toISOString(),
        durationMinutes: 60,
      });

    expect(nonConflictRes.status).toBe(201);
    expect(nonConflictRes.body.data.id).toBeDefined();
  });

  it('CRUD operations on schedules', async () => {
    const email = `emp-crud-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { building } = await createTestBuilding(app, tokens);
    const { employee } = await createTestEmployee(app, tokens);

    const { schedule } = await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building.id,
      dayOfWeek: 2,
      startTime: '10:00',
      endTime: '16:00',
    });

    const getRes = await request(app)
      .get(`/api/schedules/${schedule.id}`)
      .set(authHeader(tokens));

    expect(getRes.status).toBe(200);
    expect(getRes.body.data.dayOfWeek).toBe(2);

    const updateRes = await request(app)
      .put(`/api/schedules/${schedule.id}`)
      .set(authHeader(tokens))
      .send({ startTime: '08:00', endTime: '18:00' });

    expect(updateRes.status).toBe(200);
    expect(updateRes.body.data.startTime).toBe('08:00');

    const deleteRes = await request(app)
      .delete(`/api/schedules/${schedule.id}`)
      .set(authHeader(tokens));

    expect(deleteRes.status).toBe(200);

    const getAfterDelete = await request(app)
      .get(`/api/schedules/${schedule.id}`)
      .set(authHeader(tokens));

    expect(getAfterDelete.status).toBe(200);
    expect(getAfterDelete.body.data.isActive).toBe(false);
  });

  it('filters schedules by employee and building', async () => {
    const email = `emp-filter-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { building: building1 } = await createTestBuilding(app, tokens, { name: 'B1' });
    const { building: building2 } = await createTestBuilding(app, tokens, { name: 'B2' });
    const { employee } = await createTestEmployee(app, tokens);

    await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building1.id,
      dayOfWeek: 0,
      startTime: '09:00',
      endTime: '17:00',
    });

    await createTestSchedule(app, tokens, {
      employeeId: employee.id,
      buildingId: building2.id,
      dayOfWeek: 1,
      startTime: '10:00',
      endTime: '18:00',
    });

    const filterRes = await request(app)
      .get(`/api/schedules?employeeId=${employee.id}&buildingId=${building1.id}`)
      .set(authHeader(tokens));

    expect(filterRes.status).toBe(200);
    expect(filterRes.body.data.length).toBe(1);
    expect(filterRes.body.data[0].buildingId).toBe(building1.id);
  });
});
