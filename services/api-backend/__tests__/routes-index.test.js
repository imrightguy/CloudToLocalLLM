const express = require('express');
const supertest = require('supertest');

jest.mock('../src/database/connection', () => ({
  connect: jest.fn().mockResolvedValue(true),
  db: {},
  pool: {},
  closeDatabase: jest.fn(),
}));

const router = require('../src/routes/index');

function createApp() {
  const app = express();
  app.use(express.json());
  app.use('/api', router);
  return app;
}

describe('routes/index', () => {
  let app;

  beforeEach(() => {
    app = createApp();
    jest.clearAllMocks();
  });

  it('exports a valid express router', () => {
    expect(router).toBeDefined();
    expect(typeof router.use).toBe('function');
    expect(typeof router.get).toBe('function');
    expect(typeof router.post).toBe('function');
  });

  describe('GET /api/health', () => {
    it('returns healthy status with database connected', async () => {
      const { connect } = require('../src/database/connection');
      connect.mockResolvedValueOnce(true);

      const res = await supertest(app).get('/api/health');

      expect(res.status).toBe(200);
      expect(res.body.status).toBe('healthy');
      expect(res.body.version).toBe('1.0.0');
      expect(res.body.uptime).toBeGreaterThan(0);
      expect(res.body.timestamp).toBeDefined();
      expect(res.body.database).toBeDefined();
      expect(res.body.database.status).toBe('connected');
      expect(res.body.database.latencyMs).toBeGreaterThanOrEqual(0);
    });

    it('returns unhealthy status when database fails', async () => {
      const { connect } = require('../src/database/connection');
      connect.mockRejectedValueOnce(new Error('Connection refused'));

      const res = await supertest(app).get('/api/health');

      expect(res.status).toBe(503);
      expect(res.body.status).toBe('unhealthy');
      expect(res.body.database).toBeDefined();
      expect(res.body.database.status).toBe('disconnected');
      expect(res.body.database.error).toBe('Connection refused');
    });

    it('includes CORS headers in health response', async () => {
      const { connect } = require('../src/database/connection');
      connect.mockResolvedValueOnce(true);

      const res = await supertest(app).get('/api/health');

      expect(res.headers['access-control-allow-origin']).toBeDefined();
    });

    it('returns complete structure on unhealthy response', async () => {
      const { connect } = require('../src/database/connection');
      connect.mockRejectedValueOnce(new Error('ECONNREFUSED'));

      const res = await supertest(app).get('/api/health');

      expect(res.status).toBe(503);
      expect(res.body).toHaveProperty('status', 'unhealthy');
      expect(res.body).toHaveProperty('timestamp');
      expect(res.body).toHaveProperty('version', '1.0.0');
      expect(res.body).toHaveProperty('uptime');
      expect(res.body).toHaveProperty('database');
      expect(res.body.database).toHaveProperty('status', 'disconnected');
      expect(res.body.database).toHaveProperty('error');
    });
  });

  describe('404 handling', () => {
    it('returns 404 for unregistered routes', async () => {
      const res = await supertest(app).get('/api/nonexistent-route');

      expect(res.status).toBe(404);
    });

    it('returns 404 for deeply nested unregistered paths', async () => {
      const res = await supertest(app).get('/api/buildings/99999/unit');

      expect(res.status).toBe(404);
    });
  });
});
