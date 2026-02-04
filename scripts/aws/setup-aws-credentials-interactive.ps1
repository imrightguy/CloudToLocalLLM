param([switch]$SkipValidation)

$ErrorActionPreference = "Stop"

Write-Host "AWS Credentials Setup for Zoidbot CI/CD" -ForegroundColor Cyan
Write-Host ""

Write-Host "Enter your AWS credentials:" -ForegroundColor Yellow
Write-Host ""

$accessKeyId = Read-Host "AWS Access Key ID"
if ([string]::IsNullOrWhiteSpace($accessKeyId)) {
    Write-Host "Error: Access Key ID cannot be empty" -ForegroundColor Red
    exit 1
}

$secretAccessKey = Read-Host "AWS Secret Access Key" -AsSecureString
$secretAccessKeyPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($secretAccessKey))

if ([string]::IsNullOrWhiteSpace($secretAccessKeyPlain)) {
    Write-Host "Error: Secret Access Key cannot be empty" -ForegroundColor Red
    exit 1
}

$region = Read-Host "AWS Region (default: us-east-1)"
if ([string]::IsNullOrWhiteSpace($region)) {
    $region = "us-east-1"
}

Write-Host ""
Write-Host "Configuring AWS credentials..." -ForegroundColor Cyan

$awsDir = "$env:USERPROFILE\.aws"
if (-not (Test-Path $awsDir)) {
    New-Item -ItemType Directory -Path $awsDir -Force | Out-Null
    Write-Host "Created $awsDir" -ForegroundColor Green
}

try {
    aws configure set aws_access_key_id $accessKeyId
    aws configure set aws_secret_access_key $secretAccessKeyPlain
    aws configure set region $region
    Write-Host "Credentials configured successfully" -ForegroundColor Green
}
catch {
    Write-Host "Error configuring credentials: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

if (-not $SkipValidation) {
    Write-Host "Validating credentials..." -ForegroundColor Cyan
    $result = aws sts get-caller-identity 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Credentials validated successfully" -ForegroundColor Green
        Write-Host ""
        Write-Host "Account Information:" -ForegroundColor Yellow
        $result | ConvertFrom-Json | Format-Table -AutoSize
    }
    else {
        Write-Host "Credential validation failed" -ForegroundColor Red
        Write-Host ""
        Write-Host "Error details:" -ForegroundColor Yellow
        Write-Host $result
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "1. Verify Access Key ID and Secret Access Key are correct"
        Write-Host "2. Check if credentials are active in AWS IAM console"
        Write-Host "3. If using MFA, use temporary credentials from aws sts get-session-token"
        Write-Host "4. Check for account restrictions or SCPs"
        Write-Host ""
        
        $retry = Read-Host "Try different credentials? (y/n)"
        if ($retry -eq "y") {
            & $PSCommandPath
        }
        exit 1
    }
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: .\scripts\aws\setup-github-actions-iam-role.ps1"
Write-Host "2. Run: .\scripts\aws\setup-oidc-provider.ps1"
Write-Host "3. Configure GitHub Actions secrets with the IAM role ARN"
Write-Host ""

$secretAccessKeyPlain = $null
[System.GC]::Collect()
