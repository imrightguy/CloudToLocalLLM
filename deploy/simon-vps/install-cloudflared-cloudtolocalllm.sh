#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${INSTALL_ROOT:-/}"
CLOUDFLARED_BIN="${CLOUDFLARED_BIN:-/usr/local/bin/cloudflared}"
CLOUDFLARE_TUNNEL_ID="${CLOUDFLARE_TUNNEL_ID:-b0aebd5d-5fdf-4dc1-b64c-932c4ee8b400}"
CLOUDFLARE_TUNNEL_TOKEN="${CLOUDFLARE_TUNNEL_TOKEN:-}"
CLOUDFLARE_TUNNEL_TOKEN_FILE="${CLOUDFLARE_TUNNEL_TOKEN_FILE:-}"
CONFIG_DIR="$INSTALL_ROOT/etc/cloudflared"
DEFAULTS_DIR="$INSTALL_ROOT/etc/default"
SYSTEMD_DIR="$INSTALL_ROOT/etc/systemd/system"
ENV_PATH="$DEFAULTS_DIR/cloudflared-cloudtolocalllm"
CONFIG_PATH="$CONFIG_DIR/cloudtolocalllm.yml"
SERVICE_PATH="$SYSTEMD_DIR/cloudflared-cloudtolocalllm.service"

mkdir -p "$CONFIG_DIR" "$DEFAULTS_DIR" "$SYSTEMD_DIR"

if [[ ! -x "$CLOUDFLARED_BIN" ]]; then
  echo "cloudflared binary not found or not executable: $CLOUDFLARED_BIN" >&2
  exit 1
fi

if [[ -z "$CLOUDFLARE_TUNNEL_TOKEN" && -n "$CLOUDFLARE_TUNNEL_TOKEN_FILE" && -f "$CLOUDFLARE_TUNNEL_TOKEN_FILE" ]]; then
  CLOUDFLARE_TUNNEL_TOKEN="$(tr -d '\r\n' < "$CLOUDFLARE_TUNNEL_TOKEN_FILE")"
fi

if [[ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]]; then
  echo "CLOUDFLARE_TUNNEL_TOKEN or CLOUDFLARE_TUNNEL_TOKEN_FILE is required" >&2
  exit 1
fi

printf 'TUNNEL_TOKEN=%s\n' "$CLOUDFLARE_TUNNEL_TOKEN" > "$ENV_PATH"
chmod 600 "$ENV_PATH"
cp "$SCRIPT_DIR/cloudtolocalllm.yml" "$CONFIG_PATH"
sed -i "s/^tunnel: .*/tunnel: $CLOUDFLARE_TUNNEL_ID/" "$CONFIG_PATH"
cp "$SCRIPT_DIR/cloudflared-cloudtolocalllm.service" "$SERVICE_PATH"
chmod 644 "$SERVICE_PATH"

if [[ -z "${INSTALL_ROOT:-}" || "$INSTALL_ROOT" == "/" ]]; then
  systemctl daemon-reload
  systemctl enable --now cloudflared-cloudtolocalllm.service
fi
