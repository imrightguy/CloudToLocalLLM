# Simon VPS deployment

This package deploys CloudToLocalLLM on Simon's VPS as a narrow single-host compose stack.

## What it exposes
- One public HTTP entrypoint on `${PUBLIC_HTTP_PORT}` (default `3100`)
- Flutter web app behind an nginx reverse proxy
- Node API on the same origin for `/api/*`, `/v1/*`, `/health`, `/dashboard/ws`, `/ssh`
- PostgreSQL backing store

## Why this shape
The repo's historical Swarm path is stale on the current VPS: Simon's box is running plain Docker, not Swarm, and is already hosting ImmoGestion on the same machine. This package avoids touching the existing ImmoGestion deployment while still getting CloudToLocalLLM live on the VPS.

## Build + run
From repo root on the VPS:

```bash
cp deploy/simon-vps/.env.example deploy/simon-vps/.env
# edit deploy/simon-vps/.env

# build the Flutter web assets first
./deploy/simon-vps/build-web.sh

cd deploy/simon-vps
docker compose --env-file .env up -d --build
```

## Verify
```bash
curl http://127.0.0.1:${PUBLIC_HTTP_PORT:-3100}/health
curl -I http://127.0.0.1:${PUBLIC_HTTP_PORT:-3100}/
docker compose ps
```

## Dedicated Cloudflared tunnel

This host keeps ImmoGestion untouched. CloudToLocalLLM's public path is a dedicated Cloudflare Tunnel on Simon's VPS.

Manual install:

```bash
sudo CLOUDFLARE_TUNNEL_ID=b0aebd5d-5fdf-4dc1-b64c-932c4ee8b400 \
  CLOUDFLARE_TUNNEL_TOKEN_FILE=/path/to/cloudflared.token \
  ./deploy/simon-vps/install-cloudflared-cloudtolocalllm.sh
sudo systemctl status cloudflared-cloudtolocalllm --no-pager -l
sudo journalctl -u cloudflared-cloudtolocalllm -n 100 --no-pager
```

Automated paths:
- `deployment.yml` is the normal CI/CD path for pushing code to Simon's VPS and reconciling Cloudflare.
- `recover-simon-vps-cloudflared.yml` is the manual recovery workflow for tunnel/DNS drift.

## Notes
- The web build uses `--dart-define` values so the deployed app can point at the VPS origin instead of hardcoded stale targets.
- This package intentionally uses a separate port instead of taking over 80/443, because Simon's VPS already hosts other services.
- Public HTTPS is delivered by Cloudflare Tunnel; raw `:3100` is for on-box verification, not the canonical public website path.
