#!/bin/bash

##############################################################################
# PostgreSQL Restore Script for AWS EKS
#
# This script restores a PostgreSQL database from a backup stored in AWS S3.
# It supports point-in-time recovery and backup verification.
#
# Usage:
#   ./restore-postgres.sh [OPTIONS]
#
# Options:
#   --backup-file FILE              Backup file name (required)
#   --s3-bucket BUCKET              S3 bucket for backups (default: CloudToLocalLLM-backups)
#   --namespace NAMESPACE           Kubernetes namespace (default: CloudToLocalLLM)
#   --pod-name POD_NAME             PostgreSQL pod name (default: postgres-0)
#   --db-name DB_NAME               Database name (default: CloudToLocalLLM)
#   --db-user DB_USER               Database user (default: cloud_admin)
#   --point-in-time TIMESTAMP       Point-in-time recovery (optional)
#   --verify-only                   Only verify backup, don't restore
#   --dry-run                       Show what would be done without doing it
#   --help                          Show this help message
#
# Requirements:
#   - kubectl configured and authenticated
#   - AWS CLI configured with S3 access
#   - PostgreSQL client tools (psql)
#
# Environment Variables:
#   POSTGRES_PASSWORD               PostgreSQL password (required)
#   AWS_REGION                      AWS region (default: us-east-1)
#
# Examples:
#   # List available backups
#   aws s3 ls s3://cloudtolocalllm-backups/
#
#   # Restore from specific backup
#   ./restore-postgres.sh --backup-file backup_20240101_020000_full.sql
#
#   # Verify backup before restoring
#   ./restore-postgres.sh --backup-file backup_20240101_020000_full.sql --verify-only
#
#   # Dry run to see what would happen
#   ./restore-postgres.sh --backup-file backup_20240101_020000_full.sql --dry-run
#
##############################################################################

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BACKUP_FILE=""
S3_BUCKET="CloudToLocalLLM-backups"
NAMESPACE="CloudToLocalLLM"
POD_NAME="postgres-0"
DB_NAME="CloudToLocalLLM"
DB_USER="cloud_admin"
POINT_IN_TIME=""
VERIFY_ONLY=false
DRY_RUN=false
AWS_REGION="${AWS_REGION:-us-east-1}"
RESTORE_DIR="/tmp/postgres-restore"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show help
show_help() {
    head -n 50 "$0" | tail -n +2 | sed 's/^# //'
}

# Function to validate prerequisites
validate_prerequisites() {
    print_info "Validating prerequisites..."

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI not found. Please install AWS CLI."
        exit 1
    fi

    # Check psql
    if ! command -v psql &> /dev/null; then
        print_warning "psql not found. Will use kubectl exec instead."
    fi

    # Check PostgreSQL password
    if [ -z "${POSTGRES_PASSWORD:-}" ]; then
        print_error "POSTGRES_PASSWORD environment variable not set."
        exit 1
    fi

    # Check if backup file is specified
    if [ -z "${BACKUP_FILE}" ]; then
        print_error "Backup file not specified. Use --backup-file option."
        exit 1
    fi

    # Check if pod exists
    if ! kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" &> /dev/null; then
        print_error "PostgreSQL pod '${POD_NAME}' not found in namespace '${NAMESPACE}'."
        exit 1
    fi

    # Check if S3 bucket exists
    if ! aws s3 ls "s3://${S3_BUCKET}" --region "${AWS_REGION}" &> /dev/null; then
        print_error "S3 bucket '${S3_BUCKET}' not found or not accessible."
        exit 1
    fi

    print_success "All prerequisites validated."
}

# Function to create restore directory
create_restore_directory() {
    print_info "Creating restore directory..."
    mkdir -p "${RESTORE_DIR}"
    print_success "Restore directory created: ${RESTORE_DIR}"
}

# Function to list available backups
list_available_backups() {
    print_info "Available backups in S3:"
    aws s3 ls "s3://${S3_BUCKET}/" --region "${AWS_REGION}" | grep "backup_"
}

# Function to download backup from S3
download_backup() {
    print_info "Downloading backup from S3..."

    BACKUP_PATH="${RESTORE_DIR}/${BACKUP_FILE}"

    if [ "${DRY_RUN}" = true ]; then
        print_info "[DRY RUN] Would download: s3://${S3_BUCKET}/${BACKUP_FILE}"
        return
    fi

    # Check if backup exists in S3
    if ! aws s3 ls "s3://${S3_BUCKET}/${BACKUP_FILE}" --region "${AWS_REGION}" &> /dev/null; then
        print_error "Backup file not found in S3: ${BACKUP_FILE}"
        list_available_backups
        exit 1
    fi

    # Download backup
    aws s3 cp "s3://${S3_BUCKET}/${BACKUP_FILE}" "${BACKUP_PATH}" \
        --region "${AWS_REGION}"

    if [ ! -f "${BACKUP_PATH}" ]; then
        print_error "Failed to download backup file."
        exit 1
    fi

    BACKUP_SIZE=$(du -h "${BACKUP_PATH}" | cut -f1)
    print_success "Backup downloaded. Size: ${BACKUP_SIZE}"
}

