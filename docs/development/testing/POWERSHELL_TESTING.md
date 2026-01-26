# CloudToLocalLLM PowerShell Testing Framework

This directory contains comprehensive unit and integration tests for the CloudToLocalLLM automated deployment workflow PowerShell scripts.

## Overview

The testing framework provides:

- **Unit Tests**: Test individual PowerShell functions with mock objects
- **Integration Tests**: Test complete workflows and external dependencies
- **Mock Objects**: Realistic mock responses for WSL, SSH, Git, and other external dependencies
- **Test Configuration**: Centralized configuration for test execution and mock behavior
- **Automated Test Execution**: PowerShell test runner with comprehensive reporting

## Directory Structure

```
tests/powershell/
├── README.md                           # This documentation
├── Run-Tests.ps1                       # Main test runner script
├── TestConfig.ps1                      # Centralized test configuration
├── Deploy-CloudToLocalLLM.Tests.ps1    # Unit tests for main deployment script
├── BuildEnvironmentUtilities.Tests.ps1 # Unit tests for utility functions
├── Mocks/
│   └── WSLMocks.ps1                    # Mock objects for WSL and external dependencies
└── Integration/
    ├── EndToEnd.Tests.ps1              # End-to-end deployment workflow tests
    ├── VPSConnection.Tests.ps1         # VPS connectivity and authentication tests
    ├── GitHubRelease.Tests.ps1         # GitHub release creation and validation tests
    └── RollbackScenarios.Tests.ps1     # Rollback scenario testing and validation
```

## Prerequisites

### Required Software

- **PowerShell 5.1+** or **PowerShell Core 7.0+**
- **Pester 5.0+** (PowerShell testing framework)
- **Git** (for repository operations)

### Optional Software (for integration tests)

- **WSL2 with Ubuntu 24.04** (for WSL integration tests)
- **SSH client** (for VPS connectivity tests)
- **GitHub CLI (gh)** (for GitHub release tests)

### Installation

1. **Install Pester Module** (if not already installed):

   ```powershell
   Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
   ```

2. **Verify Installation**:

   ```powershell
   Get-Module -Name Pester -ListAvailable
   ```

## Running Tests

### Quick Start

Run all tests with default settings:

```powershell
.\tests\powershell\Run-Tests.ps1
```

### Test Execution Options

#### Run Specific Test File

```powershell
.\Run-Tests.ps1 -TestFile "Deploy-CloudToLocalLLM.Tests.ps1"
```

#### Run Tests with Code Coverage

```powershell
.\Run-Tests.ps1 -CodeCoverage
```

#### Run Tests with Detailed Output

```powershell
.\Run-Tests.ps1 -OutputFormat Detailed -Verbose
```

#### Export Test Results

```powershell
.\Run-Tests.ps1 -ExportResults -CodeCoverage
```

#### Run Tests by Tag

```powershell
.\Run-Tests.ps1 -Tag "Unit" -OutputFormat Minimal
```

### Advanced Options

#### Complete Test Suite with All Options

```powershell
.\Run-Tests.ps1 -CodeCoverage -ExportResults -OutputFormat Detailed -Verbose
```

#### Run Only Failed Tests (after initial run)

```powershell
.\Run-Tests.ps1 -FailedOnly
```

## Test Categories

### Unit Tests

#### Deploy-CloudToLocalLLM.Tests.ps1

Tests for the main deployment orchestration script:

- **Logging Functions**: Write-DeploymentLog, Update-DeploymentStatus
- **Prerequisites Validation**: Test-DeploymentPrerequisites
- **Version Management**: Update-ProjectVersion
- **Flutter Build**: Build-FlutterApplication
- **VPS Deployment**: Invoke-VPSDeployment
- **Verification**: Invoke-DeploymentVerification
- **Error Handling**: Exception handling and rollback triggers

#### BuildEnvironmentUtilities.Tests.ps1

Tests for utility functions:

- **Logging Functions**: Write-LogInfo, Write-LogSuccess, Write-LogWarning, Write-LogError
- **WSL Integration**: Test-WSLAvailable, Get-WSLDistributions, Invoke-WSLCommand
- **Path Conversion**: Convert-WindowsPathToWSL, Convert-WSLPathToWindows
- **SSH Functions**: Test-SSHConnectivity, Set-SSHKeyPermissions
- **Utility Functions**: Test-Command, Get-ProjectRoot, New-DirectoryIfNotExists

### Integration Tests

#### EndToEnd.Tests.ps1

Complete deployment workflow integration tests:

- **Happy Path Workflow**: Complete successful deployment
- **Error Scenarios**: Failure handling at each phase
- **Rollback Integration**: Automatic rollback triggers
- **Performance Testing**: Timeout and long-running operations
- **Cross-Platform Integration**: WSL and SSH integration

#### VPSConnection.Tests.ps1

VPS connectivity and authentication tests:

- **SSH Connectivity**: Connection testing and timeout handling
- **Authentication**: SSH key management and synchronization
- **Remote Command Execution**: Deployment and verification scripts
- **Environment Validation**: VPS system requirements and health checks
- **Multi-Environment Testing**: Staging vs production configurations

#### GitHubRelease.Tests.ps1

GitHub release creation and validation tests:

- **GitHub CLI Integration**: Authentication and repository access
- **Release Creation**: Creating releases with various options
- **Release Management**: Listing, viewing, and deleting releases
- **Git Integration**: Repository state validation and tagging
- **Release Notes Generation**: Automated release notes from commits

#### RollbackScenarios.Tests.ps1

Rollback scenario testing and validation:

- **Automatic Rollback Triggers**: Deployment and verification failures
- **Rollback Execution**: Git-based rollback and service restart
- **Rollback Verification**: Post-rollback health checks
- **Failure Recovery**: Rollback failure handling and manual recovery
- **Performance Monitoring**: Rollback timing and progress tracking

## Mock Objects and Test Data

### WSLMocks.ps1

Provides realistic mock responses for:

- **WSL Distribution Lists**: Various distribution scenarios
- **WSL Command Responses**: Flutter, Git, and system commands
- **File System Responses**: Project files and SSH keys
- **Network Responses**: SSH connectivity scenarios
- **Version Manager Responses**: Version increment and file updates

### TestConfig.ps1

Centralized configuration for:

- **Test Environment Settings**: Paths and temporary directories
- **Mock Behavior Configuration**: WSL, SSH, Git, Flutter, and network mocks
- **Test Data**: Sample project files, SSH keys, and command outputs
- **Test Execution Settings**: Timeouts, retries, and logging
- **Validation Settings**: Required files, commands, and endpoints

## Test Results and Reporting

### Test Output Formats

- **Minimal**: Basic pass/fail summary
- **Normal**: Standard Pester output with test names
- **Detailed**: Comprehensive output with timing and context
- **Diagnostic**: Full diagnostic information for troubleshooting

### Generated Reports

- **Test Results**: NUnit XML format for CI/CD integration
- **Code Coverage**: JaCoCo XML format for coverage analysis
- **Execution Logs**: Detailed test execution logs

### Report Locations

```
test-results/powershell/
├── TestResults_YYYYMMDD_HHMMSS.xml     # NUnit test results
└── Coverage_YYYYMMDD_HHMMSS.xml        # JaCoCo coverage report

coverage/powershell/
└── Coverage_YYYYMMDD_HHMMSS.xml        # Code coverage reports
```

## Continuous Integration

### GitHub Actions Integration

```yaml
- name: Run PowerShell Tests
  run: |
    .\tests\powershell\Run-Tests.ps1 -CodeCoverage -ExportResults -OutputFormat Minimal
  shell: pwsh

- name: Upload Test Results
  uses: actions/upload-artifact@v3
  with:
    name: test-results
    path: test-results/powershell/
```

