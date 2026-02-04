<#
.SYNOPSIS
    Applies OIDC trust policy using AWS API directly

.DESCRIPTION
    Uses AWS Signature Version 4 to call IAM API directly without AWS CLI.

.EXAMPLE
    .\apply-oidc-via-api.ps1
#>

param(
    [string]$RoleName = "github-actions-role",
    [string]$AwsAccountId = "422017356244",
    [string]$GitHubRepo = "zoidbot/zoidbot",
    [string]$AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"

Write-Host "GitHub Actions OIDC Trust Policy Setup (API)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
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

Write-Host ""
Write-Host "✓ Credentials received" -ForegroundColor Green
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

# AWS API parameters
$service = "iam"
$host = "iam.amazonaws.com"
$method = "POST"
$action = "UpdateAssumeRolePolicy"
$version = "2010-05-08"

# Build request body
$body = "Action=$action&RoleName=$RoleName&PolicyDocument=$([System.Web.HttpUtility]::UrlEncode($policyJson))&Version=$version"

Write-Host "Calling AWS IAM API..." -ForegroundColor Yellow
Write-Host "Action: $action" -ForegroundColor Gray
Write-Host "Role: $RoleName" -ForegroundColor Gray
Write-Host ""

try {
    # Create signature
    $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ")
    $datestamp = [DateTime]::UtcNow.ToString("yyyyMMdd")
    
    # Create canonical request
    $canonicalRequest = @(
        $method,
        "/",
        "",
        "host:$host",
        "",
        "host",
        (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($body))) -Algorithm SHA256).Hash.ToLower()
    ) -join "`n"
    
    # Create string to sign
    $credentialScope = "$datestamp/$AwsRegion/$service/aws4_request"
    $canonicalRequestHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($canonicalRequest))) -Algorithm SHA256).Hash.ToLower()
    
    $stringToSign = @(
        "AWS4-HMAC-SHA256",
        $timestamp,
        $credentialScope,
        $canonicalRequestHash
    ) -join "`n"
    
    # Calculate signature
    $kDate = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes("AWS4$secretAccessKeyPlain")).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($datestamp))
    $kRegion = [System.Security.Cryptography.HMACSHA256]::new($kDate).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($AwsRegion))
    $kService = [System.Security.Cryptography.HMACSHA256]::new($kRegion).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($service))
    $kSigning = [System.Security.Cryptography.HMACSHA256]::new($kService).ComputeHash([System.Text.Encoding]::UTF8.GetBytes("aws4_request"))
    $signature = [System.Security.Cryptography.HMACSHA256]::new($kSigning).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($stringToSign))
    $signatureHex = [System.BitConverter]::ToString($signature).Replace("-", "").ToLower()
    
    # Create authorization header
    $authorizationHeader = "AWS4-HMAC-SHA256 Credential=$accessKeyId/$credentialScope, SignedHeaders=host, Signature=$signatureHex"
    
    # Make request
    $headers = @{
        "Authorization" = $authorizationHeader
        "X-Amz-Date" = $timestamp
        "Content-Type" = "application/x-www-form-urlencoded"
    }
    
    $response = Invoke-WebRequest `
        -Uri "https://$host/" `
        -Method $method `
        -Headers $headers `
        -Body $body `
        -ErrorAction Stop
    
    Write-Host "✓ Trust policy updated successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response:" -ForegroundColor Yellow
    Write-Host $response.Content -ForegroundColor Gray
}
catch {
    Write-Host "✗ Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✓ OIDC trust policy applied successfully" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Trigger Deploy to AWS EKS workflow in GitHub"
Write-Host "2. Monitor the workflow"
Write-Host "3. Delete the root API key"
