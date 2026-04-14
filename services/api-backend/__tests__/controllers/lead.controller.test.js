jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
  ilike: jest.fn((col, val) => ({ col, val, _type: 'ilike' })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
}));

jest.mock('../../src/constants/lead-stages', () => ({
  VALID_LEAD_STAGES: ['nouveau', 'contacte', 'visite_planifiee', 'visite_terminee', 'negociation', 'bail_signe', 'inactif'],
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

const mockSelectChain = () => {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  return chain;
};

let selectChain;

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => ({
    values: jest.fn().mockReturnValue({
      returning: jest.fn(() => Promise.resolve([{ id: 'lead-1', fullName: 'Test Lead' }])),
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
  leadsTable: { id: 'id', fullName: 'fullName', email: 'email', phone: 'phone', stage: 'stage', source: 'source', buildingId: 'buildingId', assignedEmployeeId: 'assignedEmployeeId', isActive: 'isActive', createdAt: 'createdAt', updatedAt: 'updatedAt' },
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

  it('returns 400 when fullName is empty string', async () => {
    const res = mockRes();
    await leadController.createLead({ body: { fullName: '  ' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('creates lead with defaults', async () => {
    const res = mockRes();
    await leadController.createLead({ body: { fullName: 'Jean Dupont' } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'lead-1' }),
    }));
  });

  it('creates lead with all fields', async () => {
    const res = mockRes();
    await leadController.createLead({
      body: {
        fullName: 'Marie Tremblay',
        email: 'marie@test.com',
        phone: '+15145551234',
        source: 'website',
        stage: 'contacte',
        notes: 'Interested in 2BR',
        tags: ['urgent'],
        language: 'en',
        assignedEmployeeId: 'emp-1',
        buildingId: 'bld-1',
      },
    }, res);
    expect(res.status).toHaveBeenCalledWith(201);
  });

  it('handles FK violation (23503)', async () => {
    const fkError = new Error('FK violation');
    fkError.code = '23503';
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(fkError),
      }),
    });
    const res = mockRes();
    await leadController.createLead({ body: { fullName: 'Test', buildingId: 'bad-ref' } }, res);
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
  it('returns paginated leads', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'lead-1' }]);
    const res = mockRes();
    await leadController.getLeads({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: [{ id: 'lead-1' }],
      metadata: expect.objectContaining({ total: 1, page: 1, limit: 20 }),
    }));
  });

  it('filters by stage and buildingId', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.getLeads({ query: { stage: 'nouveau', buildingId: 'bld-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ data: [] }));
  });

  it('searches by fullName', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'lead-1', fullName: 'Jean' }]);
    const res = mockRes();
    await leadController.getLeads({ query: { search: 'Jean' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      data: [{ id: 'lead-1', fullName: 'Jean' }],
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await leadController.getLeads({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
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
    const lead = { id: 'lead-1', fullName: 'Jean Dupont' };
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([lead]);
    const res = mockRes();
    await leadController.getLeadById({ params: { id: 'lead-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true, data: lead }));
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
  });

  it('returns 400 when stage is invalid', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1' }]);
    const res = mockRes();
    await leadController.updateLead({ params: { id: 'lead-1' }, body: { stage: 'invalid_stage' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('updates lead successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1' }]);
    const res = mockRes();
    await leadController.updateLead({ params: { id: 'lead-1' }, body: { fullName: 'Updated Name' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'lead-1' }),
    }));
  });

  it('handles FK violation on update', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1' }]);
    const fkError = new Error('FK');
    fkError.code = '23503';
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockRejectedValue(fkError),
        }),
      }),
    });
    const res = mockRes();
    await leadController.updateLead({ params: { id: 'lead-1' }, body: { buildingId: 'bad-ref' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'FOREIGN_KEY_VIOLATION' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// deleteLead
// ═══════════════════════════════════════════════════════════════════
describe('deleteLead', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.deleteLead({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('soft-deletes lead', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1' }]);
    const res = mockRes();
    await leadController.deleteLead({ params: { id: 'lead-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Lead deleted successfully',
    }));
    expect(db.update).toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateLeadStatus
// ═══════════════════════════════════════════════════════════════════
describe('updateLeadStatus', () => {
  it('returns 400 when stage is invalid', async () => {
    const res = mockRes();
    await leadController.updateLeadStatus({ params: { id: 'lead-1' }, body: { stage: 'bad_stage' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 when stage is missing', async () => {
    const res = mockRes();
    await leadController.updateLeadStatus({ params: { id: 'lead-1' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 404 when lead not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await leadController.updateLeadStatus({ params: { id: 'nonexistent' }, body: { stage: 'contacte' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('updates lead status successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'lead-1' }]);
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
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// bulkUpdateLeads
// ═══════════════════════════════════════════════════════════════════
describe('bulkUpdateLeads', () => {
  it('returns 400 when ids is empty', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({ body: { ids: [], updates: {} } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when ids is not an array', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({ body: { ids: 'not-array', updates: {} } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when updates is not an object', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({ body: { ids: ['lead-1'], updates: 'bad' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when field is not allowed', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({ body: { ids: ['lead-1'], updates: { fullName: 'Hack' } } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 when stage value is invalid', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({ body: { ids: ['lead-1'], updates: { stage: 'bad_stage' } } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('bulk updates leads successfully', async () => {
    const res = mockRes();
    await leadController.bulkUpdateLeads({
      body: { ids: ['lead-1', 'lead-2'], updates: { stage: 'contacte', buildingId: 'bld-1' } },
    }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: { updatedCount: 2 },
      message: '2 lead(s) updated successfully',
    }));
  });
});
