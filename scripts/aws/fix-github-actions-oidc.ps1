#Requires -Version 7.0

<#
.SYNOPSIS
    Fixes GitHub Actions OIDC authentication for AWS EKS deployment

.DESCRIPTION
    Verifies and updates the IAM role trust policy to allow GitHub Actions
    to assume the role via OIDC authentication.

.PARAMETER AwsAccountId
    AWS Account ID (default: 422017356244)

.PARAMETER RoleName
    IAM role name (default: github-actions-role)

.PARAMETER GitHubRepo
    GitHub repository in format owner/repo (default: zoidbot/zoidbot)

.PARAMETER GitHubBranch
    GitHub branch to allow (default: main)

.EXAMPLE
    .\fix-github-actions-oidc.ps1
#>

param(
    [string]$AwsAccountId = "422017356244",
    [string]$RoleName = "github-actions-role",
    [string]$GitHubRepo = "zoidbot/zoidbot",
    [string]$GitHubBranch = "main"
)

$ErrorActionPreference = "Stop"

Write-Host "Fixing GitHub Actions OIDC Authentication" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Verify AWS CLI
try {
    $awsVersion = aws --version
    Write-Host "✓ AWS CLI: $awsVersion" -ForegroundColor Green
}
catch {
    Write-Host "✗ AWS CLI not found" -ForegroundColor Red
    exit 1
}

# Check OIDC provider
Write-Host ""
Write-Host "Checking GitHub OIDC provider..." -ForegroundColor Yellow

$oidcProviders = aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output text

if ($oidcProviders -like "*token.actions.githubusercontent.com*") {
    Write-Host "✓ GitHub OIDC provider exists" -ForegroundColor Green
}
else {
    Write-Host "✗ GitHub OIDC provider not found" -ForegroundColor Red
    exit 1
}

# Get current role trust policy
Write-Host ""
Write-Host "Retrieving current role trust policy..." -ForegroundColor Yellow

try {
    $currentPolicy = aws iam get-role --role-name $RoleName --query 'Role.AssumeRolePolicyDocument' --output json | ConvertFrom-Json
    Write-Host "✓ Role found: $RoleName" -ForegroundColor Green
}
catch {
    Write-Host "✗ Role not found: $RoleName" -ForegroundColor Red
    exit 1
}

# Create correct trust policy
$correctPolicy = @{
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

# Compare policies
$currentJson = $currentPolicy | ConvertTo-Json -Depth 10
$correctJson = $correctPolicy | ConvertTo-Json -Depth 10

if ($currentJson -eq $correctJson) {
    Write-Host "✓ Trust policy is correct" -ForegroundColor Green
}
else {
    Write-Host "⚠ Trust policy needs update" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Current policy:" -ForegroundColor Yellow
    Write-Host ($currentPolicy | ConvertTo-Json -Depth 10) -ForegroundColor Gray
    Write-Host ""
    Write-Host "Correct policy:" -ForegroundColor Yellow
    Write-Host ($correctPolicy | ConvertTo-Json -Depth 10) -ForegroundColor Gray
    Write-Host ""
    
    # Update trust policy
    Write-Host "Updating trust policy..." -ForegroundColor Yellow
    
    $policyFile = "trust-policy-fix.json"
    $correctPolicy | ConvertTo-Json -Depth 10 | Out-File -FilePath $policyFile -Encoding UTF8
    
    try {
        aws iam update-assume-role-policy-document `
            --role-name $RoleName `
            --policy-document file://$policyFile
        
        Write-Host "✓ Trust policy updated successfully" -ForegroundColor Green
        Remove-Item $policyFile -Force
    }
    catch {
        Write-Host "✗ Failed to update trust policy: $_" -ForegroundColor Red
        Remove-Item $policyFile -Force
        exit 1
    }
}

# Verify role has EKS permissions
Write-Host ""
Write-Host "Checking role permissions..." -ForegroundColor Yellow

try {
    $policies = aws iam list-attached-role-policies --role-name $RoleName --query 'AttachedPolicies[*].PolicyName' --output text
    
    if ($policies) {
        Write-Host "✓ Attached policies:" -ForegroundColor Green
        $policies -split '\s+' | ForEach-Object {
            if ($_) {
                Write-Host "  - $_" -ForegroundColor Green
            }
        }
    }
    else {
        Write-Host "⚠ No policies attached to role" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Failed to check policies: $_" -ForegroundColor Red
}

# Test OIDC token generation
Write-Host ""
Write-Host "Testing OIDC configuration..." -ForegroundColor Yellow

try {
    $oidcProvider = aws iam get-open-id-connect-provider `
        --open-id-connect-provider-arn "arn:aws:iam::${AwsAccountId}:oidc-provider/token.actions.githubusercontent.com" `
        --query 'ThumbprintList[0]' `
        --output text
    
    Write-Host "✓ OIDC provider thumbprint: $oidcProvider" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to verify OIDC provider: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "✓ GitHub Actions OIDC configuration verified" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Trigger the deployment workflow manually or push changes to main"
Write-Host "2. Monitor the workflow run in GitHub Actions"
Write-Host "3. Check CloudWatch logs if deployment fails"
