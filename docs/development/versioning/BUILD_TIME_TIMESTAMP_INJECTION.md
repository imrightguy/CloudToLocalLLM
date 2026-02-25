# CloudToLocalLLM Build-Time Timestamp Injection v3.5.5+

## Overview

CloudToLocalLLM now implements build-time timestamp injection to ensure that timestamp-based build numbers (YYYYMMDDHHMM format) are generated at the exact moment when the actual build process occurs, not during version increment or preparation phases. This provides accurate build tracking and deployment correlation.

## Key Concepts

### Build-Time vs Preparation-Time Timestamps

**Previous Behavior (Preparation-Time):**

- Timestamp generated when running `./scripts/version_manager.sh increment build`
- Build number reflected when version was incremented, not when build was executed
- Gap between version preparation and actual build execution

**New Behavior (Build-Time):**

- Timestamp generated during actual Flutter build command execution
- Build number accurately reflects when build artifacts were created
- True correlation between build timestamp and artifact creation time

## Architecture

### Core Components

#### 1. **Version Manager with Preparation Mode**

- **`./scripts/version_manager.sh prepare <type>`**: Prepares version with placeholder
- **`./scripts/version_manager.sh increment <type>`**: Immediate timestamp (legacy mode)
- **Placeholder**: `BUILD_TIME_PLACEHOLDER` used during preparation

#### 2. **Build-Time Version Injector**

- **`./scripts/build_time_version_injector.sh`**: Core injection script
- **Commands**: `inject`, `restore`, `cleanup`
- **Backup System**: Automatic backup and restore of version files

#### 3. **Flutter Build Wrapper**

- **`./scripts/flutter_build_with_timestamp.sh`**: Wraps Flutter build commands
- **Automatic Injection**: Injects timestamp before build, restores after
- **Error Handling**: Proper cleanup on build failures

#### 4. **Integration Points**

- **Deployment Scripts**: Updated to use build-time injection
- **Package Scripts**: AUR, Snap, Debian packages use build-time timestamps
- **Build Automation**: All build processes use wrapper script

## Workflow

### Standard Build-Time Injection Workflow

```bash
# 1. Prepare version with placeholder
./scripts/version_manager.sh prepare build

# 2. Build with automatic timestamp injection
./scripts/flutter_build_with_timestamp.sh web --release

# 3. Build artifacts contain actual build execution timestamp
```

### Manual Build-Time Injection Workflow

```bash
# 1. Prepare version with placeholder
./scripts/version_manager.sh prepare build

# 2. Manually inject timestamp
./scripts/build_time_version_injector.sh inject

# 3. Execute Flutter build
flutter build web --release

# 4. Restore original version files (optional)
./scripts/build_time_version_injector.sh restore
```

## File Structure

### Version Files Updated During Injection

#### **pubspec.yaml**

```yaml
# Before injection
version: 3.5.5+BUILD_TIME_PLACEHOLDER

# After injection
version: 3.5.5+202506111430
```

#### **assets/version.json**

```json
{
  "version": "3.5.5",
  "build_number": "202506111430",
  "build_date": "2025-06-11T14:30:00Z",
  "git_commit": "abc1234"
}
```

#### **lib/shared/lib/version.dart**

```dart
static const String mainAppVersion = '3.5.5';
static const int mainAppBuildNumber = 202506111430;
static const String buildTimestamp = '2025-06-11T14:30:00Z';
```

#### **lib/shared/pubspec.yaml**

```yaml
version: 3.5.5+202506111430
```

## Commands Reference

### Version Manager Commands

#### **Prepare Version (Build-Time Injection)**

```bash
# Prepare build increment with placeholder
./scripts/version_manager.sh prepare build

# Prepare semantic version increment with placeholder
./scripts/version_manager.sh prepare patch
./scripts/version_manager.sh prepare minor
./scripts/version_manager.sh prepare major
```

#### **Immediate Version (Legacy Mode)**

```bash
# Increment with immediate timestamp
./scripts/version_manager.sh increment build
./scripts/version_manager.sh increment patch
```

### Build-Time Injector Commands

#### **Inject Timestamp**

```bash
# Inject current timestamp into all version files
./scripts/build_time_version_injector.sh inject
```

#### **Restore Version Files**

```bash
# Restore version files from backups
./scripts/build_time_version_injector.sh restore
```

#### **Cleanup Backups**

```bash
# Clean up backup files
./scripts/build_time_version_injector.sh cleanup
```

### Flutter Build Wrapper Commands

#### **Build with Timestamp Injection**

```bash
# Web build with timestamp injection
./scripts/flutter_build_with_timestamp.sh web --release

# Linux build with timestamp injection
./scripts/flutter_build_with_timestamp.sh linux --release

# Verbose build with timestamp injection
./scripts/flutter_build_with_timestamp.sh --verbose web --release

# Dry run (simulation)
./scripts/flutter_build_with_timestamp.sh --dry-run web --release
```

