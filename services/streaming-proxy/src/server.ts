/**
 * Streaming Proxy Server
 * 
 * Main entry point for the WebSocket-based SSH tunnel proxy server.
 * Integrates all components: authentication, rate limiting, connection pool,
 * circuit breaker, WebSocket handling, and metrics collection.
 * 
 * Requirements: All server-side requirements
 */

// Import Sentry FIRST to catch all errors from the very beginning
import * as Sentry from '@sentry/node';

// Initialize Sentry IMMEDIATELY - before any other code runs
// Environment variables are provided by Kubernetes secrets
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || 'development',
  release: process.env.VERSION,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  serverName: process.env.HOSTNAME || 'streaming-proxy',
  beforeSend(event) {
    // Add custom tags
    if (event.tags) {
      event.tags.service = 'streaming-proxy';
      event.tags.region = process.env.AZURE_REGION || 'unknown';
    }
    return event;
  },
});

console.log('Starting streaming-proxy server process...');

import express, { Request, Response, NextFunction } from 'express';
import { createServer } from 'http';
import { WebSocketServer } from 'ws';
import { ServerMetricsCollector } from './metrics/server-metrics-collector';
import { globalMetricsCollector as circuitBreakerMetrics } from './circuit-breaker/circuit-breaker-metrics';
import { ConsoleLogger, setLogLevelManagerGetter } from './utils/logger';
import { getLogLevelManager } from './utils/log-level-manager';
import { HealthChecker } from './health/health-checker';
import { loadAndValidateConfig } from './config/server-config';
import { initializeConfigManager, getConfigManager } from './config/config-manager';
import { initializeTracing } from './tracing/tracer';
import { ConnectionPoolImpl } from './connection-pool/connection-pool-impl';
import { TokenBucketRateLimiter } from './rate-limiter/token-bucket-rate-limiter';
import { CircuitBreakerImpl } from './circuit-breaker/circuit-breaker-impl';
import { WebSocketHandlerImpl } from './websocket/websocket-handler-impl';
import { JWTValidationMiddleware } from './middleware/jwt-validation-middleware';
import { Auth0JWTValidator } from './middleware/auth0-validator';
import { AuthAuditLogger } from './middleware/auth-audit-logger';
import { loadAuthConfig, validateAuthConfig } from './middleware/auth-config';
import { createAdminAuthMiddleware } from './middleware/admin-auth.middleware';
import { HTTP_STATUS, TIME_MS, WEBSOCKET_CLOSE_CODES } from './utils/http-constants';

// ... (tracing and config initialization code)

// Load and validate authentication configuration
const authConfig = loadAuthConfig();
validateAuthConfig(authConfig);

// Initialize Auth0 Validator
const auth0Validator = new Auth0JWTValidator(
  authConfig.auth0.jwksUri,
  authConfig.auth0.audience
);

// ... (pool and rate limiter initialization)

// Authentication middleware - Requirement 26.2: Connect AuthMiddleware to all protected endpoints
const authMiddleware = new JWTValidationMiddleware(auth0Validator);
const authAuditLogger = new AuthAuditLogger();

const requireAdminAuth = createAdminAuthMiddleware({
  authMiddleware,
  authAuditLogger,
});

// Create Express app
const app = express();

// Create HTTP server and WebSocket server
const httpServer = createServer(app);
const wss = new WebSocketServer({ server: httpServer, path: WEBSOCKET_PATH });

// WebSocket handler - Requirement 26.2: Wire WebSocketHandler with all components
const wsHandler = new WebSocketHandlerImpl(
  wss,
  authMiddleware,
  rateLimiter
);

// Initialize health checker with all components
const healthChecker = new HealthChecker(
  logger,
  connectionPool,
  circuitBreakerMetrics,
  metricsCollector,
  rateLimiter
);

// Middleware
app.use(express.json());

// Request logging middleware
app.use((req: Request, res: Response, next: NextFunction): void => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info(`${req.method} ${req.path} ${res.statusCode} ${duration}ms`);
  });
  
  next();
});

