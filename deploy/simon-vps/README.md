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

This host keeps ImmoGestion untouched. If Cloudflare Tunnel is used for public access, install the Simon-VPS-specific unit and config with:

```bash
sudo CLOUDFLARE_TUNNEL_ID=62da6c19-947b-4bf6-acad-100a73de4e0d \
  CLOUDFLARE_TUNNEL_TOKEN_FILE=/etc/cloudflared/62da6c19-947b-4bf6-acad-100a73de4e0d.token \
  ./deploy/simon-vps/install-cloudflared-cloudtolocalllm.sh
sudo systemctl status cloudflared-cloudtolocalllm --no-pager -l
sudo journalctl -u cloudflared-cloudtolocalllm -n 100 --no-pager
```

## Notes
- The web build uses `--dart-define` values so the deployed app can point at the VPS origin instead of the hardcoded production domains.
- This package intentionally uses a separate port instead of taking over 80/443, because Simon's VPS already hosts other services.
- For a later public DNS/TLS cutover, put Cloudflare/Tailscale in front of this port instead of changing the app again.
