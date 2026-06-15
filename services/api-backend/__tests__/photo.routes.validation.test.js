const validate = require('../src/middleware/validate');
const { photoRecordSchemas } = require('../src/config/validation-schemas');
const photoRouter = require('../src/routes/photo.routes');

function mockReqRes(body = {}, query = {}, params = {}) {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  const next = jest.fn();
  return { req: { body, query, params }, res, next };
}

describe('Photo route validation contract', () => {
  it('protects GET / with authentication and validation before the controller', () => {
    const listRoute = photoRouter.stack.find((layer) => layer.route?.path === '/' && layer.route.methods.get);

    expect(listRoute).toBeDefined();
    expect(listRoute.route.stack.map((layer) => layer.name)).toEqual(['authenticateToken', 'requireCompanyAccess', '<anonymous>', '<anonymous>']);
  });

  it('protects POST / with authentication and validation before the controller', () => {
    const createRoute = photoRouter.stack.find((layer) => layer.route?.path === '/' && layer.route.methods.post);

    expect(createRoute).toBeDefined();
    expect(createRoute.route.stack.map((layer) => layer.name)).toEqual(['authenticateToken', 'requireCompanyAccess', '<anonymous>', '<anonymous>']);
  });

  it('protects POST /upload with upload parsing before validation and the controller', () => {
    const uploadRoute = photoRouter.stack.find((layer) => layer.route?.path === '/upload' && layer.route.methods.post);

    expect(uploadRoute).toBeDefined();
    expect(uploadRoute.route.stack.map((layer) => layer.name)).toEqual(['authenticateToken', 'requireCompanyAccess', 'parsePropertyPhotoUpload', '<anonymous>', '<anonymous>']);
  });

  it('accepts the photo record create payload used by the mobile capture flow', () => {
    const { req, res, next } = mockReqRes({
      buildingId: '550e8400-e29b-41d4-a716-446655440001',
      unitId: '550e8400-e29b-41d4-a716-446655440002',
      roomContext: 'Salon',
      useCase: 'maintenance',
      displayOrder: 3,
      fileName: 'living-room.jpg',
      mimeType: 'image/jpeg',
      url: 'https://example.com/living-room.jpg',
      documentRefId: 'doc-1',
      capturedAt: '2026-05-06T10:00:00.000Z',
      metadata: { source: 'mobile' },
    }, {}, {
      companyId: '388be569-9d9d-46e2-b548-7bf0167cb11b',
    });

    validate(photoRecordSchemas.create)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.params).toEqual({ companyId: '388be569-9d9d-46e2-b548-7bf0167cb11b' });
    expect(req.body).toMatchObject({
      buildingId: '550e8400-e29b-41d4-a716-446655440001',
      unitId: '550e8400-e29b-41d4-a716-446655440002',
      roomContext: 'Salon',
      useCase: 'maintenance',
      displayOrder: 3,
      fileName: 'living-room.jpg',
      mimeType: 'image/jpeg',
      url: 'https://example.com/living-room.jpg',
      documentRefId: 'doc-1',
      metadata: { source: 'mobile' },
    });
  });

  it('accepts the photo upload payload used by the binary capture flow', () => {
    const { req, res, next } = mockReqRes({
      buildingId: '550e8400-e29b-41d4-a716-446655440001',
      unitId: '550e8400-e29b-41d4-a716-446655440002',
      roomContext: 'Cuisine',
      useCase: 'maintenance',
      displayOrder: 1,
      documentRefId: 'doc-1',
      capturedAt: '2026-05-06T10:00:00.000Z',
      metadata: { source: 'mobile' },
    }, {}, {
      companyId: '388be569-9d9d-46e2-b548-7bf0167cb11b',
    });

    validate(photoRecordSchemas.upload)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body).toMatchObject({
      buildingId: '550e8400-e29b-41d4-a716-446655440001',
      unitId: '550e8400-e29b-41d4-a716-446655440002',
      roomContext: 'Cuisine',
      useCase: 'maintenance',
      displayOrder: 1,
      documentRefId: 'doc-1',
      metadata: { source: 'mobile' },
    });
  });

  it('accepts filters for company, building, unit, use case, and inactive records', () => {
    const { req, res, next } = mockReqRes({}, {
      page: '2',
      limit: '25',
      buildingId: '550e8400-e29b-41d4-a716-446655440001',
      unitId: '550e8400-e29b-41d4-a716-446655440002',
      useCase: 'marketing',
      roomContext: 'Cuisine',
      includeInactive: 'true',
    }, {
      companyId: '388be569-9d9d-46e2-b548-7bf0167cb11b',
    });

    validate(photoRecordSchemas.list)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.query).toMatchObject({
      page: 2,
      limit: 25,
      buildingId: '550e8400-e29b-41d4-a716-446655440001',
      unitId: '550e8400-e29b-41d4-a716-446655440002',
      useCase: 'marketing',
      roomContext: 'Cuisine',
      includeInactive: true,
    });
  });

  it('rejects invalid photo record payloads early', () => {
    const { req, res, next } = mockReqRes({
      buildingId: 'not-a-uuid',
      useCase: 'floorplan',
      fileName: '',
      url: 'not-a-url',
    }, { includeInactive: 'maybe' }, { companyId: 'not-a-uuid' });

    validate(photoRecordSchemas.create)(req, res, next);

    expect(res.status).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledTimes(1);
    const [error] = next.mock.calls[0];
    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe('ValidationError');
    expect(error.details.params).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: 'companyId' }),
    ]));
    expect(error.details.body).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: 'buildingId' }),
      expect.objectContaining({ field: 'useCase' }),
      expect.objectContaining({ field: 'fileName' }),
      expect.objectContaining({ field: 'url' }),
    ]));
  });
});
