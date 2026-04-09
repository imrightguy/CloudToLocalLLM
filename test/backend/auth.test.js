import request from 'supertest';

const { app } = (await import('../../backend/auth/handlers.js')).default || await import('../../backend/auth/handlers.js');

describe('Auth Backend', () => {
  describe('GET /health', () => {
    it('returns 200 with status ok', async () => {
      const res = await request(app).get('/health');
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ status: 'ok' });
    });
  });

  describe('CORS', () => {
    const allowedOrigins = [
      'https://app.cloudtolocalllm.online',
      'https://cloudtolocalllm.online',
      'http://localhost:3000',
      'http://localhost:8080',
      'http://127.0.0.1:3000',
      'http://127.0.0.1:8080',
    ];

    allowedOrigins.forEach((origin) => {
      it(`allows origin ${origin}`, async () => {
        const res = await request(app).get('/health').set('Origin', origin);
        expect(res.status).toBe(200);
      });
    });

    it('strips CORS headers for disallowed origin', async () => {
      const res = await request(app)
        .get('/health')
        .set('Origin', 'https://evil.com');
      expect(res.status).toBe(200);
      expect(res.headers['access-control-allow-origin']).toBeUndefined();
    });
  });

  describe('GET /api/protected', () => {
    it('returns 401 without token', async () => {
      const res = await request(app).get('/api/protected');
      expect(res.status).toBe(401);
    });

    it('returns 401 with invalid token', async () => {
      const res = await request(app)
        .get('/api/protected')
        .set('Authorization', 'Bearer invalid.jwt.token');
      expect(res.status).toBe(401);
    });
  });
});
