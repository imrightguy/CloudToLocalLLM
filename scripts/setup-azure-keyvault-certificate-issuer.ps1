# Setup Azure Key Vault Certificate Issuer
# This creates a certificate issuer in Azure Key Vault that can issue certificates from a CA
# Supports: DigiCert, GlobalSign, Sectigo, Entrust

$ErrorActionPreference = "Stop"

$KEY_VAULT_NAME = "zoidbot-kv"
$RESOURCE_GROUP = "zoidbot-rg"
$DOMAIN = "zoidbot.online"

Write-Host "🔐 Setting up Azure Key Vault Certificate Issuer..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Available Certificate Authorities:" -ForegroundColor Yellow
Write-Host "  1. DigiCert" -ForegroundColor White
Write-Host "  2. GlobalSign" -ForegroundColor White
Write-Host "  3. Sectigo (formerly Comodo)" -ForegroundColor White
Write-Host "  4. Entrust" -ForegroundColor White
Write-Host ""

$caChoice = Read-Host "Select CA (1-4) or enter CA name"
$caName = switch ($caChoice) {
    "1" { "DigiCert" }
    "2" { "GlobalSign" }
    "3" { "Sectigo" }
    "4" { "Entrust" }
    default { $caChoice }
}

if (-not $caName) {
    Write-Host "❌ Invalid CA selection" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Setting up $caName certificate issuer..." -ForegroundColor Cyan
Write-Host ""
Write-Host "⚠️  Requirements:" -ForegroundColor Yellow
Write-Host "  - Account with $caName" -ForegroundColor White
Write-Host "  - API credentials from $caName" -ForegroundColor White
Write-Host "  - Certificate product/certificate ID" -ForegroundColor White
Write-Host ""

$proceed = Read-Host "Do you have $caName account credentials? (yes/no)"
if ($proceed -ne "yes") {
    Write-Host ""
    Write-Host "Please sign up with $caName first:" -ForegroundColor Yellow
    switch ($caName) {
        "DigiCert" { Write-Host "  https://www.digicert.com/" -ForegroundColor Cyan }
        "GlobalSign" { Write-Host "  https://www.globalsign.com/" -ForegroundColor Cyan }
        "Sectigo" { Write-Host "  https://www.sectigo.com/" -ForegroundColor Cyan }
        "Entrust" { Write-Host "  https://www.entrust.com/" -ForegroundColor Cyan }
    }
    Write-Host ""
    Write-Host "Then run this script again with your credentials." -ForegroundColor White
    exit 0
}

# Get CA-specific credentials
Write-Host ""
Write-Host "Enter $caName credentials:" -ForegroundColor Cyan

switch ($caName) {
    "DigiCert" {
        $orgId = Read-Host "DigiCert Organization ID"
        $apiKey = Read-Host "DigiCert API Key" -AsSecureString | ConvertFrom-SecureString -AsPlainText
        $issuerName = "digicert"
        $providerName = "DigiCert"
    }
    "GlobalSign" {
        $orgId = Read-Host "GlobalSign Organization ID"
        $apiKey = Read-Host "GlobalSign API Key" -AsSecureString | ConvertFrom-SecureString -AsPlainText
        $issuerName = "globalsign"
        $providerName = "GlobalSign"
    }
    "Sectigo" {
        $orgId = Read-Host "Sectigo Organization ID"
        $apiKey = Read-Host "Sectigo API Key" -AsSecureString | ConvertFrom-SecureString -AsPlainText
        $issuerName = "sectigo"
        $providerName = "Sectigo"
    }
    "Entrust" {
        $orgId = Read-Host "Entrust Organization ID"
        $apiKey = Read-Host "Entrust API Key" -AsSecureString | ConvertFrom-SecureString -AsPlainText
        $issuerName = "entrust"
        $providerName = "Entrust"
    }
}

# Create certificate issuer in Key Vault
Write-Host ""
Write-Host "Creating certificate issuer in Azure Key Vault..." -ForegroundColor Cyan

$issuerConfig = @{
    provider = $providerName
    accountId = $orgId
    password = $apiKey
    organizationId = $orgId
}

az keyvault certificate issuer create `
    --vault-name $KEY_VAULT_NAME `
    --issuer-name $issuerName `
    --provider-name $providerName `
    --account-id $orgId `
    --api-key $apiKey 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Certificate issuer created: $issuerName" -ForegroundColor Green
} else {
    Write-Host "⚠️  Could not create issuer automatically. Please create via Azure Portal:" -ForegroundColor Yellow
    Write-Host "   1. Key Vault: $KEY_VAULT_NAME → Certificates → Certificate issuers" -ForegroundColor White
    Write-Host "   2. Add → Provider: $providerName" -ForegroundColor White
    Write-Host "   3. Enter credentials" -ForegroundColor White
}

Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Create certificate policy in Key Vault" -ForegroundColor White
Write-Host "  2. Request certificate from Key Vault" -ForegroundColor White
Write-Host "  3. Sync certificate to Kubernetes" -ForegroundColor White
Write-Host ""
Write-Host "See k8s/README_AZURE_KEYVAULT_CERT_ISSUER.md for details" -ForegroundColor Gray

