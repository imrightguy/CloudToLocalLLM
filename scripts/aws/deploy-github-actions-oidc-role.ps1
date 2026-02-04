#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys GitHub Actions OIDC role via CloudFormation

.DESCRIPTION
    Creates or updates the IAM role for GitHub Actions OIDC authentication
    using CloudFormation template.

.PARAMETER StackName
    CloudFormation stack name (default: github-actions-oidc-role)

.PARAMETER AwsRegion
    AWS region (default: us-east-1)

.PARAMETER GitHubOrgRepo
    GitHub organization/repository (default: zoidbot/zoidbot)

.PARAMETER GitHubBranch
    GitHub branch to allow (default: main)

.EXAMPLE
    .\deploy-github-actions-oidc-role.ps1
    .\deploy-github-actions-oidc-role.ps1 -AwsRegion us-west-2
#>

param(
    [string]$StackName = "github-actions-oidc-role",
    [string]$AwsRegion = "us-east-1",
    [string]$GitHubOrgRepo = "zoidbot/zoidbot",
    [string]$GitHubBranch = "main"
)

$ErrorActionPreference = "Stop"

Write-Host "Deploying GitHub Actions OIDC Role" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Stack Name: $StackName" -ForegroundColor Yellow
Write-Host "Region: $AwsRegion" -ForegroundColor Yellow
Write-Host "GitHub Repo: $GitHubOrgRepo" -ForegroundColor Yellow
Write-Host "GitHub Branch: $GitHubBranch" -ForegroundColor Yellow
Write-Host ""

# Check template exists
$templateFile = "config/cloudformation/github-actions-oidc-role.yaml"
if (-not (Test-Path $templateFile)) {
    Write-Host "✗ Template file not found: $templateFile" -ForegroundColor Red
    exit 1
}

Write-Host "Deploying CloudFormation stack..." -ForegroundColor Yellow

try {
    aws cloudformation deploy `
        --template-file $templateFile `
        --stack-name $StackName `
        --region $AwsRegion `
        --parameter-overrides `
            GitHubOrgRepo=$GitHubOrgRepo `
            GitHubBranch=$GitHubBranch `
        --capabilities CAPABILITY_NAMED_IAM `
        --no-fail-on-empty-changeset
    
    Write-Host "✓ Stack deployment complete" -ForegroundColor Green
}
catch {
    Write-Host "✗ Stack deployment failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Stack Outputs:" -ForegroundColor Yellow

try {
    $outputs = aws cloudformation describe-stacks `
        --stack-name $StackName `
        --region $AwsRegion `
        --query 'Stacks[0].Outputs' `
        --output json | ConvertFrom-Json
    
    foreach ($output in $outputs) {
        Write-Host "  $($output.OutputKey): $($output.OutputValue)" -ForegroundColor Green
    }
}
catch {
    Write-Host "⚠ Could not retrieve stack outputs" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "✓ GitHub Actions OIDC role deployed successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Verify the role in AWS IAM console"
Write-Host "2. Trigger the deployment workflow in GitHub"
Write-Host "3. Monitor the workflow run"