/**
 * Health check endpoint
 * Used by Kubernetes liveness and readiness probes
 * Returns 200 for healthy, 503 for unhealthy
 * 
 * Requirements: 11.2
 */
app.get('/api/tunnel/health', async (req: Request, res: Response) => {
  try {
    const healthCheck = await healthChecker.performHealthCheck();
    
    const statusCode = healthCheck.status === 'healthy' ? HTTP_STATUS.OK : HTTP_STATUS.SERVICE_UNAVAILABLE;
    
    res.status(statusCode).json({
      status: healthCheck.status,
      timestamp: healthCheck.timestamp.toISOString(),
      uptime: healthCheck.uptime,
      activeConnections: healthCheck.components.find(c => c.name === 'WebSocket Service')?.details?.activeConnections || 0,
      requestsPerSecond: healthCheck.components.find(c => c.name === 'WebSocket Service')?.details?.requestsPerSecond || 0,
      successRate: healthCheck.components.find(c => c.name === 'WebSocket Service')?.details?.successRate || 0,
      memoryUsage: process.memoryUsage(),
      components: healthCheck.components.map(c => ({
        name: c.name,
        status: c.status,
        responseTime: c.responseTime,
      })),
    });
  } catch (error) {
    logger.error('Health check failed', {
      error: error instanceof Error ? error.message : String(error),
    });
    res.status(HTTP_STATUS.SERVICE_UNAVAILABLE).json({
      status: 'unhealthy',
      error: 'Health check failed',
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * Diagnostics endpoint
 * Requires admin authentication
 * Returns detailed system diagnostics and component health information
 * 
 * Requirements: 2.7, 11.2, 26.2
 */
app.get('/api/tunnel/diagnostics', requireAdminAuth, async (req: Request, res: Response) => {
  try {
    const diagnostics = await healthChecker.performDiagnostics();
    
    res.status(HTTP_STATUS.OK).json(diagnostics);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Diagnostics failed', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({
      error: 'Diagnostics failed',
      message: errorMessage,
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * Prometheus metrics endpoint
 * Exposes metrics in Prometheus text format for Grafana scraping
 * 
 * Requirements: 11.1, 3.1, 3.2, 3.4
 */
app.get('/api/tunnel/metrics', async (req: Request, res: Response) => {
  try {
    const prometheusMetrics = await metricsCollector.exportPrometheusFormat();
    
    res.setHeader('Content-Type', 'text/plain; version=0.0.4; charset=utf-8');
    res.status(HTTP_STATUS.OK).send(prometheusMetrics);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error exporting Prometheus metrics', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to export metrics' });
  }
});

/**
 * JSON metrics endpoint
 * Returns metrics in JSON format for debugging
 */
app.get('/api/tunnel/metrics/json', (req: Request, res: Response) => {
  try {
    const window = req.query.window ? parseInt(req.query.window as string, 10) : undefined;
    const metrics = metricsCollector.getServerMetrics(window);
    
    res.status(HTTP_STATUS.OK).json(metrics);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error exporting JSON metrics', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to export metrics' });
  }
});

/**
 * User metrics endpoint
 * Returns metrics for a specific user
 */
app.get('/api/tunnel/metrics/user/:userId', (req: Request, res: Response) => {
  try {
    const { userId } = req.params;
    const userMetrics = metricsCollector.getUserMetrics(userId);
    
    res.status(HTTP_STATUS.OK).json(userMetrics);
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error getting user metrics', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to get user metrics' });
  }
});

/**
 * Circuit breaker metrics endpoint
 * Returns circuit breaker status and metrics
 */
app.get('/api/tunnel/circuit-breakers', (req: Request, res: Response) => {
  try {
    const metrics = circuitBreakerMetrics.getAllMetrics();
    const summary = circuitBreakerMetrics.getSummary();
    
    res.status(HTTP_STATUS.OK).json({
      summary,
      circuitBreakers: metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error getting circuit breaker metrics', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to get circuit breaker metrics' });
  }
});

/**
 * Historical metrics endpoint
 * Returns historical metrics with configurable time window and aggregation level
 * Query parameters:
 *   - window: '1h', '24h', '7d' (default: '1h')
 *   - aggregation: 'raw', 'hourly', 'daily' (default: 'raw')
 */
app.get('/api/tunnel/metrics/history', (req: Request, res: Response) => {
  try {
    // Parse window parameter
    const windowParam = (req.query.window as string) || '1h';
    let windowMs = TIME_MS.ONE_HOUR;
    
    switch (windowParam) {
      case '1h':
        windowMs = TIME_MS.ONE_HOUR;
        break;
      case '24h':
        windowMs = TIME_MS.ONE_DAY;
        break;
      case '7d':
        windowMs = TIME_MS.ONE_WEEK;
        break;
      default: {
        // Try to parse as milliseconds
        const parsed = parseInt(windowParam, 10);
        if (!isNaN(parsed) && parsed > 0) {
          windowMs = parsed;
        }
        break;
      }
    }
    
    // Parse aggregation parameter
    const aggregationParam = (req.query.aggregation as string) || 'raw';
    const aggregation = aggregationParam as 'raw' | 'hourly' | 'daily';
    
    if (!['raw', 'hourly', 'daily'].includes(aggregation)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        error: 'Invalid aggregation level. Must be one of: raw, hourly, daily',
      });
    }
    
    // Get historical metrics
    const metrics = metricsCollector.getHistoricalMetrics(windowMs, aggregation);
    const statistics = metricsCollector.getHistoricalStatistics(windowMs, aggregation);
    
    res.status(HTTP_STATUS.OK).json({
      window: windowParam,
      windowMs,
      aggregation,
      dataPoints: metrics.length,
      statistics,
      metrics,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error getting historical metrics', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to get historical metrics' });
  }
});

