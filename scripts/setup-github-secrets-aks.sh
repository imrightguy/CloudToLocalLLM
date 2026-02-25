#!/usr/bin/env bash
#
# GitHub Secrets Setup Script for AKS Deployment
#
# This script configures GitHub repository secrets required for AKS deployment.
# It reads configuration from .azure-deployment-config.json (created by setup-azure-aks-infrastructure.sh)
# and prompts for additional required secrets.
#
# Usage:
#   ./scripts/setup-github-secrets-aks.sh [OPTIONS]
#
# Options:
#   --config-file FILE      Path to Azure config file (default: .azure-deployment-config.json)
#   --repo OWNER/REPO       GitHub repository (default: from config or prompt)
#   --non-interactive       Run without prompts (use env vars for secrets)
#   --skip-validation       Skip validation of GitHub CLI auth
#   --help                  Show this help message
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
CONFIG_FILE=".azure-deployment-config.json"
NON_INTERACTIVE="false"
SKIP_VALIDATION="false"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --config-file)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --repo)
      GITHUB_REPO="$2"
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE="true"
      shift
      ;;
    --skip-validation)
      SKIP_VALIDATION="true"
      shift
      ;;
    --help)
      head -n 20 "$0" | tail -n +2 | sed 's/^# //'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Helper functions
log_info() {
    echo -e "${BLUE}â„¹${NC} $1"
}

log_success() {
    echo -e "${GREEN}âœ“${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}âš ${NC} $1"
}

