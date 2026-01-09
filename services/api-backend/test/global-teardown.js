// Global teardown for Jest tests
// Runs once after all tests

export default async function globalTeardown() {
  console.log('🧹 Cleaning up global test environment...');

  // Close database pool if it was initialized
  try {
    const dbPool = await import('../database/db-pool.js');
    if (dbPool.closePool) {
      await dbPool.closePool();
      console.log('✅ Database pool closed successfully');
    }
  } catch (error) {
    // Pool may not have been initialized, that's fine
    console.log('ℹ️ Database pool not initialized or already closed');
  }

  console.log('✅ Global test cleanup completed');
}
