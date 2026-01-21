import { v4 as uuidv4 } from 'uuid';
import { TunnelLogger } from '../utils/logger.js';
import { getPool } from '../database/db-pool.js';

/**
 * Rate limit violation types
 */
export const VIOLATION_TYPES = {
  WINDOW_LIMIT_EXCEEDED: 'window_limit_exceeded',
  BURST_LIMIT_EXCEEDED: 'burst_limit_exceeded',
  CONCURRENT_LIMIT_EXCEEDED: 'concurrent_limit_exceeded',
};

/**
 * @fileoverview Rate Limit Violations Service
 * Handles logging, tracking, and analysis of rate limit violations
 */
export class RateLimitViolationsService {
  constructor() {
    this.logger = new TunnelLogger('rate-limit-violations-service');
    this.pool = getPool();
  }

  /**
   * Log a rate limit violation
   * @param {Object} violation - Violation details
   * @param {string} violation.userId - User ID
   * @param {string} violation.violationType - Type of violation
   * @param {string} violation.endpoint - API endpoint
   * @param {string} violation.method - HTTP method
   * @param {string} violation.ipAddress - Client IP address
   * @param {string} violation.userAgent - User agent string
   * @param {Object} violation.context - Additional context
   * @returns {Promise<Object>} Logged violation
   */
  async logViolation(violation) {
    const {
      userId,
      violationType,
      endpoint,
      method,
      ipAddress,
      userAgent,
      context = {},
    } = violation;

    try {
      const violationId = uuidv4();
      const now = new Date();

      const query = `
        INSERT INTO rate_limit_violations (
          id,
          user_id,
          violation_type,
          endpoint,
          method,
          ip_address,
          user_agent,
          violation_context,
          timestamp,
          created_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
        RETURNING *;
      `;

      const result = await this.pool.query(query, [
        violationId,
        userId || null,
        violationType,
        endpoint,
        method,
        ipAddress,
        userAgent,
        JSON.stringify(context),
        now,
        now,
      ]);

      this.logger.info('Rate limit violation logged', {
        violationId,
        userId,
        violationType,
        endpoint,
        ipAddress,
      });

      return this.formatViolation(result.rows[0]);
    } catch (error) {
      this.logger.error('Failed to log rate limit violation', {
        error: error.message,
        userId,
        violationType,
      });
      throw error;
    }
  }

  /**
   * Get violations for a user
   * @param {string} userId - User ID
   * @param {Object} options - Query options
   * @param {number} options.limit - Number of results
   * @param {number} options.offset - Offset for pagination
   * @param {string} options.startTime - Start time for filtering
   * @param {string} options.endTime - End time for filtering
   * @returns {Promise<Array>} User violations
   */
  async getUserViolations(userId, options = {}) {
    const {
      limit = 100,
      offset = 0,
      startTime = null,
      endTime = null,
    } = options;

    try {
      let query = `
        SELECT *
        FROM rate_limit_violations
        WHERE user_id = $1
      `;

      const params = [userId];
      let paramIndex = 2;

      if (startTime) {
        query += ` AND timestamp >= $${paramIndex}`;
        params.push(new Date(startTime));
        paramIndex++;
      }

      if (endTime) {
        query += ` AND timestamp <= $${paramIndex}`;
        params.push(new Date(endTime));
        paramIndex++;
      }

      query += ` ORDER BY timestamp DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
      params.push(limit, offset);

      const result = await this.pool.query(query, params);

      return result.rows.map((row) => this.formatViolation(row));
    } catch (error) {
      this.logger.error('Failed to get user violations', {
        error: error.message,
        userId,
      });
      throw error;
    }
  }

  /**
   * Get violations by IP address
   * @param {string} ipAddress - IP address
   * @param {Object} options - Query options
   * @param {number} options.limit - Number of results
   * @param {number} options.offset - Offset for pagination
   * @param {string} options.startTime - Start time for filtering
   * @param {string} options.endTime - End time for filtering
   * @returns {Promise<Array>} IP violations
   */
  async getIpViolations(ipAddress, options = {}) {
    const {
      limit = 100,
      offset = 0,
      startTime = null,
      endTime = null,
    } = options;

    try {
      let query = `
        SELECT *
        FROM rate_limit_violations
        WHERE ip_address = $1
      `;

      const params = [ipAddress];
      let paramIndex = 2;

      if (startTime) {
        query += ` AND timestamp >= $${paramIndex}`;
        params.push(new Date(startTime));
        paramIndex++;
      }

      if (endTime) {
        query += ` AND timestamp <= $${paramIndex}`;
        params.push(new Date(endTime));
        paramIndex++;
      }

      query += ` ORDER BY timestamp DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
      params.push(limit, offset);

      const result = await this.pool.query(query, params);

      return result.rows.map((row) => this.formatViolation(row));
    } catch (error) {
      this.logger.error('Failed to get IP violations', {
        error: error.message,
        ipAddress,
      });
      throw error;
    }
  }

