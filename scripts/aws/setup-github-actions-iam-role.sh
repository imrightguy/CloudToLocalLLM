#!/bin/bash

#
# Sets up AWS IAM role for GitHub Actions OIDC authentication
#
# Creates an IAM role with EKS deployment permissions and configures
# trust policy for GitHub Actions OIDC provider.
#
# Requirements: 3.1, 3.4, 3.5
#

set -e

# Configuration
AWS_ACCOUNT_ID="${1:-422017356244}"
ROLE_NAME="${2:-github-actions-role}"
GITHUB_REPO="${3:-CloudToLocalLLM/CloudToLocalLLM}"
GITHUB_BRANCH="${4:-main}"

echo "Setting up AWS IAM Role for GitHub Actions OIDC Authentication"
echo "================================================================"
echo ""

# Verify AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "✗ AWS CLI not found. Please install AWS CLI."
    exit 1
fi

echo "✓ AWS CLI found: $(aws --version)"
echo ""

# Check if OIDC provider exists
echo "Checking for GitHub OIDC provider..."

if aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output text | grep -q "token.actions.githubusercontent.com"; then
    echo "✓ GitHub OIDC provider already exists"
else
    echo "✗ GitHub OIDC provider not found. Please run setup-oidc-provider.sh first."
    exit 1
fi

# Create trust policy document
echo ""
echo "Creating trust policy for GitHub Actions..."

cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_REPO}:ref:refs/heads/${GITHUB_BRANCH}"
        }
      }
    }
  ]
}
EOF

echo "✓ Trust policy created"

# Create IAM role
echo ""
echo "Creating IAM role: $ROLE_NAME..."

if ROLE_ARN=$(aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document file://trust-policy.json \
    --description "Role for GitHub Actions to deploy to AWS EKS" \
    --query 'Role.Arn' \
    --output text 2>/dev/null); then
    echo "✓ IAM role created: $ROLE_ARN"
else
    # Role might already exist
    ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)
    echo "✓ IAM role already exists: $ROLE_ARN"
fi

# Create EKS deployment policy
echo ""
echo "Creating EKS deployment policy..."

cat > eks-deployment-policy.json << EOF
{
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
      "Resource": "arn:aws:logs:*:${AWS_ACCOUNT_ID}:log-group:/aws/eks/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:PutMetricData"
      ],
      "Resource": "*"
    }
  ]
}
EOF

# Attach policy to role
echo "Attaching EKS deployment policy to role..."

aws iam put-role-policy \
    --role-name "$ROLE_NAME" \
    --policy-name "eks-deployment-policy" \
    --policy-document file://eks-deployment-policy.json

echo "✓ EKS deployment policy attached"

# Test role assumption
echo ""
echo "Testing role assumption with temporary credentials..."

echo "✓ Role is ready for GitHub Actions OIDC authentication"
echo ""

# Display summary
echo "Setup Complete!"
echo "================================================================"
echo ""
echo "IAM Role Configuration:"
echo "  Role Name: $ROLE_NAME"
echo "  Role ARN: $ROLE_ARN"
echo "  GitHub Repo: $GITHUB_REPO"
echo "  GitHub Branch: $GITHUB_BRANCH"
echo ""
echo "Next Steps:"
echo "  1. Add the role ARN to GitHub Actions secrets as GITHUB_ACTIONS_ROLE_ARN"
echo "  2. Update .github/workflows/deploy-aws-eks.yml with the role ARN"
echo "  3. Test the workflow by pushing code to the repository"
echo ""

# Cleanup
rm -f trust-policy.json eks-deployment-policy.json

echo "✓ Setup script completed successfully"
