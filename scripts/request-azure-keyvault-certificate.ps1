# Request SSL Certificate from Azure Key Vault Certificate Issuer
# This requests a certificate from Azure Key Vault using a configured certificate issuer

$ErrorActionPreference = "Stop"

$KEY_VAULT_NAME = "zoidbot-kv"
$CERT_NAME = "zoidbot-wildcard"
$DOMAIN = "zoidbot.online"
$WILDCARD_DOMAIN = "*.zoidbot.online"

Write-Host "🔐 Requesting certificate from Azure Key Vault..." -ForegroundColor Cyan

# Check if issuer exists
Write-Host "Checking certificate issuers..." -ForegroundColor Yellow
$issuers = az keyvault certificate issuer list --vault-name $KEY_VAULT_NAME --query "[].name" -o tsv 2>&1

if ($LASTEXITCODE -ne 0 -or -not $issuers) {
    Write-Host "❌ No certificate issuers found in Key Vault" -ForegroundColor Red
    Write-Host "Please run: .\scripts\setup-azure-keyvault-certificate-issuer.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Found issuers: $issuers" -ForegroundColor Green
$issuerName = ($issuers -split "`n")[0]

# Certificate policy for wildcard certificate
Write-Host ""
Write-Host "Creating certificate policy..." -ForegroundColor Cyan

$policyJson = @{
    keyProperties = @{
        exportable = $true
        keyType = "RSA"
        keySize = 2048
        reuseKey = $false
    }
    secretProperties = @{
        contentType = "application/x-pkcs12"
    }
    x509CertificateProperties = @{
        subject = "CN=$DOMAIN"
        subjectAlternativeNames = @{
            dnsNames = @($DOMAIN, $WILDCARD_DOMAIN)
        }
        validityInMonths = 12
        keyUsage = @("digitalSignature", "keyEncipherment")
        enhancedKeyUsage = @("1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2")
    }
    issuerParameters = @{
        name = $issuerName
        certificateType = "WildCard"
    }
} | ConvertTo-Json -Depth 10

$policyFile = New-TemporaryFile
$policyJson | Set-Content -Path $policyFile.FullName

# Create certificate policy
Write-Host "Setting certificate policy..." -ForegroundColor Cyan
az keyvault certificate policy create `
    --vault-name $KEY_VAULT_NAME `
    --name $CERT_NAME `
    --policy $policyFile.FullName 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Policy may already exist, continuing..." -ForegroundColor Yellow
}

Remove-Item $policyFile.FullName -Force

# Request certificate
Write-Host ""
Write-Host "Requesting certificate from $issuerName..." -ForegroundColor Cyan
Write-Host "This may take a few minutes..." -ForegroundColor Yellow

az keyvault certificate create `
    --vault-name $KEY_VAULT_NAME `
    --name $CERT_NAME `
    --policy $policyFile.FullName 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Certificate requested successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Certificate status:" -ForegroundColor Cyan
    az keyvault certificate show --vault-name $KEY_VAULT_NAME --name $CERT_NAME --query "{Status:attributes.enabled, Expires:attributes.expires}" -o table
} else {
    Write-Host "⚠️  Certificate request initiated. Check status:" -ForegroundColor Yellow
    Write-Host "   az keyvault certificate show --vault-name $KEY_VAULT_NAME --name $CERT_NAME" -ForegroundColor White
}

Write-Host ""
Write-Host "📋 Next: Sync certificate to Kubernetes" -ForegroundColor Cyan
Write-Host "   kubectl create job --from=cronjob/sync-cert-to-keyvault sync-now -n zoidbot" -ForegroundColor White

