/**
 * CloudToLocalLLM Administrative Server
 *
 * Dedicated administrative interface running on separate port for:
 * - Secure admin-only operations
 * - System monitoring and management
 * - User administration
 * - Configuration management
 * - Advanced container management
 *
 * Security Features:
 * - Dedicated port isolation (3001)
 * - Admin-only authentication
 * - Enhanced rate limiting
 * - Comprehensive audit logging
 * - Multi-step confirmation for critical operations
 */

import express from 'express';
import http from 'http';
import cors from 'cors';
import helmet from 'helmet';
import rateLimit from 'express-rate-limit';
import winston from 'winston';
import dotenv from 'dotenv';
import os from 'os';
import Docker from 'dockerode';

// Import existing middleware and services
import { authenticateJWT, requireAdmin } from './middleware/auth.js';
import { adminDataFlushService } from './admin-data-flush-service.js';

dotenv.config();

// Initialize logger with admin-specific prefix
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'cloudtolocalllm-admin' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.printf(({ timestamp, level, message, ...meta }) => {
          return `${timestamp} [${level.toUpperCase()}]  [AdminPanel] ${message} ${Object.keys(meta).length ? JSON.stringify(meta) : ''}`;
        }),
      ),
    }),
  ],
});

// Configuration
const ADMIN_PORT = process.env.ADMIN_PORT || 3001;
const JWT_ISSUER_DOMAIN =
  process.env.JWT_ISSUER_DOMAIN || 'jwt-issuer.cloudtolocalllm.online';
const JWT_AUDIENCE =
  process.env.JWT_AUDIENCE || 'https://api.cloudtolocalllm.online';

// Docker client for container management
const docker = new Docker();

// Express app setup
const app = express();
const server = http.createServer(app);

// Enhanced security middleware for admin interface
app.use(
  helmet({
    contentSecurityPolicy: {
      directives: {
        defaultSrc: ["'self'"],
        connectSrc: ["'self'", 'wss:', 'https:'],
        scriptSrc: ["'self'", "'unsafe-inline'"],
        styleSrc: ["'self'", "'unsafe-inline'"],
        imgSrc: ["'self'", 'data:', 'https:'],
        frameSrc: ["'none'"],
        objectSrc: ["'none'"],
      },
    },
    hsts: {
      maxAge: 31536000,
      includeSubDomains: true,
      preload: true,
    },
  }),
);

// CORS configuration for admin interface
app.use(
  cors({
    origin: [
      'https://app.cloudtolocalllm.online',
      'https://cloudtolocalllm.online',
      'http://localhost:3000', // Development
      'http://localhost:8080', // Development
    ],
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  }),
);

// Strict rate limiting for admin operations
const adminRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 20, // Limit each admin to 20 requests per windowMs
  message: {
    error: 'Too many admin requests',
    code: 'ADMIN_RATE_LIMIT_EXCEEDED',
  },
  standardHeaders: true,
  legacyHeaders: false,
  handler: (req, res) => {
    logger.warn(' [AdminPanel] Rate limit exceeded', {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      path: req.path,
    });
    res.status(429).json({
      error: 'Too many admin requests',
      code: 'ADMIN_RATE_LIMIT_EXCEEDED',
    });
  },
});

app.use(adminRateLimit);

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging middleware
app.use((req, res, next) => {
  logger.info(' [AdminPanel] Admin request', {
    method: req.method,
    path: req.path,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
  });
  next();
});

// Health check endpoint (no auth required)
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'cloudtolocalllm-admin',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0',
  });
});

// Admin authentication check endpoint
app.get('/api/admin/auth/check', authenticateJWT, requireAdmin, (req, res) => {
  logger.info(' [AdminPanel] Admin authentication check', {
    adminUserId: req.user.sub,
  });

  res.json({
    success: true,
    message: 'Admin authentication successful',
    user: {
      id: req.user.sub,
      email: req.user.email,
      roles: req.user['https://cloudtolocalllm.online/roles'] || [],
    },
    timestamp: new Date().toISOString(),
  });
});

