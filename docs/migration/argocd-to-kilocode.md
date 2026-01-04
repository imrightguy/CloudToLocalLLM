# Migration Plan: ArgoCD to Kilocode GitOps Controller (Final)

## 1. Executive Summary
This document defines the technical strategy for replacing the multi-pod ArgoCD deployment with a streamlined, single-pod GitOps controller. The architecture leverages the **official `kilocode/cli` Docker container** as the core execution engine and implements **Comprehensive Audit Logging** and a **Legacy Decommissioning Plan** to ensure a clean, secure, and compliant transition.

## 2. Architecture Design
The Kilocode GitOps Controller operates as a single Kubernetes Pod containing two containers in a sidecar pattern.

### 2.1 GitOps Trigger Sidecar (Management & Webhooks)
A lightweight service responsible for:
*   **Webhook Listener**: Exposes a REST endpoint (port 8080) for immediate sync triggers (e.g., from GitHub Actions).
*   **Scheduler**: Manages configurable polling intervals for drift detection.
*   **Audit Logger**: Captures and persists metadata for every trigger event (Source IP, User-Agent, SHA, Timestamp).
*   **Orchestration**: Signals the `kilocode/cli` container to start reconciliation.

### 2.2 Core Execution Engine (`kilocode/cli`)
The official `kilocode/cli:latest` image handles:
*   **Git Sync**: Performing `git pull` on the shared volume.
*   **Analysis & Application**: Executing `kilocode --auto --sync` to reconcile cluster state with Git.
*   **Output Capture**: All CLI execution logs (stdout/stderr) are captured by the sidecar and persisted.

## 3. Comprehensive Audit Logging & Persistence
Audit logging is a core component of the implementation, ensuring every GitOps event is traceable.

### 3.1 Log Capture Strategy
*   **Trigger Logs**: Logs the initiation of every sync (polling vs. webhook), including the triggering payload.
*   **Execution Logs**: Captures the raw output of the `kilocode/cli` execution, including AI decision reasoning and `kubectl` application results.
*   **Sync Event Logs**: Summarizes the outcome (Success/Failure, number of resources modified, Duration).

### 3.2 Persistence & Storage
*   **Local Persistence**: Logs are written to a `/logs` directory on a Persistent Volume (PV) shared with the administrative dashboard for history retrieval.
*   **Cloud Observability**: Simultaneous streaming of logs to standard output for capture by FluentBit/Loki/CloudWatch.
*   **Audit Store**: A structured JSON audit trail (`audit.jsonl`) is maintained for programmatic analysis.

## 4. Legacy ArgoCD Decommissioning Plan
To ensure a clean environment, all ArgoCD artifacts must be purged after the Kilocode controller is verified.

### 4.1 Identified ArgoCD Components
*   **Namespaces**: `argocd`
*   **CRDs**: `applications.argoproj.io`, `applicationsets.argoproj.io`, `appprojects.argoproj.io`
*   **Core Services**: `argocd-server`, `argocd-repo-server`, `argocd-application-controller`, `argocd-redis`, `argocd-dex-server`, `argocd-notifications-controller`
*   **RBAC**: `argocd-manager` Role, ClusterRoles, and associated Bindings.
*   **Config**: `argocd-cm`, `argocd-secret`, `argocd-rbac-cm`.

### 4.2 Purge Commands
```bash
# 1. Delete all Applications and ApplicationSets (terminates managed resource ownership)
kubectl delete applicationsets.argoproj.io --all -n argocd
kubectl delete applications.argoproj.io --all -n argocd

# 2. Remove ArgoCD Namespace (removes deployments, services, pods, and secrets)
kubectl delete namespace argocd

# 3. Remove Cluster-wide RBAC
kubectl delete clusterrole argocd-server argocd-application-controller
kubectl delete clusterrolebinding argocd-server argocd-application-controller

# 4. Final Cleanup: Purge CRDs (Caution: This removes all history of Argo resources)
kubectl delete crd applications.argoproj.io applicationsets.argoproj.io appprojects.argoproj.io
```

## 5. Kubernetes Infrastructure

### 5.1 RBAC & Identity
The pod uses a dedicated `ServiceAccount` with a `ClusterRole` permitting management of all resources managed by the previous ArgoCD deployment.

### 5.2 Volume Architecture
*   **Workspace (`/workspace`)**: Shared `EmptyDir` or `PVC` for the repository clone.
*   **Audit Logs (`/logs`)**: Dedicated `PVC` for persistent storage of synchronization history and audit trails.
*   **Secrets**: Mounted Git SSH keys and Kilocode configuration files.

## 6. Implementation Roadmap

### Phase 1: Controller & Identity Setup (Current)
*   Establish `kilocode-system` namespace and RBAC.
*   Deploy the dual-container pod with the official `kilocode/cli` image.
*   **Active Audit Engine**: Enable JSONL log persistence and execution output capture.

### Phase 2: Migration & Parity Verification
*   Switch Git webhooks to the Kilocode endpoint.
*   Validate sync parity (Kilocode vs. ArgoCD sync status).
*   Verify log integrity for both successful and failed sync attempts.

### Phase 3: Purge & Decommissioning
*   Execute the ArgoCD Decommissioning Plan (Section 4.2).
*   Conduct an environment audit to ensure no `argoproj.io` annotations or legacy RBAC remain.

## 7. Future Extensibility
*   **Advanced Rollbacks**: Historical SHA selection via the dashboard using persisted `/logs`.
*   **Multi-Cluster Management**: Coordinating sync across multiple remote clusters.
