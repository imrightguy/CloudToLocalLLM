// Minimal Flutter Service Worker
// This is a stub service worker that prevents Flutter from timing out
// while waiting for service worker initialization

self.addEventListener("install", (_event) => {
  console.log("[Service Worker] Installing...");
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  console.log("[Service Worker] Activating...");
  // Claim all clients immediately
  event.waitUntil(clients.claim());
});

self.addEventListener("fetch", (event) => {
  // Pass through all requests - no caching
  // This allows the app to work without service worker caching
  event.respondWith(
    fetch(event.request).catch(() => {
      // If fetch fails, return a basic error response
      return new Response("Service unavailable", {
        status: 503,
        statusText: "Service Unavailable",
      });
    }),
  );
});

console.log("[Service Worker] Loaded and ready");