// System monitoring endpoints
app.get(
  '/api/admin/system/stats',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.info(' [AdminPanel] System statistics requested', {
        adminUserId: req.user.sub,
      });

      // Get system information
      const systemInfo = {
        hostname: os.hostname(),
        platform: os.platform(),
        arch: os.arch(),
        uptime: os.uptime(),
        loadAverage: os.loadavg(),
        totalMemory: os.totalmem(),
        freeMemory: os.freemem(),
        cpuCount: os.cpus().length,
      };

      // Get Docker statistics
      const containers = await docker.listContainers({
        all: true,
        filters: {
          label: ['cloudtolocalllm.type'],
        },
      });

      const networks = await docker.listNetworks({
        filters: {
          label: ['cloudtolocalllm.type=user-network'],
        },
      });

      const userContainers = containers.filter(
        (c) => c.Labels['cloudtolocalllm.type'] === 'streaming-proxy',
      );

      const activeUsers = new Set(
        userContainers.map((c) => c.Labels['cloudtolocalllm.user']),
      ).size;

      const stats = {
        system: systemInfo,
        docker: {
          totalContainers: containers.length,
          userContainers: userContainers.length,
          runningContainers: containers.filter((c) => c.State === 'running')
            .length,
          userNetworks: networks.length,
          activeUsers,
        },
        lastFlushOperation:
          adminDataFlushService.flushHistory.length > 0
            ? adminDataFlushService.flushHistory[
                adminDataFlushService.flushHistory.length - 1
              ].startTime
            : null,
        timestamp: new Date().toISOString(),
      };

      res.json({
        success: true,
        data: stats,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get system statistics', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve system statistics',
        code: 'STATS_RETRIEVAL_FAILED',
        details: error.message,
      });
    }
  },
);

// Real-time system monitoring endpoint
app.get(
  '/api/admin/system/realtime',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.debug(' [AdminPanel] Real-time system data requested', {
        adminUserId: req.user.sub,
      });

      // Get current system metrics
      const memoryUsage = process.memoryUsage();
      const cpuUsage = process.cpuUsage();

      // Get Docker container stats
      const containers = await docker.listContainers({ all: true });
      const runningContainers = containers.filter((c) => c.State === 'running');

      const realtimeData = {
        system: {
          memoryUsage: {
            rss: memoryUsage.rss,
            heapTotal: memoryUsage.heapTotal,
            heapUsed: memoryUsage.heapUsed,
            external: memoryUsage.external,
          },
          cpuUsage,
          uptime: process.uptime(),
          loadAverage: os.loadavg(),
        },
        docker: {
          totalContainers: containers.length,
          runningContainers: runningContainers.length,
          stoppedContainers: containers.length - runningContainers.length,
        },
        timestamp: new Date().toISOString(),
      };

      res.json({
        success: true,
        data: realtimeData,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get real-time system data', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve real-time system data',
        code: 'REALTIME_DATA_FAILED',
      });
    }
  },
);

// Container management endpoints
app.get(
  '/api/admin/containers',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.info(' [AdminPanel] Container list requested', {
        adminUserId: req.user.sub,
      });

      const containers = await docker.listContainers({
        all: true,
        filters: {
          label: ['cloudtolocalllm.type'],
        },
      });

      const containerDetails = await Promise.all(
        containers.map(async (containerInfo) => {
          try {
            const container = docker.getContainer(containerInfo.Id);
            const stats = await container.stats({ stream: false });

            return {
              id: containerInfo.Id,
              name: containerInfo.Names[0],
              state: containerInfo.State,
              status: containerInfo.Status,
              image: containerInfo.Image,
              created: containerInfo.Created,
              labels: containerInfo.Labels,
              ports: containerInfo.Ports,
              stats: {
                cpuPercent: calculateCpuPercent(stats),
                memoryUsage: stats.memory_stats.usage || 0,
                memoryLimit: stats.memory_stats.limit || 0,
                networkRx: stats.networks?.eth0?.rx_bytes || 0,
                networkTx: stats.networks?.eth0?.tx_bytes || 0,
              },
            };
          } catch (statsError) {
            logger.warn(' [AdminPanel] Failed to get container stats', {
              containerId: containerInfo.Id,
              error: statsError.message,
            });

            return {
              id: containerInfo.Id,
              name: containerInfo.Names[0],
              state: containerInfo.State,
              status: containerInfo.Status,
              image: containerInfo.Image,
              created: containerInfo.Created,
              labels: containerInfo.Labels,
              ports: containerInfo.Ports,
              stats: null,
            };
          }
        }),
      );

      res.json({
        success: true,
        data: containerDetails,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get container list', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve container list',
        code: 'CONTAINER_LIST_FAILED',
      });
    }
  },
);

