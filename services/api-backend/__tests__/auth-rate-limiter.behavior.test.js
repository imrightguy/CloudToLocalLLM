const express = require('express');
const request = require('supertest');

function createAuthLimiterApp({ succeed = false } = {}) {
  const app = express();
  app.set('trust proxy', 1);
  app.use(express.json());
  const { authLimiter } = require('../src/middleware/rateLimiters');
  app.post('/login', authLimiter, (req, res) => {
    if (succeed) {
      return res.status(200).json({ success: true });
    }
    return res.status(401).json({ success: false, error: { message: 'Invalid credentials', code: 'INVALID_CREDENTIALS' } });
  });
  return app;
}

describe('authLimiter login protection behavior', () => {
  beforeEach(() => {
    jest.resetModules();
  });

  it('rate-limits only after 10 failed login attempts for the same email and IP', async () => {
    const app = createAuthLimiterApp();

    for (let i = 0; i < 10; i += 1) {
      const res = await request(app)
        .post('/login')
        .set('X-Forwarded-For', '203.0.113.10')
        .send({ email: 'same@example.com', password: 'wrongpass' });
      expect(res.status).toBe(401);
    }

    const blocked = await request(app)
      .post('/login')
      .set('X-Forwarded-For', '203.0.113.10')
      .send({ email: 'same@example.com', password: 'wrongpass' });

    expect(blocked.status).toBe(429);
    expect(blocked.body.error.code).toBe('AUTH_RATE_LIMIT_EXCEEDED');
  });

  it('does not let one email lock out another email on the same IP', async () => {
    const app = createAuthLimiterApp();

    for (let i = 0; i < 10; i += 1) {
      const res = await request(app)
        .post('/login')
        .set('X-Forwarded-For', '203.0.113.11')
        .send({ email: 'first@example.com', password: 'wrongpass' });
      expect(res.status).toBe(401);
    }

    const otherEmail = await request(app)
      .post('/login')
      .set('X-Forwarded-For', '203.0.113.11')
      .send({ email: 'second@example.com', password: 'wrongpass' });

    expect(otherEmail.status).toBe(401);
    expect(otherEmail.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('does not let one IP lock out the same email from a different IP', async () => {
    const app = createAuthLimiterApp();

    // Fresh email unique to this test — no shared state with other tests
    const email = 'test-diffip-' + Date.now() + '@example.com';

    for (let i = 0; i < 10; i += 1) {
      const res = await request(app)
        .post('/login')
        .set('X-Forwarded-For', '203.0.113.12')
        .send({ email, password: 'wrongpass' });
      expect(res.status).toBe(401);
    }

    const otherIp = await request(app)
      .post('/login')
      .set('X-Forwarded-For', '203.0.113.13')
      .send({ email, password: 'wrongpass' });

    expect(otherIp.status).toBe(401);
    expect(otherIp.body.error.code).toBe('INVALID_CREDENTIALS');
  });
});
