# Automatic Documentation Updates in Version Management

## Overview

The CloudToLocalLLM deployment workflow now automatically updates all relevant documentation files when versions are changed, ensuring consistency across all documentation and eliminating manual update errors.

## Implementation Details

### Important Clarification

Both version manager scripts (`scripts/powershell/version_manager.ps1` and `scripts/version_manager.sh`) are **development tools** designed for use by developers on their local machines. The choice between them depends on the developer's operating system, not the deployment target:

- **Windows developers** use the PowerShell version regardless of where they're deploying
- **Linux developers** use the bash version regardless of where they're deploying
- **VPS deployments** use automated deployment scripts that may incorporate version management logic but don't directly call these development tools

### Platform-Specific Scripts

**Windows Development Environment:**

- Primary script: `scripts/powershell/version_manager.ps1`
- Used by: `scripts/powershell/Deploy-CloudToLocalLLM.ps1`
- Context: Local development and version management on Windows systems

**Linux Development Environment:**

- Primary script: `scripts/version_manager.sh`
- Used by: Linux-based development workflows
- Context: Local development and version management on Linux systems

**Deployment:**

- Version managers are development tools used during the build process
- Kubernetes deployments use Dockerfiles which include version information
- Version is baked into Docker images during build

### Files Automatically Updated

When using `increment` or `set` commands, the following documentation files are automatically updated:

1. **README.md** (line 3)
   - Updates version badge: `[![Version](https://img.shields.io/badge/version-X.X.X-blue.svg)]`
   - Example: `version-3.13.0` → `version-4.0.32`

2. **package.json** (line 3)
   - Updates version field: `"version": "X.X.X"`
   - Example: `"version": "3.11.1"` → `"version": "4.0.32"`

3. **docs/CHANGELOG.md**
   - Adds new version entry with current date
   - Includes appropriate change description based on version type
   - Inserts entry in chronological order (newest first)

### Version Type Descriptions

The CHANGELOG.md entries are automatically categorized based on the version increment type:

- **major**: "### Breaking Changes - Major version update with breaking changes"
- **minor**: "### Added - New features and enhancements"
- **patch**: "### Fixed - Bug fixes and improvements"
- **build**: "### Technical - Build and deployment updates"
- **manual**: "### Changes - Version update"

## Usage Examples

### PowerShell (Windows Development)

```powershell
# Increment patch version and update all documentation
./scripts/powershell/version_manager.ps1 increment patch -SkipDependencyCheck

# Set specific version and update all documentation
./scripts/powershell/version_manager.ps1 set 4.1.0 -SkipDependencyCheck

# Increment minor version and update all documentation
./scripts/powershell/version_manager.ps1 increment minor -SkipDependencyCheck
```

### Bash (Linux Development)

```bash
# Increment patch version and update all documentation
./scripts/version_manager.sh increment patch

# Set specific version and update all documentation
./scripts/version_manager.sh set 4.1.0

# Increment minor version and update all documentation
./scripts/version_manager.sh increment minor
```

## Integration with Development Workflow

### Manual Version Increment Strategy

The version incrementing is performed **AFTER** deployment verification to give developers control over when versions are committed. Both version manager scripts are development tools used by developers on their local machines:

1. **Deploy Current Version**: Use existing version for deployment
2. **Verify Deployment**: Ensure all components are working correctly
3. **Manual Version Increment**: Developer uses appropriate version manager script based on their OS (automatically updates documentation)
4. **Commit Version Changes**: Prepare repository for next development cycle

### Development Environment Selection

- **Windows Developers**: Use `scripts/powershell/version_manager.ps1`
- **Linux Developers**: Use `scripts/version_manager.sh`
- **VPS Deployment**: Automated through deployment scripts, not direct version manager usage

### Example Development Workflow

**Windows Developer:**

```powershell
# 1. Deploy current version
./scripts/powershell/Deploy-CloudToLocalLLM.ps1 -SkipVersionUpdate

# 2. Verify deployment success
# (manual verification or automated tests)

# 3. Increment version (automatically updates documentation)
./scripts/powershell/version_manager.ps1 increment patch -SkipDependencyCheck

# 4. Commit changes
git add .
git commit -m "Update version to $(./scripts/powershell/version_manager.ps1 get-semantic) with documentation updates"
git push origin master
```

**Linux Developer:**

```bash
# 1. Deploy current version using appropriate deployment script
# (deployment method varies based on target environment)

# 2. Verify deployment success
# (manual verification or automated tests)

# 3. Increment version (automatically updates documentation)
./scripts/version_manager.sh increment patch

# 4. Commit changes
git add .
git commit -m "Update version to $(./scripts/version_manager.sh get-semantic) with documentation updates"
git push origin master
```

## Benefits

### 1. Consistency

- All documentation files are updated simultaneously
- No risk of version mismatches between files
- Standardized changelog entries

### 2. Automation

- Eliminates manual documentation updates
- Reduces human error in version management
- Ensures documentation is never forgotten

### 3. Traceability

- Automatic changelog entries with timestamps
- Clear version history with appropriate categorization
- Backup files created for all updates

### 4. Developer Experience

- Single command updates everything
- Clear feedback on what was updated
- Help text explains automatic updates

## Backup and Recovery

All documentation update functions create backup files:

- `README.md.backup`
- `package.json.backup`
- `docs/CHANGELOG.md.backup`

These backups can be used to restore previous states if needed.

## Error Handling

The documentation update functions include robust error handling:

- Missing files are skipped with warnings
- Backup creation before any modifications
- Graceful degradation if individual updates fail
- Clear success/failure logging

## Future Enhancements

Potential future improvements:

- API documentation version updates
- Docker compose file version updates
- Automated release notes generation
- Integration with GitHub releases API

---

**Last Updated**: 2025-08-01
**Implementation Version**: 4.0.32
