#!/bin/bash

# CloudToLocalLLM Complete Automated Deployment Script v3.5.5+
# Implements the six-phase deployment workflow with full automation
# Zero manual operations principle with comprehensive error handling
# Enhanced with robust network operations and timeout handling

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Load deployment utilities with error handling
if [[ -f "$SCRIPT_DIR/deployment_utils.sh" ]]; then
    source "$SCRIPT_DIR/deployment_utils.sh"
    # Manually log success after sourcing
    if declare -F utils_log_success &> /dev/null; then
        utils_log_success "Deployment utilities library loaded"
    fi
else
    echo "ERROR: deployment_utils.sh not found at $SCRIPT_DIR/deployment_utils.sh"
    exit 1
fi

# Colors for output (from utils, but keeping for compatibility)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
FORCE=false
VERBOSE=false
SKIP_BACKUP=false
DRY_RUN=false

# Phase tracking
CURRENT_PHASE=0
TOTAL_PHASES=6

# Logging functions
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES] ❌${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[$(date '+%H:%M:%S')] [Phase $CURRENT_PHASE/$TOTAL_PHASES] [VERBOSE]${NC} $1"
    fi
}

log_phase() {
    echo ""
    echo -e "${BLUE}🔄 Phase $1/$TOTAL_PHASES: $2${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
    CURRENT_PHASE=$1
}

# Usage information
show_usage() {
    cat << EOF
CloudToLocalLLM Complete Automated Deployment Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --force             Skip all confirmation prompts
    --verbose           Enable detailed logging
    --skip-backup       Skip backup creation for faster deployment
    --dry-run           Simulate deployment without actual changes
    --help              Show this help message

EXAMPLES:
    $0                  # Non-interactive deployment with 3-second delay
    $0 --force          # Fully automated deployment (CI/CD compatible)
    $0 --verbose        # Detailed logging
    $0 --dry-run        # Simulate entire deployment

EXIT CODES:
    0 - Success
    1 - General error
    2 - Validation failure
    3 - Build failure
    4 - Deployment failure
    5 - Verification failure

DEPLOYMENT PHASES:
    1. Pre-Flight Validation
    2. Version Management
    3. Multi-Platform Build
    4. Distribution Validation
    5. Comprehensive Verification
    6. Operational Readiness
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --skip-backup)
                SKIP_BACKUP=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Phase 1: Pre-Flight Validation
