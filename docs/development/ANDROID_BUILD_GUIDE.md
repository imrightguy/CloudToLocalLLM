# Android Build Guide

This guide explains the Android build system for CloudToLocalLLM, which creates multi-architecture APKs.

## Overview

Android builds are **ENABLED** and fully integrated into the CI/CD pipeline. The build system:

- Creates separate APKs for ARM64, ARMv7, and x86_64 architectures
- Uses GitHub-hosted runners (ubuntu-latest) - FREE for public repositories
- Automatically signs APKs with release keystore
- Runs in parallel with Windows and Linux builds

## Build Artifacts

Android builds produce three APK files optimized for different architectures:

1. **arm64-v8a** (`CloudToLocalLLM-{version}-arm64-v8a.apk`)
   - 64-bit ARM architecture
   - For most modern Android devices (2015+)
   - Recommended for most users

2. **armeabi-v7a** (`CloudToLocalLLM-{version}-armeabi-v7a.apk`)
   - 32-bit ARM architecture
   - For older Android devices
   - Wider compatibility

3. **x86_64** (`CloudToLocalLLM-{version}-x86_64.apk`)
   - 64-bit x86 architecture
   - For Android emulators and some tablets
   - Testing and development

Each APK is ~30-40% smaller than a universal APK, providing faster downloads and optimal performance.

## Prerequisites

The Android build system requires:

1. **Android Keystore**: Release keystore for signing APKs (✓ Configured)
2. **GitHub Secrets**: Signing credentials in repository secrets (✓ Configured)
3. **Android Configuration**: Project configuration in `android/` directory (✓ Ready)

## Step 1: Create Android Release Keystore

### Generate Keystore

```bash
# Generate a new keystore (run this locally, not in CI)
keytool -genkey -v -keystore release-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias CloudToLocalLLM-release

# You will be prompted for:
# - Keystore password (save this securely!)
# - Key password (save this securely!)
# - Your name, organization, etc.
```

### Important Notes

- **DO NOT commit the keystore to the repository**
- Store the keystore file securely (password manager, secure vault)
- Keep backup copies of the keystore in multiple secure locations
- If you lose the keystore, you cannot update your app on Google Play Store

### Convert Keystore to Base64

```bash
# Convert keystore to base64 for GitHub Secrets
base64 release-keystore.jks > release-keystore.base64.txt

# On Windows (PowerShell):
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release-keystore.jks")) | Out-File release-keystore.base64.txt
```

## Step 2: Configure GitHub Secrets

**✓ COMPLETED** - Android signing secrets have been configured in the GitHub repository.

The following secrets are now available for CI/CD builds:

| Secret Name | Description | Status |
|-------------|-------------|--------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded keystore file | ✓ Configured |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password | ✓ Configured |
| `ANDROID_KEY_PASSWORD` | Key password | ✓ Configured |
| `ANDROID_KEY_ALIAS` | Key alias (`CloudToLocalLLM-release`) | ✓ Configured |

### Automated Setup Scripts

Two PowerShell scripts are provided for managing Android signing:

#### Setup Script (`scripts/setup-android-signing.ps1`)

Generates keystore and configures GitHub Secrets automatically:

```powershell
# Run the setup script
.\scripts\setup-android-signing.ps1

# What it does:
# 1. Checks if keystore already exists
# 2. Generates new keystore with strong passwords (if needed)
# 3. Converts keystore to base64 for GitHub Secrets
# 4. Configures all required GitHub Secrets via GitHub CLI
# 5. Saves backup information to android/keystore-backup-info.txt
```

**Requirements**:

- GitHub CLI (`gh`) installed and authenticated
- Java keytool (included with JDK)
- PowerShell 5.1 or later

#### Verification Script (`scripts/verify-android-secrets.ps1`)

Verifies that all Android signing secrets are configured correctly:

```powershell
# Run the verification script
.\scripts\verify-android-secrets.ps1

# What it checks:
# 1. All required secrets exist in GitHub repository
# 2. Keystore file exists locally
# 3. Keystore is valid and accessible
# 4. Key alias matches configured secret
# 5. Passwords work with the keystore
```

**Output**:

- ✓ Green checkmarks for configured secrets
- ✗ Red X for missing or invalid secrets
- Detailed error messages for troubleshooting

### Manual Secret Configuration

If you prefer to configure secrets manually:

1. **Generate keystore** (if not already created):

   ```bash
   keytool -genkey -v -keystore android/release-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias CloudToLocalLLM-release
   ```

2. **Convert to base64**:

   ```powershell
   # Windows PowerShell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes("android/release-keystore.jks")) | Out-File android/release-keystore.base64.txt
   
   # Linux/macOS
   base64 android/release-keystore.jks > android/release-keystore.base64.txt
   ```

3. **Add secrets to GitHub**:

   ```bash
   # Using GitHub CLI
   gh secret set ANDROID_KEYSTORE_BASE64 < android/release-keystore.base64.txt
   gh secret set ANDROID_KEYSTORE_PASSWORD
   gh secret set ANDROID_KEY_PASSWORD
   gh secret set ANDROID_KEY_ALIAS -b "CloudToLocalLLM-release"
   ```

