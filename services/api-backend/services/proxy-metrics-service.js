/**
 * Proxy Metrics Service
 *
 * Manages proxy performance metrics collection and aggregation:
 * - Collect proxy performance metrics
 * - Implement metrics aggregation
 * - Create metrics reporting endpoints
 *
 * Validates: Requirements 5.6
 * - Implements proxy metrics collection
 * - Aggregates metrics by time period
 * - Provides metrics reporting capabilities
 *
 * @fileoverview Proxy metrics collection and aggregation service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class ProxyMetricsService {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize the proxy metrics service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info('[ProxyMetricsService] Proxy metrics service initialized');
    } catch (error) {
      logger.error(
        '[ProxyMetricsService] Failed to initialize proxy metrics service',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Record a proxy metrics event
   *
   * @param {string} proxyId - Proxy ID
   * @param {string} userId - User ID
   * @param {string} eventType - Event type (request, error, connection, latency)
   * @param {Object} metrics - Metrics data
   * @returns {Promise<Object>} Created event
   */
  async recordMetricsEvent(proxyId, userId, eventType, metrics = {}) {
    try {
      const validEventTypes = ['request', 'error', 'connection', 'latency'];

      if (!validEventTypes.includes(eventType)) {
        throw new Error(
          `Invalid event type. Must be one of: ${validEventTypes.join(', ')}`,
        );
      }

      const result = await this.pool.query(
        `INSERT INTO proxy_metrics_events 
         (proxy_id, user_id, event_type, request_count, success_count, error_count, 
          total_latency_ms, min_latency_ms, max_latency_ms, data_transferred_bytes, 
          data_received_bytes, connection_count, concurrent_connections, error_message)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
         RETURNING *`,
        [
          proxyId,
          userId,
          eventType,
          metrics.requestCount || 0,
          metrics.successCount || 0,
          metrics.errorCount || 0,
          metrics.totalLatencyMs || 0,
          metrics.minLatencyMs || 0,
          metrics.maxLatencyMs || 0,
          metrics.dataTransferredBytes || 0,
          metrics.dataReceivedBytes || 0,
          metrics.connectionCount || 0,
          metrics.concurrentConnections || 0,
          metrics.errorMessage || null,
        ],
      );

      logger.debug('[ProxyMetricsService] Metrics event recorded', {
        proxyId,
        userId,
        eventType,
      });

      return result.rows[0];
    } catch (error) {
      logger.error('[ProxyMetricsService] Failed to record metrics event', {
        proxyId,
        userId,
        eventType,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get proxy metrics for a specific date
   *
   * @param {string} proxyId - Proxy ID
   * @param {string} userId - User ID (for authorization)
   * @param {string} date - Date in YYYY-MM-DD format
   * @returns {Promise<Object>} Daily metrics
   */
  async getProxyMetricsDaily(proxyId, userId, date) {
    try {
      // Verify proxy ownership
      const proxyResult = await this.pool.query(
        'SELECT id FROM proxy_health_status WHERE proxy_id = $1 AND user_id = $2',
        [proxyId, userId],
      );

      if (proxyResult.rows.length === 0) {
        throw new Error('Proxy not found');
      }

      const result = await this.pool.query(
        'SELECT * FROM proxy_metrics_daily WHERE proxy_id = $1 AND date = $2',
        [proxyId, date],
      );

      if (result.rows.length === 0) {
        return {
          proxyId,
          date,
          requestCount: 0,
          successCount: 0,
          errorCount: 0,
          averageLatencyMs: 0,
          minLatencyMs: 0,
          maxLatencyMs: 0,
          p95LatencyMs: 0,
          p99LatencyMs: 0,
          dataTransferredBytes: 0,
          dataReceivedBytes: 0,
          peakConcurrentConnections: 0,
          averageConcurrentConnections: 0,
          uptimePercentage: 100,
        };
      }

      const metrics = result.rows[0];
      return {
        proxyId: metrics.proxy_id,
        date: metrics.date,
        requestCount: metrics.request_count,
        successCount: metrics.success_count,
        errorCount: metrics.error_count,
        averageLatencyMs: metrics.average_latency_ms,
        minLatencyMs: metrics.min_latency_ms,
        maxLatencyMs: metrics.max_latency_ms,
        p95LatencyMs: metrics.p95_latency_ms,
        p99LatencyMs: metrics.p99_latency_ms,
        dataTransferredBytes: metrics.data_transferred_bytes,
        dataReceivedBytes: metrics.data_received_bytes,
        peakConcurrentConnections: metrics.peak_concurrent_connections,
        averageConcurrentConnections: metrics.average_concurrent_connections,
        uptimePercentage: metrics.uptime_percentage,
      };
    } catch (error) {
      logger.error('[ProxyMetricsService] Failed to get daily metrics', {
        proxyId,
        userId,
        date,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get proxy metrics for a date range
   *
   * @param {string} proxyId - Proxy ID
   * @param {string} userId - User ID (for authorization)
   * @param {string} startDate - Start date in YYYY-MM-DD format
   * @param {string} endDate - End date in YYYY-MM-DD format
   * @returns {Promise<Array>} Daily metrics for each day
   */
  async getProxyMetricsDailyRange(proxyId, userId, startDate, endDate) {
    try {
      // Verify proxy ownership
      const proxyResult = await this.pool.query(
        'SELECT id FROM proxy_health_status WHERE proxy_id = $1 AND user_id = $2',
        [proxyId, userId],
      );

      if (proxyResult.rows.length === 0) {
        throw new Error('Proxy not found');
      }

      const result = await this.pool.query(
        `SELECT * FROM proxy_metrics_daily 
         WHERE proxy_id = $1 AND date >= $2 AND date <= $3
         ORDER BY date ASC`,
        [proxyId, startDate, endDate],
      );

      return result.rows.map((metrics) => ({
        proxyId: metrics.proxy_id,
        date: metrics.date,
        requestCount: metrics.request_count,
        successCount: metrics.success_count,
        errorCount: metrics.error_count,
        averageLatencyMs: metrics.average_latency_ms,
        minLatencyMs: metrics.min_latency_ms,
        maxLatencyMs: metrics.max_latency_ms,
        p95LatencyMs: metrics.p95_latency_ms,
        p99LatencyMs: metrics.p99_latency_ms,
        dataTransferredBytes: metrics.data_transferred_bytes,
        dataReceivedBytes: metrics.data_received_bytes,
        peakConcurrentConnections: metrics.peak_concurrent_connections,
        averageConcurrentConnections: metrics.average_concurrent_connections,
        uptimePercentage: metrics.uptime_percentage,
      }));
    } catch (error) {
      logger.error('[ProxyMetricsService] Failed to get daily metrics range', {
        proxyId,
        userId,
        startDate,
        endDate,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get aggregated proxy metrics for a period
   *
   * @param {string} proxyId - Proxy ID
   * @param {string} userId - User ID (for authorization)
   * @param {string} periodStart - Period start date in YYYY-MM-DD format
   * @param {string} periodEnd - Period end date in YYYY-MM-DD format
   * @returns {Promise<Object>} Aggregated metrics
   */
  async getProxyMetricsAggregation(proxyId, userId, periodStart, periodEnd) {
    try {
      // Verify proxy ownership
      const proxyResult = await this.pool.query(
        'SELECT id FROM proxy_health_status WHERE proxy_id = $1 AND user_id = $2',
        [proxyId, userId],
      );

      if (proxyResult.rows.length === 0) {
        throw new Error('Proxy not found');
      }

      const result = await this.pool.query(
        `SELECT * FROM proxy_metrics_aggregation 
         WHERE proxy_id = $1 AND period_start = $2 AND period_end = $3`,
        [proxyId, periodStart, periodEnd],
      );

      if (result.rows.length === 0) {
        return {
          proxyId,
          periodStart,
          periodEnd,
          totalRequestCount: 0,
          totalSuccessCount: 0,
          totalErrorCount: 0,
          averageLatencyMs: 0,
          minLatencyMs: 0,
          maxLatencyMs: 0,
          p95LatencyMs: 0,
          p99LatencyMs: 0,
          totalDataTransferredBytes: 0,
          totalDataReceivedBytes: 0,
          peakConcurrentConnections: 0,
          averageConcurrentConnections: 0,
          averageUptimePercentage: 100,
        };
      }

      const metrics = result.rows[0];
      return {
        proxyId: metrics.proxy_id,
        periodStart: metrics.period_start,
        periodEnd: metrics.period_end,
        totalRequestCount: metrics.total_request_count,
        totalSuccessCount: metrics.total_success_count,
        totalErrorCount: metrics.total_error_count,
        averageLatencyMs: metrics.average_latency_ms,
        minLatencyMs: metrics.min_latency_ms,
        maxLatencyMs: metrics.max_latency_ms,
        p95LatencyMs: metrics.p95_latency_ms,
        p99LatencyMs: metrics.p99_latency_ms,
        totalDataTransferredBytes: metrics.total_data_transferred_bytes,
        totalDataReceivedBytes: metrics.total_data_received_bytes,
        peakConcurrentConnections: metrics.peak_concurrent_connections,
        averageConcurrentConnections: metrics.average_concurrent_connections,
        averageUptimePercentage: metrics.average_uptime_percentage,
      };
    } catch (error) {
      logger.error('[ProxyMetricsService] Failed to get aggregated metrics', {
        proxyId,
        userId,
        periodStart,
        periodEnd,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Aggregate proxy metrics for a period
   *
   * @param {string} proxyId - Proxy ID
   * @param {string} userId - User ID
   * @param {string} periodStart - Period start date in YYYY-MM-DD format
   * @param {string} periodEnd - Period end date in YYYY-MM-DD format
   * @returns {Promise<Object>} Aggregated metrics
   */
  async aggregateProxyMetrics(proxyId, userId, periodStart, periodEnd) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Aggregate metrics from daily data
      const aggregateResult = await client.query(
        `SELECT 
           SUM(request_count) as total_request_count,
           SUM(success_count) as total_success_count,
           SUM(error_count) as total_error_count,
           AVG(average_latency_ms) as average_latency_ms,
           MIN(min_latency_ms) as min_latency_ms,
           MAX(max_latency_ms) as max_latency_ms,
           AVG(p95_latency_ms) as p95_latency_ms,
           AVG(p99_latency_ms) as p99_latency_ms,
           SUM(data_transferred_bytes) as total_data_transferred_bytes,
           SUM(data_received_bytes) as total_data_received_bytes,
           MAX(peak_concurrent_connections) as peak_concurrent_connections,
           AVG(average_concurrent_connections) as average_concurrent_connections,
           AVG(uptime_percentage) as average_uptime_percentage
         FROM proxy_metrics_daily 
         WHERE proxy_id = $1 AND date >= $2 AND date <= $3`,
        [proxyId, periodStart, periodEnd],
      );

      const aggregateData = aggregateResult.rows[0];

      // Upsert aggregation record
      const result = await client.query(
        `INSERT INTO proxy_metrics_aggregation 
         (proxy_id, user_id, period_start, period_end, total_request_count, total_success_count, 
          total_error_count, average_latency_ms, min_latency_ms, max_latency_ms, p95_latency_ms, 
          p99_latency_ms, total_data_transferred_bytes, total_data_received_bytes, 
          peak_concurrent_connections, average_concurrent_connections, average_uptime_percentage)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)
         ON CONFLICT (proxy_id, period_start, period_end) 
         DO UPDATE SET 
           total_request_count = $5,
           total_success_count = $6,
           total_error_count = $7,
           average_latency_ms = $8,
           min_latency_ms = $9,
           max_latency_ms = $10,
           p95_latency_ms = $11,
           p99_latency_ms = $12,
           total_data_transferred_bytes = $13,
           total_data_received_bytes = $14,
           peak_concurrent_connections = $15,
           average_concurrent_connections = $16,
           average_uptime_percentage = $17,
           updated_at = NOW()
         RETURNING *`,
        [
          proxyId,
          userId,
          periodStart,
          periodEnd,
          aggregateData.total_request_count || 0,
          aggregateData.total_success_count || 0,
          aggregateData.total_error_count || 0,
          aggregateData.average_latency_ms || 0,
          aggregateData.min_latency_ms || 0,
          aggregateData.max_latency_ms || 0,
          aggregateData.p95_latency_ms || 0,
          aggregateData.p99_latency_ms || 0,
          aggregateData.total_data_transferred_bytes || 0,
          aggregateData.total_data_received_bytes || 0,
          aggregateData.peak_concurrent_connections || 0,
          aggregateData.average_concurrent_connections || 0,
          aggregateData.average_uptime_percentage || 100,
        ],
      );

      await client.query('COMMIT');

      logger.info('[ProxyMetricsService] Proxy metrics aggregated', {
        proxyId,
        userId,
        periodStart,
        periodEnd,
      });

      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[ProxyMetricsService] Failed to aggregate proxy metrics', {
        proxyId,
        userId,
        periodStart,
        periodEnd,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }
}

export default ProxyMetricsService;