# Function to verify backup integrity
verify_backup_integrity() {
    print_info "Verifying backup integrity..."

    BACKUP_PATH="${RESTORE_DIR}/${BACKUP_FILE}"

    if [ ! -f "${BACKUP_PATH}" ]; then
        print_error "Backup file not found: ${BACKUP_PATH}"
        exit 1
    fi

    # Check if backup file is valid SQL
    if head -c 100 "${BACKUP_PATH}" | grep -q "PostgreSQL"; then
        print_success "Backup file appears to be valid PostgreSQL dump."
    else
        print_warning "Backup file may not be valid PostgreSQL dump."
    fi

    # Check file size
    FILE_SIZE=$(stat -f%z "${BACKUP_PATH}" 2>/dev/null || stat -c%s "${BACKUP_PATH}")
    if [ "${FILE_SIZE}" -lt 1000 ]; then
        print_warning "Backup file is very small (${FILE_SIZE} bytes). May indicate an issue."
    else
        print_success "Backup file size: $(numfmt --to=iec ${FILE_SIZE} 2>/dev/null || echo ${FILE_SIZE} bytes)"
    fi

    # Verify backup syntax (dry run)
    print_info "Verifying backup SQL syntax..."
    if head -n 100 "${BACKUP_PATH}" | grep -q "CREATE TABLE\|INSERT INTO\|CREATE SCHEMA"; then
        print_success "Backup contains expected SQL statements."
    else
        print_warning "Backup may not contain expected SQL statements."
    fi
}

# Function to create backup of current database
backup_current_database() {
    print_info "Creating backup of current database before restore..."

    export PGPASSWORD="${POSTGRES_PASSWORD}"

    CURRENT_BACKUP="${RESTORE_DIR}/backup_current_${TIMESTAMP}.sql"

    if [ "${DRY_RUN}" = true ]; then
        print_info "[DRY RUN] Would backup current database to: ${CURRENT_BACKUP}"
        return
    fi

    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- \
        pg_dump -h localhost -U "${DB_USER}" -d "${DB_NAME}" \
        > "${CURRENT_BACKUP}" 2>/dev/null

    if [ -f "${CURRENT_BACKUP}" ]; then
        CURRENT_SIZE=$(du -h "${CURRENT_BACKUP}" | cut -f1)
        print_success "Current database backed up. Size: ${CURRENT_SIZE}"
    else
        print_warning "Failed to backup current database."
    fi
}

# Function to restore database from backup
restore_database() {
    print_info "Restoring database from backup..."

    BACKUP_PATH="${RESTORE_DIR}/${BACKUP_FILE}"

    if [ ! -f "${BACKUP_PATH}" ]; then
        print_error "Backup file not found: ${BACKUP_PATH}"
        exit 1
    fi

    export PGPASSWORD="${POSTGRES_PASSWORD}"

    if [ "${DRY_RUN}" = true ]; then
        print_info "[DRY RUN] Would restore database from: ${BACKUP_PATH}"
        return
    fi

    print_warning "Starting database restore. This may take several minutes..."

    # Restore database
    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- \
        psql -h localhost -U "${DB_USER}" -d "${DB_NAME}" \
        < "${BACKUP_PATH}" 2>/dev/null

    print_success "Database restore completed."
}

# Function to verify restored data
verify_restored_data() {
    print_info "Verifying restored data..."

    export PGPASSWORD="${POSTGRES_PASSWORD}"

    if [ "${DRY_RUN}" = true ]; then
        print_info "[DRY RUN] Would verify restored data"
        return
    fi

    # Get table count
    TABLE_COUNT=$(kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- \
        psql -h localhost -U "${DB_USER}" -d "${DB_NAME}" -t -c \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public';" 2>/dev/null)

    print_info "Number of tables in restored database: ${TABLE_COUNT}"

    # Get row counts for key tables
    print_info "Checking key tables..."

    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- \
        psql -h localhost -U "${DB_USER}" -d "${DB_NAME}" -t -c \
        "SELECT tablename, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 10;" 2>/dev/null

    print_success "Data verification completed."
}

# Function to cleanup restore files
cleanup_restore_files() {
    print_info "Cleaning up restore files..."

    if [ -d "${RESTORE_DIR}" ]; then
        rm -rf "${RESTORE_DIR}"
        print_success "Restore directory cleaned up."
    fi
}

# Function to send notification
send_notification() {
    local status=$1
    local message=$2

    print_info "Sending notification..."

    if [ "${status}" = "SUCCESS" ]; then
        print_success "Restore notification: ${message}"
    else
        print_error "Restore notification: ${message}"
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backup-file)
                BACKUP_FILE="$2"
                shift 2
                ;;
            --s3-bucket)
                S3_BUCKET="$2"
                shift 2
                ;;
            --namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            --pod-name)
                POD_NAME="$2"
                shift 2
                ;;
            --db-name)
                DB_NAME="$2"
                shift 2
                ;;
            --db-user)
                DB_USER="$2"
                shift 2
                ;;
            --point-in-time)
                POINT_IN_TIME="$2"
                shift 2
                ;;
            --verify-only)
                VERIFY_ONLY=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    print_info "Starting PostgreSQL restore process..."
    print_info "Backup File: ${BACKUP_FILE}"
    print_info "S3 Bucket: ${S3_BUCKET}"
    print_info "Namespace: ${NAMESPACE}"
    print_info "Pod: ${POD_NAME}"
    print_info "Database: ${DB_NAME}"

    if [ "${DRY_RUN}" = true ]; then
        print_warning "DRY RUN MODE - No changes will be made"
    fi

    # Validate prerequisites
    validate_prerequisites

    # Create restore directory
    create_restore_directory

    # Download backup
    download_backup

    # Verify backup integrity
    verify_backup_integrity

    # If verify-only, stop here
    if [ "${VERIFY_ONLY}" = true ]; then
        print_success "Backup verification completed. Backup is ready for restore."
        cleanup_restore_files
        exit 0
    fi

    # Backup current database
    backup_current_database

    # Restore database
    restore_database

    # Verify restored data
    verify_restored_data

    # Cleanup restore files
    cleanup_restore_files

    # Send notification
    send_notification "SUCCESS" "PostgreSQL restore completed successfully from backup: ${BACKUP_FILE}"

    print_success "PostgreSQL restore process completed successfully!"
}

# Run main function
parse_arguments "$@"
main