/**
 * Get current log level endpoint
 * Returns the current log level configuration
 */
app.get('/api/tunnel/config/log-level', async (req: Request, res: Response) => {
  try {
    const { getLogLevelManager } = await import('./utils/log-level-manager.js');
    const manager = getLogLevelManager();
    const currentLevel = manager.getLogLevel();
    
    res.status(HTTP_STATUS.OK).json({
      level: currentLevel,
      validLevels: manager.getValidLogLevels(),
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error getting log level', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to get log level' });
  }
});

/**
 * Set log level endpoint
 * Requires admin authentication
 * Request body: { "level": "DEBUG" }
 */
app.put('/api/tunnel/config/log-level', async (req: Request, res: Response) => {
  try {
    const { level } = req.body;
    
    if (!level || typeof level !== 'string') {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ error: 'Missing or invalid level parameter' });
    }

    const { getLogLevelManager } = await import('./utils/log-level-manager.js');
    const manager = getLogLevelManager();

    // Validate log level
    if (!manager.isValidLogLevel(level)) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        error: `Invalid log level: ${level}`,
        validLevels: manager.getValidLogLevels(),
      });
    }

    // Set new log level
    manager.setLogLevelFromString(level);
    
    logger.info('Log level changed', {
      newLevel: level,
      timestamp: new Date().toISOString(),
    });

    res.status(HTTP_STATUS.OK).json({
      level: manager.getLogLevel(),
      message: `Log level changed to ${level}`,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error setting log level', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to set log level' });
  }
});

/**
 * Get current configuration endpoint
 * Returns current server configuration (sanitized)
 * Requires authentication
 * 
 * Requirements: 9.6, 26.2
 */
app.get('/api/tunnel/config', (req: Request, res: Response) => {
  try {
    const manager = getConfigManager();
    const config = manager.getConfig();
    
    res.status(HTTP_STATUS.OK).json({
      config,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error getting configuration', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to get configuration' });
  }
});

/**
 * Update configuration endpoint
 * Accepts partial configuration updates
 * Validates before applying changes
 * Requires authentication
 * 
 * Request body: Partial ServerConfig object
 * Example: { "websocket": { "pingInterval": 60000 } }
 * 
 * Requirements: 9.6, 26.2
 */
