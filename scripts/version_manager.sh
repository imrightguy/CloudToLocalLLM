#!/bin/bash

# CloudToLocalLLM Version Management Utility
# Provides unified version management across all platforms and build systems

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC_FILE="$PROJECT_ROOT/pubspec.yaml"
APP_CONFIG_FILE="$PROJECT_ROOT/lib/config/app_config.dart"
SHARED_VERSION_FILE="$PROJECT_ROOT/lib/shared/lib/version.dart"
SHARED_PUBSPEC_FILE="$PROJECT_ROOT/lib/shared/pubspec.yaml"
ASSETS_VERSION_FILE="$PROJECT_ROOT/assets/version.json"

# Documentation files that need version updates
README_FILE="$PROJECT_ROOT/README.md"
PACKAGE_JSON_FILE="$PROJECT_ROOT/package.json"
CHANGELOG_FILE="$PROJECT_ROOT/docs/CHANGELOG.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables for error handling and cleanup
declare -a TEMP_FILES=()
declare -a BACKUP_FILES=()
SCRIPT_PID=$$

# Error handling and cleanup functions
cleanup_temp_files() {
    local exit_code=${1:-0}

    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        log_info "Cleaning up ${#TEMP_FILES[@]} temporary files..."
        for temp_file in "${TEMP_FILES[@]}"; do
            if [[ -f "$temp_file" ]]; then
                rm -f "$temp_file"
                log_info "Removed temporary file: $temp_file"
            fi
        done
        TEMP_FILES=()
    fi

    # If exit code indicates error, list available backups for recovery
    if [[ $exit_code -ne 0 ]] && [[ ${#BACKUP_FILES[@]} -gt 0 ]]; then
        log_warning "Script failed. The following backup files are available for recovery:"
        for backup_file in "${BACKUP_FILES[@]}"; do
            if [[ -f "$backup_file" ]]; then
                log_warning "  - $backup_file"
            fi
        done
        log_warning "To restore a file: cp <backup_file> <original_file>"
    fi
}

# Register cleanup function to run on script exit
trap 'cleanup_temp_files $?' EXIT

# Error handler for critical failures
handle_critical_error() {
    local line_number=$1
    local command="$2"
    local exit_code=$3

    log_error "Critical error on line $line_number: Command '$command' failed with exit code $exit_code"
    log_error "Script execution halted to prevent data corruption"

    # Attempt to restore from backups if available
    if [[ ${#BACKUP_FILES[@]} -gt 0 ]]; then
        log_warning "Attempting to restore files from backups..."
        for backup_file in "${BACKUP_FILES[@]}"; do
            if [[ -f "$backup_file" ]]; then
                local original_file="${backup_file%.backup.*}"
                if [[ -f "$original_file" ]]; then
                    cp "$backup_file" "$original_file" 2>/dev/null || true
                    log_info "Restored: $original_file"
                fi
            fi
        done
    fi

    exit $exit_code
}

# Set up error trap for critical failures
trap 'handle_critical_error ${LINENO} "$BASH_COMMAND" $?' ERR

# Function to register temporary files for cleanup
register_temp_file() {
    local temp_file="$1"
    TEMP_FILES+=("$temp_file")
}

# Function to register backup files for potential recovery
register_backup_file() {
    local backup_file="$1"
    BACKUP_FILES+=("$backup_file")
}

# Enhanced backup management with rotation
create_timestamped_backup() {
    local file="$1"
    local backup_dir="${2:-$(dirname "$file")/backups}"
    local max_backups="${3:-10}"

    if [[ ! -f "$file" ]]; then
        log_error "Cannot create backup: source file does not exist: $file"
        return 1
    fi

    # Create backup directory if needed
    if [[ ! -d "$backup_dir" ]]; then
        if ! mkdir -p "$backup_dir"; then
            log_error "Failed to create backup directory: $backup_dir"
            return 1
        fi
        log_info "Created backup directory: $backup_dir"
    fi

    # Generate backup filename with timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local basename=$(basename "$file")
    local backup_file="$backup_dir/${basename}.backup.$timestamp"

    # Create backup with verification
    if cp "$file" "$backup_file"; then
        # Verify backup was created successfully
        if [[ -f "$backup_file" ]] && [[ -s "$backup_file" ]]; then
            # Compare file sizes to ensure backup is complete
            local original_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
            local backup_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null || echo "0")

            if [[ "$original_size" -eq "$backup_size" ]]; then
                log_info "Created verified backup: $backup_file"
                register_backup_file "$backup_file"

                # Cleanup old backups
                cleanup_old_backups "$backup_dir" "$basename" "$max_backups"

                echo "$backup_file"
                return 0
            else
                log_error "Backup verification failed: size mismatch"
                rm -f "$backup_file"
                return 1
            fi
        else
            log_error "Backup file was not created or is empty"
            return 1
        fi
    else
        log_error "Failed to create backup: $backup_file"
        return 1
    fi
}

# Cleanup old backups (keep only max_backups)
cleanup_old_backups() {
    local backup_dir="$1"
    local basename="$2"
    local max_backups="$3"

    if [[ ! -d "$backup_dir" ]]; then
        return 0
    fi

    # Find and sort backup files by modification time (newest first)
    local backup_files=()
    while IFS= read -r -d '' file; do
        backup_files+=("$file")
    done < <(find "$backup_dir" -name "${basename}.backup.*" -type f -print0 | sort -z)

    # Remove oldest backups if we exceed max_backups
    local num_backups=${#backup_files[@]}
    if [[ $num_backups -gt $max_backups ]]; then
        local files_to_remove=$((num_backups - max_backups))
        log_info "Removing $files_to_remove old backup(s) (keeping $max_backups most recent)"

        # Sort by timestamp in filename (oldest first) and remove excess
        printf '%s\n' "${backup_files[@]}" | sort | head -n "$files_to_remove" | while read -r old_backup; do
            if [[ -f "$old_backup" ]]; then
                rm -f "$old_backup"
                log_info "Removed old backup: $(basename "$old_backup")"
            fi
        done
    fi
}

# Verify backup integrity
verify_backup_integrity() {
    local original_file="$1"
    local backup_file="$2"

    if [[ ! -f "$original_file" ]]; then
        log_error "Original file not found for backup verification: $original_file"
        return 1
    fi

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    # Compare file sizes
    local original_size=$(stat -f%z "$original_file" 2>/dev/null || stat -c%s "$original_file" 2>/dev/null || echo "0")
    local backup_size=$(stat -f%z "$backup_file" 2>/dev/null || stat -c%s "$backup_file" 2>/dev/null || echo "0")

    if [[ "$original_size" -ne "$backup_size" ]]; then
        log_error "Backup verification failed: size mismatch ($original_size vs $backup_size)"
        return 1
    fi

    # Compare checksums if available
    if command -v sha256sum >/dev/null 2>&1; then
        local original_hash=$(sha256sum "$original_file" | cut -d' ' -f1)
        local backup_hash=$(sha256sum "$backup_file" | cut -d' ' -f1)

        if [[ "$original_hash" != "$backup_hash" ]]; then
            log_error "Backup verification failed: checksum mismatch"
            return 1
        fi

        log_info "Backup integrity verified with checksum"
    else
        log_info "Backup integrity verified by size comparison"
    fi

    return 0
}

# File locking mechanisms to prevent race conditions
acquire_file_lock() {
    local file="$1"
    local lock_file="${file}.lock"
    local timeout="${2:-30}"
    local wait_time=0
    local lock_pid=""

    log_info "Attempting to acquire lock for: $file"

    while [[ $wait_time -lt $timeout ]]; do
        # Try to create lock file atomically
        if (set -C; echo $$ > "$lock_file") 2>/dev/null;
        then
            # Lock acquired successfully
            log_info "Lock acquired: $lock_file"
            echo "$lock_file"
            return 0
        fi

        # Check if lock is stale (process no longer exists)
        if [[ -f "$lock_file" ]]; then
            lock_pid=$(cat "$lock_file" 2>/dev/null)
            if [[ -n "$lock_pid" ]] && [[ "$lock_pid" =~ ^[0-9]+$ ]]; then
                # Check if the process is still running
                if ! kill -0 "$lock_pid" 2>/dev/null;
                then
                    log_warning "Removing stale lock file (PID $lock_pid no longer exists): $lock_file"
                    rm -f "$lock_file"
                    continue
                else
                    log_info "Lock held by active process (PID $lock_pid), waiting..."
                fi
            else
                log_warning "Invalid lock file content, removing: $lock_file"
                rm -f "$lock_file"
                continue
            fi
        fi

        sleep 1
        ((wait_time++))

        # Show progress every 10 seconds
        if [[ $((wait_time % 10)) -eq 0 ]]; then
            log_info "Still waiting for lock... ($wait_time/${timeout}s)"
        fi
    done

    log_error "Failed to acquire lock for $file after ${timeout}s (held by PID $lock_pid)"
    return 1
}

# Release file lock
release_file_lock() {
    local lock_file="$1"

    if [[ -z "$lock_file" ]]; then
        log_warning "No lock file specified for release"
        return 1
    fi

    if [[ -f "$lock_file" ]]; then
        # Verify we own the lock before removing it
        local lock_pid=$(cat "$lock_file" 2>/dev/null)
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$lock_file"
            log_info "Released lock: $lock_file"
            return 0
        else
            log_warning "Cannot release lock owned by different process (PID $lock_pid): $lock_file"
            return 1
        fi
    else
        log_warning "Lock file does not exist: $lock_file"
        return 1
    fi
}

# Function to create secure temporary file
create_secure_temp_file() {
    local base_name="$1"
    local temp_file=$(mktemp "${base_name}.XXXXXX")

    if [[ $? -ne 0 ]] || [[ ! -f "$temp_file" ]]; then
        log_error "Failed to create secure temporary file for $base_name"
        return 1
    fi

    # Set restrictive permissions
    chmod 600 "$temp_file"

    # Register for cleanup
    register_temp_file "$temp_file"

    echo "$temp_file"
}

# Character encoding and file characteristics preservation
preserve_file_characteristics() {
    local original_file="$1"
    local temp_file="$2"

    if [[ ! -f "$original_file" ]]; then
        log_error "Original file not found for characteristic preservation: $original_file"
        return 1
    fi

    # Detect if original file ends with newline
    local has_final_newline=false
    if [[ -s "$original_file" ]]; then
        # Check if last character is a newline
        if [[ $(tail -c1 "$original_file" | wc -l) -eq 1 ]]; then
            has_final_newline=true
        fi
    fi

    # Ensure temp file matches original newline behavior
    if [[ "$has_final_newline" == true ]]; then
        # Ensure temp file ends with newline
        if [[ $(tail -c1 "$temp_file" | wc -l) -eq 0 ]]; then
            echo >> "$temp_file"
        fi
    else
        # Remove final newline if original didn't have one
        if [[ $(tail -c1 "$temp_file" | wc -l) -eq 1 ]]; then
            # Use perl to remove final newline without affecting content
            perl -pi -e 'chomp if eof' "$temp_file"
        fi
    fi

    # Verify UTF-8 encoding
    if command -v file >/dev/null 2>&1;
    then
        if ! file "$temp_file" | grep -q "UTF-8"; then
            log_warning "Temp file may not be UTF-8 encoded: $temp_file"
        fi
    fi

    return 0
}

# Validate UTF-8 encoding of file
validate_utf8_encoding() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "File not found for UTF-8 validation: $file"
        return 1
    fi

    # Check if file command is available
    if command -v file >/dev/null 2>&1;
    then
        if ! file "$file" | grep -q "UTF-8\|ASCII"; then
            log_error "File is not UTF-8 or ASCII encoded: $file"
            return 1
        fi
    fi

    # Additional check using iconv if available
    if command -v iconv >/dev/null 2>&1;
    then
        if ! iconv -f UTF-8 -t UTF-8 "$file" >/dev/null 2>&1;
        then
            log_error "File contains invalid UTF-8 sequences: $file"
            return 1
        fi
    fi

    return 0
}

# Atomic file replacement with verification
atomic_file_replace() {
    local source="$1"
    local target="$2"
    local backup_dir="${3:-$(dirname "$target")}"

    # Pre-flight checks
    if ! verify_file_operations_safe "$source" "$target"; then
        log_error "File operations safety check failed"
        return 1
    fi

    # Verify source file has content
    if [[ ! -s "$source" ]]; then
        log_error "Source file is empty: $source"
        return 1
    fi

    # Create timestamped backup if target exists
    local backup_file=""
    if [[ -f "$target" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        backup_file="${backup_dir}/$(basename "$target").backup.$timestamp"

        if ! cp "$target" "$backup_file"; then
            log_error "Failed to create backup: $backup_file"
            return 1
        fi

        register_backup_file "$backup_file"
        log_info "Created backup: $backup_file"
    fi

    # Perform atomic move with verification
    if mv "$source" "$target"; then
        # Force filesystem sync to ensure data is written
        sync

        # Verify target file exists and has content
        if [[ -f "$target" ]] && [[ -s "$target" ]]; then
            log_success "Atomic file replacement completed: $target"
            return 0
        else
            log_error "Atomic replacement verification failed: target file missing or empty"
            # Restore from backup if available
            if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
                cp "$backup_file" "$target"
                log_info "Restored from backup due to verification failure"
            fi
            return 1
        fi
    else
        log_error "Atomic move operation failed"
        # Restore from backup if available
        if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
            cp "$backup_file" "$target"
            log_info "Restored from backup due to move failure"
        fi
        return 1
    fi
}

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

# Security: Input validation and sanitization functions
validate_version_string() {
    local version="$1"

    # Check if version is provided
    if [[ -z "$version" ]]; then
        log_error "Version string cannot be empty"
        return 1
    fi

    # Strict semantic version validation (MAJOR.MINOR.PATCH format only)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: '$version' (expected: MAJOR.MINOR.PATCH, e.g., 1.2.3)"
        return 1
    fi

    # Length validation to prevent buffer overflow attacks
    if [[ ${#version} -gt 20 ]]; then
        log_error "Version string too long: '$version' (maximum 20 characters)"
        return 1
    fi

    # Check for reasonable version numbers (prevent extremely large numbers)
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    local patch=$(echo "$version" | cut -d. -f3)

    if [[ $major -gt 999 ]] || [[ $minor -gt 999 ]] || [[ $patch -gt 999 ]]; then
        log_error "Version numbers too large: '$version' (maximum 999 for each component)"
        return 1
    fi

    log_info "Version string validation passed: '$version'"
    echo "$version"
}

# Security: Escape special characters for safe sed usage
escape_for_sed() {
    local input="$1"
    # Escape all special regex characters for sed
    printf '%s\n' "$input" | sed 's/[[\\.^$()+?{|]/\\&/g'
}

# Security: Validate file operations are safe before proceeding
verify_file_operations_safe() {
    local source="$1"
    local target="$2"

    # Check source file exists and is readable
    if [[ ! -f "$source" ]] || [[ ! -r "$source" ]]; then
        log_error "Source file not accessible: '$source'"
        return 1
    fi

    # Check target directory is writable
    local target_dir=$(dirname "$target")
    if [[ ! -w "$target_dir" ]]; then
        log_error "Target directory not writable: '$target_dir'"
        return 1
    fi

    # Check target file is writable (if it exists)
    if [[ -f "$target" ]] && [[ ! -w "$target" ]]; then
        log_error "Target file not writable: '$target'"
        return 1
    fi

    return 0
}

# Extract version components from pubspec.yaml
get_version_from_pubspec() {
    if [[ ! -f "$PUBSPEC_FILE" ]]; then
        log_error "pubspec.yaml not found at $PUBSPEC_FILE"
        exit 1
    fi
    
    local version_line=$(grep "^version:" "$PUBSPEC_FILE" | head -1)
    if [[ -z "$version_line" ]]; then
        log_error "No version found in pubspec.yaml"
        exit 1
    fi
    
    # Extract version (format: version: MAJOR.MINOR.PATCH+BUILD_NUMBER)
    local full_version=$(echo "$version_line" | sed 's/version: *//' | tr -d ' ')
    echo "$full_version"
}

# Extract semantic version (without build number)
get_semantic_version() {
    local full_version=$(get_version_from_pubspec)
    echo "$full_version" | sed 's/+.*//'
}

# Extract build number
get_build_number() {
    local full_version=$(get_version_from_pubspec)
    if [[ "$full_version" == *"+"* ]]; then
        echo "$full_version" | sed 's/.*+//'
    else
        echo "1"
    fi
}

# Generate new build number based on git commit count
generate_build_number() {
    git rev-list --count HEAD 2>/dev/null || echo "1"
}

# Increment build number - generates actual commit count for immediate use
# For deployment workflows that need immediate valid version numbers
increment_build_number() {
    # Generate commit count for immediate use in deployment
    generate_build_number
}

# Check if version qualifies for GitHub release
should_create_github_release() {
    local version="$1"

    # Always create GitHub releases for all versions as part of standard deployment workflow
    # GitHub releases are mandatory for version management and deployment tracking
    return 0  # true - always create releases
}

# Get release type based on version change
get_release_type() {
    local old_version="$1"
    local new_version="$2"

    local old_major=$(echo "$old_version" | cut -d. -f1)
    local old_minor=$(echo "$old_version" | cut -d. -f2)
    local old_patch=$(echo "$old_version" | cut -d. -f3)

    local new_major=$(echo "$new_version" | cut -d. -f1)
    local new_minor=$(echo "$new_version" | cut -d. -f2)
    local new_patch=$(echo "$new_version" | cut -d. -f3)

    if [[ "$new_major" != "$old_major" ]]; then
        echo "major"
    elif [[ "$new_minor" != "$old_minor" ]]; then
        echo "minor"
    elif [[ "$new_patch" != "$old_patch" ]]; then
        echo "patch"
    else
        echo "build"
    fi
}

# Increment version based on type (major, minor, patch, build)
#
# CloudToLocalLLM Semantic Versioning Strategy:
#
# PATCH (0.0.X+YYYYMMDDHHMM):
#   - Hotfixes and critical bug fixes requiring immediate deployment
#   - Security updates and emergency patches
#   - Critical stability fixes that can't wait for next minor release
#   - Example: Database connection fix, authentication bug, crash fix
#
# MINOR (0.X.0+YYYYMMDDHHMM):
#   - Feature additions and new functionality
#   - Quality of life improvements and UI enhancements
#   - Planned feature releases and capability expansions
#   - Example: New tunnel features, UI improvements, API additions
#
# MAJOR (X.0.0+YYYYMMDDHHMM):
#   - Breaking changes and architectural overhauls
#   - Significant API changes requiring user adaptation
#   - Major platform or framework migrations
#   - Example: Flutter 4.0 migration, API v2 breaking changes
#
increment_version() {
    local increment_type="$1"
    local current_version=$(get_semantic_version)

    # Parse current version
    local major=$(echo "$current_version" | cut -d. -f1)
    local minor=$(echo "$current_version" | cut -d. -f2)
    local patch=$(echo "$current_version" | cut -d. -f3)

    # Increment based on type
    case "$increment_type" in
        "major")
            # MAJOR: Breaking changes, architectural overhauls, significant API changes
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            # MINOR: Feature additions, UI enhancements, planned functionality
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            # PATCH: Hotfixes, security updates, critical bug fixes
            patch=$((patch + 1))
            ;;
        "build")
            # BUILD: Timestamp-only increment, no semantic version change
            ;;
        *)
            log_error "Invalid increment type. Use: major, minor, patch, or build"
            exit 1
            ;;
    esac

    echo "$major.$minor.$patch"
}

# Update version in pubspec.yaml
update_pubspec_version() {
    local new_version="$1"
    local new_build_number="$2"
    local full_version="$new_version+$new_build_number"
    
    log_info "Updating pubspec.yaml version to $full_version"
    
    # Create backup
    cp "$PUBSPEC_FILE" "$PUBSPEC_FILE.backup"
    
    # Update version line
    sed -i "s/^version:.*/version: $full_version/" "$PUBSPEC_FILE"
    
    log_success "Updated pubspec.yaml version to $full_version"
}

# Update version in app_config.dart
update_app_config_version() {
    local new_version="$1"

    log_info "Updating app_config.dart version to $new_version"

    if [[ ! -f "$APP_CONFIG_FILE" ]]; then
        log_warning "app_config.dart not found, skipping update"
        return
    fi

    # Create backup
    cp "$APP_CONFIG_FILE" "$APP_CONFIG_FILE.backup"

    # Update version constant
    sed -i "s/static const String appVersion = '[^']*';/static const String appVersion = '$new_version';/" "$APP_CONFIG_FILE"

    log_success "Updated app_config.dart version to $new_version"
}

# Update version in shared/lib/version.dart
update_shared_version_file() {
    local new_version="$1"
    local new_build_number="$2"

    log_info "Updating shared/lib/version.dart to $new_version"

    if [[ ! -f "$SHARED_VERSION_FILE" ]]; then
        log_warning "shared/lib/version.dart not found, skipping update"
        return
    fi

    # Create backup
    cp "$SHARED_VERSION_FILE" "$SHARED_VERSION_FILE.backup"

    # Generate build timestamp and ensure build number is in YYYYMMDDHHMM format
    local build_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # Use the provided build_number parameter which should already be in YYYYMMDDHHMM format
    local build_number_int="$new_build_number"

    # Update all version constants - handle both numeric build numbers and BUILD_TIME_PLACEHOLDER
    sed -i "s/static const String mainAppVersion = '[^']*';/static const String mainAppVersion = '$new_version';/" "$SHARED_VERSION_FILE"
    sed -i "s/static const int mainAppBuildNumber = \([0-9]*\|BUILD_TIME_PLACEHOLDER\);/static const int mainAppBuildNumber = $build_number_int;/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String tunnelManagerVersion = '[^']*';/static const String tunnelManagerVersion = '$new_version';/" "$SHARED_VERSION_FILE"
    sed -i "s/static const int tunnelManagerBuildNumber = \([0-9]*\|BUILD_TIME_PLACEHOLDER\);/static const int tunnelManagerBuildNumber = $build_number_int;/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String sharedLibraryVersion = '[^']*';/static const String sharedLibraryVersion = '$new_version';/" "$SHARED_VERSION_FILE"
    sed -i "s/static const int sharedLibraryBuildNumber = \([0-9]*\|BUILD_TIME_PLACEHOLDER\);/static const int sharedLibraryBuildNumber = $build_number_int;/" "$SHARED_VERSION_FILE"
    sed -i "s/static const String buildTimestamp = '[^']*';/static const String buildTimestamp = '$build_timestamp';/" "$SHARED_VERSION_FILE"

    log_success "Updated shared/lib/version.dart to $new_version"
}

# Update version in shared/pubspec.yaml
update_shared_pubspec_version() {
    local new_version="$1"
    local new_build_number="$2"
    local full_version="$new_version+$new_build_number"

    log_info "Updating shared/pubspec.yaml version to $full_version"

    if [[ ! -f "$SHARED_PUBSPEC_FILE" ]]; then
        log_warning "shared/pubspec.yaml not found, skipping update"
        return
    fi

    # Create backup
    cp "$SHARED_PUBSPEC_FILE" "$SHARED_PUBSPEC_FILE.backup"

    # Update version line
    sed -i "s/^version:.*/version: $full_version/" "$SHARED_PUBSPEC_FILE"

    log_success "Updated shared/pubspec.yaml version to $full_version"
}

# Update version in assets/version.json
update_assets_version_json() {
    local new_version="$1"
    local new_build_number="$2"

    log_info "Updating assets/version.json to $new_version"

    if [[ ! -f "$ASSETS_VERSION_FILE" ]]; then
        log_warning "assets/version.json not found, skipping update"
        return
    fi

    # Create backup
    cp "$ASSETS_VERSION_FILE" "$ASSETS_VERSION_FILE.backup"

    # Generate build timestamp
    local build_timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Read current git commit (preserve existing value if available)
    local git_commit="unknown"
    if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1;
    then
        git_commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    fi

    # Update the JSON file using sed (preserving existing git_commit if extraction fails)
    sed -i "s/\"version\": \"[^\"]*\"/\"version\": \"$new_version\"/" "$ASSETS_VERSION_FILE"
    sed -i "s/\"build_number\": \"[^\"]*\"/\"build_number\": \"$new_build_number\"/" "$ASSETS_VERSION_FILE"
    sed -i "s/\"build_date\": \"[^\"]*\"/\"build_date\": \"$build_timestamp\"/" "$ASSETS_VERSION_FILE"

    # Only update git_commit if we successfully got one
    if [[ "$git_commit" != "unknown" ]]; then
        sed -i "s/\"git_commit\": \"[^\"]*\"/\"git_commit\": \"$git_commit\"/" "$ASSETS_VERSION_FILE"
    fi

    log_success "Updated assets/version.json to $new_version"
}

# Update README.md version badge (SECURE VERSION)
update_readme_version() {
    local new_version="$1"

    log_info "Updating README.md version badge to $new_version"

    # Security: Validate input version string
    local validated_version=$(validate_version_string "$new_version")
    if [[ $? -ne 0 ]]; then
        log_error "README update failed: invalid version string"
        return 1
    fi

    if [[ ! -f "$README_FILE" ]]; then
        log_warning "README.md not found, skipping update"
        return 0
    fi

    # Security: Acquire file lock to prevent concurrent modifications
    local lock_file=$(acquire_file_lock "$README_FILE")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to acquire lock for README.md - another process may be updating it"
        return 1
    fi

    # Security: Create secure temporary file
    local temp_file=$(create_secure_temp_file "$README_FILE")
    if [[ $? -ne 0 ]]; then
        log_error "Failed to create temporary file for README update"
        release_file_lock "$lock_file"
        return 1
    fi

    # Security: Create enhanced timestamped backup with verification
    local backup_file=$(create_timestamped_backup "$README_FILE")
    if [[ $? -ne 0 ]]; then
        release_file_lock "$lock_file"
        log_error "Failed to create verified backup of README.md"
        return 1
    fi

    # Security: Escape version for safe sed usage
    local escaped_version=$(escape_for_sed "$validated_version")

    # Security: Use more specific pattern matching to prevent injection
    local pattern='\[!\[Version\]\(https://img\.shields\.io/badge/version-[0-9]\+\.[0-9]\+\.[0-9]\+-blue\.svg\)\]'
    local replacement="[![Version](https://img.shields.io/badge/version-$escaped_version-blue.svg)]"

    # Validate original file encoding
    if ! validate_utf8_encoding "$README_FILE"; then
        release_file_lock "$lock_file"
        log_error "README.md encoding validation failed"
        return 1
    fi

    # Perform replacement with error checking
    if sed "s/$pattern/$replacement/" "$README_FILE" > "$temp_file"; then
        # Preserve original file characteristics
        if ! preserve_file_characteristics "$README_FILE" "$temp_file"; then
            log_error "Failed to preserve file characteristics"
            return 1
        fi

        # Verify the replacement was successful
        if grep -q "version-$escaped_version-blue" "$temp_file"; then
            # Validate temp file encoding
            if ! validate_utf8_encoding "$temp_file"; then
                log_error "Temp file encoding validation failed"
                return 1
            fi

            # Use atomic file replacement
            if atomic_file_replace "$temp_file" "$README_FILE"; then
                release_file_lock "$lock_file"
                log_success "Updated README.md version badge to $validated_version"
                return 0
            else
                release_file_lock "$lock_file"
                log_error "Atomic file replacement failed for README.md"
                return 1
            fi
        else
            release_file_lock "$lock_file"
            log_error "Version replacement verification failed - no version badge found or updated"
            return 1
        fi
    else
        release_file_lock "$lock_file"
        log_error "sed command failed during README update"
        return 1
    fi
}

# Update package.json version
update_package_json_version() {
    local new_version="$1"

    log_info "Updating package.json version to $new_version"

    if [[ ! -f "$PACKAGE_JSON_FILE" ]]; then
        log_warning "package.json not found, skipping update"
        return
    fi

    # Create backup
    cp "$PACKAGE_JSON_FILE" "$PACKAGE_JSON_FILE.backup"

    # Update version field (line 3: "version": "X.X.X",)
    sed -i "s/\"version\":[[:space:]]*\"[^\"]*\"/\"version\": \"$new_version\"/" "$PACKAGE_JSON_FILE"

    log_success "Updated package.json version to $new_version"
}

# Update CHANGELOG.md with new version entry
update_changelog_version() {
    local new_version="$1"
    local version_type="$2"

    log_info "Updating CHANGELOG.md with new version entry $new_version"

    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        log_warning "docs/CHANGELOG.md not found, skipping update"
        return
    fi

    # Create backup
    cp "$CHANGELOG_FILE" "$CHANGELOG_FILE.backup"

    # Get current date
    local current_date=$(date +%Y-%m-%d)

    # Determine change type description
    local change_description
    case "$version_type" in
        "major")
            change_description="### Breaking Changes\n- Major version update with breaking changes"
            ;;
        "minor")
            change_description="### Added\n- New features and enhancements"
            ;;
        "patch")
            change_description="### Fixed\n- Bug fixes and improvements"
            ;;
        "build")
            change_description="### Technical\n- Build and deployment updates"
            ;;
        *)
            change_description="### Changes\n- Version update"
            ;;
    esac

    # Create new version entry
    local new_entry="## [$new_version] - $current_date\n\n$change_description\n\n"

    # Create temporary file with new entry
    local temp_file=$(mktemp)

    # Find the insertion point (after the header section, before first version entry)
    local insert_line=0
    local line_num=0
    local found_first_version=false

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Look for the first version entry
        if [[ "$line" =~ ^##[[:space:]]*\[ ]] && [[ $found_first_version == false ]]; then
            # Found first version entry, insert before it
            echo -e "$new_entry" >> "$temp_file"
            echo "$line" >> "$temp_file"
            found_first_version=true
            insert_line=$line_num
        else
            echo "$line" >> "$temp_file"
        fi

        # If we've passed the header section and haven't found a version entry yet
        if [[ $line_num -gt 8 ]] && [[ "$line" =~ ^[[:space:]]*$ ]] && [[ $found_first_version == false ]] && [[ $insert_line -eq 0 ]]; then
            # Check if next line exists and is not a version entry
            local next_line=""
            if IFS= read -r next_line <&3;
            then
                if [[ ! "$next_line" =~ ^##[[:space:]]*\[ ]]; then
                    # Insert here
                    echo -e "$new_entry" >> "$temp_file"
                    echo "$next_line" >> "$temp_file"
                    insert_line=$line_num
                    found_first_version=true
                else
                    # Next line is a version entry, will be handled in next iteration
                    echo "$next_line" >> "$temp_file"
                fi
            else
                # End of file, insert here
                echo -e "$new_entry" >> "$temp_file"
                insert_line=$line_num
                found_first_version=true
            fi
        fi
    done < "$CHANGELOG_FILE" 3< "$CHANGELOG_FILE"

    # If we never found a good insertion point, append to end
    if [[ $insert_line -eq 0 ]]; then
        echo -e "\n$new_entry" >> "$temp_file"
    fi

    # Replace original file
    mv "$temp_file" "$CHANGELOG_FILE"

    log_success "Updated CHANGELOG.md with version $new_version entry"
}

# Update all documentation files with new version
update_all_documentation() {
    local new_version="$1"
    local version_type="$2"

    log_info "Updating all documentation files with version $new_version"

    # Update individual documentation files
    update_readme_version "$new_version"
    update_package_json_version "$new_version"
    update_changelog_version "$new_version" "$version_type"

    log_success "All documentation files updated with version $new_version"
}

# Validate version format
validate_version_format() {
    local version="$1"
    
    # Check semantic version format (MAJOR.MINOR.PATCH)
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: $version. Expected format: MAJOR.MINOR.PATCH"
        exit 1
    fi
    
    log_success "Version format is valid: $version"
}

# Display current version information
show_version_info() {
    local full_version=$(get_version_from_pubspec)
    local semantic_version=$(get_semantic_version)
    local build_number=$(get_build_number)
    
    echo -e "${CYAN}=== CloudToLocalLLM Version Information ===${NC}"
    echo -e "Full Version:     ${GREEN}$full_version${NC}"
    echo -e "Semantic Version: ${GREEN}$semantic_version${NC}"
    echo -e "Build Number:     ${GREEN}$build_number${NC}"
    echo -e "Source File:      ${BLUE}$PUBSPEC_FILE${NC}"
}

# Main command dispatcher
main() {
    case "${1:-}" in
        "get")
            get_version_from_pubspec
            ;;
        "get-semantic")
            get_semantic_version
            ;;
        "get-build")
            get_build_number
            ;;
        "info")
            show_version_info
            ;;
        "increment")
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: $0 increment <major|minor|patch|build>"
                exit 1
            fi

            local current_version=$(get_semantic_version)
            local increment_type="$2"

            if [[ "$increment_type" == "build" ]]; then
                # For build increments, keep same semantic version but increment build number
                local new_build_number=$(increment_build_number)
                validate_version_format "$current_version"
                update_pubspec_version "$current_version" "$new_build_number"
                update_app_config_version "$current_version"
                update_shared_version_file "$current_version" "$new_build_number"
                update_shared_pubspec_version "$current_version" "$new_build_number"
                update_assets_version_json "$current_version" "$new_build_number"

                # Update documentation files for build increments
                update_all_documentation "$current_version" "$increment_type"

                log_info "Build number incremented (no GitHub release needed)"
            else
                # For semantic version changes, generate new timestamp build number
                local new_version=$(increment_version "$increment_type")
                local new_build_number=$(generate_build_number)  # Use timestamp for new semantic version
                validate_version_format "$new_version"
                update_pubspec_version "$new_version" "$new_build_number"
                update_app_config_version "$new_version"
                update_shared_version_file "$new_version" "$new_build_number"
                update_shared_pubspec_version "$new_version" "$new_build_number"
                update_assets_version_json "$new_version" "$new_build_number"

                # Update documentation files for semantic version changes
                update_all_documentation "$new_version" "$increment_type"

                # GitHub release creation is mandatory for all versions
                if should_create_github_release "$new_version"; then
                    log_info "GitHub release will be created for version v$new_version"
                    log_info "Run: git tag v$new_version && git push origin v$new_version"
                else
                    log_error "GitHub release creation failed - this should not happen"
                fi
            fi

            show_version_info
            ;;
        "set")
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: $0 set <version>"
                exit 1
            fi
            validate_version_format "$2"
            local new_build_number=$(generate_build_number)  # Use timestamp for set command
            update_pubspec_version "$2" "$new_build_number"
            update_app_config_version "$2"
            update_shared_version_file "$2" "$new_build_number"
            update_shared_pubspec_version "$2" "$new_build_number"
            update_assets_version_json "$2" "$new_build_number"

            # Update documentation files for manual version set
            update_all_documentation "$2" "manual"

            show_version_info
            ;;
        "validate")
            local version=$(get_semantic_version)
            validate_version_format "$version"
            ;;
        "validate-placeholders")
            log_info "Validating that no BUILD_TIME_PLACEHOLDER remains in version files"

            local files_to_check=("$PUBSPEC_FILE" "$SHARED_PUBSPEC_FILE" "$SHARED_VERSION_FILE" "$ASSETS_VERSION_FILE")
            local placeholder_found=false

            for file in "${files_to_check[@]}"; do
                if [[ -f "$file" ]]; then
                    if grep -q "BUILD_TIME_PLACEHOLDER" "$file"; then
                        log_error "BUILD_TIME_PLACEHOLDER found in: $file"
                        placeholder_found=true
                    else
                        log_info "âœ“ No placeholders in: $file"
                    fi
                fi
            done

            if [[ "$placeholder_found" == "true" ]]; then
                log_error "Validation failed: BUILD_TIME_PLACEHOLDER instances remain in version files"
                exit 1
            else
                log_success "Validation passed: All BUILD_TIME_PLACEHOLDER instances have been replaced"
            fi
            ;;
        "prepare")
            if [[ -z "${2:-}" ]]; then
                log_error "Usage: $0 prepare <major|minor|patch|build>"
                exit 1
            fi

            local current_version=$(get_semantic_version)
            local increment_type="$2"

            if [[ "$increment_type" == "build" ]]; then
                # For build preparation, keep same semantic version with placeholder
                local placeholder_build="BUILD_TIME_PLACEHOLDER"
                validate_version_format "$current_version"
                update_pubspec_version "$current_version" "$placeholder_build"
                update_app_config_version "$current_version"
                update_shared_version_file "$current_version" "$placeholder_build"
                update_shared_pubspec_version "$current_version" "$placeholder_build"
                update_assets_version_json "$current_version" "$placeholder_build"
                log_info "Version prepared for build-time timestamp injection"
            else
                # For semantic version changes, prepare with placeholder
                local new_version=$(increment_version "$increment_type")
                local placeholder_build="BUILD_TIME_PLACEHOLDER"
                validate_version_format "$new_version"
                update_pubspec_version "$new_version" "$placeholder_build"
                update_app_config_version "$new_version"
                update_shared_version_file "$new_version" "$placeholder_build"
                update_shared_pubspec_version "$new_version" "$placeholder_build"
                update_assets_version_json "$new_version" "$placeholder_build"

                # GitHub release creation is mandatory for all versions
                if should_create_github_release "$new_version"; then
                    log_info "GitHub release will be created for version v$new_version"
                    log_info "Run: git tag v$new_version && git push origin v$new_version"
                else
                    log_error "GitHub release creation failed - this should not happen"
                fi
            fi

            log_info "Version prepared with placeholder. Use build-time injection during actual build."
            show_version_info
            ;;
        "help"|"--help"|"-h"|"")
            echo "CloudToLocalLLM Version Manager"
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  get              Get full version (MAJOR.MINOR.PATCH+BUILD)"
            echo "  get-semantic     Get semantic version (MAJOR.MINOR.PATCH)"
            echo "  get-build        Get build number"
            echo "  info             Show detailed version information"
            echo "  increment <type> Increment version (major|minor|patch|build) - immediate timestamp"
            echo "                   Automatically updates README.md, package.json, and CHANGELOG.md"
            echo "  prepare <type>   Prepare version (major|minor|patch|build) - build-time timestamp"
            echo "  set <version>    Set specific version (MAJOR.MINOR.PATCH)"
            echo "                   Automatically updates README.md, package.json, and CHANGELOG.md"
            echo "  validate         Validate current version format"
            echo "  validate-placeholders  Validate no BUILD_TIME_PLACEHOLDER remains"
            echo "  help             Show this help message"
            echo ""
            echo "CloudToLocalLLM Semantic Versioning Strategy:"
            echo ""
            echo "  PATCH (0.0.X+YYYYMMDDHHMM) - URGENT FIXES:"
            echo "    Ã¢â‚¬Â¢ Hotfixes and critical bug fixes requiring immediate deployment"
            echo "    Ã¢â‚¬Â¢ Security updates and emergency patches"
            echo "    Ã¢â‚¬Â¢ Critical stability fixes that can't wait for next minor release"
            echo "    Ã¢â‚¬Â¢ Examples: Database connection fix, authentication bug, crash fix"
            echo ""
            echo "  MINOR (0.X.0+YYYYMMDDHHMM) - PLANNED FEATURES:"
            echo "    Ã¢â‚¬Â¢ Feature additions and new functionality"
            echo "    Ã¢â‚¬Â¢ Quality of life improvements and UI enhancements"
            echo "    Ã¢â‚¬Â¢ Planned feature releases and capability expansions"
            echo "    Ã¢â‚¬Â¢ Examples: New tunnel features, UI improvements, API additions"
            echo ""
            echo "  MAJOR (X.0.0+YYYYMMDDHHMM) - BREAKING CHANGES:"
            echo "    Ã¢â‚¬Â¢ Breaking changes and architectural overhauls"
            echo "    Ã¢â‚¬Â¢ Significant API changes requiring user adaptation"
            echo "    Ã¢â‚¬Â¢ Major platform or framework migrations"
            echo "    Ã¢â‚¬Â¢ Examples: Flutter 4.0 migration, API v2 breaking changes"
            echo "    Ã¢â‚¬Â¢ Creates GitHub release automatically"
            echo ""
            echo "  BUILD (X.Y.Z+YYYYMMDDHHMM) - TIMESTAMP ONLY:"
            echo "    Ã¢â‚¬Â¢ No semantic version change, only build timestamp update"
            echo "    Ã¢â‚¬Â¢ Used for CI/CD builds and testing iterations"
            echo ""
            echo "Build Number Format:"
            echo "  YYYYMMDDHHMM     Timestamp format representing build creation time"
            echo "  Example: 202506092204 = December 9, 2025 at 22:04"
            echo ""
            echo "Examples:"
            echo "  $0 info                    # Show current version info"
            echo "  $0 increment build         # Increment build number with immediate timestamp"
            echo "  $0 prepare build           # Prepare build increment for build-time timestamp"
            echo "  $0 increment patch         # Increment patch version with immediate timestamp"
            echo "  $0 prepare patch           # Prepare patch increment for build-time timestamp"
            echo "  $0 increment major         # Increment major (creates GitHub release)"
            echo "  $0 set 3.1.0              # Set version to 3.1.0 with immediate timestamp"
            echo ""
            echo "Automatic Documentation Updates:"
            echo "  When using 'increment' or 'set' commands, the following files are automatically updated:"
            echo "  - README.md      Version badge (line 3)"
            echo "  - package.json   Version field (line 3)"
            echo "  - docs/CHANGELOG.md  New version entry with current date"
            echo ""
            echo "Build-Time Workflow:"
            echo "  1. $0 prepare build        # Prepare version with placeholder"
            echo "  2. flutter build ...       # Build process injects actual timestamp"
            echo "  3. Artifacts have real build creation time"
            ;;
        *)
            log_error "Unknown command: $1"
            echo "Use '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"