// Helper function to calculate CPU percentage
function calculateCpuPercent(stats) {
  if (!stats.cpu_stats || !stats.precpu_stats) {
    return 0;
  }

  const cpuDelta =
    stats.cpu_stats.cpu_usage.total_usage -
    stats.precpu_stats.cpu_usage.total_usage;
  const systemDelta =
    stats.cpu_stats.system_cpu_usage - stats.precpu_stats.system_cpu_usage;
  const numberCpus = stats.cpu_stats.online_cpus || 1;

  if (systemDelta > 0 && cpuDelta > 0) {
    return (cpuDelta / systemDelta) * numberCpus * 100;
  }
  return 0;
}

// Network monitoring endpoint
app.get(
  '/api/admin/networks',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.info(' [AdminPanel] Network list requested', {
        adminUserId: req.user.sub,
      });

      const networks = await docker.listNetworks({
        filters: {
          label: ['cloudtolocalllm.type'],
        },
      });

      const networkDetails = networks.map((network) => ({
        id: network.Id,
        name: network.Name,
        driver: network.Driver,
        scope: network.Scope,
        created: network.Created,
        labels: network.Labels,
        containers: Object.keys(network.Containers || {}).length,
        options: network.Options,
      }));

      res.json({
        success: true,
        data: networkDetails,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get network list', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve network list',
        code: 'NETWORK_LIST_FAILED',
      });
    }
  },
);

// Active sessions monitoring endpoint
app.get(
  '/api/admin/sessions',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.info(' [AdminPanel] Active sessions requested', {
        adminUserId: req.user.sub,
      });

      // Get streaming proxy containers (active sessions)
      const containers = await docker.listContainers({
        filters: {
          label: ['cloudtolocalllm.type=streaming-proxy'],
          status: ['running'],
        },
      });

      const sessions = containers.map((container) => ({
        userId: container.Labels['cloudtolocalllm.user'],
        proxyId: container.Labels['cloudtolocalllm.proxy-id'],
        containerId: container.Id,
        containerName: container.Names[0],
        status: container.Status,
        created: new Date(container.Created * 1000).toISOString(),
        ports: container.Ports,
        uptime: container.Status,
      }));

      res.json({
        success: true,
        data: {
          activeSessions: sessions.length,
          sessions: sessions,
          timestamp: new Date().toISOString(),
        },
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get active sessions', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve active sessions',
        code: 'SESSIONS_RETRIEVAL_FAILED',
      });
    }
  },
);

// System performance metrics endpoint
app.get(
  '/api/admin/system/performance',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.debug(' [AdminPanel] Performance metrics requested', {
        adminUserId: req.user.sub,
      });

      // Get system performance data
      const cpus = os.cpus();
      const networkInterfaces = os.networkInterfaces();

      // Calculate CPU usage over time (simplified)
      const cpuInfo = cpus.map((cpu) => ({
        model: cpu.model,
        speed: cpu.speed,
        times: cpu.times,
      }));

      // Get Docker system info
      const dockerInfo = await docker.info();

      const performanceData = {
        cpu: {
          count: cpus.length,
          model: cpus[0]?.model || 'Unknown',
          details: cpuInfo,
        },
        memory: {
          total: os.totalmem(),
          free: os.freemem(),
          used: os.totalmem() - os.freemem(),
          percentage: ((os.totalmem() - os.freemem()) / os.totalmem()) * 100,
        },
        network: {
          interfaces: Object.keys(networkInterfaces).length,
          details: networkInterfaces,
        },
        docker: {
          containers: dockerInfo.Containers,
          containersRunning: dockerInfo.ContainersRunning,
          containersPaused: dockerInfo.ContainersPaused,
          containersStopped: dockerInfo.ContainersStopped,
          images: dockerInfo.Images,
          serverVersion: dockerInfo.ServerVersion,
          kernelVersion: dockerInfo.KernelVersion,
          operatingSystem: dockerInfo.OperatingSystem,
          architecture: dockerInfo.Architecture,
        },
        timestamp: new Date().toISOString(),
      };

      res.json({
        success: true,
        data: performanceData,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get performance metrics', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve performance metrics',
        code: 'PERFORMANCE_METRICS_FAILED',
      });
    }
  },
);