  /**
   * Get violation statistics for a user
   * @param {string} userId - User ID
   * @param {Object} options - Query options
   * @param {string} options.startTime - Start time for filtering
   * @param {string} options.endTime - End time for filtering
   * @returns {Promise<Object>} User violation statistics
   */
  async getUserViolationStats(userId, options = {}) {
    const { startTime = null, endTime = null } = options;

    try {
      let query = `
        SELECT
          COUNT(*) as total_violations,
          COUNT(DISTINCT violation_type) as violation_types_count,
          COUNT(DISTINCT ip_address) as unique_ips,
          COUNT(DISTINCT endpoint) as unique_endpoints,
          MIN(timestamp) as first_violation,
          MAX(timestamp) as last_violation,
          jsonb_object_agg(violation_type, COUNT(*)) as violations_by_type
        FROM rate_limit_violations
        WHERE user_id = $1
      `;

      const params = [userId];
      let paramIndex = 2;

      if (startTime) {
        query += ` AND timestamp >= $${paramIndex}`;
        params.push(new Date(startTime));
        paramIndex++;
      }

      if (endTime) {
        query += ` AND timestamp <= $${paramIndex}`;
        params.push(new Date(endTime));
        paramIndex++;
      }

      query += ' GROUP BY user_id';

      const result = await this.pool.query(query, params);

      if (result.rows.length === 0) {
        return {
          userId,
          totalViolations: 0,
          violationTypesCount: 0,
          uniqueIps: 0,
          uniqueEndpoints: 0,
          firstViolation: null,
          lastViolation: null,
          violationsByType: {},
        };
      }

      const row = result.rows[0];
      return {
        userId,
        totalViolations: parseInt(row.total_violations, 10),
        violationTypesCount: parseInt(row.violation_types_count, 10),
        uniqueIps: parseInt(row.unique_ips, 10),
        uniqueEndpoints: parseInt(row.unique_endpoints, 10),
        firstViolation: row.first_violation,
        lastViolation: row.last_violation,
        violationsByType: row.violations_by_type || {},
      };
    } catch (error) {
      this.logger.error('Failed to get user violation stats', {
        error: error.message,
        userId,
      });
      throw error;
    }
  }

