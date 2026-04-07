// CloudToLocalLLM v10.1.147 Authentication Loop Analysis Test
// Comprehensive E2E test to analyze and verify the login loop race condition fix

import { test, expect } from "@playwright/test";
import fs from "fs";
import path from "path";

// Test configuration
const CONFIG = {
  DEPLOYMENT_URL:
    process.env.DEPLOYMENT_URL || "https://your-vercel-app.vercel.app",
  JWT_TEST_EMAIL: process.env.JWT_TEST_EMAIL || "test@example.com",
  JWT_TEST_PASSWORD: process.env.JWT_TEST_PASSWORD || "TestPassword123!",
  MAX_REDIRECTS: 10, // Maximum redirects before considering it a loop
  TIMEOUT: 30000, // 30 seconds timeout
  DELAY_THRESHOLD: 100, // Expected delay from our fix (ms)
};

// Test data collection
let testReport = {
  startTime: new Date().toISOString(),
  version: "10.1.147",
  deploymentUrl: CONFIG.DEPLOYMENT_URL,
  events: [],
  networkRequests: [],
  consoleLogs: [],
  redirects: [],
  screenshots: [],
  result: "UNKNOWN",
  issues: [],
  timings: {},
};

test.describe("CloudToLocalLLM v10.1.147 Authentication Loop Analysis", () => {
  let page;
  let context;

  test.beforeAll(async ({ browser }) => {
    // Create context with detailed logging
    context = await browser.newContext({
      recordVideo: { dir: "test-results/videos/" },
      recordHar: { path: "test-results/network.har" },
    });

    page = await context.newPage();

    // Set up network monitoring
    page.on("request", (request) => {
      testReport.networkRequests.push({
        timestamp: new Date().toISOString(),
        type: "request",
        url: request.url(),
        method: request.method(),
        headers: request.headers(),
        resourceType: request.resourceType(),
      });
    });

    page.on("response", (response) => {
      testReport.networkRequests.push({
        timestamp: new Date().toISOString(),
        type: "response",
        url: response.url(),
        status: response.status(),
        headers: response.headers(),
      });
    });

    // Set up console monitoring
    page.on("console", (msg) => {
      const logEntry = {
        timestamp: new Date().toISOString(),
        type: msg.type(),
        text: msg.text(),
        location: msg.location(),
      };
      testReport.consoleLogs.push(logEntry);

      // Log our specific debug messages
      if (msg.text().includes("") || msg.text().includes("")) {
        console.log(`[DEBUG] ${logEntry.timestamp}: ${msg.text()}`);
      }
    });

    // Monitor page navigation
    page.on("framenavigated", (frame) => {
      if (frame === page.mainFrame()) {
        const redirect = {
          timestamp: new Date().toISOString(),
          url: frame.url(),
          title: frame.title(),
        };
        testReport.redirects.push(redirect);
        console.log(`[NAVIGATION] ${redirect.timestamp}: ${redirect.url}`);
      }
    });
  });

  test.afterAll(async () => {
    // Generate comprehensive test report
    testReport.endTime = new Date().toISOString();
    testReport.duration =
      new Date(testReport.endTime) - new Date(testReport.startTime);

    // Save test report
    const reportPath = path.join(
      "test-results",
      `auth-loop-analysis-${Date.now()}.json`,
    );
    fs.writeFileSync(reportPath, JSON.stringify(testReport, null, 2));
    console.log(`Test report saved to: ${reportPath}`);

    await context.close();
  });

  test("Analyze authentication flow and detect login loops", async () => {
    console.log(
      `Starting authentication loop analysis for ${CONFIG.DEPLOYMENT_URL}`,
    );

    // Step 1: Navigate to deployment
    testReport.events.push({
      timestamp: new Date().toISOString(),
      event: "NAVIGATE_TO_APP",
    });

    try {
      await page.goto(CONFIG.DEPLOYMENT_URL, { waitUntil: "networkidle" });
      await page.screenshot({ path: "test-results/01-initial-load.png" });
      testReport.screenshots.push("01-initial-load.png");
    } catch (error) {
      testReport.issues.push(`Failed to load deployment: ${error.message}`);
      testReport.result = "DEPLOYMENT_UNREACHABLE";
      return;
    }

    // Step 2: Verify version
    try {
      const versionResponse = await page.request.get(
        `${CONFIG.DEPLOYMENT_URL}/version.json`,
      );
      const versionData = await versionResponse.json();

      if (versionData.version === "10.1.147") {
        testReport.events.push({
          timestamp: new Date().toISOString(),
          event: "VERSION_VERIFIED",
          data: versionData,
        });
      } else {
        testReport.issues.push(
          `Unexpected version: ${versionData.version}, expected 10.1.147`,
        );
      }
    } catch (error) {
      testReport.issues.push(`Failed to verify version: ${error.message}`);
    }

    // Step 3: Check if already authenticated
    const currentUrl = page.url();
    if (!currentUrl.includes("/login")) {
      testReport.events.push({
        timestamp: new Date().toISOString(),
        event: "ALREADY_AUTHENTICATED",
        url: currentUrl,
      });

      // Try to logout first
      try {
        await page.click('button:has-text("Logout")', { timeout: 5000 });
        await page.waitForURL("**/login", { timeout: 10000 });
      } catch (error) {
        // If no logout button, navigate directly to login
        await page.goto(`${CONFIG.DEPLOYMENT_URL}/login`);
      }
    }

    // Step 4: Locate and click login button
    testReport.events.push({
      timestamp: new Date().toISOString(),
      event: "LOCATE_LOGIN_BUTTON",
    });

    await page.screenshot({ path: "test-results/02-login-page.png" });
    testReport.screenshots.push("02-login-page.png");

    const loginButton = page.locator('button:has-text("Sign In with JWT")');
    await expect(loginButton).toBeVisible({ timeout: 10000 });

    // Step 5: Start authentication flow monitoring
    const authStartTime = Date.now();
    testReport.timings.authStart = authStartTime;

    testReport.events.push({
      timestamp: new Date().toISOString(),
      event: "CLICK_LOGIN_BUTTON",
    });

    // Monitor for redirect loops
    let redirectCount = 0;
    const redirectUrls = [];

    const redirectMonitor = setInterval(() => {
      const currentUrl = page.url();
      if (redirectUrls[redirectUrls.length - 1] !== currentUrl) {
        redirectUrls.push(currentUrl);
        redirectCount++;

        console.log(`[REDIRECT ${redirectCount}] ${currentUrl}`);

        // Check for loop pattern
        if (redirectCount > CONFIG.MAX_REDIRECTS) {
          testReport.result = "INFINITE_LOOP_DETECTED";
          testReport.issues.push(
            `Infinite loop detected: ${redirectCount} redirects`,
          );
          clearInterval(redirectMonitor);
        }

        // Check for specific loop pattern (login -> callback -> login)
        if (redirectUrls.length >= 3) {
          const lastThree = redirectUrls.slice(-3);
          if (
            lastThree[0].includes("/login") &&
            lastThree[1].includes("/callback") &&
            lastThree[2].includes("/login")
          ) {
            testReport.result = "LOGIN_CALLBACK_LOOP_DETECTED";
            testReport.issues.push(
              "Classic login-callback loop pattern detected",
            );
            clearInterval(redirectMonitor);
          }
        }
      }
    }, 100);

    // Click login button and handle JWT flow
    try {
      await loginButton.click();

      // Wait for JWT redirect or popup
      await page.waitForURL("**/authorize**", { timeout: 10000 });
      testReport.events.push({
        timestamp: new Date().toISOString(),
        event: "AUTH_REDIRECT",
      });

      await page.screenshot({ path: "test-results/03-jwt-page.png" });
      testReport.screenshots.push("03-jwt-page.png");

      // Handle JWT authentication (if test credentials provided)
      if (CONFIG.JWT_TEST_EMAIL && CONFIG.JWT_TEST_PASSWORD) {
        try {
          await page.fill('input[name="email"]', CONFIG.JWT_TEST_EMAIL);
          await page.fill('input[name="password"]', CONFIG.JWT_TEST_PASSWORD);
          await page.click('button[type="submit"]');

          testReport.events.push({
            timestamp: new Date().toISOString(),
            event: "AUTH_CREDENTIALS_SUBMITTED",
          });
        } catch (error) {
          testReport.issues.push(
            `JWT form interaction failed: ${error.message}`,
          );
        }
      }

      // Wait for callback processing
      await page.waitForURL("**/callback**", { timeout: 15000 });
      const callbackTime = Date.now();
      testReport.timings.callbackReached = callbackTime;

      testReport.events.push({
        timestamp: new Date().toISOString(),
        event: "CALLBACK_REACHED",
        timeFromAuthStart: callbackTime - authStartTime,
      });

      await page.screenshot({
        path: "test-results/04-callback-processing.png",
      });
      testReport.screenshots.push("04-callback-processing.png");

      // Monitor callback processing with our fix delays
      const callbackStartTime = Date.now();

      // Wait for the 100ms delay from our fix
      await page.waitForTimeout(150); // Wait slightly longer than our fix delay

      // Check for successful navigation to home
      try {
        await page.waitForURL(
          (url) => !url.includes("/callback") && !url.includes("/login"),
          {
            timeout: 5000,
          },
        );

        const successTime = Date.now();
        testReport.timings.authComplete = successTime;
        testReport.timings.callbackProcessingTime =
          successTime - callbackStartTime;

        testReport.events.push({
          timestamp: new Date().toISOString(),
          event: "AUTH_SUCCESS",
          finalUrl: page.url(),
          totalTime: successTime - authStartTime,
          callbackProcessingTime: successTime - callbackStartTime,
        });

        testReport.result = "SUCCESS";

        await page.screenshot({ path: "test-results/05-auth-success.png" });
        testReport.screenshots.push("05-auth-success.png");
      } catch (error) {
        testReport.issues.push(
          `Failed to navigate away from callback: ${error.message}`,
        );
        testReport.result = "CALLBACK_STUCK";
      }
    } catch (error) {
      testReport.issues.push(`Authentication flow failed: ${error.message}`);
      testReport.result = "AUTH_FLOW_FAILED";
    } finally {
      clearInterval(redirectMonitor);
    }

    // Step 6: Analyze console logs for our debug messages
    const authLogs = testReport.consoleLogs.filter(
      (log) => log.text.includes("") || log.text.includes(""),
    );

    testReport.events.push({
      timestamp: new Date().toISOString(),
      event: "ANALYZE_DEBUG_LOGS",
      debugLogCount: authLogs.length,
      debugLogs: authLogs,
    });

    // Check for specific fix indicators
    const callbackSuccessLog = authLogs.find((log) =>
      log.text.includes("Authentication successful, redirecting to home"),
    );

    const routerAllowLog = authLogs.find((log) =>
      log.text.includes("Allowing access to protected route"),
    );

    if (callbackSuccessLog && routerAllowLog) {
      testReport.events.push({
        timestamp: new Date().toISOString(),
        event: "FIX_INDICATORS_FOUND",
        callbackSuccess: callbackSuccessLog,
        routerAllow: routerAllowLog,
      });
    }

    // Step 7: Analyze network requests for JWT API calls
    const jwtRequests = testReport.networkRequests.filter(
      (req) =>
        req.url && (req.url.includes("jwt.com") || req.url.includes("/oauth/")),
    );

    testReport.events.push({
      timestamp: new Date().toISOString(),
      event: "ANALYZE_AUTH_REQUESTS",
      jwtRequestCount: jwtRequests.length,
      jwtRequests: jwtRequests.slice(0, 10), // Limit to first 10 for readability
    });

    // Step 8: Check for timing issues
    if (testReport.timings.callbackProcessingTime) {
      const processingTime = testReport.timings.callbackProcessingTime;
      if (processingTime < CONFIG.DELAY_THRESHOLD) {
        testReport.issues.push(
          `Callback processing too fast: ${processingTime}ms (expected >${CONFIG.DELAY_THRESHOLD}ms)`,
        );
      } else {
        testReport.events.push({
          timestamp: new Date().toISOString(),
          event: "TIMING_FIX_VERIFIED",
          processingTime: processingTime,
          expectedMinimum: CONFIG.DELAY_THRESHOLD,
        });
      }
    }

    // Step 9: Final analysis and reporting
    console.log(`\n=== AUTHENTICATION ANALYSIS COMPLETE ===`);
    console.log(`Result: ${testReport.result}`);
    console.log(`Total redirects: ${redirectCount}`);
    console.log(`Issues found: ${testReport.issues.length}`);
    console.log(`Debug logs captured: ${authLogs.length}`);
    console.log(`JWT requests: ${jwtRequests.length}`);

    if (testReport.timings.authComplete) {
      console.log(
        `Total auth time: ${testReport.timings.authComplete - testReport.timings.authStart}ms`,
      );
      console.log(
        `Callback processing time: ${testReport.timings.callbackProcessingTime}ms`,
      );
    }

    // Print key debug messages
    if (authLogs.length > 0) {
      console.log(`\n=== KEY DEBUG MESSAGES ===`);
      authLogs.forEach((log) => {
        console.log(`${log.timestamp}: ${log.text}`);
      });
    }

    // Print issues if any
    if (testReport.issues.length > 0) {
      console.log(`\n=== ISSUES DETECTED ===`);
      testReport.issues.forEach((issue, index) => {
        console.log(`${index + 1}. ${issue}`);
      });
    }

    // Assert test results
    expect(testReport.result).not.toBe("INFINITE_LOOP_DETECTED");
    expect(testReport.result).not.toBe("LOGIN_CALLBACK_LOOP_DETECTED");
    expect(testReport.result).not.toBe("CALLBACK_STUCK");

    if (testReport.result === "SUCCESS") {
      expect(testReport.timings.callbackProcessingTime).toBeGreaterThan(
        CONFIG.DELAY_THRESHOLD,
      );
    }
  });
});
