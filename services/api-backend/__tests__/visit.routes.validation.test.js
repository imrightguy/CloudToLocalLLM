const validate = require('../src/middleware/validate');
const { visitSchemas } = require('../src/config/validation-schemas');
const visitRouter = require('../src/routes/visit.routes');

function mockReqRes(body = {}, query = {}, params = {}) {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  const next = jest.fn();
  return { req: { body, query, params }, res, next };
}

describe('Visit route validation contract', () => {
  it('protects GET / with validation middleware before the controller', () => {
    const listRoute = visitRouter.stack.find((layer) => layer.route?.path === '/' && layer.route.methods.get);

    expect(listRoute).toBeDefined();
    expect(listRoute.route.stack.map((layer) => layer.name)).toEqual(['authenticateToken', '<anonymous>', '<anonymous>']);
  });

  it('accepts visit list filters supported by the controller', () => {
    const { req, res, next } = mockReqRes({}, {
      status: 'confirmed',
      employeeId: '550e8400-e29b-41d4-a716-446655440001',
      leadId: '550e8400-e29b-41d4-a716-446655440002',
      dateFrom: '2026-05-01',
      dateTo: '2026-05-31',
      sortBy: 'updatedAt',
      sortOrder: 'asc',
      expand: 'unit,building,employee,lead',
      page: '2',
      limit: '25',
    });

    validate(visitSchemas.list)(req, res, next);

    expect(next).toHaveBeenCalledWith();
    expect(req.query).toMatchObject({
      status: 'confirmed',
      employeeId: '550e8400-e29b-41d4-a716-446655440001',
      leadId: '550e8400-e29b-41d4-a716-446655440002',
      sortBy: 'updatedAt',
      sortOrder: 'asc',
      expand: 'unit,building,employee,lead',
      page: 2,
      limit: 25,
    });
  });

  it('rejects invalid visit list filters early', () => {
    const { req, res, next } = mockReqRes({}, { status: 'queued', sortBy: 'buildingId', expand: 'unit,owner' });

    validate(visitSchemas.list)(req, res, next);

    expect(res.status).not.toHaveBeenCalled();
    expect(next).toHaveBeenCalledTimes(1);
    const [error] = next.mock.calls[0];
    expect(error).toBeInstanceOf(Error);
    expect(error.name).toBe('ValidationError');
    expect(error.details.query).toEqual(expect.arrayContaining([
      expect.objectContaining({ field: 'status' }),
      expect.objectContaining({ field: 'sortBy' }),
      expect.objectContaining({ field: 'expand' }),
    ]));
  });
});
