const { getTestDb, createTestApp, runMigrations, cleanAllTables, registerTestUser, authHeader, createTestLead } = require('./helpers');
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

describe('Lead lifecycle integration flow', () => {
  const lifecycleStages = [
    'nouveau',
    'contacte',
    'qualifie',
    'visite_planifiee',
    'offreEnvoyee',
    'negociation',
    'bailSigne',
    'signe',
  ];

  it('creates a lead and walks through all lifecycle stages', async () => {
    const email = `lead-flow-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });

    const { lead, response: createRes } = await createTestLead(app, tokens, {
      fullName: 'Sophie Martin',
      email: 'sophie@example.com',
      phone: '+15145553333',
      source: 'website',
      notes: 'Interested in 4 1/2',
    });

    expect(createRes.status).toBe(201);
    expect(lead.fullName).toBe('Sophie Martin');
    expect(lead.stage).toBe('nouveau');

    const leadId = lead.id;

    for (const stage of lifecycleStages) {
      const res = await request(app)
        .patch(`/api/leads/${leadId}/status`)
        .set(authHeader(tokens))
        .send({ stage });

      expect(res.status).toBe(200);
      expect(res.body.data.stage).toBe(stage);
    }

    const finalLead = await request(app)
      .get(`/api/leads/${leadId}`)
      .set(authHeader(tokens));

    expect(finalLead.status).toBe(200);
    expect(finalLead.body.data.stage).toBe('signe');
  });

  it('rejects invalid stage transitions', async () => {
    const email = `lead-invalid-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { lead } = await createTestLead(app, tokens);

    const res = await request(app)
      .patch(`/api/leads/${lead.id}/status`)
      .set(authHeader(tokens))
      .send({ stage: 'nonexistent_stage' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('allows updating lead fields', async () => {
    const email = `lead-update-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { lead } = await createTestLead(app, tokens, { fullName: 'Original Name' });

    const updateRes = await request(app)
      .put(`/api/leads/${lead.id}`)
      .set(authHeader(tokens))
      .send({
        fullName: 'Updated Name',
        notes: 'Called on Monday',
        tags: ['hot', 'urgent'],
      });

    expect(updateRes.status).toBe(200);
    expect(updateRes.body.data.fullName).toBe('Updated Name');
    expect(updateRes.body.data.notes).toBe('Called on Monday');
    expect(updateRes.body.data.tags).toEqual(['hot', 'urgent']);
  });

  it('soft-deletes a lead', async () => {
    const email = `lead-delete-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });
    const { lead } = await createTestLead(app, tokens);

    const deleteRes = await request(app)
      .delete(`/api/leads/${lead.id}`)
      .set(authHeader(tokens));

    expect(deleteRes.status).toBe(200);

    const getRes = await request(app)
      .get(`/api/leads/${lead.id}`)
      .set(authHeader(tokens));

    expect(getRes.status).toBe(200);
    expect(getRes.body.data.isActive).toBe(false);
  });

  it('lists leads with pagination and filtering', async () => {
    const email = `lead-list-${Date.now()}@example.com`;
    cleanupUser = email;

    const { tokens } = await registerTestUser(app, { email });

    await createTestLead(app, tokens, { fullName: 'Alice', stage: 'nouveau' });
    await createTestLead(app, tokens, { fullName: 'Bob', stage: 'contacte' });
    await createTestLead(app, tokens, { fullName: 'Charlie', stage: 'nouveau' });

    const listRes = await request(app)
      .get('/api/leads?stage=nouveau')
      .set(authHeader(tokens));

    expect(listRes.status).toBe(200);
    expect(listRes.body.data.length).toBe(2);
    expect(listRes.body.metadata.total).toBe(2);

    const allRes = await request(app)
      .get('/api/leads?limit=2&page=1')
      .set(authHeader(tokens));

    expect(allRes.status).toBe(200);
    expect(allRes.body.data.length).toBe(2);
    expect(allRes.body.metadata.totalPages).toBe(2);
  });
});