// User management endpoints
app.get('/api/admin/users', authenticateJWT, requireAdmin, async (req, res) => {
  try {
    logger.info(' [AdminPanel] User list requested', {
      adminUserId: req.user.sub,
    });

    // Get all containers to extract user information
    const containers = await docker.listContainers({
      all: true,
      filters: {
        label: ['cloudtolocalllm.type=streaming-proxy'],
      },
    });

    // Extract unique users and their activity
    const userMap = new Map();

    containers.forEach((container) => {
      const userId = container.Labels['cloudtolocalllm.user'];
      if (userId) {
        if (!userMap.has(userId)) {
          userMap.set(userId, {
            userId,
            containers: [],
            lastActivity: null,
            isActive: false,
          });
        }

        const userData = userMap.get(userId);
        userData.containers.push({
          containerId: container.Id,
          containerName: container.Names[0],
          state: container.State,
          status: container.Status,
          created: new Date(container.Created * 1000).toISOString(),
        });

        // Update activity status
        if (container.State === 'running') {
          userData.isActive = true;
        }

        // Update last activity (most recent container creation)
        const containerDate = new Date(container.Created * 1000);
        if (
          !userData.lastActivity ||
          containerDate > new Date(userData.lastActivity)
        ) {
          userData.lastActivity = containerDate.toISOString();
        }
      }
    });

    const users = Array.from(userMap.values()).map((user) => ({
      ...user,
      containerCount: user.containers.length,
      activeContainers: user.containers.filter((c) => c.state === 'running')
        .length,
    }));

    res.json({
      success: true,
      data: {
        totalUsers: users.length,
        activeUsers: users.filter((u) => u.isActive).length,
        users: users,
      },
    });
  } catch (error) {
    logger.error(' [AdminPanel] Failed to get user list', {
      adminUserId: req.user.sub,
      error: error.message,
    });

    res.status(500).json({
      error: 'Failed to retrieve user list',
      code: 'USER_LIST_FAILED',
    });
  }
});

// User session management endpoint
app.get(
  '/api/admin/users/:userId/sessions',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { userId } = req.params;

      logger.info(' [AdminPanel] User sessions requested', {
        adminUserId: req.user.sub,
        targetUserId: userId,
      });

      // Get user's containers
      const containers = await docker.listContainers({
        all: true,
        filters: {
          label: [`cloudtolocalllm.user=${userId}`],
        },
      });

      const sessions = await Promise.all(
        containers.map(async (containerInfo) => {
          try {
            const container = docker.getContainer(containerInfo.Id);
            const inspect = await container.inspect();

            return {
              containerId: containerInfo.Id,
              containerName: containerInfo.Names[0],
              state: containerInfo.State,
              status: containerInfo.Status,
              created: containerInfo.Created,
              image: containerInfo.Image,
              labels: containerInfo.Labels,
              ports: containerInfo.Ports,
              networkMode: inspect.HostConfig.NetworkMode,
              restartCount: inspect.RestartCount,
              startedAt: inspect.State.StartedAt,
              finishedAt: inspect.State.FinishedAt,
            };
          } catch (inspectError) {
            logger.warn(' [AdminPanel] Failed to inspect container', {
              containerId: containerInfo.Id,
              error: inspectError.message,
            });

            return {
              containerId: containerInfo.Id,
              containerName: containerInfo.Names[0],
              state: containerInfo.State,
              status: containerInfo.Status,
              created: containerInfo.Created,
              error: 'Failed to get detailed information',
            };
          }
        }),
      );

      res.json({
        success: true,
        data: {
          userId,
          sessionCount: sessions.length,
          activeSessions: sessions.filter((s) => s.state === 'running').length,
          sessions,
        },
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get user sessions', {
        adminUserId: req.user.sub,
        targetUserId: req.params.userId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve user sessions',
        code: 'USER_SESSIONS_FAILED',
      });
    }
  },
);

