const validate = require('../src/middleware/validate');
const { communicationSchemas } = require('../src/config/validation-schemas');
const communicationRouter = require('../src/routes/communication.routes');

function mockReqRes(body = {}, query = {}, params = {}) {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  const next = jest.fn();
  return { req: { body, query, params }, res, next };
}

describe('Communication route validation contract', () => {
  it('protects GET / with validation middleware before the controller', () => {
    const listRoute = communicationRouter.stack.find((layer) => layer.route?.path === '/' && layer.route.methods.get);

    expect(listRoute).toBeDefined();
    expect(listRoute.route.stack.map((layer) => layer.name)).toEqual(['authenticateToken', '<anonymous>', '<anonymous>']);
  });

  it('protects GET /activity with validation middleware before the controller', () => {
    const activityRoute = communicationRouter.stack.find((layer) => layer.route?.path === '/activity' && layer.route.methods.get);

    expect(activityRoute).toBeDefined();
    expect(activityRoute.route.stack.map((layer) => layer.name)).toEqual(['authenticateToken', '<anonymous>', '<anonymous>']);
  });

  it('accepts marketplace communication list filters supported by the controller', () => {
    const { req, res, next } = mockReqRes({}, {
      page: '2',
      limit: '25',
      leadId: '550e8400-e29b-41d4-a716-446655440000',
      employeeId: '550e8400-e29b-41d4-a716-446655440001',
      type: 'fb_messenger',
      direction: 'inbound',
      status: 'read',
    });

    validate(communicationSchemas.list)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.query).toMatchObject({
      page: 2,
      limit: 25,
      leadId: '550e8400-e29b-41d4-a716-446655440000',
      employeeId: '550e8400-e29b-41d4-a716-446655440001',
      type: 'fb_messenger',
      direction: 'inbound',
      status: 'read',
    });
  });

  it('rejects invalid marketplace communication list filters early', () => {
    const { req, res, next } = mockReqRes({}, {
      type: 'whatsapp',
      direction: 'sideways',
      page: '0',
    });

    validate(communicationSchemas.list)(req, res, next);

    expect(res.status).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledTimes(1);
    const [error] = next.mock.calls[0];
    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe('ValidationError');
    expect(error.details.query).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: 'type' }),
      expect.objectContaining({ field: 'direction' }),
      expect.objectContaining({ field: 'page' }),
    ]));
  });

  it('accepts activity feed filters for marketplace and visit activity types', () => {
    const { req, res, next } = mockReqRes({}, {
      limit: '40',
      hoursAgo: '24',
      type: 'visit_scheduled,communication_logged',
    });

    validate(communicationSchemas.activity)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.query).toMatchObject({
      limit: 40,
      hoursAgo: 24,
      type: 'visit_scheduled,communication_logged',
    });
  });

  it('rejects invalid activity feed filters early', () => {
    const { req, res, next } = mockReqRes({}, {
      limit: '999',
      hoursAgo: '0',
      type: 'unsupported_type',
    });

    validate(communicationSchemas.activity)(req, res, next);

    expect(res.status).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledTimes(1);
    const [error] = next.mock.calls[0];
    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe('ValidationError');
    expect(error.details.query).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: 'limit' }),
      expect.objectContaining({ field: 'hoursAgo' }),
      expect.objectContaining({ field: 'type' }),
    ]));
  });

  it('accepts Messenger communication log payloads without a leadId', () => {
    const { req, res, next } = mockReqRes({
      employeeId: '550e8400-e29b-41d4-a716-446655440001',
      type: 'fb_messenger',
      direction: 'outbound',
      content: 'Bonjour! Êtes-vous disponible pour une visite?',
      attachments: [{ type: 'image', url: 'https://example.com/image.jpg' }],
      metadata: { pageThreadId: 'thread-123' },
    });

    validate(communicationSchemas.log)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.body).toMatchObject({
      employeeId: '550e8400-e29b-41d4-a716-446655440001',
      type: 'fb_messenger',
      direction: 'outbound',
      content: 'Bonjour! Êtes-vous disponible pour une visite?',
      attachments: [{ type: 'image', url: 'https://example.com/image.jpg' }],
      metadata: { pageThreadId: 'thread-123' },
    });
  });

  it('accepts communication log update payloads with params validation', () => {
    const { req, res, next } = mockReqRes({
      status: 'read',
      metadata: { deliveryProvider: 'meta' },
    }, {}, {
      id: '550e8400-e29b-41d4-a716-446655440099',
    });

    validate(communicationSchemas.updateLog)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.params).toEqual({ id: '550e8400-e29b-41d4-a716-446655440099' });
    expect(req.body).toMatchObject({
      status: 'read',
      metadata: { deliveryProvider: 'meta' },
    });
  });

  it('rejects invalid communication log updates early', () => {
    const { req, res, next } = mockReqRes({
      status: 'queued',
    }, {}, {
      id: 'not-a-uuid',
    });

    validate(communicationSchemas.updateLog)(req, res, next);

    expect(res.status).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledTimes(1);
    const [error] = next.mock.calls[0];
    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe('ValidationError');
    expect(error.details.params).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: 'id' }),
    ]));
    expect(error.details.body).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: 'status' }),
    ]));
  });
});
