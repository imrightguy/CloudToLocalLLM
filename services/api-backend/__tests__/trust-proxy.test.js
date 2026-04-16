const express = require('express');
const request = require('supertest');

const { apiLimiter } = require('../src/middleware/rateLimiters');

function createApp(trustProxy) {
  const app = express();
  if (trustProxy !== undefined) {
    app.set('trust proxy', trustProxy);
  }
  app.use(apiLimiter);
  app.get('/test', (req, res) => {
    res.json({ ip: req.ip });
  });
  return app;
}

describe('rate limiter respects X-Forwarded-For when trust proxy is enabled', () => {
  it('uses client IP from X-Forwarded-For when trust proxy is set', async () => {
    const app = createApp(1);
    const res = await request(app)
      .get('/test')
      .set('X-Forwarded-For', '203.0.113.50');

    expect(res.status).toBe(200);
    expect(res.body.ip).toBe('203.0.113.50');
  });

    it('ignores X-Forwarded-For when trust proxy is not set', async () => {
    const app = createApp(false);
    const res = await request(app)
      .get('/test')
      .set('X-Forwarded-For', '203.0.113.50');

    expect(res.status).toBe(200);
    expect(res.body.ip).not.toBe('203.0.113.50');
  });

  it('rate-limits per forwarded IP when trust proxy is enabled', async () => {
    const app = createApp(1);

    const makeRequest = (ip) =>
      request(app).get('/test').set('X-Forwarded-For', ip);

    const res1 = await makeRequest('10.0.0.1');
    expect(res1.status).toBe(200);

    const res2 = await makeRequest('10.0.0.2');
    expect(res2.status).toBe(200);
  });
});
