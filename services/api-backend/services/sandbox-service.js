/**
 * Sandbox Service
 *
 * Provides sandbox environment configuration and management for testing without side effects.
 * Allows developers to test API endpoints with mock data and simulated responses.
 *
 * Features:
 * - Sandbox mode detection and configuration
 * - Mock data generation for testing
 * - Request/response interception for sandbox mode
 * - Test credentials management
 * - Sandbox-specific rate limiting and quotas
 */

import winston from 'winston';

const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'sandbox-service' },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.simple(),
      ),
    }),
  ],
});

/**
 * Sandbox Service for managing sandbox environment
 */
export class SandboxService {
  constructor() {
    this.isSandboxEnabled =
      process.env.SANDBOX_MODE === 'true' || process.env.NODE_ENV === 'sandbox';
    this.sandboxDatabase = new Map();
    this.sandboxUsers = new Map();
    this.sandboxTunnels = new Map();
    this.sandboxWebhooks = new Map();
    this.requestLog = [];
    this.maxRequestLogSize = 1000;
  }

  /**
   * Check if sandbox mode is enabled
   * @returns {boolean} True if sandbox mode is enabled
   */
  isSandbox() {
    return this.isSandboxEnabled;
  }

  /**
   * Get sandbox configuration
   * @returns {Object} Sandbox configuration
   */
  getSandboxConfig() {
    return {
      enabled: this.isSandboxEnabled,
      mode: 'testing',
      features: {
        mockData: true,
        noSideEffects: true,
        requestLogging: true,
        dataIsolation: true,
      },
      rateLimits: {
        requestsPerMinute: 10000, // Unlimited for testing
        burstSize: 5000,
      },
      quotas: {
        maxTunnels: 100,
        maxWebhooks: 100,
        maxUsers: 1000,
        storageGB: 10,
      },
    };
  }

  /**
   * Get test credentials for sandbox environment
   * @returns {Object} Test credentials
   */
  getTestCredentials() {
    return {
      users: [
        {
          id: 'test-user-1',
          email: 'test@sandbox.local',
          jwtId: 'jwt|sandbox-test-1',
          tier: 'free',
          token:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMSIsImVtYWlsIjoidGVzdEBzYW5kYm94LmxvY2FsIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-1',
        },
        {
          id: 'test-user-2',
          email: 'premium@sandbox.local',
          jwtId: 'jwt|sandbox-test-2',
          tier: 'premium',
          token:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXItMiIsImVtYWlsIjoicHJlbWl1bUBzYW5kYm94LmxvY2FsIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-2',
        },
        {
          id: 'test-admin',
          email: 'admin@sandbox.local',
          jwtId: 'jwt|sandbox-admin',
          tier: 'enterprise',
          role: 'admin',
          token:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LWFkbWluIiwiZW1haWwiOiJhZG1pbkBzYW5kYm94LmxvY2FsIiwicm9sZSI6ImFkbWluIiwiaWF0IjoxNjcwMDAwMDAwfQ.sandbox-token-admin',
        },
      ],
      apiKeys: [
        {
          key: 'sk_sandbox_test_1234567890abcdef',
          secret: 'sandbox-secret-1',
          name: 'Test API Key 1',
          tier: 'free',
        },
        {
          key: 'sk_sandbox_premium_abcdef1234567890',
          secret: 'sandbox-secret-2',
          name: 'Premium API Key',
          tier: 'premium',
        },
      ],
    };
  }

