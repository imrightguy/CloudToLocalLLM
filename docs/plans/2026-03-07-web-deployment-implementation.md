# Kubernetes-First Proxmox Deployment Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a Kubernetes-first (k3s) deployment path on Proxmox with Cloudflare Tunnel-only ingress, template-based node provisioning, and ArgoCD management isolation.

**Architecture:** This plan hardens the existing k8s/Argo setup by codifying Proxmox template workflows, splitting public app ingress from admin surfaces, and enforcing private-origin networking through Cloudflare Tunnel. Changes are scoped to deployment manifests, scripts, and deployment documentation so runtime behavior is reproducible and auditable.

**Tech Stack:** Kubernetes (k3s), ArgoCD, Kustomize, Cloudflare Tunnel (`cloudflared`), Proxmox VE, Bash, Markdown.

---

### Task 1: Add Proxmox k3s Template Provisioning Script

**Files:**
- Create: `scripts/proxmox/create-k3s-template.sh`
- Test: `scripts/proxmox/create-k3s-template.sh`
- Modify: `docs/deployment/DEPLOYMENT_OVERVIEW.md`

**Step 1: Write the failing test**

Run:
```bash
bash -n scripts/proxmox/create-k3s-template.sh
```
Expected: FAIL with `No such file or directory`.

**Step 2: Create script with parameter validation and dry-run mode**

Add complete script with:
- required args: `--template-id`, `--name`, `--storage`, `--image-path`
- optional args: `--cores`, `--memory`, `--disk-gb`, `--bridge`, `--dry-run`
- commands encapsulating `qm create`, `qm importdisk`, cloud-init config, and `qm template`

Script skeleton:
```bash
#!/usr/bin/env bash
set -euo pipefail

DRY_RUN="false"
run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run] %s\n' "$*"
  else
    eval "$*"
  fi
}
```

**Step 3: Run shell syntax check**

Run:
```bash
bash -n scripts/proxmox/create-k3s-template.sh
```
Expected: PASS (exit code 0).

**Step 4: Run dry-run verification**

Run:
```bash
scripts/proxmox/create-k3s-template.sh --template-id 9001 --name k3s-ubuntu-2404-template --storage local-zfs --image-path /var/lib/vz/template/iso/ubuntu-24.04-server-cloudimg-amd64.img --dry-run
```
Expected: PASS with printed `qm` commands and no execution.

**Step 5: Commit**

```bash
git add scripts/proxmox/create-k3s-template.sh docs/deployment/DEPLOYMENT_OVERVIEW.md
git commit -m "feat: add Proxmox k3s VM template provisioning script"
```

### Task 2: Add k3s Node Clone-and-Join Script

**Files:**
- Create: `scripts/proxmox/clone-k3s-node.sh`
- Test: `scripts/proxmox/clone-k3s-node.sh`
- Modify: `docs/deployment/COMPLETE_DEPLOYMENT_WORKFLOW.md`

**Step 1: Write the failing test**

Run:
```bash
bash -n scripts/proxmox/clone-k3s-node.sh
```
Expected: FAIL with `No such file or directory`.

**Step 2: Implement script for control/worker node clone**

Include:
- args: `--template-id`, `--vm-id`, `--name`, `--target-node`, `--ip-cidr`, `--gateway`, `--role`
- cloud-init network config injection
- output with join-command placeholder for workers

**Step 3: Run shell syntax check**

Run:
```bash
bash -n scripts/proxmox/clone-k3s-node.sh
```
Expected: PASS.

**Step 4: Run dry-run verification**

Run:
```bash
scripts/proxmox/clone-k3s-node.sh --template-id 9001 --vm-id 9101 --name k3s-control-01 --target-node pve --ip-cidr 10.0.10.21/24 --gateway 10.0.10.1 --role control --dry-run
```
Expected: PASS with clone/start/config commands printed.

**Step 5: Commit**

```bash
git add scripts/proxmox/clone-k3s-node.sh docs/deployment/COMPLETE_DEPLOYMENT_WORKFLOW.md
git commit -m "feat: add Proxmox k3s clone workflow for control and worker nodes"
```

