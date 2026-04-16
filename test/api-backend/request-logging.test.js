import { describe, it, expect, jest, beforeEach, afterEach } from '@jest/globals';

let createRequestLoggingMiddleware;

beforeEach(async () => {
  jest.resetModules();

  jest.unstable_mockModule('../../services/api-backend/logger.js', () => ({
    default: {
      info: jest.fn(),
      error: jest.fn(),
      warn: jest.fn(),
    },
  }));

  const mod = await import('../../services/api-backend/middleware/request-logging.js');
  createRequestLoggingMiddleware = mod.createRequestLoggingMiddleware;
});

describe('request-logging middleware', () => {
  let middleware;
  let mockReq;
  let mockRes;
  let mockNext;

  beforeEach(() => {
    middleware = createRequestLoggingMiddleware();
    mockNext = jest.fn();

    mockReq = {
      method: 'GET',
      path: '/api/test',
      query: { foo: 'bar' },
      headers: {},
      user: { sub: 'user-123' },
      ip: '127.0.0.1',
      get: jest.fn().mockReturnValue('TestAgent/1.0'),
    };

    mockRes = {
      statusCode: 200,
      setHeader: jest.fn(),
      send: jest.fn().mockImplementation(function (data) {
        this.body = data;
        return this;
      }),
    };
  });

  it('generates a correlation ID when none provided', () => {
    middleware(mockReq, mockRes, mockNext);

    expect(mockReq.correlationId).toMatch(/^req-/);
    expect(mockRes.setHeader).toHaveBeenCalledWith('X-Correlation-ID', mockReq.correlationId);
  });

  it('uses provided X-Correlation-ID header', () => {
    mockReq.headers['x-correlation-id'] = 'my-custom-id';

    middleware(mockReq, mockRes, mockNext);

    expect(mockReq.correlationId).toBe('my-custom-id');
    expect(mockRes.setHeader).toHaveBeenCalledWith('X-Correlation-ID', 'my-custom-id');
  });

  it('calls next() to continue the middleware chain', () => {
    middleware(mockReq, mockRes, mockNext);
    expect(mockNext).toHaveBeenCalledTimes(1);
  });

  it('logs incoming request with correct fields', async () => {
    const logger = (await import('../../services/api-backend/logger.js')).default;

    middleware(mockReq, mockRes, mockNext);

    expect(logger.info).toHaveBeenCalledWith('Incoming request', {
      correlationId: mockReq.correlationId,
      method: 'GET',
      path: '/api/test',
      query: { foo: 'bar' },
      userId: 'user-123',
      ip: '127.0.0.1',
      userAgent: 'TestAgent/1.0',
    });
  });

  it('logs request completion when res.send is called', async () => {
    const logger = (await import('../../services/api-backend/logger.js')).default;

    middleware(mockReq, mockRes, mockNext);

    mockRes.statusCode = 201;
    mockRes.send({ data: 'ok' });

    expect(logger.info).toHaveBeenCalledWith('Request completed', expect.objectContaining({
      correlationId: mockReq.correlationId,
      method: 'GET',
      path: '/api/test',
      statusCode: 201,
      duration: expect.any(Number),
      userId: 'user-123',
      ip: '127.0.0.1',
    }));
  });

  it('sets X-Response-Time header on send', () => {
    middleware(mockReq, mockRes, mockNext);
    mockRes.send({ ok: true });

    const timeCall = mockRes.setHeader.mock.calls.find(
      (c) => c[0] === 'X-Response-Time'
    );
    expect(timeCall).toBeDefined();
    expect(timeCall[1]).toMatch(/^\d+ms$/);
  });

  it('returns res from send for chaining', () => {
    middleware(mockReq, mockRes, mockNext);

    const result = mockRes.send('payload');
    expect(result).toBe(mockRes);
  });

  it('handles missing user object gracefully', async () => {
    const logger = (await import('../../services/api-backend/logger.js')).default;
    delete mockReq.user;

    middleware(mockReq, mockRes, mockNext);

    const incomingCall = logger.info.mock.calls.find(
      (c) => c[0] === 'Incoming request'
    );
    expect(incomingCall[1].userId).toBeUndefined();
  });

  it('duration is a positive number', () => {
    middleware(mockReq, mockRes, mockNext);
    mockRes.send();

    const completedCall = mockRes.setHeader.mock.calls.find(
      (c) => c[0] === 'X-Response-Time'
    );
    const durationMs = parseInt(completedCall[1], 10);
    expect(durationMs).toBeGreaterThanOrEqual(0);
  });
});
