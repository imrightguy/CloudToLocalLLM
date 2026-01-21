/**
 * Tunnel Health Service
 *
 * Manages tunnel health checking and status tracking:
 * - Periodic health checks for tunnel endpoints
 * - Health status updates (healthy, unhealthy, unknown)
 * - Metrics collection and aggregation
 * - Request tracking (count, success rate, latency)
 *
 * Validates: Requirements 4.2, 4.6
 * - Tracks tunnel status and health metrics
 * - Implements tunnel metrics collection and aggregation
 *
 * @fileoverview Tunnel health checking and metrics service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class TunnelHealthService {
  constructor() {
    this.pool = null;
    this.healthCheckIntervals = new Map();
    this.metricsBuffer = new Map();
  }

  /**
   * Initialize the tunnel health service
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info('[TunnelHealthService] Tunnel health service initialized');
    } catch (error) {
      logger.error(
        '[TunnelHealthService] Failed to initialize tunnel health service',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Start health checks for a tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {number} intervalMs - Health check interval in milliseconds (default: 30000)
   */
  startHealthChecks(tunnelId, intervalMs = 30000) {
    if (this.healthCheckIntervals.has(tunnelId)) {
      logger.warn(
        '[TunnelHealthService] Health checks already running for tunnel',
        {
          tunnelId,
        },
      );
      return;
    }

    const interval = setInterval(async () => {
      try {
        await this.performHealthCheck(tunnelId);
      } catch (error) {
        logger.error('[TunnelHealthService] Health check failed', {
          tunnelId,
          error: error.message,
        });
      }
    }, intervalMs);

    this.healthCheckIntervals.set(tunnelId, interval);
    logger.info('[TunnelHealthService] Health checks started for tunnel', {
      tunnelId,
      intervalMs,
    });
  }

  /**
   * Stop health checks for a tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   */
  stopHealthChecks(tunnelId) {
    const interval = this.healthCheckIntervals.get(tunnelId);
    if (interval) {
      clearInterval(interval);
      this.healthCheckIntervals.delete(tunnelId);
      logger.info('[TunnelHealthService] Health checks stopped for tunnel', {
        tunnelId,
      });
    }
  }

  /**
   * Perform health check for a tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   */
  async performHealthCheck(tunnelId) {
    try {
      const endpointsResult = await this.pool.query(
        'SELECT * FROM tunnel_endpoints WHERE tunnel_id = $1',
        [tunnelId],
      );

      if (endpointsResult.rows.length === 0) {
        logger.debug('[TunnelHealthService] No endpoints found for tunnel', {
          tunnelId,
        });
        return { tunnelId, endpoints: [] };
      }

      const endpoints = endpointsResult.rows;
      const healthResults = [];

      // Check each endpoint
      for (const endpoint of endpoints) {
        const healthStatus = await this.checkEndpointHealth(endpoint.url);
        healthResults.push({
          endpointId: endpoint.id,
          url: endpoint.url,
          healthStatus,
          lastHealthCheck: new Date(),
        });

        // Update endpoint health status
        await this.pool.query(
          `UPDATE tunnel_endpoints 
           SET health_status = $1, last_health_check = NOW() 
           WHERE id = $2`,
          [healthStatus, endpoint.id],
        );
      }

      logger.debug('[TunnelHealthService] Health check completed for tunnel', {
        tunnelId,
        endpointCount: endpoints.length,
        healthyCount: healthResults.filter((r) => r.healthStatus === 'healthy')
          .length,
      });

      return {
        tunnelId,
        endpoints: healthResults,
        timestamp: new Date(),
      };
    } catch (error) {
      logger.error('[TunnelHealthService] Failed to perform health check', {
        tunnelId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Check health of a single endpoint
   *
   * @param {string} url - Endpoint URL
   * @returns {Promise<string>} Health status (healthy, unhealthy, unknown)
   */
  async checkEndpointHealth(url) {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 5000); // 5 second timeout

      const response = await fetch(url, {
        method: 'HEAD',
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      // Consider 2xx and 3xx as healthy
      if (response.status >= 200 && response.status < 400) {
        return 'healthy';
      }

      return 'unhealthy';
    } catch (error) {
      logger.debug('[TunnelHealthService] Endpoint health check failed', {
        url,
        error: error.message,
      });
      return 'unhealthy';
    }
  }

  /**
   * Record request metrics for a tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {Object} metrics - Request metrics
   * @param {number} metrics.latency - Request latency in milliseconds
   * @param {boolean} metrics.success - Whether request was successful
   * @param {number} metrics.statusCode - HTTP status code
   */
  recordRequestMetrics(tunnelId, metrics) {
    try {
      if (!this.metricsBuffer.has(tunnelId)) {
        this.metricsBuffer.set(tunnelId, {
          requestCount: 0,
          successCount: 0,
          errorCount: 0,
          totalLatency: 0,
          minLatency: Infinity,
          maxLatency: 0,
          lastUpdated: new Date(),
        });
      }

      const buffer = this.metricsBuffer.get(tunnelId);
      buffer.requestCount++;

      if (metrics.success) {
        buffer.successCount++;
      } else {
        buffer.errorCount++;
      }

      buffer.totalLatency += metrics.latency;
      buffer.minLatency = Math.min(buffer.minLatency, metrics.latency);
      buffer.maxLatency = Math.max(buffer.maxLatency, metrics.latency);
      buffer.lastUpdated = new Date();

      logger.debug('[TunnelHealthService] Request metrics recorded', {
        tunnelId,
        latency: metrics.latency,
        success: metrics.success,
      });
    } catch (error) {
      logger.error('[TunnelHealthService] Failed to record request metrics', {
        tunnelId,
        error: error.message,
      });
    }
  }

  /**
   * Get aggregated metrics for a tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   * @returns {Object} Aggregated metrics
   */
  getAggregatedMetrics(tunnelId) {
    const buffer = this.metricsBuffer.get(tunnelId);

    if (!buffer || buffer.requestCount === 0) {
      return {
        requestCount: 0,
        successCount: 0,
        errorCount: 0,
        successRate: 0,
        averageLatency: 0,
        minLatency: 0,
        maxLatency: 0,
      };
    }

    return {
      requestCount: buffer.requestCount,
      successCount: buffer.successCount,
      errorCount: buffer.errorCount,
      successRate: (buffer.successCount / buffer.requestCount) * 100,
      averageLatency: buffer.totalLatency / buffer.requestCount,
      minLatency: buffer.minLatency === Infinity ? 0 : buffer.minLatency,
      maxLatency: buffer.maxLatency,
    };
  }

  /**
   * Flush metrics to database
   *
   * @param {string} tunnelId - Tunnel ID
   * @returns {Promise<void>}
   */
  async flushMetricsToDatabase(tunnelId) {
    try {
      const metrics = this.getAggregatedMetrics(tunnelId);

      if (metrics.requestCount === 0) {
        logger.debug('[TunnelHealthService] No metrics to flush for tunnel', {
          tunnelId,
        });
        return;
      }

      await this.pool.query(
        `UPDATE tunnels 
         SET metrics = $1, updated_at = NOW() 
         WHERE id = $2`,
        [JSON.stringify(metrics), tunnelId],
      );

      logger.debug('[TunnelHealthService] Metrics flushed to database', {
        tunnelId,
        metrics,
      });

      // Reset buffer
      this.metricsBuffer.delete(tunnelId);
    } catch (error) {
      logger.error(
        '[TunnelHealthService] Failed to flush metrics to database',
        {
          tunnelId,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Get tunnel status summary
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @returns {Promise<Object>} Tunnel status summary
   */
  async getTunnelStatusSummary(tunnelId, userId) {
    try {
      // Get tunnel
      const tunnelResult = await this.pool.query(
        'SELECT * FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      const tunnel = tunnelResult.rows[0];
      if (!tunnel) {
        throw new Error('Tunnel not found');
      }

      const endpointsResult = await this.pool.query(
        'SELECT * FROM tunnel_endpoints WHERE tunnel_id = $1',
        [tunnelId],
      );

      const endpoints = endpointsResult.rows;
      const healthyEndpoints = endpoints.filter(
        (e) => e.health_status === 'healthy',
      ).length;

      return {
        tunnelId,
        status: tunnel.status,
        metrics: JSON.parse(tunnel.metrics),
        endpoints: {
          total: endpoints.length,
          healthy: healthyEndpoints,
          unhealthy: endpoints.length - healthyEndpoints,
          details: endpoints.map((e) => ({
            id: e.id,
            url: e.url,
            healthStatus: e.health_status,
            lastHealthCheck: e.last_health_check,
            priority: e.priority,
            weight: e.weight,
          })),
        },
        lastUpdated: tunnel.updated_at,
      };
    } catch (error) {
      logger.error(
        '[TunnelHealthService] Failed to get tunnel status summary',
        {
          tunnelId,
          userId,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Get health status for all endpoints of a tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @returns {Promise<Array>} Endpoint health statuses
   */
  async getEndpointHealthStatus(tunnelId, userId) {
    try {
      // Verify tunnel ownership
      const tunnelResult = await this.pool.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      // Get endpoints
      const endpointsResult = await this.pool.query(
        'SELECT * FROM tunnel_endpoints WHERE tunnel_id = $1 ORDER BY priority DESC',
        [tunnelId],
      );

      return endpointsResult.rows.map((endpoint) => ({
        id: endpoint.id,
        url: endpoint.url,
        healthStatus: endpoint.health_status,
        lastHealthCheck: endpoint.last_health_check,
        priority: endpoint.priority,
        weight: endpoint.weight,
      }));
    } catch (error) {
      logger.error(
        '[TunnelHealthService] Failed to get endpoint health status',
        {
          tunnelId,
          userId,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Update endpoint health status manually
   *
   * @param {string} endpointId - Endpoint ID
   * @param {string} healthStatus - Health status (healthy, unhealthy, unknown)
   * @returns {Promise<void>}
   */
  async updateEndpointHealthStatus(endpointId, healthStatus) {
    try {
      const validStatuses = ['healthy', 'unhealthy', 'unknown'];
      if (!validStatuses.includes(healthStatus)) {
        throw new Error(
          `Invalid health status. Must be one of: ${validStatuses.join(', ')}`,
        );
      }

      await this.pool.query(
        `UPDATE tunnel_endpoints 
         SET health_status = $1, last_health_check = NOW() 
         WHERE id = $2`,
        [healthStatus, endpointId],
      );

      logger.info('[TunnelHealthService] Endpoint health status updated', {
        endpointId,
        healthStatus,
      });
    } catch (error) {
      logger.error(
        '[TunnelHealthService] Failed to update endpoint health status',
        {
          endpointId,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Cleanup - stop all health checks
   */
  cleanup() {
    for (const interval of this.healthCheckIntervals.values()) {
      clearInterval(interval);
    }
    this.healthCheckIntervals.clear();
    this.metricsBuffer.clear();
    logger.info('[TunnelHealthService] Tunnel health service cleaned up');
  }
}
