// Import Sentry FIRST to catch all errors from the very beginning
import * as Sentry from '@sentry/node';
import dotenv from 'dotenv';

// Load environment variables before anything else
dotenv.config();

// Initialize Sentry IMMEDIATELY - before any other code runs
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || 'development',
  release: process.env.VERSION || process.env.npm_package_version,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  serverName: process.env.HOSTNAME || 'api-backend',
  ignoreErrors: [
    'UnauthorizedError',
    'ForbiddenError',
    'Validation failed',
    'SequelizeValidationError',
    'JsonWebTokenError',
    'TokenExpiredError',
    /^40[134]/, // Ignore 401, 403, 404
  ],
  beforeSend(event) {
    // Add custom tags
    event.tags = event.tags || {};
    event.tags.service = 'api-backend';
    event.tags.region = process.env.AZURE_REGION || 'unknown';
    event.tags.db_type = process.env.DB_TYPE || 'postgres';
    event.tags.node_env = process.env.NODE_ENV || 'development';

    // Scrub user data if present in extra
    if (event.extra && event.extra.user) {
      delete event.extra.user.email;
    }

    return event;
  },
});

// console.log('Starting api-backend server process...'); // Moved to logger below
import express from 'express';
import http from 'http';
import winston from 'winston';
import swaggerUi from 'swagger-ui-express';
const specs = {
  openapi: '3.0.0',
  info: {
    title: 'CloudToLocalLLM API Backend',
    version: '2.0.0',
    description:
      'Comprehensive API for CloudToLocalLLM - Bridge cloud AI services with local models',
  },
  paths: {},
};
import {
  setupMiddlewarePipeline,
  getAuthMiddleware,
} from './middleware/pipeline.js';
import { setupGracefulShutdown } from './middleware/graceful-shutdown.js';
import { standardCorsOptions } from './middleware/cors-config.js';