### Task 3: Enforce Cloudflare Tunnel-Only Ingress for Public App Endpoints

**Files:**
- Modify: `k8s/deployments/overlays/managed/cloudflared-tunnel.yaml`
- Test: `k8s/deployments/overlays/managed/cloudflared-tunnel.yaml`

**Step 1: Write the failing test**

Run:
```bash
grep -n "argocd.cloudtolocalllm.online" k8s/deployments/overlays/managed/cloudflared-tunnel.yaml
```
Expected: FAILING policy check because ArgoCD is currently publicly routed.

**Step 2: Remove direct public ArgoCD route and keep app/API/grafana routes**

Edit `config.yaml` ingress list to:
- keep app/api/root/grafana entries
- remove public `argocd.cloudtolocalllm.online`
- preserve catch-all `http_status:404`

**Step 3: Validate manifest render**

Run:
```bash
kubectl kustomize k8s/deployments/overlays/managed > /tmp/managed-render.yaml
```
Expected: PASS render with cloudflared resources present.

**Step 4: Commit**

```bash
git add k8s/deployments/overlays/managed/cloudflared-tunnel.yaml
git commit -m "fix: remove public ArgoCD route from managed cloudflared ingress"
```

### Task 4: Add Private Admin Tunnel Overlay for ArgoCD

**Files:**
- Create: `k8s/deployments/overlays/managed/cloudflared-admin-tunnel.yaml`
- Modify: `k8s/apps/managed/ingress-cloudflared/kustomization.yaml`
- Test: `k8s/deployments/overlays/managed/cloudflared-admin-tunnel.yaml`

**Step 1: Write the failing test**

Run:
```bash
test -f k8s/deployments/overlays/managed/cloudflared-admin-tunnel.yaml
```
Expected: FAIL (file missing).

**Step 2: Implement separate admin tunnel manifest**

Define dedicated deployment/config for admin ingress only:
- hostname: `argocd-admin.cloudtolocalllm.online`
- service: `argocd-server.argocd.svc.cluster.local:80`
- separate token secret key (for least privilege)

**Step 3: Include new resource in managed ingress kustomization**

Update:
```yaml
resources:
  - ../../../deployments/overlays/managed/cloudflared-tunnel.yaml
  - ../../../deployments/overlays/managed/cloudflared-admin-tunnel.yaml
```

**Step 4: Validate kustomize output**

Run:
```bash
kubectl kustomize k8s/apps/managed/ingress-cloudflared > /tmp/ingress-cloudflared-render.yaml
```
Expected: PASS with both tunnel deployments rendered.

**Step 5: Commit**

```bash
git add k8s/deployments/overlays/managed/cloudflared-admin-tunnel.yaml k8s/apps/managed/ingress-cloudflared/kustomization.yaml
git commit -m "feat: add dedicated private admin cloudflare tunnel for ArgoCD"
```

### Task 5: Add ArgoCD Management VM Runbook (Proxmox)

**Files:**
- Create: `docs/deployment/ARGOCD_PROXMOX_MANAGEMENT_VM.md`
- Modify: `docs/deployment/README.md`
- Test: `docs/deployment/ARGOCD_PROXMOX_MANAGEMENT_VM.md`

**Step 1: Write the failing test**

Run:
```bash
test -f docs/deployment/ARGOCD_PROXMOX_MANAGEMENT_VM.md
```
Expected: FAIL.

**Step 2: Write full runbook**

Include:
- VM sizing baseline (single-node now, growth notes)
- network placement and firewall model
- install steps for ArgoCD management components
- secure access patterns (VPN/Tailscale/protected tunnel)
- backup and restore checklist

**Step 3: Add index link in deployment README**

Add entry under specialized docs linking the new runbook.

**Step 4: Validate markdown links**

Run:
```bash
node scripts/validate-internal-links.js docs/deployment/README.md docs/deployment/ARGOCD_PROXMOX_MANAGEMENT_VM.md
```
Expected: PASS with no broken links.

**Step 5: Commit**

