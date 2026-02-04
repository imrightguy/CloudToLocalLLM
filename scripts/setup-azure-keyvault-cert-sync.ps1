# Setup Azure Key Vault integration with cert-manager
# This syncs certificates from Kubernetes secrets to Azure Key Vault
# Maintains platform independence for certificate issuance (ACME) while using Azure Key Vault for storage

$ErrorActionPreference = "Stop"

$RESOURCE_GROUP = if ($env:AZURE_RESOURCE_GROUP) { $env:AZURE_RESOURCE_GROUP } else { "zoidbot-rg" }
$KEY_VAULT_NAME = if ($env:AZURE_KEY_VAULT_NAME) { $env:AZURE_KEY_VAULT_NAME } else { "zoidbot-kv" }
$LOCATION = if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { "eastus" }

Write-Host "🔐 Setting up Azure Key Vault certificate sync..." -ForegroundColor Cyan

# Get subscription ID
$SUBSCRIPTION_ID = az account show --query id -o tsv
if (-not $SUBSCRIPTION_ID) {
    Write-Host "❌ Not logged into Azure. Please run: az login" -ForegroundColor Red
    exit 1
}

# Create Key Vault if it doesn't exist
$kvExists = az keyvault show --name $KEY_VAULT_NAME --resource-group $RESOURCE_GROUP 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "📦 Creating Azure Key Vault: $KEY_VAULT_NAME" -ForegroundColor Yellow
    az keyvault create `
        --name $KEY_VAULT_NAME `
        --resource-group $RESOURCE_GROUP `
        --location $LOCATION `
        --enabled-for-deployment true `
        --enabled-for-template-deployment true `
        --enabled-for-disk-encryption true
    Write-Host "✅ Key Vault created" -ForegroundColor Green
} else {
    Write-Host "✅ Key Vault already exists" -ForegroundColor Green
}

# Get service principal from existing secret
Write-Host ""
Write-Host "📋 Setting up access for certificate sync..." -ForegroundColor Cyan

try {
    $secret = kubectl get secret azure-dns-config -n cert-manager -o json 2>&1 | ConvertFrom-Json
    $CLIENT_ID = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($secret.data.'client-id'))
    $CLIENT_SECRET = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($secret.data.'client-secret'))
    $TENANT_ID = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($secret.data.'tenant-id'))
    
    Write-Host "✅ Found existing Azure credentials from secret" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Azure service principal not found. Please provide credentials:" -ForegroundColor Yellow
    $CLIENT_ID = Read-Host "Azure Client ID"
    $CLIENT_SECRET = Read-Host "Azure Client Secret" -AsSecureString | ConvertFrom-SecureString -AsPlainText
    $TENANT_ID = Read-Host "Azure Tenant ID"
}

# Grant access to Key Vault
Write-Host "🔑 Granting access to Key Vault..." -ForegroundColor Cyan
try {
    $spId = az ad sp show --id $CLIENT_ID --query id -o tsv 2>&1
    if ($LASTEXITCODE -eq 0 -and $spId) {
        az keyvault set-policy `
            --name $KEY_VAULT_NAME `
            --object-id $spId `
            --secret-permissions get list set `
            --certificate-permissions get list import | Out-Null
    } else {
        az keyvault set-policy `
            --name $KEY_VAULT_NAME `
            --spn $CLIENT_ID `
            --secret-permissions get list set `
            --certificate-permissions get list import | Out-Null
    }
    Write-Host "✅ Access granted" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not grant access automatically. Please grant manually:" -ForegroundColor Yellow
    Write-Host "   az keyvault set-policy --name $KEY_VAULT_NAME --spn $CLIENT_ID --secret-permissions get list set --certificate-permissions get list import" -ForegroundColor White
}

Write-Host ""
Write-Host "✅ Azure Key Vault setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Install Azure CSI Secret Store Driver:" -ForegroundColor White
Write-Host "   kubectl apply -f https://raw.githubusercontent.com/Azure/secrets-store-csi-driver-provider-azure/master/deployment/secrets-store-csi-driver.yaml" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Update k8s/azure-keyvault-csi-driver.yaml with your credentials" -ForegroundColor White
Write-Host ""
Write-Host "3. Apply the sync configuration:" -ForegroundColor White
Write-Host "   kubectl apply -f k8s/azure-keyvault-csi-driver.yaml" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Certificates will automatically sync from Kubernetes secrets to Key Vault every 6 hours" -ForegroundColor White
Write-Host ""
Write-Host "✅ Certificates will be available in Key Vault: $KEY_VAULT_NAME" -ForegroundColor Green