import adminRoutes from './routes/admin.js';
import adminUserRoutes from './routes/admin/users.js';
import adminSubscriptionRoutes from './routes/admin/subscriptions.js';
import userRoutes from './routes/users.js';
import userProfileRoutes, {
  initializeUserProfileService,
} from './routes/user-profile.js';
import sessionRoutes from './routes/sessions.js';
import clientLogRoutes from './routes/client-logs.js';
import webhookRoutes from './routes/webhooks.js';
import authRoutes from './routes/auth.js';
import apiKeysRouter from './routes/api-keys.js';
import tunnelRoutes, { initializeTunnelService } from './routes/tunnels.js';
import adaptiveRateLimitingRoutes from './routes/adaptive-rate-limiting.js';
import adminMetricsRoutes from './routes/admin-metrics.js';
import alertConfigurationRoutes from './routes/alert-configuration.js';
import authAuditRoutes from './routes/auth-audit.js';
import backupRecoveryRoutes from './routes/backup-recovery.js';
import bridgePollingRoutes from './routes/bridge-polling-routes.js';
import cacheMetricsRoutes from './routes/cache-metrics.js';
import deprecationRoutes from './routes/deprecation.js';
import directProxyRoutes from './routes/direct-proxy-routes.js';
import errorRecoveryRoutes from './routes/error-recovery.js';
import failoverRoutes from './routes/failover.js';
import proxyConfigRoutes from './routes/proxy-config.js';
import proxyDiagnosticsRoutes from './routes/proxy-diagnostics.js';
import proxyFailoverRoutes from './routes/proxy-failover.js';
import proxyHealthRoutes from './routes/proxy-health.js';
import proxyMetricsRoutes from './routes/proxy-metrics.js';
import proxyScalingRoutes from './routes/proxy-scaling.js';
import proxyUsageRoutes from './routes/proxy-usage.js';
import proxyWebhooksRoutes from './routes/proxy-webhooks.js';
import quotasRoutes from './routes/quotas.js';
import rateLimitExemptionsRoutes from './routes/rate-limit-exemptions.js';
import rateLimitViolationsRoutes from './routes/rate-limit-violations.js';
import sandboxRoutes from './routes/sandbox.js';
import dashboardWSManager from './websocket/dashboard-ws.js';
import tunnelFailoverRoutes from './routes/tunnel-failover.js';
import tunnelHealthRoutes from './routes/tunnel-health.js';
import tunnelSharingRoutes from './routes/tunnel-sharing.js';
import tunnelUsageRoutes from './routes/tunnel-usage.js';
import tunnelWebhooksRoutes from './routes/tunnel-webhooks.js';
import userActivityRoutes from './routes/user-activity.js';
import userDeletionRoutes from './routes/user-deletion.js';
import webhookEventFiltersRoutes from './routes/webhook-event-filters.js';
import webhookPayloadTransformationsRoutes from './routes/webhook-payload-transformations.js';
import webhookRateLimitingRoutes from './routes/webhook-rate-limiting.js';
import webhookTestingRoutes from './routes/webhook-testing.js';
import infrastructureTunnelRoutes from './routes/infrastructure-tunnel.js';
// SSH tunnel integration
import { SSHProxy } from './tunnel/ssh-proxy.js';
import { AuthService } from './auth/auth-service.js';
import { DatabaseMigratorPG } from './database/migrate-pg.js';
import { AuthDatabaseMigratorPG } from './database/migrate-auth-pg.js';
import { initializePool } from './database/db-pool.js';
import { startMonitoring, stopMonitoring } from './database/pool-monitor.js';
import dbHealthRoutes from './routes/db-health.js';
import databasePerformanceRoutes from './routes/database-performance.js';
import turnCredentialsRoutes from './routes/turn-credentials.js';
import { createTunnelRoutes } from './tunnel/tunnel-routes.js';
import { createMonitoringRoutes } from './routes/monitoring.js';
import { createConversationRoutes } from './routes/conversations.js';
import { authenticateJWT } from './middleware/auth.js';
import serviceVersionHandler from './routes/service-version.js';
import { addTierInfo } from './middleware/tier-check.js';
import { HealthCheckService } from './services/health-check.js';
import {
  setDbMigrator,
  dbHealthHandler,
  setSshProxy,
  handleOllamaProxyRequest,
  userTierHandler,
  versionInfoHandler,
  queueStatusHandler,
  queueDrainHandler,
  proxyStartHandler,
  proxyStopHandler,
  proxyProvisionHandler,
  proxyStatusHandler,
} from './routes/handlers.js';
import rateLimitMetricsRoutes from './routes/rate-limit-metrics.js';
import prometheusMetricsRoutes from './routes/prometheus-metrics.js';
import changelogRoutes from './routes/changelog.js';
import agentEventsRoutes from './routes/agent-events.js';
import subagentRegistryRoutes from './routes/subagent-registry-routes.js';
import modelsRoutes from './routes/models-routes.js';
import contextUsageRoutes from './routes/context-usage-routes.js';
import behaviorWarningsRoutes from './routes/behavior-warnings-routes.js';

// Sentry and dotenv already initialized at top of file

import Transport from 'winston-transport';

// Initialize Sentry Winston Transport
const SentryWinstonTransport = Sentry.createSentryWinstonTransport(Transport);

// Initialize logger
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'cloudtolocalllm-api' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
    new SentryWinstonTransport({
      level: 'info', // Capture info and above
    }),
  ],
});

// Configuration
const PORT = process.env.PORT || 8080;
const LEGACY_PROXY_ROUTES_ENABLED =
  process.env.CLOUDTOLOCALLLM_ENABLE_LEGACY_PROXY_ROUTES === 'true';
const LEGACY_TUNNEL_ROUTES_ENABLED =
  LEGACY_PROXY_ROUTES_ENABLED ||
  process.env.CLOUDTOLOCALLLM_ENABLE_LEGACY_TUNNEL_ROUTES === 'true';
