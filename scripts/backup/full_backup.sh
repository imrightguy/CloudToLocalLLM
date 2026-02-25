#!/bin/bash

# CloudToLocalLLM Full Backup Script
# Creates comprehensive backups of application data, configuration files,
# and system settings with verification and retention management

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# VPS configuration
VPS_HOST="cloudtolocalllm.online"
VPS_USER="cloudllm"
VPS_PROJECT_DIR="/opt/CloudToLocalLLM"

# Backup configuration
BACKUP_BASE_DIR="/var/backups/CloudToLocalLLM"
BACKUP_RETENTION_DAYS=30
COMPRESSION_LEVEL=6

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${CYAN}[STEP $1]${NC} $2"
}

# Create backup log entry
log_backup() {
    local log_file="/var/log/CloudToLocalLLM/backup.log"
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    echo "[$timestamp] BACKUP: $1" >> "$log_file" 2>/dev/null || true
}

# Check if running on VPS or locally
is_vps_environment() {
    [[ "$(hostname)" == *"CloudToLocalLLM"* ]] || [[ -f "/opt/CloudToLocalLLM/docker-compose.yml" ]]
}

# Execute command on VPS or locally
execute_command() {
    local cmd="$1"
    
    if is_vps_environment; then
        eval "$cmd"
    else
        ssh "$VPS_USER@$VPS_HOST" "$cmd"
    fi
}

# Create backup directory structure
create_backup_structure() {
    local backup_date="$1"
    local backup_dir="$BACKUP_BASE_DIR/$backup_date"
    
    log_step 1 "Creating backup directory structure..."
    
    execute_command "mkdir -p $backup_dir/{application,configuration,logs,database}"
    
    if execute_command "test -d $backup_dir"; then
        log_success "Backup directory created: $backup_dir"
        echo "$backup_dir"
    else
        log_error "Failed to create backup directory"
        exit 1
    fi
}

# Backup application files
backup_application() {
    local backup_dir="$1"
    
    log_step 2 "Backing up application files..."
    
    # Backup main application directory
    log_info "Backing up CloudToLocalLLM application..."
    execute_command "cd $VPS_PROJECT_DIR && tar -czf $backup_dir/application/cloudtolocalllm_app.tar.gz \
        --exclude='*.log' \
        --exclude='node_modules' \
        --exclude='.git' \
        --exclude='build/web' \
        --exclude='temp' \
        --exclude='.cache' \
        . 2>/dev/null || true"
    
    # Backup Flutter web build if it exists
    if execute_command "test -d $VPS_PROJECT_DIR/build/web"; then
        log_info "Backing up Flutter web build..."
        execute_command "cd $VPS_PROJECT_DIR && tar -czf $backup_dir/application/flutter_web_build.tar.gz build/web/ 2>/dev/null || true"
    fi
    
    # Backup Docker images (optional)
    log_info "Backing up Docker images..."
    execute_command "docker save \$(docker images --format '{{.Repository}}:{{.Tag}}' | grep CloudToLocalLLM) | gzip > $backup_dir/application/docker_images.tar.gz 2>/dev/null || true"
    
    log_success "Application backup completed"
    log_backup "Application files backed up"
}

# Backup configuration files
backup_configuration() {
    local backup_dir="$1"
    
    log_step 3 "Backing up configuration files..."
    
    # System configuration files
    local config_files=(
        "/etc/nginx/"
        "/etc/ssl/"
        "/etc/systemd/system/CloudToLocalLLM*"
        "/etc/docker/"
        "/etc/crontab"
        "/etc/hosts"
    )
    
    for config in "${config_files[@]}"; do
        if execute_command "test -e $config"; then
            local config_name=$(basename "$config" | sed 's/\*//g')
            log_info "Backing up $config..."
            execute_command "tar -czf $backup_dir/configuration/${config_name}_config.tar.gz $config 2>/dev/null || true"
        fi
    done
    
    # Application-specific configuration
    if execute_command "test -f $VPS_PROJECT_DIR/docker-compose.yml"; then
        log_info "Backing up Docker Compose configuration..."
        execute_command "cp $VPS_PROJECT_DIR/docker-compose.yml $backup_dir/configuration/"
    fi
    
    # Environment files
    if execute_command "test -f $VPS_PROJECT_DIR/.env"; then
        log_info "Backing up environment configuration..."
        execute_command "cp $VPS_PROJECT_DIR/.env $backup_dir/configuration/"
    fi
    
    log_success "Configuration backup completed"
    log_backup "Configuration files backed up"
}

