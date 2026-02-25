import * as k8s from '@kubernetes/client-node';
import crypto from 'crypto';
import winston from 'winston';
import { getUserTier, shouldUseDirectTunnel } from './middleware/tier-check.js';

// Initialize K8s client
const kc = new k8s.KubeConfig();
kc.loadFromDefault();
const k8sApi = kc.makeApiClient(k8s.CoreV1Api);
const namespace = process.env.K8S_NAMESPACE || 'CloudToLocalLLM';

// Logger for proxy management
const logger = winston.createLogger({
  level: process.env.LOG_LEVEL || 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json(),
  ),
  defaultMeta: { service: 'proxy-manager' },
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
 * StreamingProxyManager - Manages ephemeral streaming proxy pods in Kubernetes
 * Implements zero-storage, multi-tenant architecture with complete user isolation
 */
export class StreamingProxyManager {
  constructor() {
    this.activeProxies = new Map(); // userId -> proxy metadata
    this.cleanupInterval = null;
    // Note: k8s client is declared at module scope; keep instance usage minimal per process

    // Start periodic cleanup
    this.startCleanupProcess();
  }

  /**
   * Generate secure, collision-free proxy identifier
   */
  generateProxyId(userId) {
    const hash = crypto.createHash('sha256').update(userId).digest('hex');
    return `proxy-${hash.substring(0, 12)}`;
  }

  /**
   * Provision streaming proxy pod for user with tier-aware logic
   */
  async provisionProxy(userId, _userToken, user = null) {
    // Input validation
    if (!userId || typeof userId !== 'string') {
      throw new Error('Valid userId is required for proxy provisioning');
    }

    const proxyId = this.generateProxyId(userId);

    try {
      // Check user tier - free tier users get direct tunnel access
      if (user && shouldUseDirectTunnel(user)) {
        const userTier = getUserTier(user);

        logger.info(
          'ℹ️ [StreamingProxy] Free tier user detected, providing direct tunnel access',
          {
            userTier,
            userId,
            proxyId,
          },
        );

        // Return direct tunnel configuration instead of pod
        const directTunnelConfig = {
          userId,
          proxyId: `direct-tunnel-${userId}`,
          directTunnel: true,
          endpoint: `/api/direct-proxy/${userId}`,
          port: null,
          createdAt: new Date(),
          lastActivity: new Date(),
          status: 'direct-tunnel',
          userTier,
          type: 'direct-tunnel',
        };

        return directTunnelConfig;
      }

      // Premium/Enterprise tier pod provisioning
      logger.info(
        '🚀 [StreamingProxy] Premium tier user detected, provisioning pod',
        {
          userId,
          userTier: getUserTier(user),
          proxyId,
        },
      );

      // Check if proxy already exists
      if (this.activeProxies.has(userId)) {
        const existingProxy = this.activeProxies.get(userId);
        logger.info(`Proxy already exists for user: ${userId}`);
        return existingProxy;
      }

      // Pod configuration
      const podManifest = {
        apiVersion: 'v1',
        kind: 'Pod',
        metadata: {
          name: proxyId,
          namespace: namespace,
          labels: {
            app: 'streaming-proxy',
            'CloudToLocalLLM.user': userId,
            'CloudToLocalLLM.type': 'streaming-proxy',
          },
        },
        spec: {
          containers: [
            {
              name: 'proxy',
              image:
                'ghcr.io/cloudtolocalllm-online/CloudToLocalLLM/streaming:latest',
              env: [
                { name: 'USER_ID', value: userId },
                { name: 'PROXY_ID', value: proxyId },
                { name: 'NODE_ENV', value: 'production' },
                { name: 'LOG_LEVEL', value: 'info' },
                {
                  name: 'OLLAMA_BASE_URL',
                  value: `http://api-backend:8080/api/tunnel/${userId}`,
                },
                { name: 'API_BASE_URL', value: 'http://api-backend:8080' },
              ],
              resources: {
                requests: {
                  memory: '128Mi',
                  cpu: '100m',
                },
                limits: {
                  memory: '512Mi',
                  cpu: '500m',
                },
              },
              ports: [{ containerPort: 8080 }],
            },
          ],
          restartPolicy: 'Never',
        },
      };

      // Create pod
      await k8sApi.createNamespacedPod(namespace, podManifest);

      // Store proxy metadata
      const proxyMetadata = {
        userId,
        proxyId,
        podName: proxyId,
        createdAt: new Date(),
        lastActivity: new Date(),
        status: 'provisioning',
      };

      this.activeProxies.set(userId, proxyMetadata);

      logger.info(`Provisioned streaming proxy pod for user: ${userId}`, {
        proxyId,
        namespace,
      });

      return proxyMetadata;
    } catch (error) {
      logger.error(`Failed to provision proxy for user: ${userId}`, {
        error: error.message,
        body: error.body,
      });
      throw error;
    }
  }

  /**
   * Terminate streaming proxy for user
   */
  async terminateProxy(userId) {
    try {
      const proxyMetadata = this.activeProxies.get(userId);
      if (!proxyMetadata) {
        logger.warn(`No active proxy found for user: ${userId}`);
        return false;
      }

      // Delete pod
      await k8sApi.deleteNamespacedPod(proxyMetadata.podName, namespace);

      // Remove from tracking
      this.activeProxies.delete(userId);

      logger.info(`Terminated streaming proxy for user: ${userId}`, {
        proxyId: proxyMetadata.proxyId,
        duration: Date.now() - proxyMetadata.createdAt.getTime(),
      });

      return true;
    } catch (error) {
      logger.error(`Failed to terminate proxy for user: ${userId}`, {
        error: error.message,
        body: error.body,
      });
      return false;
    }
  }

  /**
   * Get proxy status for user
   */
  async getProxyStatus(userId) {
    const proxyMetadata = this.activeProxies.get(userId);
    if (!proxyMetadata) {
      return { status: 'not-found', userId };
    }

    if (proxyMetadata.status === 'direct-tunnel') {
      return proxyMetadata;
    }

    try {
      // Check pod status
      const response = await k8sApi.readNamespacedPod(
        proxyMetadata.podName,
        namespace,
      );
      const pod = response.body;

      return {
        status: pod.status.phase.toLowerCase(),
        userId,
        proxyId: proxyMetadata.proxyId,
        createdAt: proxyMetadata.createdAt,
        lastActivity: proxyMetadata.lastActivity,
        podIP: pod.status.podIP,
      };
    } catch (error) {
      logger.error(`Failed to get proxy status for user: ${userId}`, {
        error: error.message,
        body: error.body,
      });
      return { status: 'error', userId, error: error.message };
    }
  }

  /**
   * Update last activity for proxy
   */
  updateProxyActivity(userId) {
    const proxyMetadata = this.activeProxies.get(userId);
    if (proxyMetadata) {
      proxyMetadata.lastActivity = new Date();
    }
  }

  /**
   * Start periodic cleanup process
   */
  startCleanupProcess() {
    this.cleanupInterval = setInterval(async () => {
      await this.cleanupStaleProxies();
    }, 60000); // Check every minute

    logger.info('Started proxy cleanup process');
  }

  /**
   * Clean up stale or orphaned proxies
   */
  async cleanupStaleProxies() {
    const now = Date.now();
    const staleThreshold = 10 * 60 * 1000; // 10 minutes of inactivity

    for (const [userId, proxyMetadata] of this.activeProxies.entries()) {
      const inactiveTime = now - proxyMetadata.lastActivity.getTime();

      if (inactiveTime > staleThreshold) {
        logger.info(`Cleaning up stale proxy for user: ${userId}`, {
          proxyId: proxyMetadata.proxyId,
          inactiveTime: Math.floor(inactiveTime / 1000) + 's',
        });

        await this.terminateProxy(userId);
      }
    }
  }

  /**
   * Get all active proxies (for monitoring)
   */
  getAllActiveProxies() {
    return Array.from(this.activeProxies.entries()).map(
      ([userId, metadata]) => ({
        userId,
        ...metadata,
      }),
    );
  }

  /**
   * Shutdown proxy manager
   */
  async shutdown() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
    }

    // Terminate all active proxies
    const terminationPromises = Array.from(this.activeProxies.keys()).map(
      (userId) => this.terminateProxy(userId),
    );

    await Promise.allSettled(terminationPromises);
    logger.info('Streaming proxy manager shutdown complete');
  }
}

export default StreamingProxyManager;
