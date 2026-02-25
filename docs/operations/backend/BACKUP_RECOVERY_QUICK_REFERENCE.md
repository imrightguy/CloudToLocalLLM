# Backup and Recovery Quick Reference

## Quick Start

### 1. Initialize the Service

```javascript
import { getBackupRecoveryService } from './services/backup-recovery-service.js';

const backupService = getBackupRecoveryService({
  backupDir: './backups',
  retentionDays: 30,
  maxBackups: 10,
  compressionEnabled: true,
  verificationEnabled: true
});

await backupService.initialize();
```

### 2. Create a Backup

```javascript
const backup = await backupService.createFullBackup();
console.log(`Backup created: ${backup.backupId}`);
console.log(`Size: ${backup.size} bytes`);
console.log(`Checksum: ${backup.checksum}`);
```

### 3. Verify Backup Integrity

```javascript
const verification = await backupService.verifyBackup(backupId);
if (verification.verified) {
  console.log('Backup is valid');
}
```

### 4. Restore from Backup

```javascript
const recovery = await backupService.restoreFromBackup(backupId);
console.log(`Recovery completed in ${recovery.duration}ms`);
```

### 5. List All Backups

```javascript
const backups = await backupService.listBackups();
backups.forEach(backup => {
  console.log(`${backup.backupId}: ${backup.size} bytes`);
});
```

## API Endpoints

### Create Backup

```
POST /backup/create
Authorization: Bearer <admin-token>
```

### List Backups

```
GET /backup/list
Authorization: Bearer <admin-token>
```

### Get Backup Info

```
GET /backup/:backupId
Authorization: Bearer <admin-token>
```

### Verify Backup

```
POST /backup/:backupId/verify
Authorization: Bearer <admin-token>
```

### Restore Backup

```
POST /backup/:backupId/restore
Authorization: Bearer <admin-token>
Content-Type: application/json

{
  "confirmed": true
}
```

### Delete Backup

```
DELETE /backup/:backupId
Authorization: Bearer <admin-token>
```

## Configuration

### Environment Variables

```bash
# Backup storage
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
DB_SSL=false
```

### Service Options

```javascript
{
  backupDir: string,              // Directory for backup files
  retentionDays: number,          // Days to keep backups
  maxBackups: number,             // Maximum number of backups
  compressionEnabled: boolean,    // Enable gzip compression
  verificationEnabled: boolean    // Enable integrity verification
}
```

## Backup Status Codes

- `pending` - Backup is queued
- `in_progress` - Backup is being created
- `completed` - Backup completed successfully
- `failed` - Backup failed
- `verified` - Backup verified and ready for restoration

## Recovery Status Codes

- `pending` - Recovery is queued
- `in_progress` - Recovery is in progress
- `completed` - Recovery completed successfully
- `failed` - Recovery failed
- `verified` - Recovery verified

## Error Handling

### Common Errors

```javascript
// Backup not found
Error: Backup not found: backup_123

// Backup file missing
Error: Backup file not found: /path/to/backup.sql

// Checksum mismatch
Error: Backup checksum mismatch - file may be corrupted

// Backup not verified
Error: Backup must be verified before restoration
```

## Testing

### Run Unit Tests

```bash
npm test -- backup-recovery.test.js
```

### Run Integration Tests

```bash
npm test -- backup-recovery-integration.test.js
```

## Performance Tips

1. **Schedule Backups**: Create backups during low-traffic periods
2. **Compression**: Enable compression for large databases
3. **Retention**: Adjust retention policy based on storage capacity
4. **Verification**: Verify backups regularly to catch corruption early
5. **Monitoring**: Monitor backup creation time and size

## Troubleshooting

### Backup Creation Fails

1. Check database connectivity
2. Verify `pg_dump` is installed
3. Check backup directory permissions
4. Review logs for detailed error messages

### Verification Fails

1. Check backup file integrity
2. Verify checksum calculation
3. Ensure backup file is not corrupted
4. Check file permissions

### Restoration Fails

1. Verify backup is verified before restoration
2. Check database connectivity
3. Verify `psql` is installed
4. Ensure target database exists
5. Check database permissions

## Best Practices

1. **Regular Backups**: Create backups on a regular schedule
2. **Verify Backups**: Always verify backups before relying on them
3. **Test Restoration**: Periodically test restoration procedures
4. **Monitor Storage**: Monitor backup storage usage
5. **Secure Backups**: Store backups in a secure location
6. **Encrypt Backups**: Consider encrypting backups at rest
7. **Replicate Backups**: Replicate backups to multiple locations
8. **Document Procedures**: Document backup and recovery procedures

## Monitoring

### Key Metrics

- Backup creation time
- Backup file size
- Verification time
- Recovery time
- Backup success rate
- Storage usage

### Logging

All backup operations are logged with:

- Correlation IDs for request tracing
- Timestamps for audit trails
- Error details for troubleshooting
- Performance metrics for optimization

## Support

For issues or questions:

1. Check the implementation documentation
2. Review test cases for usage examples
3. Check logs for error details
4. Contact the development team
