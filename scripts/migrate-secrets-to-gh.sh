#!/usr/bin/env bash
# scripts/migrate-secrets-to-gh.sh
# Automates the migration of hardcoded credentials to GitHub Actions secrets.
#
# This script reads values from environment variables or a local .env file
# and uploads them to the GitHub repository using the 'gh' CLI.

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting GitHub Secrets Migration...${NC}"

# 1. Verify GitHub CLI installation
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ Error: GitHub CLI (gh) is not installed.${NC}"
    echo "Please install it from: https://cli.github.com/"
    exit 1
fi

# 2. Verify GitHub CLI authentication
if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ Error: Not authenticated with GitHub CLI.${NC}"
    echo "Please run 'gh auth login' to authenticate."
    exit 1
fi

# 3. Load .env file if it exists
if [ -f .env ]; then
    echo -e "${BLUE}ℹ️  Loading secrets from .env file...${NC}"
    # Use a safe way to source .env without executing arbitrary code
    set -a
    source .env
    set +a
else
    echo -e "${YELLOW}⚠️  No .env file found. Reading from environment variables.${NC}"
fi

# 4. Define required secrets
REQUIRED_SECRETS=(
    "AZURE_CLIENT_ID"
    "AZURE_CLIENT_SECRET"
    "AZURE_TENANT_ID"
    "AZURE_SUBSCRIPTION_ID"
    "CLOUDFLARE_TUNNEL_ID"
    "CLOUDFLARE_ACCOUNT_ID"
    "CLOUDFLARE_API_TOKEN"
    "GCIP_API_KEY"
    "SENTRY_DSN"
    "POSTGRES_PASSWORD"
    "JWT_SECRET"
    "STRIPE_TEST_SECRET_KEY"
    "SUPABASE_JWT_SECRET",
    "SLACK_WEBHOOK_URL",
    "SMTP_HOST",
    "SMTP_PORT",
    "SMTP_USERNAME",
    "SMTP_PASSWORD",
    "GRAFANA_CLOUD_PROMETHEUS_URL",
    "GRAFANA_CLOUD_PROMETHEUS_USER",
    "GRAFANA_CLOUD_PROMETHEUS_TOKEN",
    "GRAFANA_ADMIN_PASSWORD",
    "POSTGRES_AUTH_PASSWORD",
    "CLOUDFLARE_TUNNEL_TOKEN",
    "KILOCODE_TOKEN"
)

# 5. Migrate secrets
SUCCESS_COUNT=0
FAIL_COUNT=0
MISSING_COUNT=0

for SECRET_NAME in "${REQUIRED_SECRETS[@]}"; do
    # Get value from environment
    SECRET_VALUE="${!SECRET_NAME:-}"
    
    if [ -z "$SECRET_VALUE" ]; then
        echo -e "${YELLOW}⚠️  Skipping $SECRET_NAME: Value not found in environment or .env${NC}"
        MISSING_COUNT=$((MISSING_COUNT + 1))
        continue
    fi
    
    echo -ne "${BLUE}⏳ Setting secret $SECRET_NAME... ${NC}"
    
    if echo -n "$SECRET_VALUE" | gh secret set "$SECRET_NAME" 2>/dev/null; then
        echo -e "${GREEN}✅ Success${NC}"
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
    else
        echo -e "${RED}❌ Failed${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

# 6. Summary
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Migration Summary:${NC}"
echo -e "  ${GREEN}✓ Successfully set:${NC} $SUCCESS_COUNT"
echo -e "  ${YELLOW}⚠ Missing/Skipped:${NC}  $MISSING_COUNT"
echo -e "  ${RED}✗ Failed:${NC}           $FAIL_COUNT"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [ $FAIL_COUNT -eq 0 ] && [ $SUCCESS_COUNT -gt 0 ]; then
    echo -e "${GREEN}🎉 Migration completed successfully!${NC}"
    echo -e "${YELLOW}⚠️  IMPORTANT: Rotate any secrets that were previously hardcoded in the repository.${NC}"
elif [ $SUCCESS_COUNT -eq 0 ]; then
    echo -e "${RED}❌ No secrets were migrated. Please check your .env file or environment variables.${NC}"
else
    echo -e "${YELLOW}⚠️  Migration completed with some issues. Review the output above.${NC}"
fi
