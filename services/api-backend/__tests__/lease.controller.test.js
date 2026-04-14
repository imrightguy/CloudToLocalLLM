let mockDbResults = [];

function mockCreateChain() {
  const instance = {
    then: (resolve, reject) => {
      const val = mockDbResults.length > 0 ? mockDbResults.shift() : [];
      return Promise.resolve(val).then(resolve, reject);
    },
    catch: () => instance,
  };
  const chainMethods = [
    'insert', 'values', 'returning',
    'select', 'from', 'where', 'orderBy', 'limit', 'offset', 'leftJoin', 'innerJoin', 'set',
  ];
  for (const m of chainMethods) {
    instance[m] = jest.fn().mockReturnValue(instance);
  }
  return instance;
}

jest.mock('../src/database/connection', () => ({
  db: {
    insert: jest.fn(() => mockCreateChain()),
    select: jest.fn(() => mockCreateChain()),
    update: jest.fn(() => mockCreateChain()),
  },
}));

jest.mock('../src/database/schema', () => ({
  leasesTable: {},
  unitsTable: {},
  buildingsTable: {},
  leadsTable: {},
}));

jest.mock('../src/utils/logger', () => ({
  child: jest.fn(() => ({
    error: jest.fn(),
    warn: jest.fn(),
    info: jest.fn(),
    debug: jest.fn(),
  })),
}));

jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ _type: 'eq', col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
}));

const leaseController = require('../src/controllers/lease.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  jest.clearAllMocks();
  mockDbResults = [];
});

describe('deleteLease', () => {
  it('returns 404 when lease not found', async () => {
    mockDbResults = [[]];
    const res = mockRes();
    await leaseController.deleteLease(
      { params: { id: '550e8400-e29b-41d4-a716-446655440000' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('LEASE_NOT_FOUND');
    expect(body.error.message).toContain('introuvable');
  });

  it('returns 400 when lease is active', async () => {
    mockDbResults = [[{ id: 'l1', status: 'active', unitId: 'u1' }]];
    const res = mockRes();
    await leaseController.deleteLease(
      { params: { id: 'l1' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('LEASE_ACTIVE');
    expect(body.error.message).toContain('actif');
  });

  it('soft-deletes a non-active lease', async () => {
    mockDbResults = [[{ id: 'l1', status: 'draft', unitId: 'u1' }]];
    const res = mockRes();
    await leaseController.deleteLease(
      { params: { id: 'l1' } },
      res,
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
    const body = res.json.mock.calls[0][0];
    expect(body.data).toBeNull();
    expect(body.message).toContain('supprimé');
  });

  it('soft-deletes an expired lease', async () => {
    mockDbResults = [[{ id: 'l2', status: 'expired', unitId: 'u1' }]];
    const res = mockRes();
    await leaseController.deleteLease(
      { params: { id: 'l2' } },
      res,
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
  });
});

describe('getLeaseById', () => {
  it('returns 404 when lease not found', async () => {
    mockDbResults = [[]];
    const res = mockRes();
    await leaseController.getLeaseById(
      { params: { id: '550e8400-e29b-41d4-a716-446655440000' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(false);
    expect(body.error.code).toBe('LEASE_NOT_FOUND');
  });

  it('returns lease with rent converted from cents', async () => {
    mockDbResults = [
      [{ id: 'l1', unitId: 'u1', rentCents: 120000, depositCents: 60000, status: 'draft' }],
      [],
      [],
    ];
    const res = mockRes();
    await leaseController.getLeaseById(
      { params: { id: 'l1' } },
      res,
    );
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.data.rent).toBe(1200);
    expect(body.data.deposit).toBe(600);
  });
});

describe('getLeases', () => {
  it('returns paginated results with metadata', async () => {
    mockDbResults = [[{ count: 5 }], []];
    const res = mockRes();
    await leaseController.getLeases({ query: { page: '1', limit: '10' } }, res);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.metadata).toBeDefined();
    expect(body.metadata.total).toBe(5);
    expect(body.metadata.page).toBe(1);
    expect(body.metadata.limit).toBe(10);
  });

  it('accepts valid status filter values', async () => {
    mockDbResults = [[{ count: 1 }], [{ id: 'l1', status: 'active' }]];
    const res = mockRes();
    await leaseController.getLeases({ query: { status: 'active' } }, res);
    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
  });
});

describe('updateLeaseStatus', () => {
  it('returns 404 when lease not found', async () => {
    mockDbResults = [[]];
    const res = mockRes();
    await leaseController.updateLeaseStatus(
      { params: { id: 'nonexistent' }, body: { status: 'active' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 for invalid status transition', async () => {
    mockDbResults = [[{ id: 'l1', status: 'terminated' }]];
    const res = mockRes();
    await leaseController.updateLeaseStatus(
      { params: { id: 'l1' }, body: { status: 'active' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    const body = res.json.mock.calls[0][0];
    expect(body.error.code).toBe('INVALID_STATUS_TRANSITION');
  });
});

describe('signLease', () => {
  it('returns 404 when lease not found', async () => {
    mockDbResults = [[]];
    const res = mockRes();
    await leaseController.signLease(
      { params: { id: 'nonexistent' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 when lease already signed', async () => {
    mockDbResults = [[{ id: 'l1', status: 'active', signedAt: new Date(), startDate: new Date() }]];
    const res = mockRes();
    await leaseController.signLease(
      { params: { id: 'l1' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    const body = res.json.mock.calls[0][0];
    expect(body.error.code).toBe('LEASE_ALREADY_SIGNED');
  });
});