  /**
   * Get violation statistics for an IP address
   * @param {string} ipAddress - IP address
   * @param {Object} options - Query options
   * @param {string} options.startTime - Start time for filtering
   * @param {string} options.endTime - End time for filtering
   * @returns {Promise<Object>} IP violation statistics
   */
  async getIpViolationStats(ipAddress, options = {}) {
    const { startTime = null, endTime = null } = options;

    try {
      let query = `
        SELECT
          COUNT(*) as total_violations,
          COUNT(DISTINCT violation_type) as violation_types_count,
          COUNT(DISTINCT user_id) as unique_users,
          COUNT(DISTINCT endpoint) as unique_endpoints,
          MIN(timestamp) as first_violation,
          MAX(timestamp) as last_violation,
          jsonb_object_agg(violation_type, COUNT(*)) as violations_by_type
        FROM rate_limit_violations
        WHERE ip_address = $1
      `;

      const params = [ipAddress];
      let paramIndex = 2;

      if (startTime) {
        query += ` AND timestamp >= $${paramIndex}`;
        params.push(new Date(startTime));
        paramIndex++;
      }

      if (endTime) {
        query += ` AND timestamp <= $${paramIndex}`;
        params.push(new Date(endTime));
        paramIndex++;
      }

      query += ' GROUP BY ip_address';

      const result = await this.pool.query(query, params);

      if (result.rows.length === 0) {
        return {
          ipAddress,
          totalViolations: 0,
          violationTypesCount: 0,
          uniqueUsers: 0,
          uniqueEndpoints: 0,
          firstViolation: null,
          lastViolation: null,
          violationsByType: {},
        };
      }

      const row = result.rows[0];
      return {
        ipAddress,
        totalViolations: parseInt(row.total_violations, 10),
        violationTypesCount: parseInt(row.violation_types_count, 10),
        uniqueUsers: parseInt(row.unique_users, 10),
        uniqueEndpoints: parseInt(row.unique_endpoints, 10),
        firstViolation: row.first_violation,
        lastViolation: row.last_violation,
        violationsByType: row.violations_by_type || {},
      };
    } catch (error) {
      this.logger.error('Failed to get IP violation stats', {
        error: error.message,
        ipAddress,
      });
      throw error;
    }
  }

