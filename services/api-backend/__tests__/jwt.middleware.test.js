const jwt = require('jsonwebtoken');

jest.mock('jsonwebtoken');

jest.mock('../src/database/connection', () => {
  const mockSelect = jest.fn();
  const mockFrom = jest.fn();
  const mockWhere = jest.fn();
  const mockLimit = jest.fn();

  mockSelect.mockReturnValue({ from: mockFrom });
  mockFrom.mockReturnValue({ where: mockWhere });
  mockWhere.mockReturnValue({ limit: mockLimit });

  return {
    db: {
      select: mockSelect,
      _mockFrom: mockFrom,
      _mockWhere: mockWhere,
      _mockLimit: mockLimit,
    },
  };
});

const { db } = require('../src/database/connection');
const {
  authenticateToken,
  authorizeRole,
  optionalAuth,
  generateAccessToken,
  generateRefreshToken,
} = require('../src/auth/jwt.middleware');

process.env.JWT_SECRET = 'test-secret';
process.env.JWT_REFRESH_SECRET = 'test-refresh-secret';
process.env.JWT_EXPIRES_IN = '1h';

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

function mockNext() {
  return jest.fn();
}

const activeUser = {
  id: 1,
  email: 'admin@test.com',
  firstName: 'Admin',
  lastName: 'User',
  role: 'admin',
  isActive: true,
};

beforeEach(() => {
  jest.clearAllMocks();
  db.select.mockReturnValue({ from: db._mockFrom });
  db._mockFrom.mockReturnValue({ where: db._mockWhere });
  db._mockWhere.mockReturnValue({ limit: db._mockLimit });
});

describe('authenticateToken', () => {
  it('returns 401 when no authorization header', async () => {
    const req = { headers: {} };
    const res = mockRes();
    const next = mockNext();

    await authenticateToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        success: false,
        error: expect.objectContaining({ code: 'ACCESS_TOKEN_REQUIRED' }),
      }),
    );
    expect(next).not.toHaveBeenCalled();
  });

  it('returns 401 when token is missing (header present but no token)', async () => {
    const req = { headers: { authorization: 'Bearer ' } };
    const res = mockRes();
    const next = mockNext();

    await authenticateToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'ACCESS_TOKEN_REQUIRED' }),
      }),
    );
  });

  it('returns 401 for expired token', async () => {
    const error = new Error('jwt expired');
    error.name = 'TokenExpiredError';
    jwt.verify.mockImplementation(() => { throw error; });

    const req = { headers: { authorization: 'Bearer expired-token' } };
    const res = mockRes();
    const next = mockNext();

    await authenticateToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'TOKEN_EXPIRED' }),
      }),
    );
  });

  it('returns 401 for invalid token', async () => {
    jwt.verify.mockImplementation(() => { throw new Error('bad token'); });

    const req = { headers: { authorization: 'Bearer bad-token' } };
    const res = mockRes();
    const next = mockNext();

    await authenticateToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'INVALID_TOKEN' }),
      }),
    );
  });

  it('returns 401 when user not found in database', async () => {
    jwt.verify.mockReturnValue({ userId: 999 });
    db._mockLimit.mockResolvedValue([]);

    const req = { headers: { authorization: 'Bearer valid-token' } };
    const res = mockRes();
    const next = mockNext();

    await authenticateToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'USER_NOT_FOUND' }),
      }),
    );
  });

  it('returns 401 when user is inactive', async () => {
    jwt.verify.mockReturnValue({ userId: 2 });
    db._mockLimit.mockResolvedValue([{ ...activeUser, isActive: false }]);

    const req = { headers: { authorization: 'Bearer valid-token' } };
    const res = mockRes();
    const next = mockNext();

    await authenticateToken(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'USER_NOT_FOUND' }),
      }),
    );
  });

  it('attaches user to req and calls next for valid token', async () => {
    jwt.verify.mockReturnValue({ userId: 1 });
    db._mockLimit.mockResolvedValue([activeUser]);

    const req = { headers: { authorization: 'Bearer valid-token' } };
    const res = mockRes();
    const next = mockNext();

    await authenticateToken(req, res, next);

    expect(req.user).toEqual(activeUser);
    expect(req.token).toBe('valid-token');
    expect(next).toHaveBeenCalledTimes(1);
  });
});

