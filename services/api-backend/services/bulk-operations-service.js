/**
 * Bulk Operations Service
 *
 * Handles bulk user management operations:
 * - Bulk tier updates
 * - Bulk user suspension/reactivation
 * - Bulk user deletion
 * - Bulk metadata updates
 *
 * Features:
 * - Batch processing with transaction support
 * - Progress tracking and status reporting
 * - Comprehensive error handling and rollback
 * - Audit logging for all operations
 */

import { v4 as uuidv4 } from 'uuid';
import { getPool } from '../database/db-pool.js';
import { logAdminAction } from '../utils/audit-logger.js';
import logger from '../logger.js';

class BulkOperationsService {
  constructor() {
    this.operations = new Map();
  }

  /**
   * Create a new bulk operation
   * @param {string} operationType - Type of operation (tier_update, suspend, reactivate, delete)
   * @param {Array} userIds - Array of user IDs to operate on
   * @param {Object} operationData - Operation-specific data
   * @returns {Object} Operation details with ID and status
   */
  async createBulkOperation(operationType, userIds, operationData) {
    const operationId = uuidv4();

    // Validate operation type
    const validTypes = ['tier_update', 'suspend', 'reactivate', 'delete'];
    if (!validTypes.includes(operationType)) {
      throw new Error(`Invalid operation type: ${operationType}`);
    }

    // Validate user IDs
    if (!Array.isArray(userIds) || userIds.length === 0) {
      throw new Error('User IDs must be a non-empty array');
    }

    if (userIds.length > 1000) {
      throw new Error('Maximum 1000 users per bulk operation');
    }

    // Validate operation data based on type
    if (operationType === 'tier_update') {
      const validTiers = ['free', 'premium', 'enterprise'];
      if (!validTiers.includes(operationData.tier)) {
        throw new Error(`Invalid subscription tier: ${operationData.tier}`);
      }
    }

    if (operationType === 'suspend' && !operationData.reason) {
      throw new Error('Suspension reason is required');
    }

    // Create operation record
    const operation = {
      id: operationId,
      type: operationType,
      status: 'pending',
      totalUsers: userIds.length,
      processedUsers: 0,
      successCount: 0,
      failureCount: 0,
      errors: [],
      createdAt: new Date(),
      startedAt: null,
      completedAt: null,
      operationData,
      userIds,
    };

    this.operations.set(operationId, operation);

    logger.info('✅ [BulkOps] Bulk operation created', {
      operationId,
      type: operationType,
      totalUsers: userIds.length,
    });

    return {
      operationId,
      status: operation.status,
      totalUsers: operation.totalUsers,
      createdAt: operation.createdAt,
    };
  }