#### **Build Options**

```bash
--verbose           # Enable detailed logging
--dry-run           # Simulate build without execution
--skip-injection    # Skip timestamp injection
--no-restore        # Don't restore version files after build
```

## Integration with Deployment Scripts

### Updated Deployment Scripts

#### **`scripts/deploy/update_and_deploy.sh`**

- Uses `./scripts/flutter_build_with_timestamp.sh` for web builds
- Automatic fallback to direct Flutter build if wrapper not available
- Maintains timeout and error handling

#### **`scripts/build_unified_package.sh`**

- Uses build-time injection for Linux package builds
- Ensures unified packages have accurate build timestamps

#### **`scripts/packaging/build_aur.sh`**

- AUR packages built with build-time timestamp injection
- Maintains compatibility with existing AUR build process

## Testing

### Comprehensive Test Suite

#### **Build-Time Injection Testing**

```bash
# Test build-time injection functionality
./scripts/build_time_version_injector.sh --help
```

**Tests Include:**

- Version preparation with placeholder
- Build-time timestamp injection
- Version file synchronization
- Backup and restore functionality
- Flutter build wrapper (dry run)
- Complete workflow validation

### Manual Testing

#### **Test Version Preparation**

```bash
# Prepare version and verify placeholder
./scripts/version_manager.sh prepare build
./scripts/version_manager.sh get-build  # Should show: BUILD_TIME_PLACEHOLDER
```

#### **Test Timestamp Injection**

```bash
# Inject timestamp and verify format
./scripts/build_time_version_injector.sh inject
./scripts/version_manager.sh get-build  # Should show: YYYYMMDDHHMM format
```

#### **Test Build Wrapper**

```bash
# Test dry run
./scripts/flutter_build_with_timestamp.sh --dry-run web --release
```

## Benefits

### 1. **Accurate Build Tracking**

- Build numbers reflect exact build execution time
- True correlation between timestamp and artifact creation
- Eliminates gap between version preparation and build execution

### 2. **Deployment Correlation**

- Build timestamps correlate with deployment logs
- Easy identification of build-to-deployment timing
- Accurate audit trails for production deployments

### 3. **Development Workflow**

- Clear separation between version preparation and build execution
- Flexible workflow supporting both immediate and build-time timestamps
- Maintains backward compatibility with existing processes

### 4. **Build Artifact Integrity**

- Build artifacts contain timestamps of actual creation
- Consistent timestamps across all version files
- Reliable build identification in production environments

## Migration Guide

### From Immediate to Build-Time Timestamps

#### **Old Workflow**

```powershell
./scripts/powershell/version_manager.ps1 increment build
flutter build web --release
```

#### **New Workflow**

```powershell
./scripts/powershell/version_manager.ps1 prepare build
./scripts/flutter_build_with_timestamp.sh web --release
```

### Deployment Script Updates

All deployment scripts have been automatically updated to use build-time injection. No manual changes required for existing deployment workflows.

### Package Build Updates

AUR, Snap, and Debian package builds automatically use build-time injection when the wrapper script is available, with fallback to direct Flutter builds.

## Troubleshooting

### Common Issues

#### **Placeholder Not Replaced**

```bash
# Check if injection script exists and is executable
ls -la scripts/build_time_version_injector.sh

# Manually inject timestamp
./scripts/build_time_version_injector.sh inject
```

#### **Version File Corruption**

```bash
# Restore from backups
./scripts/build_time_version_injector.sh restore

# Or restore from git
git checkout -- pubspec.yaml assets/version.json lib/shared/lib/version.dart
```

#### **Build Wrapper Not Found**

```bash
# Check if wrapper script exists
ls -la scripts/flutter_build_with_timestamp.sh

# Make executable if needed
chmod +x scripts/flutter_build_with_timestamp.sh
```

### Verification Commands

#### **Check Current System Status**

```bash
# Test build-time injection functionality
./scripts/build_time_version_injector.sh --help

# Check version format
./scripts/version_manager.sh get-build | grep -E '^[0-9]{12}$|^BUILD_TIME_PLACEHOLDER$'
```

## Best Practices

### 1. **Use Preparation Mode for Builds**

Always use `prepare` command for versions that will be built, reserving `increment` for immediate versioning needs.

### 2. **Test Before Deployment**

Run the test suite before important deployments to ensure build-time injection is working correctly.

### 3. **Monitor Build Timestamps**

Use build timestamps to correlate with deployment logs and monitor build performance.

### 4. **Backup Before Major Changes**

The system automatically creates backups, but consider manual backups before major version changes.

The build-time timestamp injection system ensures that CloudToLocalLLM build numbers accurately represent when build artifacts were actually created, providing true build tracking and deployment correlation! 🚀
