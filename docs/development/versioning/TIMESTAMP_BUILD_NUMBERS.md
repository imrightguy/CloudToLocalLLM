# CloudToLocalLLM Timestamp-Based Build Numbers v3.5.5+

## Overview

CloudToLocalLLM uses timestamp-based build numbers in YYYYMMDDHHMM format to represent the actual build creation time. This ensures that build numbers are unique, chronologically ordered, and meaningful for tracking deployment history.

## Build Number Format

### YYYYMMDDHHMM Structure

- **YYYY**: 4-digit year (e.g., 2025)
- **MM**: 2-digit month (01-12)
- **DD**: 2-digit day (01-31)
- **HH**: 2-digit hour in 24-hour format (00-23)
- **MM**: 2-digit minute (00-59)

### Examples

- `202506092204` = June 9, 2025 at 22:04 (10:04 PM)
- `202512251430` = December 25, 2025 at 14:30 (2:30 PM)
- `202601010000` = January 1, 2026 at 00:00 (midnight)

## Version String Format

The complete version string follows the pattern: `MAJOR.MINOR.PATCH+YYYYMMDDHHMM`

### Examples

- `3.5.5+202506092204` - Version 3.5.5 built on June 9, 2025 at 22:04
- `4.0.0+202512251430` - Version 4.0.0 built on December 25, 2025 at 14:30

## Implementation

### Core Functions

#### `generate_build_number()`

```bash
# Generate new build number based on current timestamp
generate_build_number() {
    date +"%Y%m%d%H%M"
}
```

#### `increment_build_number()`

```bash
# Always generates new timestamp for CloudToLocalLLM v3.5.5+
increment_build_number() {
    generate_build_number
}
```

### Version Synchronization Points

The timestamp-based build number is synchronized across:

1. **pubspec.yaml** - Main version source

   ```yaml
   version: 3.5.5+202506092204
   ```

2. **assets/version.json** - Runtime version information

   ```json
   {
     "version": "3.5.5",
     "build_number": "202506092204",
     "build_date": "2025-06-09T22:04:00Z",
     "git_commit": "abc1234"
   }
   ```

3. **lib/shared/lib/version.dart** - Dart constants

   ```dart
   static const String mainAppVersion = '3.5.5';
   static const int mainAppBuildNumber = 202506092204;
   static const String buildTimestamp = '2025-06-09T22:04:00Z';
   ```

4. **lib/shared/pubspec.yaml** - Shared library version

   ```yaml
   version: 3.5.5+202506092204
   ```

5. **lib/config/app_config.dart** - Application configuration

   ```dart
   static const String appVersion = '3.5.5';
   ```

## Usage

### Version Manager Commands

#### Increment Build Number

```powershell
# Generates new timestamp-based build number (Windows PowerShell)
./scripts/powershell/version_manager.ps1 increment build
```

#### Increment Semantic Version

```powershell
# Generates new semantic version with timestamp build number (Windows PowerShell)
./scripts/powershell/version_manager.ps1 increment patch
./scripts/powershell/version_manager.ps1 increment minor
./scripts/powershell/version_manager.ps1 increment major
```

#### Set Specific Version

```powershell
# Sets version with new timestamp build number (Windows PowerShell)
./scripts/powershell/version_manager.ps1 set 3.6.0
```

#### Get Version Information

```powershell
# Display current version information (Windows PowerShell)
./scripts/powershell/version_manager.ps1 info

# Get full version string (Windows PowerShell)
./scripts/powershell/version_manager.ps1 get

# Get semantic version only (Windows PowerShell)
./scripts/powershell/version_manager.ps1 get-semantic

# Get build number only (Windows PowerShell)
./scripts/powershell/version_manager.ps1 get-build
```

### Synchronization Commands

#### Automatic Synchronization

```powershell
# PowerShell version manager automatically synchronizes all files
./scripts/powershell/version_manager.ps1 info
```

#### Manual Verification

```powershell
# Test timestamp versioning system (Windows PowerShell)
./scripts/powershell/version_manager.ps1 get-build
```

## Benefits

### 1. Chronological Ordering

Build numbers naturally sort chronologically, making it easy to identify newer builds:

- `202506091200` (older)
- `202506091430` (newer)

### 2. Meaningful Timestamps

Build numbers immediately convey when the build was created, useful for:

- Debugging deployment issues
- Tracking release schedules
- Correlating builds with events

### 3. Uniqueness Guarantee

Timestamp-based build numbers are virtually guaranteed to be unique, preventing conflicts.

### 4. Deployment Tracking

Easy to correlate builds with deployment logs and monitoring data.

## Deployment Integration

### Automated Deployment Workflow

The timestamp-based build numbers integrate seamlessly with the six-phase deployment workflow:

1. **Version Management**: New timestamp generated during version increment
2. **Build Process**: Build number reflects actual build creation time
3. **Distribution**: Timestamp preserved across all distribution channels
4. **Verification**: Build time can be verified against deployment logs

### AUR Package Integration

AUR packages use the semantic version (without build number) for package versioning:

- Package version: `3.5.5`
- Internal build tracking: `3.5.5+202506092204`

## Testing

### Automated Tests

```bash
# Run comprehensive timestamp versioning tests
./scripts/version_manager.sh info
```

### Manual Verification

```bash
# Check current build number format
./scripts/version_manager.sh get-build | grep -E '^[0-9]{12}$'

# Verify version synchronization
./scripts/deploy/sync_versions.sh
```

## Migration Notes

### From Incremental Build Numbers

Previous versions used incremental build numbers (001, 002, etc.). The new system:

- Always generates timestamp-based build numbers
- Maintains backward compatibility in version string format
- Provides more meaningful build identification

### Deployment Considerations

- Build numbers are now 12 digits instead of 3
- Build numbers reflect actual build time, not sequential order
- All deployment scripts updated to handle timestamp format

## Best Practices

### 1. Always Use Version Manager

Use `./scripts/version_manager.sh` for all version operations to ensure consistency.

### 2. Synchronize Before Deployment

Run `./scripts/deploy/sync_versions.sh` before any deployment to ensure all files are synchronized.

### 3. Test Versioning System

Regularly run `./scripts/version_manager.sh info` to verify system integrity.

### 4. Monitor Build Times

Use build numbers to track build performance and deployment schedules.

## Troubleshooting

### Build Number Format Issues

If build numbers don't match YYYYMMDDHHMM format:

1. Check system date/time settings
2. Verify `date` command availability
3. Run version synchronization script

### Version Mismatch Errors

If version files are out of sync:

1. Run `./scripts/deploy/sync_versions.sh`
2. Verify all backup files are restored
3. Check for manual edits to version files

### Deployment Failures

If deployment fails due to version issues:

1. Verify timestamp format with test script
2. Check all version synchronization points
3. Ensure build number reflects actual build time

This timestamp-based versioning system provides CloudToLocalLLM with robust, meaningful, and chronologically ordered build identification that integrates seamlessly with the automated deployment workflow.