const LEGACY_OLLAMA_PROXY_ENABLED =
  LEGACY_PROXY_ROUTES_ENABLED ||
  process.env.CLOUDTOLOCALLLM_ENABLE_LEGACY_OLLAMA_PROXY === 'true';
const LEGACY_STREAMING_PROXY_ROUTES_ENABLED =
  LEGACY_PROXY_ROUTES_ENABLED ||
  process.env.CLOUDTOLOCALLLM_ENABLE_LEGACY_STREAMING_PROXY_ROUTES === 'true';
const LEGACY_DIRECT_PROXY_ROUTES_ENABLED =
  LEGACY_PROXY_ROUTES_ENABLED ||
  process.env.CLOUDTOLOCALLLM_ENABLE_LEGACY_DIRECT_PROXY_ROUTES === 'true';

// AuthService will be initialized in initializeHttpPollingSystem()

// Express app setup
const app = express();

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

const server = http.createServer(app);
dashboardWSManager.initialize(server, logger);

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

// SSH tunnel server and auth service (initialized in initializeTunnelSystem)
let sshProxy = null;
let sshAuthService = null;

// Health check service
const healthCheckService = new HealthCheckService(logger);

// Webhook routes MUST be mounted before body parsing middleware
// Stripe requires raw body for signature verification
app.use('/api/webhooks', webhookRoutes);
app.use('/webhooks', webhookRoutes); // Also register without /api prefix for api subdomain

// Swagger UI documentation endpoint
// Serves OpenAPI specification and interactive Swagger UI
app.use(
  '/api/docs',
  swaggerUi.serve,
  swaggerUi.setup(specs, {
    swaggerOptions: {
      url: '/api/docs/swagger.json',
      displayOperationId: true,
      filter: true,
      showExtensions: true,
      deepLinking: true,
    },
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'CloudToLocalLLM API Documentation',
  }),
);

// Serve OpenAPI specification as JSON
app.get('/api/docs/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(specs);
});

// Also serve docs without /api prefix for api subdomain
app.use(
  '/docs',
  swaggerUi.serve,
  swaggerUi.setup(specs, {
    swaggerOptions: {
      url: '/docs/swagger.json',
      displayOperationId: true,
      filter: true,
      showExtensions: true,
      deepLinking: true,
    },
    customCss: '.swagger-ui .topbar { display: none }',
    customSiteTitle: 'CloudToLocalLLM API Documentation',
  }),
);

app.get('/docs/swagger.json', (req, res) => {
  res.setHeader('Content-Type', 'application/json');
  res.send(specs);
});

// Auth middleware wrapper for backward compatibility
async function authenticateToken(req, res, next) {
  const authMiddleware = getAuthMiddleware();
  return authMiddleware(req, res, next);
}

// Bridge connections removed - using HTTP polling only

// Initialize streaming proxy manager

let tunnelRouter = null;
let monitoringRouter = null;
if (LEGACY_TUNNEL_ROUTES_ENABLED) {
  // Create WebSocket-based tunnel routes
  tunnelRouter = createTunnelRoutes(
    {}, // Config placeholder
    sshProxy,
    logger,
    sshAuthService,
  );

  // Create monitoring routes
  monitoringRouter = createMonitoringRoutes(sshProxy, logger);
}

// API Routes
// Register routes both with /api prefix (for other subdomains) and without (for api subdomain)

function registerRoutes(path, ...middlewares) {
  app.use(`/api${path}`, ...middlewares);
  app.use(path, ...middlewares);
}

// Service version endpoint (no auth required)
app.get('/api/service-version', serviceVersionHandler);
app.get('/service-version', serviceVersionHandler);

if (LEGACY_TUNNEL_ROUTES_ENABLED) {
  logger.warn('Legacy tunnel routes are enabled by explicit configuration');
  registerRoutes('/tunnel', tunnelRouter);
  registerRoutes('/monitoring', monitoringRouter);
}

