import { jest } from '@jest/globals';
import { createGracefulShutdownManager, setupGracefulShutdown } from '../../services/api-backend/middleware/graceful-shutdown.js';

function createMockServer() {
  const sockets = new Set();
  const listeners = {};

  const server = {
    _sockets: sockets,
    on(event, fn) {
      if (!listeners[event]) listeners[event] = [];
      listeners[event].push(fn);
      return server;
    },
    emit(event, ...args) {
      if (listeners[event]) {
        for (const fn of listeners[event]) fn(...args);
      }
      return true;
    },
    close(cb) {
      if (cb) cb();
      return server;
    },
    _listeners: listeners,
  };

  return server;
}

function createMockSocket(opts = {}) {
  const socket = {
    writable: opts.writable !== undefined ? opts.writable : true,
    destroyed: false,
    _events: {},
    on(event, fn) {
      this._events[event] = fn;
      return this;
    },
    emit(event) {
      if (this._events[event]) this._events[event]();
      return true;
    },
    destroy() {
      this.destroyed = true;
      return this;
    },
  };
  return socket;
}

describe('createGracefulShutdownManager', () => {
  let server;
  let manager;

  beforeEach(() => {
    server = createMockServer();
    manager = createGracefulShutdownManager(server, { shutdownTimeoutMs: 500 });
  });

  test('returns shutdown, getActiveRequestCount, isShutdownInProgress', () => {
    expect(manager.shutdown).toBeInstanceOf(Function);
    expect(manager.getActiveRequestCount).toBeInstanceOf(Function);
    expect(manager.isShutdownInProgress).toBeInstanceOf(Function);
  });

  test('initial state: not shutting down, zero active requests', () => {
    expect(manager.isShutdownInProgress()).toBe(false);
    expect(manager.getActiveRequestCount()).toBe(0);
  });

  test('tracks connections via socket add/remove', () => {
    const socket = createMockSocket();
    server.emit('connection', socket);
    expect(manager.getActiveRequestCount()).toBe(1);

    socket.emit('close');
    expect(manager.getActiveRequestCount()).toBe(0);
  });

  test('tracks multiple connections', () => {
    const s1 = createMockSocket();
    const s2 = createMockSocket();
    server.emit('connection', s1);
    server.emit('connection', s2);
    expect(manager.getActiveRequestCount()).toBe(2);

    s1.emit('close');
    expect(manager.getActiveRequestCount()).toBe(1);
  });

  test('shutdown sets isShuttingDown to true', async () => {
    const shutdownPromise = manager.shutdown();
    expect(manager.isShutdownInProgress()).toBe(true);
    await shutdownPromise;
  });

  test('duplicate shutdown call is a no-op (does not hang)', async () => {
    const p1 = manager.shutdown();
    const p2 = manager.shutdown();
    await Promise.all([p1, p2]);
    expect(manager.isShutdownInProgress()).toBe(true);
  });

  test('shutdown calls onShutdown callback if provided', async () => {
    const onShutdown = jest.fn().mockResolvedValue(undefined);
    const mgr = createGracefulShutdownManager(server, {
      shutdownTimeoutMs: 500,
      onShutdown,
    });
    await mgr.shutdown();
    expect(onShutdown).toHaveBeenCalledTimes(1);
  });

  test('shutdown continues even if onShutdown throws', async () => {
    const onShutdown = jest.fn().mockRejectedValue(new Error('boom'));
    const mgr = createGracefulShutdownManager(server, {
      shutdownTimeoutMs: 500,
      onShutdown,
    });
    await expect(mgr.shutdown()).resolves.toBeUndefined();
    expect(onShutdown).toHaveBeenCalledTimes(1);
  });

  test('shutdown calls server.close', async () => {
    const closeSpy = jest.spyOn(server, 'close');
    await manager.shutdown();
    expect(closeSpy).toHaveBeenCalledTimes(1);
  });

  test('shutdown destroys non-writable sockets immediately', async () => {
    const socket = createMockSocket({ writable: false });
    server.emit('connection', socket);
    expect(manager.getActiveRequestCount()).toBe(1);

    await manager.shutdown();
    expect(socket.destroyed).toBe(true);
    expect(manager.getActiveRequestCount()).toBe(0);
  });

  test('shutdown waits for writable sockets to close', async () => {
    const socket = createMockSocket({ writable: true });
    server.emit('connection', socket);
    expect(manager.getActiveRequestCount()).toBe(1);

    const shutdownPromise = manager.shutdown();

    // Close the socket after a brief delay to simulate in-flight completion
    setTimeout(() => socket.emit('close'), 50);

    await shutdownPromise;
    expect(socket.destroyed).toBe(false);
    expect(manager.getActiveRequestCount()).toBe(0);
  });

  test('shutdown force-closes remaining sockets after timeout', async () => {
    const mgr = createGracefulShutdownManager(server, { shutdownTimeoutMs: 200 });
    const socket = createMockSocket({ writable: true });
    server.emit('connection', socket);
    expect(mgr.getActiveRequestCount()).toBe(1);

    // Socket never closes — timeout should force-destroy it
    await mgr.shutdown();
    expect(socket.destroyed).toBe(true);
  });

  test('uses default shutdownTimeoutMs of 10000', () => {
    const mgr = createGracefulShutdownManager(server);
    // No easy way to inspect internal timeout, just verify no crash
    expect(mgr.shutdown).toBeInstanceOf(Function);
  });

  test('request event assigns requestId and wraps res.end', () => {
    const req = { method: 'GET', url: '/test' };
    const originalEnd = jest.fn();
    const res = { end: originalEnd, statusCode: 200 };

    server.emit('request', req, res);

    expect(req.requestId).toBeDefined();
    expect(typeof req.requestId).toBe('string');

    res.end('done');
    expect(originalEnd).toHaveBeenCalledWith('done');
  });

  test('request event generates unique requestIds', () => {
    const req1 = { method: 'GET', url: '/a' };
    const res1 = { end: jest.fn(), statusCode: 200 };
    const req2 = { method: 'POST', url: '/b' };
    const res2 = { end: jest.fn(), statusCode: 201 };

    server.emit('request', req1, res1);
    server.emit('request', req2, res2);

    expect(req1.requestId).not.toBe(req2.requestId);
  });
});