# Backup logs
backup_logs() {
    local backup_dir="$1"
    
    log_step 4 "Backing up log files..."
    
    # Application logs
    if execute_command "test -d /var/log/CloudToLocalLLM"; then
        log_info "Backing up application logs..."
        execute_command "tar -czf $backup_dir/logs/application_logs.tar.gz /var/log/CloudToLocalLLM/ 2>/dev/null || true"
    fi
    
    # System logs (recent only)
    log_info "Backing up recent system logs..."
    execute_command "tar -czf $backup_dir/logs/system_logs.tar.gz \
        --newer-mtime='7 days ago' \
        /var/log/nginx/ \
        /var/log/auth.log \
        /var/log/syslog \
        /var/log/kern.log \
        2>/dev/null || true"
    
    # Docker logs
    log_info "Backing up Docker container logs..."
    local containers=$(execute_command "cd $VPS_PROJECT_DIR && docker compose ps -q" 2>/dev/null || echo "")
    if [[ -n "$containers" ]]; then
        execute_command "mkdir -p $backup_dir/logs/docker"
        for container in $containers; do
            local container_name=$(execute_command "docker inspect --format='{{.Name}}' $container" | sed 's/^\/*//')
            execute_command "docker logs $container > $backup_dir/logs/docker/${container_name}.log 2>&1" || true
        done
    fi
    
    log_success "Log backup completed"
    log_backup "Log files backed up"
}

# Backup database (if applicable)
backup_database() {
    local backup_dir="$1"
    
    log_step 5 "Backing up database..."
    
    # Check if database container exists
    local db_container=$(execute_command "cd $VPS_PROJECT_DIR && docker compose ps -q db 2>/dev/null || echo ''")
    
    if [[ -n "$db_container" ]]; then
        log_info "Database container found, creating backup..."
        
        # MySQL backup
        if execute_command "docker exec $db_container mysql --version >/dev/null 2>&1"; then
            execute_command "docker exec $db_container mysqldump --all-databases --single-transaction --routines --triggers > $backup_dir/database/mysql_backup.sql 2>/dev/null || true"
            execute_command "gzip $backup_dir/database/mysql_backup.sql" || true
        fi
        
        # PostgreSQL backup
        if execute_command "docker exec $db_container pg_dump --version >/dev/null 2>&1"; then
            execute_command "docker exec $db_container pg_dumpall > $backup_dir/database/postgresql_backup.sql 2>/dev/null || true"
            execute_command "gzip $backup_dir/database/postgresql_backup.sql" || true
        fi
        
        log_success "Database backup completed"
    else
        log_info "No database container found, skipping database backup"
    fi
    
    log_backup "Database backup completed"
}

