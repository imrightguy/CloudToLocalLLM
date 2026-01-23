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

console.log('Starting api-backend server process...');
import express from 'express';
import http from 'http';
import winston from 'winston';
import swaggerUi from 'swagger-ui-express';
// Temporarily disable swagger-jsdoc import due to Node.js v24 compatibility
// import { specs } from './swagger-config.js';
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

// Create WebSocket-based tunnel routes
const tunnelRouter = createTunnelRoutes(
  {}, // Config placeholder
  sshProxy,
  logger,
  sshAuthService,
);

// Create monitoring routes
const monitoringRouter = createMonitoringRoutes(sshProxy, logger);

// API Routes
// Register routes both with /api prefix (for other subdomains) and without (for api subdomain)

function registerRoutes(path, router) {
  app.use(`/api${path}`, router);
  app.use(path, router);
}

// Service version endpoint (no auth required)
app.get('/api/service-version', serviceVersionHandler);
app.get('/service-version', serviceVersionHandler);

// Simplified tunnel routes
registerRoutes('/tunnel', tunnelRouter);

// Performance monitoring routes
registerRoutes('/monitoring', monitoringRouter);

// Conversation management routes (initialized after database is ready)
// Will be set up in initializeTunnelSystem() after dbMigrator is initialized

// Database health endpoint (dbMigrator will be set after initialization)
registerRoutes('/db/health', dbHealthHandler);

// Authentication routes (token refresh, validation, logout)
registerRoutes('/auth', authRoutes);

// Session management routes
registerRoutes('/auth/sessions', sessionRoutes);

// Client log ingestion
registerRoutes('/client-logs', clientLogRoutes);

// Database health check routes
registerRoutes('/db', dbHealthRoutes);

// Database performance metrics routes
registerRoutes('/database/performance', databasePerformanceRoutes);

// TURN server credentials (authenticated)
registerRoutes('/turn', turnCredentialsRoutes);

// Administrative routes
registerRoutes('/admin', adminRoutes);
registerRoutes('/admin/users', adminUserRoutes);
registerRoutes('/admin', adminSubscriptionRoutes);

// User tier management routes
registerRoutes('/users', userRoutes);

// User profile management routes
registerRoutes('/users', userProfileRoutes);

// API Key management routes (for service-to-service authentication)
registerRoutes('/api-keys', apiKeysRouter);

// Tunnel lifecycle management routes
registerRoutes('/tunnels', tunnelRoutes);

registerRoutes('/adaptive-rate-limiting', adaptiveRateLimitingRoutes);
registerRoutes('/admin-metrics', adminMetricsRoutes);
registerRoutes('/alert-configuration', alertConfigurationRoutes);
registerRoutes('/auth-audit', authAuditRoutes);
registerRoutes('/backup-recovery', backupRecoveryRoutes);
registerRoutes('/bridge-polling', bridgePollingRoutes);
registerRoutes('/cache-metrics', cacheMetricsRoutes);
registerRoutes('/deprecation', deprecationRoutes);
registerRoutes('/direct-proxy', directProxyRoutes);
registerRoutes('/error-recovery', errorRecoveryRoutes);
registerRoutes('/failover', failoverRoutes);
registerRoutes('/proxy-config', proxyConfigRoutes);
registerRoutes('/proxy-diagnostics', proxyDiagnosticsRoutes);
registerRoutes('/proxy-failover', proxyFailoverRoutes);
registerRoutes('/proxy-health', proxyHealthRoutes);
registerRoutes('/proxy-metrics', proxyMetricsRoutes);
registerRoutes('/proxy-scaling', proxyScalingRoutes);
registerRoutes('/proxy-usage', proxyUsageRoutes);
registerRoutes('/proxy-webhooks', proxyWebhooksRoutes);
registerRoutes('/quotas', quotasRoutes);
registerRoutes('/rate-limit-exemptions', rateLimitExemptionsRoutes);
registerRoutes('/rate-limit-violations', rateLimitViolationsRoutes);
registerRoutes('/sandbox', sandboxRoutes);
registerRoutes('/tunnel-failover', tunnelFailoverRoutes);
registerRoutes('/tunnel-health', tunnelHealthRoutes);
registerRoutes('/tunnel-sharing', tunnelSharingRoutes);
registerRoutes('/tunnel-usage', tunnelUsageRoutes);
registerRoutes('/tunnel-webhooks', tunnelWebhooksRoutes);
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

