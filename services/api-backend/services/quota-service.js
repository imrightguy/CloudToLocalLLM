/**
 * Quota Management Service
 *
 * Manages resource quotas for users:
 * - Create quota tracking mechanism
 * - Implement quota enforcement
 * - Add quota reporting endpoints
 *
 * Validates: Requirements 6.6
 * - Implements quota management for resource usage
 * - Tracks quota usage per user
 * - Enforces quota limits
 * - Provides quota reporting
 *
 * @fileoverview Quota management service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class QuotaService {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize the quota service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info('[QuotaService] Quota service initialized');
    } catch (error) {
      logger.error('[QuotaService] Failed to initialize quota service', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get quota definition for a tier and resource type
   *
   * @param {string} tier - User tier (free, premium, enterprise)
   * @param {string} resourceType - Resource type (api_requests, data_transfer, etc.)
   * @returns {Promise<Object>} Quota definition
   */
  async getQuotaDefinition(tier, resourceType) {
    try {
      const result = await this.pool.query(
        `SELECT * FROM quota_definitions 
         WHERE tier = $1 AND resource_type = $2`,
        [tier, resourceType],
      );

      if (result.rows.length === 0) {
        throw new Error(
          `Quota definition not found for tier ${tier} and resource ${resourceType}`,
        );
      }

      const row = result.rows[0];
      return {
        id: row.id,
        tier: row.tier,
        resourceType: row.resource_type,
        limitValue: row.limit_value,
        limitUnit: row.limit_unit,
        resetPeriod: row.reset_period,
      };
    } catch (error) {
      logger.error('[QuotaService] Failed to get quota definition', {
        tier,
        resourceType,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Initialize user quotas for a new user
   *
   * @param {string} userId - User ID
   * @param {string} userTier - User tier
   * @returns {Promise<Array>} Created quotas
   */
  async initializeUserQuotas(userId, userTier) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Get all quota definitions for the tier
      const definitionsResult = await client.query(
        'SELECT * FROM quota_definitions WHERE tier = $1',
        [userTier],
      );

      if (definitionsResult.rows.length === 0) {
        throw new Error(`No quota definitions found for tier ${userTier}`);
      }

      const quotas = [];
      const today = new Date();
      const periodStart = new Date(today.getFullYear(), today.getMonth(), 1);
      const periodEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);

      for (const definition of definitionsResult.rows) {
        const result = await client.query(
          `INSERT INTO user_quotas 
           (user_id, resource_type, limit_value, current_usage, reset_period, period_start, period_end)
           VALUES ($1, $2, $3, 0, $4, $5, $6)
           ON CONFLICT (user_id, resource_type, period_start, period_end) DO NOTHING
           RETURNING *`,
          [
            userId,
            definition.resource_type,
            definition.limit_value,
            definition.reset_period,
            periodStart.toISOString().split('T')[0],
            periodEnd.toISOString().split('T')[0],
          ],
        );

        if (result.rows.length > 0) {
          quotas.push(result.rows[0]);
        }
      }

      await client.query('COMMIT');

      logger.info('[QuotaService] User quotas initialized', {
        userId,
        userTier,
        quotaCount: quotas.length,
      });

      return quotas;
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[QuotaService] Failed to initialize user quotas', {
        userId,
        userTier,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get current quota usage for a user
   *
   * @param {string} userId - User ID
   * @param {string} resourceType - Resource type
   * @returns {Promise<Object>} Current quota usage
   */
  async getUserQuotaUsage(userId, resourceType) {
    try {
      const today = new Date();
      const periodStart = new Date(today.getFullYear(), today.getMonth(), 1);
      const periodEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);

      const result = await this.pool.query(
        `SELECT * FROM user_quotas 
         WHERE user_id = $1 AND resource_type = $2 
         AND period_start = $3 AND period_end = $4`,
        [
          userId,
          resourceType,
          periodStart.toISOString().split('T')[0],
          periodEnd.toISOString().split('T')[0],
        ],
      );

      if (result.rows.length === 0) {
        throw new Error(
          `Quota not found for user ${userId} and resource ${resourceType}`,
        );
      }

      const row = result.rows[0];
      const percentageUsed = (row.current_usage / row.limit_value) * 100;

      return {
        id: row.id,
        userId: row.user_id,
        resourceType: row.resource_type,
        limitValue: row.limit_value,
        currentUsage: row.current_usage,
        percentageUsed: Math.round(percentageUsed * 100) / 100,
        isExceeded: row.is_exceeded,
        exceededAt: row.exceeded_at,
        periodStart: row.period_start,
        periodEnd: row.period_end,
      };
    } catch (error) {
      logger.error('[QuotaService] Failed to get user quota usage', {
        userId,
        resourceType,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Check if user has exceeded quota
   *
   * @param {string} userId - User ID
   * @param {string} resourceType - Resource type
   * @returns {Promise<boolean>} True if quota exceeded
   */
  async isQuotaExceeded(userId, resourceType) {
    try {
      const quota = await this.getUserQuotaUsage(userId, resourceType);
      return quota.isExceeded;
    } catch (error) {
      logger.error('[QuotaService] Failed to check quota exceeded', {
        userId,
        resourceType,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Record quota usage
   *
   * @param {string} userId - User ID
   * @param {string} resourceType - Resource type
   * @param {number} usageDelta - Amount of resource used
   * @param {Object} details - Additional details
   * @returns {Promise<Object>} Updated quota
   */
  async recordQuotaUsage(userId, resourceType, usageDelta, details = {}) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Get current quota
      const today = new Date();
      const periodStart = new Date(today.getFullYear(), today.getMonth(), 1);
      const periodEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);

      const quotaResult = await client.query(
        `SELECT * FROM user_quotas 
         WHERE user_id = $1 AND resource_type = $2 
         AND period_start = $3 AND period_end = $4
         FOR UPDATE`,
        [
          userId,
          resourceType,
          periodStart.toISOString().split('T')[0],
          periodEnd.toISOString().split('T')[0],
        ],
      );

      if (quotaResult.rows.length === 0) {
        throw new Error(
          `Quota not found for user ${userId} and resource ${resourceType}`,
        );
      }

      const quota = quotaResult.rows[0];
      const newUsage = quota.current_usage + usageDelta;
      const isExceeded = newUsage > quota.limit_value;
      const percentageUsed = (newUsage / quota.limit_value) * 100;

      // Update quota
      const updateResult = await client.query(
        `UPDATE user_quotas 
         SET current_usage = $1, is_exceeded = $2, exceeded_at = CASE WHEN $2 THEN NOW() ELSE exceeded_at END, updated_at = NOW()
         WHERE id = $3
         RETURNING *`,
        [newUsage, isExceeded, quota.id],
      );

      // Record event
      await client.query(
        `INSERT INTO quota_events 
         (user_id, resource_type, event_type, usage_delta, total_usage, limit_value, percentage_used, details)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          userId,
          resourceType,
          isExceeded ? 'quota_exceeded' : 'usage_recorded',
          usageDelta,
          newUsage,
          quota.limit_value,
          percentageUsed,
          JSON.stringify(details),
        ],
      );

      await client.query('COMMIT');

      const updatedQuota = updateResult.rows[0];
      logger.info('[QuotaService] Quota usage recorded', {
        userId,
        resourceType,
        usageDelta,
        newUsage,
        isExceeded,
      });

      return {
        id: updatedQuota.id,
        userId: updatedQuota.user_id,
        resourceType: updatedQuota.resource_type,
        limitValue: updatedQuota.limit_value,
        currentUsage: updatedQuota.current_usage,
        percentageUsed: Math.round(percentageUsed * 100) / 100,
        isExceeded: updatedQuota.is_exceeded,
        exceededAt: updatedQuota.exceeded_at,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[QuotaService] Failed to record quota usage', {
        userId,
        resourceType,
        usageDelta,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get all quotas for a user
   *
   * @param {string} userId - User ID
   * @returns {Promise<Array>} All quotas for user
   */
  async getUserAllQuotas(userId) {
    try {
      const today = new Date();
      const periodStart = new Date(today.getFullYear(), today.getMonth(), 1);
      const periodEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);

      const result = await this.pool.query(
        `SELECT * FROM user_quotas 
         WHERE user_id = $1 
         AND period_start = $2 AND period_end = $3
         ORDER BY resource_type ASC`,
        [
          userId,
          periodStart.toISOString().split('T')[0],
          periodEnd.toISOString().split('T')[0],
        ],
      );

      return result.rows.map((row) => {
        const percentageUsed = (row.current_usage / row.limit_value) * 100;
        return {
          id: row.id,
          userId: row.user_id,
          resourceType: row.resource_type,
          limitValue: row.limit_value,
          currentUsage: row.current_usage,
          percentageUsed: Math.round(percentageUsed * 100) / 100,
          isExceeded: row.is_exceeded,
          exceededAt: row.exceeded_at,
          periodStart: row.period_start,
          periodEnd: row.period_end,
        };
      });
    } catch (error) {
      logger.error('[QuotaService] Failed to get user all quotas', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get quota events for a user
   *
   * @param {string} userId - User ID
   * @param {Object} options - Query options
   * @param {string} options.resourceType - Filter by resource type
   * @param {string} options.eventType - Filter by event type
   * @param {number} options.limit - Limit results
   * @param {number} options.offset - Offset results
   * @returns {Promise<Array>} Quota events
   */
  async getQuotaEvents(userId, options = {}) {
    try {
      const { resourceType, eventType, limit = 100, offset = 0 } = options;

      let query = 'SELECT * FROM quota_events WHERE user_id = $1';
      const params = [userId];
      let paramIndex = 2;

      if (resourceType) {
        query += ` AND resource_type = $${paramIndex}`;
        params.push(resourceType);
        paramIndex++;
      }

      if (eventType) {
        query += ` AND event_type = $${paramIndex}`;
        params.push(eventType);
        paramIndex++;
      }

      query += ` ORDER BY created_at DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
      params.push(limit, offset);

      const result = await this.pool.query(query, params);

      return result.rows.map((row) => ({
        id: row.id,
        userId: row.user_id,
        resourceType: row.resource_type,
        eventType: row.event_type,
        usageDelta: row.usage_delta,
        totalUsage: row.total_usage,
        limitValue: row.limit_value,
        percentageUsed: row.percentage_used,
        details: row.details,
        createdAt: row.created_at,
      }));
    } catch (error) {
      logger.error('[QuotaService] Failed to get quota events', {
        userId,
        options,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Reset quota for a user (for testing or manual reset)
   *
   * @param {string} userId - User ID
   * @param {string} resourceType - Resource type
   * @returns {Promise<Object>} Reset quota
   */
  async resetQuota(userId, resourceType) {
    try {
      const today = new Date();
      const periodStart = new Date(today.getFullYear(), today.getMonth(), 1);
      const periodEnd = new Date(today.getFullYear(), today.getMonth() + 1, 0);

      const result = await this.pool.query(
        `UPDATE user_quotas 
         SET current_usage = 0, is_exceeded = FALSE, exceeded_at = NULL, updated_at = NOW()
         WHERE user_id = $1 AND resource_type = $2 
         AND period_start = $3 AND period_end = $4
         RETURNING *`,
        [
          userId,
          resourceType,
          periodStart.toISOString().split('T')[0],
          periodEnd.toISOString().split('T')[0],
        ],
      );

      if (result.rows.length === 0) {
        throw new Error(
          `Quota not found for user ${userId} and resource ${resourceType}`,
        );
      }

      logger.info('[QuotaService] Quota reset', {
        userId,
        resourceType,
      });

      return result.rows[0];
    } catch (error) {
      logger.error('[QuotaService] Failed to reset quota', {
        userId,
        resourceType,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get quota summary for a user
   *
   * @param {string} userId - User ID
   * @returns {Promise<Object>} Quota summary
   */
  async getQuotaSummary(userId) {
    try {
      const quotas = await this.getUserAllQuotas(userId);

      const summary = {
        userId,
        totalQuotas: quotas.length,
        quotasExceeded: quotas.filter((q) => q.isExceeded).length,
        quotasNearLimit: quotas.filter((q) => q.percentageUsed >= 80).length,
        quotas,
      };

      return summary;
    } catch (error) {
      logger.error('[QuotaService] Failed to get quota summary', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }
}