  /**
   * Create mock user for sandbox
   * @param {Object} userData - User data
   * @returns {Object} Created mock user
   */
  createMockUser(userData) {
    const userId = `sandbox-user-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const mockUser = {
      id: userId,
      email: userData.email || `user-${userId}@sandbox.local`,
      tier: userData.tier || 'free',
      profile: {
        firstName: userData.firstName || 'Test',
        lastName: userData.lastName || 'User',
        preferences: {
          theme: 'light',
          language: 'en',
          notifications: true,
        },
      },
      createdAt: new Date(),
      isActive: true,
    };

    this.sandboxUsers.set(userId, mockUser);
    logger.info(`Created mock user in sandbox: ${userId}`);
    return mockUser;
  }

  /**
   * Create mock tunnel for sandbox
   * @param {Object} tunnelData - Tunnel data
   * @returns {Object} Created mock tunnel
   */
  createMockTunnel(tunnelData) {
    const tunnelId = `sandbox-tunnel-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const mockTunnel = {
      id: tunnelId,
      userId: tunnelData.userId || 'test-user-1',
      name: tunnelData.name || `Test Tunnel ${tunnelId}`,
      status: 'connected',
      endpoints: [
        {
          id: `endpoint-${tunnelId}`,
          url: 'http://localhost:3000',
          priority: 1,
          weight: 100,
          healthStatus: 'healthy',
          lastHealthCheck: new Date(),
        },
      ],
      config: {
        maxConnections: 100,
        timeout: 30000,
        compression: true,
      },
      metrics: {
        requestCount: 0,
        successCount: 0,
        errorCount: 0,
        averageLatency: 0,
      },
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    this.sandboxTunnels.set(tunnelId, mockTunnel);
    logger.info(`Created mock tunnel in sandbox: ${tunnelId}`);
    return mockTunnel;
  }

  /**
   * Create mock webhook for sandbox
   * @param {Object} webhookData - Webhook data
   * @returns {Object} Created mock webhook
   */
  createMockWebhook(webhookData) {
    const webhookId = `sandbox-webhook-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    const mockWebhook = {
      id: webhookId,
      userId: webhookData.userId || 'test-user-1',
      url: webhookData.url || 'https://webhook.sandbox.local/events',
      events: webhookData.events || ['tunnel.created', 'tunnel.updated'],
      active: true,
      signature: `sandbox-sig-${webhookId}`,
      createdAt: new Date(),
      deliveryStats: {
        total: 0,
        successful: 0,
        failed: 0,
        lastDelivery: null,
      },
    };

    this.sandboxWebhooks.set(webhookId, mockWebhook);
    logger.info(`Created mock webhook in sandbox: ${webhookId}`);
    return mockWebhook;
  }

  /**
   * Log request in sandbox
   * @param {Object} request - Request details
   */
  logRequest(request) {
    // Always log in sandbox service (don't check isSandbox here)
    // The middleware will decide whether to call this
    const logEntry = {
      timestamp: new Date(),
      method: request.method,
      path: request.path,
      userId: request.userId,
      statusCode: request.statusCode,
      responseTime: request.responseTime,
      body: request.body,
    };

    this.requestLog.push(logEntry);

    // Keep log size manageable
    if (this.requestLog.length > this.maxRequestLogSize) {
      this.requestLog.shift();
    }
  }

  /**
   * Get request log
   * @param {Object} options - Filter options
   * @returns {Array} Request log entries
   */
  getRequestLog(options = {}) {
    let log = [...this.requestLog];

    if (options.userId) {
      log = log.filter((entry) => entry.userId === options.userId);
    }

    if (options.method) {
      log = log.filter((entry) => entry.method === options.method);
    }

    if (options.path) {
      log = log.filter((entry) => entry.path.includes(options.path));
    }

    if (options.limit) {
      log = log.slice(-options.limit);
    }

    return log;
  }

  /**
   * Clear sandbox data
   */
  clearSandboxData() {
    this.sandboxUsers.clear();
    this.sandboxTunnels.clear();
    this.sandboxWebhooks.clear();
    this.requestLog = [];
    logger.info('Cleared all sandbox data');
  }

  /**
   * Get sandbox statistics
   * @returns {Object} Sandbox statistics
   */
  getSandboxStats() {
    return {
      users: this.sandboxUsers.size,
      tunnels: this.sandboxTunnels.size,
      webhooks: this.sandboxWebhooks.size,
      requestsLogged: this.requestLog.length,
      enabled: this.isSandboxEnabled,
    };
  }

  /**
   * Get mock user by ID
   * @param {string} userId - User ID
   * @returns {Object|null} Mock user or null
   */
  getMockUser(userId) {
    return this.sandboxUsers.get(userId) || null;
  }

  /**
   * Get mock tunnel by ID
   * @param {string} tunnelId - Tunnel ID
   * @returns {Object|null} Mock tunnel or null
   */
  getMockTunnel(tunnelId) {
    return this.sandboxTunnels.get(tunnelId) || null;
  }

  /**
   * Get mock webhook by ID
   * @param {string} webhookId - Webhook ID
   * @returns {Object|null} Mock webhook or null
   */
  getMockWebhook(webhookId) {
    return this.sandboxWebhooks.get(webhookId) || null;
  }

  /**
   * Update mock tunnel status
   * @param {string} tunnelId - Tunnel ID
   * @param {string} status - New status
   */
  updateMockTunnelStatus(tunnelId, status) {
    const tunnel = this.sandboxTunnels.get(tunnelId);
    if (tunnel) {
      tunnel.status = status;
      tunnel.updatedAt = new Date();
      logger.info(`Updated mock tunnel status: ${tunnelId} -> ${status}`);
    }
  }

  /**
   * Record mock tunnel metrics
   * @param {string} tunnelId - Tunnel ID
   * @param {Object} metrics - Metrics to record
   */
  recordMockTunnelMetrics(tunnelId, metrics) {
    const tunnel = this.sandboxTunnels.get(tunnelId);
    if (tunnel) {
      tunnel.metrics.requestCount += metrics.requestCount || 0;
      tunnel.metrics.successCount += metrics.successCount || 0;
      tunnel.metrics.errorCount += metrics.errorCount || 0;
      if (metrics.latency) {
        tunnel.metrics.averageLatency = metrics.latency;
      }
    }
  }
}

// Export singleton instance
export const sandboxService = new SandboxService();