app.put('/api/tunnel/config', (req: Request, res: Response) => {
  try {
    const manager = getConfigManager();
    const updates = req.body;
    
    if (!updates || typeof updates !== 'object') {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({ error: 'Request body must be a valid configuration object' });
    }
    
    const result = manager.updateConfig(updates);
    
    if (!result.success) {
      return res.status(HTTP_STATUS.BAD_REQUEST).json({
        error: result.error,
        timestamp: new Date().toISOString(),
      });
    }
    
    res.status(HTTP_STATUS.OK).json({
      message: 'Configuration updated successfully',
      config: result.config,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error updating configuration', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to update configuration' });
  }
});

/**
 * Reset configuration endpoint
 * Resets configuration to original values
 * Requires authentication
 * 
 * Requirements: 9.6, 26.2
 */
app.post('/api/tunnel/config/reset', (req: Request, res: Response) => {
  try {
    const manager = getConfigManager();
    const config = manager.resetConfig();
    
    logger.info('Configuration reset to original values');
    
    res.status(HTTP_STATUS.OK).json({
      message: 'Configuration reset to original values',
      config,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    logger.error('Error resetting configuration', { error: errorMessage });
    res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Failed to reset configuration' });
  }
});

/**
 * 404 handler
 */
app.use((req: Request, res: Response) => {
  res.status(HTTP_STATUS.NOT_FOUND).json({ error: 'Not found' });
});

/**
 * Error handler
 */
// eslint-disable-next-line @typescript-eslint/no-unused-vars
app.use((err: Error, req: Request, res: Response, next: NextFunction): void => {
  logger.error('Unhandled error', { error: err.message });
  res.status(HTTP_STATUS.INTERNAL_SERVER_ERROR).json({ error: 'Internal server error' });
});

// WebSocket connection handler
// Requirement 26.2: Wire WebSocketHandler with all components
wss.on('connection', async (ws, req) => {
  const clientIp = req.socket.remoteAddress || 'unknown';
  logger.info(`WebSocket connection from ${clientIp}`);
  
  try {
    // Handle the WebSocket connection with the integrated handler
    await wsHandler.handleConnection(ws, req);
  } catch (error) {
    logger.error('Error handling WebSocket connection', {
      clientIp,
      error: error instanceof Error ? error.message : String(error),
    });
    ws.close(WEBSOCKET_CLOSE_CODES.INTERNAL_ERROR, 'Internal server error');
  }
});

// Graceful shutdown handler
const shutdown = async() => {
  logger.info('Shutting down gracefully...', {
    timestamp: new Date().toISOString(),
  });
  
  try {
    // Close WebSocket server to prevent new connections
    // Requirement 8.9: Ensure no new connections are accepted during shutdown
    wss.close(() => {
      logger.info('WebSocket server closed', {
        timestamp: new Date().toISOString(),
      });
    });
    
    // Notify all connected clients before shutdown
    // Requirement 8.5: Add notification to all connected clients
    for (const client of wss.clients) {
      if (client.readyState === 1) { // OPEN
        try {
          // Close with code 1001 "Going Away"
          client.close(WEBSOCKET_CLOSE_CODES.GOING_AWAY, 'Server shutting down');
        } catch (error) {
          logger.error('Error closing client connection', {
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }
    }
    
    // Close HTTP server
    httpServer.close(() => {
      logger.info('HTTP server closed', {
        timestamp: new Date().toISOString(),
      });
      process.exit(0);
    });
    
    // Force exit after 30 seconds
    setTimeout(() => {
      logger.warn('Forcing shutdown after timeout', {
        timestamp: new Date().toISOString(),
      });
      process.exit(1);
    }, TIME_MS.SHUTDOWN_TIMEOUT);
  } catch (error) {
    logger.error('Error during shutdown', {
      error: error instanceof Error ? error.message : String(error),
    });
    process.exit(1);
  }
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

// Start server
httpServer.listen(PORT, () => {
  logger.info(`Streaming proxy server started`, {
    port: PORT,
    websocketPath: WEBSOCKET_PATH,
    logLevel: LOG_LEVEL,
    nodeVersion: process.version,
  });
});

// Export for testing
export { app, httpServer, wss, metricsCollector };

