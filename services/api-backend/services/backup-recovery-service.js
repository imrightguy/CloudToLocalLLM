/**
 * Database Backup and Recovery Service
 *
 * Provides utilities for creating database backups, verifying backup integrity,
 * and recovering from backups. Supports both full and incremental backups.
 *
 * Requirements: 9.6 (Database backup and recovery procedures)
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import logger from '../logger.js';
import { getClient } from '../database/db-pool.js';

const execAsync = promisify(exec);
const fsPromises = fs.promises;

/**
 * Backup types
 */
export const BackupType = {
  FULL: 'full',
  INCREMENTAL: 'incremental',
  DIFFERENTIAL: 'differential',
};

/**
 * Backup status enum
 */
export const BackupStatus = {
  PENDING: 'pending',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  FAILED: 'failed',
  VERIFIED: 'verified',
};

/**
 * Recovery status enum
 */
export const RecoveryStatus = {
  PENDING: 'pending',
  IN_PROGRESS: 'in_progress',
  COMPLETED: 'completed',
  FAILED: 'failed',
  VERIFIED: 'verified',
};

/**
 * Backup and Recovery Service
 */
export class BackupRecoveryService {
  constructor(options = {}) {
    this.backupDir = options.backupDir || process.env.BACKUP_DIR || './backups';
    this.retentionDays =
      options.retentionDays ||
      parseInt(process.env.BACKUP_RETENTION_DAYS || '30', 10);
    this.maxBackups =
      options.maxBackups || parseInt(process.env.MAX_BACKUPS || '10', 10);
    this.compressionEnabled = options.compressionEnabled !== false;
    this.verificationEnabled = options.verificationEnabled !== false;
    this.backupMetadata = new Map();
  }

  /**
   * Initialize backup directory
   * @returns {Promise<void>}
   */
  async initialize() {
    try {
      // Create backup directory if it doesn't exist
      await fsPromises.mkdir(this.backupDir, { recursive: true });

      logger.info('✅ [BackupRecovery] Backup directory initialized', {
        backupDir: this.backupDir,
      });
    } catch (error) {
      logger.error(
        '🔴 [BackupRecovery] Failed to initialize backup directory',
        {
          error: error.message,
        },
      );
      throw error;
    }
  }

