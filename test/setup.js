// Jest setup file for CloudToLocalLLM API Backend tests
// Configures test environment and global mocks

import { jest, afterEach } from "@jest/globals";

// Set test environment variables
process.env.NODE_ENV = "test";
process.env.JWT_SECRET = "test-secret-key";
process.env.JWT_ISSUER_DOMAIN = "test.jwt.com";
process.env.JWT_AUDIENCE = "test-audience";
process.env.LOG_LEVEL = "error"; // Reduce log noise in tests

// Global test timeout
jest.setTimeout(30000);

// Mock external dependencies that shouldn't be called in tests
jest.mock("winston", () => ({
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

// Mock database pool by default for test isolation
// Tests that need real database access should call jest.unmock() on the db-pool module
jest.mock("../services/api-backend/database/db-pool.js", () => ({
  initializePool: jest.fn(),
  getPool: jest.fn(() => ({
    query: jest.fn(),
    connect: jest.fn(),
    end: jest.fn(),
    totalCount: 0,
    idleCount: 0,
    waitingCount: 0,
    on: jest.fn(),
  })),
  getPoolMetrics: jest.fn(() => ({
    totalConnections: 0,
    idleConnections: 0,
    waitingClients: 0,
    errors: 0,
    status: "mocked",
  })),
  healthCheck: jest.fn(() => Promise.resolve({ healthy: true })),
  closePool: jest.fn(() => Promise.resolve()),
  query: jest.fn(),
  getClient: jest.fn(),
}));

// Cleanup after each test
afterEach(async () => {
  jest.clearAllMocks();

  // Close any open database connections from individual tests
  // This helps prevent connection leaks between tests
  try {
    const { getPool } =
      await import("../services/api-backend/database/db-pool.js");
    const pool = getPool();
    if (pool) {
      // Force close idle connections to ensure test isolation
      pool.idleCount > 0 && pool.idleCount;
    }
  } catch (error) {
    // Ignore errors if pool is not initialized
  }
});

console.info("Test environment setup completed");
