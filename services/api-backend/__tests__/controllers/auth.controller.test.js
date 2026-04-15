jest.mock('drizzle-orm', () => ({
  eq: jest.fn((col, val) => ({ col, val })),
  and: jest.fn((...conds) => ({ _type: 'and', conds })),
  ne: jest.fn((col, val) => ({ col, val, _type: 'ne' })),
  desc: jest.fn((col) => ({ _type: 'desc', col })),
  sql: jest.fn((strings, ...values) => ({ _type: 'sql', strings, values })),
}));

jest.mock('../../src/auth/jwt.middleware', () => ({
  generateAccessToken: jest.fn(() => 'mock-access-token'),
  generateRefreshToken: jest.fn(() => 'mock-refresh-token'),
}));

jest.mock('../../src/utils/logger', () => ({
  child: jest.fn(() => ({ info: jest.fn(), warn: jest.fn(), error: jest.fn() })),
}));

const bcrypt = require('bcryptjs');

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
      returning: jest.fn(() => Promise.resolve([{ id: 'user-1', email: 'test@test.com' }])),
    }),
  })),
  update: jest.fn(() => ({
    set: jest.fn().mockReturnValue({
      where: jest.fn().mockReturnValue({
        returning: jest.fn(() => Promise.resolve([{ id: 'user-1', email: 'test@test.com' }])),
      }),
    }),
  })),
  delete: jest.fn(() => ({
    where: jest.fn().mockResolvedValue(undefined),
  })),
};

jest.mock('../../src/database/connection', () => ({ db: mockDb }));

jest.mock('../../src/database/schema', () => ({
  usersTable: { id: 'id', email: 'email', passwordHash: 'passwordHash', firstName: 'firstName', lastName: 'lastName', phone: 'phone', role: 'role', isActive: 'isActive', emailVerified: 'emailVerified', tokenVersion: 'tokenVersion', lastLogin: 'lastLogin', createdAt: 'createdAt', updatedAt: 'updatedAt' },
  refreshTokensTable: { id: 'id', userId: 'userId', token: 'token', expiresAt: 'expiresAt', ip: 'ip', userAgent: 'userAgent', tokenVersion: 'tokenVersion' },
}));

