#!/usr/bin/env bash
#
# GitHub Secrets Setup Script for AWS EKS Deployment
#
# This script configures GitHub repository secrets required for AWS EKS deployment.
# It reads configuration from .aws-deployment-config.json and manages secrets in AWS Secrets Manager.
#
# Usage:
#   ./scripts/setup-aws-secrets.sh [OPTIONS]
#
# Options:
#   --config-file FILE      Path to AWS config file (default: .aws-deployment-config.json)
#   --repo OWNER/REPO       GitHub repository (default: from config or prompt)
#   --non-interactive       Run without prompts (use env vars for secrets)
#   --skip-validation       Skip validation of AWS CLI auth
#   --help                  Show this help message
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CONFIG_FILE=".aws-deployment-config.json"
NON_INTERACTIVE="false"
SKIP_VALIDATION="false"
EKS_CLUSTER_NAME="cloudtolocalllm-eks"

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

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}───────────────────────────────────────${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}───────────────────────────────────────${NC}"
    echo ""
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

generate_secret() {
    local length=$1
    openssl rand -base64 "$length" 2>/dev/null || echo ""
}

validate_aws_cli() {
    if [[ "$SKIP_VALIDATION" == "true" ]]; then
        return
    fi

    log_section "Validating AWS CLI"

    if ! command_exists aws; then
        log_error "AWS CLI is not installed"
        log_info "Install from: https://aws.amazon.com/cli/"
        exit 1
    fi

    log_success "AWS CLI is installed: $(aws --version | head -n 1)"

    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "Not authenticated to AWS"
        log_info "Run: aws configure or set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        exit 1
    fi

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    log_success "Authenticated to AWS (Account: $ACCOUNT_ID)"
}

load_aws_config() {
    log_section "Loading AWS Configuration"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_warning "Configuration file not found: $CONFIG_FILE"

        if [[ -n "${AWS_REGION:-}" && -n "${AWS_SECRETS_MANAGER_SECRET_ID:-}" ]]; then
            log_success "Using environment variables for AWS configuration"
            GITHUB_REPO="${GITHUB_REPOSITORY:-}"
            return
        fi

        log_error "Configuration file not found and environment variables missing."
        log_info "Run: ./scripts/setup-aws-infrastructure.sh first"
        exit 1
    fi

    log_info "Loading configuration from: $CONFIG_FILE"

    if ! command_exists jq; then
        log_error "jq is required but not installed"
        log_info "Install jq: https://stedolan.github.io/jq/download/"
        exit 1
    fi

    AWS_REGION=$(jq -r '.AWS_REGION // "us-east-1"' "$CONFIG_FILE")
    AWS_SECRETS_MANAGER_SECRET_ID=$(jq -r '.AWS_SECRETS_MANAGER_SECRET_ID // "CloudToLocalLLM/production"' "$CONFIG_FILE")

    if [[ -z "${GITHUB_REPO:-}" ]]; then
        GITHUB_REPO=$(jq -r '.GITHUB_REPO // ""' "$CONFIG_FILE")
    fi

    log_success "Configuration loaded"
    log_info "Region: $AWS_REGION"
    log_info "Secrets Manager Secret ID: $AWS_SECRETS_MANAGER_SECRET_ID"
    if [[ -n "$GITHUB_REPO" ]]; then
        log_info "Repository: $GITHUB_REPO"
    fi
}