### Security Best Practices

- ✓ Keystore file is excluded from version control (.gitignore)
- ✓ Strong, unique passwords generated automatically
- ✓ Secrets stored securely in GitHub Secrets (encrypted at rest)
- ✓ Backup information saved in `android/keystore-backup-info.txt`
- ✓ Secrets only accessible during workflow execution
- Rotate secrets periodically for enhanced security
- Use GitHub's secret scanning to detect accidental exposure
- Never commit keystore or passwords to repository

## Step 3: Verify Android Project Configuration

### Check android/app/build.gradle

Ensure your `android/app/build.gradle` has signing configuration:

```gradle
android {
    // ... other configuration

    signingConfigs {
        release {
            // This will be populated from key.properties file
            if (project.hasProperty('android.injected.signing.store.file')) {
                storeFile file(project.property('android.injected.signing.store.file'))
                storePassword project.property('android.injected.signing.store.password')
                keyAlias project.property('android.injected.signing.key.alias')
                keyPassword project.property('android.injected.signing.key.password')
            } else {
                // Fallback to key.properties file
                def keystorePropertiesFile = rootProject.file("key.properties")
                if (keystorePropertiesFile.exists()) {
                    def keystoreProperties = new Properties()
                    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
                    
                    storeFile file(keystoreProperties['storeFile'])
                    storePassword keystoreProperties['storePassword']
                    keyAlias keystoreProperties['keyAlias']
                    keyPassword keystoreProperties['keyPassword']
                }
            }
        }
    }

    buildTypes {
        release {
            signingConfig signingConfigs.release
            // ... other release configuration
        }
    }
}
```

### Check android/app/src/main/AndroidManifest.xml

Verify minimum SDK version and permissions:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-sdk android:minSdkVersion="21" android:targetSdkVersion="33" />
    
    <!-- Add required permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    
    <!-- ... rest of manifest -->
</manifest>
```

### Update pubspec.yaml

Ensure Flutter version constraints are compatible with Android:

```yaml
environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: '>=3.24.0'

# Verify Android-compatible dependencies
dependencies:
  flutter:
    sdk: flutter
  # ... other dependencies
```

## Build Configuration

The Android build is configured in `.github/workflows/build-release.yml` with the following matrix entry:

```yaml
- platform: android
  os: ubuntu-latest
  build-command: flutter build apk --release --split-per-abi
  artifact-name: android-apk
```

### Build Steps

The Android build process includes the following automated steps:

1. **Setup Java 17** - Installs Zulu OpenJDK 17 (required for Android builds)
2. **Setup Android SDK** - Installs Android SDK API 33 and build tools
3. **Setup Android NDK** - Installs NDK version 25.1.8937393
4. **Cache Gradle Dependencies** - Caches Gradle wrapper and dependencies
5. **Configure Signing** - Decodes keystore from base64 and creates key.properties
6. **Verify Dependencies** - Checks Java, Android SDK, and Flutter are ready
7. **Build APKs** - Compiles app with `--split-per-abi` flag for optimized APKs
8. **Verify APKs** - Checks all three architecture APKs were created
9. **Generate Checksums** - Creates SHA256 checksums for each APK
10. **Upload Artifacts** - Uploads APKs and checksums to GitHub release

All steps are fully automated and require no manual intervention.

## Step 5: Test Android Build Locally

Before enabling in CI/CD, test the build locally:

```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build Android APK
flutter build apk --release

# Verify APK was created
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Test APK on device or emulator
flutter install
```

### Troubleshooting Local Build

**Issue: Gradle build fails**

```bash
# Clear Gradle cache
cd android
./gradlew clean
cd ..

# Rebuild
flutter build apk --release
```

**Issue: Signing configuration not found**

```bash
# Verify key.properties exists
ls -la android/key.properties

