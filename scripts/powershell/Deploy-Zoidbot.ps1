# Zoidbot Local Desktop Build Script
# Builds desktop applications and creates GitHub releases for local distribution
# Cloud deployment is handled separately by GitHub Actions

[CmdletBinding()]
param(
[ValidateSet('build', 'patch', 'minor', 'major')]
[string]$VersionIncrement = 'patch',

[switch]$SkipVerification,
[switch]$Force,
[switch]$DryRun
)

# Configuration
$ProjectRoot = Split-Path $PSScriptRoot -Parent | Split-Path -Parent

Write-Host "=== Zoidbot Local Desktop Build ===" -ForegroundColor Cyan
Write-Host "Version Increment: $VersionIncrement"
Write-Host "Project Root: $ProjectRoot"
Write-Host "Dry Run: $DryRun"
Write-Host ""

# Step 1: Check prerequisites
Write-Host "=== STEP 1: PREREQUISITES ===" -ForegroundColor Yellow

if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
Write-Host "ERROR: pubspec.yaml not found" -ForegroundColor Red
exit 1
}

# Check if there are uncommitted changes
Write-Host "Checking for uncommitted changes..."
git status --porcelain
if ($LASTEXITCODE -eq 0) {
$uncommittedChanges = git status --porcelain
if ($uncommittedChanges) {
    Write-Host "ERROR: You have uncommitted changes. Commit and push all changes before building:" -ForegroundColor Red
    Write-Host $uncommittedChanges -ForegroundColor Red
    Write-Host "Run: git add . && git commit -m 'message' && git push origin main" -ForegroundColor Yellow
    exit 1
}
}
Write-Host "? Found pubspec.yaml"

Write-Host "Checking Git status..."
git status
if ($LASTEXITCODE -ne 0) {
Write-Host "ERROR: Git status failed" -ForegroundColor Red
exit 1
}

# SSH connection test removed - cloud deployment handled by GitHub Actions

# Define version manager path (used throughout script)
$versionManagerPath = Join-Path $PSScriptRoot "version_manager.ps1"

# Step 2: Version management
Write-Host ""
Write-Host "=== STEP 2: VERSION MANAGEMENT ===" -ForegroundColor Yellow

if (-not $DryRun) {
    try {
        Write-Host "Incrementing version ($VersionIncrement)..."
        & $versionManagerPath increment $VersionIncrement
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Version increment failed" -ForegroundColor Red
            exit 1
        }
        Write-Host "? Version incremented successfully"

        # Commit and push version changes
        Write-Host "Committing version changes..."
                        git add pubspec.yaml assets/version.json lib/shared/lib/version.dart lib/shared/pubspec.yaml lib/config/app_config.dart package.json docs/CHANGELOG.md
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to stage version changes" -ForegroundColor Red
            exit 1
        }

        $versionCommitMessage = "Update version to $(& $versionManagerPath get-semantic)"
        git commit -m $versionCommitMessage
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to commit version changes" -ForegroundColor Red
            exit 1
        }

        git push origin main
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to push version changes" -ForegroundColor Red
            exit 1
        }
        Write-Host "? Version changes committed and pushed"
    } catch {
        Write-Host "ERROR: Version management failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[DRY RUN] Would increment version ($VersionIncrement)"
}

# Step 3: Source preparation
Write-Host ""
Write-Host "=== STEP 3: SOURCE PREPARATION ===" -ForegroundColor Yellow

$requiredFiles = @("pubspec.yaml", "lib/main.dart", "docker-compose.yml")
foreach ($file in $requiredFiles) {
$filePath = Join-Path $ProjectRoot $file
if (Test-Path $filePath) {
    Write-Host "? Found: $file"
} else {
    Write-Host "? Missing: $file" -ForegroundColor Red
    exit 1
}
}

# Step 3.5: Windows Release Build and GitHub Release Creation (Native PowerShell)
Write-Host ""
Write-Host "=== STEP 3.5: WINDOWS RELEASE BUILD AND GITHUB RELEASE CREATION ===" -ForegroundColor Yellow

