# CloudToLocalLLM Web Deployment Design

**Date:** 2026-03-07  
**Status:** Approved design baseline  
**Primary target:** Kubernetes (k3s) on Proxmox  
**Fallback target:** Docker Swarm for constrained environments only

## Goal

Deploy CloudToLocalLLM web stack with production reliability on current Proxmox infrastructure, using template-based provisioning, GitOps operations, and private-origin networking through Cloudflare Tunnel only.

## Constraints and Context

- Proxmox host is currently single-node (no corosync cluster configured).
- Host capacity is sufficient for a single-node-first Kubernetes bootstrap.
- Existing workloads are already running on the same host and must not be starved.
- Public IP exposure of app containers/services is not allowed.
- External access is Cloudflare Tunnel only.
- Persistence model is hybrid: client-local Drift/SQLite plus server-managed persistence.

## Architecture Direction

### 1) Orchestration Strategy

- Use k3s as the primary orchestrator for production path.
- Keep Docker Swarm path as non-primary fallback for constrained infra.
- Keep deployment contract stable across orchestrators:
  - Same image build pipeline
  - Same environment model
  - Same health/rollback semantics where possible

### 2) Runtime Components (Kubernetes-first)

- `web` service: Flutter static app served by Nginx-based image
- `api-backend` service: Node/Express API
- `server persistence` component: server-side persistent store for shared/server-owned data
- ingress/service routing inside cluster
- ArgoCD (separate management VM/LXC on Proxmox)

### 3) Data Ownership Boundaries

- Client-local data remains in Drift/SQLite (local state and local-first concerns).
- Shared/server-owned entities remain in backend persistence.
- API contracts must explicitly define ownership per entity to avoid drift and split-brain behavior.

## Proxmox Provisioning Model

### 1) Template System

- Build a golden Ubuntu 24.04 cloud-image-based VM template.
- Include cloud-init support and baseline hardening.
- Clone from template for:
  - `k3s-control-01` (initial control node)
  - future workers (`k3s-worker-0x`)

### 2) Scale Path

- Start single-node k3s.
- Add worker nodes by cloning template and joining cluster when thresholds are hit.
- Enable multi-node scheduling policies during expansion phase.

## GitOps and Release Flow

1. Build immutable `web` and `api` images.
2. Push tagged images to registry (no mutable production tags).
3. Update manifests in git with pinned image tags.
4. ArgoCD syncs desired state to k3s.
5. Validate rollout via health gates.
6. Roll back to previous revision automatically or operator-triggered when gates fail.

## Networking and Security Model (Cloudflare Tunnel Only)

- No direct public exposure for app containers/services.
- Origin runs on private network only.
- Cloudflare Tunnel is the sole internet ingress path.
- External TLS termination handled at Cloudflare edge.
- Tunnel credentials stored as Kubernetes secrets.
- Firewall/routing policy prevents direct bypass of tunnel path.
- ArgoCD should be private/admin-only (VPN/Tailscale or protected management tunnel), not publicly exposed.

## Reliability, Rollback, and Validation

### Deployment Gates

- Pre-deploy checks:
  - Manifest/schema validity
  - Required secret/config presence
  - Image availability
- Post-deploy checks:
  - Web health endpoint(s)
  - API health endpoint(s)
  - Pod readiness and restart checks
  - Basic end-to-end smoke test via tunnel path

### Rollback Policy

- Any failed post-deploy gate triggers rollback to previous known-good revision.
- Capture diagnostics snapshot on failure:
  - pod events
  - relevant logs
  - deployment status

## Resource Safety on Shared Proxmox Host

- Set conservative `requests/limits` for each workload.
- Protect incumbent workloads from starvation.
- Alert on sustained host pressure before user-facing degradation.

## Decision Triggers for Scale Expansion

Promote from single-node to multi-node when at least two conditions hold:

- sustained high utilization during peak windows
- need for stronger availability/SLO protection
- increased operational incidents/rollback frequency
- need for autoscaling behavior beyond single-node practicality

## Out of Scope (for this design)

- Full implementation task breakdown (handled in implementation plan phase)
- Detailed per-service Terraform/Ansible automation
- Full observability stack selection and tuning

## Approved Baseline Summary

- Kubernetes-first with k3s is the primary deployment path.
- Proxmox template system is mandatory for repeatable node provisioning.
- ArgoCD runs in a separate Proxmox VM/LXC for management isolation.
- Hybrid persistence boundaries are explicit.
- Cloudflare Tunnel-only ingress is enforced; no public app IP exposure.
- Reliability and rollback are enforced by deployment health gates.
