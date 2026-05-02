jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
  gte: jest.fn((col, val) => ({ col, val, _type: 'gte' })),
  lte: jest.fn((col, val) => ({ col, val, _type: 'lte' })),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn((...args) => console.log('LOGGER_ERROR', ...args)),
}));

jest.mock('../../src/services/sms.service', () => ({
  sendOccupantAccessRequest: jest.fn().mockResolvedValue({ success: true }),
  sendVisitConfirmation: jest.fn().mockResolvedValue({ success: true }),
  sendTenantConfirmationRequest: jest.fn().mockResolvedValue({ success: true }),
}));

jest.mock('../../src/controllers/tenant-confirmation.controller', () => ({
  generateConfirmationToken: jest.fn(() => 'token-abc'),
}));

jest.mock('../../src/services/communication-thread.service', () => ({
  refreshCommunicationThread: jest.fn().mockResolvedValue(null),
}));

const mockSelectChain = () => {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  chain.leftJoin = jest.fn().mockReturnValue(chain);
  chain.innerJoin = jest.fn().mockReturnValue(chain);
  return chain;
};

let selectChain;

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => ({
    values: jest.fn().mockReturnValue({
      returning: jest.fn(() => Promise.resolve([{ id: 'visit-1', status: 'scheduled', dateTime: new Date() }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{ id: 'visit-1', status: 'scheduled', updatedAt: new Date() }])),
      }),
    }),
  })),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/database/schema', () => ({
  visitsTable: {},
  unitsTable: { buildingId: 'buildingId', label: 'label', rentCents: 'rentCents', status: 'status', tenantPhone: 'tenantPhone' },
  buildingsTable: { id: 'id', name: 'name', address: 'address', city: 'city' },
  employeesTable: { firstName: 'firstName', lastName: 'lastName', phone: 'phone' },
  leadsTable: { fullName: 'fullName', email: 'email', phone: 'phone' },
  employeeSchedulesTable: {},
  communicationThreadsTable: { id: 'id', leadId: 'leadId' },
}));

const visitController = require('../../src/controllers/visit.controller');
const { db } = require('../../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

const futureDate = new Date(Date.now() + 7 * 86400000);
futureDate.setHours(14, 0, 0, 0);

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
});

