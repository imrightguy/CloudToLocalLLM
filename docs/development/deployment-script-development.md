# Deployment Script Development Guide

This document provides technical guidance for developers who need to maintain, extend, or customize the Zoidbot automated deployment script. It covers the script architecture, key components, and best practices for modifications.

## Script Architecture

The automated deployment script (`Deploy-Zoidbot.ps1`) follows a modular architecture with clear separation of concerns:

```
Deploy-Zoidbot.ps1
├── Parameter Handling and Configuration
├── Logging and Status Tracking
├── Core Deployment Phases
│   ├── Pre-flight Validation
│   ├── Version Management
│   ├── Flutter Build
│   ├── VPS Deployment
│   ├── Verification
│   └── GitHub Release
├── Error Handling and Rollback
└── Helper Functions
```

### Key Components

1. **Parameter Handling**: Processes command-line arguments and sets up configuration
2. **Logging System**: Provides structured logging with timestamps and color coding
3. **Deployment Status Tracking**: Maintains state throughout the deployment process
4. **Phase Execution**: Orchestrates the sequential execution of deployment phases
5. **Error Handling**: Catches and processes errors with appropriate recovery actions
6. **WSL Integration**: Manages interaction with WSL for Linux commands
7. **SSH Management**: Handles secure connections to the VPS
8. **Kiro Hook Integration**: Provides hook-compatible output and progress reporting

## Code Structure

### Main Script Sections

The deployment script is organized into these main sections:

1. **Script Header**: Documentation, parameter definitions, and help information
2. **Configuration**: Default settings and environment setup
3. **Logging Functions**: Enhanced logging with deployment context
4. **Core Functions**: Main deployment phase implementations
5. **Helper Functions**: Utility functions for common operations
6. **Main Execution**: Orchestration of the deployment workflow

### Key Functions

| Function | Purpose |
|----------|---------|
| `Initialize-DeploymentLogging` | Sets up logging system with file output |
| `Test-DeploymentPrerequisites` | Validates environment and dependencies |
| `Update-ProjectVersion` | Manages version incrementation and updates |
| `Build-FlutterApplication` | Orchestrates Flutter build process |
| `Invoke-VPSDeployment` | Executes deployment on VPS via SSH |
| `Invoke-DeploymentVerification` | Runs verification checks on deployed system |
| `New-GitHubRelease` | Creates GitHub releases with proper versioning |
| `Invoke-DeploymentRollback` | Handles rollback procedures on failure |
| `Write-DeploymentProgress` | Reports progress for UI feedback |
| `Update-DeploymentStatus` | Tracks deployment state throughout process |

## Extending the Script

### Adding a New Deployment Phase

To add a new deployment phase:

1. Create a new function for the phase:

```powershell
function Invoke-NewDeploymentPhase {
    [CmdletBinding()]
    param()
    
    Write-DeploymentLog -Level Phase -Message "New Deployment Phase"
    Update-DeploymentStatus -Phase "NewPhase" -Status "InProgress"
    
    try {
        # Phase implementation
        Write-DeploymentLog -Level Step -Message "Executing new phase step"
        
        # Your code here
        
        Write-DeploymentLog -Level Success -Message "New phase completed successfully"
        Update-DeploymentStatus -Status "Completed"
        return $true
    }
    catch {
        $errorMsg = "New phase failed: $($_.Exception.Message)"
        Write-DeploymentLog -Level Error -Message $errorMsg
        Update-DeploymentStatus -Status "Failed" -ErrorDetails $errorMsg
        return $false
    }
}
```

1. Add the phase to the main execution flow:

```powershell
# In the main execution section
if (Invoke-NewDeploymentPhase) {
    Write-DeploymentLog -Level Success -Message "New phase completed"
} else {
    Write-DeploymentLog -Level Error -Message "New phase failed"
    $deploymentSuccess = $false
    if ($AutoRollback) {
        Invoke-DeploymentRollback
    }
}
```

1. Add a parameter to control the phase (optional):

```powershell
[Parameter(HelpMessage = "Skip new phase")]
[switch]$SkipNewPhase
```

### Adding New Parameters

To add new command-line parameters:

1. Add the parameter definition to the `param()` block:

```powershell
[Parameter(HelpMessage = "Description of new parameter")]
[string]$NewParameter = "DefaultValue"
```

1. Update the configuration to include the new parameter:

```powershell
$Script:DeploymentConfig = @{
    # Existing configuration
    NewParameter = $NewParameter
}
```

1. Update the help information to document the new parameter:

```powershell
function Show-DeploymentHelp {
    # Existing help content
    Write-Host "  -NewParameter <value>                      Description of new parameter"
}
```

### Modifying Existing Phases

When modifying existing deployment phases:

1. Locate the function for the phase you want to modify
2. Make changes while preserving the error handling structure
3. Ensure proper logging of all actions
4. Update status tracking appropriately
5. Test thoroughly with both success and failure scenarios