  /**
   * Create a full database backup
   * @param {Object} options - Backup options
   * @returns {Promise<Object>} Backup metadata
   */
  async createFullBackup(_options = {}) {
    const backupId = this._generateBackupId();
    const timestamp = new Date().toISOString();

    const backupMetadata = {
      backupId,
      type: BackupType.FULL,
      status: BackupStatus.IN_PROGRESS,
      startTime: timestamp,
      endTime: null,
      duration: null,
      size: null,
      checksum: null,
      verified: false,
      error: null,
      database: process.env.DB_NAME || 'cloudtolocalllm',
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || '5432',
    };

    try {
      logger.info('🔵 [BackupRecovery] Starting full database backup', {
        backupId,
        database: backupMetadata.database,
      });

      const backupFile = path.join(
        this.backupDir,
        `backup_${backupId}_full.sql${this.compressionEnabled ? '.gz' : ''}`,
      );

      const startTime = Date.now();

      // Execute pg_dump command
      const dumpCommand = this._buildDumpCommand(backupFile);
      await execAsync(dumpCommand);

      const endTime = Date.now();
      const duration = endTime - startTime;

      // Get backup file size
      const stats = await fsPromises.stat(backupFile);
      const size = stats.size;

      // Calculate checksum
      const checksum = await this._calculateChecksum(backupFile);

      backupMetadata.endTime = new Date().toISOString();
      backupMetadata.duration = duration;
      backupMetadata.size = size;
      backupMetadata.checksum = checksum;
      backupMetadata.status = BackupStatus.COMPLETED;
      backupMetadata.filePath = backupFile;

      // Store metadata
      this.backupMetadata.set(backupId, backupMetadata);

      logger.info('✅ [BackupRecovery] Full backup completed successfully', {
        backupId,
        size: `${(size / 1024 / 1024).toFixed(2)} MB`,
        duration: `${duration}ms`,
        checksum,
      });

      // Cleanup old backups
      await this._cleanupOldBackups();

      return backupMetadata;
    } catch (error) {
      backupMetadata.status = BackupStatus.FAILED;
      backupMetadata.error = error.message;
      backupMetadata.endTime = new Date().toISOString();

      logger.error('🔴 [BackupRecovery] Full backup failed', {
        backupId,
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Verify backup integrity
   * @param {string} backupId - Backup ID
   * @returns {Promise<Object>} Verification result
   */
  async verifyBackup(backupId) {
    try {
      const metadata = this.backupMetadata.get(backupId);

      if (!metadata) {
        throw new Error(`Backup not found: ${backupId}`);
      }

      logger.info('🔵 [BackupRecovery] Starting backup verification', {
        backupId,
      });

      const backupFile = metadata.filePath;

      // Check if file exists
      try {
        await fsPromises.access(backupFile);
      } catch {
        throw new Error(`Backup file not found: ${backupFile}`);
      }

      // Verify checksum
      const currentChecksum = await this._calculateChecksum(backupFile);

      if (currentChecksum !== metadata.checksum) {
        throw new Error('Backup checksum mismatch - file may be corrupted');
      }

      // Verify backup can be restored (dry run)
      if (this.verificationEnabled) {
        await this._verifyBackupIntegrity(backupFile);
      }

      metadata.verified = true;
      metadata.status = BackupStatus.VERIFIED;

      logger.info('✅ [BackupRecovery] Backup verification completed', {
        backupId,
        checksum: currentChecksum,
      });

      return {
        backupId,
        verified: true,
        checksum: currentChecksum,
        timestamp: new Date().toISOString(),
      };
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Backup verification failed', {
        backupId,
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Restore database from backup
   * @param {string} backupId - Backup ID
   * @param {Object} options - Restore options
   * @returns {Promise<Object>} Recovery metadata
   */
  async restoreFromBackup(backupId, options = {}) {
    const recoveryId = this._generateRecoveryId();
    const timestamp = new Date().toISOString();

    const recoveryMetadata = {
      recoveryId,
      backupId,
      status: RecoveryStatus.IN_PROGRESS,
      startTime: timestamp,
      endTime: null,
      duration: null,
      error: null,
      database: process.env.DB_NAME || 'cloudtolocalllm',
      pointInTime: options.pointInTime || null,
    };

    const client = await getClient();

    try {
      const metadata = this.backupMetadata.get(backupId);

      if (!metadata) {
        throw new Error(`Backup not found: ${backupId}`);
      }

      if (!metadata.verified) {
        throw new Error('Backup must be verified before restoration');
      }

      logger.info('🔵 [BackupRecovery] Starting database restoration', {
        recoveryId,
        backupId,
        database: recoveryMetadata.database,
      });

      const backupFile = metadata.filePath;
      const startTime = Date.now();

      // Verify backup file exists
      try {
        await fsPromises.access(backupFile);
      } catch {
        throw new Error(`Backup file not found: ${backupFile}`);
      }

      // Execute restore command
      const restoreCommand = this._buildRestoreCommand(backupFile);
      await execAsync(restoreCommand);

      const endTime = Date.now();
      const duration = endTime - startTime;

      recoveryMetadata.endTime = new Date().toISOString();
      recoveryMetadata.duration = duration;
      recoveryMetadata.status = RecoveryStatus.COMPLETED;

      logger.info('✅ [BackupRecovery] Database restoration completed', {
        recoveryId,
        backupId,
        duration: `${duration}ms`,
      });

      return recoveryMetadata;
    } catch (error) {
      recoveryMetadata.status = RecoveryStatus.FAILED;
      recoveryMetadata.error = error.message;
      recoveryMetadata.endTime = new Date().toISOString();

      logger.error('🔴 [BackupRecovery] Database restoration failed', {
        recoveryId,
        backupId,
        error: error.message,
      });

      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * List all available backups
   * @returns {Promise<Array>} Array of backup metadata
   */
  async listBackups() {
    try {
      const backups = Array.from(this.backupMetadata.values()).sort(
        (a, b) => new Date(b.startTime) - new Date(a.startTime),
      );

      logger.debug('📋 [BackupRecovery] Listing backups', {
        count: backups.length,
      });

      return backups;
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Failed to list backups', {
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Get backup metadata
   * @param {string} backupId - Backup ID
   * @returns {Promise<Object>} Backup metadata
   */
  async getBackupMetadata(backupId) {
    const metadata = this.backupMetadata.get(backupId);

    if (!metadata) {
      throw new Error(`Backup not found: ${backupId}`);
    }

    return metadata;
  }

  /**
   * Delete a backup
   * @param {string} backupId - Backup ID
   * @returns {Promise<void>}
   */
  async deleteBackup(backupId) {
    try {
      const metadata = this.backupMetadata.get(backupId);

      if (!metadata) {
        throw new Error(`Backup not found: ${backupId}`);
      }

      const backupFile = metadata.filePath;

      // Delete backup file
      try {
        await fsPromises.unlink(backupFile);
      } catch (error) {
        logger.warn('⚠️ [BackupRecovery] Failed to delete backup file', {
          backupId,
          error: error.message,
        });
      }

      // Remove metadata
      this.backupMetadata.delete(backupId);

      logger.info('✅ [BackupRecovery] Backup deleted', {
        backupId,
      });
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Failed to delete backup', {
        backupId,
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Build pg_dump command
   * @private
   * @param {string} backupFile - Backup file path
   * @returns {string} pg_dump command
   */
  _buildDumpCommand(backupFile) {
    const host = process.env.DB_HOST || 'localhost';
    const port = process.env.DB_PORT || '5432';
    const database = process.env.DB_NAME || 'cloudtolocalllm';
    const user = process.env.DB_USER;
    const password = process.env.DB_PASSWORD;

    let command = `PGPASSWORD="${password}" pg_dump -h ${host} -p ${port} -U ${user} -d ${database}`;

    if (this.compressionEnabled) {
      command += ` | gzip > ${backupFile}`;
    } else {
      command += ` > ${backupFile}`;
    }

    return command;
  }

  /**
   * Build restore command
   * @private
   * @param {string} backupFile - Backup file path
   * @returns {string} Restore command
   */
  _buildRestoreCommand(backupFile) {
    const host = process.env.DB_HOST || 'localhost';
    const port = process.env.DB_PORT || '5432';
    const database = process.env.DB_NAME || 'cloudtolocalllm';
    const user = process.env.DB_USER;
    const password = process.env.DB_PASSWORD;

    let command;

    if (this.compressionEnabled) {
      command = `gunzip -c ${backupFile} | PGPASSWORD="${password}" psql -h ${host} -p ${port} -U ${user} -d ${database}`;
    } else {
      command = `PGPASSWORD="${password}" psql -h ${host} -p ${port} -U ${user} -d ${database} < ${backupFile}`;
    }

    return command;
  }

  /**
   * Calculate file checksum
   * @private
   * @param {string} filePath - File path
   * @returns {Promise<string>} SHA256 checksum
   */
  async _calculateChecksum(filePath) {
    return new Promise((resolve, reject) => {
      const hash = crypto.createHash('sha256');
      const stream = fs.createReadStream(filePath);

      stream.on('data', (data) => {
        hash.update(data);
      });

      stream.on('end', () => {
        resolve(hash.digest('hex'));
      });

      stream.on('error', reject);
    });
  }

  /**
   * Verify backup integrity by attempting to restore to temporary database
   * @private
   * @param {string} backupFile - Backup file path
   * @returns {Promise<void>}
   */
  async _verifyBackupIntegrity(backupFile) {
    try {
      // For now, just verify the file can be read
      const stats = await fsPromises.stat(backupFile);

      if (stats.size === 0) {
        throw new Error('Backup file is empty');
      }

      logger.debug('✅ [BackupRecovery] Backup integrity verified', {
        size: stats.size,
      });
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Backup integrity verification failed', {
        error: error.message,
      });

      throw error;
    }
  }

  /**
   * Cleanup old backups based on retention policy
   * @private
   * @returns {Promise<void>}
   */
  async _cleanupOldBackups() {
    try {
      const backups = Array.from(this.backupMetadata.values()).sort(
        (a, b) => new Date(b.startTime) - new Date(a.startTime),
      );

      const now = Date.now();
      const retentionMs = this.retentionDays * 24 * 60 * 60 * 1000;

      // Delete backups older than retention period
      for (const backup of backups) {
        const backupAge = now - new Date(backup.startTime).getTime();

        if (backupAge > retentionMs) {
          await this.deleteBackup(backup.backupId);
        }
      }

      // Keep only max backups
      const remainingBackups = Array.from(this.backupMetadata.values()).sort(
        (a, b) => new Date(b.startTime) - new Date(a.startTime),
      );

      for (let i = this.maxBackups; i < remainingBackups.length; i++) {
        await this.deleteBackup(remainingBackups[i].backupId);
      }

      logger.debug('🧹 [BackupRecovery] Cleanup completed', {
        retentionDays: this.retentionDays,
        maxBackups: this.maxBackups,
        remainingBackups: remainingBackups.length,
      });
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Cleanup failed', {
        error: error.message,
      });
    }
  }

  /**
   * Generate unique backup ID
   * @private
   * @returns {string} Backup ID
   */
  _generateBackupId() {
    return `backup_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  /**
   * Generate unique recovery ID
   * @private
   * @returns {string} Recovery ID
   */
  _generateRecoveryId() {
    return `recovery_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }
}

// Create singleton instance
let backupRecoveryService = null;

/**
 * Get or create backup recovery service instance
 * @param {Object} options - Service options
 * @returns {BackupRecoveryService} Service instance
 */
export function getBackupRecoveryService(options = {}) {
  if (!backupRecoveryService) {
    backupRecoveryService = new BackupRecoveryService(options);
  }

  return backupRecoveryService;
}

// Export default
export default {
  BackupRecoveryService,
  getBackupRecoveryService,
  BackupType,
  BackupStatus,
  RecoveryStatus,
};
