# CloudToLocalLLM Versioning Strategy

## Overview

CloudToLocalLLM follows a strict semantic versioning scheme that aligns release types with deployment urgency and testing requirements. This strategy ensures appropriate prioritization of different types of changes and helps teams understand the impact and urgency of each release.

## Semantic Versioning Format

**Format:** `MAJOR.MINOR.PATCH+YYYYMMDDHHMM`

- **MAJOR.MINOR.PATCH**: Semantic version following semver.org standards
- **YYYYMMDDHHMM**: Build timestamp in 12-digit format (Year-Month-Day-Hour-Minute)

**Example:** `3.5.14+202506172035` = Version 3.5.14 built on June 17, 2025 at 20:35

## Release Type Classifications

### 🚨 PATCH Releases (0.0.X+YYYYMMDDHHMM)

**Purpose:** Urgent fixes requiring immediate deployment

**Use Cases:**

- **Hotfixes**: Critical bugs affecting user functionality
- **Security Updates**: Vulnerabilities requiring immediate patching
- **Emergency Patches**: System failures, data corruption, or service outages
- **Critical Stability Fixes**: Crashes, memory leaks, or performance degradation

**Examples:**

- Database connection timeout causing login failures
- Authentication bypass vulnerability
- Application crash on startup
- Memory leak causing system instability
- API endpoint returning 500 errors

**Deployment Characteristics:**

- **Urgency**: High - Deploy immediately
- **Testing**: Minimal testing, focus on fix verification
- **Approval**: Fast-track approval process
- **Rollback Plan**: Required before deployment

### 🔧 MINOR Releases (0.X.0+YYYYMMDDHHMM)

**Purpose:** Planned feature additions and improvements

**Use Cases:**

- **Feature Additions**: New functionality and capabilities
- **Quality of Life Improvements**: User experience enhancements
- **UI Enhancements**: Interface improvements and visual updates
- **API Expansions**: New endpoints or enhanced existing functionality
- **Performance Optimizations**: Non-critical performance improvements

**Examples:**

- New tunnel connection management features
- Enhanced system tray functionality
- Improved settings interface
- Additional model download options
- Better error messaging and user guidance

**Deployment Characteristics:**

- **Urgency**: Medium - Deploy during planned release windows
- **Testing**: Full testing suite including integration tests
- **Approval**: Standard approval process
- **Documentation**: Feature documentation required

### 💥 MAJOR Releases (X.0.0+YYYYMMDDHHMM)

**Purpose:** Breaking changes and architectural overhauls

**Use Cases:**

- **Breaking Changes**: API changes requiring user adaptation
- **Architectural Overhauls**: Fundamental system redesigns
- **Platform Migrations**: Framework or technology stack changes
- **Significant API Changes**: Non-backward-compatible modifications

**Examples:**

- Flutter framework major version upgrade
- API v2 with breaking endpoint changes
- Database schema migration requiring data transformation
- Authentication system overhaul
- Complete UI framework replacement

**Deployment Characteristics:**

- **Urgency**: Low - Planned major releases with advance notice
- **Testing**: Comprehensive testing including migration testing
- **Approval**: Extended approval process with stakeholder review
- **Documentation**: Migration guides and breaking change documentation
- **GitHub Release**: Automatically creates GitHub release

## Version Management Commands

### Using the Version Manager Script

```powershell
# Show current version information (Windows PowerShell)
./scripts/powershell/version_manager.ps1 info

# Manual version increment (AFTER deployment verification)
./scripts/powershell/version_manager.ps1 increment patch    # For urgent fixes
./scripts/powershell/version_manager.ps1 increment minor    # For planned features
./scripts/powershell/version_manager.ps1 increment major    # For breaking changes
./scripts/powershell/version_manager.ps1 increment build    # For timestamp updates

# Prepare versions for build-time injection (during deployment)
./scripts/powershell/version_manager.ps1 prepare patch      # Prepare with placeholder
./scripts/powershell/version_manager.ps1 prepare minor      # Build-time timestamp injection
```

### Decision Matrix

| Change Type | Version Increment | Deployment Urgency | Testing Level | Example |
|-------------|-------------------|-------------------|---------------|---------|
| Critical Bug Fix | PATCH | Immediate | Minimal | Login failure fix |
| Security Vulnerability | PATCH | Immediate | Security-focused | Auth bypass patch |
| New Feature | MINOR | Planned | Full | Tunnel management UI |
| UI Enhancement | MINOR | Planned | Full | Settings redesign |
| Breaking API Change | MAJOR | Planned | Comprehensive | API v2 migration |
| Framework Upgrade | MAJOR | Planned | Comprehensive | Flutter 4.0 |

## Deployment Workflow Integration

### Manual Version Increment Strategy

**Version incrementing is now performed AFTER deployment verification** to give developers control over when versions are committed.

#### **New Workflow:**

1. **Deploy Current Version**: Use existing version for deployment
2. **Verify Deployment**: Ensure all components are working correctly
3. **Manual Version Increment**: Choose appropriate increment type
4. **Commit Version Changes**: Prepare repository for next development cycle

#### **Version Increment Commands (Post-Deployment):**

