# AWS Infrastructure Setup with Root Credentials
# This script configures AWS CLI with provided credentials and sets up OIDC provider

param(
    [string]$AccessKeyId,
    [string]$SecretAccessKey,
    [string]$AwsAccountId = "422017356244",
    [string]$GitHubRepo = "zoidbot/zoidbot",
    [string]$AwsRegion = "us-east-1"
)

$ErrorActionPreference = "Stop"

# Validate inputs
if (-not $AccessKeyId -or -not $SecretAccessKey) {
    Write-Host "Error: AccessKeyId and SecretAccessKey are required" -ForegroundColor Red
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\setup-aws-infrastructure.ps1 -AccessKeyId <KEY_ID> -SecretAccessKey <SECRET_KEY>" -ForegroundColor White
    exit 1
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "AWS Infrastructure Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Configure AWS CLI
Write-Host "Step 1: Configuring AWS CLI with provided credentials..." -ForegroundColor Yellow

try {
    # Create AWS credentials directory if it doesn't exist
    $awsCredentialsDir = "$env:USERPROFILE\.aws"
    if (-not (Test-Path $awsCredentialsDir)) {
        New-Item -ItemType Directory -Path $awsCredentialsDir -Force | Out-Null
    }
    
    # Create credentials file
    $credentialsContent = @"
[default]
aws_access_key_id = $AccessKeyId
aws_secret_access_key = $SecretAccessKey
"@
    
    $credentialsFile = "$awsCredentialsDir\credentials"
    $credentialsContent | Out-File -FilePath $credentialsFile -Encoding UTF8 -Force
    
    # Create config file
    $configContent = @"
[default]
region = $AwsRegion
output = json
"@
    
    $configFile = "$awsCredentialsDir\config"
    $configContent | Out-File -FilePath $configFile -Encoding UTF8 -Force
    
    Write-Host "✓ AWS CLI configured" -ForegroundColor Green
    Write-Host "  Credentials file: $credentialsFile" -ForegroundColor Gray
    Write-Host "  Config file: $configFile" -ForegroundColor Gray
}
catch {
    Write-Host "✗ Error configuring AWS CLI: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Verify AWS credentials
Write-Host "Step 2: Verifying AWS credentials..." -ForegroundColor Yellow

try {
    $identity = aws sts get-caller-identity | ConvertFrom-Json
    Write-Host "✓ AWS credentials verified" -ForegroundColor Green
    Write-Host "  Account ID: $($identity.Account)" -ForegroundColor Green
    Write-Host "  User ARN: $($identity.Arn)" -ForegroundColor Green
    Write-Host "  User ID: $($identity.UserId)" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error verifying AWS credentials: $_" -ForegroundColor Red
    Write-Host "  Please check your Access Key ID and Secret Access Key" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 3: Create OIDC Provider
Write-Host "Step 3: Creating OIDC Provider..." -ForegroundColor Yellow

$OidcProviderUrl = "token.actions.githubusercontent.com"
$OidcAudience = "sts.amazonaws.com"

try {
    # Check if OIDC provider already exists
    $existingProviders = aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?Arn=='arn:aws:iam::$($AwsAccountId):oidc-provider/$OidcProviderUrl'].Arn" --output text 2>$null
    
    if ($existingProviders) {
        Write-Host "✓ OIDC provider already exists" -ForegroundColor Green
    }
    else {
        Write-Host "  Creating new OIDC provider..." -ForegroundColor Yellow
        
        # Get the thumbprint for the OIDC provider
        Write-Host "  Fetching OIDC provider certificate thumbprint..." -ForegroundColor Gray
        
        $thumbprint = "6938fd4d98bab03faadb97b34396831e3780aea1"  # GitHub's OIDC provider thumbprint
        
        # Create OIDC provider
        aws iam create-open-id-connect-provider `
            --url "https://$OidcProviderUrl" `
            --client-id-list $OidcAudience `
            --thumbprint-list $thumbprint `
            --region $AwsRegion
        
        Write-Host "✓ OIDC provider created" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Error creating OIDC provider: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 4: Create IAM Role
Write-Host "Step 4: Creating IAM Role for GitHub Actions..." -ForegroundColor Yellow

$RoleName = "github-actions-role"

try {
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
    
    # Check if role already exists
    $existingRole = aws iam get-role --role-name $RoleName 2>$null
    
    if ($existingRole) {
        Write-Host "✓ IAM role already exists" -ForegroundColor Green
        Write-Host "  Updating trust policy..." -ForegroundColor Yellow
        aws iam update-assume-role-policy-document `
            --role-name $RoleName `
            --policy-document "file://$trustPolicyPath"
        Write-Host "✓ Trust policy updated" -ForegroundColor Green
    }
    else {
        Write-Host "  Creating new IAM role..." -ForegroundColor Yellow
        aws iam create-role `
            --role-name $RoleName `
            --assume-role-policy-document "file://$trustPolicyPath" `
            --description "Role for GitHub Actions to deploy to AWS EKS"
        Write-Host "✓ IAM role created" -ForegroundColor Green
    }
}
catch {
    Write-Host "✗ Error creating IAM role: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 5: Attach Policies
Write-Host "Step 5: Attaching policies to IAM role..." -ForegroundColor Yellow

$policies = @(
    "arn:aws:iam::aws:policy/AmazonEKSFullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess",
    "arn:aws:iam::aws:policy/AmazonECRFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchFullAccess",
    "arn:aws:iam::aws:policy/IAMFullAccess"
)

try {
    foreach ($policy in $policies) {
        $policyName = $policy.Split("/")[-1]
        Write-Host "  Attaching $policyName..." -ForegroundColor Gray
        aws iam attach-role-policy `
            --role-name $RoleName `
            --policy-arn $policy 2>$null
    }
    Write-Host "✓ All policies attached" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error attaching policies: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 6: Get Role ARN
Write-Host "Step 6: Getting IAM role ARN..." -ForegroundColor Yellow

try {
    $role = aws iam get-role --role-name $RoleName | ConvertFrom-Json
    $roleArn = $role.Role.Arn
    Write-Host "✓ IAM Role ARN: $roleArn" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error getting IAM role ARN: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 7: Save Configuration
Write-Host "Step 7: Saving configuration..." -ForegroundColor Yellow

try {
    $config = @{
        AwsAccountId = $AwsAccountId
        GitHubRepo = $GitHubRepo
        OidcProviderUrl = $OidcProviderUrl
        OidcAudience = $OidcAudience
        RoleName = $RoleName
        RoleArn = $roleArn
        AwsRegion = $AwsRegion
        SetupDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $configPath = "scripts/aws/aws-config.json"
    $config | ConvertTo-Json | Out-File -FilePath $configPath -Encoding UTF8
    Write-Host "✓ Configuration saved to $configPath" -ForegroundColor Green
}
catch {
    Write-Host "✗ Error saving configuration: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "✓ AWS Infrastructure Setup Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration Summary:" -ForegroundColor Cyan
Write-Host "  AWS Account ID: $AwsAccountId" -ForegroundColor White
Write-Host "  GitHub Repository: $GitHubRepo" -ForegroundColor White
Write-Host "  OIDC Provider: $OidcProviderUrl" -ForegroundColor White
Write-Host "  IAM Role Name: $RoleName" -ForegroundColor White
Write-Host "  IAM Role ARN: $roleArn" -ForegroundColor White
Write-Host "  AWS Region: $AwsRegion" -ForegroundColor White
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. The GitHub Actions workflow is already configured with the role ARN" -ForegroundColor White
Write-Host "2. Add AWS credentials to GitHub Secrets (if needed for other workflows)" -ForegroundColor White
Write-Host "3. Test the deployment by pushing code to main branch" -ForegroundColor White
Write-Host ""
