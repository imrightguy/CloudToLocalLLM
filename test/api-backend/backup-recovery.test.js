/**
 * Backup and Recovery Service Tests
 *
 * Tests for database backup creation, verification, and recovery procedures.
 * Validates backup integrity, recovery functionality, and error handling.
 *
 * Requirements: 9.6 (Database backup and recovery procedures)
 */

import {
  BackupRecoveryService,
  BackupType,
  BackupStatus,
} from "../../services/api-backend/services/backup-recovery-service.js";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const testBackupDir = path.join(
  __dirname,
  "../../services/api-backend/test-backups",
);

describe("BackupRecoveryService", () => {
  let service;

  beforeAll(async () => {
    // Create test backup directory
    if (!fs.existsSync(testBackupDir)) {
      fs.mkdirSync(testBackupDir, { recursive: true });
    }

    service = new BackupRecoveryService({
      backupDir: testBackupDir,
      retentionDays: 30,
      maxBackups: 5,
      compressionEnabled: false,
      verificationEnabled: true,
    });

    await service.initialize();
  });

  afterAll(async () => {
    // Cleanup test backup directory
    if (fs.existsSync(testBackupDir)) {
      const files = fs.readdirSync(testBackupDir);
      for (const file of files) {
        fs.unlinkSync(path.join(testBackupDir, file));
      }
      fs.rmdirSync(testBackupDir);
    }
  });

  describe("Backup Creation", () => {
    test("should create a full backup with metadata", async () => {
      // Create a mock backup file for testing
      const backupId = service._generateBackupId();
      const backupFile = path.join(
        testBackupDir,
        `backup_${backupId}_full.sql`,
      );

      // Create mock backup file
      fs.writeFileSync(backupFile, "MOCK BACKUP DATA");

      const metadata = {
        backupId,
        type: BackupType.FULL,
        status: BackupStatus.COMPLETED,
        startTime: new Date().toISOString(),
        endTime: new Date().toISOString(),
        duration: 1000,
        size: 16,
        checksum: "mock-checksum",
        verified: false,
        error: null,
        database: "CloudToLocalLLM",
        host: "localhost",
        port: "5432",
        filePath: backupFile,
      };

      service.backupMetadata.set(backupId, metadata);

      const backup = await service.getBackupMetadata(backupId);

      expect(backup).toBeDefined();
      expect(backup.backupId).toBe(backupId);
      expect(backup.type).toBe(BackupType.FULL);
      expect(backup.status).toBe(BackupStatus.COMPLETED);
      expect(backup.size).toBe(16);
    });

    test("should generate unique backup IDs", () => {
      const id1 = service._generateBackupId();
      const id2 = service._generateBackupId();

      expect(id1).not.toBe(id2);
      expect(id1).toMatch(/^backup_\d+_[a-z0-9]+$/);
      expect(id2).toMatch(/^backup_\d+_[a-z0-9]+$/);
    });
  });

  describe("Backup Verification", () => {
    test("should verify backup integrity with checksum", async () => {
      const backupId = service._generateBackupId();
      const backupFile = path.join(
        testBackupDir,
        `backup_${backupId}_full.sql`,
      );

      // Create mock backup file
      const backupData = "MOCK BACKUP DATA FOR VERIFICATION";
      fs.writeFileSync(backupFile, backupData);

      // Calculate checksum
      const checksum = await service._calculateChecksum(backupFile);

      const metadata = {
        backupId,
        type: BackupType.FULL,
        status: BackupStatus.COMPLETED,
        startTime: new Date().toISOString(),
        endTime: new Date().toISOString(),
        duration: 1000,
        size: backupData.length,
        checksum,
        verified: false,
        error: null,
        database: "CloudToLocalLLM",
        host: "localhost",
        port: "5432",
        filePath: backupFile,
      };

      service.backupMetadata.set(backupId, metadata);

      const verification = await service.verifyBackup(backupId);

      expect(verification).toBeDefined();
      expect(verification.verified).toBe(true);
      expect(verification.checksum).toBe(checksum);
      expect(verification.backupId).toBe(backupId);
    });

    test("should detect corrupted backups", async () => {
      const backupId = service._generateBackupId();
      const backupFile = path.join(
        testBackupDir,
        `backup_${backupId}_full.sql`,
      );

      // Create mock backup file
      const backupData = "MOCK BACKUP DATA";
      fs.writeFileSync(backupFile, backupData);

      // Calculate original checksum

      const metadata = {
        backupId,
        type: BackupType.FULL,
        status: BackupStatus.COMPLETED,
        startTime: new Date().toISOString(),
        endTime: new Date().toISOString(),
        duration: 1000,
        size: backupData.length,
        checksum: "wrong-checksum",
        verified: false,
        error: null,
        database: "CloudToLocalLLM",
        host: "localhost",
        port: "5432",
        filePath: backupFile,
      };

      service.backupMetadata.set(backupId, metadata);

      // Verification should fail due to checksum mismatch
      await expect(service.verifyBackup(backupId)).rejects.toThrow(
        "Backup checksum mismatch",
      );
    });

    test("should fail verification for missing backup file", async () => {
      const backupId = service._generateBackupId();

      const metadata = {
        backupId,
        type: BackupType.FULL,
        status: BackupStatus.COMPLETED,
        startTime: new Date().toISOString(),
        endTime: new Date().toISOString(),
        duration: 1000,
        size: 100,
        checksum: "mock-checksum",
        verified: false,
        error: null,
        database: "CloudToLocalLLM",
        host: "localhost",
        port: "5432",
        filePath: "/nonexistent/backup.sql",
      };

      service.backupMetadata.set(backupId, metadata);

      await expect(service.verifyBackup(backupId)).rejects.toThrow(
        "Backup file not found",
      );
    });
  });

  describe("Backup Listing", () => {
    test("should list all backups sorted by date", async () => {
      // Create multiple mock backups
      const backupIds = [];

      for (let i = 0; i < 3; i++) {
        const backupId = service._generateBackupId();
        const backupFile = path.join(
          testBackupDir,
          `backup_${backupId}_full.sql`,
        );

        fs.writeFileSync(backupFile, `MOCK BACKUP DATA ${i}`);

        const metadata = {
          backupId,
          type: BackupType.FULL,
          status: BackupStatus.COMPLETED,
          startTime: new Date(Date.now() - i * 1000).toISOString(),
          endTime: new Date().toISOString(),
          duration: 1000,
          size: 20,
          checksum: `checksum-${i}`,
          verified: false,
          error: null,
          database: "CloudToLocalLLM",
          host: "localhost",
          port: "5432",
          filePath: backupFile,
        };

        service.backupMetadata.set(backupId, metadata);
        backupIds.push(backupId);
      }

      const backups = await service.listBackups();

      expect(backups.length).toBeGreaterThanOrEqual(3);
      expect(new Date(backups[0].startTime).getTime()).toBeGreaterThanOrEqual(
        new Date(backups[1].startTime).getTime(),
      );
    });

    test("should return empty list when no backups exist", async () => {
      const emptyService = new BackupRecoveryService({
        backupDir: testBackupDir,
      });

      emptyService.backupMetadata.clear();

      const backups = await emptyService.listBackups();

      expect(Array.isArray(backups)).toBe(true);
      expect(backups.length).toBe(0);
    });
  });

  describe("Backup Deletion", () => {
    test("should delete backup and remove metadata", async () => {
      const backupId = service._generateBackupId();
      const backupFile = path.join(
        testBackupDir,
        `backup_${backupId}_full.sql`,
      );

      // Create mock backup file
      fs.writeFileSync(backupFile, "MOCK BACKUP DATA");

      const metadata = {
        backupId,
        type: BackupType.FULL,
        status: BackupStatus.COMPLETED,
        startTime: new Date().toISOString(),
        endTime: new Date().toISOString(),
        duration: 1000,
        size: 16,
        checksum: "mock-checksum",
        verified: false,
        error: null,
        database: "CloudToLocalLLM",
        host: "localhost",
        port: "5432",
        filePath: backupFile,
      };

      service.backupMetadata.set(backupId, metadata);

      // Verify backup exists
      expect(service.backupMetadata.has(backupId)).toBe(true);
      expect(fs.existsSync(backupFile)).toBe(true);

      // Delete backup
      await service.deleteBackup(backupId);

      // Verify backup is deleted
      expect(service.backupMetadata.has(backupId)).toBe(false);
      expect(fs.existsSync(backupFile)).toBe(false);
    });

    test("should fail to delete non-existent backup", async () => {
      const backupId = "nonexistent-backup-id";

      await expect(service.deleteBackup(backupId)).rejects.toThrow(
        "Backup not found",
      );
    });
  });

  describe("Checksum Calculation", () => {
    test("should calculate consistent checksums", async () => {
      const backupFile = path.join(testBackupDir, "checksum-test.sql");
      const testData = "TEST DATA FOR CHECKSUM";

      fs.writeFileSync(backupFile, testData);

      const checksum1 = await service._calculateChecksum(backupFile);
      const checksum2 = await service._calculateChecksum(backupFile);

      expect(checksum1).toBe(checksum2);
      expect(checksum1).toMatch(/^[a-f0-9]{64}$/); // SHA256 hex format

      // Cleanup
      fs.unlinkSync(backupFile);
    });

    test("should produce different checksums for different data", async () => {
      const file1 = path.join(testBackupDir, "checksum-test-1.sql");
      const file2 = path.join(testBackupDir, "checksum-test-2.sql");

      fs.writeFileSync(file1, "DATA 1");
      fs.writeFileSync(file2, "DATA 2");

      const checksum1 = await service._calculateChecksum(file1);
      const checksum2 = await service._calculateChecksum(file2);

      expect(checksum1).not.toBe(checksum2);

      // Cleanup
      fs.unlinkSync(file1);
      fs.unlinkSync(file2);
    });
  });

  describe("Recovery ID Generation", () => {
    test("should generate unique recovery IDs", () => {
      const id1 = service._generateRecoveryId();
      const id2 = service._generateRecoveryId();

      expect(id1).not.toBe(id2);
      expect(id1).toMatch(/^recovery_\d+_[a-z0-9]+$/);
      expect(id2).toMatch(/^recovery_\d+_[a-z0-9]+$/);
    });
  });

  describe("Backup Metadata Retrieval", () => {
    test("should retrieve backup metadata by ID", async () => {
      const backupId = service._generateBackupId();
      const backupFile = path.join(
        testBackupDir,
        `backup_${backupId}_full.sql`,
      );

      fs.writeFileSync(backupFile, "MOCK BACKUP DATA");

      const metadata = {
        backupId,
        type: BackupType.FULL,
        status: BackupStatus.COMPLETED,
        startTime: new Date().toISOString(),
        endTime: new Date().toISOString(),
        duration: 1000,
        size: 16,
        checksum: "mock-checksum",
        verified: true,
        error: null,
        database: "CloudToLocalLLM",
        host: "localhost",
        port: "5432",
        filePath: backupFile,
      };

      service.backupMetadata.set(backupId, metadata);

      const retrieved = await service.getBackupMetadata(backupId);

      expect(retrieved).toEqual(metadata);
      expect(retrieved.backupId).toBe(backupId);
      expect(retrieved.verified).toBe(true);
    });

    test("should throw error for non-existent backup", async () => {
      await expect(service.getBackupMetadata("nonexistent-id")).rejects.toThrow(
        "Backup not found",
      );
    });
  });

  describe("Service Initialization", () => {
    test("should initialize backup directory", async () => {
      const tempDir = path.join(
        __dirname,
        "../../services/api-backend/test-backups-init",
      );

      const tempService = new BackupRecoveryService({
        backupDir: tempDir,
      });

      await tempService.initialize();

      expect(fs.existsSync(tempDir)).toBe(true);

      // Cleanup
      fs.rmdirSync(tempDir);
    });
  });
});
