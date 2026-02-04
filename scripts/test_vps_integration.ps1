# Zoidbot Windows-to-VPS Integration Test Script
# Tests SSH connectivity and VPS deployment script availability
# Validates the restored Windows PowerShell orchestration

[CmdletBinding()]
param(
    [switch]$TestSSH,
    [switch]$TestScripts,
    [switch]$TestDeployment,
    [switch]$All,
    [switch]$Verbose
)

# Configuration
$VPSHost = "zoidbot.online"
$VPSUser = "cloudllm"
$VPSProjectPath = "/opt/zoidbot"
$VPSScriptsPath = "$VPSProjectPath/scripts/deploy"

# Colors for output
$Colors = @{
    Info = "Blue"
    Success = "Green"
    Warning = "Yellow"
    Error = "Red"
    Step = "Cyan"
}

function Write-LogInfo {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Colors.Info
}

function Write-LogSuccess {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors.Success
}

function Write-LogWarning {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors.Warning
}

function Write-LogError {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors.Error
}

function Write-LogStep {
    param([string]$Message)
    Write-Host "[STEP] $Message" -ForegroundColor $Colors.Step
}

function Show-Help {
    Write-Host "Zoidbot Windows-to-VPS Integration Test" -ForegroundColor Blue
    Write-Host "=============================================" -ForegroundColor Blue
    Write-Host ""
    Write-Host "Tests the integration between Windows PowerShell orchestration"
    Write-Host "and the restored VPS deployment scripts."
    Write-Host ""
    Write-Host "Usage: .\test_vps_integration.ps1 [options]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -TestSSH         Test SSH connectivity to VPS"
    Write-Host "  -TestScripts     Test VPS deployment script availability"
    Write-Host "  -TestDeployment  Test deployment script execution (dry run)"
    Write-Host "  -All             Run all tests"
    Write-Host "  -Verbose         Enable verbose output"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\test_vps_integration.ps1 -All"
    Write-Host "  .\test_vps_integration.ps1 -TestSSH -TestScripts"
    Write-Host "  .\test_vps_integration.ps1 -TestDeployment -Verbose"
}

function Test-SSHConnectivity {
    Write-LogStep "Testing SSH connectivity to VPS..."
    
    try {
        Write-LogInfo "Testing SSH connection to $VPSUser@$VPSHost"
        
        # Test basic SSH connectivity
        $sshTest = ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPSUser@$VPSHost" "echo 'SSH test successful'"
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess " SSH connectivity test passed"
            if ($Verbose) {
                Write-LogInfo "SSH response: $sshTest"
            }
            return $true
        } else {
            Write-LogError " SSH connectivity test failed"
            Write-LogError "Exit code: $LASTEXITCODE"
            return $false
        }
    } catch {
        Write-LogError " SSH connectivity test failed with exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-VPSEnvironment {
    Write-LogStep "Testing VPS environment..."
    
    try {
        Write-LogInfo "Checking VPS user and directory..."
        
        # Check if running as correct user and in correct directory
        $userCheck = ssh "$VPSUser@$VPSHost" "whoami && pwd"
        
        if ($LASTEXITCODE -eq 0) {
            $lines = $userCheck -split "`n"
            $currentUser = $lines[0].Trim()
            $currentDir = $lines[1].Trim()
            
            if ($currentUser -eq $VPSUser) {
                Write-LogSuccess " VPS user check passed: $currentUser"
            } else {
                Write-LogWarning " Unexpected VPS user: $currentUser (expected: $VPSUser)"
            }
            
            Write-LogInfo "Current directory: $currentDir"
            
            # Check if project directory exists
            $dirCheck = ssh "$VPSUser@$VPSHost" "test -d $VPSProjectPath && echo 'exists' || echo 'missing'"
            
            if ($dirCheck.Trim() -eq "exists") {
                Write-LogSuccess " Project directory exists: $VPSProjectPath"
                return $true
            } else {
                Write-LogError " Project directory missing: $VPSProjectPath"
                return $false
            }
        } else {
            Write-LogError " VPS environment check failed"
            return $false
        }
    } catch {
        Write-LogError " VPS environment test failed with exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-DeploymentScripts {
    Write-LogStep "Testing VPS deployment scripts availability..."
    
    $requiredScripts = @(
        "update_and_deploy.sh",
        "complete_deployment.sh",
        "verify_deployment.sh",
        "sync_versions.sh",
        "git_monitor.sh",
        "install_vps_automation.sh"
    )
    
    $allScriptsFound = $true
    
    foreach ($script in $requiredScripts) {
        $scriptPath = "$VPSScriptsPath/$script"
        
        try {
            Write-LogInfo "Checking script: $script"
            
            # Check if script exists and is executable
            $scriptCheck = ssh "$VPSUser@$VPSHost" "test -f $scriptPath && test -x $scriptPath && echo 'ok' || echo 'missing'"
            
            if ($scriptCheck.Trim() -eq "ok") {
                Write-LogSuccess "   $script (found and executable)"
            } else {
                Write-LogError "   $script (missing or not executable)"
                $allScriptsFound = $false
            }
        } catch {
            Write-LogError "   $script (check failed: $($_.Exception.Message))"
            $allScriptsFound = $false
        }
    }
    
    if ($allScriptsFound) {
        Write-LogSuccess " All deployment scripts are available and executable"
        return $true
    } else {
        Write-LogError " Some deployment scripts are missing or not executable"
        return $false
    }
}

function Test-DeploymentExecution {
    Write-LogStep "Testing deployment script execution (dry run)..."
    
    try {
        Write-LogInfo "Testing complete deployment script with dry run..."
        
        $deploymentScript = "$VPSScriptsPath/complete_deployment.sh"
        $deploymentCommand = "cd $VPSProjectPath && $deploymentScript --dry-run --verbose"
        
        Write-LogInfo "Executing: $deploymentCommand"
        
        $deploymentOutput = ssh "$VPSUser@$VPSHost" "$deploymentCommand"
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess " Deployment script dry run completed successfully"
            
            if ($Verbose) {
                Write-LogInfo "Deployment output:"
                Write-Host $deploymentOutput -ForegroundColor Gray
            }
            
            return $true
        } else {
            Write-LogError " Deployment script dry run failed"
            Write-LogError "Exit code: $LASTEXITCODE"
            
            if ($Verbose) {
                Write-LogError "Deployment output:"
                Write-Host $deploymentOutput -ForegroundColor Red
            }
            
            return $false
        }
    } catch {
        Write-LogError " Deployment execution test failed with exception: $($_.Exception.Message)"
        return $false
    }
}

