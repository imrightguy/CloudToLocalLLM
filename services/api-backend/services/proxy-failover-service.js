import winston from 'winston';
import { v4 as uuidv4 } from 'uuid';

/**
 * ProxyFailoverService - Manages proxy failover and redundancy
 * Implements failover logic, redundancy management, and instance health tracking
 * Validates: Requirements 5.8
 */
export class ProxyFailoverService {
  constructor(db = null, logger = null) {
    this.db = db;
    this.logger =
      logger ||
      winston.createLogger({
        level: process.env.LOG_LEVEL || 'info',
        format: winston.format.combine(
          winston.format.timestamp(),
          winston.format.errors({ stack: true }),
          winston.format.json(),
        ),
        defaultMeta: { service: 'proxy-failover' },
        transports: [
          new winston.transports.Console({
            format: winston.format.combine(
              winston.format.timestamp(),
              winston.format.simple(),
            ),
          }),
        ],
      });

    // In-memory tracking
    this.failoverState = new Map(); // proxyId -> failover state
    this.instanceHealthCache = new Map(); // instanceId -> health status
    this.activeInstances = new Map(); // proxyId -> active instance ID

    // Default failover configuration
    this.defaultConfig = {
      failoverStrategy: 'priority',
      healthCheckIntervalSeconds: 30,
      healthCheckTimeoutSeconds: 5,
      unhealthyThreshold: 3,
      healthyThreshold: 2,
      maxRecoveryAttempts: 3,
      recoveryBackoffSeconds: 5,
      enableAutoFailover: true,
      enableAutoRecovery: true,
      enableLoadBalancing: false,
      loadBalancingAlgorithm: 'round_robin',
    };

    // Failover callbacks
    this.onFailoverNeeded = null;
    this.onRecoveryNeeded = null;
    this.onRedundancyStatusChanged = null;
  }

  /**
   * Create or update failover configuration for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {Object} config - Failover configuration
   * @returns {Promise<Object>} Created/updated configuration
   */
  async createFailoverConfiguration(proxyId, userId, config = {}) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    // Merge with defaults
    const mergedConfig = { ...this.defaultConfig, ...config };

    // Validate configuration
    this.validateFailoverConfig(mergedConfig);

    try {
      const result = await this.db.query(
        `INSERT INTO proxy_failover_configurations (
          proxy_id, user_id, failover_strategy, health_check_interval_seconds,
          health_check_timeout_seconds, unhealthy_threshold, healthy_threshold,
          max_recovery_attempts, recovery_backoff_seconds, enable_auto_failover,
          enable_auto_recovery, enable_load_balancing, load_balancing_algorithm
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
        ON CONFLICT (proxy_id) DO UPDATE SET
          failover_strategy = $3, health_check_interval_seconds = $4,
          health_check_timeout_seconds = $5, unhealthy_threshold = $6,
          healthy_threshold = $7, max_recovery_attempts = $8,
          recovery_backoff_seconds = $9, enable_auto_failover = $10,
          enable_auto_recovery = $11, enable_load_balancing = $12,
          load_balancing_algorithm = $13, updated_at = CURRENT_TIMESTAMP
        RETURNING *`,
        [
          proxyId,
          userId,
          mergedConfig.failoverStrategy,
          mergedConfig.healthCheckIntervalSeconds,
          mergedConfig.healthCheckTimeoutSeconds,
          mergedConfig.unhealthyThreshold,
          mergedConfig.healthyThreshold,
          mergedConfig.maxRecoveryAttempts,
          mergedConfig.recoveryBackoffSeconds,
          mergedConfig.enableAutoFailover,
          mergedConfig.enableAutoRecovery,
          mergedConfig.enableLoadBalancing,
          mergedConfig.loadBalancingAlgorithm,
        ],
      );

      this.logger.info('Failover configuration created/updated', {
        proxyId,
        userId,
        config: mergedConfig,
      });

      return this.formatConfigResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error creating failover configuration', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get failover configuration for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Promise<Object>} Failover configuration
   */
  async getFailoverConfiguration(proxyId) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        'SELECT * FROM proxy_failover_configurations WHERE proxy_id = $1',
        [proxyId],
      );

      if (result.rows.length === 0) {
        return null;
      }

