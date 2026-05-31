[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipBuild,
    [switch]$Force,
    [string]$Version,
    [switch]$Help
)

$ErrorActionPreference = 'Stop'
$BuilderScript = Join-Path $PSScriptRoot '..\powershell\Build-GitHubReleaseAssets.ps1'
$BuilderScript = [System.IO.Path]::GetFullPath($BuilderScript)

if (-not (Test-Path $BuilderScript)) {
    throw "Release asset builder not found at: $BuilderScript"
}

$builderArgs = @()
if ($Help) {
    $builderArgs += '-Help'
} else {
    if ($Clean) { $builderArgs += '-Clean' }
    if ($SkipBuild) { $builderArgs += '-SkipBuild' }
    if ($Force) { $builderArgs += '-Force' }
    if ($Version) {
        $builderArgs += '-Version'
        $builderArgs += $Version
    }
    $builderArgs += '-SkipInstaller'
}

& $BuilderScript @builderArgs
exit $LASTEXITCODE