```bash
git add docs/deployment/ARGOCD_PROXMOX_MANAGEMENT_VM.md docs/deployment/README.md
git commit -m "docs: add ArgoCD management VM runbook for Proxmox"
```

### Task 6: Add End-to-End Deployment Verification for Tunnel-Only Networking

**Files:**
- Create: `scripts/verify-k8s-tunnel-only.sh`
- Modify: `scripts/integration-test-deployments.sh`
- Test: `scripts/verify-k8s-tunnel-only.sh`

**Step 1: Write the failing test**

Run:
```bash
bash -n scripts/verify-k8s-tunnel-only.sh
```
Expected: FAIL with missing file.

**Step 2: Implement verification script**

Checks:
- cloudflared deployment ready
- app/api routes resolve through expected hostnames
- no forbidden public admin host in active config
- required Kubernetes resources healthy

**Step 3: Run syntax validation**

Run:
```bash
bash -n scripts/verify-k8s-tunnel-only.sh
```
Expected: PASS.

**Step 4: Wire script into integration test flow**

Add invocation in `scripts/integration-test-deployments.sh` under managed/k8s checks.

**Step 5: Commit**

```bash
git add scripts/verify-k8s-tunnel-only.sh scripts/integration-test-deployments.sh
git commit -m "test: add k8s tunnel-only deployment verification checks"
```

### Task 7: Document k3s-on-Proxmox Workflow End-to-End

**Files:**
- Create: `docs/deployment/K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md`
- Modify: `docs/deployment/DEPLOYMENT_OVERVIEW.md`
- Modify: `docs/deployment/COMPLETE_DEPLOYMENT_WORKFLOW.md`
- Test: `docs/deployment/K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md`

**Step 1: Write the failing test**

Run:
```bash
test -f docs/deployment/K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md
```
Expected: FAIL.

**Step 2: Add complete workflow doc**

Include sequence:
1. create VM template
2. clone control node
3. install k3s
4. provision ArgoCD management VM
5. bootstrap root app
6. verify tunnel-only ingress
7. run rollback drill

**Step 3: Link from overview and workflow indexes**

Update both deployment docs with quickstart references.

**Step 4: Validate links and consistency**

Run:
```bash
node scripts/validate-internal-links.js docs/deployment/K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md docs/deployment/DEPLOYMENT_OVERVIEW.md docs/deployment/COMPLETE_DEPLOYMENT_WORKFLOW.md
```
Expected: PASS.

**Step 5: Commit**

```bash
git add docs/deployment/K3S_PROXMOX_DEPLOYMENT_WORKFLOW.md docs/deployment/DEPLOYMENT_OVERVIEW.md docs/deployment/COMPLETE_DEPLOYMENT_WORKFLOW.md
git commit -m "docs: add k3s on Proxmox deployment workflow with cloudflare tunnel model"
```

### Task 8: Final Validation and Release Readiness Check

**Files:**
- Modify: `docs/deployment/DEPLOYMENT_READY_SUMMARY.md`
- Test: `k8s/deployments/overlays/managed/cloudflared-tunnel.yaml`
- Test: `k8s/deployments/overlays/managed/cloudflared-admin-tunnel.yaml`

**Step 1: Render managed overlays and validate**

Run:
```bash
kubectl kustomize k8s/apps/managed/ingress-cloudflared > /tmp/final-ingress.yaml
kubectl kustomize k8s/apps/managed/api-backend > /tmp/final-api.yaml
kubectl kustomize k8s/apps/managed/web-frontend > /tmp/final-web.yaml
```
Expected: PASS for all commands.

**Step 2: Run deployment integration checks**

Run:
```bash
bash scripts/integration-test-deployments.sh
```
Expected: PASS for managed deployment checks (or clear actionable failures).

**Step 3: Update deployment readiness summary**

Document:
- tunnel-only ingress enforcement
- ArgoCD private access stance
- template system availability
- remaining known limitations

**Step 4: Commit**

```bash
git add docs/deployment/DEPLOYMENT_READY_SUMMARY.md
git commit -m "docs: update deployment readiness for k3s proxmox and tunnel-only ingress"
```