      return this.formatConfigResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error retrieving failover configuration', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Register a proxy instance
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {Object} instanceData - Instance data
   * @returns {Promise<Object>} Registered instance
   */
  async registerProxyInstance(proxyId, userId, instanceData) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    if (!instanceData || !instanceData.instanceName) {
      throw new Error('instanceData with instanceName is required');
    }

    const {
      instanceName,
      instanceType = 'standard',
      priority = 100,
      weight = 100,
    } = instanceData;

    try {
      const result = await this.db.query(
        `INSERT INTO proxy_instances (
          proxy_id, user_id, instance_name, instance_type, priority, weight, status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7)
        RETURNING *`,
        [
          proxyId,
          userId,
          instanceName,
          instanceType,
          priority,
          weight,
          'unknown',
        ],
      );

      const instance = result.rows[0];

      this.logger.info('Proxy instance registered', {
        proxyId,
        userId,
        instanceId: instance.id,
        instanceName,
      });

      return this.formatInstanceResponse(instance);
    } catch (error) {
      this.logger.error('Error registering proxy instance', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get all instances for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Promise<Array>} Proxy instances
   */
  async getProxyInstances(proxyId) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        `SELECT * FROM proxy_instances 
         WHERE proxy_id = $1 AND is_active = true
         ORDER BY priority ASC, weight DESC`,
        [proxyId],
      );

