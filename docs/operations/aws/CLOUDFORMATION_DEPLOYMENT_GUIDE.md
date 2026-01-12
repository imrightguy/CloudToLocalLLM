# CloudFormation Deployment Guide for AWS EKS

This guide provides step-by-step instructions for deploying CloudToLocalLLM on AWS EKS using CloudFormation templates.

## Overview

The CloudFormation templates are organized into three main stacks:

1. **VPC and Networking** (`vpc-networking.yaml`) - Creates VPC, subnets, NAT gateways, and security groups
2. **IAM Roles** (`iam-roles.yaml`) - Creates IAM roles for EKS, nodes, GitHub Actions, and pods
3. **EKS Cluster** (`eks-cluster.yaml`) - Creates EKS cluster, node group, and load balancer

## Prerequisites

- AWS CLI installed and configured with appropriate credentials
- AWS Account ID: 422017356244
- GitHub OIDC Provider already configured in AWS
- CloudFormation permissions in your AWS account
- GitHub Container Registry (GHCR) access for container images

## Deployment Steps

### Step 1: Deploy VPC and Networking Stack

```bash
aws cloudformation create-stack \
  --stack-name cloudtolocalllm-vpc \
  --template-body file://config/cloudformation/vpc-networking.yaml \
  --region us-east-1 \
  --parameters \
    ParameterKey=VPCCidr,ParameterValue=10.0.0.0/16 \
    ParameterKey=PrivateSubnet1Cidr,ParameterValue=10.0.1.0/24 \
    ParameterKey=PrivateSubnet2Cidr,ParameterValue=10.0.2.0/24 \
    ParameterKey=PrivateSubnet3Cidr,ParameterValue=10.0.3.0/24 \
    ParameterKey=PublicSubnet1Cidr,ParameterValue=10.0.101.0/24 \
    ParameterKey=PublicSubnet2Cidr,ParameterValue=10.0.102.0/24
```

Wait for the stack to complete:

```bash
aws cloudformation wait stack-create-complete \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1
```

Retrieve the outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1 \
  --query 'Stacks[0].Outputs' \
  --output table
```

### Step 2: Deploy IAM Roles Stack

```bash
aws cloudformation create-stack \
  --stack-name cloudtolocalllm-iam \
  --template-body file://config/cloudformation/iam-roles.yaml \
  --region us-east-1 \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameters \
    ParameterKey=GitHubOIDCProviderArn,ParameterValue=arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com \
    ParameterKey=GitHubRepository,ParameterValue=cloudtolocalllm/cloudtolocalllm
```

Wait for the stack to complete:

```bash
aws cloudformation wait stack-create-complete \
  --stack-name cloudtolocalllm-iam \
  --region us-east-1
```

Retrieve the outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-iam \
  --region us-east-1 \
  --query 'Stacks[0].Outputs' \
  --output table
```

### Step 3: Deploy EKS Cluster Stack

First, get the outputs from the previous stacks:

```bash
# Get VPC outputs
VPC_ID=$(aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`VPCId`].OutputValue' \
  --output text)

PRIVATE_SUBNETS=$(aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetIds`].OutputValue' \
  --output text)

NODE_SG=$(aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`NodeSecurityGroupId`].OutputValue' \
  --output text)

# Get IAM outputs
EKS_ROLE=$(aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-iam \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`EKSServiceRoleArn`].OutputValue' \
  --output text)

NODE_ROLE=$(aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-iam \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`NodeInstanceRoleArn`].OutputValue' \
  --output text)
```

Now deploy the EKS cluster:

```bash
aws cloudformation create-stack \
  --stack-name cloudtolocalllm-eks \
  --template-body file://config/cloudformation/eks-cluster.yaml \
  --region us-east-1 \
  --parameters \
    ParameterKey=ClusterName,ParameterValue=cloudtolocalllm-eks \
    ParameterKey=KubernetesVersion,ParameterValue=1.30 \
    ParameterKey=NodeInstanceType,ParameterValue=t3.medium \
    ParameterKey=DesiredNodeCount,ParameterValue=2 \
    ParameterKey=MinNodeCount,ParameterValue=1 \
    ParameterKey=MaxNodeCount,ParameterValue=5 \
    ParameterKey=EKSServiceRoleArn,ParameterValue=$EKS_ROLE \
    ParameterKey=NodeInstanceRoleArn,ParameterValue=$NODE_ROLE \
    ParameterKey=VPCId,ParameterValue=$VPC_ID \
    ParameterKey=PrivateSubnetIds,ParameterValue=\"$PRIVATE_SUBNETS\" \
    ParameterKey=NodeSecurityGroupId,ParameterValue=$NODE_SG
