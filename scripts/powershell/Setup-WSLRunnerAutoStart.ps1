# Setup GitHub Actions Runner Auto-Start for WSL
# This creates a Windows Task Scheduler task to start the runner when WSL starts

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$WslDistribution = "FedoraLinux-43"
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "WSL Runner Auto-Start Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "Setting up auto-start for WSL Linux runner..." -ForegroundColor Cyan
Write-Host ""

# Option 1: Configure in WSL bashrc (no admin needed)
Write-Host "Method 1: Adding to WSL ~/.bashrc (Recommended)" -ForegroundColor Green
wsl -d $WslDistribution bash "/mnt/d/dev/Zoidbot/scripts/setup-wsl-runner-autostart.sh"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ WSL auto-start configured" -ForegroundColor Green
} else {
    Write-Host " WSL auto-start configuration had issues" -ForegroundColor Yellow
}

Write-Host ""

# Option 2: Windows Task Scheduler (requires admin)
if ($isAdmin) {
    Write-Host "Method 2: Creating Windows Task Scheduler task..." -ForegroundColor Green
    
    $taskName = "GitHubActionsRunner-WSL"
    $taskPath = "$env:USERPROFILE\actions-runner-wsl-start.ps1"
    
    # Create PowerShell script for task
    $taskScript = @"
`$wslDistro = `"$WslDistribution`"
wsl -d `$wslDistro bash -c "cd ~/actions-runner && ./start-runner.sh"
"@
    
    $taskScript | Out-File -FilePath $taskPath -Encoding UTF8
    
    # Remove existing task if present
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
    
    # Create task action
    $action = New-ScheduledTaskAction -Execute "pwsh.exe" -Argument "-File `"$taskPath`""
    
    # Create trigger (at logon)
    $trigger = New-ScheduledTaskTrigger -AtLogOn
    
    # Create settings
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable
    
    # Register task
    try {
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Auto-start GitHub Actions Runner in WSL" | Out-Null
        Write-Host "✓ Windows Task Scheduler task created" -ForegroundColor Green
        Write-Host "  Task name: $taskName" -ForegroundColor Cyan
    }
    catch {
        Write-Host " Failed to create scheduled task: $($_.Exception.Message)" -ForegroundColor Yellow
    }
} else {
    Write-Host "Method 2: Windows Task Scheduler (Skipped - requires Admin)" -ForegroundColor Yellow
    Write-Host "  To enable: Run PowerShell as Administrator and run this script again" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Auto-start methods configured:" -ForegroundColor Yellow
Write-Host "  1. WSL ~/.bashrc - starts when you open WSL terminal" -ForegroundColor White
if ($isAdmin) {
    Write-Host "  2. Windows Task Scheduler - starts on Windows login" -ForegroundColor White
}
Write-Host ""
Write-Host "To test:" -ForegroundColor Yellow
Write-Host "  wsl -d $WslDistribution" -ForegroundColor Cyan
Write-Host "  ps aux | grep Runner.Listener" -ForegroundColor Cyan

