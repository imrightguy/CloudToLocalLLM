<#
.SYNOPSIS
    Applies OIDC trust policy with interactive credential prompt

.DESCRIPTION
    Prompts for AWS credentials and applies the OIDC trust policy.

.EXAMPLE
    .\apply-oidc-with-prompt.ps1
#>

param(
    [string]$RoleName = "github-actions-role",
    [string]$AwsAccountId = "422017356244",
    [string]$GitHubRepo = "zoidbot/zoidbot",
    [string]$AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"

Write-Host "GitHub Actions OIDC Trust Policy Setup" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# Prompt for credentials
Write-Host "Enter AWS Root Credentials:" -ForegroundColor Yellow
Write-Host ""

$accessKeyId = Read-Host "AWS Access Key ID"
$secretAccessKey = Read-Host "AWS Secret Access Key" -AsSecureString
$secretAccessKeyPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secretAccessKey))

if (-not $accessKeyId -or -not $secretAccessKeyPlain) {
    Write-Host "✗ Credentials cannot be empty" -ForegroundColor Red
    exit 1
}

# Set environment variables
$env:AWS_ACCESS_KEY_ID = $accessKeyId
$env:AWS_SECRET_ACCESS_KEY = $secretAccessKeyPlain
$env:AWS_DEFAULT_REGION = $AwsRegion

Write-Host ""
Write-Host "✓ Credentials set" -ForegroundColor Green
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

try {
    # Call AWS CLI
    $output = & aws iam update-assume-role-policy-document `
        --role-name $RoleName `
        --policy-document file://$policyFile `
        --region $AwsRegion 2>&1
    
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
    Write-Host "✗ Error: $_" -ForegroundColor Red
    Remove-Item $policyFile -Force
    exit 1
}

# Verify
Write-Host ""
Write-Host "Verifying trust policy..." -ForegroundColor Yellow

try {
    $verifyOutput = & aws iam get-role `
        --role-name $RoleName `
        --query "Role.AssumeRolePolicyDocument" `
        --output json `
        --region $AwsRegion 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Trust policy verified" -ForegroundColor Green
        Write-Host ""
        Write-Host "Current Trust Policy:" -ForegroundColor Yellow
        Write-Host $verifyOutput -ForegroundColor Gray
    }
}
catch {
    Write-Host "⚠ Could not verify: $_" -ForegroundColor Yellow
}

# Cleanup
Remove-Item $policyFile -Force
$env:AWS_ACCESS_KEY_ID = ""
$env:AWS_SECRET_ACCESS_KEY = ""

Write-Host ""
Write-Host "✓ OIDC trust policy applied successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Trigger Deploy to AWS EKS workflow in GitHub"
Write-Host "2. Monitor the workflow"
Write-Host "3. Delete the root API key"
