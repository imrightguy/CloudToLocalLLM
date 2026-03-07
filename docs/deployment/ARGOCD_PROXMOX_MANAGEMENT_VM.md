# ArgoCD Proxmox Management VM Runbook

This runbook defines how to run ArgoCD in a dedicated Proxmox VM/LXC, separate from application workloads.

## Purpose

- Isolate GitOps control plane from application data plane
- Improve recovery posture if app cluster is degraded
- Keep admin access private and auditable

## Baseline Sizing

For single-cluster, single-node k3s management:

- vCPU: 2
- RAM: 4 GB (minimum), 8 GB recommended
- Disk: 40 GB
- Network: private VLAN/subnet, no direct public exposure

Scale guidance:

- Increase to 4 vCPU / 8-16 GB RAM for multi-cluster operations
- Add persistent backup storage for ArgoCD state and repo cache

## Network and Access Model

- ArgoCD VM/LXC must remain on private origin network
- No direct public ingress
- Access through one of:
  - VPN/Tailscale
  - dedicated protected Cloudflare admin tunnel
- Restrict admin endpoint to trusted source identities/IP policies

## Proxmox Build Steps

1. Clone from hardened Ubuntu 24.04 template
2. Apply static IP and DNS
3. Install required packages: `curl`, `jq`, `kubectl`, `helm`
4. Configure SSH hardening and host firewall
5. Install ArgoCD CLI for admin operations

## ArgoCD Bootstrap

1. Install ArgoCD into `argocd` namespace on target k3s cluster
2. Apply `k8s/bootstrap/root-app.yaml` or managed variant
3. Verify ApplicationSet health (`k8s/apps/managed/argo-apps.yaml`)
4. Confirm sync automation and self-heal behavior

## Security Controls

- Store tunnel/admin tokens in Kubernetes secrets only
- Rotate ArgoCD admin credentials and API tokens regularly
- Enable RBAC role separation for deployers vs auditors
- Audit failed logins and unauthorized app edits

## Backup and Restore Checklist

- Backup ArgoCD namespace resources regularly
- Export projects/applications metadata
- Keep git as source of truth for desired state
- Validate restore quarterly in a staging cluster

## Operational Checks

- `argocd app list` reports expected apps and health
- No public app route exposes `argocd-server`
- Cloudflare admin tunnel targets only `argocd-server.argocd.svc.cluster.local:80`
- Sync drift alerts are monitored and actionable