Example of modifying an existing phase:

```powershell
function Build-FlutterApplication {
    [CmdletBinding()]
    param()
    
    # Existing code
    
    # Add new step
    Write-DeploymentLog -Level Step -Message "Running Flutter tests before build"
    if ($DryRun) {
        Write-DeploymentLog -Level Info -Message "[DRY RUN] Would run: flutter test"
    }
    else {
        Invoke-WSLCommand -DistroName $Script:DeploymentConfig.WSLDistribution -Command "cd $(Convert-WindowsPathToWSL $Script:ProjectRoot) && flutter test" -WorkingDirectory $Script:ProjectRoot
    }
    
    # Continue with existing code
}
```

## Error Handling Best Practices

When modifying or extending the script, follow these error handling practices:

1. **Use try-catch blocks** for all operations that might fail
2. **Log detailed error information** with context
3. **Update deployment status** on both success and failure
4. **Return boolean values** from phase functions to indicate success/failure
5. **Consider rollback implications** for each modification
6. **Preserve idempotence** where possible (operations can be safely repeated)

Example error handling pattern:

```powershell
try {
    # Operation that might fail
    $result = Some-Operation
    
    if ($result -ne $expectedValue) {
        throw "Operation returned unexpected value: $result"
    }
    
    Write-DeploymentLog -Level Success -Message "Operation completed successfully"
}
catch {
    $errorMsg = "Operation failed: $($_.Exception.Message)"
    Write-DeploymentLog -Level Error -Message $errorMsg
    
    # Consider whether this error should trigger rollback
    if ($criticalError) {
        $Script:DeploymentStatus.RollbackRequired = $true
    }
    
    throw $errorMsg  # Re-throw for higher-level handling
}
```

## Logging Best Practices

Follow these logging practices when modifying the script:

1. **Use appropriate log levels**:
   - `Info` for general information
   - `Success` for completed operations
   - `Warning` for non-critical issues
   - `Error` for failures
   - `Phase` for major deployment phases
   - `Step` for individual steps within phases
   - `Debug` for detailed troubleshooting information
   - `Verbose` for very detailed execution flow

2. **Include context in log messages**:
   - What operation is being performed
   - What resources are being affected
   - What the outcome or status is

3. **Log both attempts and outcomes**:
   - Log before starting an operation
   - Log the result after completion
   - Include relevant details in both logs

Example of proper logging:

```powershell
Write-DeploymentLog -Level Step -Message "Updating version in pubspec.yaml to $newVersion"
# Operation here
Write-DeploymentLog -Level Success -Message "Successfully updated pubspec.yaml version to $newVersion"
```

## Testing Modifications

After modifying the deployment script:

1. **Test with `-DryRun`** to validate logic without making changes
2. **Test with `-Verbose`** to see detailed execution flow
3. **Test error scenarios** by temporarily introducing failures
4. **Test rollback functionality** to ensure it works with your changes
5. **Test in staging environment** before using in production
6. **Test Kiro hook integration** if applicable

## Linux Build Integration (WSL)

**Important**: WSL integration is only required for:

1. **Building Linux application packages** (Debian, AppImage, etc.)

WSL should **NOT** be used for:

- Windows development workflows
- Version management on Windows
- Local file operations on Windows
- Git operations on Windows
- **VPS deployment operations** (use PowerShell SSH instead)

When building Linux packages using WSL:

1. **Use WSL wrapper functions only for Linux builds**:
   - `Invoke-WSLCommand` for executing Linux build commands
   - `Test-WSLDistribution` for checking WSL availability (Linux builds only)
   - `Convert-WindowsPathToWSL` for path conversion (Linux builds only)

2. **Handle path conversions for Linux builds**:
   - Windows paths need to be converted to WSL paths for Linux builds
   - Use proper quoting for paths with spaces
   - Consider using absolute paths where possible

Example WSL integration for Linux builds only:

```powershell
# WSL is ONLY for Linux application builds, NEVER for deployment
if ($BuildLinuxPackages) {
    $wslPath = Convert-WindowsPathToWSL $Script:ProjectRoot
    $command = "cd $wslPath && flutter build linux --release"
    $result = Invoke-WSLCommand -DistroName "Ubuntu-24.04" -Command $command -WorkingDirectory $Script:ProjectRoot -PassThru
}

# For VPS deployment, use PowerShell SSH instead:
# ssh cloudllm@zoidbot.online "cd /opt/zoidbot && ./scripts/deploy/complete_deployment.sh --force"
```

## PowerShell Deployment Integration

For deployment operations, use native PowerShell capabilities:

1. **Use PowerShell for Windows deployment operations**:
   - Native PowerShell cmdlets for file operations
   - `ssh` command for VPS operations (from Windows to Linux VPS)
   - PowerShell version manager for version operations

2. **Example PowerShell deployment**:

```powershell
# Use PowerShell for deployment, not WSL
$sshCommand = "ssh cloudllm@zoidbot.online 'cd /opt/zoidbot && bash scripts/deploy/complete_deployment.sh'"
Invoke-Expression $sshCommand
```

## SSH Integration

When working with SSH operations:

1. **Use consistent connection parameters**:
   - Store connection info in `$Script:DeploymentConfig`
   - Use the same timeout and retry settings

2. **Handle SSH errors appropriately**:
   - Check exit codes from SSH commands
   - Capture and log SSH output
   - Implement retry logic for transient failures

3. **Consider security implications**:
   - Use key-based authentication only
   - Avoid hardcoding credentials
   - Validate SSH connections before executing commands

Example SSH integration:

```powershell
$vpsConnection = "$($Script:DeploymentConfig.VPSUser)@$($Script:DeploymentConfig.VPSHost)"
$command = "cd $($Script:DeploymentConfig.VPSProjectPath) && ./scripts/deploy/some_script.sh"

try {
    $output = ssh -o ConnectTimeout=30 $vpsConnection $command 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "SSH command failed with exit code $LASTEXITCODE. Output: $output"
    }
    
    Write-DeploymentLog -Level Success -Message "SSH command executed successfully"
    return $output
}
catch {
    Write-DeploymentLog -Level Error -Message "SSH command failed: $($_.Exception.Message)"
    throw
}
```

## Kiro Hook Integration

When enhancing Kiro hook support:

1. **Maintain hook-compatible output**:
   - Use consistent output patterns that hooks can parse
   - Include progress indicators for long-running operations

2. **Support hook parameters**:
   - Handle parameters passed from hook configuration
   - Provide sensible defaults for missing parameters

3. **Ensure proper error reporting**:
   - Return appropriate exit codes
   - Format error messages for hook consumption

Example hook-compatible output:

```powershell
if ($Script:DeploymentConfig.KiroHookMode) {
    Write-Host "Progress: 75%" -ForegroundColor Green
    Write-Host "[INFO] Executing deployment on VPS" -ForegroundColor White
} else {
    Write-Progress -Activity "Zoidbot Deployment" -Status "Deploying" -CurrentOperation "Executing on VPS" -PercentComplete 75
    Write-Host "Executing deployment on VPS..." -ForegroundColor Cyan
}
```

## Version Management Integration

When working with version management:

1. **Use the existing version management script**:
   - Call `version_manager.ps1` for version operations
   - Maintain consistent version format across files

2. **Handle version backup and rollback**:
   - Back up version state before changes
   - Implement version rollback on deployment failure

3. **Ensure Git integration**:
   - Commit version changes when appropriate
   - Tag releases with version numbers

Example version management integration:

```powershell
# Get current version
$currentVersion = & $versionManagerPath get-semantic
Write-DeploymentLog -Level Info -Message "Current version: $currentVersion"

# Back up version state
$Script:VersionBackup = $currentVersion

# Increment version
& $versionManagerPath increment $VersionIncrement

# Get new version
$newVersion = & $versionManagerPath get-semantic
Write-DeploymentLog -Level Success -Message "Version updated: $currentVersion -> $newVersion"
```

## Performance Considerations

When modifying the script, consider these performance aspects:

1. **Minimize WSL context switches**:
   - Batch commands where possible
   - Avoid unnecessary WSL calls

2. **Optimize SSH operations**:
   - Use connection sharing for multiple commands
   - Minimize the number of SSH connections

3. **Handle large files efficiently**:
   - Stream large outputs rather than loading into memory
   - Use compression for file transfers

4. **Implement timeouts appropriately**:
   - Set reasonable timeouts for network operations
   - Provide progress feedback for long-running operations

## Documentation

When modifying the script:

1. **Update inline documentation**:
   - Keep function documentation current
   - Document parameters and return values
   - Explain complex logic with comments

2. **Update help information**:
   - Add new parameters to help output
   - Document new features and behaviors

3. **Update external documentation**:
   - Update this developer guide for significant changes
   - Update user documentation for visible changes

## Security Considerations

When modifying the script:

1. **Avoid hardcoding sensitive information**:
   - Use parameters or configuration files
   - Consider environment variables for sensitive values

2. **Validate user input**:
   - Check parameter values before use
   - Sanitize inputs used in commands

3. **Use secure communication**:
   - Ensure SSH uses key-based authentication
   - Validate SSL certificates for HTTPS connections

4. **Handle credentials securely**:
   - Don't log sensitive information
   - Clear sensitive variables when no longer needed

## Further Resources

- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/developer/cmdlet/cmdlet-development-guidelines)
- [WSL Documentation](https://docs.microsoft.com/en-us/windows/wsl/)
- [SSH Key Management](https://www.ssh.com/academy/ssh/keygen)
- [Docker Deployment Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [Flutter Build Documentation](https://docs.flutter.dev/deployment/web)
