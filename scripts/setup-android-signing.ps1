# Setup Android Signing for GitHub Actions
# This script generates an Android release keystore and configures GitHub Secrets
# for automated APK signing in CI/CD workflows.
#
# Usage: .\scripts\setup-android-signing.ps1
#
# Prerequisites:
# - Java JDK installed (for keytool)
# - GitHub CLI (gh) installed and authenticated
# - Repository write access

param(
    [string]$KeystorePath = "android/release-keystore.jks",
    [string]$KeyAlias = "zoidbot-release",
    [int]$Validity = 10000,
    [switch]$SkipKeystoreGeneration,
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Android Signing Setup for GitHub Actions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to check if a command exists
function Test-Command {
    param([string]$Command)
    $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
}

# Function to generate a secure random password
function New-SecurePassword {
    param([int]$Length = 24)
    $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*"
    $password = -join ((1..$Length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    return $password
}

# Step 1: Verify prerequisites
Write-Host "Step 1: Verifying prerequisites..." -ForegroundColor Yellow
Write-Host ""

# Check Java/keytool
if (-not (Test-Command "keytool")) {
    Write-Host "ERROR: keytool not found. Please install Java JDK." -ForegroundColor Red
    Write-Host ""
    Write-Host "Download Java JDK from:" -ForegroundColor Yellow
    Write-Host "  https://www.oracle.com/java/technologies/downloads/" -ForegroundColor Cyan
    Write-Host "  or use: choco install openjdk" -ForegroundColor Cyan
    exit 1
}
Write-Host "✓ keytool found" -ForegroundColor Green

# Check GitHub CLI
if (-not (Test-Command "gh")) {
    Write-Host "ERROR: GitHub CLI (gh) not found." -ForegroundColor Red
    Write-Host ""
    Write-Host "Install GitHub CLI:" -ForegroundColor Yellow
    Write-Host "  choco install gh" -ForegroundColor Cyan
    Write-Host "  or download from: https://cli.github.com/" -ForegroundColor Cyan
    exit 1
}
Write-Host "✓ GitHub CLI found" -ForegroundColor Green

# Check GitHub authentication
$ghAuthStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: GitHub CLI not authenticated." -ForegroundColor Red
    Write-Host ""
    Write-Host "Authenticate with: gh auth login" -ForegroundColor Yellow
    exit 1
}
Write-Host "✓ GitHub CLI authenticated" -ForegroundColor Green
Write-Host ""

# Step 2: Generate or verify keystore
Write-Host "Step 2: Android keystore setup..." -ForegroundColor Yellow
Write-Host ""

$keystoreExists = Test-Path $KeystorePath

if ($keystoreExists -and -not $Force) {
    Write-Host "⚠ Keystore already exists at: $KeystorePath" -ForegroundColor Yellow
    Write-Host ""
    
    if (-not $SkipKeystoreGeneration) {
        $response = Read-Host "Do you want to use the existing keystore? (Y/n)"
        if ($response -eq "n" -or $response -eq "N") {
            Write-Host ""
            Write-Host "ERROR: Please remove the existing keystore or use -Force to overwrite." -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host "✓ Using existing keystore" -ForegroundColor Green
    $useExistingKeystore = $true
} else {
    if ($keystoreExists -and $Force) {
        Write-Host "⚠ Removing existing keystore (Force mode)" -ForegroundColor Yellow
        Remove-Item $KeystorePath -Force
    }
    
    Write-Host "Generating new Android release keystore..." -ForegroundColor Cyan
    Write-Host ""
    
    # Generate secure passwords
    $keystorePassword = New-SecurePassword -Length 24
    $keyPassword = New-SecurePassword -Length 24
    
    Write-Host "Generated secure passwords:" -ForegroundColor Green
    Write-Host "  Keystore Password: $keystorePassword" -ForegroundColor Cyan
    Write-Host "  Key Password: $keyPassword" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "⚠ IMPORTANT: Save these passwords securely!" -ForegroundColor Yellow
    Write-Host "  You will need them to update your app in the future." -ForegroundColor Yellow
    Write-Host ""
    
    # Ensure android directory exists
    $androidDir = Split-Path $KeystorePath -Parent
    if (-not (Test-Path $androidDir)) {
        New-Item -ItemType Directory -Path $androidDir -Force | Out-Null
    }
    
    # Generate keystore
    $dname = "CN=Zoidbot, OU=Development, O=Zoidbot, L=Unknown, ST=Unknown, C=US"
    
    $keytoolArgs = @(
        "-genkey",
        "-v",
        "-keystore", $KeystorePath,
        "-keyalg", "RSA",
        "-keysize", "2048",
        "-validity", $Validity,
        "-alias", $KeyAlias,
        "-storepass", $keystorePassword,
        "-keypass", $keyPassword,
        "-dname", $dname
    )
    
    Write-Host "Running keytool..." -ForegroundColor Cyan
    & keytool @keytoolArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Failed to generate keystore" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "✓ Keystore generated successfully" -ForegroundColor Green
    Write-Host "  Location: $KeystorePath" -ForegroundColor Cyan
    Write-Host "  Alias: $KeyAlias" -ForegroundColor Cyan
    Write-Host "  Validity: $Validity days" -ForegroundColor Cyan
    
    $useExistingKeystore = $false
}

Write-Host ""

# Step 3: Get keystore credentials
if ($useExistingKeystore) {
    Write-Host "Step 3: Enter keystore credentials..." -ForegroundColor Yellow
    Write-Host ""
    
    $keystorePassword = Read-Host "Enter keystore password" -AsSecureString
    $keystorePassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keystorePassword)
    )
    
    $keyPassword = Read-Host "Enter key password" -AsSecureString
    $keyPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassword)
    )
    
    Write-Host ""
    Write-Host "✓ Credentials entered" -ForegroundColor Green
} else {
    Write-Host "Step 3: Using generated credentials..." -ForegroundColor Yellow
    Write-Host "✓ Credentials ready" -ForegroundColor Green
}

