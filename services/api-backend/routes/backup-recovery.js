/**
 * Database Backup and Recovery Routes
 *
 * Provides REST API endpoints for managing database backups and recovery.
 * Includes endpoints for creating backups, verifying integrity, and restoring.
 *
 * Requirements: 9.6 (Database backup and recovery procedures)
 */

import express from 'express';
import { z } from 'zod';
import logger from '../logger.js';
import { getBackupRecoveryService } from '../services/backup-recovery-service.js';
import { authenticateJWT, requireAdmin } from '../middleware/auth.js';
import { validateSchema } from '../middleware/schema-validation.js';

const router = express.Router();
const backupService = getBackupRecoveryService();

const backupIdParamSchema = {
  params: z.object({
    backupId: z.string().uuid({ message: 'backupId must be a valid UUID' }),
  }),
};

const restoreBackupBodySchema = {
  params: z.object({
    backupId: z.string().uuid({ message: 'backupId must be a valid UUID' }),
  }),
  body: z.object({
    confirmed: z.boolean({ required_error: 'confirmed is required' }),
  }),
};

/**
 * POST /backup/create
 * Create a full database backup
 * Admin only
 */
router.post(
  '/backup/create',
  authenticateJWT,
  requireAdmin,
  async (req, res) => {
    const correlationId = req.correlationId || 'unknown';

    try {
      logger.info('🔵 [BackupRecovery] Creating full backup', {
        correlationId,
        userId: req.user?.sub,
      });

      const backup = await backupService.createFullBackup();

      logger.info('✅ [BackupRecovery] Backup created successfully', {
        correlationId,
        backupId: backup.backupId,
        size: backup.size,
      });

      res.status(201).json({
        success: true,
        backup,
        message: 'Backup created successfully',
      });
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Failed to create backup', {
        correlationId,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        error: 'Failed to create backup',
        message: error.message,
        correlationId,
      });
    }
  },
);

/**
 * GET /backup/list
 * List all available backups
 * Admin only
 */
router.get('/backup/list', authenticateJWT, requireAdmin, async (req, res) => {
  const correlationId = req.correlationId || 'unknown';

  try {
    logger.debug('📋 [BackupRecovery] Listing backups', {
      correlationId,
      userId: req.user?.sub,
    });

    const backups = await backupService.listBackups();

    res.status(200).json({
      success: true,
      backups,
      count: backups.length,
      message: 'Backups retrieved successfully',
    });
  } catch (error) {
    logger.error('🔴 [BackupRecovery] Failed to list backups', {
      correlationId,
      error: error.message,
    });

    res.status(500).json({
      success: false,
      error: 'Failed to list backups',
      message: error.message,
      correlationId,
    });
  }
});

/**
 * GET /backup/:backupId
 * Get backup metadata
 * Admin only
 */
router.get(
  '/backup/:backupId',
  authenticateJWT,
  requireAdmin,
  validateSchema(backupIdParamSchema),
  async (req, res) => {
    const correlationId = req.correlationId || 'unknown';
    const { backupId } = req.params;

    try {
      logger.debug('📋 [BackupRecovery] Getting backup metadata', {
        correlationId,
        backupId,
        userId: req.user?.sub,
      });

      const backup = await backupService.getBackupMetadata(backupId);

      res.status(200).json({
        success: true,
        backup,
        message: 'Backup metadata retrieved successfully',
      });
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Failed to get backup metadata', {
        correlationId,
        backupId,
        error: error.message,
      });

      res.status(404).json({
        success: false,
        error: 'Backup not found',
        message: error.message,
        correlationId,
      });
    }
  },
);

/**
 * POST /backup/:backupId/verify
 * Verify backup integrity
 * Admin only
 */
router.post(
  '/backup/:backupId/verify',
  authenticateJWT,
  requireAdmin,
  validateSchema(backupIdParamSchema),
  async (req, res) => {
    const correlationId = req.correlationId || 'unknown';
    const { backupId } = req.params;

    try {
      logger.info('🔵 [BackupRecovery] Verifying backup', {
        correlationId,
        backupId,
        userId: req.user?.sub,
      });

      const verification = await backupService.verifyBackup(backupId);

      logger.info('✅ [BackupRecovery] Backup verified successfully', {
        correlationId,
        backupId,
        verified: verification.verified,
      });

      res.status(200).json({
        success: true,
        verification,
        message: 'Backup verified successfully',
      });
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Backup verification failed', {
        correlationId,
        backupId,
        error: error.message,
      });

      res.status(400).json({
        success: false,
        error: 'Backup verification failed',
        message: error.message,
        correlationId,
      });
    }
  },
);

/**
 * POST /backup/:backupId/restore
 * Restore database from backup
 * Admin only - requires confirmation
 */
router.post(
  '/backup/:backupId/restore',
  authenticateJWT,
  requireAdmin,
  validateSchema(restoreBackupBodySchema),
  async (req, res) => {
    const correlationId = req.correlationId || 'unknown';
    const { backupId } = req.params;

    try {
      logger.warn('🟡 [BackupRecovery] Starting database restoration', {
        correlationId,
        backupId,
        userId: req.user?.sub,
      });

      const recovery = await backupService.restoreFromBackup(backupId);

      logger.info('✅ [BackupRecovery] Database restored successfully', {
        correlationId,
        backupId,
        recoveryId: recovery.recoveryId,
        duration: recovery.duration,
      });

      res.status(200).json({
        success: true,
        recovery,
        message: 'Database restored successfully',
      });
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Database restoration failed', {
        correlationId,
        backupId,
        error: error.message,
      });

      res.status(500).json({
        success: false,
        error: 'Database restoration failed',
        message: error.message,
        correlationId,
      });
    }
  },
);

/**
 * DELETE /backup/:backupId
 * Delete a backup
 * Admin only
 */
router.delete(
  '/backup/:backupId',
  authenticateJWT,
  requireAdmin,
  validateSchema(backupIdParamSchema),
  async (req, res) => {
    const correlationId = req.correlationId || 'unknown';
    const { backupId } = req.params;

    try {
      logger.info('🔵 [BackupRecovery] Deleting backup', {
        correlationId,
        backupId,
        userId: req.user?.sub,
      });

      await backupService.deleteBackup(backupId);

      logger.info('✅ [BackupRecovery] Backup deleted successfully', {
        correlationId,
        backupId,
      });

      res.status(200).json({
        success: true,
        message: 'Backup deleted successfully',
      });
    } catch (error) {
      logger.error('🔴 [BackupRecovery] Failed to delete backup', {
        correlationId,
        backupId,
        error: error.message,
      });

      res.status(404).json({
        success: false,
        error: 'Backup not found',
        message: error.message,
        correlationId,
      });
    }
  },
);

export default router;
