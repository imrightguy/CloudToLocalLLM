# Build Troubleshooting Guide

This guide helps you diagnose and fix common issues with CloudToLocalLLM builds using GitHub Actions.

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [Common Build Issues](#common-build-issues)
- [GitHub Actions Specific Issues](#github-actions-specific-issues)
- [Manual Build Triggers](#manual-build-triggers)
- [Cost Information](#cost-information)
- [Getting Help](#getting-help)

## Quick Diagnostics

### Check Build Status

1. Go to your repository on GitHub
2. Click the "Actions" tab
3. Look for "Build Desktop Apps & Create Release" workflow
4. Click on the latest run to see detailed logs

### Common Status Indicators

- ✅ **Green checkmark** - Build succeeded
- ❌ **Red X** - Build failed (see logs for details)
- 🟡 **Yellow circle** - Build in progress
- ⚪ **Gray circle** - Build queued or waiting

## Common Build Issues

### Issue 1: Flutter SDK Installation Failed

**Symptoms:**

- Build fails during "Setup Flutter SDK" step
- Error message: "Failed to download Flutter SDK"

**Solutions:**

1. **Re-run the workflow** (often fixes transient network issues):
   - Go to Actions → Failed workflow → "Re-run all jobs"

2. **Check Flutter version compatibility**:
   - Verify `FLUTTER_VERSION` in `.github/workflows/build-release.yml`
   - Current version: `3.32.8`
   - Update if needed to latest stable version

3. **Clear GitHub Actions cache**:

   ```bash
   # Use GitHub CLI to clear caches
   gh cache list
   gh cache delete <cache-key>
   ```

**Prevention:**

- Pin to stable Flutter versions
- Monitor Flutter release notes for breaking changes

### Issue 2: Dependency Download Failed

**Symptoms:**

- Build fails during "Get Flutter dependencies" step
- Error: "pub get failed" or "Could not resolve dependencies"

**Solutions:**

1. **Check pubspec.yaml syntax**:

   ```bash
   # Validate locally
   flutter pub get
   ```

2. **Update dependency versions**:
   - Check for deprecated packages
   - Update version constraints in `pubspec.yaml`

3. **Clear pub cache** (in workflow):
   - Delete cache from Actions → Caches
   - Re-run workflow to rebuild cache

**Prevention:**

- Test `flutter pub get` locally before pushing
- Use version ranges instead of exact versions
- Keep dependencies up to date

### Issue 3: Flutter Build Compilation Errors

**Symptoms:**

- Build fails during "Build Windows desktop application" step
- Compilation errors in Dart/Flutter code

**Solutions:**

1. **Test build locally first**:

   ```bash
   flutter build windows --release
   ```

2. **Check for platform-specific issues**:
   - Verify Windows-specific code compiles
   - Check conditional imports are correct

3. **Review error logs**:
   - Click on failed step in GitHub Actions
   - Look for specific file/line causing error
   - Fix code and push changes

**Prevention:**

- Always test builds locally before pushing
- Run `flutter analyze` to catch issues early
- Use `flutter doctor` to verify environment

### Issue 4: Inno Setup Installation or Compilation Failed

**Symptoms:**

- Build fails during "Install Inno Setup" or "Create Windows installer" step
- Error: "Inno Setup not found" or "ISCC.exe failed"

**Solutions:**

1. **Verify Inno Setup script exists**:
   - Check `build-tools/installers/windows/CloudToLocalLLM_Simple.iss` exists
   - Validate script syntax locally with Inno Setup

2. **Check installation paths**:
   - Workflow tries multiple installation methods (Chocolatey, Winget)
   - Review logs to see which method was attempted

3. **Validate script parameters**:
   - Ensure version format is correct
   - Check file paths in .iss script are valid

**Prevention:**

- Test Inno Setup script locally before pushing
- Keep .iss script in version control
- Document any custom Inno Setup requirements

### Issue 5: Version Extraction Failed

**Symptoms:**

- Build fails during "Extract version and generate build number" step
- Error: "Version not found" or "Invalid version format"

**Solutions:**

1. **Check pubspec.yaml format**:

   ```yaml
   version: 4.5.0+20241115
   ```

2. **Verify tag format** (for tag-triggered builds):

   ```bash
   # Correct format
   git tag v4.5.0
   
   # Incorrect formats
   git tag 4.5.0      # Missing 'v' prefix
   git tag version4.5.0  # Wrong prefix
   ```

3. **Check git history**:
   - Ensure repository has commits
   - Verify tags are pushed to remote

**Prevention:**

- Use semantic versioning (MAJOR.MINOR.PATCH)
- Always prefix tags with 'v'
- Test version extraction locally

### Issue 6: Release Creation Failed

**Symptoms:**

- Build succeeds but release creation fails
- Error: "Tag already exists" or "Permission denied"

**Solutions:**

1. **Check if tag already exists**:

   ```bash
   # List existing tags
   git tag -l
   
   # Delete tag if needed
   git tag -d v4.5.0
   git push --delete origin v4.5.0
   ```

2. **Verify GitHub token permissions**:
   - Workflow uses `GITHUB_TOKEN` automatically
   - Check repository settings → Actions → General
   - Ensure "Read and write permissions" is enabled

3. **Check artifact availability**:
   - Verify build artifacts were uploaded successfully
   - Check artifact retention hasn't expired (30 days default)

**Prevention:**

- Don't reuse version tags
- Increment version for each release
- Verify permissions before running workflow

## GitHub Actions Specific Issues

### Workflow Not Triggering

**Symptoms:**

- Push tag but workflow doesn't start
- Manual trigger button not visible

**Solutions:**

1. **Verify workflow file location**:
   - Must be in `.github/workflows/` directory
   - File must have `.yml` or `.yaml` extension

2. **Check workflow syntax**:

   ```bash
   # Validate workflow locally (requires act or similar)
   # Or push and check Actions tab for syntax errors
   ```

3. **Verify trigger conditions**:

   ```yaml
   on:
     push:
       tags:
         - 'v*'  # Only triggers on tags starting with 'v'
   ```

4. **Check repository settings**:
   - Settings → Actions → General
   - Ensure "Allow all actions" is selected

**Prevention:**

- Test workflow syntax before committing
- Review GitHub Actions documentation
- Check workflow permissions

### Cache Issues

**Symptoms:**

- Builds are slow despite caching
- Cache restore fails
- Stale dependencies causing issues

**Solutions:**

1. **Clear specific cache**:

   ```bash
   # List all caches
   gh cache list
   
   # Delete specific cache
   gh cache delete <cache-key>
   ```

2. **Clear all caches**:
   - Go to Actions → Caches
   - Delete all caches manually
   - Next build will recreate fresh caches

3. **Update cache keys**:
   - Modify cache key in workflow if needed
   - Change `hashFiles()` pattern to force new cache

**Cache Locations:**

- Flutter pub cache: `~/.pub-cache`, `.dart_tool`
- Chocolatey packages: `C:\ProgramData\chocolatey`
- Flutter SDK: `${{ runner.tool_cache }}/flutter`

**Prevention:**

- Monitor cache hit rates in logs
- Periodically clear old caches
- Use appropriate cache keys

### Runner Out of Disk Space

**Symptoms:**

- Build fails with "No space left on device"
- Artifact upload fails

**Solutions:**

1. **Clean up build artifacts**:
   - Add cleanup steps in workflow
   - Remove unnecessary files before artifact upload

2. **Optimize build output**:
   - Only include necessary files in artifacts
   - Compress large files before upload

3. **Use larger runner** (if needed):

   ```yaml
   runs-on: windows-latest  # Standard runner (14GB disk)
   # For larger builds, consider self-hosted runners
   ```

**Prevention:**

- Monitor disk usage in workflow logs
- Clean up intermediate build files
- Optimize artifact sizes

## Manual Build Triggers

### Triggering a Build Manually

**Via GitHub Web Interface:**

1. Go to your repository on GitHub
2. Click "Actions" tab
3. Select "Build Desktop Apps & Create Release" workflow
4. Click "Run workflow" button (top right)
5. Select branch (usually `main`)
6. Choose build type: `release`
7. Click "Run workflow"

**Via GitHub CLI:**

```bash
# Trigger workflow manually
gh workflow run build-release.yml

# Trigger with specific inputs
gh workflow run build-release.yml \
  --ref main \
  -f build_type=release

# Check workflow status
gh run list --workflow=build-release.yml

# View workflow logs
gh run view <run-id> --log
```

**Via Git Tag (Recommended):**

```bash
# Create and push tag to trigger automatic build
git tag v4.5.0
git push origin v4.5.0

# Or create annotated tag with message
git tag -a v4.5.0 -m "Release version 4.5.0"
git push origin v4.5.0
```

### Canceling a Running Build

**Via GitHub Web Interface:**

1. Go to Actions tab
2. Click on the running workflow
3. Click "Cancel workflow" button (top right)

**Via GitHub CLI:**

```bash
# List running workflows
gh run list --workflow=build-release.yml --status in_progress

# Cancel specific run
gh run cancel <run-id>

# Cancel all running workflows
gh run list --workflow=build-release.yml --status in_progress \
  --json databaseId --jq '.[].databaseId' | xargs -I {} gh run cancel {}
```

## Expected Build Times

Understanding typical build times helps identify performance issues:

### Platform Build Times

| Platform | First Build | Cached Build | Notes |
|----------|-------------|--------------|-------|
| **Windows** | 15-20 min | 8-12 min | Includes Inno Setup installation |
| **Linux** | 12-18 min | 6-10 min | Flatpak + .deb packaging |
| **Android** | 10-15 min | 5-8 min | 3 APKs with --split-per-abi |

### Total Workflow Time

Since all platforms build in parallel:

- **First build**: ~20-25 minutes (slowest platform + overhead)
- **Cached build**: ~12-15 minutes (with >80% cache hit rate)
- **Release creation**: +2-3 minutes (artifact collection and upload)

### Build Time Breakdown

**Windows Build**:

- Flutter SDK setup: 2-3 min (cached: <30 sec)
- Inno Setup installation: 1-2 min (cached: <10 sec)
- Flutter pub get: 1-2 min (cached: <30 sec)
- Windows build: 5-8 min
- Installer creation: 2-3 min
- Artifact upload: 1-2 min

**Linux Build**:

- Flutter SDK setup: 2-3 min (cached: <30 sec)
- Linux dependencies: 2-3 min (cached: <30 sec)
- Flutter pub get: 1-2 min (cached: <30 sec)
- Linux build: 3-5 min
- Flatpak packaging: 2-4 min
- .deb packaging: 1-2 min
- Artifact upload: 1-2 min

**Android Build**:

- Flutter SDK setup: 2-3 min (cached: <30 sec)
- Java/Android SDK: 2-3 min (cached: <30 sec)
- Gradle dependencies: 2-3 min (cached: <30 sec)
- APK builds (3x): 3-5 min
- Signing and verification: 1-2 min
- Artifact upload: 1-2 min

### Performance Optimization Tips

1. **Use caching effectively**:
   - Cache hit rate should be >80%
   - Clear old caches if builds are slow

2. **Monitor cache sizes**:
   - Flutter SDK: ~500MB
   - Pub dependencies: ~200-300MB
   - Gradle cache: ~300-500MB
   - Total: ~1-1.5GB per platform

3. **Parallel execution**:
   - All platforms build simultaneously
   - Total time ≈ slowest platform
   - No sequential bottlenecks

4. **Identify slow steps**:
   - Check workflow logs for step durations
   - Look for steps taking >5 minutes
   - Consider optimizing or caching

### When to Worry

Build times significantly longer than expected may indicate:

- **Cache miss**: Check cache keys and restore logs
- **Network issues**: Slow dependency downloads
- **Resource contention**: GitHub Actions capacity issues
- **Code changes**: Large refactors may increase build time

## Cost Information

### GitHub-Hosted Runners (Current Setup)

**Public Repositories:**

- ✅ **Completely FREE** - Unlimited minutes
- ✅ No credit card required
- ✅ No usage limits for public repos

**Private Repositories:**

- Free tier: 2,000 minutes/month
- Windows runners: 2x multiplier (1 minute = 2 minutes)
- Estimated cost per build: ~30-40 minutes = 60-80 billable minutes

**Cost Comparison:**

| Solution | Monthly Cost | Setup Time | Maintenance |
|----------|-------------|------------|-------------|
| GitHub-hosted (public) | **$0** | 0 minutes | None |
| GitHub-hosted (private) | ~$0-8/month | 0 minutes | None |
| Self-hosted runner | $0-50+/month | 2-4 hours | Ongoing |
| Cloud VM (Azure/AWS) | $50-200/month | 4-8 hours | Ongoing |

**Savings with GitHub-Hosted Runners:**

- No infrastructure costs
- No maintenance overhead
- No setup time required
- Automatic updates and security patches
- Scalable (parallel builds)

**For Private Repositories:**

If you exceed free tier, consider:

1. Optimize build time (caching, parallel jobs)
2. Use self-hosted runner for frequent builds
3. Upgrade to GitHub Team/Enterprise plan

## Android Build Issues

### Issue: Android Build Not Running

**Symptoms:**

- Android build job doesn't appear in workflow
- Only Windows/Linux builds are running

**Solutions:**

1. **Verify Android build is enabled**:
   - Check `.github/workflows/build-release.yml`
   - Ensure Android matrix entry is uncommented
   - See  for setup

2. **Check GitHub Secrets**:
   - Verify all Android signing secrets are configured
   - Required: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, `ANDROID_KEY_ALIAS`

### Issue: Android Signing Failed

**Symptoms:**

- Build fails during "Setup Android signing configuration" step
- Error: "Keystore not found" or "Invalid keystore format"

**Solutions:**

1. **Verify keystore secret**:

   ```bash
   # Re-encode keystore to base64
   base64 release-keystore.jks > release-keystore.base64.txt
   
   # Update ANDROID_KEYSTORE_BASE64 secret with content
   ```

2. **Check secret names**:
   - Ensure secret names match exactly (case-sensitive)
   - Verify no extra spaces in secret values

3. **Test keystore locally**:

   ```bash
   # Verify keystore is valid
   keytool -list -v -keystore release-keystore.jks
   ```

### Issue: APK Build Failed

**Symptoms:**

- Build fails during "Build Android APK" step
- Gradle compilation errors

**Solutions:**

1. **Check Android SDK version**:
   - Verify `compileSdkVersion` in `android/app/build.gradle`
   - Ensure it matches workflow SDK version (33)

2. **Clear Gradle cache**:
   - Re-run workflow (cache will be cleared automatically)
   - Or manually clear cache in Actions settings

3. **Test build locally**:

   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

### Issue: APK Signature Verification Failed

**Symptoms:**

- APK builds but signature verification fails
- Error: "APK signature verification failed"

**Solutions:**

1. **Verify signing configuration**:
   - Check `android/app/build.gradle` has correct signing config
   - Ensure keystore passwords are correct

2. **Check key alias**:
   - Verify `ANDROID_KEY_ALIAS` matches keystore alias
   - List aliases: `keytool -list -keystore release-keystore.jks`

3. **Regenerate keystore** if corrupted:
   - Create new keystore (see )
   - Update GitHub Secrets with new values

### Issue: APK Won't Install on Device

**Symptoms:**

- APK downloads but won't install
- Error: "App not installed" or "Parse error"

**Solutions:**

1. **Check minimum SDK version**:
   - Device must be Android 5.0+ (API 21+)
   - Verify `minSdkVersion` in `android/app/build.gradle`

2. **Enable unknown sources**:
   - Settings → Security → Enable "Install from Unknown Sources"
   - Or Settings → Apps → Special access → Install unknown apps

3. **Check device architecture**:
   - Download the correct APK for your device:
     - **arm64-v8a**: Most modern devices (2015+)
     - **armeabi-v7a**: Older devices
     - **x86_64**: Emulators and some tablets
   - Check device architecture: `adb shell getprop ro.product.cpu.abi`

4. **Verify APK integrity**:

   ```bash
   # Check SHA256 checksum
   sha256sum -c CloudToLocalLLM-*-arm64-v8a.apk.sha256
   ```

5. **Check available storage**:
   - Ensure device has sufficient free space (>100MB)
   - Clear cache if needed

6. **Uninstall previous version**:

   ```bash
   # If upgrading, uninstall old version first
   adb uninstall com.CloudToLocalLLM.CloudToLocalLLM
   ```

### Issue: APK Installs but Crashes on Launch

**Symptoms:**

- APK installs successfully
- App crashes immediately when opened
- Error in logcat

**Solutions:**

1. **Check logcat for errors**:

   ```bash
   # View crash logs
   adb logcat | grep -E "AndroidRuntime|CloudToLocalLLM"
   ```

2. **Verify permissions**:
   - Check `AndroidManifest.xml` has required permissions
   - Grant permissions manually in Settings → Apps

3. **Check Android version compatibility**:
   - Minimum: Android 5.0 (API 21)
   - Target: Android 13 (API 33)
   - Some features may not work on older versions

4. **Clear app data**:

   ```bash
   # Clear app data and cache
   adb shell pm clear com.CloudToLocalLLM.CloudToLocalLLM
   ```

### Issue: Gradle Build Timeout

**Symptoms:**

- Android build times out during Gradle build
- Error: "Gradle build exceeded timeout"

**Solutions:**

1. **Check Gradle cache**:
   - Cache may be corrupted
   - Clear cache in Actions → Caches
   - Re-run workflow

2. **Increase timeout** (if needed):

   ```yaml
   # In workflow file
   - name: Build Android APK
     timeout-minutes: 30  # Increase if needed
   ```

3. **Check network connectivity**:
   - Gradle may be downloading dependencies
   - Verify GitHub Actions has internet access

### Issue: Multiple APKs Not Created

**Symptoms:**

- Only one APK created instead of three
- Missing architecture-specific APKs

**Solutions:**

1. **Verify build command**:

   ```bash
   # Correct command with --split-per-abi
   flutter build apk --release --split-per-abi
   ```

2. **Check build output**:
   - Look in `build/app/outputs/flutter-apk/`
   - Should see: `app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, `app-x86_64-release.apk`

3. **Check Flutter version**:
   - Ensure Flutter 3.24.0+ (supports --split-per-abi)
   - Update Flutter if needed

### Android Build Resources

For detailed Android build setup and configuration:

- Complete setup guide with secret configuration
- [android/README.md](../android/README.md) - Local build instructions
- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)

## Getting Help

### Viewing Detailed Logs

1. **Navigate to workflow run**:
   - Actions → Build Desktop Apps & Create Release → Click on run

2. **Expand job steps**:
   - Click on job name (e.g., "Build Windows Desktop App")
   - Click on individual steps to see detailed logs

3. **Download logs**:
   - Click "..." menu (top right of job)
   - Select "Download log archive"
   - Extract and review locally

### Debug Mode

Enable debug logging for more detailed output:

1. Go to repository Settings → Secrets and variables → Actions
2. Add repository secret:
   - Name: `ACTIONS_STEP_DEBUG`
   - Value: `true`
3. Re-run workflow to see debug logs

### Common Log Locations

- **Flutter version**: Look for "Setup Flutter SDK" step
- **Dependency issues**: Check "Get Flutter dependencies" step
- **Build errors**: Review "Build Windows desktop application" step
- **Installer issues**: Check "Create Windows installer" step
- **Release errors**: Review "Create GitHub Release" step

### Reporting Issues

When reporting build issues, include:

1. **Workflow run URL**: Link to failed GitHub Actions run
2. **Error message**: Copy exact error from logs
3. **Environment**: OS, Flutter version, workflow file version
4. **Steps to reproduce**: What triggered the build
5. **Expected vs actual**: What should happen vs what happened

**Where to report:**

- GitHub Issues: https://github.com/CloudToLocalLLM-online/CloudToLocalLLM/issues
- Include label: `ci/cd` or `build`

### Additional Resources

- **GitHub Actions Documentation**: https://docs.github.com/en/actions
- **Flutter Build Documentation**: https://docs.flutter.dev/deployment/windows
- **Inno Setup Documentation**: https://jrsoftware.org/ishelp/
- **Workflow File**: `.github/workflows/build-release.yml`
- **CI/CD Setup Guide**: `docs/CICD_SETUP_GUIDE.md`

### Quick Reference Commands

```bash
# Check workflow status
gh workflow view build-release.yml

# List recent runs
gh run list --workflow=build-release.yml --limit 5

# View specific run
gh run view <run-id>

# Download artifacts
gh run download <run-id>

# Re-run failed jobs
gh run rerun <run-id> --failed

# List caches
gh cache list

# Delete cache
gh cache delete <cache-key>
```

---

**Last Updated**: 2024-11-15  
**Workflow Version**: build-release.yml (GitHub-hosted runners)
