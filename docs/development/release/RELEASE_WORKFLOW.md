# CloudToLocalLLM Release Workflow

## Overview

This document provides the complete, tested workflow for creating CloudToLocalLLM releases. Follow these steps exactly to ensure successful releases with all assets properly uploaded.

## Prerequisites

### Required Tools

- [x] **PowerShell 5.1+** (Windows) or **PowerShell Core 7+** (cross-platform)
- [x] **Flutter SDK** (latest stable version)
- [x] **Git** with repository access
- [x] **GitHub CLI** (`gh`) installed and authenticated
- [x] **WSL Ubuntu** (for VPS deployment)

### Authentication Setup

```bash
# Authenticate GitHub CLI (one-time setup)
gh auth login

# Verify authentication
gh auth status
```

### Environment Verification

```powershell
# Run this before starting any release
.\scripts\powershell\version_manager.ps1 get
flutter doctor
gh auth status
git status
```

## Release Workflow Steps

### Step 1: Pre-Release Preparation

1. **Ensure Clean Working Directory**:

   ```bash
   git status
   # Should show "working tree clean"
   ```

2. **Verify Current Version**:

   ```powershell
   .\scripts\powershell\version_manager.ps1 get
   ```

3. **Test Build Locally**:

   ```powershell
   .\scripts\powershell\Build-GitHubReleaseAssets-Simple.ps1 -Clean
   ```

### Step 2: Version Management

1. **Update Version Number**:

   ```powershell
   # For new major/minor release
   .\scripts\powershell\version_manager.ps1 set X.Y.Z
   
   # Example for v3.8.0
   .\scripts\powershell\version_manager.ps1 set 3.8.0
   ```

2. **Verify Version Update**:

   ```powershell
   .\scripts\powershell\version_manager.ps1 get
   # Check that all files are updated consistently
   ```

### Step 3: Build Release Assets

1. **Clean Build with Asset Creation**:

   ```powershell
   .\scripts\powershell\Build-GitHubReleaseAssets-Simple.ps1 -Clean
   ```

2. **Verify Build Output**:

   ```powershell
   Get-ChildItem dist\windows\cloudtolocalllm-*.zip*
   # Should show both .zip and .sha256 files
   ```

### Step 4: Create GitHub Release

1. **Create Release via GitHub CLI**:

   ```bash
   # Create draft release
   gh release create v3.8.0 --draft --title "CloudToLocalLLM v3.8.0 - [Feature Name]" --notes-file release-notes.md
   
   # Or create release directly
   gh release create v3.8.0 --title "CloudToLocalLLM v3.8.0 - [Feature Name]" --notes "Release notes here"
   ```

2. **Get Release ID** (if using API):

   ```bash
   gh api repos/CloudToLocalLLM-online/CloudToLocalLLM/releases/latest | jq '.id'
   ```

### Step 5: Upload Assets to GitHub Release

**Option A: Integrated Build + Upload (Recommended)**

```powershell
# Build and upload in one step
.\scripts\powershell\Build-GitHubReleaseAssets-Simple.ps1 -Clean -UploadToGitHub -ReleaseId <release-id>
```

**Option B: Separate Upload**

```powershell
# Upload to existing release
.\scripts\powershell\Upload-GitHubReleaseAssets.ps1 -ReleaseId <release-id>
```

**Option C: GitHub CLI Upload**

```bash
# Upload specific files
gh release upload v3.8.0 dist/windows/cloudtolocalllm-3.8.0-portable.zip
gh release upload v3.8.0 dist/windows/cloudtolocalllm-3.8.0-portable.zip.sha256
```

### Step 6: Commit and Push Changes

1. **Commit Version Changes**:

   ```bash
   git add .
   git commit -m "Release v3.8.0: [Brief description of main features]
   
   - [Feature 1 description]
   - [Feature 2 description]
   - Update version to 3.8.0+[timestamp]"
   ```

2. **Push to Repository**:

   ```bash
   git push origin master
   ```

### Step 7: Deploy to VPS

1. **Deploy via SSH from Windows PowerShell**:

   ```powershell
   ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git pull origin master && flutter build web --release && docker-compose -f docker-compose.multi.yml down && docker-compose -f docker-compose.multi.yml up -d"
   ```

2. **Verify Deployment**:

   ```powershell
   curl -s https://app.cloudtolocalllm.online/version.json
   # Should show new version number
   ```

### Step 8: Post-Release Verification

1. **Verify GitHub Release**:
   - [ ] Release page accessible
   - [ ] Assets downloadable
   - [ ] Release notes complete
   - [ ] Version tags correct

2. **Verify VPS Deployment**:
   - [ ] Application accessible at cloudtolocalllm.online
   - [ ] Version number updated
   - [ ] New features functional

3. **Test Download and Installation**:
   - [ ] Download ZIP package
   - [ ] Verify SHA256 checksum
   - [ ] Test application startup
   - [ ] Verify new features work

## Error Handling

### Common Issues and Solutions

#### GitHub CLI Not Authenticated

```bash
# Error: authentication required
gh auth login
gh auth refresh
```

#### Asset Upload Fails

```powershell
# Retry with standalone upload script
.\scripts\powershell\Upload-GitHubReleaseAssets.ps1 -ReleaseId <id>
```

#### Build Fails

```powershell
# Clean everything and retry
flutter clean
flutter pub get
.\scripts\powershell\Build-GitHubReleaseAssets-Simple.ps1 -Clean
```

#### VPS Deployment Fails

```bash
# Check VPS status and retry
wsl -d Ubuntu-24.04 -- ssh cloudllm@cloudtolocalllm.online "docker ps"
# Retry deployment commands individually
```

### Rollback Procedures

#### Rollback GitHub Release

```bash
# Delete release if needed
gh release delete v3.8.0 --yes

# Or mark as pre-release
gh release edit v3.8.0 --prerelease
```

#### Rollback VPS Deployment

```bash
# Revert to previous version
wsl -d Ubuntu-24.04 -- ssh cloudllm@cloudtolocalllm.online "cd /opt/cloudtolocalllm && git reset --hard HEAD~1 && flutter build web --release && docker-compose -f docker-compose.multi.yml restart"
```

## Quality Checklist

### Pre-Release Checklist

- [ ] All tests passing
- [ ] Documentation updated
- [ ] Version numbers consistent
- [ ] Build artifacts verified
- [ ] GitHub CLI authenticated

### Release Checklist

- [ ] GitHub release created
- [ ] Assets uploaded successfully
- [ ] Release notes comprehensive
- [ ] Version committed and pushed
- [ ] VPS deployment successful

### Post-Release Checklist

- [ ] Download links functional
- [ ] Application starts correctly
- [ ] New features working
- [ ] Version displayed correctly
- [ ] No critical issues reported

## Automation Opportunities

### Future Improvements

1. **GitHub Actions Workflow**: Automate entire release process
2. **Automated Testing**: Run tests before release creation
3. **Multi-Platform Builds**: Automate Linux package creation
4. **Release Notes Generation**: Auto-generate from commit messages
5. **Deployment Verification**: Automated post-deployment testing

### Monitoring

- Set up alerts for failed deployments
- Monitor download statistics
- Track user feedback on new releases
- Monitor application performance post-release

## Contact and Support

For questions about the release process:

- Check this documentation first
- Review post-mortem documents for known issues
- Create GitHub issue for process improvements
- Update this documentation when process changes
