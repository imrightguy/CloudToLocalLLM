import { jest } from '@jest/globals';
import {
  TunnelLogger,
  ErrorResponseBuilder,
  ERROR_CODES,
  HTTP_STATUS_CODES,
  LOG_LEVELS,
  logger,
} from '../../services/api-backend/utils/logger.js';

describe('utils/logger', () => {
  describe('exports', () => {
    it('exports LOG_LEVELS with expected keys', () => {
      expect(LOG_LEVELS).toEqual({
        ERROR: 'error',
        WARN: 'warn',
        INFO: 'info',
        DEBUG: 'debug',
      });
    });

    it('exports ERROR_CODES with expected keys', () => {
      expect(ERROR_CODES).toHaveProperty('AUTH_TOKEN_MISSING');
      expect(ERROR_CODES).toHaveProperty('INTERNAL_SERVER_ERROR');
      expect(ERROR_CODES).toHaveProperty('REQUEST_TIMEOUT');
    });

    it('exports HTTP_STATUS_CODES with expected values', () => {
      expect(HTTP_STATUS_CODES.BAD_REQUEST).toBe(400);
      expect(HTTP_STATUS_CODES.UNAUTHORIZED).toBe(401);
      expect(HTTP_STATUS_CODES.INTERNAL_SERVER_ERROR).toBe(500);
    });

    it('exports a default logger instance', () => {
      expect(logger).toBeInstanceOf(TunnelLogger);
    });
  });

  describe('TunnelLogger', () => {
    let tunnelLogger;

    beforeEach(() => {
      tunnelLogger = new TunnelLogger('test-service');
    });

    describe('constructor', () => {
      it('sets service name', () => {
        expect(tunnelLogger.service).toBe('test-service');
      });

      it('defaults to "tunnel-system" service name', () => {
        const defaultLogger = new TunnelLogger();
        expect(defaultLogger.service).toBe('tunnel-system');
      });

      it('creates a winston logger', () => {
        expect(tunnelLogger.logger).toBeDefined();
        expect(typeof tunnelLogger.logger.info).toBe('function');
      });
    });

    describe('hashUserId', () => {
      it('returns null for falsy userId', () => {
        expect(tunnelLogger.hashUserId(null)).toBeNull();
        expect(tunnelLogger.hashUserId(undefined)).toBeNull();
        expect(tunnelLogger.hashUserId('')).toBeNull();
      });

      it('returns prefixed hash for valid userId', () => {
        const result = tunnelLogger.hashUserId('user-123-abc');
        expect(result).toMatch(/^user-123\.\.\.[a-f0-9]{8}$/);
      });

      it('produces consistent hashes for the same input', () => {
        const a = tunnelLogger.hashUserId('my-user');
        const b = tunnelLogger.hashUserId('my-user');
        expect(a).toBe(b);
      });
    });

    describe('generateCorrelationId', () => {
      it('returns a UUID string', () => {
        const id = tunnelLogger.generateCorrelationId();
        expect(id).toMatch(
          /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/,
        );
      });

      it('returns unique ids', () => {
        const a = tunnelLogger.generateCorrelationId();
        const b = tunnelLogger.generateCorrelationId();
        expect(a).not.toBe(b);
      });
    });

    describe('info', () => {
      it('calls winston info', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'info');
        tunnelLogger.info('test message', { key: 'val' });
        expect(spy).toHaveBeenCalledWith('test message', { key: 'val' });
        spy.mockRestore();
      });

      it('defaults meta to empty object', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'info');
        tunnelLogger.info('hello');
        expect(spy).toHaveBeenCalledWith('hello', {});
        spy.mockRestore();
      });
    });

    describe('debug', () => {
      it('calls winston debug', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'debug');
        tunnelLogger.debug('debug msg');
        expect(spy).toHaveBeenCalledWith('debug msg', {});
        spy.mockRestore();
      });
    });

    describe('warn', () => {
      it('calls winston warn', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'warn');
        tunnelLogger.warn('warning msg');
        expect(spy).toHaveBeenCalledWith('warning msg', {});
        spy.mockRestore();
      });
    });

    describe('error', () => {
      it('logs Error objects with structured fields', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'error');
        const err = new Error('boom');
        err.code = 'E_FAIL';
        tunnelLogger.error('something failed', err);
        expect(spy).toHaveBeenCalledWith(
          'something failed',
          expect.objectContaining({
            error: expect.objectContaining({
              name: 'Error',
              message: 'boom',
              code: 'E_FAIL',
            }),
          }),
        );
        spy.mockRestore();
      });

      it('logs plain objects as error meta', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'error');
        tunnelLogger.error('fail', { reason: 'timeout' });
        expect(spy).toHaveBeenCalledWith(
          'fail',
          expect.objectContaining({ error: { reason: 'timeout' } }),
        );
        spy.mockRestore();
      });

      it('merges additional meta with error info', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'error');
        const err = new Error('nope');
        tunnelLogger.error('failed', err, { requestId: 'r1' });
        expect(spy).toHaveBeenCalledWith(
          'failed',
          expect.objectContaining({
            requestId: 'r1',
            error: expect.objectContaining({ message: 'nope' }),
          }),
        );
        spy.mockRestore();
      });

      it('defaults error and meta to empty objects', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'error');
        tunnelLogger.error('oops');
        expect(spy).toHaveBeenCalledWith('oops', { error: {} });
        spy.mockRestore();
      });
    });

    describe('logConnection', () => {
      it('logs connection events with metadata', () => {
        const spy = jest.spyOn(tunnelLogger, 'info');
        tunnelLogger.logConnection('connected', 'conn-1', 'user-1', {
          ip: '10.0.0.1',
        });
        expect(spy).toHaveBeenCalledWith('Connection connected', {
          event: 'connection',
          connectionEvent: 'connected',
          connectionId: 'conn-1',
          userId: 'user-1',
          ip: '10.0.0.1',
        });
        spy.mockRestore();
      });

      it('defaults meta to empty object', () => {
        const spy = jest.spyOn(tunnelLogger, 'info');
        tunnelLogger.logConnection('disconnected', 'c2', 'u2');
        expect(spy).toHaveBeenCalledWith('Connection disconnected', {
          event: 'connection',
          connectionEvent: 'disconnected',
          connectionId: 'c2',
          userId: 'u2',
        });
        spy.mockRestore();
      });
    });

    describe('logRequest', () => {
      it('logs "failed" events as warn', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'warn');
        tunnelLogger.logRequest('failed', 'req-1', 'user-1');
        expect(spy).toHaveBeenCalledWith('Request failed', {
          event: 'request',
          requestEvent: 'failed',
          correlationId: 'req-1',
          userId: 'user-1',
        });
        spy.mockRestore();
      });

      it('logs "timeout" events as warn', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'warn');
        tunnelLogger.logRequest('timeout', 'req-2', 'user-2');
        expect(spy).toHaveBeenCalledWith('Request timeout', {
          event: 'request',
          requestEvent: 'timeout',
          correlationId: 'req-2',
          userId: 'user-2',
        });
        spy.mockRestore();
      });

      it('logs "started" events as info', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'info');
        tunnelLogger.logRequest('started', 'req-3', 'user-3');
        expect(spy).toHaveBeenCalledWith('Request started', {
          event: 'request',
          requestEvent: 'started',
          correlationId: 'req-3',
          userId: 'user-3',
        });
        spy.mockRestore();
      });

      it('logs "completed" events as info', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'info');
        tunnelLogger.logRequest('completed', 'req-4', 'user-4', {
          duration: 120,
        });
        expect(spy).toHaveBeenCalledWith('Request completed', {
          event: 'request',
          requestEvent: 'completed',
          correlationId: 'req-4',
          userId: 'user-4',
          duration: 120,
        });
        spy.mockRestore();
      });
    });

    describe('logTunnelError', () => {
      it('logs tunnel errors with errorCode and context', () => {
        const spy = jest.spyOn(tunnelLogger, 'error');
        tunnelLogger.logTunnelError(ERROR_CODES.AUTH_TOKEN_MISSING, 'no token', {
          ip: '1.2.3.4',
        });
        expect(spy).toHaveBeenCalledWith('Tunnel error: no token', {
          event: 'tunnel_error',
          errorCode: ERROR_CODES.AUTH_TOKEN_MISSING,
          ip: '1.2.3.4',
        });
        spy.mockRestore();
      });

      it('defaults context to empty object', () => {
        const spy = jest.spyOn(tunnelLogger, 'error');
        tunnelLogger.logTunnelError(ERROR_CODES.INTERNAL_SERVER_ERROR, 'crash');
        expect(spy).toHaveBeenCalledWith('Tunnel error: crash', {
          event: 'tunnel_error',
          errorCode: ERROR_CODES.INTERNAL_SERVER_ERROR,
        });
        spy.mockRestore();
      });
    });

    describe('logPerformance', () => {
      it('logs performance metrics', () => {
        const spy = jest.spyOn(tunnelLogger, 'info');
        tunnelLogger.logPerformance('db_query', 42, { rows: 10 });
        expect(spy).toHaveBeenCalledWith('Performance: db_query', {
          event: 'performance',
          operation: 'db_query',
          duration: 42,
          rows: 10,
        });
        spy.mockRestore();
      });

      it('defaults meta to empty object', () => {
        const spy = jest.spyOn(tunnelLogger, 'info');
        tunnelLogger.logPerformance('cache_hit', 1);
        expect(spy).toHaveBeenCalledWith('Performance: cache_hit', {
          event: 'performance',
          operation: 'cache_hit',
          duration: 1,
        });
        spy.mockRestore();
      });
    });

    describe('logSecurity', () => {
      it('logs security events as warn', () => {
        const spy = jest.spyOn(tunnelLogger, 'warn');
        tunnelLogger.logSecurity('login_failed', 'user-1', { ip: '5.5.5.5' });
        expect(spy).toHaveBeenCalledWith('Security event: login_failed', {
          event: 'security',
          securityEvent: 'login_failed',
          userId: 'user-1',
          ip: '5.5.5.5',
        });
        spy.mockRestore();
      });

      it('defaults meta to empty object', () => {
        const spy = jest.spyOn(tunnelLogger, 'warn');
        tunnelLogger.logSecurity('token_refresh', 'user-2');
        expect(spy).toHaveBeenCalledWith('Security event: token_refresh', {
          event: 'security',
          securityEvent: 'token_refresh',
          userId: 'user-2',
        });
        spy.mockRestore();
      });
    });

    describe('child', () => {
      it('returns a new TunnelLogger', () => {
        const child = tunnelLogger.child({ requestId: 'r1' });
        expect(child).toBeInstanceOf(TunnelLogger);
        expect(child.service).toBe('test-service');
      });

      it('creates a child winston logger', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'child');
        tunnelLogger.child({ requestId: 'r1' });
        expect(spy).toHaveBeenCalledWith({ requestId: 'r1' });
        spy.mockRestore();
      });

      it('defaults context to empty object', () => {
        const spy = jest.spyOn(tunnelLogger.logger, 'child');
        tunnelLogger.child();
        expect(spy).toHaveBeenCalledWith({});
        spy.mockRestore();
      });
    });
  });

  describe('ErrorResponseBuilder', () => {
    describe('createErrorResponse', () => {
      it('creates a structured error response', () => {
        const resp = ErrorResponseBuilder.createErrorResponse(
          'CODE',
          'msg',
          400,
          { detail: 'extra' },
        );
        expect(resp).toEqual({
          error: {
            code: 'CODE',
            message: 'msg',
            timestamp: expect.stringMatching(/^\d{4}-\d{2}-\d{2}T/),
            detail: 'extra',
          },
        });
      });

      it('defaults details to empty object', () => {
        const resp = ErrorResponseBuilder.createErrorResponse('X', 'y', 500);
        expect(resp.error).toEqual({
          code: 'X',
          message: 'y',
          timestamp: expect.any(String),
        });
      });
    });

    describe('authenticationError', () => {
      it('returns 401 with defaults', () => {
        const resp = ErrorResponseBuilder.authenticationError();
        expect(resp.error.code).toBe(ERROR_CODES.AUTH_TOKEN_MISSING);
        expect(resp.error.message).toBe('Authentication required');
      });

      it('accepts custom message and code', () => {
        const resp = ErrorResponseBuilder.authenticationError(
          'Bad token',
          ERROR_CODES.AUTH_TOKEN_INVALID,
        );
        expect(resp.error.code).toBe(ERROR_CODES.AUTH_TOKEN_INVALID);
        expect(resp.error.message).toBe('Bad token');
      });
    });

    describe('serviceUnavailableError', () => {
      it('returns 503 with defaults', () => {
        const resp = ErrorResponseBuilder.serviceUnavailableError();
        expect(resp.error.code).toBe(ERROR_CODES.DESKTOP_CLIENT_DISCONNECTED);
        expect(resp.error.message).toBe('Service temporarily unavailable');
      });

      it('accepts custom message and code', () => {
        const resp = ErrorResponseBuilder.serviceUnavailableError(
          'WS down',
          ERROR_CODES.WEBSOCKET_CONNECTION_FAILED,
        );
        expect(resp.error.code).toBe(ERROR_CODES.WEBSOCKET_CONNECTION_FAILED);
        expect(resp.error.message).toBe('WS down');
      });
    });

    describe('gatewayTimeoutError', () => {
      it('returns 504 with defaults', () => {
        const resp = ErrorResponseBuilder.gatewayTimeoutError();
        expect(resp.error.code).toBe(ERROR_CODES.REQUEST_TIMEOUT);
        expect(resp.error.message).toBe('Request timed out');
      });

      it('accepts custom message and code', () => {
        const resp = ErrorResponseBuilder.gatewayTimeoutError(
          'Ping lost',
          ERROR_CODES.PING_TIMEOUT,
        );
        expect(resp.error.code).toBe(ERROR_CODES.PING_TIMEOUT);
        expect(resp.error.message).toBe('Ping lost');
      });
    });

    describe('badRequestError', () => {
      it('returns 400 with defaults', () => {
        const resp = ErrorResponseBuilder.badRequestError();
        expect(resp.error.code).toBe(ERROR_CODES.INVALID_REQUEST_FORMAT);
        expect(resp.error.message).toBe('Invalid request format');
      });

      it('accepts custom message and code', () => {
        const resp = ErrorResponseBuilder.badRequestError(
          'Missing field',
          ERROR_CODES.MISSING_REQUIRED_FIELD,
        );
        expect(resp.error.code).toBe(ERROR_CODES.MISSING_REQUIRED_FIELD);
        expect(resp.error.message).toBe('Missing field');
      });
    });

    describe('internalServerError', () => {
      it('returns 500 with defaults', () => {
        const resp = ErrorResponseBuilder.internalServerError();
        expect(resp.error.code).toBe(ERROR_CODES.INTERNAL_SERVER_ERROR);
        expect(resp.error.message).toBe('Internal server error');
      });

      it('accepts custom message and code', () => {
        const resp = ErrorResponseBuilder.internalServerError(
          'Serialization failed',
          ERROR_CODES.MESSAGE_SERIALIZATION_FAILED,
        );
        expect(resp.error.code).toBe(ERROR_CODES.MESSAGE_SERIALIZATION_FAILED);
        expect(resp.error.message).toBe('Serialization failed');
      });
    });
  });
});
