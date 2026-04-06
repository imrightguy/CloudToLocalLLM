# TOOLS.md - Zoidbot Environment Cheat Sheet

## Channels

| Platform | Home ID | Notes |
|----------|---------|-------|
| Discord | `1466397358790152353` | No threads, no @mentions, #general only |
| Telegram | `7910589259` | Topics supported |

## SSH / Remote

- LXC container: `ssh root@208.110.72.50 "pct enter 201"` (4 cores, 16GB RAM, Docker Swarm)
- GitHub: `imrightguy` (not currently authed with gh CLI)

## Google Accounts (via gog CLI)

- chokesmaster
- christopher.maltais
- cloudtolocalllm
- teh.right.bot

## Obsidian Vault

- Path: `/home/rightguy/Documents/The Right Vault`
- Recovery notes: `Zoidbot/Recovery/`
- Primary recovery source (Notion is legacy)

## Email

- christopher.maltais@gmail.com
- chokesmaster@gmail.com
- himalaya: 🔴 not configured (needs app password)

## Storage Layout

| Mount | Device | Size | Notes |
|-------|--------|------|-------|
| `/` | nvme0n1 (Btrfs) | 950GB | Root — disposable |
| `/mnt/data` | nvme1n1 (Btrfs, DATA) | 932GB | Durable — NEVER format |
| USB | sda (Ventoy) | — | Boot media |

## Key Config Paths

| Path | Purpose |
|------|---------|
| `~/.hermes/` | Hermes agent config, skills, memory |
| `~/.hermes/config.yaml` | Main gateway config |
| `~/.config/himalaya/` | Email client config (placeholder) |
| `/mnt/data/zoidbot/` | Env backups, hermes tokens, OAuth secrets |
| `/mnt/data/zoidbot/backup_hermes_env_secrets.env` | Hermes env secret backup |