// Terminate user session endpoint
app.post(
  '/api/admin/users/:userId/sessions/:containerId/terminate',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { userId, containerId } = req.params;

      logger.warn(' [AdminPanel] User session termination requested', {
        adminUserId: req.user.sub,
        targetUserId: userId,
        containerId,
      });

      // Verify container belongs to user
      const containerInfo = await docker.getContainer(containerId).inspect();

      if (containerInfo.Config.Labels['cloudtolocalllm.user'] !== userId) {
        return res.status(403).json({
          error: 'Container does not belong to specified user',
          code: 'CONTAINER_USER_MISMATCH',
        });
      }

      // Stop and remove container
      const container = docker.getContainer(containerId);

      if (containerInfo.State.Running) {
        await container.stop({ t: 10 });
      }

      await container.remove({ force: true });

      logger.info(' [AdminPanel] User session terminated successfully', {
        adminUserId: req.user.sub,
        targetUserId: userId,
        containerId,
      });

      res.json({
        success: true,
        message: 'Session terminated successfully',
        containerId,
        userId,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to terminate user session', {
        adminUserId: req.user.sub,
        targetUserId: req.params.userId,
        containerId: req.params.containerId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to terminate user session',
        code: 'SESSION_TERMINATION_FAILED',
        details: error.message,
      });
    }
  },
);

// Configuration management endpoints
app.get(
  '/api/admin/config',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.info(' [AdminPanel] System configuration requested', {
        adminUserId: req.user.sub,
      });

      // Get current configuration (excluding sensitive data)
      const config = {
        server: {
          adminPort: ADMIN_PORT,
          mainApiPort: process.env.PORT || 8080,
          nodeEnv: process.env.NODE_ENV || 'development',
          logLevel: process.env.LOG_LEVEL || 'info',
        },
        auth: {
          jwtDomain: JWT_ISSUER_DOMAIN,
          jwtAudience: JWT_AUDIENCE,
        },
        docker: {
          host: process.env.DOCKER_HOST || 'unix:///var/run/docker.sock',
        },
        features: {
          enableDebugMode: process.env.ENABLE_DEBUG_MODE === 'true',
          enableVerboseLogging: process.env.ENABLE_VERBOSE_LOGGING === 'true',
          enableAnalytics: process.env.ENABLE_ANALYTICS === 'true',
        },
        limits: {
          containerMemoryLimit: process.env.CONTAINER_MEMORY_LIMIT || '512m',
          containerCpuLimit: process.env.CONTAINER_CPU_LIMIT || '0.5',
          maxContainersPerUser: process.env.MAX_CONTAINERS_PER_USER || '3',
          sessionTimeoutMinutes: process.env.SESSION_TIMEOUT_MINUTES || '10',
        },
      };

      res.json({
        success: true,
        data: config,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get system configuration', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve system configuration',
        code: 'CONFIG_RETRIEVAL_FAILED',
      });
    }
  },
);

// Environment variables endpoint (read-only, filtered)
app.get(
  '/api/admin/config/environment',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.info(' [AdminPanel] Environment variables requested', {
        adminUserId: req.user.sub,
      });

      // Filter environment variables (exclude sensitive ones)
      const sensitiveKeys = [
        'JWT_CLIENT_SECRET',
        'JWT_SECRET',
        'DATABASE_PASSWORD',
        'API_KEY',
        'SECRET',
        'PASSWORD',
        'TOKEN',
      ];

      const filteredEnv = Object.entries(process.env)
        .filter(([key]) => {
          return !sensitiveKeys.some((sensitive) =>
            key.toUpperCase().includes(sensitive),
          );
        })
        .reduce((acc, [key, value]) => {
          acc[key] = value;
          return acc;
        }, {});

      res.json({
        success: true,
        data: {
          environment: filteredEnv,
          totalVariables: Object.keys(process.env).length,
          filteredVariables: Object.keys(filteredEnv).length,
          hiddenVariables:
            Object.keys(process.env).length - Object.keys(filteredEnv).length,
        },
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get environment variables', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve environment variables',
        code: 'ENV_RETRIEVAL_FAILED',
      });
    }
  },
);

// Feature flags management endpoint
app.get(
  '/api/admin/config/features',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.info(' [AdminPanel] Feature flags requested', {
        adminUserId: req.user.sub,
      });

      const features = {
        debugMode: {
          enabled: process.env.ENABLE_DEBUG_MODE === 'true',
          description:
            'Enable debug mode for enhanced logging and error details',
        },
        verboseLogging: {
          enabled: process.env.ENABLE_VERBOSE_LOGGING === 'true',
          description: 'Enable verbose logging for detailed operation tracking',
        },
        analytics: {
          enabled: process.env.ENABLE_ANALYTICS === 'true',
          description: 'Enable analytics and usage tracking',
        },
        containerAutoCleanup: {
          enabled: process.env.ENABLE_AUTO_CLEANUP !== 'false',
          description: 'Automatically cleanup inactive containers',
        },
        rateLimiting: {
          enabled: process.env.DISABLE_RATE_LIMITING !== 'true',
          description: 'Enable rate limiting for API endpoints',
        },
      };

      res.json({
        success: true,
        data: features,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get feature flags', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve feature flags',
        code: 'FEATURES_RETRIEVAL_FAILED',
      });
    }
  },
);

