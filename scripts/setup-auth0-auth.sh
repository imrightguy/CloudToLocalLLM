#!/bin/bash
set -e

# Configuration
REPO_OWNER="imrightguy"
REPO_NAME="CloudToLocalLLM"
ENV_FILE=".env.auth0"

echo "Setting up Auth0 authentication for CloudToLocalLLM..."
echo ""

# Prompt for Auth0 configuration
read -p "Enter your Auth0 Domain (e.g., your-tenant.auth0.com): " AUTH0_DOMAIN
if [[ -z "$AUTH0_DOMAIN" ]]; then echo "Error: Auth0 Domain is required." && exit 1; fi

read -p "Enter your Auth0 Client ID: " AUTH0_CLIENT_ID
if [[ -z "$AUTH0_CLIENT_ID" ]]; then echo "Error: Auth0 Client ID is required." && exit 1; fi

read -p "Enter your Auth0 Client Secret (optional for SPA): " AUTH0_CLIENT_SECRET

read -p "Enter your Auth0 Audience (default: https://api.cloudtolocalllm.online): " AUTH0_AUDIENCE
AUTH0_AUDIENCE=${AUTH0_AUDIENCE:-https://api.cloudtolocalllm.online}

# Construct Issuer URL
AUTH0_ISSUER_URL="https://$AUTH0_DOMAIN/"

echo ""
echo "--------------------------------------------------"
echo "Configuration Details (Zero-Hardcode Enforcement):"
echo "Domain: $AUTH0_DOMAIN"
echo "Client ID: $AUTH0_CLIENT_ID"
echo "Audience: $AUTH0_AUDIENCE"
echo "Issuer URL: $AUTH0_ISSUER_URL"
echo "--------------------------------------------------"

# Save to local .env file for reference (gitignored)
echo "Writing to $ENV_FILE..."
cat <<EOF > "$ENV_FILE"
AUTH0_DOMAIN=$AUTH0_DOMAIN
AUTH0_CLIENT_ID=$AUTH0_CLIENT_ID
AUTH0_CLIENT_SECRET=$AUTH0_CLIENT_SECRET
AUTH0_ISSUER_URL=$AUTH0_ISSUER_URL
AUTH0_AUDIENCE=$AUTH0_AUDIENCE
EOF

# Update GitHub Secrets
echo "Updating GitHub Secrets for repo $REPO_OWNER/$REPO_NAME..."

# Check if gh is installed and logged in
if command -v gh &> /dev/null; then
    # Check if gh is authenticated
    if gh auth status &>/dev/null; then
        # Set new Auth0 secrets
        echo "Setting AUTH0_ISSUER_URL..."
        echo "$AUTH0_ISSUER_URL" | gh secret set AUTH0_ISSUER_URL -R "$REPO_OWNER/$REPO_NAME"

        echo "Setting AUTH0_CLIENT_ID..."
        echo "$AUTH0_CLIENT_ID" | gh secret set AUTH0_CLIENT_ID -R "$REPO_OWNER/$REPO_NAME"

        echo "Setting AUTH0_CLIENT_SECRET..."
        echo "$AUTH0_CLIENT_SECRET" | gh secret set AUTH0_CLIENT_SECRET -R "$REPO_OWNER/$REPO_NAME"

        echo "Setting AUTH0_DOMAIN..."
        echo "$AUTH0_DOMAIN" | gh secret set AUTH0_DOMAIN -R "$REPO_OWNER/$REPO_NAME"

        echo "Setting AUTH0_AUDIENCE..."
        echo "$AUTH0_AUDIENCE" | gh secret set AUTH0_AUDIENCE -R "$REPO_OWNER/$REPO_NAME"

        # Optional: Delete old Entra secrets
        echo "Removing old ENTRA secrets..."
        gh secret delete ENTRA_ISSUER_URL -R "$REPO_OWNER/$REPO_NAME" 2>/dev/null || echo "ENTRA_ISSUER_URL not found or already deleted"
        gh secret delete ENTRA_CLIENT_ID -R "$REPO_OWNER/$REPO_NAME" 2>/dev/null || echo "ENTRA_CLIENT_ID not found or already deleted"
        gh secret delete ENTRA_TENANT_ID -R "$REPO_OWNER/$REPO_NAME" 2>/dev/null || echo "ENTRA_TENANT_ID not found or already deleted"

        echo "GitHub Secrets updated successfully."
    else
        echo "GitHub CLI is not authenticated. Please run 'gh auth login' first."
        echo "Please update secrets manually using the values in $ENV_FILE"
    fi
else
    echo "GitHub CLI (gh) not found. Please install it from https://cli.github.com/"
    echo "Please update secrets manually using the values in $ENV_FILE"
fi

echo ""
echo "Done! Auth0 authentication is configured."
echo "Local config saved to: $ENV_FILE"
echo ""
echo "Next steps:"
echo "1. Update your Auth0 application settings if needed"
echo "2. Redeploy your application to pick up the new secrets"
echo "3. Test authentication flow to ensure Auth0 is working"
