const request = require('supertest');
const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const rateLimit = require('express-rate-limit');
const { errorHandler } = require('../src/utils/apiResponse');

// Build a minimal app matching the real middleware stack
// (avoids importing server.js which starts listeners, DB connections, and cron jobs)
function createTestApp() {
  const app = express();
  app.use(helmet());
  app.use(cors());
  app.use(express.json());
  app.use(rateLimit({ windowMs: 15 * 60 * 1000, max: 100 }));

  app.use('*', (req, res) => {
    res.status(404).json({ success: false, error: { message: 'Route not found', code: 'NOT_FOUND' } });
  });

  app.use(errorHandler);
  return app;
}

describe('API integration', () => {
  const app = createTestApp();

  describe('404 handler', () => {
    it('returns 404 for unknown routes with standard error format', async () => {
      const res = await request(app).get('/api/nonexistent');
      expect(res.status).toBe(404);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns 404 for root non-api routes', async () => {
      const res = await request(app).get('/random-path');
      expect(res.status).toBe(404);
    });
  });

  describe('CORS headers', () => {
    it('sends CORS headers on request', async () => {
      const res = await request(app)
        .get('/api/units')
        .set('Origin', 'http://localhost:3000');
      expect(res.headers['access-control-allow-origin']).toBeDefined();
    });
  });

  describe('errorHandler middleware', () => {
    it('returns 500 for unhandled errors', async () => {
      const errApp = express();
      errApp.get('/err', (req, res, next) => {
        next(new Error('something broke'));
      });
      errApp.use(errorHandler);

      const res = await request(errApp).get('/err');
      expect(res.status).toBe(500);
      expect(res.body.success).toBe(false);
      expect(res.body.error.code).toBe('INTERNAL_ERROR');
    });

    it('returns 400 for ValidationError', async () => {
      const errApp = express();
      errApp.get('/validation', (req, res, next) => {
        const err = new Error('Field required');
        err.name = 'ValidationError';
        err.details = { field: 'email', message: 'Email is required' };
        next(err);
      });
      errApp.use(errorHandler);

      const res = await request(errApp).get('/validation');
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.details).toEqual({ field: 'email', message: 'Email is required' });
    });

    it('returns 404 for not-found errors', async () => {
      const errApp = express();
      errApp.get('/missing', (req, res, next) => {
        next(new Error('Unit not found'));
      });
      errApp.use(errorHandler);

      const res = await request(errApp).get('/missing');
      expect(res.status).toBe(404);
      expect(res.body.error.code).toBe('NOT_FOUND');
    });

    it('returns 401 for UnauthorizedError', async () => {
      const errApp = express();
      errApp.get('/protected', (req, res, next) => {
        const err = new Error('No token');
        err.name = 'UnauthorizedError';
        next(err);
      });
      errApp.use(errorHandler);

      const res = await request(errApp).get('/protected');
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('UNAUTHORIZED');
    });

    it('returns 409 for duplicate entry (PG code 23505)', async () => {
      const errApp = express();
      errApp.get('/dup', (req, res, next) => {
        const err = new Error('duplicate key');
        err.code = '23505';
        next(err);
      });
      errApp.use(errorHandler);

      const res = await request(errApp).get('/dup');
      expect(res.status).toBe(409);
      expect(res.body.error.code).toBe('DUPLICATE_ENTRY');
    });
  });
});