describe('authorizeRole', () => {
  it('returns 401 when req.user is not set', () => {
    const middleware = authorizeRole(['admin']);
    const req = {};
    const res = mockRes();
    const next = mockNext();

    middleware(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'NOT_AUTHENTICATED' }),
      }),
    );
  });

  it('returns 403 when user role not in allowed roles', () => {
    const middleware = authorizeRole(['admin']);
    const req = { user: { ...activeUser, role: 'viewer' } };
    const res = mockRes();
    const next = mockNext();

    middleware(req, res, next);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: expect.objectContaining({ code: 'FORBIDDEN' }),
      }),
    );
  });

  it('calls next when user has allowed role', () => {
    const middleware = authorizeRole(['admin', 'manager']);
    const req = { user: activeUser };
    const res = mockRes();
    const next = mockNext();

    middleware(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
  });

  it('handles single role check', () => {
    const middleware = authorizeRole(['admin']);
    const req = { user: activeUser };
    const res = mockRes();
    const next = mockNext();

    middleware(req, res, next);

    expect(next).toHaveBeenCalledTimes(1);
  });
});

describe('optionalAuth', () => {
  it('calls next without user when no token', async () => {
    const req = { headers: {} };
    const res = mockRes();
    const next = mockNext();

    await optionalAuth(req, res, next);

    expect(req.user).toBeUndefined();
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('attaches user when valid token provided', async () => {
    jwt.verify.mockReturnValue({ userId: 1 });
    db._mockLimit.mockResolvedValue([activeUser]);

    const req = { headers: { authorization: 'Bearer valid-token' } };
    const res = mockRes();
    const next = mockNext();

    await optionalAuth(req, res, next);

    expect(req.user).toEqual(activeUser);
    expect(req.token).toBe('valid-token');
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('skips user attachment when user is inactive', async () => {
    jwt.verify.mockReturnValue({ userId: 2 });
    db._mockLimit.mockResolvedValue([{ ...activeUser, isActive: false }]);

    const req = { headers: { authorization: 'Bearer valid-token' } };
    const res = mockRes();
    const next = mockNext();

    await optionalAuth(req, res, next);

    expect(req.user).toBeUndefined();
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('continues without user on invalid token', async () => {
    jwt.verify.mockImplementation(() => { throw new Error('bad'); });

    const req = { headers: { authorization: 'Bearer bad-token' } };
    const res = mockRes();
    const next = mockNext();

    await optionalAuth(req, res, next);

    expect(req.user).toBeUndefined();
    expect(next).toHaveBeenCalledTimes(1);
  });
});

describe('generateAccessToken', () => {
  it('signs a token with userId, email, role', () => {
    jwt.sign.mockReturnValue('signed-access-token');

    const token = generateAccessToken(activeUser);

    expect(token).toBe('signed-access-token');
    expect(jwt.sign).toHaveBeenCalledWith(
      { userId: activeUser.id, email: activeUser.email, role: activeUser.role },
      'test-secret',
      { expiresIn: '1h' },
    );
  });
});

describe('generateRefreshToken', () => {
  it('signs a refresh token with userId and tokenVersion', () => {
    jwt.sign.mockReturnValue('signed-refresh-token');

    const token = generateRefreshToken({ id: 1, tokenVersion: 3 });

    expect(token).toBe('signed-refresh-token');
    expect(jwt.sign).toHaveBeenCalledWith(
      { userId: 1, tokenVersion: 3 },
      'test-refresh-secret',
      { expiresIn: '7d' },
    );
  });

  it('defaults tokenVersion to 1', () => {
    jwt.sign.mockReturnValue('signed-refresh-token');

    generateRefreshToken({ id: 5 });

    expect(jwt.sign).toHaveBeenCalledWith(
      expect.objectContaining({ tokenVersion: 1 }),
      'test-refresh-secret',
      { expiresIn: '7d' },
    );
  });
});
