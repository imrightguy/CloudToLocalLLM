#!/bin/bash

# File Integrity Validation Test Suite for README.md Update Scripts
# Comprehensive tests for file integrity, encoding preservation, and content accuracy

# Set up test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION_MANAGER="$PROJECT_ROOT/scripts/version_manager.sh"
TEST_DIR="$SCRIPT_DIR/temp_integrity_tests"
TEST_README="$TEST_DIR/README.md"

# Colors for test output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test logging functions
log_test_info() {
    echo -e "${BLUE}[INTEGRITY]${NC} $1"
}

log_test_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_test_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

# Test setup and cleanup
setup_test_environment() {
    log_test_info "Setting up integrity test environment..."
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    
    # Create test files with different characteristics
    create_test_files
    
    log_test_info "Test environment ready at: $TEST_DIR"
}

cleanup_test_environment() {
    log_test_info "Cleaning up integrity test environment..."
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Create test files with various characteristics
create_test_files() {
    # Standard UTF-8 file with LF endings
    cat > "$TEST_DIR/readme_lf.md" << 'EOF'
# CloudToLocalLLM

[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM)

Test file with LF line endings.
EOF

    # UTF-8 file with CRLF endings
    cat > "$TEST_DIR/readme_crlf.md" << 'EOF'
# CloudToLocalLLM

[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM)

Test file with CRLF line endings.
EOF
    # Convert to CRLF
    sed -i 's/$/\r/' "$TEST_DIR/readme_crlf.md"

    # File without final newline
    printf "# CloudToLocalLLM\n\n[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM)\n\nTest file without final newline." > "$TEST_DIR/readme_no_final_newline.md"

    # File with Unicode characters
    cat > "$TEST_DIR/readme_unicode.md" << 'EOF'
# CloudToLocalLLM 🚀

[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM)

Test file with Unicode: ✅ 🔒 📝 🌟
Special characters: àáâãäåæçèéêë
Mathematical symbols: ∑ ∏ ∫ ∆ ∇
EOF

    # Large file for performance testing
    {
        echo "# CloudToLocalLLM"
        echo ""
        echo "[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM)"
        echo ""
        for i in {1..1000}; do
            echo "Line $i: This is a test line with some content to make the file larger."
        done
    } > "$TEST_DIR/readme_large.md"
}

# Source the version manager functions for testing
source_version_manager() {
    if [[ ! -f "$VERSION_MANAGER" ]]; then
        log_test_failure "Version manager script not found: $VERSION_MANAGER"
        exit 1
    fi
    
    source "$VERSION_MANAGER"
}

# Test file characteristics preservation
test_file_characteristics_preservation() {
    log_test_info "Testing file characteristics preservation..."
    ((TESTS_RUN++))
    
    local test_files=(
        "readme_lf.md"
        "readme_crlf.md" 
        "readme_no_final_newline.md"
        "readme_unicode.md"
    )
    
    local failed_tests=0
    
    for test_file in "${test_files[@]}"; do
        local file_path="$TEST_DIR/$test_file"
        log_test_info "Testing characteristics preservation for: $test_file"
        
        # Capture original characteristics
        local original_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
        local original_lines=$(wc -l < "$file_path")
        local has_final_newline=false
        
        if [[ -s "$file_path" ]] && [[ $(tail -c1 "$file_path" | wc -l) -eq 1 ]]; then
            has_final_newline=true
        fi
        
        # Detect line ending style
        local has_crlf=false
        if grep -q $'\r' "$file_path"; then
            has_crlf=true
        fi
        
        # Override README_FILE for this test
        README_FILE="$file_path"
        
        # Perform update
        if update_readme_version "5.1.0"; then
            # Check characteristics after update
            local new_size=$(stat -c%s "$file_path" 2>/dev/null || stat -f%z "$file_path" 2>/dev/null)
            local new_lines=$(wc -l < "$file_path")
            local new_has_final_newline=false
            
            if [[ -s "$file_path" ]] && [[ $(tail -c1 "$file_path" | wc -l) -eq 1 ]]; then
                new_has_final_newline=true
            fi
            
            local new_has_crlf=false
            if grep -q $'\r' "$file_path"; then
                new_has_crlf=true
            fi
            
            # Verify characteristics preserved
            if [[ $new_lines -eq $original_lines ]]; then
                log_test_success "$test_file: Line count preserved ($new_lines)"
            else
                log_test_failure "$test_file: Line count changed ($original_lines -> $new_lines)"
                ((failed_tests++))
            fi
            
            if [[ $has_final_newline == $new_has_final_newline ]]; then
                log_test_success "$test_file: Final newline behavior preserved"
            else
                log_test_failure "$test_file: Final newline behavior changed"
                ((failed_tests++))
            fi
            
            if [[ $has_crlf == $new_has_crlf ]]; then
                log_test_success "$test_file: Line ending style preserved"
            else
                log_test_failure "$test_file: Line ending style changed"
                ((failed_tests++))
            fi
            
            # Verify version was updated
            if grep -q "version-5.1.0-blue" "$file_path"; then
                log_test_success "$test_file: Version correctly updated"
            else
                log_test_failure "$test_file: Version not updated correctly"
                ((failed_tests++))
            fi
            
        else
            log_test_failure "$test_file: Update function failed"
            ((failed_tests++))
        fi
    done
    
    if [[ $failed_tests -eq 0 ]]; then
        log_test_success "File characteristics preservation test passed"
    else
        log_test_failure "File characteristics preservation test failed ($failed_tests failures)"
    fi
}

# Test UTF-8 encoding preservation
test_utf8_encoding_preservation() {
    log_test_info "Testing UTF-8 encoding preservation..."
    ((TESTS_RUN++))
    
    local test_file="$TEST_DIR/readme_unicode.md"
    local original_content=$(cat "$test_file")
    
    # Override README_FILE for this test
    README_FILE="$test_file"
    
    # Perform update
    if update_readme_version "6.0.0"; then
        # Verify UTF-8 encoding is still valid
        if validate_utf8_encoding "$test_file"; then
            log_test_success "UTF-8 encoding preserved after update"
            
            # Verify Unicode characters are intact
            local new_content=$(cat "$test_file")
            if echo "$new_content" | grep -q "🚀\|✅\|🔒\|📝\|🌟"; then
                log_test_success "Unicode characters preserved"
            else
                log_test_failure "Unicode characters corrupted"
            fi
            
            if echo "$new_content" | grep -q "àáâãäåæçèéêë"; then
                log_test_success "Accented characters preserved"
            else
                log_test_failure "Accented characters corrupted"
            fi
            
            if echo "$new_content" | grep -q "∑\|∏\|∫\|∆\|∇"; then
                log_test_success "Mathematical symbols preserved"
            else
                log_test_failure "Mathematical symbols corrupted"
            fi
            
        else
            log_test_failure "UTF-8 encoding corrupted after update"
        fi
    else
        log_test_failure "Update function failed for Unicode file"
    fi
}

# Test content accuracy and structure preservation
test_content_accuracy() {
    log_test_info "Testing content accuracy and structure preservation..."
    ((TESTS_RUN++))
    
    local test_file="$TEST_DIR/readme_lf.md"
    local original_content=$(cat "$test_file")
    
    # Override README_FILE for this test
    README_FILE="$test_file"
    
    # Perform update
    if update_readme_version "7.0.0"; then
        local new_content=$(cat "$test_file")
        
        # Verify only the version badge was changed
        local original_without_version=$(echo "$original_content" | sed 's/version-[0-9]\+\.[0-9]\+\.[0-9]\+-blue/VERSION_PLACEHOLDER/')
        local new_without_version=$(echo "$new_content" | sed 's/version-[0-9]\+\.[0-9]\+\.[0-9]\+-blue/VERSION_PLACEHOLDER/')
        
        if [[ "$original_without_version" == "$new_without_version" ]]; then
            log_test_success "Content structure preserved (only version changed)"
        else
            log_test_failure "Content structure modified beyond version update"
        fi
        
        # Verify specific version was set
        if echo "$new_content" | grep -q "version-7.0.0-blue"; then
            log_test_success "Correct version set in badge"
        else
            log_test_failure "Incorrect version in badge"
        fi
        
        # Verify no duplicate badges were created
        local badge_count=$(echo "$new_content" | grep -c "img.shields.io/badge/version-")
        if [[ $badge_count -eq 1 ]]; then
            log_test_success "No duplicate version badges created"
        else
            log_test_failure "Multiple version badges found ($badge_count)"
        fi
        
    else
        log_test_failure "Update function failed for content accuracy test"
    fi
}

# Test large file handling
test_large_file_handling() {
    log_test_info "Testing large file handling..."
    ((TESTS_RUN++))
    
    local test_file="$TEST_DIR/readme_large.md"
    local original_size=$(stat -c%s "$test_file" 2>/dev/null || stat -f%z "$test_file" 2>/dev/null)
    
    # Override README_FILE for this test
    README_FILE="$test_file"
    
    # Time the operation
    local start_time=$(date +%s)
    
    if update_readme_version "8.0.0"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        # Verify file integrity
        local new_size=$(stat -c%s "$test_file" 2>/dev/null || stat -f%z "$test_file" 2>/dev/null)
        
        if [[ -f "$test_file" ]] && [[ -s "$test_file" ]]; then
            log_test_success "Large file remains intact after update"
            
            # Check performance (should complete within reasonable time)
            if [[ $duration -le 10 ]]; then
                log_test_success "Large file update completed in reasonable time (${duration}s)"
            else
                log_test_failure "Large file update took too long (${duration}s)"
            fi
            
            # Verify version was updated
            if grep -q "version-8.0.0-blue" "$test_file"; then
                log_test_success "Version correctly updated in large file"
            else
                log_test_failure "Version not updated in large file"
            fi
            
        else
            log_test_failure "Large file corrupted or deleted"
        fi
    else
        log_test_failure "Update function failed for large file"
    fi
}

# Test backup integrity
test_backup_integrity() {
    log_test_info "Testing backup integrity..."
    ((TESTS_RUN++))
    
    local test_file="$TEST_DIR/readme_lf.md"
    local original_content=$(cat "$test_file")
    
    # Override README_FILE for this test
    README_FILE="$test_file"
    
    # Perform update (this should create backups)
    if update_readme_version "9.0.0"; then
        # Find backup files
        local backup_files=($(find "$TEST_DIR" -name "*.backup.*" -type f))
        
        if [[ ${#backup_files[@]} -gt 0 ]]; then
            log_test_success "Backup files created (${#backup_files[@]} found)"
            
            # Test the most recent backup
            local latest_backup="${backup_files[0]}"
            for backup in "${backup_files[@]}"; do
                if [[ "$backup" -nt "$latest_backup" ]]; then
                    latest_backup="$backup"
                fi
            done
            
            # Verify backup integrity
            if verify_backup_integrity "$test_file" "$latest_backup"; then
                log_test_success "Backup integrity verification passed"
            else
                log_test_failure "Backup integrity verification failed"
            fi
            
        else
            log_test_failure "No backup files found"
        fi
    else
        log_test_failure "Update function failed for backup test"
    fi
}

# Main test runner
run_integrity_tests() {
    log_test_info "Starting README.md File Integrity Test Suite"
    log_test_info "============================================="
    
    # Set up test environment
    setup_test_environment
    
    # Source the version manager functions
    source_version_manager
    
    # Run all integrity tests
    test_file_characteristics_preservation
    test_utf8_encoding_preservation
    test_content_accuracy
    test_large_file_handling
    test_backup_integrity
    
    # Cleanup
    cleanup_test_environment
    
    # Print summary
    echo
    log_test_info "Integrity Test Summary"
    log_test_info "====================="
    log_test_info "Tests Run: $TESTS_RUN"
    log_test_success "Tests Passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_test_failure "Tests Failed: $TESTS_FAILED"
        echo
        log_test_failure "FILE INTEGRITY TESTS FAILED"
        exit 1
    else
        echo
        log_test_success "ALL FILE INTEGRITY TESTS PASSED"
        exit 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_integrity_tests
fi