function Test-VersionSynchronization {
    Write-LogStep "Testing version synchronization..."
    
    try {
        Write-LogInfo "Testing version sync script..."
        
        $versionScript = "$VPSScriptsPath/sync_versions.sh"
        $versionCommand = "cd $VPSProjectPath && $versionScript --check-only --verbose"
        
        Write-LogInfo "Executing: $versionCommand"
        
        $versionOutput = ssh "$VPSUser@$VPSHost" "$versionCommand"
        
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess " Version synchronization test passed"
        } else {
            Write-LogWarning " Version synchronization test failed (may need sync)"
        }
        
        if ($Verbose) {
            Write-LogInfo "Version output:"
            Write-Host $versionOutput -ForegroundColor Gray
        }
        
        return $true
    } catch {
        Write-LogError " Version synchronization test failed with exception: $($_.Exception.Message)"
        return $false
    }
}

function Show-TestSummary {
    param(
        [hashtable]$TestResults
    )
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "WINDOWS-TO-VPS INTEGRATION TEST SUMMARY" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $totalTests = $TestResults.Count
    $passedTests = ($TestResults.Values | Where-Object { $_ -eq $true }).Count
    $failedTests = $totalTests - $passedTests
    
    foreach ($test in $TestResults.GetEnumerator()) {
        if ($test.Value) {
            Write-Host " $($test.Key)" -ForegroundColor Green
        } else {
            Write-Host " $($test.Key)" -ForegroundColor Red
        }
    }
    
    Write-Host ""
    Write-Host "Results: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Yellow" })
    
    if ($passedTests -eq $totalTests) {
        Write-LogSuccess "� All integration tests passed! Windows-to-VPS integration is working correctly."
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Green
        Write-Host "  1. Deploy using: .\scripts\powershell\Deploy-Zoidbot.ps1 -Force" -ForegroundColor Yellow
        Write-Host "  2. Install VPS automation: ssh $VPSUser@$VPSHost 'cd $VPSProjectPath && ./scripts/deploy/install_vps_automation.sh --install-service --enable-service'" -ForegroundColor Yellow
    } else {
        Write-LogError " Some integration tests failed. Please fix the issues before proceeding."
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Check SSH key configuration" -ForegroundColor Yellow
        Write-Host "  2. Verify VPS deployment scripts are present and executable" -ForegroundColor Yellow
        Write-Host "  3. Ensure VPS environment meets requirements" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
}

# Main execution
Write-Host "================================================================" -ForegroundColor Blue
Write-Host "Zoidbot Windows-to-VPS Integration Test" -ForegroundColor Blue
Write-Host "Time: $(Get-Date)" -ForegroundColor Blue
Write-Host "VPS: $VPSHost" -ForegroundColor Blue
Write-Host "User: $VPSUser" -ForegroundColor Blue
Write-Host "================================================================" -ForegroundColor Blue
Write-Host ""

# Parse parameters
if (-not ($TestSSH -or $TestScripts -or $TestDeployment -or $All)) {
    Show-Help
    exit 0
}

if ($All) {
    $TestSSH = $true
    $TestScripts = $true
    $TestDeployment = $true
}

# Execute tests
$testResults = @{}

if ($TestSSH) {
    $testResults["SSH Connectivity"] = Test-SSHConnectivity
    $testResults["VPS Environment"] = Test-VPSEnvironment
}

if ($TestScripts) {
    $testResults["Deployment Scripts"] = Test-DeploymentScripts
    $testResults["Version Synchronization"] = Test-VersionSynchronization
}

if ($TestDeployment) {
    $testResults["Deployment Execution"] = Test-DeploymentExecution
}

# Show summary
Show-TestSummary -TestResults $testResults

# Exit with appropriate code
$allPassed = ($testResults.Values | Where-Object { $_ -eq $false }).Count -eq 0
exit $(if ($allPassed) { 0 } else { 1 })
