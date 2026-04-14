#!/bin/sh
set -euo pipefail

BACKUP_DIR="/backups"
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-postgres}"
DB_NAME="${DB_NAME:-immogestion}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"

mkdir -p "$BACKUP_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"

echo "[backup] Starting backup of ${DB_NAME} at $(date)"

pg_dump \
  -h "$DB_HOST" \
  -p "$DB_PORT" \
  -U "$DB_USER" \
  -d "$DB_NAME" \
  --format=plain \
  --no-owner \
  --no-privileges \
  2>"${BACKUP_DIR}/backup_${TIMESTAMP}.log" \
| gzip > "$BACKUP_FILE"

BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "[backup] Completed: ${BACKUP_FILE} (${BACKUP_SIZE})"

if [ -f "$BACKUP_FILE" ]; then
  echo "[backup] Verifying backup integrity..."
  if gzip -t "$BACKUP_FILE" 2>/dev/null; then
    echo "[backup] Backup integrity verified."
  else
    echo "[backup] ERROR: Backup integrity check failed!"
    rm -f "$BACKUP_FILE"
    exit 1
  fi
else
  echo "[backup] ERROR: Backup file not created!"
  exit 1
fi

echo "[backup] Cleaning up backups older than ${RETENTION_DAYS} days..."
DELETED=$(find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +"${RETENTION_DAYS}" -delete -print | wc -l)
echo "[backup] Removed ${DELETED} old backup(s)."

echo "[backup] Done."
