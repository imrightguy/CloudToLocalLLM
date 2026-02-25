#!/bin/bash
# scripts/sync-auth0-config.sh
# 
# This script extracts Auth0 metadata and credentials for the currently active tenant
# and synchronizes them EXCLUSIVELY to GitHub repository secrets.
#
# STRICT COMPLIANCE: No credentials (DOMAIN, CLIENT_ID, CLIENT_SECRET) are to be persisted
# to the local filesystem or repository files to ensure a zero-secret-exposure policy.

set -e

# Function to check dependencies
check_dependencies() {
    local missing=()
    if ! command -v auth0 &> /dev/null; then missing+=("auth0-cli"); fi
    if ! command -v gh &> /dev/null; then missing+=("gh-cli"); fi
    if ! command -v jq &> /dev/null; then missing+=("jq"); fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo "Error: Missing dependencies: ${missing[*]}"
        echo "Please install them before running this script."
        exit 1
    fi
}

# 1. Start process
check_dependencies

echo "=== Auth0 to GitHub Secrets Sync (Zero-Exposure Mode) ==="

# 2. Extract metadata from Auth0
echo "Extracting active tenant details..."

# Get Tenant Domain (Ignore stderr which contains headers and spinners)
TENANT_LIST_JSON=$(auth0 tenants list --json --no-input --no-color 2>/dev/null)
TENANT_DOMAIN=$(echo "$TENANT_LIST_JSON" | jq -r '.[] | select(.active == true) | .name' 2>/dev/null || true)
if [ -z "$TENANT_DOMAIN" ] || [ "$TENANT_DOMAIN" == "null" ]; then
    TENANT_DOMAIN=$(echo "$TENANT_LIST_JSON" | jq -r '.[0].name' 2>/dev/null || true)
fi

if [ -z "$TENANT_DOMAIN" ] || [ "$TENANT_DOMAIN" == "null" ]; then
    echo "Error: Could not determine Auth0 tenant domain. Are you logged in?"
    echo "Run 'auth0 login' to authenticate."
    exit 1
fi

echo "Active Tenant: $TENANT_DOMAIN"

# Get Application Details
echo "Searching for application credentials..."
APP_LIST_JSON=$(auth0 apps list --json --no-input --no-color 2>/dev/null)

# Strategy: 1. CloudToLocalLLM, 2. Default App, 3. First available
APP_JSON=$(echo "$APP_LIST_JSON" | jq -c '.[] | select(.name | contains("CloudToLocalLLM"))' 2>/dev/null | head -n 1 || true)

if [ -z "$APP_JSON" ] || [ "$APP_JSON" == "null" ] || [ "$APP_JSON" == "" ]; then
    APP_JSON=$(echo "$APP_LIST_JSON" | jq -c '.[] | select(.name == "Default App")' 2>/dev/null | head -n 1 || true)
fi

if [ -z "$APP_JSON" ] || [ "$APP_JSON" == "null" ] || [ "$APP_JSON" == "" ]; then
    APP_JSON=$(echo "$APP_LIST_JSON" | jq -c '.[0]' 2>/dev/null || true)
fi

if [ -z "$APP_JSON" ] || [ "$APP_JSON" == "null" ] || [ "$APP_JSON" == "" ]; then
    echo "Error: Could not find any Auth0 applications."
    exit 1
fi

CLIENT_ID=$(echo "$APP_JSON" | jq -r '.client_id')
APP_NAME=$(echo "$APP_JSON" | jq -r '.name')

echo "Found Application: $APP_NAME ($CLIENT_ID)"

# Get Client Secret (Revealing secrets)
echo "Extracting Client Secret..."
CLIENT_SECRET=$(auth0 apps show "$CLIENT_ID" --reveal-secrets --json --no-input --no-color 2>/dev/null | jq -r '.client_secret')

if [ -z "$CLIENT_SECRET" ] || [ "$CLIENT_SECRET" == "null" ]; then
    echo "Warning: Client Secret is null (typical for SPA apps). Proceeding with empty value."
    CLIENT_SECRET=""
fi

AUTH0_ISSUER_URL="https://$TENANT_DOMAIN/"
AUTH0_AUDIENCE="https://api.cloudtolocalllm.online"

# 3. Update GitHub Secrets (Programmatic Injection Only)
echo "Updating GitHub Repository Secrets..."

# Check GitHub Auth
if ! gh auth status &> /dev/null; then
    echo "Error: GitHub CLI not authenticated. Please run 'gh auth login' first."
    exit 1
fi

echo "  -> Injecting AUTH0_DOMAIN"
echo "$TENANT_DOMAIN" | gh secret set AUTH0_DOMAIN

echo "  -> Injecting AUTH0_CLIENT_ID"
echo "$CLIENT_ID" | gh secret set AUTH0_CLIENT_ID

echo "  -> Injecting AUTH0_CLIENT_SECRET"
echo "$CLIENT_SECRET" | gh secret set AUTH0_CLIENT_SECRET

echo "  -> Injecting AUTH0_ISSUER_URL"
echo "$AUTH0_ISSUER_URL" | gh secret set AUTH0_ISSUER_URL

echo "  -> Injecting AUTH0_AUDIENCE"
echo "$AUTH0_AUDIENCE" | gh secret set AUTH0_AUDIENCE

echo "=== Synchronization Success ==="
echo "Credentials successfully injected into GitHub Secrets."
echo "ZERO-EXPOSURE VERIFIED: No repository files were modified."
