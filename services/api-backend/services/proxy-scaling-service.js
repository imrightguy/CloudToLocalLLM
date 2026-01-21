import winston from 'winston';
import { v4 as uuidv4 } from 'uuid';

/**
 * ProxyScalingService - Manages proxy scaling based on load
 * Implements load-based scaling logic, metrics collection, and scaling policies
 * Validates: Requirements 5.5
 */
export class ProxyScalingService {
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
        defaultMeta: { service: 'proxy-scaling' },
        transports: [
          new winston.transports.Console({
            format: winston.format.combine(
              winston.format.timestamp(),
              winston.format.simple(),
            ),
          }),
        ],
      });

    // In-memory tracking of scaling state
    this.scalingState = new Map(); // proxyId -> scaling state
    this.lastScalingTime = new Map(); // proxyId -> last scaling timestamp
    this.loadMetricsCache = new Map(); // proxyId -> cached metrics

    // Default scaling policy
    this.defaultPolicy = {
      minReplicas: 1,
      maxReplicas: 10,
      targetCpuPercent: 70.0,
      targetMemoryPercent: 80.0,
      targetRequestRate: 1000.0,
      scaleUpThreshold: 80.0,
      scaleDownThreshold: 30.0,
      scaleUpCooldownSeconds: 60,
      scaleDownCooldownSeconds: 300,
    };

    // Scaling callbacks
    this.onScalingNeeded = null;
  }

  /**
   * Create or update scaling policy for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {Object} policy - Scaling policy configuration
   * @returns {Promise<Object>} Created/updated policy
   */
  async createScalingPolicy(proxyId, userId, policy = {}) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    // Merge with defaults
    const mergedPolicy = { ...this.defaultPolicy, ...policy };

    // Validate policy
    this.validateScalingPolicy(mergedPolicy);

    try {
      const result = await this.db.query(
        `INSERT INTO proxy_scaling_policies (
          proxy_id, user_id, min_replicas, max_replicas, target_cpu_percent,
          target_memory_percent, target_request_rate, scale_up_threshold,
          scale_down_threshold, scale_up_cooldown_seconds, scale_down_cooldown_seconds, enabled
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        ON CONFLICT (proxy_id) DO UPDATE SET
          min_replicas = $3, max_replicas = $4, target_cpu_percent = $5,
          target_memory_percent = $6, target_request_rate = $7,
          scale_up_threshold = $8, scale_down_threshold = $9,
          scale_up_cooldown_seconds = $10, scale_down_cooldown_seconds = $11,
          enabled = $12, updated_at = CURRENT_TIMESTAMP
        RETURNING *`,
        [
          proxyId,
          userId,
          mergedPolicy.minReplicas,
          mergedPolicy.maxReplicas,
          mergedPolicy.targetCpuPercent,
          mergedPolicy.targetMemoryPercent,
          mergedPolicy.targetRequestRate,
          mergedPolicy.scaleUpThreshold,
          mergedPolicy.scaleDownThreshold,
          mergedPolicy.scaleUpCooldownSeconds,
          mergedPolicy.scaleDownCooldownSeconds,
          true,
        ],
      );

      this.logger.info('Scaling policy created/updated', {
        proxyId,
        userId,
        policy: mergedPolicy,
      });

      return this.formatPolicyResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error creating scaling policy', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get scaling policy for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Promise<Object>} Scaling policy
   */
  async getScalingPolicy(proxyId) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        'SELECT * FROM proxy_scaling_policies WHERE proxy_id = $1',
        [proxyId],
      );

      if (result.rows.length === 0) {
        return null;
      }

      return this.formatPolicyResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error retrieving scaling policy', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Record load metrics for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {Object} metrics - Load metrics
   * @returns {Promise<Object>} Recorded metrics
   */
  async recordLoadMetrics(proxyId, userId, metrics) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    if (!metrics || typeof metrics !== 'object') {
      throw new Error('metrics must be an object');
    }

    // Validate required metrics
    const requiredMetrics = [
      'currentReplicas',
      'cpuPercent',
      'memoryPercent',
      'requestRate',
      'averageLatencyMs',
      'errorRate',
      'connectionCount',
    ];

    for (const metric of requiredMetrics) {
      if (metrics[metric] === undefined) {
        throw new Error(`Missing required metric: ${metric}`);
      }
    }

    try {
      // Calculate load score
      const loadScore = this.calculateLoadScore(metrics);

      const result = await this.db.query(
        `INSERT INTO proxy_load_metrics (
          proxy_id, user_id, current_replicas, cpu_percent, memory_percent,
          request_rate, average_latency_ms, error_rate, connection_count, load_score
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *`,
        [
          proxyId,
          userId,
          metrics.currentReplicas,
          metrics.cpuPercent,
          metrics.memoryPercent,
          metrics.requestRate,
          metrics.averageLatencyMs,
          metrics.errorRate,
          metrics.connectionCount,
          loadScore,
        ],
      );

      // Cache metrics
      this.loadMetricsCache.set(proxyId, {
        ...metrics,
        loadScore,
        timestamp: new Date(),
      });

      this.logger.debug('Load metrics recorded', {
        proxyId,
        userId,
        loadScore,
      });

      return this.formatMetricsResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error recording load metrics', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get current load metrics for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @returns {Promise<Object>} Current load metrics
   */
  async getCurrentLoadMetrics(proxyId) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        `SELECT * FROM proxy_load_metrics 
         WHERE proxy_id = $1 
         ORDER BY created_at DESC 
         LIMIT 1`,
        [proxyId],
      );

      if (result.rows.length === 0) {
        return null;
      }

      return this.formatMetricsResponse(result.rows[0]);
    } catch (error) {
      this.logger.error('Error retrieving load metrics', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Evaluate if scaling is needed based on current metrics
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Scaling decision
   */
  async evaluateScaling(proxyId, userId) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    try {
      // Get scaling policy
      const policy = await this.getScalingPolicy(proxyId);
      if (!policy) {
        return {
          proxyId,
          shouldScale: false,
          reason: 'No scaling policy configured',
        };
      }

      if (!policy.enabled) {
        return {
          proxyId,
          shouldScale: false,
          reason: 'Scaling policy is disabled',
        };
      }

      // Get current metrics
      const metrics = await this.getCurrentLoadMetrics(proxyId);
      if (!metrics) {
        return {
          proxyId,
          shouldScale: false,
          reason: 'No metrics available',
        };
      }

      // Check cooldown period
      const lastScaling = this.lastScalingTime.get(proxyId);
      if (lastScaling) {
        const timeSinceLastScaling = (Date.now() - lastScaling) / 1000;
        const cooldownSeconds =
          metrics.loadScore > policy.scaleUpThreshold
            ? policy.scaleUpCooldownSeconds
            : policy.scaleDownCooldownSeconds;

        if (timeSinceLastScaling < cooldownSeconds) {
          return {
            proxyId,
            shouldScale: false,
            reason: `Cooldown period active (${cooldownSeconds}s)`,
            timeSinceLastScaling,
          };
        }
      }

      // Determine scaling action
      let scalingAction = null;
      let reason = null;

      if (metrics.loadScore > policy.scaleUpThreshold) {
        // Scale up
        if (metrics.currentReplicas < policy.maxReplicas) {
          scalingAction = 'scale_up';
          reason = `Load score ${metrics.loadScore.toFixed(2)} exceeds threshold ${policy.scaleUpThreshold}`;
        }
      } else if (metrics.loadScore < policy.scaleDownThreshold) {
        // Scale down
        if (metrics.currentReplicas > policy.minReplicas) {
          scalingAction = 'scale_down';
          reason = `Load score ${metrics.loadScore.toFixed(2)} below threshold ${policy.scaleDownThreshold}`;
        }
      }

      return {
        proxyId,
        shouldScale: scalingAction !== null,
        scalingAction,
        reason,
        currentReplicas: metrics.currentReplicas,
        loadScore: metrics.loadScore,
        policy: {
          minReplicas: policy.minReplicas,
          maxReplicas: policy.maxReplicas,
          scaleUpThreshold: policy.scaleUpThreshold,
          scaleDownThreshold: policy.scaleDownThreshold,
        },
      };
    } catch (error) {
      this.logger.error('Error evaluating scaling', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Execute scaling operation
   * @param {string} proxyId - Unique proxy identifier
   * @param {string} userId - User ID
   * @param {number} newReplicaCount - Target number of replicas
   * @param {string} reason - Reason for scaling
   * @param {string} triggeredBy - Source of scaling trigger (auto, manual, admin)
   * @returns {Promise<Object>} Scaling event
   */
  async executeScaling(
    proxyId,
    userId,
    newReplicaCount,
    reason,
    triggeredBy = 'manual',
  ) {
    if (!proxyId || !userId) {
      throw new Error('proxyId and userId are required');
    }

    if (!Number.isInteger(newReplicaCount) || newReplicaCount < 1) {
      throw new Error('newReplicaCount must be a positive integer');
    }

    try {
      // Get current metrics
      const metrics = await this.getCurrentLoadMetrics(proxyId);
      if (!metrics) {
        throw new Error('No metrics available for scaling');
      }

      const previousReplicas = metrics.currentReplicas;

      // Create scaling event
      const eventId = uuidv4();
      const result = await this.db.query(
        `INSERT INTO proxy_scaling_events (
          id, proxy_id, user_id, event_type, previous_replicas, new_replicas,
          reason, triggered_by, load_metrics, status
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *`,
        [
          eventId,
          proxyId,
          userId,
          newReplicaCount > previousReplicas ? 'scale_up' : 'scale_down',
          previousReplicas,
          newReplicaCount,
          reason,
          triggeredBy,
          JSON.stringify({
            cpuPercent: metrics.cpuPercent,
            memoryPercent: metrics.memoryPercent,
            requestRate: metrics.requestRate,
            loadScore: metrics.loadScore,
          }),
          'in_progress',
        ],
      );

      const scalingEvent = result.rows[0];

      // Update last scaling time
      this.lastScalingTime.set(proxyId, Date.now());

      this.logger.info('Scaling event created', {
        proxyId,
        userId,
        eventId,
        previousReplicas,
        newReplicaCount,
        reason,
        triggeredBy,
      });

      // Trigger scaling callback if registered
      if (this.onScalingNeeded) {
        try {
          await this.onScalingNeeded(
            proxyId,
            userId,
            newReplicaCount,
            scalingEvent,
          );
        } catch (error) {
          this.logger.error('Error in scaling callback', {
            proxyId,
            error: error.message,
          });
        }
      }

      return this.formatScalingEventResponse(scalingEvent);
    } catch (error) {
      this.logger.error('Error executing scaling', {
        proxyId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Complete a scaling event
   * @param {string} eventId - Scaling event ID
   * @param {string} status - Final status (completed, failed)
   * @param {string} errorMessage - Error message if failed
   * @param {number} durationMs - Duration of scaling operation
   * @returns {Promise<Object>} Updated scaling event
   */
  async completeScalingEvent(
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
        `UPDATE proxy_scaling_events 
         SET status = $1, error_message = $2, duration_ms = $3, completed_at = CURRENT_TIMESTAMP
         WHERE id = $4
         RETURNING *`,
        [status, errorMessage, durationMs, eventId],
      );

      if (result.rows.length === 0) {
        throw new Error(`Scaling event not found: ${eventId}`);
      }

      const event = result.rows[0];

      this.logger.info('Scaling event completed', {
        eventId,
        proxyId: event.proxy_id,
        status,
        durationMs,
      });

      return this.formatScalingEventResponse(event);
    } catch (error) {
      this.logger.error('Error completing scaling event', {
        eventId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get scaling events for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {number} limit - Maximum number of events to return
   * @returns {Promise<Array>} Scaling events
   */
  async getScalingEvents(proxyId, limit = 50) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        `SELECT * FROM proxy_scaling_events 
         WHERE proxy_id = $1 
         ORDER BY created_at DESC 
         LIMIT $2`,
        [proxyId, limit],
      );

      return result.rows.map((row) => this.formatScalingEventResponse(row));
    } catch (error) {
      this.logger.error('Error retrieving scaling events', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get scaling history for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {number} limit - Maximum number of records to return
   * @returns {Promise<Array>} Scaling history
   */
  async getScalingHistory(proxyId, limit = 100) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const result = await this.db.query(
        `SELECT * FROM proxy_scaling_history 
         WHERE proxy_id = $1 
         ORDER BY timestamp DESC 
         LIMIT $2`,
        [proxyId, limit],
      );

      return result.rows;
    } catch (error) {
      this.logger.error('Error retrieving scaling history', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get scaling metrics summary for a proxy
   * @param {string} proxyId - Unique proxy identifier
   * @param {number} hoursBack - Number of hours to look back
   * @returns {Promise<Object>} Scaling metrics summary
   */
  async getScalingSummary(proxyId, hoursBack = 24) {
    if (!proxyId) {
      throw new Error('proxyId is required');
    }

    try {
      const cutoffTime = new Date(Date.now() - hoursBack * 60 * 60 * 1000);

      // Get scaling events
      const eventsResult = await this.db.query(
        `SELECT * FROM proxy_scaling_events 
         WHERE proxy_id = $1 AND created_at >= $2
         ORDER BY created_at DESC`,
        [proxyId, cutoffTime],
      );

      const events = eventsResult.rows;

      // Get load metrics
      const metricsResult = await this.db.query(
        `SELECT * FROM proxy_load_metrics 
         WHERE proxy_id = $1 AND created_at >= $2
         ORDER BY created_at DESC`,
        [proxyId, cutoffTime],
      );

      const metrics = metricsResult.rows;

      // Calculate statistics
      const scaleUpCount = events.filter(
        (e) => e.event_type === 'scale_up',
      ).length;
      const scaleDownCount = events.filter(
        (e) => e.event_type === 'scale_down',
      ).length;
      const successfulCount = events.filter(
        (e) => e.status === 'completed',
      ).length;
      const failedCount = events.filter((e) => e.status === 'failed').length;

      const avgLoadScore =
        metrics.length > 0
          ? metrics.reduce((sum, m) => sum + m.load_score, 0) / metrics.length
          : 0;

      const maxLoadScore =
        metrics.length > 0 ? Math.max(...metrics.map((m) => m.load_score)) : 0;
      const minLoadScore =
        metrics.length > 0 ? Math.min(...metrics.map((m) => m.load_score)) : 0;

      return {
        proxyId,
        timeRange: {
          hoursBack,
          from: cutoffTime,
          to: new Date(),
        },
        scalingEvents: {
          total: events.length,
          scaleUp: scaleUpCount,
          scaleDown: scaleDownCount,
          successful: successfulCount,
          failed: failedCount,
        },
        loadMetrics: {
          recordCount: metrics.length,
          averageLoadScore: avgLoadScore.toFixed(2),
          maxLoadScore: maxLoadScore.toFixed(2),
          minLoadScore: minLoadScore.toFixed(2),
        },
      };
    } catch (error) {
      this.logger.error('Error retrieving scaling summary', {
        proxyId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Validate scaling policy
   * @param {Object} policy - Policy to validate
   * @throws {Error} If policy is invalid
   */
  validateScalingPolicy(policy) {
    if (!Number.isInteger(policy.minReplicas) || policy.minReplicas < 1) {
      throw new Error('minReplicas must be a positive integer');
    }

    if (
      !Number.isInteger(policy.maxReplicas) ||
      policy.maxReplicas < policy.minReplicas
    ) {
      throw new Error('maxReplicas must be >= minReplicas');
    }

    if (
      typeof policy.targetCpuPercent !== 'number' ||
      policy.targetCpuPercent < 0 ||
      policy.targetCpuPercent > 100
    ) {
      throw new Error('targetCpuPercent must be between 0 and 100');
    }

    if (
      typeof policy.targetMemoryPercent !== 'number' ||
      policy.targetMemoryPercent < 0 ||
      policy.targetMemoryPercent > 100
    ) {
      throw new Error('targetMemoryPercent must be between 0 and 100');
    }

    if (
      typeof policy.scaleUpThreshold !== 'number' ||
      policy.scaleUpThreshold < 0 ||
      policy.scaleUpThreshold > 100
    ) {
      throw new Error('scaleUpThreshold must be between 0 and 100');
    }

    if (
      typeof policy.scaleDownThreshold !== 'number' ||
      policy.scaleDownThreshold < 0 ||
      policy.scaleDownThreshold > 100
    ) {
      throw new Error('scaleDownThreshold must be between 0 and 100');
    }

    if (policy.scaleDownThreshold >= policy.scaleUpThreshold) {
      throw new Error('scaleDownThreshold must be less than scaleUpThreshold');
    }

    if (
      !Number.isInteger(policy.scaleUpCooldownSeconds) ||
      policy.scaleUpCooldownSeconds < 0
    ) {
      throw new Error('scaleUpCooldownSeconds must be a non-negative integer');
    }

    if (
      !Number.isInteger(policy.scaleDownCooldownSeconds) ||
      policy.scaleDownCooldownSeconds < 0
    ) {
      throw new Error(
        'scaleDownCooldownSeconds must be a non-negative integer',
      );
    }
  }

  /**
   * Calculate composite load score
   * @param {Object} metrics - Load metrics
   * @returns {number} Load score (0-100)
   */
  calculateLoadScore(metrics) {
    // Weighted average of normalized metrics
    const cpuScore = Math.min(metrics.cpuPercent, 100);
    const memoryScore = Math.min(metrics.memoryPercent, 100);
    const errorScore = Math.min(metrics.errorRate * 100, 100);

    // Normalize request rate (assume 1000 req/s is 100%)
    const requestScore = Math.min((metrics.requestRate / 1000) * 100, 100);

    // Weights: CPU 40%, Memory 30%, Request Rate 20%, Error Rate 10%
    const loadScore =
      cpuScore * 0.4 +
      memoryScore * 0.3 +
      requestScore * 0.2 +
      errorScore * 0.1;

    return Math.round(loadScore * 100) / 100;
  }

  /**
   * Format policy response
   * @param {Object} row - Database row
   * @returns {Object} Formatted policy
   */
  formatPolicyResponse(row) {
    return {
      id: row.id,
      proxyId: row.proxy_id,
      userId: row.user_id,
      minReplicas: row.min_replicas,
      maxReplicas: row.max_replicas,
      targetCpuPercent: row.target_cpu_percent,
      targetMemoryPercent: row.target_memory_percent,
      targetRequestRate: row.target_request_rate,
      scaleUpThreshold: row.scale_up_threshold,
      scaleDownThreshold: row.scale_down_threshold,
      scaleUpCooldownSeconds: row.scale_up_cooldown_seconds,
      scaleDownCooldownSeconds: row.scale_down_cooldown_seconds,
      enabled: row.enabled,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  /**
   * Format metrics response
   * @param {Object} row - Database row
   * @returns {Object} Formatted metrics
   */
  formatMetricsResponse(row) {
    return {
      id: row.id,
      proxyId: row.proxy_id,
      userId: row.user_id,
      currentReplicas: row.current_replicas,
      cpuPercent: row.cpu_percent,
      memoryPercent: row.memory_percent,
      requestRate: row.request_rate,
      averageLatencyMs: row.average_latency_ms,
      errorRate: row.error_rate,
      connectionCount: row.connection_count,
      loadScore: row.load_score,
      createdAt: row.created_at,
    };
  }

  /**
   * Format scaling event response
   * @param {Object} row - Database row
   * @returns {Object} Formatted event
   */
  formatScalingEventResponse(row) {
    return {
      id: row.id,
      proxyId: row.proxy_id,
      userId: row.user_id,
      eventType: row.event_type,
      previousReplicas: row.previous_replicas,
      newReplicas: row.new_replicas,
      reason: row.reason,
      triggeredBy: row.triggered_by,
      loadMetrics: row.load_metrics ? JSON.parse(row.load_metrics) : null,
      status: row.status,
      errorMessage: row.error_message,
      durationMs: row.duration_ms,
      createdAt: row.created_at,
      completedAt: row.completed_at,
    };
  }

  /**
   * Set callback for when scaling is needed
   * @param {Function} callback - Callback function
   */
  setScalingCallback(callback) {
    this.onScalingNeeded = callback;
  }

  /**
   * Shutdown scaling service
   */
  shutdown() {
    this.scalingState.clear();
    this.lastScalingTime.clear();
    this.loadMetricsCache.clear();

    this.logger.info('Proxy scaling service shutdown complete');
  }
}

export default ProxyScalingService;