Write-Host ""

# Step 4: Convert keystore to base64
Write-Host "Step 4: Converting keystore to base64..." -ForegroundColor Yellow
Write-Host ""

try {
    $keystoreBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $KeystorePath).Path)
    $keystoreBase64 = [System.Convert]::ToBase64String($keystoreBytes)
    
    $keystoreSize = (Get-Item $KeystorePath).Length
    $base64Size = $keystoreBase64.Length
    
    Write-Host "✓ Keystore converted to base64" -ForegroundColor Green
    Write-Host "  Original size: $keystoreSize bytes" -ForegroundColor Cyan
    Write-Host "  Base64 size: $base64Size characters" -ForegroundColor Cyan
} catch {
    Write-Host ""
    Write-Host "ERROR: Failed to convert keystore to base64" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 5: Configure GitHub Secrets
Write-Host "Step 5: Configuring GitHub Secrets..." -ForegroundColor Yellow
Write-Host ""

# Get repository information
$repoInfo = gh repo view --json nameWithOwner -q .nameWithOwner 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to get repository information" -ForegroundColor Red
    Write-Host $repoInfo -ForegroundColor Red
    exit 1
}

Write-Host "Repository: $repoInfo" -ForegroundColor Cyan
Write-Host ""

# Set secrets
$secrets = @{
    "ANDROID_KEYSTORE_BASE64" = $keystoreBase64
    "ANDROID_KEYSTORE_PASSWORD" = $keystorePassword
    "ANDROID_KEY_PASSWORD" = $keyPassword
    "ANDROID_KEY_ALIAS" = $KeyAlias
}

