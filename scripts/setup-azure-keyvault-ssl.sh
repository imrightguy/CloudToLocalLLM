#!/bin/bash

# Setup Azure Key Vault and Managed Certificate for SSL
# This script creates an Azure Key Vault and sets up a managed certificate

set -e

RESOURCE_GROUP="CloudToLocalLLM-rg"
KEY_VAULT_NAME="CloudToLocalLLM-kv"
DOMAIN="cloudtolocalllm.online"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}"

echo "ðŸ” Setting up Azure Key Vault for SSL certificate management..."

# Create Key Vault if it doesn't exist
if ! az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null; then
    echo "Creating Azure Key Vault..."
    az keyvault create \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location eastus \
        --enabled-for-deployment true \
        --enabled-for-template-deployment true \
        --enabled-for-disk-encryption true
    echo "âœ… Key Vault created"
else
    echo "âœ… Key Vault already exists"
fi

echo ""
echo "ðŸ“‹ Next steps for Azure-managed SSL certificates:"
echo ""
echo "Option 1: Import existing certificate to Key Vault"
echo "  az keyvault certificate import \\"
echo "    --vault-name $KEY_VAULT_NAME \\"
echo "    --name $DOMAIN \\"
echo "    --file certificate.pfx"
echo ""
echo "Option 2: Use Azure Application Gateway with managed certificates"
echo "  - Create Application Gateway with managed certificate"
echo "  - Certificate will be automatically provisioned by Azure"
echo ""
echo "Option 3: Use cert-manager with Azure DNS-01 challenge"
echo "  - Configure cert-manager to use Azure DNS for validation"
echo "  - Certificates stored in Kubernetes secrets"
echo ""
echo "âœ… Azure Key Vault ready for SSL certificate management"

