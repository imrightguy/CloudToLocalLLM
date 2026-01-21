/**
 * @fileoverview Comprehensive metrics collection service for Prometheus
 * Collects standard metrics: request latency, throughput, errors, and custom API metrics
 */

import { Counter, Gauge, Histogram, register } from 'prom-client';
import { TunnelLogger } from '../utils/logger.js';

/**
 * Metrics Service - Collects and exposes Prometheus metrics
 */
export class MetricsService {
  constructor() {
    this.logger = new TunnelLogger('metrics-service');
    this.initializeMetrics();
    this.logger.info('Metrics service initialized');
  }

  /**
   * Initialize all Prometheus metrics
   */
  initializeMetrics() {
    // ============ HTTP Request Metrics ============

    // HTTP request duration histogram
    this.httpRequestDuration = new Histogram({
      name: 'http_request_duration_seconds',
      help: 'HTTP request latency in seconds',
      labelNames: ['method', 'route', 'status'],
      buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
    });

    // Total HTTP requests counter
    this.httpRequestTotal = new Counter({
      name: 'http_requests_total',
      help: 'Total number of HTTP requests',
      labelNames: ['method', 'route', 'status'],
    });

    // HTTP request errors counter
    this.httpRequestErrors = new Counter({
      name: 'http_request_errors_total',
      help: 'Total number of HTTP request errors',
      labelNames: ['method', 'route', 'error_type'],
    });

    // ============ Service Metrics ============

    // Active tunnel connections gauge
    this.tunnelConnectionsActive = new Gauge({
      name: 'tunnel_connections_active',
      help: 'Number of active tunnel connections',
    });

    // Total tunnel connections created counter
    this.tunnelConnectionsTotal = new Counter({
      name: 'tunnel_connections_total',
      help: 'Total number of tunnel connections created',
    });

    // Active proxy instances gauge
    this.proxyInstancesActive = new Gauge({
      name: 'proxy_instances_active',
      help: 'Number of active proxy instances',
    });

    // Total proxy instances created counter
    this.proxyInstancesTotal = new Counter({
      name: 'proxy_instances_total',
      help: 'Total number of proxy instances created',
    });

    // ============ Database Metrics ============

    // Database connection pool size gauge
    this.dbConnectionPoolSize = new Gauge({
      name: 'db_connection_pool_size',
      help: 'Current database connection pool size',
      labelNames: ['pool_type'],
    });

    // Database connection pool available gauge
    this.dbConnectionPoolAvailable = new Gauge({
      name: 'db_connection_pool_available',
      help: 'Available connections in database pool',
      labelNames: ['pool_type'],
    });

    // Database query duration histogram
    this.dbQueryDuration = new Histogram({
      name: 'db_query_duration_seconds',
      help: 'Database query latency in seconds',
      labelNames: ['query_type'],
      buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1],
    });

    // Database query errors counter
    this.dbQueryErrors = new Counter({
      name: 'db_query_errors_total',
      help: 'Total number of database query errors',
      labelNames: ['query_type', 'error_type'],
    });

    // Database query total counter
    this.dbQueryTotal = new Counter({
      name: 'db_queries_total',
      help: 'Total number of database queries',
      labelNames: ['query_type'],
    });

    // ============ Authentication Metrics ============

    // Authentication attempts counter
    this.authAttempts = new Counter({
      name: 'auth_attempts_total',
      help: 'Total authentication attempts',
      labelNames: ['auth_type', 'result'],
    });

    // Active sessions gauge
    this.activeSessions = new Gauge({
      name: 'active_sessions',
      help: 'Number of active user sessions',
    });

    // ============ Rate Limiting Metrics ============

    // Rate limit violations counter
    this.rateLimitViolations = new Counter({
      name: 'rate_limit_violations_total',
      help: 'Total rate limit violations',
      labelNames: ['violation_type', 'user_tier'],
    });

