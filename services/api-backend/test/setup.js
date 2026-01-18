// Jest setup file for CloudToLocalLLM API Backend tests
// Configures test environment and global mocks

import { jest, afterEach } from '@jest/globals';

// Set test environment variables
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'test-secret-key';
process.env.JWT_ISSUER_DOMAIN = 'test.jwt.com';
process.env.JWT_AUDIENCE = 'test-audience';
process.env.LOG_LEVEL = 'error'; // Reduce log noise in tests

// Global test timeout
jest.setTimeout(30000);

// Mock external dependencies that shouldn't be called in tests
jest.mock('winston', () => ({
  createLogger: jest.fn(() => ({
    info: jest.fn(),
    error: jest.fn(),
    warn: jest.fn(),
    debug: jest.fn(),
    log: jest.fn(),
    add: jest.fn(),
  })),
  format: {
    combine: jest.fn((...args) => args),
    timestamp: jest.fn(),
    errors: jest.fn(),
    json: jest.fn(),
    colorize: jest.fn(),
    simple: jest.fn(),
    printf: jest.fn((formatter) => formatter),
  },
  transports: {
    Console: jest.fn(),
    File: jest.fn(),
  },
}));

// Mock Sentry to prevent it from keeping the process alive
jest.mock('@sentry/node', () => ({
  init: jest.fn(),
  captureException: jest.fn(),
  captureMessage: jest.fn(),
  startTransaction: jest.fn(() => ({
    finish: jest.fn(),
    startChild: jest.fn(() => ({
      finish: jest.fn(),
    })),
  })),
  addBreadcrumb: jest.fn(),
  setUser: jest.fn(),
  setTag: jest.fn(),
  setContext: jest.fn(),
  close: jest.fn().mockResolvedValue(true),
  createSentryWinstonTransport: jest.fn(() => class MockTransport { }),
  setupExpressErrorHandler: jest.fn(),
}));

// Mock Docker operations
jest.mock('dockerode', () => {
  return jest.fn().mockImplementation(() => ({
    listContainers: jest.fn().mockResolvedValue([]),
    listNetworks: jest.fn().mockResolvedValue([]),
    createContainer: jest.fn().mockResolvedValue({
      start: jest.fn().mockResolvedValue(),
      stop: jest.fn().mockResolvedValue(),
      remove: jest.fn().mockResolvedValue(),
    }),
  }));
});

// Mock ws WebSocket to avoid dependency on internal options
jest.mock('ws', () => {
  class MockWebSocket {
    constructor(..._args) {
      this.readyState = 1; // OPEN
      this.OPEN = 1;
      this.CLOSED = 3;
      this.listeners = {};
    }
    on(event, handler) {
      this.listeners[event] = this.listeners[event] || [];
      this.listeners[event].push(handler);
    }
    addEventListener(event, handler) {
      this.on(event, handler);
    }
    removeEventListener(event, handler) {
      if (!this.listeners[event]) {
        return;
      }
      this.listeners[event] = this.listeners[event].filter(
        (h) => h !== handler,
      );
    }
    send(_data) { }
    close() {
      this.readyState = this.CLOSED;
    }
  }
  MockWebSocket.Server = class { };
  return MockWebSocket;
});

// Mock WebSocket for tunnel tests
global.WebSocket = jest.fn().mockImplementation(() => ({
  send: jest.fn(),
  close: jest.fn(),
  addEventListener: jest.fn(),
  removeEventListener: jest.fn(),
  readyState: 1, // OPEN
  CONNECTING: 0,
  OPEN: 1,
  CLOSING: 2,
  CLOSED: 3,
}));

// Global test utilities
global.testUtils = {
  // Create mock request object
  createMockReq: (overrides = {}) => ({
    headers: {},
    body: {},
    params: {},
    query: {},
    user: null,
    ...overrides,
  }),

  // Create mock response object
  createMockRes: () => {
    const res = {
      status: jest.fn().mockReturnThis(),
      json: jest.fn().mockReturnThis(),
      send: jest.fn().mockReturnThis(),
      end: jest.fn().mockReturnThis(),
      setHeader: jest.fn().mockReturnThis(),
      locals: {},
    };
    return res;
  },

  // Create mock next function
  createMockNext: () => jest.fn(),

  // Wait for async operations
  waitFor: (ms) => new Promise((resolve) => setTimeout(resolve, ms)),

  // Generate test JWT token
  generateTestJWT: () => 'test.jwt.token',
};

// Console override for cleaner test output
const originalConsole = global.console;
global.console = {
  ...originalConsole,
  log: jest.fn(),
  info: jest.fn(),
  warn: jest.fn(),
  error: originalConsole.error, // Keep errors visible
};

// Cleanup after each test
afterEach(() => {
  jest.clearAllMocks();
});

// Cleanup after all tests complete in this worker
afterAll(async() => {
  // Close database pool if it was initialized (within worker process)
  try {
    const dbPool = await import('../database/db-pool.js');
    if (dbPool.closePool) {
      await dbPool.closePool();
    }
  } catch {
    // Pool may not have been initialized
  }

  // Clear request queue service to stop all pending timeouts
  try {
    const { getRequestQueueService } = await import('../services/request-queue-service.js');
    const queueService = getRequestQueueService();
    if (queueService && queueService.clearAllQueues) {
      queueService.clearAllQueues();
    }
  } catch {
    // Queue service may not have been initialized
  }

  // Close FailoverManager if initialized
  try {
    const { closeFailoverManager } = await import('../database/failover-manager.js');
    await closeFailoverManager();
  } catch {
    // Failover manager may not have been initialized
  }
});

// Global error handler for unhandled promises
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Don't exit the process in tests
});

console.info('Test environment setup completed');
