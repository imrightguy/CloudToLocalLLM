# Operations Documentation

Operational documentation covers running, monitoring, recovering, and securing CloudToLocalLLM infrastructure.

## Primary Operations

- [Deployment Index](../deployment/README.md)
- [Self Hosting](../deployment/SELF_HOSTING.md)
- [Docker Deployment](../deployment/DOCKER_DEPLOYMENT.md)
- [Complete Deployment Workflow](../deployment/COMPLETE_DEPLOYMENT_WORKFLOW.md)
- [Strict Deployment Policy](../deployment/STRICT_DEPLOYMENT_POLICY.md)

## CI/CD

- [Unified Deployment Workflow](cicd/UNIFIED_DEPLOYMENT_WORKFLOW.md)
- [CI/CD Quick Reference](cicd/CI_CD_QUICK_REFERENCE.md)

## Backend Operations

- [Backend Operations Index](backend/README.md)
- [Backup Recovery](backend/BACKUP_RECOVERY_QUICK_REFERENCE.md)
- [Database Performance](backend/DATABASE_PERFORMANCE_QUICK_REFERENCE.md)
- [Error Recovery](backend/ERROR_RECOVERY_QUICK_REFERENCE.md)
- [Prometheus Metrics](backend/PROMETHEUS_METRICS_QUICK_REFERENCE.md)

## Security Operations

- [Backend Security](security/BACKEND_SECURITY.md)
- [Rate Limiting](security/RATE_LIMITING.md)
- [RBAC Guide](security/RBAC_GUIDE.md)

## Current Baseline

CloudToLocalLLM supports local desktop operation first. Cloud deployment paths currently include Docker Compose for self-hosting and Kubernetes manifests under `k8s/` and `config/kubernetes/`; provider-specific deployment notes should be treated as runbooks, not universal architecture.
