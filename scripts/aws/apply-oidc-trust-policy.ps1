<#
.SYNOPSIS
    Applies the OIDC trust policy to GitHub Actions role using AWS credentials

.DESCRIPTION
    Uses AWS credentials to update the IAM role trust policy for GitHub Actions OIDC.
    Requires AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables.

.PARAMETER RoleName
    IAM role name (default: github-actions-role)

.PARAMETER AwsAccountId
    AWS Account ID (default: 422017356244)

.PARAMETER GitHubRepo
    GitHub repository (default: zoidbot/zoidbot)

.PARAMETER AwsRegion
    AWS region (default: us-east-1)

.EXAMPLE
    $env:AWS_ACCESS_KEY_ID = "your-key-id"
    $env:AWS_SECRET_ACCESS_KEY = "your-secret-key"
    .\apply-oidc-trust-policy.ps1
#>

param(
    [string]$RoleName = "github-actions-role",
    [string]$AwsAccountId = "422017356244",
    [string]$GitHubRepo = "zoidbot/zoidbot",
    [string]$AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"

Write-Host "Applying GitHub Actions OIDC Trust Policy" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Check for AWS credentials
if (-not $env:AWS_ACCESS_KEY_ID -or -not $env:AWS_SECRET_ACCESS_KEY) {
    Write-Host "✗ AWS credentials not found in environment variables" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please set the following environment variables:" -ForegroundColor Yellow
    Write-Host "  `$env:AWS_ACCESS_KEY_ID = 'your-access-key-id'" -ForegroundColor Gray
    Write-Host "  `$env:AWS_SECRET_ACCESS_KEY = 'your-secret-access-key'" -ForegroundColor Gray
    exit 1
}

Write-Host "✓ AWS credentials found" -ForegroundColor Green
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
}

$policyJson = $trustPolicy | ConvertTo-Json -Depth 10

Write-Host "Trust Policy:" -ForegroundColor Yellow
Write-Host $policyJson -ForegroundColor Gray
Write-Host ""

# Save to file
$policyFile = "trust-policy-apply.json"
$policyJson | Out-File -FilePath $policyFile -Encoding UTF8

Write-Host "Updating IAM role trust policy..." -ForegroundColor Yellow
Write-Host "Role: $RoleName" -ForegroundColor Gray
Write-Host "Region: $AwsRegion" -ForegroundColor Gray
Write-Host ""

# Build AWS CLI command
$awsCmd = @(
    "iam",
    "update-assume-role-policy-document",
    "--role-name", $RoleName,
    "--policy-document", "file://$policyFile",
    "--region", $AwsRegion
)

try {
    # Call AWS CLI
    $output = & aws @awsCmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Trust policy updated successfully" -ForegroundColor Green
    }
    else {
        Write-Host "✗ Failed to update trust policy" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        Remove-Item $policyFile -Force
        exit 1
    }
}
catch {
    Write-Host "✗ Error executing AWS CLI: $_" -ForegroundColor Red
    Remove-Item $policyFile -Force
    exit 1
}

# Verify the update
Write-Host ""
Write-Host "Verifying trust policy..." -ForegroundColor Yellow

try {
    $verifyCmd = @(
        "iam",
        "get-role",
        "--role-name", $RoleName,
        "--query", "Role.AssumeRolePolicyDocument",
        "--output", "json",
        "--region", $AwsRegion
    )
    
    $verifyOutput = & aws @verifyCmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Trust policy verified" -ForegroundColor Green
        Write-Host ""
        Write-Host "Current Trust Policy:" -ForegroundColor Yellow
        Write-Host $verifyOutput -ForegroundColor Gray
    }
    else {
        Write-Host "⚠ Could not verify trust policy" -ForegroundColor Yellow
        Write-Host $verifyOutput -ForegroundColor Gray
    }
}
catch {
    Write-Host "⚠ Error verifying trust policy: $_" -ForegroundColor Yellow
}

# Cleanup
Remove-Item $policyFile -Force

Write-Host ""
Write-Host "✓ GitHub Actions OIDC trust policy applied successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Trigger the Deploy to AWS EKS workflow in GitHub"
Write-Host "2. Monitor the workflow run"
Write-Host "3. Delete the root API key after deployment succeeds"