// Conversation management routes (initialized after database is ready)
// Will be set up in initializeTunnelSystem() after dbMigrator is initialized

// Database health endpoint (dbMigrator will be set after initialization)
registerRoutes('/db/health', dbHealthHandler);

// Authentication routes (token refresh, validation, logout)
registerRoutes('/auth', authRoutes);

// Session management routes
registerRoutes('/auth/sessions', sessionRoutes);

// Client log ingestion (no auth — logged before user authenticates)
registerRoutes('/client-logs', clientLogRoutes);

// Database health check routes
registerRoutes('/db', dbHealthRoutes);

// Database performance metrics routes
registerRoutes('/database/performance', databasePerformanceRoutes);

// TURN server credentials (authenticated)
registerRoutes('/turn', turnCredentialsRoutes);

// Administrative routes
registerRoutes('/admin', adminRoutes);
registerRoutes('/admin/behavior-warnings', behaviorWarningsRoutes);
registerRoutes('/admin/subagents', subagentRegistryRoutes);
registerRoutes('/admin/models', modelsRoutes);
registerRoutes('/admin/context-usage', contextUsageRoutes);
registerRoutes('/admin/users', adminUserRoutes);
registerRoutes('/admin', adminSubscriptionRoutes);

// User tier management routes
registerRoutes('/users', userRoutes);

// User profile management routes
registerRoutes('/users', userProfileRoutes);

// API Key management routes (for service-to-service authentication)
registerRoutes('/api-keys', apiKeysRouter);

if (LEGACY_TUNNEL_ROUTES_ENABLED) {
  registerRoutes('/tunnels', tunnelRoutes);
}

registerRoutes('/adaptive-rate-limiting', adaptiveRateLimitingRoutes);
registerRoutes('/admin-metrics', adminMetricsRoutes);
registerRoutes('/alert-configuration', alertConfigurationRoutes);
registerRoutes('/auth-audit', authAuditRoutes);
registerRoutes('/backup-recovery', backupRecoveryRoutes);
registerRoutes('/bridge-polling', bridgePollingRoutes);
registerRoutes('/cache-metrics', cacheMetricsRoutes);
registerRoutes('/deprecation', deprecationRoutes);
if (LEGACY_DIRECT_PROXY_ROUTES_ENABLED) {
  logger.warn('Legacy direct proxy routes are enabled by explicit configuration');
  registerRoutes('/direct-proxy', directProxyRoutes);
}
registerRoutes('/error-recovery', errorRecoveryRoutes);
if (LEGACY_DIRECT_PROXY_ROUTES_ENABLED) {
  registerRoutes('/failover', failoverRoutes);
  registerRoutes('/proxy-config', proxyConfigRoutes);
  registerRoutes('/proxy-diagnostics', proxyDiagnosticsRoutes);
  registerRoutes('/proxy-failover', proxyFailoverRoutes);
  registerRoutes('/proxy-health', proxyHealthRoutes);
  registerRoutes('/proxy-metrics', proxyMetricsRoutes);
  registerRoutes('/proxy-scaling', proxyScalingRoutes);
  registerRoutes('/proxy-usage', proxyUsageRoutes);
  registerRoutes('/proxy-webhooks', proxyWebhooksRoutes);
}
registerRoutes('/quotas', quotasRoutes);
registerRoutes('/rate-limit-exemptions', rateLimitExemptionsRoutes);
registerRoutes('/rate-limit-violations', rateLimitViolationsRoutes);
registerRoutes('/sandbox', sandboxRoutes);
if (LEGACY_TUNNEL_ROUTES_ENABLED) {
  registerRoutes('/tunnel-failover', tunnelFailoverRoutes);
  registerRoutes('/tunnel-health', tunnelHealthRoutes);
  registerRoutes('/tunnel-sharing', tunnelSharingRoutes);
  registerRoutes('/tunnel-usage', tunnelUsageRoutes);
  registerRoutes('/tunnel-webhooks', tunnelWebhooksRoutes);
}
registerRoutes('/user-activity', userActivityRoutes);
registerRoutes('/user-deletion', userDeletionRoutes);
// Note: versionedRoutes is a utility module, not a router - don't register it
registerRoutes('/webhook-event-filters', webhookEventFiltersRoutes);
registerRoutes(
  '/webhook-payload-transformations',
  webhookPayloadTransformationsRoutes,
);
registerRoutes('/webhook-rate-limiting', webhookRateLimitingRoutes);
registerRoutes('/webhook-testing', webhookTestingRoutes);

