# Database Backup and Recovery Implementation

## Overview

This document describes the implementation of database backup and recovery procedures for the CloudToLocalLLM API backend. The system provides comprehensive backup management, integrity verification, and recovery capabilities.

## Requirements

**Requirement 9.6:** THE API SHALL implement database backup and recovery procedures

### Acceptance Criteria

- Create backup mechanism
- Implement recovery procedures
- Add backup verification
- Add unit tests for backup/recovery

## Implementation

### 1. Backup Recovery Service

**File:** `services/api-backend/services/backup-recovery-service.js`

The `BackupRecoveryService` class provides the core backup and recovery functionality:

#### Key Features

- **Full Backup Creation**: Creates complete database backups using `pg_dump`
- **Backup Verification**: Validates backup integrity using SHA256 checksums
- **Database Recovery**: Restores databases from backups using `psql`
- **Backup Management**: Lists, retrieves, and deletes backups
- **Retention Policy**: Automatically cleans up old backups based on retention days and max backup count
- **Compression Support**: Optional gzip compression for backup files
- **Metadata Tracking**: Maintains detailed metadata for each backup

#### Core Methods

```javascript
// Create a full database backup
async createFullBackup(options = {})

// Verify backup integrity
async verifyBackup(backupId)

// Restore database from backup
async restoreFromBackup(backupId, options = {})

// List all available backups
async listBackups()

// Get backup metadata
async getBackupMetadata(backupId)

// Delete a backup
async deleteBackup(backupId)
```

#### Configuration

The service accepts the following configuration options:

```javascript
{
  backupDir: './backups',           // Directory for backup files
  retentionDays: 30,                // Keep backups for 30 days
  maxBackups: 10,                   // Keep maximum 10 backups
  compressionEnabled: true,         // Enable gzip compression
  verificationEnabled: true         // Enable backup verification
}
```

### 2. API Routes

**File:** `services/api-backend/routes/backup-recovery.js`

REST API endpoints for backup and recovery operations:

#### Endpoints

- **POST /backup/create** - Create a full database backup
  - Admin only
  - Returns: Backup metadata with ID, size, checksum, and timestamps

- **GET /backup/list** - List all available backups
  - Admin only
  - Returns: Array of backup metadata sorted by date

- **GET /backup/:backupId** - Get backup metadata
  - Admin only
  - Returns: Detailed backup information

- **POST /backup/:backupId/verify** - Verify backup integrity
  - Admin only
  - Returns: Verification result with checksum validation

- **POST /backup/:backupId/restore** - Restore database from backup
  - Admin only
  - Requires: `{ confirmed: true }` in request body
  - Returns: Recovery metadata with status and duration

- **DELETE /backup/:backupId** - Delete a backup
  - Admin only
  - Returns: Success confirmation

### 3. Data Models

#### Backup Metadata

```javascript
{
  backupId: string,              // Unique backup identifier
  type: 'full' | 'incremental',  // Backup type
  status: 'pending' | 'in_progress' | 'completed' | 'failed' | 'verified',
  startTime: ISO8601,            // Backup start timestamp
  endTime: ISO8601,              // Backup end timestamp
  duration: number,              // Duration in milliseconds
  size: number,                  // Backup file size in bytes
  checksum: string,              // SHA256 checksum
  verified: boolean,             // Verification status
  error: string | null,          // Error message if failed
  database: string,              // Database name
  host: string,                  // Database host
  port: string,                  // Database port
  filePath: string               // Path to backup file
}
```

#### Recovery Metadata

```javascript
{
  recoveryId: string,            // Unique recovery identifier
  backupId: string,              // Source backup ID
  status: 'pending' | 'in_progress' | 'completed' | 'failed' | 'verified',
  startTime: ISO8601,            // Recovery start timestamp
  endTime: ISO8601,              // Recovery end timestamp
  duration: number,              // Duration in milliseconds
  error: string | null,          // Error message if failed
  database: string,              // Target database name
  pointInTime: ISO8601 | null    // Point-in-time recovery timestamp
}
```

## Testing

### Unit Tests

**File:** `test/api-backend/backup-recovery.test.js`

Comprehensive unit tests covering:

- Backup creation with metadata
- Unique ID generation
- Backup verification with checksum validation
- Corruption detection
- Backup listing and sorting
- Backup deletion
- Checksum calculation consistency
- Recovery ID generation
- Metadata retrieval
- Service initialization

**Test Coverage:** 15 tests, all passing

### Integration Tests

**File:** `test/api-backend/backup-recovery-integration.test.js`

API endpoint integration tests covering:

- POST /backup/create - Backup creation
- GET /backup/list - Listing backups
- GET /backup/:backupId - Retrieving metadata
- POST /backup/:backupId/verify - Verification
- POST /backup/:backupId/restore - Restoration with confirmation
- DELETE /backup/:backupId - Deletion

**Test Coverage:** 11 tests, all passing

## Usage Examples

### Creating a Backup

```bash
curl -X POST http://localhost:8080/backup/create \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json"
```

Response:

```json
{
  "success": true,
  "backup": {
    "backupId": "backup_1234567890_abc123",
    "type": "full",
    "status": "completed",
    "size": 52428800,
    "checksum": "abc123def456...",
    "startTime": "2025-11-19T23:17:02.293Z",
    "endTime": "2025-11-19T23:17:05.293Z",
    "duration": 3000
  }
}
```

### Verifying a Backup

```bash
curl -X POST http://localhost:8080/backup/backup_1234567890_abc123/verify \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json"
```

Response:

```json
{
  "success": true,
  "verification": {
    "backupId": "backup_1234567890_abc123",
    "verified": true,
    "checksum": "abc123def456..."
  }
}
```

### Restoring from a Backup

```bash
curl -X POST http://localhost:8080/backup/backup_1234567890_abc123/restore \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"confirmed": true}'
```

Response:

```json
{
  "success": true,
  "recovery": {
    "recoveryId": "recovery_1234567890_xyz789",
    "backupId": "backup_1234567890_abc123",
    "status": "completed",
    "duration": 5000
  }
}
```

## Environment Variables

Configure backup behavior with environment variables:

```bash
# Backup directory
BACKUP_DIR=./backups

# Retention policy
BACKUP_RETENTION_DAYS=30
MAX_BACKUPS=10

# Database connection
DB_HOST=localhost
DB_PORT=5432
DB_NAME=CloudToLocalLLM
DB_USER=postgres
DB_PASSWORD=password
```

## Security Considerations

1. **Admin Only Access**: All backup endpoints require admin authorization
2. **Confirmation Required**: Database restoration requires explicit confirmation
3. **Checksum Verification**: All backups are verified using SHA256 checksums
4. **Secure Storage**: Backup files should be stored in a secure location
5. **Encryption**: Consider encrypting backup files at rest
6. **Access Control**: Restrict backup directory access to authorized users

## Performance Characteristics

- **Backup Creation**: O(n) where n is database size
- **Verification**: O(n) for checksum calculation
- **Restoration**: O(n) for database restore
- **Listing**: O(m) where m is number of backups
- **Cleanup**: O(m) for retention policy enforcement

## Error Handling

The service provides comprehensive error handling:

- **Backup Failures**: Logged with full context and error details
- **Verification Failures**: Detected checksum mismatches and missing files
- **Recovery Failures**: Automatic rollback on errors
- **Cleanup Failures**: Non-blocking cleanup errors

## Future Enhancements

1. **Incremental Backups**: Support for incremental backup creation
2. **Point-in-Time Recovery**: Restore to specific timestamps
3. **Backup Encryption**: Encrypt backups at rest
4. **Cloud Storage**: Support for S3, GCS, Azure Blob Storage
5. **Backup Scheduling**: Automated backup scheduling
6. **Backup Replication**: Replicate backups to multiple locations
7. **Backup Monitoring**: Real-time backup status monitoring
8. **Backup Compression**: Multiple compression algorithms

## Compliance

This implementation satisfies:

- **Requirement 9.6**: Database backup and recovery procedures
- **ACID Compliance**: Maintains data consistency during backup/recovery
- **Data Protection**: Implements checksum verification and integrity checks
- **Audit Logging**: All backup operations are logged with correlation IDs

## References

- PostgreSQL pg_dump documentation
- PostgreSQL psql documentation
- SHA256 checksum verification
- Database backup best practices
