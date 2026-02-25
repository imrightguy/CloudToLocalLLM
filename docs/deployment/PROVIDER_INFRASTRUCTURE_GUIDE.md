# Provider Infrastructure Guide

## Overview

CloudToLocalLLM is designed to be **provider-agnostic**, supporting deployment on multiple cloud platforms and Kubernetes providers. This document clarifies the current deployment status and available options.

## Current Deployment Status

### Primary Infrastructure: Azure AKS

- **Current Provider**: Microsoft Azure
- **Service**: Azure Kubernetes Service (AKS)
- **Status**: ✅ **ACTIVE PRODUCTION DEPLOYMENT**
- **Authentication**: Auth0 (provider-agnostic)
- **Container Registry**: Docker Hub
- **DNS/SSL**: Cloudflare

### Alternative Infrastructure: AWS EKS

- **Provider**: Amazon Web Services
- **Service**: Elastic Kubernetes Service (EKS)
- **Status**: 🔄 **MIGRATION PLANNING / ALTERNATIVE OPTION**
- **Purpose**: Cost optimization and feature parity evaluation

## Provider-Agnostic Architecture

CloudToLocalLLM is built with provider independence in mind:

### Kubernetes-Native Design

- Standard Kubernetes manifests in `k8s/` directory
- Compatible with any Kubernetes provider (AKS, EKS, GKE, self-hosted)
- No vendor-specific dependencies in core application

### Authentication Flexibility

- **Current**: Auth0 (cloud-agnostic)
- **Supported**: Any OIDC-compatible provider
- **Future Options**: Auth0, Firebase Auth, custom solutions

### Container Strategy

- Docker Hub registry (provider-neutral)
- Standard container images work across all platforms
- No platform-specific container requirements

## Available Deployment Options

### 1. Azure AKS (Current Production)

- **Documentation**: `docs/DEPLOYMENT/AKS_*.md`
- **Scripts**: `scripts/setup-azure-aks-infrastructure.sh`
- **Status**: Fully operational and tested
- **Recommended For**: Current production deployments

### 2. AWS EKS (Migration Option)

- **Documentation**: `docs/ops/aws/` and `.kiro/steering/aws-infrastructure.md`
- **Scripts**: `scripts/aws/` directory
- **Status**: Infrastructure provisioned, migration in planning
- **Recommended For**: Cost optimization scenarios

### 3. Self-Hosted Kubernetes

- **Documentation**: `docs/ops/kubernetes/KUBERNETES_SELF_HOSTED_GUIDE.md`
- **Requirements**: Any Kubernetes 1.24+ cluster
- **Status**: Supported via standard manifests
- **Recommended For**: On-premises or custom cloud deployments

### 4. Local Development

- **Method**: Docker Compose
- **Files**: `docker-compose.yml`, `docker-compose.production.yml`
- **Status**: Fully supported
- **Recommended For**: Development and testing

## Migration Considerations

### Azure to AWS Migration

The AWS documentation represents a **planned migration option**, not the current state:

- **Current Reality**: Azure AKS is the active production environment
- **AWS Status**: Infrastructure provisioned for evaluation
- **Migration Timeline**: To be determined based on cost/benefit analysis
- **Rollback Plan**: Azure remains the fallback option

### Provider Selection Criteria

When choosing a provider, consider:

1. **Cost**: Monthly operational expenses
2. **Features**: Required services and integrations
3. **Compliance**: Regional and regulatory requirements
4. **Expertise**: Team familiarity with the platform
5. **Migration Effort**: Time and complexity to switch

## Documentation Structure

### Current Provider (Azure)

- Primary documentation in `docs/DEPLOYMENT/`
- Deployment scripts in `scripts/`
- Kubernetes manifests in `k8s/`

### Alternative Providers

- AWS documentation in `docs/ops/aws/` and `.kiro/steering/aws-infrastructure.md`
- Self-hosted guides in `docs/ops/kubernetes/`
- Provider-specific scripts in respective subdirectories

## Best Practices

### For Operators

1. **Use Current Documentation**: Follow Azure AKS guides for production deployments
2. **Evaluate Alternatives**: Review AWS documentation for future planning
3. **Test Locally**: Use Docker Compose for development
4. **Plan Migrations**: Consider provider changes carefully

### For Developers

1. **Avoid Vendor Lock-in**: Use standard Kubernetes APIs
2. **Test Portability**: Ensure code works across providers
3. **Document Dependencies**: Note any provider-specific requirements
4. **Use Abstractions**: Prefer cloud-agnostic libraries and patterns

## Support and Troubleshooting

### Current Production Issues (Azure AKS)

- Use Azure-specific documentation and scripts
- Follow established deployment procedures
- Contact Azure support for infrastructure issues

### Migration Planning (AWS EKS)

- Review AWS documentation for planning purposes
- Test in development environments first
- Validate cost and feature assumptions

### General Kubernetes Issues

- Use standard Kubernetes troubleshooting
- Check application logs and metrics
- Verify resource quotas and limits

## Conclusion

CloudToLocalLLM's provider-agnostic design ensures flexibility while maintaining production stability. The current Azure AKS deployment provides a solid foundation, while AWS EKS documentation offers a viable migration path when needed.

**Key Takeaway**: Azure AKS is the current production reality, AWS EKS is a future option, and the architecture supports both seamlessly.
