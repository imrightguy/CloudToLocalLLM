param(
    [string]$AwsAccountId = "422017356244",
    [string]$RoleName = "github-actions-role",
    [string]$GitHubRepo = "zoidbot/zoidbot",
    [string]$GitHubBranch = "main"
)

$ErrorActionPreference = "Stop"

Write-Host "Setting up AWS IAM Role for GitHub Actions OIDC Authentication" -ForegroundColor Cyan
Write-Host ""

try {
    $awsVersion = aws --version
    Write-Host "AWS CLI found: $awsVersion" -ForegroundColor Green
}
catch {
    Write-Host "AWS CLI not found. Please install AWS CLI." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Checking for GitHub OIDC provider..." -ForegroundColor Yellow

$oidcProviders = aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output text

if ($oidcProviders -like "*token.actions.githubusercontent.com*") {
    Write-Host "GitHub OIDC provider already exists" -ForegroundColor Green
}
else {
    Write-Host "GitHub OIDC provider not found. Please run setup-oidc-provider.ps1 first." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Creating trust policy for GitHub Actions..." -ForegroundColor Yellow

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
                    "token.actions.githubusercontent.com:sub" = "repo:${GitHubRepo}:ref:refs/heads/${GitHubBranch}"
                }
            }
        }
    )
} | ConvertTo-Json -Depth 10

$trustPolicyFile = "trust-policy.json"
$trustPolicy | Out-File -FilePath $trustPolicyFile -Encoding UTF8

Write-Host "Trust policy created" -ForegroundColor Green

Write-Host ""
Write-Host "Creating IAM role: $RoleName..." -ForegroundColor Yellow

try {
    $roleArn = aws iam create-role `
        --role-name $RoleName `
        --assume-role-policy-document file://$trustPolicyFile `
        --description "Role for GitHub Actions to deploy to AWS EKS" `
        --query 'Role.Arn' `
        --output text

    Write-Host "IAM role created: $roleArn" -ForegroundColor Green
}
catch {
    if ($_ -like "*EntityAlreadyExists*") {
        Write-Host "IAM role already exists" -ForegroundColor Green
        $roleArn = "arn:aws:iam::${AwsAccountId}:role/${RoleName}"
    }
    else {
        Write-Host "Failed to create IAM role: $_" -ForegroundColor Red
        Remove-Item $trustPolicyFile -Force
        exit 1
    }
}

Write-Host ""
Write-Host "Creating EKS deployment policy..." -ForegroundColor Yellow

$policyFile = "eks-deployment-policy.json"

$policyContent = '{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:AccessKubernetesApi"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:*:' + $AwsAccountId + ':log-group:/aws/eks/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}'

$policyContent | Out-File -FilePath $policyFile -Encoding UTF8

Write-Host "Attaching EKS deployment policy to role..." -ForegroundColor Yellow

try {
    aws iam put-role-policy `
        --role-name $RoleName `
        --policy-name "eks-deployment-policy" `
        --policy-document file://$policyFile

    Write-Host "EKS deployment policy attached" -ForegroundColor Green
}
catch {
    Write-Host "Failed to attach policy: $_" -ForegroundColor Red
    Remove-Item $trustPolicyFile, $policyFile -Force
    exit 1
}

Write-Host ""
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "IAM Role Configuration:" -ForegroundColor Cyan
Write-Host "  Role Name: $RoleName"
Write-Host "  Role ARN: $roleArn"
Write-Host "  GitHub Repo: $GitHubRepo"
Write-Host "  GitHub Branch: $GitHubBranch"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Add role ARN to GitHub Actions secrets as GITHUB_ACTIONS_ROLE_ARN"
Write-Host "  2. Update .github/workflows/deploy-aws-eks.yml with the role ARN"
Write-Host "  3. Test the workflow by pushing code to the repository"
Write-Host ""

Remove-Item $trustPolicyFile, $policyFile -Force

Write-Host "Setup script completed successfully" -ForegroundColor Green