get_secret_value() {
    local var_name="$1"
    local prompt_text="$2"
    local allow_empty="${3:-false}"
    local auto_generate="${4:-false}"
    local generate_length="${5:-32}"

    local var_value="${!var_name:-}"

    if [[ -n "$var_value" ]]; then
        echo "$var_value"
        return
    fi

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

collect_secrets() {
    log_section "Collecting Required Secrets"

    log_info "The following secrets will be configured:"
    echo ""
    echo "AWS Configuration:"
    echo "  ✓ AWS_REGION: $AWS_REGION"
    echo "  ✓ AWS_SECRETS_MANAGER_SECRET_ID: $AWS_SECRETS_MANAGER_SECRET_ID"
    echo ""
    echo "Application Secrets (will prompt if not set as env vars):"
    echo "  • POSTGRES_PASSWORD (auto-generated if empty)"
    echo "  • JWT_SECRET (auto-generated if empty)"
    echo "  • STRIPE_TEST_SECRET_KEY (required)"
    echo "  • STRIPE_TEST_PUBLISHABLE_KEY (optional)"
    echo "  • STRIPE_TEST_WEBHOOK_SECRET (optional)"
    echo "  • STRIPE_LIVE_SECRET_KEY (optional)"
    echo "  • STRIPE_LIVE_PUBLISHABLE_KEY (optional)"
    echo "  • STRIPE_LIVE_WEBHOOK_SECRET (optional)"
    echo "  • SENTRY_DSN (optional)"
    echo "  • CLOUDFLARE_DNS_TOKEN (required)"
    echo "  • CLOUDFLARE_TUNNEL_TOKEN (required)"
    echo "  • SUPABASE_JWT_SECRET (optional)"
    echo ""

    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        read -p "Continue? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi

    log_info "Collecting secrets..."
    echo ""

    POSTGRES_PASSWORD=$(get_secret_value "POSTGRES_PASSWORD" "PostgreSQL Database Password" false true 32)
    log_success "POSTGRES_PASSWORD: ****"

    JWT_SECRET=$(get_secret_value "JWT_SECRET" "JWT Secret Key" false true 48)
    log_success "JWT_SECRET: ****"

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

    SENTRY_DSN=$(get_secret_value "SENTRY_DSN" "Sentry DSN (optional, https://...@sentry.io/...)" true false)
    if [[ -n "$SENTRY_DSN" ]]; then
        log_success "SENTRY_DSN: ****"
    else
        log_info "SENTRY_DSN: (not set)"
    fi

    CLOUDFLARE_DNS_TOKEN=$(get_secret_value "CLOUDFLARE_DNS_TOKEN" "Cloudflare DNS Token (for DNS challenges)" false false)
    log_success "CLOUDFLARE_DNS_TOKEN: ****"

    CLOUDFLARE_TUNNEL_TOKEN=$(get_secret_value "CLOUDFLARE_TUNNEL_TOKEN" "Cloudflare Tunnel Token" false false)
    log_success "CLOUDFLARE_TUNNEL_TOKEN: ****"

    SUPABASE_JWT_SECRET=$(get_secret_value "SUPABASE_JWT_SECRET" "Supabase JWT Secret (optional)" true false)
    if [[ -n "$SUPABASE_JWT_SECRET" ]]; then
        log_success "SUPABASE_JWT_SECRET: ****"
    else
        log_info "SUPABASE_JWT_SECRET: (not set)"
    fi

    log_success "All secrets collected"
}

store_secrets_in_aws() {
    log_section "Storing Secrets in AWS Secrets Manager"

    SECRET_STRING=$(cat <<EOF
{
  "POSTGRES_PASSWORD": "$POSTGRES_PASSWORD",
  "JWT_SECRET": "$JWT_SECRET",
  "STRIPE_TEST_SECRET_KEY": "$STRIPE_TEST_SECRET_KEY",
  "STRIPE_TEST_PUBLISHABLE_KEY": "${STRIPE_TEST_PUBLISHABLE_KEY:-}",
  "STRIPE_TEST_WEBHOOK_SECRET": "${STRIPE_TEST_WEBHOOK_SECRET:-}",
  "STRIPE_LIVE_SECRET_KEY": "${STRIPE_LIVE_SECRET_KEY:-}",
  "STRIPE_LIVE_PUBLISHABLE_KEY": "${STRIPE_LIVE_PUBLISHABLE_KEY:-}",
  "STRIPE_LIVE_WEBHOOK_SECRET": "${STRIPE_LIVE_WEBHOOK_SECRET:-}",
  "SENTRY_DSN": "${SENTRY_DSN:-}",
  "CLOUDFLARE_DNS_TOKEN": "$CLOUDFLARE_DNS_TOKEN",
  "CLOUDFLARE_TUNNEL_TOKEN": "$CLOUDFLARE_TUNNEL_TOKEN",
  "SUPABASE_JWT_SECRET": "${SUPABASE_JWT_SECRET:-}"
}
EOF
)

    if aws secretsmanager describe-secret --secret-id "$AWS_SECRETS_MANAGER_SECRET_ID" >/dev/null 2>&1; then
        log_info "Secret already exists, updating..."
        aws secretsmanager update-secret \
            --secret-id "$AWS_SECRETS_MANAGER_SECRET_ID" \
            --secret-string "$SECRET_STRING" \
            --region "$AWS_REGION"
        log_success "Secrets updated in AWS Secrets Manager"
    else
        log_info "Creating new secret..."
        aws secretsmanager create-secret \
            --name "$AWS_SECRETS_MANAGER_SECRET_ID" \
            --secret-string "$SECRET_STRING" \
            --region "$AWS_REGION"
        log_success "Secrets created in AWS Secrets Manager"
    fi
}

set_github_secrets() {
    if [[ -z "$GITHUB_REPO" ]]; then
        log_warning "GITHUB_REPO not set, skipping GitHub secrets configuration"
        return
    fi

    log_section "Setting GitHub Secrets"

    log_info "Setting secrets for repository: $GITHUB_REPO"

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

    set_secret "AWS_ACCESS_KEY_ID" "$AWS_ACCESS_KEY_ID"
    set_secret "AWS_SECRET_ACCESS_KEY" "$AWS_SECRET_ACCESS_KEY"
    set_secret "AWS_REGION" "$AWS_REGION"
    set_secret "AWS_SECRETS_MANAGER_SECRET_ID" "$AWS_SECRETS_MANAGER_SECRET_ID"
    set_secret "EKS_CLUSTER_NAME" "$EKS_CLUSTER_NAME"

    log_success "All GitHub secrets configured"
}

validate_secrets() {
    log_section "Validating AWS Secrets"

    log_info "Verifying secrets are stored correctly..."

    if aws secretsmanager describe-secret --secret-id "$AWS_SECRETS_MANAGER_SECRET_ID" >/dev/null 2>&1; then
        log_success "Secrets Manager secret exists"

        aws secretsmanager get-secret-value \
            --secret-id "$AWS_SECRETS_MANAGER_SECRET_ID" \
            --region "$AWS_REGION" \
            --query 'SecretString' \
            --output text | jq -r 'keys[]' | sort | uniq > /tmp/secrets_list.txt

        local required_keys=("POSTGRES_PASSWORD" "JWT_SECRET" "CLOUDFLARE_DNS_TOKEN" "CLOUDFLARE_TUNNEL_TOKEN")
        local missing=0

        for key in "${required_keys[@]}"; do
            if grep -q "^$key$" /tmp/secrets_list.txt; then
                log_success "$key is present"
            else
                log_error "$key is missing"
                missing=$((missing + 1))
            fi
        done

        if [[ $missing -eq 0 ]]; then
            log_success "All required secrets are present"
        else
            log_error "$missing required secret(s) are missing"
            exit 1
        fi
    else
        log_error "Secrets Manager secret not found"
        exit 1
    fi
}

generate_summary() {
    log_section "Configuration Complete"

    echo ""
    echo -e "${GREEN}────────────────────────────────────────${NC}"
    echo -e "${GREEN}✓ GitHub Secrets Setup Complete!${NC}"
    echo -e "${GREEN}────────────────────────────────────────${NC}"
    echo ""
    echo "Repository: ${GITHUB_REPO:-not set}"
    echo ""
    echo "AWS Configuration:"
    echo "  • Region: $AWS_REGION"
    echo "  • Secrets Manager Secret ID: $AWS_SECRETS_MANAGER_SECRET_ID"
    if [[ -n "$EKS_CLUSTER_NAME" ]]; then
        echo "  • EKS Cluster Name: $EKS_CLUSTER_NAME"
    fi
    echo ""
    echo "Next Steps:"
    echo "  1. Push code to main branch:"
    echo "     git push origin main"
    echo ""
    echo "  2. Monitor deployment:"
    if [[ -n "$GITHUB_REPO" ]]; then
        echo "     gh run watch --repo $GITHUB_REPO"
    fi
    echo ""
    echo "  3. Verify EKS cluster access:"
    echo "     aws eks update-kubeconfig --name $EKS_CLUSTER_NAME"
    echo "     kubectl get nodes"
    echo ""

    local secrets_file=".aws-secrets-reference.txt"
    cat > "$secrets_file" <<EOF
# AWS Secrets Reference
# DO NOT COMMIT THIS FILE!
# This file is for your reference only.

Repository: ${GITHUB_REPO:-not set}
Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

AWS Configuration:
  AWS_REGION: $AWS_REGION
  AWS_SECRETS_MANAGER_SECRET_ID: $AWS_SECRETS_MANAGER_SECRET_ID
  EKS_CLUSTER_NAME: ${EKS_CLUSTER_NAME:-cloudtolocalllm-eks}

Application Secrets:
  POSTGRES_PASSWORD: [stored in AWS Secrets Manager]
  JWT_SECRET: [stored in AWS Secrets Manager]
  STRIPE_TEST_SECRET_KEY: [stored in AWS Secrets Manager]
  CLOUDFLARE_DNS_TOKEN: [stored in AWS Secrets Manager]
  CLOUDFLARE_TUNNEL_TOKEN: [stored in AWS Secrets Manager]
  SUPABASE_JWT_SECRET: [stored in AWS Secrets Manager]
  SENTRY_DSN: ${SENTRY_DSN:-[not set]}

⚠️  IMPORTANT: Keep this file secure and never commit it to version control!
EOF

    log_info "Secrets reference saved to: $secrets_file"
    log_warning "Keep this file secure! Add to .gitignore if not already."
}

main() {
    log_section "GitHub Secrets Setup for AWS EKS Deployment"
    log_info "CloudToLocalLLM - AWS EKS Configuration"

    validate_aws_cli
    load_aws_config
    collect_secrets

    if [[ "${CI:-}" != "true" ]]; then
        store_secrets_in_aws
        set_github_secrets
        validate_secrets
    else
        log_info "Running in CI environment - skipping secret updates and API validation (read-only mode)"
    fi

    generate_summary

    log_success "All done! 🎉"
}

main "$@"
