const express = require('express');
const supertest = require('supertest');

jest.mock('../src/database/connection', () => ({
  connect: jest.fn().mockResolvedValue(true),
  db: {},
  pool: {},
  closeDatabase: jest.fn(),
}));

jest.mock('../src/auth/jwt.middleware', () => ({
  authenticateToken: (req, res, next) => {
    req.user = { id: 'user-1' };
    next();
  },
  authorizeRole: () => (req, res, next) => next(),
  requireCompanyAccess: (req, res, next) => next(),
  optionalAuth: (req, res, next) => next(),
}));

jest.mock('../src/controllers/photo.controller', () => ({
  listPropertyPhotos: async (req, res) => res.status(200).json({
    success: true,
    data: [],
    metadata: { total: 0, page: 1, limit: 20, totalPages: 0, hasMore: false },
  }),
  createPropertyPhoto: async (req, res) => res.status(201).json({
    success: true,
    data: { id: 'photo-1', companyId: req.params.companyId },
    message: 'Photo record created successfully',
  }),
  uploadPropertyPhoto: async (req, res) => res.status(201).json({
    success: true,
    data: { id: 'photo-upload-1', companyId: req.params.companyId },
    message: 'Photo file uploaded successfully',
  }),
  downloadPropertyPhotoFile: async (req, res) => res.status(200).send('binary-photo'),
}));

const router = require('../src/routes/index');

function createApp() {
  const app = express();
  app.use(express.json());
  app.use('/api', router);
  return app;
}

describe('photo route exposure through the API router', () => {
  it('exposes GET /api/companies/:companyId/photos', async () => {
    const app = createApp();

    const res = await supertest(app).get('/api/companies/388be569-9d9d-46e2-b548-7bf0167cb11b/photos');

    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.data).toEqual([]);
  });

  it('exposes POST /api/companies/:companyId/photos', async () => {
    const app = createApp();

    const res = await supertest(app)
      .post('/api/companies/388be569-9d9d-46e2-b548-7bf0167cb11b/photos')
      .send({
        buildingId: '550e8400-e29b-41d4-a716-446655440001',
        useCase: 'maintenance',
        fileName: 'photo.jpg',
        url: 'https://example.com/photo.jpg',
      });

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.companyId).toBe('388be569-9d9d-46e2-b548-7bf0167cb11b');
  });

  it('exposes POST /api/companies/:companyId/photos/upload', async () => {
    const app = createApp();

    const res = await supertest(app)
      .post('/api/companies/388be569-9d9d-46e2-b548-7bf0167cb11b/photos/upload')
      .field('buildingId', '550e8400-e29b-41d4-a716-446655440001')
      .field('useCase', 'maintenance')
      .attach('file', Buffer.from('fake-binary'), 'photo.jpg');

    expect(res.status).toBe(201);
    expect(res.body.success).toBe(true);
    expect(res.body.data.companyId).toBe('388be569-9d9d-46e2-b548-7bf0167cb11b');
  });

  it('exposes GET /api/companies/:companyId/photos/:photoId/file', async () => {
    const app = createApp();

    const res = await supertest(app).get('/api/companies/388be569-9d9d-46e2-b548-7bf0167cb11b/photos/550e8400-e29b-41d4-a716-446655440099/file');

    expect(res.status).toBe(200);
    expect(res.text).toBe('binary-photo');
  });
});