# Check signing configuration in build.gradle
cat android/app/build.gradle | grep -A 10 "signingConfigs"
```

**Issue: SDK licenses not accepted**

```bash
# Accept all SDK licenses
flutter doctor --android-licenses
```

## Testing Android Builds

### Triggering a Build

Android builds are triggered automatically when you push a version tag:

```bash
# Create and push a version tag
git tag v4.5.0
git push origin v4.5.0
```

Or manually trigger via GitHub Actions:

- Go to: `Actions` → `Build Desktop Apps & Create Release` → `Run workflow`
- Select branch: `main`
- Click `Run workflow`

### Monitoring the Build

1. **Go to Actions tab** in GitHub repository
2. **Click on the workflow run** to see progress
3. **Expand the Android build job** to see detailed logs
4. **Wait for completion** (~10-15 minutes for first build, ~5-8 minutes with cache)

### Verifying Build Output

After successful build:

1. **Download APKs** from GitHub release or Actions artifacts
2. **Verify APK signatures**:

   ```bash
   # Using apksigner (part of Android SDK build-tools)
   $ANDROID_HOME/build-tools/33.0.2/apksigner verify --verbose CloudToLocalLLM-*-arm64-v8a.apk
   ```

3. **Test on Android device**:

   ```bash
   # Install via ADB
   adb install CloudToLocalLLM-*-arm64-v8a.apk
   
   # Launch app
   adb shell am start -n com.CloudToLocalLLM.CloudToLocalLLM/.MainActivity
   
   # Check logs
   adb logcat | grep CloudToLocalLLM
   ```

4. **Verify checksums**:

   ```bash
   # Verify SHA256 checksum for each APK
   sha256sum -c CloudToLocalLLM-*-arm64-v8a.apk.sha256
   sha256sum -c CloudToLocalLLM-*-armeabi-v7a.apk.sha256
   sha256sum -c CloudToLocalLLM-*-x86_64.apk.sha256
   ```

### Testing on Different Architectures

Test each APK on appropriate devices:

- **arm64-v8a**: Modern smartphones (Samsung Galaxy S10+, Pixel 4+, OnePlus 7+)
- **armeabi-v7a**: Older devices (Samsung Galaxy S6, Nexus 5, Moto G4)
- **x86_64**: Android emulators, some tablets (Chromebooks)

## Build Configuration Details

### Target Architectures

The Android build targets three architectures:

- `arm64-v8a` - 64-bit ARM (most modern devices)
- `armeabi-v7a` - 32-bit ARM (older devices)
- `x86_64` - 64-bit x86 (emulators, some tablets)

### Build Command

```bash
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

This creates a single "fat APK" that works on all architectures.

### Alternative: App Bundle

For Google Play Store distribution, consider using App Bundle instead:

```bash
flutter build appbundle --release
```

App Bundles are smaller and optimized per-device by Google Play.

## Maintenance

### Updating Android SDK

To update Android SDK version:

1. Update in workflow file:

   ```yaml
   - name: 🤖 Setup Android SDK
     uses: android-actions/setup-android@v3
     with:
       api-level: 34  # Update this
       build-tools: 34.0.0  # Update this
   ```

2. Update in `android/app/build.gradle`:

   ```gradle
   android {
       compileSdkVersion 34  // Update this
       targetSdkVersion 34   // Update this
   }
   ```

### Updating Java Version

To update Java version:

```yaml
- name: ☕ Setup Java for Android
  uses: actions/setup-java@v4
  with:
    distribution: 'zulu'
    java-version: '21'  # Update this
```

### Rotating Keystore

If you need to rotate the keystore:

1. Generate new keystore (see Step 1)
2. Update GitHub Secrets with new values
3. Keep old keystore for existing app updates
4. Use new keystore for new apps or major versions

## Troubleshooting

### Build Fails: "Keystore not found"

**Cause**: GitHub Secret not configured or base64 decoding failed

**Solution**:

1. Verify `ANDROID_KEYSTORE_BASE64` secret exists
2. Re-encode keystore to base64
3. Update secret with new value

### Build Fails: "Signing configuration not found"

**Cause**: `key.properties` file not created or invalid

**Solution**:

1. Check the "Setup Android signing configuration" step logs
2. Verify all signing secrets are set
3. Ensure secret names match exactly

### Build Fails: "SDK licenses not accepted"

**Cause**: Android SDK licenses not accepted in CI

**Solution**:

- The workflow includes automatic license acceptance
- Check the "Verify Android SDK and dependencies" step
- Ensure `sdkmanager --licenses` command runs successfully

### APK Signature Verification Fails

**Cause**: APK not properly signed or keystore mismatch

**Solution**:

1. Verify keystore password is correct
2. Check key alias matches
3. Ensure signing configuration in `build.gradle` is correct

### Build Succeeds but APK Won't Install

**Cause**: Minimum SDK version too high or permissions issue

**Solution**:

1. Check device Android version (must be 5.0+)
2. Verify `minSdkVersion` in `build.gradle`
3. Check required permissions in `AndroidManifest.xml`

## Cost Considerations

### GitHub Actions Minutes

- **Public repositories**: FREE unlimited minutes
- **Private repositories**: 2,000 free minutes/month, then $0.008/minute

### Build Time Estimates

- Android APK build: ~10-15 minutes
- With cache: ~5-8 minutes
- Total workflow (all platforms): ~20-30 minutes

## Security Considerations

### Keystore Security

- **Never commit keystore** to version control
- Store keystore in secure location (password manager, vault)
- Keep multiple backup copies
- Use strong passwords (16+ characters)

### Secret Management

- Use GitHub Secrets for all sensitive values
- Rotate secrets periodically
- Audit secret access logs
- Use environment-specific secrets for staging/production

### APK Distribution

- Always provide SHA256 checksums
- Sign APKs with release keystore
- Verify APK signature before distribution
- Use HTTPS for download links

## Additional Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- [GitHub Actions Android](https://github.com/android-actions)
- [Gradle Build Configuration](https://developer.android.com/studio/build)

## Support

If you encounter issues:

1. Check the  guide
2. Review GitHub Actions logs for specific errors
3. Test build locally to isolate CI/CD issues
4. Open an issue with build logs and error messages
