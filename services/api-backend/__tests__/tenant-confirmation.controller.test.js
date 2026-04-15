// Mock database
jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn(),
    insert: jest.fn(),
    update: jest.fn(),
  },
}));

jest.mock('../src/utils/logger', () => ({
  error: jest.fn(),
  info: jest.fn(),
  child: jest.fn(() => ({ error: jest.fn(), info: jest.fn() })),
}));

const { db } = require('../src/database/connection');
const tenantConfirmation = require('../src/controllers/tenant-confirmation.controller');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.send = jest.fn().mockReturnValue(res);
  res.accepts = jest.fn();
  return res;
}

// ─── submitConfirmation validation ───

describe('tenant-confirmation — submitConfirmation', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('rejects invalid action', async () => {
    await tenantConfirmation.submitConfirmation(
      { params: { token: 'abc123' }, body: { action: 'maybe' }, query: {}, accepts: jest.fn() },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'INVALID_ACTION' }),
      }),
    );
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await tenantConfirmation.submitConfirmation(
      { params: { token: 'abc123' }, body: { action: 'confirm' }, query: {}, accepts: jest.fn() },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'CONFIRMATION_FAILED' }),
      }),
    );
  });
});

// ─── getConfirmationPage ───

describe('tenant-confirmation — getConfirmationPage', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
  });

  it('returns 500 when db fails', async () => {
    db.select.mockImplementation(() => { throw new Error('DB error'); });

    await tenantConfirmation.getConfirmationPage(
      { params: { token: 'abc123' }, query: {} },
      res,
    );
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.send).toHaveBeenCalledWith('Internal error');
  });
});

// ─── generateConfirmationToken ───

describe('tenant-confirmation — generateConfirmationToken', () => {
  it('generates a non-empty string token', () => {
    const token = tenantConfirmation.generateConfirmationToken();
    expect(typeof token).toBe('string');
    expect(token.length).toBeGreaterThan(0);
  });

  it('generates unique tokens', () => {
    const token1 = tenantConfirmation.generateConfirmationToken();
    const token2 = tenantConfirmation.generateConfirmationToken();
    expect(token1).not.toBe(token2);
  });
});