```powershell
# After successful deployment verification
./scripts/powershell/version_manager.ps1 increment patch    # For bug fixes
./scripts/powershell/version_manager.ps1 increment minor    # For new features
./scripts/powershell/version_manager.ps1 increment major    # For breaking changes

# Commit the version increment
git add . && git commit -m "Increment version after deployment"
bash -c "git push origin master"  # Use Git Bash for Windows SSH compatibility
```

### 6-Phase Deployment Considerations

**PATCH Releases:**

- **Phase 1-3**: Expedited execution
- **Phase 4**: Minimal distribution testing
- **Phase 5**: Immediate VPS deployment
- **Phase 6**: Fast-track verification
- **Post-Deployment**: Verify fixes, then manually increment patch version

**MINOR Releases:**

- **Phase 1-3**: Standard execution
- **Phase 4**: Full distribution testing
- **Phase 5**: Scheduled VPS deployment
- **Phase 6**: Complete verification including AUR testing
- **Post-Deployment**: Verify features, then manually increment minor version

**MAJOR Releases:**

- **Phase 1-3**: Extended testing and validation
- **Phase 4**: Comprehensive distribution testing
- **Phase 5**: Coordinated VPS deployment with rollback plan
- **Phase 6**: Extended verification and monitoring
- **Post-Deployment**: Verify compatibility, then manually increment major version

## GitHub Release Strategy

### Automatic GitHub Releases

**MAJOR versions only** (X.0.0) automatically trigger GitHub release creation:

```powershell
# Major version increment automatically suggests GitHub release (Windows PowerShell)
./scripts/powershell/version_manager.ps1 increment major
# Output: "This is a MAJOR version update - GitHub release should be created!"
# Output: "Run: git tag v3.0.0 && git push origin v3.0.0"
```

**MINOR and PATCH versions** do not create GitHub releases to avoid release noise.

## Best Practices

### Version Selection Guidelines

1. **Ask: "Is this change breaking existing functionality?"**
   - Yes → MAJOR release
   - No → Continue to next question

2. **Ask: "Is this an urgent fix that can't wait?"**
   - Yes → PATCH release
   - No → Continue to next question

3. **Ask: "Does this add new functionality or features?"**
   - Yes → MINOR release
   - No → BUILD update

### Common Mistakes to Avoid

❌ **Using PATCH for planned features**

- Patch releases should be reserved for urgent fixes only

❌ **Using MINOR for breaking changes**

- Breaking changes always require MAJOR version increment

❌ **Creating GitHub releases for every version**

- Only MAJOR versions warrant GitHub releases

❌ **Inconsistent versioning across team**

- Use the version manager script to ensure consistency

### Emergency Hotfix Process

1. **Identify Critical Issue**: Confirm issue requires immediate fix
2. **Create Hotfix Branch**: `git checkout -b hotfix/critical-auth-fix`
3. **Implement Fix**: Minimal code changes to address issue
4. **Fast-Track Testing**: Focus on fix verification only
5. **Deploy Immediately**: Use expedited 6-phase deployment with current version
6. **Verify Fix**: Ensure hotfix resolves the critical issue
7. **Manual Version Increment**: `./scripts/powershell/version_manager.ps1 increment patch`
8. **Commit Version**: `git add . && git commit -m "Increment version after hotfix"`
9. **Push Changes**: `bash -c "git push origin master"`  # Use Git Bash for Windows SSH compatibility
10. **Monitor Closely**: Enhanced monitoring post-deployment

## Version History Examples

```
3.6.0+202506180800  ← MINOR: New tunnel management features
3.5.15+202506171200 ← PATCH: Critical authentication fix
3.5.14+202506170900 ← MINOR: UI enhancements and settings improvements
3.5.13+202506160800 ← PATCH: Database connection timeout fix
4.0.0+202506150900  ← MAJOR: Flutter 4.0 migration (GitHub release)
```

## Integration with 6-Phase Deployment

### Version-Specific Deployment Adjustments

**PATCH Releases (Urgent):**

- **Phase 1**: Expedited pre-flight validation
- **Phase 2**: Fast-track version synchronization
- **Phase 3**: Minimal build testing (focus on fix verification)
- **Phase 4**: Streamlined distribution with essential testing only
- **Phase 5**: Immediate VPS deployment with enhanced monitoring
- **Phase 6**: Fast-track operational readiness with critical path verification

**MINOR Releases (Planned):**

- **Phase 1**: Standard pre-flight validation
- **Phase 2**: Complete version synchronization
- **Phase 3**: Full multi-platform build testing
- **Phase 4**: Comprehensive distribution testing including AUR
- **Phase 5**: Scheduled VPS deployment during maintenance window
- **Phase 6**: Complete operational readiness including mandatory AUR verification

**MAJOR Releases (Breaking):**

- **Phase 1**: Extended pre-flight validation with migration testing
- **Phase 2**: Comprehensive version synchronization with documentation updates
- **Phase 3**: Extensive multi-platform build testing with compatibility verification
- **Phase 4**: Full distribution testing with rollback preparation
- **Phase 5**: Coordinated VPS deployment with staged rollout
- **Phase 6**: Extended operational readiness with comprehensive monitoring

This versioning strategy ensures that deployment urgency aligns with the type of changes being released, enabling appropriate testing and approval processes for each release type.
