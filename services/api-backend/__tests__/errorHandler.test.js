const {
  errorHandler,
  setCacheHeaders,
  setCORSHeaders,
} = require('../src/utils/apiResponse');
const AppError = require('../src/middleware/AppError');

const originalEnv = process.env.NODE_ENV;

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
    process.env.NODE_ENV = originalEnv;
  });

  it('returns 500 INTERNAL_ERROR for generic errors', () => {
    process.env.NODE_ENV = 'production';
    const { req, res, next } = mockReqRes();
    const error = new Error('Something unexpected');

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(500);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Internal server error', code: 'INTERNAL_ERROR' },
    });
  });

  it('hides error details in production', () => {
    process.env.NODE_ENV = 'production';
    const { req, res, next } = mockReqRes();
    const error = new Error('Something unexpected');

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(500);
    const response = res.json.mock.calls[0][0];
    expect(response.error.message).toBe('Internal server error');
    expect(response.error.stack).toBeUndefined();
  });

  it('includes stack trace in development', () => {
    process.env.NODE_ENV = 'development';
    const { req, res, next } = mockReqRes();
    const error = new Error('Something unexpected');

    errorHandler(error, req, res, next);

    const response = res.json.mock.calls[0][0];
    expect(response.error.message).toBe('Something unexpected');
    expect(response.error.stack).toBeDefined();
  });

  it('handles AppError with statusCode and code', () => {
    const { req, res, next } = mockReqRes();
    const error = AppError.notFound({ message: 'User not found', code: 'USER_NOT_FOUND' });

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(404);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'User not found', code: 'USER_NOT_FOUND' },
    });
  });

  it('handles AppError with details', () => {
    const { req, res, next } = mockReqRes();
    const error = AppError.validationError({
      message: 'Validation failed',
      details: [{ field: 'email', message: 'Invalid email' }],
    });

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    const response = res.json.mock.calls[0][0];
    expect(response.error.details).toEqual([{ field: 'email', message: 'Invalid email' }]);
  });

  it('handles AppError.badRequest', () => {
    const { req, res, next } = mockReqRes();
    const error = AppError.badRequest({ message: 'Missing fields' });

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Missing fields', code: 'BAD_REQUEST' },
    });
  });

  it('handles AppError.tooManyRequests', () => {
    const { req, res, next } = mockReqRes();
    const error = AppError.tooManyRequests({ message: 'Slow down' });

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(429);
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

  it('returns 400 INVALID_JSON for malformed JSON body', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('Unexpected token');
    error.type = 'entity.parse.failed';

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Malformed JSON in request body', code: 'INVALID_JSON' },
    });
  });

  it('returns 413 PAYLOAD_TOO_LARGE for large payloads', () => {
    const { req, res, next } = mockReqRes();
    const error = new Error('request entity too large');
    error.type = 'entity.too.large';

    errorHandler(error, req, res, next);

    expect(res.status).toHaveBeenCalledWith(413);
    expect(res.json).toHaveBeenCalledWith({
      success: false,
      error: { message: 'Request payload too large', code: 'PAYLOAD_TOO_LARGE' },
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

  it('logs isOperational flag for AppError', () => {
    const logger = require('../src/utils/logger');
    const { req, res, next } = mockReqRes();
    const error = AppError.badRequest({ message: 'test' });

    errorHandler(error, req, res, next);

    expect(logger.error).toHaveBeenCalledWith(expect.any(String), expect.objectContaining({
      isOperational: true,
      code: 'BAD_REQUEST',
    }));
  });
});

describe('setCacheHeaders', () => {
  it('sets cacheable default headers (max-age=3600, public) without contradictory no-store', () => {
    const res = { set: jest.fn() };

    setCacheHeaders(res);

    const call = res.set.mock.calls[0];
    expect(call[0]).toBe('Cache-Control');
    expect(call[1]).toContain('max-age=3600');
    expect(call[1]).toContain('public');
    // max-age and no-store are mutually exclusive — the default must not mix them.
    expect(call[1]).not.toContain('no-store');
  });

  it('emits no-store (and no max-age) when noStore is true', () => {
    const res = { set: jest.fn() };

    setCacheHeaders(res, { noStore: true });

    const call = res.set.mock.calls[0];
    expect(call[1]).toContain('no-store');
    expect(call[1]).not.toContain('max-age');
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
  it('defaults the origin to the ALLOWED_ORIGINS allow-list, never a wildcard', () => {
    const res = { set: jest.fn() };
    const prev = process.env.ALLOWED_ORIGINS;
    process.env.ALLOWED_ORIGINS = 'https://app.example.com,https://admin.example.com';

    try {
      setCORSHeaders(res);
    } finally {
      if (prev === undefined) {
        delete process.env.ALLOWED_ORIGINS;
      } else {
        process.env.ALLOWED_ORIGINS = prev;
      }
    }

    expect(res.set).toHaveBeenCalledWith('Access-Control-Allow-Origin', 'https://app.example.com');
    expect(res.set).not.toHaveBeenCalledWith('Access-Control-Allow-Origin', '*');
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
