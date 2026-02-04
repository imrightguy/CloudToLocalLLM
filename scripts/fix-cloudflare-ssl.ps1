# Fix Cloudflare SSL mode to "flexible" to resolve 500 errors
# This allows Cloudflare to connect to origin via HTTP while providing HTTPS to visitors

$ErrorActionPreference = "Stop"

# Check if CLOUDFLARE_API_TOKEN is set
if (-not $env:CLOUDFLARE_API_TOKEN) {
    Write-Host "❌ Error: CLOUDFLARE_API_TOKEN environment variable is not set" -ForegroundColor Red
    Write-Host "Please set it with: `$env:CLOUDFLARE_API_TOKEN='your_token'" -ForegroundColor Yellow
    exit 1
}

$CF_API_TOKEN = $env:CLOUDFLARE_API_TOKEN
$ZONE_NAME = "zoidbot.online"

Write-Host "🔧 Fixing Cloudflare SSL mode for $ZONE_NAME..." -ForegroundColor Cyan

# Get Zone ID
$zoneResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" `
    -Method GET `
    -Headers @{
        "Authorization" = "Bearer $CF_API_TOKEN"
        "Content-Type" = "application/json"
    }

$CF_ZONE_ID = $zoneResponse.result[0].id

if (-not $CF_ZONE_ID) {
    Write-Host "❌ Unable to determine Cloudflare Zone ID" -ForegroundColor Red
    exit 1
}

Write-Host "Found Zone ID: $CF_ZONE_ID" -ForegroundColor Green

# Change SSL mode to "flexible"
Write-Host "Setting SSL mode to 'flexible'..." -ForegroundColor Cyan
$sslResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/settings/ssl" `
    -Method PATCH `
    -Headers @{
        "Authorization" = "Bearer $CF_API_TOKEN"
        "Content-Type" = "application/json"
    } `
    -Body (@{
        value = "flexible"
    } | ConvertTo-Json)

if ($sslResponse.success) {
    Write-Host "✅ Cloudflare SSL mode changed to 'flexible' successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "This allows:" -ForegroundColor Cyan
    Write-Host "  - Visitors → Cloudflare: HTTPS (secure)" -ForegroundColor White
    Write-Host "  - Cloudflare → Origin: HTTP (no TLS required on origin)" -ForegroundColor White
    Write-Host ""
    Write-Host "The 500 error should now be resolved. Please wait a few seconds and try accessing the site again." -ForegroundColor Yellow
} else {
    Write-Host "❌ Failed to change SSL mode" -ForegroundColor Red
    $sslResponse.errors | ConvertTo-Json
    exit 1
}

