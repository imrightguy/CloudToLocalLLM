#!/bin/bash

##############################################################################
# PostgreSQL Backup Script for AWS EKS
#
# This script creates automated backups of the PostgreSQL database running
# in the EKS cluster and stores them in AWS S3.
#
# Usage:
#   ./backup-postgres.sh [OPTIONS]
#
# Options:
#   --backup-type full|incremental  Type of backup (default: full)
#   --s3-bucket BUCKET              S3 bucket for backups (default: CloudToLocalLLM-backups)
#   --namespace NAMESPACE           Kubernetes namespace (default: CloudToLocalLLM)
#   --pod-name POD_NAME             PostgreSQL pod name (default: postgres-0)
#   --db-name DB_NAME               Database name (default: CloudToLocalLLM)
#   --db-user DB_USER               Database user (default: cloud_admin)
#   --retention-days DAYS           Backup retention in days (default: 30)
#   --help                          Show this help message
#
# Requirements:
#   - kubectl configured and authenticated
#   - AWS CLI configured with S3 access
#   - PostgreSQL client tools (pg_dump)
#
# Environment Variables:
#   POSTGRES_PASSWORD               PostgreSQL password (required)
#   AWS_REGION                      AWS region (default: us-east-1)
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
BACKUP_TYPE="full"
S3_BUCKET="CloudToLocalLLM-backups"
NAMESPACE="CloudToLocalLLM"
POD_NAME="postgres-0"
DB_NAME="CloudToLocalLLM"
DB_USER="cloud_admin"
RETENTION_DAYS=30
AWS_REGION="${AWS_REGION:-us-east-1}"
BACKUP_DIR="/tmp/postgres-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="backup_${TIMESTAMP}_${BACKUP_TYPE}.sql"
BACKUP_PATH="${BACKUP_DIR}/${BACKUP_FILE}"

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
    head -n 30 "$0" | tail -n +2 | sed 's/^# //'
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

    # Check pg_dump
    if ! command -v pg_dump &> /dev/null; then
        print_warning "pg_dump not found. Will use kubectl exec instead."
    fi

    # Check PostgreSQL password
    if [ -z "${POSTGRES_PASSWORD:-}" ]; then
        print_error "POSTGRES_PASSWORD environment variable not set."
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

# Function to create backup directory
create_backup_directory() {
    print_info "Creating backup directory..."
    mkdir -p "${BACKUP_DIR}"
    print_success "Backup directory created: ${BACKUP_DIR}"
}

