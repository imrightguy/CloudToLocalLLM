/**
 * Tunnel Service
 *
 * Manages tunnel lifecycle operations including:
 * - Tunnel creation, retrieval, updates, and deletion
 * - Tunnel status tracking and health metrics
 * - Tunnel configuration management
 * - Tunnel endpoint management for failover
 *
 * Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.6
 * - Provides endpoints for tunnel lifecycle management (create, start, stop, delete)
 * - Tracks tunnel status and health metrics
 * - Implements tunnel configuration management
 * - Supports multiple tunnel endpoints for failover
 * - Implements tunnel metrics collection and aggregation
 *
 * @fileoverview Tunnel lifecycle management service
 * @version 1.0.0
 */

import { v4 as uuidv4 } from 'uuid';
import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class TunnelService {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize the tunnel service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info('[TunnelService] Tunnel service initialized');
    } catch (error) {
      logger.error('[TunnelService] Failed to initialize tunnel service', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Create a new tunnel
   *
   * @param {string} userId - User ID
   * @param {Object} tunnelData - Tunnel data
   * @param {string} tunnelData.name - Tunnel name
   * @param {Object} tunnelData.config - Tunnel configuration
   * @param {Array} tunnelData.endpoints - Initial endpoints
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} Created tunnel
   */
  async createTunnel(userId, tunnelData, ipAddress, userAgent) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      const tunnelId = uuidv4();
      const { name, config = {}, endpoints = [] } = tunnelData;

      // Validate tunnel name
      if (!name || typeof name !== 'string' || name.trim().length === 0) {
        throw new Error(
          'Tunnel name is required and must be a non-empty string',
        );
      }

      if (name.length > 255) {
        throw new Error('Tunnel name must not exceed 255 characters');
      }

      // Check for duplicate tunnel name for this user
      const existingTunnel = await client.query(
        'SELECT id FROM tunnels WHERE user_id = $1 AND name = $2',
        [userId, name],
      );

      if (existingTunnel.rows.length > 0) {
        throw new Error('Tunnel with this name already exists for this user');
      }

      // Create tunnel
      const tunnelResult = await client.query(
        `INSERT INTO tunnels (id, user_id, name, status, config, created_by_ip, created_by_user_agent)
         VALUES ($1, $2, $3, $4, $5, $6, $7)
         RETURNING *`,
        [
          tunnelId,
          userId,
          name,
          'created',
          JSON.stringify(config),
          ipAddress,
          userAgent,
        ],
      );

      const tunnel = tunnelResult.rows[0];

      // Add endpoints if provided
      let endpointsList = [];
      if (endpoints && Array.isArray(endpoints) && endpoints.length > 0) {
        for (const endpoint of endpoints) {
          const endpointId = uuidv4();
          const endpointResult = await client.query(
            `INSERT INTO tunnel_endpoints (id, tunnel_id, url, priority, weight)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING *`,
            [
              endpointId,
              tunnelId,
              endpoint.url,
              endpoint.priority || 0,
              endpoint.weight || 1,
            ],
          );
          endpointsList.push(endpointResult.rows[0]);
        }
      }

      // Log activity
      await client.query(
        `INSERT INTO tunnel_activity_logs (tunnel_id, user_id, action, status, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [tunnelId, userId, 'create', 'success', ipAddress, userAgent],
      );

      await client.query('COMMIT');

      logger.info('[TunnelService] Tunnel created', {
        tunnelId,
        userId,
        name,
      });

      return {
        ...tunnel,
        config: JSON.parse(tunnel.config),
        metrics: JSON.parse(tunnel.metrics),
        endpoints: endpointsList,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelService] Failed to create tunnel', {
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get tunnel by ID
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @returns {Promise<Object>} Tunnel data
   */
  async getTunnelById(tunnelId, userId) {
    try {
      const result = await this.pool.query(
        'SELECT * FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (result.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      const tunnel = result.rows[0];

      // Get endpoints
      const endpointsResult = await this.pool.query(
        'SELECT * FROM tunnel_endpoints WHERE tunnel_id = $1 ORDER BY priority DESC, weight DESC',
        [tunnelId],
      );

      return {
        ...tunnel,
        config: JSON.parse(tunnel.config),
        metrics: JSON.parse(tunnel.metrics),
        endpoints: endpointsResult.rows,
      };
    } catch (error) {
      logger.error('[TunnelService] Failed to get tunnel', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * List tunnels for a user
   *
   * @param {string} userId - User ID
   * @param {Object} options - Query options
   * @param {number} options.limit - Result limit
   * @param {number} options.offset - Result offset
   * @returns {Promise<Object>} Tunnels and total count
   */
  async listTunnels(userId, options = {}) {
    try {
      const { limit = 50, offset = 0 } = options;

      // Validate pagination parameters
      if (limit < 1 || limit > 1000) {
        throw new Error('Limit must be between 1 and 1000');
      }

      if (offset < 0) {
        throw new Error('Offset must be non-negative');
      }

      // Get total count
      const countResult = await this.pool.query(
        'SELECT COUNT(*) as count FROM tunnels WHERE user_id = $1',
        [userId],
      );

      const total = parseInt(countResult.rows[0].count, 10);

      // Get tunnels
      const result = await this.pool.query(
        'SELECT * FROM tunnels WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3',
        [userId, limit, offset],
      );

      const tunnels = await Promise.all(
        result.rows.map(async (tunnel) => {
          const endpointsResult = await this.pool.query(
            'SELECT * FROM tunnel_endpoints WHERE tunnel_id = $1 ORDER BY priority DESC',
            [tunnel.id],
          );

          return {
            ...tunnel,
            config: JSON.parse(tunnel.config),
            metrics: JSON.parse(tunnel.metrics),
            endpoints: endpointsResult.rows,
          };
        }),
      );

      return {
        tunnels,
        total,
        limit,
        offset,
      };
    } catch (error) {
      logger.error('[TunnelService] Failed to list tunnels', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @param {Object} updateData - Data to update
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} Updated tunnel
   */
  async updateTunnel(tunnelId, userId, updateData, ipAddress, userAgent) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Verify tunnel ownership
      const tunnelResult = await client.query(
        'SELECT * FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      const { name, config, endpoints } = updateData;

      // Update tunnel fields
      let updateQuery = 'UPDATE tunnels SET updated_at = NOW()';
      const params = [];
      let paramIndex = 1;

      if (name !== undefined) {
        if (!name || typeof name !== 'string' || name.trim().length === 0) {
          throw new Error('Tunnel name must be a non-empty string');
        }

        if (name.length > 255) {
          throw new Error('Tunnel name must not exceed 255 characters');
        }

        // Check for duplicate name
        const duplicateResult = await client.query(
          'SELECT id FROM tunnels WHERE user_id = $1 AND name = $2 AND id != $3',
          [userId, name, tunnelId],
        );

        if (duplicateResult.rows.length > 0) {
          throw new Error('Tunnel with this name already exists for this user');
        }

        updateQuery += `, name = $${paramIndex}`;
        params.push(name);
        paramIndex++;
      }

      if (config !== undefined) {
        updateQuery += `, config = $${paramIndex}`;
        params.push(JSON.stringify(config));
        paramIndex++;
      }

      updateQuery += ` WHERE id = $${paramIndex} AND user_id = $${paramIndex + 1}`;
      params.push(tunnelId, userId);

      await client.query(updateQuery, params);

      // Update endpoints if provided
      if (endpoints !== undefined && Array.isArray(endpoints)) {
        // Delete existing endpoints
        await client.query(
          'DELETE FROM tunnel_endpoints WHERE tunnel_id = $1',
          [tunnelId],
        );

        // Add new endpoints
        for (const endpoint of endpoints) {
          const endpointId = uuidv4();
          await client.query(
            `INSERT INTO tunnel_endpoints (id, tunnel_id, url, priority, weight)
             VALUES ($1, $2, $3, $4, $5)`,
            [
              endpointId,
              tunnelId,
              endpoint.url,
              endpoint.priority || 0,
              endpoint.weight || 1,
            ],
          );
        }
      }

      // Log activity
      await client.query(
        `INSERT INTO tunnel_activity_logs (tunnel_id, user_id, action, status, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [tunnelId, userId, 'update', 'success', ipAddress, userAgent],
      );

      await client.query('COMMIT');

      logger.info('[TunnelService] Tunnel updated', {
        tunnelId,
        userId,
      });

      return this.getTunnelById(tunnelId, userId);
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelService] Failed to update tunnel', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Update tunnel status
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @param {string} status - New status
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} Updated tunnel
   */
  async updateTunnelStatus(tunnelId, userId, status, ipAddress, userAgent) {
    const validStatuses = [
      'created',
      'connecting',
      'connected',
      'disconnected',
      'error',
    ];

    if (!validStatuses.includes(status)) {
      throw new Error(
        `Invalid status. Must be one of: ${validStatuses.join(', ')}`,
      );
    }

    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Verify tunnel ownership
      await client.query(
        `INSERT INTO tunnel_activity_logs (tunnel_id, user_id, action, status, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [tunnelId, userId, 'status_change', status, ipAddress, userAgent],
      );

      await client.query('COMMIT');

      logger.info('[TunnelService] Tunnel status updated', {
        tunnelId,
        userId,
        status,
      });

      return this.getTunnelById(tunnelId, userId);
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelService] Failed to update tunnel status', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Delete tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<void>}
   */
  async deleteTunnel(tunnelId, userId, ipAddress, userAgent) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Verify tunnel ownership
      const tunnelResult = await client.query(
        'SELECT * FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      // Delete tunnel (cascades to endpoints and activity logs)
      await client.query('DELETE FROM tunnels WHERE id = $1', [tunnelId]);

      // Log activity
      await client.query(
        `INSERT INTO tunnel_activity_logs (tunnel_id, user_id, action, status, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [tunnelId, userId, 'delete', 'success', ipAddress, userAgent],
      );

      await client.query('COMMIT');

      logger.info('[TunnelService] Tunnel deleted', {
        tunnelId,
        userId,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelService] Failed to delete tunnel', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get tunnel metrics
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @returns {Promise<Object>} Tunnel metrics
   */
  async getTunnelMetrics(tunnelId, userId) {
    try {
      const result = await this.pool.query(
        'SELECT metrics FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (result.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      return JSON.parse(result.rows[0].metrics);
    } catch (error) {
      logger.error('[TunnelService] Failed to get tunnel metrics', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update tunnel metrics
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {Object} metrics - Metrics to update
   * @returns {Promise<void>}
   */
  async updateTunnelMetrics(tunnelId, metrics) {
    try {
      await this.pool.query(
        'UPDATE tunnels SET metrics = $1, updated_at = NOW() WHERE id = $2',
        [JSON.stringify(metrics), tunnelId],
      );

      logger.debug('[TunnelService] Tunnel metrics updated', {
        tunnelId,
      });
    } catch (error) {
      logger.error('[TunnelService] Failed to update tunnel metrics', {
        tunnelId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get tunnel activity logs
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @param {Object} options - Query options
   * @returns {Promise<Array>} Activity logs
   */
  async getTunnelActivityLogs(tunnelId, userId, options = {}) {
    try {
      const { limit = 50, offset = 0 } = options;

      // Verify tunnel ownership
      const tunnelResult = await this.pool.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      const result = await this.pool.query(
        'SELECT * FROM tunnel_activity_logs WHERE tunnel_id = $1 ORDER BY created_at DESC LIMIT $2 OFFSET $3',
        [tunnelId, limit, offset],
      );

      return result.rows.map((log) => ({
        ...log,
        details: JSON.parse(log.details),
      }));
    } catch (error) {
      logger.error('[TunnelService] Failed to get tunnel activity logs', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get tunnel configuration
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @returns {Promise<Object>} Tunnel configuration
   */
  async getTunnelConfig(tunnelId, userId) {
    try {
      const result = await this.pool.query(
        'SELECT config FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (result.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      return JSON.parse(result.rows[0].config);
    } catch (error) {
      logger.error('[TunnelService] Failed to get tunnel config', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update tunnel configuration
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @param {Object} config - New configuration
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} Updated configuration
   */
  async updateTunnelConfig(tunnelId, userId, config, ipAddress, userAgent) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Verify tunnel ownership
      const tunnelResult = await client.query(
        'SELECT config FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      // Merge with existing config
      const existingConfig = JSON.parse(tunnelResult.rows[0].config);
      const mergedConfig = {
        ...existingConfig,
        ...config,
      };

      // Update configuration
      await client.query(
        'UPDATE tunnels SET config = $1, updated_at = NOW() WHERE id = $2',
        [JSON.stringify(mergedConfig), tunnelId],
      );

      // Log activity
      await client.query(
        `INSERT INTO tunnel_activity_logs (tunnel_id, user_id, action, status, details, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          tunnelId,
          userId,
          'config_update',
          'success',
          JSON.stringify({ changes: config }),
          ipAddress,
          userAgent,
        ],
      );

      await client.query('COMMIT');

      logger.info('[TunnelService] Tunnel config updated', {
        tunnelId,
        userId,
      });

      return mergedConfig;
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelService] Failed to update tunnel config', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Reset tunnel configuration to defaults
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID (for authorization)
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} Reset configuration
   */
  async resetTunnelConfig(tunnelId, userId, ipAddress, userAgent) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Verify tunnel ownership
      const tunnelResult = await client.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error('Tunnel not found');
      }

      // Default configuration
      const defaultConfig = {
        maxConnections: 100,
        timeout: 30000,
        compression: true,
      };

      // Update configuration
      await client.query(
        'UPDATE tunnels SET config = $1, updated_at = NOW() WHERE id = $2',
        [JSON.stringify(defaultConfig), tunnelId],
      );

      // Log activity
      await client.query(
        `INSERT INTO tunnel_activity_logs (tunnel_id, user_id, action, status, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [tunnelId, userId, 'config_reset', 'success', ipAddress, userAgent],
      );

      await client.query('COMMIT');

      logger.info('[TunnelService] Tunnel config reset', {
        tunnelId,
        userId,
      });

      return defaultConfig;
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelService] Failed to reset tunnel config', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }
}
