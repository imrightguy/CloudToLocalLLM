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
import adminRoutes from './admin.js';
import adminUserRoutes from './admin/users.js';
import adminSubscriptionRoutes from './admin/subscriptions.js';
import userRoutes from './users.js';
import userProfileRoutes from './user-profile.js';
import sessionRoutes from './sessions.js';
import clientLogRoutes from './client-logs.js';
import webhookRoutes from './webhooks.js';
import authRoutes from './auth.js';
import apiKeysRouter from './api-keys.js';
import tunnelRoutes from './tunnels.js';
import adaptiveRateLimitingRoutes from './adaptive-rate-limiting.js';
import adminMetricsRoutes from './admin-metrics.js';
import alertConfigurationRoutes from './alert-configuration.js';
import authAuditRoutes from './auth-audit.js';
import backupRecoveryRoutes from './backup-recovery.js';
import bridgePollingRoutes from './bridge-polling-routes.js';
import cacheMetricsRoutes from './cache-metrics.js';
import deprecationRoutes from './deprecation.js';
import directProxyRoutes from './direct-proxy-routes.js';
import errorRecoveryRoutes from './error-recovery.js';
import failoverRoutes from './failover.js';
import proxyConfigRoutes from './proxy-config.js';
import proxyDiagnosticsRoutes from './proxy-diagnostics.js';
import proxyFailoverRoutes from './proxy-failover.js';
import proxyHealthRoutes from './proxy-health.js';
import proxyMetricsRoutes from './proxy-metrics.js';
import proxyScalingRoutes from './proxy-scaling.js';
import proxyUsageRoutes from './proxy-usage.js';
import proxyWebhooksRoutes from './proxy-webhooks.js';
import quotasRoutes from './quotas.js';
import rateLimitExemptionsRoutes from './rate-limit-exemptions.js';
import rateLimitViolationsRoutes from './rate-limit-violations.js';
import sandboxRoutes from './sandbox.js';
import tunnelFailoverRoutes from './tunnel-failover.js';
import tunnelHealthRoutes from './tunnel-health.js';
import tunnelSharingRoutes from './tunnel-sharing.js';
import tunnelUsageRoutes from './tunnel-usage.js';
import tunnelWebhooksRoutes from './tunnel-webhooks.js';
import userActivityRoutes from './user-activity.js';
import userDeletionRoutes from './user-deletion.js';
import webhookEventFiltersRoutes from './webhook-event-filters.js';
import webhookPayloadTransformationsRoutes from './webhook-payload-transformations.js';
import webhookRateLimitingRoutes from './webhook-rate-limiting.js';
import webhookTestingRoutes from './webhook-testing.js';
import infrastructureTunnelRoutes from './infrastructure-tunnel.js';
import dbHealthRoutes from './db-health.js';
import databasePerformanceRoutes from './database-performance.js';
import turnCredentialsRoutes from './turn-credentials.js';
import { createTunnelRoutes } from '../tunnel/tunnel-routes.js';
import { createMonitoringRoutes } from './monitoring.js';
import { authenticateJWT } from '../middleware/auth.js';
import serviceVersionHandler from './service-version.js';
import { addTierInfo } from '../middleware/tier-check.js';
import { authenticateComposite } from '../middleware/composite-auth.js';
import {
  dbHealthHandler,
  handleOllamaProxyRequest,
  userTierHandler,
  versionInfoHandler,
  queueStatusHandler,
  queueDrainHandler,
} from './handlers.js';
import rateLimitMetricsRoutes from './rate-limit-metrics.js';
import prometheusMetricsRoutes from './prometheus-metrics.js';
import changelogRoutes from './changelog.js';
import agentEventsRoutes from './agent-events.js';

export function setupRoutes(
  app,
  sshProxy,
  logger,
  sshAuthService,
  healthCheckService,
  isInitializing,
) {
  // Webhook routes MUST be mounted before body parsing middleware
  app.use('/api/webhooks', webhookRoutes);
  app.use('/webhooks', webhookRoutes);

  // Swagger UI documentation endpoint
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

  app.get('/api/docs/swagger.json', (req, res) => {
    res.setHeader('Content-Type', 'application/json');
    res.send(specs);
  });

  // Also serve docs without /api prefix
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

  // Auth middleware wrapper (kept for potential future use)
  // async function authenticateToken(req, res, next) {
  //   const authMiddleware = getAuthMiddleware();
  //   return authMiddleware(req, res, next);
  // }

  // Create tunnel and monitoring routes
  const tunnelRouter = createTunnelRoutes({}, sshProxy, logger, sshAuthService);
  const monitoringRouter = createMonitoringRoutes(sshProxy, logger);

  // Register routes function
  function registerRoutes(path, ...middlewares) {
    app.use(`/api${path}`, ...middlewares);
    app.use(path, ...middlewares);
  }

  // Service version
  app.get('/api/service-version', serviceVersionHandler);
  app.get('/service-version', serviceVersionHandler);

  // Register all routes
  registerRoutes('/tunnel', tunnelRouter);
  registerRoutes('/monitoring', monitoringRouter);
  registerRoutes('/db/health', dbHealthHandler);
  registerRoutes('/auth', authRoutes);
  registerRoutes('/auth/sessions', sessionRoutes);
  registerRoutes('/client-logs', clientLogRoutes);
  registerRoutes('/db', dbHealthRoutes);
  registerRoutes('/database/performance', databasePerformanceRoutes);
  registerRoutes('/turn', turnCredentialsRoutes);
  registerRoutes('/admin', adminRoutes);
  registerRoutes('/admin/users', adminUserRoutes);
  registerRoutes('/admin', adminSubscriptionRoutes);
  registerRoutes('/users', userRoutes);
  registerRoutes('/users', userProfileRoutes);
  registerRoutes('/api-keys', apiKeysRouter);
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
  registerRoutes('/webhook-event-filters', webhookEventFiltersRoutes);
  registerRoutes(
    '/webhook-payload-transformations',
    webhookPayloadTransformationsRoutes,
  );
  registerRoutes('/webhook-rate-limiting', webhookRateLimitingRoutes);
  registerRoutes('/webhook-testing', webhookTestingRoutes);
  registerRoutes('/infrastructure/tunnel', infrastructureTunnelRoutes);
  registerRoutes('/agent/events', agentEventsRoutes);

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
          statusCode = 503;
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

  // API versions
  registerRoutes('/versions', versionInfoHandler);

  // Other routes...
  registerRoutes('/metrics', rateLimitMetricsRoutes);
  registerRoutes('/prometheus', prometheusMetricsRoutes);
  registerRoutes('/changelog', changelogRoutes);
  registerRoutes('/queue/status', ...authenticateJWT, queueStatusHandler);
  registerRoutes('/queue/drain', ...authenticateJWT, queueDrainHandler);

  // Ollama proxy
  const OLLAMA_ROUTE_REGEX = /^\/(api\/)?ollama(\/.*)?$/;
  app.all(
    OLLAMA_ROUTE_REGEX,
    ...authenticateComposite,
    addTierInfo,
    handleOllamaProxyRequest,
  );

  // User tier
  registerRoutes(
    '/user/tier',
    ...authenticateJWT,
    addTierInfo,
    ...userTierHandler,
  );
}
