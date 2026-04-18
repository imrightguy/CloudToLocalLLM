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

jest.mock('../../src/constants/lead-stages', () => ({
  VALID_LEAD_STAGES: ['nouveau', 'contacte', 'qualifie', 'bailSigne', 'inactif'],
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
      returning: jest.fn(() => Promise.resolve([{ id: 'lead-1', fullName: 'Test Lead', stage: 'nouveau' }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{ id: 'lead-1', fullName: 'Updated Lead' }])),
      }),
    }),
  })),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/database/schema', () => ({
  leadsTable: {
    id: 'id', fullName: 'fullName', email: 'email', phone: 'phone',
    budgetCents: 'budgetCents', desiredUnit: 'desiredUnit', source: 'source',
    stage: 'stage', notes: 'notes', tags: 'tags', language: 'language',
    assignedEmployeeId: 'assignedEmployeeId', buildingId: 'buildingId',
    unitId: 'unitId', isActive: 'isActive', createdAt: 'createdAt', updatedAt: 'updatedAt',
  },
}));

const leadController = require('../../src/controllers/lead.controller');
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
// createLead
// ═══════════════════════════════════════════════════════════════════
describe('createLead', () => {
  it('returns 400 when fullName is missing', async () => {
    const res = mockRes();
    await leadController.createLead({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 when fullName is whitespace only', async () => {
    const res = mockRes();
    await leadController.createLead({ body: { fullName: '   ' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('creates a lead with required fields and defaults', async () => {
    const res = mockRes();
    await leadController.createLead({ body: { fullName: 'Jean Dupont' } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'lead-1', stage: 'nouveau' }),
    }));
  });

  it('creates a lead with all fields provided', async () => {
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{
          id: 'lead-2', fullName: 'Marie Tremblay', email: 'marie@test.com',
          phone: '514-555-0100', stage: 'contacte', language: 'en',
        }]),
      }),
    });
    const res = mockRes();
    await leadController.createLead({
      body: {
        fullName: 'Marie Tremblay', email: 'marie@test.com', phone: '514-555-0100',
        source: 'facebook', stage: 'contacte', language: 'en', notes: 'Interested',
      },
    }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({ fullName: 'Marie Tremblay', email: 'marie@test.com' }),
    }));
  });

  it('returns 400 on FK violation (23503)', async () => {
    const fkError = new Error('FK violation');
    fkError.code = '23503';
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(fkError),
      }),
    });
    const res = mockRes();
    await leadController.createLead({ body: { fullName: 'Test', buildingId: 'bad-id' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'FOREIGN_KEY_VIOLATION' }),
    }));
  });

  it('returns 500 on DB error', async () => {
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(new Error('DB down')),
      }),
    });
    const res = mockRes();
    await leadController.createLead({ body: { fullName: 'Test' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEAD_CREATION_FAILED' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getLeads
// ═══════════════════════════════════════════════════════════════════
describe('getLeads', () => {
  it('returns paginated leads with metadata', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 2 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'lead-1' }, { id: 'lead-2' }]);
    const res = mockRes();
    await leadController.getLeads({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.arrayContaining([expect.objectContaining({ id: 'lead-1' })]),
      metadata: expect.objectContaining({
        total: 2,
        page: 1,
        limit: 20,
        totalPages: 1,
        hasMore: false,
      }),
    }));
  });

  it('applies stage filter', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'lead-1', stage: 'contacte' }]);
    const res = mockRes();
    await leadController.getLeads({ query: { stage: 'contacte' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      data: [{ id: 'lead-1', stage: 'contacte' }],
      metadata: expect.objectContaining({ total: 1 }),
    }));
  });

  it('applies buildingId filter', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.getLeads({ query: { buildingId: 'bld-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ data: [] }));
  });

  it('applies search filter', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'lead-1', fullName: 'Jean' }]);
    const res = mockRes();
    await leadController.getLeads({ query: { search: 'Jean' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      metadata: expect.objectContaining({ total: 1 }),
    }));
  });

  it('applies custom page and limit', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 50 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.getLeads({ query: { page: '3', limit: '10' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      metadata: expect.objectContaining({ page: 3, limit: 10 }),
    }));
  });

  it('clamps limit to max 100', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.getLeads({ query: { limit: '999' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      metadata: expect.objectContaining({ limit: 100 }),
    }));
  });

  it('applies ascending sort', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.getLeads({ query: { sortOrder: 'asc' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await leadController.getLeads({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEAD_FETCH_FAILED' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getLeadById
// ═══════════════════════════════════════════════════════════════════
describe('getLeadById', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.getLeadById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEAD_NOT_FOUND' }),
    }));
  });

  it('returns lead data', async () => {
    const lead = { id: 'lead-1', fullName: 'Test', stage: 'nouveau' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([lead]);
    const res = mockRes();
    await leadController.getLeadById({ params: { id: 'lead-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: lead,
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await leadController.getLeadById({ params: { id: 'lead-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateLead
// ═══════════════════════════════════════════════════════════════════
describe('updateLead', () => {
  it('returns 404 when lead not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.updateLead({ params: { id: 'nonexistent' }, body: { fullName: 'New' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEAD_NOT_FOUND' }),
    }));
  });

  it('updates lead successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1' }]);
    const res = mockRes();
    await leadController.updateLead({ params: { id: 'lead-1' }, body: { fullName: 'Updated Name' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'lead-1', fullName: 'Updated Lead' }),
    }));
  });

  it('rejects invalid stage', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1' }]);
    const res = mockRes();
    await leadController.updateLead({ params: { id: 'lead-1' }, body: { stage: 'invalid_stage' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 on FK violation (23503)', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1' }]);
    const fkError = new Error('FK violation');
    fkError.code = '23503';
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockRejectedValue(fkError),
        }),
      }),
    });
    const res = mockRes();
    await leadController.updateLead({ params: { id: 'lead-1' }, body: { buildingId: 'bad-id' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'FOREIGN_KEY_VIOLATION' }),
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await leadController.updateLead({ params: { id: 'lead-1' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ═══════════════════════════════════════════════════════════════════
// deleteLead
// ═══════════════════════════════════════════════════════════════════
describe('deleteLead', () => {
  it('returns 404 when lead not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.deleteLead({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEAD_NOT_FOUND' }),
    }));
  });

  it('soft-deletes lead (sets isActive false)', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1' }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(undefined),
      }),
    });
    const res = mockRes();
    await leadController.deleteLead({ params: { id: 'lead-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: null,
      message: 'Lead deleted successfully',
    }));
    expect(db.update).toHaveBeenCalled();
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await leadController.deleteLead({ params: { id: 'lead-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEAD_DELETE_FAILED' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateLeadStatus
// ═══════════════════════════════════════════════════════════════════
describe('updateLeadStatus', () => {
  it('returns 400 when stage is missing', async () => {
    const res = mockRes();
    await leadController.updateLeadStatus({ params: { id: 'lead-1' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 for invalid stage', async () => {
    const res = mockRes();
    await leadController.updateLeadStatus({ params: { id: 'lead-1' }, body: { stage: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when lead not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.updateLeadStatus({ params: { id: 'nonexistent' }, body: { stage: 'contacte' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('updates lead stage successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1', stage: 'nouveau' }]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'lead-1', stage: 'contacte' }]),
        }),
      }),
    });
    const res = mockRes();
    await leadController.updateLeadStatus({ params: { id: 'lead-1' }, body: { stage: 'contacte' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ stage: 'contacte' }),
      message: 'Lead status updated successfully',
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await leadController.updateLeadStatus({ params: { id: 'lead-1' }, body: { stage: 'contacte' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ═══════════════════════════════════════════════════════════════════
// bulkUpdateLeads
// ═══════════════════════════════════════════════════════════════════
describe('bulkUpdateLeads', () => {
  it('returns 400 when ids is empty array', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({ body: { ids: [], updates: { stage: 'contacte' } } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 when ids is not an array', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({ body: { ids: 'not-array', updates: {} } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when updates is missing', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({ body: { ids: ['lead-1'] } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when updates is not an object', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({ body: { ids: ['lead-1'], updates: 'bad' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when a disallowed field is in updates', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({
      body: { ids: ['lead-1'], updates: { fullName: 'Hacked' } },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 for invalid stage in bulk update', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({
      body: { ids: ['lead-1'], updates: { stage: 'invalid' } },
    }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('bulk updates leads successfully', async () => {
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(undefined),
      }),
    });
    const res = mockRes();
    await leadController.bulkUpdateLeads({
      body: { ids: ['lead-1', 'lead-2'], updates: { stage: 'qualifie' } },
    }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: { updatedCount: 2 },
      message: '2 lead(s) updated successfully',
    }));
  });

  it('returns 500 on DB error', async () => {
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockRejectedValue(new Error('DB down')),
      }),
    });
    const res = mockRes();
    await leadController.bulkUpdateLeads({
      body: { ids: ['lead-1'], updates: { stage: 'contacte' } },
    }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'LEAD_BULK_UPDATE_FAILED' }),
    }));
  });
});