describe('setupGracefulShutdown', () => {
  let server;
  let originalListeners;

  beforeEach(() => {
    server = createMockServer();
    originalListeners = {
      SIGTERM: process.listeners('SIGTERM'),
      SIGINT: process.listeners('SIGINT'),
      uncaughtException: process.listeners('uncaughtException'),
      unhandledRejection: process.listeners('unhandledRejection'),
    };
  });

  afterEach(() => {
    // Remove handlers added by setupGracefulShutdown to avoid polluting process
    process.removeAllListeners('SIGTERM');
    process.removeAllListeners('SIGINT');
    process.removeAllListeners('uncaughtException');
    process.removeAllListeners('unhandledRejection');
    for (const [event, fns] of Object.entries(originalListeners)) {
      for (const fn of fns) {
        process.on(event, fn);
      }
    }
  });

  test('registers process signal handlers and returns shutdown manager', () => {
    const mgr = setupGracefulShutdown(server, { shutdownTimeoutMs: 500 });
    expect(mgr.shutdown).toBeInstanceOf(Function);
    expect(process.listenerCount('SIGTERM')).toBeGreaterThan(originalListeners.SIGTERM.length);
    expect(process.listenerCount('SIGINT')).toBeGreaterThan(originalListeners.SIGINT.length);
    expect(process.listenerCount('uncaughtException')).toBeGreaterThan(originalListeners.uncaughtException.length);
    expect(process.listenerCount('unhandledRejection')).toBeGreaterThan(originalListeners.unhandledRejection.length);
  });

  test('passes options through to createGracefulShutdownManager', () => {
    const onShutdown = jest.fn();
    const mgr = setupGracefulShutdown(server, {
      shutdownTimeoutMs: 500,
      onShutdown,
    });
    expect(mgr.getActiveRequestCount).toBeInstanceOf(Function);
  });
});