const authController = require('../../src/controllers/auth.controller');
const { db: _db } = require('../../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

const mockUser = {
  id: 'user-1',
  email: 'test@test.com',
  firstName: 'John',
  lastName: 'Doe',
  phone: '+15145551234',
  role: 'admin',
  isActive: true,
  emailVerified: true,
  tokenVersion: 1,
  passwordHash: '$2a$12$hash',
};

beforeEach(() => {
  jest.clearAllMocks();
  selectChain = mockSelectChain();
  jest.spyOn(bcrypt, 'hash').mockResolvedValue('hashed-password');
  jest.spyOn(bcrypt, 'compare').mockResolvedValue(true);
});

// ═══════════════════════════════════════════════════════════════════
// register
// ═══════════════════════════════════════════════════════════════════
describe('register', () => {
  it('returns 400 when email is missing', async () => {
    const res = mockRes();
    await authController.register({ body: { password: 'pass', firstName: 'J', lastName: 'D' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: false,
      error: expect.objectContaining({ code: 'MISSING_REQUIRED_FIELDS' }),
    }));
  });

  it('returns 400 when password is missing', async () => {
    const res = mockRes();
    await authController.register({ body: { email: 'e@e.com', firstName: 'J', lastName: 'D' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 409 when email already exists', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'existing' }]);
    const res = mockRes();
    await authController.register({ body: { email: 'test@test.com', password: 'pass123', firstName: 'J', lastName: 'D' } }, res);
    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'USER_ALREADY_EXISTS' }),
    }));
  });

  it('registers a new user successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([{ id: 'user-1', email: 'new@test.com' }]),
      }),
    });
    const res = mockRes();
    await authController.register({
      body: { email: 'new@test.com', password: 'pass123', firstName: 'John', lastName: 'Doe', phone: '+15145551234' },
      ip: '127.0.0.1',
      headers: { 'user-agent': 'test' },
    }, res);
    expect(res.status).toHaveBeenCalledWith(201);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        user: expect.objectContaining({ email: 'new@test.com' }),
        tokens: expect.objectContaining({ tokenType: 'Bearer' }),
      }),
    }));
  });

  it('returns 500 when user creation fails', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    mockDb.insert.mockReturnValueOnce({
      values: jest.fn().mockReturnValue({
        returning: jest.fn().mockResolvedValue([]),
      }),
    });
    const res = mockRes();
    await authController.register({ body: { email: 'fail@test.com', password: 'pass123', firstName: 'J', lastName: 'D' } }, res);
    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'USER_CREATION_FAILED' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// login
// ═══════════════════════════════════════════════════════════════════
describe('login', () => {
  it('returns 400 when email or password is missing', async () => {
    const res = mockRes();
    await authController.login({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'MISSING_CREDENTIALS' }),
    }));
  });

  it('returns 401 when user not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await authController.login({ body: { email: 'nobody@test.com', password: 'pass' } }, res);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'INVALID_CREDENTIALS' }),
    }));
  });

  it('returns 401 when account is inactive', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ ...mockUser, isActive: false }]);
    const res = mockRes();
    await authController.login({ body: { email: 'inactive@test.com', password: 'pass' } }, res);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'ACCOUNT_INACTIVE' }),
    }));
  });

  it('returns 401 when password is incorrect', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([mockUser]);
    bcrypt.compare.mockResolvedValueOnce(false);
    const res = mockRes();
    await authController.login({ body: { email: 'test@test.com', password: 'wrong' } }, res);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'INVALID_CREDENTIALS' }),
    }));
  });

  it('logs in successfully and returns tokens', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([mockUser]);
    const res = mockRes();
    await authController.login({
      body: { email: 'test@test.com', password: 'pass123' },
      ip: '127.0.0.1',
      headers: { 'user-agent': 'test' },
    }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        user: expect.objectContaining({ email: 'test@test.com' }),
        tokens: expect.objectContaining({ tokenType: 'Bearer' }),
      }),
    }));
    expect(bcrypt.compare).toHaveBeenCalledWith('pass123', mockUser.passwordHash);
  });
});

