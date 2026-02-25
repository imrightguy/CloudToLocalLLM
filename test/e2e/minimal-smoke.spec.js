// Minimal E2E Smoke Test for CloudToLocalLLM
// Verifies essential application functionality for post-deployment validation.

import { test, expect } from '@playwright/test';

test.describe('Minimal E2E Smoke Test', () => {

  // Test 1: Application loads successfully
  test('Application should load without errors', async ({ page }) => {
    // Navigate to the root URL
    await page.goto('/');

    // Wait for the page to be fully loaded
    await page.waitForLoadState('networkidle');

    // Check for the correct page title
    await expect(page).toHaveTitle(/CloudToLocalLLM/);

    // Verify that the main application container is visible
    const mainContent = page.locator('main, #root, .app');
    await expect(mainContent).toBeVisible();
    
    console.log(' Minimal Smoke Test: Application loaded successfully.');
  });

  // Test 2: No critical console errors on load
  test('Should not have critical console errors on page load', async ({ page }) => {
    const errors = [];
    
    // Listen for console errors
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    // Navigate to the application
    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Filter out non-critical, common errors
    const criticalErrors = errors.filter(error => 
      !error.includes('favicon.ico') && 
      !error.includes('manifest.json')
    );

    // Assert that there are no critical errors
    expect(criticalErrors.length).toBe(0);

    console.log(' Minimal Smoke Test: No critical console errors detected on load.');
  });
});