foreach ($secretName in $secrets.Keys) {
    Write-Host "Setting secret: $secretName..." -ForegroundColor Cyan
    
    $secretValue = $secrets[$secretName]
    
    # Use gh secret set command
    $secretValue | gh secret set $secretName 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ $secretName set successfully" -ForegroundColor Green
    } else {
        Write-Host "  ✗ Failed to set $secretName" -ForegroundColor Red
        Write-Host "    Error: $($Error[0].Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Step 6: Verify secrets
Write-Host "Step 6: Verifying GitHub Secrets..." -ForegroundColor Yellow
Write-Host ""

$secretsList = gh secret list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "WARNING: Failed to list secrets" -ForegroundColor Yellow
    Write-Host $secretsList -ForegroundColor Yellow
} else {
    Write-Host "Configured secrets:" -ForegroundColor Cyan
    Write-Host $secretsList
    Write-Host ""
    
    # Check if all required secrets are present
    $requiredSecrets = @(
        "ANDROID_KEYSTORE_BASE64",
        "ANDROID_KEYSTORE_PASSWORD",
        "ANDROID_KEY_PASSWORD",
        "ANDROID_KEY_ALIAS"
    )
    
    $allSecretsPresent = $true
    foreach ($secretName in $requiredSecrets) {
        if ($secretsList -match $secretName) {
            Write-Host "  ✓ $secretName is configured" -ForegroundColor Green
        } else {
            Write-Host "  ✗ $secretName is missing" -ForegroundColor Red
            $allSecretsPresent = $false
        }
    }
    
    Write-Host ""
    
    if ($allSecretsPresent) {
        Write-Host "✓ All required secrets are configured" -ForegroundColor Green
    } else {
        Write-Host "⚠ Some secrets are missing" -ForegroundColor Yellow
    }
}

Write-Host ""

# Step 7: Create backup information file
Write-Host "Step 7: Creating backup information file..." -ForegroundColor Yellow
Write-Host ""

$backupFile = "android/keystore-backup-info.txt"
$backupContent = @"
Android Release Keystore Information
=====================================

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

Keystore Details:
- Location: $KeystorePath
- Alias: $KeyAlias
- Validity: $Validity days
- Algorithm: RSA 2048-bit

GitHub Secrets Configured:
- ANDROID_KEYSTORE_BASE64
- ANDROID_KEYSTORE_PASSWORD
- ANDROID_KEY_PASSWORD
- ANDROID_KEY_ALIAS

IMPORTANT SECURITY NOTES:
=========================

1. BACKUP THE KEYSTORE FILE
   - Store the keystore file ($KeystorePath) in a secure location
   - Keep multiple backup copies in different secure locations
   - Use a password manager or secure vault

2. BACKUP THE PASSWORDS
   - Keystore Password: [REDACTED - stored in GitHub Secrets]
   - Key Password: [REDACTED - stored in GitHub Secrets]
   - Store passwords in a password manager

3. NEVER COMMIT TO VERSION CONTROL
   - The keystore file is in .gitignore
   - Never commit keystore or passwords to git
   - Never share keystore or passwords publicly

4. LOSING THE KEYSTORE
   - If you lose the keystore, you CANNOT update your app on Google Play
   - You will need to publish a new app with a different package name
   - Users will need to uninstall and reinstall

5. ROTATING THE KEYSTORE
   - Keep the old keystore for existing app updates
   - Use new keystore only for new apps or major versions
   - Update GitHub Secrets when rotating

Next Steps:
===========

1. Verify the keystore is backed up securely
2. Test Android build locally:
   flutter build apk --release

3. Test Android build in CI/CD:
   - Push a tag: git tag v4.5.0-test && git push origin v4.5.0-test
   - Or manually trigger workflow in GitHub Actions

4. See docs/ANDROID_BUILD_GUIDE.md for complete setup instructions

"@

$backupContent | Out-File -FilePath $backupFile -Encoding UTF8

Write-Host "✓ Backup information saved to: $backupFile" -ForegroundColor Green
Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  ✓ Keystore: $KeystorePath" -ForegroundColor Green
Write-Host "  ✓ Base64 conversion: Complete" -ForegroundColor Green
Write-Host "  ✓ GitHub Secrets: Configured" -ForegroundColor Green
Write-Host "  ✓ Backup info: $backupFile" -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: Backup the keystore file and passwords securely!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Backup keystore file to secure location" -ForegroundColor White
Write-Host "  2. Test local build: flutter build apk --release" -ForegroundColor White
Write-Host "  3. Test CI/CD build: Push a version tag" -ForegroundColor White
Write-Host "  4. See: docs/ANDROID_BUILD_GUIDE.md" -ForegroundColor White
Write-Host ""
