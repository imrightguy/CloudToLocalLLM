const rateLimiters = require('../src/middleware/rateLimiters');

function mockRes() {
  const res = {
    set: jest.fn(),
    status: jest.fn().mockReturnThis(),
    json: jest.fn(),
    getHeader: jest.fn(),
    once: jest.fn(),
  };
  return res;
}

describe('rate limiters', () => {
  it('exports all expected limiters', () => {
    expect(rateLimiters.authLimiter).toBeDefined();
    expect(rateLimiters.registrationLimiter).toBeDefined();
    expect(rateLimiters.passwordChangeLimiter).toBeDefined();
    expect(rateLimiters.passwordResetLimiter).toBeDefined();
    expect(rateLimiters.apiLimiter).toBeDefined();
  });

  it('each limiter is a function (middleware)', () => {
    const { authLimiter, registrationLimiter, passwordChangeLimiter, passwordResetLimiter, apiLimiter } = rateLimiters;

    expect(typeof authLimiter).toBe('function');
    expect(typeof registrationLimiter).toBe('function');
    expect(typeof passwordChangeLimiter).toBe('function');
    expect(typeof passwordResetLimiter).toBe('function');
    expect(typeof apiLimiter).toBe('function');
  });

  it('authLimiter calls next for requests under limit', () => {
    const req = {
      ip: '127.0.0.1',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = mockRes();

    return new Promise((resolve) => {
      rateLimiters.authLimiter(req, res, () => {
        resolve();
      });
    });
  });

  it('registrationLimiter calls next for requests under limit', () => {
    const req = {
      ip: '127.0.0.2',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = mockRes();

    return new Promise((resolve) => {
      rateLimiters.registrationLimiter(req, res, () => {
        resolve();
      });
    });
  });

  it('passwordChangeLimiter calls next for requests under limit', () => {
    const req = {
      ip: '127.0.0.3',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = mockRes();

    return new Promise((resolve) => {
      rateLimiters.passwordChangeLimiter(req, res, () => {
        resolve();
      });
    });
  });

  it('passwordResetLimiter calls next for requests under limit', () => {
    const req = {
      ip: '127.0.0.4',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = mockRes();

    return new Promise((resolve) => {
      rateLimiters.passwordResetLimiter(req, res, () => {
        resolve();
      });
    });
  });

  it('apiLimiter calls next for requests under limit', () => {
    const req = {
      ip: '127.0.0.5',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = mockRes();

    return new Promise((resolve) => {
      rateLimiters.apiLimiter(req, res, () => {
        resolve();
      });
    });
  });
});
