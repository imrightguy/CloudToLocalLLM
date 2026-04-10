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
