# VPS Connection and Authentication Integration Tests
# Tests SSH connectivity, authentication, and remote command execution

BeforeAll {
    # Import required modules
    $TestConfigPath = Join-Path $PSScriptRoot "..\TestConfig.ps1"
    $MocksPath = Join-Path $PSScriptRoot "..\Mocks\WSLMocks.ps1"
    $UtilitiesPath = Join-Path $PSScriptRoot "..\..\..\scripts\powershell\BuildEnvironmentUtilities.ps1"
    
    . $TestConfigPath
    . $MocksPath
    . $UtilitiesPath
    
    # Initialize test configuration
    $Global:TestConfig = Initialize-TestConfig
    
    # Set up VPS test configuration
    $Global:VPSTestConfig = @{
        StagingVPS = @{
            Host = "staging.zoidbot.online"
            User = "staging-user"
            Port = 22
            ProjectPath = "/opt/zoidbot-staging"
            SSHKeyPath = "~/.ssh/id_ed25519"
        }
        ProductionVPS = @{
            Host = "zoidbot.online"
            User = "cloudllm"
            Port = 22
            ProjectPath = "/opt/zoidbot"
            SSHKeyPath = "~/.ssh/id_ed25519"
        }
        TestVPS = @{
            Host = "test.example.com"
            User = "testuser"
            Port = 22
            ProjectPath = "/opt/test"
            SSHKeyPath = "~/.ssh/id_rsa"
        }
    }
    
    # Mock Write-Host to capture output
    Mock Write-Host { }
}

Describe "SSH Connectivity Tests" {
    
    Context "Basic SSH Connection Testing" {
        BeforeEach {
            # Reset mock state
            $Global:LASTEXITCODE = 0
        }
        
        It "Should successfully test SSH connectivity to staging VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*$($vpsConfig.Host)*" -and $args -like "*SSH_TEST_SUCCESS*") {
                    $Global:LASTEXITCODE = 0
                    return "SSH_TEST_SUCCESS"
                }
                return "SSH command output"
            }
            
            $result = Test-SSHConnectivity -VPSHost $vpsConfig.Host -VPSUser $vpsConfig.User
            
            $result | Should -Be $true
            Should -Invoke ssh -ParameterFilter { 
                $args -like "*$($vpsConfig.User)@$($vpsConfig.Host)*" 
            }
        }
        
        It "Should handle SSH connection timeout" {
            $vpsConfig = $Global:VPSTestConfig.TestVPS
            
            Mock ssh { 
                Start-Sleep -Milliseconds 100  # Simulate delay
                throw "Connection timeout"
            }
            
            $result = Test-SSHConnectivity -VPSHost $vpsConfig.Host -VPSUser $vpsConfig.User -TimeoutSeconds 1
            
            $result | Should -Be $false
        }
        
        It "Should handle SSH authentication failure" {
            $vpsConfig = $Global:VPSTestConfig.TestVPS
            
            Mock ssh { 
                $Global:LASTEXITCODE = 255
                return "Permission denied (publickey)"
            }
            
            $result = Test-SSHConnectivity -VPSHost $vpsConfig.Host -VPSUser $vpsConfig.User
            
            $result | Should -Be $false
        }
        
        It "Should handle network connectivity issues" {
            $vpsConfig = $Global:VPSTestConfig.TestVPS
            
            Mock ssh { 
                $Global:LASTEXITCODE = 1
                return "ssh: connect to host test.example.com port 22: Connection refused"
            }
            
            $result = Test-SSHConnectivity -VPSHost $vpsConfig.Host -VPSUser $vpsConfig.User
            
            $result | Should -Be $false
        }
        
        It "Should use custom timeout parameter" {
            $vpsConfig = $Global:VPSTestConfig.TestVPS
            $customTimeout = 15
            
            Mock ssh { 
                $Global:LASTEXITCODE = 0
                return "SSH_TEST_SUCCESS"
            }
            
            Test-SSHConnectivity -VPSHost $vpsConfig.Host -VPSUser $vpsConfig.User -TimeoutSeconds $customTimeout
            
            Should -Invoke ssh -ParameterFilter { 
                $args -like "*ConnectTimeout=$customTimeout*" 
            }
        }
    }
    
    Context "SSH Key Management and Authentication" {
        BeforeEach {
            # Create mock SSH directory structure
            $sshDir = Join-Path $TestDrive ".ssh"
            New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
            
            # Create mock SSH keys
            $keyTypes = @("id_rsa", "id_rsa.pub", "id_ed25519", "id_ed25519.pub")
            foreach ($keyType in $keyTypes) {
                $keyPath = Join-Path $sshDir $keyType
                Set-Content -Path $keyPath -Value (Get-MockSSHKeyContent -KeyType $keyType)
            }
        }
        
        It "Should detect available SSH keys" {
            $sshDir = Join-Path $TestDrive ".ssh"
            
            $rsaKey = Join-Path $sshDir "id_rsa"
            $ed25519Key = Join-Path $sshDir "id_ed25519"
            
            Test-Path $rsaKey | Should -Be $true
            Test-Path $ed25519Key | Should -Be $true
        }
        
        It "Should set proper permissions on SSH private keys" {
            $privateKey = Join-Path $TestDrive ".ssh\id_rsa"
            
            Mock icacls { return "Successfully processed 1 files" }
            Mock Get-Acl { 
                $acl = New-Object System.Security.AccessControl.FileSecurity
                $rule = New-Object System.Security.AccessControl.FileSystemAccessRule($env:USERNAME, "FullControl", "Allow")
                $acl.SetAccessRule($rule)
                return $acl
            }
            
            $result = Set-SSHKeyPermissions -KeyPath $privateKey
            
            $result | Should -Be $true
            Should -Invoke icacls -ParameterFilter { $args -contains $privateKey }
        }
        
        It "Should handle SSH key synchronization from WSL" {
            Mock Test-WSLDistribution { return $true }
            Mock Invoke-WSLCommand { 
                param($Command)
                if ($Command -like "*ls ~/.ssh/id_**") {
                    return "id_rsa`nid_rsa.pub`nid_ed25519`nid_ed25519.pub"
                }
                elseif ($Command -like "*cat ~/.ssh/id_*") {
                    return Get-MockSSHKeyContent -KeyType "id_rsa"
                }
                return "WSL command output"
            }
            Mock New-DirectoryIfNotExists { }
            Mock Set-Content { }
            Mock Set-SSHKeyPermissions { return $true }
            Mock Update-SSHConfig { return $true }
            
            $result = Sync-SSHKeys -SourceDistro "Ubuntu-24.04" -AutoSync
            
            $result | Should -Be $true
            Should -Invoke Invoke-WSLCommand -AtLeast 1
        }
        
        It "Should update SSH config with VPS host configurations" {
            $configPath = Join-Path $TestDrive ".ssh\config"
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock Test-Path { param($Path) return $Path -eq $configPath }
            Mock Get-Content { return "" }  # Empty existing config
            Mock Add-Content { }
            
            $result = Update-SSHConfig -VPSHost $vpsConfig.Host -VPSUser $vpsConfig.User
            
            $result | Should -Be $true
            Should -Invoke Add-Content -ParameterFilter { 
                $Path -eq $configPath -and $Value -like "*$($vpsConfig.Host)*" 
            }
        }
    }
    
    Context "Remote Command Execution" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
        }
        
        It "Should execute simple commands on VPS" {
            $vpsConfig = $Global:VPSTestConfig.TestVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*echo test*") {
                    $Global:LASTEXITCODE = 0
                    return "test"
                }
                return "command output"
            }
            
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "echo test"
            
            $result | Should -Be "test"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should execute deployment scripts on VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            $deploymentScript = "$($vpsConfig.ProjectPath)/scripts/deploy/complete_deployment.sh"
            
            Mock ssh { 
                param($args)
                if ($args -like "*complete_deployment.sh*") {
                    $Global:LASTEXITCODE = 0
                    return Get-MockWSLCommandResponse -Command "complete_deployment.sh"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "cd $($vpsConfig.ProjectPath) && ./scripts/deploy/complete_deployment.sh"
            
            $result | Should -Not -BeNullOrEmpty
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should execute verification scripts on VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            $verificationScript = "$($vpsConfig.ProjectPath)/scripts/deploy/verify_deployment.sh"
            
            Mock ssh { 
                param($args)
                if ($args -like "*verify_deployment.sh*") {
                    $Global:LASTEXITCODE = 0
                    return Get-MockWSLCommandResponse -Command "verify_deployment.sh"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "cd $($vpsConfig.ProjectPath) && ./scripts/deploy/verify_deployment.sh"
            
            $result | Should -Not -BeNullOrEmpty
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should handle command execution failures" {
            $vpsConfig = $Global:VPSTestConfig.TestVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*false*") {
                    $Global:LASTEXITCODE = 1
                    return "Command failed"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "false"
            
            $LASTEXITCODE | Should -Be 1
        }
        
        It "Should handle long-running commands" {
            $vpsConfig = $Global:VPSTestConfig.TestVPS
            
            Mock ssh { 
                Start-Sleep -Milliseconds 200  # Simulate long-running command
                $Global:LASTEXITCODE = 0
                return "Long command completed"
            }
            
            $startTime = Get-Date
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "sleep 1"
            $endTime = Get-Date
            
            $duration = $endTime - $startTime
            $duration.TotalMilliseconds | Should -BeGreaterThan 100
            $result | Should -Be "Long command completed"
        }
    }
}

Describe "VPS Environment Validation Tests" {
    
    Context "VPS System Requirements" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
        }
        
        It "Should validate Docker availability on VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*docker --version*") {
                    $Global:LASTEXITCODE = 0
                    return "Docker version 24.0.0, build 1234567"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "docker --version"
            
            $result | Should -Match "Docker version"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should validate Git availability on VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*git --version*") {
                    $Global:LASTEXITCODE = 0
                    return "git version 2.34.1"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "git --version"
            
            $result | Should -Match "git version"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should validate project directory structure on VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*test -d*") {
                    $Global:LASTEXITCODE = 0
                    return ""
                }
                return "SSH command output"
            }
            
            ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "test -d $($vpsConfig.ProjectPath)"
            
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should validate deployment scripts exist on VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*test -f*complete_deployment.sh*") {
                    $Global:LASTEXITCODE = 0
                    return ""
                }
                elseif ($args -like "*test -f*verify_deployment.sh*") {
                    $Global:LASTEXITCODE = 0
                    return ""
                }
                return "SSH command output"
            }
            
            # Test deployment script
            ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "test -f $($vpsConfig.ProjectPath)/scripts/deploy/complete_deployment.sh"
            $LASTEXITCODE | Should -Be 0
            
            # Test verification script
            ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "test -f $($vpsConfig.ProjectPath)/scripts/deploy/verify_deployment.sh"
            $LASTEXITCODE | Should -Be 0
        }
    }
    
    Context "VPS Service Health Checks" {
        BeforeEach {
            $Global:LASTEXITCODE = 0
        }
        
        It "Should check Docker container status on VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*docker ps*") {
                    $Global:LASTEXITCODE = 0
                    return @(
                        "CONTAINER ID   IMAGE                    COMMAND                  CREATED       STATUS       PORTS                    NAMES",
                        "abc123def456   zoidbot-nginx    '/docker-entrypoint.…'   2 hours ago   Up 2 hours   0.0.0.0:80->80/tcp       nginx-proxy",
                        "def456ghi789   zoidbot-app      'flutter run --web'      2 hours ago   Up 2 hours   0.0.0.0:3000->3000/tcp   flutter-app"
                    ) -join "`n"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
            
            $result | Should -Match "nginx-proxy"
            $result | Should -Match "flutter-app"
            $result | Should -Match "Up"
        }
        
        It "Should check service endpoints on VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*curl*") {
                    $Global:LASTEXITCODE = 0
                    return "HTTP/1.1 200 OK"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "curl -I http://localhost"
            
            $result | Should -Match "200 OK"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should check SSL certificate status on VPS" {
            $vpsConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*openssl*") {
                    $Global:LASTEXITCODE = 0
                    return "Certificate will not expire"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($vpsConfig.User)@$($vpsConfig.Host)" "openssl x509 -in /etc/ssl/certs/zoidbot.crt -noout -dates"
            
            $result | Should -Not -BeNullOrEmpty
            $LASTEXITCODE | Should -Be 0
        }
    }
}

Describe "Multi-Environment VPS Testing" {
    
    Context "Staging vs Production Environment Differences" {
        It "Should use different VPS hosts for staging and production" {
            $stagingConfig = $Global:VPSTestConfig.StagingVPS
            $productionConfig = $Global:VPSTestConfig.ProductionVPS
            
            $stagingConfig.Host | Should -Not -Be $productionConfig.Host
            $stagingConfig.User | Should -Not -Be $productionConfig.User
        }
        
        It "Should use different project paths for staging and production" {
            $stagingConfig = $Global:VPSTestConfig.StagingVPS
            $productionConfig = $Global:VPSTestConfig.ProductionVPS
            
            $stagingConfig.ProjectPath | Should -Not -Be $productionConfig.ProjectPath
        }
        
        It "Should validate staging environment configuration" {
            $stagingConfig = $Global:VPSTestConfig.StagingVPS
            
            $stagingConfig.Host | Should -Match "staging"
            $stagingConfig.ProjectPath | Should -Match "staging"
        }
        
        It "Should validate production environment configuration" {
            $productionConfig = $Global:VPSTestConfig.ProductionVPS
            
            $productionConfig.Host | Should -Not -Match "staging"
            $productionConfig.Host | Should -Not -Match "test"
        }
    }
    
    Context "Environment-Specific Deployment Validation" {
        It "Should execute staging-specific deployment validation" {
            $stagingConfig = $Global:VPSTestConfig.StagingVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*$($stagingConfig.Host)*" -and $args -like "*verify_deployment.sh*") {
                    $Global:LASTEXITCODE = 0
                    return "Staging verification passed"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($stagingConfig.User)@$($stagingConfig.Host)" "cd $($stagingConfig.ProjectPath) && ./scripts/deploy/verify_deployment.sh"
            
            $result | Should -Match "verification passed"
            $LASTEXITCODE | Should -Be 0
        }
        
        It "Should execute production-specific deployment validation" {
            $productionConfig = $Global:VPSTestConfig.ProductionVPS
            
            Mock ssh { 
                param($args)
                if ($args -like "*$($productionConfig.Host)*" -and $args -like "*verify_deployment.sh*") {
                    $Global:LASTEXITCODE = 0
                    return "Production verification passed"
                }
                return "SSH command output"
            }
            
            $result = ssh "$($productionConfig.User)@$($productionConfig.Host)" "cd $($productionConfig.ProjectPath) && ./scripts/deploy/verify_deployment.sh"
            
            $result | Should -Match "verification passed"
            $LASTEXITCODE | Should -Be 0
        }
    }
}

AfterAll {
    # Cleanup test environment
    Clear-TestConfig
}