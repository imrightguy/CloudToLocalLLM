jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
  ilike: jest.fn((col, val) => ({ col, val, _type: 'ilike' })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

jest.mock('../../src/models/building', () => ({
  unitSchema: {
    validate: jest.fn((body) => {
      if (!body.buildingId) {return { error: { details: [{ message: 'buildingId is required' }] } };}
      return { error: null, value: body };
    }),
  },
  updateUnitSchema: {
    validate: jest.fn((body) => ({ error: null, value: body })),
  },
}));

jest.mock('../../src/config/validation-schemas', () => ({
  buildingSchemas: {
    create: {
      body: {
        validate: jest.fn((body) => {
          if (!body.name || !body.address || !body.city || !body.totalUnits) {
            return { error: { details: [{ message: 'name, address, city, and totalUnits are required' }] } };
          }
          return { error: null, value: body };
        }),
      },
    },
    update: {
      body: {
        validate: jest.fn((body) => ({ error: null, value: body })),
      },
    },
    createUnit: {
      body: {
        validate: jest.fn((body) => {
          if (!body.buildingId || !body.unitNumber) {
            return { error: { details: [{ message: 'buildingId and unitNumber are required' }] } };
          }
          return { error: null, value: body };
        }),
      },
    },
    updateUnit: {
      body: {
        validate: jest.fn((body) => ({ error: null, value: body })),
      },
    },
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
  return chain;
};

let selectChain;

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => ({
    values: jest.fn().mockReturnValue({
      returning: jest.fn(() => Promise.resolve([{ id: 'bld-1', name: 'Test Building' }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{ id: 'bld-1', name: 'Updated' }])),
      }),
    }),
  })),
  delete: jest.fn(() => ({
    where: jest.fn().mockResolvedValue(undefined),
  })),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/database/schema', () => ({
  buildingsTable: { id: 'id', name: 'name', address: 'address', city: 'city', province: 'province', postalCode: 'postalCode', totalUnits: 'totalUnits', occupiedUnits: 'occupiedUnits', isActive: 'isActive', createdAt: 'createdAt', updatedAt: 'updatedAt' },
  unitsTable: { id: 'id', buildingId: 'buildingId', label: 'label', rentCents: 'rentCents', status: 'status', bedrooms: 'bedrooms', bathrooms: 'bathrooms', squareFeet: 'squareFeet', description: 'description', amenities: 'amenities', tenantName: 'tenantName', tenantPhone: 'tenantPhone', tenantLeaseEnd: 'tenantLeaseEnd', isActive: 'isActive', createdAt: 'createdAt', updatedAt: 'updatedAt' },
}));

const buildingController = require('../../src/controllers/building.controller');
const { db } = require('../../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
});

