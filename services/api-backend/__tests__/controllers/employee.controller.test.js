jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  asc: jest.fn((col) => ({ _type: 'asc', col })),
  ilike: jest.fn((col, val) => ({ col, val, _type: 'ilike' })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
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
  chain.innerJoin = jest.fn().mockReturnValue(chain);
  return chain;
};

let selectChain;

const mockDb = {
  select: jest.fn(() => selectChain),
  insert: jest.fn(() => ({
    values: jest.fn().mockReturnValue({
      returning: jest.fn(() => Promise.resolve([{ id: 'emp-1', firstName: 'Jean', lastName: 'Tremblay' }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{ id: 'emp-1', firstName: 'Jean' }])),
      }),
    }),
  })),
  delete: jest.fn(() => ({
    where: jest.fn().mockResolvedValue(undefined),
  })),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/database/schema', () => ({
  employeesTable: { id: 'id', firstName: 'firstName', lastName: 'lastName', phone: 'phone', email: 'email', isActive: 'isActive', createdAt: 'createdAt', updatedAt: 'updatedAt' },
  employeeAssignmentsTable: { id: 'id', employeeId: 'employeeId', buildingId: 'buildingId', role: 'role', isActive: 'isActive', createdAt: 'createdAt' },
}));

const employeeController = require('../../src/controllers/employee.controller');
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
// createEmployee
// ═══════════════════════════════════════════════════════════════════
describe('createEmployee', () => {
  it('returns 400 when firstName missing', async () => {
    const res = mockRes();
    await employeeController.createEmployee({ body: { lastName: 'Doe', phone: '+15145551234' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('returns 400 when lastName missing', async () => {
    const res = mockRes();
    await employeeController.createEmployee({ body: { firstName: 'John', phone: '+15145551234' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when phone missing', async () => {
    const res = mockRes();
    await employeeController.createEmployee({ body: { firstName: 'John', lastName: 'Doe' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('creates employee successfully', async () => {
    const res = mockRes();
    await employeeController.createEmployee({ body: { firstName: 'Jean', lastName: 'Tremblay', phone: '+15145551234', email: 'jean@test.com' } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'emp-1' }),
    }));
  });

  it('returns 409 on duplicate phone (23505)', async () => {
    const dupError = new Error('duplicate');
    dupError.code = '23505';
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(dupError),
      }),
    });
    const res = mockRes();
    await employeeController.createEmployee({ body: { firstName: 'Jean', lastName: 'Tremblay', phone: '+15145551234' } }, res);
    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'DUPLICATE_PHONE' }),
    }));
  });

  it('returns 500 on DB error', async () => {
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(new Error('DB down')),
      }),
    });
    const res = mockRes();
    await employeeController.createEmployee({ body: { firstName: 'J', lastName: 'D', phone: '+15145551234' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'EMPLOYEE_CREATION_FAILED' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getEmployees
// ═══════════════════════════════════════════════════════════════════
describe('getEmployees', () => {
  it('returns paginated employees', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([{ id: 'emp-1', firstName: 'Jean' }]);
    const res = mockRes();
    await employeeController.getEmployees({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: [{ id: 'emp-1', firstName: 'Jean' }],
      metadata: expect.objectContaining({ total: 1, page: 1, limit: 20 }),
    }));
  });

  it('filters by search and isActive', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.where.mockResolvedValueOnce([{ count: 0 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await employeeController.getEmployees({ query: { search: 'Jean', isActive: 'true' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ data: [] }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await employeeController.getEmployees({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ═══════════════════════════════════════════════════════════════════
// getEmployeeById
// ═══════════════════════════════════════════════════════════════════
describe('getEmployeeById', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await employeeController.getEmployeeById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'EMPLOYEE_NOT_FOUND' }),
    }));
  });

  it('returns employee data', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'emp-1', firstName: 'Jean' }]);
    const res = mockRes();
    await employeeController.getEmployeeById({ params: { id: 'emp-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'emp-1' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateEmployee
// ═══════════════════════════════════════════════════════════════════
describe('updateEmployee', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await employeeController.updateEmployee({ params: { id: 'nonexistent' }, body: { firstName: 'New' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('updates employee successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'emp-1' }]);
    const res = mockRes();
    await employeeController.updateEmployee({ params: { id: 'emp-1' }, body: { firstName: 'Updated' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'emp-1' }),
    }));
  });

  it('returns 409 on duplicate phone update', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'emp-1' }]);
    const dupError = new Error('dup');
    dupError.code = '23505';
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockRejectedValue(dupError),
        }),
      }),
    });
    const res = mockRes();
    await employeeController.updateEmployee({ params: { id: 'emp-1' }, body: { phone: '+15145559999' } }, res);
    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'DUPLICATE_PHONE' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// deleteEmployee
// ═══════════════════════════════════════════════════════════════════
describe('deleteEmployee', () => {
  it('returns 404 when not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await employeeController.deleteEmployee({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('soft-deletes employee', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'emp-1' }]);
    const res = mockRes();
    await employeeController.deleteEmployee({ params: { id: 'emp-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Employee deleted successfully',
    }));
    expect(db.update).toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════════
// assignEmployee
// ═══════════════════════════════════════════════════════════════════
describe('assignEmployee', () => {
  it('returns 400 when buildingId missing', async () => {
    const res = mockRes();
    await employeeController.assignEmployee({ body: { employeeId: 'emp-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 when employeeId missing', async () => {
    const res = mockRes();
    await employeeController.assignEmployee({ body: { buildingId: 'bld-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 400 for invalid role', async () => {
    const res = mockRes();
    await employeeController.assignEmployee({ body: { buildingId: 'bld-1', employeeId: 'emp-1', role: 'manager' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
    }));
  });

  it('assigns employee with default primary role', async () => {
    const res = mockRes();
    await employeeController.assignEmployee({ body: { buildingId: 'bld-1', employeeId: 'emp-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ id: 'emp-1' }),
    }));
  });

  it('handles FK violation (23503)', async () => {
    const fkError = new Error('FK');
    fkError.code = '23503';
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockRejectedValue(fkError),
      }),
    });
    const res = mockRes();
    await employeeController.assignEmployee({ body: { buildingId: 'bad', employeeId: 'emp-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'FOREIGN_KEY_ERROR' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// removeAssignment
// ═══════════════════════════════════════════════════════════════════
describe('removeAssignment', () => {
  it('returns 404 when assignment not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await employeeController.removeAssignment({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'ASSIGNMENT_NOT_FOUND' }),
    }));
  });

  it('removes assignment', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'assign-1' }]);
    const res = mockRes();
    await employeeController.removeAssignment({ params: { id: 'assign-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Assignment removed successfully',
    }));
    expect(db.delete).toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════════
// getBuildingEmployees
// ═══════════════════════════════════════════════════════════════════
describe('getBuildingEmployees', () => {
  it('returns building employees', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.orderBy.mockResolvedValueOnce([{ id: 'emp-1', firstName: 'Jean', role: 'primary' }]);
    const res = mockRes();
    await employeeController.getBuildingEmployees({ params: { buildingId: 'bld-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: [{ id: 'emp-1', firstName: 'Jean', role: 'primary' }],
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await employeeController.getBuildingEmployees({ params: { buildingId: 'bld-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'BUILDING_EMPLOYEES_FETCH_FAILED' }),
    }));
  });
});
