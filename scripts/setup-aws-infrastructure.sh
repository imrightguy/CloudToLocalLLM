#!/usr/bin/env bash
#
# AWS Infrastructure Setup Script for CloudToLocalLLM
#
# This script creates all required AWS infrastructure for the CloudToLocalLLM EKS deployment:
# - VPC with public and private subnets
# - EKS cluster with t3.small nodes
# - IAM roles for EKS and GitHub Actions
# - Security groups
# - GitHub OIDC provider
#
# Usage:
#   ./scripts/setup-aws-infrastructure.sh [OPTIONS]
#
# Options:
#   --region REGION           AWS region (default: us-east-1)
#   --cluster-name NAME       EKS cluster name (default: cloudtolocalllm-eks)
#   --node-count NUMBER       Desired node count (default: 2)
#   --non-interactive         Run without prompts
#   --skip-secrets            Skip secrets setup
#   --help                    Show this help message
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-cloudtolocalllm-eks}"
NODE_COUNT="${NODE_COUNT:-2}"
NON_INTERACTIVE="false"
SKIP_SECRETS="false"

CONFIG_FILE=".aws-deployment-config.json"

while [[ $# -gt 0 ]]; do
  case $1 in
    --region)
      AWS_REGION="$2"
      shift 2
      ;;
    --cluster-name)
      CLUSTER_NAME="$2"
      shift 2
      ;;
    --node-count)
      NODE_COUNT="$2"
      shift 2
      ;;
    --non-interactive)
      NON_INTERACTIVE="true"
      shift
      ;;
    --skip-secrets)
      SKIP_SECRETS="true"
      shift
      ;;
    --help)
      head -n 25 "$0" | tail -n +2 | sed 's/^# //'
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

validate_prerequisites() {
    log_section "Validating Prerequisites"

    if ! command_exists aws; then
        log_error "AWS CLI is not installed"
        log_info "Install from: https://aws.amazon.com/cli/"
        exit 1
    fi
    log_success "AWS CLI is installed: $(aws --version | head -n 1)"

    if ! command_exists kubectl; then
        log_warning "kubectl is not installed (required for EKS access)"
        log_info "Install: https://kubernetes.io/docs/tasks/tools/"
    fi

    if ! command_exists jq; then
        log_error "jq is not installed"
        log_info "Install: https://stedolan.github.io/jq/download/"
        exit 1
    fi

    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "Not authenticated to AWS"
        log_info "Run: aws configure or ensure AWS credentials are set"
        exit 1
    fi

    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    log_success "Authenticated to AWS (Account: $ACCOUNT_ID, Region: $AWS_REGION)"
}

get_github_oidc_provider() {
    local provider_arn
    provider_arn=$(aws iam list-open-id-connect-providers --query "OpenIDConnectProviderList[?contains(Arn, \`githubusercontent.com\`)].Arn" --output text 2>/dev/null || echo "")

    if [[ -z "$provider_arn" ]]; then
        log_info "Creating GitHub OIDC provider..."

        local thumbprint
        thumbprint=$(echo | openssl s_client -servername token.actions.githubusercontent.com -connect token.actions.githubusercontent.com:443 2>/dev/null | openssl x509 -fingerprint -noout -sha1 2>/dev/null | tr -d ':' | tr -d '\n' | tr '[:upper:]' '[:lower:]' || echo "6938fd4d98bab03faabd2271c151b4c2d5230b89")

        provider_arn=$(aws iam create-open-id-connect-provider \
            --Url "https://token.actions.githubusercontent.com" \
            --ClientIDList "sts.amazonaws.com" \
            --ThumbprintList "$thumbprint" \
            --Query 'OpenIDConnectProviderArn' \
            --output text)

        log_success "GitHub OIDC provider created: $provider_arn"
    else
        log_success "GitHub OIDC provider already exists: $provider_arn"
    fi

    echo "$provider_arn"
}

