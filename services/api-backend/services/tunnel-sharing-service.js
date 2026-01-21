/**
 * Tunnel Sharing Service
 *
 * Manages tunnel sharing and access control including:
 * - Sharing tunnels with other users
 * - Managing permissions (read, write, admin)
 * - Creating temporary share tokens
 * - Tracking access logs for audit purposes
 *
 * Validates: Requirements 4.8
 * - Supports tunnel sharing and access control
 * - Implements permission management for tunnel access
 *
 * @fileoverview Tunnel sharing and access control service
 * @version 1.0.0
 */

import { v4 as uuidv4 } from 'uuid';
import crypto from 'crypto';
import logger from '../logger.js';
import { getPool } from '../database/db-pool.js';

export class TunnelSharingService {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize the tunnel sharing service with database connection pool
   */
  async initialize() {
    try {
      this.pool = getPool();
      if (!this.pool) {
        throw new Error('Database pool not initialized');
      }
      logger.info('[TunnelSharingService] Tunnel sharing service initialized');
    } catch (error) {
      logger.error(
        '[TunnelSharingService] Failed to initialize tunnel sharing service',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Share a tunnel with another user
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} ownerId - Owner user ID
   * @param {string} sharedWithUserId - User ID to share with
   * @param {string} permission - Permission level (read, write, admin)
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} Tunnel share record
   */
  async shareTunnel(
    tunnelId,
    ownerId,
    sharedWithUserId,
    permission = 'read',
    ipAddress,
    userAgent,
  ) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Validate permission
      const validPermissions = ['read', 'write', 'admin'];
      if (!validPermissions.includes(permission)) {
        throw new Error(
          `Invalid permission. Must be one of: ${validPermissions.join(', ')}`,
        );
      }

      // Verify tunnel ownership
      const tunnelResult = await client.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, ownerId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error(
          'Tunnel not found or you do not have permission to share it',
        );
      }

      // Verify shared_with_user exists
      const userResult = await client.query(
        'SELECT id FROM users WHERE id = $1 AND is_active = true',
        [sharedWithUserId],
      );

      if (userResult.rows.length === 0) {
        throw new Error('User to share with not found or is inactive');
      }

      // Prevent sharing with self
      if (ownerId === sharedWithUserId) {
        throw new Error('Cannot share tunnel with yourself');
      }

      // Check if already shared
      const existingShare = await client.query(
        'SELECT id FROM tunnel_shares WHERE tunnel_id = $1 AND owner_id = $2 AND shared_with_user_id = $3',
        [tunnelId, ownerId, sharedWithUserId],
      );

      let shareId;
      if (existingShare.rows.length > 0) {
        // Update existing share
        shareId = existingShare.rows[0].id;
        await client.query(
          'UPDATE tunnel_shares SET permission = $1, updated_at = NOW(), is_active = true WHERE id = $2',
          [permission, shareId],
        );
      } else {
        // Create new share
        shareId = uuidv4();
        await client.query(
          `INSERT INTO tunnel_shares (id, tunnel_id, owner_id, shared_with_user_id, permission)
           VALUES ($1, $2, $3, $4, $5)`,
          [shareId, tunnelId, ownerId, sharedWithUserId, permission],
        );
      }

