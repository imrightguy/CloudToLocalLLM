#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${INSTALL_ROOT:-/}"
CLOUDFLARED_BIN="${CLOUDFLARED_BIN:-/usr/local/bin/cloudflared}"
CLOUDFLARE_TUNNEL_ID="${CLOUDFLARE_TUNNEL_ID:-62da6c19-947b-4bf6-acad-100a73de4e0d}"
CLOUDFLARE_CREDENTIALS_FILE="${CLOUDFLARE_CREDENTIALS_FILE:-/etc/cloudflared/${CLOUDFLARE_TUNNEL_ID}.json}"
CLOUDFLARE_TUNNEL_TOKEN_FILE="${CLOUDFLARE_TUNNEL_TOKEN_FILE:-/etc/cloudflared/${CLOUDFLARE_TUNNEL_ID}.token}"
CONFIG_DIR="$INSTALL_ROOT/etc/cloudflared"
SYSTEMD_DIR="$INSTALL_ROOT/etc/systemd/system"
CONFIG_PATH="$CONFIG_DIR/cloudtolocalllm.yml"
SERVICE_PATH="$SYSTEMD_DIR/cloudflared-cloudtolocalllm.service"

mkdir -p "$CONFIG_DIR" "$SYSTEMD_DIR"

if [[ ! -x "$CLOUDFLARED_BIN" ]]; then
  echo "cloudflared binary not found or not executable: $CLOUDFLARED_BIN" >&2
  exit 1
fi

USE_TOKEN_FILE="false"
if [[ -f "$CLOUDFLARE_TUNNEL_TOKEN_FILE" ]]; then
  USE_TOKEN_FILE="true"
elif [[ -f "$CLOUDFLARE_CREDENTIALS_FILE" ]]; then
  USE_TOKEN_FILE="false"
else
  echo "cloudflared token file not found: $CLOUDFLARE_TUNNEL_TOKEN_FILE" >&2
  echo "cloudflared credentials file not found: $CLOUDFLARE_CREDENTIALS_FILE" >&2
  exit 1
fi

if [[ "$USE_TOKEN_FILE" == "true" ]]; then
cat > "$CONFIG_PATH" <<EOF
tunnel: $CLOUDFLARE_TUNNEL_ID
ingress:
  - hostname: app.cloudtolocalllm.online
    service: http://127.0.0.1:3100
  - hostname: api.cloudtolocalllm.online
    service: http://127.0.0.1:3100
  - service: http_status:404
EOF
else
cat > "$CONFIG_PATH" <<EOF
tunnel: $CLOUDFLARE_TUNNEL_ID
credentials-file: $CLOUDFLARE_CREDENTIALS_FILE
ingress:
  - hostname: app.cloudtolocalllm.online
    service: http://127.0.0.1:3100
  - hostname: api.cloudtolocalllm.online
    service: http://127.0.0.1:3100
  - service: http_status:404
EOF
fi

if [[ "$USE_TOKEN_FILE" == "true" ]]; then
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=cloudflared CloudToLocalLLM tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$CLOUDFLARED_BIN --config $CONFIG_PATH tunnel run --token-file $CLOUDFLARE_TUNNEL_TOKEN_FILE
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
else
  cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=cloudflared CloudToLocalLLM tunnel
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$CLOUDFLARED_BIN --config $CONFIG_PATH tunnel run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

if [[ -z "${INSTALL_ROOT:-}" || "$INSTALL_ROOT" == "/" ]]; then
  systemctl daemon-reload
  systemctl enable --now cloudflared-cloudtolocalllm.service
fi
