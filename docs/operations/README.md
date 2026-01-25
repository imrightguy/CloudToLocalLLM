# Operations Documentation

This directory contains operational guides for CloudToLocalLLM infrastructure management.

## 📚 Contents

### Core Operations
- **[Self Hosting](SELF_HOSTING.md)** - Deploy your own instance via Docker Compose (Core Feature).
- **[Tunnel Troubleshooting](TUNNEL_TROUBLESHOOTING.md)** - Diagnose and fix tunnel connectivity issues.

### CI/CD Operations
- **[Unified Deployment Workflow](cicd/UNIFIED_DEPLOYMENT_WORKFLOW.md)** - GitHub Actions pipeline details (Azure/GHCR).
- **[CI/CD Quick Reference](cicd/CI_CD_QUICK_REFERENCE.md)** - Quick commands and secret config.

### Backend Services
- **[Backend Operations](backend/README.md)** - Backup, recovery, and performance guides.

## 📖 Operations Overview

CloudToLocalLLM supports two primary production paths:

1.  **Azure Swarm**: Primary managed infrastructure using Azure Virtual Machines and Docker Swarm for orchestration.
2.  **Self-Hosted**: Docker Compose on a single Linux VPS for privacy and simplicity.

Deployment to Azure is automated via GitHub Actions, using the `deployment.yml` workflow which performs forensic analysis of changes before building and deploying updated containers to the Azure Swarm.