phase1_preflight_validation() {
    log_phase 1 "Pre-Flight Validation"

    log "Checking environment and repository state..."

    # Change to project root
    cd "$PROJECT_ROOT"

    # Check Git status with enhanced error handling
    if ! check_git_clean "$FORCE"; then
        exit 2
    fi

    # Check required tools with enhanced validation
    local required_tools=("flutter" "git" "ssh" "scp" "curl" "timeout")
    if ! validate_required_tools "${required_tools[@]}"; then
        exit 2
    fi

    # AUR is decommissioned - no longer checking for makepkg

    # Validate build-time injection components
    log_verbose "Validating build-time timestamp injection components..."
    local build_injection_available=true

    # Check build-time version injector script
    if [[ -f "$PROJECT_ROOT/scripts/build_time_version_injector.sh" && -x "$PROJECT_ROOT/scripts/build_time_version_injector.sh" ]]; then
        log_verbose "✓ Build-time version injector available"
    else
        log_warning "Build-time version injector not found or not executable"
        build_injection_available=false
    fi

    # Check Flutter build wrapper script
    if [[ -f "$PROJECT_ROOT/scripts/flutter_build_with_timestamp.sh" && -x "$PROJECT_ROOT/scripts/flutter_build_with_timestamp.sh" ]]; then
        log_verbose "✓ Flutter build wrapper available"
    else
        log_warning "Flutter build wrapper not found or not executable"
        build_injection_available=false
    fi

    # Check version manager prepare command support
    if "$PROJECT_ROOT/scripts/version_manager.sh" help 2>/dev/null | grep -q "prepare"; then
        log_verbose "✓ Version manager prepare command available"
    else
        log_warning "Version manager prepare command not available"
        build_injection_available=false
    fi

    if [[ "$build_injection_available" == "true" ]]; then
        log_success "Build-time timestamp injection system validated"
        export BUILD_TIME_INJECTION_AVAILABLE=true
    else
        log_warning "Build-time injection components missing - will use fallback mode"
        export BUILD_TIME_INJECTION_AVAILABLE=false
    fi

    # Check network connectivity
    if ! check_network_connectivity; then
        log_error "Network connectivity check failed"
        exit 2
    fi

    # Test SSH connection to VPS with retry logic
    if ! test_ssh_connectivity "ubuntu@cloudtolocalllm.online" 15 5; then
        log_error "SSH connectivity to VPS failed after multiple attempts"
        log_error "Please check VPS status and SSH key configuration"
        exit 2
    fi

    # Validate GitHub SSH authentication for automated deployment
    log_verbose "Validating GitHub SSH authentication..."

    # Try SSH with agent first, then with explicit key specification
    # Note: GitHub SSH test returns exit code 1 (expected) with success message
    local ssh_output
    local ssh_success=false

    # Test with ssh-agent first
    if ssh_output=$(ssh -T git@github.com -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new 2>&1); then
        # SSH command succeeded (exit code 0) - unexpected but valid
        if echo "$ssh_output" | grep -q "successfully authenticated"; then
            log_success "✓ GitHub SSH authentication validated (ssh-agent)"
            ssh_success=true
        fi
    elif [[ $? -eq 1 ]]; then
        # SSH command returned exit code 1 (expected for GitHub)
        if echo "$ssh_output" | grep -q "successfully authenticated"; then
            log_success "✓ GitHub SSH authentication validated (ssh-agent)"
            ssh_success=true
        fi
    fi

    # Try with explicit ed25519 key if ssh-agent failed
    if [[ "$ssh_success" != "true" && -f ~/.ssh/id_ed25519 ]]; then
        if ssh_output=$(ssh -T git@github.com -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i ~/.ssh/id_ed25519 2>&1); then
            if echo "$ssh_output" | grep -q "successfully authenticated"; then
                log_success "✓ GitHub SSH authentication validated (explicit ed25519 key)"
                export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new"
                ssh_success=true
            fi
        elif [[ $? -eq 1 ]]; then
            if echo "$ssh_output" | grep -q "successfully authenticated"; then
                log_success "✓ GitHub SSH authentication validated (explicit ed25519 key)"
                export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new"
                ssh_success=true
            fi
        fi
    fi

    # Try with explicit RSA key if both previous methods failed
    if [[ "$ssh_success" != "true" && -f ~/.ssh/id_rsa ]]; then
        if ssh_output=$(ssh -T git@github.com -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i ~/.ssh/id_rsa 2>&1); then
            if echo "$ssh_output" | grep -q "successfully authenticated"; then
                log_success "✓ GitHub SSH authentication validated (explicit RSA key)"
                export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=accept-new"
                ssh_success=true
            fi
        elif [[ $? -eq 1 ]]; then
            if echo "$ssh_output" | grep -q "successfully authenticated"; then
                log_success "✓ GitHub SSH authentication validated (explicit RSA key)"
                export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=accept-new"
                ssh_success=true
            fi
        fi
    fi

    # Final validation
    if [[ "$ssh_success" != "true" ]]; then
        log_error "GitHub SSH authentication failed"
        log_error "SSH output: $ssh_output"
        log_error "Automated deployment requires SSH access to GitHub:"
        log_error "  1. Generate SSH key: ssh-keygen -t ed25519 -C 'your_email@example.com'"
        log_error "  2. Add key to ssh-agent: ssh-add ~/.ssh/id_ed25519"
        log_error "  3. Add public key to GitHub account"
        log_error "  4. Test connection: ssh -T git@github.com"
        exit 2
    fi

    # Ensure git remote is configured for SSH
    local current_remote=$(git remote get-url origin)
    if [[ "$current_remote" == https://github.com/* ]]; then
        log_verbose "Converting git remote from HTTPS to SSH..."
        local ssh_url=$(echo "$current_remote" | sed 's|https://github.com/|git@github.com:|')
        git remote set-url origin "$ssh_url"
        log_success "✓ Git remote configured for SSH: $ssh_url"
    elif [[ "$current_remote" == git@github.com:* ]]; then
        log_success "✓ Git remote already configured for SSH: $current_remote"
    else
        log_error "Invalid git remote URL: $current_remote"
        log_error "Expected GitHub URL (HTTPS or SSH format)"
        exit 2
    fi

    log_success "Pre-flight validation completed"
}

# Phase 2: Version Management
phase2_version_management() {
    log_phase 2 "Version Management"

    log "Preparing version for build-time timestamp injection..."

    # Get current version information
    local current_full_version=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | tr -d ' ')
    local current_semantic_version=$(echo "$current_full_version" | cut -d'+' -f1)
    local current_build_number=$(echo "$current_full_version" | cut -d'+' -f2)

    log_verbose "Current version: $current_full_version"
    log_verbose "Semantic version: $current_semantic_version"
    log_verbose "Build number: $current_build_number"

    # Prepare version for build-time injection if system is available
    if [[ "${BUILD_TIME_INJECTION_AVAILABLE:-false}" == "true" ]]; then
        log "Using build-time timestamp injection workflow..."

        # Use simplified timestamp injection instead of placeholder system
        log "Generating real timestamp and updating all version files..."
        if [[ "$DRY_RUN" == "true" ]]; then
            log "DRY RUN: Would inject real timestamp into version files"
            log_verbose "Would execute: $PROJECT_ROOT/scripts/build_time_version_injector.sh inject"
        else
            # Use build time version injector to set real timestamp immediately
            if ! "$PROJECT_ROOT/scripts/build_time_version_injector.sh" inject; then
                log_error "Failed to inject real timestamp into version files"
                exit 2
            fi
            log_success "Real timestamp injected into all version files - no more BUILD_TIME_PLACEHOLDER!"
        fi

        # Verify version consistency in fallback mode
        local assets_version=$(grep '"version"' assets/version.json | cut -d'"' -f4 2>/dev/null || echo "unknown")

        log_verbose "pubspec.yaml: $current_semantic_version"
        log_verbose "assets/version.json: $assets_version"

        if [[ "$current_semantic_version" != "$assets_version" && "$assets_version" != "unknown" ]]; then
            log_warning "Version mismatch detected - will be resolved during build"
        fi
    fi

    log_success "Version management preparation completed"
}

# Phase 3: Multi-Platform Build
phase3_multiplatform_build() {
    log_phase 3 "Multi-Platform Build"

    log "Building unified package and web application with build-time timestamp injection..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would execute build scripts with timestamp injection"
        log_success "DRY RUN: Multi-platform build simulation completed"
        return 0
    fi

    # Verify unified package exists or build it with timestamp injection
    local current_semantic_version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.]*\).*/\1/')
    local package_file="dist/cloudtolocalllm-${current_semantic_version}-x86_64.tar.gz"

    if [[ ! -f "$package_file" ]]; then
        log "Unified package not found - building with timestamp injection..."

        # Build unified package with timestamp injection
        local build_script="$PROJECT_ROOT/scripts/build_unified_package.sh"
        if [[ -f "$build_script" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                if ! "$build_script"; then
                    log_warning "Failed to build unified package - continuing with web-only deployment"
                    log_warning "Unified package may need manual building later"
                else
                    log_success "Unified package built with build-time timestamp"
                fi
            else
                if ! "$build_script" &> /dev/null; then
                    log_warning "Failed to build unified package - continuing with web-only deployment"
                    log_warning "Unified package may need manual building later"
                else
                    log_success "Unified package built with build-time timestamp"
                fi
            fi
        else
            log_warning "Unified package build script not found: $build_script"
            log_warning "Unified package building skipped - continuing with web-only deployment"
        fi
    else
        log_verbose "✓ Unified package already exists: $package_file"
    fi

    # Build web application with build-time timestamp injection
    log_verbose "Building web application with build-time timestamp injection..."

    # Check if we're in WSL environment (which has Flutter line ending issues)
    local use_fallback=false
    if [[ -n "${WSL_DISTRO_NAME:-}" ]] || [[ -f "/proc/version" && $(grep -i microsoft /proc/version) ]]; then
        log_warning "WSL environment detected - using fallback Flutter build to avoid line ending issues"
        use_fallback=true
    fi

    if [[ "${BUILD_TIME_INJECTION_AVAILABLE:-false}" == "true" && "$use_fallback" == "false" ]]; then
        # Use Flutter build wrapper with timestamp injection
        local build_wrapper="$PROJECT_ROOT/scripts/flutter_build_with_timestamp.sh"
        local build_args="web --no-tree-shake-icons"

        if [[ "$VERBOSE" == "true" ]]; then
            build_args="--verbose $build_args"
        fi

        if ! "$build_wrapper" $build_args; then
            log_warning "Flutter web build with timestamp injection failed - falling back to direct build"
            use_fallback=true
        else
            log_success "Web application built with build-time timestamp injection"
        fi
    else
        use_fallback=true
    fi

    if [[ "$use_fallback" == "true" ]]; then
        # Fallback to direct Flutter build
        log_warning "Using fallback Flutter build (no timestamp injection)"

        # Use WSL Flutter if available and we're in WSL
        local flutter_cmd="flutter"
        if [[ -f "/opt/flutter/bin/flutter" && (-n "${WSL_DISTRO_NAME:-}" || -f "/proc/version") ]]; then
            flutter_cmd="/opt/flutter/bin/flutter"
            log_verbose "Using WSL Flutter: $flutter_cmd"
        fi

        if [[ "$VERBOSE" == "true" ]]; then
            if ! "$flutter_cmd" build web --release --no-tree-shake-icons; then
                log_error "Flutter web build failed"
                exit 3
            fi
        else
            if ! "$flutter_cmd" build web --release --no-tree-shake-icons &> /dev/null; then
                log_error "Flutter web build failed"
                exit 3
            fi
        fi

        log_success "Web application built (fallback mode)"
    fi

    # AUR package building removed - AUR is decommissioned

    log_success "Multi-platform build completed with build-time timestamps"
}

# Phase 4: Distribution Validation
phase4_distribution_execution() {
    log_phase 4 "Distribution Validation"

    log "Validating git repository state for automated deployment..."

    # IMPORTANT: This phase now validates git state instead of performing git operations
    # Developers must manually commit and push changes with proper changelogs before deployment
    log_verbose "Checking repository state for deployment readiness..."

    # Validate repository is clean (no uncommitted changes)
    log_verbose "Checking for uncommitted changes..."
    local git_status=$(git status --porcelain)
    if [[ -n "$git_status" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            log_warning "⚠️ Repository has uncommitted changes but continuing with force mode"
            log_verbose "Uncommitted changes detected:"
            echo "$git_status" | head -10
            if [[ $(echo "$git_status" | wc -l) -gt 10 ]]; then
                log_verbose "... and $(($(echo "$git_status" | wc -l) - 10)) more files"
            fi
        else
            log_error "❌ Repository has uncommitted changes - deployment cannot proceed"
            log_error "Please commit all changes with proper changelog before deployment:"
            echo "$git_status"
            log_error ""
            log_error "Required manual workflow before deployment:"
            log_error "  1. Review all changes: git status"
            log_error "  2. Stage changes: git add ."
            log_error "  3. Commit with changelog: git commit -m 'Release v${current_version}: [description]'"
            log_error "  4. Push to GitHub: git push origin master"
            log_error "  5. Re-run deployment script"
            log_error "  6. Or use --force flag to bypass this check"
            exit 4
        fi
    else
        log_success "✓ Repository is clean (no uncommitted changes)"
    fi

    # Validate local branch is up-to-date with origin/master
    log_verbose "Checking if local branch is up-to-date with origin/master..."
    git fetch origin master --quiet
    local unpushed_commits=$(git rev-list HEAD...origin/master --count 2>/dev/null || echo "unknown")
    if [[ "$unpushed_commits" != "0" ]]; then
        if [[ "$FORCE" == "true" ]]; then
            log_warning "⚠️ Local branch has unpushed commits but continuing with force mode"
            log_verbose "Unpushed commits: $unpushed_commits"
        else
            log_error "❌ Local branch is not synchronized with origin/master"
            log_error "Unpushed commits: $unpushed_commits"
            log_error "Please push all commits before deployment:"
            log_error "  git push origin master"
            log_error "  Or use --force flag to bypass this check"
            exit 4
        fi
    else
        log_success "✓ Local branch is up-to-date with origin/master"
    fi

    # Validate version files contain proper release version (not BUILD_TIME_PLACEHOLDER)
    local current_version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.+]*\).*/\1/')
    local semantic_version="${current_version%+*}"
    local build_number="${current_version#*+}"

    if [[ "$build_number" == "BUILD_TIME_PLACEHOLDER" ]]; then
        log_error "❌ Version files still contain BUILD_TIME_PLACEHOLDER"
        log_error "Please ensure version management (Phase 2) completed successfully"
        log_error "Current version: $current_version"
        exit 4
    fi
    log_success "✓ Version files contain proper release version: $current_version"

    # Validate distribution files exist and are committed
    local package_file="dist/cloudtolocalllm-${semantic_version}-x86_64.tar.gz"
    local checksum_file="${package_file}.sha256"

    if ! git ls-files --error-unmatch "$package_file" &> /dev/null; then
        log_warning "Distribution package not found in git repository: $package_file"
        log_warning "Continuing with web-only deployment (no binary distribution)"
        log_verbose "Binary package distribution will be skipped"
        local skip_binary_distribution=true
    else
        log_success "✓ Distribution files verified in git repository"
        local skip_binary_distribution=false
    fi

    # Validate GitHub repository state matches local repository
    log "Validating GitHub repository synchronization..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would validate GitHub repository state"
    else
        # Validate GitHub repository state without performing git operations
        local current_remote=$(git remote get-url origin)
        log_verbose "Current remote URL: $current_remote"

        # Ensure SSH remote configuration for validation
        if [[ "$current_remote" == https://github.com/* ]]; then
            log_verbose "Converting HTTPS remote to SSH for validation..."
            local ssh_url=$(echo "$current_remote" | sed 's|https://github.com/|git@github.com:|')
            git remote set-url origin "$ssh_url"
            current_remote="$ssh_url"
            log_verbose "Remote URL updated to: $current_remote"
        fi

        # Validate SSH authentication is available (but don't push)
        if [[ "$current_remote" == git@github.com:* ]]; then
            log_verbose "Validating SSH authentication to GitHub..."

            local ssh_validated=false
            local ssh_output

            # Test SSH authentication without performing operations
            if ssh_output=$(ssh -T git@github.com -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new 2>&1); then
                if echo "$ssh_output" | grep -q "successfully authenticated"; then
                    log_verbose "SSH authentication validated (ssh-agent)"
                    ssh_validated=true
                fi
            elif [[ $? -eq 1 ]]; then
                if echo "$ssh_output" | grep -q "successfully authenticated"; then
                    log_verbose "SSH authentication validated (ssh-agent)"
                    ssh_validated=true
                fi
            fi

            # Try with explicit ed25519 key if ssh-agent failed
            if [[ "$ssh_validated" != "true" && -f ~/.ssh/id_ed25519 ]]; then
                if ssh_output=$(ssh -T git@github.com -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i ~/.ssh/id_ed25519 2>&1); then
                    if echo "$ssh_output" | grep -q "successfully authenticated"; then
                        log_verbose "SSH authentication validated (explicit ed25519 key)"
                        export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new"
                        ssh_validated=true
                    fi
                elif [[ $? -eq 1 ]]; then
                    if echo "$ssh_output" | grep -q "successfully authenticated"; then
                        log_verbose "SSH authentication validated (explicit ed25519 key)"
                        export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=accept-new"
                        ssh_validated=true
                    fi
                fi
            fi

            # Try with explicit RSA key if both previous methods failed
            if [[ "$ssh_validated" != "true" && -f ~/.ssh/id_rsa ]]; then
                if ssh_output=$(ssh -T git@github.com -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new -i ~/.ssh/id_rsa 2>&1); then
                    if echo "$ssh_output" | grep -q "successfully authenticated"; then
                        log_verbose "SSH authentication validated (explicit RSA key)"
                        export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=accept-new"
                        ssh_validated=true
                    fi
                elif [[ $? -eq 1 ]]; then
                    if echo "$ssh_output" | grep -q "successfully authenticated"; then
                        log_verbose "SSH authentication validated (explicit RSA key)"
                        export GIT_SSH_COMMAND="ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=accept-new"
                        ssh_validated=true
                    fi
                fi
            fi

            if [[ "$ssh_validated" == "true" ]]; then
                log_success "✓ SSH authentication validated for GitHub access"
            else
                log_error "❌ SSH authentication to GitHub failed"
                log_error "SSH authentication is required for automated deployment:"
                log_error "  1. Ensure SSH key is added to GitHub account"
                log_error "  2. Verify SSH key is loaded in ssh-agent: ssh-add -l"
                log_error "  3. Test SSH connection: ssh -T git@github.com"
                log_error "  4. Verify remote URL: git remote -v"
                exit 4
            fi
        else
            log_error "Invalid remote URL format: $current_remote"
            log_error "Expected SSH format: git@github.com:CloudToLocalLLM-online/CloudToLocalLLM.git"
            exit 4
        fi

        # Validate that latest commits are already on GitHub (no push needed)
        log_verbose "Verifying latest commits are on GitHub..."
        local local_commit=$(git rev-parse HEAD)
        local remote_commit=$(git rev-parse origin/master)

        if [[ "$local_commit" != "$remote_commit" ]]; then
            log_error "❌ Local commits not synchronized with GitHub"
            log_error "Local commit: $local_commit"
            log_error "Remote commit: $remote_commit"
            log_error "Please push commits manually before deployment:"
            log_error "  git push origin master"
            exit 4
        fi
        log_success "✓ Latest commits verified on GitHub"

        # Verify GitHub raw URL accessibility with retry logic
        log_verbose "Verifying GitHub raw URL accessibility..."
        local semantic_version=$(echo "$current_version" | cut -d'+' -f1)
        local github_url="https://raw.githubusercontent.com/CloudToLocalLLM-online/CloudToLocalLLM/master/dist/cloudtolocalllm-${semantic_version}-x86_64.tar.gz"
        local max_attempts=5
        local attempt=1
        local github_accessible=false

        while [[ $attempt -le $max_attempts ]]; do
            log_verbose "Attempt $attempt/$max_attempts: Testing GitHub raw URL accessibility..."

            if curl -s -I "$github_url" | head -1 | grep -q "200"; then
                log_success "✓ GitHub raw URL accessible: $github_url"
                github_accessible=true
                break
            else
                log_verbose "GitHub raw URL not yet accessible, waiting 10 seconds..."
                sleep 10
                ((attempt++))
            fi
        done

        if [[ "$github_accessible" != "true" ]]; then
            log_warning "GitHub raw URL not accessible after $max_attempts attempts"
            log_warning "URL: $github_url"
            log_warning "Continuing with web-only deployment"
        fi

        # Verify checksum consistency between local and GitHub files
        log_verbose "Verifying checksum consistency between local and GitHub files..."
        local local_sha256=$(cat "dist/cloudtolocalllm-${current_version}-x86_64.tar.gz.sha256" 2>/dev/null | cut -d' ' -f1 || echo "")
        if [[ -n "$local_sha256" ]]; then
            local github_sha256=$(curl -s "$github_url" | sha256sum | cut -d' ' -f1)
            if [[ "$local_sha256" == "$github_sha256" ]]; then
                log_success "✓ Checksum verified: local and GitHub files match"
            else
                log_error "Checksum mismatch between local and GitHub files"
                log_error "Local: $local_sha256"
                log_error "GitHub: $github_sha256"
                exit 4
            fi
        else
            log_warning "Local SHA256 file not found, skipping checksum verification"
        fi
    fi

    # Deploy to VPS with git pull for distribution files
    local vps_flags=""
    if [[ "$FORCE" == "true" ]]; then
        vps_flags="$vps_flags --force"
    fi
    if [[ "$VERBOSE" == "true" ]]; then
        vps_flags="$vps_flags --verbose"
    fi
    if [[ "$SKIP_BACKUP" == "true" ]]; then
        vps_flags="$vps_flags --skip-backup"
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        vps_flags="$vps_flags --dry-run"
    fi

    log_verbose "Deploying to VPS with enhanced error handling..."
    local vps_deploy_cmd="cd /opt/CloudToLocalLLM && git stash && git pull origin master && ./scripts/deploy/update_and_deploy.sh $vps_flags"

    if ! ssh_execute "cloudllm@cloudtolocalllm.online" "$vps_deploy_cmd" 300 3; then
        log_error "VPS deployment failed after multiple attempts"
        log_error "Attempting recovery with force reset..."

        # Try recovery with force reset
        local recovery_cmd="cd /opt/CloudToLocalLLM && git reset --hard HEAD && git clean -fd && git pull origin master && ./scripts/deploy/update_and_deploy.sh $vps_flags"

        if ! ssh_execute "cloudllm@cloudtolocalllm.online" "$recovery_cmd" 300 1; then
            log_error "VPS deployment recovery failed"
            exit 4
        fi

        log_success "VPS deployment recovered successfully"
    fi

    # AUR package testing and submission removed - AUR is decommissioned

    log_success "Git-based distribution validation completed"
}

# Phase 5: Comprehensive Verification
phase5_comprehensive_verification() {
    log_phase 5 "Comprehensive Verification"

    log "Performing comprehensive verification with build-time timestamp validation..."

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DRY RUN: Would perform verification checks including timestamp validation"
        log_success "DRY RUN: Verification simulation completed"
        return 0
    fi

    # Test API backend health first
    log_verbose "Testing API backend health..."
    if ! wait_for_service "https://app.cloudtolocalllm.online/api/health" 120 10; then
        log_error "API backend failed to become healthy"
        exit 5
    fi

    # Test web platform with enhanced error handling
    log_verbose "Testing web platform accessibility..."
    if ! wait_for_service "https://app.cloudtolocalllm.online" 120 10; then
        log_error "Web platform failed to become accessible"
        exit 5
    fi

    # Test version endpoint with build-time timestamp validation
    log_verbose "Testing version endpoint and build-time timestamps..."
    local expected_semantic_version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.]*\).*/\1/')
    local expected_full_version=$(grep '^version:' pubspec.yaml | sed 's/version: *//' | tr -d ' ')
    local expected_build_number=$(echo "$expected_full_version" | cut -d'+' -f2)

    # Retrieve version information from endpoint
    local version_json
    if version_json=$(curl_with_retry "https://app.cloudtolocalllm.online/version.json" --max-retries 5); then
        local deployed_version=$(echo "$version_json" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
        local deployed_build_number=$(echo "$version_json" | grep -o '"build_number":"[^"]*"' | cut -d'"' -f4)
        local deployed_build_date=$(echo "$version_json" | grep -o '"build_date":"[^"]*"' | cut -d'"' -f4)

        # Validate semantic version
        if [[ "$deployed_version" == "$expected_semantic_version" ]]; then
            log_verbose "✓ Deployed semantic version correct: $deployed_version"
        else
            log_error "Deployed semantic version mismatch: expected $expected_semantic_version, got $deployed_version"
            exit 5
        fi

        # Validate build number format and content
        if [[ "$deployed_build_number" =~ ^[0-9]{12}$ ]]; then
            log_verbose "✓ Deployed build number format valid: $deployed_build_number"

            # Verify timestamp is real (not placeholder) and reasonable
            if [[ "$deployed_build_number" != "BUILD_TIME_PLACEHOLDER" ]]; then
                log_success "✓ Real timestamp injection verified: $deployed_build_number"

                # Validate timestamp is reasonable (within last 24 hours)
                local current_timestamp=$(date +"%Y%m%d%H%M")
                local timestamp_diff=$((current_timestamp - deployed_build_number))

                    if [[ $timestamp_diff -ge 0 && $timestamp_diff -le 10000 ]]; then
                        log_verbose "✓ Build timestamp is recent and valid"
                    else
                        log_warning "Build timestamp seems unusual: $deployed_build_number (diff: $timestamp_diff)"
                    fi
                else
                    log_error "❌ BUILD_TIME_PLACEHOLDER found in deployed version - timestamp injection failed"
                    exit 5
                fi
        else
            log_error "Deployed build number format invalid: $deployed_build_number"
            exit 5
        fi

        # Validate build date is present
        if [[ -n "$deployed_build_date" ]]; then
            log_verbose "✓ Build date present: $deployed_build_date"
        else
            log_warning "Build date missing from version endpoint"
        fi

    else
        log_error "Failed to retrieve version information from endpoint"
        exit 5
    fi

    log_success "Comprehensive verification with build-time timestamp validation completed"
}

# Phase 6: Operational Readiness
phase6_operational_readiness() {
    log_phase 6 "Operational Readiness"

    log "Confirming operational readiness with build timestamp correlation..."

    # Get deployment timing information
    local deployment_end_time=$(date +"%Y%m%d%H%M")
    local deployment_iso_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Display deployment summary with build-time timestamp information
    local deployed_version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.+]*\).*/\1/')
    local deployed_semantic_version="${deployed_version%+*}"
    local deployed_build_number="${deployed_version#*+}"

    echo ""
    echo -e "${GREEN}🎉 CloudToLocalLLM v${deployed_version} Deployment Completed Successfully!${NC}"
    echo -e "${GREEN}================================================================${NC}"
    echo ""
    echo -e "${BLUE}📋 Deployment Summary:${NC}"
    echo "  ✅ Version: v${deployed_version}"
    echo "  ✅ Build Timestamp: $deployed_build_number"

    # Calculate and display build-to-deployment correlation
    if [[ "$deployed_build_number" =~ ^[0-9]{12}$ && "$deployed_build_number" != "BUILD_TIME_PLACEHOLDER" ]]; then
        local build_deployment_diff=$((deployment_end_time - deployed_build_number))
        local build_time_formatted="${deployed_build_number:0:4}-${deployed_build_number:4:2}-${deployed_build_number:6:2} ${deployed_build_number:8:2}:${deployed_build_number:10:2}"

        echo "  ✅ Build Time: $build_time_formatted UTC"
        echo "  ✅ Deployment Time: $deployment_iso_time"
        echo "  ✅ Build-to-Deployment: ${build_deployment_diff} minutes"

        if [[ "${BUILD_TIME_INJECTION_AVAILABLE:-false}" == "true" ]]; then
            echo "  ✅ Build-Time Injection: Enabled"
        else
            echo "  ⚠️  Build-Time Injection: Fallback mode"
        fi
    else
        echo "  ⚠️  Build Timestamp: Invalid or placeholder"
    fi

    echo "  ✅ Git-based Distribution: Repository as single source of truth"
    echo "  ✅ Static Download: https://cloudtolocalllm.online/cloudtolocalllm-${deployed_semantic_version}-x86_64.tar.gz"
    echo "  ✅ Web Platform: https://app.cloudtolocalllm.online"
    echo "  ✅ API Backend: https://app.cloudtolocalllm.online/api/health"
    echo "  ✅ Tunnel Server: wss://app.cloudtolocalllm.online/ws/bridge"
    echo ""
    echo -e "${BLUE}📋 Build Timestamp Correlation:${NC}"

    if [[ "${BUILD_TIME_INJECTION_AVAILABLE:-false}" == "true" ]]; then
        echo "  ✅ Build artifacts contain actual build execution timestamps"
        echo "  ✅ Version endpoints reflect true build creation time"
        echo "  ✅ Package metadata includes accurate build timestamps"
        echo "  ✅ Deployment logs correlate with build timestamps"
    else
        echo "  ⚠️  Using fallback versioning (no build-time injection)"
        echo "  ⚠️  Build timestamps may not reflect actual build execution time"
    fi

    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "  1. Verify platform-specific UI features"
    echo "  2. Monitor deployment health and build timestamp correlation"
    echo "  3. Validate build timestamps in monitoring systems"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo ""
        echo -e "${YELLOW}📋 DRY RUN completed - no actual deployment performed${NC}"
    else
        echo ""
        echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
        echo ""
        echo -e "${YELLOW}📋 Next Steps - Manual Version Management:${NC}"
        echo -e "  ${BLUE}1.${NC} Verify deployment is working correctly"
        echo -e "  ${BLUE}2.${NC} Run manual version increment when ready:"
        echo -e "     ${CYAN}./scripts/powershell/version_manager.ps1 increment patch${NC}  # For bug fixes"
        echo -e "     ${CYAN}./scripts/powershell/version_manager.ps1 increment minor${NC}  # For new features"
        echo -e "     ${CYAN}./scripts/powershell/version_manager.ps1 increment major${NC}  # For breaking changes"
        echo -e "  ${BLUE}3.${NC} Commit and push version changes:"
        echo -e "     ${CYAN}git add . && git commit -m \"Increment version after deployment\" && git push${NC}"
        echo ""
        echo -e "${YELLOW}💡 Version increment is now manual to give you control over when versions are committed.${NC}"
    fi

    log_success "Operational readiness confirmed with build timestamp correlation"
}

