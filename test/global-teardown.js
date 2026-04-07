// Global teardown for Jest tests
// Runs once after all tests

import { closePool } from "../services/api-backend/database/db-pool.js";

export default async function globalTeardown() {
  console.log("Cleaning up global test environment...");

  // Close database connection pool
  try {
    await closePool();
    console.log("Database pool closed successfully");
  } catch (error) {
    console.error("Error closing database pool:", error);
  }

  console.log(" Global test cleanup completed");
}
