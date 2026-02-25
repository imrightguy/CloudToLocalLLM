#!/bin/bash

set -e

STACK_NAME="github-actions-oidc-role"
TEMPLATE_FILE="config/cloudformation/github-actions-oidc-role.yaml"
AWS_REGION="${AWS_REGION:-us-east-1}"
GITHUB_ORG_REPO="${GITHUB_ORG_REPO:-CloudToLocalLLM/CloudToLocalLLM}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"

echo "Deploying GitHub Actions OIDC Role"
echo "===================================="
echo ""
echo "Stack Name: $STACK_NAME"
echo "Region: $AWS_REGION"
echo "GitHub Repo: $GITHUB_ORG_REPO"
echo "GitHub Branch: $GITHUB_BRANCH"
echo ""

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found: $TEMPLATE_FILE"
    exit 1
fi

# Deploy or update stack
echo "Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --parameter-overrides \
        GitHubOrgRepo="$GITHUB_ORG_REPO" \
        GitHubBranch="$GITHUB_BRANCH" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset

echo ""
echo "Stack deployment complete!"
echo ""

# Get outputs
echo "Stack Outputs:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$AWS_REGION" \
    --query 'Stacks[0].Outputs' \
    --output table

echo ""
echo "✓ GitHub Actions OIDC role deployed successfully"
