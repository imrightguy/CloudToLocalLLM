const express = require('express');
const supertest = require('supertest');

jest.mock('../src/auth/jwt.middleware', () => ({
  authenticateToken: (req, res, next) => {
    req.user = { id: 'user-1' };
    next();
  },
  authorizeRole: () => (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));

jest.mock('../src/controllers/dossier.controller', () => ({
  listDossierCases: async (req, res) => res.status(200).json({
    success: true,
    data: [{ id: 'case-1', companyId: req.params.companyId }],
    message: 'Dossier cases retrieved successfully',
    metadata: { count: 1 },
  }),
  createDossierCase: async (req, res) => res.status(201).json({
    success: true,
    data: { id: 'case-1', companyId: req.params.companyId },
    message: 'Dossier case created successfully',
  }),
  getDossierCaseById: async (req, res) => res.status(200).json({
    success: true,
    data: { id: req.params.id, companyId: req.params.companyId },
    message: 'Dossier case retrieved successfully',
  }),
  reviewDossierCase: async (req, res) => res.status(200).json({
    success: true,
    data: { id: req.params.id, companyId: req.params.companyId, status: req.body.status },
    message: 'Dossier case reviewed successfully',
  }),
  exportDossierCase: async (req, res) => res.status(200).json({
    success: true,
    data: { id: req.params.id, companyId: req.params.companyId },
    message: 'Dossier case exported successfully',
  }),
}));

const router = require('../src/routes/dossier.routes');

function createApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/companies/:companyId/dossiers', router);
  return app;
}

describe('dossier route exposure through the company-scoped router', () => {
  it('exposes GET /api/companies/:companyId/dossiers with the company id available to the controller', async () => {
    const app = createApp();

    const res = await supertest(app).get('/api/companies/388be569-9d9d-46e2-b548-7bf0167cb11b/dossiers');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toEqual([
      expect.objectContaining({ companyId: '388be569-9d9d-46e2-b548-7bf0167cb11b' }),
    ]);
  });

  it('exposes POST /api/companies/:companyId/dossiers with the company id available to the controller', async () => {
    const app = createApp();

    const res = await supertest(app)
      .post('/api/companies/388be569-9d9d-46e2-b548-7bf0167cb11b/dossiers')
      .send({
        problemCategory: 'maintenance',
        leadId: '550e8400-e29b-41d4-a716-446655440001',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.companyId).toBe('388be569-9d9d-46e2-b548-7bf0167cb11b');
  });

  it('exposes GET /api/companies/:companyId/dossiers/:id/export with nested params available to the controller', async () => {
    const app = createApp();

    const res = await supertest(app).get('/api/companies/388be569-9d9d-46e2-b548-7bf0167cb11b/dossiers/550e8400-e29b-41d4-a716-446655440099/export');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toEqual(expect.objectContaining({
      id: '550e8400-e29b-41d4-a716-446655440099',
      companyId: '388be569-9d9d-46e2-b548-7bf0167cb11b',
    }));
  });
});