// ═══════════════════════════════════════════════════════════════════
// refreshAccessToken
// ═══════════════════════════════════════════════════════════════════
describe('refreshAccessToken', () => {
  it('returns 400 when refreshToken is missing', async () => {
    const res = mockRes();
    await authController.refreshAccessToken({ body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'REFRESH_TOKEN_REQUIRED' }),
    }));
  });

  it('returns 401 when refresh token is invalid', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await authController.refreshAccessToken({ body: { refreshToken: 'bad-token' } }, res);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'INVALID_REFRESH_TOKEN' }),
    }));
  });

  it('returns 401 when refresh token is expired', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'token-1', userId: 'user-1', expiresAt: '2020-01-01' }]);
    const res = mockRes();
    await authController.refreshAccessToken({ body: { refreshToken: 'expired-token' } }, res);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'REFRESH_TOKEN_EXPIRED' }),
    }));
  });

  it('returns 401 when user not found or inactive', async () => {
    selectChain.from.mockReturnValue(selectChain);
    const futureDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    selectChain.limit.mockResolvedValueOnce([{ id: 'token-1', userId: 'user-1', expiresAt: futureDate, tokenVersion: 1 }]);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await authController.refreshAccessToken({ body: { refreshToken: 'valid-token' } }, res);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'USER_NOT_FOUND' }),
    }));
  });

  it('returns 401 on token version mismatch', async () => {
    selectChain.from.mockReturnValue(selectChain);
    const futureDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    selectChain.limit.mockResolvedValueOnce([{ id: 'token-1', userId: 'user-1', expiresAt: futureDate, tokenVersion: 1 }]);
    selectChain.limit.mockResolvedValueOnce([{ ...mockUser, tokenVersion: 5 }]);
    const res = mockRes();
    await authController.refreshAccessToken({ body: { refreshToken: 'stale-token' } }, res);
    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'TOKEN_VERSION_MISMATCH' }),
    }));
  });

  it('rotates tokens successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    const futureDate = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString();
    selectChain.limit.mockResolvedValueOnce([{ id: 'token-1', userId: 'user-1', expiresAt: futureDate, tokenVersion: 1 }]);
    selectChain.limit.mockResolvedValueOnce([mockUser]);
    const res = mockRes();
    await authController.refreshAccessToken({
      body: { refreshToken: 'valid-token' },
      ip: '127.0.0.1',
      headers: { 'user-agent': 'test' },
    }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        tokens: expect.objectContaining({ tokenType: 'Bearer' }),
      }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// logout
// ═══════════════════════════════════════════════════════════════════
describe('logout', () => {
  it('returns success without refreshToken', async () => {
    const res = mockRes();
    await authController.logout({ body: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'Logged out successfully',
    }));
  });

  it('returns success even on DB error', async () => {
    mockDb.delete.mockImplementationOnce(() => {
      throw new Error('DB down');
    });
    const res = mockRes();
    await authController.logout({ body: { refreshToken: 'token' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
    }));
  });

  it('deletes all user tokens when authenticated', async () => {
    const res = mockRes();
    await authController.logout({ body: { refreshToken: 'token' }, user: { id: 'user-1' } }, res);
    expect(mockDb.delete).toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ success: true }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// getProfile
// ═══════════════════════════════════════════════════════════════════
describe('getProfile', () => {
  it('returns 404 when user not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await authController.getProfile({ user: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'USER_NOT_FOUND' }),
    }));
  });

  it('returns user profile', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([mockUser]);
    const res = mockRes();
    await authController.getProfile({ user: { id: 'user-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ email: 'test@test.com' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateProfile
// ═══════════════════════════════════════════════════════════════════
describe('updateProfile', () => {
  it('returns 400 when no fields to update', async () => {
    const res = mockRes();
    await authController.updateProfile({ body: {}, user: { id: 'user-1', email: 'test@test.com' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'NO_FIELDS_TO_UPDATE' }),
    }));
  });

  it('returns 409 when email is already taken', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'other-user' }]);
    const res = mockRes();
    await authController.updateProfile({ body: { email: 'taken@test.com' }, user: { id: 'user-1', email: 'old@test.com' } }, res);
    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'EMAIL_ALREADY_TAKEN' }),
    }));
  });

  it('updates profile successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ ...mockUser, firstName: 'Jane' }]),
        }),
      }),
    });
    const res = mockRes();
    await authController.updateProfile({ body: { firstName: 'Jane' }, user: { id: 'user-1', email: 'test@test.com' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ firstName: 'Jane' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// changePassword
// ═══════════════════════════════════════════════════════════════════
describe('changePassword', () => {
  it('returns 400 when fields missing', async () => {
    const res = mockRes();
    await authController.changePassword({ body: {}, user: { id: 'user-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'MISSING_PASSWORD_FIELDS' }),
    }));
  });

  it('returns 400 when new password is too short', async () => {
    const res = mockRes();
    await authController.changePassword({ body: { currentPassword: 'old', newPassword: 'short' }, user: { id: 'user-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'WEAK_PASSWORD' }),
    }));
  });

  it('returns 404 when user not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await authController.changePassword({ body: { currentPassword: 'old', newPassword: 'newpass123' }, user: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'USER_NOT_FOUND' }),
    }));
  });

  it('returns 400 when current password is incorrect', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'user-1', passwordHash: 'hash', tokenVersion: 1 }]);
    bcrypt.compare.mockResolvedValueOnce(false);
    const res = mockRes();
    await authController.changePassword({ body: { currentPassword: 'wrong', newPassword: 'newpass123' }, user: { id: 'user-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'INVALID_CURRENT_PASSWORD' }),
    }));
  });

  it('changes password successfully and invalidates sessions', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'user-1', passwordHash: 'hash', tokenVersion: 1 }]);
    const res = mockRes();
    await authController.changePassword({ body: { currentPassword: 'oldpass', newPassword: 'newpass1234' }, user: { id: 'user-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: expect.stringContaining('Password changed'),
    }));
    expect(bcrypt.hash).toHaveBeenCalledWith('newpass1234', expect.any(Number));
    expect(mockDb.delete).toHaveBeenCalled();
  });
});