### Azure DevOps Integration

```yaml
- task: PowerShell@2
  displayName: 'Run PowerShell Tests'
  inputs:
    targetType: 'filePath'
    filePath: 'tests/powershell/Run-Tests.ps1'
    arguments: '-CodeCoverage -ExportResults -OutputFormat Detailed'
    pwsh: true

- task: PublishTestResults@2
  inputs:
    testResultsFormat: 'NUnit'
    testResultsFiles: 'test-results/powershell/*.xml'
```

## Best Practices

### Writing Tests

1. **Use Descriptive Test Names**: Clearly describe what is being tested
2. **Follow AAA Pattern**: Arrange, Act, Assert
3. **Mock External Dependencies**: Use mock objects for WSL, SSH, Git, etc.
4. **Test Error Scenarios**: Include negative test cases
5. **Use BeforeEach/AfterEach**: Reset state between tests

### Mock Usage

1. **Realistic Responses**: Mock objects should return realistic data
2. **Error Simulation**: Include failure scenarios in mocks
3. **State Management**: Reset mock state between tests
4. **Parameter Validation**: Verify correct parameters are passed to mocks

### Test Organization

1. **Group Related Tests**: Use Describe and Context blocks effectively
2. **Shared Setup**: Use BeforeAll/BeforeEach for common setup
3. **Test Independence**: Each test should be independent
4. **Clear Assertions**: Use specific and meaningful assertions

## Troubleshooting

### Common Issues

#### Pester Module Not Found

```powershell
Install-Module -Name Pester -Force -SkipPublisherCheck -Scope CurrentUser
Import-Module Pester -Force
```

#### Test Execution Policy Issues

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Mock Objects Not Working

- Ensure mocks are defined in BeforeAll or BeforeEach blocks
- Verify mock parameter filters match actual function calls
- Check that mocks are imported correctly

#### WSL Integration Test Failures

- Verify WSL2 is installed and Ubuntu 24.04 is available
- Check that WSL distribution is running
- Ensure test environment has proper permissions

### Debug Mode

Run tests with verbose output for troubleshooting:

```powershell
.\Run-Tests.ps1 -OutputFormat Diagnostic -Verbose
```

### Test Environment Validation

Verify test environment setup:

```powershell
# Check Pester version
Get-Module -Name Pester -ListAvailable

# Verify PowerShell version
$PSVersionTable.PSVersion

# Check test configuration
. .\TestConfig.ps1
Initialize-TestConfig
Get-TestConfig
```

## Contributing

### Adding New Tests

1. **Create Test File**: Follow naming convention `*.Tests.ps1`
2. **Import Dependencies**: Include required modules and configurations
3. **Use Mock Objects**: Leverage existing mock infrastructure
4. **Document Tests**: Add clear descriptions and comments
5. **Update Documentation**: Update this README if needed

### Extending Mock Objects

1. **Add to WSLMocks.ps1**: Include new mock responses
2. **Update TestConfig.ps1**: Add configuration for new mocks
3. **Test Mock Behavior**: Verify mocks work as expected
4. **Document Changes**: Update mock documentation

### Test Coverage Goals

- **Unit Tests**: 90%+ code coverage for PowerShell functions
- **Integration Tests**: Cover all major workflow scenarios
- **Error Handling**: Test all error paths and recovery procedures
- **Cross-Platform**: Test Windows, WSL, and VPS interactions

## Support

For questions or issues with the testing framework:

1. Check this documentation first
2. Review existing test files for examples
3. Check the troubleshooting section
4. Create an issue in the project repository

## Version History

- **v1.0.0**: Initial testing framework with unit and integration tests
- **v1.1.0**: Added comprehensive mock objects and test configuration
- **v1.2.0**: Enhanced integration tests for VPS and GitHub workflows
- **v1.3.0**: Added rollback scenario testing and performance monitoring
