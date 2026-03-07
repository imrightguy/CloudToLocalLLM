#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_ID=''
VM_ID=''
NAME=''
TARGET_NODE=''
IP_CIDR=''
GATEWAY=''
ROLE=''
STORAGE='local-zfs'
BRIDGE='vmbr0'
CORES='4'
MEMORY='8192'
DRY_RUN='false'

usage() {
  cat <<'EOF'
Usage: clone-k3s-node.sh --template-id <id> --vm-id <id> --name <name> --target-node <node> --ip-cidr <cidr> --gateway <ip> --role <control|worker> [options]

Required:
  --template-id <id>      Template VM ID to clone
  --vm-id <id>            New VM ID
  --name <name>           New VM name
  --target-node <node>    Proxmox target node
  --ip-cidr <cidr>        Static IP in CIDR format (e.g. 10.0.10.21/24)
  --gateway <ip>          Gateway IP (e.g. 10.0.10.1)
  --role <control|worker> Node role

Optional:
  --storage <name>        Storage (default: local-zfs)
  --bridge <name>         Bridge (default: vmbr0)
  --cores <n>             vCPU count (default: 4)
  --memory <mb>           Memory in MB (default: 8192)
  --dry-run               Print commands only
  --help                  Show this help
EOF
}

run() {
  if [[ "$DRY_RUN" == 'true' ]]; then
    printf '[dry-run] %s\n' "$*"
  else
    eval "$*"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template-id)
      TEMPLATE_ID="$2"; shift 2 ;;
    --vm-id)
      VM_ID="$2"; shift 2 ;;
    --name)
      NAME="$2"; shift 2 ;;
    --target-node)
      TARGET_NODE="$2"; shift 2 ;;
    --ip-cidr)
      IP_CIDR="$2"; shift 2 ;;
    --gateway)
      GATEWAY="$2"; shift 2 ;;
    --role)
      ROLE="$2"; shift 2 ;;
    --storage)
      STORAGE="$2"; shift 2 ;;
    --bridge)
      BRIDGE="$2"; shift 2 ;;
    --cores)
      CORES="$2"; shift 2 ;;
    --memory)
      MEMORY="$2"; shift 2 ;;
    --dry-run)
      DRY_RUN='true'; shift ;;
    --help|-h)
      usage; exit 0 ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TEMPLATE_ID" || -z "$VM_ID" || -z "$NAME" || -z "$TARGET_NODE" || -z "$IP_CIDR" || -z "$GATEWAY" || -z "$ROLE" ]]; then
  printf 'Error: missing required arguments.\n' >&2
  usage
  exit 1
fi

if [[ "$ROLE" != 'control' && "$ROLE" != 'worker' ]]; then
  printf 'Error: --role must be control or worker\n' >&2
  exit 1
fi

printf 'Cloning %s node from template %s to VMID %s (%s)\n' "$ROLE" "$TEMPLATE_ID" "$VM_ID" "$NAME"

run "qm clone ${TEMPLATE_ID} ${VM_ID} --name ${NAME} --target ${TARGET_NODE} --full 1"
run "qm set ${VM_ID} --cores ${CORES} --memory ${MEMORY}"
run "qm set ${VM_ID} --net0 virtio,bridge=${BRIDGE}"
run "qm set ${VM_ID} --ipconfig0 ip=${IP_CIDR},gw=${GATEWAY}"
run "qm set ${VM_ID} --ciuser ubuntu"
run "qm set ${VM_ID} --scsi0 ${STORAGE}:vm-${VM_ID}-disk-0"
run "qm start ${VM_ID}"

if [[ "$ROLE" == 'control' ]]; then
  printf 'Next: install k3s server on %s and capture token from /var/lib/rancher/k3s/server/node-token\n' "$NAME"
else
  printf 'Next: join worker %s using:\n' "$NAME"
  printf '  curl -sfL https://get.k3s.io | K3S_URL=https://<control-ip>:6443 K3S_TOKEN=<token> sh -\n'
fi