      // Log access
      await client.query(
        `INSERT INTO tunnel_access_logs (tunnel_id, user_id, action, permission, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [tunnelId, ownerId, 'share', permission, ipAddress, userAgent],
      );

      await client.query('COMMIT');

      logger.info('[TunnelSharingService] Tunnel shared', {
        tunnelId,
        ownerId,
        sharedWithUserId,
        permission,
      });

      return {
        id: shareId,
        tunnelId,
        ownerId,
        sharedWithUserId,
        permission,
        createdAt: new Date().toISOString(),
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelSharingService] Failed to share tunnel', {
        tunnelId,
        ownerId,
        sharedWithUserId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Revoke tunnel access from a user
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} ownerId - Owner user ID
   * @param {string} sharedWithUserId - User ID to revoke access from
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<void>}
   */
  async revokeTunnelAccess(
    tunnelId,
    ownerId,
    sharedWithUserId,
    ipAddress,
    userAgent,
  ) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Verify tunnel ownership
      const tunnelResult = await client.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, ownerId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error(
          'Tunnel not found or you do not have permission to manage it',
        );
      }

      // Revoke access
      const revokeResult = await client.query(
        'UPDATE tunnel_shares SET is_active = false, updated_at = NOW() WHERE tunnel_id = $1 AND owner_id = $2 AND shared_with_user_id = $3',
        [tunnelId, ownerId, sharedWithUserId],
      );

      if (revokeResult.rowCount === 0) {
        throw new Error('Tunnel access not found');
      }

      // Log access
      await client.query(
        `INSERT INTO tunnel_access_logs (tunnel_id, user_id, action, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5)`,
        [tunnelId, ownerId, 'revoke', ipAddress, userAgent],
      );

      await client.query('COMMIT');

      logger.info('[TunnelSharingService] Tunnel access revoked', {
        tunnelId,
        ownerId,
        sharedWithUserId,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelSharingService] Failed to revoke tunnel access', {
        tunnelId,
        ownerId,
        sharedWithUserId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get tunnel shares (who has access to this tunnel)
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} ownerId - Owner user ID
   * @returns {Promise<Array>} Array of shares
   */
  async getTunnelShares(tunnelId, ownerId) {
    try {
      // Verify tunnel ownership
      const tunnelResult = await this.pool.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, ownerId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error(
          'Tunnel not found or you do not have permission to view shares',
        );
      }

      const result = await this.pool.query(
        `SELECT ts.id, ts.tunnel_id, ts.owner_id, ts.shared_with_user_id, ts.permission, 
                ts.created_at, ts.updated_at, ts.expires_at, ts.is_active,
                u.email as shared_with_email
         FROM tunnel_shares ts
         JOIN users u ON ts.shared_with_user_id = u.id
         WHERE ts.tunnel_id = $1 AND ts.owner_id = $2
         ORDER BY ts.created_at DESC`,
        [tunnelId, ownerId],
      );

      return result.rows;
    } catch (error) {
      logger.error('[TunnelSharingService] Failed to get tunnel shares', {
        tunnelId,
        ownerId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get tunnels shared with a user
   *
   * @param {string} userId - User ID
   * @param {Object} options - Query options
   * @returns {Promise<Array>} Array of shared tunnels
   */
  async getSharedTunnels(userId, options = {}) {
    try {
      const { limit = 50, offset = 0 } = options;

      // Validate pagination parameters
      if (limit < 1 || limit > 1000) {
        throw new Error('Limit must be between 1 and 1000');
      }

      if (offset < 0) {
        throw new Error('Offset must be non-negative');
      }

      const result = await this.pool.query(
        `SELECT t.*, ts.permission, ts.owner_id, u.email as owner_email
         FROM tunnel_shares ts
         JOIN tunnels t ON ts.tunnel_id = t.id
         JOIN users u ON ts.owner_id = u.id
         WHERE ts.shared_with_user_id = $1 AND ts.is_active = true
         ORDER BY ts.created_at DESC
         LIMIT $2 OFFSET $3`,
        [userId, limit, offset],
      );

      return result.rows;
    } catch (error) {
      logger.error('[TunnelSharingService] Failed to get shared tunnels', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Create a temporary share token
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} ownerId - Owner user ID
   * @param {string} permission - Permission level
   * @param {number} expiresInHours - Token expiration in hours
   * @param {number} maxUses - Maximum number of uses (optional)
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} Share token record
   */
  async createShareToken(
    tunnelId,
    ownerId,
    permission = 'read',
    expiresInHours = 24,
    maxUses = null,
    ipAddress,
    userAgent,
  ) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Validate permission
      const validPermissions = ['read', 'write', 'admin'];
      if (!validPermissions.includes(permission)) {
        throw new Error(
          `Invalid permission. Must be one of: ${validPermissions.join(', ')}`,
        );
      }

      // Verify tunnel ownership
      const tunnelResult = await client.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, ownerId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error(
          'Tunnel not found or you do not have permission to create share tokens',
        );
      }

      // Generate token
      const token = crypto.randomBytes(32).toString('hex');
      const tokenId = uuidv4();
      const expiresAt = new Date(Date.now() + expiresInHours * 60 * 60 * 1000);

      await client.query(
        `INSERT INTO tunnel_share_tokens (id, tunnel_id, owner_id, token, permission, expires_at, max_uses)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [tokenId, tunnelId, ownerId, token, permission, expiresAt, maxUses],
      );

