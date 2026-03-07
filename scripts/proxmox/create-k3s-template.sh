#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_ID=''
NAME=''
STORAGE=''
IMAGE_PATH=''
CORES='4'
MEMORY='8192'
DISK_GB='40'
BRIDGE='vmbr0'
CI_USER='ubuntu'
DRY_RUN='false'

usage() {
  cat <<'EOF'
Usage: create-k3s-template.sh --template-id <id> --name <name> --storage <storage> --image-path <path> [options]

Required:
  --template-id <id>      VM ID for the template
  --name <name>           Template VM name
  --storage <storage>     Proxmox storage name (e.g., local-zfs)
  --image-path <path>     Path to Ubuntu cloud image on Proxmox host

Optional:
  --cores <n>             vCPU count (default: 4)
  --memory <mb>           Memory in MB (default: 8192)
  --disk-gb <gb>          Disk size in GB (default: 40)
  --bridge <name>         Network bridge (default: vmbr0)
  --ci-user <name>        Cloud-init username (default: ubuntu)
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

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Error: required command not found: %s\n' "$1" >&2
    exit 1
  }
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --template-id)
      TEMPLATE_ID="$2"
      shift 2
      ;;
    --name)
      NAME="$2"
      shift 2
      ;;
    --storage)
      STORAGE="$2"
      shift 2
      ;;
    --image-path)
      IMAGE_PATH="$2"
      shift 2
      ;;
    --cores)
      CORES="$2"
      shift 2
      ;;
    --memory)
      MEMORY="$2"
      shift 2
      ;;
    --disk-gb)
      DISK_GB="$2"
      shift 2
      ;;
    --bridge)
      BRIDGE="$2"
      shift 2
      ;;
    --ci-user)
      CI_USER="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN='true'
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$TEMPLATE_ID" || -z "$NAME" || -z "$STORAGE" || -z "$IMAGE_PATH" ]]; then
  printf 'Error: missing required arguments.\n' >&2
  usage
  exit 1
fi

if [[ "$DRY_RUN" != 'true' && ! -f "$IMAGE_PATH" ]]; then
  printf 'Error: image path does not exist: %s\n' "$IMAGE_PATH" >&2
  exit 1
fi

if [[ "$DRY_RUN" != 'true' ]]; then
  require_cmd qm
  require_cmd pvesm
fi

printf 'Creating k3s template VM %s (%s) on storage %s\n' "$NAME" "$TEMPLATE_ID" "$STORAGE"

run "qm destroy ${TEMPLATE_ID} --destroy-unreferenced-disks 1 --purge 1 >/dev/null 2>&1 || true"
run "qm create ${TEMPLATE_ID} --name ${NAME} --memory ${MEMORY} --cores ${CORES} --cpu host --net0 virtio,bridge=${BRIDGE} --agent enabled=1 --ostype l26"
run "qm importdisk ${TEMPLATE_ID} ${IMAGE_PATH} ${STORAGE}"
run "qm set ${TEMPLATE_ID} --scsihw virtio-scsi-pci --scsi0 ${STORAGE}:vm-${TEMPLATE_ID}-disk-0"
run "qm set ${TEMPLATE_ID} --ide2 ${STORAGE}:cloudinit"
run "qm set ${TEMPLATE_ID} --boot c --bootdisk scsi0"
run "qm set ${TEMPLATE_ID} --serial0 socket --vga serial0"
run "qm resize ${TEMPLATE_ID} scsi0 ${DISK_GB}G"
run "qm set ${TEMPLATE_ID} --ciuser ${CI_USER}"
run "qm set ${TEMPLATE_ID} --ipconfig0 ip=dhcp"
run "qm template ${TEMPLATE_ID}"

printf 'Template workflow complete for VMID %s\n' "$TEMPLATE_ID"
