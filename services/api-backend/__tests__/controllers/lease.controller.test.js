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
  error: jest.fn(),
}));

jest.mock('../../src/models/lease', () => ({
  leaseSchema: {
    validate: jest.fn((body) => {
      if (!body.unitId || !body.tenantFirstName || !body.tenantLastName || !body.rent || !body.startDate || !body.endDate) {
        return { error: { details: [{ message: 'Validation failed' }] } };
      }
      return { error: null, value: body };
    }),
  },
  updateLeaseSchema: {
    validate: jest.fn((body) => ({ error: null, value: body })),
  },
  leaseStatusSchema: {
    validate: jest.fn((body) => {
      const valid = ['draft', 'active', 'expired', 'terminated', 'renewed'];
      if (!valid.includes(body.status)) return { error: { details: [{ message: 'Invalid status' }] } };
      return { error: null, value: body };
    }),
  },
  VALID_TRANSITIONS: {
    draft: ['active', 'terminated'],
    active: ['expired', 'terminated', 'renewed'],
    expired: ['renewed'],
    terminated: [],
    renewed: [],
  },
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
      returning: jest.fn(() => Promise.resolve([{
        id: 'lease-1', unitId: 'unit-1', rentCents: 150000, depositCents: 0,
        startDate: new Date('2026-06-01'), endDate: new Date('2027-05-31'),
        status: 'draft', signedAt: null,
      }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{
          id: 'lease-1', rentCents: 150000, depositCents: 0,
          startDate: new Date('2026-06-01'), endDate: new Date('2027-05-31'),
          status: 'active',
        }])),
      }),
    }),
  })),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/database/schema', () => ({
  leasesTable: { id: 'id', unitId: 'unitId', leadId: 'leadId', tenantFirstName: 'tenantFirstName', tenantLastName: 'tenantLastName', tenantEmail: 'tenantEmail', tenantPhone: 'tenantPhone', rentCents: 'rentCents', depositCents: 'depositCents', startDate: 'startDate', endDate: 'endDate', status: 'status', terms: 'terms', signedAt: 'signedAt', isActive: 'isActive', createdAt: 'createdAt', updatedAt: 'updatedAt', createdBy: 'createdBy' },
  unitsTable: { id: 'id', buildingId: 'buildingId', label: 'label', rentCents: 'rentCents', status: 'status' },
  buildingsTable: { id: 'id', name: 'name' },
  leadsTable: { id: 'id', fullName: 'fullName' },
}));

const leaseController = require('../../src/controllers/lease.controller');
const { db } = require('../../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

const futureStart = new Date(Date.now() + 30 * 86400000);
const futureEnd = new Date(Date.now() + 395 * 86400000);
const pastEnd = new Date(Date.now() - 30 * 86400000);

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
});

