jest.mock('../src/config/demo-mode', () => {
  let _enabled = false;
  return {
    isDemoMode: () => _enabled,
    getDemoModeConfig: () => ({
      enabled: _enabled,
      demoUserEmail: 'demo@immogestion.app',
      demoUserPassword: 'Demo2025!',
      demoUserRole: 'admin',
    }),
    __setDemoMode: (v) => { _enabled = v; },
  };
});

jest.mock('../src/database/connection', () => ({
  db: {
    select: jest.fn(),
    insert: jest.fn(),
    update: jest.fn(),
  },
}));

jest.mock('../src/auth/jwt.middleware', () => ({
  generateAccessToken: jest.fn(() => 'mock-access-token'),
  generateRefreshToken: jest.fn(() => 'mock-refresh-token'),
}));

const { __setDemoMode } = require('../src/config/demo-mode');
const demoController = require('../src/controllers/demo.controller');
const { db } = require('../src/database/connection');

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  res.setHeader = jest.fn();
  return res;
}

function mockReq(overrides = {}) {
  return { ip: '127.0.0.1', headers: { 'user-agent': 'jest' }, ...overrides };
}

describe('demo.controller', () => {
  let res;

  beforeEach(() => {
    res = mockRes();
    jest.clearAllMocks();
    db.select.mockImplementation(() => ({
      from: jest.fn().mockReturnValue({
        where: jest.fn().mockReturnValue({
          limit: jest.fn().mockResolvedValue([]),
        }),
      }),
    }));
    db.insert.mockImplementation(() => ({
      values: jest.fn().mockResolvedValue(undefined),
      returning: jest.fn().mockResolvedValue([{}]),
    }));
    db.update.mockImplementation(() => ({
      set: jest.fn().mockReturnValue({
        where: jest.fn().mockResolvedValue(undefined),
      }),
    }));
  });

  describe('demoLogin', () => {
    it('returns 403 when demo mode is disabled', async () => {
      __setDemoMode(false);
      await demoController.demoLogin(mockReq(), res);
      expect(res.status).toHaveBeenCalledWith(403);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: false,
          error: expect.objectContaining({ code: 'DEMO_MODE_DISABLED' }),
        }),
      );
    });

    it('creates demo user and returns tokens when user does not exist', async () => {
      __setDemoMode(true);

      const createdUser = {
        id: 'user-1', email: 'demo@immogestion.app', firstName: 'Demo',
        lastName: 'Utilisateur', role: 'admin', isActive: true,
        emailVerified: true, tokenVersion: 1, phone: null,
        lastLogin: null, createdAt: new Date(), updatedAt: new Date(),
      };

      db.select.mockImplementation(() => ({
        from: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            limit: jest.fn().mockResolvedValue([]),
          }),
        }),
      }));

      db.insert.mockImplementationOnce(() => ({
        values: jest.fn().mockReturnValue({
          returning: jest.fn().mockResolvedValue([createdUser]),
        }),
      }));

      db.insert.mockImplementationOnce(() => ({
        values: jest.fn().mockResolvedValue(undefined),
      }));

      await demoController.demoLogin(mockReq(), res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Demo login successful',
        }),
      );
      const data = res.json.mock.calls[0][0].data;
      expect(data.tokens.accessToken).toBe('mock-access-token');
      expect(data.tokens.refreshToken).toBe('mock-refresh-token');
    });

    it('returns tokens for existing demo user', async () => {
      __setDemoMode(true);

      const existingUser = {
        id: 'user-1', email: 'demo@immogestion.app', firstName: 'Demo',
        lastName: 'Utilisateur', role: 'admin', isActive: true,
        emailVerified: true, tokenVersion: 1, phone: null,
        lastLogin: null, createdAt: new Date(), updatedAt: new Date(),
        passwordHash: 'hashed',
      };

      db.select.mockImplementation(() => ({
        from: jest.fn().mockReturnValue({
          where: jest.fn().mockReturnValue({
            limit: jest.fn().mockResolvedValue([existingUser]),
          }),
        }),
      }));

      await demoController.demoLogin(mockReq(), res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: 'Demo login successful',
        }),
      );
    });
  });

  describe('getDemoStatus', () => {
    it('returns demo mode disabled', async () => {
      __setDemoMode(false);
      await demoController.getDemoStatus({}, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            demoMode: false,
            demoUserEmail: null,
          }),
        }),
      );
    });

    it('returns demo mode enabled with config', async () => {
      __setDemoMode(true);
      await demoController.getDemoStatus({}, res);

      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            demoMode: true,
            demoUserEmail: 'demo@immogestion.app',
            writeGuardEnabled: true,
          }),
        }),
      );
    });
  });
});
