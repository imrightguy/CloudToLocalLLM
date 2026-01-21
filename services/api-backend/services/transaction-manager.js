/**
 * Transaction Management Service
 *
 * Provides utilities for managing database transactions with ACID compliance.
 * Handles transaction lifecycle, error recovery, and logging.
 *
 * Requirements: 9.4 (Transaction management for data consistency)
 */

import logger from '../logger.js';
import { getClient } from '../database/db-pool.js';

/**
 * Transaction isolation levels
 */
export const IsolationLevel = {
  READ_UNCOMMITTED: 'READ UNCOMMITTED',
  READ_COMMITTED: 'READ COMMITTED',
  REPEATABLE_READ: 'REPEATABLE READ',
  SERIALIZABLE: 'SERIALIZABLE',
};

/**
 * Transaction state enum
 */
export const TransactionState = {
  IDLE: 'idle',
  ACTIVE: 'active',
  COMMITTED: 'committed',
  ROLLED_BACK: 'rolled_back',
  FAILED: 'failed',
};

/**
 * Transaction context class
 * Manages a single database transaction with automatic cleanup
 */
export class Transaction {
  constructor(client, isolationLevel = IsolationLevel.READ_COMMITTED) {
    this.client = client;
    this.isolationLevel = isolationLevel;
    this.state = TransactionState.IDLE;
    this.startTime = null;
    this.endTime = null;
    this.queries = [];
    this.savepoints = [];
    this.transactionId = this._generateTransactionId();
  }