// ═══════════════════════════════════════════════════════════════════
// createVisit
// ═══════════════════════════════════════════════════════════════════
describe('createVisit', () => {
  it('returns 400 when required fields missing', async () => {
    const res = mockRes();
    await visitController.createVisit({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 when dateTime is invalid', async () => {
    const res = mockRes();
    await visitController.createVisit({ body: { unitId: 'u', employeeId: 'e', leadId: 'l', dateTime: 'not-a-date' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when unit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.createVisit({ body: { unitId: 'bad', employeeId: 'e', leadId: 'l', dateTime: futureDate.toISOString() } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'UNIT_NOT_FOUND' }),
    }));
  });

  it('returns 409 when no schedule available', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ buildingId: 'bld-1' }]);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.createVisit({ body: { unitId: 'unit-1', employeeId: 'emp-1', leadId: 'lead-1', dateTime: futureDate.toISOString() } }, res);
    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_CONFLICT' }),
    }));
  });

  it('returns 409 when visit duration extends past employee availability', async () => {
    const lateVisit = new Date(futureDate);
    lateVisit.setHours(16, 30, 0, 0);
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ buildingId: 'bld-1' }]);
    selectChain.limit.mockResolvedValueOnce([{ startTime: '09:00', endTime: '17:00', isActive: true }]);
    const res = mockRes();

    await visitController.createVisit({
      body: {
        unitId: 'unit-1',
        employeeId: 'emp-1',
        leadId: 'lead-1',
        dateTime: lateVisit.toISOString(),
        durationMinutes: 90,
      },
    }, res);

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_CONFLICT' }),
    }));
  });

  it('returns 409 on visit time conflict', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ buildingId: 'bld-1' }]);
    selectChain.limit.mockResolvedValueOnce([{ startTime: '09:00', endTime: '17:00', isActive: true }]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'existing-visit', dateTime: futureDate }]);
    const res = mockRes();
    await visitController.createVisit({ body: { unitId: 'unit-1', employeeId: 'emp-1', leadId: 'lead-1', dateTime: futureDate.toISOString() } }, res);
    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VISIT_CONFLICT' }),
    }));
  });

  it('creates visit successfully and sends SMS', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ buildingId: 'bld-1' }]);
    selectChain.limit.mockResolvedValueOnce([{ startTime: '09:00', endTime: '17:00', isActive: true }]);
    selectChain.limit.mockResolvedValueOnce([]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'thread-1' }]);
    selectChain.limit.mockResolvedValueOnce([{ status: 'vacant' }]);
    const res = mockRes();
    await visitController.createVisit({ body: { unitId: 'unit-1', employeeId: 'emp-1', leadId: 'lead-1', dateTime: futureDate.toISOString() } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      confirmationSMS: expect.objectContaining({
        employee: expect.objectContaining({ success: true }),
        tenant: expect.objectContaining({ success: true }),
      }),
    }));
  });

  it('handles FK violation', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ buildingId: 'bld-1' }]);
    selectChain.limit.mockResolvedValueOnce([{ startTime: '09:00', endTime: '17:00', isActive: true }]);
    selectChain.limit.mockResolvedValueOnce([]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'thread-1' }]);
    const fkError = new Error('FK');
    fkError.code = '23503';
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(fkError),
      }),
    });
    const res = mockRes();
    await visitController.createVisit({ body: { unitId: 'unit-1', employeeId: 'emp-1', leadId: 'lead-1', dateTime: futureDate.toISOString() } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'FOREIGN_KEY_VIOLATION' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getVisitById
// ═══════════════════════════════════════════════════════════════════
describe('getVisitById', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.getVisitById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 404 for soft-deleted visits', async () => {
    const visit = {
      id: 'visit-1',
      status: 'cancelled',
      dateTime: new Date(),
      isActive: false,
    };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([visit]);
    const res = mockRes();

    await visitController.getVisitById({ params: { id: 'visit-1' } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
    }));
  });

  it('returns visit data', async () => {
    const visit = { id: 'visit-1', status: 'scheduled', dateTime: new Date() };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([visit]);
    const res = mockRes();
    await visitController.getVisitById({ params: { id: 'visit-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true, data: visit }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateVisit
// ═══════════════════════════════════════════════════════════════════
describe('updateVisit', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.updateVisit({ params: { id: 'nonexistent' }, body: { notes: 'test' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 404 when attempting to update a soft-deleted visit', async () => {
    const existing = {
      id: 'visit-1',
      status: 'cancelled',
      dateTime: new Date(),
      durationMinutes: 30,
      employeeId: 'emp-1',
      unitId: 'unit-1',
      isActive: false,
    };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();

    await visitController.updateVisit({ params: { id: 'visit-1' }, body: { notes: 'Updated' } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(db.update).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
    }));
  });

  it('updates visit with notes only', async () => {
    const existing = { id: 'visit-1', status: 'scheduled', dateTime: new Date(), durationMinutes: 30, employeeId: 'emp-1' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.updateVisit({ params: { id: 'visit-1' }, body: { notes: 'Updated' } }, res);
    expect(db.update).toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('returns 400 for invalid dateTime', async () => {
    const existing = { id: 'visit-1', status: 'scheduled', dateTime: new Date(), durationMinutes: 30, employeeId: 'emp-1' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    const res = mockRes();
    await visitController.updateVisit({ params: { id: 'visit-1' }, body: { dateTime: 'not-a-date' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 409 on schedule conflict when dateTime changes', async () => {
    const existing = { id: 'visit-1', status: 'scheduled', dateTime: new Date(), durationMinutes: 30, employeeId: 'emp-1', unitId: 'unit-1' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    selectChain.limit.mockResolvedValueOnce([{ buildingId: 'bld-1' }]);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    const newDate = new Date(Date.now() + 7 * 86400000);
    newDate.setHours(20, 0, 0, 0);
    await visitController.updateVisit({ params: { id: 'visit-1' }, body: { dateTime: newDate.toISOString() } }, res);
    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_CONFLICT' }),
    }));
  });

  it('returns 409 when extending a visit beyond employee availability', async () => {
    const currentStart = new Date(futureDate);
    currentStart.setHours(16, 30, 0, 0);
    const existing = { id: 'visit-1', status: 'scheduled', dateTime: currentStart, durationMinutes: 30, employeeId: 'emp-1', unitId: 'unit-1' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    selectChain.limit.mockResolvedValueOnce([{ buildingId: 'bld-1' }]);
    selectChain.limit.mockResolvedValueOnce([{ startTime: '09:00', endTime: '17:00', isActive: true }]);
    const res = mockRes();

    await visitController.updateVisit({ params: { id: 'visit-1' }, body: { durationMinutes: 90 } }, res);

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_CONFLICT' }),
    }));
  });

  it('returns 409 when reassigning a visit to a unit whose building schedule does not match', async () => {
    const existing = { id: 'visit-1', status: 'scheduled', dateTime: futureDate, durationMinutes: 30, employeeId: 'emp-1', unitId: 'unit-1' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([existing]);
    selectChain.limit.mockResolvedValueOnce([{ buildingId: 'bld-2' }]);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();

    await visitController.updateVisit({ params: { id: 'visit-1' }, body: { unitId: 'unit-2' } }, res);

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'SCHEDULE_CONFLICT' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// deleteVisit
// ═══════════════════════════════════════════════════════════════════
describe('deleteVisit', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.deleteVisit({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 404 when attempting to delete a soft-deleted visit again', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'visit-1', isActive: false }]);
    const res = mockRes();

    await visitController.deleteVisit({ params: { id: 'visit-1' } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(db.update).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
    }));
  });

  it('soft-deletes visit', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'visit-1', isActive: true }]);
    const res = mockRes();
    await visitController.deleteVisit({ params: { id: 'visit-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true, data: null }));
    expect(db.update).toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateVisitStatus
// ═══════════════════════════════════════════════════════════════════
describe('updateVisitStatus', () => {
  it('returns 400 for invalid status', async () => {
    const res = mockRes();
    await visitController.updateVisitStatus({ params: { id: 'v1' }, body: { status: 'invalid' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when visit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.updateVisitStatus({ params: { id: 'nonexistent' }, body: { status: 'completed' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 404 when attempting to patch the status of a soft-deleted visit', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'visit-1', status: 'cancelled', isActive: false }]);
    const res = mockRes();

    await visitController.updateVisitStatus({ params: { id: 'visit-1' }, body: { status: 'completed' } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(db.update).not.toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      error: expect.objectContaining({ code: 'VISIT_NOT_FOUND' }),
    }));
  });

  it('updates to completed with valid outcome', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'visit-1', status: 'scheduled' }]);
    const res = mockRes();
    await visitController.updateVisitStatus({ params: { id: 'visit-1' }, body: { status: 'completed', outcome: 'interesse' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('accepts in_progress as a valid visit status transition', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'visit-1', status: 'confirmed', isActive: true }]);
    const set = jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{ id: 'visit-1', status: 'in_progress', updatedAt: new Date() }])),
      }),
    });
    db.update.mockReturnValueOnce({ set });
    const res = mockRes();

    await visitController.updateVisitStatus({ params: { id: 'visit-1' }, body: { status: 'in_progress' } }, res);

    expect(set).toHaveBeenCalledWith(expect.objectContaining({
      status: 'in_progress',
      updatedAt: expect.any(Date),
    }));
    expect(res.status).not.toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ status: 'in_progress' }),
    }));
  });

  it('auto-sets confirmation flags on confirmed', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'visit-1', status: 'scheduled' }]);
    const res = mockRes();
    await visitController.updateVisitStatus({ params: { id: 'visit-1' }, body: { status: 'confirmed' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
    expect(db.update).toHaveBeenCalled();
  });

  it('rejects invalid outcome', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'visit-1', status: 'scheduled' }]);
    const res = mockRes();
    await visitController.updateVisitStatus({ params: { id: 'visit-1' }, body: { status: 'completed', outcome: 'banana' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('persists status notes when completing a visit', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'visit-1', status: 'scheduled' }]);
    const set = jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{ id: 'visit-1', status: 'completed', outcome: 'no_show', notes: 'Le prospect ne s’est jamais présenté.' }])),
      }),
    });
    db.update.mockReturnValueOnce({ set });
    const res = mockRes();

    await visitController.updateVisitStatus({
      params: { id: 'visit-1' },
      body: {
        status: 'completed',
        outcome: 'no_show',
        notes: 'Le prospect ne s’est jamais présenté.',
      },
    }, res);

    expect(set).toHaveBeenCalledWith(expect.objectContaining({
      status: 'completed',
      outcome: 'no_show',
      notes: 'Le prospect ne s’est jamais présenté.',
      updatedAt: expect.any(Date),
    }));
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        notes: 'Le prospect ne s’est jamais présenté.',
      }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getVisits
// ═══════════════════════════════════════════════════════════════════
describe('getVisits', () => {
  it('returns paginated visits', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'visit-1', dateTime: new Date() }]);
    const res = mockRes();
    await visitController.getVisits({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      metadata: expect.objectContaining({ total: 1, page: 1 }),
    }));
  });

  it('filters by status and date range', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await visitController.getVisits({ query: { status: 'scheduled', dateFrom: '2026-01-01', dateTo: '2026-12-31' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ data: [] }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await visitController.getVisits({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});
