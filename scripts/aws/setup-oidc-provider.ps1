# AWS OIDC Provider Setup for GitHub Actions (PowerShell)
# This script creates an OIDC provider in AWS to trust GitHub Actions
# Requirements: AWS CLI configured with appropriate credentials

param(
    [string]$AwsAccountId = "422017356244",
    [string]$GitHubRepo = "zoidbot/zoidbot",
    [string]$OidcProviderUrl = "token.actions.githubusercontent.com",
    [string]$OidcAudience = "sts.amazonaws.com",
    [string]$AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "AWS OIDC Provider Setup for GitHub Actions" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "AWS Account ID: $AwsAccountId"
Write-Host "GitHub Repository: $GitHubRepo"
Write-Host "OIDC Provider URL: $OidcProviderUrl"
Write-Host ""

# Step 1: Check if OIDC provider already exists
Write-Host "Step 1: Checking if OIDC provider already exists..." -ForegroundColor Yellow

try {
    $existingProviders = aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?Arn=='arn:aws:iam::$($AwsAccountId):oidc-provider/$OidcProviderUrl'].Arn" --output text 2>$null
    
    if ($existingProviders) {
        Write-Host "✓ OIDC provider already exists: $existingProviders" -ForegroundColor Green
    }
    else {
        Write-Host "Creating new OIDC provider..." -ForegroundColor Yellow
        
        # Get the thumbprint for the OIDC provider
        Write-Host "Fetching OIDC provider certificate thumbprint..." -ForegroundColor Yellow
        
        $thumbprint = $null
        try {
            # Use PowerShell to get the certificate thumbprint
            $cert = [System.Net.ServicePointManager]::FindServicePoint("https://$OidcProviderUrl").Certificate
            if ($null -eq $cert) {
                # Fallback: use openssl if available
                $opensslOutput = openssl s_client -servername $OidcProviderUrl -connect "$($OidcProviderUrl):443" 2>$null | openssl x509 -fingerprint -noout 2>$null
                if ($opensslOutput) {
                    $thumbprint = ($opensslOutput -replace ":", "" -split " ")[-1]
                }
            }
            else {
                $thumbprint = $cert.GetCertHashString()
            }
        }
        catch {
            Write-Host "Warning: Could not fetch thumbprint automatically. Using default thumbprint." -ForegroundColor Yellow
            # GitHub's OIDC provider thumbprint (this may need to be updated)
            $thumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1"
        }
        
        if (-not $thumbprint) {
            Write-Host "Error: Could not fetch OIDC provider thumbprint" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Thumbprint: $thumbprint" -ForegroundColor Green
        
        # Create OIDC provider
        Write-Host "Creating OIDC provider in AWS..." -ForegroundColor Yellow
        aws iam create-open-id-connect-provider `
            --url "https://$OidcProviderUrl" `
            --client-id-list $OidcAudience `
            --thumbprint-list $thumbprint `
            --region $AwsRegion
        
        Write-Host "✓ OIDC provider created successfully" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error checking/creating OIDC provider: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Creating IAM role for GitHub Actions..." -ForegroundColor Yellow

# Create trust policy document
$trustPolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{
                Federated = "arn:aws:iam::$($AwsAccountId):oidc-provider/$OidcProviderUrl"
            }
            Action = "sts:AssumeRoleWithWebIdentity"
            Condition = @{
                StringEquals = @{
                    "$($OidcProviderUrl):aud" = $OidcAudience
                }
                StringLike = @{
                    "$($OidcProviderUrl):sub" = "repo:$($GitHubRepo):ref:refs/heads/main"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10

$trustPolicyPath = "$env:TEMP\trust-policy.json"
$trustPolicy | Out-File -FilePath $trustPolicyPath -Encoding UTF8

try {
    # Check if role already exists
    $roleName = "github-actions-role"
    $existingRole = aws iam get-role --role-name $roleName 2>$null
    
    if ($existingRole) {
        Write-Host "✓ IAM role already exists: $roleName" -ForegroundColor Green
        Write-Host "Updating trust policy..." -ForegroundColor Yellow
        aws iam update-assume-role-policy-document `
            --role-name $roleName `
            --policy-document "file://$trustPolicyPath"
        Write-Host "✓ Trust policy updated" -ForegroundColor Green
    }
    else {
        Write-Host "Creating new IAM role..." -ForegroundColor Yellow
        aws iam create-role `
            --role-name $roleName `
            --assume-role-policy-document "file://$trustPolicyPath" `
            --description "Role for GitHub Actions to deploy to AWS EKS"
        Write-Host "✓ IAM role created: $roleName" -ForegroundColor Green
    }
}
catch {
    Write-Host "Error creating/updating IAM role: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Attaching policies to IAM role..." -ForegroundColor Yellow

$policies = @(
    "arn:aws:iam::aws:policy/AmazonEKSFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonECRFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchFullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess"
)

foreach ($policy in $policies) {
    Write-Host "Attaching policy: $policy" -ForegroundColor Yellow
    try {
        aws iam attach-role-policy `
            --role-name $roleName `
            --policy-arn $policy 2>$null
        Write-Host "  ✓ Attached" -ForegroundColor Green
    }
    catch {
        Write-Host "  (Policy already attached)" -ForegroundColor Gray
    }
}

Write-Host "✓ All policies attached" -ForegroundColor Green

Write-Host ""
Write-Host "Step 4: Verifying OIDC provider configuration..." -ForegroundColor Yellow

try {
    # Get OIDC provider details
    $oidcProviderArn = aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?Arn=='arn:aws:iam::$($AwsAccountId):oidc-provider/$OidcProviderUrl'].Arn" --output text
    
    if ($oidcProviderArn) {
        Write-Host "✓ OIDC Provider ARN: $oidcProviderArn" -ForegroundColor Green
        
        # Get provider details
        Write-Host ""
        Write-Host "OIDC Provider Details:" -ForegroundColor Cyan
        aws iam get-open-id-connect-provider --open-id-connect-provider-arn $oidcProviderArn | ConvertFrom-Json | Format-List
    }
    else {
        Write-Host "Error: Could not verify OIDC provider" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Error verifying OIDC provider: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 5: Getting IAM role ARN..." -ForegroundColor Yellow

try {
    $roleArn = aws iam get-role --role-name $roleName --query 'Role.Arn' --output text
    Write-Host "✓ IAM Role ARN: $roleArn" -ForegroundColor Green
}
catch {
    Write-Host "Error getting IAM role ARN: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "✓ OIDC Provider Setup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Add the following to your GitHub Actions workflow:" -ForegroundColor Yellow
Write-Host "   - uses: aws-actions/configure-aws-credentials@v2" -ForegroundColor White
Write-Host "     with:" -ForegroundColor White
Write-Host "       role-to-assume: $roleArn" -ForegroundColor White
Write-Host "       aws-region: $AwsRegion" -ForegroundColor White
Write-Host ""
Write-Host "2. Verify OIDC authentication by running a test workflow" -ForegroundColor Yellow
Write-Host ""
Write-Host "Configuration saved to: $trustPolicyPath" -ForegroundColor Gray
Write-Host ""

# Save configuration to file for reference
$config = @{
    AwsAccountId = $AwsAccountId
    GitHubRepo = $GitHubRepo
    OidcProviderUrl = $OidcProviderUrl
    OidcAudience = $OidcAudience
    OidcProviderArn = $oidcProviderArn
    RoleName = $roleName
    RoleArn = $roleArn
    AwsRegion = $AwsRegion
    SetupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$configPath = "$PSScriptRoot\oidc-config.json"
$config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8
Write-Host "Configuration saved to: $configPath" -ForegroundColor Gray