// ═══════════════════════════════════════════════════════════════════
// createBuilding
// ═══════════════════════════════════════════════════════════════════
describe('createBuilding', () => {
  it('returns 400 on validation error', async () => {
    const res = mockRes();
    await buildingController.createBuilding({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('creates a building successfully', async () => {
    const res = mockRes();
    await buildingController.createBuilding({ body: { name: 'Test', address: '123 St', city: 'Montréal', totalUnits: 1 } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'bld-1' }),
    }));
  });

  it('returns 500 on DB error', async () => {
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(new Error('DB down')),
      }),
    });
    const res = mockRes();
    await buildingController.createBuilding({ body: { name: 'Test', address: '123 St', city: 'Montréal', totalUnits: 1 } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'BUILDING_CREATION_FAILED' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getBuildings
// ═══════════════════════════════════════════════════════════════════
describe('getBuildings', () => {
  it('returns paginated buildings with metadata', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 2 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'bld-1' }, { id: 'bld-2' }]);
    const res = mockRes();
    await buildingController.getBuildings({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ id: 'bld-1' })]),
      metadata: expect.objectContaining({
        total: 2,
        page: 1,
        limit: 20,
        totalPages: 1,
        hasMore: false,
      }),
    }));
  });

  it('applies search filter', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.getBuildings({ query: { search: 'tower' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: [],
      metadata: expect.objectContaining({ total: 0 }),
    }));
  });

  it('applies custom page and limit', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 100 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.getBuildings({ query: { page: '5', limit: '10' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      metadata: expect.objectContaining({ page: 5, limit: 10 }),
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await buildingController.getBuildings({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ═══════════════════════════════════════════════════════════════════
// getBuildingById
// ═══════════════════════════════════════════════════════════════════
describe('getBuildingById', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.getBuildingById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'BUILDING_NOT_FOUND' }),
    }));
  });

  it('returns building data', async () => {
    const building = { id: 'bld-1', name: 'Test', address: '123 St' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([building]);
    const res = mockRes();
    await buildingController.getBuildingById({ params: { id: 'bld-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: building,
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await buildingController.getBuildingById({ params: { id: 'bld-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateBuilding
// ═══════════════════════════════════════════════════════════════════
describe('updateBuilding', () => {
  it('returns 400 on validation error', async () => {
    const { buildingSchemas } = require('../../src/config/validation-schemas');
    buildingSchemas.update.body.validate.mockReturnValueOnce({ error: { details: [{ message: 'invalid' }] } });
    const res = mockRes();
    await buildingController.updateBuilding({ params: { id: 'bld-1' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when building not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.updateBuilding({ params: { id: 'nonexistent' }, body: { name: 'New' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'BUILDING_NOT_FOUND' }),
    }));
  });

  it('updates building successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'bld-1' }]);
    const res = mockRes();
    await buildingController.updateBuilding({ params: { id: 'bld-1' }, body: { name: 'Updated' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ name: 'Updated' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// deleteBuilding
// ═══════════════════════════════════════════════════════════════════
describe('deleteBuilding', () => {
  it('returns 404 when building not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.deleteBuilding({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('returns 400 when building has active units', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockReturnValueOnce(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'bld-1' }]);
    selectChain.where.mockResolvedValueOnce([{ count: 3 }]);
    const res = mockRes();
    await buildingController.deleteBuilding({ params: { id: 'bld-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'BUILDING_HAS_UNITS' }),
    }));
  });

  it('soft-deletes building with no active units', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockReturnValueOnce(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'bld-1' }]);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    const res = mockRes();
    await buildingController.deleteBuilding({ params: { id: 'bld-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Building deleted successfully',
    }));
    expect(db.update).toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════════
// createUnit
// ═══════════════════════════════════════════════════════════════════
describe('createUnit', () => {
  it('returns 400 on validation error', async () => {
    const res = mockRes();
    await buildingController.createUnit({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when building not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.createUnit({ body: { buildingId: 'bld-1', unitNumber: 'A1' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'BUILDING_NOT_FOUND' }),
    }));
  });

  it('creates unit with rent conversion', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'bld-1' }]);
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{ id: 'unit-1', rentCents: 150000, status: 'vacant', tenantLeaseEnd: null }]),
      }),
    });
    const res = mockRes();
    await buildingController.createUnit({ body: { buildingId: 'bld-1', unitNumber: 'A1', rentAmount: 1500 } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        rent: 1500,
        tenantIsActive: false,
      }),
    }));
  });

  it('handles FK violation (23503)', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'bld-1' }]);
    const fkError = new Error('FK violation');
    fkError.code = '23503';
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(fkError),
      }),
    });
    const res = mockRes();
    await buildingController.createUnit({ body: { buildingId: 'bld-1', unitNumber: 'A1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'FOREIGN_KEY_VIOLATION' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getUnits
// ═══════════════════════════════════════════════════════════════════
describe('getUnits', () => {
  it('returns paginated units with rent conversion', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'unit-1', rentCents: 100000, status: 'occupied', tenantLeaseEnd: new Date(Date.now() + 86400000).toISOString() }]);
    const res = mockRes();
    await buildingController.getUnits({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ rent: 1000, tenantIsActive: true })]),
      metadata: expect.objectContaining({ total: 1 }),
    }));
  });

  it('filters by buildingId and status', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.getUnits({ query: { buildingId: 'bld-1', status: 'vacant' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: [],
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await buildingController.getUnits({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ═══════════════════════════════════════════════════════════════════
// getUnitById
// ═══════════════════════════════════════════════════════════════════
describe('getUnitById', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.getUnitById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'UNIT_NOT_FOUND' }),
    }));
  });

  it('returns unit with rent conversion', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1', rentCents: 200000, status: 'vacant', tenantLeaseEnd: null }]);
    const res = mockRes();
    await buildingController.getUnitById({ params: { id: 'unit-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ rent: 2000, tenantIsActive: false }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateUnit
// ═══════════════════════════════════════════════════════════════════
describe('updateUnit', () => {
  it('returns 400 on validation error', async () => {
    const { buildingSchemas } = require('../../src/config/validation-schemas');
    buildingSchemas.updateUnit.body.validate.mockReturnValueOnce({ error: { details: [{ message: 'invalid' }] } });
    const res = mockRes();
    await buildingController.updateUnit({ params: { id: 'unit-1' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when unit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.updateUnit({ params: { id: 'nonexistent' }, body: { label: 'B1' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('updates unit with rent conversion', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1' }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'unit-1', rentCents: 180000, status: 'vacant', tenantLeaseEnd: null }]),
        }),
      }),
    });
    const res = mockRes();
    await buildingController.updateUnit({ params: { id: 'unit-1' }, body: { rent: 1800 } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ rent: 1800 }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// deleteUnit
// ═══════════════════════════════════════════════════════════════════
describe('deleteUnit', () => {
  it('returns 404 when unit not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await buildingController.deleteUnit({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'UNIT_NOT_FOUND' }),
    }));
  });

  it('soft-deletes unit', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'unit-1' }]);
    const res = mockRes();
    await buildingController.deleteUnit({ params: { id: 'unit-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Unit deleted successfully',
    }));
    expect(db.update).toHaveBeenCalled();
  });
});
