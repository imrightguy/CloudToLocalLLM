const rateLimiters = require('../src/middleware/rateLimiters');

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

  it('authLimiter calls next for requests under limit', (done) => {
    const req = {
      ip: '127.0.0.1',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = {
      set: jest.fn(),
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      getHeader: jest.fn(),
    };
    const next = () => {
      done();
    };

    rateLimiters.authLimiter(req, res, next);
  });

  it('registrationLimiter calls next for requests under limit', (done) => {
    const req = {
      ip: '127.0.0.2',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = {
      set: jest.fn(),
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      getHeader: jest.fn(),
    };
    const next = () => {
      done();
    };

    rateLimiters.registrationLimiter(req, res, next);
  });

  it('passwordChangeLimiter calls next for requests under limit', (done) => {
    const req = {
      ip: '127.0.0.3',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = {
      set: jest.fn(),
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      getHeader: jest.fn(),
    };
    const next = () => {
      done();
    };

    rateLimiters.passwordChangeLimiter(req, res, next);
  });

  it('passwordResetLimiter calls next for requests under limit', (done) => {
    const req = {
      ip: '127.0.0.4',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = {
      set: jest.fn(),
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      getHeader: jest.fn(),
    };
    const next = () => {
      done();
    };

    rateLimiters.passwordResetLimiter(req, res, next);
  });

  it('apiLimiter calls next for requests under limit', (done) => {
    const req = {
      ip: '127.0.0.5',
      headers: {},
      app: { get: jest.fn().mockReturnValue('127.0.0.1') },
    };
    const res = {
      set: jest.fn(),
      status: jest.fn().mockReturnThis(),
      json: jest.fn(),
      getHeader: jest.fn(),
    };
    const next = () => {
      done();
    };

    rateLimiters.apiLimiter(req, res, next);
  });
});