  /**
   * Get top violators
   * @param {Object} options - Query options
   * @param {number} options.limit - Number of results
   * @param {string} options.startTime - Start time for filtering
   * @param {string} options.endTime - End time for filtering
   * @returns {Promise<Array>} Top violators
   */
  async getTopViolators(options = {}) {
    const { limit = 10, startTime = null, endTime = null } = options;

    try {
      let query = `
        SELECT
          user_id,
          COUNT(*) as violation_count,
          COUNT(DISTINCT violation_type) as violation_types,
          COUNT(DISTINCT ip_address) as unique_ips,
          MIN(timestamp) as first_violation,
          MAX(timestamp) as last_violation
        FROM rate_limit_violations
        WHERE user_id IS NOT NULL
      `;

      const params = [];
      let paramIndex = 1;

      if (startTime) {
        query += ` AND timestamp >= $${paramIndex}`;
        params.push(new Date(startTime));
        paramIndex++;
      }

      if (endTime) {
        query += ` AND timestamp <= $${paramIndex}`;
        params.push(new Date(endTime));
        paramIndex++;
      }

      query += `
        GROUP BY user_id
        ORDER BY violation_count DESC
        LIMIT $${paramIndex}
      `;
      params.push(limit);

      const result = await this.pool.query(query, params);

      return result.rows.map((row) => ({
        userId: row.user_id,
        violationCount: parseInt(row.violation_count, 10),
        violationTypes: parseInt(row.violation_types, 10),
        uniqueIps: parseInt(row.unique_ips, 10),
        firstViolation: row.first_violation,
        lastViolation: row.last_violation,
      }));
    } catch (error) {
      this.logger.error('Failed to get top violators', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get top violating IPs
   * @param {Object} options - Query options
   * @param {number} options.limit - Number of results
   * @param {string} options.startTime - Start time for filtering
   * @param {string} options.endTime - End time for filtering
   * @returns {Promise<Array>} Top violating IPs
   */
  async getTopViolatingIps(options = {}) {
    const { limit = 10, startTime = null, endTime = null } = options;

    try {
      let query = `
        SELECT
          ip_address,
          COUNT(*) as violation_count,
          COUNT(DISTINCT violation_type) as violation_types,
          COUNT(DISTINCT user_id) as unique_users,
          MIN(timestamp) as first_violation,
          MAX(timestamp) as last_violation
        FROM rate_limit_violations
        WHERE ip_address IS NOT NULL
      `;

      const params = [];
      let paramIndex = 1;

      if (startTime) {
        query += ` AND timestamp >= $${paramIndex}`;
        params.push(new Date(startTime));
        paramIndex++;
      }

      if (endTime) {
        query += ` AND timestamp <= $${paramIndex}`;
        params.push(new Date(endTime));
        paramIndex++;
      }

      query += `
        GROUP BY ip_address
        ORDER BY violation_count DESC
        LIMIT $${paramIndex}
      `;
      params.push(limit);

      const result = await this.pool.query(query, params);

      return result.rows.map((row) => ({
        ipAddress: row.ip_address,
        violationCount: parseInt(row.violation_count, 10),
        violationTypes: parseInt(row.violation_types, 10),
        uniqueUsers: parseInt(row.unique_users, 10),
        firstViolation: row.first_violation,
        lastViolation: row.last_violation,
      }));
    } catch (error) {
      this.logger.error('Failed to get top violating IPs', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get violations by endpoint
   * @param {string} endpoint - API endpoint
   * @param {Object} options - Query options
   * @param {string} options.startTime - Start time for filtering
   * @param {string} options.endTime - End time for filtering
   * @returns {Promise<Object>} Endpoint violation statistics
   */
  async getEndpointViolations(endpoint, options = {}) {
    const { startTime = null, endTime = null } = options;

    try {
      let query = `
        SELECT
          COUNT(*) as violation_count,
          COUNT(DISTINCT user_id) as unique_users,
          COUNT(DISTINCT ip_address) as unique_ips,
          COUNT(DISTINCT violation_type) as violation_types,
          MIN(timestamp) as first_violation,
          MAX(timestamp) as last_violation,
          jsonb_object_agg(violation_type, COUNT(*)) as violations_by_type
        FROM rate_limit_violations
        WHERE endpoint = $1
      `;

      const params = [endpoint];
      let paramIndex = 2;

      if (startTime) {
        query += ` AND timestamp >= $${paramIndex}`;
        params.push(new Date(startTime));
        paramIndex++;
      }

      if (endTime) {
        query += ` AND timestamp <= $${paramIndex}`;
        params.push(new Date(endTime));
        paramIndex++;
      }

      query += ' GROUP BY endpoint';

      const result = await this.pool.query(query, params);

      if (result.rows.length === 0) {
        return {
          endpoint,
          violationCount: 0,
          uniqueUsers: 0,
          uniqueIps: 0,
          violationTypes: 0,
          firstViolation: null,
          lastViolation: null,
          violationsByType: {},
        };
      }

      const row = result.rows[0];
      return {
        endpoint,
        violationCount: parseInt(row.violation_count, 10),
        uniqueUsers: parseInt(row.unique_users, 10),
        uniqueIps: parseInt(row.unique_ips, 10),
        violationTypes: parseInt(row.violation_types, 10),
        firstViolation: row.first_violation,
        lastViolation: row.last_violation,
        violationsByType: row.violations_by_type || {},
      };
    } catch (error) {
      this.logger.error('Failed to get endpoint violations', {
        error: error.message,
        endpoint,
      });
      throw error;
    }
  }

  /**
   * Format violation for response
   * @param {Object} row - Database row
   * @returns {Object} Formatted violation
   */
  formatViolation(row) {
    return {
      id: row.id,
      userId: row.user_id,
      violationType: row.violation_type,
      endpoint: row.endpoint,
      method: row.method,
      ipAddress: row.ip_address,
      userAgent: row.user_agent,
      context: row.violation_context ? JSON.parse(row.violation_context) : {},
      timestamp: row.timestamp,
      createdAt: row.created_at,
    };
  }
}

export default RateLimitViolationsService;
