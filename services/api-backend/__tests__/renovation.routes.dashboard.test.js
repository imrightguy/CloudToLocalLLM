const express = require('express');
const supertest = require('supertest');

jest.mock('../src/auth/jwt.middleware', () => ({
  authenticateToken: (req, _res, next) => {
    req.user = { id: 'user-1' };
    next();
  },
}));

jest.mock('../src/controllers/renovation.controller', () => ({
  getDashboard: async (_req, res) => res.status(200).json({ success: true, data: { ok: true }, message: 'dashboard ok' }),
  getRenovationRecords: async (_req, res) => res.status(200).json({ success: true, data: [] }),
  createRenovationRecord: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  getRenovationRecordById: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  updateRenovationRecord: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  deleteRenovationRecord: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  getRenovationTasks: async (_req, res) => res.status(200).json({ success: true, data: [] }),
  createRenovationTask: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  updateRenovationTask: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  deleteRenovationTask: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  getRenovationOrders: async (_req, res) => res.status(200).json({ success: true, data: [] }),
  createRenovationOrder: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  updateRenovationOrder: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  deleteRenovationOrder: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  createReceivingEvent: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  getRenovationReceivingEvents: async (_req, res) => res.status(200).json({ success: true, data: [] }),
  getRenovationSurplusItems: async (_req, res) => res.status(200).json({ success: true, data: [] }),
  createRenovationSurplusItem: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  updateRenovationSurplusItem: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  deleteRenovationSurplusItem: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  getRenovationWorkerIntakeRecords: async (_req, res) => res.status(200).json({ success: true, data: [] }),
  createRenovationWorkerIntakeRecord: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  updateRenovationWorkerIntakeRecord: async (_req, res) => res.status(200).json({ success: true, data: {} }),
  deleteRenovationWorkerIntakeRecord: async (_req, res) => res.status(200).json({ success: true, data: {} }),
}));

const renovationRouter = require('../src/routes/renovation.routes');

function createApp() {
  const app = express();
  app.use(express.json());
  app.use('/api/renovations', renovationRouter);
  return app;
}

describe('renovation route dashboard exposure', () => {
  it('registers /dashboard before the UUID-constrained id route so dashboard requests do not hit UUID validation', () => {
    const dashboardRouteIndex = renovationRouter.stack.findIndex((layer) => layer.route?.path === '/dashboard' && layer.route.methods.get);
    const idRouteIndex = renovationRouter.stack.findIndex((layer) => layer.route?.path?.startsWith('/:id(') && layer.route.methods.get);

    expect(dashboardRouteIndex).toBeGreaterThanOrEqual(0);
    expect(idRouteIndex).toBeGreaterThanOrEqual(0);
    expect(dashboardRouteIndex).toBeLessThan(idRouteIndex);
    expect(renovationRouter.stack[dashboardRouteIndex].route.stack.map((layer) => layer.name)).toEqual(['authenticateToken', '<anonymous>']);
  });

  it('returns the dashboard handler for GET /api/renovations/dashboard', async () => {
    const app = createApp();

    const res = await supertest(app).get('/api/renovations/dashboard');

    expect(res.status).toBe(200);
    expect(res.body).toEqual(expect.objectContaining({
      success: true,
      message: 'dashboard ok',
      data: { ok: true },
    }));
  });
});