// Service status endpoint
app.get(
  '/api/admin/config/services',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.info(' [AdminPanel] Service status requested', {
        adminUserId: req.user.sub,
      });

      // Check various service statuses
      const services = {
        adminServer: {
          status: 'running',
          port: ADMIN_PORT,
          uptime: process.uptime(),
        },
        docker: {
          status: 'unknown',
          version: null,
          containers: 0,
        },
        auth: {
          status: 'unknown',
          domain: JWT_ISSUER_DOMAIN,
          audience: JWT_AUDIENCE,
        },
      };

      // Check Docker status
      try {
        const dockerInfo = await docker.info();
        services.docker.status = 'running';
        services.docker.version = dockerInfo.ServerVersion;
        services.docker.containers = dockerInfo.Containers;
      } catch (dockerError) {
        services.docker.status = 'error';
        services.docker.error = dockerError.message;
      }

      // Check JWT connectivity (simplified)
      services.auth.status = 'configured';

      res.json({
        success: true,
        data: services,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get service status', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve service status',
        code: 'SERVICES_STATUS_FAILED',
      });
    }
  },
);

// Enhanced container management endpoints

// Container logs endpoint
app.get(
  '/api/admin/containers/:containerId/logs',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { containerId } = req.params;
      const { lines = 100, follow = false } = req.query;

      logger.info(' [AdminPanel] Container logs requested', {
        adminUserId: req.user.sub,
        containerId,
        lines,
        follow,
      });

      const container = docker.getContainer(containerId);

      // Verify container exists and belongs to CloudToLocalLLM
      const inspect = await container.inspect();
      if (!inspect.Config.Labels['cloudtolocalllm.type']) {
        return res.status(403).json({
          error: 'Container is not managed by CloudToLocalLLM',
          code: 'CONTAINER_NOT_MANAGED',
        });
      }

      const logStream = await container.logs({
        stdout: true,
        stderr: true,
        tail: parseInt(lines),
        timestamps: true,
        follow: follow === 'true',
      });

      if (follow === 'true') {
        // Stream logs in real-time
        res.setHeader('Content-Type', 'text/plain');
        res.setHeader('Transfer-Encoding', 'chunked');

        logStream.on('data', (chunk) => {
          res.write(chunk.toString());
        });

        logStream.on('end', () => {
          res.end();
        });

        logStream.on('error', (error) => {
          logger.error(' [AdminPanel] Log streaming error', {
            containerId,
            error: error.message,
          });
          res.end();
        });
      } else {
        // Return logs as JSON
        const logs = logStream.toString();
        res.json({
          success: true,
          data: {
            containerId,
            logs: logs.split('\n').filter((line) => line.trim()),
            timestamp: new Date().toISOString(),
          },
        });
      }
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get container logs', {
        adminUserId: req.user.sub,
        containerId: req.params.containerId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve container logs',
        code: 'CONTAINER_LOGS_FAILED',
        details: error.message,
      });
    }
  },
);

// Container resource usage endpoint
app.get(
  '/api/admin/containers/:containerId/stats',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      const { containerId } = req.params;

      logger.debug(' [AdminPanel] Container stats requested', {
        adminUserId: req.user.sub,
        containerId,
      });

      const container = docker.getContainer(containerId);
      const stats = await container.stats({ stream: false });

      // Calculate useful metrics
      const cpuPercent = calculateCpuPercent(stats);
      const memoryUsage = stats.memory_stats.usage || 0;
      const memoryLimit = stats.memory_stats.limit || 0;
      const memoryPercent =
        memoryLimit > 0 ? (memoryUsage / memoryLimit) * 100 : 0;

      const networkStats = stats.networks?.eth0 || {};

      const resourceStats = {
        containerId,
        cpu: {
          percent: cpuPercent,
          usage: stats.cpu_stats.cpu_usage.total_usage,
          systemUsage: stats.cpu_stats.system_cpu_usage,
        },
        memory: {
          usage: memoryUsage,
          limit: memoryLimit,
          percent: memoryPercent,
          cache: stats.memory_stats.stats?.cache || 0,
        },
        network: {
          rxBytes: networkStats.rx_bytes || 0,
          txBytes: networkStats.tx_bytes || 0,
          rxPackets: networkStats.rx_packets || 0,
          txPackets: networkStats.tx_packets || 0,
        },
        blockIO: {
          readBytes:
            stats.blkio_stats.io_service_bytes_recursive?.find(
              (item) => item.op === 'Read',
            )?.value || 0,
          writeBytes:
            stats.blkio_stats.io_service_bytes_recursive?.find(
              (item) => item.op === 'Write',
            )?.value || 0,
        },
        timestamp: new Date().toISOString(),
      };

      res.json({
        success: true,
        data: resourceStats,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get container stats', {
        adminUserId: req.user.sub,
        containerId: req.params.containerId,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve container stats',
        code: 'CONTAINER_STATS_FAILED',
        details: error.message,
      });
    }
  },
);