if (LEGACY_TUNNEL_ROUTES_ENABLED) {
  registerRoutes('/infrastructure/tunnel', infrastructureTunnelRoutes);
}
registerRoutes('/agent/events', agentEventsRoutes);
app.post('/api/agent/events', agentEventsRoutes);

// LLM Tunnel Cloud Proxy Endpoints (support both /api/ollama and /ollama)
setSshProxy(sshProxy);

import { authenticateComposite } from './middleware/composite-auth.js';

// Define Ollama route regex to match /api/ollama, /ollama, and their subpaths
if (LEGACY_OLLAMA_PROXY_ENABLED) {
  logger.warn('Legacy Ollama proxy route is enabled by explicit configuration');
  const OLLAMA_ROUTE_REGEX = /^\/(api\/)?ollama(\/.*)?$/;
  app.all(
    OLLAMA_ROUTE_REGEX,
    ...authenticateComposite,
    addTierInfo,
    handleOllamaProxyRequest,
  );
}

// User tier endpoint
registerRoutes(
  '/user/tier',
  ...authenticateJWT,
  addTierInfo,
  ...userTierHandler,
);

let isInitializing = true;

// Health check endpoints
app.get('/healthz', (req, res) => {
  if (isInitializing) {
    return res.status(503).send('Initializing');
  }
  res.status(200).send('OK');
});

registerRoutes('/health', (req, res) => {
  if (isInitializing) {
    return res.status(503).json({ status: 'initializing' });
  }
  healthCheckService
    .getHealthStatus()
    .then((healthStatus) => {
      let statusCode = 200;
      if (healthStatus.status === 'unhealthy') {
        statusCode = 503; // Service Unavailable
      } else if (healthStatus.status === 'degraded') {
        statusCode = 200; // Still return 200 but indicate degraded status
      }
      res.status(statusCode).json(healthStatus);
    })
    .catch((error) => {
      logger.error('Health check endpoint error:', error);
      res.status(503).json({
        status: 'unhealthy',
        timestamp: new Date().toISOString(),
        service: 'cloudtolocalllm-api',
        error: 'Health check failed',
        message: error.message,
      });
    });
});

// API Version Information Endpoint
// Returns information about supported API versions
/**
 * @swagger
 * /api/versions:
 *   get:
 *     summary: Get API version information
 *     description: Returns information about all supported API versions, including current version, default version, and deprecation status
 *     tags:
 *       - System
 *     responses:
 *       200:
 *         description: API version information
 *         content:
 *           application/json:
 *             schema:
 *               $ref: '#/components/schemas/APIVersionInfo'
 *       500:
 *         $ref: '#/components/responses/ServerError'
 */
registerRoutes('/versions', versionInfoHandler);

// Rate limit metrics routes
registerRoutes('/metrics', rateLimitMetricsRoutes);

// Prometheus metrics routes
registerRoutes('/prometheus', prometheusMetricsRoutes);

// Changelog and release notes routes
registerRoutes('/changelog', changelogRoutes);

// Queue status endpoints
registerRoutes('/queue/status', ...authenticateJWT, queueStatusHandler);