    // Rate limited users gauge
    this.rateLimitedUsers = new Gauge({
      name: 'rate_limited_users_active',
      help: 'Number of currently rate limited users',
    });

    // ============ System Metrics ============

    // API uptime gauge
    this.apiUptime = new Gauge({
      name: 'api_uptime_seconds',
      help: 'API uptime in seconds',
    });

    // Active users gauge
    this.activeUsers = new Gauge({
      name: 'active_users',
      help: 'Number of active users',
    });

    // System load gauge
    this.systemLoad = new Gauge({
      name: 'system_load',
      help: 'Current system load',
      labelNames: ['load_type'],
    });

    this.logger.debug('All Prometheus metrics initialized');
  }

  /**
   * Record HTTP request metrics
   * @param {Object} metrics - Request metrics
   */
  recordHttpRequest(metrics) {
    const { method, route, status, duration, error } = metrics;

    try {
      // Record request duration
      this.httpRequestDuration.observe(
        { method, route, status },
        duration / 1000, // Convert to seconds
      );

      // Increment request counter
      this.httpRequestTotal.inc({ method, route, status });

      // Record error if present
      if (error) {
        this.httpRequestErrors.inc({
          method,
          route,
          error_type: error.type || 'unknown',
        });
      }

      this.logger.debug('HTTP request metrics recorded', {
        method,
        route,
        status,
        duration,
      });
    } catch (err) {
      this.logger.error('Failed to record HTTP request metrics', {
        error: err.message,
      });
    }
  }

  /**
   * Update tunnel connection metrics
   * @param {number} activeConnections - Number of active connections
   */
  updateTunnelConnections(activeConnections) {
    try {
      this.tunnelConnectionsActive.set(activeConnections);
    } catch (error) {
      this.logger.error('Failed to update tunnel connections', {
        error: error.message,
      });
    }
  }

  /**
   * Increment tunnel connections created counter
   */
  incrementTunnelConnectionsCreated() {
    try {
      this.tunnelConnectionsTotal.inc();
    } catch (error) {
      this.logger.error('Failed to increment tunnel connections', {
        error: error.message,
      });
    }
  }

  /**
   * Update proxy instances metrics
   * @param {number} activeInstances - Number of active proxy instances
   */
  updateProxyInstances(activeInstances) {
    try {
      this.proxyInstancesActive.set(activeInstances);
    } catch (error) {
      this.logger.error('Failed to update proxy instances', {
        error: error.message,
      });
    }
  }

  /**
   * Increment proxy instances created counter
   */
  incrementProxyInstancesCreated() {
    try {
      this.proxyInstancesTotal.inc();
    } catch (error) {
      this.logger.error('Failed to increment proxy instances', {
        error: error.message,
      });
    }
  }

  /**
   * Update database connection pool metrics
   * @param {Object} poolMetrics - Pool metrics
   */
  updateDatabasePoolMetrics(poolMetrics) {
    const { poolType = 'main', size, available } = poolMetrics;

    try {
      if (size !== undefined) {
        this.dbConnectionPoolSize.set({ pool_type: poolType }, size);
      }
      if (available !== undefined) {
        this.dbConnectionPoolAvailable.set({ pool_type: poolType }, available);
      }
    } catch (error) {
      this.logger.error('Failed to update database pool metrics', {
        error: error.message,
      });
    }
  }

  /**
   * Record database query metrics
   * @param {Object} queryMetrics - Query metrics
   */
  recordDatabaseQuery(queryMetrics) {
    const { queryType = 'unknown', duration, error } = queryMetrics;

    try {
      // Record query duration
      this.dbQueryDuration.observe(
        { query_type: queryType },
        duration / 1000, // Convert to seconds
      );

      // Increment query counter
      this.dbQueryTotal.inc({ query_type: queryType });

      // Record error if present
      if (error) {
        this.dbQueryErrors.inc({
          query_type: queryType,
          error_type: error.type || 'unknown',
        });
      }

      this.logger.debug('Database query metrics recorded', {
        queryType,
        duration,
      });
    } catch (err) {
      this.logger.error('Failed to record database query metrics', {
        error: err.message,
      });
    }
  }

  /**
   * Record authentication attempt
   * @param {Object} authMetrics - Authentication metrics
   */
  recordAuthAttempt(authMetrics) {
    const { authType = 'jwt', result = 'unknown' } = authMetrics;

    try {
      this.authAttempts.inc({
        auth_type: authType,
        result,
      });

      this.logger.debug('Authentication attempt recorded', {
        authType,
        result,
      });
    } catch (error) {
      this.logger.error('Failed to record authentication attempt', {
        error: error.message,
      });
    }
  }

  /**
   * Update active sessions
   * @param {number} count - Number of active sessions
   */
  updateActiveSessions(count) {
    try {
      this.activeSessions.set(count);
    } catch (error) {
      this.logger.error('Failed to update active sessions', {
        error: error.message,
      });
    }
  }

  /**
   * Record rate limit violation
   * @param {Object} violationMetrics - Violation metrics
   */
  recordRateLimitViolation(violationMetrics) {
    const { violationType = 'unknown', userTier = 'unknown' } =
      violationMetrics;

    try {
      this.rateLimitViolations.inc({
        violation_type: violationType,
        user_tier: userTier,
      });

      this.logger.debug('Rate limit violation recorded', {
        violationType,
        userTier,
      });
    } catch (error) {
      this.logger.error('Failed to record rate limit violation', {
        error: error.message,
      });
    }
  }

  /**
   * Update rate limited users
   * @param {number} count - Number of rate limited users
   */
  updateRateLimitedUsers(count) {
    try {
      this.rateLimitedUsers.set(count);
    } catch (error) {
      this.logger.error('Failed to update rate limited users', {
        error: error.message,
      });
    }
  }

  /**
   * Update API uptime
   * @param {number} uptimeSeconds - Uptime in seconds
   */
  updateApiUptime(uptimeSeconds) {
    try {
      this.apiUptime.set(uptimeSeconds);
    } catch (error) {
      this.logger.error('Failed to update API uptime', {
        error: error.message,
      });
    }
  }

  /**
   * Update active users
   * @param {number} count - Number of active users
   */
  updateActiveUsers(count) {
    try {
      this.activeUsers.set(count);
    } catch (error) {
      this.logger.error('Failed to update active users', {
        error: error.message,
      });
    }
  }

  /**
   * Update system load
   * @param {Object} loadMetrics - Load metrics
   */
  updateSystemLoad(loadMetrics) {
    const { cpu, memory, disk } = loadMetrics;

    try {
      if (cpu !== undefined) {
        this.systemLoad.set({ load_type: 'cpu' }, cpu);
      }
      if (memory !== undefined) {
        this.systemLoad.set({ load_type: 'memory' }, memory);
      }
      if (disk !== undefined) {
        this.systemLoad.set({ load_type: 'disk' }, disk);
      }
    } catch (error) {
      this.logger.error('Failed to update system load', {
        error: error.message,
      });
    }
  }

  /**
   * Get all metrics in Prometheus format
   * @returns {Promise<string>} Prometheus metrics text
   */
  async getMetrics() {
    try {
      return await register.metrics();
    } catch (error) {
      this.logger.error('Failed to get metrics', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get metrics content type
   * @returns {string} Content type for Prometheus metrics
   */
  getContentType() {
    return register.contentType;
  }

  /**
   * Reset all metrics (for testing)
   */
  reset() {
    try {
      register.resetMetrics();
      this.logger.info('All metrics reset');
    } catch (error) {
      this.logger.error('Failed to reset metrics', {
        error: error.message,
      });
    }
  }
}

// Export singleton instance
export const metricsService = new MetricsService();

export default MetricsService;