  /**
   * Execute a bulk operation
   * @param {string} operationId - Operation ID
   * @param {string} adminUserId - Admin user ID performing the operation
   * @param {string} adminRole - Admin role
   * @returns {Object} Operation results
   */
  async executeBulkOperation(operationId, adminUserId, adminRole) {
    const operation = this.operations.get(operationId);

    if (!operation) {
      throw new Error(`Operation not found: ${operationId}`);
    }

    if (operation.status !== 'pending') {
      throw new Error(`Operation is already ${operation.status}`);
    }

    const pool = getPool();
    operation.status = 'in_progress';
    operation.startedAt = new Date();

    try {
      const results = await this._executeOperation(
        operation,
        adminUserId,
        adminRole,
        pool,
      );

      operation.status = 'completed';
      operation.completedAt = new Date();

      logger.info('✅ [BulkOps] Bulk operation completed', {
        operationId,
        type: operation.type,
        successCount: operation.successCount,
        failureCount: operation.failureCount,
        duration: operation.completedAt - operation.startedAt,
      });

      return results;
    } catch (error) {
      operation.status = 'failed';
      operation.completedAt = new Date();
      operation.errors.push(error.message);

      logger.error('🔴 [BulkOps] Bulk operation failed', {
        operationId,
        type: operation.type,
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Execute the actual bulk operation
   * @private
   */
  async _executeOperation(operation, adminUserId, adminRole, pool) {
    const { type, userIds, operationData } = operation;

    switch (type) {
      case 'tier_update':
        return await this._executeTierUpdate(
          operation,
          userIds,
          operationData,
          adminUserId,
          adminRole,
          pool,
        );
      case 'suspend':
        return await this._executeSuspend(
          operation,
          userIds,
          operationData,
          adminUserId,
          adminRole,
          pool,
        );
      case 'reactivate':
        return await this._executeReactivate(
          operation,
          userIds,
          adminUserId,
          adminRole,
          pool,
        );
      case 'delete':
        return await this._executeDelete(
          operation,
          userIds,
          operationData,
          adminUserId,
          adminRole,
          pool,
        );
      default:
        throw new Error(`Unknown operation type: ${type}`);
    }
  }

  /**
   * Execute bulk tier update
   * @private
   */
  async _executeTierUpdate(
    operation,
    userIds,
    operationData,
    adminUserId,
    adminRole,
    pool,
  ) {
    const { tier } = operationData;
    const results = {
      operationId: operation.id,
      type: operation.type,
      totalUsers: userIds.length,
      successCount: 0,
      failureCount: 0,
      errors: [],
      updatedUsers: [],
    };

    for (const userId of userIds) {
      try {
        await pool.query('BEGIN');

        // Get current subscription
        const currentQuery = `
          SELECT id, tier FROM subscriptions 
          WHERE user_id = $1 AND status = 'active'
        `;
        const currentResult = await pool.query(currentQuery, [userId]);
        const currentTier = currentResult.rows[0]?.tier || 'free';

        if (currentTier === tier) {
          operation.processedUsers++;
          continue;
        }

        // Update or create subscription
        let subscriptionId;
        if (currentResult.rows.length > 0) {
          const updateQuery = `
            UPDATE subscriptions 
            SET tier = $1, updated_at = NOW() 
            WHERE user_id = $2 
            RETURNING id
          `;
          const updateResult = await pool.query(updateQuery, [tier, userId]);
          subscriptionId = updateResult.rows[0].id;
        } else {
          const insertQuery = `
            INSERT INTO subscriptions (user_id, tier, status, created_at, updated_at)
            VALUES ($1, $2, 'active', NOW(), NOW())
            RETURNING id
          `;
          const insertResult = await pool.query(insertQuery, [userId, tier]);
          subscriptionId = insertResult.rows[0].id;
        }

        // Log action
        await logAdminAction({
          adminUserId,
          adminRole,
          action: 'bulk_tier_update',
          resourceType: 'subscription',
          resourceId: subscriptionId,
          affectedUserId: userId,
          details: {
            previousTier: currentTier,
            newTier: tier,
            bulkOperationId: operation.id,
          },
          ipAddress: 'bulk-operation',
          userAgent: 'bulk-operation',
        });

        await pool.query('COMMIT');

        operation.successCount++;
        results.updatedUsers.push({
          userId,
          previousTier: currentTier,
          newTier: tier,
        });
      } catch (error) {
        await pool.query('ROLLBACK').catch(() => {});
        operation.failureCount++;
        results.errors.push({
          userId,
          error: error.message,
        });
      }

      operation.processedUsers++;
    }

    results.successCount = operation.successCount;
    results.failureCount = operation.failureCount;
    return results;
  }

  /**
   * Execute bulk suspend
   * @private
   */
  async _executeSuspend(
    operation,
    userIds,
    operationData,
    adminUserId,
    adminRole,
    pool,
  ) {
    const { reason } = operationData;
    const results = {
      operationId: operation.id,
      type: operation.type,
      totalUsers: userIds.length,
      successCount: 0,
      failureCount: 0,
      errors: [],
      suspendedUsers: [],
    };

    for (const userId of userIds) {
      try {
        await pool.query('BEGIN');

        // Check if already suspended
        const checkQuery = `
          SELECT id, is_suspended FROM users WHERE id = $1
            `;
        const checkResult = await pool.query(checkQuery, [userId]);

        if (checkResult.rows.length === 0) {
          throw new Error('User not found');
        }

        if (checkResult.rows[0].is_suspended) {
          operation.processedUsers++;
          continue;
        }

        // Suspend user
        const suspendQuery = `
          UPDATE users 
          SET is_suspended = true, suspended_at = NOW(), suspension_reason = $1
          WHERE id = $2
            `;
        await pool.query(suspendQuery, [reason, userId]);

        // Invalidate sessions
        await pool.query(
          'UPDATE user_sessions SET expires_at = NOW() WHERE user_id = $1 AND expires_at > NOW()',
          [userId],
        );

        // Log action
        await logAdminAction({
          adminUserId,
          adminRole,
          action: 'bulk_user_suspend',
          resourceType: 'user',
          resourceId: userId,
          affectedUserId: userId,
          details: {
            reason,
            bulkOperationId: operation.id,
          },
          ipAddress: 'bulk-operation',
          userAgent: 'bulk-operation',
        });

        await pool.query('COMMIT');

        operation.successCount++;
        results.suspendedUsers.push(userId);
      } catch (error) {
        await pool.query('ROLLBACK').catch(() => {});
        operation.failureCount++;
        results.errors.push({
          userId,
          error: error.message,
        });
      }

      operation.processedUsers++;
    }

    results.successCount = operation.successCount;
    results.failureCount = operation.failureCount;
    return results;
  }

  /**
   * Execute bulk reactivate
   * @private
   */
  async _executeReactivate(operation, userIds, adminUserId, adminRole, pool) {
    const results = {
      operationId: operation.id,
      type: operation.type,
      totalUsers: userIds.length,
      successCount: 0,
      failureCount: 0,
      errors: [],
      reactivatedUsers: [],
    };

    for (const userId of userIds) {
      try {
        await pool.query('BEGIN');

        // Check if suspended
        const checkQuery = `
          SELECT id, is_suspended FROM users WHERE id = $1
            `;
        const checkResult = await pool.query(checkQuery, [userId]);

        if (checkResult.rows.length === 0) {
          throw new Error('User not found');
        }

        if (!checkResult.rows[0].is_suspended) {
          operation.processedUsers++;
          continue;
        }

        // Reactivate user
        const reactivateQuery = `
          UPDATE users 
          SET is_suspended = false, suspended_at = NULL, suspension_reason = NULL
          WHERE id = $1
            `;
        await pool.query(reactivateQuery, [userId]);

        // Log action
        await logAdminAction({
          adminUserId,
          adminRole,
          action: 'bulk_user_reactivate',
          resourceType: 'user',
          resourceId: userId,
          affectedUserId: userId,
          details: {
            bulkOperationId: operation.id,
          },
          ipAddress: 'bulk-operation',
          userAgent: 'bulk-operation',
        });

        await pool.query('COMMIT');

        operation.successCount++;
        results.reactivatedUsers.push(userId);
      } catch (error) {
        await pool.query('ROLLBACK').catch(() => {});
        operation.failureCount++;
        results.errors.push({
          userId,
          error: error.message,
        });
      }

      operation.processedUsers++;
    }

    results.successCount = operation.successCount;
    results.failureCount = operation.failureCount;
    return results;
  }

  /**
   * Execute bulk delete
   * @private
   */
  async _executeDelete(
    operation,
    userIds,
    operationData,
    adminUserId,
    adminRole,
    pool,
  ) {
    const { softDelete = true } = operationData;
    const results = {
      operationId: operation.id,
      type: operation.type,
      totalUsers: userIds.length,
      successCount: 0,
      failureCount: 0,
      errors: [],
      deletedUsers: [],
    };

    for (const userId of userIds) {
      try {
        await pool.query('BEGIN');

        if (softDelete) {
          // Soft delete
          const deleteQuery = `
            UPDATE users 
            SET deleted_at = NOW()
            WHERE id = $1
            `;
          await pool.query(deleteQuery, [userId]);
        } else {
          // Hard delete - cascade delete related data
          await pool.query('DELETE FROM user_sessions WHERE user_id = $1', [
            userId,
          ]);
          await pool.query('DELETE FROM subscriptions WHERE user_id = $1', [
            userId,
          ]);
          await pool.query('DELETE FROM users WHERE id = $1', [userId]);
        }

        // Log action
        await logAdminAction({
          adminUserId,
          adminRole,
          action: 'bulk_user_delete',
          resourceType: 'user',
          resourceId: userId,
          affectedUserId: userId,
          details: {
            softDelete,
            bulkOperationId: operation.id,
          },
          ipAddress: 'bulk-operation',
          userAgent: 'bulk-operation',
        });

        await pool.query('COMMIT');

        operation.successCount++;
        results.deletedUsers.push(userId);
      } catch (error) {
        await pool.query('ROLLBACK').catch(() => {});
        operation.failureCount++;
        results.errors.push({
          userId,
          error: error.message,
        });
      }

      operation.processedUsers++;
    }

    results.successCount = operation.successCount;
    results.failureCount = operation.failureCount;
    return results;
  }

  /**
   * Get operation status
   */
  getOperationStatus(operationId) {
    const operation = this.operations.get(operationId);

    if (!operation) {
      return null;
    }

    return {
      operationId: operation.id,
      type: operation.type,
      status: operation.status,
      totalUsers: operation.totalUsers,
      processedUsers: operation.processedUsers,
      successCount: operation.successCount,
      failureCount: operation.failureCount,
      progress: Math.round(
        (operation.processedUsers / operation.totalUsers) * 100,
      ),
      createdAt: operation.createdAt,
      startedAt: operation.startedAt,
      completedAt: operation.completedAt,
      errors: operation.errors,
    };
  }

  /**
   * Get operation history
   */
  getOperationHistory(limit = 50) {
    const operations = Array.from(this.operations.values())
      .sort((a, b) => b.createdAt - a.createdAt)
      .slice(0, limit)
      .map((op) => ({
        operationId: op.id,
        type: op.type,
        status: op.status,
        totalUsers: op.totalUsers,
        successCount: op.successCount,
        failureCount: op.failureCount,
        createdAt: op.createdAt,
        completedAt: op.completedAt,
      }));

    return operations;
  }
}

export const bulkOperationsService = new BulkOperationsService();
