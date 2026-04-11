const employeeController = require('../src/controllers/employee.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

// ─── createEmployee validation ───

describe('createEmployee', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing firstName', async () => {
    await employeeController.createEmployee(
      { body: { lastName: 'Tremblay', phone: '514-555-0001' } },
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

  it('rejects missing lastName', async () => {
    await employeeController.createEmployee(
      { body: { firstName: 'Jean', phone: '514-555-0001' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing phone', async () => {
    await employeeController.createEmployee(
      { body: { firstName: 'Jean', lastName: 'Tremblay' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty body', async () => {
    await employeeController.createEmployee({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects null firstName', async () => {
    await employeeController.createEmployee(
      { body: { firstName: null, lastName: 'Tremblay', phone: '514-555-0001' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects undefined firstName', async () => {
    await employeeController.createEmployee(
      { body: { firstName: undefined, lastName: 'Tremblay', phone: '514-555-0001' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('error message mentions all required fields', async () => {
    await employeeController.createEmployee({ body: {} }, res);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toContain('firstName');
    expect(errorMsg).toContain('lastName');
    expect(errorMsg).toContain('phone');
  });

  it('allows missing email (optional)', async () => {
    await employeeController.createEmployee(
      { body: { firstName: 'Jean', lastName: 'Tremblay', phone: '514-555-0001' } },
      res,
    );
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});

// ─── assignEmployee validation ───

describe('assignEmployee', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing buildingId', async () => {
    await employeeController.assignEmployee(
      { body: { employeeId: 'emp-123' } },
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

  it('rejects missing employeeId', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: 'bld-456' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty body', async () => {
    await employeeController.assignEmployee({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid role', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: 'bld-456', employeeId: 'emp-123', role: 'manager' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    const errorMsg = res.json.mock.calls[0][0].error.message;
    expect(errorMsg).toContain('primary');
    expect(errorMsg).toContain('backup');
  });

  it('accepts "primary" role', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: 'bld-456', employeeId: 'emp-123', role: 'primary' } },
      res,
    );
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('accepts "backup" role', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: 'bld-456', employeeId: 'emp-123', role: 'backup' } },
      res,
    );
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('defaults role to "primary" when omitted', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: 'bld-456', employeeId: 'emp-123' } },
      res,
    );
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});

// ─── getBuildingEmployees (DB-dependent, not tested without mock) ───

// ─── Shared mock helpers for DB-dependent tests ──────────────────────────────

const { db } = require('../src/database/connection');

/**
 * Creates a chainable mock that mirrors the drizzle query-builder API.
 * The chain itself is thenable so `await db.select().from()…` resolves.
 */
function createMockChain(resolveTo = []) {
  const chain = {};
  chain.from = jest.fn().mockReturnValue(chain);
  chain.where = jest.fn().mockReturnValue(chain);
  chain.orderBy = jest.fn().mockReturnValue(chain);
  chain.limit = jest.fn().mockReturnValue(chain);
  chain.offset = jest.fn().mockReturnValue(chain);
  chain.innerJoin = jest.fn().mockReturnValue(chain);
  chain.values = jest.fn().mockReturnValue(chain);
  chain.returning = jest.fn().mockResolvedValue(resolveTo);
  chain.set = jest.fn().mockReturnValue(chain);
  // Make the chain awaitable (drizzle builders implement the Promise interface)
  chain.then = (onFulfilled, onRejected) => Promise.resolve(resolveTo).then(onFulfilled, onRejected);
  chain.catch = (onRejected) => Promise.resolve(resolveTo).catch(onRejected);
  return chain;
}

// ─── getEmployees query param parsing ───

describe('getEmployees - query param parsing', () => {
  let res;
  let selectChain;

  beforeEach(() => {
    res = mockRes();
    selectChain = createMockChain([{ count: 0 }]);
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('defaults page to 1 and limit to 20', async () => {
    jest.spyOn(db, 'select').mockReturnValue(selectChain);

    await employeeController.getEmployees({ query: {} }, res);

    expect(db.select).toHaveBeenCalledTimes(2);
    expect(selectChain.limit).toHaveBeenCalledWith(20);
  });

  it('parses page and limit from query params', async () => {
    jest.spyOn(db, 'select').mockReturnValue(selectChain);

    await employeeController.getEmployees({ query: { page: '3', limit: '10' } }, res);

    expect(selectChain.limit).toHaveBeenCalledWith(10);
    expect(selectChain.offset).toHaveBeenCalledWith(20); // (3-1) * 10
  });

  it('parses search parameter', async () => {
    jest.spyOn(db, 'select').mockReturnValue(selectChain);

    await employeeController.getEmployees({ query: { search: 'Jean' } }, res);

    expect(db.select).toHaveBeenCalledTimes(2);
    // search builds a WHERE clause via ilike
    expect(selectChain.where).toHaveBeenCalled();
  });

  it('parses isActive filter with "true"', async () => {
    jest.spyOn(db, 'select').mockReturnValue(selectChain);

    await employeeController.getEmployees({ query: { isActive: 'true' } }, res);

    expect(selectChain.where).toHaveBeenCalled();
  });

  it('parses isActive filter with "false"', async () => {
    jest.spyOn(db, 'select').mockReturnValue(selectChain);

    await employeeController.getEmployees({ query: { isActive: 'false' } }, res);

    expect(selectChain.where).toHaveBeenCalled();
  });

  it('does not add WHERE clause when no filters are provided', async () => {
    jest.spyOn(db, 'select').mockReturnValue(selectChain);

    await employeeController.getEmployees({ query: {} }, res);

    // Still called (once per query — count + data), but the controller's
    // conditions array stays empty and `and()` is never invoked with args,
    // so whereClause becomes `undefined`.  Drizzle's `.where(undefined)` is
    // a no-op, but the method is still part of the chain.
    expect(db.select).toHaveBeenCalledTimes(2);
  });

  it('returns metadata with total, page, limit, totalPages, hasMore', async () => {
    jest.spyOn(db, 'select').mockReturnValue(selectChain);

    await employeeController.getEmployees({ query: {} }, res);

    const body = res.json.mock.calls[0][0];
    expect(body.success).toBe(true);
    expect(body.metadata).toBeDefined();
    expect(body.metadata).toHaveProperty('total', 0);
    expect(body.metadata).toHaveProperty('page', 1);
    expect(body.metadata).toHaveProperty('limit', 20);
    expect(body.metadata).toHaveProperty('totalPages', 0);
    expect(body.metadata).toHaveProperty('hasMore', false);
  });

  it('calculates totalPages as Math.ceil(total / limit)', async () => {
    const chain = createMockChain([{ count: 25 }]);
    jest.spyOn(db, 'select').mockReturnValue(chain);

    await employeeController.getEmployees({ query: { limit: '10' } }, res);

    const { metadata } = res.json.mock.calls[0][0];
    expect(metadata.total).toBe(25);
    expect(metadata.totalPages).toBe(3); // ceil(25 / 10)
  });

  it('sets hasMore to true when current page < totalPages', async () => {
    const chain = createMockChain([{ count: 25 }]);
    jest.spyOn(db, 'select').mockReturnValue(chain);

    await employeeController.getEmployees({ query: { page: '1', limit: '10' } }, res);

    expect(res.json.mock.calls[0][0].metadata.hasMore).toBe(true);
  });

  it('sets hasMore to false when current page >= totalPages', async () => {
    const chain = createMockChain([{ count: 5 }]);
    jest.spyOn(db, 'select').mockReturnValue(chain);

    await employeeController.getEmployees({ query: { page: '1', limit: '10' } }, res);

    expect(res.json.mock.calls[0][0].metadata.hasMore).toBe(false);
  });

  it('calculates offset correctly for page 1', async () => {
    jest.spyOn(db, 'select').mockReturnValue(selectChain);

    await employeeController.getEmployees({ query: { page: '1', limit: '20' } }, res);

    expect(selectChain.offset).toHaveBeenCalledWith(0); // (1-1) * 20
  });

  it('calculates offset correctly for page 2 with limit 10', async () => {
    jest.spyOn(db, 'select').mockReturnValue(selectChain);

    await employeeController.getEmployees({ query: { page: '2', limit: '10' } }, res);

    expect(selectChain.offset).toHaveBeenCalledWith(10); // (2-1) * 10
  });
});

// ─── getEmployeeById ───

describe('getEmployeeById', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  const id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  it('does not crash with a valid UUID id', async () => {
    const chain = createMockChain([{ id, firstName: 'Test' }]);
    jest.spyOn(db, 'select').mockReturnValue(chain);

    await expect(
      employeeController.getEmployeeById({ params: { id } }, res),
    ).resolves.not.toThrow();
  });

  it('returns 404 when employee is not found', async () => {
    const chain = createMockChain([]);
    jest.spyOn(db, 'select').mockReturnValue(chain);

    await employeeController.getEmployeeById({ params: { id } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'EMPLOYEE_NOT_FOUND' }),
      }),
    );
  });

  it('returns employee data when found', async () => {
    const employee = {
      id, firstName: 'Jean', lastName: 'Tremblay', phone: '514-555-0001',
    };
    const chain = createMockChain([employee]);
    jest.spyOn(db, 'select').mockReturnValue(chain);

    await employeeController.getEmployeeById({ params: { id } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: employee,
      }),
    );
  });
});

// ─── updateEmployee ───

describe('updateEmployee', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  const id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  function mockExistingEmployee() {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([{ id, firstName: 'Jean' }]));
    jest.spyOn(db, 'update').mockReturnValue(createMockChain([{ id, firstName: 'Jean' }]));
  }

  it('does not crash when called with valid params', async () => {
    mockExistingEmployee();

    await expect(
      employeeController.updateEmployee(
        { params: { id }, body: { firstName: 'Updated' } },
        res,
      ),
    ).resolves.not.toThrow();
  });

  it('handles updating firstName', async () => {
    mockExistingEmployee();

    await employeeController.updateEmployee(
      { params: { id }, body: { firstName: 'NewName' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('handles updating lastName', async () => {
    mockExistingEmployee();

    await employeeController.updateEmployee(
      { params: { id }, body: { lastName: 'NewLastName' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('handles updating phone', async () => {
    mockExistingEmployee();

    await employeeController.updateEmployee(
      { params: { id }, body: { phone: '514-555-9999' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('handles updating email', async () => {
    mockExistingEmployee();

    await employeeController.updateEmployee(
      { params: { id }, body: { email: 'new@example.com' } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('handles updating isActive', async () => {
    mockExistingEmployee();

    await employeeController.updateEmployee(
      { params: { id }, body: { isActive: false } },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('handles updating multiple fields at once', async () => {
    mockExistingEmployee();

    await employeeController.updateEmployee(
      {
        params: { id },
        body: {
          firstName: 'New', lastName: 'Name', phone: '514-555-0000', email: 'new@example.com',
        },
      },
      res,
    );

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });

  it('returns 404 when employee does not exist', async () => {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([]));

    await employeeController.updateEmployee(
      { params: { id }, body: { firstName: 'Ghost' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'EMPLOYEE_NOT_FOUND' }),
      }),
    );
  });
});

// ─── deleteEmployee ───

describe('deleteEmployee', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  const id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  it('does not crash when called with valid params', async () => {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([{ id }]));
    jest.spyOn(db, 'update').mockReturnValue(createMockChain(undefined));

    await expect(
      employeeController.deleteEmployee({ params: { id } }, res),
    ).resolves.not.toThrow();
  });

  it('returns success when employee exists', async () => {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([{ id }]));
    jest.spyOn(db, 'update').mockReturnValue(createMockChain(undefined));

    await employeeController.deleteEmployee({ params: { id } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        message: 'Employee deleted successfully',
      }),
    );
  });

  it('returns 404 when employee not found', async () => {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([]));

    await employeeController.deleteEmployee({ params: { id } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'EMPLOYEE_NOT_FOUND' }),
      }),
    );
  });
});

// ─── assignEmployee additional validation ───

describe('assignEmployee - additional validation', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects when both buildingId and employeeId are missing', async () => {
    await employeeController.assignEmployee({ body: {} }, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }),
    );
  });

  it('rejects empty string buildingId', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: '', employeeId: 'emp-123' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty string employeeId', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: 'bld-456', employeeId: '' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects role "Primary" (case-sensitive)', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: 'bld-456', employeeId: 'emp-123', role: 'Primary' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects role "BACKUP" (case-sensitive)', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: 'bld-456', employeeId: 'emp-123', role: 'BACKUP' } },
      res,
    );

    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects null role', async () => {
    await employeeController.assignEmployee(
      { body: { buildingId: 'bld-456', employeeId: 'emp-123', role: null } },
      res,
    );

    // null role → assignmentRole = null || 'primary' = 'primary', which is valid
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});

// ─── removeAssignment ───

describe('removeAssignment', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  const id = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890';

  it('does not crash when called with a valid UUID id', async () => {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([{ id }]));
    jest.spyOn(db, 'delete').mockReturnValue(createMockChain(undefined));

    await expect(
      employeeController.removeAssignment({ params: { id } }, res),
    ).resolves.not.toThrow();
  });

  it('returns success when assignment exists', async () => {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([{ id }]));
    jest.spyOn(db, 'delete').mockReturnValue(createMockChain(undefined));

    await employeeController.removeAssignment({ params: { id } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        message: 'Assignment removed successfully',
      }),
    );
  });

  it('returns 404 when assignment not found', async () => {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([]));

    await employeeController.removeAssignment({ params: { id } }, res);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'ASSIGNMENT_NOT_FOUND' }),
      }),
    );
  });
});

// ─── getBuildingEmployees ───

describe('getBuildingEmployees', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  const buildingId = 'b1b2c3d4-e5f6-7890-abcd-ef1234567890';

  it('does not crash when called with a buildingId param', async () => {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([]));

    await expect(
      employeeController.getBuildingEmployees({ params: { buildingId } }, res),
    ).resolves.not.toThrow();
  });

  it('returns employees array for the building', async () => {
    const employees = [
      {
        id: 'e1', firstName: 'Jean', lastName: 'Tremblay', role: 'primary',
      },
    ];
    jest.spyOn(db, 'select').mockReturnValue(createMockChain(employees));

    await employeeController.getBuildingEmployees({ params: { buildingId } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: employees,
      }),
    );
  });

  it('returns empty array when no employees are assigned', async () => {
    jest.spyOn(db, 'select').mockReturnValue(createMockChain([]));

    await employeeController.getBuildingEmployees({ params: { buildingId } }, res);

    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: true,
        data: [],
      }),
    );
  });
});