      // Log access
      await client.query(
        `INSERT INTO tunnel_access_logs (tunnel_id, user_id, action, permission, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [tunnelId, ownerId, 'create_token', permission, ipAddress, userAgent],
      );

      await client.query('COMMIT');

      logger.info('[TunnelSharingService] Share token created', {
        tunnelId,
        ownerId,
        permission,
      });

      return {
        id: tokenId,
        token,
        tunnelId,
        permission,
        expiresAt: expiresAt.toISOString(),
        maxUses,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelSharingService] Failed to create share token', {
        tunnelId,
        ownerId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Revoke a share token
   *
   * @param {string} tokenId - Token ID
   * @param {string} ownerId - Owner user ID
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<void>}
   */
  async revokeShareToken(tokenId, ownerId, ipAddress, userAgent) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Verify token ownership
      const tokenResult = await client.query(
        'SELECT tunnel_id FROM tunnel_share_tokens WHERE id = $1 AND owner_id = $2',
        [tokenId, ownerId],
      );

      if (tokenResult.rows.length === 0) {
        throw new Error(
          'Token not found or you do not have permission to revoke it',
        );
      }

      const tunnelId = tokenResult.rows[0].tunnel_id;

      // Revoke token
      await client.query(
        'UPDATE tunnel_share_tokens SET is_active = false WHERE id = $1',
        [tokenId],
      );

      // Log access
      await client.query(
        `INSERT INTO tunnel_access_logs (tunnel_id, user_id, action, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5)`,
        [tunnelId, ownerId, 'revoke_token', ipAddress, userAgent],
      );

      await client.query('COMMIT');

      logger.info('[TunnelSharingService] Share token revoked', {
        tokenId,
        ownerId,
      });
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelSharingService] Failed to revoke share token', {
        tokenId,
        ownerId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get share tokens for a tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} ownerId - Owner user ID
   * @returns {Promise<Array>} Array of share tokens
   */
  async getShareTokens(tunnelId, ownerId) {
    try {
      // Verify tunnel ownership
      const tunnelResult = await this.pool.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, ownerId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error(
          'Tunnel not found or you do not have permission to view tokens',
        );
      }

      const result = await this.pool.query(
        `SELECT id, tunnel_id, permission, created_at, expires_at, is_active, max_uses, use_count
         FROM tunnel_share_tokens
         WHERE tunnel_id = $1 AND owner_id = $2
         ORDER BY created_at DESC`,
        [tunnelId, ownerId],
      );

      return result.rows;
    } catch (error) {
      logger.error('[TunnelSharingService] Failed to get share tokens', {
        tunnelId,
        ownerId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Verify user has permission to access tunnel
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} userId - User ID
   * @param {string} requiredPermission - Required permission level
   * @returns {Promise<Object>} Permission info
   */
  async verifyTunnelAccess(tunnelId, userId, requiredPermission = 'read') {
    try {
      // Check if user is the owner
      const ownerResult = await this.pool.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, userId],
      );

      if (ownerResult.rows.length > 0) {
        return {
          hasAccess: true,
          isOwner: true,
          permission: 'admin',
        };
      }

      // Check if tunnel is shared with user
      const shareResult = await this.pool.query(
        `SELECT permission FROM tunnel_shares 
         WHERE tunnel_id = $1 AND shared_with_user_id = $2 AND is_active = true
         AND (expires_at IS NULL OR expires_at > NOW())`,
        [tunnelId, userId],
      );

      if (shareResult.rows.length === 0) {
        return {
          hasAccess: false,
          isOwner: false,
          permission: null,
        };
      }

      const permission = shareResult.rows[0].permission;
      const permissionLevels = { read: 1, write: 2, admin: 3 };
      const requiredLevel = permissionLevels[requiredPermission] || 1;
      const userLevel = permissionLevels[permission] || 0;

      return {
        hasAccess: userLevel >= requiredLevel,
        isOwner: false,
        permission,
      };
    } catch (error) {
      logger.error('[TunnelSharingService] Failed to verify tunnel access', {
        tunnelId,
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get tunnel access logs
   *
   * @param {string} tunnelId - Tunnel ID
   * @param {string} ownerId - Owner user ID
   * @param {Object} options - Query options
   * @returns {Promise<Array>} Access logs
   */
  async getTunnelAccessLogs(tunnelId, ownerId, options = {}) {
    try {
      const { limit = 50, offset = 0 } = options;

      // Verify tunnel ownership
      const tunnelResult = await this.pool.query(
        'SELECT id FROM tunnels WHERE id = $1 AND user_id = $2',
        [tunnelId, ownerId],
      );

      if (tunnelResult.rows.length === 0) {
        throw new Error(
          'Tunnel not found or you do not have permission to view access logs',
        );
      }

      const result = await this.pool.query(
        `SELECT id, tunnel_id, user_id, action, permission, ip_address, user_agent, created_at
         FROM tunnel_access_logs
         WHERE tunnel_id = $1
         ORDER BY created_at DESC
         LIMIT $2 OFFSET $3`,
        [tunnelId, limit, offset],
      );

      return result.rows;
    } catch (error) {
      logger.error('[TunnelSharingService] Failed to get tunnel access logs', {
        tunnelId,
        ownerId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Update share permission
   *
   * @param {string} shareId - Share ID
   * @param {string} ownerId - Owner user ID
   * @param {string} newPermission - New permission level
   * @param {string} ipAddress - Client IP address
   * @param {string} userAgent - Client user agent
   * @returns {Promise<Object>} Updated share
   */
  async updateSharePermission(
    shareId,
    ownerId,
    newPermission,
    ipAddress,
    userAgent,
  ) {
    const client = await this.pool.connect();
    try {
      await client.query('BEGIN');

      // Validate permission
      const validPermissions = ['read', 'write', 'admin'];
      if (!validPermissions.includes(newPermission)) {
        throw new Error(
          `Invalid permission. Must be one of: ${validPermissions.join(', ')}`,
        );
      }

      // Verify share ownership
      const shareResult = await client.query(
        'SELECT tunnel_id FROM tunnel_shares WHERE id = $1 AND owner_id = $2',
        [shareId, ownerId],
      );

      if (shareResult.rows.length === 0) {
        throw new Error(
          'Share not found or you do not have permission to update it',
        );
      }

      const tunnelId = shareResult.rows[0].tunnel_id;

      // Update permission
      await client.query(
        'UPDATE tunnel_shares SET permission = $1, updated_at = NOW() WHERE id = $2',
        [newPermission, shareId],
      );

      // Log access
      await client.query(
        `INSERT INTO tunnel_access_logs (tunnel_id, user_id, action, permission, ip_address, user_agent)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [
          tunnelId,
          ownerId,
          'update_permission',
          newPermission,
          ipAddress,
          userAgent,
        ],
      );

      await client.query('COMMIT');

      logger.info('[TunnelSharingService] Share permission updated', {
        shareId,
        ownerId,
        newPermission,
      });

      return {
        id: shareId,
        permission: newPermission,
        updatedAt: new Date().toISOString(),
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[TunnelSharingService] Failed to update share permission', {
        shareId,
        ownerId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }
}
