#!/bin/bash

# Security Test Suite for README.md Update Scripts
# Tests all identified vulnerabilities and security improvements

# Set up test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VERSION_MANAGER="$PROJECT_ROOT/scripts/version_manager.sh"
TEST_DIR="$SCRIPT_DIR/temp_test_files"
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
    echo -e "${BLUE}[TEST INFO]${NC} $1"
}

log_test_success() {
    echo -e "${GREEN}[TEST PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_test_failure() {
    echo -e "${RED}[TEST FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_test_warning() {
    echo -e "${YELLOW}[TEST WARN]${NC} $1"
}

# Test setup and cleanup
setup_test_environment() {
    log_test_info "Setting up test environment..."
    
    # Create test directory
    mkdir -p "$TEST_DIR"
    
    # Create a test README.md with version badge
    cat > "$TEST_README" << 'EOF'
# CloudToLocalLLM

[![Version](https://img.shields.io/badge/version-4.0.32-blue.svg)](https://github.com/CloudToLocalLLM-online/CloudToLocalLLM)

A sophisticated Flutter-based application that bridges cloud-based AI services with local AI models.

## Features

- Hybrid AI model support
- Real-time streaming
- Cross-platform compatibility

## Installation

Follow the installation guide in the docs directory.
EOF
    
    log_test_info "Test environment ready at: $TEST_DIR"
}

cleanup_test_environment() {
    log_test_info "Cleaning up test environment..."
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}

# Source the version manager functions for testing
source_version_manager() {
    if [[ ! -f "$VERSION_MANAGER" ]]; then
        log_test_failure "Version manager script not found: $VERSION_MANAGER"
        exit 1
    fi
    
    # Source the script to get access to functions
    source "$VERSION_MANAGER"
    
    # Override the README_FILE variable for testing
    README_FILE="$TEST_README"
}

# Test 1: Input Validation Tests
test_input_validation() {
    log_test_info "Running input validation tests..."
    ((TESTS_RUN++))
    
    local malicious_versions=(
        "1.0.0]/[![Malicious](http://evil.com/badge.svg)]"
        "1.0.0\"; rm -rf /; echo \""
        "../../../etc/passwd"
        "\$(rm -rf /)"
        "1.0.0\n\n## Injected Content"
        "999999.999999.999999"
        ""
        "1.0"
        "1.0.0.0"
        "v1.0.0"
        "1.0.0-beta"
        "1.0.0+build"
    )
    
    local failed_tests=0
    
    for version in "${malicious_versions[@]}"; do
        log_test_info "Testing malicious/invalid version: '$version'"
        
        if validate_version_string "$version" >/dev/null 2>&1; then
            log_test_failure "SECURITY FAILURE: Malicious/invalid version passed validation: '$version'"
            ((failed_tests++))
        else
            log_test_success "Malicious/invalid version correctly rejected: '$version'"
        fi
    done
    
    # Test valid versions
    local valid_versions=("1.0.0" "0.0.1" "999.999.999" "10.20.30")
    
    for version in "${valid_versions[@]}"; do
        log_test_info "Testing valid version: '$version'"
        
        if validate_version_string "$version" >/dev/null 2>&1; then
            log_test_success "Valid version correctly accepted: '$version'"
        else
            log_test_failure "Valid version incorrectly rejected: '$version'"
            ((failed_tests++))
        fi
    done
    
    if [[ $failed_tests -eq 0 ]]; then
        log_test_success "Input validation test suite passed"
    else
        log_test_failure "Input validation test suite failed ($failed_tests failures)"
    fi
}

# Test 2: Regex Injection Prevention
test_regex_injection_prevention() {
    log_test_info "Running regex injection prevention tests..."
    ((TESTS_RUN++))
    
    # Create a test README with known content
    setup_test_environment
    
    # Test that malicious regex patterns don't break the replacement
    local test_version="1.2.3"
    local original_content=$(cat "$TEST_README")
    
    # Test the escape_for_sed function
    local test_strings=(
        "1.0.0[malicious]"
        "1.0.0\$injection"
        "1.0.0.*wildcard"
        "1.0.0^anchor"
        "1.0.0(group)"
    )
    
    local failed_tests=0
    
    for test_string in "${test_strings[@]}"; do
        log_test_info "Testing regex escaping for: '$test_string'"
        
        local escaped=$(escape_for_sed "$test_string")
        
        # Verify that the escaped string doesn't contain unescaped special characters
        if [[ "$escaped" =~ [^\\][\[\.*\^\$\(\)\+\?\{\|] ]]; then
            log_test_failure "Regex escaping failed for: '$test_string' -> '$escaped'"
            ((failed_tests++))
        else
            log_test_success "Regex escaping successful for: '$test_string' -> '$escaped'"
        fi
    done
    
    if [[ $failed_tests -eq 0 ]]; then
        log_test_success "Regex injection prevention test suite passed"
    else
        log_test_failure "Regex injection prevention test suite failed ($failed_tests failures)"
    fi
}

# Test 3: File Integrity Tests
test_file_integrity() {
    log_test_info "Running file integrity tests..."
    ((TESTS_RUN++))
    
    setup_test_environment
    
    # Test that README update preserves file integrity
    local test_version="5.0.0"
    local original_size=$(stat -c%s "$TEST_README" 2>/dev/null || stat -f%z "$TEST_README" 2>/dev/null)
    local original_lines=$(wc -l < "$TEST_README")
    
    # Perform update
    if update_readme_version "$test_version"; then
        # Verify file still exists and has content
        if [[ -f "$TEST_README" ]] && [[ -s "$TEST_README" ]]; then
            local new_size=$(stat -c%s "$TEST_README" 2>/dev/null || stat -f%z "$TEST_README" 2>/dev/null)
            local new_lines=$(wc -l < "$TEST_README")
            
            # Check that version was updated
            if grep -q "version-$test_version-blue" "$TEST_README"; then
                log_test_success "Version badge correctly updated to $test_version"
                
                # Check that file structure is preserved
                if [[ $new_lines -eq $original_lines ]]; then
                    log_test_success "File line count preserved ($new_lines lines)"
                else
                    log_test_failure "File line count changed: $original_lines -> $new_lines"
                fi
                
                # Check that file is still valid UTF-8
                if validate_utf8_encoding "$TEST_README"; then
                    log_test_success "File UTF-8 encoding preserved"
                else
                    log_test_failure "File UTF-8 encoding corrupted"
                fi
                
            else
                log_test_failure "Version badge was not updated correctly"
            fi
        else
            log_test_failure "README file was corrupted or deleted"
        fi
    else
        log_test_failure "README update function failed"
    fi
}

# Test 4: Concurrent Access Tests
test_concurrent_access() {
    log_test_info "Running concurrent access tests..."
    ((TESTS_RUN++))
    
    setup_test_environment
    
    # Test file locking mechanism
    local lock_file=$(acquire_file_lock "$TEST_README" 5)
    
    if [[ $? -eq 0 ]] && [[ -n "$lock_file" ]]; then
        log_test_success "File lock acquired successfully: $lock_file"
        
        # Test that second lock attempt fails quickly
        local start_time=$(date +%s)
        if ! acquire_file_lock "$TEST_README" 3 >/dev/null 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            
            if [[ $duration -le 5 ]]; then
                log_test_success "Second lock attempt correctly failed within timeout ($duration seconds)"
            else
                log_test_failure "Second lock attempt took too long to fail ($duration seconds)"
            fi
        else
            log_test_failure "Second lock attempt should have failed but succeeded"
        fi
        
        # Release the lock
        if release_file_lock "$lock_file"; then
            log_test_success "File lock released successfully"
        else
            log_test_failure "Failed to release file lock"
        fi
    else
        log_test_failure "Failed to acquire initial file lock"
    fi
}

# Test 5: Backup and Recovery Tests
test_backup_recovery() {
    log_test_info "Running backup and recovery tests..."
    ((TESTS_RUN++))
    
    setup_test_environment
    
    local original_content=$(cat "$TEST_README")
    
    # Test backup creation
    local backup_file=$(create_timestamped_backup "$TEST_README")
    
    if [[ $? -eq 0 ]] && [[ -f "$backup_file" ]]; then
        log_test_success "Backup created successfully: $backup_file"
        
        # Verify backup integrity
        if verify_backup_integrity "$TEST_README" "$backup_file"; then
            log_test_success "Backup integrity verification passed"
        else
            log_test_failure "Backup integrity verification failed"
        fi
        
        # Test backup content
        local backup_content=$(cat "$backup_file")
        if [[ "$original_content" == "$backup_content" ]]; then
            log_test_success "Backup content matches original"
        else
            log_test_failure "Backup content differs from original"
        fi
    else
        log_test_failure "Failed to create backup"
    fi
}

# Main test runner
run_all_tests() {
    log_test_info "Starting README.md Script Security Test Suite"
    log_test_info "=============================================="
    
    # Source the version manager functions
    source_version_manager
    
    # Run all test suites
    test_input_validation
    test_regex_injection_prevention
    test_file_integrity
    test_concurrent_access
    test_backup_recovery
    
    # Cleanup
    cleanup_test_environment
    
    # Print summary
    echo
    log_test_info "Test Summary"
    log_test_info "============"
    log_test_info "Tests Run: $TESTS_RUN"
    log_test_success "Tests Passed: $TESTS_PASSED"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        log_test_failure "Tests Failed: $TESTS_FAILED"
        echo
        log_test_failure "SECURITY TEST SUITE FAILED - CRITICAL ISSUES DETECTED"
        exit 1
    else
        echo
        log_test_success "ALL SECURITY TESTS PASSED - SCRIPTS ARE SECURE"
        exit 0
    fi
}

# Run tests if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
