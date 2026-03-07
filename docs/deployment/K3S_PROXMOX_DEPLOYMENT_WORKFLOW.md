# k3s on Proxmox Deployment Workflow

This workflow defines the Kubernetes-first deployment path on Proxmox with Cloudflare Tunnel-only ingress.

## Prerequisites

- Proxmox VE node with sufficient free resources
- Ubuntu 24.04 cloud image available on Proxmox storage
- DNS and Cloudflare Tunnel prepared
- Container registry credentials for app images

## Step 1: Create Proxmox k3s Template

Use:

```bash
scripts/proxmox/create-k3s-template.sh \
  --template-id 9001 \
  --name k3s-ubuntu-2404-template \
  --storage local-zfs \
  --image-path /var/lib/vz/template/iso/ubuntu-24.04-server-cloudimg-amd64.img
```

## Step 2: Clone Control Node from Template

```bash
scripts/proxmox/clone-k3s-node.sh \
  --template-id 9001 \
  --vm-id 9101 \
  --name k3s-control-01 \
  --target-node pve \
  --ip-cidr 10.0.10.21/24 \
  --gateway 10.0.10.1 \
  --role control
```

## Step 3: Install k3s Control Plane

On control node:

```bash
curl -sfL https://get.k3s.io | sh -
kubectl get nodes
```

## Step 4: Provision ArgoCD Management VM/LXC

Follow `docs/deployment/ARGOCD_PROXMOX_MANAGEMENT_VM.md`.

## Step 5: Bootstrap GitOps

Apply bootstrap app:

```bash
kubectl apply -f k8s/bootstrap/root-app.yaml
kubectl -n argocd get applications,applicationsets
```

## Step 6: Deploy Cloudflare Tunnel-Only Ingress

- Managed app ingress uses `k8s/deployments/overlays/managed/cloudflared-tunnel.yaml`
- Admin ArgoCD ingress uses `k8s/deployments/overlays/managed/cloudflared-admin-tunnel.yaml`

Validate render:

```bash
kubectl kustomize k8s/apps/managed/ingress-cloudflared > /tmp/ingress-cloudflared-render.yaml
```

## Step 7: Verify Deployment Health

```bash
bash scripts/verify-k8s-tunnel-only.sh
bash scripts/integration-test-deployments.sh --e2e-deployment
```

## Step 8: Expansion to Multi-Node (When Needed)

- Clone worker nodes from the same template
- Join workers using control-plane token
- Enable multi-node scheduling and scaling policies

## Rollback Drill

- Trigger a controlled bad rollout in staging
- Verify health gate failure path
- Confirm rollback to previous ArgoCD revision
- Capture and review diagnostics logs/events
