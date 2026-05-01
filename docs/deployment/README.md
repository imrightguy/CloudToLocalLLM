# Deployment Documentation

This directory documents supported deployment paths for CloudToLocalLLM.

## Start Here

- [Deployment Overview](DEPLOYMENT_OVERVIEW.md)
- [Complete Deployment Workflow](COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Self Hosting](SELF_HOSTING.md)
- [Docker Deployment](DOCKER_DEPLOYMENT.md)
- [Strict Deployment Policy](STRICT_DEPLOYMENT_POLICY.md)
- [Secrets Management](SECRETS_MANAGEMENT.md)

## Installation Guides

- [Linux Installation](installation/LINUX.md)
- [Windows Installation](installation/WINDOWS.md)
- [macOS Installation](installation/MACOS.md)

## Kubernetes And GitOps

- [k3s Proxmox Deployment Workflow](K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md)
- [ArgoCD Integration](ARGOCD_INTEGRATION.md)
- [ArgoCD Proxmox Management VM](ARGOCD_PROXMOX_MANAGEMENT_VM.md)

Kubernetes manifests live under `k8s/`, `services/*/k8s/`, and `config/kubernetes/`. Not every Kubernetes path has a README, so link to specific runbooks from this directory when documenting deployment procedures.

## Cloud And Provider Runbooks

- [Provider Infrastructure Guide](PROVIDER_INFRASTRUCTURE_GUIDE.md)
- [Cloudron Deployment](../../CloudronManifest.json)
- [Cloudflare/Chisel Deployment](CHISEL_DEPLOYMENT.md)
- [DigitalOcean Deployment Summary](DIGITALOCEAN_DEPLOYMENT_SUMMARY.md)

Provider-specific notes are runbooks, not universal architecture. Prefer [Deployment Overview](DEPLOYMENT_OVERVIEW.md) for the cross-provider model. Older tunnel/proxy runbooks are legacy or fallback material unless a deployment explicitly depends on them.

## Packaging And Releases

- [AUR Status](AUR_STATUS.md)
- [Versioning Strategy](VERSIONING_STRATEGY.md)
- [Deployment Testing Guide](DEPLOYMENT_TESTING_GUIDE.md)
- [Validation Testing Guide](VALIDATION_TESTING_GUIDE.md)

## Related Documentation

- [Documentation Hub](../README.md)
- [Operations Index](../operations/README.md)
- [Development Workflow](../development/DEVELOPMENT_WORKFLOW.md)
- [Security Policy](../governance/security/SECURITY.md)
