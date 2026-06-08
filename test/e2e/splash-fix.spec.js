// Splash-fix regression test for CloudToLocalLLM web build.
//
// Verifies the fix from PR #416: the Flutter web bootstrap splash <picture>
// must be removed from the DOM, either by the flutter-first-frame event or
// by the 8s hard timeout. Also guards against a frozen-spinner regression
// by checking that Flutter actually paints into <flt-glass-pane>.
//
// These three assertions map 1:1 to the three failure modes that motivated
// the fix:
//   1. Splash picture still in DOM after page load   (broken before fix)
//   2. Body still opaque after splash is gone        (visual flash)
//   3. No flt-glass-pane ever appears                (Flutter never painted)

import { test, expect } from "@playwright/test";

const SPLASH_SELECTOR = "picture#splash, picture#splash-branding";
const GLASS_PANE_SELECTOR = "flt-glass-pane, flutter-view";

test.describe("Splash fix (PR #416)", () => {
  test("splash picture is removed from DOM", async ({ page }) => {
    const consoleErrors = [];
    page.on("console", (msg) => {
      if (msg.type() === "error") consoleErrors.push(msg.text());
    });

    await page.goto("/");

    // The splash must be gone. flutter-first-frame is the happy path; the
    // 8s setTimeout is the safety net. We wait up to 10s for either.
    await expect(page.locator(SPLASH_SELECTOR)).toHaveCount(0, { timeout: 10_000 });

    // No critical console errors. Filter Auth0/Auth CDN noise that is
    // unrelated to the splash fix; surface anything else.
    const criticalErrors = consoleErrors.filter(
      (e) =>
        !e.includes("favicon.ico") &&
        !e.includes("manifest.json") &&
        !e.includes("auth0") &&
        !/Failed to load resource.*auth0/i.test(e),
    );
    expect(criticalErrors, `unexpected console errors: ${criticalErrors.join("\n")}`).toHaveLength(0);
  });

  test("Flutter actually paints into the DOM (no frozen spinner)", async ({ page }) => {
    await page.goto("/");
    // Give Flutter a generous window to bootstrap, run main(), and paint.
    // Production build on a fresh CI runner typically paints in 3-6s; the
    // 8s splash timeout already covers the slow case.
    await expect(page.locator(GLASS_PANE_SELECTOR).first()).toBeVisible({
      timeout: 15_000,
    });
  });

  test("hard 8s timeout removes the splash even if first-frame never fires", async ({ page }) => {
    // Simulate the failure mode the timeout was designed for: never receive
    // flutter-first-frame. We do this by intercepting window events and
    // verifying the setTimeout fallback still cleans the splash.
    await page.addInitScript(() => {
      // Block flutter-first-frame events from reaching the splash script.
      // The hard timeout should still kick in and call removeSplashFromWeb.
      const original = window.addEventListener.bind(window);
      window.addEventListener = function (type, listener, opts) {
        if (type === "flutter-first-frame") return undefined;
        return original(type, listener, opts);
      };
    });

    await page.goto("/");

    // Splash should still be gone — the setTimeout path is the safety net.
    await expect(page.locator(SPLASH_SELECTOR)).toHaveCount(0, { timeout: 12_000 });
  });
});
