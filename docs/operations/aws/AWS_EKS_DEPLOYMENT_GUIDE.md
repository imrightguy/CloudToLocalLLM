# AWS EKS Deployment Guide for CloudToLocalLLM

## Overview

This comprehensive guide walks through deploying CloudToLocalLLM on AWS EKS (Elastic Kubernetes Service) with GitHub Actions CI/CD. The deployment uses OIDC for secure authentication, Docker Hub for container images, and Cloudflare for DNS/SSL management.

**Key Features:**
- ✓ OIDC authentication (no long-lived credentials)
- ✓ Automated CI/CD with GitHub Actions
- ✓ Cost-optimized for development ($200-300/month)
- ✓ High availability with 2-node cluster
- ✓ Automatic health checks and rollback
- ✓ CloudWatch monitoring and logging
- ✓ Infrastructure as Code (CloudFormation)

## Prerequisites

Before starting, ensure you have:

### AWS Account
- AWS Account ID: 422017356244
- AWS CLI installed and configured
- Appropriate IAM permissions (admin or equivalent)
- AWS region: us-east-1 (default)

### GitHub
- GitHub repository: cloudtolocalllm/cloudtolocalllm
- GitHub Actions enabled
- GitHub CLI (gh) installed (optional but recommended)

### Local Tools
- Docker installed (for building images)
- kubectl installed (for cluster management)
- PowerShell 5.0+ (Windows) or Bash (Linux/macOS)

### Container Registry
- Docker Hub account with credentials
- Docker Hub credentials stored in GitHub Secrets:
  - `DOCKERHUB_USERNAME`
  - `DOCKERHUB_TOKEN`

### DNS Provider
- Cloudflare account with API token
- Cloudflare API token in GitHub Secrets: `CLOUDFLARE_API_TOKEN`
- Domains configured in Cloudflare:
  - cloudtolocalllm.online
  - app.cloudtolocalllm.online
  - api.cloudtolocalllm.online

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
│  (Code Push) → GitHub Actions Workflow                       │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  GitHub Actions Workflow                     │
│  1. OIDC Authentication to AWS                              │
│  2. Build Docker Images                                      │
│  3. Push to Docker Hub                                       │
│  4. Deploy to AWS EKS                                        │
│  5. Verify Health Checks                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    AWS Account                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  EKS Cluster (cloudtolocalllm-eks)                   │   │
│  │  ├─ Control Plane (AWS Managed)                      │   │
│  │  ├─ Node Group (2x t3.medium)                        │   │
│  │  ├─ VPC & Subnets (Private)                          │   │
│  │  ├─ Security Groups                                  │   │
│  │  └─ Network Load Balancer                            │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Kubernetes Namespace: cloudtolocalllm               │   │
│  │  ├─ Deployment: web-app                              │   │
│  │  ├─ Deployment: api-backend                          │   │
│  │  ├─ StatefulSet: postgres                            │   │
│  │  ├─ Services & Ingress                               │   │
│  │  └─ ConfigMaps & Secrets                             │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  CloudWatch Monitoring                               │   │
│  │  ├─ Container Insights                               │   │
│  │  ├─ Log Groups                                       │   │
│  │  └─ Alarms & Dashboards                              │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  Cloudflare DNS & SSL                        │
│  cloudtolocalllm.online → AWS NLB IP                         │
│  app.cloudtolocalllm.online → AWS NLB IP                     │
│  api.cloudtolocalllm.online → AWS NLB IP                     │
└─────────────────────────────────────────────────────────────┘
```

## Step-by-Step Deployment

### Phase 1: AWS Infrastructure Setup (30-45 minutes)

#### Step 1.1: Set Up OIDC Provider

The OIDC provider enables GitHub Actions to authenticate to AWS without storing long-lived credentials.

**Windows (PowerShell):**
```powershell
cd scripts/aws
.\setup-oidc-provider.ps1 `
  -AwsAccountId "422017356244" `
  -GitHubRepo "cloudtolocalllm/cloudtolocalllm"
```

**Linux/macOS (Bash):**
```bash
cd scripts/aws
chmod +x setup-oidc-provider.sh
./setup-oidc-provider.sh
```

**Expected Output:**
```
✓ OIDC Provider created
✓ IAM Role created
✓ Policies attached
✓ Trust relationship configured

OIDC Provider ARN: arn:aws:iam::422017356244:oidc-provider/token.actions.githubusercontent.com
IAM Role ARN: arn:aws:iam::422017356244:role/github-actions-role
```

**Verify Setup:**
```powershell
.\verify-oidc-setup.ps1
```

#### Step 1.2: Deploy VPC and Networking

Create the VPC, subnets, and security groups for the EKS cluster.

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

Wait for completion:
```bash
aws cloudformation wait stack-create-complete \
  --stack-name cloudtolocalllm-vpc \
  --region us-east-1
