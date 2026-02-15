# ============================================================================
# GitHub Secrets Setup Script
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║            GitHub Secrets Setup for CI/CD                      ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "This script will help you set up GitHub repository secrets for CI/CD." -ForegroundColor Yellow
Write-Host ""

# Check if gh CLI is installed
if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host "GitHub CLI (gh) is not installed." -ForegroundColor Red
    Write-Host "Install it from: https://cli.github.com/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or set secrets manually at:" -ForegroundColor Yellow
    Write-Host "https://github.com/Zoidbot-online/Zoidbot/settings/secrets/actions" -ForegroundColor White
    exit 1
}

# Authenticate with GitHub
Write-Host "Checking GitHub authentication..." -ForegroundColor Cyan
$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not authenticated with GitHub. Running 'gh auth login'..." -ForegroundColor Yellow
    gh auth login
}

Write-Host "✓ Authenticated with GitHub" -ForegroundColor Green
Write-Host ""

# Repository
$repo = "Zoidbot-online/Zoidbot"
Write-Host "Repository: $repo" -ForegroundColor Cyan
Write-Host ""

# Collect secrets
Write-Host "=== Required Secrets ===" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. DigitalOcean Access Token" -ForegroundColor Cyan
$doToken = Read-Host "Enter your DigitalOcean Personal Access Token" -MaskInput

Write-Host ""
Write-Host "2. Domain Name" -ForegroundColor Cyan
$domain = Read-Host "Enter your domain (e.g., zoidbot.com)"

Write-Host ""
Write-Host "3. PostgreSQL Password" -ForegroundColor Cyan
$generatePgPass = Read-Host "Generate secure password? (Y/n)"
if ($generatePgPass -ne "n") {
    $pgPassword = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    Write-Host "Generated: $pgPassword" -ForegroundColor Gray
} else {
    $pgPassword = Read-Host "Enter PostgreSQL password" -MaskInput
}

Write-Host ""
Write-Host "4. JWT Secret" -ForegroundColor Cyan
$generateJwt = Read-Host "Generate secure JWT secret? (Y/n)"
if ($generateJwt -ne "n") {
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
    $jwtSecret = [Convert]::ToBase64String($bytes)
    Write-Host "Generated: $jwtSecret" -ForegroundColor Gray
} else {
    $jwtSecret = Read-Host "Enter JWT secret" -MaskInput
}

Write-Host ""
Write-Host "5. JWT Domain" -ForegroundColor Cyan
$jwtDomain = Read-Host "Enter JWT domain (e.g., your-tenant.us.jwt.com)"

Write-Host ""
Write-Host "6. JWT Audience" -ForegroundColor Cyan
$jwtAudience = Read-Host "Enter JWT audience (e.g., https://app.$domain)"

Write-Host ""
Write-Host "7. Sentry DSN (optional)" -ForegroundColor Cyan
$sentryDsn = Read-Host "Enter Sentry DSN (press Enter to skip)"

# Set secrets
Write-Host ""
Write-Host "=== Setting GitHub Secrets ===" -ForegroundColor Yellow
Write-Host ""

function Set-GitHubSecret {
    param($Name, $Value)
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Host "⊘ Skipping $Name (empty)" -ForegroundColor Gray
        return
    }
    Write-Host "Setting $Name..." -ForegroundColor Cyan
    echo $Value | gh secret set $Name --repo $repo
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ $Name set successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Failed to set $Name" -ForegroundColor Red
    }
}

Set-GitHubSecret "DIGITALOCEAN_ACCESS_TOKEN" $doToken
Set-GitHubSecret "DOMAIN" $domain
Set-GitHubSecret "POSTGRES_PASSWORD" $pgPassword
Set-GitHubSecret "JWT_SECRET" $jwtSecret
Set-GitHubSecret "JWT_ISSUER_DOMAIN" $jwtDomain
Set-GitHubSecret "JWT_AUDIENCE" $jwtAudience
Set-GitHubSecret "SENTRY_DSN" $sentryDsn

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Green
Write-Host "✓ All secrets have been set in GitHub repository" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Configure DNS A records for your domain:" -ForegroundColor White
Write-Host "   $domain -> (will be shown after deployment)" -ForegroundColor Gray
Write-Host "   app.$domain -> (will be shown after deployment)" -ForegroundColor Gray
Write-Host "   api.$domain -> (will be shown after deployment)" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Push changes to GitHub to trigger deployment:" -ForegroundColor White
Write-Host "   git push origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Monitor deployment at:" -ForegroundColor White
Write-Host "   https://github.com/$repo/actions" -ForegroundColor Gray
Write-Host ""

# Save configuration locally for reference
$config = @{
    domain = $domain
    jwtDomain = $jwtDomain
    jwtAudience = $jwtAudience
    postgresPassword = $pgPassword
    jwtSecret = $jwtSecret
}

$config | ConvertTo-Json | Out-File -FilePath ".deployment-config.json" -Encoding UTF8
Write-Host "Configuration saved to .deployment-config.json (DO NOT commit this file!)" -ForegroundColor Yellow

