---
name: proxmox-admin
description: Proxmox VE day-2 operations skill for node health, VM/LXC lifecycle, storage, backup verification, networking checks, and safe maintenance over SSH.
---

# Proxmox Admin

Operational skill for managing Proxmox VE hosts safely in production-like environments.

## Use This Skill When

- Managing Proxmox node health and services
- Creating, starting, stopping, migrating, or debugging VMs/LXCs
- Verifying storage, snapshots, and backup jobs
- Performing safe maintenance and reboots
- Troubleshooting networking, boot, and package issues

## Safety Defaults

- Always verify backups before risky operations.
- Prefer `qm shutdown`/`pct shutdown` before forced stop.
- Avoid destructive storage commands unless explicitly requested.
- Use `tmux` or `screen` for long-running tasks over SSH.
- For kernel/package changes, plan a reboot window.

## Quick Environment Checks

```bash
# Node + version
hostname
pveversion
uname -r

# Cluster and quorum
pvecm status

# Services
systemctl status pveproxy pvedaemon pvestatd pve-cluster

# Resource pressure
free -h
df -h
pvesm status
```

## VM and LXC Operations

### Inventory

```bash
qm list
pct list
```

### Power Lifecycle

```bash
# VM
qm start <vmid>
qm shutdown <vmid>
qm stop <vmid>

# Container
pct start <ctid>
pct shutdown <ctid>
pct stop <ctid>
```

### Console and Config

```bash
qm config <vmid>
pct config <ctid>
qm terminal <vmid>
pct enter <ctid>
```

### Snapshots

```bash
qm snapshot <vmid> pre-change --description "before maintenance"
pct snapshot <ctid> pre-change --description "before maintenance"

qm delsnapshot <vmid> pre-change
pct delsnapshot <ctid> pre-change
```

## Backup and Restore Essentials

```bash
# Check backup jobs and storage
pvesh get /cluster/backup
pvesm status

# Trigger manual backup task example
vzdump <vmid> --mode snapshot --compress zstd --storage <storage-id>

# List backups on a storage target
find /var/lib/vz/dump -maxdepth 1 -type f -name 'vzdump-*'
```

## Storage and Replication Checks

```bash
# Storage status
pvesm status

# ZFS status (if applicable)
zpool status
zfs list

# LVM status (if applicable)
vgs
lvs
```

## Networking and Access

```bash
# Interface and bridge config
ip -br a
cat /etc/network/interfaces

# Firewall state
pve-firewall status

# API/UI connectivity from node
curl -k https://127.0.0.1:8006/api2/json/version
```

## Maintenance Workflow

1. Validate backup recency and restore readiness.
2. Confirm cluster health (`pvecm status`) and node load.
3. Evacuate/migrate critical workloads where needed.
4. Apply changes in smallest possible blast radius.
5. Re-validate services, guests, storage, and networking.

## Troubleshooting Commands

```bash
# Task history
pvesh get /nodes/$(hostname)/tasks --limit 20

# Recent logs
journalctl -xeu pveproxy
journalctl -xeu pvedaemon
journalctl -xeu pve-cluster

# Corosync (cluster nodes)
journalctl -xeu corosync
```

## Related Commands Cheat Sheet

```bash
# Migrate VM (online where supported)
qm migrate <vmid> <target-node> --online

# Move disk
qm move_disk <vmid> <disk> <target-storage>

# Cloud-init regenerate
qm cloudinit update <vmid>

# HA resources
ha-manager status
```

## References

- Proxmox VE docs: https://pve.proxmox.com/pve-docs/
- Upgrade wiki (8 -> 9): https://pve.proxmox.com/wiki/Upgrade_from_8_to_9
