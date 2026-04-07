// Global setup for Jest tests
// Runs once before all tests

export default async function globalSetup() {
  console.log(" Setting up global test environment...");

  // Set up test database or external services if needed
  // For now, we'll just ensure environment is clean

  // Clean up any existing test artifacts
  process.env.NODE_ENV = "test";

  console.log(" Global test setup completed");
}
