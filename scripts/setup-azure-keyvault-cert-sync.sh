#!/bin/bash

# Setup Azure Key Vault integration with cert-manager
# This syncs certificates from Kubernetes secrets to Azure Key Vault
# Maintains platform independence for certificate issuance (ACME) while using Azure Key Vault for storage

set -e

RESOURCE_GROUP="${AZURE_RESOURCE_GROUP:-CloudToLocalLLM-rg}"
KEY_VAULT_NAME="${AZURE_KEY_VAULT_NAME:-CloudToLocalLLM-kv}"
LOCATION="${AZURE_LOCATION:-eastus}"
SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID}"

echo "ðŸ” Setting up Azure Key Vault certificate sync..."

# Get or create subscription ID
if [ -z "$SUBSCRIPTION_ID" ]; then
    SUBSCRIPTION_ID=$(az account show --query id -o tsv)
fi

# Create Key Vault if it doesn't exist
if ! az keyvault show --name "$KEY_VAULT_NAME" --resource-group "$RESOURCE_GROUP" &>/dev/null 2>&1; then
    echo "ðŸ“¦ Creating Azure Key Vault: $KEY_VAULT_NAME"
    az keyvault create \
        --name "$KEY_VAULT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --location "$LOCATION" \
        --enabled-for-deployment true \
        --enabled-for-template-deployment true \
        --enabled-for-disk-encryption true
    echo "âœ… Key Vault created"
else
    echo "âœ… Key Vault already exists"
fi

# Get service principal for AKS (or create one)
echo ""
echo "ðŸ“‹ Setting up access for certificate sync..."

# Option 1: Use existing service principal (from azure-dns-config secret)
# Get client ID from existing secret
CLIENT_ID=$(kubectl get secret azure-dns-config -n cert-manager -o jsonpath='{.data.client-id}' | base64 -d 2>/dev/null || echo "")

if [ -z "$CLIENT_ID" ]; then
    echo "âš ï¸  Azure service principal not found. Please provide credentials:"
    read -p "Azure Client ID: " CLIENT_ID
    read -p "Azure Client Secret: " CLIENT_SECRET
    read -p "Azure Tenant ID: " TENANT_ID
else
    CLIENT_SECRET=$(kubectl get secret azure-dns-config -n cert-manager -o jsonpath='{.data.client-secret}' | base64 -d 2>/dev/null || echo "")
    TENANT_ID=$(kubectl get secret azure-dns-config -n cert-manager -o jsonpath='{.data.tenant-id}' | base64 -d 2>/dev/null || echo "")
fi

# Grant access to Key Vault
echo "ðŸ”‘ Granting access to Key Vault..."
az keyvault set-policy \
    --name "$KEY_VAULT_NAME" \
    --object-id "$(az ad sp show --id "$CLIENT_ID" --query id -o tsv 2>/dev/null || echo "")" \
    --secret-permissions get list set \
    --certificate-permissions get list import || \
az keyvault set-policy \
    --name "$KEY_VAULT_NAME" \
    --spn "$CLIENT_ID" \
    --secret-permissions get list set \
    --certificate-permissions get list import

echo ""
echo "âœ… Azure Key Vault setup complete!"
echo ""
echo "ðŸ“‹ Next steps:"
echo ""
echo "1. Install Azure CSI Secret Store Driver:"
echo "   kubectl apply -f https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/deployment/secrets-store-csi-driver.yaml"
echo ""
echo "2. Update azure-keyvault-csi-driver.yaml with your credentials"
echo ""
echo "3. Apply the sync configuration:"
echo "   kubectl apply -f k8s/azure-keyvault-csi-driver.yaml"
echo ""
echo "4. Certificates will automatically sync from Kubernetes secrets to Key Vault every 6 hours"
echo ""
echo "âœ… Certificates will be available in Key Vault: $KEY_VAULT_NAME"

