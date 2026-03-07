#!/usr/bin/env bash
set -euo pipefail

# Recover Kubernetes (k3s) in a Proxmox LXC that previously hosted CloudToLocalLLM.
# This script configures /dev/kmsg passthrough required by kubelet in user namespaces,
# reinstalls k3s with KubeletInUserNamespace feature gate, and verifies cluster health.

CTID="${1:-201}"
PVE_HOST="${2:-root@208.110.72.50}"

run_ssh() {
  ssh -o BatchMode=yes -o ConnectTimeout=15 "$PVE_HOST" "$@"
}

echo "[1/6] Backing up and patching LXC config for CT ${CTID}"
run_ssh "cp /etc/pve/lxc/${CTID}.conf /etc/pve/lxc/${CTID}.conf.bak.$(date +%s) && \
  grep -q '^lxc.cgroup2.devices.allow: c 1:11 rwm' /etc/pve/lxc/${CTID}.conf || \
  printf 'lxc.cgroup2.devices.allow: c 1:11 rwm\\n' >> /etc/pve/lxc/${CTID}.conf; \
  grep -q '^lxc.mount.entry: /dev/kmsg dev/kmsg none bind,create=file' /etc/pve/lxc/${CTID}.conf || \
  printf 'lxc.mount.entry: /dev/kmsg dev/kmsg none bind,create=file\\n' >> /etc/pve/lxc/${CTID}.conf"

echo "[2/6] Restarting container"
run_ssh "pct stop ${CTID} || true; pct start ${CTID}; pct status ${CTID}"

echo "[3/6] Reinstalling k3s with user-namespace kubelet support"
run_ssh "pct exec ${CTID} -- sh -lc '/usr/local/bin/k3s-uninstall.sh || true; \
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\"server --disable traefik --disable servicelb --write-kubeconfig-mode 644 --kubelet-arg=feature-gates=KubeletInUserNamespace=true\" sh -'"

echo "[4/6] Waiting for k3s service"
run_ssh "pct exec ${CTID} -- sh -lc 'for i in \$(seq 1 30); do systemctl is-active k3s >/dev/null 2>&1 && break; sleep 2; done; systemctl is-active k3s'"

echo "[5/6] Checking node readiness"
run_ssh "pct exec ${CTID} -- sh -lc 'kubectl get nodes -o wide; kubectl get pods -A'"

echo "[6/6] Recovery complete"
run_ssh "pct exec ${CTID} -- sh -lc 'kubectl get nodes; kubectl get pods -A'"

echo "Kubernetes recovery done for CT ${CTID} on ${PVE_HOST}."
