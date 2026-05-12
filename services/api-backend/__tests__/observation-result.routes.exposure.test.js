const express = require('express');
const request = require('supertest');

jest.mock('../src/auth/jwt.middleware', () => ({
  authenticateToken: (req, res, next) => {
    req.user = { id: 'user-1' };
    next();
  },
  authorizeRole: () => (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));

jest.mock('../src/controllers/observation-result.controller', () => ({
  listObservationResults: async (req, res) => res.status(200).json({
    success: true,
    data: [],
    metadata: { total: 0, page: 1, limit: 5, totalPages: 0, hasMore: false },
    companyId: req.params.companyId,
  }),
  importObservationResults: async (req, res) => res.status(201).json({
    success: true,
    data: [{ id: 'obs-1', companyId: req.params.companyId }],
    message: 'Observation results imported successfully',
  }),
  getObservationResultById: async (req, res) => res.status(200).json({
    success: true,
    data: { id: req.params.id, companyId: req.params.companyId },
    message: 'Observation result retrieved successfully',
  }),
  reviewObservationResult: async (req, res) => res.status(200).json({
    success: true,
    data: { id: req.params.id, companyId: req.params.companyId },
    message: 'Observation result reviewed successfully',
  }),
  dismissObservationResult: async (req, res) => res.status(200).json({
    success: true,
    data: { id: req.params.id, companyId: req.params.companyId },
    message: 'Observation result dismissed successfully',
  }),
}));

const observationResultRoutes = require('../src/routes/observation-result.routes');

function createApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/companies/:companyId/observation-results', observationResultRoutes);
  return app;
}

describe('observation-result route exposure through nested company routes', () => {
  it('propagates companyId into GET /api/companies/:companyId/observation-results', async () => {
    const app = createApp();

    const res = await request(app).get('/api/companies/388be569-9d9d-46e2-b548-7bf0167cb11b/observation-results?page=1&limit=5');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.companyId).toBe('388be569-9d9d-46e2-b548-7bf0167cb11b');
    expect(res.body.data).toEqual([]);
  });

});
