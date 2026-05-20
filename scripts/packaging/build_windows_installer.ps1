param(
  [string]$SourceDir = "build/windows/x64/runner/Release",
  [string]$OutputDir = "dist/windows",
  [string]$Version = ""
)

$ErrorActionPreference = 'Stop'

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = (Resolve-Path (Join-Path $scriptRoot "../..")).Path
Set-Location $projectRoot

if (-not $Version) {
  $versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version:\s*(.+)$' | Select-Object -First 1
  if (-not $versionLine) {
    throw "Could not read version from pubspec.yaml"
  }
  $Version = ($versionLine.Matches[0].Groups[1].Value -split '\+')[0]
}

$resolvedSourceDir = (Resolve-Path $SourceDir).Path
if (-not $resolvedSourceDir) {
  throw "Windows release bundle not found at $SourceDir"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$resolvedOutputDir = (Resolve-Path $OutputDir).Path
$installerScript = Join-Path $projectRoot "windows/installer/CloudToLocalLLM.iss"

$isccCommand = (Get-Command iscc.exe -ErrorAction SilentlyContinue)?.Source
if (-not $isccCommand) {
  $fallback = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
  if (Test-Path $fallback) {
    $isccCommand = $fallback
  } else {
    throw "ISCC.exe not found. Inno Setup is required on the Windows runner."
  }
}

$arguments = @(
  "/DMyAppVersion=$Version",
  "/DMyAppSourceDir=$resolvedSourceDir",
  "/DMyOutputDir=$resolvedOutputDir",
  $installerScript
)

& $isccCommand @arguments
