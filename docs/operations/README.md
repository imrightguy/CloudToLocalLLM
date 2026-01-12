# Operations Documentation
 
This directory contains comprehensive operational guides for CloudToLocalLLM infrastructure management.
 
## 📚 Contents
 
### Core Operations
- **[Infrastructure](INFRASTRUCTURE.md)** - Server requirements and environment strategy.
- **[Self Hosting](SELF_HOSTING.md)** - Deploy your own instance via Docker Compose (Core Feature).
- **[Disaster Recovery](DISASTER_RECOVERY_STRATEGY.md)** - Continuity and recovery procedures.
 
### Monitoring & Troubleshooting
- **[Tunnel Troubleshooting](TUNNEL_TROUBLESHOOTING.md)** - Diagnose and fix tunnel connectivity issues.
- **[Alert Response](ALERT_RESPONSE_PROCEDURES.md)** - Incident response steps.
- **[Grafana Usage](GRAFANA_MCP_TOOLS_USAGE.md)** - Monitoring dashboards and tools.
 
### Platform-Specific Operations
 
#### AWS Operations
See the **[AWS Operations Index](aws/README.md)** for:
- EKS Deployment
- CloudFormation Stacks
- Operations Runbook
 
#### Kubernetes Operations
- **[Kubernetes Quickstart](kubernetes/KUBERNETES_QUICKSTART.md)** - Quick setup for K8s.
- **[Self-Hosted K8s](kubernetes/KUBERNETES_SELF_HOSTED_GUIDE.md)** - Running K8s on your own hardware.
 
#### CI/CD Operations
- **[Unified Deployment Workflow](cicd/UNIFIED_DEPLOYMENT_WORKFLOW.md)** - Current GHA pipeline details (AWS/GHCR).
- **[CI/CD Quick Reference](cicd/CI_CD_QUICK_REFERENCE.md)** - Quick commands and secret config.
 
## 📖 Operations Overview
 
CloudToLocalLLM supports two primary production paths:
1. **AWS EKS**: Managed Kubernetes for scale and high availability.
2. **Self-Hosted**: Docker Compose on a single Linux VPS for privacy and simplicity.