// Queue drain endpoint (for testing/debugging)
registerRoutes('/queue/drain', ...authenticateJWT, queueDrainHandler);

// WebSocket bridge endpoints removed - using HTTP polling only

// WebSocket upgrade handling for SSH tunnel
server.on('upgrade', (request, socket, head) => {
  const pathname = new URL(request.url, `http://${request.headers.host}`)
    .pathname;

  if (LEGACY_TUNNEL_ROUTES_ENABLED && pathname === '/ssh') {
    if (sshProxy && sshProxy.handleUpgrade) {
      logger.info('Received WebSocket upgrade request for /ssh', {
        url: request.url,
        headers: Object.keys(request.headers),
      });

      try {
        sshProxy.handleUpgrade(request, socket, head);
      } catch (error) {
        logger.error('SSH WebSocket upgrade failed', { error: error.message });
        socket.destroy();
      }
    } else {
      logger.warn(
        'SSH proxy not initialized or does not support WebSocket upgrade',
      );
      socket.destroy();
    }
  } else if (pathname === '/dashboard/ws') {
    dashboardWSManager.handleUpgrade(request, socket, head);
  } else {
    // Let other handlers handle it or destroy
    socket.destroy();
  }
});

// Streaming Proxy Management Endpoints
if (LEGACY_STREAMING_PROXY_ROUTES_ENABLED) {
  logger.warn(
    'Legacy streaming proxy management routes are enabled by explicit configuration',
  );

  // Start streaming proxy for user
  const proxyStartRoute = [authenticateToken, proxyStartHandler];
  registerRoutes('/proxy/start', ...proxyStartRoute);

  // Stop streaming proxy for user
  const proxyStopRoute = [authenticateToken, proxyStopHandler];
  registerRoutes('/proxy/stop', ...proxyStopRoute);

  // Provision streaming proxy for user (with test mode support)
  const proxyProvisionRoute = [authenticateToken, proxyProvisionHandler];
  registerRoutes('/streaming-proxy/provision', ...proxyProvisionRoute);

  // Get streaming proxy status
  const proxyStatusRoute = [authenticateToken, proxyStatusHandler];
  registerRoutes('/proxy/status', ...proxyStatusRoute);
}

// Ollama proxy endpoints removed - using HTTP polling tunnel system instead

// The error handler must be registered before any other error middleware and after all controllers

// Sentry Error Handler must be before any other error middleware and after all controllers
Sentry.setupExpressErrorHandler(app);

// Error handling middleware
app.use((error, req, res, _next) => {
  logger.error('Unhandled error:', error);
  res.status(500).json({
    error: 'Internal server error',
    message:
      process.env.NODE_ENV === 'development'
        ? error.message
        : 'Something went wrong',
  });
});

// Conversation routes - defined as a placeholder, will be initialized in initializeTunnelSystem
let conversationRouter = null;

// Register versioned conversations route after initialization
async function registerConversationRoutes(migrator) {
  conversationRouter = createConversationRoutes(migrator, logger);
  app.use('/api/conversations', ...authenticateJWT, conversationRouter);
  app.use('/conversations', ...authenticateJWT, conversationRouter);
  logger.info('Conversation routes registered with authentication');
}

// 404 handler (moved below route registrations)
function setupFinalHandlers() {
  app.use((req, res, next) => {
    if (req.path === '/health' || req.path === '/healthz') {
      return next();
    }
    res.status(404).json({ error: 'Not found' });
  });

  // Sentry Error Handler
  Sentry.setupExpressErrorHandler(app);

  // Error handling middleware
  app.use((error, req, res, _next) => {
    logger.error('Unhandled error:', error);
    res.status(500).json({
      error: 'Internal server error',
      message:
        process.env.NODE_ENV === 'development'
          ? error.message
          : 'Something went wrong',
    });
  });
}

// Initialize Tunnel System
let authService = null;
let dbMigrator = null;
let authDbMigrator = null;

