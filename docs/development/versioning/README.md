# Versioning Documentation

This directory contains version management and build process documentation for CloudToLocalLLM.

## 📚 Contents

### Version Management

- **[Versioning](VERSIONING.md)** - Version numbering scheme and release process
- **[AI Versioning](AI-VERSIONING.md)** - AI-assisted version management

### Build Process

- **[Build Time Timestamp Injection](BUILD_TIME_TIMESTAMP_INJECTION.md)** - Build-time version injection
- **[Timestamp Build Numbers](TIMESTAMP_BUILD_NUMBERS.md)** - Timestamp-based build numbering

## 🔗 Related Documentation

- **[Release Documentation](../RELEASE/README.md)** - Release notes and procedures
- **[Development Documentation](../DEVELOPMENT/README.md)** - Development build processes
- **[Operations Documentation](../OPERATIONS/README.md)** - Deployment version management

## 📖 Versioning Overview

### Version Scheme

CloudToLocalLLM uses semantic versioning (SemVer) with the following format:

```
MAJOR.MINOR.PATCH+BUILD_NUMBER
```

- **MAJOR** - Breaking changes or major feature releases
- **MINOR** - New features, backward compatible
- **PATCH** - Bug fixes, backward compatible
- **BUILD_NUMBER** - Timestamp-based build identifier (YYYYMMDDHHmm)

### Version Sources

Version information is maintained in:

- `pubspec.yaml` - Flutter application version (primary source)
- `package.json` - Node.js services version (synchronized)
- Git tags - Release version markers (`v{version}`)

### Build Process

1. **Version Extraction** - Extract version from `pubspec.yaml`
2. **Build Number Generation** - Generate timestamp-based build number
3. **Version Injection** - Inject version into build artifacts
4. **Git Tagging** - Create version tags for releases
5. **Release Creation** - Generate GitHub releases with artifacts

### Automated Version Management

- **CI/CD Integration** - Automated version handling in build pipelines
- **Cross-platform Sync** - Ensure version consistency across platforms
- **Release Automation** - Automated release creation and artifact publishing

### Version Tracking

- **Build Artifacts** - All builds include version information
- **Runtime Display** - Version shown in application UI
- **API Endpoints** - Version information available via API
- **Monitoring** - Version tracking in operational dashboards
