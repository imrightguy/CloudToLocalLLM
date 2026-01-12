# CI/CD Quick Reference

## AWS OIDC Setup - Complete ✓

### Role ARN
```
arn:aws:iam::422017356244:role/github-actions-role
```

### GitHub Actions Workflows

#### 1. Build Pipeline
**File**: `.github/workflows/build-pipeline.yml`
 
**Triggers**:
- Push to `main` branch
- Manual workflow dispatch
 
**What it does**:
1. Analyzes changes to determine which components need building
2. Checks GHCR for existing SHA-tagged images
3. Authenticates to AWS using OIDC
4. Builds Docker images (if needed) and pushes to GHCR
5. Deploys to AWS EKS cluster
6. Verifies tunnel and cloudflare connectivity


**Environment Variables**:
- `AWS_REGION`: us-east-1
- `EKS_CLUSTER_NAME`: cloudtolocalllm-eks
- `DOCKER_REGISTRY`: cloudtolocalllm
- `NAMESPACE`: cloudtolocalllm

**Required Secrets**:
- `DOCKERHUB_USERNAME`: GHCR username
- `DOCKERHUB_TOKEN`: GHCR access token

#### 2. Test OIDC Authentication
**File**: `.github/workflows/test-oidc-auth.yml`

**Triggers**:
- Manual workflow dispatch
- Weekly schedule (Sunday at midnight UTC)

**What it does**:
1. Tests OIDC token exchange
2. Verifies AWS credentials
3. Tests EKS cluster access
4. Tests ECR repository access
5. Tests CloudWatch access
6. Verifies temporary credentials
7. Checks CloudTrail logging

## How to Use

### 1. Test OIDC Authentication
```bash
# Manually trigger the test workflow
gh workflow run test-oidc-auth.yml

# Check the workflow run
gh run list --workflow=test-oidc-auth.yml
```

### 2. Deploy to AWS EKS
```bash
# Push code to main branch
git push origin main

# Or manually trigger the workflow
gh workflow run deploy-aws-eks.yml
```

### 3. Monitor Deployments
```bash
# Check workflow runs
gh run list --workflow=deploy-aws-eks.yml

# View workflow details
gh run view <RUN_ID>

# View workflow logs
gh run view <RUN_ID> --log
```

## Security

✓ **No Long-Lived Credentials**: OIDC eliminates AWS access keys
✓ **Automatic Rotation**: Credentials rotated on each workflow run
✓ **Least Privilege**: IAM role has specific permissions
✓ **Branch Restriction**: Deployments only from main branch
✓ **Audit Trail**: All deployments logged in CloudTrail

## Troubleshooting

### Workflow fails with "AssumeRoleUnauthorizedOperation"
1. Check GitHub Actions permissions include `id-token: write`
2. Verify trust policy includes correct repository and branch
3. Check AWS credentials are configured correctly

### Workflow fails with "Docker image push failed"
1. Verify GHCR credentials in GitHub Secrets
2. Check GHCR repository exists
3. Verify GHCR token has push permissions

### Workflow fails with "EKS cluster not found"
1. Verify EKS cluster exists in AWS
2. Check cluster name matches `cloudtolocalllm-eks`
3. Verify AWS region is `us-east-1`

## Next Steps

1. **Create EKS Cluster** (Task 3)
   - Set up VPC and subnets
   - Create EKS cluster
   - Create node group

2. **Configure Kubernetes** (Task 4)
   - Create namespace
   - Set up RBAC
   - Configure network policies

3. **Deploy Application** (Task 6+)
   - Create Kubernetes manifests
   - Deploy to EKS cluster
   - Verify deployment health

## Files

- `.github/workflows/deploy-aws-eks.yml` - Main deployment workflow
- `.github/workflows/test-oidc-auth.yml` - OIDC test workflow
- `scripts/aws/ROLE_ARN.txt` - Role ARN reference
- `docs/AWS_OIDC_SETUP_GUIDE.md` - Detailed setup guide
- `docs/AWS_INFRASTRUCTURE_SETUP_COMPLETE.md` - Setup completion summary

## Resources

- [GitHub Actions: About security hardening with OpenID Connect](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [AWS: Using OpenID Connect identity providers](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_providers_oidc.html)
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
