#!/usr/bin/env bash
#
# Fix Azure OIDC Subject for GitHub Actions
#
# This script updates the Federated Credential in Azure AD to match the current
# GitHub repository name. This resolves AADSTS700213 errors.
#
# Usage:
#   ./scripts/fix-oidc-subject.sh
#

set -euo pipefail

# Configuration
# Update these if your repo or branch differs
GITHUB_REPO="CloudToLocalLLM-online/CloudToLocalLLM"
BRANCH="main"
CREDENTIAL_NAME="github-actions-main"

echo "🔧 Fixing Azure OIDC Federated Credential..."
echo "Target Repo: $GITHUB_REPO"
echo "Target Branch: $BRANCH"

# Check if logged in
if ! az account show >/dev/null 2>&1; then
    echo "❌ Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
fi

# Get Client ID from env or prompt
if [[ -z "${AZURE_CLIENT_ID:-}" ]]; then
    echo "⚠️ AZURE_CLIENT_ID not set."
    read -p "Enter Service Principal Client/App ID: " AZURE_CLIENT_ID
fi

if [[ -z "$AZURE_CLIENT_ID" ]]; then
    echo "❌ Client ID required."
    exit 1
fi

# Get the Object ID of the App Registration (not the SP) associated with this Client ID
echo "🔍 Looking up App Registration for Client ID: $AZURE_CLIENT_ID..."
APP_OBJECT_ID=$(az ad app list --app-id "$AZURE_CLIENT_ID" --query "[0].id" -o tsv)

if [[ -z "$APP_OBJECT_ID" ]]; then
    echo "❌ Could not find App Registration for Client ID $AZURE_CLIENT_ID"
    exit 1
fi

echo "✅ Found App Object ID: $APP_OBJECT_ID"

# Check existing credential
echo "🔍 Checking existing federated credential '$CREDENTIAL_NAME'..."
EXISTING_SUBJECT=$(az ad app federated-credential show --id "$APP_OBJECT_ID" --federated-credential-id "$CREDENTIAL_NAME" --query "subject" -o tsv 2>/dev/null || echo "")

NEW_SUBJECT="repo:${GITHUB_REPO}:ref:refs/heads/${BRANCH}"

if [[ "$EXISTING_SUBJECT" == "$NEW_SUBJECT" ]]; then
    echo "✅ Credential subject is already correct: $EXISTING_SUBJECT"
    exit 0
fi

if [[ -n "$EXISTING_SUBJECT" ]]; then
    echo "⚠️  Found incorrect subject: $EXISTING_SUBJECT"
    echo "🔄 Updating to:            $NEW_SUBJECT"
    
    # Delete and Recreate (Update sometimes has constraints)
    az ad app federated-credential delete --id "$APP_OBJECT_ID" --federated-credential-id "$CREDENTIAL_NAME"
else
    echo "⚠️  Credential not found. Creating new one..."
fi

# Create new credential
cat > federated-credential.json <<EOF
{
  "name": "$CREDENTIAL_NAME",
  "issuer": "https://token.actions.githubusercontent.com",
  "subject": "$NEW_SUBJECT",
  "description": "GitHub Actions for $GITHUB_REPO ($BRANCH)",
  "audiences": [
    "api://AzureADTokenExchange"
  ]
}
EOF

az ad app federated-credential create --id "$APP_OBJECT_ID" --parameters federated-credential.json

rm federated-credential.json

echo "✅ Successfully updated Federated Credential!"
echo "🚀 Retrying the GitHub Action run should now succeed."
