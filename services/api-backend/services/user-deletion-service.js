/**
 * User Deletion Service
 *
 * Handles user account deletion with cascading data cleanup:
 * - Delete user profile and preferences
 * - Delete user sessions
 * - Delete tunnel connections
 * - Delete audit logs
 * - Delete API usage records
 * - Delete conversations and messages
 * - Support for soft delete (compliance)
 *
 * Validates: Requirements 3.5
 * - Supports user account deletion with data cleanup
 * - Implements cascading data cleanup (sessions, tunnels, audit logs)
 * - Adds soft delete option for compliance
 *
 * @fileoverview User account deletion service
 * @version 1.0.0
 */

import logger from '../logger.js';
import { initializePool } from '../database/db-pool.js';

/**
 * UserDeletionService
 * Manages user account deletion and data cleanup
 */
export class UserDeletionService {
  constructor() {
    this.pool = null;
  }

  /**
   * Initialize the service with database pool
   */
  async initialize() {
    try {
      this.pool = await initializePool();
      logger.info('[UserDeletionService] Service initialized');
    } catch (error) {
      logger.error('[UserDeletionService] Failed to initialize', {
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Delete user account with cascading cleanup
   * @param {string} userId - JWT user ID
   * @param {Object} options - Deletion options
   * @param {boolean} options.softDelete - If true, mark as deleted instead of hard delete
   * @param {string} options.reason - Reason for deletion (for audit purposes)
   * @returns {Promise<Object>} Deletion result with cleanup summary
   */
  async deleteUserAccount(userId, options = {}) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    const { softDelete = true, reason = 'User requested deletion' } = options;

    const client = await this.pool.connect();

    try {
      await client.query('BEGIN');

      // Get user UUID from jwt_id
      const userQuery = 'SELECT id FROM users WHERE jwt_id = $1';
      const userResult = await client.query(userQuery, [userId]);

      if (userResult.rows.length === 0) {
        throw new Error('User not found');
      }

      const userUuid = userResult.rows[0].id;

      // Track cleanup statistics
      const cleanupStats = {
        sessionsDeleted: 0,
        tunnelsDeleted: 0,
        auditLogsDeleted: 0,
        apiUsageDeleted: 0,
        conversationsDeleted: 0,
        messagesDeleted: 0,
        preferencesDeleted: 0,
        userDeleted: false,
      };

      if (softDelete) {
        // Soft delete: mark user as deleted
        const softDeleteQuery = `
          UPDATE users
          SET 
            metadata = jsonb_set(metadata, '{deleted_at}', to_jsonb(NOW())),
            metadata = jsonb_set(metadata, '{deletion_reason}', to_jsonb($1)),
            metadata = jsonb_set(metadata, '{is_deleted}', 'true'::jsonb),
            updated_at = NOW()
          WHERE id = $2
        `;

        const softDeleteResult = await client.query(softDeleteQuery, [
          reason,
          userUuid,
        ]);
        cleanupStats.userDeleted = softDeleteResult.rowCount > 0;

        logger.info('[UserDeletion] User soft deleted', {
          userId,
          userUuid,
          reason,
        });
      } else {
        // Hard delete: perform cascading cleanup

        // Delete user sessions
        const sessionsResult = await client.query(
          'DELETE FROM user_sessions WHERE user_id = $1',
          [userUuid],
        );
        cleanupStats.sessionsDeleted = sessionsResult.rowCount;

        // Delete tunnel connections
        const tunnelsResult = await client.query(
          'DELETE FROM tunnel_connections WHERE user_id = $1',
          [userId],
        );
        cleanupStats.tunnelsDeleted = tunnelsResult.rowCount;

        // Delete audit logs
        const auditResult = await client.query(
          'DELETE FROM audit_logs WHERE user_id = $1',
          [userId],
        );
        cleanupStats.auditLogsDeleted = auditResult.rowCount;

        // Delete API usage records
        const apiUsageResult = await client.query(
          'DELETE FROM api_usage WHERE user_id = $1',
          [userId],
        );
        cleanupStats.apiUsageDeleted = apiUsageResult.rowCount;

        // Delete messages (cascade from conversations)
        const messagesResult = await client.query(
          `DELETE FROM messages 
           WHERE conversation_id IN (
             SELECT id FROM conversations WHERE user_id = $1
           )`,
          [userId],
        );
        cleanupStats.messagesDeleted = messagesResult.rowCount;

        // Delete conversations
        const conversationsResult = await client.query(
          'DELETE FROM conversations WHERE user_id = $1',
          [userId],
        );
        cleanupStats.conversationsDeleted = conversationsResult.rowCount;

        // Delete user preferences
        const preferencesResult = await client.query(
          'DELETE FROM user_preferences WHERE user_id = $1',
          [userUuid],
        );
        cleanupStats.preferencesDeleted = preferencesResult.rowCount;

        // Delete user
        const deleteResult = await client.query(
          'DELETE FROM users WHERE id = $1',
          [userUuid],
        );
        cleanupStats.userDeleted = deleteResult.rowCount > 0;

        logger.info('[UserDeletion] User hard deleted with cascading cleanup', {
          userId,
          userUuid,
          cleanupStats,
        });
      }

      await client.query('COMMIT');

      return {
        success: true,
        userId,
        deletionType: softDelete ? 'soft' : 'hard',
        cleanupStats,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[UserDeletionService] Error deleting user account', {
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Restore a soft-deleted user account
   * @param {string} userId - JWT user ID
   * @returns {Promise<Object>} Restoration result
   */
  async restoreUserAccount(userId) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    try {
      const query = `
        UPDATE users
        SET 
          metadata = metadata - 'deleted_at' - 'deletion_reason' - 'is_deleted',
          updated_at = NOW()
        WHERE jwt_id = $1 AND metadata->>'is_deleted' = 'true'
        RETURNING id
      `;

      const result = await this.pool.query(query, [userId]);

      if (result.rows.length === 0) {
        throw new Error('User not found or not soft-deleted');
      }

      logger.info('[UserDeletion] User account restored', {
        userId,
      });

      return {
        success: true,
        userId,
        message: 'User account restored successfully',
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      logger.error('[UserDeletionService] Error restoring user account', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Check if a user is soft-deleted
   * @param {string} userId - JWT user ID
   * @returns {Promise<boolean>} True if user is soft-deleted
   */
  async isUserDeleted(userId) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    try {
      const query = `
        SELECT metadata->>'is_deleted' as is_deleted
        FROM users
        WHERE jwt_id = $1
      `;

      const result = await this.pool.query(query, [userId]);

      if (result.rows.length === 0) {
        throw new Error('User not found');
      }

      return result.rows[0].is_deleted === 'true';
    } catch (error) {
      logger.error(
        '[UserDeletionService] Error checking user deletion status',
        {
          userId,
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Get deletion information for a soft-deleted user
   * @param {string} userId - JWT user ID
   * @returns {Promise<Object>} Deletion information
   */
  async getDeletionInfo(userId) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    try {
      const query = `
        SELECT 
          metadata->>'deleted_at' as deleted_at,
          metadata->>'deletion_reason' as deletion_reason,
          metadata->>'is_deleted' as is_deleted
        FROM users
        WHERE jwt_id = $1
      `;

      const result = await this.pool.query(query, [userId]);

      if (result.rows.length === 0) {
        throw new Error('User not found');
      }

      const row = result.rows[0];

      if (row.is_deleted !== 'true') {
        throw new Error('User is not deleted');
      }

      return {
        userId,
        deletedAt: row.deleted_at,
        deletionReason: row.deletion_reason,
        isDeleted: true,
      };
    } catch (error) {
      logger.error('[UserDeletionService] Error retrieving deletion info', {
        userId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Permanently delete a soft-deleted user (after retention period)
   * @param {string} userId - JWT user ID
   * @returns {Promise<Object>} Permanent deletion result
   */
  async permanentlyDeleteUser(userId) {
    if (!userId || typeof userId !== 'string') {
      throw new Error('Invalid user ID');
    }

    const client = await this.pool.connect();

    try {
      await client.query('BEGIN');

      // Get user UUID
      const userQuery = 'SELECT id FROM users WHERE jwt_id = $1';
      const userResult = await client.query(userQuery, [userId]);

      if (userResult.rows.length === 0) {
        throw new Error('User not found');
      }

      const userUuid = userResult.rows[0].id;

      // Track cleanup statistics
      const cleanupStats = {
        sessionsDeleted: 0,
        tunnelsDeleted: 0,
        auditLogsDeleted: 0,
        apiUsageDeleted: 0,
        conversationsDeleted: 0,
        messagesDeleted: 0,
        preferencesDeleted: 0,
        userDeleted: false,
      };

      // Delete all related data
      const sessionsResult = await client.query(
        'DELETE FROM user_sessions WHERE user_id = $1',
        [userUuid],
      );
      cleanupStats.sessionsDeleted = sessionsResult.rowCount;

      const tunnelsResult = await client.query(
        'DELETE FROM tunnel_connections WHERE user_id = $1',
        [userId],
      );
      cleanupStats.tunnelsDeleted = tunnelsResult.rowCount;

      const auditResult = await client.query(
        'DELETE FROM audit_logs WHERE user_id = $1',
        [userId],
      );
      cleanupStats.auditLogsDeleted = auditResult.rowCount;

      const apiUsageResult = await client.query(
        'DELETE FROM api_usage WHERE user_id = $1',
        [userId],
      );
      cleanupStats.apiUsageDeleted = apiUsageResult.rowCount;

      const messagesResult = await client.query(
        `DELETE FROM messages 
         WHERE conversation_id IN (
           SELECT id FROM conversations WHERE user_id = $1
         )`,
        [userId],
      );
      cleanupStats.messagesDeleted = messagesResult.rowCount;

      const conversationsResult = await client.query(
        'DELETE FROM conversations WHERE user_id = $1',
        [userId],
      );
      cleanupStats.conversationsDeleted = conversationsResult.rowCount;

      const preferencesResult = await client.query(
        'DELETE FROM user_preferences WHERE user_id = $1',
        [userUuid],
      );
      cleanupStats.preferencesDeleted = preferencesResult.rowCount;

      // Delete user
      const deleteResult = await client.query(
        'DELETE FROM users WHERE id = $1',
        [userUuid],
      );
      cleanupStats.userDeleted = deleteResult.rowCount > 0;

      await client.query('COMMIT');

      logger.info('[UserDeletion] User permanently deleted', {
        userId,
        userUuid,
        cleanupStats,
      });

      return {
        success: true,
        userId,
        deletionType: 'permanent',
        cleanupStats,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('[UserDeletionService] Error permanently deleting user', {
        userId,
        error: error.message,
      });
      throw error;
    } finally {
      client.release();
    }
  }
}

export default UserDeletionService;
