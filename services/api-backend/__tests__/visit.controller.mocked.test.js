// ─── Visit Controller Mocked DB Tests ───
// Tests controller logic beyond validation by mocking the database layer.

jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
  gte: jest.fn((col, val) => ({ col, val })),
  lte: jest.fn((col, val) => ({ col, val })),
}));

const mockSelectChain = () => {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  chain.leftJoin = jest.fn().mockReturnValue(chain);
  return chain;
};

let selectChain;
let mockUpdateResults;

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => ({
    values: jest.fn().mockReturnValue({
      returning: jest.fn(() => Promise.resolve([{ id: 'visit-new', status: 'scheduled', dateTime: new Date() }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve(mockUpdateResults)),
      }),
    }),
  })),
};

jest.mock('../src/database/connection', () => ({ db: mockDb }));

jest.mock('../src/database/schema', () => ({
  visitsTable: {},
  unitsTable: { buildingId: 'buildingId', label: 'label', rentCents: 'rentCents', status: 'status' },
  buildingsTable: { id: 'id', name: 'name', address: 'address', city: 'city' },
  employeesTable: { firstName: 'firstName', lastName: 'lastName', phone: 'phone' },
  leadsTable: { fullName: 'fullName', email: 'email', phone: 'phone' },
  employeeSchedulesTable: {},
}));

jest.mock('../src/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
}));

jest.mock('../src/services/sms.service', () => ({
  sendOccupantAccessRequest: jest.fn().mockResolvedValue({ success: true }),
  sendVisitConfirmation: jest.fn().mockResolvedValue({ success: true }),
  sendTenantConfirmationRequest: jest.fn().mockResolvedValue({ success: true }),
}));

jest.mock('../src/controllers/tenant-confirmation.controller', () => ({
  generateConfirmationToken: jest.fn(() => 'token-abc'),
}));

const visitController = require('../src/controllers/visit.controller');
const { db } = require('../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
  mockUpdateResults = [{ id: 'visit-1', status: 'scheduled', updatedAt: new Date() }];
});