# Function to perform full backup
perform_full_backup() {
    print_info "Starting full backup of database '${DB_NAME}'..."

    # Export password for pg_dump
    export PGPASSWORD="${POSTGRES_PASSWORD}"

    # Get PostgreSQL pod IP
    POD_IP=$(kubectl get pod "${POD_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.podIP}')
    print_info "PostgreSQL pod IP: ${POD_IP}"

    # Perform backup using kubectl exec
    print_info "Executing pg_dump in pod..."
    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- \
        pg_dump -h localhost -U "${DB_USER}" -d "${DB_NAME}" \
        > "${BACKUP_PATH}" 2>/dev/null

    # Verify backup file was created
    if [ ! -f "${BACKUP_PATH}" ]; then
        print_error "Backup file not created."
        exit 1
    fi

    # Get backup file size
    BACKUP_SIZE=$(du -h "${BACKUP_PATH}" | cut -f1)
    print_success "Full backup completed. Size: ${BACKUP_SIZE}"
}

# Function to perform incremental backup (WAL archive)
perform_incremental_backup() {
    print_info "Starting incremental backup (WAL archive)..."

    # Create WAL archive backup
    export PGPASSWORD="${POSTGRES_PASSWORD}"

    # Get list of WAL files since last backup
    kubectl exec -n "${NAMESPACE}" "${POD_NAME}" -- \
        pg_basebackup -h localhost -U "${DB_USER}" -D /tmp/backup -Ft -z \
        > "${BACKUP_PATH}.tar.gz" 2>/dev/null

    if [ ! -f "${BACKUP_PATH}.tar.gz" ]; then
        print_error "Incremental backup file not created."
        exit 1
    fi

    BACKUP_SIZE=$(du -h "${BACKUP_PATH}.tar.gz" | cut -f1)
    print_success "Incremental backup completed. Size: ${BACKUP_SIZE}"
}

# Function to calculate backup checksum
calculate_checksum() {
    print_info "Calculating backup checksum..."

    if [ -f "${BACKUP_PATH}" ]; then
        CHECKSUM=$(sha256sum "${BACKUP_PATH}" | awk '{print $1}')
    else
        CHECKSUM=$(sha256sum "${BACKUP_PATH}.tar.gz" | awk '{print $1}')
    fi

    print_success "Checksum: ${CHECKSUM}"
}

# Function to upload backup to S3
upload_to_s3() {
    print_info "Uploading backup to S3..."

    if [ -f "${BACKUP_PATH}" ]; then
        aws s3 cp "${BACKUP_PATH}" "s3://${S3_BUCKET}/${BACKUP_FILE}" \
            --region "${AWS_REGION}" \
            --sse AES256 \
            --metadata "timestamp=${TIMESTAMP},type=${BACKUP_TYPE},checksum=${CHECKSUM}"
    else
        aws s3 cp "${BACKUP_PATH}.tar.gz" "s3://${S3_BUCKET}/${BACKUP_FILE}.tar.gz" \
            --region "${AWS_REGION}" \
            --sse AES256 \
            --metadata "timestamp=${TIMESTAMP},type=${BACKUP_TYPE},checksum=${CHECKSUM}"
    fi

    print_success "Backup uploaded to S3: s3://${S3_BUCKET}/${BACKUP_FILE}"
}

# Function to verify backup integrity
verify_backup() {
    print_info "Verifying backup integrity..."

    if [ -f "${BACKUP_PATH}" ]; then
        # Check if backup file is valid SQL
        if head -c 100 "${BACKUP_PATH}" | grep -q "PostgreSQL"; then
            print_success "Backup file appears to be valid."
        else
            print_warning "Backup file may not be valid SQL."
        fi

        # Check file size
        FILE_SIZE=$(stat -f%z "${BACKUP_PATH}" 2>/dev/null || stat -c%s "${BACKUP_PATH}")
        if [ "${FILE_SIZE}" -lt 1000 ]; then
            print_warning "Backup file is very small (${FILE_SIZE} bytes). May indicate an issue."
        fi
    fi

    print_success "Backup verification completed."
}

# Function to cleanup old backups
cleanup_old_backups() {
    print_info "Cleaning up backups older than ${RETENTION_DAYS} days..."

    # Calculate cutoff date
    CUTOFF_DATE=$(date -d "${RETENTION_DAYS} days ago" +%Y%m%d 2>/dev/null || date -v-${RETENTION_DAYS}d +%Y%m%d)

    # List and delete old backups from S3
    aws s3api list-objects-v2 \
        --bucket "${S3_BUCKET}" \
        --region "${AWS_REGION}" \
        --query "Contents[?LastModified<='${CUTOFF_DATE}'].Key" \
        --output text | \
    while read -r key; do
        if [ -n "${key}" ]; then
            print_info "Deleting old backup: ${key}"
            aws s3 rm "s3://${S3_BUCKET}/${key}" --region "${AWS_REGION}"
        fi
    done

    print_success "Old backups cleaned up."
}

# Function to cleanup local backup files
cleanup_local_backups() {
    print_info "Cleaning up local backup files..."

    if [ -f "${BACKUP_PATH}" ]; then
        rm -f "${BACKUP_PATH}"
        print_success "Local backup file deleted: ${BACKUP_PATH}"
    fi

    if [ -f "${BACKUP_PATH}.tar.gz" ]; then
        rm -f "${BACKUP_PATH}.tar.gz"
        print_success "Local backup file deleted: ${BACKUP_PATH}.tar.gz"
    fi
}

# Function to log backup metadata
log_backup_metadata() {
    print_info "Logging backup metadata..."

    METADATA_FILE="${BACKUP_DIR}/backup_metadata.log"

    cat >> "${METADATA_FILE}" << EOF
Backup: ${BACKUP_FILE}
Type: ${BACKUP_TYPE}
Timestamp: ${TIMESTAMP}
Database: ${DB_NAME}
Size: ${BACKUP_SIZE}
Checksum: ${CHECKSUM}
S3 Location: s3://${S3_BUCKET}/${BACKUP_FILE}
Status: SUCCESS
---
EOF

    print_success "Backup metadata logged."
}

# Function to send notification
send_notification() {
    local status=$1
    local message=$2

    print_info "Sending notification..."

    # This is a placeholder for notification logic
    # In production, this could send to SNS, CloudWatch, or email
    if [ "${status}" = "SUCCESS" ]; then
        print_success "Backup notification: ${message}"
    else
        print_error "Backup notification: ${message}"
    fi
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --backup-type)
                BACKUP_TYPE="$2"
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
            --retention-days)
                RETENTION_DAYS="$2"
                shift 2
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
    print_info "Starting PostgreSQL backup process..."
    print_info "Backup Type: ${BACKUP_TYPE}"
    print_info "S3 Bucket: ${S3_BUCKET}"
    print_info "Namespace: ${NAMESPACE}"
    print_info "Pod: ${POD_NAME}"
    print_info "Database: ${DB_NAME}"

    # Validate prerequisites
    validate_prerequisites

    # Create backup directory
    create_backup_directory

    # Perform backup
    if [ "${BACKUP_TYPE}" = "full" ]; then
        perform_full_backup
    elif [ "${BACKUP_TYPE}" = "incremental" ]; then
        perform_incremental_backup
    else
        print_error "Invalid backup type: ${BACKUP_TYPE}"
        exit 1
    fi

    # Calculate checksum
    calculate_checksum

    # Verify backup
    verify_backup

    # Upload to S3
    upload_to_s3

    # Log metadata
    log_backup_metadata

    # Cleanup old backups
    cleanup_old_backups

    # Cleanup local files
    cleanup_local_backups

    # Send notification
    send_notification "SUCCESS" "PostgreSQL backup completed successfully. File: ${BACKUP_FILE}"

    print_success "PostgreSQL backup process completed successfully!"
}

# Run main function
parse_arguments "$@"
main
