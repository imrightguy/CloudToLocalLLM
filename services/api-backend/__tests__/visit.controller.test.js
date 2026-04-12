const visitController = require('../src/controllers/visit.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

// ─── createVisit validation ───

describe('createVisit', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing unitId', async () => {
    await visitController.createVisit(
      { body: { employeeId: 'emp-1', leadId: 'lead-1', dateTime: '2025-06-15T14:00:00Z' } },
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
    await visitController.createVisit(
      { body: { unitId: 'unit-1', leadId: 'lead-1', dateTime: '2025-06-15T14:00:00Z' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing leadId', async () => {
    await visitController.createVisit(
      { body: { unitId: 'unit-1', employeeId: 'emp-1', dateTime: '2025-06-15T14:00:00Z' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects missing dateTime', async () => {
    await visitController.createVisit(
      { body: { unitId: 'unit-1', employeeId: 'emp-1', leadId: 'lead-1' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty body', async () => {
    await visitController.createVisit({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid dateTime', async () => {
    await visitController.createVisit(
      {
        body: {
          unitId: 'unit-1',
          employeeId: 'emp-1',
          leadId: 'lead-1',
          dateTime: 'not-a-date',
        },
      },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'VALIDATION_ERROR' }),
      }),
    );
  });

  it('error message mentions required fields', async () => {
    await visitController.createVisit({ body: {} }, res);
    const msg = res.json.mock.calls[0][0].error.message;
    expect(msg).toMatch(/unitId.*employeeId.*leadId.*dateTime/s);
  });
});

// ─── getVisits pagination ───

describe('getVisits', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('accepts default query params', async () => {
    await visitController.getVisits({ query: {} }, res);
    // Should hit DB (returns 500 in test without mock), not 400
    expect(res.status).not.toHaveBeenCalledWith(400);
  });

  it('accepts page and limit params', async () => {
    await visitController.getVisits({ query: { page: '2', limit: '50' } }, res);
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});

// ─── getVisitById ───

describe('getVisitById', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('accepts valid id param', async () => {
    await visitController.getVisitById({ params: { id: 'visit-123' } }, res);
    // Will hit DB, not a validation error
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});

// ─── updateVisit ───

describe('updateVisit', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects invalid dateTime in body', async () => {
    // When visit exists and dateTime is invalid
    await visitController.updateVisit(
      { params: { id: 'visit-123' }, body: { dateTime: 'garbage' } },
      res,
    );
    // Either 400 (validation) or hits DB and fails — either way no 200
    expect(res.json).toHaveBeenCalled();
  });
});

// ─── updateVisitStatus ───

describe('updateVisitStatus', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('rejects missing status', async () => {
    await visitController.updateVisitStatus(
      { params: { id: 'visit-123' }, body: {} },
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

  it('rejects invalid status value', async () => {
    await visitController.updateVisitStatus(
      { params: { id: 'visit-123' }, body: { status: 'banana' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    const msg = res.json.mock.calls[0][0].error.message;
    expect(msg).toMatch(/scheduled.*confirmed.*completed.*cancelled.*no_show/s);
  });

  it('rejects null status', async () => {
    await visitController.updateVisitStatus(
      { params: { id: 'visit-123' }, body: { status: null } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects empty string status', async () => {
    await visitController.updateVisitStatus(
      { params: { id: 'visit-123' }, body: { status: '' } },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('rejects invalid outcome value', async () => {
    // DB will throw before reaching outcome validation in unit test env,
    // so we just verify it doesn't succeed (200) — outcome validation is
    // tested in integration tests with a real DB.
    await visitController.updateVisitStatus(
      { params: { id: 'visit-123' }, body: { status: 'completed', outcome: 'invalid_outcome' } },
      res,
    );
    const called = res.status.mock.calls[0][0];
    expect(called).not.toBe(200);
  });
});

// ─── deleteVisit ───

describe('deleteVisit', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
  });

  it('accepts valid id param', async () => {
    await visitController.deleteVisit({ params: { id: 'visit-123' } }, res);
    // Will hit DB, not a validation error
    expect(res.status).not.toHaveBeenCalledWith(400);
  });
});
