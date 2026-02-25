# CloudToLocalLLM Deployment Testing Guide

This document provides comprehensive guidance on testing the automated deployment workflow for CloudToLocalLLM.

## Overview

The deployment testing framework provides a structured approach to validate all aspects of the automated deployment workflow, including:

- Basic functionality testing
- Error scenario handling
- Rollback procedures
- Kiro hook integration
- Performance optimization

## Test Structure

The testing framework consists of several specialized test scripts:

1. **Test-DeploymentWorkflow.ps1**: Tests the basic functionality of the deployment workflow
2. **Test-DeploymentErrorScenarios.ps1**: Tests error handling and rollback procedures
3. **Test-KiroHookIntegration.ps1**: Tests Kiro hook integration and execution
4. **Run-DeploymentIntegrationTests.ps1**: Master script to run all tests and generate reports

## Running Tests

### Using the Batch File

The simplest way to run tests is using the provided batch file:

```cmd
scripts\run-deployment-tests.bat
```

Command-line options:

- `-TestSuite <All|Basic|ErrorScenarios|KiroHook|Performance>`: Test suite to run (default: All)
- `-Environment <Local|Staging>`: Target test environment (default: Staging)
- `-GenerateReport`: Generate HTML report
- `-Verbose`: Enable verbose logging
- `-Help`: Show help message

Examples:

```cmd
# Run all tests
scripts\run-deployment-tests.bat

# Run basic tests only
scripts\run-deployment-tests.bat -TestSuite Basic

# Run all tests and generate HTML report
scripts\run-deployment-tests.bat -GenerateReport
```

### Using PowerShell Directly

You can also run the PowerShell scripts directly:

```powershell
# Run all tests
.\scripts\powershell\Run-DeploymentIntegrationTests.ps1

# Run specific test suite
.\scripts\powershell\Run-DeploymentIntegrationTests.ps1 -TestSuite ErrorScenarios

# Run individual test script
.\scripts\powershell\Test-KiroHookIntegration.ps1 -CreateHook -TestHookExecution
```

### Using Kiro Hook

A Kiro hook is provided for running the tests:

1. Open the Kiro panel in your IDE
2. Navigate to the "Agent Hooks" section
3. Find and click "Run Deployment Tests"
4. The tests will run and generate a report

## Test Suites

### Basic Workflow Tests

Tests the fundamental functionality of the deployment workflow:

- Script execution and parameter handling
- Pre-flight validation
- Version management
- Dry run mode

### Error Scenario Tests

Tests error handling and recovery mechanisms:

- Invalid parameter handling
- Build failures
- Deployment errors
- Verification failures
- Automatic rollback procedures

### Kiro Hook Integration Tests

Tests integration with Kiro hooks:

- Hook configuration validation
- Hook execution simulation
- Output formatting for Kiro interface

### Performance Tests

Tests the performance and optimization of the deployment workflow:

- Execution time measurement
- Resource usage monitoring
- Optimization opportunities

## Test Reports

### Log Files

All test runs generate detailed log files in the `logs` directory:

- `deployment_test_YYYYMMDD_HHMMSS.log`: Comprehensive test log
- `error_scenarios_test_YYYYMMDD.log`: Error scenario test log
- `hook_execution_YYYYMMDD.log`: Kiro hook integration test log
- `integration_test_YYYYMMDD_HHMMSS.log`: Master integration test log

### HTML Reports

When using the `-GenerateReport` option, an HTML report is generated:

- `integration_test_report_YYYYMMDD_HHMMSS.html`: Comprehensive HTML report

The HTML report provides:

- Test summary statistics
- Pass/fail rates
- Test suite details
- Links to log files

## Best Practices

1. **Run in Staging First**: Always run tests in a staging environment before production
2. **Regular Testing**: Run tests after any significant changes to the deployment workflow
3. **Complete Test Suite**: Run the complete test suite before releases
4. **Review Reports**: Always review test reports for warnings and optimization opportunities
5. **Update Tests**: Keep tests updated as the deployment workflow evolves

## Troubleshooting

### Common Issues

#### Tests Fail with PowerShell Execution Policy Error

```
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

#### Tests Fail with WSL Not Available

WSL is only required for Linux application building, not deployment testing:

```powershell
# WSL is optional - only needed for Linux package creation
# Deployment tests use PowerShell SSH, not WSL
wsl --list --verbose  # Check if needed for Linux builds
```

#### Tests Fail with SSH Connection Issues

Verify SSH configuration:

```powershell
ssh -T <vps_user>@<vps_host>
```

#### Tests Run Slowly

Use specific test suites instead of running all tests:

```cmd
scripts\run-deployment-tests.bat -TestSuite Basic
```

## Extending the Test Framework

To add new tests:

1. Create a new PowerShell script in `scripts/powershell/`
2. Follow the existing test script patterns
3. Add the new test to the appropriate test suite in `Run-DeploymentIntegrationTests.ps1`
4. Update this documentation to reflect the new tests

## Conclusion

The deployment testing framework provides comprehensive validation of the automated deployment workflow. Regular testing ensures the reliability and robustness of the deployment process, reducing the risk of deployment failures and improving the overall quality of the CloudToLocalLLM application.