// ═══════════════════════════════════════════════════════════════════
// createLease
// ═══════════════════════════════════════════════════════════════════
describe('createLease', () => {
  it('returns 400 on validation error', async () => {
    const res = mockRes();
    await leaseController.createLease({ body: {}, user: { id: 'user-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 404 when unit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.createLease({
      body: { unitId: 'bad', tenantFirstName: 'J', tenantLastName: 'D', rent: 1000, startDate: futureStart, endDate: futureEnd },
      user: { id: 'user-1' },
    }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'UNIT_NOT_FOUND' }),
    }));
  });

  it('returns 404 when lead not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1' }]);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.createLease({
      body: { unitId: 'unit-1', leadId: 'bad-lead', tenantFirstName: 'J', tenantLastName: 'D', rent: 1000, startDate: futureStart, endDate: futureEnd },
      user: { id: 'user-1' },
    }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEAD_NOT_FOUND' }),
    }));
  });

  it('creates lease with auto-draft status', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1' }]);
    const res = mockRes();
    await leaseController.createLease({
      body: { unitId: 'unit-1', tenantFirstName: 'Jean', tenantLastName: 'Doe', rent: 1500, startDate: futureStart, endDate: futureEnd },
      user: { id: 'user-1' },
    }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ rent: 1500, deposit: 0 }),
    }));
  });

  it('handles FK violation', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1' }]);
    const fkError = new Error('FK');
    fkError.code = '23503';
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(fkError),
      }),
    });
    const res = mockRes();
    await leaseController.createLease({
      body: { unitId: 'unit-1', tenantFirstName: 'J', tenantLastName: 'D', rent: 1000, startDate: futureStart, endDate: futureEnd },
      user: { id: 'user-1' },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'FOREIGN_KEY_VIOLATION' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getLeases
// ═══════════════════════════════════════════════════════════════════
describe('getLeases', () => {
  it('returns paginated leases with rent conversion', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'lease-1', rentCents: 150000, depositCents: 150000 }]);
    const res = mockRes();
    await leaseController.getLeases({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ rent: 1500, deposit: 1500 })]),
      metadata: expect.objectContaining({ total: 1 }),
    }));
  });

  it('filters by status and unitId', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.getLeases({ query: { status: 'active', unitId: 'unit-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ data: [] }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await leaseController.getLeases({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ═══════════════════════════════════════════════════════════════════
// getLeaseById
// ═══════════════════════════════════════════════════════════════════
describe('getLeaseById', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.getLeaseById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEASE_NOT_FOUND' }),
    }));
  });

  it('returns lease with unit and building data', async () => {
    selectChain.from.mockReturnValue(selectChain);
    const lease = { id: 'lease-1', unitId: 'unit-1', rentCents: 150000, depositCents: 0, startDate: futureStart, endDate: futureEnd };
    selectChain.limit.mockResolvedValueOnce([lease]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1', buildingId: 'bld-1', rentCents: 150000 }]);
    selectChain.limit.mockResolvedValueOnce([{ id: 'bld-1', name: 'Test' }]);
    const res = mockRes();
    await leaseController.getLeaseById({ params: { id: 'lease-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        rent: 1500,
        unit: expect.objectContaining({ id: 'unit-1', rent: 1500 }),
        building: expect.objectContaining({ id: 'bld-1' }),
      }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateLease
// ═══════════════════════════════════════════════════════════════════
describe('updateLease', () => {
  it('returns 400 on validation error', async () => {
    const { updateLeaseSchema } = require('../../src/models/lease');
    updateLeaseSchema.validate.mockReturnValueOnce({ error: { details: [{ message: 'bad' }] } });
    const res = mockRes();
    await leaseController.updateLease({ params: { id: 'lease-1' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when lease not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.updateLease({ params: { id: 'nonexistent' }, body: { tenantFirstName: 'New' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 when lease is already signed', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', signedAt: new Date(), startDate: futureStart, endDate: futureEnd }]);
    const res = mockRes();
    await leaseController.updateLease({ params: { id: 'lease-1' }, body: { tenantFirstName: 'New' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEASE_ALREADY_SIGNED' }),
    }));
  });

  it('returns 400 when endDate is before startDate', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', signedAt: null, startDate: futureStart, endDate: futureEnd }]);
    const res = mockRes();
    await leaseController.updateLease({ params: { id: 'lease-1' }, body: { endDate: '2020-01-01' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('updates unsigned lease successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', signedAt: null, startDate: futureStart, endDate: futureEnd }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'lease-1', rentCents: 200000, depositCents: 0, status: 'draft' }]),
        }),
      }),
    });
    const res = mockRes();
    await leaseController.updateLease({ params: { id: 'lease-1' }, body: { rent: 2000 } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ rent: 2000 }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateLeaseStatus
// ═══════════════════════════════════════════════════════════════════
describe('updateLeaseStatus', () => {
  it('returns 400 on validation error', async () => {
    const res = mockRes();
    await leaseController.updateLeaseStatus({ params: { id: 'lease-1' }, body: { status: 'invalid' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when lease not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.updateLeaseStatus({ params: { id: 'nonexistent' }, body: { status: 'active' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 for invalid transition', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', status: 'terminated' }]);
    const res = mockRes();
    await leaseController.updateLeaseStatus({ params: { id: 'lease-1' }, body: { status: 'active' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'INVALID_STATUS_TRANSITION' }),
    }));
  });

  it('allows valid transition draft -> active', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', status: 'draft' }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'lease-1', status: 'active', rentCents: 150000, depositCents: 0 }]),
        }),
      }),
    });
    const res = mockRes();
    await leaseController.updateLeaseStatus({ params: { id: 'lease-1' }, body: { status: 'active' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ status: 'active' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// signLease
// ═══════════════════════════════════════════════════════════════════
describe('signLease', () => {
  it('returns 404 when lease not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.signLease({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 when already signed', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', signedAt: new Date(), startDate: futureStart, endDate: futureEnd }]);
    const res = mockRes();
    await leaseController.signLease({ params: { id: 'lease-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEASE_ALREADY_SIGNED' }),
    }));
  });

  it('signs lease and sets auto-status', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', signedAt: null, startDate: futureStart, endDate: futureEnd }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'lease-1', signedAt: new Date(), status: 'draft', rentCents: 150000, depositCents: 0 }]),
        }),
      }),
    });
    const res = mockRes();
    await leaseController.signLease({ params: { id: 'lease-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ status: 'draft' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// deleteLease
// ═══════════════════════════════════════════════════════════════════
describe('deleteLease', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.deleteLease({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 when lease is active', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', status: 'active' }]);
    const res = mockRes();
    await leaseController.deleteLease({ params: { id: 'lease-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEASE_ACTIVE' }),
    }));
  });

  it('soft-deletes non-active lease', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lease-1', status: 'draft' }]);
    const res = mockRes();
    await leaseController.deleteLease({ params: { id: 'lease-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: expect.stringContaining('supprimé'),
    }));
    expect(db.update).toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════════
// getLeasesByBuilding
// ═══════════════════════════════════════════════════════════════════
describe('getLeasesByBuilding', () => {
  it('returns 404 when building not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.getLeasesByBuilding({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'BUILDING_NOT_FOUND' }),
    }));
  });

  it('returns leases for a building', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'bld-1' }]);
    selectChain.where.mockReturnValueOnce(selectChain);
    selectChain.where.mockResolvedValueOnce([{ leases: { id: 'lease-1', rentCents: 150000, depositCents: 0 } }]);
    const res = mockRes();
    await leaseController.getLeasesByBuilding({ params: { id: 'bld-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ rent: 1500 })]),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getLeasesByUnit
// ═══════════════════════════════════════════════════════════════════
describe('getLeasesByUnit', () => {
  it('returns 404 when unit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leaseController.getLeasesByUnit({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'UNIT_NOT_FOUND' }),
    }));
  });

  it('returns leases for a unit', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1' }]);
    selectChain.orderBy.mockResolvedValueOnce([{ id: 'lease-1', rentCents: 150000, depositCents: 0 }]);
    const res = mockRes();
    await leaseController.getLeasesByUnit({ params: { id: 'unit-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ rent: 1500 })]),
    }));
  });
});
