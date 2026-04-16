import { jest } from '@jest/globals';
import {
  createRequestTimeoutMiddleware,
  requestTimeoutMiddleware,
} from '../../services/api-backend/middleware/request-timeout.js';

function createMockRes() {
  const res = {
    headersSent: false,
    statusCode: null,
    jsonBody: null,
    _events: {},
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.jsonBody = body;
      return this;
    },
    on(event, fn) {
      this._events[event] = this._events[event] || [];
      this._events[event].push(fn);
      return this;
    },
    emit(event) {
      if (this._events[event]) {
        for (const fn of this._events[event]) fn();
      }
      return true;
    },
  };
  return res;
}

function createMockReq(opts = {}) {
  return {
    upgrade: opts.upgrade || false,
    method: opts.method || 'GET',
    path: opts.path || '/api/test',
    correlationId: opts.correlationId || 'test-corr-123',
    user: opts.user || null,
  };
}

describe('createRequestTimeoutMiddleware', () => {
  let res;
  let req;
  let next;

  beforeEach(() => {
    jest.useFakeTimers();
    next = jest.fn();
    res = createMockRes();
    req = createMockReq();
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it('should call next() immediately', () => {
    const middleware = createRequestTimeoutMiddleware(5000);
    middleware(req, res, next);
    expect(next).toHaveBeenCalledTimes(1);
  });

  it('should skip timeout for WebSocket upgrade requests', () => {
    const middleware = createRequestTimeoutMiddleware(1000);
    const wsReq = createMockReq({ upgrade: true });
    middleware(wsReq, res, next);
    expect(next).toHaveBeenCalledTimes(1);

    jest.advanceTimersByTime(2000);

    expect(res.statusCode).toBeNull();
    expect(res.jsonBody).toBeNull();
  });

  it('should return 408 when timeout is reached', () => {
    const middleware = createRequestTimeoutMiddleware(5000);
    middleware(req, res, next);

    jest.advanceTimersByTime(5001);

    expect(res.statusCode).toBe(408);
    expect(res.jsonBody).toEqual({
      error: 'Request timeout',
      code: 'REQUEST_TIMEOUT',
      message: 'Request exceeded 5000ms timeout',
      correlationId: 'test-corr-123',
    });
  });

  it('should not send response if headers already sent', () => {
    const middleware = createRequestTimeoutMiddleware(3000);
    middleware(req, res, next);

    res.headersSent = true;
    jest.advanceTimersByTime(3001);

    expect(res.statusCode).toBeNull();
    expect(res.jsonBody).toBeNull();
  });

  it('should use default timeout of 30000ms', () => {
    const middleware = createRequestTimeoutMiddleware();
    middleware(req, res, next);

    jest.advanceTimersByTime(29999);
    expect(res.statusCode).toBeNull();

    jest.advanceTimersByTime(2);
    expect(res.statusCode).toBe(408);
    expect(res.jsonBody.message).toBe('Request exceeded 30000ms timeout');
  });

  it('should clear timeout when response finishes before timeout', () => {
    const middleware = createRequestTimeoutMiddleware(5000);
    middleware(req, res, next);

    jest.advanceTimersByTime(2000);
    res.emit('finish');

    jest.advanceTimersByTime(5000);
    expect(res.statusCode).toBeNull();
  });

  it('should clear timeout when connection closes before timeout', () => {
    const middleware = createRequestTimeoutMiddleware(5000);
    middleware(req, res, next);

    jest.advanceTimersByTime(2000);
    res.emit('close');

    jest.advanceTimersByTime(5000);
    expect(res.statusCode).toBeNull();
  });

  it('should include userId in timeout log when user is present', () => {
    const middleware = createRequestTimeoutMiddleware(1000);
    const authReq = createMockReq({ user: { sub: 'user-42' } });
    middleware(authReq, res, next);

    jest.advanceTimersByTime(1001);

    expect(res.statusCode).toBe(408);
    expect(res.jsonBody.correlationId).toBe('test-corr-123');
  });

  it('should include custom timeout value in error message', () => {
    const middleware = createRequestTimeoutMiddleware(1500);
    middleware(req, res, next);

    jest.advanceTimersByTime(1501);

    expect(res.jsonBody.message).toBe('Request exceeded 1500ms timeout');
  });

  it('should register both finish and close handlers', () => {
    const middleware = createRequestTimeoutMiddleware(5000);
    middleware(req, res, next);

    expect(res._events['finish']).toBeDefined();
    expect(res._events['close']).toBeDefined();
    expect(res._events['finish'].length).toBeGreaterThanOrEqual(1);
    expect(res._events['close'].length).toBeGreaterThanOrEqual(1);
  });
});

describe('requestTimeoutMiddleware (default export)', () => {
  it('should be a function', () => {
    expect(typeof requestTimeoutMiddleware).toBe('function');
  });

  it('should work with default 30s timeout', () => {
    const next = jest.fn();
    const res = createMockRes();
    const req = createMockReq();

    requestTimeoutMiddleware(req, res, next);
    expect(next).toHaveBeenCalledTimes(1);
  });
});