// LLM Tunnel Cloud Proxy Endpoints (support both /api/ollama and /ollama)
setSshProxy(sshProxy);

import { authenticateComposite } from './middleware/composite-auth.js';

// Define Ollama route regex to match /api/ollama, /ollama, and their subpaths
const OLLAMA_ROUTE_REGEX = /^\/(api\/)?ollama(\/.*)?$/;
app.all(
  OLLAMA_ROUTE_REGEX,
  ...authenticateComposite,
  addTierInfo,
  handleOllamaProxyRequest,
);

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
registerRoutes('/queue/status', queueStatusHandler);

// Queue drain endpoint (for testing/debugging)
registerRoutes('/queue/drain', ...authenticateJWT, queueDrainHandler);

// WebSocket bridge endpoints removed - using HTTP polling only

// WebSocket upgrade handling for SSH tunnel
server.on('upgrade', (request, socket, head) => {
  const pathname = new URL(request.url, `http://${request.headers.host}`)
    .pathname;

  if (pathname === '/ssh') {
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
  } else {
    // Let other handlers handle it or destroy
    socket.destroy();
  }
});

// Streaming Proxy Management Endpoints

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

// Conversation routes - implemented directly due to router mounting issues
app.get('/conversations/', ...authenticateJWT, async (req, res) => {
  try {
    const userId = req.auth?.payload?.sub || req.user?.sub;
    if (!userId) {
      return res
        .status(401)
        .json({ error: 'Unauthorized', message: 'User ID not found in token' });
    }

    if (!dbMigrator || !dbMigrator.pool) {
      return res.status(503).json({
        error: 'Service Unavailable',
        message: 'Database not initialized',
      });
    }

    const client = await dbMigrator.pool.connect();
    try {
      const { rows } = await client.query(
        `SELECT id, title, model, created_at, updated_at, metadata
         FROM conversations
         WHERE user_id = $1
         ORDER BY updated_at DESC`,
        [userId],
      );

      res.json({ conversations: rows });
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error('Failed to get conversations', { error: error.message });
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to get conversations',
    });
  }
});

