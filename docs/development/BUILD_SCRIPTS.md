# CloudToLocalLLM Build Scripts Guide

## Overview

This guide explains the different build scripts available in CloudToLocalLLM and when to use each one for creating release packages.

## Build Scripts Comparison

### 1. Build-GitHubReleaseAssets-Simple.ps1 ✅ **RECOMMENDED**

**Purpose**: Creates portable ZIP packages for GitHub releases

**Features**:

- ✅ Creates portable ZIP package with all dependencies
- ✅ Generates SHA256 checksums
- ✅ Includes GitHub asset upload functionality
- ✅ Clean, reliable, and well-tested
- ✅ Suitable for most users and deployment scenarios

**Usage**:

```powershell
# Basic build
.\Build-GitHubReleaseAssets-Simple.ps1

# Build and upload to GitHub release
.\Build-GitHubReleaseAssets-Simple.ps1 -UploadToGitHub -ReleaseId 228513276

# Clean build
.\Build-GitHubReleaseAssets-Simple.ps1 -Clean
```

**Output**: `dist/windows/cloudtolocalllm-{version}-portable.zip`

### 2. Create-UnifiedPackages.ps1 ⚠️ **INCOMPLETE**

**Purpose**: Intended to create multiple package formats (ZIP, MSI, NSIS)

**Current Status**:

- ✅ PortableZip: Fully implemented
- ❌ MSI: Not implemented (requires WiX Toolset)
- ❌ NSIS: Not implemented (requires NSIS compiler)

**Limitations**:

- MSI and NSIS package types will fail with "not implemented" errors
- Only creates the same portable ZIP as the simple script
- More complex but no additional functionality currently

**Usage** (not recommended until MSI/NSIS implemented):

```powershell
.\Create-UnifiedPackages.ps1 -PackageTypes @('PortableZip')
```

## Package Format Status

### ✅ Portable ZIP Package

- **Status**: Fully implemented and tested
- **Size**: ~13MB (includes Flutter web build and all dependencies)
- **Installation**: Extract and run `CloudToLocalLLM.exe`
- **Advantages**: No installation required, portable, works on all Windows versions
- **Recommended for**: Testing, temporary use, and users who prefer portable applications

### ✅ Inno Setup Installer Package

- **Status**: Implemented in the GitHub Actions Windows build lane
- **Output**: `CloudToLocalLLM-Windows-x64-Setup.exe`
- **Installation**: Guided installer with Start Menu shortcut, optional desktop shortcut, and per-user URL-scheme registration
- **Recommended for**: Most Windows users

### ❌ MSI Installer Package

- **Status**: Not implemented
- **Requirements**: WiX Toolset, MSI build configuration
- **Previous Files**: Existing MSI files in `dist/windows/msi/` are 69KB placeholder files
- **Implementation Needed**:
  - WiX configuration files (.wxs)
  - MSI build integration in PowerShell scripts
  - Installer UI and upgrade logic

### ❌ NSIS Setup Executable

- **Status**: Not implemented  
- **Requirements**: NSIS compiler, installer script configuration
- **Previous Files**: Existing NSIS files in `dist/windows/nsis/` are ~77KB placeholder files
- **Implementation Needed**:
  - NSIS installer script (.nsi)
  - NSIS build integration in PowerShell scripts
  - Installer UI and uninstaller logic

## Release Workflow Recommendations

### For Regular Releases (Recommended)

Use `Build-GitHubReleaseAssets-Simple.ps1` for all releases:

```powershell
# 1. Update version
.\version_manager.ps1 set 3.7.0

# 2. Build and upload to GitHub
.\Build-GitHubReleaseAssets-Simple.ps1 -Clean -UploadToGitHub -ReleaseId <release-id>
```

### For Development/Testing

```powershell
# Quick build without upload
.\Build-GitHubReleaseAssets-Simple.ps1 -SkipBuild
```

## Future MSI/NSIS Implementation

To implement MSI and NSIS packages in the future:

### MSI Implementation Requirements

1. Install WiX Toolset v3 or v4
2. Create WiX configuration files:
   - `installer/windows/CloudToLocalLLM.wxs` (main installer definition)
   - `installer/windows/Components.wxs` (file components)
3. Integrate MSI build into `Create-UnifiedPackages.ps1`
4. Add MSI-specific features (registry entries, start menu shortcuts, etc.)

### NSIS Implementation Requirements

1. Install NSIS compiler
2. Create NSIS installer script:
   - `installer/windows/CloudToLocalLLM.nsi`
3. Integrate NSIS build into `Create-UnifiedPackages.ps1`
4. Add NSIS-specific features (uninstaller, registry cleanup, etc.)

## Troubleshooting

### "Unknown package type" Error

- **Cause**: Using `Create-UnifiedPackages.ps1` with MSI or NSIS package types
- **Solution**: Use `Build-GitHubReleaseAssets-Simple.ps1` or only specify 'PortableZip' type

### GitHub Upload Fails

- **Cause**: GitHub CLI not installed or not authenticated
- **Solution**: Install GitHub CLI and run `gh auth login`

### Build Fails

- **Cause**: Flutter not in PATH or dependencies missing
- **Solution**: Run `flutter doctor` and resolve any issues

## Best Practices

1. **Always use the Simple build script** for releases until MSI/NSIS are implemented
2. **Test locally** before uploading to GitHub releases
3. **Use -Clean flag** for release builds to ensure fresh compilation
4. **Verify checksums** after building packages
5. **Document any build script changes** in this guide

## Migration from Previous Releases

If you previously relied on MSI or NSIS packages:

1. **For End Users**: The portable ZIP package provides the same functionality
2. **For Enterprise Deployment**: Consider using deployment tools that can handle ZIP packages
3. **For Automated Installation**: Create wrapper scripts around the portable package

The portable ZIP package is actually more flexible and reliable than traditional installers for many use cases.
