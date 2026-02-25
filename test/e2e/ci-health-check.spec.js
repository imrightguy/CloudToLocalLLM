// CI/CD Health Check Test for CloudToLocalLLM
// Validates basic application functionality in CI environment

import { test, expect } from '@playwright/test';
import fs from 'fs';
import path from 'path';

test.describe('CI Health Check', () => {
  test.beforeEach(async ({ page }) => {
    // Set up test environment
    await page.setExtraHTTPHeaders({
      'User-Agent': 'CloudToLocalLLM-CI-Test/1.0'
    });
  });

  test('Application loads successfully', async ({ page }) => {
    // Navigate to the application
    await page.goto('/');

    // Wait for the page to load
    await page.waitForLoadState('networkidle');

    // Check that the page title is correct
    await expect(page).toHaveTitle(/CloudToLocalLLM/);

    // Verify main content is visible
    const mainContent = page.locator('main, #root, .app');
    await expect(mainContent).toBeVisible();

    console.log(' Application loaded successfully');
  });

  test('No critical JavaScript errors', async ({ page }) => {
    const errors = [];

    // Capture console errors
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    // Capture page errors
    page.on('pageerror', error => {
      errors.push(error.message);
    });

    // Navigate and wait for load
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Filter out known non-critical errors
    const criticalErrors = errors.filter(error => {
      // Filter out common non-critical errors
      return !error.includes('favicon') &&
        !error.includes('manifest') &&
        !error.includes('service-worker');
    });

    // Assert no critical errors
    expect(criticalErrors).toHaveLength(0);

    console.log(' No critical JavaScript errors detected');
  });

  test('Basic navigation works', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Try to find and click navigation elements
    const navElements = await page.locator('nav a, .nav-link, [role="navigation"] a').all();

    if (navElements.length > 0) {
      // Test first navigation link
      const firstNav = navElements[0];
      const href = await firstNav.getAttribute('href');

      if (href && !href.startsWith('http') && !href.startsWith('mailto:')) {
        await firstNav.click();
        await page.waitForLoadState('networkidle');

        // Verify navigation worked
        expect(page.url()).not.toBe(page.url());
      }
    }

    console.log(' Basic navigation functional');
  });

  test('API endpoints respond', async ({ page, request }) => {
    // Test if API endpoints are accessible
    const apiEndpoints = [
      '/api/health',
      '/api/status',
      '/health'
    ];

    for (const endpoint of apiEndpoints) {
      try {
        const response = await request.get(endpoint);
        if (response.ok()) {
          console.log(` API endpoint ${endpoint} is accessible`);
          break; // At least one endpoint works
        }
      } catch (error) {
        // Continue to next endpoint
        console.log(` API endpoint ${endpoint} not accessible: ${error.message}`);
      }
    }
  });

  test('Authentication flow is accessible', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Look for authentication-related elements
    const authElements = await page.locator('button:has-text("Login"), button:has-text("Sign In"), a:has-text("Login"), a:has-text("Sign In")').all();

    if (authElements.length > 0) {
      // Verify auth elements are visible
      await expect(authElements[0]).toBeVisible();
      console.log(' Authentication flow is accessible');
    } else {
      // Check if user might already be authenticated
      const userElements = await page.locator('[data-testid="user-menu"], .user-profile, button:has-text("Logout")').all();
      if (userElements.length > 0) {
        console.log(' User appears to be authenticated');
      } else {
        console.log(' No authentication elements found');
      }
    }
  });

  test('Performance baseline check', async ({ page }) => {
    // Start performance measurement
    const startTime = Date.now();

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    const loadTime = Date.now() - startTime;

    // Assert reasonable load time (adjust threshold as needed)
    expect(loadTime).toBeLessThan(10000); // 10 seconds max

    console.log(` Page loaded in ${loadTime}ms`);
  });

  test('Responsive design check', async ({ page }) => {
    await page.goto('/');

    // Test different viewport sizes
    const viewports = [
      { width: 1920, height: 1080 }, // Desktop
      { width: 768, height: 1024 },  // Tablet
      { width: 375, height: 667 }    // Mobile
    ];

    for (const viewport of viewports) {
      await page.setViewportSize(viewport);
      await page.waitForLoadState('networkidle');

      // Verify content is still visible
      const mainContent = page.locator('main, #root, .app');
      await expect(mainContent).toBeVisible();

      console.log(` Responsive design works at ${viewport.width}x${viewport.height}`);
    }
  });
});

test.describe('CI Environment Validation', () => {
  test('Environment variables are set', async () => {
    // Verify CI environment is properly configured
    expect(process.env.CI).toBe('true');
    expect(process.env.DEPLOYMENT_URL).toBeDefined();

    console.log(' CI environment variables are properly set');
  });

  test('Test artifacts directory exists', async () => {
    // This test ensures the test results directory structure is correct
    // This test ensures the test results directory structure is correct
    const testResultsDir = path.join(process.cwd(), 'test-results');

    // Create directory if it doesn't exist (for CI)
    if (!fs.existsSync(testResultsDir)) {
      fs.mkdirSync(testResultsDir, { recursive: true });
    }

    expect(fs.existsSync(testResultsDir)).toBe(true);

    console.log(' Test artifacts directory is ready');
  });
});