app.put('/conversations/:id', ...authenticateJWT, async (req, res) => {
  try {
    const userId = req.auth?.payload?.sub || req.user?.sub;
    const conversationId = req.params.id;
    const { title, messages, model, metadata } = req.body;

    if (!userId) {
      return res
        .status(401)
        .json({ error: 'Unauthorized', message: 'User ID not found in token' });
    }

    if (!dbMigrator || !dbMigrator.pool) {
      return res.status(503).json({
        error: 'Service Unavailable',
        message: 'Database not initialized',
      });
    }

    const client = await dbMigrator.pool.connect();
    try {
      await client.query('BEGIN');

      // Check if conversation exists
      const { rows: conversationRows } = await client.query(
        'SELECT id FROM conversations WHERE id = $1 AND user_id = $2',
        [conversationId, userId],
      );

      if (conversationRows.length === 0) {
        // Create new conversation
        const newModel = model || 'gpt-3.5-turbo';
        const newTitle = title || 'New Conversation';

        await client.query(
          `INSERT INTO conversations (id, user_id, title, model, metadata)
           VALUES ($1, $2, $3, $4, $5::jsonb)`,
          [
            conversationId,
            userId,
            newTitle,
            newModel,
            JSON.stringify(metadata || {}),
          ],
        );
      } else {
        // Update existing conversation
        if (title) {
          await client.query(
            'UPDATE conversations SET title = $1 WHERE id = $2',
            [title, conversationId],
          );
        }
        if (metadata) {
          await client.query(
            'UPDATE conversations SET metadata = $1::jsonb WHERE id = $2',
            [JSON.stringify(metadata), conversationId],
          );
        }
      }

      // Replace messages if provided
      if (messages && Array.isArray(messages)) {
        await client.query('DELETE FROM messages WHERE conversation_id = $1', [
          conversationId,
        ]);

        for (const msg of messages) {
          await client.query(
            `INSERT INTO messages (conversation_id, role, content, model, status, error, timestamp, metadata)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8::jsonb)`,
            [
              conversationId,
              msg.role || 'user',
              msg.content || '',
              msg.model || model || null,
              msg.status || 'sent',
              msg.error || null,
              msg.timestamp ? new Date(msg.timestamp) : new Date(),
              msg.metadata ? JSON.stringify(msg.metadata) : '{}',
            ],
          );
        }
      }

      await client.query('COMMIT');

      // Get updated conversation
      const { rows: updatedConversation } = await client.query(
        'SELECT id, title, model, created_at, updated_at, metadata FROM conversations WHERE id = $1',
        [conversationId],
      );

      const { rows: messageRows } = await client.query(
        `SELECT id, role, content, model, status, error, timestamp, metadata
         FROM messages WHERE conversation_id = $1 ORDER BY timestamp ASC`,
        [conversationId],
      );

      res.json({
        success: true,
        conversation: {
          ...updatedConversation[0],
          messages: messageRows,
        },
      });
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error('Failed to update conversation', {
      error: error.message,
      conversationId: req.params.id,
    });
    res.status(500).json({
      error: 'Internal Server Error',
      message: 'Failed to update conversation',
    });
  }
});

// Also mount at /api/conversations for backward compatibility
app.get('/api/conversations/', async (req, res) => {
  // Redirect to the main route
  const url = req.originalUrl.replace('/api/conversations/', '/conversations/');
  res.redirect(307, url);
});

app.put('/api/conversations/:id', async (req, res) => {
  // Redirect to the main route
  const url = req.originalUrl.replace('/api/conversations/', '/conversations/');
  res.redirect(307, url);
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Initialize Tunnel System
let authService = null;
let dbMigrator = null;
let authDbMigrator = null;

async function initializeTunnelSystem(retries = 10) {
  console.log('DEBUG: Starting initializeTunnelSystem function');
  logger.info('Starting initialization of tunnel system...');
  try {
    console.log('DEBUG: About to initialize database pool');
    // Initialize centralized database connection pool (Requirement 17)
    logger.info('Initializing centralized database connection pool...');
    initializePool();
    console.log('DEBUG: Database pool initialization completed');
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

        console.log('DEBUG: About to run migrations');
        await dbMigrator.migrate();

        console.log('DEBUG: Validating database schema');
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

    console.log('DEBUG: About to initialize auth service');
    // Initialize auth service (optional - don't fail if it doesn't work)
    try {
      console.log('DEBUG: Creating AuthService instance');
      authService = new AuthService({
        authDbMigrator, // Pass auth database connection to auth service
        dbMigrator, // Pass main database connection to auth service
      });
      console.log('DEBUG: AuthService created, calling initialize');
      await authService.initialize();
      console.log('DEBUG: AuthService initialized successfully');
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

    // Initialize conversation routes after database is ready
    logger.info('About to initialize conversation routes');
    try {
      // Temporary test route directly on app
      app.get('/test-route', (req, res) => {
        logger.info('Test route accessed directly on app');
        res.json({ message: 'Direct app route working' });
      });

      // Test direct routes on app
      app.get('/conversations/test', (req, res) => {
        logger.info('Direct conversation test route accessed');
        res.json({ message: 'Direct conversation test working' });
      });

      app.get('/conversations/', (req, res) => {
        logger.info('Direct conversation root route accessed');
        res.json({ message: 'Direct conversation root working' });
      });

      const conversationRouter = createConversationRoutes(dbMigrator, logger);
      logger.info('Conversation router created', {
        routerExists: !!conversationRouter,
      });
      app.use('/api/conversations', conversationRouter);
      app.use('/conversations-router', conversationRouter); // Use different path to avoid conflict
      logger.info('Conversation API routes initialized');

      // Add 404 handler after all routes are mounted
      app.use((req, res) => {
        res.status(404).json({ error: 'Not found' });
      });
      logger.info('404 handler registered');
    } catch (error) {
      logger.error('Failed to initialize conversation routes', {
        error: error.message,
        stack: error.stack,
      });
      // Don't fail the entire server startup, just log the error
      // Still add 404 handler
      app.use((req, res) => {
        res.status(404).json({ error: 'Not found' });
      });
      logger.info('404 handler registered');
    }

    logger.info('WebSocket tunnel system ready');

    // Register custom shutdown handler with graceful shutdown manager
    shutdownManager.shutdown = async () => {
      await gracefulShutdown();
    };

    logger.info('Tunnel system initialized successfully');
  } catch (error) {
    console.log('DEBUG: Failed to initialize tunnel system:', error.message);
    console.log('DEBUG: Full error stack:', error.stack);
    logger.error('Failed to initialize tunnel system', {
      error: error.message,
      stack: error.stack,
    });
    // Don't exit - continue with degraded functionality
    logger.warn('Server starting with degraded functionality due to initialization failure');
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