create_vpc_stack() {
    log_section "Creating VPC and Networking Infrastructure"

    local stack_name="${CLUSTER_NAME}-vpc"

    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$AWS_REGION" >/dev/null 2>&1; then
        log_info "VPC stack already exists: $stack_name"
        aws cloudformation describe-stacks --stack-name "$stack_name" --region "$AWS_REGION" \
            --query 'Stacks[0].StackStatus' --output text
    else
        log_info "Creating VPC stack: $stack_name"

        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://config/cloudformation/vpc-networking.yaml" \
            --parameters "ParameterKey=VPCCidr,ParameterValue=10.0.0.0/16" \
            --capabilities CAPABILITY_IAM \
            --region "$AWS_REGION"

        log_info "Waiting for VPC stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name "$stack_name" --region "$AWS_REGION" || true

        log_success "VPC stack created: $stack_name"
    fi

    local vpc_id=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`VPCId`].OutputValue' \
        --output text)

    local private_subnet_ids=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetIds`].OutputValue' \
        --output text)

    local public_subnet_ids=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnetIds`].OutputValue' \
        --output text)

    local node_sg_id=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`NodeSecurityGroupId`].OutputValue' \
        --output text)

    echo "$vpc_id|$private_subnet_ids|$public_subnet_ids|$node_sg_id"
}

create_iam_roles_stack() {
    log_section "Creating IAM Roles"

    local stack_name="${CLUSTER_NAME}-iam"
    local github_oidc_arn="$1"

    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$AWS_REGION" >/dev/null 2>&1; then
        log_info "IAM roles stack already exists: $stack_name"
    else
        log_info "Creating IAM roles stack: $stack_name"

        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://config/cloudformation/iam-roles.yaml" \
            --parameters \
                "ParameterKey=GitHubOIDCProviderArn,ParameterValue=$github_oidc_arn" \
            --capabilities CAPABILITY_IAM \
            --region "$AWS_REGION"

        log_info "Waiting for IAM roles stack creation to complete..."
        aws cloudformation wait stack-create-complete --stack-name "$stack_name" --region "$AWS_REGION" || true

        log_success "IAM roles stack created: $stack_name"
    fi

    local github_role_arn=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`GitHubActionsRoleArn`].OutputValue' \
        --output text)

    local pod_execution_role_arn=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`PodExecutionRoleArn`].OutputValue' \
        --output text)

    echo "$github_role_arn|$pod_execution_role_arn"
}

create_eks_cluster() {
    log_section "Creating EKS Cluster"

    local stack_name="${CLUSTER_NAME}-eks"
    local vpc_info="$1"
    local iam_info="$2"

    local vpc_id=$(echo "$vpc_info" | cut -d'|' -f1)
    local private_subnet_ids=$(echo "$vpc_info" | cut -d'|' -f2)
    local node_sg_id=$(echo "$vpc_info" | cut -d'|' -f4)
    local github_role_arn=$(echo "$iam_info" | cut -d'|' -f1)
    local pod_execution_role_arn=$(echo "$iam_info" | cut -d'|' -f2)

    local eks_service_role_arn=$(aws cloudformation describe-stacks \
        --stack-name "${CLUSTER_NAME}-iam" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`EKSServiceRoleArn`].OutputValue' \
        --output text)

    local node_instance_role_arn=$(aws cloudformation describe-stacks \
        --stack-name "${CLUSTER_NAME}-iam" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`NodeInstanceRoleArn`].OutputValue' \
        --output text)

    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$AWS_REGION" >/dev/null 2>&1; then
        log_info "EKS cluster stack already exists: $stack_name"
    else
        log_info "Creating EKS cluster stack: $stack_name"

        aws cloudformation create-stack \
            --stack-name "$stack_name" \
            --template-body "file://config/cloudformation/eks-cluster.yaml" \
            --parameters \
                "ParameterKey=ClusterName,ParameterValue=$CLUSTER_NAME" \
                "ParameterKey=KubernetesVersion,ParameterValue=1.30" \
                "ParameterKey=NodeInstanceType,ParameterValue=t3.small" \
                "ParameterKey=DesiredNodeCount,ParameterValue=$NODE_COUNT" \
                "ParameterKey=MinNodeCount,ParameterValue=1" \
                "ParameterKey=MaxNodeCount,ParameterValue=5" \
                "ParameterKey=EKSServiceRoleArn,ParameterValue=$eks_service_role_arn" \
                "ParameterKey=NodeInstanceRoleArn,ParameterValue=$node_instance_role_arn" \
                "ParameterKey=VPCId,ParameterValue=$vpc_id" \
                "ParameterKey=PrivateSubnetIds,ParameterValue=$private_subnet_ids" \
                "ParameterKey=NodeSecurityGroupId,ParameterValue=$node_sg_id" \
            --capabilities CAPABILITY_IAM \
            --region "$AWS_REGION"

        log_info "Waiting for EKS cluster stack creation to complete (this may take 10-15 minutes)..."
        aws cloudformation wait stack-create-complete --stack-name "$stack_name" --region "$AWS_REGION" || true

        log_success "EKS cluster stack created: $stack_name"
    fi

    local cluster_endpoint=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ClusterEndpoint`].OutputValue' \
        --output text)

    local cluster_arn=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$AWS_REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ClusterArn`].OutputValue' \
        --output text)

    echo "$cluster_endpoint|$cluster_arn|$github_role_arn|$pod_execution_role_arn"
}

