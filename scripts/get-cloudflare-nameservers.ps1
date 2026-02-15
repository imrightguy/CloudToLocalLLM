# Get Cloudflare nameservers for a domain
# This fetches the actual nameservers assigned to your Cloudflare zone

$ErrorActionPreference = "Stop"

$DOMAIN = "zoidbot.online"

# Check if CLOUDFLARE_API_TOKEN is set
if (-not $env:CLOUDFLARE_API_TOKEN) {
    Write-Host "❌ Error: CLOUDFLARE_API_TOKEN environment variable is not set" -ForegroundColor Red
    Write-Host "Please set it with: `$env:CLOUDFLARE_API_TOKEN='your_token'" -ForegroundColor Yellow
    exit 1
}

$CF_API_TOKEN = $env:CLOUDFLARE_API_TOKEN

Write-Host "🔍 Fetching Cloudflare nameservers for $DOMAIN..." -ForegroundColor Cyan
Write-Host ""

# Get Zone ID
$zoneResponse = Invoke-RestMethod -Uri "https://api.cloudflare.com/client/v4/zones?name=$DOMAIN" `
    -Method GET `
    -Headers @{
        "Authorization" = "Bearer $CF_API_TOKEN"
        "Content-Type" = "application/json"
    }

if ($zoneResponse.result.Count -eq 0) {
    Write-Host "❌ Error: Domain $DOMAIN not found in Cloudflare" -ForegroundColor Red
    exit 1
}

$CF_ZONE_ID = $zoneResponse.result[0].id
$zoneInfo = $zoneResponse.result[0]

Write-Host "✅ Zone ID: $CF_ZONE_ID" -ForegroundColor Green
Write-Host ""

# Get nameservers
$nameservers = $zoneInfo.name_servers

if ($nameservers -and $nameservers.Count -gt 0) {
    Write-Host "Cloudflare Nameservers for $DOMAIN :" -ForegroundColor Cyan
    Write-Host ""
    foreach ($ns in $nameservers) {
        Write-Host "  • $ns" -ForegroundColor White
    }
    Write-Host ""
    Write-Host "📋 Add these nameservers at your domain registrar (Namecheap):" -ForegroundColor Yellow
    Write-Host "   1. Go to: https://www.namecheap.com/myaccount/login.aspx" -ForegroundColor White
    Write-Host "   2. Domain List → $DOMAIN → Manage → Nameservers" -ForegroundColor White
    Write-Host "   3. Select 'Custom DNS'" -ForegroundColor White
    Write-Host "   4. Enter the nameservers above" -ForegroundColor White
    Write-Host ""
    
    # Save to file for monitoring script
    $nameservers | Out-File -FilePath "cloudflare-nameservers.txt" -Encoding UTF8
    Write-Host "✅ Nameservers saved to: cloudflare-nameservers.txt" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now run: .\scripts\monitor-nameservers.ps1" -ForegroundColor Cyan
} else {
    Write-Host "⚠️  Warning: Could not retrieve nameservers from Cloudflare API" -ForegroundColor Yellow
    Write-Host "Using default Cloudflare nameserver pattern..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Cloudflare typically uses nameservers like:" -ForegroundColor Cyan
    Write-Host "  • kip.ns.cloudflare.com" -ForegroundColor White
    Write-Host "  • lewis.ns.cloudflare.com" -ForegroundColor White
    Write-Host ""
    Write-Host "Check your Cloudflare dashboard for the actual nameservers:" -ForegroundColor Yellow
    Write-Host "  https://dash.cloudflare.com → $DOMAIN → Overview → Nameservers" -ForegroundColor White
}

