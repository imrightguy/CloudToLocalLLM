# Android Build Configuration

This directory contains the Android-specific configuration for CloudToLocalLLM.

## Signing Configuration

### For Local Development

1. **Generate a debug keystore** (if not already present):
   ```bash
   keytool -genkey -v -keystore debug-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias androiddebugkey
   ```

2. **For release builds**, create a release keystore:
   ```bash
   keytool -genkey -v -keystore release-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias CloudToLocalLLM-release
   ```

3. **Create key.properties** from template:
   ```bash
   cp key.properties.template key.properties
   ```

4. **Edit key.properties** with your keystore information:
   ```properties
   storePassword=your-keystore-password
   keyPassword=your-key-password
   keyAlias=CloudToLocalLLM-release
   storeFile=../release-keystore.jks
   ```

### For CI/CD (GitHub Actions)

The CI/CD workflow automatically creates the signing configuration from GitHub Secrets.

**Required GitHub Secrets:**
- `ANDROID_KEYSTORE_BASE64` - Base64-encoded keystore file
- `ANDROID_KEYSTORE_PASSWORD` - Keystore password
- `ANDROID_KEY_PASSWORD` - Key password
- `ANDROID_KEY_ALIAS` - Key alias

**Setup Instructions:**

See  for complete setup instructions.

## Security Notes

⚠️ **IMPORTANT**: Never commit these files to version control:
- `key.properties` - Contains passwords
- `*.jks` - Keystore files
- `*.keystore` - Keystore files

These files are already listed in `.gitignore` to prevent accidental commits.

## Building Android APK

### Debug Build

```bash
# From project root
flutter build apk --debug
```

### Release Build

```bash
# From project root
flutter build apk --release
```

The release build requires proper signing configuration (key.properties and keystore).

### Build for Specific Architectures

```bash
# ARM 64-bit only (most modern devices)
flutter build apk --release --target-platform android-arm64

# ARM 32-bit only (older devices)
flutter build apk --release --target-platform android-arm

# All architectures (fat APK)
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

## Testing

### Install on Device

```bash
# Install debug build
flutter install

# Install specific APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Run on Device

```bash
# Run debug build
flutter run

# Run release build
flutter run --release
```

## Troubleshooting

### "Keystore not found"

**Solution**: Ensure `key.properties` exists and `storeFile` path is correct.

### "Signing configuration not found"

**Solution**: Check that `android/app/build.gradle` has the signing configuration block.

### "SDK licenses not accepted"

**Solution**: Run `flutter doctor --android-licenses` and accept all licenses.

### Build fails with Gradle errors

**Solution**: 
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

## Additional Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Android App Signing](https://developer.android.com/studio/publish/app-signing)
- 
