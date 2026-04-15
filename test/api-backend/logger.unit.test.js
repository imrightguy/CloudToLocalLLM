import { jest } from '@jest/globals';
import logger from '../../services/api-backend/logger.js';

describe('logger', () => {
  it('exports a logger object with standard log methods', () => {
    expect(typeof logger.info).toBe('function');
    expect(typeof logger.warn).toBe('function');
    expect(typeof logger.error).toBe('function');
    expect(typeof logger.debug).toBe('function');
  });

  it('has default level info', () => {
    expect(logger.level).toBe('info');
  });

  describe('component loggers', () => {
    it('has zrok component with all log methods', () => {
      expect(typeof logger.zrok.info).toBe('function');
      expect(typeof logger.zrok.warn).toBe('function');
      expect(typeof logger.zrok.error).toBe('function');
      expect(typeof logger.zrok.debug).toBe('function');
    });

    it('has auth component with all log methods', () => {
      expect(typeof logger.auth.info).toBe('function');
      expect(typeof logger.auth.warn).toBe('function');
      expect(typeof logger.auth.error).toBe('function');
      expect(typeof logger.auth.debug).toBe('function');
    });

    it('has proxy component with all log methods', () => {
      expect(typeof logger.proxy.info).toBe('function');
      expect(typeof logger.proxy.warn).toBe('function');
      expect(typeof logger.proxy.error).toBe('function');
      expect(typeof logger.proxy.debug).toBe('function');
    });

    it('has container component with all log methods', () => {
      expect(typeof logger.container.info).toBe('function');
      expect(typeof logger.container.warn).toBe('function');
      expect(typeof logger.container.error).toBe('function');
      expect(typeof logger.container.debug).toBe('function');
    });

    it('zrok.info prefixes message with [Zrok]', () => {
      const spy = jest.spyOn(logger, 'info');
      logger.zrok.info('test message', { key: 'val' });
      expect(spy).toHaveBeenCalledWith(' [Zrok] test message', { key: 'val' });
      spy.mockRestore();
    });

    it('zrok.warn prefixes message with [Zrok]', () => {
      const spy = jest.spyOn(logger, 'warn');
      logger.zrok.warn('warning!');
      expect(spy).toHaveBeenCalledWith(' [Zrok] warning!', {});
      spy.mockRestore();
    });

    it('zrok.error prefixes message with [Zrok]', () => {
      const spy = jest.spyOn(logger, 'error');
      logger.zrok.error('fail');
      expect(spy).toHaveBeenCalledWith(' [Zrok] fail', {});
      spy.mockRestore();
    });

    it('zrok.debug prefixes message with [Zrok]', () => {
      const spy = jest.spyOn(logger, 'debug');
      logger.zrok.debug('trace');
      expect(spy).toHaveBeenCalledWith(' [Zrok] trace', {});
      spy.mockRestore();
    });

    it('auth.info prefixes message with [Auth]', () => {
      const spy = jest.spyOn(logger, 'info');
      logger.auth.info('login');
      expect(spy).toHaveBeenCalledWith(' [Auth] login', {});
      spy.mockRestore();
    });

    it('auth.warn prefixes message with [Auth]', () => {
      const spy = jest.spyOn(logger, 'warn');
      logger.auth.warn('token expired');
      expect(spy).toHaveBeenCalledWith(' [Auth] token expired', {});
      spy.mockRestore();
    });

    it('auth.error prefixes message with [Auth]', () => {
      const spy = jest.spyOn(logger, 'error');
      logger.auth.error('forbidden');
      expect(spy).toHaveBeenCalledWith(' [Auth] forbidden', {});
      spy.mockRestore();
    });

    it('auth.debug prefixes message with [Auth]', () => {
      const spy = jest.spyOn(logger, 'debug');
      logger.auth.debug('checking');
      expect(spy).toHaveBeenCalledWith(' [Auth] checking', {});
      spy.mockRestore();
    });

    it('proxy.info prefixes message with [Proxy]', () => {
      const spy = jest.spyOn(logger, 'info');
      logger.proxy.info('proxied');
      expect(spy).toHaveBeenCalledWith(' [Proxy] proxied', {});
      spy.mockRestore();
    });

    it('proxy.warn prefixes message with [Proxy]', () => {
      const spy = jest.spyOn(logger, 'warn');
      logger.proxy.warn('slow upstream');
      expect(spy).toHaveBeenCalledWith(' [Proxy] slow upstream', {});
      spy.mockRestore();
    });

    it('proxy.error prefixes message with [Proxy]', () => {
      const spy = jest.spyOn(logger, 'error');
      logger.proxy.error('upstream down');
      expect(spy).toHaveBeenCalledWith(' [Proxy] upstream down', {});
      spy.mockRestore();
    });

    it('proxy.debug prefixes message with [Proxy]', () => {
      const spy = jest.spyOn(logger, 'debug');
      logger.proxy.debug('trace');
      expect(spy).toHaveBeenCalledWith(' [Proxy] trace', {});
      spy.mockRestore();
    });

    it('container.info prefixes message with [Container]', () => {
      const spy = jest.spyOn(logger, 'info');
      logger.container.info('started');
      expect(spy).toHaveBeenCalledWith(
        expect.stringContaining('[Container]'),
        {},
      );
      spy.mockRestore();
    });

    it('container.warn prefixes message with [Container]', () => {
      const spy = jest.spyOn(logger, 'warn');
      logger.container.warn('oom');
      expect(spy).toHaveBeenCalledWith(
        expect.stringContaining('[Container]'),
        {},
      );
      spy.mockRestore();
    });

    it('container.error prefixes message with [Container]', () => {
      const spy = jest.spyOn(logger, 'error');
      logger.container.error('crashed');
      expect(spy).toHaveBeenCalledWith(
        expect.stringContaining('[Container]'),
        {},
      );
      spy.mockRestore();
    });

    it('container.debug prefixes message with [Container]', () => {
      const spy = jest.spyOn(logger, 'debug');
      logger.container.debug('inspecting');
      expect(spy).toHaveBeenCalledWith(
        expect.stringContaining('[Container]'),
        {},
      );
      spy.mockRestore();
    });

    it('passes through metadata to underlying logger', () => {
      const spy = jest.spyOn(logger, 'info');
      const meta = { requestId: 'abc-123', duration: 45 };
      logger.zrok.info('done', meta);
      expect(spy).toHaveBeenCalledWith(' [Zrok] done', meta);
      spy.mockRestore();
    });

    it('defaults metadata to empty object', () => {
      const spy = jest.spyOn(logger, 'info');
      logger.auth.info('no meta');
      expect(spy).toHaveBeenCalledWith(' [Auth] no meta', {});
      spy.mockRestore();
    });
  });

  describe('logRequest middleware', () => {
    it('calls next when provided', () => {
      const next = jest.fn();
      const req = { method: 'GET', url: '/', get: jest.fn(), connection: {} };
      const res = { on: jest.fn(), statusCode: 200 };

      logger.logRequest(req, res, next);

      expect(next).toHaveBeenCalledTimes(1);
    });

    it('does not crash when next is not provided', () => {
      const req = { method: 'GET', url: '/', get: jest.fn(), connection: {} };
      const res = { on: jest.fn(), statusCode: 200 };

      expect(() => logger.logRequest(req, res)).not.toThrow();
    });

    it('registers a finish event listener on res', () => {
      const next = jest.fn();
      const req = { method: 'GET', url: '/', get: jest.fn(), connection: {} };
      const res = { on: jest.fn(), statusCode: 200 };

      logger.logRequest(req, res, next);

      expect(res.on).toHaveBeenCalledWith('finish', expect.any(Function));
    });

    it('logs successful requests (status < 400) as info', () => {
      const spy = jest.spyOn(logger, 'info');
      const next = jest.fn();
      const req = {
        method: 'GET',
        url: '/api/health',
        get: jest.fn(() => 'TestAgent'),
        ip: '127.0.0.1',
        connection: { remoteAddress: '127.0.0.1' },
        userId: 'user-1',
      };
      const res = { on: jest.fn(), statusCode: 200 };

      logger.logRequest(req, res, next);
      const finishCb = res.on.mock.calls[0][1];
      finishCb();

      expect(spy).toHaveBeenCalledWith(
        'HTTP Request',
        expect.objectContaining({
          method: 'GET',
          url: '/api/health',
          statusCode: 200,
          userId: 'user-1',
        }),
      );
      spy.mockRestore();
    });

    it('logs error requests (status >= 400) as warn', () => {
      const spy = jest.spyOn(logger, 'warn');
      const next = jest.fn();
      const req = {
        method: 'POST',
        url: '/api/login',
        get: jest.fn(() => 'TestAgent'),
        ip: '10.0.0.1',
        connection: { remoteAddress: '10.0.0.1' },
        userId: 'anonymous',
      };
      const res = { on: jest.fn(), statusCode: 401 };

      logger.logRequest(req, res, next);
      const finishCb = res.on.mock.calls[0][1];
      finishCb();

      expect(spy).toHaveBeenCalledWith(
        'HTTP Request',
        expect.objectContaining({
          method: 'POST',
          url: '/api/login',
          statusCode: 401,
        }),
      );
      spy.mockRestore();
    });

    it('defaults userId to anonymous when not set', () => {
      const spy = jest.spyOn(logger, 'info');
      const next = jest.fn();
      const req = {
        method: 'GET',
        url: '/',
        get: jest.fn(() => ''),
        connection: { remoteAddress: '::1' },
      };
      const res = { on: jest.fn(), statusCode: 200 };

      logger.logRequest(req, res, next);
      const finishCb = res.on.mock.calls[0][1];
      finishCb();

      expect(spy).toHaveBeenCalledWith(
        'HTTP Request',
        expect.objectContaining({ userId: 'anonymous' }),
      );
      spy.mockRestore();
    });

    it('records duration in log metadata', () => {
      const spy = jest.spyOn(logger, 'info');
      const next = jest.fn();
      const req = {
        method: 'GET',
        url: '/slow',
        get: jest.fn(),
        connection: {},
      };
      const res = { on: jest.fn(), statusCode: 200 };

      logger.logRequest(req, res, next);
      const finishCb = res.on.mock.calls[0][1];
      finishCb();

      expect(spy).toHaveBeenCalledWith(
        'HTTP Request',
        expect.objectContaining({
          duration: expect.stringMatching(/^\d+ms$/),
        }),
      );
      spy.mockRestore();
    });

    it('logs 500 as warn', () => {
      const spy = jest.spyOn(logger, 'warn');
      const next = jest.fn();
      const req = {
        method: 'GET',
        url: '/fail',
        get: jest.fn(),
        connection: {},
      };
      const res = { on: jest.fn(), statusCode: 500 };

      logger.logRequest(req, res, next);
      const finishCb = res.on.mock.calls[0][1];
      finishCb();

      expect(spy).toHaveBeenCalledWith(
        'HTTP Request',
        expect.objectContaining({ statusCode: 500 }),
      );
      spy.mockRestore();
    });

    it('logs 400 as warn', () => {
      const spy = jest.spyOn(logger, 'warn');
      const next = jest.fn();
      const req = {
        method: 'POST',
        url: '/bad',
        get: jest.fn(),
        connection: {},
      };
      const res = { on: jest.fn(), statusCode: 400 };

      logger.logRequest(req, res, next);
      const finishCb = res.on.mock.calls[0][1];
      finishCb();

      expect(spy).toHaveBeenCalledWith(
        'HTTP Request',
        expect.objectContaining({ statusCode: 400 }),
      );
      spy.mockRestore();
    });
  });
});