// ═══════════════════════════════════════════════════════════════════════════════
// getVisitById
// ═══════════════════════════════════════════════════════════════════════════════
describe('getVisitById (mocked)', () => {
  it('returns 404 when visit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.getVisitById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
      }),
    );
  });

  it('returns 404 for soft-deleted visits', async () => {
    const visit = { id: 'visit-1', status: 'cancelled', dateTime: new Date(), isActive: false };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([visit]);
    const res = mockRes();

    await visitController.getVisitById({ params: { id: 'visit-1' } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
      }),
    );
  });

  it('returns visit data when found', async () => {
    const visit = { id: 'visit-1', status: 'scheduled', dateTime: new Date() };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([visit]);
    const res = mockRes();
    await visitController.getVisitById({ params: { id: 'visit-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: visit,
      }),
    );
  });

  it('returns 500 on database error', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await visitController.getVisitById({ params: { id: 'visit-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_FETCH_FAILED' }),
      }),
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// deleteVisit (soft delete)
// ═══════════════════════════════════════════════════════════════════════════════
describe('deleteVisit (mocked)', () => {
  it('returns 404 when visit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.deleteVisit({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
      }),
    );
  });

  it('returns 404 when deleting a soft-deleted visit again', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'visit-1', status: 'cancelled', isActive: false }]);
    const res = mockRes();

    await visitController.deleteVisit({ params: { id: 'visit-1' } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(db.update).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
      }),
    );
  });

  it('soft-deletes existing visit', async () => {
    const existing = { id: 'visit-1', status: 'scheduled', isActive: true };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.deleteVisit({ params: { id: 'visit-1' } }, res);
    expect(db.update).toHaveBeenCalledTimes(1);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: null,
      }),
    );
  });

  it('returns 500 on database error', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await visitController.deleteVisit({ params: { id: 'visit-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_DELETE_FAILED' }),
      }),
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// updateVisitStatus
// ═══════════════════════════════════════════════════════════════════════════════
describe('updateVisitStatus (mocked)', () => {
  it('returns 404 when visit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.updateVisitStatus(
      { params: { id: 'nonexistent' }, body: { status: 'completed' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
      }),
    );
  });

  it('returns 404 when patching the status of a soft-deleted visit', async () => {
    const existing = { id: 'visit-1', status: 'cancelled', isActive: false };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();

    await visitController.updateVisitStatus(
      { params: { id: 'visit-1' }, body: { status: 'completed' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
    expect(db.update).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
      }),
    );
  });

  it('updates status and returns updated visit', async () => {
    const existing = { id: 'visit-1', status: 'scheduled' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.updateVisitStatus(
      { params: { id: 'visit-1' }, body: { status: 'completed' } },
      res,
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        message: 'Visit status updated successfully',
      }),
    );
  });

  it('auto-sets confirmation flags when status is confirmed', async () => {
    const existing = { id: 'visit-1', status: 'scheduled' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.updateVisitStatus(
      { params: { id: 'visit-1' }, body: { status: 'confirmed' } },
      res,
    );
    expect(db.update).toHaveBeenCalledTimes(1);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
  });

  it('accepts valid outcome values', async () => {
    const existing = { id: 'visit-1', status: 'scheduled' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.updateVisitStatus(
      { params: { id: 'visit-1' }, body: { status: 'completed', outcome: 'interesse' } },
      res,
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
  });

  it('rejects invalid outcome value', async () => {
    const existing = { id: 'visit-1', status: 'scheduled' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.updateVisitStatus(
      { params: { id: 'visit-1' }, body: { status: 'completed', outcome: 'banana' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }),
    );
  });

  it('accepts null outcome value', async () => {
    const existing = { id: 'visit-1', status: 'scheduled' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.updateVisitStatus(
      { params: { id: 'visit-1' }, body: { status: 'cancelled', outcome: null, reasonCode: 'tenant_request' } },
      res,
    );
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
  });

  it('returns 500 on database error', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await visitController.updateVisitStatus(
      { params: { id: 'visit-1' }, body: { status: 'completed' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_STATUS_UPDATE_FAILED' }),
      }),
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// updateVisit
// ═══════════════════════════════════════════════════════════════════════════════
describe('updateVisit (mocked)', () => {
  it('returns 404 when visit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.updateVisit(
      { params: { id: 'nonexistent' }, body: { notes: 'test' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
      }),
    );
  });

  it('updates visit with notes only', async () => {
    const existing = { id: 'visit-1', status: 'scheduled', dateTime: new Date(), durationMinutes: 30, employeeId: 'emp-1' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.updateVisit(
      { params: { id: 'visit-1' }, body: { notes: 'Updated notes' } },
      res,
    );
    expect(db.update).toHaveBeenCalledTimes(1);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({ success: true }),
    );
  });

  it('returns 400 for invalid dateTime on update', async () => {
    const existing = { id: 'visit-1', status: 'scheduled', dateTime: new Date(), durationMinutes: 30, employeeId: 'emp-1' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.updateVisit(
      { params: { id: 'visit-1' }, body: { dateTime: 'not-a-date' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }),
    );
  });

  it('handles foreign key violation on update', async () => {
    const existing = { id: 'visit-1', status: 'scheduled', dateTime: new Date(), durationMinutes: 30, employeeId: 'emp-1' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);

    const fkError = new Error('FK violation');
    fkError.code = '23503';
    const errorChain = {
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockImplementation(() => { throw fkError; }),
      }),
    };
    db.update.mockReturnValueOnce(errorChain);

    const res = mockRes();
    await visitController.updateVisit(
      { params: { id: 'visit-1' }, body: { employeeId: 'nonexistent-emp' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'FOREIGN_KEY_VIOLATION' }),
      }),
    );
  });
});

// ═══════════════════════════════════════════════════════════════════════════════
// getVisits (pagination and filtering)
// ═══════════════════════════════════════════════════════════════════════════════
describe('getVisits (mocked)', () => {
  it('returns 500 on database error', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await visitController.getVisits({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VISIT_FETCH_FAILED' }),
      }),
    );
  });
});
