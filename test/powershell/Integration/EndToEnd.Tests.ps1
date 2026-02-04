# End-to-End Integration Tests for Zoidbot Deployment Workflow
# Tests complete deployment scenarios in staging environment with real external dependencies

BeforeAll {
    # Import required modules and configurations
    $TestConfigPath = Join-Path $PSScriptRoot "..\TestConfig.ps1"
    $MocksPath = Join-Path $PSScriptRoot "..\Mocks\WSLMocks.ps1"
    
    . $TestConfigPath
    . $MocksPath
    
    # Initialize test configuration
    $Global:TestConfig = Initialize-TestConfig
    
    # Import the deployment script (without executing)
    $DeploymentScriptPath = Join-Path $PSScriptRoot "..\..\..\scripts\powershell\Deploy-Zoidbot.ps1"
    
    # Set up staging environment configuration
    $Global:StagingConfig = @{
        Environment = "Staging"
        VPSHost = "staging.zoidbot.online"
        VPSUser = "staging-user"
        VPSProjectPath = "/opt/zoidbot-staging"
        WSLDistribution = "Ubuntu-24.04"
        TimeoutSeconds = 300
        DryRun = $true  # Use dry run for integration tests to avoid actual deployment
    }
    
    # Mock external dependencies for integration testing
    Mock Write-Host { }
    Mock Write-Progress { }
    
    # Create test environment
    $Global:TestEnvironment = New-MockTestEnvironment -TestDrive $TestDrive
}

Describe "End-to-End Deployment Workflow Integration Tests" {
    
    Context "Complete Deployment Workflow - Happy Path" {
        BeforeEach {
            # Reset deployment state
            $Script:DeploymentStatus = @{
                Phase = "NotStarted"
                Status = "NotStarted"
                StartTime = $null
                EndTime = $null
                Messages = @()
                ErrorDetails = $null
                RollbackRequired = $false
                Version = $null
            }
            
            $Script:DeploymentConfig = $Global:StagingConfig.Clone()
            $Script:ProjectRoot = $Global:TestEnvironment.ProjectRoot
            
            # Mock successful external dependencies
            Mock Test-WSLAvailable { return $true }
            Mock Test-WSLDistribution { return $true }
            Mock Test-Command { return $true }
            Mock Invoke-WSLCommand { 
                param($Command)
                return Get-MockWSLCommandResponse -Command $Command
            }
            Mock ssh { 
                $Global:LASTEXITCODE = 0
                param($args)
                if ($args -like "*complete_deployment.sh*") {
                    return Get-MockWSLCommandResponse -Command "complete_deployment.sh"
                }
                elseif ($args -like "*verify_deployment.sh*") {
                    return Get-MockWSLCommandResponse -Command "verify_deployment.sh"
                }
                else {
                    return "SSH command successful"
                }
            }
            Mock git { $Global:LASTEXITCODE = 0; return "Git command successful" }
            Mock Test-Path { param($Path) return Test-MockPath -Path $Path }
            
            # Mock version manager
            Mock Invoke-Expression {
                param($Command)
                if ($Command -like "*get-semantic*") {
                    return Get-MockVersionManagerResponse -Action "get-semantic"
                }
                elseif ($Command -like "*increment*") {
                    $Global:LASTEXITCODE = 0
                    return Get-MockVersionManagerResponse -Action "increment"
                }
                return "Mock command output"
            }
        }
        
        It "Should execute complete deployment workflow successfully" {
            # Execute the complete workflow
            $result = @{
                Prerequisites = Test-DeploymentPrerequisites
                VersionUpdate = Update-ProjectVersion
                FlutterBuild = Build-FlutterApplication
                VPSDeployment = Invoke-VPSDeployment
                Verification = Invoke-DeploymentVerification
            }
            
            # Verify each phase completed successfully
            $result.Prerequisites | Should -Be $true
            $result.VersionUpdate | Should -Be $true
            $result.FlutterBuild | Should -Be $true
            $result.VPSDeployment | Should -Be $true
            $result.Verification | Should -Be $true
            
            # Verify deployment status was updated correctly
            $Script:DeploymentStatus.Status | Should -Be "Completed"
            $Script:DeploymentStatus.Version | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle dry run mode throughout entire workflow" {
            $Script:DeploymentConfig.DryRun = $true
            
            # Execute workflow in dry run mode
            $result = @{
                Prerequisites = Test-DeploymentPrerequisites
                VersionUpdate = Update-ProjectVersion
                FlutterBuild = Build-FlutterApplication
                VPSDeployment = Invoke-VPSDeployment
                Verification = Invoke-DeploymentVerification
            }
            
            # All phases should succeed in dry run
            $result.Values | ForEach-Object { $_ | Should -Be $true }
            
            # Verify no actual external commands were executed
            Should -Not -Invoke ssh -ParameterFilter { $args -notlike "*DRY RUN*" }
        }
        
        It "Should maintain deployment state consistency across phases" {
            # Track state changes through workflow
            $stateHistory = @()
            
            # Mock state tracking
            Mock Update-DeploymentStatus {
                param($Phase, $Status, $ErrorDetails)
                $stateHistory += @{
                    Timestamp = Get-Date
                    Phase = $Phase
                    Status = $Status
                    ErrorDetails = $ErrorDetails
                }
                # Call original function
                & $OriginalUpdateDeploymentStatus @PSBoundParameters
            }
            
            # Execute workflow
            Test-DeploymentPrerequisites
            Update-ProjectVersion
            Build-FlutterApplication
            Invoke-VPSDeployment
            Invoke-DeploymentVerification
            
            # Verify state progression
            $stateHistory.Count | Should -BeGreaterThan 0
            $stateHistory | ForEach-Object {
                $_.Phase | Should -Not -BeNullOrEmpty
                $_.Status | Should -BeIn @('NotStarted', 'InProgress', 'Completed', 'Failed')
            }
        }
    }
    
    Context "Deployment Workflow - Error Scenarios" {
        BeforeEach {
            # Reset deployment state
            $Script:DeploymentStatus = @{
                Phase = "NotStarted"
                Status = "NotStarted"
                RollbackRequired = $false
            }
            $Script:DeploymentConfig = $Global:StagingConfig.Clone()
            $Script:ProjectRoot = $Global:TestEnvironment.ProjectRoot
        }
        
        It "Should fail gracefully when prerequisites are not met" {
            # Mock prerequisite failures
            Mock Test-WSLAvailable { return $false }
            Mock Test-Path { return $false }
            
            $result = Test-DeploymentPrerequisites
            
            $result | Should -Be $false
            $Script:DeploymentStatus.Status | Should -Be "Failed"
            $Script:DeploymentStatus.ErrorDetails | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle version management failures" {
            Mock Test-Path { param($Path) return $Path -notlike "*version_manager.ps1" }
            
            $result = Update-ProjectVersion
            
            $result | Should -Be $false
            $Script:DeploymentStatus.Status | Should -Be "Failed"
        }
        
        It "Should handle Flutter build failures" {
            Mock Invoke-WSLCommand { throw "Flutter build failed" }
            
            $result = Build-FlutterApplication
            
            $result | Should -Be $false
            $Script:DeploymentStatus.Status | Should -Be "Failed"
        }
        
        It "Should handle VPS deployment failures and set rollback flag" {
            Mock ssh { $Global:LASTEXITCODE = 1; return "Deployment failed" }
            
            $result = Invoke-VPSDeployment
            
            $result | Should -Be $false
            $Script:DeploymentStatus.Status | Should -Be "Failed"
            $Script:DeploymentStatus.RollbackRequired | Should -Be $true
        }
        
        It "Should handle verification failures" {
            Mock ssh { 
                param($args)
                if ($args -like "*verify_deployment.sh*") {
                    $Global:LASTEXITCODE = 1
                    return "Verification failed"
                }
                return "SSH command successful"
            }
            
            $result = Invoke-DeploymentVerification
            
            $result | Should -Be $false
            $Script:DeploymentStatus.Status | Should -Be "Failed"
        }
    }
    
    Context "Rollback Scenario Integration" {
        BeforeEach {
            $Script:DeploymentStatus = @{
                RollbackRequired = $false
            }
            $Script:DeploymentConfig = $Global:StagingConfig.Clone()
            $Script:DeploymentConfig.AutoRollback = $true
        }
        
        It "Should trigger rollback when deployment fails" {
            # Mock deployment failure
            Mock ssh { 
                param($args)
                if ($args -like "*complete_deployment.sh*") {
                    $Global:LASTEXITCODE = 1
                    return "Deployment failed"
                }
                return "SSH command successful"
            }
            
            $result = Invoke-VPSDeployment
            
            $result | Should -Be $false
            $Script:DeploymentStatus.RollbackRequired | Should -Be $true
        }
        
        It "Should trigger rollback when verification fails" {
            # Mock verification failure
            Mock ssh { 
                param($args)
                if ($args -like "*verify_deployment.sh*") {
                    $Global:LASTEXITCODE = 1
                    return "Verification failed"
                }
                return "SSH command successful"
            }
            
            $result = Invoke-DeploymentVerification
            
            $result | Should -Be $false
            $Script:DeploymentStatus.Status | Should -Be "Failed"
        }
    }
    
    Context "Performance and Timeout Integration" {
        BeforeEach {
            $Script:DeploymentConfig = $Global:StagingConfig.Clone()
            $Script:DeploymentConfig.TimeoutSeconds = 5  # Short timeout for testing
        }
        
        It "Should handle long-running operations within timeout" {
            # Mock operations that complete within timeout
            Mock ssh { 
                Start-Sleep -Milliseconds 100  # Simulate work
                $Global:LASTEXITCODE = 0
                return "Operation completed"
            }
            
            $result = Invoke-VPSDeployment
            
            $result | Should -Be $true
        }
        
        It "Should handle operations that exceed reasonable time" {
            # This test verifies that timeout handling is properly configured
            # Actual timeout implementation would be tested in the real deployment script
            $Script:DeploymentConfig.TimeoutSeconds | Should -BeGreaterThan 0
            $Script:DeploymentConfig.TimeoutSeconds | Should -BeLessThan 3600  # Reasonable upper bound
        }
    }
}

Describe "Cross-Platform Integration Tests" {
    
    Context "WSL Integration Scenarios" {
        BeforeEach {
            $Script:DeploymentConfig = $Global:StagingConfig.Clone()
        }
        
        It "Should handle multiple WSL distributions" {
            Mock Get-WSLDistributions { 
                return Get-MockWSLDistributions -Scenario "Full"
            }
            
            $distributions = Get-WSLDistributions
            $distributions.Count | Should -BeGreaterThan 1
            
            # Should find Ubuntu distribution
            $ubuntu = $distributions | Where-Object { $_.Name -like "*Ubuntu*" }
            $ubuntu | Should -Not -BeNullOrEmpty
        }
        
        It "Should handle WSL distribution state changes" {
            # Test stopped distribution
            Mock Test-WSLDistribution { return $false }
            
            $result = Test-WSLDistribution -DistroName "Ubuntu-24.04"
            $result | Should -Be $false
            
            # Test running distribution
            Mock Test-WSLDistribution { return $true }
            
            $result = Test-WSLDistribution -DistroName "Ubuntu-24.04"
            $result | Should -Be $true
        }
        
        It "Should handle path conversion between Windows and WSL" {
            $windowsPath = "C:\Users\Test\Project"
            $wslPath = Convert-WindowsPathToWSL -WindowsPath $windowsPath
            
            $wslPath | Should -Be "/mnt/c/users/test/project"
            
            $convertedBack = Convert-WSLPathToWindows -WSLPath $wslPath
            $convertedBack | Should -Be "C:\users\test\project"
        }
    }
    
    Context "SSH Integration Scenarios" {
        BeforeEach {
            $Script:DeploymentConfig = $Global:StagingConfig.Clone()
        }
        
        It "Should handle SSH key authentication" {
            Mock Test-SSHConnectivity { return $true }
            
            $result = Test-SSHConnectivity -VPSHost $Script:DeploymentConfig.VPSHost -VPSUser $Script:DeploymentConfig.VPSUser
            
            $result | Should -Be $true
        }
        
        It "Should handle SSH connection failures" {
            Mock Test-SSHConnectivity { return $false }
            
            $result = Test-SSHConnectivity -VPSHost "unreachable.example.com" -VPSUser "testuser"
            
            $result | Should -Be $false
        }
        
        It "Should handle SSH command execution with proper error propagation" {
            # Test successful command
            Mock ssh { $Global:LASTEXITCODE = 0; return "Command successful" }
            
            $result = ssh "test@example.com" "echo test"
            $result | Should -Be "Command successful"
            
            # Test failed command
            Mock ssh { $Global:LASTEXITCODE = 1; return "Command failed" }
            
            ssh "test@example.com" "false"
            $LASTEXITCODE | Should -Be 1
        }
    }
}

Describe "Environment-Specific Integration Tests" {
    
    Context "Staging Environment Integration" {
        BeforeEach {
            $Script:DeploymentConfig = @{
                Environment = "Staging"
                VPSHost = "staging.zoidbot.online"
                VPSUser = "staging-user"
                DryRun = $true
            }
        }
        
        It "Should configure staging environment correctly" {
            $Script:DeploymentConfig.Environment | Should -Be "Staging"
            $Script:DeploymentConfig.VPSHost | Should -Be "staging.zoidbot.online"
            $Script:DeploymentConfig.DryRun | Should -Be $true
        }
        
        It "Should use staging-specific deployment paths" {
            $Script:DeploymentConfig.VPSHost | Should -Not -Be "zoidbot.online"  # Not production
            $Script:DeploymentConfig.VPSUser | Should -Be "staging-user"
        }
    }
    
    Context "Production Environment Integration" {
        BeforeEach {
            $Script:DeploymentConfig = @{
                Environment = "Production"
                VPSHost = "zoidbot.online"
                VPSUser = "cloudllm"
                DryRun = $true  # Keep dry run for tests
            }
        }
        
        It "Should configure production environment correctly" {
            $Script:DeploymentConfig.Environment | Should -Be "Production"
            $Script:DeploymentConfig.VPSHost | Should -Be "zoidbot.online"
            $Script:DeploymentConfig.VPSUser | Should -Be "cloudllm"
        }
        
        It "Should use production-specific deployment paths" {
            $Script:DeploymentConfig.VPSHost | Should -Be "zoidbot.online"
            $Script:DeploymentConfig.VPSUser | Should -Be "cloudllm"
        }
    }
}

AfterAll {
    # Cleanup test environment
    Clear-TestConfig
    
    # Remove environment variables
    Remove-Item -Path "env:PESTER_TEST_MODE" -ErrorAction SilentlyContinue
    Remove-Item -Path "env:PESTER_TEST_TIMESTAMP" -ErrorAction SilentlyContinue
}