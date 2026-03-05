---
name: proxmox-upgrade
description: Proxmox VE upgrade runbook skill for safe major-version upgrades (including 8 to 9) with checklist automation, repository migration, dist-upgrade execution, reboot validation, and rollback awareness.
---

# Proxmox Upgrade Runbook

Structured upgrade playbook for Proxmox VE hosts.

## Use This Skill When

- Planning or executing Proxmox major upgrades
- Validating pre-upgrade readiness
- Updating apt repositories to new Debian/PVE suite
- Running controlled `apt dist-upgrade` and reboot checks

## Mandatory Preconditions

- Verified, recent backups of all critical guests.
- Out-of-band access (IPMI/IKVM) strongly preferred.
- Root filesystem free space >= 5 GB (10+ GB preferred).
- Latest minor release on current major version before switching repos.

## Preflight Checklist

```bash
pveversion
uname -r
df -h /
pve8to9 --full
apt update && apt dist-upgrade -y
```

## Repository Transition Pattern (8 -> 9)

1. Backup apt configs:
   - `/etc/apt/sources.list`
   - `/etc/apt/sources.list.d/*`
2. Switch Debian suite from `bookworm` -> `trixie`.
3. Add Proxmox VE 9 repository in deb822 format (`*.sources`).
4. Disable old `.list` entries for PVE 8 / old Ceph channels.
5. Run `apt update` and inspect `apt policy` for expected origins only.

## Upgrade Execution

```bash
# Optional: remove unnecessary systemd-boot meta package when warned
apt remove -y systemd-boot

# Noninteractive but conservative config handling
DEBIAN_FRONTEND=noninteractive \
APT_LISTCHANGES_FRONTEND=none \
apt -o Dpkg::Options::=--force-confdef \
    -o Dpkg::Options::=--force-confold \
    -y dist-upgrade

# Repair if needed
apt -f install -y
```

## Post-Upgrade Validation

```bash
pveversion
apt update
apt list --upgradable
pve8to9 --full
```

Expected:

- `pve-manager/9.x`
- no upgrade failures
- warning only if reboot pending old kernel

## Reboot and Final Validation

```bash
reboot

# after reconnect
uname -r
pveversion
systemctl --failed
```

Target state:

- running latest installed PVE 9 kernel
- core Proxmox services active

## Cluster Guidance

- Upgrade one node at a time.
- Migrate critical guests away before node upgrade.
- Avoid mixed-version operations from a newer GUI onto older nodes when possible.
- Validate quorum after each node.

## Known Risk Areas

- Bootloader mode mismatches (legacy vs UEFI)
- Interface name changes after new kernel
- Third-party storage plugins not yet compatible
- Old hardware incompatibilities with newer kernel/QEMU

## Rollback Awareness

- Apt major upgrades are not trivially reversible.
- Rollback path is typically restore from backups or host reinstall + restore.
- Keep backup of apt source files and critical `/etc` configs before changing repos.

## References

- Upgrade wiki: https://pve.proxmox.com/wiki/Upgrade_from_8_to_9
- Debian 13 release notes: https://www.debian.org/releases/trixie/release-notes/