```

Wait for the stack to complete (this may take 15-20 minutes):

```bash
aws cloudformation wait stack-create-complete \
  --stack-name cloudtolocalllm-eks \
  --region us-east-1
```

Retrieve the outputs:

```bash
aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-eks \
  --region us-east-1 \
  --query 'Stacks[0].Outputs' \
  --output table
```

## Verifying the Deployment

### 1. Verify EKS Cluster

```bash
aws eks describe-cluster \
  --name cloudtolocalllm-eks \
  --region us-east-1
```

### 2. Configure kubectl

```bash
aws eks update-kubeconfig \
  --name cloudtolocalllm-eks \
  --region us-east-1
```

### 3. Verify Nodes

```bash
kubectl get nodes
```

Expected output: 2 nodes in Ready state

### 4. Verify Cluster Health

```bash
kubectl cluster-info
kubectl get componentstatuses
```

### 5. Get Load Balancer DNS

```bash
aws cloudformation describe-stacks \
  --stack-name cloudtolocalllm-eks \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`LoadBalancerDNS`].OutputValue' \
  --output text
```

## Updating Stacks

To update a stack with new parameters:

```bash
aws cloudformation update-stack \
  --stack-name cloudtolocalllm-eks \
  --template-body file://config/cloudformation/eks-cluster.yaml \
  --region us-east-1 \
  --parameters \
    ParameterKey=DesiredNodeCount,ParameterValue=3 \
    UsePreviousValue=true
```

## Deleting Stacks

To delete the stacks (in reverse order):

```bash
# Delete EKS cluster stack
aws cloudformation delete-stack \
  --stack-name cloudtolocalllm-eks \
  --region us-east-1

# Wait for deletion
aws cloudformation wait stack-delete-complete \
  --stack-name cloudtolocalllm-eks \
  --region us-east-1

# Delete IAM stack
aws cloudformation delete-stack \
  --stack-name cloudtolocalllm-iam \
  --region us-east-1

aws cloudformation wait stack-delete-complete \
  --stack-name cloudtolocalllm-iam \
  --region us-east-1

# Delete VPC stack
aws cloudformation delete-stack \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1

aws cloudformation wait stack-delete-complete \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1
```

## Troubleshooting

### Stack Creation Fails

Check the stack events for error details:

```bash
aws cloudformation describe-stack-events \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1 \
  --query 'StackEvents[?ResourceStatus==`CREATE_FAILED`]'
```

### Nodes Not Ready

Check node status:

```bash
kubectl describe nodes
kubectl get events --all-namespaces
```

### Load Balancer Not Accessible

Verify security groups:

```bash
aws ec2 describe-security-groups \
  --filters Name=group-name,Values=cloudtolocalllm-* \
  --region us-east-1
```

## Cost Optimization

The current configuration uses:
- **Compute**: 2x t3.medium instances (~$30-45/month each)
- **NAT Gateways**: 2x NAT gateways (~$32/month each)
- **Load Balancer**: 1x Network Load Balancer (~$16/month)
- **Estimated Total**: $200-300/month

To reduce costs:
- Use 1 NAT gateway instead of 2 (less redundancy)
- Use smaller instance types (t3.small)
- Use Spot instances for non-critical workloads
- Enable cluster autoscaling to scale down during off-hours

## Infrastructure as Code Best Practices

1. **Version Control**: Keep CloudFormation templates in Git
2. **Change Sets**: Use CloudFormation change sets to preview changes
3. **Stack Policies**: Implement stack policies to prevent accidental deletions
4. **Monitoring**: Enable CloudTrail to audit infrastructure changes
5. **Backups**: Regularly backup cluster data and configurations
6. **Documentation**: Document all custom parameters and modifications

## Next Steps

After deploying the infrastructure:

1. Deploy Kubernetes manifests for applications
2. Configure Ingress controller for routing
3. Set up monitoring and logging
4. Configure auto-scaling policies
5. Implement backup and disaster recovery procedures

## References

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
