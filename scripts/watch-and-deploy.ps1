# Watch GitHub Actions and auto-deploy when ready
# This script monitors GitHub Actions workflow and restarts Kubernetes pods when new image is ready

Write-Host " Monitoring GitHub Actions workflow..." -ForegroundColor Cyan
Write-Host ""

$repoOwner = "imrightguy"
$repoName = "Zoidbot"
$namespace = "zoidbot"
$deployment = "web"
$maxChecks = 30  # Check for up to 10 minutes

# Get current commit SHA
$currentSha = git rev-parse HEAD
Write-Host "Current commit: $currentSha" -ForegroundColor White
Write-Host ""

for ($i = 1; $i -le $maxChecks; $i++) {
    Write-Host "[$i/$maxChecks] Checking build status..." -ForegroundColor Gray
    
    # Use GitHub API to check workflow status
    try {
        $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/actions/runs?per_page=1&head_sha=$currentSha"
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{
            "Accept" = "application/vnd.github+json"
        }
        
        if ($response.workflow_runs.Count -gt 0) {
            $run = $response.workflow_runs[0]
            $status = $run.status
            $conclusion = $run.conclusion
            
            Write-Host "  Status: $status" -ForegroundColor $(if ($status -eq 'completed') { 'Green' } else { 'Yellow' })
            
            if ($status -eq 'completed') {
                if ($conclusion -eq 'success') {
                    Write-Host ""
                    Write-Host " Build completed successfully!" -ForegroundColor Green
                    Write-Host ""
                    Write-Host "Restarting deployment to pull new image..." -ForegroundColor Cyan
                    
                    kubectl rollout restart deployment/$deployment -n $namespace
                    
                    Write-Host ""
                    Write-Host "Waiting for rollout to complete..." -ForegroundColor Yellow
                    kubectl rollout status deployment/$deployment -n $namespace --timeout=180s
                    
                    Write-Host ""
                    Write-Host "=====================================" -ForegroundColor Cyan
                    Write-Host "   ✨ Deployment Complete!" -ForegroundColor Green
                    Write-Host "=====================================" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Test your app:" -ForegroundColor White
                    Write-Host "  https://app.zoidbot.online" -ForegroundColor Cyan
                    Write-Host ""
                    Write-Host "Hard refresh (Ctrl+Shift+R) to clear cache!" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "Expected console:" -ForegroundColor White
                    Write-Host "   JWT initialized" -ForegroundColor Green
                    Write-Host "   No Sentry errors!" -ForegroundColor Green
                    
                    exit 0
                } else {
                    Write-Host ""
                    Write-Host " Build failed with conclusion: $conclusion" -ForegroundColor Red
                    Write-Host "Check logs: $($run.html_url)" -ForegroundColor White
                    exit 1
                }
            }
        } else {
            Write-Host "  No workflow found for commit $currentSha yet..." -ForegroundColor Gray
        }
    } catch {
        Write-Host "  Error checking workflow: $_" -ForegroundColor Red
    }
    
    if ($i -lt $maxChecks) {
        Start-Sleep -Seconds 20
    }
}

Write-Host ""
Write-Host "  Build is taking longer than expected (10+ minutes)" -ForegroundColor Yellow
Write-Host "Check manually: https://github.com/$repoOwner/$repoName/actions" -ForegroundColor White

