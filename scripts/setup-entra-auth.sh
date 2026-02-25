#!/bin/bash
set -e

# Configuration
APP_NAME="CloudToLocalLLM-Auth"
REPO_OWNER="imrightguy"
REPO_NAME="CloudToLocalLLM"
ENV_FILE=".env.entra"

echo "Checking Azure CLI login status..."
az account show > /dev/null 2>&1 || { echo "Please login to Azure CLI first using 'az login'"; exit 1; }

echo "Creating Entra ID Application: $APP_NAME..."
# Create the App Registration
APP_ID=$(az ad app create --display-name "$APP_NAME" --sign-in-audience AzureADMyOrg --query appId -o tsv)
OBJECT_ID=$(az ad app show --id "$APP_ID" --query id -o tsv)

echo "App ID: $APP_ID"

# Create Service Principal (required for some operations)
echo "Creating Service Principal..."
SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)

# Get Tenant ID
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "Tenant ID: $TENANT_ID"

# reset credentials
echo "Resetting/Creating Client Secret..."
CLIENT_SECRET=$(az ad app credential reset --id "$APP_ID" --append --display-name "GitHubMethod" --years 1 --query password -o tsv)

# Construct Issuer URL
ISSUER_URL="https://login.microsoftonline.com/$TENANT_ID/v2.0"

echo "--------------------------------------------------"
echo "Configuration Details:"
echo "Client ID: $APP_ID"
echo "Tenant ID: $TENANT_ID"
echo "Issuer URL: $ISSUER_URL"
echo "--------------------------------------------------"

# Save to local .env file for reference (gitignored)
echo "Writing to $ENV_FILE..."
cat <<EOF > "$ENV_FILE"
ENTRA_CLIENT_ID=$APP_ID
ENTRA_TENANT_ID=$TENANT_ID
ENTRA_CLIENT_SECRET=$CLIENT_SECRET
ENTRA_ISSUER_URL=$ISSUER_URL
EOF

# Update GitHub Secrets
echo "Updating GitHub Secrets for repo $REPO_OWNER/$REPO_NAME..."

# Check if gh is installed and logged in
if command -v gh &> /dev/null; then
    # Set new secrets
    echo "Setting ENTRA_ISSUER_URL..."
    echo "$ISSUER_URL" | gh secret set ENTRA_ISSUER_URL -R "$REPO_OWNER/$REPO_NAME"
    
    echo "Setting ENTRA_CLIENT_ID..."
    echo "$APP_ID" | gh secret set ENTRA_CLIENT_ID -R "$REPO_OWNER/$REPO_NAME"
    
    echo "Setting ENTRA_TENANT_ID..."
    echo "$TENANT_ID" | gh secret set ENTRA_TENANT_ID -R "$REPO_OWNER/$REPO_NAME"

    # Optional: Delete old Supabase secrets if confirmed
    # echo "Deleting old secrets..."
    # gh secret delete SUPABASE_URL -R "$REPO_OWNER/$REPO_NAME" || true
    # gh secret delete SUPABASE_JWT_SECRET -R "$REPO_OWNER/$REPO_NAME" || true
    
    echo "GitHub Secrets updated successfully."
else
    echo "GitHub CLI (gh) not found or not logged in. Skipping secret updates."
    echo "Please update secrets manually using the values in $ENV_FILE"
fi

echo "Done! Entra ID App '$APP_NAME' is ready."