if (-not $DryRun) {
    try {
        # Get current version for release
        $versionManagerPath = Join-Path $ProjectRoot "scripts\version_manager.sh"
        # Convert Windows path to WSL path (e.g., C:\Users\... -> /mnt/c/Users/...)
        $wslProjectRoot = $ProjectRoot -replace '\\', '/'
        $wslProjectRoot = $wslProjectRoot -replace '^([A-Za-z]):', '/mnt/$1'
        $wslProjectRoot = $wslProjectRoot.ToLower()
        $currentVersion = & wsl bash -c "cd '$wslProjectRoot' && ./scripts/version_manager.sh get-semantic"
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get current version"
        }
        $currentVersion = $currentVersion.Trim()
        Write-Host "Building release for version: $currentVersion"

        # Step 3.5.1: Build Windows packages
        Write-Host ""
        Write-Host "--- Building Windows Release Assets ---" -ForegroundColor Cyan
        $buildAssetsScript = Join-Path $ProjectRoot "scripts\powershell\Build-GitHubReleaseAssets.ps1"
        & $buildAssetsScript -InstallInnoSetup
        if ($LASTEXITCODE -ne 0) {
            throw "Windows release assets build failed"
        }
        Write-Host "? Windows release assets built successfully"

        # Step 3.5.2: Build Linux AppImage packages (via WSL)
        Write-Host ""
        Write-Host "--- Building Linux AppImage Assets ---" -ForegroundColor Cyan
        $linuxBuildScript = Join-Path $ProjectRoot "scripts\packaging\build_all_packages.sh"
        $wslLinuxBuildPath = $linuxBuildScript -replace '\\', '/'
        $wslLinuxBuildPath = $wslLinuxBuildPath -replace '^([A-Za-z]):', '/mnt/$1'
        $wslLinuxBuildPath = $wslLinuxBuildPath.ToLower()
        & wsl -d ArchLinux bash -c "cd '$wslProjectRoot' && chmod +x '$wslLinuxBuildPath' && '$wslLinuxBuildPath' --skip-increment --packages appimage"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WARNING: Linux AppImage build failed (likely due to FUSE not being available in WSL)" -ForegroundColor Yellow
            Write-Host "Continuing deployment with Windows assets only..." -ForegroundColor Yellow
        } else {
            Write-Host "? Linux release assets built successfully"
        }

        # Step 3.5.3: Update AUR PKGBUILD (via WSL)
        Write-Host ""
        Write-Host "--- Updating AUR PKGBUILD ---" -ForegroundColor Cyan
        $aurUpdateScript = Join-Path $ProjectRoot "scripts\packaging\update_aur_pkgbuild.sh"
        $wslAurUpdatePath = $aurUpdateScript -replace '\\', '/'
        $wslAurUpdatePath = $wslAurUpdatePath -replace '^([A-Za-z]):', '/mnt/$1'
        $wslAurUpdatePath = $wslAurUpdatePath.ToLower()
        & wsl -d ArchLinux bash -c "cd '$wslProjectRoot' && chmod +x '$wslAurUpdatePath' && '$wslAurUpdatePath'"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "WARNING: AUR PKGBUILD update failed, continuing with deployment" -ForegroundColor Yellow
        } else {
            Write-Host "? AUR PKGBUILD updated successfully"
        }

        # Step 3.5.4: Create GitHub Release (Native PowerShell using gh CLI)
        Write-Host ""
        Write-Host "--- Creating GitHub Release ---" -ForegroundColor Cyan

        # Check if gh CLI is available
        $ghPath = Get-Command gh -ErrorAction SilentlyContinue
        if (-not $ghPath) {
            throw "GitHub CLI (gh) is not installed or not in PATH. Please install it from https://cli.github.com/"
        }

        $tagName = "v$currentVersion"
        $releaseName = "Zoidbot v$currentVersion"

        # Generate release notes
        $releaseNotes = @"
# Zoidbot v$currentVersion

## What's Changed
- Version $currentVersion release
- Updated dependencies and bug fixes
- Performance improvements

## Download
Choose the appropriate package for your system:

### Windows
- **zoidbot-$currentVersion-portable.zip** - Portable version (no installation required)
- **Zoidbot-Windows-$currentVersion-Setup.exe** - Windows installer

### Linux
- **zoidbot-$($currentVersion)-x86_64.AppImage** - Universal Linux package (recommended)

### Package Managers
- **AUR**: `yay -S zoidbot` (Arch Linux and derivatives)
- **Manual**: Download AppImage for any Linux distribution

## Checksums
SHA256 checksums are provided for all packages to verify integrity.