```

#### Step 1.3: Deploy IAM Roles

Create IAM roles for EKS service, nodes, and pod authentication.

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

Wait for completion:
```bash
aws cloudformation wait stack-create-complete \
  --stack-name cloudtolocalllm-iam \
  --region us-east-1
```

#### Step 1.4: Deploy EKS Cluster

Create the EKS cluster with 2 t3.medium nodes.

```bash
# Get outputs from previous stacks
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

# Deploy EKS cluster
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
    ParameterKey=PrivateSubnetIds,ParameterValue=\"$PRIVATE_SUBNETS\"
```

Wait for completion (15-20 minutes):
```bash
aws cloudformation wait stack-create-complete \
  --stack-name cloudtolocalllm-eks \
  --region us-east-1
```

### Phase 2: Kubernetes Configuration (15-20 minutes)

#### Step 2.1: Configure kubectl

```bash
aws eks update-kubeconfig \
  --name cloudtolocalllm-eks \
  --region us-east-1
```

Verify cluster access:
```bash
kubectl cluster-info
kubectl get nodes
```

Expected output: 2 nodes in Ready state

#### Step 2.2: Create Kubernetes Namespace

```bash
kubectl create namespace cloudtolocalllm
kubectl label namespace cloudtolocalllm name=cloudtolocalllm
```

#### Step 2.3: Create Secrets

```bash
# Create Docker Hub credentials secret
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=$DOCKERHUB_USERNAME \
  --docker-password=$DOCKERHUB_TOKEN \
  --docker-email=your-email@example.com \
  -n cloudtolocalllm

# Create application secrets
kubectl create secret generic app-secrets \
  --from-literal=auth0-domain=$AUTH0_DOMAIN \
  --from-literal=auth0-client-id=$AUTH0_CLIENT_ID \
  --from-literal=auth0-client-secret=$AUTH0_CLIENT_SECRET \
  -n cloudtolocalllm
```

#### Step 2.4: Create ConfigMaps

```bash
kubectl create configmap app-config \
  --from-literal=api-url=https://api.cloudtolocalllm.online \
  --from-literal=web-url=https://app.cloudtolocalllm.online \
  --from-literal=environment=production \
  -n cloudtolocalllm
```

#### Step 2.5: Apply Kubernetes Manifests

```bash
# Apply RBAC
kubectl apply -f k8s/rbac.yaml

# Apply network policies
kubectl apply -f k8s/network-policies.yaml

# Apply deployments
kubectl apply -f k8s/web-deployment.yaml
kubectl apply -f k8s/api-backend-deployment.yaml
kubectl apply -f k8s/postgres-statefulset.yaml

# Apply services
kubectl apply -f k8s/web-service.yaml
kubectl apply -f k8s/api-service.yaml
kubectl apply -f k8s/postgres-service.yaml

