# Zoidbot - Release Directory Cleanup Script
# This script removes old/unused installer files from the releases directory

param(
    [Parameter(Mandatory=$false)]
    [string]$CandidateVersion = "latest",
    
    [Parameter(Mandatory=$false)]
    [switch]$PreserveAdmin,
    
    [Parameter(Mandatory=$false)]
    [switch]$PreserveRegular,
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepLatestBuild
)

$ErrorActionPreference = "Stop"
$ReleasesDir = Join-Path $PSScriptRoot "releases"

# Display banner
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Zoidbot - Release Directory Cleanup" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# Check if releases directory exists
if (-not (Test-Path $ReleasesDir)) {
    Write-Host "Error: Releases directory not found at $ReleasesDir" -ForegroundColor Red
    exit 1
}

# Check if running in Dry Run mode
if ($DryRun) {
    Write-Host "Running in DRY RUN mode. No files will be deleted." -ForegroundColor Yellow
}

# Set default preserve flags if none specified
if (-not $PreserveAdmin -and -not $PreserveRegular) {
    $PreserveAdmin = $true
    $PreserveRegular = $true
    Write-Host "No specific installer type specified to preserve, keeping both regular and admin." -ForegroundColor Yellow
}

# List all files in the releases directory
$allFiles = Get-ChildItem -Path $ReleasesDir -File

# Separate files by type
$regularInstallers = $allFiles | Where-Object { $_.Name -match "Zoidbot-Windows-.*-Setup\.exe" -and $_.Name -notmatch "Admin" }
$adminInstallers = $allFiles | Where-Object { $_.Name -match "Zoidbot-(Windows-)?Admin.*\.(exe|zip)" }
$zipFiles = $allFiles | Where-Object { $_.Name -match "Zoidbot-Windows-.*\.zip" -and $_.Name -notmatch "Admin" }

# Function to get timestamp from filename
function Get-FileTimestamp($filename) {
    if ($filename -match "\d{12}") {
        return $matches[0]
    }
    elseif ($filename -match "\d{14}") {
        return $matches[0]
    }
    elseif ($filename -match "(\d{12})") {
        return $matches[1]
    }
    elseif ($filename -match "(\d{14})") {
        return $matches[1]
    }
    elseif ($filename -match "(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})") {
        return $matches[0]
    }
    elseif ($filename -match "(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})" ) {
        return $matches[0]
    }
    return "00000000000000"  # Default timestamp for sorting
}

# Function to sort files by timestamp
function Sort-FilesByTimestamp($files) {
    return $files | Sort-Object -Property @{Expression = { Get-FileTimestamp $_.Name }; Descending = $true}
}

# Sort files by timestamp (newest first)
$regularInstallers = Sort-FilesByTimestamp $regularInstallers
$adminInstallers = Sort-FilesByTimestamp $adminInstallers
$zipFiles = Sort-FilesByTimestamp $zipFiles

# Function to display file info
function Show-FileInfo($file) {
    $size = [math]::Round($file.Length / 1MB, 2)
    $timestamp = Get-FileTimestamp $file.Name
    Write-Host "    $($file.Name) ($size MB) - Timestamp: $timestamp"
}

# Display current files
Write-Host "`nCurrent files in releases directory:" -ForegroundColor Green
Write-Host "`nRegular Installers:" -ForegroundColor Yellow
$regularInstallers | ForEach-Object { Show-FileInfo $_ }
Write-Host "`nAdmin Installers:" -ForegroundColor Yellow
$adminInstallers | ForEach-Object { Show-FileInfo $_ }
Write-Host "`nZIP Files:" -ForegroundColor Yellow
$zipFiles | ForEach-Object { Show-FileInfo $_ }

# Function to process file deletion
function Remove-OldFiles($files, $preserveType, $keepCount = 1) {
    $filesToDelete = @()
    
    # Keep the specified number of latest files
    if ($files.Count -gt $keepCount) {
        $filesToDelete = $files[$keepCount..$($files.Count - 1)]
    }
    
    if ($filesToDelete.Count -eq 0) {
        Write-Host "`nNo $preserveType files to delete." -ForegroundColor Green
        return
    }
    
    Write-Host "`n$preserveType files to be removed:" -ForegroundColor Yellow
    $filesToDelete | ForEach-Object { Show-FileInfo $_ }
    
    if (-not $DryRun) {
        foreach ($file in $filesToDelete) {
            try {
                Remove-Item $file.FullName -Force
                Write-Host "Deleted: $($file.Name)" -ForegroundColor Green
            }
            catch {
                Write-Host "Error deleting $($file.Name): $_" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "DRY RUN: Files would be deleted, but no action taken." -ForegroundColor Yellow
    }
}

# Process deletions based on command line parameters
$keepCount = if ($KeepLatestBuild) { 1 } else { 0 }

if ($PreserveRegular) {
    Write-Host "`nProcessing regular installers..." -ForegroundColor Cyan
    Remove-OldFiles $regularInstallers "Regular installer" $keepCount
    
    Write-Host "`nProcessing ZIP files..." -ForegroundColor Cyan
    Remove-OldFiles $zipFiles "ZIP file" $keepCount
}

if ($PreserveAdmin) {
    Write-Host "`nProcessing admin installers..." -ForegroundColor Cyan
    Remove-OldFiles $adminInstallers "Admin installer" $keepCount
}

Write-Host "`n==================================================" -ForegroundColor Cyan
if ($DryRun) {
    Write-Host "Dry run completed. No files were deleted." -ForegroundColor Yellow
}
else {
    Write-Host "Cleanup completed. Releases directory has been organized." -ForegroundColor Green
}
Write-Host "==================================================" -ForegroundColor Cyan 