/**
 * CloudToLocalLLM v10.1.147 Global Test Setup
 * Prepares environment for authentication loop analysis
 */

import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function globalSetup(config) {
  console.log(" CloudToLocalLLM v10.1.147 Authentication Loop Analysis Setup");
  console.log(
    "================================================================",
  );

  // Create test results directory
  const testResultsDir = "test-results";
  if (!fs.existsSync(testResultsDir)) {
    fs.mkdirSync(testResultsDir, { recursive: true });
  }

  // Create subdirectories for artifacts
  const subdirs = ["screenshots", "videos", "traces", "reports", "artifacts"];
  subdirs.forEach((subdir) => {
    const dirPath = path.join(testResultsDir, subdir);
    if (!fs.existsSync(dirPath)) {
      fs.mkdirSync(dirPath, { recursive: true });
    }
  });

  // --- Auth0 Test User Creation ---
  let testUser = null;
  // Dynamic import to handle optional dependency
  let auth0Manager = null;

  try {
    // We need to construct the URL for dynamic import
    const scriptPath = path.resolve(
      __dirname,
      "../../services/api-backend/scripts/auth0-test-user-manager.js",
    );
    if (fs.existsSync(scriptPath)) {
      auth0Manager = await import(scriptPath);
    } else {
      console.log(
        `[WARN] Auth0 User Manager script not found at ${scriptPath}`,
      );
    }
  } catch (e) {
    console.log("[WARN] Failed to load Auth0 User Manager:", e.message);
  }

  if (
    process.env.AUTH0_CLIENT_ID &&
    process.env.AUTH0_CLIENT_SECRET &&
    auth0Manager
  ) {
    console.log("\n Creating Ephemeral Test User...");
    try {
      // Create a specialized e2e-test user
      testUser = await auth0Manager.createTestUser("e2e-user");

      // Set environment variables for the test run
      process.env.JWT_TEST_EMAIL = testUser.email;
      process.env.JWT_TEST_PASSWORD = testUser.password;

      // Save to file for other processes/tests to access if needed
      fs.writeFileSync(
        path.join(testResultsDir, "user-config.json"),
        JSON.stringify(testUser, null, 2),
      );
      console.log(`  User created: ${testUser.email}`);
    } catch (error) {
      console.error("  Failed to create test user:", error.message);
      console.log("  Falling back to manual credentials if provided.");
    }
  } else {
    console.log(
      "\n Skipping automatic test user creation (Missing credentials or script)",
    );
  }

  // Validate environment variables
  const requiredEnvVars = ["DEPLOYMENT_URL"];
  const optionalEnvVars = ["JWT_TEST_EMAIL", "JWT_TEST_PASSWORD"];

  console.log("\n Environment Configuration:");
  console.log("==============================");

  requiredEnvVars.forEach((envVar) => {
    if (process.env[envVar]) {
      console.log(` ${envVar}: ${process.env[envVar]}`);
    } else {
      console.log(` ${envVar}: NOT SET (required)`);
      console.log(" [WARN] DEPLOYMENT_URL not set. Tests might fail.");
    }
  });

  optionalEnvVars.forEach((envVar) => {
    if (process.env[envVar]) {
      console.log(` ${envVar}: ****** (set)`);
    } else {
      console.log(
        `  ${envVar}: NOT SET (optional - will skip JWT form interaction)`,
      );
    }
  });

  // Validate deployment URL accessibility
  console.log("\n Deployment Validation:");
  console.log("=========================");

  if (process.env.DEPLOYMENT_URL) {
    try {
      const deploymentUrl = process.env.DEPLOYMENT_URL;
      console.log(`Testing connectivity to: ${deploymentUrl}`);

      // Simple fetch to check if deployment is accessible
      const response = await fetch(deploymentUrl);
      if (response.ok) {
        console.log(` Deployment accessible (HTTP ${response.status})`);

        // Check version endpoint
        try {
          const versionResponse = await fetch(`${deploymentUrl}/version.json`);
          if (versionResponse.ok) {
            const versionData = await versionResponse.json();
            console.log(
              ` Version endpoint accessible: v${versionData.version}`,
            );

            if (versionData.version === "10.1.147") {
              console.log(` Correct version deployed (10.1.147)`);
            } else {
              console.log(
                `  Unexpected version: ${versionData.version} (expected 10.1.147)`,
              );
            }
          } else {
            console.log(
              `  Version endpoint not accessible (HTTP ${versionResponse.status})`,
            );
          }
        } catch (error) {
          console.log(`  Version check failed: ${error.message}`);
        }
      } else {
        console.log(` Deployment not accessible (HTTP ${response.status})`);
        console.log(" [WARN] Deployment not accessible");
      }
    } catch (error) {
      console.log(` Deployment validation failed: ${error.message}`);
      console.log(" [WARN] Deployment validation exception");
    }
  }

  // Create test configuration summary
  const testConfig = {
    timestamp: new Date().toISOString(),
    version: "10.1.147",
    deploymentUrl: process.env.DEPLOYMENT_URL,
    hasJWTCredentials: !!(
      process.env.JWT_TEST_EMAIL && process.env.JWT_TEST_PASSWORD
    ),
    testEnvironment: process.env.CI ? "CI" : "LOCAL",
    browsers: config.projects.map((p) => p.name),
    generatedTestUser: testUser ? testUser.email : null,
    expectedFeatures: [
      "Login loop race condition fix",
      "100ms callback processing delay",
      "Enhanced authentication state synchronization",
      "Improved error handling",
      "Debug logging for authentication flow",
    ],
  };

  fs.writeFileSync(
    path.join(testResultsDir, "test-config.json"),
    JSON.stringify(testConfig, null, 2),
  );

  console.log("\n Test Configuration:");
  console.log("======================");
  console.log(`Test Environment: ${testConfig.testEnvironment}`);
  console.log(
    `JWT Credentials: ${testConfig.hasJWTCredentials ? "Available" : "Not Available"}`,
  );
  console.log(`Generated User: ${testConfig.generatedTestUser || "None"}`);
  console.log(`Browsers: ${testConfig.browsers.join(", ")}`);

  console.log("\n Setup Complete - Ready to run authentication loop analysis");
  console.log(
    "==============================================================\n",
  );
}

export default globalSetup;