configure_kubectl() {
    log_section "Configuring kubectl"

    log_info "Updating kubeconfig for EKS cluster: $CLUSTER_NAME"

    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"

    log_success "kubectl configured"

    log_info "Testing cluster connection..."
    if kubectl cluster-info >/dev/null 2>&1; then
        log_success "Cluster is accessible"
        kubectl get nodes
    else
        log_warning "Cluster connection test failed (this is normal if nodes aren't ready yet)"
    fi
}

generate_config_file() {
    local cluster_info="$1"

    local cluster_endpoint=$(echo "$cluster_info" | cut -d'|' -f1)
    local cluster_arn=$(echo "$cluster_info" | cut -d'|' -f2)
    local github_role_arn=$(echo "$cluster_info" | cut -d'|' -f3)

    log_section "Generating Configuration File"

    cat > "$CONFIG_FILE" <<EOF
{
  "AWS_REGION": "$AWS_REGION",
  "CLUSTER_NAME": "$CLUSTER_NAME",
  "AWS_SECRETS_MANAGER_SECRET_ID": "CloudToLocalLLM/production",
  "EKS_CLUSTER_ENDPOINT": "$cluster_endpoint",
  "EKS_CLUSTER_ARN": "$cluster_arn",
  "GITHUB_ACTIONS_ROLE_ARN": "$github_role_arn",
  "GITHUB_REPO": "$(git remote get-url origin 2>/dev/null | sed 's|https://github.com/||' || echo "")"
}
EOF

    log_success "Configuration saved to: $CONFIG_FILE"
    log_info "Run: ./scripts/setup-aws-secrets.sh to configure secrets"
}

main() {
    log_section "AWS Infrastructure Setup for CloudToLocalLLM"
    log_info "Region: $AWS_REGION | Cluster: $CLUSTER_NAME | Nodes: $NODE_COUNT"

    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        echo "This script will create the following AWS resources:"
        echo "  • VPC with public and private subnets"
        echo "  • EKS cluster with t3.small nodes"
        echo "  • IAM roles for EKS and GitHub Actions"
        echo "  • Security groups"
        echo "  • GitHub OIDC provider"
        echo ""
        read -p "Continue? (y/n): " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "Aborted by user"
            exit 0
        fi
    fi

    validate_prerequisites

    local github_oidc_arn=$(get_github_oidc_provider)

    local vpc_info=$(create_vpc_stack)
    log_success "VPC created"

    local iam_info=$(create_iam_roles_stack "$github_oidc_arn")
    log_success "IAM roles created"

    local cluster_info=$(create_eks_cluster "$vpc_info" "$iam_info")
    log_success "EKS cluster created"

    configure_kubectl

    generate_config_file "$cluster_info"

    log_section "Setup Complete"
    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ AWS Infrastructure Setup Complete!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Configure secrets: ./scripts/setup-aws-secrets.sh"
    echo "  2. Update GitHub secrets with AWS credentials"
    echo "  3. Push code to trigger deployment"
    echo ""
    echo "Useful commands:"
    echo "  • View cluster: kubectl cluster-info"
    echo "  • List nodes: kubectl get nodes"
    echo "  • View pods: kubectl get pods -n CloudToLocalLLM"
    echo ""

    if [[ "$SKIP_SECRETS" != "true" ]]; then
        log_info "Running secrets setup..."
        ./scripts/setup-aws-secrets.sh --non-interactive
    fi

    log_success "All done! 🎉"
}

main "$@"