// Network topology endpoint
app.get(
  '/api/admin/network/topology',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    try {
      logger.info(' [AdminPanel] Network topology requested', {
        adminUserId: req.user.sub,
      });

      // Get all CloudToLocalLLM networks
      const networks = await docker.listNetworks({
        filters: {
          label: ['cloudtolocalllm.type'],
        },
      });

      // Get all CloudToLocalLLM containers
      const containers = await docker.listContainers({
        all: true,
        filters: {
          label: ['cloudtolocalllm.type'],
        },
      });

      // Build network topology
      const topology = {
        networks: await Promise.all(
          networks.map(async (network) => {
            const networkDetail = await docker.getNetwork(network.Id).inspect();

            return {
              id: network.Id,
              name: network.Name,
              driver: network.Driver,
              scope: network.Scope,
              labels: network.Labels,
              containers: Object.keys(networkDetail.Containers || {}),
              ipam: networkDetail.IPAM,
              options: networkDetail.Options,
            };
          }),
        ),
        containers: containers.map((container) => ({
          id: container.Id,
          name: container.Names[0],
          state: container.State,
          labels: container.Labels,
          networkMode: container.HostConfig?.NetworkMode,
          ports: container.Ports,
        })),
        connections: [],
      };

      // Map container-network connections
      topology.networks.forEach((network) => {
        network.containers.forEach((containerId) => {
          const container = topology.containers.find((c) =>
            c.id.startsWith(containerId),
          );
          if (container) {
            topology.connections.push({
              containerId: container.id,
              containerName: container.name,
              networkId: network.id,
              networkName: network.name,
            });
          }
        });
      });

      res.json({
        success: true,
        data: topology,
      });
    } catch (error) {
      logger.error(' [AdminPanel] Failed to get network topology', {
        adminUserId: req.user.sub,
        error: error.message,
      });

      res.status(500).json({
        error: 'Failed to retrieve network topology',
        code: 'NETWORK_TOPOLOGY_FAILED',
      });
    }
  },
);

// Import and mount existing admin routes
import adminRoutes from './routes/admin.js';
app.use('/api/admin', adminRoutes);

// Error handling middleware
app.use((error, req, res, _next) => {
  logger.error(' [AdminPanel] Unhandled error', {
    error: error.message,
    stack: error.stack,
    path: req.path,
    method: req.method,
  });

  res.status(500).json({
    error: 'Internal server error',
    code: 'ADMIN_INTERNAL_ERROR',
    message:
      process.env.NODE_ENV === 'development'
        ? error.message
        : 'Something went wrong',
  });
});

// 404 handler
app.use((req, res) => {
  logger.warn(' [AdminPanel] Admin endpoint not found', {
    path: req.path,
    method: req.method,
    ip: req.ip,
  });

  res.status(404).json({
    error: 'Admin endpoint not found',
    code: 'ADMIN_ENDPOINT_NOT_FOUND',
  });
});

// Start admin server
server.listen(ADMIN_PORT, () => {
  logger.info(' [AdminPanel] CloudToLocalLLM Admin Server started', {
    port: ADMIN_PORT,
    environment: process.env.NODE_ENV || 'development',
    jwtDomain: JWT_ISSUER_DOMAIN,
    jwtAudience: JWT_AUDIENCE,
  });
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info(' [AdminPanel] Admin server shutting down gracefully');
  server.close(() => {
    logger.info(' [AdminPanel] Admin server closed');
    process.exit(0);
  });
});

export default app;
