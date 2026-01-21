/**
 * Proxy Usage Service
 *
 * Manages proxy usage tracking for billing and analytics:
 * - Track proxy usage metrics (connections, data transferred)
 * - Implement usage aggregation per user/tier
 * - Create usage reporting endpoints
 *
 * Validates: Requirements 5.9
 * - Implements proxy usage tracking
 * - Tracks connections and data transfer metrics
 * - Aggregates usage per user and tier
 * - Provides usage reporting capabilities
 *
 * @fileoverview Proxy usage tracking and billing service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class ProxyUsageService {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize the proxy usage service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info('[ProxyUsageService] Proxy usage service initialized');
    } catch (error) {
      logger.error(
        '[ProxyUsageService] Failed to initialize proxy usage service',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Record a proxy usage event
   *
   * @param {string} proxyId - Proxy ID
   * @param {string} userId - User ID
   * @param {string} eventType - Event type (connection_start, connection_end, data_transfer, error)
   * @param {Object} eventData - Event data
   * @param {string} eventData.connectionId - Connection ID
   * @param {number} eventData.dataBytes - Data transferred in bytes
   * @param {number} eventData.durationSeconds - Connection duration in seconds
   * @param {string} eventData.errorMessage - Error message if applicable
   * @param {string} eventData.ipAddress - Client IP address
   * @returns {Promise<Object>} Created event
   */
  async recordUsageEvent(proxyId, userId, eventType, eventData = {}) {
    try {
      const validEventTypes = [
        'connection_start',
        'connection_end',
        'data_transfer',
        'error',
      ];

      if (!validEventTypes.includes(eventType)) {
        throw new Error(
          `Invalid event type. Must be one of: ${validEventTypes.join(', ')}`,
        );
      }

      const result = await this.pool.query(
        `INSERT INTO proxy_usage_events 
         (proxy_id, user_id, event_type, connection_id, data_bytes, duration_seconds, error_message, ip_address)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         RETURNING *`,
        [
          proxyId,
          userId,
          eventType,
          eventData.connectionId || null,
          eventData.dataBytes || 0,
          eventData.durationSeconds || null,
          eventData.errorMessage || null,
          eventData.ipAddress || null,
        ],
      );

      logger.debug('[ProxyUsageService] Usage event recorded', {
        proxyId,
        userId,
        eventType,
      });

      return result.rows[0];
    } catch (error) {
      logger.error('[ProxyUsageService] Failed to record usage event', {
        proxyId,
        userId,
        eventType,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get proxy usage metrics for a specific date
   *
   * @param {string} proxyId - Proxy ID
   * @param {string} userId - User ID (for authorization)
   * @param {string} date - Date in YYYY-MM-DD format
   * @returns {Promise<Object>} Usage metrics
   */
  async getProxyUsageMetrics(proxyId, userId, date) {
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
        'SELECT * FROM proxy_usage_metrics WHERE proxy_id = $1 AND date = $2',
        [proxyId, date],
      );

      if (result.rows.length === 0) {
        // Return zero metrics if no data exists
        return {
          proxyId,
          date,
          connectionCount: 0,
          dataTransferredBytes: 0,
          dataReceivedBytes: 0,
          peakConcurrentConnections: 0,
          averageConnectionDurationSeconds: 0,
          errorCount: 0,
          successCount: 0,
        };
      }

      const metrics = result.rows[0];
      return {
        proxyId: metrics.proxy_id,
        date: metrics.date,
        connectionCount: metrics.connection_count,
        dataTransferredBytes: metrics.data_transferred_bytes,
        dataReceivedBytes: metrics.data_received_bytes,
        peakConcurrentConnections: metrics.peak_concurrent_connections,
        averageConnectionDurationSeconds:
          metrics.average_connection_duration_seconds,
        errorCount: metrics.error_count,
        successCount: metrics.success_count,
      };
    } catch (error) {
      logger.error('[ProxyUsageService] Failed to get proxy usage metrics', {
        proxyId,
        userId,
        date,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get proxy usage metrics for a date range
   *
   * @param {string} proxyId - Proxy ID
   * @param {string} userId - User ID (for authorization)
   * @param {string} startDate - Start date in YYYY-MM-DD format
   * @param {string} endDate - End date in YYYY-MM-DD format
   * @returns {Promise<Array>} Usage metrics for each day
   */
  async getProxyUsageMetricsRange(proxyId, userId, startDate, endDate) {
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
        `SELECT * FROM proxy_usage_metrics 
         WHERE proxy_id = $1 AND date >= $2 AND date <= $3
         ORDER BY date ASC`,
        [proxyId, startDate, endDate],
      );

      return result.rows.map((metrics) => ({
        proxyId: metrics.proxy_id,
        date: metrics.date,
        connectionCount: metrics.connection_count,
        dataTransferredBytes: metrics.data_transferred_bytes,
        dataReceivedBytes: metrics.data_received_bytes,
        peakConcurrentConnections: metrics.peak_concurrent_connections,
        averageConnectionDurationSeconds:
          metrics.average_connection_duration_seconds,
        errorCount: metrics.error_count,
        successCount: metrics.success_count,
      }));
    } catch (error) {
      logger.error(
        '[ProxyUsageService] Failed to get proxy usage metrics range',
        {
          proxyId,
          userId,
          startDate,
          endDate,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Get aggregated usage for a user
   *
   * @param {string} userId - User ID
   * @param {string} userTier - User tier (free, premium, enterprise)
   * @param {string} periodStart - Period start date in YYYY-MM-DD format
   * @param {string} periodEnd - Period end date in YYYY-MM-DD format
   * @returns {Promise<Object>} Aggregated usage
   */
  async getUserUsageAggregation(userId, userTier, periodStart, periodEnd) {
    try {
      const result = await this.pool.query(
        `SELECT * FROM proxy_usage_aggregation 
         WHERE user_id = $1 AND period_start = $2 AND period_end = $3`,
        [userId, periodStart, periodEnd],
      );

      if (result.rows.length === 0) {
        // Return zero aggregation if no data exists
        return {
          userId,
          userTier,
          periodStart,
          periodEnd,
          totalConnections: 0,
          totalDataTransferredBytes: 0,
          totalDataReceivedBytes: 0,
          proxyCount: 0,
          peakConcurrentConnections: 0,
          averageConnectionDurationSeconds: 0,
          totalErrorCount: 0,
          totalSuccessCount: 0,
        };
      }

      const aggregation = result.rows[0];
      return {
        userId: aggregation.user_id,
        userTier: aggregation.user_tier,
        periodStart: aggregation.period_start,
        periodEnd: aggregation.period_end,
        totalConnections: aggregation.total_connections,
        totalDataTransferredBytes: aggregation.total_data_transferred_bytes,
        totalDataReceivedBytes: aggregation.total_data_received_bytes,
        proxyCount: aggregation.proxy_count,
        peakConcurrentConnections: aggregation.peak_concurrent_connections,
        averageConnectionDurationSeconds:
          aggregation.average_connection_duration_seconds,
        totalErrorCount: aggregation.total_error_count,
        totalSuccessCount: aggregation.total_success_count,
      };
    } catch (error) {
      logger.error('[ProxyUsageService] Failed to get user usage aggregation', {
        userId,
        userTier,
        periodStart,
        periodEnd,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Aggregate usage metrics for a user and period
   *
   * @param {string} userId - User ID
   * @param {string} userTier - User tier
   * @param {string} periodStart - Period start date in YYYY-MM-DD format
   * @param {string} periodEnd - Period end date in YYYY-MM-DD format
   * @returns {Promise<Object>} Aggregated usage
   */
  async aggregateUserUsage(userId, userTier, periodStart, periodEnd) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Get all proxies for the user
      const proxiesResult = await client.query(
        'SELECT proxy_id FROM proxy_health_status WHERE user_id = $1',
        [userId],
      );

      const proxyIds = proxiesResult.rows.map((row) => row.proxy_id);

      if (proxyIds.length === 0) {
        // No proxies, create zero aggregation
        const result = await client.query(
          `INSERT INTO proxy_usage_aggregation 
           (user_id, user_tier, period_start, period_end, total_connections, total_data_transferred_bytes, 
            total_data_received_bytes, proxy_count, peak_concurrent_connections, average_connection_duration_seconds,
            total_error_count, total_success_count)
           VALUES ($1, $2, $3, $4, 0, 0, 0, 0, 0, 0, 0, 0)
           ON CONFLICT (user_id, period_start, period_end) 
           DO UPDATE SET updated_at = NOW()
           RETURNING *`,
          [userId, userTier, periodStart, periodEnd],
        );

        await client.query('COMMIT');
        return result.rows[0];
      }

      // Aggregate metrics from all proxies for the period
      const aggregateResult = await client.query(
        `SELECT 
           SUM(connection_count) as total_connections,
           SUM(data_transferred_bytes) as total_data_transferred_bytes,
           SUM(data_received_bytes) as total_data_received_bytes,
           MAX(peak_concurrent_connections) as peak_concurrent_connections,
           AVG(average_connection_duration_seconds) as average_connection_duration_seconds,
           SUM(error_count) as total_error_count,
           SUM(success_count) as total_success_count
         FROM proxy_usage_metrics 
         WHERE proxy_id = ANY($1) AND date >= $2 AND date <= $3`,
        [proxyIds, periodStart, periodEnd],
      );

      const aggregateData = aggregateResult.rows[0];

      // Upsert aggregation record
      const result = await client.query(
        `INSERT INTO proxy_usage_aggregation 
         (user_id, user_tier, period_start, period_end, total_connections, total_data_transferred_bytes, 
          total_data_received_bytes, proxy_count, peak_concurrent_connections, average_connection_duration_seconds,
          total_error_count, total_success_count)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
         ON CONFLICT (user_id, period_start, period_end) 
         DO UPDATE SET 
           total_connections = $5,
           total_data_transferred_bytes = $6,
           total_data_received_bytes = $7,
           proxy_count = $8,
           peak_concurrent_connections = $9,
           average_connection_duration_seconds = $10,
           total_error_count = $11,
           total_success_count = $12,
           updated_at = NOW()
         RETURNING *`,
        [
          userId,
          userTier,
          periodStart,
          periodEnd,
          aggregateData.total_connections || 0,
          aggregateData.total_data_transferred_bytes || 0,
          aggregateData.total_data_received_bytes || 0,
          proxyIds.length,
          aggregateData.peak_concurrent_connections || 0,
          Math.round(aggregateData.average_connection_duration_seconds || 0),
          aggregateData.total_error_count || 0,
          aggregateData.total_success_count || 0,
        ],
      );

      await client.query('COMMIT');

      logger.info('[ProxyUsageService] User usage aggregated', {
        userId,
        userTier,
        periodStart,
        periodEnd,
      });

      return result.rows[0];
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[ProxyUsageService] Failed to aggregate user usage', {
        userId,
        userTier,
        periodStart,
        periodEnd,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get usage report for a user
   *
   * @param {string} userId - User ID
   * @param {Object} options - Report options
   * @param {string} options.startDate - Start date in YYYY-MM-DD format
   * @param {string} options.endDate - End date in YYYY-MM-DD format
   * @param {string} options.groupBy - Group by 'day' or 'proxy'
   * @returns {Promise<Object>} Usage report
   */
  async getUserUsageReport(userId, options = {}) {
    try {
      const { startDate, endDate, groupBy = 'day' } = options;

      if (!startDate || !endDate) {
        throw new Error('startDate and endDate are required');
      }

      if (groupBy === 'day') {
        // Group by day
        const result = await this.pool.query(
          `SELECT 
             date,
             SUM(connection_count) as total_connections,
             SUM(data_transferred_bytes) as total_data_transferred_bytes,
             SUM(data_received_bytes) as total_data_received_bytes,
             MAX(peak_concurrent_connections) as peak_concurrent_connections,
             AVG(average_connection_duration_seconds) as average_connection_duration_seconds,
             SUM(error_count) as total_error_count,
             SUM(success_count) as total_success_count
           FROM proxy_usage_metrics 
           WHERE user_id = $1 AND date >= $2 AND date <= $3
           GROUP BY date
           ORDER BY date ASC`,
          [userId, startDate, endDate],
        );

        return {
          userId,
          startDate,
          endDate,
          groupBy: 'day',
          data: result.rows.map((row) => ({
            date: row.date,
            totalConnections: row.total_connections,
            totalDataTransferredBytes: row.total_data_transferred_bytes,
            totalDataReceivedBytes: row.total_data_received_bytes,
            peakConcurrentConnections: row.peak_concurrent_connections,
            averageConnectionDurationSeconds:
              row.average_connection_duration_seconds,
            totalErrorCount: row.total_error_count,
            totalSuccessCount: row.total_success_count,
          })),
        };
      } else if (groupBy === 'proxy') {
        // Group by proxy
        const result = await this.pool.query(
          `SELECT 
             proxy_id,
             SUM(connection_count) as total_connections,
             SUM(data_transferred_bytes) as total_data_transferred_bytes,
             SUM(data_received_bytes) as total_data_received_bytes,
             MAX(peak_concurrent_connections) as peak_concurrent_connections,
             AVG(average_connection_duration_seconds) as average_connection_duration_seconds,
             SUM(error_count) as total_error_count,
             SUM(success_count) as total_success_count
           FROM proxy_usage_metrics 
           WHERE user_id = $1 AND date >= $2 AND date <= $3
           GROUP BY proxy_id
           ORDER BY total_connections DESC`,
          [userId, startDate, endDate],
        );

        return {
          userId,
          startDate,
          endDate,
          groupBy: 'proxy',
          data: result.rows.map((row) => ({
            proxyId: row.proxy_id,
            totalConnections: row.total_connections,
            totalDataTransferredBytes: row.total_data_transferred_bytes,
            totalDataReceivedBytes: row.total_data_received_bytes,
            peakConcurrentConnections: row.peak_concurrent_connections,
            averageConnectionDurationSeconds:
              row.average_connection_duration_seconds,
            totalErrorCount: row.total_error_count,
            totalSuccessCount: row.total_success_count,
          })),
        };
      } else {
        throw new Error('groupBy must be either "day" or "proxy"');
      }
    } catch (error) {
      logger.error('[ProxyUsageService] Failed to get usage report', {
        userId,
        options,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get billing summary for a user
   *
   * @param {string} userId - User ID
   * @param {string} userTier - User tier
   * @param {string} periodStart - Period start date in YYYY-MM-DD format
   * @param {string} periodEnd - Period end date in YYYY-MM-DD format
   * @returns {Promise<Object>} Billing summary
   */
  async getBillingSummary(userId, userTier, periodStart, periodEnd) {
    try {
      // Get aggregated usage
      const aggregation = await this.getUserUsageAggregation(
        userId,
        userTier,
        periodStart,
        periodEnd,
      );

      // Calculate billing based on tier
      let billingAmount = 0;
      let breakdown = {};

      if (userTier === 'free') {
        // Free tier: no charges
        billingAmount = 0;
        breakdown = {
          baseCharge: 0,
          dataTransferCharge: 0,
          connectionCharge: 0,
        };
      } else if (userTier === 'premium') {
        // Premium tier: $10/month + $0.01 per GB transferred
        const dataTransferGB =
          (aggregation.totalDataTransferredBytes +
            aggregation.totalDataReceivedBytes) /
          (1024 * 1024 * 1024);
        billingAmount = 10 + dataTransferGB * 0.01;
        breakdown = {
          baseCharge: 10,
          dataTransferCharge: dataTransferGB * 0.01,
          connectionCharge: 0,
        };
      } else if (userTier === 'enterprise') {
        // Enterprise tier: custom pricing (placeholder)
        billingAmount = 0; // Custom pricing
        breakdown = {
          baseCharge: 0,
          dataTransferCharge: 0,
          connectionCharge: 0,
          note: 'Custom pricing - contact sales',
        };
      }

      return {
        userId,
        userTier,
        periodStart,
        periodEnd,
        usage: aggregation,
        billing: {
          amount: billingAmount,
          currency: 'USD',
          breakdown,
        },
      };
    } catch (error) {
      logger.error('[ProxyUsageService] Failed to get billing summary', {
        userId,
        userTier,
        periodStart,
        periodEnd,
        error: error.message,
      });
      throw error;
    }
  }
}

export default ProxyUsageService;
