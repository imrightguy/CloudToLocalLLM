#!/bin/bash

# AWS OIDC Provider Setup for GitHub Actions
# This script creates an OIDC provider in AWS to trust GitHub Actions
# Requirements: AWS CLI configured with appropriate credentials

set -e

# Configuration
AWS_ACCOUNT_ID="422017356244"
GITHUB_REPO="CloudToLocalLLM/CloudToLocalLLM"
OIDC_PROVIDER_URL="token.actions.githubusercontent.com"
OIDC_AUDIENCE="sts.amazonaws.com"

echo "=========================================="
echo "AWS OIDC Provider Setup for GitHub Actions"
echo "=========================================="
echo ""
echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "GitHub Repository: $GITHUB_REPO"
echo "OIDC Provider URL: $OIDC_PROVIDER_URL"
echo ""

# Step 1: Check if OIDC provider already exists
echo "Step 1: Checking if OIDC provider already exists..."
EXISTING_PROVIDER=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?Arn=='arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER_URL'].Arn" --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_PROVIDER" ]; then
    echo "✓ OIDC provider already exists: $EXISTING_PROVIDER"
else
    echo "Creating new OIDC provider..."
    
    # Get the thumbprint for the OIDC provider
    echo "Fetching OIDC provider certificate thumbprint..."
    THUMBPRINT=$(echo | openssl s_client -servername $OIDC_PROVIDER_URL -connect $OIDC_PROVIDER_URL:443 2>/dev/null | openssl x509 -fingerprint -noout | sed 's/://g' | awk '{print $NF}')
    
    if [ -z "$THUMBPRINT" ]; then
        echo "Error: Could not fetch OIDC provider thumbprint"
        exit 1
    fi
    
    echo "Thumbprint: $THUMBPRINT"
    
    # Create OIDC provider
    aws iam create-open-id-connect-provider \
        --url "https://$OIDC_PROVIDER_URL" \
        --client-id-list "$OIDC_AUDIENCE" \
        --thumbprint-list "$THUMBPRINT" \
        --region us-east-1
    
    echo "✓ OIDC provider created successfully"
fi

echo ""
echo "Step 2: Creating IAM role for GitHub Actions..."

# Create trust policy document
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER_URL"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "$OIDC_PROVIDER_URL:aud": "$OIDC_AUDIENCE"
        },
        "StringLike": {
          "$OIDC_PROVIDER_URL:sub": "repo:$GITHUB_REPO:ref:refs/heads/main"
        }
      }
    }
  ]
}
EOF

# Check if role already exists
ROLE_NAME="github-actions-role"
EXISTING_ROLE=$(aws iam get-role --role-name $ROLE_NAME 2>/dev/null || echo "")

if [ -n "$EXISTING_ROLE" ]; then
    echo "✓ IAM role already exists: $ROLE_NAME"
    echo "Updating trust policy..."
    aws iam update-assume-role-policy-document \
        --role-name $ROLE_NAME \
        --policy-document file:///tmp/trust-policy.json
    echo "✓ Trust policy updated"
else
    echo "Creating new IAM role..."
    aws iam create-role \
        --role-name $ROLE_NAME \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "Role for GitHub Actions to deploy to AWS EKS"
    echo "✓ IAM role created: $ROLE_NAME"
fi

echo ""
echo "Step 3: Attaching policies to IAM role..."

# Policies to attach
POLICIES=(
    "arn:aws:iam::aws:policy/AmazonEKSFullAccess"
    "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
    "arn:aws:iam::aws:policy/AmazonECRFullAccess"
    "arn:aws:iam::aws:policy/CloudWatchFullAccess"
    "arn:aws:iam::aws:policy/IAMFullAccess"
)

for policy in "${POLICIES[@]}"; do
    echo "Attaching policy: $policy"
    aws iam attach-role-policy \
        --role-name $ROLE_NAME \
        --policy-arn "$policy" 2>/dev/null || echo "  (Policy already attached)"
done

echo "✓ All policies attached"

echo ""
echo "Step 4: Verifying OIDC provider configuration..."

# Get OIDC provider details
OIDC_PROVIDER_ARN=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?Arn=='arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER_URL'].Arn" --output text)

if [ -n "$OIDC_PROVIDER_ARN" ]; then
    echo "✓ OIDC Provider ARN: $OIDC_PROVIDER_ARN"
    
    # Get provider details
    aws iam get-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_PROVIDER_ARN"
else
    echo "Error: Could not verify OIDC provider"
    exit 1
fi

echo ""
echo "Step 5: Getting IAM role ARN..."

ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
echo "✓ IAM Role ARN: $ROLE_ARN"

echo ""
echo "=========================================="
echo "✓ OIDC Provider Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Add the following to your GitHub Actions workflow:"
echo "   - uses: aws-actions/configure-aws-credentials@v2"
echo "     with:"
echo "       role-to-assume: $ROLE_ARN"
echo "       aws-region: us-east-1"
echo ""
echo "2. Verify OIDC authentication by running a test workflow"
echo ""
echo "Configuration saved to: /tmp/trust-policy.json"
echo ""