async function initializeTunnelSystem(retries = 10) {
  logger.debug('Starting initializeTunnelSystem function');
  logger.info('Starting initialization of tunnel system...');
  try {
    logger.debug('About to initialize database pool');
    // Initialize centralized database connection pool (Requirement 17)
    logger.info('Initializing centralized database connection pool...');
    initializePool();
    logger.debug('Database pool initialization completed');
    logger.info('Database connection pool initialized successfully');

    // Initialize application database
    dbMigrator = new DatabaseMigratorPG();

    // Add retry logic for THE ENTIRE database startup sequence
    let connected = false;
    let attempt = 0;
    while (!connected && attempt < retries) {
      try {
        attempt++;
        logger.info(`Database initialization attempt ${attempt}/${retries}...`);

        await dbMigrator.initialize();
        await dbMigrator.createMigrationsTable();
        await dbMigrator.applyInitialSchema();

        logger.debug('About to run migrations');
        await dbMigrator.migrate();

        logger.debug('Validating database schema');
        const validation = await dbMigrator.validateSchema();
        if (!validation.allValid) {
          throw new Error('Database schema validation failed');
        }

        connected = true;
        logger.info('Database system fully initialized and migrated');
      } catch (err) {
        if (attempt >= retries) {
          throw err;
        }
        logger.warn(
          `Database initialization attempt ${attempt} failed: ${err.message}. Retrying in 5s...`,
        );
        await new Promise((resolve) => setTimeout(resolve, 5000));
      }
    }

    // Set dbMigrator for health endpoint now that it's initialized
    setDbMigrator(dbMigrator);

    // Register conversation routes now that database is ready
    await registerConversationRoutes(dbMigrator);

    // Setup final handlers (404, Sentry, Error)
    setupFinalHandlers();

    // Register database with health check service
    healthCheckService.registerDatabase(dbMigrator);
    logger.info('Database registered with health check service');

    // Start database pool monitoring (Requirement 17)
    logger.info('Starting database pool monitoring...');
    startMonitoring();
    logger.info('Database pool monitoring started successfully');

    // Initialize authentication database (separate instance)
    if (process.env.AUTH_DB_HOST) {
      logger.info('Initializing separate authentication database...');
      authDbMigrator = new AuthDatabaseMigratorPG({}, logger);
      await authDbMigrator.initialize();
      await authDbMigrator.migrate();
      logger.info('Authentication database initialized successfully');
    }

    logger.debug('About to initialize auth service');
    // Initialize auth service (optional - don't fail if it doesn't work)
    try {
      logger.debug('Creating AuthService instance');
      authService = new AuthService({
        authDbMigrator, // Pass auth database connection to auth service
        dbMigrator, // Pass main database connection to auth service
      });
      logger.debug('AuthService created, calling initialize');
      await authService.initialize();
      logger.debug('AuthService initialized successfully');
      logger.info('Authentication service initialized successfully');

      // Register auth service with health check service
      healthCheckService.registerService('auth-service', async () => {
        return {
          status: authService ? 'healthy' : 'unhealthy',
          message: authService
            ? 'Authentication service is running'
            : 'Authentication service is not available',
        };
      });

      if (LEGACY_TUNNEL_ROUTES_ENABLED) {
        // Use the same auth service for SSH proxy
        sshAuthService = authService;

        // Initialize SSH Proxy
        try {
          sshProxy = new SSHProxy(
            logger,
            {
              sshPort: parseInt(process.env.SSH_PORT) || 2222,
            },
            sshAuthService,
          );
          await sshProxy.start();
          logger.info('SSH tunnel server initialized successfully');

          // Register SSH proxy with health check service
          healthCheckService.registerService('ssh-tunnel', async () => {
            return {
              status: sshProxy && sshProxy.isRunning ? 'healthy' : 'unhealthy',
              message:
                sshProxy && sshProxy.isRunning
                  ? 'SSH tunnel is running'
                  : 'SSH tunnel is not running',
            };
          });
        } catch (sshError) {
          logger.error('Failed to initialize SSH tunnel server', {
            error: sshError.message,
            stack: sshError.stack,
          });

          // Register SSH proxy as unhealthy
          healthCheckService.registerService('ssh-tunnel', async () => {
            return {
              status: 'degraded',
              message: 'SSH tunnel service failed to initialize (non-critical)',
              error: sshError.message,
            };
          });
        }
      } else {
        logger.info('Legacy SSH tunnel server disabled by default');
      }
    } catch (error) {
      logger.warn(
        'Authentication service initialization failed, continuing without auth features',
        { error: error.message },
      );
      authService = null; // Set to null so routes can handle missing auth service
    }

    // Initialize user profile service after database is ready
    try {
      await initializeUserProfileService();
      logger.info('User profile service initialized successfully');
    } catch (error) {
      logger.error('Failed to initialize user profile service', {
        error: error.message,
      });
      // Don't fail the entire server startup, just log the error
    }

    if (LEGACY_TUNNEL_ROUTES_ENABLED) {
      // Initialize tunnel service after database is ready
      try {
        await initializeTunnelService();
        logger.info('Tunnel service initialized successfully');
      } catch (error) {
        logger.error('Failed to initialize tunnel service', {
          error: error.message,
        });
        // Don't fail the entire server startup, just log the error
      }
    }

    logger.info(
      LEGACY_TUNNEL_ROUTES_ENABLED
        ? 'WebSocket tunnel system ready'
        : 'Runtime connector system ready with legacy tunnels disabled',
    );

    // Register custom shutdown handler with graceful shutdown manager
    isInitializing = false;
    shutdownManager.shutdown = async () => {
      await gracefulShutdown();
    };

    logger.info('Tunnel system initialized successfully');
  } catch (error) {
    logger.debug(`Failed to initialize tunnel system: ${error.message}`);
    logger.debug(`Full error stack: ${error.stack}`);
    logger.error('Failed to initialize tunnel system', {
      error: error.message,
      stack: error.stack,
    });
    // Don't exit - continue with degraded functionality
    logger.warn(
      'Server starting with degraded functionality due to initialization failure',
    );
  }
}

