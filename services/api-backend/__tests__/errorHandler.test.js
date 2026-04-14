const {
  errorHandler,
  setCacheHeaders,
  setCORSHeaders,
} = require('../src/utils/apiResponse');

function mockReqRes(method = 'GET', path = '/test') {
  const res = {
    status: jest.fn().mockReturnThis(),
    json: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
  };
  return { req: { method, path }, res, next: jest.fn() };
}

describe('errorHandler', () => {
  beforeEach(() => {
    jest.spyOn(require('../src/utils/logger'), 'error').mockImplementation(() => {});
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it('returns 500 INTERNAL_ERROR for generic errors', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('Something unexpected');

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Internal server error', code: 'INTERNAL_ERROR' },
    });
  });

  it('uses error.statusCode if provided', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('Custom');
    error.statusCode = 502;

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(502);
  });

  it('returns 400 VALIDATION_ERROR for ValidationError', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('Invalid field');
    error.name = 'ValidationError';
    error.details = [{ field: 'email', message: 'required' }];

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: {
        message: 'Invalid field',
        code: 'VALIDATION_ERROR',
        details: [{ field: 'email', message: 'required' }],
      },
    });
  });

  it('returns 409 DUPLICATE_ENTRY for PG unique violation (23505)', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('dup');
    error.code = '23505';

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(409);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Duplicate entry', code: 'DUPLICATE_ENTRY' },
    });
  });

  it('returns 400 FOREIGN_KEY_VIOLATION for PG FK error (23503)', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('fk');
    error.code = '23503';

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Foreign key constraint violation', code: 'FOREIGN_KEY_VIOLATION' },
    });
  });

  it('returns 401 UNAUTHORIZED for UnauthorizedError', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('bad token');
    error.name = 'UnauthorizedError';

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Unauthorized access', code: 'UNAUTHORIZED' },
    });
  });

  it('returns 404 NOT_FOUND when error message contains "not found"', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('Building not found');

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Building not found', code: 'NOT_FOUND' },
    });
  });

  it('returns 413 FILE_SIZE_EXCEEDED for LIMIT_FILE_SIZE', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('too large');
    error.code = 'LIMIT_FILE_SIZE';

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(413);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'File size exceeds limit', code: 'FILE_SIZE_EXCEEDED' },
    });
  });

  it('returns 429 RATE_LIMIT_EXCEEDED for "too many requests" message', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('too many requests from this IP');

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(429);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Too many requests', code: 'RATE_LIMIT_EXCEEDED' },
    });
  });

  it('logs error with method, path, and stack', () => {
    const logger = require('../src/utils/logger');
    const { req, res, next } = mockReqRes('POST', '/api/leads');
    const error = new Error('test log');

    errorHandler(error, req, res, next);

    expect(logger.error).toHaveBeenCalledWith('test log', expect.objectContaining({
      method: 'POST',
      path: '/api/leads',
    }));
  });
});

describe('setCacheHeaders', () => {
  it('sets default cache headers (max-age=3600, public, no-cache, no-store)', () => {
    const res = { set: jest.fn() };

    setCacheHeaders(res);

    const call = res.set.mock.calls[0];
    expect(call[0]).toBe('Cache-Control');
    expect(call[1]).toContain('max-age=3600');
    expect(call[1]).toContain('public');
    expect(call[1]).toContain('no-cache');
    expect(call[1]).toContain('no-store');
  });

  it('sets private when isPrivate is true', () => {
    const res = { set: jest.fn() };

    setCacheHeaders(res, { isPrivate: true });

    const call = res.set.mock.calls[0];
    expect(call[1]).toContain('private');
    expect(call[1]).not.toContain('public');
  });

  it('includes must-revalidate when set', () => {
    const res = { set: jest.fn() };

    setCacheHeaders(res, { mustRevalidate: true });

    const call = res.set.mock.calls[0];
    expect(call[1]).toContain('must-revalidate');
  });

  it('uses custom maxAge', () => {
    const res = { set: jest.fn() };

    setCacheHeaders(res, { maxAge: 600 });

    const call = res.set.mock.calls[0];
    expect(call[1]).toContain('max-age=600');
  });
});

describe('setCORSHeaders', () => {
  it('sets default CORS headers', () => {
    const res = { set: jest.fn() };

    setCORSHeaders(res);

    expect(res.set).toHaveBeenCalledWith('Access-Control-Allow-Origin', '*');
    expect(res.set).toHaveBeenCalledWith('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, PATCH');
    expect(res.set).toHaveBeenCalledWith('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-Requested-With');
    expect(res.set).toHaveBeenCalledWith('Access-Control-Max-Age', 86400);
  });

  it('sets custom origin', () => {
    const res = { set: jest.fn() };

    setCORSHeaders(res, { origin: 'https://example.com' });

    expect(res.set).toHaveBeenCalledWith('Access-Control-Allow-Origin', 'https://example.com');
  });

  it('sets credentials header when credentials is true', () => {
    const res = { set: jest.fn() };

    setCORSHeaders(res, { credentials: true });

    expect(res.set).toHaveBeenCalledWith('Access-Control-Allow-Credentials', 'true');
  });

  it('does not set credentials header when credentials is false', () => {
    const res = { set: jest.fn() };

    setCORSHeaders(res, { credentials: false });

    const allCalls = res.set.mock.calls.map((c) => c[0]);
    expect(allCalls).not.toContain('Access-Control-Allow-Credentials');
  });
});
