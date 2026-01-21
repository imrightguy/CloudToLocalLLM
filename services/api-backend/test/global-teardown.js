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
  } catch {
    // Pool may not have been initialized, that's fine
    console.log('ℹ️ Database pool not initialized or already closed');
  }

  // Clear request queue service to stop all pending timeouts
  try {
    const { getRequestQueueService } = await import(
      '../services/request-queue-service.js'
    );
    const queueService = getRequestQueueService();
    if (queueService && queueService.clearAllQueues) {
      queueService.clearAllQueues();
      console.log('✅ Request queue service cleared successfully');
    }
  } catch {
    // Queue service may not have been initialized, that's fine
    console.log('ℹ️ Request queue service not initialized or already cleared');
  }

  console.log('✅ Global test cleanup completed');
}