log_error() {
    echo -e "${RED}âœ—${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
    echo ""
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Generate secure random string
generate_secret() {
    local length=$1
    openssl rand -base64 "$length" 2>/dev/null || echo ""
}

# Validate GitHub CLI
validate_github_cli() {
    if [[ "$SKIP_VALIDATION" == "true" ]]; then
        return
    fi
    
    log_section "Validating GitHub CLI"
    
    if ! command_exists gh; then
        log_error "GitHub CLI is not installed"
        log_info "Install from: https://cli.github.com/"
        exit 1
    fi
    
    log_success "GitHub CLI is installed: $(gh --version | head -n 1)"
    
    # Check if authenticated
    if ! gh auth status >/dev/null 2>&1; then
        log_error "Not authenticated to GitHub CLI"
        log_info "Run: gh auth login"
        exit 1
    fi
    
    log_success "Authenticated to GitHub CLI"
}

# Load Azure configuration
load_azure_config() {
    log_section "Loading Azure Configuration"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "Configuration file not found: $CONFIG_FILE"
        
        # Check if we have env vars instead (CI scenario)
        if [[ -n "${AZURE_SUBSCRIPTION_ID:-}" && -n "${AZURE_TENANT_ID:-}" && -n "${AZURE_CLIENT_ID:-}" && -n "${AZURE_KEY_VAULT_NAME:-}" ]]; then
            log_success "Using environment variables for Azure configuration"
            GITHUB_REPO="${GITHUB_REPOSITORY:-}"
            return
        fi

        log_error "Configuration file not found and environment variables missing."
        log_info "Run: ./scripts/setup-azure-aks-infrastructure.sh"
        exit 1
    fi
    
    log_info "Loading configuration from: $CONFIG_FILE"
    
    # Check if jq is installed
    if ! command_exists jq; then
        log_error "jq is required but not installed"
        log_info "Install jq: https://stedolan.github.io/jq/download/"
        exit 1
    fi
    
    # Load values from config file
    AZURE_SUBSCRIPTION_ID=$(jq -r '.AZURE_SUBSCRIPTION_ID' "$CONFIG_FILE")
    AZURE_TENANT_ID=$(jq -r '.AZURE_TENANT_ID' "$CONFIG_FILE")
    AZURE_CLIENT_ID=$(jq -r '.AZURE_CLIENT_ID' "$CONFIG_FILE")
    AZURE_KEY_VAULT_NAME=$(jq -r '.AZURE_KEY_VAULT_NAME' "$CONFIG_FILE")
    
    if [[ -z "${GITHUB_REPO:-}" ]]; then
        GITHUB_REPO=$(jq -r '.GITHUB_REPO' "$CONFIG_FILE")
    fi
    
    log_success "Configuration loaded"
    log_info "Repository: $GITHUB_REPO"
}

# Prompt for or use environment variable
get_secret_value() {
    local var_name="$1"
    local prompt_text="$2"
    local allow_empty="${3:-false}"
    local auto_generate="${4:-false}"
    local generate_length="${5:-32}"
    
    # Check if already set as environment variable
    local var_value="${!var_name:-}"
    
    if [[ -n "$var_value" ]]; then
        echo "$var_value"
        return
    fi
    
    # Non-interactive mode handling
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        if [[ "$auto_generate" == "true" ]]; then
            local generated=$(generate_secret "$generate_length")
            echo "$generated"
            return
        elif [[ "$allow_empty" == "true" ]]; then
            echo ""
            return
        else
            log_error "Required variable $var_name not set in non-interactive mode"
            exit 1
        fi
    fi
    
    # Interactive mode
    if [[ "$auto_generate" == "true" ]]; then
        local default_value=$(generate_secret "$generate_length")
        echo ""
        echo "$prompt_text"
        echo "  (Leave empty to auto-generate secure value)"
        read -s -p "> " input_value
        echo ""
        
        if [[ -z "$input_value" ]]; then
            echo "$default_value"
        else
            echo "$input_value"
        fi
    else
        echo ""
        echo "$prompt_text"
        if [[ "$allow_empty" == "true" ]]; then
            echo "  (Optional - press Enter to skip)"
        fi
        read -s -p "> " input_value
        echo ""
        
        if [[ -z "$input_value" && "$allow_empty" != "true" ]]; then
            log_error "This value is required"
            exit 1
        fi
        
        echo "$input_value"
    fi
}

# Collect all required secrets
collect_secrets() {
    log_section "Collecting Required Secrets"
    
    log_info "The following secrets will be configured in GitHub:"
    echo ""
    echo "Azure Configuration (from $CONFIG_FILE):"
    echo "  âœ“ AZURE_CLIENT_ID"
    echo "  âœ“ AZURE_TENANT_ID"
    echo "  âœ“ AZURE_SUBSCRIPTION_ID"
    echo "  âœ“ AZURE_KEY_VAULT_NAME"
    echo ""
    echo "Application Secrets (will prompt if not set as env vars):"
    echo "  â€¢ POSTGRES_PASSWORD (auto-generated if empty)"
    echo "  â€¢ JWT_SECRET (auto-generated if empty)"
    echo "  â€¢ STRIPE_TEST_SECRET_KEY (required)"
    echo "  â€¢ STRIPE_TEST_PUBLISHABLE_KEY (optional)"
    echo "  â€¢ STRIPE_TEST_WEBHOOK_SECRET (optional)"
    echo "  â€¢ STRIPE_LIVE_SECRET_KEY (optional)"
    echo "  â€¢ STRIPE_LIVE_PUBLISHABLE_KEY (optional)"
    echo "  â€¢ STRIPE_LIVE_WEBHOOK_SECRET (optional)"
    echo "  â€¢ SENTRY_DSN (optional)"
    echo "  â€¢ CLOUDFLARE_DNS_TOKEN (required)"
    echo "  â€¢ CLOUDFLARE_TUNNEL_TOKEN (required)"
    echo ""
    
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        read -p "Continue? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi
    
    # Collect secrets
    log_info "Collecting secrets..."
    echo ""
    
    # Database password (auto-generate)
    POSTGRES_PASSWORD=$(get_secret_value "POSTGRES_PASSWORD" "PostgreSQL Database Password" false true 32)
    log_success "POSTGRES_PASSWORD: ****"
    
    # JWT Secret (auto-generate)
    JWT_SECRET=$(get_secret_value "JWT_SECRET" "JWT Secret Key" false true 48)
    log_success "JWT_SECRET: ****"
    
    # Stripe secrets
    STRIPE_TEST_SECRET_KEY=$(get_secret_value "STRIPE_TEST_SECRET_KEY" "Stripe Test Secret Key (sk_test_...)" false false)
    log_success "STRIPE_TEST_SECRET_KEY: ****"
    
    STRIPE_TEST_PUBLISHABLE_KEY=$(get_secret_value "STRIPE_TEST_PUBLISHABLE_KEY" "Stripe Test Publishable Key (pk_test_...)" true false)
    if [[ -n "$STRIPE_TEST_PUBLISHABLE_KEY" ]]; then
        log_success "STRIPE_TEST_PUBLISHABLE_KEY: ****"
    else
        log_info "STRIPE_TEST_PUBLISHABLE_KEY: (not set)"
    fi
    
    STRIPE_TEST_WEBHOOK_SECRET=$(get_secret_value "STRIPE_TEST_WEBHOOK_SECRET" "Stripe Test Webhook Secret (whsec_...)" true false)
    if [[ -n "$STRIPE_TEST_WEBHOOK_SECRET" ]]; then
        log_success "STRIPE_TEST_WEBHOOK_SECRET: ****"
    else
        log_info "STRIPE_TEST_WEBHOOK_SECRET: (not set)"
    fi
    
    # Optional live Stripe keys
    STRIPE_LIVE_SECRET_KEY=$(get_secret_value "STRIPE_LIVE_SECRET_KEY" "Stripe Live Secret Key (optional, sk_live_...)" true false)
    if [[ -n "$STRIPE_LIVE_SECRET_KEY" ]]; then
        log_success "STRIPE_LIVE_SECRET_KEY: ****"
    else
        log_info "STRIPE_LIVE_SECRET_KEY: (not set)"
    fi
    
    STRIPE_LIVE_PUBLISHABLE_KEY=$(get_secret_value "STRIPE_LIVE_PUBLISHABLE_KEY" "Stripe Live Publishable Key (optional, pk_live_...)" true false)
    if [[ -n "$STRIPE_LIVE_PUBLISHABLE_KEY" ]]; then
        log_success "STRIPE_LIVE_PUBLISHABLE_KEY: ****"
    else
        log_info "STRIPE_LIVE_PUBLISHABLE_KEY: (not set)"
    fi
    
    STRIPE_LIVE_WEBHOOK_SECRET=$(get_secret_value "STRIPE_LIVE_WEBHOOK_SECRET" "Stripe Live Webhook Secret (optional, whsec_...)" true false)
    if [[ -n "$STRIPE_LIVE_WEBHOOK_SECRET" ]]; then
        log_success "STRIPE_LIVE_WEBHOOK_SECRET: ****"
    else
        log_info "STRIPE_LIVE_WEBHOOK_SECRET: (not set)"
    fi
    
    # Sentry DSN (optional)
    SENTRY_DSN=$(get_secret_value "SENTRY_DSN" "Sentry DSN (optional, https://...@sentry.io/...)" true false)
    if [[ -n "$SENTRY_DSN" ]]; then
        log_success "SENTRY_DSN: ****"
    else
        log_info "SENTRY_DSN: (not set)"
    fi
    
    # Cloudflare tokens
    CLOUDFLARE_DNS_TOKEN=$(get_secret_value "CLOUDFLARE_DNS_TOKEN" "Cloudflare DNS Token (for DNS challenges)" false false)
    log_success "CLOUDFLARE_DNS_TOKEN: ****"
    
    CLOUDFLARE_TUNNEL_TOKEN=$(get_secret_value "CLOUDFLARE_TUNNEL_TOKEN" "Cloudflare Tunnel Token" false false)
    log_success "CLOUDFLARE_TUNNEL_TOKEN: ****"
    
    # Supabase JWT secret
    
    log_success "All secrets collected"
}

# Set GitHub secrets
set_github_secrets() {
    log_section "Setting GitHub Secrets"
    
    log_info "Setting secrets for repository: $GITHUB_REPO"
    
    # Function to set a secret
    set_secret() {
        local name="$1"
        local value="$2"
        
        if [[ -z "$value" ]]; then
            log_info "Skipping $name (not set)"
            return
        fi
        
        echo -n "$value" | gh secret set "$name" \
            --repo "$GITHUB_REPO" \
            --body - \
            >/dev/null 2>&1
        
        log_success "$name"
    }
    
    # Set Azure secrets
    set_secret "AZURE_CLIENT_ID" "$AZURE_CLIENT_ID"
    set_secret "AZURE_TENANT_ID" "$AZURE_TENANT_ID"
    set_secret "AZURE_SUBSCRIPTION_ID" "$AZURE_SUBSCRIPTION_ID"
    set_secret "AZURE_KEY_VAULT_NAME" "$AZURE_KEY_VAULT_NAME"
    
    # Set application secrets
    set_secret "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
    set_secret "JWT_SECRET" "$JWT_SECRET"
    set_secret "STRIPE_TEST_SECRET_KEY" "$STRIPE_TEST_SECRET_KEY"
    set_secret "STRIPE_TEST_PUBLISHABLE_KEY" "$STRIPE_TEST_PUBLISHABLE_KEY"
    set_secret "STRIPE_TEST_WEBHOOK_SECRET" "$STRIPE_TEST_WEBHOOK_SECRET"
    set_secret "STRIPE_LIVE_SECRET_KEY" "$STRIPE_LIVE_SECRET_KEY"
    set_secret "STRIPE_LIVE_PUBLISHABLE_KEY" "$STRIPE_LIVE_PUBLISHABLE_KEY"
    set_secret "STRIPE_LIVE_WEBHOOK_SECRET" "$STRIPE_LIVE_WEBHOOK_SECRET"
    set_secret "SENTRY_DSN" "$SENTRY_DSN"
    set_secret "CLOUDFLARE_DNS_TOKEN" "$CLOUDFLARE_DNS_TOKEN"
    set_secret "CLOUDFLARE_TUNNEL_TOKEN" "$CLOUDFLARE_TUNNEL_TOKEN"
    
    log_success "All secrets configured in GitHub"
}

# Validate secrets are set
validate_secrets() {
    log_section "Validating GitHub Secrets"
    
    log_info "Verifying secrets are set correctly..."
    
    local required_secrets=(
        "AZURE_CLIENT_ID"
        "AZURE_TENANT_ID"
        "AZURE_SUBSCRIPTION_ID"
        "AZURE_KEY_VAULT_NAME"
        "POSTGRES_PASSWORD"
        "JWT_SECRET"
        "STRIPE_TEST_SECRET_KEY"
        "CLOUDFLARE_DNS_TOKEN"
        "CLOUDFLARE_TUNNEL_TOKEN"
    )
    
    local all_secrets=$(gh secret list --repo "$GITHUB_REPO" 2>/dev/null || echo "")
    
    local missing_count=0
    for secret in "${required_secrets[@]}"; do
        if echo "$all_secrets" | grep -q "^$secret"; then
            log_success "$secret is set"
        else
            log_error "$secret is missing"
            missing_count=$((missing_count + 1))
        fi
    done
    
    if [[ $missing_count -eq 0 ]]; then
        log_success "All required secrets are set"
    else
        log_error "$missing_count required secret(s) are missing"
        exit 1
    fi
}

# Generate summary
generate_summary() {
    log_section "Configuration Complete"
    
    echo ""
    echo -e "${GREEN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
    echo -e "${GREEN}âœ“ GitHub Secrets Setup Complete!${NC}"
    echo -e "${GREEN}â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”${NC}"
    echo ""
    echo "Repository: $GITHUB_REPO"
    echo ""
    echo "Azure Configuration:"
    echo "  â€¢ Subscription: $AZURE_SUBSCRIPTION_ID"
    echo "  â€¢ Tenant: $AZURE_TENANT_ID"
    echo "  â€¢ Service Principal: $AZURE_CLIENT_ID"
    echo "  â€¢ Key Vault: $AZURE_KEY_VAULT_NAME"
    echo ""
    echo "Next Steps:"
    echo "  1. Push code to main branch:"
    echo "     git push origin main"
    echo ""
    echo "  2. Monitor deployment:"
    echo "     gh run watch --repo $GITHUB_REPO"
    echo ""
    echo "  3. View logs if issues occur:"
    echo "     gh run list --repo $GITHUB_REPO"
    echo "     gh run view <run-id> --log --repo $GITHUB_REPO"
    echo ""
    
    # Save secrets to local file for reference (DO NOT COMMIT)
    local secrets_file=".github-secrets-reference.txt"
    cat > "$secrets_file" <<EOF
# GitHub Secrets Reference
# DO NOT COMMIT THIS FILE!
# This file is for your reference only.

Repository: $GITHUB_REPO
Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Azure Configuration:
  AZURE_CLIENT_ID: $AZURE_CLIENT_ID
  AZURE_TENANT_ID: $AZURE_TENANT_ID
  AZURE_SUBSCRIPTION_ID: $AZURE_SUBSCRIPTION_ID
  AZURE_KEY_VAULT_NAME: $AZURE_KEY_VAULT_NAME

Application Secrets:
  POSTGRES_PASSWORD: $POSTGRES_PASSWORD
  JWT_SECRET: $JWT_SECRET
  STRIPE_TEST_SECRET_KEY: [redacted]
  CLOUDFLARE_DNS_TOKEN: [redacted]
  CLOUDFLARE_TUNNEL_TOKEN: [redacted]
  # SUPABASE_JWT_SECRET: [redacted]
  SENTRY_DSN: ${SENTRY_DSN:-[not set]}

âš ï¸  IMPORTANT: Keep this file secure and never commit it to version control!
EOF
    
    log_info "Secrets reference saved to: $secrets_file"
    log_warning "Keep this file secure! Add to .gitignore if not already."
}

# Main execution
main() {
    log_section "GitHub Secrets Setup for AKS Deployment"
    log_info "CloudToLocalLLM - GitHub Actions Configuration"
    
    validate_github_cli
    load_azure_config
    collect_secrets
    
    if [[ "${CI:-}" != "true" ]]; then
        set_github_secrets
        validate_secrets
    else
        log_info "Running in CI environment - skipping secret updates and API validation (read-only mode)"
    fi
    
    generate_summary
    
    log_success "All done! ðŸŽ‰"
}

# Run main function
main "$@"

