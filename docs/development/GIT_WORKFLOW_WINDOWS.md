# CloudToLocalLLM Git Workflow for Windows

## Overview

This document defines the comprehensive git workflow for CloudToLocalLLM development on Windows, addressing SSH authentication issues by using Git Bash for push operations while maintaining PowerShell for other development tasks.

## Comprehensive Commit and Push Workflow

When performing git operations in the CloudToLocalLLM repository, always follow this workflow:

### 1. Check for All Uncommitted Changes

```powershell
git status
```

**Purpose**: Identify ALL modified, added, or deleted files in the repository, not just files you recently worked on.

### 2. Review All Changes

```powershell
git diff
```

**Purpose**: Review all uncommitted changes to ensure they are intentional and related to your current work.

### 3. Stage All Relevant Changes

```powershell
# Stage all changes
git add .

# OR selectively add files
git add <file1> <file2> <file3>
```

**Include**:

- Files you directly modified
- Auto-generated files (like version files updated by scripts)
- Documentation updates
- Configuration changes
- Any other files modified as part of current work

### 4. Commit with Descriptive Message

```powershell
git commit -m "Comprehensive commit message describing all changes

- Primary change description
- Secondary changes included
- Auto-generated file updates
- Documentation updates
- Any other relevant changes"
```

### 5. Push to Remote (Windows-Specific)

**Use Git Bash for push operations to resolve SSH authentication issues:**

```powershell
bash -c "git push origin master"
```

**Alternative branches:**

```powershell
bash -c "git push origin <branch-name>"
```

**Force push (when necessary):**

```powershell
bash -c "git push origin master --force-with-lease"
```

### 6. Verify Push Success

```powershell
git status
git log --oneline -3
```

**Purpose**: Confirm push was successful and all changes are reflected in the remote repository.

## Why Git Bash for Push Operations?

### Problem

Windows PowerShell's SSH client has compatibility issues with certain SSH key formats, causing errors like:

- `Load key '/c/Users/user/.ssh/id_ed25519': error in libcrypto`
- `Permission denied (publickey)`

### Solution

Git Bash uses the same SSH implementation as Linux and handles SSH keys correctly on Windows.

### Workflow Impact

- **Other git operations**: Continue using PowerShell (status, add, commit, diff, log)
- **Push operations only**: Use Git Bash via `bash -c "git push ..."`
- **SSH testing**: Use `bash -c "ssh -T git@github.com"` to verify connectivity

## Complete Example Workflow

```powershell
# 1. Check status
git status

# 2. Review changes
git diff

# 3. Stage all changes
git add .

# 4. Commit with comprehensive message
git commit -m "Implement feature X with documentation updates

- Added new feature X functionality
- Updated configuration files
- Added unit tests for feature X
- Updated documentation in docs/
- Version files synchronized by scripts"

# 5. Push using native git command
git push origin master

# 6. Verify success
git status
git log --oneline -3
```

## Integration with CloudToLocalLLM Workflows

### Manual Version Increment Workflow

After performing manual version increment:

```powershell
# Version increment
./scripts/powershell/version_manager.ps1 increment patch

# Stage version files
git add pubspec.yaml assets/version.json lib/shared/lib/version.dart lib/config/app_config.dart lib/shared/pubspec.yaml

# Commit version changes
git commit -m "Increment version after deployment

- Post-deployment version management
- Prepare repository for next development cycle
- Automated version synchronization across all files"

# Push using Git Bash
bash -c "git push origin master"
```

### Deployment Workflow Integration

During deployment processes:

```powershell
# After deployment completion and verification
git add .
git commit -m "Complete deployment with all changes"
bash -c "git push origin master"
```

## Troubleshooting

### SSH Connectivity Issues

Test SSH connectivity:

```powershell
bash -c "ssh -T git@github.com"
```

Expected output: `Hi username! You've successfully authenticated...`

### SSH Agent Issues

If SSH agent is not running:

```powershell
# Check SSH agent status
Get-Service ssh-agent

# Start SSH agent (requires elevated permissions)
Start-Service ssh-agent
```

### Alternative: Use Git Bash Terminal

If PowerShell continues to have issues, open Git Bash directly:

1. Right-click in repository folder
2. Select "Git Bash Here"
3. Use standard git commands: `git push origin master`

## Best Practices

1. **Always use comprehensive workflow**: Don't skip steps
2. **Review all changes**: Use `git diff` before committing
3. **Descriptive commit messages**: Include all changes, not just primary ones
4. **Use Git Bash for push**: Resolves Windows SSH issues
5. **Verify push success**: Always confirm remote synchronization
6. **Stage related changes together**: Group logical changes in single commits

## Repository Consistency

This workflow ensures:

- ✅ No local changes left uncommitted
- ✅ All auto-generated files included in commits
- ✅ Comprehensive commit messages for traceability
- ✅ Reliable push operations on Windows
- ✅ Consistent repository state between local and remote

## Integration with Development Tools

### PowerShell Scripts

Continue using PowerShell for:

- Version management: `./scripts/powershell/version_manager.ps1`
- Build operations: `flutter build`, `flutter clean`
- File operations: `Get-Content`, `Test-Path`

### Git Usage

Use native git commands for all operations:

- Push operations: `git push origin master`
- SSH testing: `ssh -T git@github.com`
- All git operations work natively in PowerShell