async function gracefulShutdown() {
  logger.info('Received shutdown signal, starting graceful shutdown...');

  try {
    // Stop database pool monitoring (Requirement 17)
    logger.info('Stopping database pool monitoring...');
    stopMonitoring();
    logger.info('Database pool monitoring stopped');

    if (sshProxy) {
      await sshProxy.stop();
    }
    if (authService) {
      await authService.close();
    }
    if (authDbMigrator) {
      await authDbMigrator.close();
    }
    if (dbMigrator) {
      await dbMigrator.close();
    }

    logger.info('All services closed successfully');
  } catch (error) {
    logger.error('Error during shutdown', { error: error.message });
    process.exit(1);
  }
}

app.post('/test-hook', (req, res) => {
  logger.info('Received test hook');
  res.json({ ok: true });
});

// Start server with enhanced tunnel system
async function startServer() {
  logger.info('Starting server...');

  // Listen early to pass healthchecks during initialization
  server.listen(PORT, '0.0.0.0', async () => {
    logger.info(
      `CloudToLocalLLM API Backend listening on 0.0.0.0:${PORT} (Initializing...)`,
    );

    try {
      await initializeTunnelSystem();
      isInitializing = false;
      logger.info('Initialization complete, server ready.');
    } catch (error) {
      logger.error('Failed to initialize server', { error: error.message });
      isInitializing = false; // Allow health checks to proceed with degraded status
      // Keep listening so we can report errors via health endpoint, but don't exit
    }
  });
}

// Start the server if not in test mode
if (process.env.NODE_ENV !== 'test') {
  startServer();
}

export { app, server, startServer };
// Deploy test:
