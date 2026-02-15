# Test Configuration for Zoidbot PowerShell Tests
# Centralized configuration for test execution and mock behavior

# Test execution configuration
$Script:TestConfig = @{
    # Test environment settings
    Environment = @{
        ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        TestDataPath = Join-Path $PSScriptRoot "TestData"
        MocksPath = Join-Path $PSScriptRoot "Mocks"
        TempPath = Join-Path $env:TEMP "Zoidbot_Tests"
    }
    
    # Mock behavior configuration
    Mocks = @{
        # WSL mock settings
        WSL = @{
            DefaultDistribution = "Ubuntu-24.04"
            AvailableDistributions = @("Ubuntu-24.04", "Ubuntu-22.04", "Debian")
            SimulateFailures = $false
            ResponseDelay = 0  # milliseconds
        }
        
        # SSH mock settings
        SSH = @{
            DefaultHost = "test.zoidbot.online"
            DefaultUser = "testuser"
            DefaultPort = 22
            SimulateConnectivity = $true
            ConnectionTimeout = 10
        }
        
        # Git mock settings
        Git = @{
            SimulateRepository = $true
            DefaultBranch = "main"
            HasUncommittedChanges = $false
            RemoteUrl = "https://github.com/test/zoidbot.git"
        }
        
        # Flutter mock settings
        Flutter = @{
            Version = "3.8.0"
            BuildSuccess = $true
            BuildOutputPath = "build/web"
            SimulateDependencies = $true
        }
        
        # Version manager mock settings
        VersionManager = @{
            CurrentVersion = "3.10.3"
            BuildNumber = 123
            IncrementSuccess = $true
            FilesToUpdate = @("pubspec.yaml", "assets/version.json")
        }
        
        # Network mock settings
        Network = @{
            InternetConnectivity = $true
            VPSConnectivity = $true
            DNSResolution = $true
            SSLCertificateValid = $true
        }
    }
    
    # Test data configuration
    TestData = @{
        # Sample project files
        ProjectFiles = @{
            "pubspec.yaml" = @"
name: zoidbot
description: Zoidbot Flutter Application
version: 3.10.3+123

environment:
  sdk: '>=3.8.0 <4.0.0'
  flutter: ">=3.8.0"

dependencies:
  flutter:
    sdk: flutter
  go_router: ^16.0.0
  provider: ^6.1.5
  http: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
"@
            
            "lib/main.dart" = @"
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void main() {
  runApp(ZoidbotApp());
}

class ZoidbotApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Zoidbot',
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomeScreen(),
    ),
  ],
);

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Zoidbot')),
      body: Center(child: Text('Welcome to Zoidbot')),
    );
  }
}
"@
            
            "assets/version.json" = @"
{
  "version": "3.10.3",
  "build": 123,
  "timestamp": "2024-01-15T10:30:00Z",
  "commit": "abc123def456"
}
"@
        }
        
        # Sample SSH keys
        SSHKeys = @{
            "id_rsa" = @"
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAFwAAAAdzc2gtcn
NhAAAAAwEAAQAAAQEA1234567890abcdef...
-----END OPENSSH PRIVATE KEY-----
"@
            
            "id_rsa.pub" = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQD1234567890abcdef... testuser@testhost"
            
            "id_ed25519" = @"
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACAbcdef1234567890...
-----END OPENSSH PRIVATE KEY-----
"@
            
            "id_ed25519.pub" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBtx3vEjRWeJSACaGVQoBaqkrgl... testuser@testhost"
        }
        
        # Sample command outputs
        CommandOutputs = @{
            "wsl_list_verbose" = @(
                "  NAME            STATE           VERSION",
                "* Ubuntu-24.04    Running         2",
                "  Ubuntu-22.04    Stopped         2",
                "  Debian          Running         2"
            )
            
            "flutter_version" = @(
                "Flutter 3.8.0 • channel stable • https://github.com/flutter/flutter.git",
                "Framework • revision 12345abc (2 weeks ago) • 2024-01-15 10:30:00 -0800",
                "Engine • revision 67890def",
                "Tools • Dart 3.2.0 (build 3.2.0-1.0.dev) • DevTools 2.28.4"
            )
            
            "git_status_clean" = ""
            
            "git_status_dirty" = @(
                " M lib/main.dart",
                "?? new_file.txt"
            )
            
            "ssh_test_success" = "SSH connection test successful"
            
            "deployment_success" = @(
                "Starting deployment process...",
                "Pulling latest changes from repository...",
                "Building Docker containers...",
                "Starting services...",
                "Running health checks...",
                "Deployment completed successfully!"
            )
            
            "verification_success" = @(
                "Verifying HTTP endpoints... OK",
                "Verifying HTTPS endpoints... OK",
                "Checking SSL certificate validity... OK",
                "Testing container health... OK",
                "All verification checks passed!"
            )
        }
    }
    
    # Test execution settings
    Execution = @{
        # Timeout settings (in seconds)
        Timeouts = @{
            ShortOperation = 5
            MediumOperation = 30
            LongOperation = 300
            DeploymentOperation = 1800
        }
        
        # Retry settings
        Retries = @{
            MaxAttempts = 3
            DelayBetweenAttempts = 1  # seconds
            ExponentialBackoff = $true
        }
        
        # Logging settings
        Logging = @{
            EnableVerbose = $false
            EnableDebug = $false
            LogToFile = $false
            LogFilePath = Join-Path $env:TEMP "Zoidbot_Test.log"
        }
        
        # Cleanup settings
        Cleanup = @{
            RemoveTempFiles = $true
            RemoveTestContainers = $true
            RestoreOriginalFiles = $true
        }
    }
    
    # Test validation settings
    Validation = @{
        # File validation
        Files = @{
            RequiredProjectFiles = @(
                "pubspec.yaml",
                "lib/main.dart",
                "scripts/powershell/Deploy-Zoidbot.ps1",
                "scripts/powershell/BuildEnvironmentUtilities.ps1"
            )
            
            RequiredBuildOutputs = @(
                "build/web/index.html",
                "build/web/main.dart.js",
                "build/web/flutter.js"
            )
        }
        
        # Command validation
        Commands = @{
            RequiredCommands = @(
                "git",
                "flutter",
                "wsl"
            )
            
            OptionalCommands = @(
                "ssh",
                "choco",
                "docker"
            )
        }
        
        # Network validation
        Network = @{
            RequiredEndpoints = @(
                "https://github.com",
                "https://pub.dev"
            )
            
            VPSEndpoints = @(
                "https://zoidbot.online",
                "https://api.zoidbot.online"
            )
        }
    }
}

# Function to get test configuration
function Get-TestConfig {
    [CmdletBinding()]
    param(
        [string]$Section = $null
    )
    
    if ($Section) {
        return $Script:TestConfig[$Section]
    }
    
    return $Script:TestConfig
}

# Function to set test configuration
function Set-TestConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Section,
        
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $true)]
        $Value
    )
    
    if (-not $Script:TestConfig.ContainsKey($Section)) {
        $Script:TestConfig[$Section] = @{}
    }
    
    $Script:TestConfig[$Section][$Key] = $Value
}

# Function to initialize test environment
function Initialize-TestConfig {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot = $null
    )
    
    if ($ProjectRoot) {
        $Script:TestConfig.Environment.ProjectRoot = $ProjectRoot
    }
    
    # Create temp directory if it doesn't exist
    $tempPath = $Script:TestConfig.Environment.TempPath
    if (-not (Test-Path $tempPath)) {
        New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
    }
    
    # Set environment variables for tests
    $env:CLOUDTOLOCALLLM_TEST_MODE = "true"
    $env:CLOUDTOLOCALLLM_PROJECT_ROOT = $Script:TestConfig.Environment.ProjectRoot
    $env:CLOUDTOLOCALLLM_TEST_TEMP = $tempPath
    
    return $Script:TestConfig
}

# Function to cleanup test environment
function Clear-TestConfig {
    [CmdletBinding()]
    param()
    
    # Remove temp directory
    $tempPath = $Script:TestConfig.Environment.TempPath
    if (Test-Path $tempPath) {
        Remove-Item -Path $tempPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Clear environment variables
    Remove-Item -Path "env:CLOUDTOLOCALLLM_TEST_MODE" -ErrorAction SilentlyContinue
    Remove-Item -Path "env:CLOUDTOLOCALLLM_PROJECT_ROOT" -ErrorAction SilentlyContinue
    Remove-Item -Path "env:CLOUDTOLOCALLLM_TEST_TEMP" -ErrorAction SilentlyContinue
}

# Export functions
Export-ModuleMember -Function @(
    'Get-TestConfig',
    'Set-TestConfig',
    'Initialize-TestConfig',
    'Clear-TestConfig'
)