# Main execution
main() {
    # Header
    local target_version=$(grep '^version:' pubspec.yaml | sed 's/version: *\([0-9.+]*\).*/\1/')
    echo -e "${BLUE}CloudToLocalLLM Complete Automated Deployment v${target_version%+*}+${NC}"
    echo -e "${BLUE}======================================================${NC}"
    echo "Target: CloudToLocalLLM v${target_version} Production Deployment"
    echo "Strategy: Six-Phase Automated Workflow"
    echo "Distribution: Static Download + VPS"
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Non-interactive execution - no prompts allowed
    # Use --force flag to bypass safety checks in automated environments
    if [[ "$FORCE" != "true" && "$DRY_RUN" != "true" ]]; then
        log_warning "Production deployment starting without --force flag"
        log_warning "Use --force flag for automated/CI environments"
        log "Proceeding with deployment in 3 seconds..."
        sleep 3
    elif [[ "$FORCE" == "true" ]]; then
        log "Force mode enabled - proceeding with automated deployment"
    fi
    
    # Execute six-phase deployment workflow
    phase1_preflight_validation
    phase2_version_management
    phase3_multiplatform_build
    phase4_distribution_execution
    phase5_comprehensive_verification
    phase6_operational_readiness
}

# Enhanced error handling with cleanup
cleanup_on_error() {
    local exit_code=$?

    # Don't treat successful exit as error
    if [[ $exit_code -eq 0 ]]; then
        return 0
    fi

    # Prevent recursive calls
    if [[ "${CLEANUP_IN_PROGRESS:-false}" == "true" ]]; then
        return $exit_code
    fi
    export CLEANUP_IN_PROGRESS=true

    if declare -F log_error &> /dev/null; then
        log_error "Deployment failed at line $LINENO in phase ${CURRENT_PHASE:-unknown} with exit code $exit_code"
        log_error "Check logs above for details"
    else
        echo "ERROR: Deployment failed at line $LINENO in phase ${CURRENT_PHASE:-unknown} with exit code $exit_code"
    fi

    # Cleanup any temporary files
    if declare -F cleanup_temp_files &> /dev/null; then
        cleanup_temp_files "/tmp/cloudtolocalllm-deploy-*"
    fi

    exit $exit_code
}

# Setup signal handlers for graceful shutdown
if declare -F setup_signal_handlers &> /dev/null; then
    setup_signal_handlers cleanup_on_error
else
    # Fallback signal handling if utils not available
    trap 'cleanup_on_error' EXIT
    trap 'cleanup_on_error; exit 130' INT
    trap 'cleanup_on_error; exit 143' TERM
fi
trap 'cleanup_on_error' ERR

# Execute main function
main "$@"
