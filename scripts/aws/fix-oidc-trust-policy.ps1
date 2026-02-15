#Requires -Modules @{ ModuleName='AWS.Tools.IdentityManagement'; ModuleVersion='4.0' }

<#
.SYNOPSIS
    Fixes GitHub Actions OIDC trust policy for EKS deployment

.DESCRIPTION
    Updates the IAM role trust policy to allow GitHub Actions OIDC authentication.
    Uses AWS PowerShell tools directly.

.PARAMETER RoleName
    IAM role name (default: github-actions-role)

.PARAMETER AwsAccountId
    AWS Account ID (default: 422017356244)

.PARAMETER GitHubRepo
    GitHub repository (default: zoidbot/zoidbot)

.EXAMPLE
    .\fix-oidc-trust-policy.ps1
#>

param(
    [string]$RoleName = "github-actions-role",
    [string]$AwsAccountId = "422017356244",
    [string]$GitHubRepo = "zoidbot/zoidbot"
)

$ErrorActionPreference = "Stop"

Write-Host "Fixing GitHub Actions OIDC Trust Policy" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Create trust policy
$trustPolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{
                Federated = "arn:aws:iam::${AwsAccountId}:oidc-provider/token.actions.githubusercontent.com"
            }
            Action = "sts:AssumeRoleWithWebIdentity"
            Condition = @{
                StringEquals = @{
                    "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
                }
                StringLike = @{
                    "token.actions.githubusercontent.com:sub" = "repo:${GitHubRepo}:*"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10

Write-Host "Trust Policy:" -ForegroundColor Yellow
Write-Host $trustPolicy -ForegroundColor Gray
Write-Host ""

# Save to file
$policyFile = "trust-policy.json"
$trustPolicy | Out-File -FilePath $policyFile -Encoding UTF8

Write-Host "Updating IAM role trust policy..." -ForegroundColor Yellow

try {
    # Update the role's assume role policy
    Update-IAMAssumeRolePolicy `
        -RoleName $RoleName `
        -PolicyDocument (Get-Content -Path $policyFile -Raw) `
        -ErrorAction Stop
    
    Write-Host "✓ Trust policy updated successfully" -ForegroundColor Green
    Remove-Item $policyFile -Force
}
catch {
    Write-Host "✗ Failed to update trust policy: $_" -ForegroundColor Red
    Remove-Item $policyFile -Force
    exit 1
}

# Verify the update
Write-Host ""
Write-Host "Verifying trust policy..." -ForegroundColor Yellow

try {
    $role = Get-IAMRole -RoleName $RoleName -ErrorAction Stop
    $currentPolicy = $role.AssumeRolePolicyDocument | ConvertFrom-Json
    
    Write-Host "✓ Role trust policy verified" -ForegroundColor Green
    Write-Host ""
    Write-Host "Current Trust Policy:" -ForegroundColor Yellow
    Write-Host ($currentPolicy | ConvertTo-Json -Depth 10) -ForegroundColor Gray
}
catch {
    Write-Host "✗ Failed to verify trust policy: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✓ GitHub Actions OIDC trust policy fixed successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Trigger the deployment workflow in GitHub"
Write-Host "2. Monitor the workflow run"
Write-Host "3. Check CloudWatch logs if deployment fails"
