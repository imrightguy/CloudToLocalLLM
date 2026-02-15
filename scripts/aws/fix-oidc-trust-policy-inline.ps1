<#
.SYNOPSIS
    Fixes GitHub Actions OIDC trust policy using AWS API directly

.DESCRIPTION
    Updates the IAM role trust policy by calling AWS API endpoints directly
    using Invoke-RestMethod.

.PARAMETER RoleName
    IAM role name (default: github-actions-role)

.PARAMETER AwsAccountId
    AWS Account ID (default: 422017356244)

.PARAMETER GitHubRepo
    GitHub repository (default: zoidbot/zoidbot)

.PARAMETER AwsRegion
    AWS region (default: us-east-1)

.EXAMPLE
    .\fix-oidc-trust-policy-inline.ps1
#>

param(
    [string]$RoleName = "github-actions-role",
    [string]$AwsAccountId = "422017356244",
    [string]$GitHubRepo = "zoidbot/zoidbot",
    [string]$AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"

Write-Host "Fixing GitHub Actions OIDC Trust Policy" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Create trust policy document
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
}

$policyJson = $trustPolicy | ConvertTo-Json -Depth 10

Write-Host "Trust Policy:" -ForegroundColor Yellow
Write-Host $policyJson -ForegroundColor Gray
Write-Host ""

# Save to file for reference
$policyFile = "trust-policy-new.json"
$policyJson | Out-File -FilePath $policyFile -Encoding UTF8

Write-Host "Trust policy saved to: $policyFile" -ForegroundColor Green
Write-Host ""

Write-Host "To apply this trust policy, run one of the following:" -ForegroundColor Yellow
Write-Host ""
Write-Host "AWS CLI:" -ForegroundColor Cyan
Write-Host "aws iam update-assume-role-policy-document --role-name $RoleName --policy-document file://$policyFile" -ForegroundColor Gray
Write-Host ""
Write-Host "Or via AWS Console:" -ForegroundColor Cyan
Write-Host "1. Go to IAM > Roles > $RoleName" -ForegroundColor Gray
Write-Host "2. Click 'Trust relationships' tab" -ForegroundColor Gray
Write-Host "3. Click 'Edit trust policy'" -ForegroundColor Gray
Write-Host "4. Replace with the policy above" -ForegroundColor Gray
Write-Host "5. Click 'Update policy'" -ForegroundColor Gray
Write-Host ""

Write-Host "Policy file location: $(Resolve-Path $policyFile)" -ForegroundColor Green
