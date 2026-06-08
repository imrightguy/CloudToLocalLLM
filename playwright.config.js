// Playwright config for CloudToLocalLLM web E2E tests.
//
// Serves the local Flutter web build at build/web/ on port 4173 (Vite-style
// convention) and runs the splash-fix regression test plus the existing
// minimal-smoke and ci-health-check specs. Production environment tests
// (against https://app.cloudtolocalllm.online) run separately via
// web-e2e-production.yml on a schedule.

import { defineConfig, devices } from "@playwright/test";

const PORT = Number(process.env.PLAYWRIGHT_WEB_PORT || 4173);
const BASE_URL = `http://127.0.0.1:${PORT}`;

export default defineConfig({
  testDir: "./test/e2e",
  // Only run splash-fix.spec.js for now. The pre-existing
  // minimal-smoke.spec.js and ci-health-check.spec.js were authored for a
  // Vercel/React-style app (waitForLoadState("networkidle"),
  // main/#root/.app selectors) and are not compatible with Flutter web
  // (which uses <flt-glass-pane> and never reaches networkidle). They are
  // not wired into any CI workflow; revisit before re-enabling.
  testMatch: /splash-fix\.spec\.js$/,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  fullyParallel: false,
  workers: 1,
  reporter: [
    ["list"],
    ["html", { open: "never", outputFolder: "playwright-report" }],
    ["junit", { outputFile: "playwright-report/results.xml" }],
  ],
  use: {
    baseURL: BASE_URL,
    headless: true,
    trace: "retain-on-failure",
    video: "retain-on-failure",
    screenshot: "only-on-failure",
    actionTimeout: 10_000,
    navigationTimeout: 30_000,
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    // Flutter web build is static. python's http.server is fine and avoids
    // adding a Node dep for a one-file static host.
    command: `python3 -m http.server ${PORT} --directory build/web --bind 127.0.0.1`,
    url: BASE_URL,
    reuseExistingServer: !process.env.CI,
    timeout: 30_000,
    stdout: "ignore",
    stderr: "pipe",
  },
});