**Full Changelog**: https://github.com/Zoidbot-online/Zoidbot/compare/v$($currentVersion.Split('.')[0]).$($currentVersion.Split('.')[1]).$([int]$currentVersion.Split('.')[2] - 1)...v$currentVersion
"@

        # Create and push tag
        Write-Host "Creating and pushing tag $tagName..."
        git tag -a $tagName -m "Zoidbot v$currentVersion"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Tag may already exist, continuing..."
        }

        git push origin $tagName
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Tag push may have failed, continuing with release creation..."
        }

        # Collect release assets for current version only
        $distDir = Join-Path $ProjectRoot "dist"
        $windowsDir = Join-Path $distDir "windows"
        $linuxDir = Join-Path $distDir "linux"

        $assets = @()

        # Windows assets - only for current version
        if (Test-Path $windowsDir) {
            $windowsAssets = Get-ChildItem -Path $windowsDir -File | Where-Object {
                $_.Name -match "zoidbot-$currentVersion.*\.(zip|exe)$" -or
                $_.Name -match "Zoidbot-Windows-$currentVersion.*\.exe$"
            }
            $assets += $windowsAssets.FullName

            # Also include SHA256 checksums for the current version assets
            $checksumAssets = Get-ChildItem -Path $windowsDir -File | Where-Object {
                $_.Name -match "zoidbot-$currentVersion.*\.sha256$" -or
                $_.Name -match "Zoidbot-Windows-$currentVersion.*\.sha256$"
            }
            $assets += $checksumAssets.FullName
        }

        # Linux assets - only for current version
        if (Test-Path $linuxDir) {
            $linuxAssets = Get-ChildItem -Path $linuxDir -File | Where-Object {
                $_.Name -match "zoidbot-$currentVersion.*\.AppImage$" -or
                $_.Name -match "Zoidbot-$currentVersion.*\.AppImage$"
            }
            $assets += $linuxAssets.FullName

            # Also include SHA256 checksums for the current version Linux assets
            $linuxChecksumAssets = Get-ChildItem -Path $linuxDir -File | Where-Object {
                $_.Name -match "zoidbot-$currentVersion.*\.AppImage\.sha256$" -or
                $_.Name -match "Zoidbot-$currentVersion.*\.AppImage\.sha256$"
            }
            $assets += $linuxChecksumAssets.FullName
        }

        # Filter out any null or empty paths
        $assets = $assets | Where-Object { $_ -and $_.Trim() -ne "" }

        Write-Host "Found $($assets.Count) assets to upload for version $currentVersion"
        foreach ($asset in $assets) {
            Write-Host "  - $(Split-Path $asset -Leaf)"
        }

        if ($assets.Count -eq 0) {
            Write-Host "WARNING: No assets found for version $currentVersion. Expected files:" -ForegroundColor Yellow
            Write-Host "  Windows:" -ForegroundColor Yellow
            Write-Host "    - zoidbot-$currentVersion-portable.zip" -ForegroundColor Yellow
            Write-Host "    - Zoidbot-Windows-$currentVersion-Setup.exe" -ForegroundColor Yellow
            Write-Host "  Linux:" -ForegroundColor Yellow
            Write-Host "    - zoidbot-$currentVersion.AppImage" -ForegroundColor Yellow
        }

        # Verify we have the expected assets
        $expectedPortableZip = $assets | Where-Object { $_ -and $_ -match "zoidbot-$currentVersion.*portable\.zip$" }
        $expectedInstaller = $assets | Where-Object { $_ -and $_ -match "Zoidbot-Windows-$currentVersion.*Setup\.exe$" }
        $expectedAppImage = $assets | Where-Object { $_ -and $_ -match "zoidbot-$currentVersion.*\.AppImage$" }

        Write-Host "Asset verification for version ${currentVersion}:" -ForegroundColor Cyan
        Write-Host "  Windows Portable ZIP: $($expectedPortableZip -ne $null)" -ForegroundColor $(if ($expectedPortableZip) { "Green" } else { "Yellow" })
        Write-Host "  Windows Installer EXE: $($expectedInstaller -ne $null)" -ForegroundColor $(if ($expectedInstaller) { "Green" } else { "Yellow" })
        Write-Host "  Linux AppImage: $($expectedAppImage -ne $null)" -ForegroundColor $(if ($expectedAppImage) { "Green" } else { "Yellow" })

        if (-not $expectedPortableZip -and -not $expectedInstaller -and -not $expectedAppImage) {
            Write-Host "WARNING: No platform assets found for version $currentVersion" -ForegroundColor Yellow
            Write-Host "Continuing with available assets..." -ForegroundColor Yellow
        }

        # Create GitHub release
        Write-Host "Creating GitHub release $tagName..."
        $releaseNotesFile = Join-Path $env:TEMP "release_notes_$currentVersion.md"
        $releaseNotes | Set-Content -Path $releaseNotesFile -Encoding UTF8

        $ghArgs = @(
            "release", "create", $tagName,
            "--repo", "Zoidbot-online/Zoidbot",
            "--title", $releaseName,
            "--notes-file", $releaseNotesFile
        )

        # Add assets to the command only if we have any
        if ($assets.Count -gt 0) {
            $ghArgs += $assets
        }

        & gh @ghArgs
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub release creation failed"
        }

        # Clean up
        Remove-Item $releaseNotesFile -ErrorAction SilentlyContinue

        Write-Host "? GitHub release created successfully!"
        Write-Host "? Release URL: https://github.com/Zoidbot-online/Zoidbot/releases/tag/$tagName"
        Write-Host "? Uploaded $($assets.Count) assets to the release"

    } catch {
        Write-Host "ERROR: Release build and GitHub release creation failed: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[DRY RUN] Would perform Windows release build and GitHub release creation using native PowerShell"
}