# Apply ingress
kubectl apply -f k8s/ingress-aws-nlb.yaml
```

Verify deployments:
```bash
kubectl get deployments -n cloudtolocalllm
kubectl get pods -n cloudtolocalllm
kubectl get services -n cloudtolocalllm
```

### Phase 3: DNS and SSL Configuration (10-15 minutes)

#### Step 3.1: Get Load Balancer IP

```bash
# Get the Network Load Balancer DNS name
NLB_DNS=$(kubectl get svc -n cloudtolocalllm ingress-nlb \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "NLB DNS: $NLB_DNS"

# Get the IP address
NLB_IP=$(dig +short $NLB_DNS | head -1)
echo "NLB IP: $NLB_IP"
```

#### Step 3.2: Update Cloudflare DNS Records

```bash
# Update DNS records to point to AWS NLB
curl -X PUT "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"cloudtolocalllm.online\",\"content\":\"$NLB_IP\",\"ttl\":3600}"

curl -X PUT "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"app.cloudtolocalllm.online\",\"content\":\"$NLB_IP\",\"ttl\":3600}"

curl -X PUT "https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"api.cloudtolocalllm.online\",\"content\":\"$NLB_IP\",\"ttl\":3600}"
```

#### Step 3.3: Verify DNS Resolution

```bash
# Wait for DNS propagation (may take a few minutes)
nslookup cloudtolocalllm.online
nslookup app.cloudtolocalllm.online
nslookup api.cloudtolocalllm.online

# Verify SSL certificates
curl -I https://cloudtolocalllm.online
curl -I https://app.cloudtolocalllm.online
curl -I https://api.cloudtolocalllm.online
```

### Phase 4: CI/CD Configuration (10 minutes)

#### Step 4.1: Update GitHub Actions Workflow

Update `.github/workflows/deploy-aws-eks.yml` with the role ARN:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: arn:aws:iam::422017356244:role/github-actions-role
    aws-region: us-east-1
```

#### Step 4.2: Test Deployment

Push code to main branch or manually trigger workflow:

```bash
# Manual trigger
gh workflow run deploy-aws-eks.yml

# Or push code
git push origin main
```

Monitor workflow:
```bash
gh run list --workflow=deploy-aws-eks.yml
gh run view <run-id>
```

## Verification Checklist

After deployment, verify:

- [ ] EKS cluster is running: `aws eks describe-cluster --name cloudtolocalllm-eks`
- [ ] 2 nodes are ready: `kubectl get nodes`
- [ ] All pods are running: `kubectl get pods -n cloudtolocalllm`
- [ ] Services are accessible: `kubectl get svc -n cloudtolocalllm`
- [ ] Ingress is configured: `kubectl get ingress -n cloudtolocalllm`
- [ ] DNS resolves correctly: `nslookup cloudtolocalllm.online`
- [ ] SSL certificates are valid: `curl -I https://cloudtolocalllm.online`
- [ ] Application is accessible: `curl https://app.cloudtolocalllm.online`
- [ ] API is accessible: `curl https://api.cloudtolocalllm.online`
- [ ] CloudWatch logs are available: `aws logs describe-log-groups`
- [ ] Health checks pass: `kubectl describe pods -n cloudtolocalllm`

## Cost Estimation

**Monthly Costs:**
- EKS Control Plane: $73
- EC2 Instances (2x t3.medium): $60-90
- NAT Gateways (2x): $64
- Network Load Balancer: $16
- Data Transfer: $0-20
- CloudWatch: $5-10
- **Total: $200-300/month**

**Cost Optimization Tips:**
- Use 1 NAT gateway instead of 2 (less redundancy)
- Use t3.small instances instead of t3.medium
- Use Spot instances for non-critical workloads
- Enable cluster autoscaling to scale down during off-hours
- Use Reserved Instances for long-term deployments

## Monitoring and Logging

### CloudWatch Container Insights

```bash
# View cluster metrics
aws cloudwatch get-metric-statistics \
  --namespace ContainerInsights \
  --metric-name PodCPU \
  --dimensions Name=ClusterName,Value=cloudtolocalllm-eks \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-02T00:00:00Z \
  --period 300 \
  --statistics Average
```

### View Logs

```bash
# View application logs
kubectl logs -n cloudtolocalllm deployment/web-app
kubectl logs -n cloudtolocalllm deployment/api-backend

# View pod events
kubectl describe pod -n cloudtolocalllm <pod-name>

# View cluster events
kubectl get events -n cloudtolocalllm
```

## Scaling and Auto-Scaling

### Manual Scaling

```bash
# Scale deployment
kubectl scale deployment web-app --replicas=3 -n cloudtolocalllm

# Scale node group
aws eks update-nodegroup-config \
  --cluster-name cloudtolocalllm-eks \
  --nodegroup-name cloudtolocalllm-nodes \
  --scaling-config minSize=1,maxSize=10,desiredSize=3
```

### Horizontal Pod Autoscaling

```bash
# Create HPA
kubectl autoscale deployment web-app \
  --min=2 --max=10 \
  --cpu-percent=80 \
  -n cloudtolocalllm
```

## Backup and Disaster Recovery

### Backup PostgreSQL

```bash
# Create backup
kubectl exec -n cloudtolocalllm postgres-0 -- \
  pg_dump -U postgres cloudtolocalllm > backup.sql

# Upload to S3
aws s3 cp backup.sql s3://cloudtolocalllm-backups/
```

### Restore PostgreSQL

```bash
# Download from S3
aws s3 cp s3://cloudtolocalllm-backups/backup.sql .

# Restore
kubectl exec -n cloudtolocalllm postgres-0 -- \
  psql -U postgres < backup.sql
```

## Troubleshooting

See the [AWS EKS Troubleshooting Guide](AWS_EKS_TROUBLESHOOTING_GUIDE.md) for common issues and solutions.

## Next Steps

1. Monitor cluster health in CloudWatch
2. Set up alerts for critical metrics
3. Configure backup and disaster recovery
4. Document operational procedures
5. Plan for production deployment

## Support and Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Cloudflare Documentation](https://developers.cloudflare.com/)
