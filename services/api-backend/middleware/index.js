import { setupMiddlewarePipeline } from './pipeline.js';
import { setupGracefulShutdown } from './graceful-shutdown.js';
import { standardCorsOptions } from './cors-config.js';

export function setupAppMiddleware(app, server, logger) {
  // Trust proxy headers (required for rate limiting behind nginx)
  // Use specific proxy configuration to avoid ERR_ERL_PERMISSIVE_TRUST_PROXY
  app.set('trust proxy', 1); // Trust first proxy (nginx)

  // Setup middleware pipeline with proper ordering
  setupMiddlewarePipeline(app, {
    corsOptions: standardCorsOptions,
    rateLimitOptions: {
      windowMs: 15 * 60 * 1000,
      max: 100,
      bridgeMax: 500,
    },
    timeoutMs: 30000,
    enableCompression: true,
  });

  // Prevent 502s by ensuring Node keep-alive is longer than Nginx (60s)
  server.keepAliveTimeout = 65000; // 65 seconds
  server.headersTimeout = 66000; // 66 seconds (must be > keepAliveTimeout)

  // Setup graceful shutdown with in-flight request completion
  const shutdownManager = setupGracefulShutdown(server, {
    shutdownTimeoutMs: 10000,
    onShutdown: async () => {
      logger.info('Running custom shutdown handlers');
      // Custom shutdown logic will be added here
    },
  });

  return shutdownManager;
}
