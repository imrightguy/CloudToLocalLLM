/**
 * Jest setup file — runs after the test framework is installed in each worker.
 * Registers global afterAll hooks to clean up persistent resources that prevent
 * the worker from exiting gracefully (pg Pool, NodeCache timers, etc.).
 *
 * IMPORTANT: Imports are deferred to afterAll to avoid interfering with
 * per-test mocking (e.g., database-connection.test.js mocks pg).
 */

afterAll(async () => {
  // Use jest.resetModules()-safe deferred imports to avoid conflicting
  // with tests that mock pg or node-cache at the module level.
  try {
    const { pool } = require('./src/database/connection');
    if (
      typeof pool?.end === 'function' &&
      !jest.isMockFunction(pool.end)
    ) {
      await pool.end().catch(() => {});
    }
  } catch {
    // Module not imported or already closed
  }

  try {
    const { cache } = require('./src/utils/cache');
    if (
      typeof cache?.close === 'function' &&
      !jest.isMockFunction(cache.close)
    ) {
      cache.close();
    }
  } catch {
    // Module not imported or already closed
  }
});