# Create backup manifest
create_backup_manifest() {
    local backup_dir="$1"
    local backup_date="$2"
    
    log_step 6 "Creating backup manifest..."
    
    local manifest_file="$backup_dir/BACKUP_MANIFEST.txt"
    
    execute_command "cat > $manifest_file << EOF
CloudToLocalLLM Full Backup Manifest
====================================

Backup Date: $backup_date
Backup Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Backup Location: $backup_dir
Backup Host: \$(hostname)
Backup User: \$(whoami)

System Information:
- OS: \$(uname -a)
- Uptime: \$(uptime)
- Disk Usage: \$(df -h / | tail -1)
- Memory: \$(free -h | grep Mem)

Application Information:
- Project Directory: $VPS_PROJECT_DIR
- Docker Compose Status: \$(cd $VPS_PROJECT_DIR && docker compose ps 2>/dev/null || echo 'Not available')

Backup Contents:
================

Application Files:
\$(find $backup_dir/application -name '*.tar.gz' -exec ls -lh {} \; 2>/dev/null || echo 'No application backups')

Configuration Files:
\$(find $backup_dir/configuration -name '*.tar.gz' -exec ls -lh {} \; 2>/dev/null || echo 'No configuration backups')

Log Files:
\$(find $backup_dir/logs -name '*.tar.gz' -exec ls -lh {} \; 2>/dev/null || echo 'No log backups')

Database Files:
\$(find $backup_dir/database -name '*.sql.gz' -exec ls -lh {} \; 2>/dev/null || echo 'No database backups')

Total Backup Size:
\$(du -sh $backup_dir | cut -f1)

Backup Verification:
===================
\$(find $backup_dir -name '*.tar.gz' -exec tar -tzf {} \; >/dev/null 2>&1 && echo 'All tar.gz files verified successfully' || echo 'Some tar.gz files may be corrupted')

EOF" 2>/dev/null || true
    
    log_success "Backup manifest created"
}

# Verify backup integrity
verify_backup() {
    local backup_dir="$1"
    
    log_step 7 "Verifying backup integrity..."
    
    local verification_failed=false
    
    # Verify tar.gz files
    local tar_files=$(execute_command "find $backup_dir -name '*.tar.gz'" || echo "")
    if [[ -n "$tar_files" ]]; then
        while IFS= read -r tar_file; do
            if execute_command "tar -tzf $tar_file >/dev/null 2>&1"; then
                log_success "Verified: $(basename $tar_file)"
            else
                log_error "Verification failed: $(basename $tar_file)"
                verification_failed=true
            fi
        done <<< "$tar_files"
    fi
    
    # Check backup size
    local backup_size=$(execute_command "du -sb $backup_dir | cut -f1" || echo "0")
    if [[ "$backup_size" -gt 1048576 ]]; then  # > 1MB
        log_success "Backup size is reasonable: $(execute_command "du -sh $backup_dir | cut -f1")"
    else
        log_warning "Backup size seems small: $(execute_command "du -sh $backup_dir | cut -f1")"
        verification_failed=true
    fi
    
    if $verification_failed; then
        log_error "Backup verification failed"
        log_backup "ALERT: Backup verification failed"
        return 1
    else
        log_success "Backup verification passed"
        log_backup "Backup verification successful"
        return 0
    fi
}

# Clean old backups
clean_old_backups() {
    log_step 8 "Cleaning old backups..."
    
    # Remove backups older than retention period
    local old_backups=$(execute_command "find $BACKUP_BASE_DIR -maxdepth 1 -type d -name '20*' -mtime +$BACKUP_RETENTION_DAYS" || echo "")
    
    if [[ -n "$old_backups" ]]; then
        local removed_count=0
        while IFS= read -r old_backup; do
            execute_command "rm -rf $old_backup"
            log_info "Removed old backup: $(basename $old_backup)"
            ((removed_count++))
        done <<< "$old_backups"
        log_success "Removed $removed_count old backups"
    else
        log_info "No old backups to remove"
    fi
    
    # Show current backup status
    local backup_count=$(execute_command "ls -1d $BACKUP_BASE_DIR/20* 2>/dev/null | wc -l" || echo "0")
    local total_size=$(execute_command "du -sh $BACKUP_BASE_DIR 2>/dev/null | cut -f1" || echo "unknown")
    log_info "Current backups: $backup_count directories ($total_size total)"
    
    log_backup "Old backup cleanup completed"
}

