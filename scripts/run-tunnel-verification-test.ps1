# Container Tunnel Integration Test Runner (PowerShell)
# Tests that containers can communicate through the simplified tunnel proxy

param(
    [string]$TestUserId = "test-user-123",
    [string]$ApiBaseUrl = "http://localhost:8080",
    [string]$ContainerHealthUrl = "http://localhost:8081"
)

Write-Host " Zoidbot Container Tunnel Integration Tests" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# Check if Node.js is available
try {
    $nodeVersion = node --version
    Write-Host " Node.js found: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host " Node.js is required to run integration tests" -ForegroundColor Red
    exit 1
}

# Set environment variables
$env:TEST_USER_ID = $TestUserId
$env:API_BASE_URL = $ApiBaseUrl
$env:CONTAINER_HEALTH_URL = $ContainerHealthUrl

Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Test User ID: $TestUserId" -ForegroundColor White
Write-Host "  API Base URL: $ApiBaseUrl" -ForegroundColor White
Write-Host "  Container Health URL: $ContainerHealthUrl" -ForegroundColor White
Write-Host ""

# Get the script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Run the integration tests
Write-Host "Starting integration tests..." -ForegroundColor Yellow
try {
    $testScript = Join-Path $scriptDir "test-container-tunnel-integration.js"
    node $testScript
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host " Container tunnel integration tests completed successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host " Some tests failed. Check the output above for details." -ForegroundColor Red
        exit $LASTEXITCODE
    }
} catch {
    Write-Host " Failed to run integration tests: $_" -ForegroundColor Red
    exit 1
}