  /**
   * Generate unique transaction ID for logging
   * @private
   * @returns {string} Transaction ID
   */
  _generateTransactionId() {
    return `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Begin the transaction
   * @returns {Promise<void>}
   */
  async begin() {
    try {
      this.startTime = Date.now();
      this.state = TransactionState.ACTIVE;

      // Set isolation level and begin transaction
      await this.client.query(`BEGIN ISOLATION LEVEL ${this.isolationLevel}`);

      logger.debug('🟢 [Transaction] Transaction started', {
        transactionId: this.transactionId,
        isolationLevel: this.isolationLevel,
      });
    } catch (error) {
      this.state = TransactionState.FAILED;
      logger.error('🔴 [Transaction] Failed to begin transaction', {
        transactionId: this.transactionId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Execute a query within the transaction
   * @param {string} text - SQL query text
   * @param {Array} params - Query parameters
   * @returns {Promise<Object>} Query result
   */
  async query(text, params = []) {
    if (this.state !== TransactionState.ACTIVE) {
      throw new Error(
        `Cannot execute query in ${this.state} transaction (ID: ${this.transactionId})`,
      );
    }

    try {
      const result = await this.client.query(text, params);

      // Log query execution
      this.queries.push({
        text,
        params,
        timestamp: new Date().toISOString(),
        rowCount: result.rowCount,
      });

      logger.debug('🟡 [Transaction] Query executed', {
        transactionId: this.transactionId,
        queryCount: this.queries.length,
        rowCount: result.rowCount,
      });

      return result;
    } catch (error) {
      this.state = TransactionState.FAILED;
      logger.error('🔴 [Transaction] Query failed', {
        transactionId: this.transactionId,
        error: error.message,
        query: text,
      });
      throw error;
    }
  }

  /**
   * Create a savepoint for partial rollback
   * @param {string} name - Savepoint name
   * @returns {Promise<void>}
   */
  async savepoint(name) {
    if (this.state !== TransactionState.ACTIVE) {
      throw new Error(
        `Cannot create savepoint in ${this.state} transaction (ID: ${this.transactionId})`,
      );
    }

    try {
      await this.client.query(`SAVEPOINT ${name}`);
      this.savepoints.push({
        name,
        timestamp: new Date().toISOString(),
      });

      logger.debug('🟡 [Transaction] Savepoint created', {
        transactionId: this.transactionId,
        savepointName: name,
      });
    } catch (error) {
      logger.error('🔴 [Transaction] Failed to create savepoint', {
        transactionId: this.transactionId,
        savepointName: name,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Rollback to a savepoint
   * @param {string} name - Savepoint name
   * @returns {Promise<void>}
   */
  async rollbackToSavepoint(name) {
    if (this.state !== TransactionState.ACTIVE) {
      throw new Error(
        `Cannot rollback to savepoint in ${this.state} transaction (ID: ${this.transactionId})`,
      );
    }

    try {
      await this.client.query(`ROLLBACK TO SAVEPOINT ${name}`);

      logger.debug('🟡 [Transaction] Rolled back to savepoint', {
        transactionId: this.transactionId,
        savepointName: name,
      });
    } catch (error) {
      logger.error('🔴 [Transaction] Failed to rollback to savepoint', {
        transactionId: this.transactionId,
        savepointName: name,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Commit the transaction
   * @returns {Promise<void>}
   */
  async commit() {
    if (this.state !== TransactionState.ACTIVE) {
      throw new Error(
        `Cannot commit ${this.state} transaction (ID: ${this.transactionId})`,
      );
    }

    try {
      await this.client.query('COMMIT');
      this.state = TransactionState.COMMITTED;
      this.endTime = Date.now();

      const duration = this.endTime - this.startTime;

      logger.info('✅ [Transaction] Transaction committed', {
        transactionId: this.transactionId,
        duration: `${duration}ms`,
        queryCount: this.queries.length,
      });
    } catch (error) {
      this.state = TransactionState.FAILED;
      logger.error('🔴 [Transaction] Failed to commit transaction', {
        transactionId: this.transactionId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Rollback the transaction
   * @returns {Promise<void>}
   */
  async rollback() {
    if (this.state === TransactionState.COMMITTED) {
      logger.warn('⚠️ [Transaction] Cannot rollback committed transaction', {
        transactionId: this.transactionId,
      });
      return;
    }

    try {
      if (this.state === TransactionState.ACTIVE) {
        await this.client.query('ROLLBACK');
      }

      this.state = TransactionState.ROLLED_BACK;
      this.endTime = Date.now();

      const duration = this.endTime - this.startTime;

      logger.info('🔄 [Transaction] Transaction rolled back', {
        transactionId: this.transactionId,
        duration: `${duration}ms`,
        queryCount: this.queries.length,
      });
    } catch (error) {
      this.state = TransactionState.FAILED;
      logger.error('🔴 [Transaction] Failed to rollback transaction', {
        transactionId: this.transactionId,
        error: error.message,
      });
      throw error;
    }
  }

  /**
   * Get transaction metadata
   * @returns {Object} Transaction metadata
   */
  getMetadata() {
    return {
      transactionId: this.transactionId,
      state: this.state,
      isolationLevel: this.isolationLevel,
      startTime: this.startTime,
      endTime: this.endTime,
      duration: this.endTime ? this.endTime - this.startTime : null,
      queryCount: this.queries.length,
      savepointCount: this.savepoints.length,
    };
  }
}

/**
 * Transaction Manager Service
 * Provides high-level transaction management with automatic cleanup
 */
export class TransactionManager {
  /**
   * Execute a function within a transaction
   * Automatically handles commit/rollback
   *
   * @param {Function} callback - Async function to execute within transaction
   * @param {Object} options - Transaction options
   * @returns {Promise<*>} Result from callback
   */
  static async withTransaction(callback, options = {}) {
    const {
      isolationLevel = IsolationLevel.READ_COMMITTED,
      maxRetries = 3,
      retryDelay = 100,
    } = options;

    let lastError;
    let attempt = 0;

    while (attempt < maxRetries) {
      const client = await getClient();
      const transaction = new Transaction(client, isolationLevel);

      try {
        await transaction.begin();

        // Execute callback with transaction context
        const result = await callback(transaction);

        // Commit transaction
        await transaction.commit();

        logger.debug(
          '✅ [TransactionManager] Transaction completed successfully',
          {
            transactionId: transaction.transactionId,
            attempt: attempt + 1,
          },
        );

        return result;
      } catch (error) {
        lastError = error;
        attempt++;

        // Attempt rollback
        try {
          await transaction.rollback();
        } catch (rollbackError) {
          logger.error('🔴 [TransactionManager] Rollback failed', {
            transactionId: transaction.transactionId,
            error: rollbackError.message,
          });
        }

        // Retry logic for serialization conflicts
        if (error.code === '40P01' && attempt < maxRetries) {
          logger.warn(
            '⚠️ [TransactionManager] Serialization conflict, retrying',
            {
              attempt: attempt + 1,
              maxRetries,
              delay: `${retryDelay * attempt}ms`,
            },
          );

          await new Promise((resolve) =>
            setTimeout(resolve, retryDelay * attempt),
          );
        } else {
          break;
        }
      } finally {
        // Always release the client
        try {
          client.release();
        } catch (releaseError) {
          logger.error('🔴 [TransactionManager] Failed to release client', {
            error: releaseError.message,
          });
        }
      }
    }

    // All retries exhausted
    logger.error('🔴 [TransactionManager] Transaction failed after retries', {
      attempts: attempt,
      maxRetries,
      error: lastError?.message,
    });

    throw lastError;
  }

  /**
   * Execute multiple queries in a transaction
   * Useful for batch operations
   *
   * @param {Array<Object>} queries - Array of {text, params} objects
   * @param {Object} options - Transaction options
   * @returns {Promise<Array>} Array of query results
   */
  static async executeQueries(queries, options = {}) {
    return this.withTransaction(async (transaction) => {
      const results = [];

      for (const { text, params } of queries) {
        const result = await transaction.query(text, params);
        results.push(result);
      }

      return results;
    }, options);
  }

  /**
   * Execute a transaction with automatic retry on serialization conflicts
   * Useful for high-concurrency scenarios
   *
   * @param {Function} callback - Async function to execute
   * @param {Object} options - Transaction options
   * @returns {Promise<*>} Result from callback
   */
  static async withRetry(callback, options = {}) {
    const {
      maxRetries = 5,
      retryDelay = 50,
      backoffMultiplier = 2,
      ...transactionOptions
    } = options;

    let lastError;

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        return await this.withTransaction(callback, {
          ...transactionOptions,
          maxRetries: 1, // Disable internal retries
        });
      } catch (error) {
        lastError = error;

        // Only retry on serialization conflicts
        if (error.code !== '40P01') {
          throw error;
        }

        if (attempt < maxRetries - 1) {
          const delay = retryDelay * Math.pow(backoffMultiplier, attempt);
          logger.warn(
            '⚠️ [TransactionManager] Retrying transaction with backoff',
            {
              attempt: attempt + 1,
              maxRetries,
              delay: `${delay}ms`,
            },
          );

          await new Promise((resolve) => setTimeout(resolve, delay));
        }
      }
    }

    throw lastError;
  }
}

// Export default
export default {
  Transaction,
  TransactionManager,
  IsolationLevel,
  TransactionState,
};