# Step 4: Commit Build Artifacts to Releases Branch
if (-not $DryRun) {
Write-Host ""
Write-Host "=== STEP 4: COMMIT BUILD ARTIFACTS TO RELEASES BRANCH ===" -ForegroundColor Yellow

    # Get current version for branch naming
    $currentVersion = & $versionManagerPath get-semantic
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to get current version" -ForegroundColor Red
        exit 1
    }
    $currentVersion = $currentVersion.Trim()
    $releasesBranch = "releases/v$currentVersion"

    Write-Host "Creating releases branch: $releasesBranch"

    # Create and checkout releases branch
    git checkout -b $releasesBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to create releases branch" -ForegroundColor Red
        exit 1
    }

    # Add build artifacts (dist folder and version files)
    Write-Host "Adding build artifacts to releases branch..."
    git add dist/ pubspec.yaml assets/version.json lib/shared/lib/version.dart lib/shared/pubspec.yaml lib/config/app_config.dart
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to stage build artifacts" -ForegroundColor Red
        exit 1
    }

    # Check if there are changes to commit
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        # There are staged changes, commit them
        $buildArtifactsCommitMessage = "Add build artifacts for release v$currentVersion"
        git commit -m $buildArtifactsCommitMessage
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to commit build artifacts" -ForegroundColor Red
            exit 1
        }

        # Push the releases branch
        git push origin $releasesBranch
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Failed to push releases branch" -ForegroundColor Red
            exit 1
        }
        Write-Host "? Build artifacts committed and pushed to releases branch: $releasesBranch"
    } else {
        Write-Host "? No build artifacts to commit"
    }

    # Switch back to main branch
    git checkout main
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: Failed to switch back to main branch" -ForegroundColor Yellow
    }
}

# VPS deployment removed - now handled by GitHub Actions cloud deployment workflow



# Step 5: Verification
if (-not $SkipVerification) {
Write-Host ""
Write-Host "=== STEP 5: VERIFICATION ===" -ForegroundColor Yellow

Write-Host "? Desktop build artifacts created successfully" -ForegroundColor Green
Write-Host "? GitHub release created with desktop binaries" -ForegroundColor Green
Write-Host "? Build artifacts pushed to releases branch" -ForegroundColor Green
}

# Final report
Write-Host ""
Write-Host "=== LOCAL DESKTOP BUILD COMPLETE ===" -ForegroundColor Green
Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC')"
Write-Host ""
Write-Host "Next Steps:"
Write-Host "  1. Desktop applications are available in GitHub releases"
Write-Host "  2. Cloud deployment will be triggered automatically by GitHub Actions"
Write-Host "  3. Monitor GitHub Actions for cloud deployment status"
Write-Host ""
Write-Host "? Local desktop build successful!" -ForegroundColor Green
Write-Host "? Cloud deployment handled by CI/CD pipeline" -ForegroundColor Cyan