// ═══════════════════════════════════════════════════════════════════
// getAllUsers
// ═══════════════════════════════════════════════════════════════════
describe('getAllUsers', () => {
  it('returns paginated users', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.from.mockResolvedValueOnce([{ count: 1 }]);
    selectChain.offset.mockResolvedValueOnce([mockUser]);
    const res = mockRes();
    await authController.getAllUsers({ query: {} }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({
        users: [mockUser],
        pagination: expect.objectContaining({
          total: 1,
          page: 1,
          limit: 20,
        }),
      }),
    }));
  });

  it('applies page and limit from query', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.from.mockResolvedValueOnce([{ count: 50 }]);
    selectChain.offset.mockResolvedValueOnce([]);
    const res = mockRes();
    await authController.getAllUsers({ query: { page: '3', limit: '10' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      data: expect.objectContaining({
        pagination: expect.objectContaining({ page: 3, limit: 10 }),
      }),
    }));
  });

  it('returns 500 on DB error', async () => {
    selectChain.from.mockImplementation(() => { throw new Error('DB down'); });
    const res = mockRes();
    await authController.getAllUsers({ query: {} }, res);
    expect(res.status).toHaveBeenCalledWith(500);
  });
});

// ═══════════════════════════════════════════════════════════════════
// getUserById
// ═══════════════════════════════════════════════════════════════════
describe('getUserById', () => {
  it('returns 404 when user not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    const res = mockRes();
    await authController.getUserById({ params: { id: 'nonexistent' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'USER_NOT_FOUND' }),
    }));
  });

  it('returns user by id', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([mockUser]);
    const res = mockRes();
    await authController.getUserById({ params: { id: 'user-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: mockUser,
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// updateUser
// ═══════════════════════════════════════════════════════════════════
describe('updateUser', () => {
  it('returns 400 when no fields to update', async () => {
    const res = mockRes();
    await authController.updateUser({ params: { id: 'user-1' }, body: {} }, res);
    expect(res.status).toHaveBeenCalledWith(400);
  });

  it('returns 409 when email is taken', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([{ id: 'other' }]);
    const res = mockRes();
    await authController.updateUser({ params: { id: 'user-1' }, body: { email: 'taken@test.com' } }, res);
    expect(res.status).toHaveBeenCalledWith(409);
  });

  it('returns 404 when user not found', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([]),
        }),
      }),
    });
    const res = mockRes();
    await authController.updateUser({ params: { id: 'user-1' }, body: { firstName: 'New' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('updates user successfully', async () => {
    selectChain.from.mockReturnValue(selectChain);
    selectChain.limit.mockResolvedValueOnce([]);
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ ...mockUser, firstName: 'Updated' }]),
        }),
      }),
    });
    const res = mockRes();
    await authController.updateUser({ params: { id: 'user-1' }, body: { firstName: 'Updated' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      data: expect.objectContaining({ firstName: 'Updated' }),
    }));
  });
});

// ═══════════════════════════════════════════════════════════════════
// deleteUser
// ═══════════════════════════════════════════════════════════════════
describe('deleteUser', () => {
  it('returns 400 when trying to delete self', async () => {
    const res = mockRes();
    await authController.deleteUser({ params: { id: 'user-1' }, user: { id: 'user-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      error: expect.objectContaining({ code: 'CANNOT_DELETE_SELF' }),
    }));
  });

  it('returns 404 when user not found', async () => {
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([]),
        }),
      }),
    });
    const res = mockRes();
    await authController.deleteUser({ params: { id: 'nonexistent' }, user: { id: 'admin-1' } }, res);
    expect(res.status).toHaveBeenCalledWith(404);
  });

  it('deactivates user successfully', async () => {
    mockDb.update.mockReturnValueOnce({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([{ id: 'user-1' }]),
        }),
      }),
    });
    const res = mockRes();
    await authController.deleteUser({ params: { id: 'user-1' }, user: { id: 'admin-1' } }, res);
    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({
      success: true,
      message: 'User deactivated successfully',
    }));
    expect(mockDb.delete).toHaveBeenCalled();
  });
});