      return result.rows.map((row) => this.formatInstanceResponse(row));
    } catch (error) {
      this.logger.error('Error retrieving proxy instances', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update instance health status
   * @param {string} instanceId - Instance ID
   * @param {string} healthStatus - Health status (healthy, unhealthy, unknown)
   * @param {Object} metrics - Instance metrics
   * @returns {Promise<Object>} Updated instance
   */
  async updateInstanceHealth(instanceId, healthStatus, metrics = {}) {
    if (!instanceId) {
      throw new Error('instanceId is required');
    }

    if (!['healthy', 'unhealthy', 'unknown'].includes(healthStatus)) {
      throw new Error('healthStatus must be healthy, unhealthy, or unknown');
    }

    try {
      // Get current instance
      const currentResult = await this.db.query(
        'SELECT * FROM proxy_instances WHERE id = $1',
        [instanceId],
      );

      if (currentResult.rows.length === 0) {
        throw new Error(`Instance not found: ${instanceId}`);
      }

      const currentInstance = currentResult.rows[0];
      const previousStatus = currentInstance.health_status;

      // Update consecutive failures
      let consecutiveFailures = currentInstance.consecutive_failures;
      if (healthStatus === 'unhealthy') {
        consecutiveFailures += 1;
      } else if (healthStatus === 'healthy') {
        consecutiveFailures = 0;
      }

      // Update instance
      const result = await this.db.query(
        `UPDATE proxy_instances 
         SET health_status = $1, last_health_check = CURRENT_TIMESTAMP,
             consecutive_failures = $2, updated_at = CURRENT_TIMESTAMP
         WHERE id = $3
         RETURNING *`,
        [healthStatus, consecutiveFailures, instanceId],
      );

      const updatedInstance = result.rows[0];

      // Record metrics if provided
      if (Object.keys(metrics).length > 0) {
        await this.recordInstanceMetrics(
          instanceId,
          currentInstance.proxy_id,
          currentInstance.user_id,
          metrics,
        );
      }

      // Cache health status
      this.instanceHealthCache.set(instanceId, {
        status: healthStatus,
        timestamp: new Date(),
        consecutiveFailures,
      });

      this.logger.debug('Instance health updated', {
        instanceId,
        previousStatus,
        newStatus: healthStatus,
        consecutiveFailures,
      });

      return this.formatInstanceResponse(updatedInstance);
    } catch (error) {
      this.logger.error('Error updating instance health', {
        instanceId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Record instance metrics
   * @param {string} instanceId - Instance ID
   * @param {string} proxyId - Proxy ID
   * @param {string} userId - User ID
   * @param {Object} metrics - Instance metrics
   * @returns {Promise<Object>} Recorded metrics
   */
  async recordInstanceMetrics(instanceId, proxyId, userId, metrics) {
    if (!instanceId || !proxyId || !userId) {
      throw new Error('instanceId, proxyId, and userId are required');
    }

    try {
      const result = await this.db.query(
        `INSERT INTO proxy_instance_metrics (
          instance_id, proxy_id, user_id, cpu_percent, memory_percent,
          request_rate, average_latency_ms, error_rate, connection_count, throughput_mbps
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *`,
        [
          instanceId,
          proxyId,
          userId,
          metrics.cpuPercent || 0,
          metrics.memoryPercent || 0,
          metrics.requestRate || 0,
          metrics.averageLatencyMs || 0,
          metrics.errorRate || 0,
          metrics.connectionCount || 0,
          metrics.throughputMbps || 0,
        ],
      );

      return result.rows[0];
    } catch (error) {
      this.logger.error('Error recording instance metrics', {
        instanceId,
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Evaluate if failover is needed
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Failover decision
   */
  async evaluateFailover(proxyId, userId) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    try {
      // Get failover configuration
      const config = await this.getFailoverConfiguration(proxyId);
      if (!config || !config.enableAutoFailover) {
        return {
          proxyId,
          shouldFailover: false,
          reason: 'Auto failover is disabled',
        };
      }

      // Get all instances
      const instances = await this.getProxyInstances(proxyId);
      if (instances.length === 0) {
        return {
          proxyId,
          shouldFailover: false,
          reason: 'No instances available',
        };
      }

      // Get current active instance
      const activeInstanceId = this.activeInstances.get(proxyId);
      const activeInstance = instances.find((i) => i.id === activeInstanceId);

      // Check if active instance is unhealthy
      if (activeInstance && activeInstance.healthStatus === 'unhealthy') {
        if (activeInstance.consecutiveFailures >= config.unhealthyThreshold) {
          // Find healthy backup instance
          const backupInstance = instances.find(
            (i) => i.id !== activeInstanceId && i.healthStatus === 'healthy',
          );

          if (backupInstance) {
            return {
              proxyId,
              shouldFailover: true,
              reason: `Active instance unhealthy (${activeInstance.consecutiveFailures} failures)`,
              sourceInstanceId: activeInstanceId,
              targetInstanceId: backupInstance.id,
              strategy: config.failoverStrategy,
            };
          }
        }
      }

      return {
        proxyId,
        shouldFailover: false,
        reason: 'No failover needed',
        activeInstanceId,
      };
    } catch (error) {
      this.logger.error('Error evaluating failover', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Execute failover operation
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {string} sourceInstanceId - Source instance ID
   * @param {string} targetInstanceId - Target instance ID
   * @param {string} reason - Reason for failover
   * @returns {Promise<Object>} Failover event
   */
  async executeFailover(
    proxyId,
    userId,
    sourceInstanceId,
    targetInstanceId,
    reason,
  ) {
    if (!proxyId || !userId || !sourceInstanceId || !targetInstanceId) {
      throw new Error(
        'proxyId, userId, sourceInstanceId, and targetInstanceId are required',
      );
    }

    try {
      const eventId = uuidv4();
      const startTime = Date.now();

      // Create failover event
      const result = await this.db.query(
        `INSERT INTO proxy_failover_events (
          id, proxy_id, user_id, event_type, source_instance_id, target_instance_id,
          reason, status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
        RETURNING *`,
        [
          eventId,
          proxyId,
          userId,
          'failover',
          sourceInstanceId,
          targetInstanceId,
          reason,
          'in_progress',
        ],
      );

      const failoverEvent = result.rows[0];

      // Update active instance
      this.activeInstances.set(proxyId, targetInstanceId);

      this.logger.info('Failover event created', {
        proxyId,
        userId,
        eventId,
        sourceInstanceId,
        targetInstanceId,
        reason,
      });

      // Trigger failover callback if registered
      if (this.onFailoverNeeded) {
        try {
          await this.onFailoverNeeded(
            proxyId,
            userId,
            sourceInstanceId,
            targetInstanceId,
            failoverEvent,
          );
        } catch (error) {
          this.logger.error('Error in failover callback', {
            proxyId,
            error: error.message,
          });
        }
      }

      return {
        ...this.formatFailoverEventResponse(failoverEvent),
        startTime,
      };
    } catch (error) {
      this.logger.error('Error executing failover', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Complete a failover event
   * @param {string} eventId - Failover event ID
   * @param {string} status - Final status (completed, failed)
   * @param {string} errorMessage - Error message if failed
   * @param {number} durationMs - Duration of failover operation
   * @returns {Promise<Object>} Updated failover event
   */
  async completeFailoverEvent(
    eventId,
    status,
    errorMessage = null,
    durationMs = null,
  ) {
    if (!eventId) {
      throw new Error('eventId is required');
    }

    if (!['completed', 'failed'].includes(status)) {
      throw new Error('status must be completed or failed');
    }

    try {
      const result = await this.db.query(
        `UPDATE proxy_failover_events 
         SET status = $1, error_message = $2, duration_ms = $3, completed_at = CURRENT_TIMESTAMP
         WHERE id = $4
         RETURNING *`,
        [status, errorMessage, durationMs, eventId],
      );

      if (result.rows.length === 0) {
        throw new Error(`Failover event not found: ${eventId}`);
      }

      const event = result.rows[0];

      this.logger.info('Failover event completed', {
        eventId,
        proxyId: event.proxy_id,
        status,
        durationMs,
      });

      return this.formatFailoverEventResponse(event);
    } catch (error) {
      this.logger.error('Error completing failover event', {
        eventId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get redundancy status for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Promise<Object>} Redundancy status
   */
  async getRedundancyStatus(proxyId) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        'SELECT * FROM proxy_redundancy_status WHERE proxy_id = $1',
        [proxyId],
      );

      if (result.rows.length === 0) {
        return null;
      }

      return this.formatRedundancyStatusResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error retrieving redundancy status', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update redundancy status
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {Object} statusData - Status data
   * @returns {Promise<Object>} Updated redundancy status
   */
  async updateRedundancyStatus(proxyId, userId, statusData) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    try {
      const {
        totalInstances = 0,
        healthyInstances = 0,
        unhealthyInstances = 0,
        activeInstanceId = null,
        backupInstanceIds = [],
        redundancyLevel = 'single',
        isDegraded = false,
      } = statusData;

      const result = await this.db.query(
        `INSERT INTO proxy_redundancy_status (
          proxy_id, user_id, total_instances, healthy_instances, unhealthy_instances,
          active_instance_id, backup_instance_ids, redundancy_level, is_degraded
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
        ON CONFLICT (proxy_id) DO UPDATE SET
          total_instances = $3, healthy_instances = $4, unhealthy_instances = $5,
          active_instance_id = $6, backup_instance_ids = $7, redundancy_level = $8,
          is_degraded = $9, updated_at = CURRENT_TIMESTAMP
        RETURNING *`,
        [
          proxyId,
          userId,
          totalInstances,
          healthyInstances,
          unhealthyInstances,
          activeInstanceId,
          backupInstanceIds,
          redundancyLevel,
          isDegraded,
        ],
      );

      this.logger.info('Redundancy status updated', {
        proxyId,
        userId,
        redundancyLevel,
        isDegraded,
      });

      return this.formatRedundancyStatusResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error updating redundancy status', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get failover events for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {number} limit - Maximum number of events to return
   * @returns {Promise<Array>} Failover events
   */
  async getFailoverEvents(proxyId, limit = 50) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        `SELECT * FROM proxy_failover_events 
         WHERE proxy_id = $1 
         ORDER BY created_at DESC 
         LIMIT $2`,
        [proxyId, limit],
      );

      return result.rows.map((row) => this.formatFailoverEventResponse(row));
    } catch (error) {
      this.logger.error('Error retrieving failover events', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Validate failover configuration
   * @param {Object} config - Configuration to validate
   * @throws {Error} If configuration is invalid
   */
  validateFailoverConfig(config) {
    const validStrategies = ['priority', 'round_robin', 'least_connections'];
    if (!validStrategies.includes(config.failoverStrategy)) {
      throw new Error(
        `failoverStrategy must be one of: ${validStrategies.join(', ')}`,
      );
    }

    if (
      !Number.isInteger(config.healthCheckIntervalSeconds) ||
      config.healthCheckIntervalSeconds < 1
    ) {
      throw new Error('healthCheckIntervalSeconds must be a positive integer');
    }

    if (
      !Number.isInteger(config.unhealthyThreshold) ||
      config.unhealthyThreshold < 1
    ) {
      throw new Error('unhealthyThreshold must be a positive integer');
    }

    if (
      !Number.isInteger(config.healthyThreshold) ||
      config.healthyThreshold < 1
    ) {
      throw new Error('healthyThreshold must be a positive integer');
    }

    if (
      !Number.isInteger(config.maxRecoveryAttempts) ||
      config.maxRecoveryAttempts < 1
    ) {
      throw new Error('maxRecoveryAttempts must be a positive integer');
    }
  }

  /**
   * Format configuration response
   * @param {Object} row - Database row
   * @returns {Object} Formatted configuration
   */
  formatConfigResponse(row) {
    return {
      id: row.id,
      proxyId: row.proxy_id,
      userId: row.user_id,
      failoverStrategy: row.failover_strategy,
      healthCheckIntervalSeconds: row.health_check_interval_seconds,
      healthCheckTimeoutSeconds: row.health_check_timeout_seconds,
      unhealthyThreshold: row.unhealthy_threshold,
      healthyThreshold: row.healthy_threshold,
      maxRecoveryAttempts: row.max_recovery_attempts,
      recoveryBackoffSeconds: row.recovery_backoff_seconds,
      enableAutoFailover: row.enable_auto_failover,
      enableAutoRecovery: row.enable_auto_recovery,
      enableLoadBalancing: row.enable_load_balancing,
      loadBalancingAlgorithm: row.load_balancing_algorithm,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  /**
   * Format instance response
   * @param {Object} row - Database row
   * @returns {Object} Formatted instance
   */
  formatInstanceResponse(row) {
    return {
      id: row.id,
      proxyId: row.proxy_id,
      userId: row.user_id,
      instanceName: row.instance_name,
      instanceType: row.instance_type,
      status: row.status,
      priority: row.priority,
      weight: row.weight,
      healthStatus: row.health_status,
      lastHealthCheck: row.last_health_check,
      consecutiveFailures: row.consecutive_failures,
      totalRequests: row.total_requests,
      successfulRequests: row.successful_requests,
      failedRequests: row.failed_requests,
      averageLatencyMs: row.average_latency_ms,
      errorRate: row.error_rate,
      isActive: row.is_active,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  /**
   * Format failover event response
   * @param {Object} row - Database row
   * @returns {Object} Formatted event
   */
  formatFailoverEventResponse(row) {
    return {
      id: row.id,
      proxyId: row.proxy_id,
      userId: row.user_id,
      eventType: row.event_type,
      sourceInstanceId: row.source_instance_id,
      targetInstanceId: row.target_instance_id,
      reason: row.reason,
      status: row.status,
      errorMessage: row.error_message,
      durationMs: row.duration_ms,
      createdAt: row.created_at,
      completedAt: row.completed_at,
    };
  }

  /**
   * Format redundancy status response
   * @param {Object} row - Database row
   * @returns {Object} Formatted status
   */
  formatRedundancyStatusResponse(row) {
    return {
      id: row.id,
      proxyId: row.proxy_id,
      userId: row.user_id,
      totalInstances: row.total_instances,
      healthyInstances: row.healthy_instances,
      unhealthyInstances: row.unhealthy_instances,
      activeInstanceId: row.active_instance_id,
      backupInstanceIds: row.backup_instance_ids || [],
      lastFailoverAt: row.last_failover_at,
      lastFailoverReason: row.last_failover_reason,
      redundancyLevel: row.redundancy_level,
      isDegraded: row.is_degraded,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  /**
   * Set callback for when failover is needed
   * @param {Function} callback - Callback function
   */
  setFailoverCallback(callback) {
    this.onFailoverNeeded = callback;
  }

  /**
   * Set callback for when recovery is needed
   * @param {Function} callback - Callback function
   */
  setRecoveryCallback(callback) {
    this.onRecoveryNeeded = callback;
  }

  /**
   * Set callback for redundancy status changes
   * @param {Function} callback - Callback function
   */
  setRedundancyStatusCallback(callback) {
    this.onRedundancyStatusChanged = callback;
  }

  /**
   * Shutdown failover service
   */
  shutdown() {
    this.failoverState.clear();
    this.instanceHealthCache.clear();
    this.activeInstances.clear();

    this.logger.info('Proxy failover service shutdown complete');
  }
}

export default ProxyFailoverService;