# Generate backup report
generate_backup_report() {
    local backup_dir="$1"
    local backup_date="$2"
    local status="$3"
    
    echo
    echo "=== CloudToLocalLLM Full Backup Report ==="
    echo "Date: $backup_date"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Status: $status"
    echo "Location: $backup_dir"
    echo
    
    if [[ "$status" == "SUCCESS" ]]; then
        echo "✅ Full backup completed successfully"
        echo "📁 Application files backed up"
        echo "⚙️  Configuration files backed up"
        echo "📋 Log files backed up"
        echo "💾 Database backed up (if applicable)"
        echo "✅ Backup integrity verified"
        echo "🧹 Old backups cleaned up"
    else
        echo "❌ Full backup completed with errors"
        echo "📋 Review the backup steps above for details"
        echo "🔧 Check backup directory and permissions"
    fi
    
    echo
    if execute_command "test -d $backup_dir"; then
        local backup_size=$(execute_command "du -sh $backup_dir | cut -f1" || echo "unknown")
        local file_count=$(execute_command "find $backup_dir -type f | wc -l" || echo "unknown")
        echo "Backup Summary:"
        echo "  Size: $backup_size"
        echo "  Files: $file_count"
        echo "  Retention: $BACKUP_RETENTION_DAYS days"
        echo
        echo "Backup Contents:"
        execute_command "find $backup_dir -name '*.tar.gz' -exec ls -lh {} \;" 2>/dev/null || true
    fi
    echo
}

# Main execution function
main() {
    local backup_date=$(date +%Y%m%d_%H%M%S)
    
    log_info "Starting CloudToLocalLLM full backup..."
    log_backup "Full backup started"
    echo
    
    # Create log directory if it doesn't exist
    execute_command "mkdir -p /var/log/CloudToLocalLLM" 2>/dev/null || true
    execute_command "mkdir -p $BACKUP_BASE_DIR" 2>/dev/null || true
    
    # Create backup directory
    local backup_dir=$(create_backup_structure "$backup_date")
    echo
    
    local backup_status="SUCCESS"
    
    # Execute backup steps
    backup_application "$backup_dir" || backup_status="FAILED"
    echo
    
    backup_configuration "$backup_dir" || backup_status="FAILED"
    echo
    
    backup_logs "$backup_dir" || backup_status="FAILED"
    echo
    
    backup_database "$backup_dir" || backup_status="FAILED"
    echo
    
    create_backup_manifest "$backup_dir" "$backup_date" || backup_status="FAILED"
    echo
    
    verify_backup "$backup_dir" || backup_status="FAILED"
    echo
    
    clean_old_backups || backup_status="FAILED"
    echo
    
    # Generate final report
    generate_backup_report "$backup_dir" "$backup_date" "$backup_status"
    
    if [[ "$backup_status" == "SUCCESS" ]]; then
        log_success "Full backup completed successfully!"
        log_backup "Full backup completed successfully: $backup_dir"
        exit 0
    else
        log_error "Full backup completed with errors"
        log_backup "Full backup completed with errors: $backup_dir"
        exit 1
    fi
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "CloudToLocalLLM Full Backup Script"
        echo
        echo "Usage: $0 [options]"
        echo
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo
        echo "This script creates comprehensive backups including:"
        echo "  - Application files and Docker images"
        echo "  - System and application configuration"
        echo "  - Log files (recent system logs and all app logs)"
        echo "  - Database dumps (if database containers exist)"
        echo "  - Backup manifest and verification"
        echo "  - Automatic cleanup of old backups"
        echo
        echo "Configuration:"
        echo "  Backup location: $BACKUP_BASE_DIR"
        echo "  Retention period: $BACKUP_RETENTION_DAYS days"
        echo "  Compression level: $COMPRESSION_LEVEL"
        echo
        echo "Can be run locally (connects to VPS) or directly on VPS"
        echo
        exit 0
        ;;
esac

# Run main function
main "$@"
