# ============================================================================
# DigitalOcean Setup Script
# ============================================================================

$ErrorActionPreference = "Stop"

Write-Host @"

╔════════════════════════════════════════════════════════════════╗
║        DigitalOcean CLI Authentication Setup                   ║
╚════════════════════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "To authenticate with DigitalOcean, you need a Personal Access Token." -ForegroundColor Yellow
Write-Host ""
Write-Host "Steps to create a token:" -ForegroundColor Green
Write-Host "  1. Go to: https://cloud.digitalocean.com/account/api/tokens" -ForegroundColor White
Write-Host "  2. Click 'Generate New Token'" -ForegroundColor White
Write-Host "  3. Name: 'Zoidbot-CLI'" -ForegroundColor White
Write-Host "  4. Scopes: Select 'Read' and 'Write'" -ForegroundColor White
Write-Host "  5. Copy the token (you'll only see it once!)" -ForegroundColor White
Write-Host ""

# Open browser to token page
$openBrowser = Read-Host "Open DigitalOcean token page in browser? (Y/n)"
if ($openBrowser -ne "n") {
    Start-Process "https://cloud.digitalocean.com/account/api/tokens"
    Write-Host "✓ Opening browser..." -ForegroundColor Green
    Start-Sleep -Seconds 2
}

Write-Host ""
$token = Read-Host "Paste your DigitalOcean Personal Access Token" -MaskInput

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "✗ No token provided. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Authenticating with DigitalOcean..." -ForegroundColor Cyan

try {
    # Initialize doctl
    $env:DIGITALOCEAN_ACCESS_TOKEN = $token
    doctl auth init --access-token $token
    
    Write-Host "✓ Authentication successful!" -ForegroundColor Green
    Write-Host ""
    
    # Verify authentication by getting account info
    Write-Host "Fetching your DigitalOcean account info..." -ForegroundColor Cyan
    doctl account get
    
    Write-Host ""
    Write-Host "✓ Setup complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Available commands:" -ForegroundColor Yellow
    Write-Host "  doctl kubernetes cluster list          - List your K8s clusters" -ForegroundColor White
    Write-Host "  doctl registry get                     - View your container registry" -ForegroundColor White
    Write-Host "  doctl compute droplet list             - List your droplets" -ForegroundColor White
    Write-Host "  doctl projects list                    - List your projects" -ForegroundColor White
    
} catch {
    Write-Host "✗ Authentication failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

